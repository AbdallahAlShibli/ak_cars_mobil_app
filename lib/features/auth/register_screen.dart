import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import '../services/proof_upload_sheet.dart';

enum OtpChannel { phone, email }

/// Rules 4–6: one-time registration gate before any transaction, and the
/// editor for those same details afterwards.
///
/// Both modes are one screen on purpose — they hold the identical fields and
/// the identical validation. This screen used to be sign-up only, so "My
/// details" on the profile hub reopened an empty registration form and
/// re-demanded an OTP just to correct an address.
///
/// Verification is asked for only when it means something: a brand-new
/// account, or an existing one whose phone or email actually changed. The
/// channel is then dictated by *which* of the two changed rather than left
/// as a free choice, since a code sent to the old address proves nothing.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  /// The code the staging backend always accepts. Real builds swap the mock
  /// auth service; this screen only ever compares against what it displayed.
  static const _stagingCode = '7391';
  static const _resendSeconds = 30;

  /// Captured once: the profile must not flip mid-edit if the state changes
  /// underneath (a sign-out elsewhere, a failed optimistic write rolling back).
  UserProfile? _initial;
  bool get _editing => _initial != null;

  OtpChannel _channel = OtpChannel.phone;
  bool _otpSent = false;
  bool _saving = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _otp = TextEditingController();

  /// Canonical English governorate key. Starts empty for a new account —
  /// silently defaulting to the first governorate in the list filed every
  /// user who never opened the picker under the wrong region.
  String? _region;

  /// Canonical English wilayat key, always one of [_region]'s own wilayats.
  String? _wilayat;

  /// Field key → message, shown under the offending row.
  final _errors = <String, String>{};

  // ------------------------------------------------- workshop registration

  /// What kind of account this is (§8).
  ///
  /// Null until the user picks, and only on a first registration — which is
  /// what keeps the submit button disabled at step zero (§9). An existing
  /// account already answered this and is never asked again: changing a
  /// customer account into a workshop is an application, not an edit, and it
  /// would have to go through the founder either way.
  AccountKind? _kind;

  bool get _isWorkshop => _kind == AccountKind.workshop;

  final _businessNameAr = TextEditingController();
  final _businessNameEn = TextEditingController();
  final _crNumber = TextEditingController();
  final _vatNumber = TextEditingController();

  /// Canonical English area key, from `LocationCatalog` — the same vocabulary
  /// `ServiceProvider.area` uses, so approval copies it across untouched.
  String? _area;

  /// How the workshop takes delivery of cars. A *set*, unlike the single
  /// choice a customer makes per booking: a garage that does both counter work
  /// and collection is the normal case, not an edge one.
  final _fulfillments = <Fulfillment>{};

  /// The commercial-registration certificate. Picked with the same control the
  /// proof sheet uses (`MediaStrip`) rather than a second uploader.
  final _crDocs = <ProofMedia>[];
  final _picker = ImagePicker();
  bool _pickingDoc = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;
    _initial = profile;
    _name.text = profile.name;
    // The field holds the local 8 digits only — the +968 is painted into the
    // row. Prefilling the stored "+968 9200 1234" verbatim would render the
    // dial code twice.
    _phone.text = _grouped(_local(profile.phone));
    _email.text = profile.email;
    _address.text = profile.address;
    _region = profile.region.isEmpty ? null : profile.region;
    _wilayat = profile.wilayat.isEmpty ? null : profile.wilayat;

    // An existing account keeps the kind it registered under, and a workshop
    // one reopens its own submission so a rejected application is *corrected*
    // rather than retyped from nothing (§11 step 5).
    _kind = profile.kind;
    final application = profile.workshop;
    if (application != null) {
      _businessNameAr.text = application.businessNameAr;
      _businessNameEn.text = application.businessNameEn ?? '';
      _crNumber.text = application.crNumber;
      _vatNumber.text = application.vatNumber ?? '';
      _area = application.area.isEmpty ? null : application.area;
      _fulfillments.addAll(application.fulfillments);
      if (application.crDocumentUrl.isNotEmpty) {
        _crDocs.add(ProofMedia(id: 'cr-existing', uri: application.crDocumentUrl));
      }
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _otp.dispose();
    _businessNameAr.dispose();
    _businessNameEn.dispose();
    _crNumber.dispose();
    _vatNumber.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- verification

  static String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  /// Phone reduced to its Oman-local digits, so "+968 9200 1234",
  /// "96892001234" and "9200 1234" all compare equal.
  static String _local(String v) {
    final digits = _digits(v);
    return digits.startsWith('968') ? digits.substring(3) : digits;
  }

  /// The 8 local digits split "9200 1234" for reading. Storage and every
  /// comparison go through [_local], so the space is presentation only.
  static String _grouped(String local) =>
      local.length > 4 ? '${local.substring(0, 4)} ${local.substring(4)}' : local;

  static String _normEmail(String v) => v.trim().toLowerCase();

  /// Which contact detail still has to be proven, or null when nothing does.
  ///
  /// A new account always verifies through the channel the user picked. An
  /// existing one verifies only what it changed, so editing an address or a
  /// name saves straight away.
  OtpChannel? get _pendingChannel {
    final initial = _initial;
    if (initial == null) return _channel;
    if (_local(_phone.text) != _local(initial.phone)) return OtpChannel.phone;
    final email = _normEmail(_email.text);
    if (email.isNotEmpty && email != _normEmail(initial.email)) {
      return OtpChannel.email;
    }
    return null;
  }

  /// Full E.164-ish phone as stored and displayed, built from the local field.
  String get _fullPhone => '+968 ${_grouped(_local(_phone.text))}';

  String get _otpTarget =>
      _pendingChannel == OtpChannel.email ? _email.text.trim() : _fullPhone;

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  /// Sends the code, after checking the destination is actually usable —
  /// the old screen happily announced "code sent to " with an empty address.
  void _sendOtp() {
    final s = S.of(context);
    final channel = _pendingChannel;
    if (channel == null) return;

    final error = channel == OtpChannel.phone
        ? _phoneError(s)
        : _emailError(s, required: true);
    if (error != null) {
      setState(() => _errors[channel == OtpChannel.phone ? 'phone' : 'email'] =
          error);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _otpSent = true;
      _errors.remove('otp');
    });
    _startResendCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(channel == OtpChannel.phone
            ? s.t('أُرسل الرمز عبر SMS إلى $_otpTarget — رمز التجربة: $_stagingCode',
                'Code sent by SMS to $_otpTarget — staging code: $_stagingCode')
            : s.t('أُرسل الرمز إلى $_otpTarget — رمز التجربة: $_stagingCode',
                'Code sent to $_otpTarget — staging code: $_stagingCode')),
      ),
    );
  }

  // ------------------------------------------------------------ validation

  String? _phoneError(S s) {
    final local = _local(_phone.text);
    if (local.isEmpty) {
      return s.t('رقم الهاتف مطلوب', 'Phone number is required');
    }
    if (local.length != 8) {
      return s.t('رقم عُماني من 8 أرقام', 'An 8-digit Oman number');
    }
    // The code arrives by SMS, so a landline (2x) cannot receive it.
    if (!RegExp(r'^[79]').hasMatch(local)) {
      return s.t('رقم هاتف نقّال عُماني يبدأ بـ 7 أو 9',
          'An Oman mobile number starting with 7 or 9');
    }
    return null;
  }

  String? _emailError(S s, {required bool required}) {
    final email = _normEmail(_email.text);
    if (email.isEmpty) {
      return required
          ? s.t('البريد الإلكتروني مطلوب للتوثيق بالبريد',
              'Email is required to verify by email')
          : null;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return s.t('صيغة بريد غير صحيحة', 'That does not look like an email');
    }
    return null;
  }

  /// Fills [_errors] and reports whether the form is submittable.
  bool _validate(S s) {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) {
      errors['name'] = s.t('الاسم مطلوب', 'Your name is required');
    }
    final phone = _phoneError(s);
    if (phone != null) errors['phone'] = phone;
    final channel = _pendingChannel;
    final email = _emailError(s, required: channel == OtpChannel.email);
    if (email != null) errors['email'] = email;
    if (_region == null) {
      errors['region'] = s.t('اختر المحافظة', 'Choose your governorate');
    }
    // §10. Only for a workshop account — a customer never sees these fields, so
    // it must never be blocked by them.
    if (_isWorkshop) {
      if (_businessNameAr.text.trim().isEmpty) {
        errors['businessNameAr'] = s.t('اسم السجل التجاري مطلوب',
            'The commercial registration name is required');
      }
      final cr = _crNumber.text.trim();
      if (cr.isEmpty) {
        errors['crNumber'] =
            s.t('رقم السجل التجاري مطلوب', 'The CR number is required');
      } else if (!RegExp(r'^\d{6,10}$').hasMatch(cr)) {
        // A shape check, not a registry lookup: the app cannot verify a CR
        // number, and the founder reads the certificate anyway. This only
        // catches a typo before it wastes a review.
        errors['crNumber'] = s.t('رقم السجل التجاري من 6 إلى 10 أرقام',
            'A CR number is 6–10 digits');
      }
      if (_crDocs.isEmpty) {
        errors['crDocument'] = s.t('أرفق صورة السجل التجاري',
            'Attach a photo of the commercial registration');
      }
      if (_area == null) {
        errors['area'] = s.t('اختر منطقة الورشة', "Choose the workshop's area");
      }
      // `vatNumber` is deliberately unvalidated: Oman's VAT registration is
      // turnover-based, so a small garage genuinely has no number, and a
      // required field here would simply be answered with an invented one.
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  // ---------------------------------------------------------------- submit

  Future<void> _submit() async {
    final s = S.of(context);
    if (!_validate(s)) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_pendingChannel != null) {
      // First tap sends the code and reveals the field. The old screen just
      // complained about a missing code while no code field was on screen.
      if (!_otpSent) {
        _sendOtp();
        return;
      }
      if (_otp.text.trim() != _stagingCode) {
        HapticFeedback.heavyImpact();
        setState(() => _errors['otp'] = _otp.text.trim().isEmpty
            ? s.t('أدخل الرمز المكوّن من 4 أرقام', 'Enter the 4-digit code')
            : s.t('رمز غير صحيح', 'That code is not right'));
        return;
      }
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final profile = UserProfile(
      id: _initial?.id,
      name: _name.text.trim(),
      phone: _fullPhone,
      email: _email.text.trim(),
      region: _region!,
      wilayat: _wilayat ?? '',
      address: _address.text.trim(),
      kind: _kind ?? AccountKind.customer,
      workshop: _isWorkshop ? _buildApplication() : null,
    );

    final notifier = ref.read(authProvider.notifier);
    if (_editing) {
      await notifier.updateProfile(profile);
      // A workshop account that edited its submission is re-applying, and §11
      // step 5 says that puts it back into the founder's pipeline. Doing it
      // here rather than silently leaving the old application in place is the
      // difference between "I fixed it and resubmitted" and "I fixed it and
      // nothing happened".
      if (_isWorkshop && profile.workshop != null) {
        await notifier.resubmitWorkshopApplication(profile.workshop!);
      }
    } else {
      await notifier.register(profile);
    }
    if (!mounted) return;

    // Keeps the region the app searches in aligned with the one on file.
    ref.read(regionProvider.notifier).state = profile.region;

    HapticFeedback.heavyImpact();

    // §11 step 4: a workshop gets a *receipt*, not a welcome. Nothing has been
    // approved — reusing the customer's "you can now transact" line here would
    // tell a workshop owner they are live when the founder has not looked at
    // their documents yet.
    if (_isWorkshop) {
      context.go('/workshop-application-received');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    // Reached from a gated action or the profile hub → back to it. Deep
    // linked with nothing to pop → the profile hub.
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/profile');
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(_editing
            ? s.t('تم حفظ بياناتك', 'Your details are saved')
            : s.t('تم توثيق الحساب — يمكنك الآن إجراء المعاملات',
                'Account verified — you can now transact')),
      ),
    );
  }

  /// The submission, in [ServiceProvider]'s own field names so approval copies
  /// it across without a mapping step (§8).
  WorkshopApplication _buildApplication() => WorkshopApplication(
        businessNameAr: _businessNameAr.text.trim(),
        businessNameEn: _businessNameEn.text.trim().isEmpty
            ? null
            : _businessNameEn.text.trim(),
        crNumber: _crNumber.text.trim(),
        vatNumber:
            _vatNumber.text.trim().isEmpty ? null : _vatNumber.text.trim(),
        // The first attachment is the certificate. More than one is allowed —
        // a two-page CR is ordinary — and the rest ride along on the same
        // record rather than being dropped.
        crDocumentUrl: _crDocs.first.uri,
        area: _area ?? '',
        fulfillments: {..._fulfillments},
        submittedAt: DateTime.now(),
      );

  Future<void> _pickCrDocument(ImageSource source) async {
    if (_pickingDoc) return;
    setState(() => _pickingDoc = true);
    final picked =
        await pickAttachments(_picker, source, startIndex: _crDocs.length);
    if (!mounted) return;
    setState(() {
      _crDocs.addAll(picked);
      _pickingDoc = false;
      if (_crDocs.isNotEmpty) _errors.remove('crDocument');
    });
  }

  Future<void> _pickArea() async {
    final s = S.of(context);
    final locations = ref.read(locationCatalogProvider);
    // Areas are the wilayats of the governorate the account is registered in —
    // a workshop operates where its owner registered it, and offering the whole
    // country here would let an application name an area in a governorate it
    // does not serve.
    final region = _region;
    final options = region == null
        ? <String>[]
        : locations.wilayatsOf(region);
    if (options.isEmpty) {
      setState(() => _errors['area'] =
          s.t('اختر المحافظة أولاً', 'Choose your governorate first'));
      return;
    }
    final picked = await _pickLocation(
      title: s.t('منطقة الورشة', "Workshop's area"),
      options: options,
      selected: _area,
    );
    if (picked == null) return;
    setState(() {
      _area = picked;
      _errors.remove('area');
    });
  }

  Future<void> _pickRegion() async {
    final s = S.of(context);
    final locations = ref.read(locationCatalogProvider);
    final picked = await _pickLocation(
      title: s.t('المحافظة', 'Governorate'),
      options: locations.governorates.keys.toList(),
      selected: _region,
    );
    if (picked == null || picked == _region) return;
    setState(() {
      _region = picked;
      // The wilayats belong to the governorate — keeping the old one would
      // file the user in a wilayat that is not in their region.
      _wilayat = null;
      _errors.remove('region');
    });
  }

  Future<void> _pickWilayat() async {
    final region = _region;
    if (region == null) return;
    final s = S.of(context);
    final locations = ref.read(locationCatalogProvider);
    final picked = await _pickLocation(
      title: s.isAr
          ? 'الولاية — ${locations.localized(region, true)}'
          : 'Wilayat — $region',
      options: locations.wilayatsOf(region),
      selected: _wilayat,
    );
    if (picked != null) setState(() => _wilayat = picked);
  }

  /// One sheet for both location pickers — same rows, same look, so the
  /// wilayat list behaves exactly like the governorate list above it.
  Future<String?> _pickLocation({
    required String title,
    required List<String> options,
    required String? selected,
  }) {
    final s = S.of(context);
    final locations = ref.read(locationCatalogProvider);
    final ak = AkColors.of(context);
    HapticFeedback.selectionClick();

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: ak.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    for (final option in options)
                      _RegionOption(
                        label: locations.localized(option, s.isAr),
                        selected: option == selected,
                        onTap: () => Navigator.pop(context, option),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final pending = _pendingChannel;

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        title: Text(_editing
            ? s.t('بياناتي', 'My details')
            : s.t('أكمل بياناتك', 'Complete your details')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _editing
                      ? _NoticeCard(
                          icon: LucideIcons.badgeCheck,
                          background: ak.successSoft,
                          foreground: ak.success,
                          message: s.t(
                              'حسابك موثّق. عدّل ما تشاء — لن نطلب رمزاً جديداً إلا إذا غيّرت رقم هاتفك أو بريدك.',
                              'Your account is verified. Change anything you like — a new code is only needed if you change your phone or email.'),
                        )
                      : _NoticeCard(
                          icon: LucideIcons.lock,
                          background: ak.amberBgSoft,
                          foreground: ak.amberText,
                          message: s.t(
                              'مطلوب مرة واحدة — قبل طلب الخدمات أو حجز الصيانة. التصفح يبقى مجانياً.',
                              'Required once — before requesting services or booking maintenance. Browsing stays free.'),
                        ),
                  const SizedBox(height: 18),
                  // ------------------------------------------- step zero (§9)
                  // Asked before anything else, and only once: what this
                  // account *is* changes which fields the form even has, so
                  // answering it after typing a name would mean re-laying out
                  // the page under the user's hands.
                  if (!_editing) ...[
                    _SectionLabel(s.t('نوع الحساب', 'Account type')),
                    Row(
                      children: [
                        for (final kind in AccountKind.values) ...[
                          if (kind != AccountKind.values.first)
                            const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: _AccountKindCard(
                              kind: kind,
                              selected: _kind == kind,
                              onTap: () => _pickKind(kind),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  _SectionLabel(s.t('بياناتك', 'Your details')),
                  _FieldRow(
                    icon: LucideIcons.user,
                    label: s.t('الاسم الكامل', 'Full name'),
                    hint: s.t('مثال: سالم الهنائي', 'e.g. Salim Al Hinai'),
                    controller: _name,
                    error: _errors['name'],
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => _clear('name'),
                  ),
                  _FieldRow(
                    icon: LucideIcons.phone,
                    label: s.t('رقم الهاتف', 'Phone number'),
                    hint: '9200 1234',
                    prefix: '+968 ',
                    controller: _phone,
                    error: _errors['phone'],
                    keyboardType: TextInputType.phone,
                    numeric: true,
                    // A phone number reads left-to-right in both languages —
                    // under RTL the row otherwise rendered as "98765432 968+".
                    forceLtr: true,
                    formatters: const [_OmanMobileFormatter()],
                    onChanged: (_) => _clear('phone'),
                  ),
                  _FieldRow(
                    icon: LucideIcons.mail,
                    label: s.t('البريد الإلكتروني', 'Email'),
                    hint: 'name@example.om',
                    controller: _email,
                    error: _errors['email'],
                    optional: _channel == OtpChannel.phone && !_editing,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _clear('email'),
                  ),
                  _PickerRow(
                    icon: LucideIcons.map,
                    label: s.t('المحافظة', 'Governorate'),
                    value: _region == null
                        ? null
                        : locations.localized(_region!, s.isAr),
                    hint: s.t('اختر من القائمة', 'Choose from the list'),
                    error: _errors['region'],
                    onTap: _pickRegion,
                  ),
                  _PickerRow(
                    icon: LucideIcons.mapPin,
                    label: s.t('الولاية', 'Wilayat'),
                    value: _wilayat == null
                        ? null
                        : locations.localized(_wilayat!, s.isAr),
                    hint: _region == null
                        ? s.t('اختر المحافظة أولاً', 'Choose a governorate first')
                        : s.t('اختر من القائمة', 'Choose from the list'),
                    enabled: _region != null,
                    optional: true,
                    onTap: _pickWilayat,
                  ),
                  _FieldRow(
                    icon: LucideIcons.house,
                    label: s.t('العنوان', 'Address'),
                    hint: s.t('المنطقة، الشارع', 'Area, street'),
                    controller: _address,
                    optional: true,
                    onChanged: (_) => _clear('address'),
                  ),
                  // -------------------------------- workshop details (§10)
                  // Between the personal fields and the OTP block, exactly
                  // where the spec puts them: the OTP is the last thing on the
                  // page in both flows, so a workshop applicant is not asked
                  // for a code and *then* for six more fields.
                  if (_isWorkshop) _workshopSection(context, s, ak, locations),
                  // The verification block disappears entirely once there is
                  // nothing left to prove, so an address edit is one tap.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: pending == null
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _SectionLabel(s.t('التوثيق عبر', 'Verify with')),
                              if (_editing)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _NoticeCard(
                                    icon: LucideIcons.shield,
                                    background: ak.amberBgSoft,
                                    foreground: ak.amberText,
                                    message: pending == OtpChannel.phone
                                        ? s.t(
                                            'غيّرت رقم هاتفك — أكّده برمز قبل الحفظ.',
                                            'You changed your phone number — confirm it with a code before saving.')
                                        : s.t(
                                            'غيّرت بريدك الإلكتروني — أكّده برمز قبل الحفظ.',
                                            'You changed your email — confirm it with a code before saving.'),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    _ChannelCard(
                                      selected: _channel == OtpChannel.phone,
                                      icon: LucideIcons.messageSquare,
                                      title:
                                          s.t('رمز عبر الهاتف', 'Phone OTP'),
                                      subtitle: s.t('رمز SMS', 'SMS code'),
                                      onTap: () => _switchChannel(
                                          OtpChannel.phone),
                                    ),
                                    const SizedBox(width: 10),
                                    _ChannelCard(
                                      selected: _channel == OtpChannel.email,
                                      icon: LucideIcons.mailCheck,
                                      title:
                                          s.t('رمز عبر البريد', 'Email OTP'),
                                      subtitle:
                                          s.t('رمز بالبريد', 'Code by email'),
                                      onTap: () => _switchChannel(
                                          OtpChannel.email),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              _OtpBlock(
                                sent: _otpSent,
                                controller: _otp,
                                target: _otpTarget,
                                error: _errors['otp'],
                                resendIn: _resendIn,
                                onSend: _sendOtp,
                                onChanged: (_) => _clear('otp'),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info,
                          size: 14, color: ak.inkFaint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.t('رقم الهاتف مطلوب دائماً — حتى عند التوثيق بالبريد الإلكتروني.',
                              'Phone number is always required — even when verifying by email.'),
                          style: TextStyle(
                              fontSize: 11.5, color: ak.inkFaint, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: ak.bg,
                border: Border(top: BorderSide(color: ak.divider)),
              ),
              child: FilledButton(
                // §9: disabled until step zero is answered. The form below it
                // is still readable and fillable — what is blocked is
                // submitting an account whose *kind* nobody has stated, which
                // would silently file every applicant as a customer.
                onPressed: _saving || (!_editing && _kind == null)
                    ? null
                    : _submit,
                child: _saving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: ak.onPrimary),
                      )
                    : Text(_submitLabel(s)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The workshop half of the form (§10).
  ///
  /// Deliberately part of this screen rather than a second registration
  /// screen: it is the same account, the same OTP and the same validation map
  /// — a parallel screen would be a parallel copy of all three (§14).
  Widget _workshopSection(
    BuildContext context,
    S s,
    AkColors ak,
    LocationCatalog locations,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _SectionLabel(s.t('معلومات الورشة', 'Workshop details')),
          _FieldRow(
            icon: LucideIcons.store,
            label: s.t('اسم السجل التجاري (عربي)', 'CR name (Arabic)'),
            hint: s.t('كما هو في السجل', 'Exactly as on the certificate'),
            controller: _businessNameAr,
            error: _errors['businessNameAr'],
            onChanged: (_) => _clear('businessNameAr'),
          ),
          _FieldRow(
            icon: LucideIcons.languages,
            label: s.t('اسم السجل التجاري (إنجليزي)', 'CR name (English)'),
            hint: s.t('يظهر للمستخدمين الناطقين بالإنجليزية',
                'Shown to English-speaking users'),
            controller: _businessNameEn,
            optional: true,
            onChanged: (_) => _clear('businessNameEn'),
          ),
          _FieldRow(
            icon: LucideIcons.fileText,
            label: s.t('رقم السجل التجاري', 'CR number'),
            hint: '1234567',
            controller: _crNumber,
            error: _errors['crNumber'],
            keyboardType: TextInputType.number,
            numeric: true,
            forceLtr: true,
            onChanged: (_) => _clear('crNumber'),
          ),
          _FieldRow(
            icon: LucideIcons.receipt,
            label: s.t('الرقم الضريبي', 'VAT number'),
            hint: s.t('اختياري — إن كانت ورشتك مسجّلة ضريبياً',
                'Optional — if VAT-registered'),
            controller: _vatNumber,
            optional: true,
            forceLtr: true,
            onChanged: (_) => _clear('vatNumber'),
          ),
          // ------------------------------------------- the certificate
          const SizedBox(height: AppSpacing.sm),
          Text(s.t('صورة السجل التجاري', 'Commercial registration document'),
              style: context.text.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.t('يفتحها المؤسس ويطابقها بالبيانات أعلاه قبل الاعتماد.',
                'The founder opens this and checks it against the details above before approving.'),
            style: context.text.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          // The same control the proof sheet uses — one uploader in the app.
          MediaStrip(
            s: s,
            media: _crDocs,
            busy: _pickingDoc,
            onRemove: (id) =>
                setState(() => _crDocs.removeWhere((m) => m.id == id)),
            onCamera: () => _pickCrDocument(ImageSource.camera),
            onGallery: () => _pickCrDocument(ImageSource.gallery),
          ),
          if (_errors['crDocument'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_errors['crDocument']!,
                style: context.text.bodySecondary.copyWith(color: ak.dangerText)),
          ],
          const SizedBox(height: AppSpacing.lg),
          _PickerRow(
            icon: LucideIcons.mapPin,
            label: s.t('منطقة الورشة', "Workshop's area"),
            value: _area == null ? null : locations.localized(_area!, s.isAr),
            hint: _region == null
                ? s.t('اختر المحافظة أولاً', 'Choose your governorate first')
                : s.t('اختر من القائمة', 'Choose from the list'),
            error: _errors['area'],
            enabled: _region != null,
            onTap: _pickArea,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(s.t('كيف تستقبل السيارات', 'How you take cars in'),
              style: context.text.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          // Multi-select, unlike the single choice a customer makes when
          // booking: a workshop that does counter work *and* collection is the
          // ordinary case.
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final f in Fulfillment.values)
                SelectChip(
                  label: f.label(s),
                  icon: f.icon,
                  selected: _fulfillments.contains(f),
                  onTap: () => setState(() {
                    if (!_fulfillments.remove(f)) _fulfillments.add(f);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _NoticeCard(
            icon: LucideIcons.shieldCheck,
            background: ak.amberBgSoft,
            foreground: ak.amberText,
            message: s.t(
              'لن نطلب أي بيانات بنكية هنا. تُرتَّب طريقة التحويل مع المؤسس بعد اعتماد ورشتك.',
              'No bank details are asked for here. Transfers are arranged with the founder after your workshop is approved.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      );

  void _pickKind(AccountKind kind) {
    if (_kind == kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      // Switching back to a customer account drops the workshop errors with
      // it: a customer must never be blocked by a field they cannot see.
      if (kind == AccountKind.customer) {
        _errors.removeWhere((key, _) => const {
              'businessNameAr',
              'crNumber',
              'crDocument',
              'area',
            }.contains(key));
      }
    });
  }

  String _submitLabel(S s) {
    if (_editing) {
      return _pendingChannel != null && !_otpSent
          ? s.t('إرسال الرمز', 'Send the code')
          : s.t('حفظ التعديلات', 'Save changes');
    }
    // A workshop is not "continuing" anywhere — it is submitting an
    // application that a person will read. The button says so.
    if (_isWorkshop) {
      return _pendingChannel != null && !_otpSent
          ? s.t('إرسال الرمز', 'Send the code')
          : s.t('إرسال طلب الورشة', 'Submit workshop application');
    }
    return s.t('توثيق ومتابعة', 'Verify and continue');
  }

  void _switchChannel(OtpChannel channel) {
    if (_channel == channel) return;
    HapticFeedback.selectionClick();
    setState(() {
      _channel = channel;
      // The code that was sent proves the *other* address, so it is void.
      _otpSent = false;
      _otp.clear();
      _errors.remove('otp');
    });
    _resendTimer?.cancel();
  }

  /// Drops a field's error as soon as the user starts fixing it.
  void _clear(String key) {
    if (!_errors.containsKey(key)) {
      // Editing the phone/email can change what still needs verifying, so
      // the verification block has to be rebuilt either way.
      setState(() {});
      return;
    }
    setState(() => _errors.remove(key));
  }
}

/// Group label above a run of fields.
/// One of the two account-type cards at step zero (§9).
///
/// Built to the shape of the theme picker in `settings_screen.dart` — the
/// selected card takes a heavier ink border and a filled check badge in the
/// trailing corner — because that is already this app's answer to "one of
/// these two", and inventing a second answer for the same question is how two
/// screens stop looking like one app.
class _AccountKindCard extends StatelessWidget {
  const _AccountKindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AccountKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: ak.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? ak.ink : ak.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kind.icon, size: 22, color: selected ? ak.ink : ak.inkSub),
                const SizedBox(height: AppSpacing.md),
                Text(kind.label(s), style: context.text.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  kind.description(s),
                  style: context.text.bodySecondary.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          if (selected)
            PositionedDirectional(
              top: 10,
              end: 10,
              child: Container(
                width: 20,
                height: 20,
                decoration:
                    BoxDecoration(color: ak.primary, shape: BoxShape.circle),
                child: Icon(LucideIcons.check, size: 12, color: ak.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: ak.inkFaint,
        ),
      ),
    );
  }
}

/// Tinted advisory card (gate notice, verified badge, re-verify warning).
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.message,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: foreground,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared shell for a labelled row: border turns ink once filled, red when
/// the row is reporting an error, with the message underneath.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.icon,
    required this.child,
    required this.filled,
    this.error,
    this.onTap,
  });

  final IconData icon;
  final Widget child;
  final bool filled;
  final String? error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final bad = error != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: bad
                      ? ak.danger
                      : filled
                          ? ak.primary
                          : ak.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: bad
                        ? ak.danger
                        : filled
                            ? ak.primary
                            : ak.inkFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          if (bad)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
              child: Text(
                error!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: ak.dangerText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Typed field with a floating label — matches the car form's rows.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.prefix,
    this.error,
    this.optional = false,
    this.numeric = false,
    this.forceLtr = false,
    this.formatters,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;

  /// Static leading text inside the field (the +968 dial code).
  final String? prefix;
  final String? error;
  final bool optional;
  final bool numeric;

  /// Renders the value row left-to-right whatever the app language is, for
  /// content that is never Arabic-ordered (dial code + digits).
  final bool forceLtr;

  /// Replaces the default digits-only filter when the field needs its own
  /// formatting rules.
  final List<TextInputFormatter>? formatters;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  Widget _maybeLtr(Widget child) => forceLtr
      ? Directionality(textDirection: TextDirection.ltr, child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filled = controller.text.trim().isNotEmpty;
    return _FieldShell(
      icon: icon,
      filled: filled,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ak.inkSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (optional && !filled) ...[
                const SizedBox(width: 6),
                Text(
                  s.t('اختياري', 'optional'),
                  style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
                ),
              ],
            ],
          ),
          _maybeLtr(
            Row(
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix!,
                    style: AppTheme.numeric(
                        size: 13.5, weight: FontWeight.w700, color: ak.inkSub),
                  ),
                  // Keeps the dial code visually attached to the number
                  // instead of drifting to the far edge of the row.
                  Container(
                    width: 1,
                    height: 15,
                    margin: const EdgeInsets.only(right: 8),
                    color: ak.divider,
                  ),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    textDirection: forceLtr ? TextDirection.ltr : null,
                    textAlign: forceLtr ? TextAlign.left : TextAlign.start,
                    inputFormatters: formatters ??
                        (numeric
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null),
                    style: numeric
                        ? AppTheme.numeric(size: 13.5, color: ak.ink)
                        : const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintText: hint,
                      hintTextDirection:
                          forceLtr ? TextDirection.ltr : null,
                      hintStyle: TextStyle(
                          fontSize: 13, color: ak.inkFaint,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the phone field holding exactly the 8 local Oman digits, shown as
/// "9200 1234".
///
/// Typing is only half of it — people paste. "+968 9200 1234", "00968…",
/// "096892001234" and "9200-1234" all reduce to the same eight digits here
/// rather than failing validation for a reason the user can't see.
class _OmanMobileFormatter extends TextInputFormatter {
  const _OmanMobileFormatter();

  static const _maxLocalDigits = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final all = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Digits dropped off the front, so the caret can be moved back by the
    // same amount instead of jumping.
    var dropped = 0;
    var local = all;
    if (local.startsWith('00968')) {
      local = local.substring(5);
      dropped = 5;
    } else if (local.startsWith('968')) {
      local = local.substring(3);
      dropped = 3;
    }
    while (local.startsWith('0')) {
      local = local.substring(1);
      dropped += 1;
    }
    if (local.length > _maxLocalDigits) {
      local = local.substring(0, _maxLocalDigits);
    }

    final text = local.length > 4
        ? '${local.substring(0, 4)} ${local.substring(4)}'
        : local;

    // A collapsed caret reports end == -1 before the field has focus.
    final caret = newValue.selection.end < 0
        ? newValue.text.length
        : math.min(newValue.selection.end, newValue.text.length);
    final typedBefore =
        newValue.text.substring(0, caret).replaceAll(RegExp(r'\D'), '').length;
    final keptBefore = math.max(0, math.min(typedBefore - dropped, local.length));
    final offset = keptBefore > 4 ? keptBefore + 1 : keptBefore;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Read-only row that opens a picker sheet (governorate).
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.error,
    this.enabled = true,
    this.optional = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final String? hint;
  final String? error;

  /// A row that cannot be opened yet (wilayat before a governorate). It stays
  /// visible and says why in its hint rather than vanishing.
  final bool enabled;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filled = value != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: _FieldShell(
        icon: icon,
        filled: filled,
        error: error,
        onTap: enabled ? onTap : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: ak.inkSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (optional && !filled) ...[
                        const SizedBox(width: 6),
                        Text(
                          s.t('اختياري', 'optional'),
                          style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    value ?? hint ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                      color: filled ? ak.ink : ak.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronDown, color: ak.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _RegionOption extends StatelessWidget {
  const _RegionOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? ak.primary : ak.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.mapPin,
                  size: 17, color: selected ? ak.primary : ak.inkFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              if (selected)
                Icon(LucideIcons.check, size: 18, color: ak.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two OTP delivery choices.
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? ak.primary : ak.border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? ak.primary : ak.inkFaint),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? ak.ink : ak.inkSub,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: ak.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Send the code" prompt before sending; the code field plus a resend
/// countdown after.
class _OtpBlock extends StatelessWidget {
  const _OtpBlock({
    required this.sent,
    required this.controller,
    required this.target,
    required this.resendIn,
    required this.onSend,
    required this.onChanged,
    this.error,
  });

  final bool sent;
  final TextEditingController controller;
  final String target;
  final int resendIn;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    if (!sent) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onSend,
          icon: const Icon(LucideIcons.sendHorizontal, size: 16),
          label: Text(s.t('إرسال الرمز', 'Send the code')),
        ),
      );
    }

    final bad = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('أدخل الرمز المُرسل إلى $target',
              'Enter the code sent to $target'),
          style: TextStyle(fontSize: 12, color: ak.inkSub),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bad ? ak.danger : ak.border,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTheme.numeric(
                size: 20, weight: FontWeight.w800, color: ak.ink)
                .copyWith(letterSpacing: 10),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: '• • • •',
              counterText: '',
            ),
          ),
        ),
        if (bad)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 11.5,
                color: ak.dangerText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: resendIn > 0 ? null : onSend,
            child: Text(
              resendIn > 0
                  ? s.t('إعادة الإرسال خلال $resendIn ثانية',
                      'Resend in ${resendIn}s')
                  : s.t('إعادة إرسال الرمز', 'Resend the code'),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

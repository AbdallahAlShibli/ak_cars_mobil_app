import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/oman_locations.dart';

enum OtpChannel { phone, email }

/// Rules 4–6: one-time registration gate before any transaction.
/// OTP via phone or email — phone number always required.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  OtpChannel _channel = OtpChannel.phone;
  bool _otpSent = false;
  bool _verifying = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _otp = TextEditingController();
  String _region = OmanLocations.governorates.keys.first;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _sendOtp() {
    HapticFeedback.mediumImpact();
    setState(() => _otpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_channel == OtpChannel.phone
            ? 'Code sent by SMS to ${_phone.text} — staging code: 7391'
            : 'Code sent to ${_email.text} — staging code: 7391'),
      ),
    );
  }

  Future<void> _verify() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _otp.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Enter your name, phone number, and the 4-digit code')),
      );
      return;
    }
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    ref.read(authProvider.notifier).register(UserProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          region: _region,
          address: _address.text.trim(),
        ));
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Account verified — you can now transact')),
    );
  }

  Widget _channelCard(OtpChannel channel, IconData icon, String title,
      String subtitle) {
    final selected = _channel == channel;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _channel = channel;
          _otpSent = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? AppColors.brand : AppColors.ink3),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.ink : AppColors.ink2,
                  )),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.ink3)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.amberText, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Required once — before requesting services, ordering parts, or posting a car ad. Browsing stays free.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C5205),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Verify with',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                _channelCard(OtpChannel.phone,
                    Icons.sms_outlined, 'Phone OTP', 'SMS code'),
                const SizedBox(width: 8),
                _channelCard(OtpChannel.email,
                    Icons.mark_email_read_outlined, 'Email OTP', 'Code by email'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+968 phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
                suffixIcon: _channel == OtpChannel.phone
                    ? TextButton(
                        onPressed: _sendOtp, child: const Text('Send OTP'))
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                suffixIcon: _channel == OtpChannel.email
                    ? TextButton(
                        onPressed: _sendOtp, child: const Text('Send OTP'))
                    : null,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _otpSent
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 8),
                        decoration: const InputDecoration(
                          hintText: '• • • •',
                          counterText: '',
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _region,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: [
                for (final r in OmanLocations.governorates.keys)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _region = v ?? _region),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                hintText: 'Address',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.ink3),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Phone number is always required — even when verifying by email.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Verify and continue'),
            ),
          ],
        ),
      ),
    );
  }
}

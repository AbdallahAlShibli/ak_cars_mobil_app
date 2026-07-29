import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'review_widgets.dart';

/// Writing a verified review (spec §8).
///
/// Reachable only for a booking that reached `releasedToWorkshop` — and the
/// repository refuses anything else even if a stale deep link gets here. There
/// is no "write a review" entry point anywhere else in the app, by design.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.requestId,
    this.direction = ReviewDirection.customerToWorkshop,
  });

  final String requestId;

  /// Which way round this review runs. The workshop panel opens the same
  /// screen with [ReviewDirection.workshopToCustomer].
  final ReviewDirection direction;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final request = ref
        .watch(requestsProvider)
        .firstWhereOrNull((r) => r.id == widget.requestId);

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('تقييم', 'Review'))),
        body: Center(child: Text(s.t('الطلب غير موجود', 'Request not found'))),
      );
    }

    final repository = ref.watch(reviewRepositoryProvider);
    final existing =
        ref.watch(reviewForBookingProvider((request.id, widget.direction)));
    // Prefill once, so a rebuild does not overwrite what the user is typing.
    if (existing != null && !_loaded) {
      _loaded = true;
      _rating = existing.rating;
      _comment.text = existing.comment ?? '';
    }

    final unlocked = repository.reviewable(request);
    final editable = existing == null ||
        existing.editableAt(DateTime.now(), repository.editWindow);
    final subject = switch (widget.direction) {
      ReviewDirection.customerToWorkshop =>
        request.offering.provider.name.of(s),
      ReviewDirection.workshopToCustomer =>
        s.t('عميل الطلب #${request.id}', 'Customer of #${request.id}'),
    };

    return Scaffold(
      appBar: AppBar(title: Text(s.t('قيّم التجربة', 'Rate the experience'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (!unlocked)
              AppCard(
                color: ak.amberSoft,
                child: Text(
                  s.t('لا يُفتح التقييم إلا بعد اكتمال الحجز وتحرير المبلغ. هذا ما يجعل التقييمات هنا موثّقة.',
                      'A review only unlocks once the booking completes and the payment is released. That is what makes reviews here verified.'),
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: ak.amberDeep),
                ),
              )
            else ...[
              Text(
                subject,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${request.offering.name.of(s)} · #${request.id}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: ak.inkSub),
              ),
              const SizedBox(height: 14),
              StarPicker(
                rating: _rating,
                onChanged: editable ? (v) => setState(() => _rating = v) : (_) {},
              ),
              const SizedBox(height: 4),
              Text(
                _ratingWord(s, _rating),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ak.inkSub),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _comment,
                enabled: editable,
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: switch (widget.direction) {
                    ReviewDirection.customerToWorkshop => s.t(
                        'ما الذي يفيد غيرك أن يعرفه؟ (اختياري)',
                        'What would help the next customer know? (optional)'),
                    ReviewDirection.workshopToCustomer => s.t(
                        'كيف كان التعامل مع العميل؟ (اختياري)',
                        'How was dealing with this customer? (optional)'),
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _rating > 0 && !_busy && editable
                    ? () => _submit(request, existing)
                    : null,
                child: Text(existing == null
                    ? s.t('أرسل التقييم', 'Submit review')
                    : s.t('حدّث التقييم', 'Update review')),
              ),
              const SizedBox(height: 10),
              Text(
                existing == null
                    ? s.t('تقييم واحد لكل حجز. يمكنك تعديله خلال ${s.t('٢٤ ساعة', '24 hours')}، ولا يمكن حذفه.',
                        'One review per booking. You can correct it within 24 hours; it cannot be deleted.')
                    : editable
                        ? s.t('ما زال بإمكانك تعديله.',
                            'You can still correct it.')
                        : s.t('انتهت مهلة التعديل — يبقى التقييم كما هو.',
                            'The edit window has closed — the review stands as written.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: ak.inkFaint, height: 1.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _ratingWord(S s, int rating) => switch (rating) {
        1 => s.t('سيئة', 'Poor'),
        2 => s.t('دون المتوقع', 'Below expectations'),
        3 => s.t('مقبولة', 'Okay'),
        4 => s.t('جيدة', 'Good'),
        5 => s.t('ممتازة', 'Excellent'),
        _ => s.t('اختر تقييمك', 'Pick a rating'),
      };

  Future<void> _submit(ServiceRequest request, Review? existing) async {
    final s = S.of(context);
    setState(() => _busy = true);
    final reviews = ref.read(reviewsProvider.notifier);
    final saved = existing == null
        ? await reviews.submit(
            request,
            direction: widget.direction,
            rating: _rating,
            comment: _comment.text,
          )
        : await reviews.edit(
            existing.id,
            rating: _rating,
            comment: _comment.text,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.t('تعذّر حفظ التقييم — قد يكون سُجّل بالفعل.',
                'Could not save the review — it may already be recorded.'))),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(s.t('شكراً — نُشر تقييمك.',
              'Thank you — your review is live.'))),
    );
    context.pop();
  }
}

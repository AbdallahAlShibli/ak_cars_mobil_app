import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../models/app_notification.dart';
import '../models/escrow.dart';
import '../models/gallery_listing.dart';
import '../models/order.dart';
import '../models/service_request.dart';
import '../services/notification_service.dart';

/// The in-app notification inbox.
///
/// The lifecycle copy lives here rather than in the notifiers that trigger it:
/// these messages are content, and content belongs to the data layer. When
/// the backend starts pushing them, the [notifyRequestStatus] /
/// [notifyOrderStatus] bodies are deleted and only [fetchNotifications]
/// remains.
abstract interface class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();

  Future<AppNotification> push({
    required L title,
    required L body,
    IconData icon,
    String? route,
  });

  Future<List<AppNotification>> markAllRead();

  /// Raises the notification an escrow transition would have pushed.
  /// Returns null for transitions the customer is not told about — the
  /// automatic proof hand-off, for one, is invisible by design.
  Future<AppNotification?> notifyEscrowState(
    ServiceRequest request,
    EscrowState state,
  );

  /// Warns the customer that the approval window is about to close and the
  /// escrow will release itself (spec §3, note 1).
  Future<AppNotification> notifyApprovalWindowClosing(
    ServiceRequest request,
    DateTime deadline,
  );

  /// Raises the notification a store's status change would have pushed.
  Future<AppNotification?> notifyOrderStatus(Order order, OrderStatus status);

  /// Raises the "order placed, funds held" notification after checkout.
  Future<AppNotification> notifyOrderPlaced(Order order);

  /// Raises the "escrow released" notification after the buyer confirms.
  Future<AppNotification> notifyEscrowReleased(Order order);

  /// Raises the "request sent" notification after booking.
  Future<AppNotification> notifyRequestPlaced(ServiceRequest request);

  /// Raises the "we've asked the workshop to price this" notification after a
  /// part-and-fit request is opened (spec §6).
  Future<AppNotification> notifyPartRequestSent(ServiceRequest request);

  /// Raises the "your quote is in" notification. Carries the itemised total,
  /// because the split between part and labour is the point of the quote.
  Future<AppNotification> notifyQuoteReceived(ServiceRequest request);

  /// Invites both sides to rate a completed booking (spec §8). Nothing is
  /// held back waiting for a reply — this is an invitation, not a gate.
  Future<AppNotification> notifyReviewUnlocked(ServiceRequest request);

  /// Raises the "your ad is live" notification after an ad is published.
  Future<AppNotification> notifyAdPublished(GalleryListing ad);
}

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._service);

  final NotificationService _service;

  @override
  Future<List<AppNotification>> fetchNotifications() =>
      _service.fetchNotifications();

  @override
  Future<AppNotification> push({
    required L title,
    required L body,
    IconData icon = LucideIcons.bell,
    String? route,
  }) =>
      _service.push(title: title, body: body, icon: icon, route: route);

  @override
  Future<List<AppNotification>> markAllRead() => _service.markAllRead();

  // The booking exists but nothing is held yet — the founder confirms that
  // separately (spec §3). Saying "held in escrow" here would be the app
  // claiming a transfer that has not happened.
  @override
  Future<AppNotification> notifyRequestPlaced(ServiceRequest request) => push(
        title: L('تم إرسال الطلب #${request.id}',
            'Request #${request.id} sent'),
        body: L(
            'المبلغ ${request.total.toStringAsFixed(2)} ر.ع بانتظار التأكيد، ثم يُعرض الطلب على ${request.offering.provider.name.ar}.',
            'OMR ${request.total.toStringAsFixed(2)} is awaiting confirmation, then the job goes to ${request.offering.provider.name.en}.'),
        icon: LucideIcons.sendHorizontal,
        route: '/track/${request.id}',
      );

  // No amount is named: there isn't one yet, and putting an estimate here
  // would pre-empt the quote the workshop has not written.
  @override
  Future<AppNotification> notifyPartRequestSent(ServiceRequest request) => push(
        title: L('أُرسل طلب القطعة #${request.id}',
            'Part request #${request.id} sent'),
        body: L(
            'وصل وصفك إلى ${request.offering.provider.name.ar}. تسعّر القطعة والتركيب كلاً على حدة، ثم تقرّر أنت.',
            'Your description reached ${request.offering.provider.name.en}. They price the part and the fitting separately, then it is your call.'),
        icon: LucideIcons.hammer,
        route: '/track/${request.id}',
      );

  @override
  Future<AppNotification> notifyQuoteReceived(ServiceRequest request) {
    final quote = request.quote;
    final provider = request.offering.provider.name;
    // Guarded rather than assumed: a notification that says "OMR 0.00" because
    // the quote went missing is worse than one that just says a quote arrived.
    if (quote == null) {
      return push(
        title: L('وصل عرض سعر للطلب #${request.id}',
            'A quote arrived for #${request.id}'),
        body: L('من ${provider.ar} — افتح الطلب لمراجعته.',
            'From ${provider.en} — open the request to review it.'),
        icon: LucideIcons.receiptText,
        route: '/track/${request.id}',
      );
    }
    final part = quote.partPrice.toStringAsFixed(2);
    final labor = quote.laborPrice.toStringAsFixed(2);
    return push(
      title: L('عرض سعر من ${provider.ar}', 'Quote from ${provider.en}'),
      body: L(
          'القطعة $part ر.ع + التركيب $labor ر.ع = ${quote.total.toStringAsFixed(2)} ر.ع. اقبل أو ارفض.',
          'Part OMR $part + fitting OMR $labor = OMR ${quote.total.toStringAsFixed(2)}. Accept or decline.'),
      icon: LucideIcons.receiptText,
      route: '/quote/${request.id}',
    );
  }

  @override
  Future<AppNotification> notifyReviewUnlocked(ServiceRequest request) => push(
        title: const L('كيف كانت التجربة؟', 'How was it?'),
        body: L(
            'قيّم ${request.offering.provider.name.ar} عن الطلب #${request.id}. تقييمك يظهر لأنه عن حجز مكتمل فعلاً.',
            'Rate ${request.offering.provider.name.en} for #${request.id}. Your review shows because it comes from a booking that actually completed.'),
        icon: LucideIcons.star,
        route: '/review/${request.id}',
      );

  @override
  Future<AppNotification> notifyAdPublished(GalleryListing ad) => push(
        title: const L('إعلانك الآن مباشر', 'Your ad is live'),
        body: L(
            '${ad.year} ${ad.make} ${ad.model} أصبح الآن في المعرض.',
            '${ad.year} ${ad.make} ${ad.model} is now in the gallery.'),
        icon: LucideIcons.megaphone,
        route: '/cars/listing/${ad.id}',
      );

  @override
  Future<AppNotification?> notifyEscrowState(
    ServiceRequest request,
    EscrowState state,
  ) {
    final provider = request.offering.provider.name;
    final amount = request.total.toStringAsFixed(2);
    return switch (state) {
      EscrowState.fundsHeld => push(
          title: L('تم حجز المبلغ للطلب #${request.id}',
              'Funds held for #${request.id}'),
          body: L(
              'تم تأكيد حجز $amount ر.ع كضمان — بانتظار قبول ${provider.ar}.',
              'OMR $amount is confirmed held in escrow — waiting for ${provider.en} to accept.'),
          icon: LucideIcons.lock,
          route: '/track/${request.id}',
        ),
      EscrowState.acceptedByWorkshop => push(
          title: L('تم قبول الطلب #${request.id}',
              'Request #${request.id} accepted'),
          body: L(
              'قبلت ${provider.ar} حجزك في ${request.slot}.',
              '${provider.en} accepted your booking for ${request.slot}.'),
          icon: LucideIcons.thumbsUp,
          route: '/track/${request.id}',
        ),
      EscrowState.inProgress => push(
          title: L('بدأ العمل على #${request.id}',
              'Work started on #${request.id}'),
          body: L(
              '${provider.ar} تعمل الآن على سيارتك ${request.car.label}.',
              '${provider.en} is working on your ${request.car.label}.'),
          icon: LucideIcons.wrench,
          route: '/track/${request.id}',
        ),
      EscrowState.awaitingApproval => push(
          title: L('اكتمل العمل — بانتظار مراجعتك',
              'Work completed — review needed'),
          body: L(
              'رفعت ${provider.ar} إثبات الإنجاز للطلب #${request.id}. وافق لتحرير $amount ر.ع.',
              '${provider.en} submitted proof of work for #${request.id}. Approve to release OMR $amount.'),
          icon: LucideIcons.clipboardList,
          route: '/approve/${request.id}',
        ),
      EscrowState.releasedToWorkshop => push(
          title: const L('تم تحرير الدفعة', 'Payment released'),
          body: L(
              'تم تحرير $amount ر.ع إلى ${provider.ar} عن الطلب #${request.id}.',
              'OMR $amount released to ${provider.en} for #${request.id}.'),
          icon: LucideIcons.lockOpen,
          route: '/payments',
        ),
      EscrowState.disputed => push(
          title: L('فُتح نزاع على الطلب #${request.id}',
              'Dispute opened on #${request.id}'),
          body: const L(
              'المبلغ ما زال محجوزاً. سنراجع الطرفين ونعود إليك.',
              'The funds stay held. We will review both sides and get back to you.'),
          icon: LucideIcons.scale,
          route: '/track/${request.id}',
        ),
      EscrowState.refunded => push(
          title: L('تمت إعادة المبلغ للطلب #${request.id}',
              'Refunded for #${request.id}'),
          body: L('أُعيد $amount ر.ع إليك.', 'OMR $amount has been returned to you.'),
          icon: LucideIcons.undo2,
          route: '/payments',
        ),
      // createdPendingPayment is the booking confirmation itself
      // (notifyRequestPlaced), proofSubmitted is a hand-off the customer never
      // sees, and a cancellation is something they just did themselves.
      _ => Future.value(null),
    };
  }

  @override
  Future<AppNotification> notifyApprovalWindowClosing(
    ServiceRequest request,
    DateTime deadline,
  ) {
    final hours = deadline.difference(DateTime.now()).inHours.clamp(1, 999);
    return push(
      title: L('راجع الطلب #${request.id} قبل التحرير التلقائي',
          'Review #${request.id} before it auto-releases'),
      body: L(
          'إن لم ترد خلال $hours ساعة، سيُحرَّر ${request.total.toStringAsFixed(2)} ر.ع تلقائياً إلى ${request.offering.provider.name.ar}.',
          'If you do not respond within $hours hours, OMR ${request.total.toStringAsFixed(2)} releases automatically to ${request.offering.provider.name.en}.'),
      icon: LucideIcons.hourglass,
      route: '/approve/${request.id}',
    );
  }

  @override
  Future<AppNotification?> notifyOrderStatus(Order order, OrderStatus status) =>
      switch (status) {
        OrderStatus.processing => push(
            title: L('طلبك ${order.id} قيد التجهيز',
                'Order ${order.id} is being prepared'),
            body: L(
                'المتجر يجهّز ${order.items.length} قطعة من طلبك.',
                'The store is packing your ${order.items.length} part(s).'),
            icon: LucideIcons.package,
            route: '/orders',
          ),
        OrderStatus.delivered => push(
            title: L('تم توصيل الطلب ${order.id}',
                'Order ${order.id} delivered'),
            body: L(
                'أكد الاستلام لتحرير ${order.total.toStringAsFixed(2)} ر.ع للمتجر.',
                'Confirm receipt to release OMR ${order.total.toStringAsFixed(2)} to the store.'),
            icon: LucideIcons.truckElectric,
            route: '/orders',
          ),
        _ => Future.value(null),
      };

  @override
  Future<AppNotification> notifyOrderPlaced(Order order) => push(
        title: L('تم إنشاء الطلب ${order.id}', 'Order ${order.id} placed'),
        body: L(
            'تم احتجاز ${order.total.toStringAsFixed(2)} ر.ع — تُحرّر عند تأكيد الاستلام.',
            'OMR ${order.total.toStringAsFixed(2)} held — released when you confirm receipt.'),
        icon: LucideIcons.package,
        route: '/orders',
      );

  @override
  Future<AppNotification> notifyEscrowReleased(Order order) => push(
        title: L('تم تحرير الدفعة للطلب ${order.id}',
            'Payment released for order ${order.id}'),
        body: L(
            'تم تحرير ${order.total.toStringAsFixed(2)} ر.ع للمتجر — شكراً لتأكيدك.',
            'OMR ${order.total.toStringAsFixed(2)} released to the store — thanks for confirming.'),
        icon: LucideIcons.lockOpen,
        route: '/payments',
      );
}

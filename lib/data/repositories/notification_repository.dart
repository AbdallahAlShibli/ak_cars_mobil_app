import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../models/app_notification.dart';
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

  /// Raises the notification a provider's status change would have pushed.
  /// Returns null for transitions the customer is not told about.
  Future<AppNotification?> notifyRequestStatus(
    ServiceRequest request,
    RequestStatus status,
  );

  /// Raises the notification a store's status change would have pushed.
  Future<AppNotification?> notifyOrderStatus(Order order, OrderStatus status);

  /// Raises the "order placed, funds held" notification after checkout.
  Future<AppNotification> notifyOrderPlaced(Order order);

  /// Raises the "escrow released" notification after the buyer confirms.
  Future<AppNotification> notifyEscrowReleased(Order order);

  /// Raises the "request sent, funds held" notification after booking.
  Future<AppNotification> notifyRequestPlaced(ServiceRequest request);

  /// Raises the "escrow released to the workshop" notification after the
  /// customer approves the completion proof.
  Future<AppNotification> notifyRequestApproved(ServiceRequest request);

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
    IconData icon = Icons.notifications_outlined,
    String? route,
  }) =>
      _service.push(title: title, body: body, icon: icon, route: route);

  @override
  Future<List<AppNotification>> markAllRead() => _service.markAllRead();

  @override
  Future<AppNotification> notifyRequestPlaced(ServiceRequest request) => push(
        title: L('تم إرسال الطلب #${request.id}',
            'Request #${request.id} sent'),
        body: L(
            'تم حجز ${request.total.toStringAsFixed(2)} ر.ع كضمان — بانتظار قبول ${request.offering.provider.name.ar}.',
            'OMR ${request.total.toStringAsFixed(2)} held in escrow — waiting for ${request.offering.provider.name.en} to accept.'),
        icon: Icons.schedule_send_outlined,
        route: '/track/${request.id}',
      );

  @override
  Future<AppNotification> notifyRequestApproved(ServiceRequest request) {
    final provider = request.offering.provider.name;
    return push(
      title: const L('تم تحرير الدفعة', 'Payment released'),
      body: L(
          'تم تحرير ${request.total.toStringAsFixed(2)} ر.ع إلى ${provider.ar} عن الطلب #${request.id}.',
          'OMR ${request.total.toStringAsFixed(2)} released to ${provider.en} for #${request.id}.'),
      icon: Icons.lock_open_rounded,
      route: '/payments',
    );
  }

  @override
  Future<AppNotification> notifyAdPublished(GalleryListing ad) => push(
        title: const L('إعلانك الآن مباشر', 'Your ad is live'),
        body: L(
            '${ad.year} ${ad.make} ${ad.model} أصبح الآن في المعرض.',
            '${ad.year} ${ad.make} ${ad.model} is now in the gallery.'),
        icon: Icons.campaign_outlined,
        route: '/cars/listing/${ad.id}',
      );

  @override
  Future<AppNotification?> notifyRequestStatus(
    ServiceRequest request,
    RequestStatus status,
  ) {
    final provider = request.offering.provider.name;
    return switch (status) {
      RequestStatus.accepted => push(
          title: L('تم قبول الطلب #${request.id}',
              'Request #${request.id} accepted'),
          body: L(
              'قبلت ${provider.ar} حجزك في ${request.slot}.',
              '${provider.en} accepted your booking for ${request.slot}.'),
          icon: Icons.thumb_up_alt_outlined,
          route: '/track/${request.id}',
        ),
      RequestStatus.inProgress => push(
          title: L('بدأ العمل على #${request.id}',
              'Work started on #${request.id}'),
          body: L(
              '${provider.ar} تعمل الآن على سيارتك ${request.car.label}.',
              '${provider.en} is working on your ${request.car.label}.'),
          icon: Icons.build_rounded,
          route: '/track/${request.id}',
        ),
      RequestStatus.proofSubmitted => push(
          title: L('اكتمل العمل — بانتظار مراجعتك',
              'Work completed — review needed'),
          body: L(
              'رفعت ${provider.ar} صور الإثبات للطلب #${request.id}. وافق لتحرير ${request.total.toStringAsFixed(2)} ر.ع.',
              '${provider.en} uploaded proof photos for #${request.id}. Approve to release OMR ${request.total.toStringAsFixed(2)}.'),
          icon: Icons.fact_check_outlined,
          route: '/approve/${request.id}',
        ),
      _ => Future.value(null),
    };
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
            icon: Icons.inventory_2_outlined,
            route: '/orders',
          ),
        OrderStatus.delivered => push(
            title: L('تم توصيل الطلب ${order.id}',
                'Order ${order.id} delivered'),
            body: L(
                'أكد الاستلام لتحرير ${order.total.toStringAsFixed(2)} ر.ع للمتجر.',
                'Confirm receipt to release OMR ${order.total.toStringAsFixed(2)} to the store.'),
            icon: Icons.local_shipping_outlined,
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
        icon: Icons.inventory_2_outlined,
        route: '/orders',
      );

  @override
  Future<AppNotification> notifyEscrowReleased(Order order) => push(
        title: L('تم تحرير الدفعة للطلب ${order.id}',
            'Payment released for order ${order.id}'),
        body: L(
            'تم تحرير ${order.total.toStringAsFixed(2)} ر.ع للمتجر — شكراً لتأكيدك.',
            'OMR ${order.total.toStringAsFixed(2)} released to the store — thanks for confirming.'),
        icon: Icons.lock_open_rounded,
        route: '/payments',
      );
}

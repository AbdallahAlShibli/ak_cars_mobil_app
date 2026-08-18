import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// A role on a workshop's own roster. Only [owner]/[manager] may mutate
/// staff, inventory, offerings or the profile — see
/// `WorkshopStaffX.canManage` and the server's identical
/// `WorkshopStaff.CanManage`.
enum WorkshopStaffRole { owner, manager, technician, receptionist }

extension WorkshopStaffRoleX on WorkshopStaffRole {
  String get key => name;

  String label(S s) => switch (this) {
    WorkshopStaffRole.owner => s.t('مالك', 'Owner'),
    WorkshopStaffRole.manager => s.t('مدير', 'Manager'),
    WorkshopStaffRole.technician => s.t('فني', 'Technician'),
    WorkshopStaffRole.receptionist => s.t('استقبال', 'Receptionist'),
  };

  IconData get icon => switch (this) {
    WorkshopStaffRole.owner => LucideIcons.crown,
    WorkshopStaffRole.manager => LucideIcons.shieldCheck,
    WorkshopStaffRole.technician => LucideIcons.wrench,
    WorkshopStaffRole.receptionist => LucideIcons.headset,
  };

  /// Mirrors the server's authorization gate — used client-side only to hide
  /// controls this account cannot use. The server re-checks independently on
  /// every write; this is a UX affordance, not the source of truth.
  bool get canManage =>
      this == WorkshopStaffRole.owner || this == WorkshopStaffRole.manager;

  static WorkshopStaffRole fromKey(String? key) {
    for (final value in WorkshopStaffRole.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return WorkshopStaffRole.technician;
  }
}

/// One person on a workshop's own roster.
class WorkshopStaff {
  const WorkshopStaff({
    required this.id,
    required this.name,
    this.phone,
    required this.role,
    this.specialties = const [],
    this.isActive = true,
    required this.joinedAt,
    this.userId,
    this.openJobCount = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final WorkshopStaffRole role;
  final List<String> specialties;

  /// Deactivated, never hard-deleted — a completed job can still point at
  /// this row.
  final bool isActive;
  final DateTime joinedAt;

  /// A roster row may or may not map to an app account.
  final String? userId;

  /// Non-terminal bookings currently assigned to this person.
  final int openJobCount;

  factory WorkshopStaff.fromJson(JsonMap json) => WorkshopStaff(
    id: json.requireString('id'),
    name: json.stringOr('name', ''),
    phone: json.stringOrNull('phone'),
    role: WorkshopStaffRoleX.fromKey(json.stringOrNull('role')),
    specialties: json.stringList('specialties'),
    isActive: json.boolOr('isActive', true),
    joinedAt: json.dateTimeOr('joinedAt', DateTime.now()),
    userId: json.stringOrNull('userId'),
    openJobCount: json.intOr('openJobCount', 0),
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role.key,
    'specialties': specialties,
    'isActive': isActive,
    'joinedAt': joinedAt.toIso8601String(),
    'userId': userId,
    'openJobCount': openJobCount,
  };

  WorkshopStaff copyWith({
    String? id,
    String? name,
    String? phone,
    WorkshopStaffRole? role,
    List<String>? specialties,
    bool? isActive,
    DateTime? joinedAt,
    String? userId,
    int? openJobCount,
  }) => WorkshopStaff(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    specialties: specialties ?? this.specialties,
    isActive: isActive ?? this.isActive,
    joinedAt: joinedAt ?? this.joinedAt,
    userId: userId ?? this.userId,
    openJobCount: openJobCount ?? this.openJobCount,
  );

  @override
  bool operator ==(Object other) =>
      other is WorkshopStaff &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.role == role &&
      other.specialties.length == specialties.length &&
      other.specialties.every(specialties.contains) &&
      other.isActive == isActive &&
      other.joinedAt == joinedAt &&
      other.userId == userId &&
      other.openJobCount == openJobCount;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    role,
    Object.hashAllUnordered(specialties),
    isActive,
    joinedAt,
    userId,
    openJobCount,
  );
}

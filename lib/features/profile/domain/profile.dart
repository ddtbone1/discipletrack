import 'package:flutter/foundation.dart';

/// A row of `public.profiles`.
///
/// `id` is the Supabase auth user id. The row is created by the
/// `handle_new_user` trigger, never by this client.
///
/// Only `fullName`, `phone` and `avatarUrl` are editable. Migration 003 grants
/// UPDATE on exactly those three columns, so attempting to change anything
/// else is rejected by the database, not merely by this model.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.avatarUrl,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The columns a client is permitted to write. Mirrors the column grant in
  /// Migration 003.
  static const editableColumns = {'full_name', 'phone', 'avatar_url'};

  static List<String> _nameParts(String name) =>
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  /// First name, for greetings. Falls back to the whole name.
  String get firstName {
    final parts = _nameParts(fullName);
    return parts.isEmpty ? fullName : parts.first;
  }

  /// Up to two uppercase initials, for an avatar placeholder.
  String get initials {
    final parts = _nameParts(fullName);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Profile copyWith({String? fullName, String? phone, String? avatarUrl}) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile &&
          other.id == id &&
          other.fullName == fullName &&
          other.phone == phone &&
          other.avatarUrl == avatarUrl &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, fullName, phone, avatarUrl, updatedAt);

  @override
  String toString() => 'Profile($id, $fullName)';
}

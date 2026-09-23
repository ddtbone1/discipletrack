import 'package:discipletrack/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({
  String fullName = 'Juan dela Cruz',
  String? phone,
  String? avatarUrl,
}) => {
  'id': '11111111-1111-1111-1111-111111111111',
  'full_name': fullName,
  'phone': phone,
  'avatar_url': avatarUrl,
  'created_at': '2026-09-01T08:30:00.000Z',
  'updated_at': '2026-09-20T10:15:00.000Z',
};

void main() {
  group('Profile.fromMap', () {
    test('maps every column', () {
      final p = Profile.fromMap(
        row(phone: '+63 900 000 0000', avatarUrl: 'https://example.test/a.png'),
      );

      expect(p.id, '11111111-1111-1111-1111-111111111111');
      expect(p.fullName, 'Juan dela Cruz');
      expect(p.phone, '+63 900 000 0000');
      expect(p.avatarUrl, 'https://example.test/a.png');
      expect(p.createdAt, DateTime.utc(2026, 9, 1, 8, 30));
      expect(p.updatedAt, DateTime.utc(2026, 9, 20, 10, 15));
    });

    test('accepts null phone and avatar_url', () {
      final p = Profile.fromMap(row());
      expect(p.phone, isNull);
      expect(p.avatarUrl, isNull);
    });
  });

  group('derived name values', () {
    test('firstName takes the first word', () {
      expect(
        Profile.fromMap(row(fullName: 'Juan dela Cruz')).firstName,
        'Juan',
      );
    });

    test('firstName handles a single-word name', () {
      expect(Profile.fromMap(row(fullName: 'Madonna')).firstName, 'Madonna');
    });

    test('firstName tolerates extra whitespace', () {
      expect(
        Profile.fromMap(row(fullName: '  Juan   dela Cruz  ')).firstName,
        'Juan',
      );
    });

    test('initials combine first and last', () {
      expect(Profile.fromMap(row(fullName: 'Juan dela Cruz')).initials, 'JC');
    });

    test('initials of a single-word name is one letter', () {
      expect(Profile.fromMap(row(fullName: 'Madonna')).initials, 'M');
    });
  });

  group('copyWith', () {
    test('changes only what is given', () {
      final original = Profile.fromMap(row(phone: '+63 900'));
      final updated = original.copyWith(fullName: 'New Name');

      expect(updated.fullName, 'New Name');
      expect(updated.phone, '+63 900');
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
    });
  });

  test('editableColumns matches the Migration 003 column grant', () {
    expect(Profile.editableColumns, {'full_name', 'phone', 'avatar_url'});
  });
}

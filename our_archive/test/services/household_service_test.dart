import 'package:flutter_test/flutter_test.dart';
import 'package:our_archive/data/services/household_service.dart';

void main() {
  group('HouseholdService', () {
    late HouseholdService service;

    setUp(() {
      service = HouseholdService();
    });

    test('generateHouseholdCode creates valid 6-char code', () {
      final code = service.generateHouseholdCode();

      expect(code.length, equals(6));
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(code), isTrue);
    });

    test('generateHouseholdCode includes valid checksum', () {
      final code = service.generateHouseholdCode();

      // Verify checksum
      const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
      int sum = 0;
      for (int i = 0; i < 5; i++) {
        sum += chars.indexOf(code[i]) * (i + 1);
      }
      final expectedChecksum = chars[sum % chars.length];

      expect(code[5], equals(expectedChecksum));
    });

    test('generateHouseholdCode creates unique codes', () {
      final codes = <String>{};
      for (int i = 0; i < 100; i++) {
        codes.add(service.generateHouseholdCode());
      }

      // All codes should be unique
      expect(codes.length, equals(100));
    });
  });
}

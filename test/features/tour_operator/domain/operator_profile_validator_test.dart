import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';

Uint8List _validPngBytes() =>
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13]);

Uint8List _validJpegBytes() => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

Uint8List _validWebpBytes() => Uint8List.fromList([
  0x52,
  0x49,
  0x46,
  0x46,
  0x00,
  0x00,
  0x00,
  0x00,
  0x57,
  0x45,
  0x42,
  0x50,
]);

void main() {
  group('OperatorProfileValidator (UC-34)', () {
    const validInput = UpdateOperatorProfileInput(
      businessName: 'Sun Tours',
      businessDescription: 'Family tours',
      businessAddress: '1 Beach Rd',
      contactPhone: '0901234567',
      contactEmail: 'hello@suntours.vn',
      website: 'https://suntours.vn',
    );

    test('accepts valid payload and blank optional fields', () {
      expect(OperatorProfileValidator.validate(validInput).isEmpty, isTrue);

      const clearedOptional = UpdateOperatorProfileInput(
        businessName: '  Sun Tours  ',
        businessDescription: '   ',
        businessAddress: '',
        contactPhone: '   ',
        contactEmail: '',
        website: '  ',
      );
      expect(
        OperatorProfileValidator.validate(clearedOptional).isEmpty,
        isTrue,
      );
    });

    test('requires businessName (MSG01) and enforces max 200 chars', () {
      final emptyErr = OperatorProfileValidator.validate(
        const UpdateOperatorProfileInput(
          businessName: '   ',
          businessDescription: '',
          businessAddress: '',
          contactPhone: '',
          contactEmail: '',
          website: '',
        ),
      );
      expect(emptyErr.businessName, contains('MSG01'));

      final longErr = OperatorProfileValidator.validate(
        UpdateOperatorProfileInput(
          businessName: 'A' * 201,
          businessDescription: '',
          businessAddress: '',
          contactPhone: '',
          contactEmail: '',
          website: '',
        ),
      );
      expect(longErr.businessName, isNotNull);
    });

    test(
      'validates phone ^0\\d{9}\$ (MSG04), email (MSG02), and website http/https',
      () {
        final errors = OperatorProfileValidator.validate(
          const UpdateOperatorProfileInput(
            businessName: 'Sun Tours',
            businessDescription: '',
            businessAddress: '',
            contactPhone: '0236 388 1234',
            contactEmail: 'invalid-email',
            website: 'suntours.vn',
          ),
        );
        expect(errors.contactPhone, contains('MSG04'));
        expect(errors.contactEmail, contains('MSG02'));
        expect(errors.website, contains('http://'));
        expect(errors.website, contains('https://'));
      },
    );

    test(
      'validates logo MIME, magic signature, and 1 byte..5 MB limit (MSG19)',
      () {
        expect(
          OperatorProfileValidator.isValidLogo(
            OperatorLogoUploadData(
              bytes: _validPngBytes(),
              fileName: 'logo.png',
              mimeType: 'image/png',
            ),
          ),
          isTrue,
        );
        expect(
          OperatorProfileValidator.isValidLogo(
            OperatorLogoUploadData(
              bytes: _validJpegBytes(),
              fileName: 'logo.jpg',
              mimeType: 'image/jpeg',
            ),
          ),
          isTrue,
        );
        expect(
          OperatorProfileValidator.isValidLogo(
            OperatorLogoUploadData(
              bytes: _validWebpBytes(),
              fileName: 'logo.webp',
              mimeType: 'image/webp',
            ),
          ),
          isTrue,
        );

        // Mismatched signature
        final spoofed = OperatorLogoUploadData(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          fileName: 'fake.png',
          mimeType: 'image/png',
        );
        final err = OperatorProfileValidator.validate(
          UpdateOperatorProfileInput(
            businessName: 'Sun Tours',
            businessDescription: '',
            businessAddress: '',
            contactPhone: '',
            contactEmail: '',
            website: '',
            logo: spoofed,
          ),
        );
        expect(err.logo, contains('MSG19'));

        // Oversized (> 5 MB)
        final oversized = Uint8List(OperatorProfileValidator.maxLogoBytes + 1);
        oversized.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(
          OperatorProfileValidator.isValidLogo(
            OperatorLogoUploadData(
              bytes: oversized,
              fileName: 'big.png',
              mimeType: 'image/png',
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'normalized() trims text fields and enforces mutual exclusion of logo vs removeLogo',
      () {
        final logo = OperatorLogoUploadData(
          bytes: _validPngBytes(),
          fileName: 'logo.png',
          mimeType: 'image/png',
        );
        final normalized = UpdateOperatorProfileInput(
          businessName: '  Sun Tours  ',
          businessDescription: '  Desc  ',
          businessAddress: '  Addr  ',
          contactPhone: ' 0901234567 ',
          contactEmail: ' a@b.vn ',
          website: ' https://a.vn ',
          logo: logo,
          removeLogo: true,
        ).normalized();

        expect(normalized.businessName, 'Sun Tours');
        expect(normalized.contactPhone, '0901234567');
        expect(normalized.logo, logo);
        expect(normalized.removeLogo, isFalse);
      },
    );
  });
}

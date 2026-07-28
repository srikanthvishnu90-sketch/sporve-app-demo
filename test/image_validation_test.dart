// Verifies upload validation rejects non-image files and oversize images, and
// accepts normal images — the pure guard behind every coach photo upload.
//   flutter test test/image_validation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/utils/image_validation.dart';

void main() {
  test('rejects a non-image file (renamed .exe)', () {
    final err = validateImageFile(name: 'malware.exe', bytes: 1024);
    expect(err, isNotNull);
    expect(err, contains('image file'));
  });

  test('rejects an oversize image', () {
    final err = validateImageFile(name: 'huge.png', bytes: kMaxImageBytes + 1);
    expect(err, isNotNull);
    expect(err, contains('too large'));
  });

  test('accepts a normal jpg', () {
    expect(validateImageFile(name: 'photo.jpg', bytes: 500 * 1024), isNull);
  });

  test('accepts unknown extension when MIME says image', () {
    // Some platforms hand back a name without a usable extension.
    expect(
      validateImageFile(name: 'IMG_0001', bytes: 1024, mimeType: 'image/jpeg'),
      isNull,
    );
  });

  test('size limit applies even to a valid image type', () {
    expect(
      validateImageFile(name: 'big.webp', bytes: kMaxImageBytes + 1),
      contains('too large'),
    );
  });
}

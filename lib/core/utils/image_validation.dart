import 'package:image_picker/image_picker.dart';

/// Outcome of a validated image pick: a usable [path], a user-facing [error], or
/// neither (the user cancelled).
class ImagePickResult {
  final String? path;
  final String? error;
  const ImagePickResult({this.path, this.error});

  bool get hasError => error != null;
  bool get hasImage => path != null;
}

/// Max accepted upload size + allowed image types. Keeps storage cost bounded and
/// blocks non-image files (e.g. a renamed .zip/.exe) that the picker might let
/// through on some platforms.
const int kMaxImageBytes = 8 * 1024 * 1024; // 8 MB
const Set<String> _allowedExt = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'heic',
  'heif',
  'gif',
};

/// PURE validation — returns a user-facing error string, or null when the file
/// passes. Extracted so it is unit-testable without a platform image picker.
/// An unknown/empty extension is allowed only when the MIME type says image/*.
String? validateImageFile({
  required String name,
  required int bytes,
  String? mimeType,
  int maxBytes = kMaxImageBytes,
}) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  final mime = mimeType ?? '';
  final looksImage = mime.startsWith('image/') || _allowedExt.contains(ext);
  if (!looksImage) {
    return 'Please choose an image file (JPG, PNG, WEBP, or HEIC).';
  }
  if (bytes > maxBytes) {
    final mb = (maxBytes / (1024 * 1024)).round();
    return 'That image is too large. Please pick one under ${mb}MB.';
  }
  return null;
}

/// Picks an image and VALIDATES size + type before returning it. The picker is
/// asked to downscale (maxWidth/quality) to keep most uploads small; the length
/// check is the hard guard. Cancelling returns an empty result (no error).
Future<ImagePickResult> pickValidatedImage(
  ImagePicker picker, {
  ImageSource source = ImageSource.gallery,
  int maxBytes = kMaxImageBytes,
}) async {
  final XFile? x = await picker.pickImage(
    source: source,
    maxWidth: 2000,
    imageQuality: 85,
  );
  if (x == null) return const ImagePickResult(); // cancelled

  final error = validateImageFile(
    name: x.name,
    bytes: await x.length(),
    mimeType: x.mimeType,
    maxBytes: maxBytes,
  );
  if (error != null) {
    return ImagePickResult(error: error);
  }
  return ImagePickResult(path: x.path);
}

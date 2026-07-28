import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Holds the AI onboarding-intake inputs, calls the `provider-onboard-draft`
/// Edge Function, and exposes the returned DRAFT for the review screen to
/// pre-fill. Provider/ChangeNotifier only (no reactive GetX). Nothing here is
/// saved or published — that happens only on the review screen's explicit Save.
class OnboardDraftProvider extends ChangeNotifier {
  // ── Intake inputs (all optional) ──────────────────────────────────────────
  String pastedBio = '';
  String transcript = '';
  String? imageBase64;
  String? imageMediaType;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Map<String, dynamic>? _draft;
  Map<String, dynamic>? get draft => _draft;

  void setBio(String v) => pastedBio = v;
  void setTranscript(String v) => transcript = v;

  void setImage(String? base64, String? mediaType) {
    imageBase64 = base64;
    imageMediaType = mediaType;
    notifyListeners();
  }

  void clearImage() {
    imageBase64 = null;
    imageMediaType = null;
    notifyListeners();
  }

  bool get hasAnyInput =>
      pastedBio.trim().isNotEmpty ||
      transcript.trim().isNotEmpty ||
      (imageBase64 != null && imageBase64!.isNotEmpty);

  /// Calls the server-side draft function and stores the returned draft.
  /// Returns true when a draft is ready. Never writes to the profile.
  Future<bool> generate() async {
    if (!hasAnyInput) {
      _error = 'Add a bio, a photo, or a voice note first.';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    _draft = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{};
      if (pastedBio.trim().isNotEmpty) body['pastedBio'] = pastedBio.trim();
      if (transcript.trim().isNotEmpty) body['voiceTranscript'] = transcript.trim();
      if (imageBase64 != null && imageBase64!.isNotEmpty) {
        body['imageBase64'] = imageBase64;
        if (imageMediaType != null) body['imageMediaType'] = imageMediaType;
      }
      // Slug must match the deployed function name (lowercase, hyphen).
      final res = await Supabase.instance.client.functions.invoke(
        'provider-onboard-draft',
        body: body,
      );
      final data = (res.data as Map?) ?? {};
      if (data['error'] != null) {
        _error = data['error'].toString();
        return false;
      }
      final d = data['draft'];
      if (d is Map) {
        _draft = Map<String, dynamic>.from(d);
        return _draft!.isNotEmpty;
      }
      _error = 'The draft service returned no draft. Please try again.';
      return false;
    } on FunctionException catch (e) {
      debugPrint('provider-onboard-draft -> ${e.status} ${e.details}');
      _error = 'Could not generate a draft (status ${e.status}). You can fill it in manually.';
      return false;
    } catch (e) {
      debugPrint('provider-onboard-draft -> $e');
      _error = 'Could not generate a draft. You can fill it in manually.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    pastedBio = '';
    transcript = '';
    imageBase64 = null;
    imageMediaType = null;
    _draft = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}

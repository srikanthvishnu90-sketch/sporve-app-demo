import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Coach OS — POLICY FIELDS (AI Front Office #3). The coach fills in the facts
/// the AI reply robot (doc #5) is allowed to cite: cancellation policy, what to
/// bring, travel radius, standing session notes, and a small FAQ. This bundle is
/// the ONLY source of truth the draft-reply function may quote — so it round-
/// trips verbatim (coach types "24-hour cancellation" → the robot uses those
/// exact words). Thin over [ProfileRepository]; RLS scopes every read/write to
/// the owning coach's own provider row. No money moves here.
class CoachPoliciesController extends ChangeNotifier {
  CoachPoliciesController(this._repo);
  final AppRepository _repo;

  String cancellationPolicy = '';
  String whatToBring = '';
  String travelRadius = '';
  String sessionNotes = '';

  /// Each entry is {'question': String, 'answer': String}.
  final List<Map<String, String>> faq = [];

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;
  bool _saving = false;
  bool get saving => _saving;

  Future<void> load() async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      final p = await _repo.getCoachPolicies();
      cancellationPolicy = (p['cancellationPolicy'] ?? '').toString();
      whatToBring = (p['whatToBring'] ?? '').toString();
      travelRadius = (p['travelRadius'] ?? '').toString();
      sessionNotes = (p['sessionNotes'] ?? '').toString();
      faq
        ..clear()
        ..addAll(_readFaq(p['faq']));
    } catch (e) {
      debugPrint('CoachPoliciesController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<Map<String, String>> _readFaq(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add({
          'question': (e['question'] ?? '').toString(),
          'answer': (e['answer'] ?? '').toString(),
        });
      }
    }
    return out;
  }

  void addFaqRow() {
    faq.add({'question': '', 'answer': ''});
    notifyListeners();
  }

  void removeFaqRow(int index) {
    if (index >= 0 && index < faq.length) {
      faq.removeAt(index);
      notifyListeners();
    }
  }

  void setFaqQuestion(int index, String value) {
    if (index >= 0 && index < faq.length) faq[index]['question'] = value;
  }

  void setFaqAnswer(int index, String value) {
    if (index >= 0 && index < faq.length) faq[index]['answer'] = value;
  }

  /// Persists the bundle. Returns true only on a confirmed write; false on
  /// failure so the view surfaces a real error and never fakes success (L-015).
  /// Blank FAQ rows (missing question or answer) are dropped before save.
  Future<bool> save() async {
    _saving = true;
    notifyListeners();
    try {
      final cleanFaq = faq
          .map((e) => {
                'question': (e['question'] ?? '').trim(),
                'answer': (e['answer'] ?? '').trim(),
              })
          .where((e) =>
              e['question']!.isNotEmpty && e['answer']!.isNotEmpty)
          .toList();
      final ok = await _repo.saveCoachPolicies({
        'cancellationPolicy': cancellationPolicy.trim(),
        'whatToBring': whatToBring.trim(),
        'travelRadius': travelRadius.trim(),
        'sessionNotes': sessionNotes.trim(),
        'faq': cleanFaq,
      });
      return ok;
    } catch (e) {
      debugPrint('CoachPoliciesController.save failed: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}

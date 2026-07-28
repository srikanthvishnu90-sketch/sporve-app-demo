import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';

/// Parent-facing C5 surface. Loads the caller's own children, then the SENT
/// parent_updates for the selected child (newest-first). Reads are doubly
/// guarded — RLS server-side AND a child-ownership + status='sent' filter in the
/// repository — so a guardian only ever sees their own child's sent updates.
class ProgressUpdatesController extends ChangeNotifier {
  ProgressUpdatesController(this._repo);
  final AppRepository _repo;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> children = [];
  String? selectedChildId;
  List<Map<String, dynamic>> updates = [];

  Map<String, dynamic>? get selectedChild {
    for (final c in children) {
      if (c['_id']?.toString() == selectedChildId) return c;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final ath = await _repo.getAthletes();
      children = ath.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      selectedChildId =
          children.isNotEmpty ? children.first['_id']?.toString() : null;
      await _loadUpdates();
    } catch (e) {
      error = 'Could not load progress updates.';
      debugPrint('progress-updates load failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectChild(String childId) async {
    if (childId == selectedChildId) return;
    selectedChildId = childId;
    await _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    final id = selectedChildId;
    if (id == null) {
      updates = [];
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      updates = await _repo.getParentUpdatesForChild(id);
    } catch (e) {
      updates = [];
      debugPrint('progress-updates fetch failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

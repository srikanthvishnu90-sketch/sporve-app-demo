import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';

/// Provider Model Rebuild — item #6 (c, deferred UI): the SHARED ORG INBOX
/// controller. Thin over [SharedInboxRepository] — org_inbox/route_conversation
/// (20260729_000620), admin-gated at the DB (empty for a non-admin, same
/// honest-empty stance as the camp roster / org grid, L-005/L-024 pattern).
///
/// This does NOT generate drafts — it only reads the ones the existing
/// draft-reply pipeline already wrote, and lets an org admin (re)route a
/// thread to a service/trainer. Approving/sending a draft happens on the
/// EXISTING chat screen's ai_draft card (L-012 discipline: never a second
/// send path).
class SharedInboxController extends ChangeNotifier {
  SharedInboxController(this._repo);

  final AppRepository _repo;

  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> get threads => List.unmodifiable(_threads);

  bool _loading = false;
  bool get loading => _loading;
  bool _error = false;
  bool get error => _error;

  final Set<String> _routing = {};
  bool isRouting(String conversationId) => _routing.contains(conversationId);

  Future<void> load() async {
    _loading = true;
    _error = false;
    notifyListeners();
    try {
      _threads = await _repo.orgInbox();
    } catch (e) {
      debugPrint('SharedInboxController.load failed: $e');
      _error = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// (Re)route a thread to [serviceId]/[memberId] (either may be null to
  /// clear). Returns true on a confirmed write (L-015); on success reloads so
  /// the list reflects the new routing + any draft that already existed.
  Future<bool> route({
    required String conversationId,
    String? serviceId,
    String? memberId,
  }) async {
    if (_routing.contains(conversationId)) return false;
    _routing.add(conversationId);
    notifyListeners();
    try {
      final ok = await _repo.routeConversation(
        conversationId: conversationId,
        serviceId: serviceId,
        memberId: memberId,
      );
      if (ok) await load();
      return ok;
    } catch (e) {
      debugPrint('SharedInboxController.route failed: $e');
      return false;
    } finally {
      _routing.remove(conversationId);
      notifyListeners();
    }
  }
}

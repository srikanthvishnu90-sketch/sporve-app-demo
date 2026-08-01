import 'package:flutter/foundation.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/utils/team_split.dart';

/// Provider Model Rebuild — item #9 (deferred UI): TEAM BLOCKS controller.
/// Thin over [TeamBlockRepository] (20260729_000900_team_blocks.sql;
/// lib/core/utils/team_split.dart for the share-math preview). A team block is
/// a BUYER construct (N sessions bought for a roster of families) attached to
/// an existing `serviceType='team_block'` service — this controller does NOT
/// create services, only blocks against one the coach already has.
///
/// Money movement is DESIGN-ONLY (L-003): [createSplitPayLinks] authors the
/// link rows + penny-exact shares only; there is no real Stripe charge here.
class TeamBlockController extends ChangeNotifier {
  TeamBlockController(this._repo);

  final AppRepository _repo;

  // ── team_block services (the coach picks one to build a block against) ──
  bool _servicesLoading = true;
  bool get servicesLoading => _servicesLoading;
  bool _servicesError = false;
  bool get servicesError => _servicesError;
  List<Map<String, dynamic>> _teamBlockServices = [];
  List<Map<String, dynamic>> get teamBlockServices => List.unmodifiable(_teamBlockServices);

  Future<void> loadServices() async {
    _servicesLoading = true;
    _servicesError = false;
    notifyListeners();
    try {
      final all = await _repo.getMyServices();
      _teamBlockServices =
          all.where((s) => (s['serviceType'] ?? '').toString() == 'team_block').toList();
    } catch (e) {
      debugPrint('TeamBlockController.loadServices failed: $e');
      _servicesError = true;
    } finally {
      _servicesLoading = false;
      notifyListeners();
    }
  }

  // ── create-block flow state ──────────────────────────────────────────
  bool _creating = false;
  bool get creating => _creating;

  /// Live pricing preview as the coach edits the form — mirrors the DB's
  /// penny-exact split (team_split.dart / team_block_even_shares) so the
  /// preview can never disagree with what gets stored (L-021 discipline).
  TeamBlockPricing? previewFor({
    required int sessionCount,
    required int unitPriceCents,
    required String paymentMode,
    required int rosterSize,
  }) {
    if (sessionCount <= 0 || unitPriceCents < 0 || rosterSize < 0) return null;
    return TeamBlockPricing.compute(
      sessionCount: sessionCount,
      unitPriceCents: unitPriceCents,
      paymentMode: paymentMode,
      rosterSize: rosterSize == 0 ? 1 : rosterSize,
    );
  }

  /// Creates the block, adds every roster row, and (split_pay only) generates
  /// the payment links. Returns the new block id on success, null on ANY
  /// failure (honest failure, L-015) — nothing partial is presented as done.
  Future<String?> createBlock({
    required String serviceId,
    String? teamName,
    required int sessionCount,
    required int unitPriceCents,
    required String paymentMode,
    List<Map<String, String?>> roster = const [],
  }) async {
    _creating = true;
    notifyListeners();
    try {
      final blockId = await _repo.createTeamBlock(
        serviceId: serviceId,
        teamName: teamName,
        sessionCount: sessionCount,
        unitPriceCents: unitPriceCents,
        paymentMode: paymentMode,
      );
      if (blockId == null) return null;

      for (final member in roster) {
        final added = await _repo.addTeamBlockMember(
          teamBlockId: blockId,
          invitedEmail: member['email'],
          invitedPhone: member['phone'],
          memberLabel: member['label'],
        );
        if (added == null) return null; // honest failure — don't half-create
      }

      if (paymentMode == 'split_pay' && roster.isNotEmpty) {
        final linked = await _repo.createSplitPayLinks(teamBlockId: blockId);
        if (linked == null) return null;
      }

      return blockId;
    } catch (e) {
      debugPrint('TeamBlockController.createBlock failed: $e');
      return null;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  // ── split-pay status view ────────────────────────────────────────────
  bool _statusLoading = false;
  bool get statusLoading => _statusLoading;
  bool _statusError = false;
  bool get statusError => _statusError;
  List<Map<String, dynamic>> _status = [];
  List<Map<String, dynamic>> get status => List.unmodifiable(_status);

  Future<void> loadStatus(String teamBlockId) async {
    _statusLoading = true;
    _statusError = false;
    notifyListeners();
    try {
      _status = await _repo.teamBlockSplitStatus(teamBlockId: teamBlockId);
    } catch (e) {
      debugPrint('TeamBlockController.loadStatus failed: $e');
      _statusError = true;
    } finally {
      _statusLoading = false;
      notifyListeners();
    }
  }
}

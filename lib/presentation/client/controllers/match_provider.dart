import 'package:flutter/material.dart';
import '../../../core/data/app_repository.dart';

/// Guided "Find my coach" state. The UI collects an athlete profile and calls
/// [findMatches]; all safety gating + ranking happens server-side in the
/// ai-match Edge Function (Provider/ChangeNotifier only, no model access here).
///
/// A result carries `{provider_id, name, title, sport, score, why,
/// price_per_session (cents), distance_km, rating_avg, rating_count,
/// available_this_week}` — every fact comes from real data, never the model.
class MatchProvider with ChangeNotifier {
  final AppRepository _repo;
  MatchProvider(this._repo);

  List<dynamic> _matches = const [];
  List<dynamic> get matches => _matches;

  String _note = '';
  String get note => _note; // honest message when nothing passed the gates

  int _eligibleCount = 0;
  int get eligibleCount => _eligibleCount;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _error;
  String? get error => _error;

  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  bool get isEmptyResult =>
      _hasSearched && !_isBusy && _error == null && _matches.isEmpty;

  Future<void> findMatches(Map<String, dynamic> client) async {
    _isBusy = true;
    _hasSearched = true;
    _error = null;
    notifyListeners();

    final res = await _repo.aiMatch(client);
    _isBusy = false;
    if (res['error'] != null) {
      _error = res['error'].toString();
      _matches = const [];
      notifyListeners();
      return;
    }
    _matches = (res['matches'] as List?) ?? const [];
    _note = res['note']?.toString() ?? '';
    _eligibleCount = (res['eligible_count'] as num?)?.toInt() ?? _matches.length;
    notifyListeners();
  }

  void reset() {
    _matches = const [];
    _note = '';
    _eligibleCount = 0;
    _error = null;
    _hasSearched = false;
    notifyListeners();
  }
}

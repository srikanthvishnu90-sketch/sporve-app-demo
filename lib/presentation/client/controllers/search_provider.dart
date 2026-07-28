import 'package:flutter/material.dart';
import '../../../core/data/app_repository.dart';

/// AI discovery state machine (Stage 3): NL query -> editable constraint chips
/// (search-parse) -> ranked results (search-execute). Provider/ChangeNotifier
/// only — all model access lives server-side behind the two Edge Functions.
///
/// Flow: [runSearch] parses the query into [constraints], then executes. The UI
/// may edit a chip ([setConstraint]/[clearConstraint]) and call [reExecute] to
/// re-rank without re-parsing. A `gated` response means the market isn't ready —
/// the UI should fall back to the normal browse grid.
class SearchProvider with ChangeNotifier {
  final AppRepository _repo;
  SearchProvider(this._repo);

  String _query = '';
  String get query => _query;

  Map<String, dynamic> _constraints = {};
  Map<String, dynamic> get constraints => _constraints;

  List<dynamic> _results = const [];
  List<dynamic> get results => _results;

  bool _gated = false;
  bool get gated => _gated; // market not ready -> show browse grid

  Map<String, dynamic>? _relax;
  Map<String, dynamic>? get relax => _relax; // thin results -> one suggestion

  bool _isParsing = false;
  bool get isParsing => _isParsing;
  bool _isExecuting = false;
  bool get isExecuting => _isExecuting;
  bool get isBusy => _isParsing || _isExecuting;

  String? _error;
  String? get error => _error;

  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  /// True once a search ran and (non-gated, non-error) returned nothing.
  bool get isEmptyResult =>
      _hasSearched &&
      !_isBusyOrUnran &&
      !_gated &&
      _error == null &&
      _results.isEmpty;
  bool get _isBusyOrUnran => isBusy || !_hasSearched;

  /// Full flow: parse the NL query into editable constraints, then execute.
  Future<void> runSearch(
    String query, {
    Map<String, dynamic>? locationHint,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _query = q;
    _hasSearched = true;
    _error = null;
    _relax = null;
    _gated = false;
    _isParsing = true;
    notifyListeners();

    final parsed = await _repo.searchParse(q, locationHint: locationHint);
    _isParsing = false;
    if (parsed['error'] != null) {
      _error = parsed['error'].toString();
      notifyListeners();
      return;
    }
    _constraints = _normalize(parsed, q);
    notifyListeners();
    await _execute(locationHint: locationHint);
  }

  /// Re-rank with the (possibly edited) constraints — no re-parse.
  Future<void> reExecute({Map<String, dynamic>? locationHint}) async {
    if (!_hasSearched) return;
    await _execute(locationHint: locationHint);
  }

  /// Apply filter-sheet selections and run discovery — works even when no NL
  /// query was typed. Merges [updates] over the current constraints, so it
  /// round-trips with the chips. Marks the search as run so results render.
  Future<void> applyConstraints(
    Map<String, dynamic> updates, {
    Map<String, dynamic>? locationHint,
  }) async {
    _constraints = {..._constraints, ...updates};
    _constraints['query_text'] ??= _constraints['sport']?.toString() ?? '';
    _hasSearched = true;
    await _execute(locationHint: locationHint);
  }

  Future<void> _execute({Map<String, dynamic>? locationHint}) async {
    _error = null;
    _isExecuting = true;
    notifyListeners();

    final res = await _repo.searchExecute(
      _constraints,
      locationHint: locationHint,
    );
    _isExecuting = false;
    if (res['error'] != null) {
      _error = res['error'].toString();
      _results = const [];
      notifyListeners();
      return;
    }
    _gated = res['gated'] == true;
    _results = _gated ? const [] : ((res['results'] as List?) ?? const []);
    _relax = res['relax'] is Map
        ? Map<String, dynamic>.from(res['relax'])
        : null;
    notifyListeners();
  }

  Map<String, dynamic> _normalize(Map parsed, String q) => {
    'sport': parsed['sport'],
    'athlete_age': parsed['athlete_age'],
    'metro': parsed['metro'],
    'max_price': parsed['max_price'],
    'radius_miles': parsed['radius_miles'],
    'soft_attributes':
        (parsed['soft_attributes'] as List?)?.toList() ?? const [],
    'query_text': q,
  };

  /// Edit one constraint chip (does NOT re-execute — the UI decides when).
  void setConstraint(String key, dynamic value) {
    _constraints = {..._constraints, key: value};
    notifyListeners();
  }

  /// Clear one chip (null, or [] for soft_attributes).
  void clearConstraint(String key) {
    _constraints = {
      ..._constraints,
      key: key == 'soft_attributes' ? const [] : null,
    };
    notifyListeners();
  }

  void reset() {
    _query = '';
    _constraints = {};
    _results = const [];
    _gated = false;
    _relax = null;
    _error = null;
    _hasSearched = false;
    notifyListeners();
  }
}

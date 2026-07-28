// Verifies the AI-discovery state machine: parse populates editable chips then
// executes; gated -> browse fallback; relax surfaces; parse/execute errors are
// captured; chip edits + reExecute re-rank without re-parsing.
//   flutter test test/search_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/client/controllers/search_provider.dart';

class _FakeRepo implements AppRepository {
  Map<String, dynamic> parseResult = {
    'sport': 'basketball',
    'athlete_age': 12,
    'metro': null,
    'max_price': 80,
    'radius_miles': null,
    'soft_attributes': ['beginner-friendly'],
  };
  Map<String, dynamic> executeResult = {
    'gated': false,
    'results': [
      {'program_id': 'p1', 'title': 'Hoops', 'why': 'Matches Basketball.'},
    ],
    'relax': null,
  };
  int executeCalls = 0;
  Map<String, dynamic>? lastExecuteConstraints;

  @override
  Future<Map<String, dynamic>> searchParse(
    String query, {
    Map<String, dynamic>? locationHint,
  }) async => parseResult;

  @override
  Future<Map<String, dynamic>> searchExecute(
    Map<String, dynamic> constraints, {
    Map<String, dynamic>? locationHint,
  }) async {
    executeCalls++;
    lastExecuteConstraints = constraints;
    return executeResult;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('runSearch: parse -> editable chips -> execute -> results', () async {
    final repo = _FakeRepo();
    final p = SearchProvider(repo);
    await p.runSearch('basketball coach under \$80 for my 12yo');

    expect(p.constraints['sport'], 'basketball');
    expect(p.constraints['max_price'], 80);
    expect(p.constraints['query_text'], isNotEmpty);
    expect(p.results.length, 1);
    expect(p.gated, false);
    expect(p.error, isNull);
    expect(p.isBusy, false);
  });

  test(
    'gated response -> no results, gated flag set (browse fallback)',
    () async {
      final repo = _FakeRepo()
        ..executeResult = {'gated': true, 'reason': 'market_not_ready'};
      final p = SearchProvider(repo);
      await p.runSearch('lacrosse in nowhere');

      expect(p.gated, true);
      expect(p.results, isEmpty);
      expect(p.isEmptyResult, false, reason: 'gated is not an empty result');
    },
  );

  test('relax suggestion surfaces on thin results', () async {
    final repo = _FakeRepo()
      ..executeResult = {
        'gated': false,
        'results': [],
        'relax': {'type': 'radius', 'message': 'Expand to 10mi'},
      };
    final p = SearchProvider(repo);
    await p.runSearch('tennis');

    expect(p.relax, isNotNull);
    expect(p.relax!['type'], 'radius');
    expect(p.isEmptyResult, true);
  });

  test('parse error short-circuits (no execute)', () async {
    final repo = _FakeRepo()..parseResult = {'error': 'bad query'};
    final p = SearchProvider(repo);
    await p.runSearch('???');

    expect(p.error, 'bad query');
    expect(repo.executeCalls, 0);
    expect(p.results, isEmpty);
  });

  test('execute error is captured', () async {
    final repo = _FakeRepo()..executeResult = {'error': 'server down'};
    final p = SearchProvider(repo);
    await p.runSearch('soccer');

    expect(p.error, 'server down');
    expect(p.results, isEmpty);
  });

  test('edit a chip + reExecute re-ranks without re-parsing', () async {
    final repo = _FakeRepo();
    final p = SearchProvider(repo);
    await p.runSearch('basketball under \$80');
    expect(repo.executeCalls, 1);

    p.setConstraint('max_price', 120);
    p.clearConstraint('soft_attributes');
    await p.reExecute();

    expect(repo.executeCalls, 2);
    expect(repo.lastExecuteConstraints!['max_price'], 120);
    expect(repo.lastExecuteConstraints!['soft_attributes'], isEmpty);
  });

  test('applyConstraints runs discovery even with no prior NL query', () async {
    final repo = _FakeRepo();
    final p = SearchProvider(repo); // never called runSearch

    await p.applyConstraints({
      'sport': 'tennis',
      'radius_miles': 25.0,
      'soft_attributes': ['beginner-friendly'],
    });

    expect(p.hasSearched, true);
    expect(repo.executeCalls, 1);
    expect(repo.lastExecuteConstraints!['sport'], 'tennis');
    expect(repo.lastExecuteConstraints!['radius_miles'], 25.0);
    // query_text is backfilled from sport so the embedder has a term.
    expect(repo.lastExecuteConstraints!['query_text'], 'tennis');
  });
}

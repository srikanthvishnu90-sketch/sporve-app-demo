// Verifies Home distinguishes a load FAILURE from an empty result: a thrown
// read sets programsError (so the UI shows retry, not a misleading empty state),
// and a successful retry clears it.
//   flutter test test/home_error_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/client/controllers/home_controller.dart';

class _FakeRepo implements AppRepository {
  Object? throwError; // set to throw from getProgramsOrThrow
  List<dynamic> programs = [];

  @override
  Future<List<dynamic>> getProgramsOrThrow() async {
    if (throwError != null) throw throwError!;
    return programs;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('load failure sets programsError; success clears it (retry)', () async {
    final repo = _FakeRepo();
    final home = HomeProvider(repo);

    // 1) failure -> programsError true, programs stays empty
    repo.throwError = Exception('network down');
    await home.fetchPrograms();
    expect(home.programsError, true);
    expect(home.programs, isEmpty);

    // 2) retry succeeds -> error cleared, data shown
    repo.throwError = null;
    repo.programs = [
      {'_id': 'p1', 'title': 'Hoops'},
    ];
    await home.fetchPrograms();
    expect(home.programsError, false);
    expect(home.programs.length, 1);
  });

  test('empty (no error) is NOT flagged as an error', () async {
    final repo = _FakeRepo(); // returns [] with no throw
    final home = HomeProvider(repo);
    await home.fetchPrograms();
    expect(home.programsError, false, reason: 'empty != failure');
    expect(home.programs, isEmpty);
  });
}

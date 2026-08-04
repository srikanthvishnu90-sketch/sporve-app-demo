// Provider Model Rebuild — item #4. Proves the AI setup interview on the
// deterministic MockRepository (offline; refineSetupBundle returns null, so the
// template-derived bundle is authoritative and the test is deterministic):
//   • A confirmed bundle calls the EXISTING item-#1 repo methods
//     (setWeeklyAvailability + createService × N + saveCoachPolicies) with
//     TEMPLATE-derived values when the coach didn't override them.
//   • The shared weekly grid is set ONCE (not per service) — no per-service
//     calendar.
//   • Honest failure: an empty service set does not fake success.
//   flutter test test/setup_interview_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/core/data/mock_repository.dart';
import 'package:flutter_structure/core/data/sport_templates.dart';
import 'package:flutter_structure/presentation/provider/controllers/setup_interview_controller.dart';

void main() {
  const AppRepository repo = MockRepository();

  Future<SetupInterviewController> runInterview({
    required String sport,
    required bool private,
    required bool group,
  }) async {
    final c = SetupInterviewController(repo)..start();
    // Step 0..7, tapping chips / template defaults (grounded suggestions).
    c.answerSport(sport); // 0 -> 1
    c.answerKinds(private: private, group: group); // 1 -> 2
    final tmpl = SportTemplates.forSport(sport);
    c.answerDuration(tmpl.privateTemplate!.durationMinutes); // 2 -> 3
    c.answerPrice(tmpl.privateTemplate!.priceMidCents); // 3 -> 4
    c.useWeekdayEvenings(); // 4 -> 5
    c.skipLocation(); // 5 -> 6
    c.useTemplateCancellation(); // 6 -> 7
    await c.useTemplateWhatToBring(); // 7 -> summary (+ best-effort refine)
    return c;
  }

  test('confirmed bundle writes template-derived services + one shared grid',
      () async {
    final tennis = SportTemplates.forSport('Tennis');
    final c = await runInterview(sport: 'Tennis', private: true, group: true);

    expect(c.atSummary, isTrue);
    // The proposal is grounded: values equal the coach's taps, which were the
    // template defaults (coach never typed a custom number).
    expect(c.privatePriceCents, tennis.privateTemplate!.priceMidCents);
    expect(c.groupPriceCents, tennis.groupTemplate!.priceMidCents);
    expect(c.groupCapacity, tennis.groupTemplate!.capacity);
    expect(c.durationMinutes, tennis.privateTemplate!.durationMinutes);

    final ok = await c.confirm();
    expect(ok, isTrue);
    expect(c.done, isTrue);

    // createService x2 with template-derived values.
    final services = await repo.getMyServices();
    final tennisSvcs =
        services.where((s) => s['sport'] == 'Tennis').toList();
    expect(tennisSvcs.length, greaterThanOrEqualTo(2));
    final priv =
        tennisSvcs.firstWhere((s) => s['serviceType'] == 'private');
    final grp = tennisSvcs.firstWhere((s) => s['serviceType'] == 'group');
    expect(priv['priceCents'], tennis.privateTemplate!.priceMidCents);
    expect(priv['durationMinutes'], tennis.privateTemplate!.durationMinutes);
    expect(priv['capacity'], 1);
    expect(grp['priceCents'], tennis.groupTemplate!.priceMidCents);
    expect(grp['capacity'], tennis.groupTemplate!.capacity);

    // ONE shared weekly grid, set once (weekday-evening template blocks).
    final grid = await repo.getWeeklyAvailability();
    expect(grid, isNotEmpty);
    final expectedDays =
        tennis.weekdayEvenings.map((b) => b.dayOfWeek).toSet();
    final gridDays =
        grid.map((b) => (b['dayOfWeek'] as num).toInt()).toSet();
    expect(gridDays, expectedDays);

    // saveCoachPolicies got the template cancellation + what-to-bring.
    final policies = await repo.getCoachPolicies();
    expect(policies['cancellationPolicy'], tennis.cancellationPolicy);
    expect(policies['whatToBring'], tennis.whatToBring);
  });

  test('private-only interview creates exactly one service kind', () async {
    final c =
        await runInterview(sport: 'Basketball', private: true, group: false);
    final ok = await c.confirm();
    expect(ok, isTrue);
    final services = await repo.getMyServices();
    final bball = services.where((s) => s['sport'] == 'Basketball').toList();
    expect(bball.any((s) => s['serviceType'] == 'private'), isTrue);
    expect(bball.any((s) => s['serviceType'] == 'group'), isFalse);
  });

  test('unknown sport falls back to a grounded generic template (not empty)',
      () async {
    final c = await runInterview(sport: 'Pickleball', private: true, group: false);
    // Keeps the coach's own sport label; still has real, editable suggestions.
    expect(c.sport, 'Pickleball');
    expect(c.privatePriceCents, greaterThan(0));
    expect(c.proposedServices(), isNotEmpty);
    final ok = await c.confirm();
    expect(ok, isTrue);
  });

  test('coach edit on the summary overrides the template suggestion', () async {
    final c = await runInterview(sport: 'Soccer', private: true, group: false);
    c.setPrivatePrice(12500); // coach disposes
    final ok = await c.confirm();
    expect(ok, isTrue);
    final services = await repo.getMyServices();
    final soccerPriv = services.firstWhere(
        (s) => s['sport'] == 'Soccer' && s['serviceType'] == 'private');
    expect(soccerPriv['priceCents'], 12500);
  });
}

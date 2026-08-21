// Provider Model Rebuild #9 — TEAM BLOCKS UI (coach create + split-pay status).
// Proves, through the REAL screen + MockRepository (no canned stub needed —
// unlike the venue-conflict grid, nothing here is guard-blocked):
//   1. A coach with no team_block service can quick-create one, then create a
//      split-pay block with a 2-family roster, and lands on the split-pay
//      status view.
//   2. The status view renders PENDING (not paid) for both families and the
//      "0 of 2 families paid" summary — the honest starting state (no fake
//      "paid" success, L-015/L-003).
//   3. Tapping "Charge" on a pending row is a labeled STUB — it surfaces
//      "Payment link — coming soon." and does NOT flip the row to paid (no
//      live money moves from this screen).
//   4. A one-payer block (no roster) lands on the honest "nothing to split"
//      empty state rather than an empty/blank list.
//
// Both scenarios run in ONE testWidgets so the second never has to guess
// whether `MockRepository`'s process-shared static demo store (L-013) already
// holds a team_block service from a prior test in this file.
//   flutter test test/team_block_ui_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:sporve_app/core/data/app_repository.dart';
import 'package:sporve_app/core/data/mock_repository.dart';
import 'package:sporve_app/core/utils/team_split.dart';
import 'package:sporve_app/presentation/provider/view/provider_team_block_screen.dart';

void main() {
  group('team_split.splitShares — penny-exact, sums to the total', () {
    test('an odd total spread across an odd roster loses no penny', () {
      final shares = splitShares(10007, 3);
      expect(shares.reduce((a, b) => a + b), 10007);
      expect(shares, [3336, 3336, 3335]);
    });
  });

  testWidgets(
      'quick-create service -> split-pay status renders PENDING, Charge is a stub, '
      'and a one-payer block renders the honest empty split state',
      (tester) async {
    const AppRepository repo = MockRepository(); // fresh process for this file
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppRepository>.value(value: repo)],
        child: GetMaterialApp(home: const ProviderTeamBlockScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // ── Phase 1: no team_block service yet -> quick-create card shows ──────
    expect(find.text('No team block service yet'), findsOneWidget);
    await tester.tap(find.text('Create team block service'));
    await tester.pumpAndSettle();

    // Quick-create landed us on the real create form with the new service
    // preselected.
    expect(find.text('TEAM BLOCK SERVICE'), findsOneWidget);

    // Switch to split-pay.
    await tester.tap(find.text('Split-pay'));
    await tester.pumpAndSettle();

    // Fill the first roster row (family label + email), found by hint text.
    final rosterLabelField = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.hintText == 'Family / child label');
    final rosterEmailField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Email');
    expect(rosterLabelField, findsOneWidget);
    expect(rosterEmailField, findsOneWidget);
    await tester.enterText(rosterLabelField, 'Garcia family');
    await tester.enterText(rosterEmailField, 'garcia@example.com');
    await tester.pumpAndSettle();

    // Add a second family row.
    // Several TextFields' internal EditableText also register a Scrollable,
    // so the target must be pinned to our form's own ListView explicitly.
    final formScrollable = find
        .descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first;
    final addFamilyFinder = find.text('+ Add a family');
    await tester.scrollUntilVisible(addFamilyFinder, 200, scrollable: formScrollable);
    await tester.tap(addFamilyFinder);
    await tester.pumpAndSettle();
    final rosterLabelFields = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.hintText == 'Family / child label');
    final rosterEmailFields = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Email');
    expect(rosterLabelFields, findsNWidgets(2));
    await tester.enterText(rosterLabelFields.last, 'Nguyen family');
    await tester.enterText(rosterEmailFields.last, 'nguyen@example.com');
    await tester.pumpAndSettle();

    // Create the block — scroll the long form so the CTA is actually built
    // (a plain ListView only builds within the viewport + cache extent).
    final createBlockFinder = find.text('Create team block');
    await tester.scrollUntilVisible(createBlockFinder, 300, scrollable: formScrollable);
    await tester.ensureVisible(createBlockFinder);
    await tester.pumpAndSettle();
    await tester.tap(createBlockFinder);
    await tester.pumpAndSettle();

    // Landed on the split-pay status view, honest starting state.
    expect(find.text('Split-pay status'), findsOneWidget);
    expect(find.text('0 of 2 families paid'), findsOneWidget);
    expect(find.text('Garcia family'), findsOneWidget);
    expect(find.text('Nguyen family'), findsOneWidget);
    expect(find.text('PENDING'), findsNWidgets(2));
    expect(find.text('PAID'), findsNothing);
    expect(find.text('ONBOARDED'), findsNothing);

    // Charge is a labeled stub — tapping it never flips a row to paid.
    await tester.tap(find.text('Charge').first);
    await tester.pump(); // let the snackbar animate in
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Payment link — coming soon'), findsOneWidget);
    expect(find.text('PAID'), findsNothing);
    expect(find.text('PENDING'), findsNWidgets(2));

    // Let the "coming soon" snackbar fully auto-dismiss — otherwise its
    // overlay keeps absorbing pointer events for phase 2's taps below.
    Get.closeAllSnackbars();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // ── Phase 2: a one-payer block (existing service, no roster) ───────────
    // Re-mount the screen fresh (a NEW key forces Flutter to actually dispose
    // the old State/controller rather than reuse it) so the create form
    // starts un-filled and the status controller starts empty, reusing the
    // team_block service quick-created in phase 1 (no quick-create card this
    // time — proves the service persisted).
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AppRepository>.value(value: repo)],
        child: GetMaterialApp(home: ProviderTeamBlockScreen(key: UniqueKey())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No team block service yet'), findsNothing);
    expect(find.text('TEAM BLOCK SERVICE'), findsOneWidget);
    // Default payment mode is One payer — leave it, no roster needed.
    final createBlockFinder2 = find.text('Create team block');
    await tester.scrollUntilVisible(createBlockFinder2, 300, scrollable: formScrollable);
    await tester.ensureVisible(createBlockFinder2);
    await tester.pumpAndSettle();
    await tester.tap(createBlockFinder2);
    await tester.pumpAndSettle();

    expect(find.text('Split-pay status'), findsOneWidget);
    expect(find.text('One-payer block — nothing to split'), findsOneWidget);
  });
}

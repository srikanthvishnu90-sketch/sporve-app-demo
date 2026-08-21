// Verifies the shareable MilestoneCard renders its core fields (athlete name,
// milestone headline, supporting context) so the parent-side progress artifact
// (roadmap P0 #4) is visually complete and safe to screenshot.
//   flutter test test/milestone_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/presentation/client/view/milestone_card.dart';

void main() {
  testWidgets('MilestoneCard renders athlete, milestone and context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MilestoneCard(
            athleteName: 'Alex',
            milestone: 'First left-handed layup',
            context: 'Finished the session hitting it 3 in a row.',
            dateLabel: 'Jul 26, 2026',
            coachName: 'with Coach Diallo',
          ),
        ),
      ),
    );

    expect(find.text('MILESTONE'), findsOneWidget);
    expect(find.text('ALEX'), findsOneWidget); // uppercased on the card
    expect(find.text('First left-handed layup'), findsOneWidget);
    expect(
      find.text('Finished the session hitting it 3 in a row.'),
      findsOneWidget,
    );
    expect(find.text('Jul 26, 2026'), findsOneWidget);
    expect(find.textContaining('with Coach Diallo'), findsOneWidget);
  });

  testWidgets('MilestoneCard omits context row when none supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MilestoneCard(
            athleteName: 'Julian',
            milestone: 'Held plank for 60s',
          ),
        ),
      ),
    );

    expect(find.text('Held plank for 60s'), findsOneWidget);
    expect(find.text('Logged on Sporve'), findsOneWidget);
  });
}

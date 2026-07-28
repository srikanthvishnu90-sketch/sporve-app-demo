// Verifies the shared widgets are screen-reader friendly: an icon-only button
// exposes a button + label to assistive tech, and an unlabelled image is hidden
// (decorative) rather than announcing a raw URL.
//   flutter test test/accessibility_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/presentation/widgets/common_widgets.dart';
import 'package:flutter_structure/presentation/widgets/sporve_image.dart';

void main() {
  testWidgets('SporveIconButton exposes a labelled button to a11y', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SporveIconButton(
            Icons.arrow_back,
            semanticLabel: 'Back',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Back')),
      isSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('unlabelled SporveImage is decorative (no semantics node)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SporveImage('', width: 40, height: 40)),
      ),
    );

    // The image wraps its content in ExcludeSemantics so nothing about it
    // (e.g. a raw url) reaches assistive tech.
    expect(
      find.descendant(
        of: find.byType(SporveImage),
        matching: find.byType(ExcludeSemantics),
      ),
      findsAtLeastNWidgets(1),
    );
    handle.dispose();
  });

  testWidgets('labelled SporveImage announces as an image', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SporveImage(
            '',
            width: 40,
            height: 40,
            semanticLabel: 'Coach Ana',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Coach Ana'), findsOneWidget);
    handle.dispose();
  });
}

// Smoke test for a core shared widget. (Replaces the default `flutter create`
// "counter" stub, which referenced a counter this app never had and pumped MyApp
// without its providers/Supabase init — so it always failed.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_structure/presentation/widgets/common_widgets.dart';

void main() {
  testWidgets('GradientScaffold renders its body', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GradientScaffold(body: Center(child: Text('hello sporve'))),
      ),
    );
    expect(find.text('hello sporve'), findsOneWidget);
  });
}

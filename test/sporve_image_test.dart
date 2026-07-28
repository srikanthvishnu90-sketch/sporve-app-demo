import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/presentation/widgets/sporve_image.dart';

/// Proves the failed/empty-image fallback (#12 Category 1): a missing image
/// never renders a broken-image glyph — it shows the configured fallback icon
/// (person for avatars, image-placeholder otherwise). The empty/null url path
/// is synchronous, so this is deterministic and needs no network.
void main() {
  testWidgets('empty url → person fallback for avatars', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SporveImage('', width: 100, height: 100, fallbackIcon: Icons.person),
      ),
    ));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('null url → default image-placeholder fallback', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SporveImage(null, width: 100, height: 100),
      ),
    ));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

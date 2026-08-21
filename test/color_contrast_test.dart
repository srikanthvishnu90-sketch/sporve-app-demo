import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/theme/app_colors.dart';

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  final high = light > dark ? light : dark;
  final low = light > dark ? dark : light;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  test('core text and semantic foregrounds meet WCAG AA on the canvas', () {
    const foregrounds = <String, Color>{
      'primary': AppColors.textPrimary,
      'secondary': AppColors.textSecondary,
      'tertiary': AppColors.textTertiary,
      'structural': AppColors.slateFg,
      'link': AppColors.blueText,
      'positive': AppColors.positive,
      'warning': AppColors.warning,
      'negative': AppColors.negative,
    };
    for (final entry in foregrounds.entries) {
      expect(
        _contrast(entry.value, AppColors.ink),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} must remain readable against the canvas.',
      );
    }
  });

  test('semantic feedback roles cannot collapse to the same value', () {
    expect({
      AppColors.positive.toARGB32(),
      AppColors.warning.toARGB32(),
      AppColors.negative.toARGB32(),
      AppColors.blue.toARGB32(),
    }, hasLength(4));
  });
}

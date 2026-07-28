import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

class ProviderCapacityScreen extends StatelessWidget {
  const ProviderCapacityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'STEP 3 OF 7',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capacity',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MAX ATHLETES PER SESSION',
                        style: AppTypography.font(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '${provider.maxAthletes}',
                        style: AppTypography.font(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.slateText,
                      inactiveTrackColor: AppColors.surface2,
                      thumbColor: AppColors.slateText,
                      overlayColor: AppColors.slateText.withValues(alpha: 0.1),
                      trackHeight: 20,
                      trackShape: const GradientSliderTrackShape(),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                        elevation: 3,
                        pressedElevation: 5,
                      ),
                    ),
                    child: Slider(
                      value: provider.maxAthletes.toDouble(),
                      min: 1,
                      max: 100,
                      onChanged: (v) => provider.setMaxAthletes(v.round()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1-ON-1',
                        style: AppTypography.font(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'GROUP 100',
                        style: AppTypography.font(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                SporveButton(
                  'Back',
                  onPressed: () => Get.back(),
                  variant: SporveButtonVariant.tertiary,
                  onDark: true,
                  fullWidth: false,
                ),
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: SporveButton(
                    'Next',
                    onPressed: () => Get.toNamed(AppRoutes.providerPricing),
                    icon: Icons.arrow_forward,
                    variant: SporveButtonVariant.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class GradientSliderTrackShape extends RoundedRectSliderTrackShape {
  const GradientSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Canvas canvas = context.canvas;

    // Inactive track paint
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? AppColors.surface2
      ..style = PaintingStyle.fill;

    // Active track paint (slate)
    final Paint activePaint = Paint()
      ..color = AppColors.slateText
      ..style = PaintingStyle.fill;

    // Border paint (for the whole track)
    final Paint borderPaint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final RRect trackRRect = RRect.fromRectAndRadius(trackRect, Radius.circular(trackRect.height / 2));
    
    // Draw inactive track
    canvas.drawRRect(trackRRect, inactivePaint);

    // Draw active track segment
    final double thumbX = thumbCenter.dx;
    final Rect activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbX, trackRect.bottom);
    final RRect activeRRect = RRect.fromRectAndRadius(activeRect, Radius.circular(trackRect.height / 2));
    canvas.drawRRect(activeRRect, activePaint);

    // Draw border outline
    canvas.drawRRect(trackRRect, borderPaint);
  }
}

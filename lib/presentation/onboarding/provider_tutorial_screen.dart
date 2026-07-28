import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/sporve_button.dart';

class ProviderTutorialScreen extends StatefulWidget {
  const ProviderTutorialScreen({super.key});

  @override
  State<ProviderTutorialScreen> createState() => _ProviderTutorialScreenState();
}

class _ProviderTutorialScreenState extends State<ProviderTutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Roster at Your Fingertips',
      'description': 'Create custom teams, group players by rosters, and move athletes seamlessly between teams in real-time.',
      'icon': Icons.groups_outlined,
      'badge': Icons.bolt,
    },
    {
      'title': 'Track Session Calendars',
      'description': 'Toggle between Month, Week, and Day views. Instantly filter schedule details and manage sessions on a clean timeline.',
      'icon': Icons.calendar_month_outlined,
      'badge': Icons.auto_awesome,
    },
    {
      'title': 'Automated Finances',
      'description': 'View weekly revenues, booking summaries, and execute transparent payouts directly to your linked account.',
      'icon': Icons.payments_outlined,
      'badge': Icons.trending_up,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _enterDashboard();
    }
  }

  void _enterDashboard() {
    Get.offAllNamed(AppRoutes.providerMainNav);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'COACH TUTORIAL',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SporveButton(
                    'Skip',
                    onPressed: _enterDashboard,
                    variant: SporveButtonVariant.tertiary,
                    onDark: true,
                    size: SporveButtonSize.compact,
                    fullWidth: false,
                  ),
                ],
              ),
            ),

            // PageView Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) {
                  setState(() {
                    _currentPage = idx;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Giant feature glyph
                        Container(
                          height: 160,
                          width: 160,
                          decoration: BoxDecoration(
                            color: AppColors.slateTint,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.slateBorder),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 72,
                            color: AppColors.slateText,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title with badge glyph
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              slide['badge'] as IconData,
                              color: AppColors.slateText,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                slide['title'] as String,
                                textAlign: TextAlign.center,
                                style: AppTypography.heading.copyWith(
                                  color: Colors.white,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            slide['description'] as String,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator dots & Bottom action button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Smooth Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (idx) {
                      final active = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 24 : 8,
                        decoration: BoxDecoration(
                          color: active ? AppColors.slateText : AppColors.textTertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 36),

                  // Continuation button
                  SporveButton(
                    _currentPage == _slides.length - 1 ? 'Get started' : 'Continue',
                    onPressed: _onNext,
                    variant: SporveButtonVariant.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

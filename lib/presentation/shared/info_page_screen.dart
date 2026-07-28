import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/common_widgets.dart';

/// A simple, reusable static content screen for Payment Methods, Privacy &
/// Security, Help & Support, and Legal. Content comes via `Get.arguments`:
/// `{ 'title': String, 'sections': [ {heading, body} ], 'note': String? }`.
class InfoPageScreen extends StatelessWidget {
  const InfoPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    final title = (map['title'] ?? 'Info').toString();
    final note = map['note']?.toString();
    final sections = (map['sections'] as List?) ?? const [];

    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back, onTap: () => Get.back()),
        ),
        title: Text(
          title,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          if (note != null && note.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.slateTint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.slateBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.slateText, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          for (final s in sections)
            if (s is Map) _section(s['heading']?.toString() ?? '', s['body']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _section(String heading, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

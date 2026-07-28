import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/home_controller.dart';

/// The athlete/family's saved (favorited) coaches & programs.
class SavedCoachesScreen extends StatelessWidget {
  const SavedCoachesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final favIds = home.favoriteIds;
    final saved = home.programs.whereType<Map>().where((p) {
      final id = p['_id']?.toString();
      return id != null && favIds.contains(id);
    }).toList();

    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back, onTap: () => Get.back()),
        ),
        title: Text(
          'Saved Coaches',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: saved.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.bookmark_border,
                title: 'No saved coaches yet',
                message:
                    'Tap the bookmark on any coach or program to save it here.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SavedCard(
                program: Map<String, dynamic>.from(saved[i]),
              ),
            ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final Map<String, dynamic> program;
  const _SavedCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final sport = program['sportType']?.toString();
    final title = program['title']?.toString() ?? 'Program';
    final coach = (program['providerId'] is Map
            ? program['providerId']['businessName']
            : null)
        ?.toString() ??
        'Academy';
    final price = program['price'];
    // Grounded: a real rating or an honest "New" — never a fabricated 0.0★.
    final hasRating =
        program['averageRating'] is num && (program['averageRating'] as num) > 0;
    final rating = hasRating ? program['averageRating'].toString() : 'New';

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: program),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border(
            left: BorderSide(color: SportColors.of(sport), width: 3),
            top: const BorderSide(color: AppColors.hairline),
            right: const BorderSide(color: AppColors.hairline),
            bottom: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            SportIconTile(sport ?? '', size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coach,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasRating) ...[
                        const Icon(Icons.star, color: AppColors.textPrimary, size: 12),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        rating,
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${price is num ? price.round() : (price ?? 0)}',
                        style: AppTypography.font(
                          color: SportColors.of(sport),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

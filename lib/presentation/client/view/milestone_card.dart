import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';

/// A single, self-contained MILESTONE rendered as a shareable card — e.g.
/// "First left-handed layup". Visual-only: the artwork is screenshot-ready (wrap
/// a parent in a RepaintBoundary to rasterize). Actual OS share-sheet delivery is
/// a separate, plugin-dependent step (no share plugin in pubspec yet), so callers
/// pass an [onShare] that today is a stub.
///
/// Design: the milestone is the ONE moment worth broadcasting, so the card leans
/// on the brand slate as a FILL (never as small foreground text on the dark
/// canvas — audit contrast rule) with lifted foreground type on top.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({
    super.key,
    required this.athleteName,
    required this.milestone,
    this.context,
    this.dateLabel,
    this.coachName,
  });

  /// The child's first name.
  final String athleteName;

  /// The achievement headline, e.g. "First left-handed layup".
  final String milestone;

  /// Optional supporting sentence (the coach's note / progress signal).
  final String? context;

  /// Optional human date, e.g. "Jul 26, 2026".
  final String? dateLabel;

  /// Optional attribution, e.g. "with Coach Diallo".
  final String? coachName;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.slateWall,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.slateBorder),
      ),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.slate,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.onSlate,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MILESTONE',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (dateLabel != null && dateLabel!.isNotEmpty)
                Text(
                  dateLabel!,
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            athleteName.toUpperCase(),
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            milestone,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (context != null && context!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context!,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.hairline),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  coachName != null && coachName!.isNotEmpty
                      ? 'Logged on Sporve · $coachName'
                      : 'Logged on Sporve',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Sporve',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Presents [card] in a bottom sheet with a (stubbed) share action. Kept out of
/// the card widget itself so the card stays a pure, rasterizable visual.
Future<void> showMilestoneSheet(
  BuildContext context, {
  required MilestoneCard card,
  required VoidCallback onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.hairlineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            RepaintBoundary(child: card),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onShare,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.slate,
                  foregroundColor: AppColors.onSlate,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
                child: Text(
                  'Share milestone',
                  style: AppTypography.font(
                    color: AppColors.onSlate,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

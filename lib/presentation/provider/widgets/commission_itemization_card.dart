import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/commission.dart';

/// Which side is looking. The NUMBERS are identical for both (spec #5: "identical
/// itemization shown to both sides") — audience only chooses which line is bolded
/// and the framing copy.
enum CommissionAudience { org, trainer }

/// The ONE shared commission-split card the org (setting the cut) and the trainer
/// (seeing their net) both read. Renders a [CommissionItemization] from
/// commission.dart — gross → Sporve fee → org commission → trainer net — so the
/// two sides can never see different math.
///
/// MONEY HONESTY (L-003): this is a projection from the current fee schedule; the
/// actual split payout is each side's Stripe payout / 1099. Labeled as such.
class CommissionItemizationCard extends StatelessWidget {
  final CommissionItemization item;
  final CommissionAudience audience;

  /// True when the gross is a representative sample (no real price entered yet).
  final bool sampleNote;

  const CommissionItemizationCard({
    super.key,
    required this.item,
    this.audience = CommissionAudience.org,
    this.sampleNote = false,
  });

  String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final orgIsAudience = audience == CommissionAudience.org;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'On a ${_money(item.grossCents)} session',
                style: AppTypography.font(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (sampleNote)
                Text(
                  'example',
                  style: AppTypography.font(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _row(
            'Organization share (${item.commissionLabel})',
            item.orgCommissionCents,
            emphasize: orgIsAudience,
            positive: orgIsAudience,
          ),
          const SizedBox(height: 6),
          _row('Sporve fee (${item.platformRatePct})', item.platformFeeCents),
          const SizedBox(height: 6),
          _row(
            'Trainer net',
            item.trainerNetCents,
            emphasize: !orgIsAudience,
            positive: !orgIsAudience,
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.hairline, height: 1),
          const SizedBox(height: 8),
          Text(
            'Sporve currently charges 0% per booking. Stripe processing and the '
            'actual payout remain authoritative in Stripe.',
            style: AppTypography.font(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    int cents, {
    bool emphasize = false,
    bool positive = false,
  }) {
    final color = positive ? AppColors.successGreen : AppColors.textPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.font(
            fontSize: emphasize ? 13 : 12,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          _money(cents),
          style: AppTypography.font(
            fontSize: emphasize ? 15 : 13,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

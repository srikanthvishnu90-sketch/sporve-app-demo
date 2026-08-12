import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/analytics_service.dart';

/// Modal dialog for reaching official Sporve Support (support@sporve.com)
class SupportModal extends StatelessWidget {
  const SupportModal({super.key});

  static Future<void> show(BuildContext context) {
    AnalyticsService().logEvent('support_modal_opened');
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SupportModal(),
    );
  }

  Future<void> _launchEmail() async {
    AnalyticsService().logEvent('support_email_clicked');
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@sporve.com',
      queryParameters: {
        'subject': 'Sporve App Inquiry / Support Request',
        'body': 'Hi Sporve Support Team,\n\nI need help with:\n\n[Please describe your issue or refund request here]\n\nApp Version: 1.0.0',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sporve Customer Support',
                style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We are here to help with bookings, payments, refunds, and coach inquiries.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairlineStrong),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: AppColors.slateText, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Official Support Channel',
                        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        'support@sporve.com',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '• Standard response time: Within 24 hours daily\n'
            '• Refund & Cancellation requests are processed per policy\n'
            '• Urgent issue? Include your Booking ID in email subject',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _launchEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate,
                foregroundColor: AppColors.onSlate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Email to support@sporve.com'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

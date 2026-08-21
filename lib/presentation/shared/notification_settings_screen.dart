import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:provider/provider.dart';
import '../widgets/common_widgets.dart';
import '../../core/data/app_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';

/// Push / email / SMS notification preferences, persisted via the repository
/// (`getNotificationPrefs` / `saveNotificationPrefs`). Delivery itself is out of
/// scope in the demo, but the preferences are real and saved.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // key → [group, label], default true.
  static const List<List<String>> _prefs = [
    ['Push', 'pushMessages', 'New messages'],
    ['Push', 'pushBookings', 'Booking updates'],
    ['Push', 'pushReminders', 'Session reminders'],
    ['Push', 'pushPromotions', 'Offers & tips'],
    ['Email', 'emailBookings', 'Booking confirmations'],
    ['Email', 'emailMessages', 'Message digests'],
    ['Email', 'emailWeeklyDigest', 'Weekly progress digest'],
    ['Email', 'emailPromotions', 'Product news'],
    ['SMS', 'smsBookings', 'Booking confirmations'],
    ['SMS', 'smsReminders', 'Session reminders'],
    ['SMS', 'smsPromotions', 'Offers'],
  ];

  Map<String, bool> _values = {};
  bool _loading = true;

  AppRepository get _repo => context.read<AppRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await _repo.getNotificationPrefs();
    if (!mounted) return;
    setState(() {
      _values = {
        for (final p in _prefs) p[1]: (saved[p[1]] as bool?) ?? true,
      };
      _loading = false;
    });
  }

  Future<void> _set(String key, bool v) async {
    setState(() => _values[key] = v);
    await _repo.saveNotificationPrefs(_values);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String>['Push', 'Email', 'SMS'];
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back,
              onTap: () => Navigator.pop(context)),
        ),
        title: Text(
          'Notifications',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slateText),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    child: Text(
                      g.toUpperCase(),
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      children: [
                        for (final p in _prefs.where((p) => p[0] == g))
                          _row(p[2], p[1], p != _prefs.where((x) => x[0] == g).last),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }

  Widget _row(String label, String key, bool divider) => Column(
    children: [
      SwitchListTile(
        value: _values[key] ?? true,
        onChanged: (v) => _set(key, v),
        activeThumbColor: AppColors.onSlate,
        activeTrackColor: AppColors.slateText,
        inactiveThumbColor: AppColors.textTertiary,
        inactiveTrackColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          label,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
      if (divider) const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Hairline(),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/sporve_button.dart';
import 'create_trainer_bottom_sheet.dart';

/// The TWO DOORS to add a trainer (Provider-Model-Rebuild #5):
///   A. Affiliate an EXISTING Sporve account (search by email/phone → invite).
///   B. Invite a NEW person by email/text into the standard funnel, org
///      pre-attached (the invitee onboards + does their own background check).
/// Plus the legacy manual profile (fastest for a club that just wants a roster
/// entry to verify). Verification ALWAYS belongs to the person (L-005) — no door
/// makes anyone bookable.
void showAddTrainerChooser(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddTrainerChooser(),
  );
}

BoxDecoration _sheetDeco() => const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    );

Widget _grabber() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

class _AddTrainerChooser extends StatelessWidget {
  const _AddTrainerChooser();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _sheetDeco(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _grabber(),
          Text('Add a trainer',
              style: AppTypography.font(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('They become bookable only after their own background check.',
              style: AppTypography.font(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _door(
            context,
            icon: Icons.person_search,
            title: 'Affiliate an existing account',
            subtitle: 'They already use Sporve — link them by email or phone.',
            onTap: () {
              Navigator.of(context).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _AffiliateExistingSheet(),
              );
            },
          ),
          const SizedBox(height: 10),
          _door(
            context,
            icon: Icons.mark_email_unread_outlined,
            title: 'Invite by email or text',
            subtitle: 'New to Sporve — they onboard with your org pre-attached.',
            onTap: () {
              Navigator.of(context).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _InviteByContactSheet(),
              );
            },
          ),
          const SizedBox(height: 10),
          _door(
            context,
            icon: Icons.edit_note,
            title: 'Add a profile manually',
            subtitle: 'Enter their details and set commission now.',
            onTap: () {
              Navigator.of(context).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const CreateTrainerBottomSheet(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _door(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.slate, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTypography.font(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppTypography.font(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ]),
      ),
    );
  }
}

/// DOOR A — search an existing account by exact email/phone, then affiliate.
class _AffiliateExistingSheet extends StatefulWidget {
  const _AffiliateExistingSheet();
  @override
  State<_AffiliateExistingSheet> createState() =>
      _AffiliateExistingSheetState();
}

class _AffiliateExistingSheetState extends State<_AffiliateExistingSheet> {
  final _query = TextEditingController();
  bool _searching = false;
  bool _searched = false;
  bool _sending = false;
  Map<String, dynamic>? _found;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searched = false;
      _found = null;
    });
    final res =
        await context.read<ProviderController>().findAccountToAffiliate(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searched = true;
      _found = res;
    });
  }

  Future<void> _affiliate() async {
    final found = _found;
    if (found == null) return;
    setState(() => _sending = true);
    final ok = await context
        .read<ProviderController>()
        .affiliateExisting(found['profile_id'].toString());
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      Get.back();
      Get.snackbar('Invite sent',
          'They\'ll appear on your roster once they accept. Bookable after their background check.',
          backgroundColor: AppColors.surface, colorText: AppColors.textPrimary);
    } else {
      Get.snackbar('Couldn\'t send the invite', 'Please try again.',
          backgroundColor: AppColors.surface, colorText: AppColors.textPrimary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: _sheetDeco(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _grabber(),
            Text('Affiliate an existing account',
                style: AppTypography.font(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Their email or phone',
                labelStyle: AppTypography.font(
                    color: AppColors.textSecondary, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            SporveButton(
              _searching ? 'Searching…' : 'Search',
              onPressed: _searching ? null : _search,
              variant: SporveButtonVariant.secondary,
              onDark: true,
            ),
            if (_searched) ...[
              const SizedBox(height: 16),
              if (_found != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.successGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Found ${_found!['display_name'] ?? 'an account'} — send an affiliation invite?',
                        style: AppTypography.font(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ]),
                )
              else
                Text(
                  'No Sporve account with that email or phone. Invite them by email or text instead (they\'ll onboard with your org attached).',
                  style: AppTypography.font(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 12),
              if (_found != null)
                SporveButton(
                  _sending ? 'Sending…' : 'Send affiliation invite',
                  onPressed: _sending ? null : _affiliate,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// DOOR B — invite a new person by email/text; org is pre-attached.
class _InviteByContactSheet extends StatefulWidget {
  const _InviteByContactSheet();
  @override
  State<_InviteByContactSheet> createState() => _InviteByContactSheetState();
}

class _InviteByContactSheetState extends State<_InviteByContactSheet> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
      );

  Future<void> _send() async {
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      Get.snackbar('Add a contact', 'Enter an email or phone to invite.',
          backgroundColor: AppColors.surface, colorText: AppColors.textPrimary);
      return;
    }
    setState(() => _sending = true);
    final token = await context.read<ProviderController>().inviteTrainerByContact(
        email: email.isEmpty ? null : email, phone: phone.isEmpty ? null : phone);
    if (!mounted) return;
    setState(() => _sending = false);
    if (token != null) {
      Get.back();
      Get.snackbar('Invite sent',
          'They\'ll onboard with your org attached. Track their progress on your roster.',
          backgroundColor: AppColors.surface, colorText: AppColors.textPrimary);
    } else {
      Get.snackbar('Couldn\'t send the invite', 'Please try again.',
          backgroundColor: AppColors.surface, colorText: AppColors.textPrimary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: _sheetDeco(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _grabber(),
            Text('Invite by email or text',
                style: AppTypography.font(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
                'They sign up, complete onboarding, and run their own background check — with your org already attached.',
                style: AppTypography.font(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email'),
                style: const TextStyle(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _dec('Phone (optional)'),
                style: const TextStyle(color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            SporveButton(
              _sending ? 'Sending…' : 'Send invite',
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/team_split.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/team_block_controller.dart';

/// Provider Model Rebuild — item #9 (deferred UI): TEAM BLOCKS. Coach create
/// (session count, per-session price, one-payer vs split-pay) + the split-pay
/// STATUS view (per-family share, paid/pending, onboarded). Self-contained,
/// additive — no existing screen is rewritten; reached from a single dashboard
/// quick action. NO new nav tab (spec item #9 / PROVIDER-UI-FOLLOWUPS #5): a
/// team block attaches to an EXISTING `serviceType='team_block'` service.
///
/// There is no manual "New Service" create form anywhere in this repo today
/// (PROVIDER-UI-FOLLOWUPS #6 note — createService is only ever called from the
/// AI setup interview / supply importer). Rather than build that full form
/// here (out of scope, tracked separately), this screen offers a MINIMAL
/// inline quick-create for a team_block service (title + per-session price
/// only) when the coach has none yet, so the flow is actually reachable in
/// the demo without a large-screen rewrite elsewhere.
///
/// MONEY HONESTY (L-003): "Generate payment links" calls the REAL repo method
/// (link rows + penny-exact shares are structure, already written), but the
/// per-family "Charge" action is a labeled STUB — "Payment link — coming
/// soon" — never a fake success, never a live charge.
class ProviderTeamBlockScreen extends StatefulWidget {
  const ProviderTeamBlockScreen({super.key});

  @override
  State<ProviderTeamBlockScreen> createState() => _ProviderTeamBlockScreenState();
}

class _RosterRow {
  final labelCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  void dispose() {
    labelCtrl.dispose();
    emailCtrl.dispose();
  }
}

class _ProviderTeamBlockScreenState extends State<ProviderTeamBlockScreen> {
  late final TeamBlockController _controller;

  // Quick-create-service state (only used when no team_block service exists).
  final _svcTitleCtrl = TextEditingController(text: 'Travel team block');
  final _svcPriceCtrl = TextEditingController(text: '35');
  bool _creatingService = false;

  // Create-block form state.
  String? _selectedServiceId;
  final _teamNameCtrl = TextEditingController();
  final _sessionCountCtrl = TextEditingController(text: '10');
  final _unitPriceCtrl = TextEditingController(text: '35');
  int _paymentMode = 0; // 0 = one_payer, 1 = split_pay
  final List<_RosterRow> _roster = [_RosterRow()];

  // After a successful create, we switch into the status view for that block.
  String? _createdBlockId;
  String? _createdTeamLabel;

  @override
  void initState() {
    super.initState();
    _controller = TeamBlockController(context.read<AppRepository>());
    _controller.loadServices();
  }

  @override
  void dispose() {
    _svcTitleCtrl.dispose();
    _svcPriceCtrl.dispose();
    _teamNameCtrl.dispose();
    _sessionCountCtrl.dispose();
    _unitPriceCtrl.dispose();
    for (final r in _roster) {
      r.dispose();
    }
    super.dispose();
  }

  String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  int _parseDollarsToCents(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || v < 0) return -1;
    return (v * 100).round();
  }

  int _parseInt(String raw) => int.tryParse(raw.trim()) ?? -1;

  Future<void> _quickCreateTeamBlockService() async {
    final title = _svcTitleCtrl.text.trim();
    final priceCents = _parseDollarsToCents(_svcPriceCtrl.text);
    if (title.isEmpty || priceCents < 0) {
      _snack("Enter a title and a valid price.");
      return;
    }
    setState(() => _creatingService = true);
    final repo = context.read<AppRepository>();
    final id = await repo.createService({
      'serviceType': 'team_block',
      'title': title,
      'priceCents': priceCents,
      'capacity': 1,
    });
    if (!mounted) return;
    setState(() => _creatingService = false);
    if (id == null) {
      _snack("Couldn't create the service. Please try again.");
      return;
    }
    await _controller.loadServices();
    if (!mounted) return;
    setState(() {
      _selectedServiceId = id;
      if (_unitPriceCtrl.text.trim().isEmpty) {
        _unitPriceCtrl.text = _svcPriceCtrl.text.trim();
      }
    });
  }

  TeamBlockPricing? get _pricingPreview {
    final sessionCount = _parseInt(_sessionCountCtrl.text);
    final unitPriceCents = _parseDollarsToCents(_unitPriceCtrl.text);
    if (sessionCount <= 0 || unitPriceCents < 0) return null;
    final rosterSize = _paymentMode == 1
        ? _roster.where((r) => r.labelCtrl.text.trim().isNotEmpty || r.emailCtrl.text.trim().isNotEmpty).length
        : 1;
    return _controller.previewFor(
      sessionCount: sessionCount,
      unitPriceCents: unitPriceCents,
      paymentMode: _paymentMode == 0 ? 'one_payer' : 'split_pay',
      rosterSize: rosterSize == 0 ? 1 : rosterSize,
    );
  }

  Future<void> _submit() async {
    final serviceId = _selectedServiceId;
    if (serviceId == null) {
      _snack('Pick a team block service first.');
      return;
    }
    final sessionCount = _parseInt(_sessionCountCtrl.text);
    final unitPriceCents = _parseDollarsToCents(_unitPriceCtrl.text);
    if (sessionCount <= 0) {
      _snack('Session count must be at least 1.');
      return;
    }
    if (unitPriceCents < 0) {
      _snack('Enter a valid per-session price.');
      return;
    }
    final paymentMode = _paymentMode == 0 ? 'one_payer' : 'split_pay';
    final rosterRows = _roster
        .where((r) => r.labelCtrl.text.trim().isNotEmpty || r.emailCtrl.text.trim().isNotEmpty)
        .map((r) => {
              'label': r.labelCtrl.text.trim().isEmpty ? null : r.labelCtrl.text.trim(),
              'email': r.emailCtrl.text.trim().isEmpty ? null : r.emailCtrl.text.trim(),
            })
        .toList();
    if (paymentMode == 'split_pay' && rosterRows.isEmpty) {
      _snack('Add at least one family to split-pay.');
      return;
    }

    final teamName = _teamNameCtrl.text.trim();
    final blockId = await _controller.createBlock(
      serviceId: serviceId,
      teamName: teamName.isEmpty ? null : teamName,
      sessionCount: sessionCount,
      unitPriceCents: unitPriceCents,
      paymentMode: paymentMode,
      roster: rosterRows,
    );
    if (!mounted) return;
    if (blockId == null) {
      _snack("Couldn't create the team block. Please try again.");
      return;
    }
    setState(() {
      _createdBlockId = blockId;
      _createdTeamLabel = teamName.isEmpty ? 'Team block' : teamName;
    });
    if (paymentMode == 'split_pay') {
      await _controller.loadStatus(blockId);
    }
  }

  void _snack(String msg) {
    Get.snackbar(
      'Team blocks',
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface2,
      colorText: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TeamBlockController>.value(
      value: _controller,
      child: GradientScaffold(
        body: SafeArea(
          child: Consumer<TeamBlockController>(
            builder: (context, c, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _header(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _createdBlockId != null
                        ? _statusView(c)
                        : _createForm(c),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          SporveIconButton(
            Icons.arrow_back,
            circle: true,
            iconSize: 20,
            onTap: () {
              if (_createdBlockId != null) {
                setState(() => _createdBlockId = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _createdBlockId != null ? 'Split-pay status' : 'Team blocks',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _createdBlockId != null
                      ? (_createdTeamLabel ?? '').toUpperCase()
                      : 'N SESSIONS · ONE ROSTER · ONE OR SPLIT PAY',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CREATE FORM ─────────────────────────────────────────────────────
  Widget _createForm(TeamBlockController c) {
    if (c.servicesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slateText, strokeWidth: 2),
      );
    }
    if (c.servicesError) {
      return ErrorRetry(
        message: "We couldn't load your services. Please try again.",
        onRetry: () => c.loadServices(),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      children: [
        if (c.teamBlockServices.isEmpty) ...[
          _quickCreateServiceCard(),
          const SizedBox(height: 20),
        ] else ...[
          _serviceDropdown(c),
          const SizedBox(height: 18),
          _label('TEAM NAME (OPTIONAL)'),
          const SizedBox(height: 8),
          _textField(_teamNameCtrl, hint: 'e.g. U12 Thunder travel team'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SESSIONS'),
                    const SizedBox(height: 8),
                    _textField(_sessionCountCtrl, keyboardType: TextInputType.number, onChanged: () => setState(() {})),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('PRICE / SESSION'),
                    const SizedBox(height: 8),
                    _textField(_unitPriceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '\$', onChanged: () => setState(() {})),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _label('PAYMENT'),
          const SizedBox(height: 8),
          SporveSegmented(
            segments: const ['One payer', 'Split-pay'],
            selected: _paymentMode,
            onChanged: (i) => setState(() => _paymentMode = i),
          ),
          const SizedBox(height: 18),
          _rosterSection(),
          const SizedBox(height: 18),
          _pricingPreviewCard(),
          const SizedBox(height: 22),
          SporveButton(
            'Create team block',
            onPressed: c.creating ? null : _submit,
            loading: c.creating,
            icon: Icons.groups_outlined,
            onDark: true,
          ),
        ],
      ],
    );
  }

  Widget _quickCreateServiceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No team block service yet',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A team block is created against a service_type="team_block" '
            'listing. Quick-create one now (title + a default per-session '
            'price) — you can refine it later.',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _label('TITLE'),
          const SizedBox(height: 8),
          _textField(_svcTitleCtrl),
          const SizedBox(height: 14),
          _label('DEFAULT PRICE / SESSION'),
          const SizedBox(height: 8),
          _textField(_svcPriceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '\$'),
          const SizedBox(height: 18),
          SporveButton(
            'Create team block service',
            onPressed: _creatingService ? null : _quickCreateTeamBlockService,
            loading: _creatingService,
            variant: SporveButtonVariant.secondary,
            icon: Icons.add,
            onDark: true,
          ),
        ],
      ),
    );
  }

  Widget _serviceDropdown(TeamBlockController c) {
    _selectedServiceId ??= c.teamBlockServices.first['_id']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('TEAM BLOCK SERVICE'),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: AppColors.surface2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairlineStrong),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedServiceId,
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textTertiary, size: 20),
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  for (final s in c.teamBlockServices)
                    DropdownMenuItem<String>(
                      value: s['_id']?.toString(),
                      child: Text(
                        (s['title'] ?? 'Untitled').toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedServiceId = v),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rosterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_paymentMode == 1 ? 'ROSTER (REQUIRED FOR SPLIT-PAY)' : 'ROSTER (OPTIONAL)'),
        const SizedBox(height: 8),
        for (int i = 0; i < _roster.length; i++) ...[
          _rosterRow(i),
          const SizedBox(height: 8),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: () => setState(() => _roster.add(_RosterRow())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairline, style: BorderStyle.solid),
            ),
            child: Text(
              '+ Add a family',
              style: AppTypography.font(
                color: AppColors.slateText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rosterRow(int i) {
    final row = _roster[i];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _textField(row.labelCtrl, hint: 'Family / child label', onChanged: () => setState(() {})),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _textField(row.emailCtrl, hint: 'Email', keyboardType: TextInputType.emailAddress, onChanged: () => setState(() {})),
        ),
        if (_roster.length > 1) ...[
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Remove family row',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              onTap: () => setState(() {
                _roster[i].dispose();
                _roster.removeAt(i);
              }),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pricingPreviewCard() {
    final preview = _pricingPreview;
    if (preview == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(
          'Enter a valid session count and price to preview pricing.',
          style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRICING PREVIEW',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'projection, not a charge',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Block total', style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13)),
              Text(_money(preview.totalCents), style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          if (preview.paymentMode == 'one_payer')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('One-payer owes', style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13)),
                Text(_money(preview.shares.first.shareCents), style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${preview.shares.length} families', style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13)),
                Text('${_money(preview.shares.first.shareCents)} each (approx.)', style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Shares are penny-exact and sum to the block total.',
              style: AppTypography.font(color: AppColors.textTertiary, fontSize: 10.5),
            ),
          ],
          const Divider(color: AppColors.hairline, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Est. platform fee', style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12)),
              Text(_money(preview.feeTotals.feeCents), style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ── SPLIT-PAY STATUS VIEW ────────────────────────────────────────────
  Widget _statusView(TeamBlockController c) {
    if (c.statusLoading && c.status.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slateText, strokeWidth: 2),
      );
    }
    if (c.statusError) {
      return ErrorRetry(
        message: "We couldn't load the split-pay status. Please try again.",
        onRetry: () => c.loadStatus(_createdBlockId!),
      );
    }
    if (c.status.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: _paymentMode == 0 ? 'One-payer block — nothing to split' : 'No roster on this block',
        message: _paymentMode == 0
            ? 'This block is set to one payer, so there is no per-family '
                'split status to show.'
            : 'Add families to the roster to generate split-pay links.',
      );
    }
    final paid = c.status.where((m) => m['linkStatus'] == 'paid').length;
    return RefreshIndicator(
      color: AppColors.slateText,
      backgroundColor: AppColors.surface,
      onRefresh: () => c.loadStatus(_createdBlockId!),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.slateTint,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: AppColors.slateText),
                const SizedBox(width: 8),
                Text(
                  '$paid of ${c.status.length} families paid',
                  style: AppTypography.font(
                    color: AppColors.slateText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment link generation and capture are design-only — no live '
            'charge moves from this screen.',
            style: AppTypography.font(color: AppColors.textTertiary, fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (final m in c.status) ...[
            _statusRow(m),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(Map<String, dynamic> m) {
    final linkStatus = (m['linkStatus'] ?? 'pending').toString();
    final paid = linkStatus == 'paid';
    final label = (m['memberLabel'] ?? m['invitedEmail'] ?? 'Family').toString();
    final email = (m['invitedEmail'] ?? '').toString();
    final memberStatus = (m['memberStatus'] ?? 'pending').toString();
    final onboarded = memberStatus == 'onboarded';
    final athleteFirstName = (m['athleteFirstName'] ?? '').toString();
    final shareCents = (m['shareAmountCents'] as num?)?.toInt();

    return Semantics(
      label: '$label, ${paid ? 'paid' : 'pending'}${onboarded ? ', onboarded' : ''}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(paid ? 'PAID' : 'PENDING', paid ? AppColors.successGreen : AppColors.warmAccent),
                if (onboarded) ...[
                  const SizedBox(width: 6),
                  _statusBadge('ONBOARDED', AppColors.slateText),
                ],
              ],
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11.5),
              ),
            ],
            if (athleteFirstName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Athlete: $athleteFirstName',
                style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shareCents == null ? 'No link generated yet' : 'Share: ${_money(shareCents)}',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!paid)
                  GestureDetector(
                    onTap: () => _snack('Payment link — coming soon.'),
                    child: Text(
                      'Charge',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        text,
        style: AppTypography.font(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTypography.font(
        color: AppColors.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboardType,
    String? prefix,
    VoidCallback? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
          prefixText: prefix,
          prefixStyle: AppTypography.font(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

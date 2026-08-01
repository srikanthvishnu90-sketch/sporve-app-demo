import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/common_widgets.dart';

/// Provider Model Rebuild — item #6 (b, deferred UI): ORG-SERVICE staffing.
/// Self-contained bottom sheet, additive alongside the existing service
/// surfaces (no rewrite): pick ONE of the coach's existing services
/// ([AppRepository.getMyServices]), mark it org-`assignable`, and pick which
/// rostered trainers ([AppRepository.getOrgMembers]) may run it. Writes via
/// [AppRepository.setServiceStaffing] (services.assignable +
/// service_assignable_members, 20260729_000610).
///
/// THE ANY-AVAILABLE RULE (mirrored, not re-decided here): whether a booking
/// with no named trainer is allowed is a pure function of the service's
/// `serviceType` (group/camp = yes, private/team_block = no) — the DB
/// (`service_allows_any_available`) is the ONLY source of truth. This sheet
/// never lets the coach override it: the switch is a locked mirror of that
/// rule, not a setting — flipping it writes nothing.
class OrgServiceStaffingSheet extends StatefulWidget {
  const OrgServiceStaffingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const OrgServiceStaffingSheet(),
    );
  }

  @override
  State<OrgServiceStaffingSheet> createState() => _OrgServiceStaffingSheetState();
}

class _OrgServiceStaffingSheetState extends State<OrgServiceStaffingSheet> {
  late final AppRepository _repo;

  bool _loading = true;
  bool _loadError = false;
  bool _saving = false;

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _members = [];

  String? _selectedServiceId;
  bool _assignable = false;
  final Set<String> _selectedMemberIds = {};

  @override
  void initState() {
    super.initState();
    _repo = context.read<AppRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final services = await _repo.getMyServices();
      final members = await _repo.getOrgMembers();
      if (!mounted) return;
      setState(() {
        _services = services;
        _members = members;
        _loading = false;
      });
      if (services.isNotEmpty) {
        await _selectService(services.first['_id']?.toString());
      }
    } catch (e) {
      debugPrint('OrgServiceStaffingSheet.load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Map<String, dynamic>? get _selectedService {
    if (_selectedServiceId == null) return null;
    for (final s in _services) {
      if (s['_id']?.toString() == _selectedServiceId) return s;
    }
    return null;
  }

  bool get _allowsAnyAvailable {
    final type = (_selectedService?['serviceType'] ?? '').toString();
    return type == 'group' || type == 'camp';
  }

  Future<void> _selectService(String? serviceId) async {
    setState(() {
      _selectedServiceId = serviceId;
      _assignable = (_selectedService?['assignable'] ?? false) == true;
      _selectedMemberIds.clear();
    });
    if (serviceId == null) return;
    try {
      final staffed = await _repo.getServiceStaffing(serviceId);
      if (!mounted || _selectedServiceId != serviceId) return;
      setState(() => _selectedMemberIds.addAll(staffed));
    } catch (e) {
      debugPrint('OrgServiceStaffingSheet.getServiceStaffing failed: $e');
    }
  }

  Future<void> _save() async {
    final serviceId = _selectedServiceId;
    if (serviceId == null || _saving) return;
    setState(() => _saving = true);
    final ok = await _repo.setServiceStaffing(
      serviceId,
      assignable: _assignable,
      memberIds: _assignable ? _selectedMemberIds.toList() : const [],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar(
        'Staffing saved',
        _assignable
            ? '${_selectedMemberIds.length} trainer(s) can run this service.'
            : 'This service is no longer org-staffed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
      Navigator.pop(context);
    } else {
      Get.snackbar(
        'Couldn\'t save',
        'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Org service staffing',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick which rostered trainers may run one of your services.',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _content(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.slateText, strokeWidth: 2),
        ),
      );
    }
    if (_loadError) {
      return ErrorRetry(
        message: "We couldn't load your services. Please try again.",
        onRetry: _load,
      );
    }
    if (_services.isEmpty) {
      return const EmptyState(
        icon: Icons.design_services_outlined,
        title: 'No services yet',
        message: 'Create a service first, then come back here to staff it.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _serviceDropdown(),
        const SizedBox(height: 18),
        _assignableToggle(),
        const SizedBox(height: 12),
        _anyAvailableIndicator(),
        if (_assignable) ...[
          const SizedBox(height: 18),
          _trainerPicker(),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slate,
              foregroundColor: AppColors.onSlate,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
            ),
            onPressed: (_saving || _selectedServiceId == null) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onSlate,
                    ),
                  )
                : Text(
                    'Save staffing',
                    style: AppTypography.font(
                      color: AppColors.onSlate,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _serviceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVICE',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
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
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary, size: 20),
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  for (final s in _services)
                    DropdownMenuItem<String>(
                      value: s['_id']?.toString(),
                      child: Text(
                        '${(s['title'] ?? 'Untitled').toString()} '
                        '(${(s['serviceType'] ?? '').toString()})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => _selectService(v),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assignableToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Org-run service',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Assignable trainers can run this service, not just you.',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _assignable,
          activeThumbColor: AppColors.slateText,
          onChanged: (v) => setState(() => _assignable = v),
        ),
      ],
    );
  }

  /// A LOCKED mirror of `service_allows_any_available` — never a setting the
  /// coach can flip; the switch's interactive state (enabled vs disabled)
  /// itself communicates the rule ("ENABLED only for group/camp").
  Widget _anyAvailableIndicator() {
    final allowed = _allowsAnyAvailable;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Any available trainer',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  allowed
                      ? 'Allowed automatically — group & camp services never '
                          'require a named trainer to book.'
                      : 'Not allowed — a private lesson always requires a '
                          'specific, named trainer.',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IgnorePointer(
            child: Switch(
              value: allowed,
              activeThumbColor: AppColors.slateText,
              // Locked — a null onChanged would suffice, but Switch requires
              // a non-null one to render "enabled" style; IgnorePointer above
              // is the real lock so this never fakes an interactive control.
              onChanged: allowed ? (_) {} : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainerPicker() {
    if (_members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(
          'No rostered trainers yet. Add trainers from the dashboard first.',
          style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12.5),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ASSIGNABLE TRAINERS',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        for (final m in _members) ...[
          _trainerRow(m),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _trainerRow(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final profile = (m['trainer_profile'] as Map?) ?? const {};
    final name = (profile['display_name'] ?? m['name'] ?? 'Trainer').toString();
    final verified = (m['background_check_status'] ?? '').toString() == 'verified';
    final selected = _selectedMemberIds.contains(id);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      onTap: id.isEmpty
          ? null
          : () => setState(() {
                if (selected) {
                  _selectedMemberIds.remove(id);
                } else {
                  _selectedMemberIds.add(id);
                }
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.slateTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? AppColors.slateBorder : AppColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: selected ? AppColors.slateText : AppColors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!verified)
              Text(
                'UNVERIFIED',
                style: AppTypography.font(
                  color: AppColors.warning,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

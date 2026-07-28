import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import '../../widgets/motion_widgets.dart';

class ProviderRosterScreen extends StatefulWidget {
  const ProviderRosterScreen({super.key});

  @override
  State<ProviderRosterScreen> createState() => _ProviderRosterScreenState();
}

class _ProviderRosterScreenState extends State<ProviderRosterScreen> {
  bool _showBroadcastCard = false;
  bool _showAddAthleteForm = false;
  bool _showCreateTeamForm = false;

  final TextEditingController _broadcastController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _teamNameController = TextEditingController();

  String _selectedInitialTeamId = 'unassigned';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProviderController>().fetchRosterData();
      }
    });
  }

  List<CoachTeam> get activeTeams {
    final pc = context.read<ProviderController>();
    return pc.rosterTeams.isNotEmpty ? pc.rosterTeams : _teams;
  }

  List<Map<String, dynamic>> get activeAthletes {
    final pc = context.read<ProviderController>();
    return pc.rosterAthletes.isNotEmpty ? pc.rosterAthletes : _athletes;
  }

  /// Skeleton rows shown while the first roster load is in flight.
  List<Widget> _buildRosterSkeleton() {
    return List.generate(
      4,
      (_) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Skeleton(width: 44, height: 44, radius: BorderRadius.circular(22)),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 13, width: 140),
                    SizedBox(height: 8),
                    Skeleton(height: 11, width: 90),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Local in-session store for the demo add-team form. Starts with only the
  // catch-all "Unassigned" group — NO fabricated teams. Real teams come from the
  // controller (rosterTeams); these locals are only used before any real data.
  final List<CoachTeam> _teams = [
    const CoachTeam(id: 'unassigned', name: 'Unassigned Athletes'),
  ];

  final Map<String, bool> _teamExpanded = {};

  // Local in-session store for the demo add-athlete form. Starts EMPTY — no
  // fabricated athletes are ever shown. Real athletes come from the controller
  // (rosterAthletes); an empty roster shows a proper empty state instead.
  final List<Map<String, dynamic>> _athletes = [];

  void _showSessionsPopup(String athleteName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$athleteName's sessions",
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SporveIconButton(
                      Icons.close,
                      color: AppColors.negative,
                      iconSize: 20,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // No per-athlete session history is loaded for the roster yet, so
                // show an honest empty state rather than invented sessions.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No sessions yet',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoveAthleteDialog(Map<String, dynamic> athlete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Move player to...",
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SporveIconButton(
                      Icons.close,
                      color: AppColors.negative,
                      iconSize: 20,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeTeams.length,
                    itemBuilder: (context, idx) {
                      final team = activeTeams[idx];
                      final isCurrent = athlete['teamId'] == team.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () async {
                            if (!isCurrent) {
                              final athleteId = athlete['id'].toString();
                              final sourceTeamId = athlete['teamId'].toString();
                              final targetTeamId = team.id;
                              final pc = context.read<ProviderController>();
                              
                              bool success = false;
                              if (!athleteId.startsWith('temp_') && !athleteId.contains('images.unsplash.com') && athleteId.length > 5) {
                                success = await pc.moveRosterAthlete(athleteId, sourceTeamId, targetTeamId);
                              }
                              
                              if (success) {
                                Get.snackbar(
                                  'Moved Player',
                                  '${athlete['name']} moved to ${team.name}.',
                                  backgroundColor: AppColors.surface,
                                  colorText: AppColors.textPrimary,
                                );
                              } else {
                                setState(() {
                                  athlete['teamId'] = team.id;
                                });
                                Get.snackbar(
                                  'Moved Player',
                                  '${athlete['name']} is now in ${team.name} locally!',
                                  backgroundColor: AppColors.surface,
                                  colorText: AppColors.textPrimary,
                                );
                              }
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.surface2 : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadii.tile),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  team.name,
                                  style: AppTypography.font(
                                    color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(Icons.check_circle, color: AppColors.slateText, size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the controller so the roster rebuilds when fetchRosterData
    // completes — the loading skeleton is replaced by real data (or empty state).
    final pc = context.watch<ProviderController>();
    int paidCount = activeAthletes.where((a) => a['isPaid'] == true).length;

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SporveIconButton(
                    Icons.arrow_back,
                    circle: true,
                    iconSize: 20,
                    onTap: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Roster',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activeAthletes.length} athletes  ·  $paidCount paid',
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.hairline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
                        cursorColor: AppColors.slateText,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search athlete...',
                          hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons: Broadcast, + Team, + Add [Player]
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SporveButton(
                    'Broadcast',
                    onPressed: () {
                      setState(() {
                        _showBroadcastCard = !_showBroadcastCard;
                        _showAddAthleteForm = false;
                        _showCreateTeamForm = false;
                      });
                    },
                    variant: _showBroadcastCard
                        ? SporveButtonVariant.primary
                        : SporveButtonVariant.dark,
                    size: SporveButtonSize.compact,
                    fullWidth: false,
                  ),
                  const SizedBox(width: 8),
                  SporveButton(
                    'Team',
                    onPressed: () {
                      setState(() {
                        _showCreateTeamForm = !_showCreateTeamForm;
                        _showAddAthleteForm = false;
                        _showBroadcastCard = false;
                      });
                    },
                    variant: _showCreateTeamForm
                        ? SporveButtonVariant.primary
                        : SporveButtonVariant.dark,
                    size: SporveButtonSize.compact,
                    fullWidth: false,
                    icon: Icons.add,
                  ),
                  const SizedBox(width: 8),
                  SporveButton(
                    'Player',
                    onPressed: () {
                      setState(() {
                        _showAddAthleteForm = !_showAddAthleteForm;
                        _showBroadcastCard = false;
                        _showCreateTeamForm = false;
                      });
                    },
                    variant: SporveButtonVariant.primary,
                    size: SporveButtonSize.compact,
                    fullWidth: false,
                    icon: Icons.add,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Broadcast popup card
              if (_showBroadcastCard) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Broadcast to all ${activeAthletes.length} athletes',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          border: Border.all(color: AppColors.hairline),
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _broadcastController,
                          maxLines: 4,
                          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type your announcement...',
                            hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SporveButton(
                              'Cancel',
                              variant: SporveButtonVariant.secondary,
                              onDark: true,
                              onPressed: () {
                                setState(() {
                                  _showBroadcastCard = false;
                                  _broadcastController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SporveButton(
                              'Send to all',
                              variant: SporveButtonVariant.primary,
                              onPressed: () {
                                final text = _broadcastController.text.trim();
                                if (text.isEmpty) return;
                                final n = context
                                    .read<ProviderController>()
                                    .sendBroadcast(text);
                                Get.snackbar(
                                  'Message sent',
                                  n > 0
                                      ? 'Delivered to $n athlete${n == 1 ? '' : 's'} on your roster.'
                                      : 'Saved to your roster feed.',
                                  backgroundColor: AppColors.surface,
                                  colorText: AppColors.textPrimary,
                                );
                                setState(() {
                                  _showBroadcastCard = false;
                                  _broadcastController.clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Create Team Form
              if (_showCreateTeamForm) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Team',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(label: 'Team Name', hint: 'e.g. Apex U18', controller: _teamNameController),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SporveButton(
                              'Cancel',
                              variant: SporveButtonVariant.secondary,
                              onDark: true,
                              onPressed: () {
                                setState(() {
                                  _showCreateTeamForm = false;
                                  _teamNameController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SporveButton(
                              'Create team',
                              variant: SporveButtonVariant.primary,
                              onPressed: () async {
                                if (_teamNameController.text.trim().isNotEmpty) {
                                  final teamName = _teamNameController.text.trim();
                                  final pc = context.read<ProviderController>();
                                  final success = await pc.createRosterTeam(teamName, 'Soccer');
                                  if (success) {
                                    setState(() {
                                      _showCreateTeamForm = false;
                                      _teamNameController.clear();
                                    });
                                    Get.snackbar(
                                      'Success',
                                      'Team created.',
                                      backgroundColor: AppColors.surface,
                                      colorText: AppColors.textPrimary,
                                    );
                                  } else {
                                    final newId = 'team_${DateTime.now().millisecondsSinceEpoch}';
                                    setState(() {
                                      _teams.add(CoachTeam(id: newId, name: teamName));
                                      _showCreateTeamForm = false;
                                      _teamNameController.clear();
                                    });
                                    Get.snackbar(
                                      'Local Fallback',
                                      'Team created locally!',
                                      backgroundColor: AppColors.surface,
                                      colorText: AppColors.textPrimary,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Add Athlete Form
              if (_showAddAthleteForm) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Athlete',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(label: 'Full name', hint: 'Alex Burton', controller: _nameController),
                      const SizedBox(height: 16),
                      _buildTextField(label: 'Email', hint: 'athlete@example.com', controller: _emailController),
                      const SizedBox(height: 16),
                      _buildTextField(label: 'Phone', hint: '(555) 000-0000', controller: _phoneController),
                      const SizedBox(height: 16),
                      _buildTeamDropdown(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SporveButton(
                              'Cancel',
                              variant: SporveButtonVariant.secondary,
                              onDark: true,
                              onPressed: () {
                                setState(() {
                                  _showAddAthleteForm = false;
                                  _nameController.clear();
                                  _emailController.clear();
                                  _phoneController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SporveButton(
                              'Add athlete',
                              variant: SporveButtonVariant.primary,
                              onPressed: () {
                                if (_nameController.text.trim().isNotEmpty && _emailController.text.trim().isNotEmpty) {
                                  setState(() {
                                    _athletes.add({
                                      'id': DateTime.now().millisecondsSinceEpoch,
                                      'name': _nameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'jersey': '',
                                      'imageUrl': '',
                                      'isAvailable': true,
                                      'isPaid': false,
                                      'teamId': _selectedInitialTeamId,
                                    });
                                    _showAddAthleteForm = false;
                                    _nameController.clear();
                                    _emailController.clear();
                                    _phoneController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // First real load in flight → skeleton (no mock content, no blank).
              if (!pc.rosterLoaded)
                ..._buildRosterSkeleton()
              // Loaded with no athletes → honest empty state.
              else if (activeAthletes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No athletes on your roster yet.',
                      style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),

              // Collapsible Accordion Sections per Team (only once real data is in).
              if (pc.rosterLoaded && activeAthletes.isNotEmpty)
                ...activeTeams.map((team) {
                final teamPlayers = activeAthletes.where((a) {
                  final matchesTeam = a['teamId'] == team.id;
                  if (_searchQuery.isEmpty) return matchesTeam;
                  final matchesSearch = a['name'].toString().toLowerCase().contains(_searchQuery) ||
                      a['email'].toString().toLowerCase().contains(_searchQuery);
                  return matchesTeam && matchesSearch;
                }).toList();

                if (teamPlayers.isEmpty && _searchQuery.isNotEmpty) {
                  return const SizedBox.shrink();
                }

                final bool isExpanded = _teamExpanded[team.id] ?? true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Section Header
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _teamExpanded[team.id] = !isExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              team.name.toUpperCase(),
                              style: AppTypography.font(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${teamPlayers.length}',
                                style: AppTypography.font(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Players List under this team
                    if (isExpanded) ...[
                      if (teamPlayers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 30, bottom: 20, top: 4),
                          child: Text(
                            'No players in this team yet.',
                            style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: teamPlayers.length,
                          itemBuilder: (context, index) {
                            final athlete = teamPlayers[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadii.card),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Avatar stack with jersey number
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            height: 48,
                                            width: 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.hairline, width: 1.5),
                                            ),
                                            child: SporveImage(
                                              athlete['imageUrl'],
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              radius: 24,
                                            ),
                                          ),
                                          if ((athlete['jersey'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Positioned(
                                              bottom: -2,
                                              right: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  athlete['jersey'].toString(),
                                                  style: AppTypography.font(
                                                    color: Colors.black,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              athlete['name'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.font(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              athlete['email'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.font(
                                                color: AppColors.textTertiary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Status Chips
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _buildStatusChip(
                                            text: athlete['isAvailable'] ? 'Available' : 'Away',
                                            color: athlete['isAvailable'] ? AppColors.successGreen : AppColors.negative,
                                          ),
                                          const SizedBox(height: 4),
                                          _buildStatusChip(
                                            text: athlete['isPaid'] ? 'Paid' : 'Unpaid',
                                            color: athlete['isPaid'] ? AppColors.successGreen : AppColors.warmAccent,
                                            isFilled: athlete['isPaid'],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Action buttons row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SporveButton(
                                          'Message',
                                          onPressed: () => Get.toNamed(AppRoutes.chatDetails, arguments: athlete['name']),
                                          variant: SporveButtonVariant.secondary,
                                          onDark: true,
                                          size: SporveButtonSize.compact,
                                          icon: Icons.chat_bubble_outline,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SporveButton(
                                          'History',
                                          onPressed: () => _showSessionsPopup(athlete['name']),
                                          variant: SporveButtonVariant.secondary,
                                          onDark: true,
                                          size: SporveButtonSize.compact,
                                          icon: Icons.history,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SporveButton(
                                          'Move',
                                          onPressed: () => _showMoveAthleteDialog(athlete),
                                          variant: SporveButtonVariant.secondary,
                                          onDark: true,
                                          size: SporveButtonSize.compact,
                                          icon: Icons.swap_horiz,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SporveIconButton(
                                        Icons.close,
                                        color: AppColors.negative,
                                        size: 44,
                                        iconSize: 18,
                                        onTap: () async {
                                          final athleteId = athlete['id'].toString();
                                          final teamId = athlete['teamId'].toString();
                                          final pc = context.read<ProviderController>();
                                          bool success = false;
                                          if (!athleteId.startsWith('temp_') && !athleteId.contains('images.unsplash.com') && athleteId.length > 5) {
                                            success = await pc.removeRosterAthlete(teamId, athleteId);
                                          }
                                          if (!success) {
                                            // Remove by identity from the local
                                            // store (no-op if it isn't there) —
                                            // never index into a different list.
                                            setState(() {
                                              _athletes.remove(athlete);
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                    const SizedBox(height: 12),
                  ],
                );
              }),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign Team',
          style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: AppColors.surface2,
              value: _selectedInitialTeamId,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              items: activeTeams.map((team) {
                return DropdownMenuItem<String>(
                  value: team.id,
                  child: Text(
                    team.name,
                    style: AppTypography.font(color: Colors.white, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedInitialTeamId = val;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            style: AppTypography.font(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required String text,
    required Color color,
    bool isFilled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFilled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFilled) ...[
            Container(
              height: 6,
              width: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: AppTypography.font(
              color: isFilled ? AppColors.onSlate : color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

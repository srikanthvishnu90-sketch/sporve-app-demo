import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:provider/provider.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../shared/controllers/chat_provider.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/shared_inbox_controller.dart';

/// Provider Model Rebuild — item #6 (c, deferred UI): the SHARED ORG INBOX —
/// every org thread, routed to the right trainer, with its already-drafted
/// ai_draft suggested reply surfaced. Reading org_inbox() (20260729_000620),
/// admin-gated at the DB.
///
/// Tapping a thread opens the EXISTING chat screen (`AppRoutes.chatDetails`)
/// where the coach-only ai_draft card + approve/edit/discard/send path
/// already lives (L-012: reuse the one pipeline, never a second send path) —
/// this screen never renders its own send affordance.
class ProviderSharedInboxScreen extends StatefulWidget {
  const ProviderSharedInboxScreen({super.key});

  @override
  State<ProviderSharedInboxScreen> createState() => _ProviderSharedInboxScreenState();
}

class _ProviderSharedInboxScreenState extends State<ProviderSharedInboxScreen> {
  late final SharedInboxController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SharedInboxController(context.read());
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SharedInboxController>.value(
      value: _controller,
      child: GradientScaffold(
        body: SafeArea(
          child: Consumer<SharedInboxController>(
            builder: (context, c, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _header(),
                const SizedBox(height: 16),
                Expanded(child: _body(c)),
              ],
            ),
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
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared inbox',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "YOUR ORG'S ROUTED THREADS",
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
          SporveIconButton(
            Icons.route_outlined,
            circle: true,
            iconSize: 18,
            semanticLabel: 'Route a conversation',
            onTap: () => _openRouteSheet(_controller),
          ),
        ],
      ),
    );
  }

  Widget _body(SharedInboxController c) {
    if (c.loading && c.threads.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slateText, strokeWidth: 2),
      );
    }
    if (c.error) {
      return ErrorRetry(
        message: "We couldn't load the shared inbox. Please try again.",
        onRetry: () => c.load(),
      );
    }
    if (c.threads.isEmpty) {
      // Non-admin and admin-with-nothing-routed look identical (the DB gate
      // decides, not this screen — same stance as the org grid / camp roster).
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'No routed threads yet',
        message: "Either your org has no threads routed to a service/trainer "
            "yet, or you're not an org admin. Tap the route icon above to "
            "assign an existing conversation to a service and trainer.",
        actionLabel: 'Route a conversation',
        onAction: () => _openRouteSheet(c),
      );
    }
    return RefreshIndicator(
      color: AppColors.slateText,
      backgroundColor: AppColors.surface,
      onRefresh: () => c.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        itemCount: c.threads.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _threadCard(c.threads[i]),
      ),
    );
  }

  Widget _threadCard(Map<String, dynamic> t) {
    final conversationId = (t['conversationId'] ?? '').toString();
    final parent = (t['parentFirstName'] ?? '').toString();
    final name = parent.isEmpty ? 'Parent' : parent;
    final serviceTitle = (t['serviceTitle'] ?? '').toString();
    final trainerName = (t['trainerName'] ?? 'Unassigned').toString();
    final lastMessage = (t['lastMessage'] ?? '').toString();
    final hasDraft = t['hasPendingDraft'] == true;
    final draftBody = (t['draftBody'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: conversationId.isEmpty
          ? null
          : () => Get.toNamed(AppRoutes.chatDetails, arguments: {
                'conversationId': conversationId,
                'contactName': name,
                'avatarUrl': '',
              }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: hasDraft ? AppColors.slateBorder : AppColors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasDraft) _draftBadge(),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (serviceTitle.isNotEmpty) _tag(Icons.design_services_outlined, serviceTitle),
                _tag(Icons.person_outline, 'Routed to $trainerName'),
              ],
            ),
            if (lastMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                lastMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
            if (hasDraft && draftBody.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.slateTint,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.slateBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: AppColors.slateText),
                        const SizedBox(width: 6),
                        Text(
                          'DRAFT READY — REVIEW TO SEND',
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      draftBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _draftBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slateTint,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        'DRAFT',
        style: AppTypography.font(
          color: AppColors.slateText,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.hairlineSoft,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Route an existing conversation to a service/trainer ──────────────────
  Future<void> _openRouteSheet(SharedInboxController controller) async {
    final chat = context.read<ChatProvider>();
    final repo = context.read<AppRepository>();
    if (chat.conversations.isEmpty) {
      await chat.loadConversations();
    }
    final conversations = chat.conversations;
    if (!mounted) return;
    if (conversations.isEmpty) {
      Get.snackbar(
        'No conversations',
        'There are no conversations to route yet.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface2,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    List<Map<String, dynamic>> services = [];
    List<Map<String, dynamic>> members = [];
    try {
      services = await repo.getMyServices();
      members = await repo.getOrgMembers();
    } catch (e) {
      debugPrint('_openRouteSheet load failed: $e');
    }
    if (!mounted) return;

    String? conversationId = conversations.first['_id']?.toString();
    String? serviceId;
    String? memberId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route a conversation',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assign a thread to a service and (optionally) a specific '
                      'trainer. A group/camp service with one staffed trainer '
                      'auto-routes; a private service always needs one named.',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetDropdown<String>(
                      label: 'CONVERSATION',
                      value: conversationId,
                      items: [
                        for (final c in conversations)
                          if (c['_id'] != null)
                            DropdownMenuItem<String>(
                              value: c['_id'].toString(),
                              child: Text(
                                _conversationLabel(c, chat.currentUserId),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                      onChanged: (v) => setSheet(() => conversationId = v),
                    ),
                    const SizedBox(height: 14),
                    _sheetDropdown<String?>(
                      label: 'SERVICE (OPTIONAL)',
                      value: serviceId,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('None')),
                        for (final s in services)
                          DropdownMenuItem<String?>(
                            value: s['_id']?.toString(),
                            child: Text(
                              (s['title'] ?? 'Untitled').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setSheet(() => serviceId = v),
                    ),
                    const SizedBox(height: 14),
                    _sheetDropdown<String?>(
                      label: 'TRAINER (OPTIONAL — LEAVE BLANK TO AUTO-ROUTE)',
                      value: memberId,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Auto / unassigned')),
                        for (final m in members)
                          DropdownMenuItem<String?>(
                            value: m['id']?.toString(),
                            child: Text(
                              ((m['trainer_profile'] as Map?)?['display_name'] ??
                                      m['name'] ??
                                      'Trainer')
                                  .toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setSheet(() => memberId = v),
                    ),
                    const SizedBox(height: 20),
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
                        onPressed: conversationId == null
                            ? null
                            : () async {
                                final navigator = Navigator.of(sheetCtx);
                                final ok = await controller.route(
                                  conversationId: conversationId!,
                                  serviceId: serviceId,
                                  memberId: memberId,
                                );
                                if (navigator.mounted) navigator.pop();
                                if (!mounted) return;
                                Get.snackbar(
                                  ok ? 'Routed' : "Couldn't route",
                                  ok
                                      ? 'The thread is now routed.'
                                      : 'Please try again.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: AppColors.surface2,
                                  colorText: AppColors.textPrimary,
                                );
                              },
                        child: Text(
                          'Route thread',
                          style: AppTypography.font(
                            color: AppColors.onSlate,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: AppColors.surface2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: AppColors.hairlineStrong),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary, size: 20),
                style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _conversationLabel(dynamic conv, String? currentUserId) {
    final participants = conv['participants'];
    if (participants is List) {
      for (final p in participants) {
        if (p is Map && p['_id'] != currentUserId) {
          final first = (p['firstName'] ?? '').toString();
          final last = (p['lastName'] ?? '').toString();
          final name = '$first $last'.trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return (conv['_id'] ?? 'Conversation').toString();
  }
}

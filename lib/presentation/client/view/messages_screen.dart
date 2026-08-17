import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/session_time.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_image.dart';
import '../../shared/controllers/chat_provider.dart';
import '../controllers/home_controller.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _activeTab = 'DIRECT'; // 'DIRECT' or 'PROGRAMS'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  Map<String, dynamic>? _getRecipient(
    dynamic conversation,
    String? currentUserId,
  ) {
    final participants = conversation['participants'];
    if (participants is List && participants.isNotEmpty) {
      for (var p in participants) {
        if (p is Map && p['_id'] != currentUserId) {
          return Map<String, dynamic>.from(p);
        }
      }
      return Map<String, dynamic>.from(participants[0]);
    }
    return null;
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0 && dateTime.day == now.day) {
        final hourRaw = dateTime.hour;
        final hour = hourRaw == 0
            ? 12
            : (hourRaw > 12 ? hourRaw - 12 : hourRaw);
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final amPm = hourRaw >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $amPm';
      } else if (difference.inDays < 7) {
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[dateTime.weekday - 1];
      } else {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[dateTime.month - 1]} ${dateTime.day}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;
    final currentUserId = chatProvider.currentUserId;
    final isLoading = chatProvider.isLoadingConversations;

    // Filter conversations:
    final directConvs = conversations.where((c) {
      final isProgram = c['programId'] != null || c['program'] != null;
      return !isProgram;
    }).toList();

    final programConvs = conversations.where((c) {
      final isProgram = c['programId'] != null || c['program'] != null;
      return isProgram;
    }).toList();

    // Calculate total unread count
    int totalUnread = 0;
    for (var c in conversations) {
      if (c['unreadCount'] is int) {
        totalUnread += c['unreadCount'] as int;
      }
    }

    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and red badge row
                  Row(
                    children: [
                      // Back arrow ONLY when this screen was pushed (e.g. from the
                      // Home "Message" button) — as the Messages tab it can't pop,
                      // so no arrow shows. Ensures you can always get back out.
                      if (Navigator.of(context).canPop()) ...[
                        SporveIconButton(
                          Icons.arrow_back,
                          semanticLabel: 'Back',
                          onTap: () => Navigator.of(context).maybePop(),
                          size: 40,
                          iconSize: 22,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        'Messages',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (totalUnread > 0) ...[
                        const SizedBox(width: 8),
                        // Slate unread count badge
                        Container(
                          height: 20,
                          width: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.slateText,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$totalUnread',
                            style: AppTypography.font(
                              color: AppColors.onSlate,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Plus Action Button
                  SporveIconButton(
                    Icons.add,
                    semanticLabel: 'New message',
                    onTap: _showNewChatSheet,
                    size: 40,
                    iconSize: 20,
                    filled: true,
                  ),
                ],
              ),
            ),

            // 2. TAB SWITCHER (DIRECT vs PROGRAMS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SporveSegmented(
                segments: const ['DIRECT', 'PROGRAMS'],
                selected: _activeTab == 'DIRECT' ? 0 : 1,
                onChanged: (i) {
                  setState(() {
                    _activeTab = i == 0 ? 'DIRECT' : 'PROGRAMS';
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // 3. CONVERSATIONS LIST
            Expanded(
              child: RefreshIndicator(
                color: AppColors.slateText,
                backgroundColor: AppColors.surface,
                onRefresh: () => chatProvider.loadConversations(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child:
                      (chatProvider.conversationsError && conversations.isEmpty)
                      ? ErrorRetry(
                          message:
                              "We couldn't load your messages. Check your connection and try again.",
                          onRetry: () => chatProvider.loadConversations(),
                        )
                      : (_activeTab == 'DIRECT'
                            ? _buildDirectList(
                                directConvs,
                                currentUserId,
                                isLoading,
                              )
                            : _buildProgramsList(
                                programConvs,
                                currentUserId,
                                isLoading,
                              )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DIRECT LIST ---
  Widget _buildDirectList(
    List<dynamic> convs,
    String? currentUserId,
    bool isLoading,
  ) {
    if (isLoading && convs.isEmpty) {
      return const Center(child: SkeletonList());
    }
    if (convs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 32),
          EmptyState(
            icon: Icons.forum_outlined,
            title: 'No messages yet',
            message: 'Message a coach from their program to start a chat.',
            actionLabel: 'Find a coach',
            onAction: () => Get.toNamed(AppRoutes.search),
          ),
        ],
      );
    }
    return ListView.builder(
      key: const ValueKey('DIRECT'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: convs.length,
      itemBuilder: (context, index) {
        final conv = convs[index];
        final recipient = _getRecipient(conv, currentUserId);
        final String name = recipient != null
            ? '${recipient['firstName'] ?? ''} ${recipient['lastName'] ?? ''}'
            : 'Chat';
        final String avatar = recipient != null
            ? (recipient['profileImage'] ?? '')
            : '';
        final lastMessage = conv['lastMessage'];
        final String lastMsg =
            (lastMessage is Map ? lastMessage['text'] : null) ?? 'No messages yet';
        final String time = _formatDateTime(
            lastMessage is Map ? lastMessage['createdAt'] : null);
        final String conversationId = conv['_id'] ?? '';
        final int unreadCount = conv['unreadCount'] is int
            ? conv['unreadCount'] as int
            : 0;

        return Column(
          children: [
            _buildMessageRow(
              title: name,
              subtitle: lastMsg,
              time: time,
              imageUrl: avatar,
              isOnline: false,
              unreadCount: unreadCount,
              onTap: () => _openDirectChat(conversationId, name, avatar),
            ),
            if (index < convs.length - 1) _buildDivider(),
          ],
        );
      },
    );
  }

  // --- TAB 2: PROGRAMS LIST ---
  Widget _buildProgramsList(
    List<dynamic> convs,
    String? currentUserId,
    bool isLoading,
  ) {
    if (isLoading && convs.isEmpty) {
      return const Center(child: SkeletonList());
    }
    if (convs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 32),
          EmptyState(
            icon: Icons.forum_outlined,
            title: 'No program chats yet',
            message: 'Booking a session opens a chat with that coach.',
            actionLabel: 'Browse programs',
            onAction: () => Get.toNamed(AppRoutes.search),
          ),
        ],
      );
    }
    return ListView.builder(
      key: const ValueKey('PROGRAMS'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: convs.length,
      itemBuilder: (context, index) {
        final conv = convs[index];
        final program = conv['program'];
        final String name = program != null
            ? (program['title'] ?? 'Program Chat')
            : 'Program Chat';
        final String avatar = program != null ? (program['image'] ?? '') : '';
        final lastMessage = conv['lastMessage'];
        final String lastMsg =
            (lastMessage is Map ? lastMessage['text'] : null) ?? 'No messages yet';
        final String time = _formatDateTime(
            lastMessage is Map ? lastMessage['createdAt'] : null);
        final String conversationId = conv['_id'] ?? '';
        final int unreadCount = conv['unreadCount'] is int
            ? conv['unreadCount'] as int
            : 0;

        return Column(
          children: [
            _buildMessageRow(
              title: name,
              subtitle: lastMsg,
              time: time,
              imageUrl: avatar,
              isOnline: false,
              unreadCount: unreadCount,
              onTap: () => _openDirectChat(conversationId, name, avatar),
            ),
            if (index < convs.length - 1) _buildDivider(),
          ],
        );
      },
    );
  }

  Widget _buildMessageRow({
    required String title,
    required String subtitle,
    required String time,
    required String imageUrl,
    required bool isOnline,
    int unreadCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // User Avatar with potential online status dot
            Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: SporveImage(
                      imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.person,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      height: 12,
                      width: 12,
                      decoration: BoxDecoration(
                        color: AppColors.successGreen, // active/online dot
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Text columns
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Time & Badge column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    height: 18,
                    width: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.slateText, // unread badge (slate chrome)
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$unreadCount',
                      style: AppTypography.font(
                        color: AppColors.onSlate,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Hairline();
  }

  void _openDirectChat(
    String conversationId,
    String contactName,
    String avatarUrl,
  ) {
    // Resolve upcoming session context with this coach so in-app chat is richer
    // than SMS (shows active child name + next session date/time).
    String athleteName = '';
    String nextSession = '';
    try {
      final home = context.read<HomeProvider>();
      for (final b in home.bookings) {
        if (b is! Map) continue;
        final program = b['programId'];
        final provider = program is Map ? program['providerId'] : null;
        final biz =
            provider is Map ? provider['businessName']?.toString() : null;
        if (biz != null &&
            biz.toLowerCase().trim() == contactName.toLowerCase().trim()) {
          final session = b['sessionId'] is Map ? b['sessionId'] : null;
          final start = parseSessionStart(session);
          if (!start.isBefore(DateTime.now())) {
            athleteName =
                (b['athleteName'] ?? b['athleteFirstName'] ?? '').toString();
            nextSession = '${start.month}/${start.day} · ${formatTime12h(start)}';
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to resolve upcoming session for message: $e');
    }

    Get.toNamed(
      AppRoutes.chatDetails,
      arguments: {
        'conversationId': conversationId,
        'contactName': contactName,
        'avatarUrl': avatarUrl,
        if (athleteName.isNotEmpty) 'athleteName': athleteName,
        if (nextSession.isNotEmpty) 'nextSession': nextSession,
      },
    );
  }

  /// Coach picker → starts (or reuses) a thread with the chosen business.
  void _showNewChatSheet() {
    final programs = context.read<HomeProvider>().programs;
    final Map<String, ({String ownerId, String sport})> businesses = {};
    for (final p in programs) {
      if (p is! Map) continue;
      final provider = p['providerId'];
      final biz = provider is Map ? provider['businessName']?.toString() : null;
      final ownerId = provider is Map ? provider['ownerId']?.toString() : null;
      if (biz == null || biz.isEmpty || ownerId == null || ownerId.isEmpty) {
        continue;
      }
      businesses.putIfAbsent(
        biz,
        () => (ownerId: ownerId, sport: (p['sportType'] ?? '').toString()),
      );
    }
    final entries = businesses.entries.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairlineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Message a coach',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No coaches to message yet',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Hairline(),
                itemBuilder: (_, i) {
                  final biz = entries[i].key;
                  final ownerId = entries[i].value.ownerId;
                  final sport = entries[i].value.sport;
                  return ListTile(
                    leading: SportIconTile(sport, size: 42),
                    title: Text(
                      biz,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onTap: () => _startChatWith(ctx, ownerId, biz),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChatWith(
    BuildContext sheetCtx,
    String providerOwnerId,
    String business,
  ) async {
    Navigator.of(sheetCtx).pop();
    final conv = await context.read<ChatProvider>().initiateConversation(
      providerOwnerId,
      recipientName: business,
    );
    if (!mounted || conv == null) return;
    _openDirectChat(conv['_id']?.toString() ?? '', business, '');
  }
}

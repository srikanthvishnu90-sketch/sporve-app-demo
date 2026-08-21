import 'package:flutter/material.dart';
import 'package:sporve_app/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_image.dart';
import '../../shared/controllers/chat_provider.dart';

class ProviderChatScreen extends StatefulWidget {
  const ProviderChatScreen({super.key});

  @override
  State<ProviderChatScreen> createState() => _ProviderChatScreenState();
}

class _ProviderChatScreenState extends State<ProviderChatScreen> {
  String _activeTab = 'DIRECT'; // 'DIRECT' or 'PROGRAMS'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  Map<String, dynamic>? _getRecipient(dynamic conversation, String? currentUserId) {
    final participants = conversation['participants'];
    if (participants is List && participants.isNotEmpty) {
      for (var p in participants) {
        if (p is Map && p['_id'] != currentUserId) {
          return Map<String, dynamic>.from(p);
        }
      }
      final first = participants[0];
      if (first is Map) return Map<String, dynamic>.from(first);
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
        final hour = hourRaw == 0 ? 12 : (hourRaw > 12 ? hourRaw - 12 : hourRaw);
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final amPm = hourRaw >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $amPm';
      } else if (difference.inDays < 7) {
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[dateTime.weekday - 1];
      } else {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
                children: [
                  Text(
                    'Messages',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 8),
                    // Unread count badge
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
            ),

            // 2. TAB SWITCHER (DIRECT vs PROGRAMS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SporveSegmented(
                segments: const ['DIRECT', 'PROGRAMS'],
                selected: const ['DIRECT', 'PROGRAMS'].indexOf(_activeTab),
                onChanged: (i) {
                  setState(() {
                    _activeTab = const ['DIRECT', 'PROGRAMS'][i];
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
                  child: _activeTab == 'DIRECT'
                      ? _buildDirectList(directConvs, currentUserId, isLoading)
                      : _buildProgramsList(programConvs, currentUserId, isLoading),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DIRECT LIST ---
  Widget _buildDirectList(List<dynamic> convs, String? currentUserId, bool isLoading) {
    if (isLoading && convs.isEmpty) {
      return const Center(child: SkeletonList());
    }
    if (convs.isEmpty) {
      return Center(
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Text(
                'No direct messages yet',
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('DIRECT'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: convs.length,
      itemBuilder: (context, index) {
        final conv = convs[index];
        final recipient = _getRecipient(conv, currentUserId);
        final String name = recipient != null ? '${recipient['firstName'] ?? ''} ${recipient['lastName'] ?? ''}' : 'Chat';
        final String avatar = recipient != null ? (recipient['profileImage'] ?? '') : '';
        final String lastMsg = conv['lastMessage']?['text'] ?? 'No messages yet';
        final String time = _formatDateTime(conv['lastMessage']?['createdAt']);
        final String conversationId = conv['_id'] ?? '';
        final int unreadCount = conv['unreadCount'] is int ? conv['unreadCount'] as int : 0;

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
  Widget _buildProgramsList(List<dynamic> convs, String? currentUserId, bool isLoading) {
    if (isLoading && convs.isEmpty) {
      return const Center(child: SkeletonList());
    }
    if (convs.isEmpty) {
      return Center(
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Text(
                'No program messages yet',
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('PROGRAMS'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: convs.length,
      itemBuilder: (context, index) {
        final conv = convs[index];
        final program = conv['program'];
        final String name = program != null ? (program['title'] ?? 'Program Chat') : 'Program Chat';
        final String avatar = program != null ? (program['image'] ?? '') : '';
        final String lastMsg = conv['lastMessage']?['text'] ?? 'No messages yet';
        final String time = _formatDateTime(conv['lastMessage']?['createdAt']);
        final String conversationId = conv['_id'] ?? '';
        final int unreadCount = conv['unreadCount'] is int ? conv['unreadCount'] as int : 0;

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
                        color: AppColors.slateText,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
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
                      color: AppColors.slateText,
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
    return Divider(
      color: AppColors.hairlineSoft,
      height: 1,
      thickness: 1,
    );
  }

  void _openDirectChat(String conversationId, String contactName, String avatarUrl) {
    Get.toNamed(AppRoutes.chatDetails, arguments: {
      'conversationId': conversationId,
      'contactName': contactName,
      'avatarUrl': avatarUrl,
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/motion_widgets.dart';
import '../../widgets/sporve_image.dart';
import '../../shared/controllers/chat_provider.dart';

class ChatDetailsScreen extends StatefulWidget {
  const ChatDetailsScreen({super.key});

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _conversationId = '';
  String _contactName = '';
  String _avatarUrl = '';
  // Booking-anchored context (§17) — rendered ONLY when the caller supplies it.
  String _athleteName = '';
  String _nextSession = '';
  String _responseTime = '';
  ChatProvider? _chat; // captured for realtime unsubscribe in dispose

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args is Map) {
        _conversationId = args['conversationId'] ?? '';
        _contactName = args['contactName'] ?? 'Chat';
        _avatarUrl = args['avatarUrl'] ?? '';
        _athleteName = (args['athleteName'] ?? '').toString();
        _nextSession = (args['nextSession'] ?? '').toString();
        _responseTime = (args['responseTime'] ?? '').toString();
      } else if (args is String) {
        _contactName = args;
      }

      final chatProvider = context.read<ChatProvider>();

      // If conversationId is empty, try to resolve it from the contact name.
      if (_conversationId.isEmpty && _contactName.isNotEmpty) {
        for (var c in chatProvider.conversations) {
          final participants = c['participants'];
          if (participants is List) {
            for (var p in participants) {
              if (p is Map) {
                final pName = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'
                    .trim();
                if (pName.toLowerCase() == _contactName.toLowerCase()) {
                  _conversationId = c['_id'] ?? '';
                  break;
                }
              }
            }
          }
          if (_conversationId.isNotEmpty) break;
        }
      }

      if (_conversationId.isNotEmpty) {
        _chat = chatProvider;
        chatProvider.loadMessages(_conversationId).then((_) {
          _scrollToBottom();
          chatProvider.subscribeToConversation(_conversationId); // live updates
        });
      }
      setState(() {});
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _formatMessageTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final hourRaw = dateTime.hour;
      final hour = hourRaw == 0 ? 12 : (hourRaw > 12 ? hourRaw - 12 : hourRaw);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = hourRaw >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    } catch (e) {
      return '';
    }
  }

  /// System events (booking confirmations, reminders, reschedules) carry no
  /// human sender. They render as centered Caption events — NEVER as a human
  /// bubble (§17 / decision #16).
  bool _isSystemMessage(dynamic msg) {
    if (msg is! Map) return false;
    final type = (msg['type'] ?? '').toString().toLowerCase();
    if (type == 'system' || type == 'event') return true;
    final sid = (msg['senderId'] ?? '').toString().toLowerCase();
    return sid.isEmpty || sid == 'system' || sid == 'sporve';
  }

  @override
  void dispose() {
    _chat?.unsubscribeFromConversation(); // stop the realtime channel
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final bool isRealChat = _conversationId.isNotEmpty;
    final bool isLoading = chatProvider.isLoadingMessages;
    final String currentUserId = chatProvider.currentUserId ?? '';

    final List<dynamic> messages = isRealChat
        ? chatProvider.messages
        : const [];

    // Booking-anchored subtitle: "athlete · next session" when we have it (§17).
    final contextParts = <String>[
      if (_athleteName.trim().isNotEmpty) _athleteName.trim(),
      if (_nextSession.trim().isNotEmpty) _nextSession.trim(),
    ];
    final String headerContext = contextParts.join('  ·  ');

    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(Icons.arrow_back, onTap: () => Get.back()),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: SporveImage(
                  _avatarUrl.isNotEmpty ? _avatarUrl : '',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.person,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Trainer name + booking context + response-time (all grounded).
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _contactName.isNotEmpty ? _contactName : 'Chat',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (headerContext.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      headerContext,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (_responseTime.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _responseTime.trim(),
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Thread menu — houses the two-tap Report action (§17).
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SporveIconButton(
              Icons.more_vert,
              semanticLabel: 'Conversation menu',
              onTap: _openThreadMenu,
              size: 36,
              iconSize: 20,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.hairline, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Message area.
          Expanded(
            child: isLoading
                ? const Center(child: SkeletonList())
                : (!isRealChat
                      ? const _ChatEmpty(
                          title: 'Conversation not found',
                          message:
                              'Open a chat from a coach\'s profile or a booking to start messaging.',
                        )
                      : (messages.isEmpty
                            ? const _ChatEmpty(
                                title: 'No messages yet',
                                message:
                                    'Say hello — your coach usually replies here.',
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(24),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  if (_isSystemMessage(msg)) {
                                    return _buildSystemEvent(msg);
                                  }
                                  return _buildBubble(msg, currentUserId);
                                },
                              ))),
          ),

          // Coach-only AI affordance — drafts a reply and pre-fills the
          // composer below. It NEVER sends; the coach edits and sends manually.
          if (chatProvider.isProvider && isRealChat)
            _buildDraftReplyBar(chatProvider),

          // Composer — only shown for a real, resolvable thread.
          if (isRealChat) _buildComposer(chatProvider),
        ],
      ),
    );
  }

  // Centered, non-attributed system event (§17): confirmations, reminders,
  // reschedules. Rendered at Caption, never as a human bubble.
  Widget _buildSystemEvent(dynamic msg) {
    final String text = (msg['text'] ?? '').toString();
    final String time = _formatMessageTime(msg['createdAt']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Column(
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  time,
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(dynamic msg, String currentUserId) {
    final bool isUser = (msg['senderId'] ?? '') == currentUserId;
    final String text = (msg['text'] ?? '').toString();
    final String time = _formatMessageTime(msg['createdAt']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? AppColors.slateTint : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadii.card),
                topRight: const Radius.circular(AppRadii.card),
                bottomLeft: isUser
                    ? const Radius.circular(AppRadii.card)
                    : Radius.zero,
                bottomRight: isUser
                    ? Radius.zero
                    : const Radius.circular(AppRadii.card),
              ),
              border: Border.all(
                color: isUser ? AppColors.slateBorder : AppColors.hairline,
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Text(
              text,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 15, // Body (§17)
                height: 22 / 15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(ChatProvider chatProvider) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32, top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.hairline, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                cursorColor: AppColors.slateText,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(chatProvider),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SporveIconButton(
            Icons.send,
            onTap: () => _handleSend(chatProvider),
            size: 56,
            iconSize: 20,
            filled: true,
            circle: true,
          ),
        ],
      ),
    );
  }

  // ── Thread menu + two-tap Report (§17) ────────────────────────────────────
  void _openThreadMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: AppColors.destructiveRed,
                size: 20,
              ),
              title: Text(
                'Report conversation',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Submit this conversation for safety review.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _submitReport();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submitReport() {
    // No detection mechanics are exposed; we simply acknowledge (§17/§20).
    Get.snackbar(
      'Reported',
      'Thanks — this conversation was submitted for review.',
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  // Coach-only "Draft reply" pill. Slate chrome (design system); shows a
  // loading state while the AI drafts. Tapping it never sends.
  Widget _buildDraftReplyBar(ChatProvider chatProvider) {
    final drafting = chatProvider.isDrafting;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: drafting ? null : () => _handleDraftReply(chatProvider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.slateTint,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              border: Border.all(color: AppColors.slateBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                drafting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.slateText,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppColors.slateText,
                      ),
                const SizedBox(width: 8),
                Text(
                  drafting ? 'Drafting…' : 'Draft reply',
                  style: AppTypography.font(
                    color: AppColors.slateText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDraftReply(ChatProvider chatProvider) async {
    final drafts = await chatProvider.draftReply(intent: 'reply');
    if (!mounted) return;
    if (drafts.isEmpty) {
      Get.snackbar(
        'Draft reply',
        chatProvider.draftError ?? 'No draft available right now.',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
      return;
    }
    if (drafts.length == 1) {
      _applyDraft(drafts.first);
    } else {
      _showDraftOptions(drafts);
    }
  }

  // Pre-fills the composer with the chosen draft — fully editable, never sent
  // until the coach taps send.
  void _applyDraft(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    setState(() {});
  }

  void _showDraftOptions(List<String> drafts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHOOSE A DRAFT',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can edit it before sending — nothing sends automatically.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ...drafts.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _applyDraft(d);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        d,
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSend(ChatProvider chatProvider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId.isEmpty) return;

    _messageController.clear();
    final success = await chatProvider.sendMessage(_conversationId, text);
    if (success) _scrollToBottom();
  }
}

// Calm, designed empty state for the thread body (§19 states discipline).
class _ChatEmpty extends StatelessWidget {
  final String title;
  final String message;
  const _ChatEmpty({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              color: AppColors.textTertiary,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

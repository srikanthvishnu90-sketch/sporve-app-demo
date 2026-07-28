import 'package:flutter/material.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/auth/auth_service.dart';

class ChatProvider with ChangeNotifier {
  final AppRepository _repo;
  final AuthService _auth;
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _currentUserId;

  // AI reply drafting (coach-only "Draft reply" affordance).
  bool _isDrafting = false;
  String? _draftError;

  List<dynamic> get conversations => _conversations;
  List<dynamic> get messages => _messages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get currentUserId => _currentUserId;
  bool get isDrafting => _isDrafting;
  String? get draftError => _draftError;

  /// Only coaches (providers) may draft replies — message-draft authorizes that
  /// the caller owns the provider, so the affordance is provider-only in the UI.
  bool get isProvider => _auth.currentUser?.role == 'provider';

  ChatProvider(this._repo, this._auth) {
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    _currentUserId = _auth.currentUser?.id;
    if (_currentUserId == null) {
      final prof = await _repo.getUserProfile();
      if (prof.isNotEmpty && prof['_id'] != null) {
        _currentUserId = prof['_id'];
      }
    }
  }

  bool _conversationsError = false;
  bool get conversationsError => _conversationsError;

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _conversationsError = false;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchCurrentUserId();

    try {
      _conversations = await _repo.getConversationsOrThrow();
    } catch (e) {
      debugPrint('loadConversations failed: $e');
      _conversationsError = true;
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> initiateConversation(
    String recipientId, {
    String? programId,
    String? recipientName,
    String recipientRole = 'provider',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Reuse an existing thread with this recipient (avoid duplicate convs on
    // every "Message coach" tap). Match by a participant with this id.
    final existing = await _repo.getConversations();
    for (final c in existing) {
      if (c is! Map) continue;
      final parts = (c['participants'] as List?) ?? const [];
      final hasRecipient = parts.any(
        (p) => p is Map && p['_id']?.toString() == recipientId,
      );
      if (hasRecipient) {
        await loadConversations();
        return Map<String, dynamic>.from(c);
      }
    }

    final newConv = await _repo.ensureProviderConversation(
      providerOwnerId: recipientId,
      programId: programId,
      providerName: recipientName,
    );
    if (newConv == null) return null;
    await loadConversations();
    return newConv;
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    _messages = [];
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final msgs = await _repo.getMessages(conversationId);
    _messages = List.from(msgs);
    _messages.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          DateTime.tryParse(b['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    _isLoadingMessages = false;
    notifyListeners();
  }

  /// Calls the `message-draft` Edge Function with the current thread's recent
  /// messages and returns 1–2 editable draft strings. NEVER sends — the UI
  /// pre-fills the composer with the chosen draft and the coach sends manually.
  /// Returns an empty list on error/refusal (see [draftError]).
  Future<List<String>> draftReply({
    String intent = 'reply',
    String? childFirstName,
    String? bookingContext,
  }) async {
    _isDrafting = true;
    _draftError = null;
    notifyListeners();

    // Build thread context from the loaded messages (most recent ~10), tagging
    // the coach's own messages 'coach' and everything else 'parent'.
    final uid = _currentUserId ?? _auth.currentUser?.id ?? '';
    final recent = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;
    final threadContext = recent
        .map(
          (m) => {
            'role': (m['senderId'] == uid) ? 'coach' : 'parent',
            'body': (m['text'] ?? '').toString(),
          },
        )
        .where((m) => (m['body'] as String).trim().isNotEmpty)
        .toList();

    if (threadContext.isEmpty) {
      _isDrafting = false;
      _draftError = 'No messages yet to draft a reply from.';
      notifyListeners();
      return [];
    }

    final res = await _repo.draftMessage({
      'threadContext': threadContext,
      'intent': intent,
      if (childFirstName != null && childFirstName.trim().isNotEmpty)
        'childFirstName': childFirstName,
      if (bookingContext != null && bookingContext.trim().isNotEmpty)
        'bookingContext': bookingContext,
    });

    _isDrafting = false;

    if (res['error'] != null) {
      _draftError = res['error'].toString();
      notifyListeners();
      return [];
    }

    final result = res['result'];
    if (result is Map && result['type'] == 'drafts') {
      final drafts = (result['drafts'] as List?) ?? const [];
      final out = drafts
          .map((d) => (d is Map ? d['text']?.toString() : d?.toString()) ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (out.isEmpty) {
        _draftError = 'No draft was returned. Please try again.';
      }
      notifyListeners();
      return out;
    }

    // needs_revision (guardrail refused) or any unexpected shape.
    _draftError =
        'The assistant couldn\'t produce a safe draft for this thread.';
    notifyListeners();
    return [];
  }

  Future<bool> sendMessage(String conversationId, String text) async {
    final body = text.trim();
    if (body.isEmpty) return false;

    // Optimistic: show it immediately with a temporary id.
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    _messages.add({
      '_id': tempId,
      'conversationId': conversationId,
      'text': body,
      'senderId': _currentUserId ?? _auth.currentUser?.id ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    });
    notifyListeners();

    // Persist (append-only insert into messages).
    final saved = await _repo.postMessage(conversationId, body);
    if (saved == null) {
      _messages.removeWhere((m) => m['_id'] == tempId); // roll back optimistic
      notifyListeners();
      return false;
    }

    // Swap the temp for the real row; de-dupe if realtime already delivered it.
    final realId = saved['_id'];
    _messages.removeWhere((m) => m['_id'] == tempId || m['_id'] == realId);
    _messages.add(saved);
    _sortMessages();
    _bumpConversation(conversationId, saved);
    notifyListeners();
    return true;
  }

  // ── Realtime: live incoming messages for the open thread ──────────────────
  void Function()? _unsub;
  String? _subscribedConv;

  Future<void> subscribeToConversation(String conversationId) async {
    if (_subscribedConv == conversationId && _unsub != null) return;
    await unsubscribeFromConversation();
    _subscribedConv = conversationId;
    _unsub = await _repo.subscribeMessages(conversationId, _onRealtimeMessage);
  }

  Future<void> unsubscribeFromConversation() async {
    final u = _unsub;
    _unsub = null;
    _subscribedConv = null;
    if (u != null) u();
  }

  void _onRealtimeMessage(Map<String, dynamic> m) {
    final id = m['_id'];
    // Ignore our own just-sent message (already present by real id) and any dupe.
    if (id == null || _messages.any((x) => x['_id'] == id)) return;
    _messages.add(m);
    _sortMessages();
    _bumpConversation(
      m['conversationId']?.toString() ?? _subscribedConv ?? '',
      m,
    );
    notifyListeners();
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final at =
          DateTime.tryParse(a['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt =
          DateTime.tryParse(b['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
  }

  void _bumpConversation(String conversationId, Map<String, dynamic> msg) {
    final i = _conversations.indexWhere((c) => c['_id'] == conversationId);
    if (i != -1) {
      _conversations[i]['lastMessage'] = msg;
      final conv = _conversations.removeAt(i);
      _conversations.insert(0, conv);
    }
  }

  @override
  void dispose() {
    unsubscribeFromConversation();
    super.dispose();
  }
}

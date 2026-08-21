// Verifies the chat data path: optimistic send -> real persistence (postMessage),
// and realtime delivery with de-dupe (our own echo ignored, others appended).
//   flutter test test/chat_realtime_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sporve_app/core/auth/auth_service.dart';
import 'package:sporve_app/core/auth/app_user.dart';
import 'package:sporve_app/core/data/app_repository.dart';
import 'package:sporve_app/presentation/shared/controllers/chat_provider.dart';

class _FakeRepo implements AppRepository {
  final List<dynamic> store = [];
  final List<dynamic> conversations = [
    <String, dynamic>{'_id': 'conv_1', 'lastMessage': null},
  ];
  void Function(Map<String, dynamic>)? _cb;
  void emit(Map<String, dynamic> m) => _cb?.call(m);

  @override
  Future<Map<String, dynamic>> getUserProfile() async => {'_id': 'me'};
  @override
  Future<List<dynamic>> getMessages(String c) async => List.from(store);
  @override
  Future<List<dynamic>> getConversations() async => conversations;
  @override
  Future<List<dynamic>> getConversationsOrThrow() async => conversations;
  @override
  Future<Map<String, dynamic>?> ensureProviderConversation({
    required String providerOwnerId,
    String? programId,
    String? providerName,
  }) async {
    final conversation = <String, dynamic>{
      '_id': 'persisted-conversation',
      'programId': programId,
      'participants': [
        {'_id': 'me', 'role': 'searcher'},
        {'_id': providerOwnerId, 'role': 'provider'},
      ],
      'lastMessage': null,
    };
    conversations.insert(0, conversation);
    return conversation;
  }

  @override
  Future<Map<String, dynamic>?> postMessage(String c, String body) async {
    final m = {
      '_id': 'real-${store.length}',
      'conversationId': c,
      'text': body,
      'senderId': 'me',
      'createdAt': '2026-06-28T10:0${store.length}:00Z',
    };
    store.add(m);
    return m;
  }

  @override
  Future<void Function()> subscribeMessages(
    String c,
    void Function(Map<String, dynamic>) onMessage,
  ) async {
    _cb = onMessage;
    return () => _cb = null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A repo whose write (postMessage) fails — either by returning null or by
/// throwing (offline / network drop). Proves a failed write never reports
/// success and never leaves a fake "sent" bubble.
class _FailingWriteRepo extends _FakeRepo {
  _FailingWriteRepo({this.throwOnPost = false});
  final bool throwOnPost;

  @override
  Future<Map<String, dynamic>?> postMessage(String c, String body) async {
    if (throwOnPost) {
      throw Exception('network down');
    }
    return null; // write did not land
  }
}

/// AI Front Office #8/#9 — a fake repo that resolves drafts against an
/// in-memory `messages`-like store and logs one `draft_feedback`-shaped row
/// per action, mirroring the real `resolve_draft` RPC / MockRepository.
class _DraftRepo extends _FakeRepo {
  final List<Map<String, dynamic>> feedback = [];

  void seedDraft(Map<String, dynamic> draft) => store.add(draft);

  @override
  Future<bool> resolveDraft({
    required String draftId,
    required String action,
    String? finalText,
  }) async {
    final i = store.indexWhere(
      (m) => m is Map && m['_id']?.toString() == draftId,
    );
    if (i == -1) return false;
    final draft = Map<String, dynamic>.from(store[i] as Map);
    if ((draft['status'] ?? '') != 'ai_draft') return false;

    final originalText = (draft['text'] ?? '').toString();
    String? finalBody;
    if (action == 'discarded') {
      draft['status'] = 'discarded';
    } else {
      finalBody = action == 'edited' ? (finalText ?? '').trim() : originalText;
      if (finalBody.isEmpty) return false;
      draft['status'] = 'sent';
      draft['visibleToParent'] = true;
      draft['text'] = finalBody;
    }
    store[i] = draft;
    feedback.add({
      'draftId': draftId,
      'action': action,
      'originalText': originalText,
      'finalText': finalBody,
    });
    return true;
  }
}

/// A repo whose resolveDraft always fails (offline / server error) — proves
/// the honest-failure path (L-015): no state mutated, no feedback logged.
class _FailingDraftRepo extends _DraftRepo {
  @override
  Future<bool> resolveDraft({
    required String draftId,
    required String action,
    String? finalText,
  }) async => false;
}

class _FakeAuth implements AuthService {
  @override
  AppUser? get currentUser => const AppUser(id: 'me', role: 'searcher');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'persist via postMessage; realtime appends others, de-dupes own echo',
    () async {
      final repo = _FakeRepo();
      final chat = ChatProvider(repo, _FakeAuth());
      await chat.loadMessages('conv_1');
      await chat.subscribeToConversation('conv_1');

      // send -> persisted; optimistic temp swapped for the real row
      expect(await chat.sendMessage('conv_1', 'hello'), true);
      expect(chat.messages.length, 1);
      expect(chat.messages.last['text'], 'hello');
      final sentId = chat.messages.last['_id'];

      // realtime echoes OUR OWN message (same id) -> ignored (no duplicate)
      repo.emit({
        '_id': sentId,
        'conversationId': 'conv_1',
        'text': 'hello',
        'senderId': 'me',
        'createdAt': '2026-06-28T10:00:00Z',
      });
      expect(chat.messages.length, 1, reason: 'own echo de-duped');

      // realtime delivers the OTHER participant's message -> appended live
      repo.emit({
        '_id': 'remote-1',
        'conversationId': 'conv_1',
        'text': 'hi back',
        'senderId': 'them',
        'createdAt': '2030-01-01T00:00:00Z',
      });
      expect(chat.messages.length, 2);
      expect(chat.messages.last['text'], 'hi back');

      // a duplicate of the remote message is ignored too
      repo.emit({
        '_id': 'remote-1',
        'conversationId': 'conv_1',
        'text': 'hi back',
        'senderId': 'them',
        'createdAt': '2030-01-01T00:00:00Z',
      });
      expect(chat.messages.length, 2, reason: 'duplicate remote de-duped');
    },
  );

  test('failed message write reports failure, not success (null return)',
      () async {
    final repo = _FailingWriteRepo();
    final chat = ChatProvider(repo, _FakeAuth());
    await chat.loadMessages('conv_1');

    final ok = await chat.sendMessage('conv_1', 'hello');

    expect(ok, false, reason: 'a write that did not land must return false');
    expect(chat.messages, isEmpty,
        reason: 'optimistic bubble rolled back — nothing looks sent');
  });

  test('thrown message write (offline) reports failure, not success', () async {
    final repo = _FailingWriteRepo(throwOnPost: true);
    final chat = ChatProvider(repo, _FakeAuth());
    await chat.loadMessages('conv_1');

    final ok = await chat.sendMessage('conv_1', 'hello');

    expect(ok, false, reason: 'a thrown write must be caught and return false');
    expect(chat.messages, isEmpty,
        reason: 'optimistic bubble rolled back — no fake "sent" message');
  });

  test('new provider thread returns a persisted backend identity', () async {
    final repo = _FakeRepo();
    final chat = ChatProvider(repo, _FakeAuth());

    final conversation = await chat.initiateConversation(
      'provider-profile-uuid',
      programId: 'program-uuid',
      recipientName: 'Coach Jordan',
    );

    expect(conversation?['_id'], 'persisted-conversation');
    expect(
      (conversation?['participants'] as List).last['_id'],
      'provider-profile-uuid',
    );
    expect(
      repo.conversations.where(
        (item) => item is Map && item['_id'] == 'persisted-conversation',
      ),
      hasLength(1),
    );
  });

  // ── AI Front Office #8/#9 — the coach's two buttons + edit logging ───────
  group('resolveDraft (Suggested reply: send / edit / discard)', () {
    test('sent_as_is flips the draft to sent+visible and logs feedback', () async {
      final repo = _DraftRepo();
      repo.seedDraft({
        '_id': 'draft-1',
        'conversationId': 'conv_1',
        'text': "Thanks for reaching out — I'll confirm shortly.",
        'senderId': 'me',
        'createdAt': '2026-07-28T10:00:00Z',
        'status': 'ai_draft',
        'visibleToParent': false,
      });
      final chat = ChatProvider(repo, _FakeAuth());
      await chat.loadMessages('conv_1');

      expect(chat.pendingDrafts, hasLength(1));

      final ok = await chat.resolveDraft(draftId: 'draft-1', action: 'sent_as_is');

      expect(ok, true);
      expect(chat.pendingDrafts, isEmpty, reason: 'no longer a pending draft');
      final resolved = chat.messages.firstWhere((m) => m['_id'] == 'draft-1');
      expect(resolved['status'], 'sent');
      expect(resolved['visibleToParent'], true);

      // #9 — feedback logged exactly once, with matching original/final text.
      expect(repo.feedback, hasLength(1));
      expect(repo.feedback.single['action'], 'sent_as_is');
      expect(
        repo.feedback.single['originalText'],
        "Thanks for reaching out — I'll confirm shortly.",
      );
      expect(
        repo.feedback.single['finalText'],
        repo.feedback.single['originalText'],
        reason: 'sent as-is: original and final text match',
      );
    });

    test(
      'edited sends the coach\'s edit and logs BOTH the original AI text and the final edited text',
      () async {
        final repo = _DraftRepo();
        repo.seedDraft({
          '_id': 'draft-2',
          'conversationId': 'conv_1',
          'text': 'Sessions are \$40 each, Tuesdays at 5pm.',
          'senderId': 'me',
          'createdAt': '2026-07-28T10:05:00Z',
          'status': 'ai_draft',
          'visibleToParent': false,
        });
        final chat = ChatProvider(repo, _FakeAuth());
        await chat.loadMessages('conv_1');

        final ok = await chat.resolveDraft(
          draftId: 'draft-2',
          action: 'edited',
          finalText: 'Sessions are \$45 each, Tuesdays at 5:30pm — let me know!',
        );

        expect(ok, true);
        final resolved = chat.messages.firstWhere((m) => m['_id'] == 'draft-2');
        expect(resolved['status'], 'sent');
        expect(resolved['visibleToParent'], true);
        expect(
          resolved['text'],
          'Sessions are \$45 each, Tuesdays at 5:30pm — let me know!',
        );

        expect(repo.feedback, hasLength(1));
        final row = repo.feedback.single;
        expect(row['action'], 'edited');
        expect(row['originalText'], 'Sessions are \$40 each, Tuesdays at 5pm.');
        expect(
          row['finalText'],
          'Sessions are \$45 each, Tuesdays at 5:30pm — let me know!',
        );
        expect(
          row['originalText'],
          isNot(equals(row['finalText'])),
          reason: 'the corpus must hold BOTH the AI draft and the edit',
        );
      },
    );

    test('discarded marks the draft discarded, stays invisible, and logs feedback',
        () async {
      final repo = _DraftRepo();
      repo.seedDraft({
        '_id': 'draft-3',
        'conversationId': 'conv_1',
        'text': 'Draft the coach never wanted to send.',
        'senderId': 'me',
        'createdAt': '2026-07-28T10:10:00Z',
        'status': 'ai_draft',
        'visibleToParent': false,
      });
      final chat = ChatProvider(repo, _FakeAuth());
      await chat.loadMessages('conv_1');

      final ok = await chat.resolveDraft(draftId: 'draft-3', action: 'discarded');

      expect(ok, true);
      final resolved = chat.messages.firstWhere((m) => m['_id'] == 'draft-3');
      expect(resolved['status'], 'discarded');
      expect(chat.pendingDrafts, isEmpty);

      expect(repo.feedback, hasLength(1));
      expect(repo.feedback.single['action'], 'discarded');
      expect(repo.feedback.single['finalText'], null);
    });

    test('a failed resolveDraft (offline/server error) returns false and never fakes success',
        () async {
      final repo = _FailingDraftRepo();
      repo.seedDraft({
        '_id': 'draft-4',
        'conversationId': 'conv_1',
        'text': 'Would still be pending.',
        'senderId': 'me',
        'createdAt': '2026-07-28T10:15:00Z',
        'status': 'ai_draft',
        'visibleToParent': false,
      });
      final chat = ChatProvider(repo, _FakeAuth());
      await chat.loadMessages('conv_1');

      final ok = await chat.resolveDraft(draftId: 'draft-4', action: 'sent_as_is');

      expect(ok, false);
      expect(chat.pendingDrafts, hasLength(1),
          reason: 'the draft stays pending — no silent fake success');
      expect(repo.feedback, isEmpty,
          reason: 'no feedback is logged for a failed resolution');
    });
  });
}

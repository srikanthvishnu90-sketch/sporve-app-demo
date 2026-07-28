// End-to-end widget test for the coach "Draft reply" flow (P3):
//   open thread -> Draft reply -> pick a draft -> coach edits -> sends via the
//   EXISTING send path. Also asserts the draft NEVER auto-sends.
//
// Uses in-memory fakes (no Supabase, no GetStorage, no deployed function), so it
// exercises the real ChatProvider + ChatDetailsScreen wiring deterministically.
//   flutter test test/draft_reply_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:flutter_structure/core/auth/auth_service.dart';
import 'package:flutter_structure/core/auth/app_user.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/shared/controllers/chat_provider.dart';
import 'package:flutter_structure/presentation/client/view/chat_details_screen.dart';

/// Minimal in-memory repo — only the methods this flow touches are real; the
/// rest fall through to noSuchMethod (never called here).
class _FakeRepo implements AppRepository {
  final Map<String, List<dynamic>> messages;
  _FakeRepo(this.messages);

  @override
  Future<Map<String, dynamic>> getUserProfile() async => {'_id': 'coach-1'};

  @override
  Future<List<dynamic>> getMessages(String conversationId) async =>
      List.from(messages[conversationId] ?? const []);

  @override
  Future<void> saveMessages(String conversationId, List<dynamic> msgs) async =>
      messages[conversationId] = List.from(msgs);

  @override
  Future<Map<String, dynamic>?> postMessage(String conversationId, String body) async {
    final msg = {
      '_id': 'm-${messages[conversationId]?.length ?? 0}',
      'conversationId': conversationId,
      'text': body,
      'senderId': 'coach-1',
      'createdAt': '2026-06-28T11:00:00Z',
    };
    (messages[conversationId] ??= []).add(msg);
    return msg;
  }

  @override
  Future<void Function()> subscribeMessages(
          String conversationId, void Function(Map<String, dynamic>) onMessage) async =>
      () {};

  @override
  Future<List<dynamic>> getConversations() async => [
    <String, dynamic>{'_id': 'conv_1', 'lastMessage': null},
  ];

  @override
  Future<void> saveConversations(List<dynamic> conversations) async {}

  @override
  Future<Map<String, dynamic>> draftMessage(
    Map<String, dynamic> payload,
  ) async {
    // Mirrors message-draft's success shape: 1–2 distinct drafts.
    return {
      'result': {
        'type': 'drafts',
        'drafts': [
          {
            'text':
                'No problem at all — happy to move the session. What day works best this week?',
          },
          {
            'text':
                'Thanks for the heads up! I have a couple of openings later this week — what is easiest?',
          },
        ],
      },
      'removed': const <String>[],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthService {
  final String role;
  _FakeAuth(this.role);
  @override
  AppUser? get currentUser => AppUser(id: 'coach-1', role: role);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ChatProvider> _pumpThread(
  WidgetTester tester, {
  required String role,
}) async {
  final repo = _FakeRepo({
    'conv_1': [
      {
        '_id': 'm1',
        'conversationId': 'conv_1',
        'text':
            "Hi coach, can we move Mia's Tuesday session to later this week?",
        'senderId': 'parent-9',
        'createdAt': '2026-06-28T10:00:00Z',
      },
    ],
  });
  final chat = ChatProvider(repo, _FakeAuth(role));

  Get.testMode = true;
  await tester.pumpWidget(
    ChangeNotifierProvider<ChatProvider>.value(
      value: chat,
      child: GetMaterialApp(home: const Scaffold(body: SizedBox())),
    ),
  );
  Get.to(
    () => const ChatDetailsScreen(),
    arguments: {'conversationId': 'conv_1', 'contactName': 'Jordan (parent)'},
  );
  await tester.pumpAndSettle();
  return chat;
}

void main() {
  testWidgets('coach: Draft reply -> pick -> edit -> send (never auto-sends)', (
    tester,
  ) async {
    final chat = await _pumpThread(tester, role: 'provider');

    // The parent's message is shown and the coach-only affordance is present.
    expect(find.text('Draft reply'), findsOneWidget);
    expect(chat.messages.length, 1, reason: 'only the parent message so far');

    // Tap "Draft reply" -> drafting -> two options surface in the sheet.
    await tester.tap(find.text('Draft reply'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A DRAFT'), findsOneWidget);

    // NEVER auto-sends: choosing has not happened yet, nothing was sent.
    expect(chat.messages.length, 1, reason: 'drafting must not send anything');

    // Pick the first draft -> sheet closes -> composer is pre-filled & editable.
    const firstDraft =
        'No problem at all — happy to move the session. What day works best this week?';
    await tester.tap(find.text(firstDraft));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, firstDraft), findsOneWidget);

    // STILL not sent — the coach must explicitly send.
    expect(
      chat.messages.length,
      1,
      reason: 'pre-filling the composer must not send',
    );

    // Coach edits the draft, then sends through the existing composer/send path.
    const edited =
        'No problem — Thursday 4pm works great for Mia. See you then!';
    await tester.enterText(find.byType(TextField), edited);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // The edited message went out through the normal send path (as the coach).
    expect(chat.messages.length, 2);
    expect(chat.messages.last['text'], edited);
    expect(chat.messages.last['senderId'], 'coach-1');
  });

  testWidgets('non-coach (searcher): no Draft reply affordance', (
    tester,
  ) async {
    await _pumpThread(tester, role: 'searcher');
    expect(find.text('Draft reply'), findsNothing);
  });
}

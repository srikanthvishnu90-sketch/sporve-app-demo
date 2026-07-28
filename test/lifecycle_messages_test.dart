// Tests for the P6 control layer: automated-message prefs (off/draft/auto with
// auto-only-logistics) and the approval queue (nothing sends without approval).
// In-memory fakes — no Supabase/network.
//   flutter test test/lifecycle_messages_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/provider/controllers/lifecycle_controller.dart';
import 'package:flutter_structure/presentation/provider/view/automated_messages_screen.dart';

class _FakeRepo implements AppRepository {
  final Map<String, String> prefs = {};
  List<Map<String, dynamic>> drafts;
  _FakeRepo({this.drafts = const []});

  @override
  Future<List<Map<String, dynamic>>> getLifecyclePrefs() async =>
      prefs.entries.map((e) => {'eventType': e.key, 'mode': e.value}).toList();

  @override
  Future<bool> setLifecyclePref(String eventType, String mode) async {
    const logistics = {'booking_confirmed', 'reminder_24h'};
    if (mode == 'auto' && !logistics.contains(eventType)) return false; // DB CHECK mirror
    prefs[eventType] = mode;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getLifecycleDrafts() async =>
      List<Map<String, dynamic>>.from(drafts);

  @override
  Future<Map<String, dynamic>> approveLifecycleMessage(String id, {String? body}) async {
    drafts = drafts.where((d) => d['id'] != id).toList();
    return {'ok': true, 'status': 'sent'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('control rules: default draft; auto only for logistics', () async {
    final ctrl = LifecycleController(_FakeRepo());
    await ctrl.loadPrefs();

    // default mode is 'draft' for every type
    expect(ctrl.modeFor('booking_confirmed'), 'draft');
    expect(ctrl.modeFor('post_session'), 'draft');

    // auto on a NON-logistics type is rejected; mode stays draft
    expect(await ctrl.setMode('post_session', 'auto'), false);
    expect(ctrl.modeFor('post_session'), 'draft');

    // auto on a logistics type is accepted
    expect(await ctrl.setMode('booking_confirmed', 'auto'), true);
    expect(ctrl.modeFor('booking_confirmed'), 'auto');

    // off is allowed anywhere
    expect(await ctrl.setMode('post_session', 'off'), true);
    expect(ctrl.modeFor('post_session'), 'off');
  });

  test('approval queue: nothing leaves the queue until approved', () async {
    final repo = _FakeRepo(drafts: [
      {'id': 'd1', 'eventType': 'post_session', 'body': 'Hi there!'},
    ]);
    final ctrl = LifecycleController(repo);
    await ctrl.loadDrafts();
    expect(ctrl.drafts.length, 1, reason: 'draft sits in the queue, unsent');

    final err = await ctrl.approveAndSend('d1', 'Hi there! (edited)');
    expect(err, isNull);
    expect(ctrl.drafts.isEmpty, true, reason: 'approved draft leaves the queue');
  });

  testWidgets('settings: auto disabled for non-logistics; logistics auto works',
      (tester) async {
    final ctrl = LifecycleController(_FakeRepo());
    Get.testMode = true;
    await tester.pumpWidget(
      ChangeNotifierProvider<LifecycleController>.value(
        value: ctrl,
        child: GetMaterialApp(home: const AutomatedMessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // event types render (top of the list is in the viewport)
    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('Post-session check-in'), findsOneWidget);

    // non-logistics types show the auto-disabled explanation
    expect(
      find.text('Substantive messages always need your approval, so auto-send is off.'),
      findsWidgets,
    );

    // nothing is in 'auto' yet
    expect(find.textContaining('Auto-sends a fixed reminder'), findsNothing);

    // tapping Auto on the first (logistics) card switches it to auto
    await tester.tap(find.text('Auto').first);
    await tester.pumpAndSettle();
    expect(ctrl.modeFor('booking_confirmed'), 'auto');
    expect(find.textContaining('Auto-sends a fixed reminder'), findsOneWidget);
  });
}

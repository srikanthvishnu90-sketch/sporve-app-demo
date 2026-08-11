import 'package:flutter/foundation.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/data/policies.dart';
import '../../../core/models/query_intent.dart';
import '../../../core/matching/provider_matcher.dart';

/// One turn in the "Ask Sporve" assistant thread.
class AssistantMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final bool isError;
  final List<ProviderMatch> providers; // tappable cards under the answer

  const AssistantMessage(
    this.role,
    this.text, {
    this.isError = false,
    this.providers = const [],
  });

  bool get isUser => role == 'user';
}

class AssistantProvider with ChangeNotifier {
  AssistantProvider(this._repo);
  final AppRepository _repo;

  final List<AssistantMessage> _messages = [];
  List<AssistantMessage> get messages => List.unmodifiable(_messages);

  bool _sending = false;
  bool get sending => _sending;
  bool get isEmpty => _messages.isEmpty;

  // Grounded follow-up state: the last non-empty result set to re-sort.
  List<ProviderMatch> _lastRows = const [];

  // Cached client context (merged into the parsed intent as defaults).
  bool _ctxLoaded = false;
  String? _profileLocation;
  int? _activeChildAge;

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

    _messages.add(AssistantMessage('user', text));
    _sending = true;
    notifyListeners();

    try {
      await _ensureContext();

      // Last 6 turns (≈12 messages) for follow-up grounding.
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();
      final recent = history.length > 12
          ? history.sublist(history.length - 12)
          : history;

      // 1) PARSE (+ merge defaults in code, not the model).
      var intent = await _repo.parseChatQuery(text);
      intent = intent.mergeDefaults(
        profileLocation: _profileLocation,
        activeChildAge: _activeChildAge,
      );

      // 2) RETRIEVE (find/compare) or POLICY (booking question).
      List<ProviderMatch> rows = const [];
      String? policy;
      final it = intent.intentType ?? QueryIntentType.other;
      if (it == QueryIntentType.findProviders || it == QueryIntentType.compare) {
        if (_isFollowUp(text, intent)) {
          rows = ProviderMatcher.sort(_lastRows, intent.sortPreference);
        } else {
          rows = await _repo.searchProviders(intent);
          if (rows.isNotEmpty) _lastRows = rows;
        }
      } else if (it == QueryIntentType.questionAboutBooking) {
        policy = Policies.text;
      }

      // 3) ANSWER (grounded strictly in rows or policy).
      final res = await _repo.answerChat(
        question: text,
        rows: rows,
        intentType: it,
        policyText: policy,
        history: recent,
      );

      if (res['error'] != null) {
        _messages.add(
          AssistantMessage('assistant', res['error'].toString(), isError: true),
        );
      } else {
        final ids = ((res['provider_ids'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        final cards = ids.isEmpty
            ? const <ProviderMatch>[]
            : rows.where((r) => ids.contains(r.providerId)).toList();
        _messages.add(
          AssistantMessage(
            'assistant',
            (res['text'] ?? '').toString(),
            providers: cards,
          ),
        );
      }
    } catch (e) {
      debugPrint('assistant pipeline failed: $e');
      _messages.add(
        const AssistantMessage(
          'assistant',
          "Something went wrong reaching the assistant. Please try again.",
          isError: true,
        ),
      );
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// A follow-up that reuses the prior result set (re-sorted) instead of a fresh
  /// retrieval — e.g. "which of those is closest?".
  bool _isFollowUp(String q, QueryIntent intent) {
    if (_lastRows.isEmpty) return false;
    final it = intent.intentType;
    if (it != QueryIntentType.findProviders &&
        it != QueryIntentType.compare) {
      return false;
    }
    if (intent.sport != null) return false; // a new sport = a new search
    final ql = q.toLowerCase();
    return RegExp(
      r'\b(those|them|these|that list|which (?:of|one|is)|first one|the (?:cheaper|cheapest|closer|closest|nearest|best))\b',
    ).hasMatch(ql);
  }

  Future<void> _ensureContext() async {
    if (_ctxLoaded) return;
    _ctxLoaded = true;
    try {
      final prof = await _repo.getUserProfile();
      _profileLocation = (prof['location'] ?? prof['city'])?.toString();
      final athletes = await _repo.getAthletes();
      if (athletes.isNotEmpty && athletes.first is Map) {
        final dob = (athletes.first as Map)['dateOfBirth']?.toString();
        final d = dob == null ? null : DateTime.tryParse(dob);
        if (d != null) {
          final now = DateTime.now();
          var age = now.year - d.year;
          if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
            age--;
          }
          if (age >= 0 && age < 100) _activeChildAge = age;
        }
      }
    } catch (e) {
      // Best-effort context only (location + child age for ranking). Failure
      // degrades ranking, not correctness — but log it rather than swallow.
      debugPrint('AssistantProvider._ensureContext failed: $e');
    }
  }

  void reset() {
    if (_messages.isEmpty && !_sending) return;
    _messages.clear();
    _lastRows = const [];
    _sending = false;
    notifyListeners();
  }
}

/// Repository abstraction (#16) — the single swap point between the mock demo
/// data and a future Supabase backend (#19).
///
/// CORE RULE: every method returns a `Future`, even though [MockRepository]
/// resolves instantly via `Future.value(...)`. Supabase calls are async/network,
/// so async-now means the backend can drop in later by changing ONE line in
/// `lib/main.dart` (`MockRepository()` → `SupabaseRepository()`) without touching
/// a single call site.
///
/// Interfaces are grouped per domain; [AppRepository] is the facade that
/// aggregates them so controllers can be injected with one object.
library;

import '../models/query_intent.dart';
import '../matching/provider_matcher.dart';

/// Programs & their sessions (provider listings + scheduled sessions).
abstract class ProgramRepository {
  Future<List<dynamic>> getPrograms();

  /// Like [getPrograms] but RETHROWS on failure (network/server) instead of
  /// swallowing to an empty list — so the UI can show "couldn't load, retry"
  /// rather than a misleading empty state.
  Future<List<dynamic>> getProgramsOrThrow();

  Future<void> savePrograms(List<dynamic> programs);

  /// Creates ONE program (real INSERT, returns its new id) AND auto-provisions a
  /// few future sessions so the listing is immediately bookable. Returns null on
  /// failure. Use this for new listings instead of the list-replace
  /// [savePrograms] (which can't return the new id or seed sessions).
  Future<String?> createProgram(Map<String, dynamic> program);

  // ── Roster: affiliated trainers of an ORGANIZATION provider (Booksy model) ──
  /// Every roster member of the caller's org (owner/admin sees all; RLS scopes).
  Future<List<Map<String, dynamic>>> getOrgMembers();

  /// Customer-facing: the bookable roster of a GIVEN org, for the athlete-side
  /// trainer picker. RLS returns ONLY verified + active members (an org can
  /// never expose an unverified trainer — L-005), so this is safe to call for
  /// any provider the searcher is browsing.
  Future<List<Map<String, dynamic>>> getOrgMembersForProvider(
    String organizationId,
  );

  /// Add a trainer to the caller's roster; also flips the provider to
  /// `provider_type = 'organization'`. Returns the new member id (null on fail).
  Future<String?> createOrgMember(Map<String, dynamic> member);

  /// Patch a roster member (name/specialty/price/commission/is_active).
  /// background_check_status is server-controlled and cannot be set here.
  Future<bool> updateOrgMember(String id, Map<String, dynamic> patch);

  /// Remove a roster member (past bookings keep their history — fk SET NULL).
  Future<bool> deleteOrgMember(String id);

  Future<List<dynamic>> getSessions();
  Future<void> saveSessions(List<dynamic> sessions);
}

/// Athlete/family bookings.
abstract class BookingRepository {
  Future<List<dynamic>> getBookings();

  /// Like [getBookings] but RETHROWS on failure so the UI can show retry.
  Future<List<dynamic>> getBookingsOrThrow();

  Future<void> saveBookings(List<dynamic> bookings);

  /// Persists a booking and returns its new id (null if it couldn't be created).
  Future<String?> addBooking(Map<String, dynamic> booking);

  /// Requests a permitted booking transition (declined/completed/no_show/cancelled).
  /// Provider-of-the-session only (RLS pins provider edits to `status`); the DB
  /// lifecycle trigger reacts to the transition. Returns true on success.
  Future<bool> updateBookingStatus(String bookingId, String status);
}

/// User + provider profiles.
abstract class ProfileRepository {
  Future<Map<String, dynamic>> getUserProfile();
  Future<void> saveUserProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>> getProviderProfile();
  Future<void> saveProviderProfile(Map<String, dynamic> profile);
}

/// Athlete records (provider roster / family athletes).
abstract class AthleteRepository {
  Future<List<dynamic>> getAthletes();
  Future<void> saveAthletes(List<dynamic> athletes);

  /// Adds ONE child for the signed-in parent and returns its new id (null on
  /// failure). Stamps parent_id + COPPA consent server-side.
  Future<String?> addAthlete(Map<String, dynamic> athlete);
}

/// Conversations + their messages.
abstract class ConversationRepository {
  Future<List<dynamic>> getConversations();

  /// Like [getConversations] but RETHROWS on failure so the UI can show retry.
  Future<List<dynamic>> getConversationsOrThrow();

  Future<void> saveConversations(List<dynamic> conversations);
  Future<Map<String, dynamic>?> ensureProviderConversation({
    required String providerOwnerId,
    String? programId,
    String? providerName,
  });
  Future<List<dynamic>> getMessages(String conversationId);
  Future<void> saveMessages(String conversationId, List<dynamic> messages);

  /// Persists ONE new message (append-only; messages are immutable) and returns
  /// it mapped (`{_id, conversationId, text, senderId, createdAt}`), or null on
  /// failure. Also bumps the conversation's last-message preview.
  Future<Map<String, dynamic>?> postMessage(String conversationId, String body);

  /// Subscribes to new messages in a conversation via realtime; [onMessage]
  /// fires once per inserted row (mapped). Returns a function that cancels the
  /// subscription. RLS-scoped: only messages the caller may read are delivered.
  Future<void Function()> subscribeMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  );
}

/// Coach teams / roster groups.
abstract class TeamRepository {
  Future<List<dynamic>> getTeams();
  Future<void> saveTeams(List<dynamic> teams);
}

/// Notification preferences + feed.
abstract class NotificationRepository {
  Future<Map<String, dynamic>> getNotificationPrefs();
  Future<void> saveNotificationPrefs(Map<String, dynamic> prefs);
  Future<List<dynamic>> getNotifications();
  Future<void> saveNotifications(List<dynamic> notifications);

  /// Registers a push destination for the signed-in user — an FCM token or a
  /// JSON web-push subscription. Idempotent (upsert by user + token).
  Future<void> savePushToken(String token, {String platform});
}

/// Saved/favourited programs.
///
/// NOTE: login + active-role state used to live here too, but auth is now owned
/// solely by [AuthProvider] (backed by AuthService → the Supabase session) since
/// #18 — the old repo `isLoggedIn`/`setLoggedIn`/`getActiveRole`/`setActiveRole`
/// methods had zero callers and were removed. The repository no longer carries
/// any auth state; identity comes from one place.
abstract class FavoritesRepository {
  Future<List<String>> getFavorites();
  Future<void> saveFavorites(List<String> favorites);
}

/// Session notes (coach raw input) + parent updates (the AI-drafted deliverable).
/// All persistence is server-side + RLS-scoped; the draft is never sent here.
abstract class SessionUpdateRepository {
  /// Persists the coach's raw notes to `session_notes`; returns the new id.
  Future<String?> createSessionNote(Map<String, dynamic> note);

  /// Calls the `session-note-summarize` Edge Function; returns its JSON body
  /// (`{result, model, audit_id, removed}` or `{error}`).
  Future<Map<String, dynamic>> summarizeSessionNote(
    Map<String, dynamic> payload,
  );

  /// Calls the `message-draft` Edge Function for AI reply drafts in a message
  /// thread. The repo injects the caller's `providerId`; pass `threadContext`
  /// ({role, body}[]) plus optional `intent`/`childFirstName`/`bookingContext`.
  /// Returns the function body (`{result:{type, drafts:[{text}]}, removed, ...}`
  /// or `{error}`). DRAFT-only — it never sends.
  Future<Map<String, dynamic>> draftMessage(Map<String, dynamic> payload);

  /// Inserts (no `id`) or updates (`id` present) a `parent_updates` draft row;
  /// returns its id. Used for autosave. Always status='draft' here.
  Future<String?> upsertParentUpdateDraft(Map<String, dynamic> update);

  /// Flips a parent_update to status='approved' (+ approved_by/approved_at).
  /// Sending stays a separate, later, explicit step. Returns the stored row.
  Future<Map<String, dynamic>?> approveParentUpdate(String id);

  /// Deterministic send: routes an APPROVED update to the child's guardian(s)
  /// via the notifications/inbox channel and flips status='sent'. Server-side
  /// (service role) because notifications has no client-insert policy. Returns
  /// the function body (`{ok,status,sent_at,...}` or `{error}`).
  Future<Map<String, dynamic>> sendParentUpdate(String id);

  /// Parent-facing read: SENT updates for a child the caller guards, newest
  /// first. Enforced by RLS AND by an explicit child-ownership + status filter.
  Future<List<Map<String, dynamic>>> getParentUpdatesForChild(String childId);
}

/// AI discovery (Stage 3). Both methods call Edge Functions that route model
/// access through ai-gateway — the client never embeds or ranks anything.
abstract class SearchRepository {
  /// NL query -> editable structured constraints. Returns
  /// `{sport, athlete_age, metro, max_price, radius_miles, soft_attributes[]}`
  /// (any field may be null) or `{error}`. The parse-to-chips step.
  Future<Map<String, dynamic>> searchParse(
    String query, {
    Map<String, dynamic>? locationHint,
  });

  /// Runs discovery for [constraints]. Returns one of:
  ///   `{gated:true, reason, metro}`     -> market not ready; show browse grid
  ///   `{gated:false, results:[...], relax:{...}|null}`
  ///   `{error}`
  Future<Map<String, dynamic>> searchExecute(
    Map<String, dynamic> constraints, {
    Map<String, dynamic>? locationHint,
  });

  /// Guided "find my coach": a [client] profile ({athlete_age, sport,
  /// skill_level?, maturation?, budget_max_per_session?,
  /// session_type_pref?, lat, lng, max_distance_km?}) -> safety-gated, ranked
  /// matches. Returns `{matches:[...], note, eligible_count}` or `{error}`.
  /// All gating + ranking lives server-side in the ai-match Edge Function.
  Future<Map<String, dynamic>> aiMatch(Map<String, dynamic> client);
}

/// Facade aggregating every domain repository. Controllers depend on this one
/// type; `lib/main.dart` injects a single concrete instance.
/// Automated lifecycle messaging (P4/P6): per-coach delivery prefs + the coach's
/// approval queue of AI-drafted lifecycle messages.
abstract class LifecycleRepository {
  /// The coach's per-event delivery modes — list of `{eventType, mode}`.
  /// Missing rows imply the default mode 'draft'.
  Future<List<Map<String, dynamic>>> getLifecyclePrefs();

  /// Upserts the coach's mode ('off'|'draft'|'auto') for an event type. The DB
  /// rejects 'auto' for non-logistics types; returns false on rejection/failure.
  Future<bool> setLifecyclePref(String eventType, String mode);

  /// Drafted lifecycle messages awaiting the coach's approval (newest first).
  Future<List<Map<String, dynamic>>> getLifecycleDrafts();

  /// Coach approves (optionally with an edited body) -> server delivers it via
  /// the `lifecycle-approve` Edge Function. Returns its body (`{ok,status,...}`
  /// or `{error}`). Nothing sends without this explicit call.
  Future<Map<String, dynamic>> approveLifecycleMessage(
    String id, {
    String? body,
  });
}

/// AI assistant chat ("Ask Sporve"). Routes model access through the
/// `ai-gateway` Edge Function (feature="assistant"); the client never hits a
/// model API directly.
abstract class AssistantRepository {
  /// Sends the running assistant conversation and returns the reply.
  /// [messages] is the full history as `{'role': 'user'|'assistant',
  /// 'content': text}` (oldest first). Returns `{'text': reply}` on success or
  /// `{'error': message}` on failure.
  Future<Map<String, dynamic>> askAssistant(List<Map<String, String>> messages);

  /// Parses a free-text customer question into a structured [QueryIntent]
  /// (prompt 1/3: parsing only — no searching/answering). Extracts ONLY what
  /// the user said; defaults are merged after, in code, via
  /// [QueryIntent.mergeDefaults]. Supabase routes to the `chat-parse-query`
  /// Edge Function (gateway, cheap tier); the mock uses the deterministic parser.
  Future<QueryIntent> parseChatQuery(String query);

  /// Retrieval (CODE, not LLM): translates [intent] into eligible provider rows,
  /// ALWAYS applying the matching-spec hard gates (verified+active, sport, age
  /// served, intensity ceiling, distance, budget, session type). Returns up to
  /// 10 rows. Safety gates are never relaxed — unverified providers never appear.
  Future<List<ProviderMatch>> searchProviders(
    QueryIntent intent, {
    double? originLat,
    double? originLng,
  });

  /// Answering (LLM, workhorse tier): grounds an answer strictly in [rows]
  /// (find/compare) or [policyText] (question_about_booking). Returns
  /// `{'text': String, 'provider_ids': List<String>}` — the referenced provider
  /// ids so the UI can render tappable cards. Never invents facts.
  Future<Map<String, dynamic>> answerChat({
    required String question,
    required List<ProviderMatch> rows,
    required QueryIntentType intentType,
    String? policyText,
    List<Map<String, String>> history,
  });
}

/// Outcome-first reframe (Prompts 1/2/3/5). The concierge PROPOSES, the parent
/// APPROVES: this surface creates a goal + development plan, reads the engine's
/// grounded `plan_proposals`, records the parent's accept/decline (status-only,
/// per RLS), attributes a resulting booking, reads the latest `progress_digest`,
/// and invokes the two backend engine functions. Nothing books autonomously.
abstract class OutcomeRepository {
  /// The single ACTIVE `athlete_goals` row for [athleteId] (optionally pinned to
  /// [sport], since one active goal is allowed per athlete per sport), newest
  /// first, or null when the athlete has no active goal. Mapped camelCase.
  Future<Map<String, dynamic>?> getActiveGoal(
    String athleteId, {
    String? sport,
  });

  /// Inserts an `athlete_goals` row (status `active`, `created_by = auth.uid()`),
  /// storing `outcome_text` verbatim + the `constraints` jsonb (incl. lat/lng).
  /// Returns the new goal id, or null on failure.
  Future<String?> createGoal(Map<String, dynamic> goal);

  /// Turns the parent's raw outcome sentence into a concise, grounded headline
  /// for the Plan home (e.g. "I really want him to make the freshman basketball
  /// team next year" → "Make the freshman team"). Supabase routes to the
  /// `goal-formulate` Edge Function (ai-gateway); the mock (and any failure)
  /// falls back to a local, grounded truncation — it NEVER injects a
  /// sport/team/date/level the parent didn't say. Best-effort: safe to call
  /// before the goal exists; a non-empty [rawOutcome] always yields something.
  Future<String> formulateGoalHeadline(String rawOutcome, {String? sport});

  /// The newest `development_plans` row for [goalId], or null. Mapped camelCase.
  Future<Map<String, dynamic>?> getPlanForGoal(String goalId);

  /// Inserts a `development_plans` row (title + starter `phases`, status
  /// `active`). Returns the new plan id, or null on failure.
  Future<String?> createPlan(Map<String, dynamic> plan);

  /// The `plan_proposals` for [planId] with [status] (default `proposed`), in
  /// rank order, each joined with its program + provider facts so the UI can
  /// render provider/price/distance/reason and open the booking flow prefilled.
  Future<List<Map<String, dynamic>>> getProposals(
    String planId, {
    String status = 'proposed',
  });

  /// Records the parent's decision on a proposal. RLS + a DB trigger allow the
  /// parent to change ONLY `status`, and only to `accepted`/`declined`
  /// (`resulting_booking_id` is set server-side from the booking's
  /// `plan_proposal_id`). Returns true on success.
  Future<bool> updateProposalStatus(String proposalId, String status);

  /// Attributes a booking to the proposal the parent approved by setting
  /// `bookings.plan_proposal_id`. Returns true on success.
  Future<bool> setBookingProposal(String bookingId, String proposalId);

  /// The newest `progress_digests` row for [planId] (parent read-only), or null.
  Future<Map<String, dynamic>?> getLatestDigest(String planId);

  /// Invokes the `generate-proposals` engine function (body `{ plan_id }`).
  /// Returns its JSON body (`{proposals, generated, no_supply, note,
  /// eligible_count}` or `{error}`). Never inserts proposals from the client.
  Future<Map<String, dynamic>> generateProposals(String planId);

  /// Invokes the `plan-progress` engine function (body `{ plan_id }`). No-ops
  /// server-side when thresholds aren't met. Returns its JSON body
  /// (`{completed_sessions, upcoming_bookings, digest, adapted}` or `{error}`).
  Future<Map<String, dynamic>> planProgress(String planId);
}

abstract class AppRepository
    implements
        ProgramRepository,
        BookingRepository,
        ProfileRepository,
        AthleteRepository,
        ConversationRepository,
        TeamRepository,
        NotificationRepository,
        SessionUpdateRepository,
        LifecycleRepository,
        SearchRepository,
        AssistantRepository,
        OutcomeRepository,
        FavoritesRepository {}

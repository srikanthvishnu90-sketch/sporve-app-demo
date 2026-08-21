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
import '../models/subscription.dart';
import '../matching/provider_matcher.dart';

/// A server-backed action failed with a message safe to show to the user.
/// Repository implementations preserve the backend's explicit message when it
/// exists and use a truthful fallback only when the response has none.
class RepositoryActionException implements Exception {
  final String message;
  const RepositoryActionException(this.message);

  @override
  String toString() => message;
}

/// Provider-workspace subscriptions. Prices and entitlements are always read
/// from Supabase; Stripe Checkout only receives a plan identifier.
abstract class BillingRepository {
  Future<List<SubscriptionPlan>> getSubscriptionPlans();

  Future<ProviderSubscription> getProviderSubscription();

  Future<Uri> createSubscriptionCheckout({
    required SubscriptionTier plan,
    required Uri successUrl,
    required Uri cancelUrl,
  });

  Future<Uri> createBillingPortal({required Uri returnUrl});
}

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

  // ── Commission engine (#5): effective-dated rates + the two add-doors ───────
  /// A trainer's effective-dated commission history (newest first). Reads
  /// `commission_rates` (RLS: org admin or the trainer themself). Empty on any
  /// failure or when only the legacy default applies.
  Future<List<Map<String, dynamic>>> getCommissionRates(String memberId);

  /// Append a NEW effective-dated commission rate for a trainer (never rewrites
  /// past bookings — those keep their captured snapshot). Returns false on fail.
  Future<bool> addCommissionRate(
    String memberId, {
    required String type, // 'percent' | 'flat'
    required num value,
  });

  /// DOOR A lookup: find an EXISTING Sporve account by EXACT email/phone to
  /// affiliate. Returns {profile_id, display_name} or null when no match (the UI
  /// then offers Door B). Org-admin gated server-side.
  Future<Map<String, dynamic>?> findAffiliatableAccount(String identifier);

  /// DOOR A: send an affiliation invite to an existing account (creates a PENDING
  /// roster link the person accepts). Returns the new member id, or null on fail.
  Future<String?> affiliateExistingAccount(
    String profileId, {
    Map<String, dynamic>? trainerProfile,
  });

  /// DOOR B: invite a NEW person by email/phone into the standard funnel with the
  /// org pre-attached (a coach_invites row, kind='trainer'). Returns the invite
  /// token to share, or null on fail.
  Future<String?> createTrainerInvite({String? email, String? phone});

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

  /// Starts Stripe-hosted checkout for an already-created unpaid booking. The
  /// client sends identifiers and return URLs only; amount, fees, eligibility,
  /// and payment state are server-owned.
  Future<Uri> createBookingCheckout({
    required String bookingId,
    required Uri successUrl,
    required Uri cancelUrl,
  });

  /// Requests cancellation/refund evaluation. The client never supplies a
  /// refund amount; the server evaluates the booking's immutable policy
  /// snapshot and returns the resulting payment state and recorded amount.
  Future<Map<String, dynamic>> requestBookingCancellation(
    String bookingId, {
    String? reason,
  });

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

  /// Starts or refreshes Stripe Connect onboarding for the signed-in provider.
  /// Returns client-observed `{onboardingUrl?, chargesEnabled, error?}`.
  Future<Map<String, dynamic>> createProviderConnectSession({
    required Uri returnUrl,
  });

  /// Best-effort, idempotent refresh after provider profile changes. Failures
  /// are logged by the controller and never roll back the confirmed profile.
  Future<void> refreshProviderEmbeddings();

  /// Generates a review-only provider onboarding draft. It never saves or
  /// publishes profile state.
  Future<Map<String, dynamic>> generateProviderOnboardDraft(
    Map<String, dynamic> payload,
  );

  /// Coach POLICY bundle — the ONLY source of truth the AI front-office reply
  /// robot (doc #5) is allowed to cite. Read/save the owner-editable policy
  /// facts on the caller's own provider row.
  ///
  /// Bundle shape (all optional):
  ///   {
  ///     'cancellationPolicy': String?,   // "24-hour cancellation, else charged"
  ///     'whatToBring':        String?,   // "Cleats, shin guards, water"
  ///     'travelRadius':       String?,   // "Within 10 miles of downtown"
  ///     'sessionNotes':       String?,   // standing notes about sessions
  ///     'faq': [ {'question': String, 'answer': String}, ... ],
  ///   }
  Future<Map<String, dynamic>> getCoachPolicies();

  /// Persists the policy bundle to the caller's OWN provider row (owner-scoped).
  /// Returns true on a confirmed write, false on failure (offline / server
  /// error / no session) — the caller MUST surface a real error on false and
  /// never fake success (L-015). Never throws.
  Future<bool> saveCoachPolicies(Map<String, dynamic> policies);
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

  /// AI Front Office #8/#9 — the coach's two buttons on a "Suggested reply"
  /// (a message with `status='ai_draft'`, `visible_to_parent=false` that only
  /// the coach can see, written by the automatic draft-reply pipeline).
  /// Resolves ONE pending draft and ALWAYS records a `draft_feedback` row in
  /// the SAME call — the corpus that makes the agent improve per-coach can
  /// never be skipped:
  ///   'sent_as_is' — sends the draft body unchanged (`visible_to_parent=true`).
  ///   'edited'     — sends [finalText] instead (the coach's edit).
  ///   'discarded'  — the coach throws it away; stays invisible to the parent.
  /// Returns true on a confirmed write, false on failure (offline / server
  /// error / already resolved / not the coach's own draft) — the CALLER must
  /// show a real error on false and never fake success (L-015). Never throws.
  Future<bool> resolveDraft({
    required String draftId,
    required String action,
    String? finalText,
  });
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

  /// Calls the `draft-recap` Edge Function (AI Front Office #11): three taps
  /// (`skills`[], `effort` 1-3, optional `note`) + `childFirstName`/`sport` →
  /// a 2-4 sentence parent recap grounded ONLY in the taps, voiced from the
  /// coach's own draft_feedback corpus. Returns `{result:{recap_text}, ...}` or
  /// `{error}`. DRAFT-only — the coach Sends it via the existing parent-update
  /// rails (#12).
  Future<Map<String, dynamic>> draftRecap(Map<String, dynamic> payload);

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

  /// Parent-facing read: ALL grounded `progress_digests` for one athlete (the
  /// child), newest first — across every plan/sport the child has. Backend-
  /// authored only; RLS scopes to the guardian, and the impl adds a defense-in-
  /// depth child-ownership check. Returns [] when the caller doesn't guard the
  /// child or there are no digests. Feeds the development-timeline surface (P0 #4)
  /// alongside `getParentUpdatesForChild`.
  Future<List<Map<String, dynamic>>> getProgressDigestsForChild(
    String athleteId,
  );

  /// Invokes the `generate-proposals` engine function (body `{ plan_id }`).
  /// Returns its JSON body (`{proposals, generated, no_supply, note,
  /// eligible_count}` or `{error}`). Never inserts proposals from the client.
  Future<Map<String, dynamic>> generateProposals(String planId);

  /// Invokes the `plan-progress` engine function (body `{ plan_id }`). No-ops
  /// server-side when thresholds aren't met. Returns its JSON body
  /// (`{completed_sessions, upcoming_bookings, digest, adapted}` or `{error}`).
  Future<Map<String, dynamic>> planProgress(String planId);
}

/// Coach OS — program WAITLIST (P0 #3). When a coach's slot is full, families
/// join a first-class, coach-owned list instead of bouncing. Backed by
/// `program_waitlist` (20260728_000300_waitlist.sql); RLS scopes every method
/// (family sees its own entries; coach sees their programs' lists). No money.
abstract class WaitlistRepository {
  /// Family-side: join the waitlist for a full program. Returns the new entry id
  /// (null on failure). `entry` carries programId + optional athlete display/note.
  Future<String?> joinWaitlist(Map<String, dynamic> entry);

  /// Family-side: this searcher's own waitlist entries (all statuses).
  Future<List<Map<String, dynamic>>> getMyWaitlistEntries();

  /// Family-side: withdraw one of the caller's own entries (status -> cancelled).
  Future<bool> cancelWaitlistEntry(String id);

  /// Coach-side: every waitlist entry across the caller's owned programs. RLS
  /// returns ONLY the coach's programs; the rows carry a denormalized athlete
  /// first name + age band only (never the athletes table — COPPA).
  Future<List<Map<String, dynamic>>> getWaitlistForProvider();

  /// Coach-side: move an entry through its lifecycle (offered/cancelled/expired/
  /// converted). Promotion to a real booking still rides the addBooking path.
  Future<bool> updateWaitlistStatus(String id, String status);

  // ── Provider Model Rebuild #8: WAITLIST OFFERS ──────────────────────────────
  // Backend: 20260729_000800_waitlist_offers.sql (waitlist_offers ledger,
  // open_waitlist_seat, roll_expired_waitlist_offers) + the deployed
  // `waitlist-offer-draft` edge fn. A seat-opens trigger already creates the
  // OFFER server-side (open_waitlist_seat); these methods READ that offer state
  // and let the coach (re)draft the agent's offer message. No new booking path:
  // accept rides the EXISTING claim_group_seat inside accept_waitlist_offer.

  /// Active/recent OFFERS (`drafted`/`sent`/`accepted`), one row per
  /// `waitlist_offers` entry. RLS scopes to the caller: the coach sees every
  /// offer for providers they own (incl. coach-only `drafted`); a family sees
  /// only their own entry's offers once `sent`. [providerId] narrows a coach's
  /// read to one provider; null returns everything the caller may see. Each map:
  /// `_id, entryId, status, serviceId, slotDate, slotTime, expiresAt,
  /// draftMessageId, createdAt`.
  Future<List<Map<String, dynamic>>> getWaitlistOffers({String? providerId});

  /// Coach: (re)draft the offer's coach-only ai_draft message via the
  /// `waitlist-offer-draft` edge function (idempotent — re-firing a
  /// already-drafted offer is a server-side no-op). Returns the function's JSON
  /// body (`{result, offer_id, draft_id, ...}` or `{skipped: ...}`), or
  /// `{'error': ...}` on failure (never throws — honest failure, L-015). This
  /// call NEVER sends anything — the coach still approves/sends the resulting
  /// ai_draft through the EXISTING draft card (L-003).
  Future<Map<String, dynamic>> draftWaitlistOffer(String offerId);

  /// Family: accept a `sent` offer. Rides the EXISTING `claim_group_seat`
  /// (invoked inside the DB's `accept_waitlist_offer`) — no new booking path.
  /// Returns the new booking id, or null on failure (expired / already taken /
  /// not open, L-015) — the caller surfaces the real reason honestly.
  Future<String?> acceptWaitlistOffer(String offerId, {String? athleteId});

  /// Family: decline a `drafted`/`sent` offer; the DB rolls the freed seat to
  /// the next eligible match. Returns true on success.
  Future<bool> declineWaitlistOffer(String offerId);
}

/// Coach OS — read-only FINANCE reads for tax-season export (P0 #3). Derives from
/// the provider's OWN paid bookings (same rows the finances screen already reads
/// for revenue). READ-ONLY: moves no money, opens no new Stripe surface (L-003).
abstract class FinanceRepository {
  /// Normalized earnings lines for the signed-in provider: one per paid/completed
  /// booking. Each map carries `id, family` (retained as historical relationship
  /// metadata), `date, athlete, program, sport, status, paymentStatus, gross,
  /// currency`, plus nullable webhook-recorded fee facts. Current transactions
  /// never infer a fee from the relationship.
  Future<List<Map<String, dynamic>>> getProviderEarnings();

  /// REAL Stripe Connect payout history for the signed-in coach (money page #1):
  /// bank transfers Stripe made to their connected account. READ-ONLY; derives
  /// from Stripe via the `stripe-provider-payouts` edge function. Returns [] only
  /// when there is genuinely nothing to show; function/network failures throw a
  /// user-safe [RepositoryActionException] so the UI can distinguish error from
  /// empty. Each map:
  /// `id, amountCents, currency, status, arrivalDate (unix s), bankLast4`.
  Future<List<Map<String, dynamic>>> getProviderPayouts();

  // ── Off-platform invoicing (money page #4) — DRAFT flow only ───────────────
  // Bill families Sporve did not source. Creating/listing DRAFT invoices is
  // read/write to coach-owned tables (RLS owner-scoped); the live Stripe CHARGE
  // is a separate, flagged, test-mode change (Env.offPlatformInvoicingCharge /
  // `coach-invoice-create`). NOTHING here moves money (L-003).

  /// The coach's own off-platform contacts (families Sporve did not source).
  Future<List<Map<String, dynamic>>> getCoachContacts();

  /// Create a coach-owned contact. Returns its new id, or null on failure.
  Future<String?> createCoachContact(Map<String, dynamic> contact);

  /// The coach's off-platform invoices (draft + any later states), newest first.
  Future<List<Map<String, dynamic>>> getCoachInvoices();

  /// Create a DRAFT invoice. Amount + any historical fee fact are pinned
  /// SERVER-SIDE (a DB trigger sums the line items) — the client only proposes
  /// line items. Returns the new invoice id, or null on failure. Charges nothing.
  Future<String?> createCoachInvoiceDraft(Map<String, dynamic> draft);
}

/// Coach OS — RECURRING WEEKLY SLOTS (AI Front Office #1). A coach's standing
/// weekly availability template ("Tuesdays 5pm, 60 min, $80") — publish once, it
/// exists every week. This is the SUPPLY side and COMPLEMENTS the family's
/// standing claim (`recurring_bookings`): a slot is what the coach OFFERS.
/// Backed by `recurring_slots` + `slot_exceptions`
/// (20260728_000500_recurring_slots.sql); RLS scopes writes to the owning coach,
/// and a skipped week writes a `slot_exception` WITHOUT deleting the slot. Prices
/// are integer CENTS; this surface moves NO money (a slot is a quote — L-003).
abstract class RecurringSlotRepository {
  /// Coach-side: the signed-in coach's own weekly slots (active first). Each map
  /// carries `_id, providerId, dayOfWeek (0=Sun..6=Sat), startTime ("HH:mm:ss"),
  /// durationMinutes, capacity, priceCents, currency, active, createdAt`.
  Future<List<Map<String, dynamic>>> getMyRecurringSlots();

  /// Coach-side: create ONE weekly slot. `slot` carries `dayOfWeek` (0-6),
  /// `startTime` ("HH:mm" 24h), `durationMinutes`, `capacity`, `priceCents`.
  /// provider_id is server-derived (owner RLS). Returns the new id (null on fail).
  Future<String?> createRecurringSlot(Map<String, dynamic> slot);

  /// Coach-side: pause/resume a slot (the `active` flag) WITHOUT losing it.
  Future<bool> setRecurringSlotActive(String slotId, bool active);

  /// Coach-side: SKIP one week — writes a `slot_exception` for [date] (ISO
  /// `yyyy-MM-dd`) so that occurrence isn't generated. Never deletes the slot.
  Future<bool> skipRecurringSlotWeek(
    String slotId,
    String date, {
    String? reason,
  });

  /// Coach-side: the recorded skip dates for one slot (ISO `yyyy-MM-dd` strings).
  Future<List<String>> getSlotExceptions(String slotId);
}

/// Provider Model Rebuild — Part 0 / item #1: the SERVICE (what a provider
/// SELLS). Backed by `public.services` (extended in
/// 20260729_000100_services_availability_locations.sql). A service carries NO
/// dates/times — price/capacity/duration only. Times come from the ONE shared
/// weekly availability (see [ProviderAvailabilityRepository]); the system
/// MULTIPLIES service × availability × location into bookable inventory via
/// [bookableSlots]. RLS scopes writes to the owning coach; public reads are
/// safety-gated (unverified coaches' services are invisible — L-005).
///
/// Supersedes the recurring_slots model: creating a SECOND service never asks
/// for times, because times live on the shared availability, not the service.
abstract class ServiceRepository {
  /// Coach-side: the signed-in coach's own services (active first). Each map:
  /// `_id, providerId, serviceType (private|group|camp|team_block), title,
  /// sport, durationMinutes, priceCents, capacity, locationId, active, createdAt`.
  Future<List<Map<String, dynamic>>> getMyServices();

  /// Coach-side: create ONE service. `service` carries `serviceType`, `title`,
  /// `sport`, `durationMinutes`, `priceCents`, `capacity`, optional `locationId`.
  /// NO times (that is availability). provider_id is server-derived (owner RLS).
  /// Returns the new id (null on failure).
  Future<String?> createService(Map<String, dynamic> service);

  /// Coach-side: patch a service (title/price/capacity/duration/location/active).
  /// Returns true on a confirmed write, false on failure (L-015).
  Future<bool> updateService(String serviceId, Map<String, dynamic> patch);

  /// Coach-side: pause/resume a service WITHOUT deleting it.
  Future<bool> setServiceActive(String serviceId, bool active);

  /// The MULTIPLICATION: candidate bookable slots for one service over a date
  /// window, generated from (service duration/capacity) × (the provider's shared
  /// weekly availability) × (location) − exceptions/vacation − already-booked.
  /// Read-only. Each map: `date` (yyyy-MM-dd — treat as a calendar day, never
  /// toLocal), `startTime`/`endTime` ("HH:mm:ss"), `capacity`, `booked`,
  /// `seatsRemaining`, `locationId`, `locationName`. Empty on failure.
  Future<List<Map<String, dynamic>>> bookableSlots({
    required String providerId,
    required String serviceId,
    required String fromDate, // yyyy-MM-dd
    required String toDate, // yyyy-MM-dd
  });

  /// Item #4 — the AI SETUP INTERVIEW's best-effort structured extraction. Sends
  /// the coach's OWN interview answers ([transcript]) + the resolved sport
  /// [template] bundle to the `setup-interview` Edge Function (ai-gateway) and
  /// returns a GROUNDED proposal bundle:
  ///   { 'services': [ {service_type,title,duration_minutes,price_cents,
  ///                     capacity,sport,source} ],
  ///     'weekly_availability': [ {day_of_week,start,end,source} ],
  ///     'policies': {cancellation,what_to_bring,source} }
  /// GROUNDING (L-012): every value is either a fact the coach stated
  /// (source='coach') or the template default (source='template', a labeled
  /// suggestion) — never a fabricated fact about THIS coach. BEST-EFFORT: returns
  /// null on any failure (offline / not-yet-deployed / model error); the caller
  /// then confirms the deterministic, offline template bundle instead. The confirm
  /// WRITES never go through here — they use createService / setWeeklyAvailability
  /// / saveCoachPolicies. Never throws.
  Future<Map<String, dynamic>?> refineSetupBundle({
    required String sport,
    required List<Map<String, String>> transcript,
    required Map<String, dynamic> template,
  });

  /// Provider Model Rebuild — item #6: ORG-LEVEL SERVICE staffing. Set whether a
  /// service is org-`assignable` and REPLACE the set of rostered trainers who may
  /// run it (`memberIds` = organization_members ids). Backed by services.assignable
  /// + service_assignable_members (20260729_000610). Returns true on a confirmed
  /// write, false on failure (L-015). Note: "any available trainer" (booking with
  /// no trainer) is allowed ONLY for group/camp — never private (DB-enforced).
  Future<bool> setServiceStaffing(
    String serviceId, {
    required bool assignable,
    required List<String> memberIds,
  });

  /// Provider Model Rebuild — item #6: the organization_members ids currently
  /// staffed on [serviceId]. Empty when none / on failure.
  Future<List<String>> getServiceStaffing(String serviceId);
}

/// Provider Model Rebuild — Part 0 / item #1: the ONE weekly AVAILABILITY per
/// provider (not per listing). Backed by `public.availability` + provider
/// settings (`buffer_minutes`, `vacation_until`) + `public.availability_exceptions`
/// (20260626 + 20260729_000100). Changing Tuesday here updates EVERY service,
/// because services reference this shared grid and carry no times of their own.
abstract class ProviderAvailabilityRepository {
  /// Coach-side: the signed-in coach's weekly grid. Each map:
  /// `_id, dayOfWeek (0=Sun..6=Sat), startTime/endTime ("HH:mm:ss"), isBlocked`.
  Future<List<Map<String, dynamic>>> getWeeklyAvailability();

  /// Coach-side: REPLACE the whole weekly grid with [blocks] (each carries
  /// `dayOfWeek`, `startTime` "HH:mm", `endTime` "HH:mm"). Deletes-then-inserts
  /// the caller's recurring rows so the UI can hand back the full edited grid.
  /// Returns true on a confirmed write, false on failure (L-015).
  Future<bool> setWeeklyAvailability(List<Map<String, dynamic>> blocks);

  /// Coach-side: the buffer-between-sessions (minutes) + vacation_until (ISO
  /// `yyyy-MM-dd` or null) settings on the caller's own provider row.
  Future<Map<String, dynamic>> getAvailabilitySettings();

  /// Coach-side: set buffer minutes and/or vacation_until (pass null to clear
  /// vacation). Returns true on a confirmed write, false on failure (L-015).
  Future<bool> setAvailabilitySettings({
    int? bufferMinutes,
    String? vacationUntil,
  });

  /// Coach-side: the recorded whole-day exception dates (ISO `yyyy-MM-dd`).
  Future<List<String>> getAvailabilityExceptions();

  /// Coach-side: skip a whole calendar day [date] (ISO `yyyy-MM-dd`) — upsert-safe
  /// (unique per provider+date). Returns true on success, false on failure.
  Future<bool> addAvailabilityException(String date, {String? reason});

  /// Coach-side: un-skip a previously-skipped day. Returns true on success.
  Future<bool> removeAvailabilityException(String date);
}

/// Provider Model Rebuild — Part 0 / item #1: saved LOCATIONS (venues). Backed
/// by `public.locations` (20260729_000100). A service may pin one via locationId.
/// RLS: owner CRUD; public read for verified providers.
abstract class LocationRepository {
  /// Coach-side: the signed-in coach's saved venues (active first). Each map:
  /// `_id, name, addressLine1, city, state, zip, lat, lng, active`.
  Future<List<Map<String, dynamic>>> getMyLocations();

  /// Coach-side: create a venue. `location` carries `name` + optional address/
  /// lat/lng fields. Returns the new id (null on failure).
  Future<String?> createLocation(Map<String, dynamic> location);

  /// Coach-side: patch a venue. Returns true on success, false on failure.
  Future<bool> updateLocation(String locationId, Map<String, dynamic> patch);

  /// Coach-side: remove a venue (services that pinned it are un-pinned — SET
  /// NULL, they are not deleted). Returns true on success.
  Future<bool> deleteLocation(String locationId);
}

/// Provider Model Rebuild — item #2: the THREE multi-booking mechanisms that all
/// attach to a SERVICE and read the SAME shared bookable inventory (bookable_slots):
/// GROUP SEATS (N families, one slot, auto-close at capacity), a RECURRING weekly
/// claim (the family's standing commitment), and prepaid PACK credits (redeem one
/// per booking). Backed by 20260729_0002xx. RLS/triggers guard every path; the
/// purchase CHARGE is Stripe and stays design-only (docs/PACKS-CHARGE-DESIGN.md —
/// L-003). Honest failure everywhere (L-015): expected unavailability returns
/// null-or-false; server failures throw [RepositoryActionException] so the UI
/// can render the backend's actionable message, never a fake success.
abstract class MultiBookingRepository {
  /// Group seats — claim ONE seat of a group service's shared slot. Atomic
  /// no-oversell: returns the new (or existing, idempotent for the same athlete)
  /// booking id, or NULL when the slot is unavailable. Server failures throw
  /// [RepositoryActionException]. `slotDate` is
  /// `yyyy-MM-dd` (a calendar day — never toLocal); `slotTime` is the 12h display
  /// string ("05:00 PM").
  Future<String?> claimGroupSeat({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  });

  /// Coach-side: the mini-roster for one group slot — first name + age band ONLY
  /// (L-005). Each map: `bookingId, athleteFirstName, athleteAgeBand, status,
  /// paymentStatus`. Empty for a slot the caller doesn't own / on failure.
  Future<List<Map<String, dynamic>>> groupSlotRoster({
    required String serviceId,
    required String slotDate,
    required String slotTime,
  });

  /// Family: start a RECURRING weekly claim on a service (the standing
  /// commitment). `claim` carries `serviceId`, `dayOfWeek` (0-6), `startTime`
  /// ("05:00 PM"), `startDate` (`yyyy-MM-dd`), `cadence` (weekly|biweekly),
  /// `occurrenceCount` OR `endDate`, optional `athleteId`/`athleteFirstName`/
  /// `athleteAgeBand`/`billingModel`/`packageSize`. provider_id is server-derived
  /// from the service. Returns the new id, or null when unavailable; server
  /// failures throw [RepositoryActionException]. The occurrences are
  /// generated server-side (service-role) after the coach approves — not here.
  Future<String?> createRecurringClaim(Map<String, dynamic> claim);

  /// Family: prepaid pack credits REMAINING for a service (0 when none / on
  /// failure). Read-only; reads the caller's own ledger (RLS).
  Future<int> creditBalanceForService(String serviceId);

  /// Family: redeem one pack credit by booking a slot of the service. Creates the
  /// booking (rides the same seat-claim rails); the actual credit DECREMENT is
  /// settled server-side (service-role) — the client never decrements. Returns the
  /// booking id, or NULL when there is no credit to redeem. Server failures
  /// throw [RepositoryActionException].
  Future<String?> redeemPackCredit({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  });

  /// Provider Model Rebuild — item #6: book ONE occurrence of an ORG service,
  /// optionally pinning a specific trainer ([assignedMemberId]). The resource +
  /// staffing invariants are DB-enforced (20260729_000600/000610) and mirrored in
  /// the mock, so this returns NULL (honest failure, L-015) when:
  ///   • the venue is already taken by a DIFFERENT service at this slot (double-book),
  ///   • [assignedMemberId] is null on a PRIVATE assignable service ("any available"
  ///     is group/camp only — never a 1-on-1),
  ///   • [assignedMemberId] is a trainer not staffed on the service,
  ///   • the slot is full.
  /// Returns the new booking id on success. `slotDate` is `yyyy-MM-dd` (a calendar
  /// day — never toLocal); `slotTime` is the canonical slot string ("HH:mm:ss").
  Future<String?> bookAssignableService({
    required String serviceId,
    required String slotDate,
    required String slotTime,
    String? assignedMemberId,
    String? athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
  });
}

/// Provider Model Rebuild — item #6: the ORG SCHEDULING grid. One scannable view
/// of all trainers × venues × time across the org's services, with booked/capacity
/// counts and a conflict flag. Backed by org_schedule_grid (20260729_000600),
/// admin-gated. Folds into the provider schedule area — NO new nav tab.
abstract class OrgSchedulingRepository {
  /// Coach/org-admin: the occupied (venue × trainer × slot) rows over a date
  /// window. Each map: `date` (yyyy-MM-dd — a calendar day, never toLocal),
  /// `slotTime` ("HH:mm:ss"), `locationId`, `locationName`, `serviceId`,
  /// `serviceTitle`, `assignedMemberId`, `trainerName`, `booked`, `capacity`,
  /// `hasConflict`. Empty for a non-admin / on failure.
  Future<List<Map<String, dynamic>>> orgScheduleGrid({
    required String fromDate, // yyyy-MM-dd
    required String toDate, // yyyy-MM-dd
  });
}

/// Provider Model Rebuild — item #6: the SHARED ORG INBOX. Routes every org
/// inquiry to the right trainer (by service/assignment) and attaches the draft the
/// existing draft-reply pipeline already wrote — it does NOT generate drafts.
/// Backed by org_inbox + route_conversation (20260729_000620), admin-gated.
abstract class SharedInboxRepository {
  /// Coach/org-admin: every org thread, routed, with its latest ai_draft. Each
  /// map: `conversationId`, `parentFirstName` (L-005: first name only),
  /// `serviceId`, `serviceTitle`, `assignedMemberId`, `trainerName`, `lastMessage`,
  /// `lastMessageAt`, `hasPendingDraft`, `draftId`, `draftBody`, `draftIntent`,
  /// `draftConfidence`. Empty for a non-admin / on failure.
  Future<List<Map<String, dynamic>>> orgInbox();

  /// Coach/org-admin: (re)route a thread to a service and/or a specific trainer.
  /// Pass null to clear. Ownership is DB-validated. Returns true on success.
  Future<bool> routeConversation({
    required String conversationId,
    String? serviceId,
    String? memberId,
  });
}

/// Provider Model Rebuild — item #7: CAMPS (a service type) + the ops layer.
/// A camp is `service_type='camp'` on the SAME services table with a date range,
/// daily hours, capacity, age band, and camp pricing (early-bird + deposit/balance).
/// REGISTRATION rides the group-seat rails (capacity auto-close inherited). Backed by
/// `20260729_000700_camps.sql` + `20260729_000701_camp_roster.sql`. No new nav tab.
abstract class CampRepository {
  /// Family-facing: the REAL, server-derived registration price for a camp as of a
  /// date. Returns `{fullPriceCents, dueNowCents, balanceCents, isEarlyBird,
  /// hasDeposit}` (all cents-exact), or NULL when the camp isn't visible / on
  /// failure. The actual Stripe charge is design-only (docs/CAMP-CHARGE-DESIGN.md,
  /// L-003) — this is display math. `asOf` is `yyyy-MM-dd`.
  Future<Map<String, dynamic>?> campPriceDue({
    required String serviceId,
    required String asOf,
  });

  /// Family: register the caller's OWN athlete for a camp. Rides the group-seat
  /// no-oversell claim, so a FULL camp returns NULL (honest failure, L-015). On the
  /// real backend the emergency/medical PII is copied server-side from the owned
  /// athlete; the optional hints below are only used by the demo/mock (mirrors the
  /// `claimGroupSeat` athlete-hint pattern) and are IGNORED by the server. Returns
  /// the registration booking id, or NULL when full / on failure. The seat is
  /// created unpaid/pending — no money moves (L-003).
  Future<String?> registerCampAthlete({
    required String serviceId,
    required String athleteId,
    String? athleteFirstName,
    String? athleteAgeBand,
    Map<String, dynamic>? emergencyContact,
    String? medicalNotes,
  });

  /// STAFF-ONLY: the camp roster with emergency + allergy/medical fields, plus the
  /// given day's check-in state. Each map: `rosterId, bookingId, athleteFirstName,
  /// athleteAgeBand, emergencyContact, medicalNotes, checkedInAt`. On the real
  /// backend a non-staff caller gets an EMPTY list (RLS/gate, L-005); [asStaff] is a
  /// mock-only switch to exercise that gate in tests and is ignored by the server.
  Future<List<Map<String, dynamic>>> campRoster({
    required String serviceId,
    required String day,
    bool asStaff = true,
  });

  /// STAFF-ONLY: tap check-in for one roster entry on a day (one state per entry
  /// per day; a re-tap refreshes it). Returns the check-in time, or NULL when the
  /// caller isn't assigned staff / on failure (L-015).
  Future<DateTime?> campCheckIn({
    required String rosterId,
    required String day,
  });

  /// Coach: end-of-day recap — the coach taps the day's skills/effort/note ONCE
  /// and the `camp-recap` Edge Function drafts a warm, grounded per-family recap
  /// into `parent_updates` (status='draft') for every registered family, via the
  /// EXISTING parent-update send rails. This DRAFTS ONLY — nothing is sent; the
  /// coach reviews and sends each from the existing screen (never auto-send,
  /// L-012). Returns `{created, skipped, recapText}` on success, or `{'error':
  /// ...}` on failure (never throws — honest failure, L-015).
  Future<Map<String, dynamic>> campRecapDraft({
    required String serviceId,
    required String day,
    List<String> skills = const [],
    int? effort, // 1..3
    String? note,
  });

  /// Coach: bulk-message every registered family via the `camp-broadcast` Edge
  /// Function. Each family gets a coach-only DRAFT message in their existing
  /// thread (visible_to_parent=false) — never auto-sent (L-012); the coach
  /// approves + sends each from the shared inbox. Returns `{drafted, families,
  /// skipped}` on success, or `{'error': ...}` on failure (never throws).
  Future<Map<String, dynamic>> campBroadcast({
    required String serviceId,
    required String message,
  });
}

/// Provider Model Rebuild #9 — TEAM BLOCKS. A team is a BUYER, not an account: a
/// `team_block` is N sessions bought for a ROSTER of families, against a
/// service_type='team_block' service. Two payment shapes — one payer, or a
/// split-pay link per family. Redeeming a split share provisions that family as a
/// COPPA-consented Sporve parent + child and generates their bookings ("one team
/// deal onboards a dozen parents"). Money MOVEMENT is design-only (L-003): these
/// methods author the STRUCTURE + share math, never a live charge. Backends:
/// 20260729_000900_team_blocks.sql; share math: core/utils/team_split.dart.
abstract class TeamBlockRepository {
  /// Coach/org: create a team block against their own team_block service. Returns
  /// the block id, or NULL on failure (L-015). No money moves — this is the buyer
  /// construct + its session count / per-session price only.
  Future<String?> createTeamBlock({
    required String serviceId,
    String? teamName,
    required int sessionCount,
    required int unitPriceCents,
    required String paymentMode, // 'one_payer' | 'split_pay'
    String? onePayerProfileId,
  });

  /// Coach: add a family to the block's ROSTER (email/phone/label — NO minor PII).
  /// Returns the member id, or NULL on failure.
  Future<String?> addTeamBlockMember({
    required String teamBlockId,
    String? invitedEmail,
    String? invitedPhone,
    String? memberLabel,
  });

  /// Coach (split_pay blocks): generate one payment link per roster family with a
  /// penny-exact share (mirrors team_split.splitShares). Returns the number of links
  /// created/refreshed, or NULL on failure. Turning a link into a real Stripe
  /// payment link + capturing the charge is design-only behind a flag (L-003).
  Future<int?> createSplitPayLinks({required String teamBlockId});

  /// Family: redeem a split-pay link by TOKEN. Captures COPPA consent, provisions
  /// the caller's athlete, marks the share paid, and generates the block's N session
  /// bookings for the child (riding the existing bookings rail). Returns the count of
  /// bookings generated, or NULL on failure (invalid/used token, missing consent).
  /// No real charge (L-003) — bookings land unpaid; the link 'paid' is structure.
  Future<int?> redeemSplitShare({
    required String token,
    required String athleteFirstName,
    String? athleteDob, // yyyy-MM-dd
    required String consentVersion,
  });

  /// Coach: the split-pay status view — one entry per roster family with its share,
  /// paid/pending state, and onboarding state. Each map: `memberId, memberLabel,
  /// invitedEmail, invitedPhone, shareAmountCents, platformFeeCents, linkStatus,
  /// paidAt, memberStatus, athleteFirstName`. Empty to non-owners (owner gate).
  Future<List<Map<String, dynamic>>> teamBlockSplitStatus({
    required String teamBlockId,
  });
}

abstract class AppRepository
    implements
        BillingRepository,
        ProgramRepository,
        ServiceRepository,
        MultiBookingRepository,
        CampRepository,
        TeamBlockRepository,
        OrgSchedulingRepository,
        SharedInboxRepository,
        ProviderAvailabilityRepository,
        LocationRepository,
        RecurringSlotRepository,
        WaitlistRepository,
        FinanceRepository,
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

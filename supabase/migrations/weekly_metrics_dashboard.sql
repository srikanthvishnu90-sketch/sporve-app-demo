-- =============================================================================
-- WEEKLY METRICS RITUAL & DASHBOARD (PRE-LAUNCH DEFINITION)
-- Key Metrics: Searches, Matches Shown, Bookings, Coach Activation, Time-to-first-booking
-- THE Metric: REPEAT-BOOKING RATE (Marketplace Leakage Thermometer)
-- =============================================================================

CREATE OR REPLACE VIEW v_weekly_marketplace_metrics AS
WITH repeat_parents AS (
    -- Parents who have booked the SAME coach more than once
    SELECT parent_id, coach_id, COUNT(*) as booking_count
    FROM bookings
    WHERE status IN ('paid', 'confirmed', 'completed')
    GROUP BY parent_id, coach_id
),
parent_repeat_summary AS (
    SELECT 
        COUNT(DISTINCT parent_id) AS total_booking_parents,
        COUNT(DISTINCT CASE WHEN booking_count > 1 THEN parent_id END) AS repeat_booking_parents
    FROM repeat_parents
),
coach_activation AS (
    -- Time to first booking and activation rate for coaches
    SELECT 
        COUNT(DISTINCT id) AS total_coaches,
        COUNT(DISTINCT CASE WHEN first_booking_at IS NOT NULL THEN id END) AS activated_coaches,
        AVG(EXTRACT(EPOCH FROM (first_booking_at - created_at))/3600)::NUMERIC(10,2) AS avg_hours_to_first_booking
    FROM coach_profiles
)
SELECT
    -- 1. Searches & Conversions
    (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'funnel_client_search' AND created_at >= NOW() - INTERVAL '7 days') AS searches_last_7d,
    (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'funnel_client_profile_view' AND created_at >= NOW() - INTERVAL '7 days') AS matches_viewed_last_7d,
    (SELECT COUNT(*) FROM bookings WHERE created_at >= NOW() - INTERVAL '7 days') AS total_bookings_last_7d,
    
    -- 2. Coach Activation Metrics
    ca.total_coaches,
    ca.activated_coaches,
    ROUND((ca.activated_coaches::NUMERIC / NULLIF(ca.total_coaches, 0)) * 100, 2) AS coach_activation_rate_pct,
    ca.avg_hours_to_first_booking,

    -- 3. THE NUMBER: REPEAT-BOOKING RATE (Leakage Thermometer)
    -- High repeat rate = Families love staying on platform. Low = Leakage to cash.
    prs.total_booking_parents,
    prs.repeat_booking_parents,
    ROUND((prs.repeat_booking_parents::NUMERIC / NULLIF(prs.total_booking_parents, 0)) * 100, 2) AS repeat_booking_rate_pct,

    NOW() AS report_generated_at
FROM parent_repeat_summary prs, coach_activation ca;

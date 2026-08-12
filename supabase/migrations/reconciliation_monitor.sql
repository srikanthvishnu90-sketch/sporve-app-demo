-- =============================================================================
-- RECONCILIATION MONITOR: Daily check that Stripe events processed = bookings updated
-- Alert on money-state drift (The bug class that quietly kills marketplaces)
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_date DATE NOT NULL DEFAULT CURRENT_DATE,
    stripe_charge_count INT NOT NULL,
    booking_paid_count INT NOT NULL,
    drift_detected BOOLEAN NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION check_stripe_reconciliation()
RETURNS TABLE(stripe_count INT, db_count INT, has_drift BOOLEAN, message TEXT) AS $$
DECLARE
    v_stripe_count INT;
    v_booking_count INT;
    v_has_drift BOOLEAN;
    v_msg TEXT;
BEGIN
    -- 1. Count completed payment records in last 24 hours
    SELECT COUNT(*) INTO v_stripe_count
    FROM payment_transactions
    WHERE status = 'succeeded'
      AND created_at >= NOW() - INTERVAL '24 hours';

    -- 2. Count confirmed paid bookings in last 24 hours
    SELECT COUNT(*) INTO v_booking_count
    FROM bookings
    WHERE status IN ('paid', 'confirmed', 'completed')
      AND updated_at >= NOW() - INTERVAL '24 hours';

    -- 3. Compare for drift
    IF v_stripe_count <> v_booking_count THEN
        v_has_drift := TRUE;
        v_msg := FORMAT('DRIFT ALERT: Stripe processed %s payments but DB has %s paid bookings in 24h window.', v_stripe_count, v_booking_count);
    ELSE
        v_has_drift := FALSE;
        v_msg := 'RECONCILIATION PASSED: Stripe payments equal DB paid bookings.';
    END IF;

    -- 4. Log audit entry
    INSERT INTO reconciliation_logs(stripe_charge_count, booking_paid_count, drift_detected, notes)
    VALUES (v_stripe_count, v_booking_count, v_has_drift, v_msg);

    RETURN QUERY SELECT v_stripe_count, v_booking_count, v_has_drift, v_msg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule daily cron execution if pg_cron is enabled in Supabase
-- SELECT cron.schedule('stripe-reconciliation-daily', '0 3 * * *', 'SELECT check_stripe_reconciliation();');

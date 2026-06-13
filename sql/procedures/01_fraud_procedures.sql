-- ============================================================
-- procedures/01_fraud_procedures.sql
-- Stored procedures untuk fraud analysis & reporting
-- ============================================================

-- ── Procedure 1: Monthly fraud report ───────────────────────
CREATE OR REPLACE FUNCTION fn_monthly_fraud_report(
    p_year  INTEGER DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER,
    p_month INTEGER DEFAULT EXTRACT(MONTH FROM NOW())::INTEGER
)
RETURNS TABLE (
    metric      TEXT,
    value       TEXT
) AS $$
DECLARE
    v_total_tx      BIGINT;
    v_fraud_tx      BIGINT;
    v_fraud_rate    NUMERIC;
    v_total_amount  NUMERIC;
    v_fraud_amount  NUMERIC;
    v_high_risk     BIGINT;
    v_prev_fraud_rate NUMERIC;
BEGIN
    -- Hitung metrik bulan ini
    SELECT
        COUNT(*),
        SUM(is_fraud),
        ROUND(AVG(is_fraud) * 100, 2),
        SUM(transaction_amount),
        SUM(CASE WHEN is_fraud = 1 THEN transaction_amount ELSE 0 END),
        SUM(CASE WHEN risk_level = 'High' THEN 1 ELSE 0 END)
    INTO v_total_tx, v_fraud_tx, v_fraud_rate, v_total_amount, v_fraud_amount, v_high_risk
    FROM fraud_predictions
    WHERE EXTRACT(YEAR  FROM transaction_created_datetime) = p_year
      AND EXTRACT(MONTH FROM transaction_created_datetime) = p_month;

    -- Fraud rate bulan sebelumnya
    SELECT ROUND(AVG(is_fraud) * 100, 2)
    INTO v_prev_fraud_rate
    FROM fraud_predictions
    WHERE transaction_created_datetime >= (
        DATE_TRUNC('month', MAKE_DATE(p_year, p_month, 1)) - INTERVAL '1 month'
    )
    AND transaction_created_datetime < DATE_TRUNC('month', MAKE_DATE(p_year, p_month, 1));

    RETURN QUERY VALUES
        ('Period',              TO_CHAR(MAKE_DATE(p_year, p_month, 1), 'Month YYYY')),
        ('Total Transactions',  COALESCE(v_total_tx::TEXT, '0')),
        ('Fraud Transactions',  COALESCE(v_fraud_tx::TEXT, '0')),
        ('Fraud Rate (%)',       COALESCE(v_fraud_rate::TEXT, '0')),
        ('Prev Month Rate (%)',  COALESCE(v_prev_fraud_rate::TEXT, 'N/A')),
        ('MoM Change (%)',       COALESCE((v_fraud_rate - v_prev_fraud_rate)::TEXT, 'N/A')),
        ('Total Amount (IDR)',   COALESCE(TO_CHAR(v_total_amount, 'FM999,999,999,999'), '0')),
        ('Fraud Amount (IDR)',   COALESCE(TO_CHAR(v_fraud_amount, 'FM999,999,999,999'), '0')),
        ('High Risk Count',      COALESCE(v_high_risk::TEXT, '0'));
END;
$$ LANGUAGE plpgsql;

-- ── Procedure 2: Deteksi promo misuse ───────────────────────
CREATE OR REPLACE FUNCTION fn_promo_misuse_detection(
    p_threshold INTEGER DEFAULT 5
)
RETURNS TABLE (
    buyer_id                TEXT,
    promo_usage_count       BIGINT,
    total_amount            NUMERIC,
    fraud_count             BIGINT,
    fraud_rate              NUMERIC,
    avg_fraud_prob          NUMERIC,
    company_type            TEXT,
    kyc_status              TEXT,
    risk_label              TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        fp.buyer_id,
        COUNT(*)                                AS promo_usage_count,
        SUM(fp.transaction_amount)              AS total_amount,
        SUM(fp.is_fraud::INTEGER)::BIGINT                AS fraud_count,
        ROUND(AVG(fp.is_fraud) * 100, 2)        AS fraud_rate,
        ROUND(AVG(fp.fraud_probability)::NUMERIC, 4) AS avg_fraud_prob,
        c.company_type_group                    AS company_type,
        c.company_kyc_status_name               AS kyc_status,
        CASE
            WHEN AVG(fp.fraud_probability) > 0.6 THEN 'HIGH RISK'
            WHEN AVG(fp.fraud_probability) > 0.3 THEN 'MEDIUM RISK'
            ELSE 'LOW RISK'
        END AS risk_label
    FROM fraud_predictions fp
    LEFT JOIN dim_company c ON fp.buyer_id = c.company_id
    WHERE fp.promo_usage_count_buyer >= p_threshold
    GROUP BY fp.buyer_id, c.company_type_group, c.company_kyc_status_name
    ORDER BY promo_usage_count DESC;
END;
$$ LANGUAGE plpgsql;

-- ── Procedure 3: High risk account summary ───────────────────
CREATE OR REPLACE FUNCTION fn_high_risk_accounts(
    p_min_fraud_prob NUMERIC DEFAULT 0.6,
    p_min_tx         INTEGER DEFAULT 3
)
RETURNS TABLE (
    account_id      TEXT,
    role            TEXT,
    total_tx        BIGINT,
    fraud_tx        BIGINT,
    fraud_rate_pct  NUMERIC,
    avg_fraud_prob  NUMERIC,
    total_amount    NUMERIC,
    pagerank        NUMERIC,
    account_status  TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH buyer_stats AS (
        SELECT
            fp.buyer_id          AS account_id,
            'BUYER'::TEXT        AS role,
            COUNT(*)             AS total_tx,
            SUM(fp.is_fraud::INTEGER)::BIGINT AS fraud_tx,
            ROUND(AVG(fp.is_fraud) * 100, 2) AS fraud_rate_pct,
            ROUND(AVG(fp.fraud_probability)::NUMERIC, 4) AS avg_fraud_prob,
            SUM(fp.transaction_amount) AS total_amount
        FROM fraud_predictions fp
        GROUP BY fp.buyer_id
        HAVING AVG(fp.fraud_probability) >= p_min_fraud_prob
           AND COUNT(*) >= p_min_tx
    ),
    seller_stats AS (
        SELECT
            fp.seller_id         AS account_id,
            'SELLER'::TEXT       AS role,
            COUNT(*)             AS total_tx,
            SUM(fp.is_fraud::INTEGER)::BIGINT AS fraud_tx,
            ROUND(AVG(fp.is_fraud) * 100, 2) AS fraud_rate_pct,
            ROUND(AVG(fp.fraud_probability)::NUMERIC, 4) AS avg_fraud_prob,
            SUM(fp.transaction_amount) AS total_amount
        FROM fraud_predictions fp
        GROUP BY fp.seller_id
        HAVING AVG(fp.fraud_probability) >= p_min_fraud_prob
           AND COUNT(*) >= p_min_tx
    ),
    combined AS (
        SELECT * FROM buyer_stats
        UNION ALL
        SELECT * FROM seller_stats
    )
    SELECT
        c.account_id,
        c.role,
        c.total_tx,
        c.fraud_tx,
        c.fraud_rate_pct,
        c.avg_fraud_prob,
        c.total_amount,
        nn.pagerank,
        CASE
            WHEN dc.user_fraud_flag = 1 AND dc.blacklist_account_flag = 1 THEN 'FRAUD + BLACKLIST'
            WHEN dc.user_fraud_flag = 1                                   THEN 'FRAUD FLAGGED'
            WHEN dc.blacklist_account_flag = 1                            THEN 'BLACKLISTED'
            ELSE 'ML DETECTED'
        END AS account_status
    FROM combined c
    LEFT JOIN network_nodes nn ON c.account_id = nn.node
    LEFT JOIN dim_company   dc ON c.account_id = dc.company_id
    ORDER BY c.avg_fraud_prob DESC, c.total_tx DESC;
END;
$$ LANGUAGE plpgsql;

\echo '✅ Procedures created: fn_monthly_fraud_report,'
\echo '                       fn_promo_misuse_detection,'
\echo '                       fn_high_risk_accounts'

-- ============================================================
-- views/01_fraud_views.sql
-- Views untuk analisis fraud — siap pakai di Tableau & query
-- ============================================================

-- ── View 1: Ringkasan per transaksi (join semua tabel) ───────
CREATE OR REPLACE VIEW vw_transaction_detail AS
SELECT
    fp.dpt_id,
    fp.buyer_id,
    fp.seller_id,
    fp.transaction_amount,
    fp.transaction_created_datetime,
    DATE_TRUNC('month', fp.transaction_created_datetime) AS transaction_month,
    EXTRACT(YEAR  FROM fp.transaction_created_datetime)  AS year,
    EXTRACT(MONTH FROM fp.transaction_created_datetime)  AS month,
    EXTRACT(DOW   FROM fp.transaction_created_datetime)  AS day_of_week,
    EXTRACT(HOUR  FROM fp.transaction_created_datetime)  AS hour,
    fp.is_fraud,
    fp.fraud_probability,
    fp.fraud_predicted,
    fp.risk_level,
    fp.is_burst,
    fp.is_outlier_iqr,
    fp.transaction_count,
    fp.relationship_score_z,
    -- Buyer info
    bc.company_type_group   AS buyer_type,
    bc.company_kyc_status_name AS buyer_kyc,
    bc.user_fraud_flag      AS buyer_fraud_flag,
    bc.blacklist_account_flag AS buyer_blacklist,
    fp.buyer_company_age_days,
    -- Seller info
    sc.company_type_group   AS seller_type,
    sc.company_kyc_status_name AS seller_kyc,
    sc.user_fraud_flag      AS seller_fraud_flag,
    fp.seller_company_age_days
FROM fraud_predictions fp
LEFT JOIN dim_company bc ON fp.buyer_id  = bc.company_id
LEFT JOIN dim_company sc ON fp.seller_id = sc.company_id;

-- ── View 2: Top flagged buyer-seller pairs ───────────────────
CREATE OR REPLACE VIEW vw_top_fraud_pairs AS
SELECT
    ne.buyer_id,
    ne.seller_id,
    ne.tx_count,
    ne.fraud_count,
    ne.fraud_rate,
    ne.weight          AS total_amount,
    ne.fraud_prob_avg,
    bc.company_type_group AS buyer_type,
    sc.company_type_group AS seller_type,
    bc.company_kyc_status_name AS buyer_kyc,
    CASE
        WHEN ne.fraud_rate > 0.5 AND ne.tx_count > 10 THEN 'HIGH RISK'
        WHEN ne.fraud_rate > 0.2                       THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS pair_risk_label
FROM network_edges ne
LEFT JOIN dim_company bc ON ne.buyer_id  = bc.company_id
LEFT JOIN dim_company sc ON ne.seller_id = sc.company_id
WHERE ne.fraud_count > 0
ORDER BY ne.fraud_rate DESC, ne.tx_count DESC;

-- ── View 3: Flagged accounts ─────────────────────────────────
CREATE OR REPLACE VIEW vw_flagged_accounts AS
SELECT
    c.company_id,
    c.company_type_group,
    c.company_kyc_status_name,
    c.company_kyb_status_name,
    c.user_fraud_flag,
    c.blacklist_account_flag,
    c.package_active_name,
    c.company_age_days,
    nn.pagerank,
    nn.in_degree,
    nn.out_degree,
    nn.fraud_count       AS network_fraud_count,
    nn.avg_fraud_prob,
    CASE
        WHEN c.user_fraud_flag = 1 AND c.blacklist_account_flag = 1 THEN 'FRAUD + BLACKLIST'
        WHEN c.user_fraud_flag = 1                                   THEN 'FRAUD ONLY'
        WHEN c.blacklist_account_flag = 1                            THEN 'BLACKLIST ONLY'
        ELSE 'CLEAN'
    END AS account_status
FROM dim_company c
LEFT JOIN network_nodes nn ON c.company_id = nn.node
WHERE c.user_fraud_flag = 1 OR c.blacklist_account_flag = 1;

-- ── View 4: Monthly fraud trend ──────────────────────────────
CREATE OR REPLACE VIEW vw_monthly_fraud_trend AS
SELECT
    DATE_TRUNC('month', transaction_created_datetime) AS month,
    TO_CHAR(transaction_created_datetime, 'Mon YYYY') AS month_label,
    COUNT(*)                                          AS total_transactions,
    SUM(transaction_amount)                           AS total_amount,
    SUM(is_fraud)                                     AS fraud_count,
    SUM(CASE WHEN is_fraud = 1 THEN transaction_amount ELSE 0 END) AS fraud_amount,
    ROUND(AVG(is_fraud) * 100, 2)                     AS fraud_rate_pct,
    ROUND(AVG(fraud_probability)::NUMERIC, 4)         AS avg_fraud_prob,
    SUM(CASE WHEN risk_level = 'High'   THEN 1 ELSE 0 END) AS high_risk_count,
    SUM(CASE WHEN risk_level = 'Medium' THEN 1 ELSE 0 END) AS medium_risk_count
FROM fraud_predictions
GROUP BY 1, 2
ORDER BY 1;

-- ── View 5: Risk distribution by company type ────────────────
CREATE OR REPLACE VIEW vw_risk_by_company_type AS
SELECT
    bc.company_type_group   AS buyer_type,
    bc.company_kyc_status_name AS buyer_kyc,
    COUNT(*)                AS total_tx,
    SUM(fp.is_fraud)        AS fraud_count,
    ROUND(AVG(fp.is_fraud) * 100, 2) AS fraud_rate_pct,
    ROUND(AVG(fp.fraud_probability)::NUMERIC, 4) AS avg_fraud_prob,
    SUM(fp.transaction_amount) AS total_amount
FROM fraud_predictions fp
LEFT JOIN dim_company bc ON fp.buyer_id = bc.company_id
GROUP BY 1, 2
ORDER BY fraud_rate_pct DESC;

\echo '✅ Views created: vw_transaction_detail, vw_top_fraud_pairs,'
\echo '                  vw_flagged_accounts, vw_monthly_fraud_trend,'
\echo '                  vw_risk_by_company_type'

-- ============================================================
-- 02_import_csv.sql (FIXED)
-- ============================================================

-- ── dim_company ───────────────────────────────────────────────
\echo 'Importing dim_company...'

CREATE TEMP TABLE tmp_company (
    company_id                  TEXT,
    company_kyc_status_name     TEXT,
    company_kyb_status_name     TEXT,
    company_type_group          TEXT,
    company_phone_verified_flag TEXT,
    company_email_verified_flag TEXT,
    user_fraud_flag             TEXT,
    testing_account_flag        TEXT,
    blacklist_account_flag      TEXT,
    package_active_name         TEXT,
    company_registered_datetime TEXT
);

COPY tmp_company
FROM 'D:\Project\data-engineer\paperid-fraud-detection\data\raw\dim__paper__company.csv'
WITH (FORMAT csv, HEADER true, NULL '');

INSERT INTO dim_company SELECT
    company_id,
    company_kyc_status_name,
    company_kyb_status_name,
    company_type_group,
    ROUND(COALESCE(company_phone_verified_flag::NUMERIC, 0))::SMALLINT,
    ROUND(COALESCE(company_email_verified_flag::NUMERIC, 0))::SMALLINT,
    ROUND(COALESCE(user_fraud_flag::NUMERIC,             0))::SMALLINT,
    ROUND(COALESCE(testing_account_flag::NUMERIC,        0))::SMALLINT,
    ROUND(COALESCE(blacklist_account_flag::NUMERIC,      0))::SMALLINT,
    package_active_name,
    company_registered_datetime::TIMESTAMP
FROM tmp_company;

UPDATE dim_company
SET company_age_days = EXTRACT(DAY FROM NOW() - company_registered_datetime)::INTEGER;

DROP TABLE tmp_company;
\echo 'dim_company OK'

-- ── dim_promotion (4 kolom: id, code, name, cashback_amount) ──
\echo 'Importing dim_promotion...'

CREATE TEMP TABLE tmp_promotion (
    dpt_promotion_id                TEXT,
    promotion_code                  TEXT,
    promotion_name                  TEXT,
    transaction_promo_cashback_amount TEXT
);

COPY tmp_promotion
FROM 'D:\Project\data-engineer\paperid-fraud-detection\data\raw\dim__paper__promotion.csv'
WITH (FORMAT csv, HEADER true, NULL '');

INSERT INTO dim_promotion (dpt_promotion_id, promotion_code, promotion_name)
SELECT dpt_promotion_id, promotion_code, promotion_name
FROM tmp_promotion
WHERE dpt_promotion_id IS NOT NULL AND dpt_promotion_id <> '';

DROP TABLE tmp_promotion;
\echo 'dim_promotion OK'

-- ── fact_transactions ─────────────────────────────────────────
\echo 'Importing fact_transactions...'

COPY fact_transactions (
    dpt_id, dpt_promotion_id, buyer_id, seller_id,
    transaction_amount, payment_method_name, payment_provider_name,
    transaction_created_datetime, transaction_updated_datetime
)
FROM 'D:\Project\data-engineer\paperid-fraud-detection\data\raw\fact__paper__digital_payment_transaction.csv'
WITH (FORMAT csv, HEADER true, NULL '');

\echo 'fact_transactions OK'

-- ── fraud_predictions (kolom sesuai header CSV aktual) ────────
\echo 'Importing fraud_predictions...'

CREATE TEMP TABLE tmp_fraud (
    transaction_amount          TEXT,
    transaction_amount_scaled   TEXT,
    is_outlier_iqr              TEXT,
    anomaly                     TEXT,
    transaction_count           TEXT,
    relationship_score_z        TEXT,
    relationship_anomaly        TEXT,
    time_diff_minutes           TEXT,
    time_diff_minutes_zscore    TEXT,
    is_burst                    TEXT,
    burst_intensity             TEXT,
    is_unusual_gap              TEXT,
    promo_usage_count_buyer     TEXT,
    promo_usage_count_seller    TEXT,
    promo_exploit_buyer         TEXT,
    promo_exploit_seller        TEXT,
    buyer_company_age_days      TEXT,
    seller_company_age_days     TEXT,
    dpt_id                      TEXT,
    buyer_id                    TEXT,
    seller_id                   TEXT,
    transaction_amount2         TEXT,
    transaction_created_datetime TEXT,
    is_fraud                    TEXT,
    fraud_probability           TEXT,
    fraud_predicted             TEXT,
    risk_level                  TEXT
);

COPY tmp_fraud
FROM 'D:\Project\data-engineer\paperid-fraud-detection\data\processed\fraud_predictions.csv'
WITH (FORMAT csv, HEADER true, NULL '');

INSERT INTO fraud_predictions (
    dpt_id, buyer_id, seller_id,
    transaction_amount, transaction_created_datetime,
    is_fraud, fraud_probability, fraud_predicted, risk_level,
    transaction_count, is_burst, is_outlier_iqr, anomaly,
    promo_usage_count_buyer, relationship_score_z,
    buyer_company_age_days, seller_company_age_days
)
SELECT
    dpt_id,
    buyer_id,
    seller_id,
    transaction_amount::NUMERIC,
    transaction_created_datetime::TIMESTAMP,
    ROUND(is_fraud::NUMERIC)::SMALLINT,
    fraud_probability::NUMERIC,
    ROUND(fraud_predicted::NUMERIC)::SMALLINT,
    risk_level,
    ROUND(transaction_count::NUMERIC)::INTEGER,
    ROUND(is_burst::NUMERIC)::SMALLINT,
    ROUND(is_outlier_iqr::NUMERIC)::SMALLINT,
    ROUND(anomaly::NUMERIC)::SMALLINT,
    ROUND(promo_usage_count_buyer::NUMERIC)::INTEGER,
    relationship_score_z::NUMERIC,
    ROUND(buyer_company_age_days::NUMERIC)::INTEGER,
    CASE WHEN seller_company_age_days ~ '^\d' 
         THEN ROUND(seller_company_age_days::NUMERIC)::INTEGER 
         ELSE NULL END
FROM tmp_fraud;

DROP TABLE tmp_fraud;
\echo 'fraud_predictions OK'

-- ── Verifikasi ────────────────────────────────────────────────
\echo ''
\echo '=== ROW COUNTS ==='
SELECT 'dim_company'       AS tbl, COUNT(*) FROM dim_company
UNION ALL
SELECT 'dim_promotion',              COUNT(*) FROM dim_promotion
UNION ALL
SELECT 'fact_transactions',          COUNT(*) FROM fact_transactions
UNION ALL
SELECT 'fraud_predictions',          COUNT(*) FROM fraud_predictions
UNION ALL
SELECT 'network_nodes',              COUNT(*) FROM network_nodes
UNION ALL
SELECT 'network_edges',              COUNT(*) FROM network_edges;

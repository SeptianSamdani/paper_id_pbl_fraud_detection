-- ============================================================
-- 01_create_tables.sql
-- Setup schema untuk Paper.id Fraud Detection
-- ============================================================

-- Drop jika sudah ada (untuk re-run)
DROP TABLE IF EXISTS fraud_predictions CASCADE;
DROP TABLE IF EXISTS dim_company CASCADE;
DROP TABLE IF EXISTS dim_promotion CASCADE;
DROP TABLE IF EXISTS fact_transactions CASCADE;
DROP TABLE IF EXISTS network_nodes CASCADE;
DROP TABLE IF EXISTS network_edges CASCADE;

-- ── Dimension: Company ───────────────────────────────────────
CREATE TABLE dim_company (
    company_id                  TEXT PRIMARY KEY,
    company_kyc_status_name     TEXT,
    company_kyb_status_name     TEXT,
    company_type_group          TEXT,
    company_phone_verified_flag SMALLINT,
    company_email_verified_flag SMALLINT,
    user_fraud_flag             SMALLINT,
    testing_account_flag        SMALLINT,
    blacklist_account_flag      SMALLINT,
    package_active_name         TEXT,
    company_registered_datetime TIMESTAMP,
    company_age_days            INTEGER
);

-- ── Dimension: Promotion ─────────────────────────────────────
CREATE TABLE dim_promotion (
    dpt_promotion_id    TEXT PRIMARY KEY,
    promotion_code      TEXT,
    promotion_name      TEXT
);

-- ── Fact: Transactions ───────────────────────────────────────
CREATE TABLE fact_transactions (
    dpt_id                          TEXT PRIMARY KEY,
    buyer_id                        TEXT,
    seller_id                       TEXT,
    transaction_amount              NUMERIC(20, 2),
    payment_method_name             TEXT,
    payment_provider_name           TEXT,
    transaction_created_datetime    TIMESTAMP,
    transaction_updated_datetime    TIMESTAMP,
    dpt_promotion_id                TEXT
);

-- ── Fraud Predictions (output ML) ───────────────────────────
CREATE TABLE fraud_predictions (
    dpt_id                      TEXT PRIMARY KEY,
    buyer_id                    TEXT,
    seller_id                   TEXT,
    transaction_amount          NUMERIC(20, 2),
    transaction_created_datetime TIMESTAMP,
    is_fraud                    SMALLINT,
    fraud_probability           NUMERIC(6, 5),
    fraud_predicted             SMALLINT,
    risk_level                  TEXT,
    transaction_count           INTEGER,
    is_burst                    SMALLINT,
    is_outlier_iqr              SMALLINT,
    anomaly                     SMALLINT,
    promo_usage_count_buyer     INTEGER,
    relationship_score_z        NUMERIC(10, 6),
    buyer_company_age_days      INTEGER,
    seller_company_age_days     INTEGER
);

-- ── Network Nodes ────────────────────────────────────────────
CREATE TABLE network_nodes (
    node            TEXT PRIMARY KEY,
    pagerank        NUMERIC(10, 8),
    in_degree       INTEGER,
    out_degree      INTEGER,
    betweenness     NUMERIC(10, 8),
    fraud_count     INTEGER,
    avg_fraud_prob  NUMERIC(6, 5),
    is_fraud_node   SMALLINT
);

-- ── Network Edges ────────────────────────────────────────────
CREATE TABLE network_edges (
    buyer_id        TEXT,
    seller_id       TEXT,
    weight          NUMERIC(20, 2),
    tx_count        INTEGER,
    fraud_count     INTEGER,
    fraud_prob_avg  NUMERIC(6, 5),
    fraud_rate      NUMERIC(6, 5),
    PRIMARY KEY (buyer_id, seller_id)
);

-- Index untuk query performance
CREATE INDEX idx_fp_buyer_id     ON fraud_predictions(buyer_id);
CREATE INDEX idx_fp_seller_id    ON fraud_predictions(seller_id);
CREATE INDEX idx_fp_is_fraud     ON fraud_predictions(is_fraud);
CREATE INDEX idx_fp_risk_level   ON fraud_predictions(risk_level);
CREATE INDEX idx_fp_created_dt   ON fraud_predictions(transaction_created_datetime);
CREATE INDEX idx_ft_buyer_id     ON fact_transactions(buyer_id);
CREATE INDEX idx_ft_seller_id    ON fact_transactions(seller_id);
CREATE INDEX idx_nn_is_fraud     ON network_nodes(is_fraud_node);

\echo '✅ Tables created successfully.'

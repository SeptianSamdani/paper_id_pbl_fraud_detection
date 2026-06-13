-- ============================================================
-- queries/01_sample_queries.sql
-- Contoh query analisis fraud untuk eksplorasi & validasi
-- ============================================================

-- ── Q1: Overview fraud rate keseluruhan ──────────────────────
SELECT
    COUNT(*)                            AS total_transactions,
    SUM(is_fraud)                       AS fraud_count,
    ROUND(AVG(is_fraud) * 100, 2)       AS fraud_rate_pct,
    ROUND(SUM(transaction_amount) / 1e9, 2) AS total_amount_billion,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN transaction_amount ELSE 0 END) / 1e9, 2)
                                        AS fraud_amount_billion
FROM fraud_predictions;

-- ── Q2: Distribusi risk level ────────────────────────────────
SELECT
    risk_level,
    COUNT(*)                        AS tx_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct,
    ROUND(AVG(fraud_probability) * 100, 2) AS avg_fraud_prob_pct,
    ROUND(SUM(transaction_amount) / 1e6, 2) AS total_amount_million
FROM fraud_predictions
GROUP BY risk_level
ORDER BY CASE risk_level WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;

-- ── Q3: Monthly trend fraud ──────────────────────────────────
SELECT * FROM vw_monthly_fraud_trend;

-- ── Q4: Top 10 pasangan buyer-seller berisiko tinggi ─────────
SELECT
    buyer_id,
    seller_id,
    tx_count,
    fraud_count,
    ROUND(fraud_rate * 100, 2) AS fraud_rate_pct,
    ROUND(total_amount / 1e6, 2) AS total_amount_million,
    pair_risk_label
FROM vw_top_fraud_pairs
WHERE pair_risk_label = 'HIGH RISK'
LIMIT 10;

-- ── Q5: Akun blacklist + fraud flag ──────────────────────────
SELECT
    account_status,
    COUNT(*)            AS account_count,
    AVG(company_age_days)::INTEGER AS avg_age_days,
    AVG(avg_fraud_prob) AS avg_fraud_prob
FROM vw_flagged_accounts
GROUP BY account_status
ORDER BY account_count DESC;

-- ── Q6: Fraud rate by company type ───────────────────────────
SELECT * FROM vw_risk_by_company_type
WHERE total_tx >= 10;

-- ── Q7: Jalankan monthly report ──────────────────────────────
-- Ganti tahun/bulan sesuai data yang ada
SELECT * FROM fn_monthly_fraud_report(2023, 6);

-- ── Q8: Deteksi promo misuse (buyer pakai promo > 5x) ────────
SELECT * FROM fn_promo_misuse_detection(5)
LIMIT 20;

-- ── Q9: High risk accounts (fraud_prob > 0.6, min 3 tx) ──────
SELECT * FROM fn_high_risk_accounts(0.6, 3)
LIMIT 20;

-- ── Q10: Node paling berpengaruh di network (top 10 PageRank) ─
SELECT
    node,
    ROUND(pagerank::NUMERIC, 6)     AS pagerank,
    in_degree,
    out_degree,
    fraud_count,
    ROUND(avg_fraud_prob * 100, 2)  AS avg_fraud_prob_pct,
    is_fraud_node
FROM network_nodes
ORDER BY pagerank DESC
LIMIT 10;

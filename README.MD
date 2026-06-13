# 🔍 Paper.id Fraud Detection

End-to-end fraud detection project pada transaksi digital payment Paper.id — mencakup data pipeline, machine learning, network analysis, SQL analytics, dan Tableau dashboard.

---

## 📌 Latar Belakang

Paper.id adalah platform B2B digital payment Indonesia. Proyek ini bertujuan mendeteksi pola transaksi fraud menggunakan pendekatan data analytics dan machine learning, berdasarkan dataset transaksi, data perusahaan, dan penggunaan promosi.

---

## 🗂️ Struktur Project

```
paperid-fraud-detection/
├── data/
│   ├── raw/                        # Dataset original (gitignored)
│   └── processed/                  # Output pipeline & Tableau input
├── notebooks/
│   ├── 01_eda.ipynb                # Exploratory Data Analysis
│   ├── 02_feature_engineering.ipynb
│   ├── 03_modeling.ipynb           # ML classifier (XGBoost)
│   ├── 04_network_analysis.ipynb   # Graph analysis (NetworkX)
│   └── 05_export_for_tableau.ipynb # Prepare CSV untuk Tableau
├── src/
│   ├── data/
│   │   ├── loader.py               # Load 4 CSV datasets
│   │   └── cleaner.py              # Cleaning & anomaly detection
│   ├── features/
│   │   └── engineering.py          # Feature engineering pipeline
│   └── export/
│       └── tableau_exporter.py
├── sql/
│   ├── setup/                      # Create tables & import CSV
│   ├── views/                      # Analytical views
│   ├── procedures/                 # Stored functions
│   └── queries/                    # Sample queries
├── tableau/                        # Dashboard output (.twbx)
├── reports/                        # Chart exports & insights
├── requirements.txt
└── README.md
```

---

## 📊 Dataset

| File | Deskripsi | Rows |
|---|---|---|
| `fact__paper__digital_payment_transaction.csv` | Data transaksi digital | ~50K |
| `dim__paper__company.csv` | Profil perusahaan buyer/seller | ~7K |
| `fact__paper__digital_payment_request.csv` | Request pembayaran | ~4K |
| `dim__paper__promotion.csv` | Data promosi | ~20 |

---

## ⚙️ Pipeline

```
Raw CSV
  └─► src/data/loader.py         Load & parse datetime
  └─► src/data/cleaner.py        Missing values, IQR outlier, Isolation Forest
  └─► src/features/engineering.py  18 fitur baru
        ├── Buyer-Seller Relationship Score
        ├── Transaction Frequency & Burst Detection
        └── Promotion Exploitation Indicator
  └─► notebooks/03_modeling.ipynb
        ├── Random Forest (class_weight=balanced)
        ├── XGBoost (scale_pos_weight)         ← best model
        └── XGBoost + SMOTE
  └─► notebooks/04_network_analysis.ipynb
        ├── PageRank, Betweenness Centrality
        └── Connected Components & Hub Detection
  └─► data/processed/            CSV siap Tableau & PostgreSQL
```

---

## 🤖 Hasil Modeling

| Model | ROC-AUC | PR-AUC | F1 | Recall |
|---|---|---|---|---|
| Random Forest | 0.8927 | 0.7751 | 0.6593 | 0.7109 |
| **XGBoost** ✅ | **0.9543** | **0.8982** | **0.7973** | **0.8274** |
| XGBoost + SMOTE | 0.9020 | 0.8091 | 0.7192 | 0.6742 |

**Top features:** `is_outlier_iqr`, `promo_usage_count_buyer`, `relationship_score_z`, `transaction_count`, `transaction_amount`

**Dataset:** 26,772 transaksi (setelah filter self-transaction) | Fraud rate: 17.31%

---

## 🌐 Network Analysis

| Metrik | Nilai |
|---|---|
| Total nodes | 6,843 |
| Total edges | 6,794 |
| Connected components | 112 |
| Hub nodes (>P99 degree) | 67 |
| Giant component | 6,591 nodes (96.3%) |

Temuan: node paling berbahaya bukan yang paling sentral — **peripheral fraud nodes** memiliki `avg_fraud_prob` hingga 87.9% dengan PageRank rendah.

---

## 🗃️ SQL Analytics (PostgreSQL)

```sql
-- Monthly fraud report
SELECT * FROM fn_monthly_fraud_report(2023, 6);

-- Deteksi promo misuse
SELECT * FROM fn_promo_misuse_detection(5);

-- High-risk accounts
SELECT * FROM fn_high_risk_accounts(0.6, 3);

-- Top fraud pairs
SELECT * FROM vw_top_fraud_pairs WHERE pair_risk_label = 'HIGH RISK';
```

---

## 🚀 Cara Menjalankan

### 1. Setup environment

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python -m ipykernel install --user --name=paperid-fraud --display-name "Python (paperid-fraud)"
```

### 2. Jalankan notebook secara berurutan

```
notebooks/01_eda.ipynb
notebooks/02_feature_engineering.ipynb
notebooks/03_modeling.ipynb
notebooks/04_network_analysis.ipynb
notebooks/05_export_for_tableau.ipynb
```

### 3. Setup PostgreSQL

```bash
psql -U postgres
CREATE DATABASE paperid_fraud;
\c paperid_fraud
\i 'sql/setup/01_create_tables.sql'
\i 'sql/setup/02_import_csv.sql'
\i 'sql/views/01_fraud_views.sql'
\i 'sql/procedures/01_fraud_procedures.sql'
```

### 4. Tableau

Buka Tableau → Connect → Text File → `tableau/tableau_transactions.csv`

---

## 🛠️ Tech Stack

`Python` `Pandas` `Scikit-learn` `XGBoost` `NetworkX` `PostgreSQL` `Tableau` `Jupyter`

---

## 👤 Author

**Yahya** — AI Engineer Cohort · Pijak × IBM SkillsBuild

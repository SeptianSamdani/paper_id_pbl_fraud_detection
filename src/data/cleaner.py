import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from datetime import datetime


def clean_transactions(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    # Missing values
    df["dpt_promotion_id"].fillna("No Promotion", inplace=True)
    df.dropna(subset=["buyer_id", "seller_id"], inplace=True)
    df["payment_method_name"].fillna("Unknown", inplace=True)
    df["payment_provider_name"].fillna("Unknown", inplace=True)
    df["seller_id"].fillna("Unknown", inplace=True)
    df["transaction_amount"].fillna(0, inplace=True)

    # Outlier flag (IQR)
    Q1, Q3 = df["transaction_amount"].quantile([0.25, 0.75])
    IQR = Q3 - Q1
    df["is_outlier_iqr"] = (
        (df["transaction_amount"] < Q1 - 1.5 * IQR) |
        (df["transaction_amount"] > Q3 + 1.5 * IQR)
    ).astype(int)

    # Anomaly flag (Isolation Forest)
    scaler = StandardScaler()
    scaled = scaler.fit_transform(df[["transaction_amount"]])
    iso = IsolationForest(contamination=0.05, random_state=42)
    df["anomaly"] = (iso.fit_predict(scaled) == -1).astype(int)

    return df


def clean_company(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    df["company_type_group"].fillna("Unknown", inplace=True)

    # Isi missing fraud flags dengan 0
    for col in ["user_fraud_flag", "blacklist_account_flag",
                "company_phone_verified_flag", "company_email_verified_flag",
                "testing_account_flag"]:
        if col in df.columns:
            df[col] = df[col].fillna(0).astype(int)

    # Fix inkonsistensi: fraud flag=1 tapi blacklist=0
    df.loc[(df["user_fraud_flag"] == 1) & (df["blacklist_account_flag"] == 0),
           "blacklist_account_flag"] = 1

    # Fitur umur perusahaan
    df["company_age_days"] = (datetime.now() - df["company_registered_datetime"]).dt.days

    return df


def clean_promotion(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["dpt_promotion_id"].fillna("Unknown", inplace=True)
    df["promotion_code"].fillna("Unknown", inplace=True)
    df["promotion_name"].fillna("No Promotion", inplace=True)
    return df


def clean_all(data: dict) -> dict:
    return {
        "transactions": clean_transactions(data["transactions"]),
        "company":      clean_company(data["company"]),
        "request":      data["request"].copy(),
        "promotion":    clean_promotion(data["promotion"]),
    }
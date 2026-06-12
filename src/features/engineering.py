import pandas as pd
import numpy as np


def add_buyer_seller_relationship(df: pd.DataFrame) -> pd.DataFrame:
    """Hitung frekuensi interaksi buyer-seller dan Z-score-nya."""
    df = df.copy()

    counts = df.groupby(["buyer_id", "seller_id"]).size().reset_index(name="transaction_count")

    if "transaction_count" in df.columns:
        df.drop(columns=["transaction_count"], inplace=True)

    df = df.merge(counts, on=["buyer_id", "seller_id"], how="left")

    mean = df["transaction_count"].mean()
    std  = df["transaction_count"].std()
    df["relationship_score_z"] = (df["transaction_count"] - mean) / std
    df["relationship_anomaly"]  = (df["relationship_score_z"] > 3).astype(int)

    return df


def add_transaction_frequency(df: pd.DataFrame) -> pd.DataFrame:
    """Deteksi burst transaksi dan unusual gap antar transaksi per buyer."""
    df = df.copy()
    df = df.sort_values(["buyer_id", "transaction_created_datetime"])

    df["time_diff_minutes"] = (
        df.groupby("buyer_id")["transaction_created_datetime"]
        .diff()
        .dt.total_seconds() / 60
    )
    df["time_diff_minutes"].fillna(0, inplace=True)

    mean_diff = df["time_diff_minutes"].mean()
    std_diff  = df["time_diff_minutes"].std()

    df["is_burst"]       = (df["time_diff_minutes"] < 5).astype(int)
    df["is_unusual_gap"] = (df["time_diff_minutes"] > mean_diff + 3 * std_diff).astype(int)

    return df


def add_promotion_exploitation(df: pd.DataFrame) -> pd.DataFrame:
    """Deteksi eksploitasi promosi oleh buyer maupun seller."""
    df = df.copy()

    usage_buyer  = df.groupby(["buyer_id",  "dpt_promotion_id"]).size().reset_index(name="promo_usage_count_buyer")
    usage_seller = df.groupby(["seller_id", "dpt_promotion_id"]).size().reset_index(name="promo_usage_count_seller")

    df = df.merge(usage_buyer,  on=["buyer_id",  "dpt_promotion_id"], how="left")
    df = df.merge(usage_seller, on=["seller_id", "dpt_promotion_id"], how="left")

    for col, z_col, flag_col in [
        ("promo_usage_count_buyer",  "promo_exploit_z_buyer",  "promo_exploit_buyer"),
        ("promo_usage_count_seller", "promo_exploit_z_seller", "promo_exploit_seller"),
    ]:
        mean = df[col].mean()
        std  = df[col].std()
        df[z_col]   = (df[col] - mean) / std
        df[flag_col] = (df[z_col] > 3).astype(int)

    return df


def add_scaling(df: pd.DataFrame) -> pd.DataFrame:
    """Min-Max scaling transaction_amount, Z-score scaling time_diff_minutes."""
    df = df.copy()

    min_amt = df["transaction_amount"].min()
    max_amt = df["transaction_amount"].max()
    df["transaction_amount_scaled"] = (df["transaction_amount"] - min_amt) / (max_amt - min_amt)

    mean_td = df["time_diff_minutes"].mean()
    std_td  = df["time_diff_minutes"].std()
    df["time_diff_minutes_zscore"] = (df["time_diff_minutes"] - mean_td) / std_td

    return df


def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """Jalankan semua feature engineering sekaligus."""
    df = add_buyer_seller_relationship(df)
    df = add_transaction_frequency(df)
    df = add_promotion_exploitation(df)
    df = add_scaling(df)
    return df
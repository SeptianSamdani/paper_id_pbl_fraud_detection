import pandas as pd
from pathlib import Path

RAW_DIR = Path(__file__).resolve().parents[2] / "data" / "raw"

def load_transactions() -> pd.DataFrame:
    df = pd.read_csv(RAW_DIR / "fact__paper__digital_payment_transaction.csv")
    df["transaction_created_datetime"] = pd.to_datetime(df["transaction_created_datetime"])
    df["transaction_updated_datetime"] = pd.to_datetime(df["transaction_updated_datetime"])
    return df

def load_company() -> pd.DataFrame:
    df = pd.read_csv(RAW_DIR / "dim__paper__company.csv")
    df["company_registered_datetime"] = pd.to_datetime(df["company_registered_datetime"])
    return df

def load_request() -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / "fact__paper__digital_payment_request.csv")

def load_promotion() -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / "dim__paper__promotion.csv")

def load_all() -> dict:
    return {
        "transactions": load_transactions(),
        "company":      load_company(),
        "request":      load_request(),
        "promotion":    load_promotion(),
    }
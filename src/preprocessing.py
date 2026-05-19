# preprocessing.py
# ─────────────────────────────────────────────────────────────
# Loads features.csv, cleans and prepares it for ML training.
#
# Steps:
#   1. Load dataset
#   2. Fix mixed-type columns
#   3. Drop non-feature columns
#   4. Drop NaN rows
#   5. Drop zero-variance columns
#   6. Scale features with StandardScaler
#   7. Handle class imbalance with undersampling
#   8. Train/test split
#   9. Save train.csv and test.csv
#
# Run from project root:
#   python src/preprocessing.py
#
# Outputs:
#   data/processed/train.csv
#   data/processed/test.csv
#   data/processed/scaler.pkl
# ─────────────────────────────────────────────────────────────

import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.utils import resample
import pickle
import warnings
warnings.filterwarnings('ignore')

# ── Config ────────────────────────────────────────────────────
INPUT_PATH  = "data/processed/features.csv"
TRAIN_PATH  = "data/processed/train.csv"
TEST_PATH   = "data/processed/test.csv"
SCALER_PATH = "data/processed/scaler.pkl"
RANDOM_STATE = 42
TEST_SIZE    = 0.2

# Columns to drop — not useful as ML features
DROP_COLS = [
    "src_ip",       # IP addresses are identifiers, not features
    "dst_ip",
    "timestamp",    # raw timestamp not useful directly
    "scenario",     # label source metadata
    "label",        # target variable — handle separately
]

def load_data(path):
    print(f"[1] Loading dataset from {path}...")
    df = pd.read_csv(path, low_memory=False)
    print(f"    Shape: {df.shape}")
    print(f"    Label distribution:")
    print(f"      Malicious (1): {(df['label']==1).sum():,}")
    print(f"      Benign    (0): {(df['label']==0).sum():,}")
    return df

def fix_mixed_types(df):
    print("\n[2] Fixing mixed-type columns...")
    fixed = 0
    for col in df.columns:
        if df[col].dtype == object:
            try:
                df[col] = pd.to_numeric(df[col], errors='coerce')
                fixed += 1
            except Exception:
                pass
    print(f"    Fixed {fixed} columns")
    return df

def drop_non_features(df):
    print("\n[3] Separating features and labels...")
    # Save label before dropping
    y = df['label'].copy()
    scenario = df['scenario'].copy() if 'scenario' in df.columns else None

    # Drop non-feature columns
    cols_to_drop = [c for c in DROP_COLS if c in df.columns]
    X = df.drop(columns=cols_to_drop)

    print(f"    Features: {X.shape[1]} columns")
    print(f"    Dropped: {cols_to_drop}")
    return X, y, scenario

def clean_data(X, y):
    print("\n[4] Cleaning data...")
    original_len = len(X)

    # Replace infinities with NaN
    X = X.replace([np.inf, -np.inf], np.nan)

    # Drop rows with any NaN
    mask = X.notna().all(axis=1)
    X = X[mask]
    y = y[mask]

    dropped = original_len - len(X)
    print(f"    Dropped {dropped:,} rows with NaN/infinity values")
    print(f"    Remaining: {len(X):,} rows")
    return X, y

def drop_zero_variance(X):
    print("\n[5] Dropping zero-variance columns...")
    before = X.shape[1]
    variances = X.var()
    zero_var_cols = variances[variances == 0].index.tolist()
    X = X.drop(columns=zero_var_cols)
    print(f"    Dropped {len(zero_var_cols)} zero-variance columns: {zero_var_cols}")
    print(f"    Remaining features: {X.shape[1]}")
    return X

def balance_classes(X, y):
    print("\n[6] Handling class imbalance...")
    malicious_count = (y == 1).sum()
    benign_count = (y == 0).sum()
    ratio = malicious_count / benign_count
    print(f"    Before: Malicious={malicious_count:,} Benign={benign_count:,} Ratio={ratio:.1f}:1")

    # Undersample majority class (malicious) to 3:1 ratio
    # This keeps enough malicious samples while improving balance
    target_malicious = benign_count * 3

    X_benign = X[y == 0]
    y_benign = y[y == 0]
    X_malicious = X[y == 1]
    y_malicious = y[y == 1]

    X_malicious_down, y_malicious_down = resample(
        X_malicious, y_malicious,
        n_samples=target_malicious,
        random_state=RANDOM_STATE
    )

    X_balanced = pd.concat([X_malicious_down, X_benign])
    y_balanced = pd.concat([y_malicious_down, y_benign])

    # Shuffle
    shuffle_idx = X_balanced.sample(frac=1, random_state=RANDOM_STATE).index
    X_balanced = X_balanced.loc[shuffle_idx]
    y_balanced = y_balanced.loc[shuffle_idx]

    print(f"    After:  Malicious={y_malicious_down.sum():,} Benign={y_benign.sum():,} Ratio=3:1")
    print(f"    Total balanced dataset: {len(X_balanced):,} rows")
    return X_balanced, y_balanced

def scale_features(X_train, X_test):
    print("\n[7] Scaling features with StandardScaler...")
    scaler = StandardScaler()
    X_train_scaled = pd.DataFrame(
        scaler.fit_transform(X_train),
        columns=X_train.columns,
        index=X_train.index
    )
    X_test_scaled = pd.DataFrame(
        scaler.transform(X_test),
        columns=X_test.columns,
        index=X_test.index
    )
    print(f"    Scaler fitted on {len(X_train):,} training samples")
    return X_train_scaled, X_test_scaled, scaler

def split_and_save(X, y):
    print("\n[8] Splitting into train/test sets...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y,
        test_size=TEST_SIZE,
        random_state=RANDOM_STATE,
        stratify=y
    )
    print(f"    Train: {len(X_train):,} rows")
    print(f"    Test:  {len(X_test):,} rows")
    return X_train, X_test, y_train, y_test

def main():
    print("=" * 55)
    print(" Preprocessing Pipeline")
    print("=" * 55)

    # Load
    df = load_data(INPUT_PATH)

    # Fix mixed types
    df = fix_mixed_types(df)

    # Separate features and labels
    X, y, scenario = drop_non_features(df)

    # Clean
    X, y = clean_data(X, y)

    # Drop zero variance
    X = drop_zero_variance(X)

    # Balance classes
    X, y = balance_classes(X, y)

    # Split first (before scaling to prevent data leakage)
    X_train, X_test, y_train, y_test = split_and_save(X, y)

    # Scale
    X_train_scaled, X_test_scaled, scaler = scale_features(X_train, X_test)

    # Save train and test sets
    print("\n[9] Saving datasets...")
    os.makedirs("data/processed", exist_ok=True)

    train_df = X_train_scaled.copy()
    train_df['label'] = y_train.values
    train_df.to_csv(TRAIN_PATH, index=False)
    print(f"    Train saved: {TRAIN_PATH} ({len(train_df):,} rows)")

    test_df = X_test_scaled.copy()
    test_df['label'] = y_test.values
    test_df.to_csv(TEST_PATH, index=False)
    print(f"    Test saved:  {TEST_PATH} ({len(test_df):,} rows)")

    # Save scaler for later use
    with open(SCALER_PATH, 'wb') as f:
        pickle.dump(scaler, f)
    print(f"    Scaler saved: {SCALER_PATH}")

    print("\n" + "=" * 55)
    print(" Preprocessing complete!")
    print(f" Train: {len(train_df):,} rows | Test: {len(test_df):,} rows")
    print(f" Features: {X_train_scaled.shape[1]}")
    print(f" Class balance in train set:")
    print(f"   Malicious: {(train_df['label']==1).sum():,}")
    print(f"   Benign:    {(train_df['label']==0).sum():,}")
    print("=" * 55)
    print("\nNext step: python src/train.py")

if __name__ == "__main__":
    main()

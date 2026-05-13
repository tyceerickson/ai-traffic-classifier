# preprocessing.py
# ─────────────────────────────────────────────────────────────
# Reads data/processed/features.csv (labeled master dataset)
# and produces clean train/test splits ready for model training.
#
# Run from project root:
#   python3 src/preprocessing.py
#
# Outputs:
#   data/processed/train.csv
#   data/processed/test.csv
# ─────────────────────────────────────────────────────────────

import pandas as pd
import yaml

# TODO (Milestone 5): implement full preprocessing pipeline
# Steps:
#   1. Load features.csv
#   2. Drop infinities and NaNs (CICFlowMeter produces these)
#   3. Drop zero-variance columns
#   4. Encode categorical columns
#   5. Scale features with StandardScaler
#   6. Check class balance — apply SMOTE if ratio exceeds config threshold
#   7. Train/test split with stratification
#   8. Save train.csv and test.csv

def load_config(path="config.yaml"):
    with open(path) as f:
        return yaml.safe_load(f)

def main():
    config = load_config()
    print("Preprocessing pipeline — to be implemented in Milestone 5")
    print(f"Input:  {config['paths']['master_dataset']}")
    print(f"Output: {config['paths']['train_csv']}")
    print(f"        {config['paths']['test_csv']}")

if __name__ == "__main__":
    main()

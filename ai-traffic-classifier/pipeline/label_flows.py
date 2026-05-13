# label_flows.py
# ─────────────────────────────────────────────────────────────
# Merges all CICFlowMeter output CSVs, applies labels using
# timestamps from data/session_log.csv, and outputs the master
# labeled dataset to data/processed/features.csv
#
# Run from project root:
#   python3 pipeline/label_flows.py
# ─────────────────────────────────────────────────────────────

import os
import glob
import pandas as pd
import yaml
from pathlib import Path

def load_config(path="config.yaml"):
    with open(path) as f:
        return yaml.safe_load(f)

def load_session_log(path):
    """Load the manually-maintained attack session log."""
    df = pd.read_csv(path, parse_dates=["timestamp_start", "timestamp_end"])
    # Drop the example placeholder row
    df = df[df["scenario"] != "EXAMPLE_DO_NOT_USE"]
    print(f"Loaded {len(df)} attack sessions from session log")
    return df

def merge_cicflow_csvs(cicflow_dir):
    """Merge all CICFlowMeter output CSVs into one dataframe."""
    csv_files = glob.glob(os.path.join(cicflow_dir, "*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No CSVs found in {cicflow_dir}")
    print(f"Merging {len(csv_files)} CICFlowMeter output files...")
    dfs = []
    for f in csv_files:
        try:
            dfs.append(pd.read_csv(f, low_memory=False))
        except Exception as e:
            print(f"  [warning] Could not read {f}: {e}")
    return pd.concat(dfs, ignore_index=True)

def apply_labels(flows_df, session_log_df, label_col="label",
                 benign_val=0, malicious_val=1):
    """
    Label each flow based on whether its timestamp falls within
    a logged attack session window.

    TODO (Milestone 3): CICFlowMeter uses 'Timestamp' column —
    confirm exact column name after first real capture run.
    """
    flows_df[label_col] = benign_val

    # TODO: parse CICFlowMeter timestamp column and match against session windows
    print("Label application — to be completed in Milestone 3")
    print(f"Total flows: {len(flows_df)}")

    return flows_df

def main():
    config = load_config()

    cicflow_dir  = config["paths"]["cicflow_output_dir"]
    session_log  = config["paths"]["session_log"]
    output_path  = config["paths"]["master_dataset"]

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    sessions = load_session_log(session_log)
    flows    = merge_cicflow_csvs(cicflow_dir)
    labeled  = apply_labels(flows, sessions,
                            benign_val=config["pipeline"]["label_benign"],
                            malicious_val=config["pipeline"]["label_malicious"])

    labeled.to_csv(output_path, index=False)
    print(f"\nMaster dataset saved to: {output_path}")
    print(f"Total flows: {len(labeled)}")
    print(f"Malicious:   {(labeled['label'] == 1).sum()}")
    print(f"Benign:      {(labeled['label'] == 0).sum()}")

if __name__ == "__main__":
    main()

# label_flows.py
# ─────────────────────────────────────────────────────────────
# Merges all CICFlowMeter output CSVs, applies labels using
# timestamps from data/session_log.csv, and outputs the master
# labeled dataset to data/processed/features.csv
#
# How labeling works:
#   - Each row in session_log.csv defines a time window when
#     an attack was running (timestamp_start → timestamp_end)
#   - Any flow whose timestamp falls inside an attack window
#     gets labeled 1 (malicious)
#   - Everything else gets labeled 0 (benign)
#
# Run from project root:
#   python3 pipeline/label_flows.py
#
# Or with custom paths:
#   python3 pipeline/label_flows.py \
#     --cicflow-dir /opt/cicflow_output \
#     --session-log data/session_log.csv \
#     --output data/processed/features.csv
# ─────────────────────────────────────────────────────────────
 
import os
import glob
import argparse
import pandas as pd
import yaml
from pathlib import Path
from datetime import datetime
 
 
def load_config(path="config.yaml"):
    """Load central config file."""
    with open(path) as f:
        return yaml.safe_load(f)
 
 
def load_session_log(path):
    """
    Load the manually-maintained attack session log.
    Each row defines a time window when an attack was running.
    """
    df = pd.read_csv(path, parse_dates=["timestamp_start", "timestamp_end"])
 
    # Drop the example placeholder row
    df = df[df["scenario"] != "EXAMPLE_DO_NOT_USE"]
 
    if len(df) == 0:
        print("[!] WARNING: No attack sessions found in session_log.csv")
        print("    All flows will be labeled as benign.")
        return df
 
    print(f"[+] Loaded {len(df)} attack sessions from session log:")
    for _, row in df.iterrows():
        print(f"    {row['timestamp_start']} → {row['timestamp_end']} | {row['scenario']} | {row['targets']}")
 
    return df
 
 
def load_cicflow_csvs(cicflow_dir):
    """
    Load all CICFlowMeter output CSVs from the given directory.
    Handles both individual files and the merged_flows.csv.
    """
    # First check for merged file
    merged_path = os.path.join(cicflow_dir, "merged_flows.csv")
    if os.path.exists(merged_path) and os.path.getsize(merged_path) > 0:
        print(f"[+] Found merged CSV: {merged_path}")
        df = pd.read_csv(merged_path, low_memory=False)
        print(f"    {len(df)} flows, {len(df.columns)} columns")
        return df
 
    # Otherwise merge individual CSVs
    csv_files = [f for f in glob.glob(os.path.join(cicflow_dir, "*.csv"))
                 if os.path.getsize(f) > 0]
 
    if not csv_files:
        raise FileNotFoundError(
            f"No CSV files found in {cicflow_dir}\n"
            f"Run: python3 ~/pcap_to_csv.py /opt/pcaps/ {cicflow_dir}/merged_flows.csv"
        )
 
    print(f"[+] Merging {len(csv_files)} CICFlowMeter CSV files...")
    dfs = []
    for f in csv_files:
        try:
            df = pd.read_csv(f, low_memory=False)
            if len(df) > 0:
                dfs.append(df)
                print(f"    {os.path.basename(f)}: {len(df)} flows")
        except Exception as e:
            print(f"    [warning] Could not read {f}: {e}")
 
    if not dfs:
        raise ValueError("All CSV files were empty")
 
    merged = pd.concat(dfs, ignore_index=True)
    print(f"[+] Total flows after merge: {len(merged)}")
    return merged
 
 
def parse_flow_timestamps(df):
    """
    Parse the timestamp column from CICFlowMeter output.
    CICFlowMeter uses Unix timestamps (float seconds since epoch).
    """
    if "timestamp" not in df.columns:
        raise ValueError(
            f"No 'timestamp' column found. Available columns: {list(df.columns[:10])}"
        )
 
    # CICFlowMeter timestamps are Unix epoch floats
    # Convert to pandas datetime for comparison
    df["timestamp_dt"] = pd.to_datetime(df["timestamp"], unit="s", utc=True)
 
    print(f"[+] Flow timestamps: {df['timestamp_dt'].min()} → {df['timestamp_dt'].max()}")
    return df
 
 
def apply_labels(flows_df, session_log_df, label_benign=0, label_malicious=1):
    """
    Label each flow based on whether its timestamp falls within
    a logged attack session window.
 
    For each flow:
      - Check all attack windows in session_log.csv
      - If flow timestamp is between any window's start and end → malicious
      - Otherwise → benign
    """
    # Start all flows as benign
    flows_df["label"] = label_benign
    flows_df["scenario"] = ""
 
    if len(session_log_df) == 0:
        print("[!] No attack sessions to match — all flows labeled benign")
        return flows_df
 
    # Convert session log timestamps to UTC for comparison
    session_log_df["timestamp_start"] = pd.to_datetime(
        session_log_df["timestamp_start"]
    ).dt.tz_localize("UTC")
    session_log_df["timestamp_end"] = pd.to_datetime(
        session_log_df["timestamp_end"]
    ).dt.tz_localize("UTC")
 
    malicious_count = 0
 
    for _, session in session_log_df.iterrows():
        # Find flows within this attack window
        mask = (
            (flows_df["timestamp_dt"] >= session["timestamp_start"]) &
            (flows_df["timestamp_dt"] <= session["timestamp_end"])
        )
        count = mask.sum()
 
        if count > 0:
            flows_df.loc[mask, "label"] = label_malicious
            flows_df.loc[mask, "scenario"] = session["scenario"]
            malicious_count += count
            print(f"    {session['scenario']}: {count} flows labeled malicious")
        else:
            print(f"    [!] {session['scenario']}: 0 flows matched "
                  f"(window: {session['timestamp_start']} → {session['timestamp_end']})")
 
    benign_count = (flows_df["label"] == label_benign).sum()
 
    print(f"\n[+] Labeling complete:")
    print(f"    Malicious (1): {malicious_count:,}")
    print(f"    Benign    (0): {benign_count:,}")
    print(f"    Total:         {len(flows_df):,}")
 
    if malicious_count == 0:
        print("\n[!] WARNING: No malicious flows found.")
        print("    Check that session_log.csv timestamps match your PCAP capture times.")
        print("    Flow timestamps are in UTC — make sure session_log uses UTC too.")
 
    return flows_df
 
 
def clean_features(df):
    """
    Basic cleaning before saving:
    - Drop helper columns not needed for training
    - Replace infinities with NaN (CICFlowMeter can produce these)
    - Report any remaining issues
    """
    # Drop the datetime helper column we added
    df = df.drop(columns=["timestamp_dt"], errors="ignore")
 
    # Replace infinities with NaN
    import numpy as np
    inf_count = df.isin([float("inf"), float("-inf")]).sum().sum()
    if inf_count > 0:
        print(f"[+] Replacing {inf_count} infinity values with NaN")
        df = df.replace([float("inf"), float("-inf")], float("nan"))
 
    # Report NaN counts
    nan_count = df.isnull().sum().sum()
    if nan_count > 0:
        print(f"[!] {nan_count} NaN values remain — will be handled in preprocessing.py")
 
    return df
 
 
def main():
    parser = argparse.ArgumentParser(
        description="Label CICFlowMeter flows using session_log.csv timestamps"
    )
    parser.add_argument(
        "--cicflow-dir",
        default=None,
        help="Directory containing CICFlowMeter CSV output"
    )
    parser.add_argument(
        "--session-log",
        default=None,
        help="Path to session_log.csv"
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output path for labeled features.csv"
    )
    parser.add_argument(
        "--config",
        default="config.yaml",
        help="Path to config.yaml (default: config.yaml)"
    )
    args = parser.parse_args()
 
    # Load config for default paths
    try:
        config = load_config(args.config)
        cicflow_dir  = args.cicflow_dir  or config["paths"]["cicflow_output_dir"]
        session_log  = args.session_log  or config["paths"]["session_log"]
        output_path  = args.output       or config["paths"]["master_dataset"]
    except FileNotFoundError:
        # Fall back to sensible defaults if config not found
        cicflow_dir  = args.cicflow_dir  or "/opt/cicflow_output"
        session_log  = args.session_log  or "data/session_log.csv"
        output_path  = args.output       or "data/processed/features.csv"
 
    print("=" * 50)
    print(" Label Flows Pipeline")
    print(f" CICFlow dir:  {cicflow_dir}")
    print(f" Session log:  {session_log}")
    print(f" Output:       {output_path}")
    print("=" * 50)
    print()
 
    # Load data
    sessions = load_session_log(session_log)
    flows    = load_cicflow_csvs(cicflow_dir)
    flows    = parse_flow_timestamps(flows)
 
    print()
 
    # Apply labels
    labeled = apply_labels(
        flows, sessions,
        label_benign=0,
        label_malicious=1
    )
 
    # Clean up
    labeled = clean_features(labeled)
 
    # Save
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    labeled.to_csv(output_path, index=False)
 
    print(f"\n[+] Master dataset saved to: {output_path}")
    print(f"    Size: {os.path.getsize(output_path) / 1024 / 1024:.1f} MB")
    print(f"    Rows: {len(labeled):,}")
    print(f"    Columns: {len(labeled.columns)}")
    print()
    print("Next step: python3 src/preprocessing.py")
 
 
if __name__ == "__main__":
    main()

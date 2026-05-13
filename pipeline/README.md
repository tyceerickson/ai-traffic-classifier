# Pipeline

These scripts run on the **Ubuntu Server VM (192.168.10.4)** and form the
automated data processing pipeline. They take raw PCAPs from OPNsense and
produce a clean, labeled CSV ready for model training.

## Pipeline Sequence

```
OPNsense (continuous capture)
        │
        │  rsync (sync_pcaps.sh — runs on schedule via cron)
        ▼
data/raw/*.pcap
        │
        │  run_cicflowmeter.sh
        ▼
pipeline/cicflow_output/*.csv  (raw flow features, unlabeled)
        │
        │  label_flows.py  (reads data/session_log.csv for timestamps)
        ▼
data/processed/features.csv  (labeled master dataset)
```

## Scripts

### `sync_pcaps.sh`
Rsyncs new PCAP files from OPNsense to `data/raw/`. Skips files already
present. Configured via `config.yaml` (OPNsense IP, SSH user, remote path).

**Run manually:** `./pipeline/sync_pcaps.sh`
**Run on schedule:** Add to crontab — `0 * * * * /path/to/sync_pcaps.sh`

### `run_cicflowmeter.sh`
Runs CICFlowMeter on any unprocessed PCAP files in `data/raw/`. Outputs
per-PCAP CSVs to `pipeline/cicflow_output/`. Tracks which files have already
been processed to avoid duplicates.

**Run manually:** `./pipeline/run_cicflowmeter.sh`

### `label_flows.py`
Reads all CSVs from `pipeline/cicflow_output/`, merges them, then applies
labels using the timestamps in `data/session_log.csv`. Any flow whose
timestamp falls within a logged attack window is labeled malicious (1).
All other flows are labeled benign (0). Outputs `data/processed/features.csv`.

**Run manually:** `python3 pipeline/label_flows.py`

## Running the Full Pipeline

```bash
# Pull latest PCAPs from OPNsense
./pipeline/sync_pcaps.sh

# Convert PCAPs to flow features
./pipeline/run_cicflowmeter.sh

# Apply labels and build master dataset
python3 pipeline/label_flows.py

# Transfer to Alienware for training
scp data/processed/features.csv user@alienware:/path/to/project/data/processed/
```

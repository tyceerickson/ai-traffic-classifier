# explain.py
# ─────────────────────────────────────────────────────────────
# Takes representative flows from EACH attack scenario and sends
# them to a local Ollama LLM for plain-English explanation.
#
# Samples flows from each attack type so the LLM explains all
# 8 different attack patterns, not just the most common one.
#
# Run from project root:
#   python src/explain.py
#
# Outputs:
#   results/explanations.md
# ─────────────────────────────────────────────────────────────

import os
import pickle
import requests
import pandas as pd
import numpy as np
import warnings
warnings.filterwarnings('ignore')

# ── Config ────────────────────────────────────────────────────
FEATURES_PATH  = "data/processed/features.csv"
TEST_PATH      = "data/processed/test.csv"
MODEL_PATH     = "models/random_forest.pkl"
SCALER_PATH    = "data/processed/scaler.pkl"
OUTPUT_PATH    = "results/explanations.md"
OLLAMA_HOST    = "http://localhost:11434"
OLLAMA_MODEL   = "llama3.1:8b"
FLOWS_PER_SCENARIO = 2
RANDOM_STATE   = 42

SCENARIO_CONTEXT = {
    "nmap_syn_scan": "Nmap SYN stealth port scan across all 65,535 ports",
    "nmap_service_scan": "Nmap service and OS detection scan (-sV -sC -O)",
    "nmap_evasion_scan": "Nmap IDS/firewall evasion scan (fragmentation, decoys, TTL manipulation, badsum)",
    "hydra_ssh_brute": "Hydra SSH credential brute force attack",
    "hydra_http_brute": "Hydra HTTP form brute force against DVWA and phpMyAdmin",
    "c2_beacon": "Simulated C2 beaconing (regular, jittered, and exfiltration modes)",
    "slowhttptest_dos": "Slowloris slow HTTP denial of service attack",
    "metasploit_ms17010": "Metasploit EternalBlue MS17-010 SMB exploit attempt",
}

KEY_FEATURES = [
    "flow_duration", "tot_fwd_pkts", "tot_bwd_pkts",
    "flow_byts_s", "flow_pkts_s", "fwd_pkt_len_mean",
    "bwd_pkt_len_mean", "syn_flag_cnt", "rst_flag_cnt",
    "ack_flag_cnt", "psh_flag_cnt", "fwd_iat_mean",
    "bwd_iat_mean", "init_fwd_win_byts", "init_bwd_win_byts",
    "down_up_ratio", "fwd_pkts_s", "bwd_pkts_s",
]

def load_model_and_data():
    print("[1] Loading model and data...")
    with open(MODEL_PATH, 'rb') as f:
        model = pickle.load(f)
    with open(SCALER_PATH, 'rb') as f:
        scaler = pickle.load(f)
    features_df = pd.read_csv(FEATURES_PATH, low_memory=False)
    test_df = pd.read_csv(TEST_PATH)
    X_test = test_df.drop(columns=['label'])
    y_test = test_df['label']
    print(f"    Model: Random Forest ({model.n_estimators} trees)")
    print(f"    Full dataset: {len(features_df):,} flows")
    print(f"    Scenarios found: {features_df['scenario'].value_counts().to_dict()}")
    return model, scaler, features_df, X_test, y_test

def get_flows_per_scenario(features_df, model, scaler, n=FLOWS_PER_SCENARIO):
    print(f"\n[2] Sampling {n} flows per attack scenario...")
    drop_cols = ['src_ip', 'dst_ip', 'timestamp', 'scenario', 'label']
    feature_cols = [c for c in features_df.columns if c not in drop_cols]
    for col in feature_cols:
        features_df[col] = pd.to_numeric(features_df[col], errors='coerce')
    malicious_df = features_df[features_df['label'] == 1].copy()
    scenario_flows = {}
    for scenario in SCENARIO_CONTEXT.keys():
        scenario_data = malicious_df[malicious_df['scenario'] == scenario]
        if len(scenario_data) == 0:
            print(f"    {scenario}: no flows found, skipping")
            continue
        X_scenario = scenario_data[feature_cols].copy()
        X_scenario = X_scenario.fillna(0).replace([np.inf, -np.inf], 0)
        if 'bwd_urg_flags' in X_scenario.columns:
            X_scenario = X_scenario.drop(columns=['bwd_urg_flags'])
        try:
            X_scaled = pd.DataFrame(
                scaler.transform(X_scenario),
                columns=X_scenario.columns,
                index=X_scenario.index
            )
            probs = model.predict_proba(X_scaled)[:, 1]
            top_idx = probs.argsort()[::-1][:n]
            top_flows = X_scenario.iloc[top_idx]
            top_probs = probs[top_idx]
            scenario_flows[scenario] = (top_flows, top_probs)
            print(f"    {scenario}: {len(scenario_data):,} flows, top {n} confidence: {top_probs.max():.3f}")
        except Exception as e:
            print(f"    {scenario}: ERROR - {e}")
    return scenario_flows

def format_flow_for_llm(flow, confidence, scenario, flow_num):
    available = [f for f in KEY_FEATURES if f in flow.index]
    feature_lines = []
    for feat in available:
        val = flow[feat]
        if pd.notna(val) and val != 0:
            if abs(val) > 1000:
                feature_lines.append(f"  - {feat}: {val:,.0f}")
            else:
                feature_lines.append(f"  - {feat}: {val:.4f}")
    features_str = "\n".join(feature_lines) if feature_lines else "  (no significant feature values)"
    scenario_desc = SCENARIO_CONTEXT.get(scenario, scenario)
    prompt = f"""You are a cybersecurity analyst reviewing network traffic flagged as malicious by an ML classifier.

ATTACK CONTEXT: This flow was generated during a "{scenario_desc}" attack.

Flow #{flow_num} was classified as MALICIOUS with {confidence:.1%} confidence.

Key network flow features:
{features_str}

Feature definitions:
- flow_duration: total flow duration in microseconds
- tot_fwd_pkts / tot_bwd_pkts: total packets sent forward and backward
- flow_byts_s / flow_pkts_s: bytes and packets per second
- fwd/bwd_pkt_len_mean: average packet size each direction
- syn/rst/ack/psh_flag_cnt: TCP flag counts across the flow
- fwd/bwd_iat_mean: mean time between packets (microseconds)
- init_fwd/bwd_win_byts: initial TCP window size
- down_up_ratio: ratio of download to upload bytes

In 3-4 sentences explain:
1. What specific attack behavior these features reveal for a "{scenario}" attack
2. Which features are most suspicious and exactly why
3. How this attack differs from normal benign traffic

Be specific, technical, and reference the actual feature values."""
    return prompt

def query_ollama(prompt):
    try:
        response = requests.post(
            f"{OLLAMA_HOST}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": 0.2, "num_predict": 350}
            },
            timeout=120
        )
        response.raise_for_status()
        return response.json()["response"].strip()
    except requests.exceptions.ConnectionError:
        return "ERROR: Ollama not running. Start with: ollama serve"
    except Exception as e:
        return f"ERROR: {str(e)}"

def write_explanations(all_explanations):
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        f.write("# ML Alert Explanations -- Ollama LLM Analysis\n\n")
        f.write("Plain-English explanations of representative malicious flows from each\n")
        f.write("attack scenario, generated by a local llama3.1:8b LLM.\n\n")
        f.write(f"- Classifier: Random Forest (100 trees, 78 features)\n")
        f.write(f"- LLM: {OLLAMA_MODEL} (local, Alienware RTX 4070)\n")
        f.write(f"- Flows per scenario: {FLOWS_PER_SCENARIO}\n\n")
        f.write("---\n\n")
        total_flows = 0
        for scenario, explanations in all_explanations.items():
            scenario_desc = SCENARIO_CONTEXT.get(scenario, scenario)
            f.write(f"## {scenario}\n\n")
            f.write(f"**Attack type:** {scenario_desc}\n\n")
            for flow_num, confidence, explanation in explanations:
                f.write(f"### Flow #{flow_num} -- Confidence: {confidence:.1%}\n\n")
                f.write(f"{explanation}\n\n")
                total_flows += 1
            f.write("---\n\n")
        f.write(f"## Summary\n\n")
        f.write(f"| Scenario | Flows Explained |\n")
        f.write(f"|----------|-----------------|\n")
        for scenario, explanations in all_explanations.items():
            f.write(f"| {scenario} | {len(explanations)} |\n")
        f.write(f"\n**Total flows explained: {total_flows}**\n")
    print(f"    Saved: {OUTPUT_PATH}")

def main():
    print("=" * 55)
    print(" Explainability Pipeline -- All Attack Scenarios")
    print(f" Model: {OLLAMA_MODEL}")
    print(f" Flows per scenario: {FLOWS_PER_SCENARIO}")
    print(f" Total scenarios: {len(SCENARIO_CONTEXT)}")
    print("=" * 55)
    print("\n[0] Checking Ollama connection...")
    try:
        r = requests.get(f"{OLLAMA_HOST}/api/tags", timeout=5)
        models = [m['name'] for m in r.json().get('models', [])]
        print(f"    Ollama running. Models: {models}")
    except Exception:
        print("    ERROR: Ollama not running. Start with: ollama serve")
        return
    model, scaler, features_df, X_test, y_test = load_model_and_data()
    scenario_flows = get_flows_per_scenario(features_df, model, scaler)
    total = sum(len(v[0]) for v in scenario_flows.values())
    print(f"\n[3] Generating LLM explanations ({total} flows total)...")
    all_explanations = {}
    flow_counter = 1
    for scenario, (flows, probs) in scenario_flows.items():
        print(f"\n  Scenario: {scenario}")
        scenario_explanations = []
        for i in range(len(flows)):
            flow = flows.iloc[i]
            confidence = probs[i]
            print(f"    Flow {flow_counter} (confidence: {confidence:.1%})...", end=" ", flush=True)
            prompt = format_flow_for_llm(flow, confidence, scenario, flow_counter)
            explanation = query_ollama(prompt)
            print("done")
            preview = explanation[:120].replace('\n', ' ')
            print(f"    > {preview}...")
            scenario_explanations.append((flow_counter, confidence, explanation))
            flow_counter += 1
        all_explanations[scenario] = scenario_explanations
    print("\n[4] Saving explanations...")
    write_explanations(all_explanations)
    print("\n" + "=" * 55)
    print(" Explainability complete!")
    print(f" {flow_counter - 1} flows explained across {len(all_explanations)} scenarios")
    print(f" Saved to: {OUTPUT_PATH}")
    print("=" * 55)

if __name__ == "__main__":
    main()

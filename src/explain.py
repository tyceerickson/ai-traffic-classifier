# explain.py
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Takes the top N highest-confidence malicious predictions from
# the Random Forest classifier and sends them to a local Ollama
# LLM for plain-English explanation.
#
# This demonstrates explainable AI (XAI) â€” making the model's
# decisions understandable to humans, which is critical for
# real-world security operations.
#
# Run from project root:
#   python src/explain.py
#
# Outputs:
#   results/explanations.md
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import os
import json
import pickle
import requests
import pandas as pd
import numpy as np
import warnings
warnings.filterwarnings('ignore')

# â”€â”€ Config â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
TEST_PATH      = "data/processed/test.csv"
MODEL_PATH     = "models/random_forest.pkl"
OUTPUT_PATH    = "results/explanations.md"
OLLAMA_HOST    = "http://localhost:11434"
OLLAMA_MODEL   = "llama3.1:8b"
TOP_N_FLOWS    = 10   # number of flagged flows to explain
RANDOM_STATE   = 42

# Key features to highlight in explanations
# These are the most interpretable for a security analyst
KEY_FEATURES = [
    "flow_duration",
    "tot_fwd_pkts",
    "tot_bwd_pkts",
    "flow_byts_s",
    "flow_pkts_s",
    "fwd_pkt_len_mean",
    "bwd_pkt_len_mean",
    "syn_flag_cnt",
    "rst_flag_cnt",
    "ack_flag_cnt",
    "psh_flag_cnt",
    "fwd_iat_mean",
    "bwd_iat_mean",
    "init_fwd_win_byts",
    "init_bwd_win_byts",
]

def load_model_and_data():
    print("[1] Loading model and test data...")
    with open(MODEL_PATH, 'rb') as f:
        model = pickle.load(f)

    test_df = pd.read_csv(TEST_PATH)
    X_test = test_df.drop(columns=['label'])
    y_test = test_df['label']

    print(f"    Model: Random Forest ({model.n_estimators} trees)")
    print(f"    Test set: {len(X_test):,} flows")
    return model, X_test, y_test

def get_top_malicious_flows(model, X_test, y_test, n=TOP_N_FLOWS):
    """
    Get the N flows the model is most confident are malicious.
    These are the best candidates for explanation â€” high confidence
    means the model found strong signals in the features.
    """
    print(f"\n[2] Finding top {n} highest-confidence malicious predictions...")
    probs = model.predict_proba(X_test)[:, 1]  # probability of malicious
    predictions = model.predict(X_test)

    # Only look at flows the model predicted as malicious
    malicious_mask = predictions == 1
    malicious_probs = probs[malicious_mask]
    malicious_flows = X_test[malicious_mask]
    malicious_true = y_test[malicious_mask]

    # Sort by confidence descending
    top_indices = malicious_probs.argsort()[::-1][:n]
    top_flows = malicious_flows.iloc[top_indices]
    top_probs = malicious_probs[top_indices]
    top_true = malicious_true.iloc[top_indices]

    print(f"    Found {malicious_mask.sum():,} predicted malicious flows")
    print(f"    Selected top {n} by confidence")
    print(f"    Confidence range: {top_probs.min():.3f} - {top_probs.max():.3f}")

    return top_flows, top_probs, top_true

def format_flow_for_llm(flow, confidence, flow_num):
    """
    Format a flow's features into a human-readable prompt for the LLM.
    Only include the most interpretable features to keep the prompt focused.
    """
    # Get available key features
    available = [f for f in KEY_FEATURES if f in flow.index]

    feature_lines = []
    for feat in available:
        val = flow[feat]
        if pd.notna(val):
            # Format numbers nicely
            if abs(val) > 1000:
                feature_lines.append(f"  - {feat}: {val:,.0f}")
            else:
                feature_lines.append(f"  - {feat}: {val:.4f}")

    features_str = "\n".join(feature_lines)

    prompt = f"""You are a cybersecurity analyst reviewing network traffic flagged as malicious by an ML classifier.

Flow #{flow_num} was classified as MALICIOUS with {confidence:.1%} confidence.

Key network flow features:
{features_str}

Feature definitions:
- flow_duration: total duration of the flow in microseconds
- tot_fwd_pkts / tot_bwd_pkts: packets sent forward/backward
- flow_byts_s / flow_pkts_s: bytes and packets per second
- fwd/bwd_pkt_len_mean: average packet size in each direction
- syn/rst/ack/psh_flag_cnt: TCP flag counts
- fwd/bwd_iat_mean: mean inter-arrival time between packets
- init_fwd/bwd_win_byts: initial TCP window size

In 3-4 sentences, explain:
1. What type of attack or malicious behavior this traffic pattern suggests
2. Which specific features are most suspicious and why
3. How confident you are in this assessment

Be specific and technical but clear."""

    return prompt

def query_ollama(prompt, model=OLLAMA_MODEL):
    """Send a prompt to the local Ollama instance and get a response."""
    try:
        response = requests.post(
            f"{OLLAMA_HOST}/api/generate",
            json={
                "model": model,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.3,    # lower = more focused/consistent
                    "num_predict": 300,    # max tokens in response
                }
            },
            timeout=60
        )
        response.raise_for_status()
        return response.json()["response"].strip()
    except requests.exceptions.ConnectionError:
        return "ERROR: Ollama is not running. Start it with: ollama serve"
    except Exception as e:
        return f"ERROR: {str(e)}"

def write_explanations(explanations, output_path):
    """Write all explanations to a markdown file."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w') as f:
        f.write("# ML Alert Explanations â€” Ollama LLM Analysis\n\n")
        f.write("This document shows plain-English explanations of the top malicious\n")
        f.write("network flows flagged by the Random Forest classifier, generated by\n")
        f.write(f"a local {OLLAMA_MODEL} LLM running on the Alienware m16 R2.\n\n")
        f.write("---\n\n")

        for i, (flow_num, confidence, true_label, explanation) in enumerate(explanations):
            correct = "âœ… Correct" if true_label == 1 else "âŒ False Positive"
            f.write(f"## Flow #{flow_num} â€” Confidence: {confidence:.1%} â€” {correct}\n\n")
            f.write(f"**LLM Explanation:**\n\n")
            f.write(f"{explanation}\n\n")
            f.write("---\n\n")

        # Summary stats
        correct_count = sum(1 for _, _, t, _ in explanations if t == 1)
        f.write(f"## Summary\n\n")
        f.write(f"- Flows analyzed: {len(explanations)}\n")
        f.write(f"- True positives: {correct_count}/{len(explanations)}\n")
        f.write(f"- False positives: {len(explanations)-correct_count}/{len(explanations)}\n")
        f.write(f"- Model: {OLLAMA_MODEL} (local, no API cost)\n")
        f.write(f"- Classifier: Random Forest (100 trees, 78 features)\n")

    print(f"    Saved: {output_path}")

def main():
    print("=" * 55)
    print(" Explainability Pipeline (Ollama LLM)")
    print(f" Model: {OLLAMA_MODEL}")
    print(f" Flows to explain: {TOP_N_FLOWS}")
    print("=" * 55)

    # Check Ollama is running
    print("\n[0] Checking Ollama connection...")
    try:
        r = requests.get(f"{OLLAMA_HOST}/api/tags", timeout=5)
        models = [m['name'] for m in r.json().get('models', [])]
        print(f"    Ollama running. Available models: {models}")
        if not any(OLLAMA_MODEL in m for m in models):
            print(f"    WARNING: {OLLAMA_MODEL} not found. Run: ollama pull {OLLAMA_MODEL}")
    except Exception:
        print(f"    ERROR: Ollama not running. Start with: ollama serve")
        return

    # Load model and data
    model, X_test, y_test = load_model_and_data()

    # Get top malicious flows
    top_flows, top_probs, top_true = get_top_malicious_flows(
        model, X_test, y_test, n=TOP_N_FLOWS
    )

    # Generate explanations
    print(f"\n[3] Generating LLM explanations for {TOP_N_FLOWS} flows...")
    explanations = []

    for i, (idx, flow) in enumerate(top_flows.iterrows()):
        confidence = top_probs[i]
        true_label = top_true.iloc[i]
        flow_num = i + 1

        print(f"    Flow {flow_num}/{TOP_N_FLOWS} (confidence: {confidence:.1%})...", end=" ")

        prompt = format_flow_for_llm(flow, confidence, flow_num)
        explanation = query_ollama(prompt)

        print("done")
        explanations.append((flow_num, confidence, true_label, explanation))

        # Print preview
        print(f"    Preview: {explanation[:100]}...")
        print()

    # Save results
    print("\n[4] Saving explanations...")
    write_explanations(explanations, OUTPUT_PATH)

    print("\n" + "=" * 55)
    print(" Explainability complete!")
    print(f" {TOP_N_FLOWS} flows explained and saved to {OUTPUT_PATH}")
    print("=" * 55)
    print("\nNext step: python src/evaluate.py (or open results/explanations.md)")

if __name__ == "__main__":
    main()


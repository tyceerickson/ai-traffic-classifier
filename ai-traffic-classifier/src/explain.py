# explain.py
# ─────────────────────────────────────────────────────────────
# Takes the top N flagged flows from the classifier and sends
# them to a local Ollama LLM for plain-English explanation.
#
# Requires Ollama running locally:
#   ollama serve  (then: ollama pull llama3)
#
# Run from project root:
#   python3 src/explain.py
#
# Output:
#   results/explanations.md
# ─────────────────────────────────────────────────────────────

# TODO (Milestone 7): implement Ollama explainability layer
# Steps:
#   1. Load test set + model predictions
#   2. Select top N highest-confidence malicious predictions
#   3. Format flow features as structured prompt
#   4. Call Ollama API (http://localhost:11434/api/generate)
#   5. Write explanations to results/explanations.md

def main():
    print("Explainability layer — to be implemented in Milestone 7")

if __name__ == "__main__":
    main()

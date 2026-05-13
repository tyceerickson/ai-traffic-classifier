# train.py
# ─────────────────────────────────────────────────────────────
# Trains ML classifiers on the preprocessed dataset.
# Primary model: Random Forest. Comparison: XGBoost, Decision
# Tree, Logistic Regression.
#
# Run from project root:
#   python3 src/train.py
#
# Outputs:
#   models/random_forest.pkl  (primary model)
#   results/evaluation_report.md
#   results/confusion_matrix.png
#   results/roc_curve.png
#   results/feature_importance.png
# ─────────────────────────────────────────────────────────────

import yaml

# TODO (Milestone 6): implement full training pipeline
# Steps:
#   1. Load train.csv and test.csv
#   2. Train Random Forest (primary)
#   3. Train XGBoost, Decision Tree, Logistic Regression (comparison)
#   4. Evaluate all models — accuracy, precision, recall, F1, ROC-AUC
#   5. Generate confusion matrix, ROC curve, feature importance plots
#   6. Serialize best model to models/random_forest.pkl
#   7. Write results/evaluation_report.md

def load_config(path="config.yaml"):
    with open(path) as f:
        return yaml.safe_load(f)

def main():
    config = load_config()
    print("Training pipeline — to be implemented in Milestone 6")
    print(f"Primary model: {config['training']['primary_model']}")
    print(f"Models to compare: {config['training']['models']}")

if __name__ == "__main__":
    main()

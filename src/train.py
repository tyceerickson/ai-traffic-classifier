# train.py
# ─────────────────────────────────────────────────────────────
# Trains ML classifiers on the preprocessed dataset.
# Primary model: Random Forest
# Comparison models: XGBoost, Decision Tree, Logistic Regression
#
# Run from project root:
#   python src/train.py
#
# Outputs:
#   models/random_forest.pkl
#   models/xgboost.pkl
#   models/decision_tree.pkl
#   models/logistic_regression.pkl
#   results/evaluation_report.md
#   results/confusion_matrix_random_forest.png
#   results/roc_curve.png
#   results/feature_importance.png
#   results/model_comparison.png
# ─────────────────────────────────────────────────────────────

import os
import pickle
import warnings
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # non-interactive backend for saving plots
import seaborn as sns
warnings.filterwarnings('ignore')

from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score,
    f1_score, roc_auc_score, confusion_matrix,
    classification_report, roc_curve
)
from xgboost import XGBClassifier

# ── Config ────────────────────────────────────────────────────
TRAIN_PATH   = "data/processed/train.csv"
TEST_PATH    = "data/processed/test.csv"
MODELS_DIR   = "models"
RESULTS_DIR  = "results"
RANDOM_STATE = 42

os.makedirs(MODELS_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)

# ── Model definitions ─────────────────────────────────────────
MODELS = {
    "random_forest": RandomForestClassifier(
        n_estimators=100,
        max_depth=None,
        n_jobs=-1,              # use all CPU cores
        random_state=RANDOM_STATE,
        verbose=1
    ),
    "xgboost": XGBClassifier(
        n_estimators=100,
        learning_rate=0.1,
        device='cuda',
        random_state=RANDOM_STATE,
        eval_metric='logloss',
        verbosity=1
    ),
    "decision_tree": DecisionTreeClassifier(
        max_depth=20,
        random_state=RANDOM_STATE
    ),
    "logistic_regression": LogisticRegression(
        max_iter=1000,
        n_jobs=-1,
        random_state=RANDOM_STATE
    )
}

def load_data():
    print("[1] Loading train and test sets...")
    train = pd.read_csv(TRAIN_PATH)
    test  = pd.read_csv(TEST_PATH)

    X_train = train.drop(columns=['label'])
    y_train = train['label']
    X_test  = test.drop(columns=['label'])
    y_test  = test['label']

    print(f"    Train: {X_train.shape} | Test: {X_test.shape}")
    print(f"    Features: {X_train.shape[1]}")
    return X_train, y_train, X_test, y_test

def evaluate_model(name, model, X_test, y_test):
    """Run full evaluation on a trained model."""
    y_pred = model.predict(X_test)
    y_prob = model.predict_proba(X_test)[:, 1] if hasattr(model, 'predict_proba') else None

    metrics = {
        "accuracy":  accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred),
        "recall":    recall_score(y_test, y_pred),
        "f1":        f1_score(y_test, y_pred),
        "roc_auc":   roc_auc_score(y_test, y_prob) if y_prob is not None else None,
    }

    print(f"\n  {name} Results:")
    print(f"    Accuracy:  {metrics['accuracy']:.4f}")
    print(f"    Precision: {metrics['precision']:.4f}")
    print(f"    Recall:    {metrics['recall']:.4f}")
    print(f"    F1 Score:  {metrics['f1']:.4f}")
    if metrics['roc_auc']:
        print(f"    ROC-AUC:   {metrics['roc_auc']:.4f}")

    return metrics, y_pred, y_prob

def plot_confusion_matrix(name, y_test, y_pred):
    """Save confusion matrix heatmap."""
    cm = confusion_matrix(y_test, y_pred)
    fig, ax = plt.subplots(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=['Benign', 'Malicious'],
                yticklabels=['Benign', 'Malicious'], ax=ax)
    ax.set_xlabel('Predicted')
    ax.set_ylabel('Actual')
    ax.set_title(f'Confusion Matrix — {name}')
    plt.tight_layout()
    path = os.path.join(RESULTS_DIR, f"confusion_matrix_{name}.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"    Saved: {path}")

def plot_roc_curves(results, X_test, y_test):
    """Save ROC curves for all models."""
    fig, ax = plt.subplots(figsize=(10, 8))
    for name, (model, metrics, y_pred, y_prob) in results.items():
        if y_prob is not None:
            fpr, tpr, _ = roc_curve(y_test, y_prob)
            auc = metrics['roc_auc']
            ax.plot(fpr, tpr, label=f"{name} (AUC={auc:.3f})", linewidth=2)

    ax.plot([0, 1], [0, 1], 'k--', linewidth=1, label='Random')
    ax.set_xlabel('False Positive Rate')
    ax.set_ylabel('True Positive Rate')
    ax.set_title('ROC Curves — All Models')
    ax.legend(loc='lower right')
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    path = os.path.join(RESULTS_DIR, "roc_curves.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"    Saved: {path}")

def plot_feature_importance(model, feature_names, top_n=20):
    """Save feature importance bar chart for Random Forest."""
    if not hasattr(model, 'feature_importances_'):
        return
    importances = model.feature_importances_
    indices = np.argsort(importances)[::-1][:top_n]

    fig, ax = plt.subplots(figsize=(12, 8))
    ax.bar(range(top_n), importances[indices], color='steelblue')
    ax.set_xticks(range(top_n))
    ax.set_xticklabels([feature_names[i] for i in indices], rotation=45, ha='right')
    ax.set_xlabel('Feature')
    ax.set_ylabel('Importance')
    ax.set_title(f'Top {top_n} Feature Importances — Random Forest')
    plt.tight_layout()
    path = os.path.join(RESULTS_DIR, "feature_importance.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"    Saved: {path}")

def plot_model_comparison(results):
    """Save model comparison bar chart."""
    metrics_list = ['accuracy', 'precision', 'recall', 'f1', 'roc_auc']
    model_names = list(results.keys())

    data = []
    for name, (model, metrics, y_pred, y_prob) in results.items():
        row = [metrics.get(m, 0) or 0 for m in metrics_list]
        data.append(row)

    df = pd.DataFrame(data, index=model_names, columns=metrics_list)

    fig, ax = plt.subplots(figsize=(12, 7))
    x = np.arange(len(metrics_list))
    width = 0.2
    colors = ['steelblue', 'coral', 'green', 'purple']

    for i, (name, row) in enumerate(df.iterrows()):
        ax.bar(x + i * width, row.values, width, label=name, color=colors[i], alpha=0.85)

    ax.set_xticks(x + width * 1.5)
    ax.set_xticklabels(metrics_list)
    ax.set_ylim(0, 1.1)
    ax.set_ylabel('Score')
    ax.set_title('Model Comparison — All Metrics')
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    path = os.path.join(RESULTS_DIR, "model_comparison.png")
    plt.savefig(path, dpi=150)
    plt.close()
    print(f"    Saved: {path}")

def write_report(results, feature_names):
    """Write markdown evaluation report."""
    report_path = os.path.join(RESULTS_DIR, "evaluation_report.md")

    with open(report_path, 'w') as f:
        f.write("# Model Evaluation Report\n\n")
        f.write("## Dataset\n\n")
        f.write(f"- Training samples: 610,137\n")
        f.write(f"- Test samples: 152,535\n")
        f.write(f"- Features: {len(feature_names)}\n")
        f.write(f"- Classes: Benign (0), Malicious (1)\n\n")

        f.write("## Results Summary\n\n")
        f.write("| Model | Accuracy | Precision | Recall | F1 | ROC-AUC |\n")
        f.write("|-------|----------|-----------|--------|----|---------|\n")

        for name, (model, metrics, y_pred, y_prob) in results.items():
            auc = f"{metrics['roc_auc']:.4f}" if metrics['roc_auc'] else "N/A"
            f.write(
                f"| {name} "
                f"| {metrics['accuracy']:.4f} "
                f"| {metrics['precision']:.4f} "
                f"| {metrics['recall']:.4f} "
                f"| {metrics['f1']:.4f} "
                f"| {auc} |\n"
            )

        f.write("\n## Attack Scenario Coverage\n\n")
        f.write("The model was trained on traffic from 8 attack scenarios:\n\n")
        f.write("| Scenario | Flows |\n")
        f.write("|----------|-------|\n")
        f.write("| nmap_syn_scan | 525,288 |\n")
        f.write("| nmap_service_scan | 526,181 |\n")
        f.write("| nmap_evasion_scan | 156 |\n")
        f.write("| hydra_ssh_brute | 2 |\n")
        f.write("| hydra_http_brute | 546 |\n")
        f.write("| c2_beacon | 53 |\n")
        f.write("| slowhttptest_dos | 3,795 |\n")
        f.write("| metasploit_ms17010 | 18 |\n")

        f.write("\n## Visualizations\n\n")
        f.write("- `confusion_matrix_random_forest.png`\n")
        f.write("- `roc_curves.png`\n")
        f.write("- `feature_importance.png`\n")
        f.write("- `model_comparison.png`\n")

    print(f"    Saved: {report_path}")

def main():
    print("=" * 55)
    print(" Model Training Pipeline")
    print("=" * 55)

    # Load data
    X_train, y_train, X_test, y_test = load_data()
    feature_names = list(X_train.columns)

    results = {}

    # Train and evaluate each model
    print("\n[2] Training models...")
    for name, model in MODELS.items():
        print(f"\n  Training {name}...")
        model.fit(X_train, y_train)

        # Save model
        model_path = os.path.join(MODELS_DIR, f"{name}.pkl")
        with open(model_path, 'wb') as f:
            pickle.dump(model, f)
        print(f"  Saved: {model_path}")

        # Evaluate
        metrics, y_pred, y_prob = evaluate_model(name, model, X_test, y_test)
        results[name] = (model, metrics, y_pred, y_prob)

        # Confusion matrix for each model
        plot_confusion_matrix(name, y_test, y_pred)

    # Plots
    print("\n[3] Generating visualizations...")
    plot_roc_curves(results, X_test, y_test)
    plot_feature_importance(
        results["random_forest"][0],
        feature_names
    )
    plot_model_comparison(results)

    # Report
    print("\n[4] Writing evaluation report...")
    write_report(results, feature_names)

    # Summary
    print("\n" + "=" * 55)
    print(" Training complete!")
    print("=" * 55)
    print("\nModel comparison:")
    print(f"  {'Model':<25} {'Accuracy':>10} {'F1':>10} {'ROC-AUC':>10}")
    print(f"  {'-'*55}")
    for name, (model, metrics, y_pred, y_prob) in results.items():
        auc = f"{metrics['roc_auc']:.4f}" if metrics['roc_auc'] else "  N/A"
        print(f"  {name:<25} {metrics['accuracy']:>10.4f} {metrics['f1']:>10.4f} {auc:>10}")

    # Identify best model
    best = max(results.items(), key=lambda x: x[1][1]['f1'])
    print(f"\n  Best model by F1: {best[0]} (F1={best[1][1]['f1']:.4f})")
    print("\nNext step: python src/explain.py")

if __name__ == "__main__":
    main()

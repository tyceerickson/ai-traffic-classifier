# Model Evaluation Report

## Dataset

- Training samples: 610,137
- Test samples: 152,535
- Features: 78
- Classes: Benign (0), Malicious (1)

## Results Summary

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC |
|-------|----------|-----------|--------|----|---------|
| random_forest | 0.9999 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| xgboost | 0.9999 | 1.0000 | 0.9999 | 0.9999 | 1.0000 |
| decision_tree | 0.9999 | 1.0000 | 0.9999 | 0.9999 | 0.9999 |
| logistic_regression | 0.8092 | 0.8092 | 1.0000 | 0.8945 | 0.6893 |

## Attack Scenario Coverage

The model was trained on traffic from 8 attack scenarios:

| Scenario | Flows |
|----------|-------|
| nmap_syn_scan | 525,288 |
| nmap_service_scan | 526,181 |
| nmap_evasion_scan | 156 |
| hydra_ssh_brute | 2 |
| hydra_http_brute | 546 |
| c2_beacon | 53 |
| slowhttptest_dos | 3,795 |
| metasploit_ms17010 | 18 |

## Visualizations

- `confusion_matrix_random_forest.png`
- `roc_curves.png`
- `feature_importance.png`
- `model_comparison.png`

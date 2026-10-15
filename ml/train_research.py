"""Research-only, label-gated baselines. Never exports a deployable model."""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from datetime import date
from pathlib import Path

import numpy as np
from sklearn.dummy import DummyClassifier, DummyRegressor
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.metrics import (
    average_precision_score, brier_score_loss, mean_absolute_error,
    r2_score, roc_auc_score,
)
from sklearn.model_selection import GroupShuffleSplit

FEATURES = (
    "resting_heart_rate", "hrv_sdnn", "respiratory_rate", "sleep_duration_min",
    "steps", "active_energy_kcal", "exercise_duration_min",
)
TARGETS = {
    "disease_event": "classification",
    "anomaly_event": "classification",
    "next_night_sleep_min": "regression",
    "next_day_recovery": "regression",
    "next_day_performance": "regression",
}
REQUIRED_METADATA = ("dataset_name", "license", "source", "consent_basis", "label_source", "label_horizon")


def load_dataset(csv_path: Path, metadata_path: Path, target: str):
    if target not in TARGETS:
        raise ValueError("Unknown target")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    if any(not isinstance(metadata.get(key), str) or not metadata[key].strip() for key in REQUIRED_METADATA):
        raise ValueError("Dataset metadata incomplete")
    if any("unknown" in metadata[key].lower() or "synthetic" in metadata[key].lower() for key in REQUIRED_METADATA):
        raise ValueError("Unknown or synthetic provenance cannot establish model validity")
    if target in ("disease_event", "anomaly_event") and metadata["label_source"] not in (
        "clinician_adjudicated", "laboratory_confirmed", "independent_record",
    ):
        raise ValueError("Risk/anomaly labels must be independently established")

    with csv_path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        required = {"user_id", "date", target, *FEATURES}
        if not required.issubset(set(reader.fieldnames or [])):
            raise ValueError(f"Missing required columns: {', '.join(sorted(required - set(reader.fieldnames or [])))}")
        rows = list(reader)
    if len(rows) < 100:
        raise ValueError("At least 100 observations required for a research run")
    keys = [(row["user_id"], row["date"]) for row in rows]
    if len(keys) != len(set(keys)):
        raise ValueError("Duplicate subject-date observations")
    groups = np.array([row["user_id"] for row in rows])
    if len(set(groups)) < 10:
        raise ValueError("At least 10 subjects required for group holdout")
    dates = np.array([date.fromisoformat(row["date"]).toordinal() for row in rows])
    X = np.array([[float(row[key]) if row[key] else np.nan for key in FEATURES] for row in rows])
    y = np.array([float(row[target]) for row in rows])
    if not np.isfinite(y).all() or not np.isfinite(X[~np.isnan(X)]).all():
        raise ValueError("Non-finite values are not accepted")
    if TARGETS[target] == "classification" and not set(y).issubset({0.0, 1.0}):
        raise ValueError("Classification labels must be 0 or 1")
    return X, y, groups, dates, metadata


def evaluate(csv_path: Path, metadata_path: Path, target: str, cutoff: date) -> dict:
    X, y, groups, dates, metadata = load_dataset(csv_path, metadata_path, target)
    cutoff_number = cutoff.toordinal()
    splitter = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=42)
    train_groups, test_groups = next(splitter.split(X, y, groups))
    train_users = set(groups[train_groups])
    test_users = set(groups[test_groups])
    if train_users & test_users:
        raise AssertionError("Subject leakage")
    train = np.array([i for i in train_groups if dates[i] < cutoff_number])
    test = np.array([i for i in test_groups if dates[i] >= cutoff_number])
    if len(train) < 50 or len(test) < 20:
        raise ValueError("Insufficient observations on either side of prospective date cutoff")
    train_y, test_y = y[train], y[test]
    if TARGETS[target] == "classification":
        if len(set(train_y)) < 2 or len(set(test_y)) < 2:
            raise ValueError("Both classes required in training and untouched test")
        baseline = DummyClassifier(strategy="prior").fit(X[train], train_y)
        candidate = HistGradientBoostingClassifier(max_iter=100, max_leaf_nodes=8, l2_regularization=1.0, random_state=42).fit(X[train], train_y)
        scores = {}
        for name, model in (("baseline", baseline), ("candidate", candidate)):
            prediction = model.predict_proba(X[test])[:, 1]
            scores[name] = {
                "roc_auc": round(float(roc_auc_score(test_y, prediction)), 4),
                "average_precision": round(float(average_precision_score(test_y, prediction)), 4),
                "brier": round(float(brier_score_loss(test_y, prediction)), 4),
            }
    else:
        baseline = DummyRegressor(strategy="median").fit(X[train], train_y)
        candidate = HistGradientBoostingRegressor(max_iter=100, max_leaf_nodes=8, l2_regularization=1.0, random_state=42).fit(X[train], train_y)
        scores = {}
        for name, model in (("baseline", baseline), ("candidate", candidate)):
            prediction = model.predict(X[test])
            scores[name] = {
                "mae": round(float(mean_absolute_error(test_y, prediction)), 4),
                "r2": round(float(r2_score(test_y, prediction)), 4),
            }
    return {
        "status": "research_only_not_for_product",
        "target": target,
        "dataset": metadata["dataset_name"],
        "label_source": metadata["label_source"],
        "cutoff": cutoff.isoformat(),
        "train_rows": len(train), "test_rows": len(test),
        "train_subjects": len(set(groups[train])), "test_subjects": len(set(groups[test])),
        "train_target_distribution": dict(Counter(map(str, train_y))) if TARGETS[target] == "classification" else None,
        "test_target_distribution": dict(Counter(map(str, test_y))) if TARGETS[target] == "classification" else None,
        "scores": scores,
        "limitations": "Single group+time holdout; requires external validation, subgroup analysis and calibration before product use.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    parser.add_argument("metadata", type=Path)
    parser.add_argument("target", choices=TARGETS)
    parser.add_argument("--cutoff", required=True, type=date.fromisoformat)
    args = parser.parse_args()
    print(json.dumps(evaluate(args.csv, args.metadata, args.target, args.cutoff), indent=2))

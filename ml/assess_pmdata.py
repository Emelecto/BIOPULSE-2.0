"""Reproduce PMData research holdout and a prior-readiness persistence baseline."""
from __future__ import annotations

import argparse
import csv
import json
from datetime import date
from pathlib import Path

import numpy as np
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import GroupShuffleSplit

from train_research import FEATURES, evaluate, load_dataset

parser = argparse.ArgumentParser()
parser.add_argument('csv_path', type=Path)
parser.add_argument('metadata_path', type=Path)
parser.add_argument('--cutoff', type=date.fromisoformat, required=True)
args = parser.parse_args()

result = evaluate(args.csv_path, args.metadata_path, 'next_day_recovery', args.cutoff)
X, y, groups, dates, _ = load_dataset(args.csv_path, args.metadata_path, 'next_day_recovery')
with args.csv_path.open(newline='', encoding='utf-8-sig') as stream:
    records = list(csv.DictReader(stream))
prior = np.array([float(row['prior_readiness']) for row in records])
split = GroupShuffleSplit(n_splits=1, test_size=0.25, random_state=42)
_, test_indices = next(split.split(X, y, groups))
test = np.array([i for i in test_indices if dates[i] >= args.cutoff.toordinal()])
result['held_out_subjects'] = sorted(set(groups[test]))
result['persistence_baseline'] = {
    'mae': round(float(mean_absolute_error(y[test], prior[test])), 4),
    'r2': round(float(r2_score(y[test], prior[test])), 4),
}
result['feature_coverage'] = {
    key: round(float(np.isfinite(X[:, n]).mean()), 4)
    for n, key in enumerate(FEATURES)
}
print(json.dumps(result, indent=2))

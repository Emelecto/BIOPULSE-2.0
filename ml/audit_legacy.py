"""Read-only schema/provenance audit. Never publishes source rows or identifiers."""
from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from pathlib import Path


def audit(path: Path) -> dict:
    users: set[str] = set()
    keys: set[tuple[str, str]] = set()
    missing: Counter[str] = Counter()
    duplicates = 0
    dates: list[str] = []
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        columns = reader.fieldnames or []
        for row in reader:
            user, date = row.get("user_id", ""), row.get("date", "")
            users.add(user)
            dates.append(date)
            key = (user, date)
            if key in keys:
                duplicates += 1
            keys.add(key)
            missing.update(name for name, value in row.items() if value is None or value == "")
    return {
        "rows": len(dates),
        "columns": columns,
        "subjects": len(users),
        "duplicate_user_dates": duplicates,
        "min_date": min(dates) if dates else None,
        "max_date": max(dates) if dates else None,
        "missing_by_column": dict(missing),
        "has_independent_disease_label": any(c in columns for c in ("diagnosis_confirmed", "disease_outcome")),
        "provenance_and_license": "UNKNOWN — verify before training or redistribution",
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python ml/audit_legacy.py PATH_TO_CSV")
    print(json.dumps(audit(Path(sys.argv[1])), indent=2, ensure_ascii=False))

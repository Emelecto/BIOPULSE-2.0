import json
import tempfile
import unittest
import csv
from datetime import date, timedelta
from pathlib import Path

from sys import path
path.insert(0, str(Path(__file__).resolve().parents[1]))
from train_research import FEATURES, evaluate, load_dataset


class ContractTests(unittest.TestCase):
    def test_rejects_unverified_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            metadata = folder / "metadata.json"
            metadata.write_text(json.dumps({"dataset_name": "test", "license": "UNKNOWN"}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "metadata incomplete"):
                load_dataset(folder / "missing.csv", metadata, "disease_event")

    def test_rejects_rule_derived_clinical_label(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            metadata = folder / "metadata.json"
            metadata.write_text(json.dumps({
                "dataset_name": "test", "license": "private", "source": "test", "consent_basis": "test",
                "label_source": "derived_rule", "label_horizon": "one day",
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "independently established"):
                load_dataset(folder / "missing.csv", metadata, "disease_event")

    def test_rejects_score_derived_wellness_label(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            metadata = folder / "metadata.json"
            metadata.write_text(json.dumps({
                "dataset_name": "test", "license": "private", "source": "test", "consent_basis": "test",
                "label_source": "derived_rule", "label_horizon": "next day",
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "independent observations"):
                load_dataset(folder / "missing.csv", metadata, "next_day_recovery")

    def test_research_pipeline_smoke_with_artificial_fixture(self):
        # Fabricated rows validate software mechanics only; no scientific claim.
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            metadata = folder / "metadata.json"
            metadata.write_text(json.dumps({
                "dataset_name": "unit-test-fixture", "license": "internal test fixture",
                "source": "unit test", "consent_basis": "unit test",
                "label_source": "independent_record", "label_horizon": "next night",
            }), encoding="utf-8")
            csv_file = folder / "rows.csv"
            with csv_file.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(stream, fieldnames=["user_id", "date", *FEATURES, "next_night_sleep_min"])
                writer.writeheader()
                for user in range(20):
                    for day in range(20):
                        row = {"user_id": f"fixture-{user}", "date": (date(2025, 1, 1) + timedelta(days=day)).isoformat(),
                               "next_night_sleep_min": 390 + user + day}
                        row.update({name: 30 + user + day for name in FEATURES})
                        writer.writerow(row)
            result = evaluate(csv_file, metadata, "next_night_sleep_min", date(2025, 1, 11))
            self.assertEqual(result["status"], "research_only_not_for_product")
            self.assertGreater(result["train_rows"], 50)
            self.assertGreater(result["test_rows"], 20)
            self.assertIn("baseline", result["scores"])
            self.assertIn("linear", result["scores"])
            self.assertIn("candidate", result["scores"])


if __name__ == "__main__":
    unittest.main()

import unittest
from datetime import datetime, timezone
from endpoint_toolkit.compare import compare_inventories

NOW = datetime(2026, 11, 21, tzinfo=timezone.utc)


class CompareTests(unittest.TestCase):
    def test_detects_regression_addition_and_missing_device(self):
        before = [
            {"id": "win-1", "deviceName": "WIN-1", "complianceState": "compliant",
             "lastSyncDateTime": "2026-11-20T00:00:00Z"},
            {"id": "retired-2", "deviceName": "OLD-2", "complianceState": "compliant",
             "lastSyncDateTime": "2026-11-20T00:00:00Z"},
        ]
        after = [
            {"id": "win-1", "deviceName": "WIN-1", "complianceState": "noncompliant",
             "lastSyncDateTime": "2026-11-20T00:00:00Z"},
            {"id": "new-3", "deviceName": "NEW-3"},
        ]
        result = compare_inventories(before, after, now=NOW)
        self.assertEqual(result["counts"]["regressed"], 1)
        self.assertEqual(result["counts"]["added"], 1)
        self.assertEqual(result["counts"]["missing"], 1)
        self.assertEqual(result["before_total"], 2)
        self.assertEqual(result["after_total"], 2)

    def test_unknown_is_not_counted_as_healthy(self):
        before = [{"id": "1", "deviceName": "A", "complianceState": "compliant",
                   "lastSyncDateTime": "2026-11-20T00:00:00Z"}]
        after = [{"id": "1", "deviceName": "A"}]
        result = compare_inventories(before, after, now=NOW)
        self.assertEqual(result["counts"]["regressed"], 1)
        self.assertEqual(result["changes"][0]["current_risk"], "unknown")

    def test_stable_name_fallback_without_id(self):
        base = [{"deviceName": "Mac", "operatingSystem": "macOS"}]
        result = compare_inventories(base, base, now=NOW)
        self.assertEqual(result["counts"]["unchanged"], 1)

    def test_duplicate_identifiers_are_rejected(self):
        source = [{"id": "same", "deviceName": "one"}, {"id": "same", "deviceName": "two"}]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            compare_inventories(source, [], now=NOW)

    def test_unidentifiable_inventory_rejected(self):
        with self.assertRaisesRegex(ValueError, "needs an id"):
            compare_inventories([{"operatingSystem": "Windows"}], [], now=NOW)

    def test_improvement_is_tracked(self):
        before = [{"id": "a", "complianceState": "noncompliant"}]
        after = [{"id": "a", "complianceState": "compliant", "lastSyncDateTime": "2026-11-20T00:00:00Z"}]
        self.assertEqual(compare_inventories(before, after, now=NOW)["counts"]["improved"], 1)

    def test_missing_current_data_does_not_prove_improvement(self):
        before = [{"id": "a", "complianceState": "noncompliant",
                   "lastSyncDateTime": "2026-11-20T00:00:00Z"}]
        for after in (
            [{"id": "a", "lastSyncDateTime": "2026-11-20T00:00:00Z"}],
            [{"id": "a", "complianceState": "compliant"}],
            [{"id": "a", "lastSyncDateTime": "2026-01-01T00:00:00Z"}],
        ):
            with self.subTest(after=after):
                result = compare_inventories(before, after, now=NOW)
                self.assertEqual(result["counts"]["improved"], 0)
                self.assertEqual(result["counts"]["changed"], 1)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Focused loader tests: python tools/test_case_viewer.py"""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from case_viewer import apply_changes, load_case, main, render_report

FIXTURE = Path(__file__).with_name("fixtures") / "case_viewer.trace.jsonl"


class ViewerTests(unittest.TestCase):
    def load_rows(self, rows):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.jsonl"
            path.write_text("\n".join(json.dumps(row) for row in rows), encoding="utf-8")
            return load_case(path)

    def rows(self):
        return [json.loads(line) for line in FIXTURE.read_text(encoding="utf-8").splitlines()]

    def test_fixture_replay_and_streams(self):
        case = load_case(FIXTURE)
        self.assertTrue(case["detailed"])
        self.assertEqual(case["warnings"], [])
        self.assertEqual({e["stream"] for e in case["events"]}, {"real", "shadow"})

    def test_value_changes_are_not_replayed_twice(self):
        rows = self.rows()
        rows[4]["data"]["to"] = .999
        # Explanatory values are not mutations; checkpoints/deltas remain authoritative.
        self.assertTrue(self.load_rows(rows)["detailed"])

    def test_bad_delta_and_bad_checkpoint_are_rejected(self):
        rows = self.rows()
        rows[5]["data"]["changes"][0]["from"] = .1
        with self.assertRaisesRegex(ValueError, "previous value mismatch"):
            self.load_rows(rows)
        rows = self.rows()
        rows[-2]["data"]["state"]["trust"] = .7
        with self.assertRaisesRegex(ValueError, "checkpoint does not match"):
            self.load_rows(rows)

    def test_gaps_duplicate_sequence_and_new_schema_are_rejected(self):
        for mutate in (
            lambda r: r.pop(4),
            lambda r: r[4].update(seq=4),
            lambda r: r[4].update(schema=2),
        ):
            rows = self.rows()
            mutate(rows)
            with self.assertRaises(ValueError):
                self.load_rows(rows)

    def test_missing_initial_checkpoint_is_rejected(self):
        rows = self.rows()[5:6]
        rows[0]["seq"] = 1
        with self.assertRaisesRegex(ValueError, "no initial checkpoint"):
            self.load_rows(rows)

    def test_null_add_delete_and_atomic_arrays(self):
        state = {"nested": {"gone": None}, "array": [1]}
        changes = [
            {"path": ["nested", "gone"], "had_before": True, "has_after": False, "from": None, "to": None},
            {"path": ["nested", "new"], "had_before": False, "has_after": True, "from": None, "to": None},
            {"path": ["array"], "had_before": True, "has_after": True, "from": [1], "to": [1, 2]},
        ]
        apply_changes(state, changes)
        self.assertEqual(state, {"nested": {"new": None}, "array": [1, 2]})
        changes[-1]["to"].append(3)
        self.assertEqual(state["array"], [1, 2])

    def test_legacy_warning_and_event_only_logs(self):
        case = self.load_rows([{"seq": 1, "type": "trust", "actor": "agnes", "data": {"to": .4}}])
        self.assertFalse(case["detailed"])
        self.assertIn("Legacy", case["warnings"][0])
        self.assertIn("case-data", render_report(case))

    def test_empty_malformed_and_nonfinite_input(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "bad.jsonl"
            for content in ("", "{", '{"type":"x","data":{"n":NaN}}', "[]", '{"type":"x","data":{"n":1e999}}'):
                path.write_text(content, encoding="utf-8")
                with self.assertRaises(ValueError):
                    load_case(path)

    def test_payload_cannot_close_script_element(self):
        case = copy.deepcopy(load_case(FIXTURE))
        case["source"] = "</script><script>throw 'injection'</script>&"
        report = render_report(case)
        payload = report.split('<script id="case-data" type="application/json">')[1].split("</script>")[0]
        self.assertNotIn("<", payload)
        self.assertNotIn("&", payload)
        self.assertEqual(json.loads(payload)["source"], case["source"])
        self.assertNotIn("/*CASE_DATA*/", report)

    def test_cli_output_and_input_preservation(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "case.html"
            self.assertEqual(main([str(FIXTURE), "-o", str(output)]), 0)
            self.assertTrue(output.is_file())
            before = FIXTURE.read_bytes()
            self.assertEqual(main([str(FIXTURE), "-o", str(FIXTURE)]), 1)
            self.assertEqual(FIXTURE.read_bytes(), before)
            self.assertEqual(main([str(FIXTURE), "--validate-only"]), 0)


if __name__ == "__main__":
    unittest.main()

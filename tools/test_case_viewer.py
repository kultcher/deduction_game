#!/usr/bin/env python3
"""Focused loader tests: python tools/test_case_viewer.py"""
import copy
import json
from pathlib import Path
import tempfile
import threading
from http.client import HTTPConnection
from urllib.parse import urlsplit
from unittest.mock import patch
import unittest
from case_viewer import apply_changes, default_log_dir, load_case, main, make_viewer_server, render_report

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


    def test_default_log_folder(self):
        with patch.dict("os.environ", {"APPDATA": "C:/Users/kultc/AppData/Roaming"}):
            self.assertEqual(default_log_dir(), Path("C:/Users/kultc/AppData/Roaming") /
                             "Godot/app_userdata/Demonologist (text prototype)/logs")

    def test_native_load_session_and_failure_preservation(self):
        requested = []
        choices = iter([FIXTURE, None, FIXTURE.with_name("missing.jsonl")])
        directory = Path("C:/Users/kultc/AppData/Roaming/Godot/app_userdata/Demonologist (text prototype)/logs")

        def chooser(start):
            requested.append(start)
            return next(choices)

        server = make_viewer_server(load_case(FIXTURE), directory, chooser)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        address = urlsplit(server.viewer_url)

        def request(method, route, headers=None):
            connection = HTTPConnection(address.hostname, address.port, timeout=5)
            try:
                connection.request(method, route, headers=headers or {})
                response = connection.getresponse()
                return response.status, response.read().decode("utf-8")
            finally:
                connection.close()

        try:
            status, report = request("GET", address.path)
            self.assertEqual(status, 200)
            payload = report.split('<script id="case-data" type="application/json">')[1].split("</script>")[0]
            loader = json.loads(payload)["loader"]
            self.assertEqual(loader["directory"], str(directory))
            headers = {"X-Case-Viewer": loader["token"], "Origin": f"http://127.0.0.1:{address.port}"}
            self.assertEqual(request("POST", loader["url"])[0], 403)
            self.assertEqual(request("POST", loader["url"], {**headers, "Origin": "https://example.com"})[0], 403)
            self.assertEqual(requested, [])
            status, body = request("POST", loader["url"], headers)
            self.assertEqual(status, 200)
            self.assertTrue(json.loads(body)["case"]["detailed"])
            self.assertEqual(requested, [directory])
            self.assertEqual(request("POST", loader["url"], headers), (200, "{}"))
            self.assertEqual(request("POST", loader["url"], headers)[0], 400)
            self.assertEqual(request("GET", address.path)[1], report)
            self.assertEqual(request("GET", "/not-a-viewer-session")[0], 404)
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=5)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Validate a case JSONL export and create a fully offline HTML inspector.

Python 3.10+, standard library only. This tool never runs simulation code.
"""
from __future__ import annotations
import argparse
import copy
import json
import math
import os
import secrets
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import sys
import webbrowser


def apply_changes(state, changes):
    """Apply dictionary deltas, verifying their recorded preconditions."""
    for change in changes:
        path = change["path"]
        if not isinstance(path, list) or not path or not all(isinstance(k, str) for k in path):
            raise ValueError("delta path must be a nonempty list of strings")
        parent = state
        for key in path[:-1]:
            if not isinstance(parent, dict) or key not in parent:
                raise ValueError(f"missing delta parent: {path!r}")
            parent = parent[key]
        if not isinstance(parent, dict):
            raise ValueError(f"delta parent is not a dictionary: {path!r}")
        key = path[-1]
        if not isinstance(change["had_before"], bool) or not isinstance(change["has_after"], bool):
            raise ValueError("delta existence flags must be booleans")
        if (key in parent) != change["had_before"]:
            raise ValueError(f"delta existence mismatch: {path!r}")
        if change["had_before"] and parent[key] != change["from"]:
            raise ValueError(f"delta previous value mismatch: {path!r}")
        if change["has_after"]:
            parent[key] = copy.deepcopy(change["to"])
        else:
            parent.pop(key, None)


def reject_constant(value):
    raise ValueError(f"non-finite JSON number: {value}")


def finite_float(value):
    number = float(value)
    if not math.isfinite(number):
        raise ValueError(f"non-finite JSON number: {value}")
    return number


def load_case(path):
    events = []
    with Path(path).open(encoding="utf-8-sig") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                event = json.loads(line, parse_constant=reject_constant, parse_float=finite_float)
                if not isinstance(event, dict) or not isinstance(event.get("data"), dict):
                    raise ValueError("each event must be an object with dictionary data")
                if not isinstance(event.get("type"), str):
                    raise ValueError("event type must be a string")
                events.append(event)
            except (ValueError, TypeError) as error:
                raise ValueError(f"line {line_number}: {error}") from error
    if not events:
        raise ValueError("empty log")
    detailed = any("schema" in event for event in events)
    warnings = []
    states = {}
    previous = 0
    for index, event in enumerate(events):
        try:
            if not detailed:
                continue
            if event.get("schema") != 1:
                raise ValueError("unsupported or mixed trace schema (expected 1)")
            seq = event.get("seq")
            if type(seq) is not int or seq <= previous:
                raise ValueError("sequence must be a strictly increasing integer")
            if seq != previous + 1:
                raise ValueError(f"missing events before sequence {seq}; exact replay is unsafe")
            previous = seq
            if event.get("stream") not in ("real", "shadow"):
                raise ValueError("missing real/shadow stream")
            if not isinstance(event.get("actor"), str):
                raise ValueError("actor must be a string")
            data = event["data"]
            if event["type"] not in ("state_checkpoint", "state_delta"):
                continue
            mind = data["mind"]
            if mind not in ("real", "shadow"):
                raise ValueError("invalid state mind")
            key = (mind, event["actor"])
            if event["type"] == "state_checkpoint":
                state = data["state"]
                if not isinstance(state, dict):
                    raise ValueError("checkpoint state must be a dictionary")
                if key in states and states[key] != state:
                    raise ValueError(f"checkpoint does not match replay for {key}")
                states[key] = copy.deepcopy(state)
            else:
                if key not in states:
                    raise ValueError(f"delta has no initial checkpoint for {key}")
                apply_changes(states[key], data["changes"])
        except (KeyError, TypeError, ValueError) as error:
            raise ValueError(f"event {index + 1} (seq {event.get('seq')}): {error}") from error
    if detailed and not states:
        warnings.append("No state checkpoints: event inspection only.")
    if not detailed:
        warnings.append("Legacy log: observations are incomplete/rounded. Dots are recorded observations; missing changes, relationships and ledger history are unknown.")
    if detailed and events[-1]["type"] != "action_end":
        warnings.append("Export ends outside a completed action. It may be partial; histories stop at the last recorded observation.")
    return {"source": Path(path).name, "detailed": detailed, "warnings": warnings, "events": events}


def render_report(case):
    template = Path(__file__).with_name("case_viewer.html").read_text(encoding="utf-8")
    # Escape HTML-significant characters inside the inert JSON script element.
    payload = json.dumps(case, ensure_ascii=True, allow_nan=False, separators=(",", ":"))
    payload = payload.replace("&", "\\u0026").replace("<", "\\u003c").replace(">", "\\u003e")
    return template.replace("/*CASE_DATA*/", payload, 1)


def default_log_dir():
    appdata = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    return appdata / "Godot" / "app_userdata" / "Demonologist (text prototype)" / "logs"


def choose_log(directory):
    """Keep Tk on the launcher's main thread; import it only for native loading."""
    try:
        import tkinter as tk
        from tkinter import filedialog
    except ImportError as error:
        raise RuntimeError("Native Load requires Python's tkinter component.") from error
    root = tk.Tk()
    root.withdraw()
    try:
        root.attributes("-topmost", True)
        selected = filedialog.askopenfilename(
            parent=root, title="Load case log (.trace.jsonl recommended)",
            initialdir=str(directory),
            filetypes=[("Detailed traces", "*.trace.jsonl"), ("All JSONL logs", "*.jsonl"), ("All files", "*.*")],
        )
        return Path(selected) if selected else None
    finally:
        root.destroy()


def make_viewer_server(case, directory, chooser=choose_log):
    """Loopback-only UI. No arbitrary-path endpoint; Load opens a native chooser."""
    token = secrets.token_urlsafe(24)
    route = "/" + token + "/"
    current = {"case": case}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send_payload(self, code, payload, content_type="application/json"):
            body = payload.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", content_type + "; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy", "frame-ancestors 'none'")
            self.end_headers()
            self.wfile.write(body)

        def valid_host(self):
            return self.headers.get("Host") == f"127.0.0.1:{self.server.server_port}"

        def served_case(self):
            return {**current["case"], "loader": {
                "url": route + "load", "token": token, "directory": str(directory)}}

        def do_GET(self):
            if not self.valid_host() or self.path != route:
                self.send_payload(404, '{"error":"Not found"}')
                return
            self.send_payload(200, render_report(self.served_case()), "text/html")

        def do_POST(self):
            expected_origin = f"http://127.0.0.1:{self.server.server_port}"
            if (not self.valid_host() or self.path != route + "load"
                    or self.headers.get("X-Case-Viewer") != token
                    or self.headers.get("Origin") != expected_origin):
                self.send_payload(403, '{"error":"Invalid local viewer session"}')
                return
            if self.headers.get("Content-Length", "0") != "0":
                self.send_payload(400, '{"error":"Load does not accept request data"}')
                return
            try:
                selected = chooser(directory)
                if selected is None:
                    self.send_payload(200, "{}")
                    return
                next_case = load_case(selected)
                current["case"] = next_case
                self.send_payload(200, json.dumps({"case": self.served_case()}, allow_nan=False))
            except Exception as error:
                # Picker/parse failures leave the previously loaded case intact.
                self.send_payload(400, json.dumps({"error": str(error)}))

    server = HTTPServer(("127.0.0.1", 0), Handler)
    server.viewer_url = f"http://127.0.0.1:{server.server_port}{route}"
    return server


def serve_viewer(log, directory):
    case = load_case(log) if log else {
        "source": "No log loaded", "detailed": False, "warnings": [],
        "events": [{"seq": 1, "day": 0, "phase": "Setup", "type": "viewer_ready",
                    "actor": "world", "target": "", "data": {}, "reason": "Click Load log to choose a case."}],
    }
    server = make_viewer_server(case, directory)
    print(f"Log folder: {directory}")
    print(f"Viewer: {server.viewer_url}")
    print("Leave this terminal running for Load; press Ctrl+C to stop.")
    try:
        webbrowser.open(server.viewer_url)
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", nargs="?", type=Path, help="case_<seed>.trace.jsonl (or legacy .jsonl)")
    parser.add_argument("-o", "--output", type=Path, help="HTML output (default: beside input)")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--open", action="store_true", help="open generated HTML in the default browser")
    parser.add_argument("--serve", action="store_true", help="open a local viewer with a native Load dialog")
    parser.add_argument("--log-dir", type=Path, default=default_log_dir(), help="native Load starting folder (default: Godot userdata logs)")
    args = parser.parse_args(argv)
    if args.validate_only and args.log is None:
        parser.error("--validate-only requires a log")
    try:
        if args.serve or args.log is None:
            return serve_viewer(args.log, args.log_dir)
        case = load_case(args.log)
        print(f"{len(case['events'])} events; {'schema 1 replay verified' if case['detailed'] else 'legacy observations only'}")
        for warning in case["warnings"]:
            print(f"Warning: {warning}", file=sys.stderr)
        if args.validate_only:
            return 0
        output = args.output or args.log.with_suffix(".html")
        if output.resolve() == args.log.resolve():
            raise ValueError("output must differ from input")
        output.write_text(render_report(case), encoding="utf-8")
        print(output.resolve())
        if args.open:
            webbrowser.open(output.resolve().as_uri())
        return 0
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f"Case viewer: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

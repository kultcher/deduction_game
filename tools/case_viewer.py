#!/usr/bin/env python3
"""Validate a case JSONL export and create a fully offline HTML inspector.

Python 3.10+, standard library only. This tool never runs simulation code.
"""
from __future__ import annotations
import argparse
import copy
import json
import math
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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="case_<seed>.trace.jsonl (or legacy .jsonl)")
    parser.add_argument("-o", "--output", type=Path, help="HTML output (default: beside input)")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--open", action="store_true", help="open generated HTML in the default browser")
    args = parser.parse_args(argv)
    try:
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

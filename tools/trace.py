#!/usr/bin/env python3
"""Filter a case dev log (JSONL) for evaluation.

Examples:
  python3 tools/trace.py logs/case_12.jsonl                 # everything except snapshots/player output
  python3 tools/trace.py logs/case_12.jsonl --npc edda      # one NPC's actions, reasoning and how others saw them
  python3 tools/trace.py logs/case_12.jsonl --lies          # every lie, fabrication and false reading
  python3 tools/trace.py logs/case_12.jsonl --type kill,info,execution
  python3 tools/trace.py logs/case_12.jsonl --topic vote    # NPC reasoning of one topic
  python3 tools/trace.py logs/case_12.jsonl --suspicion edda  # how everyone's suspicion of edda moved
"""
import argparse, json

def fmt(e, full=False):
    who = e["actor"] + (" -> " + e["target"] if e["target"] else "")
    topic = e["data"].get("topic", "")
    head = f'[{e["seq"]:04d} D{e["day"]} {e["phase"]:<9}] {e["type"]:<14}{("("+topic+")") if topic else "":<16} {who:<22}'
    body = e["reason"]
    if full or not body:
        d = {k: v for k, v in e["data"].items() if k not in ("topic", "output")}
        if d:
            body += "  " + json.dumps(d)[:400]
    return head + " " + body

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--npc")
    ap.add_argument("--lies", action="store_true")
    ap.add_argument("--type")
    ap.add_argument("--topic")
    ap.add_argument("--suspicion")
    ap.add_argument("--full", action="store_true", help="always print data")
    ap.add_argument("--player", action="store_true", help="include player commands and output")
    a = ap.parse_args()
    entries = [json.loads(l) for l in open(a.log)]
    for e in entries:
        t, topic = e["type"], e["data"].get("topic", "")
        if t == "snapshot" and not a.type:
            continue
        if t.startswith("player_") and not a.player and not a.type:
            continue
        if a.npc and a.npc not in (e["actor"], e["target"]):
            continue
        if a.lies and not ((t == "think" and topic == "lie") or t == "fake_info"
                           or (t == "info" and not e["data"].get("true", True)) or t == "secret_assigned"):
            continue
        if a.type and t not in a.type.split(","):
            continue
        if a.topic and topic != a.topic:
            continue
        if a.suspicion and not (t == "suspicion" and e["target"] == a.suspicion):
            continue
        print(fmt(e, a.full))
        if t.startswith("player_") and a.player:
            print("    " + e["data"].get("output", "").replace("\n", "\n    "))

if __name__ == "__main__":
    main()

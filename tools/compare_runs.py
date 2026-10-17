"""Compare active/passive JSON reports from autoplay --results; no third-party dependencies."""
import argparse
import json
from pathlib import Path


def compare(active, passive):
    if active.get("schema_version") not in (1, 2) or passive.get("schema_version") not in (1, 2):
        raise ValueError("Expected schema_version 1 or 2 autoplay reports")
    if active.get("mode") != "active" or passive.get("mode") != "passive":
        raise ValueError("Pass the active report first and the passive report second")
    if active.get("npcs") != passive.get("npcs"):
        raise ValueError("Reports use different town sizes")
    a = {c["seed"]: c for c in active["cases"] if c["complete"]}
    p = {c["seed"]: c for c in passive["cases"] if c["complete"]}
    if len(a) != sum(c["complete"] for c in active["cases"]) or len(p) != sum(c["complete"] for c in passive["cases"]):
        raise ValueError("Reports contain duplicate completed seeds")
    seeds = sorted(a.keys() & p.keys())
    if not seeds:
        raise ValueError("No matching completed seeds")
    active_only = [s for s in seeds if a[s]["town_saved"] and not p[s]["town_saved"]]
    passive_only = [s for s in seeds if p[s]["town_saved"] and not a[s]["town_saved"]]
    lines = [f"Paired completed cases: {len(seeds)} (unpaired completed: active {len(a)-len(seeds)}, passive {len(p)-len(seeds)})"]
    for label, rows in [("Active", [a[s] for s in seeds]), ("Passive", [p[s] for s in seeds])]:
        wins = sum(c["town_saved"] for c in rows)
        wrong = sum(c["executions_good"] for c in rows)
        executions = sum(c["executions_total"] for c in rows)
        fraction = f"{wrong/executions:.1%}" if executions else "n/a"
        won = [c for c in rows if c["town_saved"]]
        survivors = f"{sum(c['good_surviving'] for c in won)/len(won):.2f}" if won else "n/a"
        lines.append(f"{label}: wins {wins}/{len(rows)} ({wins/len(rows):.1%}); wrongful executions {wrong}/{executions} ({fraction}); good survivors in wins {survivors}")
        lines.append(f"  Demon identified {sum(c['demon_identified'] for c in rows)}; both identities {sum(c['both_identified'] for c in rows)}; identified but lost {sum(c['identified_but_lost'] for c in rows)}")
        lines.append(f"  Wrongful execution stance: backed {sum(c['wrongful_backed'] for c in rows)}, opposed {sum(c['wrongful_opposed'] for c in rows)}, mixed {sum(c['wrongful_mixed'] for c in rows)}")
        hints = {}
        for c in rows:
            h = c.get("loss_hint", "")
            if h:
                hints[h] = hints.get(h, 0) + 1
        if hints:
            lines.append("  Losses by evidence: " + ", ".join(f"{k} {v}" for k, v in sorted(hints.items())))
        ns = [c["nights"] for c in rows if "nights" in c]
        if ns:
            prot = sum(n["warden_protects"] for n in ns)
            blk = sum(n["blocked_warden"] for n in ns)
            rate = f"{blk/prot:.1%}" if prot else "n/a"
            lines.append(f"  Nights: kills {sum(n['kills'] for n in ns)}, stopped by Warden {blk} (hit rate {rate} of {prot} guards), Veteran {sum(n['blocked_veteran'] for n in ns)}, your ward {sum(n['blocked_ward'] for n in ns)}; Warden spotted by demon {sum(n['warden_spotted'] for n in ns)}, Warden killed in {sum(1 for n in ns if n['warden_killed'])} cases")
    lines += [f"Win-rate difference: {100*(len(active_only)-len(passive_only))/len(seeds):+.1f} percentage points",
              f"Active-only wins ({len(active_only)}): {active_only}",
              f"Passive-only wins ({len(passive_only)}): {passive_only}",
              "Same seeds match starting setups; action-dependent random draws can change later events. Individual reversals are not proof of a specific harmful intervention."]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("active", type=Path)
    parser.add_argument("passive", type=Path)
    args = parser.parse_args()
    try:
        print(compare(json.loads(args.active.read_text()), json.loads(args.passive.read_text())))
    except (ValueError, KeyError, OSError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()

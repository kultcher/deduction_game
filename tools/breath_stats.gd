## Breathstealer fields for the balance-sweep record (tools/sweep_record.gd; schema in
## docs/balance_sweep.md). Reads `breath`, `breath_failed`, `silenced`, `silence_suppressed`
## and `snapshot` log entries plus finished state only: no RNG, no decisions.
##
## - breath_dealt: a Breathstealer was dealt.
## - breath_days_alive: days (1..last) it was alive at the start of the day.
## - breath_days: days it stole someone's breath (`breath`); breath_failed: poisoned tries.
## - breath_silenced / breath_suppressed: meetings where the silence held, or the Sexton's
##   bell lifted it.
## - breath_rank_after: for each silencing that held, the Breathstealer's rank (1 = most
##   suspected) among the living by the good townsfolk's mean suspicion, at the first snapshot
##   after it (the meeting's end); breath_rank_living: how many were living then.
extends RefCounted

static func build(w) -> Dictionary:
	var out := {"breath_dealt": false, "breath_days_alive": 0, "breath_days": 0, "breath_failed": 0,
		"breath_silenced": 0, "breath_suppressed": 0, "breath_rank_after": [], "breath_rank_living": []}
	var bs = null
	for n in w.npcs:
		if n.role == "breathstealer" and n.id in w.initial_minion_ids:
			bs = n
	if bs == null:
		return out
	out["breath_dealt"] = true
	var last_day: int = w.day if bs.alive or bs.death_day < 0 else bs.death_day
	# Alive at the start of day d: died (hanged or killed) on day >= d. A night death on night
	# d-1 shows as death_day d-1 here, so it's excluded from day d.
	for d in range(1, w.day + 1):
		if bs.alive or bs.death_day >= d:
			out["breath_days_alive"] += 1
	var waiting := false
	for e in w.dlog.entries:
		match str(e["type"]):
			"breath":
				if str(e.get("actor", "")) == bs.id:
					out["breath_days"] += 1
			"breath_failed":
				if str(e.get("actor", "")) == bs.id:
					out["breath_failed"] += 1
			"silence_suppressed":
				out["breath_suppressed"] += 1
			"silenced":
				out["breath_silenced"] += 1
				waiting = true
			"snapshot":
				if waiting:
					waiting = false
					var npcs: Dictionary = e.get("data", {}).get("npcs", {})
					if npcs.has(bs.id):
						var rank := _rank(w, npcs, bs.id)
						out["breath_rank_after"].append(rank[0])
						out["breath_rank_living"].append(rank[1])
	return out

## [rank of `who`, living count]: mean suspicion of each living person over the living good
## minds in the snapshot (evil minds' entries are their real views, so they're left out).
static func _rank(w, npcs: Dictionary, who: String) -> Array:
	var sums := {}
	var counts := {}
	for mind in npcs:
		if mind in w.initial_evil_ids:
			continue
		var sus: Dictionary = npcs[mind].get("suspicion", {})
		for p in sus:
			sums[p] = float(sums.get(p, 0.0)) + float(sus[p])
			counts[p] = int(counts.get(p, 0)) + 1
	var mine: float = float(sums.get(who, 0.0)) / maxf(1.0, float(counts.get(who, 0)))
	var rank := 1
	for p in sums:
		if p != who and float(sums[p]) / maxf(1.0, float(counts[p])) > mine:
			rank += 1
	return [rank, npcs.size()]

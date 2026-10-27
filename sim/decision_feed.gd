## Read-only, bounded developer observations. No world, NPC or RNG is retained.
extends RefCounted

const LIMIT = 1000
signal changed
var enabled = false
var console = false
var console_shadow = false
var records: Array = []
var version = 0
var next_sequence = 0
var action_id = 0
var trigger = ""
var resolve_actor: Callable

func clear() -> void:
	records.clear()
	version += 1
	changed.emit()

func begin_action(label: String, context: Dictionary) -> void:
	if not enabled: return
	action_id += 1
	trigger = str(context.get("cmd", label))

func observe(actor: String, kind: String, stage: String, result, details: Dictionary, target: String, source: String, day: int, phase: String) -> void:
	if not enabled or stage == "start": return
	if stage == "outcome" and not details.has("final_tier") and kind not in ["vote", "gossip_share", "nomination"]: return
	var who: Dictionary = resolve_actor.call(actor, source) if resolve_actor.is_valid() else {"name": actor, "stats": {}}
	var stats: Dictionary = details.get("inputs", {}).duplicate(true)
	var context: Dictionary = who.get("stats", {})
	var parts: Dictionary = details.get("parts", {}).duplicate()
	parts.merge(details.get("threshold_parts", {}))
	if stats.is_empty():
		for key in context:
			if parts.keys().any(func(part): return str(part).contains(key)) or details.has(key) or (key == "privacy" and parts.has("openness")) or (key == "composure" and parts.has("pressure")):
				stats[key] = context[key]
	for key in ["trust", "pressure", "composure", "paranoia", "confidence", "insight", "gossip"]:
		if details.has(key): stats[key] = details[key]
	var event = {"seq": next_sequence + 1, "action_id": action_id, "trigger": trigger,
		"actor": actor, "name": who.get("name", actor), "target": target, "stream": source,
		"day": day, "phase": phase, "kind": kind, "stage": stage, "result": result.duplicate(true) if result is Dictionary or result is Array else result,
		"stats": stats, "details": details.duplicate(true)}
	next_sequence += 1
	event["estimate"] = estimate(details, result)
	records.append(event)
	if records.size() > LIMIT: records.pop_front()
	version += 1
	if console and (source != "shadow" or console_shadow): print(format_record(event))
	changed.emit()

## Local probabilities, conditional on earlier gates. No sampling or replay.
static func estimate(d: Dictionary, result) -> Dictionary:
	if d.has("probability") or d.has("p"):
		return {"type": "probability", "chance": clampf(float(d.get("probability", d.get("p", 0.0))), 0.0, 1.0), "label": "Nominal chance across daily samples; fixed for this NPC/day, not a fresh RNG roll" if str(d.get("mechanism", "")).begins_with("fixed daily") else "Chance of this check passing (conditional on earlier gates)"}
	if d.has("openness") and d.has("thresholds"):
		var jitter: float = d.get("parts", {}).get("jitter", 0.0)
		var base: float = d.openness - jitter
		var lo: float = d.get("jitter_min", -0.2)
		var hi: float = d.get("jitter_max", 0.2)
		var cdf = func(cut): return clampf((float(cut) - base - lo) / (hi - lo), 0.0, 1.0)
		var cuts = {}
		for band in d.thresholds:
			if band.has("above"): cuts[int(band.tier)] = cdf.call(band.above)
		if not (cuts.has(2) and cuts.has(3) and cuts.has(4)): return {"type": "gate", "label": "Tier probability unavailable for this threshold layout"}
		var a: float = cuts[2]
		var b: float = cuts[3]
		var c: float = cuts[4]
		return {"type": "tiers", "chances": [a, b - a, c - b, 1.0 - c], "gift_or_more": 1.0 - b, "label": "Approximate tier chances before forced/prior/public floors; uniform jitter"}
	if d.has("weights") and d.has("selected"):
		var total = 0.0
		for value in d.weights.values(): total += maxf(float(value), 0.0)
		return {"type": "choice", "chance": maxf(float(d.weights.get(str(d.selected), 0.0)), 0.0) / total if total > 0.0 else 0.0, "label": "Chance of selecting this option"}
	if d.has("noise_min") and d.has("noise_max") and d.has("score") and d.has("threshold"):
		var base: float = d.score - d.get("noise", 0.0)
		var chance = clampf((base + float(d.noise_max) - float(d.threshold)) / (float(d.noise_max) - float(d.noise_min)), 0.0, 1.0)
		return {"type": "probability", "chance": chance, "label": "Approximate chance before this uniform jitter, conditional on the other observed inputs/scores"}
	return {"type": "deterministic" if d.has("score") and d.has("threshold") else "gate", "label": "No random draw; current inputs determine this result"}

static func chance_text(event: Dictionary) -> String:
	var e: Dictionary = event.estimate
	if e.type == "tiers": return "Gift+: %.1f%%" % (100.0 * e.gift_or_more)
	if e.has("chance"): return "~%.1f%%" % (100.0 * e.chance)
	return "N/A (no roll)"

static func format_record(e: Dictionary) -> String:
	var d: Dictionary = e.details
	var mode = "GOOD-SELF / " if e.stream == "shadow" else ""
	var lines = ["[D%d %s | %s%s | %s] %s / %s -> %s" % [e.day, e.phase, mode, e.name, e.trigger, e.kind.replace("_", " "), e.stage, str(e.result)],
		"Inputs: " + (JSON.stringify(e.stats) if not e.stats.is_empty() else "none (fixed chance or context gate)"),
		"Success estimate: %s; %s" % [chance_text(e), e.estimate.label]]
	if e.estimate.type == "tiers":
		var p: Array = e.estimate.chances
		lines.append("Tier chances: refuse %.1f%%; hint %.1f%%; gift %.1f%%; readings %.1f%%" % [100*p[0], 100*p[1], 100*p[2], 100*p[3]])
	if d.has("draw"):
		if d.has("weights"):
			lines.append("Actual sample: %s; selection uses indices/cumulative weights below, not a pass/fail cutoff." % str(d.draw))
		elif d.has("noise"):
			lines.append("Actual random sample: %.9f; score contribution after scaling/rounding: %.9f" % [d.draw, d.noise])
		else:
			lines.append("Actual draw: %.9f; requires draw %s %s" % [d.draw, d.get("comparison", "<"), str(d.get("threshold", d.get("probability", d.get("p", "see thresholds"))))])
	if d.get("parts", {}).has("jitter"):
		lines.append("Actual jitter: %.9f in [%s, %s]; resulting openness: %.9f" % [d.parts.jitter, str(d.get("jitter_min", -0.2)), str(d.get("jitter_max", 0.2)), d.openness])
	if d.has("score"): lines.append("Score: %s %s %s" % [str(d.score), d.get("comparison", ">="), str(d.get("threshold", "see details"))])
	if d.has("gate"): lines.append("Gate: " + str(d.gate))
	if e.target != "": lines.append("Target: " + e.target)
	lines.append("Calculation / thresholds: " + JSON.stringify(d))
	return "\n".join(PackedStringArray(lines))

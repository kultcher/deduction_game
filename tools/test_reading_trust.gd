## Trust from readings that confirm what I know or strongly believe (BACKLOG, Michael, Nov 19,
## set R3), in played games:
## - good listeners gain trust in a teller whose reading confirms what they know or believe, by
##   the tier's size, once for each reading;
## - the record of confirmations (for "their readings agree with what I know") is kept;
## - an evil NPC's own trust never moves for it; its good self keeps a record;
## - a listener's own reading confirms nothing for it.
extends SceneTree
const Game = preload("res://game/game.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var size: Dictionary = {"small": Tuning.Trust.READING_TRUST_SMALL, "moderate": Tuning.Trust.READING_TRUST_MODERATE, "known": Tuning.Trust.READING_TRUST_KNOWN}
	var gains: int = 0
	var dup: int = 0
	var evil_gain: int = 0
	var own: int = 0
	var wrong_size: int = 0
	var records_ok: bool = true
	var shadow_records: int = 0
	var tiers: Dictionary = {}
	for seed_v in [9901, 9902]:
		var g = Game.new()
		g.detailed_logging = true
		g.new_case(seed_v, 10)
		var guard := 0
		while g.state != "over" and g.w.day < 3 and guard < 400:
			guard += 1
			match g.state:
				"approach": g.command("decline")
				"day": g.command("wait")
				"meeting": g.command("done" if g.town_quiet else "wait")
				"talk": g.command("bye")
				"nomination": g.command("vote no")
				"night": g.command("sleep")
				_: break
		var seen: Dictionary = {}
		for e in g.w.dlog.entries:
			if str(e.get("type", "")) != "npc_trust":
				continue
			var d: Dictionary = e.get("data", {})
			var a: String = str(e.get("actor", ""))
			var t: String = str(e.get("target", ""))
			if not d.has("confirmation"):
				continue
			gains += 1
			var tier: String = str(d.confirmation)
			tiers[tier] = int(tiers.get(tier, 0)) + 1
			var k: String = a + "|" + str(d.get("card", ""))
			if seen.has(k):
				dup += 1
			seen[k] = true
			if g.w.by_id.has(a) and g.w.by_id[a].is_evil():
				evil_gain += 1
			if a == t:
				own += 1
			if absf(float(d.get("step", -1.0)) - float(size.get(tier, -2.0))) > 1e-6:
				wrong_size += 1
		for n in g.w.npcs:
			for src in n.workshop_state.get("confirmed_readings", {}):
				var rec: Dictionary = n.workshop_state.confirmed_readings[src]
				if not (str(rec.get("tier", "")) in ["small", "moderate", "known"]) or src == n.id:
					records_ok = false
			if n.is_evil() and n.shadow != null and not n.shadow.workshop_state.get("confirmed_readings", {}).is_empty():
				shadow_records += 1
	print("  confirmations by tier: %s" % str(tiers))
	_check(gains > 0, "readings that confirm what a listener knows or believes raise its trust in the teller (%d)" % gains)
	_check(dup == 0, "each reading counts once for each listener")
	_check(wrong_size == 0, "by the tier's size (small %.2f, moderate %.2f, known %.2f)" % [size.small, size.moderate, size.known])
	_check(evil_gain == 0, "an evil NPC's own trust never moves for it")
	_check(own == 0, "a listener's own reading confirms nothing for it")
	_check(records_ok, "the record of confirmations names a teller and a tier")
	_check(shadow_records > 0, "an evil NPC's good self keeps a record (%d)" % shadow_records)
	print("Reading trust: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

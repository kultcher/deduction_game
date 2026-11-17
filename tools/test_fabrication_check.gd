## Evil fabrications check what's already public (BACKLOG [decided], playtest 26532).
## Rebuilds 26532's shape: a good Archivist ("Lian"), killed by the Demon, publicly read
## "Greta or <liar> is the <liar's role>"; the liar, bluffing Magistrate, would report
## "Greta and Lian shared an alignment", which clears Greta and leaves the liar.
extends SceneTree
const Game = preload("res://game/game.gd")
const FabricationCheck = preload("res://sim/fabrication_check.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_the_26532_shape()
	_harmless_fabrication_passes()
	_notice_follows_insight()
	_switch_off()
	print("Fabrication check: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## A 10-NPC game at day 2 with Lian's public Archivist reading and his Demon death.
func _setup(seed_v: int = 4242) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 10)
	var w = g.w
	w.day = 2
	var liar = w.minion()
	var goods: Array = w.living_good()
	var lian = goods[0]
	var greta = goods[1]
	for p in w.npcs:
		p.info_log = []
	lian.role = "archivist"
	lian.info_log.append({"role": "archivist", "day": 0, "data": {"pair": [greta.id, liar.id], "role": liar.role}, "shared": true, "true": true})
	lian.alive = false
	w.public_event("demon_death", [lian.id], "town")
	return {"g": g, "w": w, "liar": liar, "lian": lian, "greta": greta, "goods": goods}

func _magistrate(a: String, b: String, same: bool) -> Dictionary:
	return {"role": "magistrate", "day": 2, "data": {"nominator": a, "nominee": b, "same": same}, "text": "probe", "fake": true}

func _the_26532_shape() -> void:
	var s: Dictionary = _setup()
	var a: Dictionary = FabricationCheck.assess(s.w, s.liar, _magistrate(s.greta.id, s.lian.id, true))
	print("  26532 shape: lift %s on %s (before %s, after %s)" % [str(a.get("lift")), str(a.get("who")), str(a.get("before", {}).get(s.liar.id)), str(a.get("after", {}).get(s.liar.id))])
	_check(not a.is_empty(), "the 26532 fabrication can be judged")
	_check(float(a.get("lift", 0.0)) > Tuning.Evil.FABRICATION_CHECK_MARGIN and a.get("who", "") == s.liar.id,
		"Greta-and-Lian-same lifts the liar past the margin (%s)" % str(a))

func _harmless_fabrication_passes() -> void:
	var s: Dictionary = _setup()
	var x = s.goods[2]
	var y = s.goods[3]
	var a: Dictionary = FabricationCheck.assess(s.w, s.liar, _magistrate(x.id, y.id, true))
	print("  harmless: lift %s" % str(a.get("lift")))
	_check(float(a.get("lift", 1.0)) <= Tuning.Evil.FABRICATION_CHECK_MARGIN, "two unrelated good people 'same' doesn't incriminate (%s)" % str(a.get("lift")))
	var r: Dictionary = FabricationCheck.vet(s.w, s.liar, _magistrate(x.id, y.id, true), func(): return {})
	_check(r.outcome == "ok", "a harmless fabrication is told as is")

## A sharp liar mostly notices; a careless one mostly slips. Noticed with nothing safer to
## say, it holds the reading back.
func _notice_follows_insight() -> void:
	var counts: Dictionary = {}
	for insight in [0.0, 1.0]:
		var c: Dictionary = {"slipped": 0, "held": 0, "reworked": 0, "ok": 0}
		for sd in range(1, 41):
			var s: Dictionary = _setup()
			s.liar.traits["insight"] = insight
			s.w.rng.seed = sd
			var r: Dictionary = FabricationCheck.vet(s.w, s.liar, _magistrate(s.greta.id, s.lian.id, true), func(): return {})
			c[r.outcome] += 1
		counts[insight] = c
	print("  insight 0: %s; insight 1: %s" % [str(counts[0.0]), str(counts[1.0])])
	_check(counts[0.0].reworked == 0 and counts[1.0].reworked == 0, "no rework offered, so none happens")
	_check(counts[0.0].slipped > counts[1.0].slipped, "the careless slip more often than the sharp")
	_check(counts[0.0].slipped > 0, "a careless liar still slips sometimes")
	_check(counts[1.0].held > counts[1.0].slipped, "a sharp liar mostly holds it back")
	# A safe alternative is taken.
	var s2: Dictionary = _setup()
	s2.liar.traits["insight"] = 1.0
	var reworked: int = 0
	for sd in range(1, 21):
		s2.w.rng.seed = sd
		var alt: Dictionary = _magistrate(s2.goods[2].id, s2.goods[3].id, true)
		var r2: Dictionary = FabricationCheck.vet(s2.w, s2.liar, _magistrate(s2.greta.id, s2.lian.id, true), func(): return alt.duplicate(true))
		if r2.outcome == "reworked":
			reworked += 1
			_check(r2.entry.data.nominator == s2.goods[2].id, "the reworked reading is the safe one")
	_check(reworked > 0, "noticed with a safe alternative, it reworks")

func _switch_off() -> void:
	var s: Dictionary = _setup()
	FabricationCheck.enabled = false
	var r: Dictionary = FabricationCheck.vet(s.w, s.liar, _magistrate(s.greta.id, s.lian.id, true), func(): return {})
	FabricationCheck.enabled = true
	_check(r.outcome == "ok", "with the check off, everything is told as is")

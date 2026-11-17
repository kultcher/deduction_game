## Evil fabrications check what's already public (BACKLOG [decided], playtest 26532).
## Rebuilds 26532's shape: a good Archivist ("Lian"), killed by the Demon, publicly read
## "Greta or <liar> is the <liar's role>"; the liar, bluffing Magistrate, would report
## "Greta and Lian shared an alignment", which clears Greta and leaves the liar.
extends SceneTree
const Game = preload("res://game/game.gd")
const FabricationCheck = preload("res://sim/fabrication_check.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const FixtureSeeds = preload("res://tools/fixture_seeds.gd")

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
	_better_lie()
	_held_day_reading_keeps_phase()
	_rework_can_ask_again()
	_impossible_record_doesnt_block()
	_reworked_reason_keeps_motive()
	_reveal_lists_what_was_told()
	_motives_use_names()
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
	var r: Dictionary = FabricationCheck.vet(s.w, s.liar, _magistrate(x.id, y.id, true), func(): return [])
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
			var r: Dictionary = FabricationCheck.vet(s.w, s.liar, _magistrate(s.greta.id, s.lian.id, true), func(): return [])
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
		var r2: Dictionary = FabricationCheck.vet(s2.w, s2.liar, _magistrate(s2.greta.id, s2.lian.id, true), func(): return [{"entry": alt.duplicate(true), "why": "test alternative"}])
		if r2.outcome == "reworked":
			reworked += 1
			_check(r2.entry.data.nominator == s2.goods[2].id, "the reworked reading is the safe one")
	_check(reworked > 0, "noticed with a safe alternative, it reworks")

func _switch_off() -> void:
	var s: Dictionary = _setup()
	FabricationCheck.enabled = false
	var r: Dictionary = FabricationCheck.vet(s.w, s.liar, _magistrate(s.greta.id, s.lian.id, true), func(): return [])
	FabricationCheck.enabled = true
	_check(r.outcome == "ok", "with the check off, everything is told as is")

## A noticed reading becomes a better lie from the role's own alternatives: the 26532
## Magistrate "same" is swapped for "different", which points at nobody on the team
## (Michael, Nov 17). Every role's alternatives carry text that matches their data.
func _better_lie() -> void:
	var s: Dictionary = _setup()
	s.liar.traits["insight"] = 1.0
	var mag = C.role_def("magistrate")
	var first: Dictionary = _magistrate(s.greta.id, s.lian.id, true)
	var reworked: int = 0
	for sd in range(1, 21):
		s.w.rng.seed = sd
		var r: Dictionary = FabricationCheck.vet(s.w, s.liar, first.duplicate(true), func():
			return mag.bluff_alternatives(s.w, s.liar, s.w.evil_plan, "", null, first).map(func(a): return {"entry": a.entry.merged({"role": "magistrate", "day": 2}, true), "why": a.why}), "")
		if r.outcome == "reworked":
			reworked += 1
			_check(r.entry.data.same == false and "did not share" in r.entry.text, "the better lie is 'did not share', worded to match (%s)" % r.entry.text)
	print("  26532 better lie: reworked %d of 20 (insight 1)" % reworked)
	_check(reworked > 0, "a sharp liar finds the better lie")

func _rework_can_ask_again() -> void:
	# Every role with alternatives words them to match their data, and none names the teller.
	var s: Dictionary = _setup()
	var w = s.w
	var n = s.liar
	var goods: Array = s.goods
	var samples: Dictionary = {
		"seer": {"pair": [goods[2].id, w.demon().id], "yes": true},
		"dowser": {"group": [goods[2].id, goods[3].id, w.demon().id], "count": 1, "block": goods[2].home_block},
		"archivist": {"pair": [goods[2].id, w.demon().id], "role": "poisoner"},
		"clerk": {"pair": [goods[2].id, w.demon().id], "role": "seer"},
		"executor": {"target": w.demon().id, "assigned": true},
		"martyr": {"target": w.demon().id, "chosen": true},
		"surveyor": {"block": goods[2].home_block, "same": false},
		"lamplighter": {"count": 2},
	}
	for role in samples:
		var alts: Array = C.role_def(role).bluff_alternatives(w, n, w.evil_plan, "", null, {"role": role, "data": samples[role]})
		_check(not alts.is_empty(), "%s offers alternatives" % role)
		for a in alts:
			var d: Dictionary = a.entry.data
			_check(str(a.entry.get("text", "")) != "" and not (n.id in d.get("pair", [])) and str(d.get("target", "")) != n.id, "%s alternative is worded and never names the teller (%s)" % [role, a.entry.text])

## A held day reading (a Dowser's) reworked on the night pass keeps its day and phase, so
## its alternatives are judged as the same daytime observation (Codex P2 on #193).
func _held_day_reading_keeps_phase() -> void:
	var s: Dictionary = _setup()
	var w = s.w
	w.phase = C.NIGHT
	var Evil = load("res://sim/evil.gd")
	var held: Dictionary = {"role": "dowser", "day": 1, "phase": 1, "data": {"group": [s.goods[2].id, s.goods[3].id], "count": 1, "block": s.goods[2].home_block}, "text": "probe"}
	var alts: Array = Evil._alternatives(w, s.liar, C.role_def("dowser"), w.evil_plan, s.liar, held, true).call()
	_check(not alts.is_empty(), "a held Dowser reading has alternatives")
	for a in alts:
		_check(int(a.entry.get("day", -1)) == 1 and int(a.entry.get("phase", -1)) == 1, "an alternative keeps day 1, phase 1 (got day %s, phase %s)" % [str(a.entry.get("day")), str(a.entry.get("phase"))])
	var night_e: Dictionary = {"role": "magistrate", "day": 2, "data": {"nominator": s.greta.id, "nominee": s.lian.id, "same": true}, "text": "probe"}
	for a in Evil._alternatives(w, s.liar, C.role_def("magistrate"), w.evil_plan, s.liar, night_e, false).call():
		_check(not a.entry.has("phase"), "a night reading's alternative stays a night reading")

## Steward A1 (Nov 17): a public record that already fits no world says nothing about the
## new lie, so it can't be judged and goes out; only a lie that itself can't stand beside
## the record counts as the largest lift on the teller.
func _impossible_record_doesnt_block() -> void:
	var team: Array = ["e1", "e2"]
	_check(FabricationCheck.lift_of({}, {"e1": 0.9}, team, "e1").is_empty(), "an impossible record before the lie: can't judge")
	_check(FabricationCheck.lift_of({}, {}, team, "e1").is_empty(), "impossible before and after: still can't judge")
	var imp: Dictionary = FabricationCheck.lift_of({"e1": 0.2, "e2": 0.3}, {}, team, "e1")
	_check(imp.get("impossible", false) and float(imp.lift) == 1.0 and imp.who == "e1", "a lie that itself breaks the record is the largest lift on the teller")
	var ok: Dictionary = FabricationCheck.lift_of({"e1": 0.2, "e2": 0.3}, {"e1": 0.25, "e2": 0.6}, team, "e1")
	_check(ok.who == "e2" and is_equal_approx(float(ok.lift), 0.3), "otherwise the biggest rise on the team (%s)" % str(ok))

## Steward A2-A3: a reworked reading keeps the motive it was made for, adds why it changed,
## by name; the alternatives' own reasons (raw ids) don't replace it.
func _reworked_reason_keeps_motive() -> void:
	var s: Dictionary = _setup()
	s.liar.traits["insight"] = 1.0
	var mag = C.role_def("magistrate")
	var first: Dictionary = _magistrate(s.greta.id, s.lian.id, true)
	var got: Dictionary = {}
	for sd in range(1, 21):
		s.w.rng.seed = sd
		var r: Dictionary = FabricationCheck.vet(s.w, s.liar, first.duplicate(true), func():
			return mag.bluff_alternatives(s.w, s.liar, s.w.evil_plan, "", null, first).map(func(a): return {"entry": a.entry.merged({"role": "magistrate", "day": 2}, true), "why": a.why}), "")
		if r.outcome == "reworked":
			got = r
			break
	_check(not got.is_empty(), "a reworked case to look at")
	if got.is_empty():
		return
	var note: String = str(got.get("note", ""))
	_check(s.w.by_id[got.who].name in note and not (got.who in note.replace(s.w.by_id[got.who].name, "")), "the note names who it would have pointed at, by name (%s)" % note)
	_check("so it told this one instead" in note, "the note says why it was changed (%s)" % note)

## Steward A2: the end-of-game reveal lists the fabrications actually told. In played games,
## every `fake_info` entry is one of the liar's readings as it went out (not a version held
## back and later reworked), and none of their reasons carries the alternatives' raw ids.
func _reveal_lists_what_was_told() -> void:
	var listed: int = 0
	var reworked: int = 0
	for seed_v in range(FixtureSeeds.SEEDS_FROM, FixtureSeeds.SEEDS_FROM + 8):
		var g = FixtureSeeds.play_to_meeting(seed_v, 4, 7)
		if g == null:
			continue
		for e in g.w.dlog.entries:
			if e["type"] != "fake_info":
				continue
			listed += 1
			var m = g.w.by_id.get(e["actor"])
			var text: String = str(e["data"].get("text", ""))
			_check(m != null and m.info_log.any(func(x): return str(x.get("text", "")) == text), "seed %d: the reveal's '%s' is a reading %s told" % [seed_v, text, e["actor"]])
			var why: String = str(e["data"].get("why", ""))
			if "told this one instead" in why:
				reworked += 1
			_check(not ("names [" in why or "instead\"" in why), "seed %d: no raw-id reason in the reveal (%s)" % [seed_v, why])
			var re := RegEx.new()
			re.compile("\\b[a-z][a-z0-9_]*\\b")
			var ids_left: Array = re.search_all(why).map(func(m): return m.get_string()).filter(func(t): return g.w.by_id.has(t) and t != g.w.by_id[t].name)
			_check(ids_left.is_empty(), "seed %d: the motive names people, not ids (%s; ids %s)" % [seed_v, why, str(ids_left)])
	print("  reveal: %d fabrications listed, %d of them reworked" % [listed, reworked])
	_check(listed > 0, "some fabrications were told in these games")

## Steward A3: a motive's ids become names, whole words only.
func _motives_use_names() -> void:
	var s: Dictionary = _setup()
	var Evil = load("res://sim/evil.gd")
	var a = s.goods[2]
	var b = s.goods[3]
	var got: String = Evil.named(s.w, "the dead Seer %s 'cleared' the demon %s; names [\"%s\", \"%s\"] instead" % [a.id, b.id, a.id, b.id])
	_check(got == "the dead Seer %s 'cleared' the demon %s; names [\"%s\", \"%s\"] instead" % [a.name, b.name, a.name, b.name], "ids become names (%s)" % got)
	_check(Evil.named(s.w, "the dead Seer reported same=true") == "the dead Seer reported same=true", "other words are left alone")

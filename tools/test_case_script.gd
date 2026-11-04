## Case scripts: the Default script deals what the global lists always did; exclusions,
## forced roles, checks, the builder, and save/load.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")

var checks = 0
var fails = 0


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + msg)


func _deal(seed_in: int, size: int, sc = null) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_in, size, sc)
	var roles = {}
	for n in g.w.npcs:
		roles[n.id] = [n.role, n.secret_mod]
	return {"roles": roles, "bluffs": g.w.bluffs.duplicate(), "w": g.w}


func _init() -> void:
	var d = ScriptDef.default_script()
	var res = d.check()
	_check(d.is_default() and res.errors.is_empty() and res.warnings.is_empty(), "Default script is clean: %s" % [res])
	_check(d.town.size() == 15 and d.minions.size() == 4 and d.secrets.size() == 4 and d.demons == ["demon"], "Default is 15 / 4 / 4 / 1")
	_check(d.mode() == "Beginner", "one demon type is Beginner")

	# Passing the Default script deals exactly what passing none does.
	for sd in [11, 900, 54875]:
		for size in [7, 10]:
			var a = _deal(sd, size)
			var b = _deal(sd, size, ScriptDef.default_script())
			_check(a.roles == b.roles and a.bluffs == b.bluffs, "seed %d/%d: Default script deals the same as no script" % [sd, size])

	# Exclusion: an off-script role is never dealt and never bluffed.
	var no_seer = ScriptDef.default_script()
	no_seer.town.erase("seer")
	no_seer.minions.erase("scion")
	var seen_seer = false
	var seen_scion = false
	for sd in range(300, 330):
		var r = _deal(sd, 10 if sd % 2 == 0 else 7, no_seer)
		for id in r.roles:
			seen_seer = seen_seer or r.roles[id][0] == "seer"
			seen_scion = seen_scion or r.roles[id][0] == "scion"
		seen_seer = seen_seer or "seer" in r.bluffs or "seer" in r.w.evil_plan.get("bluffs", {}).values()
	_check(not seen_seer and not seen_scion, "excluded Seer and Scion are never dealt or bluffed")
	_check(no_seer.check(7).errors.is_empty() and not no_seer.check(7).warnings.is_empty(), "a 14-role script deals but warns")

	# Forced roles are always dealt.
	var forced = ScriptDef.default_script()
	forced.forced = ["sexton", "veteran", "scion", "sleepwalker"]
	var always = true
	for sd in range(500, 520):
		var r = _deal(sd, 7, forced)
		var dealt: Array = r.roles.values().map(func(x): return x[0])
		var mods: Array = r.roles.values().map(func(x): return x[1])
		always = always and "sexton" in dealt and "veteran" in dealt and "scion" in dealt and "sleepwalker" in mods
	_check(always, "forced Sexton, Veteran, Scion and Sleepwalker are always in play")

	# Checks: too few to deal a size is an error for that size only.
	var small = ScriptDef.default_script()
	small.town = small.town.slice(0, 6)
	_check(small.check(7).errors.is_empty() and not small.check(10).errors.is_empty(), "6 town roles deal a 7-person town but not a 10")
	var over = ScriptDef.default_script()
	over.forced = ["poisoner", "scion"]
	_check(not over.check(7).errors.is_empty() and over.check(10).errors.is_empty(), "two forced minions block 7 but not 10")
	over.forced = ["seer", "ghost"]
	_check(not over.check().errors.is_empty(), "forcing a role that isn't on the script is an error")
	var empty = ScriptDef.new()
	_check(empty.check().errors.size() >= 3, "an empty script has errors")

	# Builder: fills to size, respects exclusions and keeps the base; deterministic by seed.
	var built = ScriptBuilder.build({"seed": 7})
	_check(built.ok() and built.town.size() == 15 and built.minions.size() == 4 and built.demons == ["demon"], "a built script is complete and Beginner")
	var trimmed = ScriptDef.default_script()
	trimmed.town.erase("clerk")
	trimmed.town.erase("warden")
	var spare_off: Array = ScriptDef.roster().town.filter(func(r): return r != "clerk" and not r in trimmed.town)
	var refilled_exact = ScriptBuilder.fill(trimmed, ["warden"] + spare_off, 3)
	_check("clerk" in refilled_exact.town and not "warden" in refilled_exact.town and refilled_exact.town.size() == 14, "fill adds back what isn't excluded")
	var refilled = ScriptBuilder.fill(trimmed, ["warden"], 3)
	_check(not "warden" in refilled.town and refilled.town.size() == ScriptDef.TOWN_SIZE, "fill tops script up to TOWN_SIZE from expanded roster")
	_check(ScriptBuilder.build({"seed": 9}).to_dict() == ScriptBuilder.build({"seed": 9}).to_dict(), "building is deterministic by seed")

	# Save and load.
	var path = "user://scripts/test_case_script.json"
	no_seer.name = "No Seer"
	no_seer.forced = ["clerk"]
	_check(no_seer.save(path) == OK, "script saves")
	var back = ScriptDef.load_file(path)
	_check(back != null and back.to_dict() == no_seer.to_dict(), "script loads back unchanged")
	DirAccess.remove_absolute(path)
	_check(ScriptDef.load_file("user://scripts/does_not_exist.json") == null, "missing file loads as null")

	# Tags.
	_check("first_night_info" in ScriptDef.tags_of("clerk") and "role_id" in ScriptDef.tags_of("medium") and not "ongoing_info" in ScriptDef.tags_of("nightwatch"), "role tags")
	_check(not "hearthwitch" in ScriptDef.roster().town, "benched roles stay off the roster")
	_check("augur" in ScriptDef.roster().town and "executor" in ScriptDef.roster().town and "registrar" in ScriptDef.roster().town, "expanded town roles appear on the buildable roster")

	# Dynamic scripts: complete, valid, varied, and the deal's guarantees always have spares.
	var roster: Dictionary = ScriptDef.roster()
	var distinct = {}
	var dyn_ok = true
	var spares_ok = true
	var ideal_ok = true
	var dealt_ok = true
	for sd in range(1, 41):
		var dyn = ScriptBuilder.dynamic({"seed": sd})
		distinct[JSON.stringify(dyn.town)] = true
		var uniq = {}
		for r in dyn.town:
			uniq[r] = true
		dyn_ok = dyn_ok and dyn.ok() and dyn.town.size() == 15 and uniq.size() == 15 and dyn.minions.size() == 4 \
			and dyn.secrets.size() == 4 and dyn.demons == ["demon"] and dyn.town.all(func(r): return r in roster.town)
		for rule in ScriptDef.DRAW_RULES:
			var eligible: int = roster.town.filter(func(r): return r in rule.roles).size()
			spares_ok = spares_ok and dyn.rule_count(rule) >= rule.min + 1
			ideal_ok = ideal_ok and dyn.rule_count(rule) >= mini(rule.min + rule.spare, eligible)
		if sd <= 6:
			var dealt = _deal(sd, 7 if sd % 2 else 10, dyn)
			var in_play: Array = dealt.roles.values().map(func(x): return x[0])
			dealt_ok = dealt_ok and in_play.all(func(r): return dyn.has(r)) and dealt.bluffs.all(func(r): return r in dyn.town)
			for rule in ScriptDef.DRAW_RULES:
				dealt_ok = dealt_ok and in_play.filter(func(r): return r in rule.roles).size() >= rule.min
	_check(dyn_ok, "dynamic scripts are 15 / 4 / 4 / 1, valid, and drawn from the roster")
	var rules_ok = true
	var nw_seen = {}
	var nw_rule: Dictionary = ScriptDef.SCRIPT_RULES.filter(func(r): return r.id == "night_walkers")[0]
	for sd in range(1, 41):
		var dyn = ScriptBuilder.dynamic({"seed": sd})
		rules_ok = rules_ok and dyn.rule_problems().is_empty() and dyn.check().warnings.is_empty()
		nw_seen[dyn.script_rule_value(nw_rule)] = true
	_check(rules_ok, "dynamic scripts keep every script rule and raise no warnings (one Demon-ID gift, two targeted role-ID, two kill protection, 5-7 night-walkers)")
	_check(nw_seen.keys().all(func(n): return n >= 5 and n <= 7) and nw_seen.size() >= 2, "script night-walkers vary around six, counting the Demon (%s)" % [nw_seen.keys()])
	# Deal-level: night-walkers in play, counting the Demon, 2-4 at 7 and 3-5 at 10.
	var band_ok = true
	var dealt_counts = {7: {}, 10: {}}
	for sd in range(600, 640):
		var size: int = 7 if sd % 2 else 10
		var dl = _deal(sd, size, ScriptBuilder.dynamic({"seed": sd}) if sd % 3 else null)
		var nwalk: int = dl.roles.values().filter(func(x): return "night_walker" in ScriptDef.tags_of(x[0])).size() + 1
		dealt_counts[size][nwalk] = true
		band_ok = band_ok and nwalk >= (2 if size == 7 else 3) and nwalk <= (4 if size == 7 else 5)
	_check(band_ok, "dealt night-walkers stay in the band, counting the Demon (7: %s, 10: %s)" % [dealt_counts[7].keys(), dealt_counts[10].keys()])
	var both = ScriptDef.default_script()
	both.town.append("augur")
	_check(both.rule_problems().any(func(w): return w.begins_with("2 Demon ID roles")), "Seer and Augur together break the one-Demon-ID limit")
	# Playtest marks: forced roles are listed and dealt, listed ones listed, favoured ones likelier.
	var marked = ScriptBuilder.dynamic({"seed": 21, "forced": ["magistrate"], "include": ["chronicler"]})
	_check("magistrate" in marked.town and "magistrate" in marked.forced and "chronicler" in marked.town and not "chronicler" in marked.forced, "playtest marks: In play roles are listed and forced; On script roles are listed")
	var with_fav = 0
	var without_fav = 0
	for sd in range(100, 160):
		if "psychologist" in ScriptBuilder.dynamic({"seed": sd, "favoured": ["psychologist"]}).town:
			with_fav += 1
		if "psychologist" in ScriptBuilder.dynamic({"seed": sd}).town:
			without_fav += 1
	_check(with_fav > without_fav, "favoured roles turn up more often (%d vs %d of 60)" % [with_fav, without_fav])
	var dealt_marked = _deal(5, 7, marked)
	_check(dealt_marked.roles.values().any(func(x): return x[0] == "magistrate"), "a forced playtest role is dealt")
	# Placement rules: Lovers and Sleepwalker never on a night-walker; the Rumormonger never holds one alone.
	_check(not ScriptDef.placement_allows("sleepwalker", "warden") and ScriptDef.placement_allows("delusional", "warden")
		and not ScriptDef.placement_allows("marked", "rumormonger") and ScriptDef.placement_allows("lovers", "rumormonger"), "secret placement rules read from the table")
	_check(spares_ok and ideal_ok, "every deal guarantee has spare roles on a dynamic script (all 4 start-knowledge gifts, 3+ identifiers)")
	_check(distinct.size() >= 30, "dynamic scripts vary (%d different town lists in 40)" % distinct.size())
	_check(ScriptBuilder.dynamic({"seed": 5}).to_dict() == ScriptBuilder.dynamic({"seed": 5}).to_dict(), "a dynamic script is reproducible from its seed")
	_check(dealt_ok, "cases dealt from dynamic scripts keep to the script and meet the deal's guarantees")
	var excl = ScriptBuilder.dynamic({"seed": 3, "excluded": ["seer", "augur"]})
	_check(not "seer" in excl.town and not "augur" in excl.town and excl.town.size() == 15, "dynamic scripts respect exclusions")
	var thin = ScriptDef.default_script()
	thin.town.erase("dowser")
	thin.town.erase("gravedigger")
	_check(thin.check().warnings.any(func(w): return w.begins_with("Only 1 strong identifiers")), "a script with exactly the guaranteed number of identifiers warns that it gives them away")

	if fails == 0:
		print("test_case_script: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_case_script: %d/%d FAILED" % [fails, checks])
		quit(1)

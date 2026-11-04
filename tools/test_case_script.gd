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
	var refilled = ScriptBuilder.fill(trimmed, ["warden"], 3)
	_check("clerk" in refilled.town and not "warden" in refilled.town and refilled.town.size() == 14, "fill adds back what isn't excluded")
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

	if fails == 0:
		print("test_case_script: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_case_script: %d/%d FAILED" % [fails, checks])
		quit(1)

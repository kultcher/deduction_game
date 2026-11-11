## Nov 10 NPC behaviour: one work shift each; asking about the dead; the haunt roll's bonus
## when nothing is known; the day-1 ongoing-info penalty.
##   godot --headless --path . --script res://tools/test_npc_behaviour_1110.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Tuning = preload("res://sim/tuning.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var single: bool = true
	for seed in range(500, 520):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(seed, 10)
		for n in g.w.npcs:
			single = single and n.work_phases.size() == 1
	_check(single, "every NPC works one shift (20 cases, 10 NPCs)")
	_check(is_equal_approx(Tuning.Roles.ONGOING_INFO_EARLY_CLAIM, -0.4), "the day-1 ongoing-info penalty is -0.40")

	# Asking about the dead: acknowledged, no opinion; the haunt line in the past tense.
	var told_dead: int = 0
	var acknowledged: int = 0
	var opinion_free: bool = true
	for seed in range(600, 612):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(seed, 7)
		var dead = g.w.npcs[0]
		dead.alive = false
		var asker = g.w.npcs.filter(func(n): return n.alive and n.loc == n.work and n.work != "")
		g.command("go " + g.w.npcs[1].work)
		var n = null
		for m in g.w.npcs:
			if m.alive and m.loc == g.loc:
				n = m
				break
		if n == null:
			continue
		n.traits["gossip"] = 1.0
		n.trust = 1.0
		g.command("talk " + n.name)
		var out: String = g.command("ask about " + dead.name)
		if "gone" in out.to_lower() or "dead" in out.to_lower() or "passed" in out.to_lower() or "bow" in out.to_lower() or "churchyard" in out.to_lower() or "left us" in out.to_lower() or "deceased" in out.to_lower() or "out of the game" in out.to_lower():
			acknowledged += 1
		opinion_free = opinion_free and not ("wickedness" in out or "villain" in out)
		if "used to" in out:
			told_dead += 1
	_check(acknowledged >= 8, "asking about the dead acknowledges the death (%d of 12)" % acknowledged)
	_check(opinion_free, "and gives no opinion of them")
	_check(told_dead >= 4, "a dead person's haunts come in the past tense (%d of 12)" % told_dead)
	# What they saw of the dead lately is still told, framed like the haunts (#97 review).
	var told_seen: int = 0
	var framed: int = 0
	for seed in range(600, 612):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(seed, 7)
		var dead = g.w.npcs[0]
		dead.alive = false
		g.command("go " + g.w.npcs[1].work)
		var n = null
		for m in g.w.npcs:
			if m.alive and m.loc == g.loc:
				n = m
				break
		if n == null or n.is_evil():
			continue
		n.traits["gossip"] = 1.0
		n.trust = 1.0
		n.beliefs.append({"kind": "saw", "who": dead.id, "block": g.w.loc_block("tavern"), "loc": "tavern", "day": g.w.day, "phase": 0, "how": "street"})
		g.command("talk " + n.name)
		var out: String = g.command("ask about " + dead.name)
		if ("saw " + dead.name) in out:
			told_seen += 1
			var lead: String = str(load("res://sim/dialogue_voices.gd").VOICES.get(n.id, {}).get("tell_sighting_dead", "")).split("{subject}")[0].strip_edges()
			if lead != "" and lead.left(12) in out:
				framed += 1
	_check(told_seen >= 4, "asking about the dead still shares a recent sighting of them (%d)" % told_seen)
	_check(framed == told_seen, "framed like the haunts, with the voice's lead line (%d of %d)" % [framed, told_seen])
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)

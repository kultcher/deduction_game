## Graded gossip's value tiers (Social.gossip_tier; a DRAFT awaiting Michael, Nov 20): what the
## tavern tags each item as. The selection doesn't use the tiers yet.
##   godot --headless --path . --script res://tools/test_gossip_tiers.gd
extends SceneTree

const Social = preload("res://sim/social.gd")
const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	check(Social.gossip_tier({"fact": {"kind": "info", "role": "seer"}}) == 1, "an anonymous reading is tier 1")
	check(Social.gossip_tier({"fact": {"kind": "sighting", "phase": C.NIGHT, "block": "docks"}}) == 1, "a night sighting with a block is tier 1")
	check(Social.gossip_tier({"fact": {"kind": "sighting", "phase": C.MORNING, "block": "docks"}}) == 3, "a daytime sighting is tier 3")
	check(Social.gossip_tier({"fact": {"kind": "claim", "role": "seer"}}) == 2 and Social.gossip_tier({"fact": {"kind": "hint"}}) == 2 and Social.gossip_tier({"fact": {"kind": "secret"}}) == 2,
		"a gift claim, a gift-family hint and a secret are tier 2")
	check(Social.gossip_tier({"profile_haunt": {"id": "x", "loc": "well"}}) == 3 and Social.gossip_tier({"profile_bond": {}}) == 3, "haunts and town relationships are tier 3")
	# In a played game, every evening's logged gossip carries a tier per item told and offered.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 10)
	var guard := 0
	while g.state != "meeting" and guard < 400:
		guard += 1
		g.command("decline" if g.state == "approach" else ("bye" if g.state == "talk" else "wait"))
	var before: int = g.w.dlog.entries.size()
	var out: Dictionary = Social.tavern_evening_gossip(g)
	var logged: Array = g.w.dlog.entries.slice(before).filter(func(e): return e["type"] == "tavern_evening_gossip")
	check(not logged.is_empty() and logged[0]["data"].get("tiers", []).size() == int(logged[0]["data"].get("count", -1))
		and logged[0]["data"].get("tiers", []).all(func(t): return int(t) in [1, 2, 3]) and not logged[0]["data"].get("offered_tiers", []).is_empty(),
		"the tavern logs a tier for each item it tells, and for the whole offer")
	print("Gossip tiers: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

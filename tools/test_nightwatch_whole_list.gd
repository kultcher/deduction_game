## A Night Watch list is sound or broken as a whole (BACKLOG "A Night Watch list that wrongly
## names the listener", Michael, Nov 18). The chance it's broken is the watcher's poison and
## Delusional priors that night (SourceDoubt.list_broken_chance); the movement model weighs
## sound against broken by fit (LiveActivity._list_mix), so a list that wrongly names the
## listener is kept and counts against its watcher, and a broken list clears nobody. The void
## rule stays only where neither secret is on the script.
## Built by hand on seed 692's 7-NPC deal (a Poisoner and Delusional on the script), no play.
##   godot --headless --path . --script res://tools/test_nightwatch_whole_list.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


## A town on day 2 where a good watcher's first-night list (or none) reaches a good listener
## who was home that night. `seen`: "listener" names the listener and another good person;
## "other" names only the other; "" gives no list. Returns the listener's chances of the
## watcher and the other being evil, its honest doubt of the watcher's night, and whether the
## list reached the movement model.
func _town(seen: String) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var watchers: Array = goods.filter(func(n): return n.role == "nightwatch")
	var watcher = watchers[0] if not watchers.is_empty() else goods[0]
	if watcher.role != "nightwatch":
		watcher.role = "nightwatch"
		if "nightwatch" not in w.case_script.town:
			w.case_script.town.append("nightwatch")
	var others: Array = goods.filter(func(n): return n != watcher)
	var listener = others[0]
	var other = others[1]
	w.day = 2
	listener.history[w.time_key(1, 3)] = "home:" + listener.home_block
	if seen != "":
		var names: Array = [listener.id, other.id] if seen == "listener" else [other.id]
		var entry: Dictionary = {"day": 1, "phase": 3, "role": "nightwatch", "shared": true, "true": true,
			"data": {"block": listener.home_block, "seen": names},
			"text": "watching %s on the first night, I saw %s out" % [listener.home_block, ", ".join(PackedStringArray(names))]}
		watcher.info_log.append(entry)
		Mind.apply_info(w, listener, watcher, entry, 0.8)
	var key: String = listener.id + ":good"
	g._workshop_evaluations.erase(key)
	w.defer_beliefs = false
	Mind.refresh_beliefs(w, listener, " (test)")
	var plan: Dictionary = g._workshop_plans.get(key, {})
	var eff: Dictionary = g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {})
	var honest: Dictionary = SourceDoubt.derive(plan, listener.ledger, {}).honest if not plan.is_empty() else {}
	var b: float = 0.0
	if not plan.is_empty():
		for c in plan.prepared.view.cards:
			if str(c.get("source", "")) == watcher.id and str(c.get("role", "")) == "nightwatch":
				b = SourceDoubt.list_broken_chance(plan.prepared.view, plan.prepared.listener, c)
	return {"watcher": float(eff.get(watcher.id, {}).get("posterior", -1.0)), "other": float(eff.get(other.id, {}).get("posterior", -1.0)),
		"void": float(honest.get("%s:1" % watcher.id, 0.0)), "b": b, "names": [watcher.name, listener.name, other.name]}


## Three lists from one watcher, on the first three nights (0, 1, 2), each wrongly naming the
## listener, who was home: each night's broken chance and honest doubt.
func _three_lists() -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var watcher = goods[0]
	watcher.role = "nightwatch"
	if "nightwatch" not in w.case_script.town:
		w.case_script.town.append("nightwatch")
	var listener = goods[1]
	w.day = 3
	for nd in range(3):
		listener.history[w.time_key(nd, 3)] = "home:" + listener.home_block
		var entry: Dictionary = {"day": nd, "phase": 3, "role": "nightwatch", "shared": true, "true": true,
			"data": {"block": listener.home_block, "seen": [listener.id]}, "text": "I saw %s out" % listener.name}
		watcher.info_log.append(entry)
		Mind.apply_info(w, listener, watcher, entry, 0.8)
	var key: String = listener.id + ":good"
	g._workshop_evaluations.erase(key)
	w.defer_beliefs = false
	Mind.refresh_beliefs(w, listener, " (test)")
	var plan: Dictionary = g._workshop_plans.get(key, {})
	var honest: Dictionary = SourceDoubt.derive(plan, listener.ledger, {}).honest
	var bs: Array = [0.0, 0.0, 0.0]
	for c in plan.prepared.view.cards:
		if str(c.get("source", "")) == watcher.id and str(c.get("role", "")) == "nightwatch":
			bs[int(c.get("night", -1))] = SourceDoubt.list_broken_chance(plan.prepared.view, plan.prepared.listener, c)
	return {"b": bs, "void": [0, 1, 2].map(func(nd): return float(honest.get("%s:%d" % [watcher.id, nd], 0.0)))}


func _init() -> void:
	var none: Dictionary = _town("")
	var wrong: Dictionary = _town("listener")
	var sound: Dictionary = _town("other")
	SourceDoubt.list_mix_enabled = false
	var old: Dictionary = _town("listener")
	SourceDoubt.list_mix_enabled = true
	print("%s watches, %s hears, %s is the other name; broken chance %.2f" % [wrong.names[0], wrong.names[1], wrong.names[2], wrong.b])
	print("watcher: %.2f with no list, %.2f with a list wrongly naming the listener (%.2f under the old void)" % [none.watcher, wrong.watcher, old.watcher])
	print("other: %.2f with no list, %.2f named on the wrong list, %.2f named on a sound list" % [none.other, wrong.other, sound.other])
	check(wrong.b > 0.0, "with a Poisoner and Delusional on the script, the list carries a broken chance (%.2f)" % wrong.b)
	check(wrong.void < 1.0 and old.void >= 1.0, "the list is kept, not voided (honest doubt %.2f; %.2f with the switch off)" % [wrong.void, old.void])
	check(wrong.watcher > none.watcher, "a list wrongly naming the listener counts against its watcher (%.2f against %.2f with no list)" % [wrong.watcher, none.watcher])
	check(absf(wrong.other - none.other) < absf(sound.other - none.other), "a list wrong about the listener counts less for its other name than a sound list does (%+.2f against %+.2f)" % [wrong.other - none.other, sound.other - none.other])
	# Codex on #273: only the latest SourceDoubt.LIST_MIX_MAX lists are mixed. An older one
	# that wrongly names the listener keeps the old fallback (set aside, its night void),
	# never the name-by-name scoring.
	var three: Dictionary = _three_lists()
	print("three lists: broken chances %s, honest doubt of each night %s" % [three.b, three.void])
	check(three.b[0] == 0.0 and three.void[0] >= 1.0, "a list beyond the mixing cap keeps the old fallback (broken chance %.2f, night void %.2f)" % [three.b[0], three.void[0]])
	check(three.b[1] > 0.0 and three.b[2] > 0.0 and three.void[1] < 1.0 and three.void[2] < 1.0, "the latest two lists are mixed and kept")
	print("Night Watch whole list: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

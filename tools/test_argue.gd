## Unit checks for the contradiction templates and NPC evaluation.
##   godot --headless --path . --script res://tools/test_argue.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Argue = preload("res://sim/argue.gd")
const C = preload("res://sim/content.gd")

var fails = 0

func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4242)
	var w = g.w
	var ids: Array = w.npcs.map(func(n): return n.id)
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]
	var d: String = ids[3]
	g.board = []
	g._card_keys = {}
	var k1 = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 1, "phase": C.NIGHT, "source": b, "text": "B saw A on market n1"})
	var k2 = g.add_card({"kind": "alibi", "subject": [a], "home": true, "day": 1, "phase": C.NIGHT, "source": a, "text": "A home n1"})
	var k3 = g.add_card({"kind": "sighting", "subject": [a], "block": "docks", "day": 1, "phase": C.NIGHT, "source": c, "text": "C saw A on docks n1"})
	var k4 = g.add_card({"kind": "sighting", "subject": [a], "block": "docks", "day": 2, "phase": C.NIGHT, "source": c, "text": "C saw A on docks n2"})
	var k5 = g.add_card({"kind": "claim", "subject": [b], "role": "seer", "source": b, "text": "B claims seer"})
	var k6 = g.add_card({"kind": "claim", "subject": [c], "role": "seer", "source": c, "text": "C claims seer"})
	var k7 = g.add_card({"kind": "info", "subject": [a, d], "source": d, "day": 1, "role": "nightwatch", "data": {"block": "market", "seen": []}, "text": "D watched market n1, nobody"})
	var k8 = g.add_card({"kind": "info", "subject": [a, b], "source": c, "day": 0, "role": "seer", "data": {"pair": [a, b], "yes": true}, "text": "C seer n0 yes A,B"})
	var k9 = g.add_card({"kind": "info", "subject": [a, b], "source": c, "day": 1, "role": "seer", "data": {"pair": [b, a], "yes": false}, "text": "C seer n1 no A,B"})
	var k10 = g.add_card({"kind": "sighting", "subject": [b], "block": "market", "day": 1, "phase": C.NIGHT, "source": "player", "vigil": true, "text": "vigil market n1 saw B"})
	var k11 = g.add_card({"kind": "death", "subject": [a], "block": "hill", "source": "player", "night": 2, "text": "A killed n2"})
	var k12 = g.add_card({"kind": "claim", "subject": [a], "role": "veteran", "source": a, "text": "A claims veteran"})
	var k13 = g.add_card({"kind": "death", "subject": [b], "block": "hill", "source": "player", "night": 2, "text": "B killed n2"})
	_expect(g, [k1, k2], "out_vs_home")
	_expect(g, [k1, k3], "two_places")
	_expect_none(g, [k1, k4], "different nights")
	_expect(g, [k5, k6], "double_claim")
	_expect(g, [k7, k1], "watch_omission")
	_expect(g, [k8, k9], "reading_flip")
	_expect(g, [k10, k1], "vigil_miss")
	_expect(g, [k12, k11], "veteran_died")
	_expect(g, [k8, k11, k13], "reading_vs_dead")
	_expect_none(g, [k5, k1], "")
	# Evaluation: file the flip as "poisoned on night 1" and convince an NPC.
	var lk = g.link_cards([k8, k9])
	var opt = lk["options"][1]
	var dn = g.file_deduction(opt["expl"]["conclusion"], opt["match"]["cards"], opt["match"], opt["expl"]["id"])
	var listener = w.living_good().filter(func(x): return not (x.id in [a, b, c]))[0]
	var r = Argue.evaluate(w, listener, g.board[dn - 1], g.board, 1.0)
	print("evaluate poisoned: agreement %.2f -> %s" % [r["agreement"], r["lines"][0]["text"]])
	var r2 = Argue.evaluate(w, listener, g.board[dn - 1], g.board, 1.0)
	_check(r2["lines"][0]["text"].begins_with("You've told me"), "repeat argument is recognised")
	# Self-knowledge: telling A they were out when they know they weren't.
	var lk2 = g.link_cards([k1, k2])
	var blame_b = 0
	for o in lk2["options"]:
		if o["expl"]["blame"] == b:
			blame_b = lk2["options"].find(o)
	var o2 = lk2["options"][blame_b]
	var dn2 = g.file_deduction(o2["expl"]["conclusion"], o2["match"]["cards"], o2["match"], o2["expl"]["id"])
	var r3 = Argue.evaluate(w, w.by_id[a], g.board[dn2 - 1], g.board, 1.0)
	print("A hears 'B lied about A being out': agreement %.2f (%s)" % [r3["agreement"], "A evil" if w.by_id[a].is_evil() else "A good"])
	# Unfounded conclusion.
	g.link_cards([k5, k1])
	var p = g._parse_conclusion("%s is evil" % w.by_id[b].name)
	var dn3 = g.file_deduction(p["conclusion"], p["supports"])
	_check(dn3 > 0 and g.board[dn3 - 1]["unfounded"], "unlinked conclusion is marked unfounded")
	_check(g.board[dn3 - 1]["class"] != "concrete", "free-form deduction is at most circumstantial")
	# Sentence grammar.
	var p2 = g._parse_conclusion("%s is misled on night 1 because #%d" % [w.by_id[c].name, k9])
	_check(p2.get("conclusion", {}).get("type", "") == "misled" and p2["conclusion"].get("night", -1) == 1 and p2["supports"] == [k9], "parse 'X is misled on night 1 because #N' (%s)" % str(p2))
	var p3 = g._parse_conclusion("%s is not the demon because #%d" % [w.by_id[c].name, k9])
	_check(p3.get("conclusion", {}).get("type", "") == "notdemon", "parse 'is not the demon'")
	var p4 = g._parse_conclusion("%s is the seer because #%d" % [w.by_id[b].name, k5])
	_check(p4.get("conclusion", {}).get("role", "") == "seer", "parse 'is the seer'")
	# Restating someone's own claim is refused; no supports is refused.
	var dn4 = g.file_deduction(p4["conclusion"], [k5])
	_check(dn4 < 0 and "restates" in g.last_error, "self-restating deduction refused (%s)" % g.last_error)
	_check(g.file_deduction({"type": "evil", "a": b}, []) < 0, "deduction with no supports refused")
	# Flimsy but legitimate: someone else's reading pointing at b.
	var dn5 = g.file_deduction({"type": "demon", "a": a}, [k8, k11])
	_check(dn5 > 0, "flimsy outside-sourced deduction allowed (%s)" % g.last_error)
	# Hide / delete.
	g.hide_card(k1, true)
	_check(not (k1 in g.filter_cards("").map(func(x): return x["n"])), "hidden card filtered out")
	g.show_hidden = true
	_check(k1 in g.filter_cards("").map(func(x): return x["n"]), "show hidden includes it")
	g.show_hidden = false
	_check(g.delete_deduction(k1).begins_with("You can only"), "can't delete an info card")
	g.delete_deduction(dn5)
	_check(not (dn5 in g.filter_cards("").map(func(x): return x["n"])), "deleted deduction gone")
	# Timeline and filters.
	print(g._timeline(""))
	_check(g.filter_cards("market").size() >= 3, "location filter by block")
	_check(g.filter_cards("n1").size() >= 3, "night filter")
	print("FAILURES: %d" % fails)
	quit()

func _expect(g, nums: Array, template: String) -> void:
	var res = g.link_cards(nums)["result"]
	var got: Array = res["matches"].map(func(m): return m["template"])
	_check(template in got, "cards %s -> %s (got %s)" % [str(nums), template, str(got)])

func _expect_none(g, nums: Array, near_contains: String) -> void:
	var res = g.link_cards(nums)["result"]
	_check(res["matches"].is_empty(), "cards %s -> no match (got %s)" % [str(nums), str(res["matches"].map(func(m): return m["template"]))])
	if near_contains != "":
		var ok = false
		for r in res["near"]:
			if near_contains in r:
				ok = true
		_check(ok, "near-miss reason mentions '%s' (%s)" % [near_contains, str(res["near"])])

func _check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1

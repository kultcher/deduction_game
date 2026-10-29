## Unit checks for the contradiction templates and NPC evaluation.
##   godot --headless --path . --script res://tools/test_argue.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Argue = preload("res://sim/argue.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")

var fails = 0

func _init() -> void:
	var g = Game.new()
	g.workshop_effects = false # Explicit legacy baseline before testing migration.
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
	# Night sightings on two blocks: only a conflict when no route from home covers both.
	w.by_id[a].home_block = "market"
	_expect_none(g, [k1, k3], "fit together")   # Market -> Docks: leaving home, and arriving
	w.by_id[a].home_block = "hill"
	_expect(g, [k1, k3], "off_route")           # from the Hill, Market and Docks lie on different ways
	var ld = g.add_card({"kind": "sighting", "subject": [a], "block": "docks", "day": 3, "phase": C.NIGHT, "source": a, "duty_claim": "medium", "duty": "medium", "text": "A says out on docks n3 (visiting the dead)"})
	var lh = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 3, "phase": C.NIGHT, "source": b, "text": "B saw A on market n3"})
	var ls = g.add_card({"kind": "sighting", "subject": [a], "block": "square", "day": 3, "phase": C.NIGHT, "source": c, "text": "C saw A on square n3"})
	_expect(g, [ld, lh], "off_route")           # the way Hill -> Docks doesn't touch the Market
	_expect(g, [ld, ls], "off_route")           # every block has its own road: Hill -> Docks skips the Square too
	var lw = g.add_card({"kind": "sighting", "subject": [a], "block": "hill", "day": 3, "phase": C.NIGHT, "source": c, "text": "C saw A on hill n3"})
	_expect_none(g, [ld, lw], "fit together")   # seen leaving home on the way to the Docks
	var ll = g.add_card({"kind": "sighting", "subject": [a], "block": "docks", "day": 4, "phase": C.NIGHT, "source": a, "duty_claim": "lamplighter", "duty": "lamplighter", "text": "A says out on docks n4 (the lamp route)"})
	var lm = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 4, "phase": C.NIGHT, "source": b, "text": "B saw A on market n4"})
	_expect_none(g, [ll, lm], "lamp route")
	var hc = g.add_card({"kind": "home", "subject": [a], "block": "hill", "source": "town", "text": "A lives on the hill"})
	_expect(g, [hc, k1, k3], "off_route")       # citing the home card alongside works too
	var lk_r = g.link_cards([k1, k3])["result"]["matches"]
	_check(not lk_r.is_empty() and lk_r[0]["explanations"].any(func(e): return "lamp route" in e["label"]), "off-route offers the lamp route as an explanation")
	_expect_none(g, [k1, k4], "different nights")
	_builder_checks()
	_expect(g, [k5, k6], "double_claim")
	_expect(g, [k7, k1], "watch_omission")
	_expect(g, [k8, k9], "reading_flip")
	_expect(g, [k10, k1], "vigil_miss")
	# A home-block sighting may be a departure, but a stated destination or
	# Lamplighter duty is covered even when the speaker lives on that block.
	w.by_id[a].home_block = "market"
	var home_vigil = g.add_card({"kind": "vigil", "subject": [], "block": "market", "day": 5, "phase": C.NIGHT, "source": "player", "text": "Market vigil night 5 saw nobody."})
	var departure = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 5, "phase": C.NIGHT, "source": b, "text": "A was seen on Market."})
	var duty = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 5, "phase": C.NIGHT, "source": a, "duty_claim": "medium", "duty": "medium", "text": "A visited Market on duty."})
	var lamp_duty = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 5, "phase": C.NIGHT, "source": a, "duty_claim": "lamplighter", "duty": "lamplighter", "text": "A walked the lamp route."})
	_expect_none(g, [home_vigil, departure], "leaving")
	_expect(g, [home_vigil, duty], "vigil_miss")
	_expect(g, [home_vigil, lamp_duty], "vigil_miss")
	w.by_id[a].home_block = "hill"
	var named_watch = g.add_card({"kind": "info", "subject": [a, d], "source": d, "day": 1, "role": "nightwatch", "data": {"block": "market", "seen": [a]}, "text": "D watched market n1 and saw A."})
	var full_vigil = g.add_card({"kind": "sighting", "subject": [d, b], "block": "market", "day": 1, "phase": C.NIGHT, "source": "player", "vigil": true, "text": "My market vigil n1 saw D and B."})
	var named_matches: Array = g.link_cards([named_watch, full_vigil]).result.matches
	_check(named_matches.any(func(m): return m.template == "watch_omission") and not named_matches.any(func(m): return m.template == "vigil_watcher"), "a named-set mismatch links without falsely missing the watcher")
	var next_watch = g.add_card({"kind": "info", "subject": [a, d], "source": d, "day": 2, "role": "nightwatch", "data": {"block": "market", "seen": [a]}, "text": "D watched market n2 and saw A."})
	_check(not g.link_cards([next_watch, full_vigil]).result.matches.any(func(m): return m.template == "watch_omission"), "different-night watch and vigil reports do not create a same-night omission")
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
	_check(r2.get("repeated", false), "repeat argument is recognised")
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
	# Unfounded = the cards don't bear on the person; it doesn't depend on pressing Link.
	g.link_cards([k6, k3])
	var p = g._parse_conclusion("%s is evil" % w.by_id[d].name)
	var dn3 = g.file_deduction(p["conclusion"], p["supports"])
	_check(dn3 > 0 and g.board[dn3 - 1]["unfounded"], "conclusion from unrelated cards is unfounded")
	g.last_link = {}
	var dn3b = g.file_deduction({"type": "evil", "a": b}, [k5, k1])
	g.link_cards([k5, k1])
	var dn3c = g.file_deduction({"type": "evil", "a": b}, [k5, k1])
	_check(not g.board[dn3b - 1]["unfounded"] and not g.board[dn3c - 1]["unfounded"], "same conclusion, same footing with or without Link")
	# Filing directly finds the template the cards support.
	var dn3d = g.file_deduction({"type": "misled", "a": c, "night": 1}, [k8, k9])
	_check(g.board[dn3d - 1]["template"] == "reading_flip", "direct filing picks up the matching template (%s)" % g.board[dn3d - 1]["template"])
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
	# Red herring: a Seer yes on two people the demon later killed can be honest.
	var rd = g.link_cards([k8, k11, k13])
	var herring = false
	for o in rd["options"]:
		if o["expl"]["kind"] == "herring":
			herring = true
	_check(herring, "reading_vs_dead offers the red-herring explanation")
	# Pair elimination: C's Seer yes on A,B; A killed -> B.
	var pe = g.link_cards([k8, k11])["result"]["matches"].map(func(m): return m["template"])
	_check("pair_elimination" in pe, "pair elimination (got %s)" % str(pe))
	# Corroboration: two witnesses put A on the docks on night 1 (C's card k3, plus D's).
	var kc = g.add_card({"kind": "sighting", "subject": [a], "block": "docks", "day": 1, "phase": C.NIGHT, "source": d, "text": "D saw A on docks n1"})
	var co = g.link_cards([k3, kc])["result"]["matches"].map(func(m): return m["template"])
	_check("corroborated" in co, "corroborated sighting (got %s)" % str(co))
	# Ledger: re-wrapping the same sighting doesn't stack.
	var lis = w.living_good().filter(func(x): return not (x.id in [a, b, c, d]))
	if not lis.is_empty():
		var L = lis[0]
		var s0 = Mind.susp(L, a)
		var da = g.file_deduction({"type": "evil", "a": a}, [k1])
		var db = g.file_deduction({"type": "evil", "a": a}, [k1, k2])
		var dc = g.file_deduction({"type": "evil", "a": a}, [k2, k1])
		Argue.evaluate(w, L, g.board[da - 1], g.board, 1.0)
		var s1 = Mind.susp(L, a)
		Argue.evaluate(w, L, g.board[db - 1], g.board, 1.0)
		Argue.evaluate(w, L, g.board[dc - 1], g.board, 1.0)
		var s3 = Mind.susp(L, a)
		print("repackaging: suspicion %.2f -> %.2f -> %.2f" % [s0, s1, s3])
		_check(s3 - s1 <= 0.5 * maxf(s1 - s0, 0.05), "repackaged argument adds little (%.2f vs first %.2f)" % [s3 - s1, s1 - s0])
		# Doubt before hearing: L is told D is misled on night 1, then hears D's reading.
		var e_d = {"day": 1, "role": "seer", "data": {"pair": [b, c], "yes": true}, "text": "x"}
		var L2 = lis[1] if lis.size() > 1 else L
		var before = Mind.susp(L2, b)
		var dm = g.file_deduction({"type": "misled", "a": d, "night": 1}, [k7])
		var unheard = Argue.evaluate(w, L2, g.board[dm - 1], g.board, 1.0)
		_check(absf(Mind.susp(L2, b) - before) < 0.01, "doubting an unheard reading changes nothing")
		Mind.apply_info(w, L2, w.by_id[d], e_d, 0.5)
		var after = Mind.susp(L2, b)
		print("doubted-then-heard reading moved suspicion of B by %.2f (reliability %.2f)" % [after - before, Mind.reliability(L2, d, 1)])
		_check(Mind.reliability(L2, d, 1) < 1.0, "doubt recorded before hearing the reading")
		# Trust rises: the earlier argument is re-weighed.
		var wt0: float = L.ledger["arg:" + Argue.conclusion_key({"type": "evil", "a": a})]["weight"]
		var tr0: float = L.trust
		Mind.set_trust(w, L, minf(L.trust + 0.3, L.trust_cap), "test")
		var wt1: float = L.ledger["arg:" + Argue.conclusion_key({"type": "evil", "a": a})]["weight"]
		# (Re-weighing skips changes under 0.02, so a very light argument may not visibly move.)
		_check(wt1 > wt0 or L.trust - tr0 < 0.05 or wt0 * (L.trust - tr0) < 0.03, "argument re-weighed after trust rises (%.2f -> %.2f; trust %.2f -> %.2f)" % [wt0, wt1, tr0, L.trust])
	# Evil replies use the shared lines.
	var ev = w.demon()
	var okl = true
	for t in w.npcs:
		if t == ev:
			continue
		var de = g.file_deduction({"type": "good", "a": t.id}, [k1])
		if de < 0:
			continue
		var reply = Argue.evaluate(w, ev, g.board[de - 1], g.board, 1.0)
		var line: String = reply["lines"][0]["text"]
		if not (reply["dialogue"]["stance"] in ["accept", "partial", "reject"] and not line.is_empty()):
			okl = false
			print("odd evil line: ", line)
	_check(okl, "evil argument replies come from the shared set")
	# Executed without ending the case: not the demon, so a Seer pair leaves the other.
	var kx = g.add_card({"kind": "execution", "subject": [a], "source": "player", "text": "A was executed on day 1."})
	var ex = g.link_cards([k8, kx])["result"]["matches"].map(func(m): return m["template"])
	_check("pair_elimination" in ex, "seer pair + execution -> pair elimination (got %s)" % str(ex))
	# Quiet night supports a Warden claim.
	var kq = g.add_card({"kind": "quiet", "subject": [], "night": 1, "day": 1, "phase": C.NIGHT, "source": "player", "ward": "", "text": "Nobody died on night 1."})
	var kw = g.add_card({"kind": "claim", "subject": [d], "role": "warden", "source": d, "text": "D claims warden"})
	var qn = g.link_cards([kq, kw])["result"]["matches"].map(func(m): return m["template"])
	_check("quiet_night" in qn, "quiet night + Warden claim (got %s)" % str(qn))
	# Conversations seen count as being somewhere.
	var kv = g.add_card({"kind": "conversation", "subject": [a, b], "block": "docks", "loc": "wharf", "day": 2, "phase": C.MORNING, "source": "player", "text": "A and B talking at the wharf"})
	var kv2 = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 2, "phase": C.MORNING, "source": c, "text": "C saw A at market d2m"})
	var tp = g.link_cards([kv, kv2])["result"]["matches"].map(func(m): return m["template"])
	_check("two_places" in tp, "conversation card places people (got %s)" % str(tp))
	# Profile lists what readings say about someone.
	_check(not g.named_in(a).is_empty(), "profile shows reading mentions (%s)" % str(g.named_in(a)))
	# Pressing.
	var pz = w.living_good().filter(func(x): return not (x.id in [a, b, c, d]))
	if not pz.is_empty():
		var P = pz[0]
		var r0 = Mind.press(w, P, g.board[k1 - 1])
		_check(r0["lines"][0]["text"].trim_prefix("[PH] ").begins_with("What has that"), "pressing with an unrelated card")
		var ksp = g.add_card({"kind": "sighting", "subject": [P.id], "block": "docks", "day": 1, "phase": C.NIGHT, "source": c, "text": "C saw P on docks n1"})
		var p0 = P.pressure
		var r1 = Mind.press(w, P, g.board[ksp - 1])
		_check(P.pressure > p0 and not r1["lines"].is_empty(), "pressing with a night sighting raises pressure and gets an answer (%s)" % str(r1["lines"]))
		# Misled about yourself: no "it's about me" rejection.
		var dme = g.file_deduction({"type": "unreliable", "a": P.id}, [ksp])
		if dme > 0:
			var rm = Argue.evaluate(w, P, g.board[dme - 1], g.board, 1.0)
			_check("I'm no liar" in rm["lines"][0]["text"], "misled-or-lying about yourself reads as misled (%s)" % rm["lines"][0]["text"])
	# present routing.
	var lis2 = w.living_good().filter(func(x): return not (x.id in [a, b, c, d]))
	if not lis2.is_empty():
		var Q = lis2[0]
		_check(g._route_present(Q, str(k1)).get("verb", "") == "tell", "present a sighting of A -> case against A (%s)" % str(g._route_present(Q, str(k1))))
		var rq = g._route_present(Q, str(k8))
		_check(rq.get("verb", "") == "tell" and "," in rq.get("rest", ""), "present a Seer yes on two -> split case against both (%s)" % str(rq))
		var k9r = g._route_present(Q, str(k9))
		_check(k9r.get("verb", "") == "defend", "present a Seer no -> speaks for them (%s)" % str(k9r))
		var kday = g.add_card({"kind": "sighting", "subject": [a], "block": "market", "day": 1, "phase": C.MORNING, "source": "player", "text": "You saw A at the market, day 1 morning (test)."})
		var fb0 = g.fallback_count
		_check(g._route_present(Q, str(kday)).has("flat") and g.fallback_count == fb0 + 1, "a directionless card falls flat and is counted")
		_check(g._route_present(Q, "%d against %s" % [k8, w.by_id[a].name]).get("verb", "") == "tell", "present ... against <name>")
		_check(g._route_present(Q, "%d for %s" % [k8, w.by_id[a].name]).get("verb", "") == "defend", "present ... for <name>")
		var kq2 = g.add_card({"kind": "info", "subject": [Q.id, a], "source": c, "day": 0, "role": "clerk", "data": {"pair": [Q.id, a], "role": "warden"}, "text": "C clerk: Q or A is warden"})
		_check(g._route_present(Q, str(kq2)).get("verb", "") == "press", "present a card naming them -> press")
		var dq = g.file_deduction({"type": "evil", "a": a}, [k1])
		_check(g._route_present(Q, str(dq)).get("verb", "") == "convince", "present a deduction -> argue it")
	# Something doesn't add up.
	var lkc = g.link_cards([k1, k2])
	_check(lkc["options"][0]["expl"]["kind"] == "conflict", "link offers 'something doesn't add up' first")
	var pc = g._parse_conclusion("one of these is misled or lying because #%d #%d" % [k1, k2])
	_check(pc.get("conclusion", {}).get("type", "") == "conflict" and pc["conclusion"]["group"].size() == 2, "parse 'one of these is misled or lying' (%s)" % str(pc))
	var dcf = g.file_deduction(pc["conclusion"], pc["supports"])
	_check(dcf > 0 and g.board[dcf - 1]["template"] == "out_vs_home", "group conclusion picks up the contradiction (%s)" % (g.board[dcf - 1]["template"] if dcf > 0 else g.last_error))
	var Lc = w.living_good().filter(func(x): return not (x.id in [a, b, c, d]))[0]
	var before_rel = Mind.reliability(Lc, b, 1)
	var rc = Argue.evaluate(w, Lc, g.board[dcf - 1], g.board, 1.0)
	print("conflict: agreement %.2f, line %s" % [rc["agreement"], rc["lines"][0]["text"]])
	_check(rc["agreement"] >= 0.5 and Mind.reliability(Lc, b, 1) < before_rel, "accepting it casts some doubt on those involved")
	var p0b = w.by_id[b].pressure
	g._conflict_pressure(g.board[dcf - 1], 0.2, null)
	_check(w.by_id[b].pressure > p0b, "presenting it raises pressure on those involved")
	_check(g.file_deduction({"type": "conflict", "a": "", "group": [b]}, [k1]) < 0, "a one-person group is refused")
	# Clerk vs both claims.
	var kcl = g.add_card({"kind": "info", "subject": [a, b], "source": d, "day": 0, "role": "clerk", "data": {"pair": [a, b], "role": "warden"}, "text": "D clerk: A or B is warden"})
	var kca = g.add_card({"kind": "claim", "subject": [a], "role": "veteran", "source": a, "text": "A claims veteran (test)"})
	var cvc = g.link_cards([kcl, kca, k5])["result"]["matches"].map(func(m): return m["template"])
	_check("clerk_vs_claims" in cvc, "clerk vs both claims (got %s)" % str(cvc))
	# Association scales with how far the listener believes the base claim.
	var kt1 = g.add_card({"kind": "conversation", "subject": [a, c], "block": "docks", "loc": "wharf", "day": 1, "phase": C.MORNING, "source": "player", "text": "A and C talking d1 (test)"})
	var kt2 = g.add_card({"kind": "conversation", "subject": [a, c], "block": "square", "loc": "tavern", "day": 2, "phase": C.EVENING, "source": "player", "text": "A and C talking d2 (test)"})
	var dev = g.file_deduction({"type": "evil", "a": a}, [k1, k3])
	var asc = g.link_cards([dev, kt1, kt2])
	var assoc_e = {}
	for o in asc["options"]:
		if o["expl"]["kind"] == "associate":
			assoc_e = o["expl"]
	_check(not assoc_e.is_empty() and assoc_e["times"] == 2, "association from a deduction plus two conversations")
	if not assoc_e.is_empty():
		var La = w.living_good().filter(func(x): return not (x.id in [a, b, c, d]) and not x.ledger.has(assoc_e["base_eid"]))
		if La.is_empty():
			La = w.living_good().filter(func(x): return not (x.id in [a, c]) and not x.ledger.has(assoc_e["base_eid"]))
		var L1 = La[0]
		var wt_before = Argue._expl_weight(w, L1, assoc_e)
		Argue.evaluate(w, L1, g.board[dev - 1], g.board, 1.0)
		var wt_after = Argue._expl_weight(w, L1, assoc_e)
		print("association weight %.2f -> %.2f once they accept 'A is evil'" % [wt_before, wt_after])
		_check(wt_after > wt_before, "association grows with belief in the base claim")
	# Vindication + cascade: D (Gravedigger) says A was the Poisoner on night 2.
	var e_gd = {"day": 2, "role": "gravedigger", "data": {"executed": a, "role": "poisoner"}, "text": "A was the Poisoner"}
	var kgd = g.add_card(Mind.info_fact(w, w.by_id[d], e_gd))
	var dmi = g.file_deduction({"type": "misled", "a": d, "night": 2}, [kgd])
	var vin = g.link_cards([dmi, kgd])["result"]["matches"].map(func(m): return m["template"])
	_check("vindication" in vin, "vindication (got %s)" % str(vin))
	var Lv = w.living_good().filter(func(x): return not (x.id in [a, b, c, d]))[-1]
	var e_a = {"day": 1, "role": "seer", "data": {"pair": [b, c], "yes": true}, "text": "A's seer reading"}
	Mind.apply_info(w, Lv, w.by_id[a], e_a, 0.5)
	var rel0 = Mind.reliability(Lv, a, 1)
	Mind.apply_info(w, Lv, w.by_id[d], e_gd, 0.5)
	var rel1 = Mind.reliability(Lv, a, 1)
	Mind.ledger_hear(w, Lv, "test-doubt-d", [[ "disc:%s:2" % d, 0.8, false, "test", ""]], 1.0)
	var rel2 = Mind.reliability(Lv, a, 1)
	print("A's readings: reliability %.2f -> %.2f after D's verdict -> %.2f once D is doubted" % [rel0, rel1, rel2])
	_check(rel1 < rel0 and rel2 > rel1, "doubt cascades: discrediting the Gravedigger restores A's readings")
	# Timeline and filters.
	print(g._timeline(""))
	_check(g.filter_cards("market").size() >= 3, "location filter by block")
	_check(g.filter_cards("n1").size() >= 3, "night filter")
	print("FAILURES: %d" % fails)
	quit()

func _builder_checks() -> void:
	# Labels and stored types swap under "is not": the drop-down passes the type, typed
	# commands pass the label.
	_check(Argue.from_builder("x", "is not", "good", -1, -1, true)["type"] == "good", "builder: 'is not evil' (stored as good) files as good")
	_check(Argue.from_builder("x", "is not", "evil", -1, -1, true)["type"] == "evil", "builder: 'is not good' (stored as evil) files as evil")
	_check(Argue.from_builder("x", "is not", "evil")["type"] == "good", "typed: 'is not evil' files as good")
	_check(Argue.from_builder("x", "is not", "good")["type"] == "evil", "typed: 'is not good' files as evil")
	_check(Argue.from_builder("x", "is", "evil")["type"] == "evil", "typed: 'is evil' files as evil")

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

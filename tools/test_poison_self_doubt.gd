## "Was my reading poisoned?" (Michael, Nov 17, with Quill; Connections._poison_doubt). When
## a listener's own reading clashes with a teller's card, a Poisoner who might have picked
## it that night is one explanation, the teller lying or broken the other, so the listener
## doubts that night of its own a little: more against a trusted teller, less against a
## suspected one, none with no Poisoner on the script. Own readings that can't stand
## together share the doubt. The clash is judged with the listener's readings at full
## strength, so the doubt doesn't switch itself off on the next refresh.
## Constructed on seed 692's 7-NPC deal (the Poisoner is on its script), flat beliefs.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Connections = preload("res://workshop/connections.gd")
const Caches = preload("res://workshop/caches.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")

var checks := 0
var fails := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("PASS: " if ok else "FAIL: ") + label)


## Constance (a Dowser here) read "none of Hollis and Merrin is evil" on day 1. `told`: the
## other cards she hears, [teller, role, day, phase, data].
func _game(own: Array, told: Array, poisoner: bool = true):
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.credibility = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	if not poisoner:
		g.w.case_script.minions = g.w.case_script.minions.filter(func(m): return m != "poisoner")
	var n = g.w.npcs[0]
	n.role = "dowser"
	n.workshop_state["reasoning_mode"] = "full"
	for o in own:
		n.info_log.append({"day": o[0], "phase": 0, "role": "dowser", "data": o[1], "text": "Dowser day %d: %s" % [o[0], JSON.stringify(o[1])]})
	for t in told:
		Mind.apply_info(g.w, n, g.w.by_id[t[0]], {"day": t[2], "phase": t[3], "role": t[1], "data": t[4], "text": "%s %s: %s" % [t[0], t[1], JSON.stringify(t[4])]}, 0.5)
	g.w.day = 3
	return g


## Two refreshes: the chances and the stored doubt after each.
func _run(g) -> Dictionary:
	var n = g.w.npcs[0]
	g.w.defer_beliefs = false
	var out: Dictionary = {}
	for i in [1, 2]:
		g._workshop_evaluations.erase(n.id + ":good")
		Mind.refresh_beliefs(g.w, n, " (test %d)" % i)
		var eff: Dictionary = g._workshop_evaluations[n.id + ":good"].proposal.effects
		var post: Dictionary = {}
		for id in eff:
			post[id] = float(eff[id].get("posterior", -1.0))
		out[i] = {"post": post, "doubt": n.workshop_state.get("connections", {}).get("core", {}).get("poison_doubt", {}).duplicate()}
	out["self_doubt"] = SourceDoubt.self_doubt(n)
	return out


const OWN = [[1, {"group": ["hollis", "merrin"], "count": 0}]]
const CLASH = ["nisha", "seer", 1, 3, {"pair": ["hollis", "merrin"], "yes": true}]
const AGAINST_NISHA = ["odette", "seer", 1, 3, {"pair": ["nisha", "agnes"], "yes": true}]


func _init() -> void:
	Connections.enabled = true
	# 1. A trusted teller's card clashes with the listener's own reading.
	Connections.poison_self_doubt = false
	var off: Dictionary = _run(_game(OWN, [CLASH]))
	Connections.poison_self_doubt = true
	var on: Dictionary = _run(_game(OWN, [CLASH]))
	var d1: float = float(on[2].doubt.get("constance:1", 0.0))
	print("trusted teller: doubt %.3f; Hollis %.3f -> %.3f, Nisha %.3f -> %.3f" % [d1, off[2].post.hollis, on[2].post.hollis, off[2].post.nisha, on[2].post.nisha])
	check(d1 > 0.0 and d1 < 0.5, "a clash with a teller's card makes the listener doubt that night of its own a little (%.3f)" % d1)
	check(on[2].post.hollis > off[2].post.hollis and on[2].post.nisha < off[2].post.nisha, "so its reading clears Hollis less and blames the teller less")
	check(on[2].doubt.keys() == ["constance:1"], "only the clashing night is doubted (%s)" % str(on[2].doubt.keys()))
	check(absf(float(on.self_doubt.get(1, 0.0)) - d1) < 1e-9, "the NPC's own self-doubt signal carries it, for what it says (%s)" % str(on.self_doubt))
	check(absf(float(on[1].doubt.get("constance:1", 0.0)) - d1) < 0.005 and absf(on[1].post.hollis - on[2].post.hollis) < 0.005, "it holds on the next refresh: the doubt doesn't switch its own clash off (%.4f, then %.4f)" % [float(on[1].doubt.get("constance:1", 0.0)), d1])
	# 2. The same clash from a teller the listener already suspects: less doubt.
	var sus: Dictionary = _run(_game(OWN, [CLASH, AGAINST_NISHA]))
	var d2: float = float(sus[2].doubt.get("constance:1", 0.0))
	print("suspected teller: doubt %.3f (Nisha %.3f)" % [d2, sus[2].post.nisha])
	check(d2 < d1, "a teller already suspected explains the clash better, so the listener doubts itself less (%.3f vs %.3f)" % [d2, d1])
	# 3. No Poisoner on the script: no such doubt.
	var none: Dictionary = _run(_game(OWN, [CLASH], false))
	check(none[2].doubt.is_empty(), "with no Poisoner on the script there's no poison self-doubt (%s)" % str(none[2].doubt))
	# 4. No clash: nothing.
	var calm: Dictionary = _run(_game(OWN, [["nisha", "seer", 1, 3, {"pair": ["hollis", "merrin"], "yes": false}]]))
	check(calm[2].doubt.is_empty(), "a teller who agrees raises no doubt (%s)" % str(calm[2].doubt))
	# 5. Two of its own readings that disagree: the judge settles that by fit (own readings
	#    carry the small own-reading error), so no extra doubt from this path.
	var pair: Dictionary = _run(_game(OWN + [[2, {"group": ["hollis", "odette"], "count": 2}]], []))
	print("own against own (disagreeing, not impossible): %s" % str(pair[2].doubt))
	check(pair[2].doubt.is_empty(), "two own readings that merely disagree add no poison doubt: the judge already weighs which is wrong (%s)" % str(pair[2].doubt))
	print("Poison self-doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

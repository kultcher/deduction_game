## "Was my reading poisoned?" (Michael, Nov 17-18, with Quill; SourceDoubt.derive). With a
## Poisoner possible, each of the listener's own readings carries the chance a Poisoner
## picked it that night (ReadingChallenges.poison_chance) as an honest doubt: the prior
## only. The judge does the rest: a reading that fits shrugs it off, one that a trusted
## teller contradicts gives way, less so when the teller is already suspected. None with no
## Poisoner on the script.
## Constructed on seed 692's 7-NPC deal (the Poisoner is on its script), flat beliefs.
extends SceneTree
const Tuning = preload("res://sim/tuning.gd")
const Seeds = preload("res://tools/fixture_seeds.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Connections = preload("res://workshop/connections.gd")
const Caches = preload("res://workshop/caches.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")

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
		out[i] = {"post": post, "doubt": SourceDoubt.self_doubt(n)}
	out["self_doubt"] = SourceDoubt.self_doubt(n)
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	out["pi"] = ReadingChallenges.poison_chance(plan.prepared.view, plan.prepared.listener, 0) if not plan.is_empty() else -1.0
	return out


const OWN = [[1, {"group": ["hollis", "merrin"], "count": 0}]]
const CLASH = ["nisha", "seer", 1, 3, {"pair": ["hollis", "merrin"], "yes": true}]
const AGAINST_NISHA = ["odette", "seer", 1, 3, {"pair": ["nisha", "agnes"], "yes": true}]


func _init() -> void:
	Connections.enabled = true
	# Seed 692's script carries Delusional too; the poison-only checks run without that
	# self-doubt, and section 7 puts the two together.
	SourceDoubt.delusional_self_doubt = false
	# 1. The doubt itself: the poison chance, on the night the Poisoner would have acted (the
	#    night before a day reading), keyed to the reading's own day.
	var on: Dictionary = _run(_game(OWN, [CLASH]))
	var d1: float = float(on[2].doubt.get(1, 0.0))
	print("own reading's doubt %.3f (poison chance for that night %.3f)" % [d1, float(on.pi)])
	check(d1 > 0.0 and absf(d1 - float(on.pi)) < 1e-9, "an own reading carries the poison chance as its doubt (%.3f)" % d1)
	check(on[2].doubt.keys() == [1], "only the night of its own reading is doubted (%s)" % str(on[2].doubt.keys()))
	check(absf(float(on.self_doubt.get(1, 0.0)) - d1) < 1e-9, "the NPC's self-doubt signal carries it, for what it says (%s)" % str(on.self_doubt))
	# 2. Against a trusted teller's clashing card, the reading gives way: it clears Hollis less
	#    and blames the teller less.
	SourceDoubt.poison_self_doubt = false
	var off: Dictionary = _run(_game(OWN, [CLASH]))
	SourceDoubt.poison_self_doubt = true
	print("trusted teller: Hollis %.3f -> %.3f, Nisha %.3f -> %.3f" % [off[2].post.hollis, on[2].post.hollis, off[2].post.nisha, on[2].post.nisha])
	check(on[2].post.hollis > off[2].post.hollis and on[2].post.nisha < off[2].post.nisha, "a clash with a trusted teller's card: the own reading clears Hollis less and blames the teller less")
	var rise_trusted: float = on[2].post.hollis - off[2].post.hollis
	# 3. The same clash from a teller the listener already suspects: the teller explains it,
	#    so the reading gives way less.
	SourceDoubt.poison_self_doubt = false
	var sus_off: Dictionary = _run(_game(OWN, [CLASH, AGAINST_NISHA]))
	SourceDoubt.poison_self_doubt = true
	var sus: Dictionary = _run(_game(OWN, [CLASH, AGAINST_NISHA]))
	var rise_sus: float = sus[2].post.hollis - sus_off[2].post.hollis
	print("suspected teller: Hollis rises %.4f (trusted: %.4f); Nisha %.3f" % [rise_sus, rise_trusted, sus[2].post.nisha])
	check(rise_sus < rise_trusted, "a teller already suspected explains the clash better, so the reading gives way less (%.4f vs %.4f)" % [rise_sus, rise_trusted])
	# 4. A teller who agrees: the reading fits, so the doubt barely shows.
	var agree: Array = [["nisha", "seer", 1, 3, {"pair": ["hollis", "merrin"], "yes": false}]]
	SourceDoubt.poison_self_doubt = false
	var calm_off: Dictionary = _run(_game(OWN, agree))
	SourceDoubt.poison_self_doubt = true
	var calm: Dictionary = _run(_game(OWN, agree))
	var calm_move: float = absf(calm[2].post.hollis - calm_off[2].post.hollis)
	print("agreeing teller: Hollis moves %.4f" % calm_move)
	check(calm_move < rise_trusted, "a reading that fits shrugs the doubt off: it moves Hollis less than the clash does (%.4f vs %.4f)" % [calm_move, rise_trusted])
	# 5. No Poisoner on the script: no such doubt.
	var none: Dictionary = _run(_game(OWN, [CLASH], false))
	check(none[2].doubt.is_empty(), "with no Poisoner on the script there's no poison self-doubt (%s)" % str(none[2].doubt))
	# 6. Stable: the next refresh changes nothing.
	check(absf(on[1].post.hollis - on[2].post.hollis) < 1e-9 and on[1].doubt == on[2].doubt, "a refresh with nothing new changes nothing")
	# 7. With the Delusional self-doubt as well (#216): two independent ways the gift can fail,
	#    1 - (1 - poison)(1 - Delusional), as the Night Watch's broken chance (Michael, Nov 18).
	SourceDoubt.delusional_self_doubt = true
	var both: Dictionary = _run(_game(OWN, [CLASH]))
	var d_both: float = float(both[2].doubt.get(1, 0.0))
	var want: float = 1.0 - (1.0 - float(both.pi)) * (1.0 - Tuning.Workshop.DELUSIONAL_SELF_DOUBT)
	print("with Delusional too: %.4f (want %.4f)" % [d_both, want])
	check(absf(d_both - want) < 1e-9, "poison and Delusional combine as independent chances (%.4f)" % d_both)
	var delus_only: Dictionary = _run(_game(OWN, [CLASH], false))
	check(absf(float(delus_only[2].doubt.get(1, 0.0)) - Tuning.Workshop.DELUSIONAL_SELF_DOUBT) < 1e-9, "with no Poisoner, only the Delusional doubt (%s)" % str(delus_only[2].doubt))
	_medium_case()
	print("Poison self-doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A Medium's own transmissions carry the dead person as source and the Medium as relay
## (LiveAssessment.medium_card): each night it heard them carries the poison chance for that
## night (Codex on #232). The Delusional doubt is off here, so the doubt is the chance alone.
func _medium_case() -> void:
	SourceDoubt.delusional_self_doubt = false
	var found: Dictionary = Seeds.search(3, func(g):
		for n in g.w.living_good():
			if str(n.role) != "medium":
				continue
			var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
			if plan.is_empty() or not ReadingChallenges.poisoner_possible(plan.prepared.view):
				continue
			var mine: Array = plan.prepared.view.cards.filter(func(c): return str(c.get("relay_source", "")) == n.id and not c.get("quoted", false))
			if not mine.is_empty():
				return {"listener": n.id}
		return {})
	check(not found.is_empty(), "found a good Medium holding its own gift results with a Poisoner possible")
	if found.is_empty():
		return
	var g = found.g
	var n = g.w.by_id[found.listener]
	var plan: Dictionary = g._workshop_plans[n.id + ":good"]
	var derived: Dictionary = SourceDoubt.derive(plan, n.ledger, {})
	var ok: bool = true
	var seen: Array = []
	for c in plan.prepared.view.cards:
		if str(c.get("relay_source", "")) != n.id or c.get("quoted", false):
			continue
		var nd: int = int(c.get("relay_observed_at", {}).get("day", -1))
		if nd < 0 or nd in seen:
			continue
		seen.append(nd)
		var pi: float = ReadingChallenges.poison_chance(plan.prepared.view, plan.prepared.listener, nd)
		var got: float = float(derived.honest.get("%s:%d" % [n.id, nd], 0.0))
		ok = ok and got >= pi - 1e-9 and pi > 0.0
	check(ok and not seen.is_empty(), "seed %d: %s (Medium): each night it heard the dead carries that night's poison chance (%s)" % [int(found.seed), n.id, str(seen)])

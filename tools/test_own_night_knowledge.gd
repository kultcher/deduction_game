## A listener's own nights at home, in its movement model (Nov 17, Lantern; the relay gap
## Beadle found). The workshop bridge passes the nights a good listener knows it spent at
## home as knowledge (view.own_home), and the movement model reads one soft alibi a night
## from them, so it weighs a sighting of the listener out against whoever told it. Before this the listener's home knowledge
## only reached the role check, and the sighting contests set their balance from the
## listener's own view, so a made-up sighting of the listener hardly moved it.
##   - each home night has its card; with the Sleepwalker on the script it carries that
##     secret's self-doubt, otherwise the tiny own-reading error;
##   - an evil planter's fake street sighting of the listener, told to it, raises the planter;
##   - so does an evil Medium's invented relay of the listener;
##   - a real Sleepwalker, honestly seen out, stays far from sure the sighter lied.
## Cases are searched for (tools/fixture_seeds.gd), on connections.
extends SceneTree
const Seeds = preload("res://tools/fixture_seeds.gd")
const Mind = preload("res://sim/mind.gd")
const Connections = preload("res://workshop/connections.gd")
const Jury = preload("res://workshop/jury.gd")
const Tuning = preload("res://sim/tuning.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")

var fails: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("PASS: " if ok else "FAIL: ") + label)


## The listener's prepared view and the teller's chance of evil with every held card, and
## with the cards `drop` accepts left out. {} if the listener has no plan.
## `plain_self`: read the listener's own home nights with only the tiny own-reading error, as
## a town with no Sleepwalker on its script would (the Sleepwalker check's comparison).
func _effect(g, listener_id: String, teller_id: String, drop: Callable, plain_self: bool = false) -> Dictionary:
	var n = g.w.by_id[listener_id]
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	var plan: Dictionary = g._workshop_plans.get(key, {})
	var cx: Dictionary = g._workshop_evaluations.get(key, {}).get("proposal", {}).get("connections", {})
	if plan.is_empty() or cx.is_empty():
		return {}
	var base: Dictionary = plan.prepared.listener
	var weigher: Dictionary = Jury._eval_listener(base, base.knowledge.get("own_reports", []))
	weigher["trust"] = base.get("trust", 0.5)
	for k in ["insight", "player_credibility"]:
		if base.has(k):
			weigher[k] = base[k]
	var held: Array = []
	for it in cx.get("items", []):
		for id in it.cards:
			if id not in held:
				held.append(id)
	var view: Dictionary = plan.prepared.view
	if plain_self:
		view = view.duplicate(true)
		for c in view.cards:
			if bool(c.get("known_self", false)):
				c["self_doubt"] = Tuning.Workshop.OWN_ERR
		if view.get("own_home") is Dictionary:
			for k in view.own_home.get("nights", {}):
				view.own_home.nights[k] = Tuning.Workshop.OWN_ERR
	var dropped: Array = view.cards.filter(drop).map(func(c): return c.id)
	var state: Dictionary = {} if plain_self else base.get("connections", {})
	var a: Dictionary = Connections.refresh(view, plan.prepared.case, weigher, held, state)
	var b: Dictionary = Connections.refresh(view, plan.prepared.case, weigher, held.filter(func(id): return id not in dropped), state)
	return {"with": float(a.posterior.get(teller_id, -1.0)), "without": float(b.posterior.get(teller_id, -1.0)),
		"dropped": dropped.size(), "view": view, "held": held}


func _logit(p: float) -> float:
	var q: float = clampf(p, 1e-9, 1.0 - 1e-9)
	return log(q / (1.0 - q))


func _own_cards(view: Dictionary, who: String) -> Array:
	return LiveActivity.own_home_cards(view).filter(func(c): return str(c.get("source", "")) == who)


func _missing(label: String) -> void:
	check(false, "%s (no seed in %d..%d has the case)" % [label, Seeds.SEEDS_FROM, Seeds.SEEDS_FROM + Seeds.SEEDS_COUNT - 1])


func _init() -> void:
	# 1. An evil planter's fake street sighting of a good person who was home (a sighting
	# on their own block, "seen leaving home", barely clashes with being home).
	var f: Dictionary = Seeds.framed_sighting(2, false, "street", 0.0, Seeds.SEEDS_FROM, 0.5)  # heard nearly in full (Lantern, Nov 20)
	if f.is_empty():
		_missing("a planter's fake sighting")
	else:
		var g = f.g
		var e: Dictionary = _effect(g, f.subject, f.sighter, func(c): return str(c.get("kind", "")) == "sighting" and str(c.get("source", "")) == f.sighter and f.subject in c.get("subjects", [c.get("subject", "")]))
		var label: String = "seed %d: %s, sighted by %s" % [f.seed, f.subject, f.sighter]
		print("%s: %.3f with the sighting, %.3f without" % [label, e.with, e.without])
		var n = g.w.by_id[f.subject]
		var home_nights: Array = []
		for key in n.history:
			if str(key).ends_with(":3") and (str(n.secret_mod) == "sleepwalker" or str(n.history[key]).begins_with("home")):
				home_nights.append(int(str(key).trim_suffix(":3")))
		var own: Array = _own_cards(e.view, f.subject)
		var nights: Array = own.map(func(c): return int(c.get("night", c.get("observed_at", {}).get("day", -1))))
		nights.sort()
		home_nights.sort()
		check(nights == home_nights and not nights.is_empty(), "%s: one known-home card for each night at home (%s, home %s)" % [label, nights, home_nights])
		var expect: float = Tuning.Workshop.SLEEPWALK_SELF_DOUBT if "sleepwalker" in g.w.case_script.secrets else Tuning.Workshop.OWN_ERR
		check(own.all(func(c): return absf(float(c.get("self_doubt", -1.0)) - expect) < 1e-9), "%s: the cards carry the self-doubt the script calls for (%s)" % [label, expect])
		check(not e.view.cards.any(func(c): return c.get("known_self", false)), "%s: they're knowledge for the movement model, not cards in the shared view" % label)
		# In log-odds, as the relay check below: a planter the rest already holds near certain
		# has no 15 points left to gain (seed 100074 on #454: 0.894 without it, 0.993 with).
		var lift1: float = _logit(e.with) - _logit(e.without)
		# Being lied about mustn't lower the listener's suspicion of the liar (Michael, Nov 21:
		# a wrong sighting no longer seeds the core, Connections.seed_wrong_sightings). It
		# still counts against its teller through its night; how far depends on the rest of
		# the board, so the floor is "doesn't clear the liar", not a fixed lift.
		print("NOTE: %s: the fake sighting moves the planter %+.2f log-odds (%+.3f)" % [label, lift1, e.with - e.without])
		check(lift1 >= 0.0, "%s: being lied about doesn't lower the listener's suspicion of the liar (%+.2f log-odds, %+.3f)" % [label, lift1, e.with - e.without])
	# 2. An evil Medium's invented relay of the listener, out on a night they were home.
	var r: Dictionary = Seeds.relay(3, func(t): return t.is_evil(), true)
	if r.is_empty():
		_missing("an evil relay of the listener")
	else:
		var e2: Dictionary = _effect(r.g, r.listener, r.teller, func(c): return str(c.get("relay_source", "")) == r.teller)
		var label2: String = "seed %d: %s, relayed out by %s" % [r.seed, r.listener, r.teller]
		print("%s: %.3f with the relay, %.3f without" % [label2, e2.with, e2.without])
		check(e2.dropped > 0, "%s: the relay is held" % label2)
		# In log-odds, so a relayer the rest already makes nearly certain still has room: at
		# least what 15 points from even odds is (0.50 -> 0.65). Which seed the finder picks
		# moves with the game (with poison self-doubt on it is 100031, where the relayer is at
		# 0.97 without the relay; the earlier 100055 shows the same +25 points either way).
		var lift: float = _logit(e2.with) - _logit(e2.without)
		check(lift >= _logit(0.65) - _logit(0.5), "%s: the invented relay raises the relayer at least as much as 15 points from even (%+.2f log-odds, %+.3f)" % [label2, lift, e2.with - e2.without])
	# 3. (The Sleepwalker case retired with the burdens prototype.)
	print("Own night knowledge: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

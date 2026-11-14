## The connections model's kept judgements (workshop/connections.gd, step 6).
##
## - A judgement made before on the same inputs is handed back, not made again.
## - Beliefs are the same with the cache on and off: a whole passive game played both ways
##   leaves the same dev log and the same suspicions, and with `cache_verify` every kept
##   answer equals a fresh one.
## - The key is what a judgement reads: an unrelated card, the meeting's talk or attention's
##   bookkeeping keep an answer; the judged card, a death, trust or a Magistrate reading
##   with new talk make it be judged again.
## - With the switch off nothing is kept.
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Connections = preload("res://workshop/connections.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const Profiler = preload("res://workshop/profiler.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_key()
	_games()
	_off()
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	Connections.cache_enabled = true
	Connections.cache_verify = false
	print("Connections cache: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _reset() -> void:
	LiveActivity.cache.clear()
	Caches.clear_all()
	Connections.cache_stats = {"hits": 0, "misses": 0, "wrong": 0}


## A passive game to `days`, with the model on. Returns what a difference in any belief
## would change: the dev log's records and every NPC's stored suspicion.
func _play(game_seed: int, npcs: int, days: int) -> Dictionary:
	_reset()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(game_seed, npcs)
	var guard: int = 0
	while g.state != "over" and int(g.w.day) <= days and guard < 400:
		# The passive player: waits, declines, votes no, sleeps (tools/autoplay.gd).
		g.command({"approach": "decline", "day": "wait", "talk": "bye", "meeting": "done" if g.town_quiet else "wait", "nomination": "vote no", "night": "sleep"}.get(g.state, "look"))
		guard += 1
	var suspicion: Dictionary = {}
	for n in g.w.npcs:
		suspicion[n.id] = n.suspicion.duplicate()
	var log: Array = g.w.dlog.entries.map(func(e): return [e.type, e.get("actor", ""), e.get("target", ""), e.get("reason", ""), JSON.stringify(e.get("data", {}))])
	return {"suspicion": suspicion, "log": log, "day": int(g.w.day), "stats": Connections.cache_stats.duplicate(), "g": g}


func _games() -> void:
	Connections.enabled = true
	for spec in [[900, 7, 3], [692, 10, 1]]:
		Connections.cache_enabled = false
		Connections.cache_verify = false
		var plain: Dictionary = _play(spec[0], spec[1], spec[2])
		check(plain.stats.hits == 0 and plain.stats.misses == 0, "seed %d: with the cache off nothing is kept" % spec[0])
		Connections.cache_enabled = true
		var kept: Dictionary = _play(spec[0], spec[1], spec[2])
		check(kept.stats.hits > 0, "seed %d: with it on, judgements are handed back (%d kept, %d made)" % [spec[0], kept.stats.hits, kept.stats.misses])
		check(kept.suspicion == plain.suspicion, "seed %d: every NPC's suspicions are the same with the cache on and off" % spec[0])
		check(kept.log.size() == plain.log.size() and kept.log == plain.log, "seed %d: so is the whole dev log (%d records)" % [spec[0], kept.log.size()])
		Connections.cache_verify = true
		var checked: Dictionary = _play(spec[0], spec[1], spec[2])
		check(checked.stats.wrong == 0 and checked.stats.hits == kept.stats.hits, "seed %d: every kept answer equals a fresh one (%d checked)" % [spec[0], checked.stats.hits])
		check(checked.suspicion == plain.suspicion, "seed %d: and checking changes nothing" % spec[0])
		Connections.cache_verify = false
	Connections.enabled = false


## The key, on one listener's real inputs.
func _key() -> void:
	Connections.enabled = true
	Connections.cache_enabled = true
	var played: Dictionary = _play(900, 7, 2)
	var g = played.g
	var n = g.w.living().filter(func(x): return not x.is_evil())[0]
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	check(not plan.is_empty(), "the key fixture has a listener with a plan")
	if plan.is_empty():
		return
	var view: Dictionary = plan.prepared.view.duplicate(true)
	var listener: Dictionary = preload("res://workshop/jury.gd")._eval_listener(plan.prepared.listener, plan.prepared.listener.knowledge.get("own_reports", [])).duplicate(true)
	var others: Array = view.people.map(func(p): return p.id).filter(func(p): return p != n.id)
	var bare: Dictionary = Connections.template(plan.prepared.get("case", {"cards": [], "conclusion": {"type": "evil", "target": others[0]}}), others[0])
	var reports: Array = view.cards.filter(func(c): return c.kind == "report" and c.id not in listener.knowledge.get("own_reports", []))
	check(reports.size() >= 2, "it holds two readings that aren't its own")
	if reports.size() < 2:
		return
	var ids: Array = [reports[0].id]
	var key: String = Connections.judge_key(view, bare, listener, ids, false)
	check(key == Connections.judge_key(view.duplicate(true), bare.duplicate(true), listener.duplicate(true), ids, false), "the same inputs give the same key")
	# What a judgement doesn't read.
	var other_card: Dictionary = view.duplicate(true)
	for c in other_card.cards:
		if c.id == reports[1].id:
			c["hearing_weight"] = 0.123
	check(Connections.judge_key(other_card, bare, listener, ids, false) == key, "another reading heard differently doesn't touch it")
	var talk: Dictionary = view.duplicate(true)
	talk.timeline.events.append({"kind": "accusation", "subjects": [others[0]], "by": others[1], "at": {"day": 2, "phase": "evening"}})
	talk.timeline.events.append({"kind": "nomination", "subjects": [others[0]], "by": others[1], "at": {"day": 2, "phase": "evening"}})
	check(Connections.judge_key(talk, bare, listener, ids, false) == key, "nor does the meeting's talk")
	var attended: Dictionary = listener.duplicate(true)
	attended.knowledge["presented_reports"] = ["x"]
	attended.knowledge["attention_reports"] = ["y"]
	attended.reading_reliability[reports[1].id] = 0.4
	check(Connections.judge_key(view, bare, attended, ids, false) == key, "nor attention's bookkeeping, nor how well another reading is trusted")
	# What it does read.
	var heard: Dictionary = view.duplicate(true)
	for c in heard.cards:
		if c.id == reports[0].id:
			c["hearing_weight"] = 0.123
	check(Connections.judge_key(heard, bare, listener, ids, false) != key, "the judged reading heard differently is a new judgement")
	var doubted: Dictionary = listener.duplicate(true)
	doubted.reading_reliability[reports[0].id] = 0.4
	check(Connections.judge_key(view, bare, doubted, ids, false) != key, "so is a change in how far it is trusted")
	var death: Dictionary = view.duplicate(true)
	death.timeline.events.append({"kind": "demon_death", "subjects": [others[0]], "by": "", "at": {"day": 2, "phase": "night"}})
	check(Connections.judge_key(death, bare, listener, ids, false) != key, "a death is")
	var trust: Dictionary = listener.duplicate(true)
	trust.npc_trust[others[0]] = 0.11
	check(Connections.judge_key(view, bare, trust, ids, false) != key, "a change of trust in someone is")
	var known: Dictionary = listener.duplicate(true)
	known.knowledge["own_outings"] = {"1": true}
	check(Connections.judge_key(view, bare, known, ids, false) != key, "something new the listener knows firsthand is")
	check(Connections.judge_key(view, bare, listener, ids, true) != key and Connections.judge_key(view, bare, listener, [reports[0].id, reports[1].id], false) != key, "the Hexer switch and the set are part of it")
	var fact: Dictionary = view.duplicate(true)
	fact.cards.append({"id": "fact:profile", "kind": "context", "context_kind": "work", "subject": others[0], "source": "player", "text": "works at the docks"})
	check(Connections.judge_key(fact, bare, listener, ids, false) == key, "a card outside the set, of any kind, doesn't touch it")
	var weighed: Dictionary = listener.duplicate(true)
	weighed["player_credibility"] = 0.9
	weighed["trust"] = 0.1
	check(Connections.judge_key(view, bare, weighed, ids, false) == key, "nor does trust in the Demonologist, which only weighs stored cases")
	# A Magistrate's reading is the one gift that reads the meeting's talk.
	var magistrate: Dictionary = view.duplicate(true)
	for c in magistrate.cards:
		if c.id == reports[0].id:
			c["role"] = "magistrate"
	var m_key: String = Connections.judge_key(magistrate, bare, listener, ids, false)
	var m_talk: Dictionary = magistrate.duplicate(true)
	m_talk.timeline.events.append({"kind": "nomination", "subjects": [others[0]], "by": others[1], "at": {"day": 2, "phase": "evening"}})
	check(Connections.judge_key(m_talk, bare, listener, ids, false) != m_key, "a Magistrate's reading is judged again when the meeting's talk changes")
	# Kept, handed back, cleared, and bypassed for a caller that wants the worlds.
	_reset()
	var first: Dictionary = Connections.judge(view, bare, listener, ids)
	var second: Dictionary = Connections.judge(view, bare, listener, ids)
	check(Connections.cache_stats.hits == 1 and Connections.cache_stats.misses == 1 and first == second, "a second judgement on the same inputs is handed back")
	var real: Dictionary = Connections._judge(view, bare, listener, ids)
	check(others.all(func(p): return is_equal_approx(float(real.people[p].posterior), float(second.people[p].posterior)) and is_equal_approx(float(real.people[p].prior), float(second.people[p].prior))),
		"and is what the judge says")
	CaseEval.capture_worlds = true
	CaseEval.captured = []
	Connections.judge(view, bare, listener, ids)
	check(not CaseEval.captured.is_empty() and Connections.cache_stats.hits == 1, "a caller that wants the worlds gets a real judgement")
	CaseEval.capture_worlds = false
	CaseEval.captured = []
	Caches.clear_all()
	check(Connections._kept.is_empty(), "clearing the caches empties it")
	# The profiler counts what was kept.
	Profiler.start()
	g._workshop_evaluations.clear()
	Mind.refresh_beliefs(g.w, n, " (once)")
	g._workshop_evaluations.clear()
	Mind.refresh_beliefs(g.w, n, " (again)")
	var profile: Dictionary = Profiler.finish()
	var kept: int = 0
	for k in profile.counters:
		if str(k).ends_with("|connections_kept"):
			kept += int(profile.counters[k])
	check(kept > 0, "the profiler counts the judgements handed back (%d)" % kept)
	Connections.enabled = false


func _off() -> void:
	Connections.enabled = false
	Connections.cache_enabled = true
	var off: Dictionary = _play(900, 7, 2)
	check(off.stats.hits == 0 and off.stats.misses == 0 and Connections._kept.is_empty(), "with the model off nothing is judged or kept")

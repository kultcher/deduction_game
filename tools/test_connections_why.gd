## The "why they moved" report with the connections belief model on (game/workshop_why.gd,
## `_connections_report`; workshop/connections.gd).
##
## - With the model on, the report is read from the breakdown the applied refresh stored
##   (and the one before it): nothing is re-run, and none of today's stages (attention,
##   change of view, headline) appear.
## - The "after" chance is the refresh's own; the parts shown for a person add up to it.
## - The case's own part and its weight (trust in the presenter, fading, the "suspicious"
##   halving) are the stored case's.
## - With the model off the report is what it always was.
## - A log played with the model on says so in case_start, and the replay tools read it.
## - The profiling hooks (Connections.capture, the profiler's spans) record and change nothing.
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Connections = preload("res://workshop/connections.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const WorkshopWhy = preload("res://game/workshop_why.gd")
const CaseWhy = preload("res://workshop/case_why.gd")
const Profiler = preload("res://workshop/profiler.gd")
const Replay = preload("res://tools/log_replay.gd")

var checks: int = 0
var fails: int = 0
var _texts: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_report()
	_hedged_and_faded()
	_off()
	_log_flag()
	_masks()
	_profiling()
	_pinned_parts()
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	print("Connections why: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## Codex's review of #148: a person proved by the listener's own knowledge has a chance set
## outright (Connections.combine), so the parts get a "settled outright" row that makes them
## add up to it; for anyone else that row is zero.
func _pinned_parts() -> void:
	var Why = preload("res://game/workshop_why.gd")
	var res := {"baseline": {"a": 0.3, "b": 0.3}, "posterior": {"a": 0.003, "b": 0.41}, "shift": 0.2,
		"items": [{"cards": ["x"], "lean": {"a": 1.2, "b": 0.1}}, {"cards": ["y"], "lean": {"a": -0.4, "b": 0.3}}],
		"core": {"lean": {"a": 0.5}, "proved": {"a": 0.003}},
		"cases": {"entries": [{"key": "case:1", "lean": {"a": 0.4, "b": -0.2}}]}}
	for who in ["a", "b"]:
		var parts: Dictionary = Why._parts(res, {}, who, "case:1", ["x"])
		var total: float = 0.0
		var fixed: float = 0.0
		for row in parts.rows:
			total += float(row.after)
			if row.stage == "fixed":
				fixed = float(row.after)
		if who == "a":
			check(parts.pinned != "" and absf(total - Connections.logit(0.003)) < 1e-9 and fixed < -1.0,
				"a proved person's parts add up to the proved chance, through a settled-outright part (%+.2f)" % fixed)
		else:
			check(parts.pinned == "" and is_zero_approx(fixed), "anyone else has no settled-outright part")


# ------------------------------------------------------------ fixtures (as test_connections_cases)

func _game():
	LiveActivity.cache.clear()
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
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.5
	n.traits.confidence = 0.5
	n.workshop_state["reasoning_mode"] = "full"
	g.w.day = 2
	return g


func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	var number: int = g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if role == "seer" else 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})
	_texts[number] = g.board[number - 1].text
	return number


func _node(model, view, number: int) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, "")):
			return id
	return ""


func _file(g, type: String, target: String, support: Array) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	return Live.file(g, model.compile(premise))


func _proposal(g, n) -> Dictionary:
	return g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {})


## A Seer "yes" on p3 and p4 with a Dowser clearing p4, filed as "p3 is <type>" and not yet
## presented. The listener has already been shown the Dowser's reading by itself ("p4 is
## good"), so they hold it and have a refresh to compare with.
func _filed(type: String, on: bool) -> Dictionary:
	Connections.enabled = on
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	var first: int = _file(g, "good", p[4].id, [dowser])
	g._evaluate_deduction(n, g.board[first - 1], 1.0, false, "meeting")
	var filed: int = _file(g, type, p[3].id, [seer, dowser])
	return {"g": g, "n": n, "p": p, "filed": filed, "first": first, "target": p[3].id}


## Everything the report could touch, to show it changes none of it.
func _state(g, n) -> Array:
	return [n.suspicion.duplicate(true), n.workshop_state.duplicate(true), g._workshop_evaluations.duplicate(true).hash(), g.w.rng.state if "rng" in g.w else 0,
		g.w.dlog.entries.size(), Connections.enabled]


# ------------------------------------------------------------ the report, model on

func _report() -> void:
	var s: Dictionary = _filed("evil", true)
	var g = s.g
	var n = s.n
	var t: String = s.target
	check(s.filed > 0, "the case files (%s)" % g.last_error)
	var before_result: Dictionary = _proposal(g, n).get("connections", {})
	check(not before_result.is_empty(), "the listener's refresh before the case stored a breakdown")
	var chance_before: float = float(before_result.get("posterior", {}).get(t, -1.0))
	var stored_before: float = float(n.suspicion[t])
	g.workshop_why = true
	g._evaluate_deduction(n, g.board[s.filed - 1], 1.0, false, "meeting")
	check(g.workshop_whys.size() == 1, "presenting with the record switch on keeps one report")
	if g.workshop_whys.size() != 1:
		return
	var b: Dictionary = g.workshop_whys[0]
	check(b.had_before, "it has the refresh before the case to compare with")
	var c: Dictionary = _proposal(g, n).connections
	print(b.text)
	check(b.get("model", "") == "connections" and b.ready, "with the model on, the report is the connections one")
	check(not b.has("chain") and not b.has("view_change") and not b.has("trust"), "none of today's stages are in it")
	check(not b.text.contains("attention") and not b.text.contains("Change of view") and not b.text.contains("headline") and not b.text.contains("Against what"),
		"and its text names no attention, change of view, headline or \"against what they already held\" step")
	var parts: Dictionary = b.parts.get(t, {})
	check(not parts.is_empty() and b.people[0] == t, "it follows the premise's subject first")
	if parts.is_empty():
		return
	# The bar: the "after" chance is the refresh's posterior for this listener.
	check(is_equal_approx(float(parts.after), float(c.posterior[t])), "the \"after\" chance is the refresh's own (%.6f, %.6f)" % [float(parts.after), float(c.posterior[t])])
	check(is_equal_approx(float(parts.after), float(_proposal(g, n).effects[t].posterior)), "which is the chance the suspicion change was made from")
	check(parts.before != null and is_equal_approx(float(parts.before), chance_before), "the \"before\" chance is the one from their refresh before the case (%.6f)" % chance_before)
	var sum_after: float = 0.0
	var sum_before: float = 0.0
	for row in parts.rows:
		sum_after += float(row.after)
		sum_before += float(row.before)
	check(parts.pinned == "" and absf(Connections.chance(sum_after) - float(parts.after)) < 1e-9 and absf(Connections.chance(sum_before) - float(parts.before)) < 1e-9,
		"the parts shown add up to each chance (%.4f -> %.4f)" % [Connections.chance(sum_before), Connections.chance(sum_after)])
	# The case's own part.
	var entry: Dictionary = c.cases.entries.filter(func(e): return e.key == "case:%d" % s.filed)[0]
	var cs: Dictionary = b["case"]
	var case_row: Array = parts.rows.filter(func(r): return r.stage == "case")
	check(cs.counted and is_equal_approx(float(cs.weight), float(entry.weight)) and is_equal_approx(float(case_row[0].after), float(entry.lean.get(t, 0.0))) and is_zero_approx(float(case_row[0].before)),
		"the case's own part is the stored case's: %+.3f on the subject at weight %.2f, and nothing before" % [float(case_row[0].after), float(cs.weight)])
	check(is_equal_approx(float(cs.trust) * float(cs.fade), float(cs.weight)) and int(cs.days) == 0 and not cs.suspicious and is_equal_approx(float(cs.trust), Connections.presenter_trust(g._workshop_plans[n.id + ":good"].prepared.listener, "player")),
		"its weight is trust in the presenter, with no fading on the day (%.2f)" % float(cs.trust))
	check(not cs.moved.is_empty() and str(cs.moved[0].id) in entry.lean and b.text.contains("weighed together added"), "it names who the case moved most (%s)" % str(cs.moved[0].id))
	# The cards alone.
	check(b.cards.size() == 2 and b.cards.all(func(r): return r.status == "alone" and r.lean.has(t)), "both cards are listed at their own value")
	check(b.cards.filter(func(r): return r.brought).size() == 1 and b.cards_n == 2 and b.held == 1 and b.text.contains("new to them"),
		"the Seer's reading is marked as brought by the case; the Dowser's was held already")
	var cards_row: Array = parts.rows.filter(func(r): return r.stage == "case_cards")
	var alone: float = 0.0
	for r in b.cards:
		alone += float(r.lean[t])
	check(is_equal_approx(float(cards_row[0].after), alone) and not is_equal_approx(float(cards_row[0].before), alone), "their own values are the \"each counted by itself\" row (%+.3f -> %+.3f)" % [float(cards_row[0].before), alone])
	check(parts.other_cases.is_empty() and cs.replaces == ["case:%d" % s.first] and b.text.contains("It takes the place of #%d" % s.first),
		"the earlier case, whose only card this one cites, is replaced by it, and the report says so")
	# Suspicion, as stored and as read.
	check(is_equal_approx(float(b.suspicion.stored), float(n.suspicion[t])) and is_equal_approx(float(b.suspicion.stored_was), stored_before) and is_equal_approx(float(b.suspicion.now), Mind.susp(n, t)),
		"suspicion is shown as stored, before and after (%+.3f -> %+.3f), and as the game reads it" % [stored_before, float(n.suspicion[t])])
	check(b.has("action") and b.text.contains("Action:"), "the vote bar is still there")
	check(b.has("evidence") and b.evidence.cards.size() == 2 and b.text.contains("Does the case support its own premise"), "and so is the premise's own check")
	# Reading it changes nothing and makes no judgement.
	var state: Array = _state(g, n)
	Connections.capture = true
	Connections.captured = []
	var again: Dictionary = WorkshopWhy.presentation(g, n, g.board[s.filed - 1], "meeting", WorkshopWhy.before(n, g))
	Connections.capture = false
	check(Connections.captured.is_empty(), "reading the report makes no connections judgement")
	check(_state(g, n) == state, "and changes no mind, stored result, RNG or log")
	check(again.get("model", "") == "connections" and is_equal_approx(float(again.parts[t].after), float(parts.after)), "asked again, it gives the same \"after\"")
	# The dev log's record.
	var logged: Array = g.w.dlog.entries.filter(func(e): return e.type == "workshop_why")
	check(logged.size() == 1 and logged[0].data.get("model", "") == "connections" and logged[0].data.has("parts") and str(logged[0].reason).contains("weighed together"),
		"the dev log's record is the connections one (%s)" % (str(logged[0].reason) if logged.size() == 1 else "none"))
	Connections.enabled = false


func _hedged_and_faded() -> void:
	var s: Dictionary = _filed("suspicious", true)
	var g = s.g
	var n = s.n
	var was: Dictionary = WorkshopWhy.before(n, g)
	g._evaluate_deduction(n, g.board[s.filed - 1], 1.0, false, "meeting")
	var b: Dictionary = WorkshopWhy.presentation(g, n, g.board[s.filed - 1], "meeting", was)
	check(b.get("model", "") == "connections" and b["case"].suspicious and is_equal_approx(float(b["case"].weight), float(b["case"].trust) * Tuning.Workshop.SUSPICIOUS_HEARING)
		and b.text.contains("\"suspicious\" premise"), "a \"suspicious\" premise shows as half the weight (%.2f of trust %.2f)" % [float(b["case"].weight), float(b["case"].trust)])
	# A day later, with nothing kept from before: the fading shows, and only the "after" side.
	g.w.day += 1
	Mind.refresh_beliefs(g.w, n, " (next day)")
	var later: Dictionary = WorkshopWhy.presentation(g, n, g.board[s.filed - 1], "meeting")
	check(later.get("model", "") == "connections" and int(later["case"].days) == 1 and is_equal_approx(float(later["case"].fade), float(later["case"].rate)) and float(later["case"].rate) >= Connections.CASE_FADE and float(later["case"].rate) <= Connections.CASE_FADE_BOUGHT
		and is_equal_approx(float(later["case"].weight), float(later["case"].trust) * float(later["case"].rate) * Tuning.Workshop.SUSPICIOUS_HEARING),
		"a day on, the weight shows the fading too (%.3f)" % float(later["case"].weight))
	check(not later.had_before and later.parts[s.target].before == null and later.text.contains("No earlier refresh was recorded"), "with no \"before\" taken, only the \"after\" side is shown")
	Connections.enabled = false


# ------------------------------------------------------------ model off

func _off() -> void:
	var s: Dictionary = _filed("evil", false)
	var g = s.g
	var n = s.n
	var was: Dictionary = WorkshopWhy.before(n, g)
	check(not was.has("connections"), "with the model off, nothing of it is kept beforehand")
	g._evaluate_deduction(n, g.board[s.filed - 1], 1.0, false, "meeting")
	var b: Dictionary = WorkshopWhy.presentation(g, n, g.board[s.filed - 1], "meeting", was)
	check(b.get("ready", false) and not b.has("model") and b.chain.map(func(x): return x.stage) == ["certain", "face", "heard", "attention", "new", "resistance", "applied"],
		"with the model off, the report is today's, stage for stage")
	check(b.text.contains("attention") and not b.text.contains("connections model"), "and so is its text")


# ------------------------------------------------------------ the log says the model was on

func _log_flag() -> void:
	Connections.enabled = true
	var on = Game.new()
	on.detailed_logging = false
	on.new_case(900, 7)
	var start_on: Dictionary = on.w.dlog.entries.filter(func(e): return e.type == "case_start")[0].data
	Connections.enabled = false
	var off = Game.new()
	off.detailed_logging = false
	off.new_case(900, 7)
	var start_off: Dictionary = off.w.dlog.entries.filter(func(e): return e.type == "case_start")[0].data
	check(start_on.get("connections", false) == true, "a case played with the model on says so in case_start")
	check(not start_off.has("connections"), "one played with it off says nothing, as before")
	# A replay tool turns it on from the log.
	var events: Array = [{"type": "case_start", "seq": 1, "data": start_on}]
	Replay.new_game(events)
	check(Connections.enabled, "replaying such a log turns the model on")
	Connections.enabled = false
	Replay.new_game([{"type": "case_start", "seq": 1, "data": start_off}])
	check(not Connections.enabled, "and a log without it leaves the switch alone")


# ------------------------------------------------------------ the premise check's kept masks

func _masks() -> void:
	var s: Dictionary = _filed("evil", true)
	var g = s.g
	var n = s.n
	g._evaluate_deduction(n, g.board[s.filed - 1], 1.0, false, "meeting")
	CaseWhy._mask_cache.clear()
	var cold: Dictionary = WorkshopWhy.presentation(g, n, g.board[s.filed - 1], "meeting").evidence.duplicate(true)
	check(not CaseWhy._mask_cache.is_empty(), "the premise check keeps its per-world masks")
	var warm: Dictionary = WorkshopWhy.presentation(g, n, g.board[s.filed - 1], "meeting").evidence.duplicate(true)
	cold.erase("elapsed_ms")
	warm.erase("elapsed_ms")
	check(cold == warm, "and gives the same answer from kept masks as from fresh ones")
	Caches.clear_all()
	check(CaseWhy._mask_cache.is_empty(), "clearing the caches clears them")
	Connections.enabled = false


# ------------------------------------------------------------ profiling records, and changes nothing

func _profiling() -> void:
	var plain: Dictionary = _filed("evil", true)
	plain.g._evaluate_deduction(plain.n, plain.g.board[plain.filed - 1], 1.0, false, "meeting")
	var want: Dictionary = _proposal(plain.g, plain.n).connections.posterior.duplicate()
	var s: Dictionary = _filed("evil", true)
	Connections.capture = true
	Connections.captured = []
	Profiler.start()
	s.g._evaluate_deduction(s.n, s.g.board[s.filed - 1], 1.0, false, "meeting")
	var profile: Dictionary = Profiler.finish()
	Connections.capture = false
	var got: Dictionary = _proposal(s.g, s.n).connections
	check(got.posterior == want, "with capture and the profiler on, the chances are the same")
	var judged: Array = Connections.captured
	Connections.captured = []
	check(judged.size() == int(got.judgements) and judged.all(func(j): return j.listener == s.n.id and j.has("usec") and j.has("result")),
		"capture records one entry per judgement of the refresh (%d)" % judged.size())
	var sections: Array = []
	for j in judged:
		if j.section not in sections:
			sections.append(j.section)
	check("baseline" in sections and "items" in sections and "cases" in sections, "each tagged with the part that made it (%s)" % str(sections))
	var paths: Array = profile.rows.map(func(r): return str(r.path))
	check(paths.any(func(x): return x.ends_with("consequences/connections/items")) and paths.any(func(x): return x.ends_with("consequences/connections/cases")),
		"the profiler shows the model's parts under the refresh")
	var counted: int = 0
	for k in profile.counters:
		if str(k).ends_with("|connections_judgements"):
			counted += int(profile.counters[k])
	check(counted == judged.size(), "and counts its judgements (%d)" % counted)
	Connections.enabled = false

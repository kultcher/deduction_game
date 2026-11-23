## The connections model's kept judgements (workshop/connections.gd, step 6).
##
## - A judgement made before on the same inputs is handed back, not made again.
## - Beliefs are the same with the cache on and off: a whole passive game played both ways
##   leaves the same dev log and the same suspicions, and with `cache_verify` every kept
##   answer equals a fresh one.
## - The key is what a judgement reads: an unrelated card, the meeting's talk or attention's
##   bookkeeping keep an answer; the judged card, a death, trust or a Magistrate reading
##   with new talk make it be judged again.
extends SceneTree

const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const Mind = preload("res://sim/mind.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
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
	_presentations_and_magistrate()
	_cache_collision_safety()
	_role_constraints_key_and_parity()
	_drop_card_posterior_parity()
	Connections.cache_enabled = true
	CaseEval.cache_enabled = true
	Connections.cache_verify = false
	print("Connections cache: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _reset() -> void:
	LiveActivity.cache.clear()
	Caches.clear_all()
	Connections.cache_stats = {"hits": 0, "misses": 0, "wrong": 0}
	Connections.captured = []


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
	# 692 runs to day 2: with the secret errand retired (burdens prototype) its first day repeats no judgement.
	for spec in [[900, 7, 3], [692, 10, 2]]:
		Connections.cache_enabled = false
		CaseEval.cache_enabled = false
		Connections.cache_verify = false
		var plain: Dictionary = _play(spec[0], spec[1], spec[2])
		check(plain.stats.hits == 0 and plain.stats.misses == 0, "seed %d: with the cache off nothing is kept" % spec[0])
		Connections.cache_enabled = true
		CaseEval.cache_enabled = true
		var kept: Dictionary = _play(spec[0], spec[1], spec[2])
		check(kept.stats.hits > 0, "seed %d: with it on, judgements are handed back (%d kept, %d made)" % [spec[0], kept.stats.hits, kept.stats.misses])
		check(kept.suspicion == plain.suspicion, "seed %d: every NPC's suspicions are the same with the cache on and off" % spec[0])
		check(kept.log.size() == plain.log.size() and kept.log == plain.log, "seed %d: so is the whole dev log (%d records)" % [spec[0], kept.log.size()])
		Connections.cache_verify = true
		var checked: Dictionary = _play(spec[0], spec[1], spec[2])
		check(checked.stats.wrong == 0 and checked.stats.hits == kept.stats.hits, "seed %d: every kept answer equals a fresh one (%d checked)" % [spec[0], checked.stats.hits])
		check(checked.suspicion == plain.suspicion, "seed %d: and checking changes nothing" % spec[0])
		Connections.cache_verify = false


func _play_magistrate_presentations(game_seed: int) -> Dictionary:
	_reset()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(game_seed, 7, ScriptBuilder.dynamic({"seed": game_seed, "forced": ["magistrate"]}))
	var mag_id: String = ""
	for n in g.w.npcs:
		if n.role == "magistrate":
			mag_id = n.id
			break
	Connections.capture = true
	var presented_days: Dictionary = {}
	var nominated_days: Dictionary = {}
	var guard: int = 0
	while g.state != "over" and int(g.w.day) <= 2 and guard < 300:
		guard += 1
		match g.state:
			"approach":
				g.command("accept")
			"day":
				if mag_id != "" and g.w.by_id[mag_id].alive and g.w.phase == 0:
					g.w.by_id[mag_id].trust = 0.95
					g.command("go " + mag_id)
					if g.state == "day":
						g.command("talk " + mag_id)
					if g.state == "day":
						g.command("wait")
				else:
					g.command("wait")
			"talk":
				if not g.pending_request.is_empty():
					g.command("yes")
				elif g.questions_left == 3:
					g.command("ask gift")
				elif g.questions_left == 2:
					g.command("ask night")
				else:
					g.command("bye")
			"meeting":
				var d: int = int(g.w.day)
				var mag_reports: Array = []
				var reports: Array = []
				for c in GameBoard.all_receipts(g):
					if c.kind == "info" and not c.get("deleted", false):
						var norm: Dictionary = Evidence.normalize_card(c)
						var cid: String = str(norm.get("id", ""))
						if not cid.is_empty():
							if str(c.get("role", "")) == "magistrate":
								mag_reports.append(cid)
							else:
								reports.append(cid)
				var chosen_cards: Array = mag_reports + reports
				if not presented_days.has(d) and not chosen_cards.is_empty():
					presented_days[d] = true
					var living: Array = g.w.living()
					var draft: Dictionary = {
						"conclusion": {"type": "evil", "target": living[0].id, "at": "Current alignment"},
						"cards": chosen_cards.slice(0, mini(2, chosen_cards.size())),
						"lines": [], "arguments": [], "positions": {}, "answers": {}, "reading_challenges": {}, "circumstantial": []
					}
					var num: int = Canvas.file(g, draft)
					if num > 0:
						g.command("present %d" % num)
					else:
						g.command("wait")
				elif not nominated_days.has(d):
					nominated_days[d] = true
					var living: Array = g.w.living().filter(func(x): return x.id != mag_id)
					if living.is_empty():
						living = g.w.living()
					var subj: String = living[d % living.size()].id
					var cases: Array = g.board.filter(func(c): return str(c.get("kind", "")) == "deduction")
					if not cases.is_empty():
						g.command("nominate %s #%d" % [subj, int(cases[-1].n)])
					else:
						g.command("nominate %s raw" % subj)
				else:
					g.command("done" if g.town_quiet else "wait")
			"nomination":
				g.command("vote no")
			"night":
				if mag_id != "" and int(g.w.day) == 1:
					var has_elig_nom: bool = g.w.public_log.any(func(e):
						return int(e.get("day", -1)) == 1 and str(e.get("kind", "")) == "nomination" and str(e.get("by", "")) not in ["", "player", mag_id])
					if not has_elig_nom:
						var nom_pool: Array = g.w.living().filter(func(x): return x.id != mag_id)
						if nom_pool.size() >= 2:
							g.w.public_log.append({"day": 1, "phase": 2, "kind": "nomination", "by": nom_pool[0].id, "subjects": [nom_pool[1].id]})
				if mag_id != "" and g.w.by_id[mag_id].alive and int(g.w.tools.get("ward", 0)) > 0:
					g.command("ward " + mag_id)
				else:
					g.command("sleep")
	Connections.capture = false
	var mag_ids: Dictionary = {}
	for c in GameBoard.all_receipts(g):
		if str(c.get("role", "")) == "magistrate":
			var cid: String = str(Evidence.normalize_card(c).get("id", ""))
			if cid != "":
				mag_ids[cid] = true
	for plan in g._workshop_plans.values():
		if plan is Dictionary:
			for vc in plan.get("prepared", {}).get("view", {}).get("cards", []):
				if str(vc.get("role", "")) == "magistrate":
					mag_ids[str(vc.get("id", ""))] = true
	var own_mag_listeners: Dictionary = {}
	for plan in g._workshop_plans.values():
		if plan is Dictionary:
			var l: Dictionary = plan.get("prepared", {}).get("listener", {})
			var lid: String = str(l.get("id", ""))
			for oid in l.get("knowledge", {}).get("own_reports", []):
				if mag_ids.has(str(oid)):
					own_mag_listeners[lid] = true
					break
	var mag_judged: int = 0
	for cap in Connections.captured:
		var kstr: String = str(cap.get("key", ""))
		if kstr.begins_with("hex|"):
			kstr = kstr.substr(4)
		var hit_card: bool = false
		for part in kstr.split(",", false):
			if mag_ids.has(part):
				hit_card = true
				break
		if hit_card or own_mag_listeners.has(str(cap.get("listener", ""))):
			mag_judged += 1
	var suspicion: Dictionary = {}
	for n in g.w.npcs:
		suspicion[n.id] = n.suspicion.duplicate()
	var log: Array = g.w.dlog.entries.map(func(e): return [e.type, e.get("actor", ""), e.get("target", ""), e.get("reason", ""), JSON.stringify(e.get("data", {}))])
	return {"suspicion": suspicion, "log": log, "stats": Connections.cache_stats.duplicate(), "presented": presented_days.size(), "mag_judged": mag_judged}


func _presentations_and_magistrate() -> void:
	Connections.cache_enabled = false
	CaseEval.cache_enabled = false
	Connections.cache_verify = false
	var plain: Dictionary = _play_magistrate_presentations(21)
	Connections.cache_enabled = true
	CaseEval.cache_enabled = true
	Connections.cache_verify = true
	var kept: Dictionary = _play_magistrate_presentations(21)
	Connections.cache_verify = false
	check(plain.presented > 0, "magistrate presentation game files and presents cases (%d days)" % plain.presented)
	check(plain.mag_judged > 0 and kept.mag_judged == plain.mag_judged, "magistrate presentation game judges sets holding a Magistrate card (%d judgements)" % plain.mag_judged)
	check(kept.stats.wrong == 0 and kept.stats.hits > 0, "magistrate presentation game: kept judgements and fast keys match fresh ones (%d hits)" % kept.stats.hits)
	check(kept.suspicion == plain.suspicion, "magistrate presentation game: suspicions match with CaseEval and Connections caches on vs off")
	check(kept.log == plain.log, "magistrate presentation game: dev log matches with CaseEval and Connections caches on vs off (%d records)" % kept.log.size())


## The key, on one listener's real inputs.
func _key() -> void:
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
	var plain_card: Array = [reports[0]]
	var mag_card: Array = [magistrate.cards.filter(func(c): return c.id == reports[0].id)[0]]
	check(CaseEval.compile(view, plain_card, bare).key == CaseEval.compile(talk, plain_card, bare).key, "CaseEval.compile reuses a non-Magistrate card across meeting talk")
	check(CaseEval.compile(magistrate, mag_card, bare).key != CaseEval.compile(m_talk, mag_card, bare).key, "CaseEval.compile recompiles a Magistrate card when the meeting's talk changes")
	# Sightings-only and Lamplighter + sightings role-fits & cache-on/off checks (routing cards feed Activity.routes).
	var alive_others: Array = view.people.filter(func(p): return p.id != n.id and bool(p.get("alive", true)))
	check(alive_others.size() >= 3, "role-fits fixture has 3 living others")
	if alive_others.size() >= 3:
		var p_lamp: Dictionary = alive_others[0]
		var p_other: Dictionary = alive_others[1]
		var p_src: Dictionary = alive_others[2]
		var non_home: Array = ["square", "market", "docks", "hill"].filter(func(b): return b != str(p_lamp.get("home", "")))
		var s1: Dictionary = {"id": "sight:lamp_1", "fact_id": "sight:lamp_1", "kind": "sighting", "source": p_src.id,
			"subject": p_lamp.id, "subjects": [p_lamp.id], "block": non_home[0], "night": 1,
			"observed_at": {"day": 1, "phase": "night"}, "text": "Saw %s on %s." % [p_lamp.id, non_home[0]]}
		var s2: Dictionary = {"id": "sight:lamp_2", "fact_id": "sight:lamp_2", "kind": "sighting", "source": p_src.id,
			"subject": p_lamp.id, "subjects": [p_lamp.id], "block": non_home[1], "night": 1,
			"observed_at": {"day": 1, "phase": "night"}, "text": "Saw %s on %s." % [p_lamp.id, non_home[1]]}
		var lamp_card: Dictionary = {"id": "rep:lamp_test", "fact_id": "rep:lamp_test", "kind": "report",
			"role": "lamplighter", "source": p_other.id, "night": 1,
			"observed_at": {"day": 1, "phase": "night"}, "data": {"count": 1}, "text": "1 folk out."}
		var view_m: Dictionary = view.duplicate(true)
		view_m.cards.append_array([s1, s2, lamp_card])
		var test_listener: Dictionary = listener.duplicate(true)
		if str(test_listener.get("knowledge", {}).get("own_role", "")) == "lamplighter":
			test_listener.knowledge["own_role"] = ""
		var cc_s: Dictionary = CaseEval.compile(view_m, [s1, s2], bare)
		var fits_before_s: PackedFloat64Array = CaseEval._class_fits(view_m, cc_s, [], test_listener.knowledge)
		_reset()
		CaseEval.cache_enabled = false
		var fits_s_off: PackedFloat64Array = CaseEval._class_fits(view_m, cc_s, [s1, s2], test_listener.knowledge)
		var ev_s_off: Dictionary = CaseEval.evaluate(view_m, Connections.case_for(bare, [s1.id, s2.id]), test_listener)
		_reset()
		CaseEval.cache_enabled = true
		var fits_s_on: PackedFloat64Array = CaseEval._class_fits(view_m, cc_s, [s1, s2], test_listener.knowledge)
		var ev_s_on: Dictionary = CaseEval.evaluate(view_m, Connections.case_for(bare, [s1.id, s2.id]), test_listener)
		check(fits_s_off != fits_before_s, "sightings-only set: after-fits differ from before-fits when sightings force a Lamplighter")
		check(fits_s_on == fits_s_off and ev_s_on.people == ev_s_off.people, "sightings-only set: fits and beliefs match with CaseEval shortcut/cache on vs off")
		var cc_ls: Dictionary = CaseEval.compile(view_m, [lamp_card, s1, s2], bare)
		var fits_before_ls: PackedFloat64Array = CaseEval._class_fits(view_m, cc_ls, [], test_listener.knowledge)
		var fits_lamp_only: PackedFloat64Array = CaseEval._class_fits(view_m, cc_ls, [lamp_card], test_listener.knowledge)
		_reset()
		CaseEval.cache_enabled = false
		var fits_ls_off: PackedFloat64Array = CaseEval._class_fits(view_m, cc_ls, [lamp_card, s1, s2], test_listener.knowledge)
		var ev_ls_off: Dictionary = CaseEval.evaluate(view_m, Connections.case_for(bare, [lamp_card.id, s1.id, s2.id]), test_listener)
		_reset()
		CaseEval.cache_enabled = true
		var fits_ls_on: PackedFloat64Array = CaseEval._class_fits(view_m, cc_ls, [lamp_card, s1, s2], test_listener.knowledge)
		var ev_ls_on: Dictionary = CaseEval.evaluate(view_m, Connections.case_for(bare, [lamp_card.id, s1.id, s2.id]), test_listener)
		check(fits_ls_off != fits_before_ls and fits_ls_off != fits_lamp_only, "Lamplighter reading plus sightings: after-fits differ from before-fits and from the reading alone")
		check(fits_ls_on == fits_ls_off and ev_ls_on.people == ev_ls_off.people, "Lamplighter reading plus sightings: fits and beliefs match with CaseEval shortcut/cache on vs off")
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


func _cache_collision_safety() -> void:
	Connections.cache_enabled = true
	CaseEval.cache_enabled = true
	var played: Dictionary = _play(900, 7, 2)
	var g = played.g
	var n = g.w.living().filter(func(x): return not x.is_evil())[0]
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	check(not plan.is_empty(), "collision safety: fixture has a listener with a plan")
	if plan.is_empty():
		return
	var view: Dictionary = plan.prepared.view.duplicate(true)
	var listener: Dictionary = preload("res://workshop/jury.gd")._eval_listener(plan.prepared.listener, plan.prepared.listener.knowledge.get("own_reports", [])).duplicate(true)
	var others: Array = view.people.map(func(p): return p.id).filter(func(p): return p != n.id)
	var bare: Dictionary = Connections.template(plan.prepared.get("case", {"cards": [], "conclusion": {"type": "evil", "target": others[0]}}), others[0])
	var reports: Array = view.cards.filter(func(c): return c.kind == "report" and c.id not in listener.knowledge.get("own_reports", []))
	check(not reports.is_empty(), "collision safety: fixture holds at least one report card")
	if reports.is_empty():
		return
	var card_rep: Dictionary = reports[0]
	var live: bool = CaseEval.Domain.live(view)
	var u_key: String = CaseEval.Solver._universe_key(view)
	var universe: Array = CaseEval.Solver.universe(view)
	var case_r: Dictionary = Connections.case_for(bare, [card_rep.id])
	var cc_r: Dictionary = CaseEval.compile(view, [card_rep], case_r)
	var nc_r: int = cc_r.team.size()
	CaseEval.cache_enabled = false
	var ev_expected: Dictionary = CaseEval.evaluate(view, case_r, listener)
	CaseEval.cache_enabled = true
	Caches.clear_all()
	var role_cards: Array = [card_rep].filter(CaseEval._is_role_card) if live else [card_rep]
	var tl: Dictionary = view.get("timeline", {})
	if not role_cards.is_empty() and tl.has("events") and not role_cards.any(CaseEval._is_movement_role_card):
		tl = tl.duplicate(false)
		tl["events"] = tl.events.filter(func(e): return str(e.get("kind", "")) not in CaseEval.SOFT_EVENTS)
	var base_fit_ref: Array = [u_key, view.people, tl if not role_cards.is_empty() else (view.get("timeline", {}) if not live else {}), view.get("live_activity", false), live, cc_r.rep, "bare" if role_cards.is_empty() else role_cards]
	var base_fit_key: int = hash(base_fit_ref)
	var neutral_key: int = hash([base_fit_ref, "neutral"])
	var personal: Dictionary = {"self": listener.knowledge.get("self", ""), "own_role": listener.knowledge.get("own_role", ""), "own_outings": listener.knowledge.get("own_outings", {})}
	if not listener.knowledge.get("public_roles", {}).is_empty():
		personal["public_roles"] = listener.knowledge.public_roles
	var pers_key: int = hash([base_fit_key, personal, live, role_cards.is_empty()])
	# Poison both _fits_cache slots with wrong-sized arrays to simulate 32-bit hash collisions.
	var wrong_size := PackedFloat64Array([1.0, 1.0])
	CaseEval._fits_cache[neutral_key] = {"ref": ["forced_neutral_collision", nc_r], "out": wrong_size}
	CaseEval._fits_cache[pers_key] = {"ref": ["forced_personal_collision", nc_r], "out": wrong_size}
	var valid_key: int = hash([u_key, card_rep.kind, card_rep.get("source", ""), card_rep.get("observed_at", {}), card_rep.get("role", ""), view.get("timeline", {}), card_rep.get("testimony_only", false), card_rep.get("reported_at"), card_rep.get("duty_only", false)])
	CaseEval._valid_cache[valid_key] = {"ref": ["forced_valid_collision"], "out": PackedByteArray([1])}
	var prem_key: int = hash([u_key, CaseEval.Solver.question_inputs(view, bare.conclusion), view.get("timeline", {})])
	CaseEval._premise_cache[prem_key] = {"ref": ["forced_premise_collision"], "out": PackedByteArray([0])}
	var ev_after: Dictionary = CaseEval.evaluate(view, case_r, listener)
	check(absf(float(ev_after.posterior) - float(ev_expected.posterior)) < 1e-12 and ev_after.people == ev_expected.people,
		"_fits_cache / _valid_cache / _premise_cache ignore 32-bit hash collisions with mismatched refs")
	var ReasonAttr := preload("res://workshop/reason_attribution.gd")
	ReasonAttr._fits_cache.clear()
	var ra_expected: PackedFloat64Array = ReasonAttr._subset_fits(view, cc_r, [card_rep], listener.knowledge)
	ReasonAttr._fits_cache.clear()
	var ra_sig: Array = [[card_rep.get("id", ""), card_rep.get("kind", ""), card_rep.get("source", ""), card_rep.get("role", ""), card_rep.get("hearing_weight", 1.0), card_rep.has("relay_source"), card_rep.get("quoted", false)]]
	var ra_neutral_key: int = hash([cc_r.key, cc_r.rep, "ra_neutral", live, ra_sig])
	var ra_pers_key: int = hash([cc_r.key, cc_r.rep, "ra_personal", live, ra_sig, personal])
	ReasonAttr._fits_cache[ra_neutral_key] = {"ref": ["forced_ra_neutral", nc_r], "out": wrong_size}
	ReasonAttr._fits_cache[ra_pers_key] = {"ref": ["forced_ra_personal", nc_r], "out": wrong_size}
	var ra_after: PackedFloat64Array = ReasonAttr._subset_fits(view, cc_r, [card_rep], listener.knowledge)
	check(ra_after == ra_expected, "ReasonAttribution._fits_cache ignores 32-bit hash collisions with mismatched refs")
	var base_h: int = SolverBackend.get_universe_handle(u_key, universe)
	var h_small: int = SolverBackend.get_sub_universe_handle("cc_reps:forced_collision", base_h, PackedInt32Array([0, 1]))
	var h_large: int = SolverBackend.get_sub_universe_handle("cc_reps:forced_collision", base_h, PackedInt32Array([0, 1, 2, 3, 4]))
	var h_small_repeat: int = SolverBackend.get_sub_universe_handle("cc_reps:forced_collision", base_h, PackedInt32Array([0, 1]))
	check(h_small >= 0 and h_large >= 0 and h_small != h_large and h_small == h_small_repeat,
		"get_sub_universe_handle disambiguates colliding sub_keys with different index arrays")


func _role_constraints_key_and_parity() -> void:
	Connections.cache_enabled = true
	CaseEval.cache_enabled = true
	var played: Dictionary = _play(900, 7, 2)
	var g = played.g
	var n = g.w.living().filter(func(x): return not x.is_evil())[0]
	var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
	check(not plan.is_empty(), "role_constraints key test: fixture has a plan")
	if plan.is_empty():
		return
	var view: Dictionary = plan.prepared.view.duplicate(true)
	var listener: Dictionary = preload("res://workshop/jury.gd")._eval_listener(plan.prepared.listener, plan.prepared.listener.knowledge.get("own_reports", [])).duplicate(true)
	var others: Array = view.people.map(func(p): return p.id).filter(func(p): return p != n.id)
	var reports: Array = view.cards.filter(func(c): return c.kind == "report" and c.id not in listener.knowledge.get("own_reports", []))
	check(not reports.is_empty(), "role_constraints key test: fixture has report cards")
	if reports.is_empty():
		return
	var Roles = CaseEval.Solver.Roles
	var universe: Array = CaseEval.Solver.universe(view)
	var u_h: int = SolverBackend.get_universe_handle(CaseEval.Solver._universe_key(view), universe)
	_reset()
	var w_base: PackedFloat64Array = Roles.fits_weights(view, universe, [reports[0]], listener.knowledge, {}, false, u_h)
	var cache_after_base: int = Roles.cache.size()
	var view_soft: Dictionary = view.duplicate(true)
	view_soft.timeline.events.append({"kind": "vote", "by": others[0], "subjects": [others[1]], "at": {"day": 2, "phase": "evening"}})
	view_soft.timeline.events.append({"kind": "nomination", "by": others[0], "subjects": [others[1]], "at": {"day": 2, "phase": "evening"}})
	var w_soft: PackedFloat64Array = Roles.fits_weights(view_soft, [], [reports[0]], listener.knowledge, {}, false, u_h)
	check(cache_after_base == 1 and Roles.cache.size() == 1 and w_soft == w_base,
		"RoleConstraints strips SOFT_EVENTS from key and handles empty reps with handle")
	var martyr_card: Dictionary = {"id": "rep:martyr_curse", "fact_id": "rep:martyr_curse", "kind": "report",
		"role": "martyr", "source": others[0], "observed_at": {"day": 2, "phase": "night"},
		"data": {"chosen": true, "target": others[1]}, "text": "promised"}
	var view_c1: Dictionary = view.duplicate(true)
	view_c1.timeline.events.append({"kind": "execution", "subjects": [others[1]], "by": others[0], "at": {"day": 1, "phase": "evening"}})
	view_c1["chronology"] = {"curse": {"executed": others[1], "from": 0, "until": 0}}
	var view_c2: Dictionary = view_c1.duplicate(true)
	view_c2["chronology"] = {"curse": {"executed": others[1], "from": 0, "until": 10}}
	Roles.reuse = false
	var w_c1_off: PackedFloat64Array = Roles.fits_weights(view_c1, universe, [martyr_card], listener.knowledge, {}, false, u_h)
	var w_c2_off: PackedFloat64Array = Roles.fits_weights(view_c2, universe, [martyr_card], listener.knowledge, {}, false, u_h)
	Roles.reuse = true
	_reset()
	var w_c1_on: PackedFloat64Array = Roles.fits_weights(view_c1, universe, [martyr_card], listener.knowledge, {}, false, u_h)
	var c1_sz: int = Roles.cache.size()
	var w_c2_on: PackedFloat64Array = Roles.fits_weights(view_c2, universe, [martyr_card], listener.knowledge, {}, false, u_h)
	var c2_sz: int = Roles.cache.size()
	check(c1_sz == 1 and c2_sz == 2 and w_c1_on == w_c1_off and w_c2_on == w_c2_off,
		"RoleConstraints includes view.chronology in key and matches uncached evaluation (%d -> %d entries)" % [c1_sz, c2_sz])
	var bare: Dictionary = Connections.template(plan.prepared.get("case", {"cards": [], "conclusion": {"type": "evil", "target": others[0]}}), others[0])
	var case_r: Dictionary = Connections.case_for(bare, reports.slice(0, mini(2, reports.size())).map(func(c): return c.id))
	_reset()
	CaseEval.use_cc_reps_handle = false
	var ev_no_h: Dictionary = CaseEval.evaluate(view, case_r, listener)
	_reset()
	CaseEval.use_cc_reps_handle = true
	var ev_with_h: Dictionary = CaseEval.evaluate(view, case_r, listener)
	check(ev_with_h.people == ev_no_h.people,
		"CaseEval._fits_over matches with cc_reps_handle forced off vs on")


func _drop_card_posterior_parity() -> void:
	Connections.cache_enabled = true
	CaseEval.cache_enabled = true
	Connections.cache_verify = true
	var played: Dictionary = _play(900, 7, 3)
	var g = played.g
	var ReasonAttr := preload("res://workshop/reason_attribution.gd")
	var checked_drops: int = 0
	var max_diff: float = 0.0
	var play_wrong: int = int(played.stats.wrong)
	Connections.cache_stats = {"hits": 0, "misses": 0, "wrong": 0}
	for n in g.w.living():
		var plan_key: String = n.id + (":cover" if n.is_shadow else ":good")
		var plan: Dictionary = g._workshop_plans.get(plan_key, {})
		if plan.is_empty():
			continue
		var prep: Dictionary = plan.prepared
		var view: Dictionary = prep.view
		var own_rep: Array = prep.listener.get("knowledge", {}).get("own_reports", [])
		var listener: Dictionary = preload("res://workshop/jury.gd")._eval_listener(prep.listener, own_rep)
		listener["trust"] = prep.listener.get("trust", 0.5)
		listener["insight"] = prep.listener.get("insight", 0.5)
		var held_ids: Array = view.cards.map(func(c): return c.id)
		if held_ids.size() < 2:
			continue
		var base_case: Dictionary = {"cards": held_ids, "conclusion": {"type": "evil", "target": view.people[0].id, "at": "Current alignment"}}
		var state_cfg: Dictionary = prep.listener.get("connections", {})
		var state: Dictionary = {"day": int(state_cfg.get("day", -1)), "core": state_cfg.get("core", {}), "cases": [{"key": "c:test", "presenter": "player", "day": int(g.w.day), "cards": [held_ids[0]], "challenges": {}, "target": view.people[0].id}]}
		var full_res: Dictionary = Connections.refresh(view, base_case, listener, held_ids, state)
		if bool(full_res.get("impossible", false)):
			continue
		var pr0: Dictionary = {"evil": 0.3}
		var ctx: Dictionary = {"cx": {"view": view, "value": base_case, "weigher": listener, "held": held_ids, "state": state, "result": full_res}}
		var pid: String = view.people[0].id if view.people[0].id != n.id else view.people[1].id
		for cid in held_ids:
			var post_fast: Dictionary = Connections.drop_card_posterior(view, base_case, listener, held_ids, state, full_res, cid)
			var post_ref: Dictionary = Connections.refresh(view, base_case, listener, held_ids.filter(func(id): return id != cid), state).get("posterior", {})
			for p in post_ref:
				max_diff = maxf(max_diff, absf(float(post_fast.get(p, -1.0)) - float(post_ref[p])))
			var _d = ReasonAttr._connections_drop(ctx, cid, pid, pr0)
			checked_drops += 1
	check(checked_drops > 0 and play_wrong == 0 and Connections.cache_stats.wrong == 0 and max_diff < 1e-12,
		"Connections.drop_card_posterior matches full refresh across %d card drops (max diff %.12f, wrong=%d)" % [checked_drops, max_diff, Connections.cache_stats.wrong])
	Connections.cache_verify = false

## The connections belief model (Phase 6; Project doc
## `claude/belief-model-direction-2026-11-10.md`, "Phase 6 spec"). Behind a switch that is
## off by default: with it off nothing here runs, and the game behaves exactly as before.
##
## The idea: the limit on an NPC moves from which cards it reads to which cards it weighs
## together. Every card it holds counts, at the value it has alone; cards are only weighed
## together where a connection says so (built-in pairings, the NPC's own core, stored
## cases).
##
##   judge       today's shared evaluator (CaseEval over the possible worlds) run on a chosen
##               set of the held cards: everyone's chance of being evil given just that set
##   prior       the listener's standing suspicion and what it knows about itself, before
##               any evidence: the judge's "before" side, the same as today's
##   baseline    the judge on no cards: the prior plus the public record (deaths, executions),
##               which is in every run
##   lean        how far a set moves a person from the baseline, in log-odds, so leans add
##   context     role claims, confessed secrets and profile cards (work, haunts, home, bonds):
##               they explain other cards, and can sit beside any set without joining sets
##   item        the things that count once: a plain card, or a built-in pairing (cards that
##               mean little alone and are always read with their partner). An item's value
##               is lean(its cards + its context) - lean(its context)
##   normalising one common shift afterwards, so the chances of being evil still sum to what
##               the baseline's do (the script's evil count): "A for sure, then B or C",
##               never four people at 70% in a two-evil town
##
##   firsthand   what the listener knows for itself among the cards it holds: its own
##               readings, and a sighting of it on a night it knows it spent at home
##   core        the items holding a firsthand card (the seed), judged together with every
##               other item worth more next to the seed than apart from it. Each candidate
##               is tested against the seed only, never against what already joined, so the
##               order can't matter and the core can't snowball. The core adds what its
##               members say together beyond their own values.
##               It is rebuilt on a new day and when the firsthand cards change; otherwise
##               its members stay, and only an item with a newly held card is tested. The
##               caller keeps that memory (`core_state`) and stores what comes back.
##               What the firsthand cards prove by themselves (someone at 0 or 1) stays
##               proved: no other card moves that person.
##
##   stored case a case someone put to the listener: the player's presentation, or the
##               cards an NPC nominator cited. Its cards are judged together and it adds
##               what they say together beyond their own values, times its weight: the
##               listener's trust in the presenter, halved for each day since (CASE_FADE),
##               halved again under a "suspicious" premise, and nothing below CASE_FLOOR.
##               A case that shares a card or pairing with the core is judged with the core
##               as one set (older cases first); the core's own part counts in full and
##               what the case adds on top is weighted. Cards it cites from an always-on
##               connection add only what they say next to the case's other cards: that
##               connection already weighs them together, in full.
##               A presenter's cases don't stack on their own cards (Michael, Nov 13): one
##               that cites every card of an earlier one takes its place, and otherwise a
##               case adds nothing for what an earlier one already put together.
##               A reading challenge in a case acts inside that case's set only: the
##               challenged reading's own value is untouched, and the floor a "lying"
##               challenge puts under its teller is scaled by the case's weight.
##
## The built-in pairings (items):
##   a night      that night's sightings, home alibis, Night Watch reports and Lamplighter
##                counts, with the named people's claims and confessed secrets as context
##   an Augur day the Augur reading and that day's sightings
##   a Psychologist reading and its two statements
##   a trace      with the profile cards as context
##
## The demon-type declaration decides how movement is read (`row`):
##   "none"    no declaration on a script with both kinds: each night by itself. Inside a
##             night the Demon's movement is today's mix of the two kinds.
##   "walker"  declared, or a walker-only script: every night and trace together, as one
##             always-on movement connection. This is today's reading.
##   "hexer"   declared, or a Hexer-only script: each night by itself (the Demon doesn't
##             walk), and the Hexer's day evidence as one always-on day connection.
## The Hexer's day evidence (the Hexer factor: kills against day logs, daytime sightings and
## haunts) is read in that one place only. Every other judgement runs with the factor off;
## the day connection's value is what the factor adds on the day cards (on minus off).
## Otherwise each night's pairing would count the same day evidence again.
##
## Pure: the prepared view, case, listener and the core's memory in; chances, a breakdown
## and the core's new memory out. It reads no game state and keeps nothing itself (the
## game stores the memory in the NPC's workshop_state.connections; caching is a later step).
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const DayPresence = preload("res://workshop/day_presence.gd")
const Profiler = preload("res://workshop/profiler.gd")

## The switch. It starts from the Tuning value; tests, autoplay and sweeps set it for a run
## (`--connections`), so paired cells come from one build.
static var enabled: bool = Tuning.Workshop.CONNECTIONS

## Tests and tools only: read movement as this row ("none", "walker" or "hexer") whatever
## the town's demon mix is. It changes the grouping, not the mix the judge uses. Empty in play.
static var force_row: String = ""

## Tests and tools only: whether a sighting of the listener on a night it knows it spent at
## home is firsthand knowledge (it seeds the core). On in play; a tool turns it off to
## measure what it changes.
static var seed_wrong_sightings: bool = true
## Measurement switches (on in play), for showing what each rule changes on a replay:
## - reuse_rule: a presenter's case that reuses its own cards doesn't stack (case_plan's
##   replacement, case_step's shared part).
## - held_together_rule: a case adds nothing for cards an always-on connection already
##   weighs together (interaction).
static var reuse_rule: bool = true
static var held_together_rule: bool = true
## Buy-in fading (buy_in_rate). Off, every case keeps CASE_FADE a day (for measuring, and
## for arithmetic tests on chosen numbers).
static var buy_in: bool = true
## Developer capture (off): one record per judgement a refresh makes, for measuring what a
## cache would save. {"listener", "section" (baseline, items, core, cases), "key" (the set
## judged), "cards", "usec", "result" (a hash of the chances it gave)}. Read-only; the
## caller turns it on, reads `captured` and turns it off.
static var capture: bool = false
static var captured: Array = []

## An item joins the core at this much interaction with the seed (log-odds, any one person).
const CORE_JOIN: float = Tuning.Workshop.CONNECTIONS_CORE_JOIN

## A stored case keeps CASE_FADE of its weight a day (more if the listener bought it:
## buy_in_rate), and stops counting below CASE_FLOOR.
const CASE_FADE: float = Tuning.Workshop.CONNECTIONS_CASE_FADE
const CASE_FLOOR: float = Tuning.Workshop.CONNECTIONS_CASE_FLOOR
## A case the listener bought fades slower: up to CASE_FADE_BOUGHT a day (buy_in_rate).
const CASE_FADE_BOUGHT: float = Tuning.Workshop.CONNECTIONS_CASE_FADE_BOUGHT
const CASE_BUYIN_FULL: float = Tuning.Workshop.CONNECTIONS_CASE_BUYIN_FULL

const ReadingChallenges = preload("res://workshop/reading_challenges.gd")

## A chance is held inside [CLIP, 1 - CLIP] before it becomes log-odds.
const CLIP: float = Tuning.Workshop.CONNECTIONS_CLIP
## A person the baseline already puts this close to 0 or 1 is settled (the public record,
## the listener's own knowledge): cards don't move them.
const FIXED: float = Tuning.Workshop.CONNECTIONS_FIXED

const LIST_KEYS: Array = ["lines", "derived", "arguments", "circumstantial", "temporal_positions", "disputes", "test_factors", "conflict_scope"]
const MAP_KEYS: Array = ["positions", "answers", "reasons", "citations", "faults", "challenges", "reading_challenges"]

const CONTEXT_KINDS: Array = ["claim", "secret_claim", "context"]
const NIGHT_KINDS: Array = ["sighting", "alibi", "coverage", "evening"]
const NIGHT_ROLES: Array = ["lamplighter", "nightwatch"]
const TRACE_KINDS: Array = ["trace", "dropped"]
## What the Hexer factor reads besides the profile cards (LiveActivity: presence_cards).
const DAY_KINDS: Array = ["location", "watch_log", "evening"]
## Item kinds that are always on for every listener and never merge with anything.
const ALWAYS_ON: Array = ["movement", "day"]


## The listener's whole-evidence case stripped to a bare "these cards" case: no lines,
## answers or challenges, and no cards yet. `target` only names the question CaseEval is
## asked; everyone's chance comes back whichever person it is.
static func template(case_data: Dictionary, target: String) -> Dictionary:
	var out: Dictionary = case_data.duplicate(true)
	for key in LIST_KEYS:
		out[key] = []
	for key in MAP_KEYS:
		out[key] = {}
	out.cards = []
	out.conclusion = {"type": "evil", "target": target, "at": case_data.get("conclusion", {}).get("at", "Original alignment")}
	return out


## The template with a set of held card ids (sorted, so one set is always one case).
static func case_for(template_case: Dictionary, ids: Array) -> Dictionary:
	var sorted: Array = ids.duplicate()
	sorted.sort()
	var out: Dictionary = template_case.duplicate(true)
	out.cards = sorted
	return out


## The judge on a set of held cards. `hex`: with the Hexer factor (only the day connection
## asks for it; see the header).
## Kept judgements (step 6). A judgement is a pure function of what it reads, so one made
## before on the same inputs is handed back instead of being made again. Its key
## (judge_key) is what the judge reads, and no more than that, so that a new card or a
## remark at the meeting doesn't throw away what it has nothing to do with:
## - the view apart from its cards and its record of public events;
## - the cards judged and the listener's own readings. The judge is handed its cards; the
##   only cards it looks up in the view are those two (Solver.selected, and the listener's
##   own reports by id), so a card outside the set changes nothing;
## - the public record: deaths, executions and the events of KINDS not in SOFT_EVENTS. The
##   meeting's own talk (nominations, votes, accusations) is read by one gift only, the
##   Magistrate's; a judgement that involves a Magistrate reading keys on all of it;
## - the bare case; the Hexer switch;
## - the listener as the judge sees it (Jury._eval_listener), with only the reliabilities
##   of the cards above, and without attention's bookkeeping or the two trust figures
##   that only weigh stored cases.
## Beliefs are the same with the cache on and off. `cache_verify` (a developer switch)
## makes every kept answer be judged again and compared (cache_stats.wrong counts any
## difference); tools/test_connections_cache.gd plays games that way.
## Kept per listener; a listener's store is emptied when it passes KEPT_MAX.
static var cache_enabled: bool = true
static var cache_verify: bool = false
static var cache_stats: Dictionary = {"hits": 0, "misses": 0, "wrong": 0}
static var _kept: Dictionary = {}
const KEPT_MAX: int = 6000
const SOFT_EVENTS: Array = ["nomination", "meeting", "vote", "vote_yes", "accusation", "reading", "clear"]
const SOFT_READERS: Array = ["magistrate"]


static func judge_key(view: Dictionary, template_case: Dictionary, listener: Dictionary, ids: Array, hex: bool) -> String:
	var own: Array = listener.get("knowledge", {}).get("own_reports", [])
	var cards: Array = []
	var names: Array = []
	var soft: bool = false
	for c in view.get("cards", []):
		var judged: bool = c.id in ids or c.id in own
		if judged:
			cards.append(c)
			soft = soft or str(c.get("role", "")) in SOFT_READERS
			for name in [c.get("accuracy_origin", ""), Solver.semantic_key(c), c.get("fact_id", ""), c.id]:
				if name != "" and name not in names:
					names.append(name)
	var around: Dictionary = view.duplicate(false)
	around.erase("cards")
	var timeline: Dictionary = around.get("timeline", {})
	if not soft and timeline.has("events"):
		timeline = timeline.duplicate(false)
		timeline["events"] = timeline.events.filter(func(e): return str(e.get("kind", "")) not in SOFT_EVENTS)
		around["timeline"] = timeline
	var who: Dictionary = listener.duplicate(false)
	who.erase("trust")
	who.erase("player_credibility")
	var heard: Dictionary = {}
	var all_heard: Dictionary = listener.get("reading_reliability", {})
	for name in names:
		if all_heard.has(name):
			heard[name] = all_heard[name]
	who["reading_reliability"] = heard
	# Attention's bookkeeping (which reports a presentation put in front of the listener)
	# is the union model's; no judgement reads it (as Solver._query_knowledge).
	var known: Dictionary = listener.get("knowledge", {}).duplicate(false)
	known.erase("presented_reports")
	known.erase("attention_reports")
	who["knowledge"] = known
	return "%d:%d:%d:%d|%s|%s" % [hash(around), hash(cards), hash(template_case), hash(who), "hex" if hex else "", ",".join(PackedStringArray(ids))]


static func judge(view: Dictionary, template_case: Dictionary, listener: Dictionary, ids: Array, hex: bool = false) -> Dictionary:
	# A caller that wants the worlds themselves (CaseEval.capture_worlds) needs the real run.
	if not cache_enabled or CaseEval.capture_worlds:
		return _judge(view, template_case, listener, ids, hex)
	var who: String = str(listener.get("id", ""))
	var key: String = judge_key(view, template_case, listener, ids, hex)
	var store: Dictionary = _kept.get(who, {})
	if store.has(key):
		cache_stats.hits += 1
		if cache_verify:
			var fresh: Dictionary = _slim(_judge(view, template_case, listener, ids, hex))
			if fresh != store[key]:
				cache_stats.wrong += 1
				if cache_stats.wrong <= 5:
					push_warning("Connections: a kept judgement differs from a fresh one (%s, %s)" % [who, str(ids)])
		return store[key]
	cache_stats.misses += 1
	var slim: Dictionary = _slim(_judge(view, template_case, listener, ids, hex))
	if store.size() >= KEPT_MAX:
		store = {}
	store[key] = slim
	_kept[who] = store
	return slim


## What the model reads of a judgement: each person's chance before and after, and whether
## anything fits at all.
static func _slim(ev: Dictionary) -> Dictionary:
	var slim: Dictionary = {"impossible": bool(ev.get("impossible", false)), "people": {}}
	for p in ev.get("people", {}):
		slim.people[p] = {"prior": float(ev.people[p].get("prior", 0.0)), "posterior": float(ev.people[p].get("posterior", 0.0))}
	return slim


static func _judge(view: Dictionary, template_case: Dictionary, listener: Dictionary, ids: Array, hex: bool = false) -> Dictionary:
	var was: bool = LiveActivity.hex_factor_enabled
	var bare: bool = DayPresence.bare_reads_view
	LiveActivity.hex_factor_enabled = hex
	DayPresence.bare_reads_view = false  # the baseline is no cards at all (day_presence.gd)
	var ev: Dictionary = CaseEval.evaluate(view, case_for(template_case, ids), listener)
	LiveActivity.hex_factor_enabled = was
	DayPresence.bare_reads_view = bare
	return ev


static func logit(p: float, clip: float = CLIP) -> float:
	var q: float = clampf(p, clip, 1.0 - clip)
	return log(q / (1.0 - q))


static func chance(log_odds: float) -> float:
	return 1.0 / (1.0 + exp(-log_odds))


## The one shift, in log-odds, that makes the chances behind `scores` sum to `target`.
static func common_shift(scores: Array, target: float) -> float:
	var lo := -30.0
	var hi := 30.0
	for step in range(60):
		var mid: float = (lo + hi) / 2.0
		var s := 0.0
		for score in scores:
			s += 1.0 / (1.0 + exp(-(float(score) + mid)))
		if s > target:
			hi = mid
		else:
			lo = mid
	return (lo + hi) / 2.0


## How movement is read: "walker", "hexer" or "none" (see the header). It follows the town's
## demon mix, which the declaration sets and a one-kind script fixes from the start.
static func row(view: Dictionary) -> String:
	if force_row != "":
		return force_row
	var share: float = LiveActivity.day_demon_share(view)
	if share <= 0.0:
		return "walker"
	if share >= 1.0:
		return "hexer"
	return "none"


static func _union(a: Array, b: Array) -> Array:
	var out: Array = a.duplicate()
	for x in b:
		if x not in out:
			out.append(x)
	return out


## The people a set of cards names anywhere in it.
static func _names(by_id: Dictionary, ids: Array, people: Array) -> Array:
	var out: Array = []
	for id in ids:
		var text: String = JSON.stringify(by_id[id])
		for p in people:
			if p not in out and text.contains("\"%s\"" % p):
				out.append(p)
	return out


## Every held card grouped into the things that count once. Each item:
## {"key", "ids", "ctx", "kind"}; kind is "card", "unit" (a built-in pairing), "movement" or
## "day" (the two always-on connections). Every held card is in exactly one item, except
## that the day connection reads cards which also sit in a night or an Augur day: it only
## ever adds what the Hexer factor makes of them.
## by_id: the view's cards by id. held: the listener's held card ids. people: everyone's id.
static func items(by_id: Dictionary, held: Array, people: Array, row_name: String) -> Array:
	var placed: Dictionary = {}
	var out: Array = []
	var context: Array = held.filter(func(id): return by_id[id].kind in CONTEXT_KINDS)
	var explain := func(ids: Array, kinds: Array) -> Array:
		var who: Array = _names(by_id, ids, people)
		return context.filter(func(c): return by_id[c].kind in kinds and (by_id[c].kind == "context" or str(by_id[c].get("subject", by_id[c].get("source", ""))) in who or str(by_id[c].get("source", "")) in who))
	var is_night := func(c: Dictionary) -> bool:
		return (c.kind in NIGHT_KINDS or (c.kind == "report" and str(c.get("role", "")) in NIGHT_ROLES)) and int(c.get("night", -1)) >= 0
	if row_name == "walker":
		# The full movement model: one always-on connection that never merges.
		var mv: Array = held.filter(func(id): return is_night.call(by_id[id]) or by_id[id].kind in TRACE_KINDS)
		if not mv.is_empty():
			for id in mv:
				placed[id] = true
			out.append({"key": "movement", "ids": mv, "ctx": explain.call(mv, CONTEXT_KINDS), "kind": "movement"})
	else:
		var nights: Dictionary = {}
		for id in held:
			if is_night.call(by_id[id]):
				var k: int = int(by_id[id].night)
				if not nights.has(k):
					nights[k] = []
				nights[k].append(id)
		var night_keys: Array = nights.keys()
		night_keys.sort()
		for k in night_keys:
			for id in nights[k]:
				placed[id] = true
			out.append({"key": "night:%d" % k, "ids": nights[k], "ctx": explain.call(nights[k], ["claim", "secret_claim"]), "kind": "unit"})
		for id in held:
			if by_id[id].kind in TRACE_KINDS and not placed.has(id):
				placed[id] = true
				out.append({"key": "trace:" + id, "ids": [id], "ctx": context.filter(func(c): return by_id[c].kind == "context"), "kind": "unit"})
	# A day's Augur readings with that day's sightings, as one item: every reading of the day
	# (an honest one and an evil bluff, say) is read against the same day evidence, so no
	# reading loses it to card order (Codex, #144). Known work schedules are day evidence too
	# (Solver.augur_day_spec reads them), so they're context, and a day with work schedules
	# but no sightings still makes an item.
	var augur_days: Dictionary = {}
	for id in held:
		var c: Dictionary = by_id[id]
		if c.kind == "report" and str(c.get("role", "")) == "augur" and not placed.has(id):
			var day: int = int(c.get("observed_at", {}).get("day", -9))
			if not augur_days.has(day):
				augur_days[day] = []
			augur_days[day].append(id)
	var work_ctx: Array = context.filter(func(x): return by_id[x].kind == "context" and str(by_id[x].get("context_kind", "")) == "work")
	var augur_keys: Array = augur_days.keys()
	augur_keys.sort()
	for day in augur_keys:
		var same: Array = held.filter(func(x): return by_id[x].kind == "location" and int(by_id[x].get("day", -1)) == day and not placed.has(x))
		if same.is_empty() and work_ctx.is_empty():
			continue
		var ids: Array = augur_days[day] + same
		for x in ids:
			placed[x] = true
		var ctx: Array = explain.call(ids, ["claim"])
		for x in work_ctx:
			if not x in ctx:
				ctx.append(x)
		out.append({"key": "augur:%d" % day, "ids": ids, "ctx": ctx, "kind": "unit"})
	# A Psychologist reading with its statements (those not already in a movement pairing).
	for id in held:
		var c: Dictionary = by_id[id]
		if c.kind == "report" and str(c.get("role", "")) == "psychologist" and not placed.has(id):
			var ids: Array = [id]
			for s in c.get("data", {}).get("statements", []):
				var sid: String = str(s.get("fact_id", ""))
				if sid in held and not placed.has(sid) and by_id[sid].kind not in CONTEXT_KINDS:
					ids.append(sid)
			if ids.size() > 1:
				for x in ids:
					placed[x] = true
				out.append({"key": "psychologist:" + id, "ids": ids, "ctx": [], "kind": "unit"})
	for id in held:
		if not placed.has(id):
			out.append({"key": id, "ids": [id], "ctx": [], "kind": "card"})
	if row_name == "hexer":
		# The Hexer's day evidence, in one always-on connection (see the header).
		var day_cards: Array = held.filter(func(id): return by_id[id].kind in DAY_KINDS)
		if not day_cards.is_empty():
			out.append({"key": "day", "ids": day_cards, "ctx": context.filter(func(c): return by_id[c].kind == "context"), "kind": "day"})
	return out


## One refresh's working state: what every judgement shares, and the judgements made so far.
static func begin(view: Dictionary, case_data: Dictionary, listener: Dictionary) -> Dictionary:
	var self_id: String = str(listener.get("id", ""))
	var people: Array = Solver.person_ids(view)
	var others: Array = people.filter(func(p): return p != self_id)
	var run: Dictionary = {"view": view, "listener": listener, "people": people, "others": others, "memo": {}, "judgements": 0,
		"prior": {}, "baseline": {}, "impossible": false, "row": row(view)}
	if others.is_empty():
		return run
	run["bare"] = template(case_data, others[0])
	var started: int = Time.get_ticks_usec() if capture else 0
	var base: Dictionary = judge(view, run.bare, listener, [])
	run.judgements += 1
	if capture:
		_captured(run, "", 0, started, base.get("people", {}))
	for p in others:
		run.prior[p] = float(base.people.get(p, {}).get("prior", 0.0))
		run.baseline[p] = float(base.people.get(p, {}).get("posterior", 0.0))
	# Nothing fits what the listener already knows: no card can be read against it.
	run.impossible = bool(base.get("impossible", false))
	return run


static func _captured(run: Dictionary, key: String, cards: int, started: int, people: Dictionary) -> void:
	var chances: Array = []
	for p in run.others:
		chances.append(snappedf(float(people.get(p, {}).get("posterior", -1.0)), 1e-9))
	captured.append({"listener": str(run.listener.get("id", "")), "section": str(run.get("section", "baseline")), "key": key, "cards": cards,
		"usec": Time.get_ticks_usec() - started, "result": hash(chances)})


## lean(ids): how far the set moves each person from the baseline.
## Returns {"lean": {id: log-odds}, "impossible": bool}; one judgement per distinct set.
static func lean(run: Dictionary, ids: Array, hex: bool = false) -> Dictionary:
	var sorted: Array = ids.duplicate()
	sorted.sort()
	var key: String = ("hex|" if hex else "") + ",".join(PackedStringArray(sorted))
	if run.memo.has(key):
		return run.memo[key]
	var out: Dictionary = {"lean": {}, "chance": {}, "impossible": false}
	if not sorted.is_empty():
		var started: int = Time.get_ticks_usec() if capture else 0
		var ev: Dictionary = judge(run.view, run.bare, run.listener, sorted, hex)
		run.judgements += 1
		if capture:
			_captured(run, key, sorted.size(), started, ev.get("people", {}))
		if ev.get("impossible", false):
			# A set no world allows says nothing about anyone.
			out.impossible = true
		else:
			for p in run.others:
				out.chance[p] = float(ev.people.get(p, {}).get("posterior", run.baseline[p]))
				out.lean[p] = logit(out.chance[p]) - logit(run.baseline[p])
	run.memo[key] = out
	return out


## What a set of cards says given its context: lean(set + context) - lean(context).
## Returns {"lean": {id: log-odds} for everyone, "impossible": bool}.
static func set_value(run: Dictionary, ids: Array, ctx: Array) -> Dictionary:
	var outside: Array = ctx.filter(func(c): return c not in ids)
	var a: Dictionary = lean(run, _union(ids, outside))
	var b: Dictionary = lean(run, outside)
	if a.impossible or b.impossible:
		return {"lean": {}, "impossible": true}
	var out: Dictionary = {}
	for p in run.others:
		out[p] = float(a.lean.get(p, 0.0)) - float(b.lean.get(p, 0.0))
	return {"lean": out, "impossible": false}


## Several items as one set: {"ids": every card in them, "ctx": every context card}.
static func pool(item_list: Array) -> Dictionary:
	var ids: Array = []
	var ctx: Array = []
	for it in item_list:
		ids = _union(ids, it.ids)
		ctx = _union(ctx, it.get("ctx", []))
	return {"ids": ids, "ctx": ctx}


## The held cards the listener knows firsthand (sorted ids): its own readings, and
## (seed_wrong_sightings) a sighting of it on a night it knows it spent at home. That
## sighting is knowledge about its teller: "he says he saw me out, and I wasn't".
static func firsthand(by_id: Dictionary, held: Array, listener: Dictionary) -> Array:
	var self_id: String = str(listener.get("id", ""))
	var outings: Dictionary = listener.get("knowledge", {}).get("own_outings", {})
	var out: Array = []
	for id in held:
		var c: Dictionary = by_id[id]
		if c.kind == "report" and str(c.get("source", "")) == self_id:
			out.append(id)
		elif seed_wrong_sightings and c.kind == "sighting" and self_id in c.get("subjects", [c.get("subject", "")]):
			var night: String = str(c.get("night", -1))
			if outings.has(night) and not bool(outings[night]):
				out.append(id)
	out.sort()
	return out


## The keys of the items that seed the core: every item holding a firsthand card. A night
## (or, under a Walker reading, the movement connection) seeds it this way when it holds
## the listener's own Night Watch or Lamplighter report, or a wrong sighting of it. The
## Hexer's day connection never does: it only re-reads cards that sit elsewhere.
static func seed_keys(item_list: Array, firsthand_ids: Array) -> Array:
	var out: Array = []
	for it in item_list:
		if it.kind != "day" and it.ids.any(func(id): return id in firsthand_ids):
			out.append(it.key)
	return out


## Which items to test against the seed now: every candidate when the core is rebuilt (a
## new day, a changed seed, or no memory), otherwise only those with a newly held card.
## Always-on connections and the seed itself are never candidates.
## memory: {"day", "seed", "firsthand", "members", "known"} or {}.
## Returns {"rebuilt": bool, "test": [keys], "kept": [keys]}.
static func candidates(item_list: Array, seeds: Array, firsthand_ids: Array, memory: Dictionary, day: int) -> Dictionary:
	var rebuilt: bool = memory.is_empty() or int(memory.get("day", -99)) != day \
		or memory.get("seed", []) != seeds or memory.get("firsthand", []) != firsthand_ids
	var known: Dictionary = memory.get("known", {})
	var before: Array = memory.get("members", [])
	var test: Array = []
	var kept: Array = []
	for it in item_list:
		if it.kind in ALWAYS_ON or it.key in seeds:
			continue
		if rebuilt:
			test.append(it.key)
		elif it.key in before:
			kept.append(it.key)
		elif it.ids.any(func(id): return not known.has(id)):
			test.append(it.key)
	return {"rebuilt": rebuilt, "test": test, "kept": kept}


## The core's members after a round of tests (item order), and the memory to keep.
## tested: {key: interaction with the seed}. kept: members that stay untested.
static func membership(item_list: Array, kept: Array, tested: Dictionary, threshold: float = CORE_JOIN) -> Array:
	var out: Array = []
	for it in item_list:
		if it.key in kept or float(tested.get(it.key, -1.0)) >= threshold:
			out.append(it.key)
	return out


static func core_memory(day: int, seeds: Array, firsthand_ids: Array, members: Array, held: Array) -> Dictionary:
	var known: Dictionary = {}
	for id in held:
		known[id] = true
	return {"day": day, "seed": seeds.duplicate(), "firsthand": firsthand_ids.duplicate(), "members": members.duplicate(), "known": known}


static func _no_core(seeds: Array, firsthand_ids: Array) -> Dictionary:
	return {"seed": seeds, "firsthand": firsthand_ids, "members": [], "tested": {}, "clash": [], "lean": {}, "proved": {},
		"cards": 0, "rebuilt": true, "impossible": false}


## The listener's core on this refresh (see the header).
## values: {item key: value(run, item)}. core_state: {"day": int, "core": memory} or {}.
## Returns {"seed", "firsthand", "members": [keys], "tested": {key: interaction},
## "clash": [keys no world allows beside the seed], "lean": {id: log-odds the core adds},
## "proved": {id: chance}, "cards": int, "rebuilt": bool, "impossible": bool, "memory"}.
static func core(run: Dictionary, by_id: Dictionary, item_list: Array, values: Dictionary, held: Array, core_state: Dictionary) -> Dictionary:
	var day: int = int(core_state.get("day", -1))
	var memory: Dictionary = core_state.get("core", {})
	var first: Array = firsthand(by_id, held, run.listener)
	var seeds: Array = seed_keys(item_list, first)
	var out: Dictionary = _no_core(seeds, first)
	out["memory"] = core_memory(day, seeds, first, [], held)
	if seeds.is_empty():
		return out
	var by_key: Dictionary = {}
	for it in item_list:
		by_key[it.key] = it
	# What the firsthand cards prove by themselves stays proved.
	var own: Dictionary = lean(run, first)
	if not own.impossible:
		for p in run.others:
			var settled: bool = run.baseline[p] <= FIXED or run.baseline[p] >= 1.0 - FIXED
			if not settled and (own.chance[p] <= FIXED or own.chance[p] >= 1.0 - FIXED):
				out.proved[p] = own.chance[p]
	var seed_set: Dictionary = pool(seeds.map(func(k): return by_key[k]))
	var seed_value: Dictionary = set_value(run, seed_set.ids, seed_set.ctx)
	if seed_value.impossible:
		# Its own knowledge doesn't fit together: nothing can be weighed against it.
		out.impossible = true
		return out
	var plan: Dictionary = candidates(item_list, seeds, first, memory, day)
	out.rebuilt = plan.rebuilt
	for key in plan.test:
		var it: Dictionary = by_key[key]
		var joint: Dictionary = set_value(run, _union(seed_set.ids, it.ids), _union(seed_set.ctx, it.ctx))
		if joint.impossible or values[key].impossible:
			out.clash.append(key)
			continue
		var most := 0.0
		for p in run.others:
			most = maxf(most, absf(float(joint.lean[p]) - float(seed_value.lean[p]) - float(values[key].lean.get(p, 0.0))))
		out.tested[key] = most
	out.members = membership(item_list, plan.kept, out.tested)
	out.memory = core_memory(day, seeds, first, out.members, held)
	var keys: Array = seeds + out.members
	var all: Dictionary = pool(keys.map(func(k): return by_key[k]))
	out.cards = all.ids.size()
	if keys.size() < 2:
		return out
	var together: Dictionary = set_value(run, all.ids, all.ctx)
	if together.impossible:
		out.impossible = true
		return out
	for p in run.others:
		var beyond: float = float(together.lean[p])
		for k in keys:
			beyond -= float(values[k].lean.get(p, 0.0))
		if not is_zero_approx(beyond):
			out.lean[p] = beyond
	return out


## An item's value: {"lean": {id: log-odds}, "impossible": bool}.
static func value(run: Dictionary, item: Dictionary) -> Dictionary:
	var ids: Array = item.ids
	var outside: Array = item.get("ctx", []).filter(func(c): return c not in ids)
	var full: Array = _union(ids, outside)
	var a: Dictionary
	var b: Dictionary
	if item.kind == "day":
		# What the Hexer factor adds on the day cards: the same set with it on and off.
		a = lean(run, full, true)
		b = lean(run, full, false)
	else:
		a = lean(run, full)
		b = lean(run, outside)
	if a.impossible or b.impossible:
		return {"lean": {}, "impossible": true}
	var out: Dictionary = {}
	for p in run.others:
		var moved: float = float(a.lean.get(p, 0.0)) - float(b.lean.get(p, 0.0))
		if not is_zero_approx(moved):
			out[p] = moved
	return {"lean": out, "impossible": false}


## One belief refresh under connections: everyone's chance of being evil from the cards in
## `held` (ids, the listener's held cards with the ones it rejects from its own knowledge
## already taken out). `listener` is the evaluator's listener (Jury._eval_listener) with no
## challenges applied.
## core_state: {"day": int, "core": the core's memory from this listener's last refresh,
## "cases": the stored cases (see case_plan)} (the listener's `connections`), or {} to
## build the core afresh with no stored case. With stored cases the listener also needs
## `trust` (and `player_credibility` if it has one): a case weighs what its presenter does.
## Returns {"prior", "baseline", "posterior": {id: chance}, "shift": log-odds, "row",
## "impossible": bool, "items": [{"key", "kind", "cards", "ctx", "lean": {id: log-odds}}],
## "core": see core() (without its memory), "core_memory": what to keep for the next
## refresh, "cases": see cases(), "judgements": int}.
static func refresh(view: Dictionary, case_data: Dictionary, listener: Dictionary, held: Array, core_state: Dictionary = {}) -> Dictionary:
	# Profiling (opt-in, workshop/profiler.gd): one span for the model, one for each part.
	var span: int = Profiler.open("connections")
	var kept_before: int = int(cache_stats.hits)
	var part: int = Profiler.open("baseline")
	var run: Dictionary = begin(view, case_data, listener)
	Profiler.close(part)
	var others: Array = run.others
	var baseline: Dictionary = run.baseline
	if others.is_empty() or run.impossible:
		Profiler.count("connections_judgements", int(run.judgements))
		Profiler.count("connections_kept", int(cache_stats.hits) - kept_before)
		Profiler.close(span)
		return {"prior": run.prior, "baseline": baseline, "posterior": run.prior.duplicate(), "shift": 0.0, "row": run.row,
			"impossible": run.impossible, "items": [], "core": _no_core([], []), "core_memory": core_state.get("core", {}),
			"cases": {"lean": {}, "entries": [], "floors": [], "challenged": challenged_ids(core_state.get("cases", []))}, "judgements": run.judgements}
	var by_id: Dictionary = {}
	for c in view.cards:
		by_id[c.id] = c
	var ids: Array = held.filter(func(id): return by_id.has(id))
	ids.sort()
	var total: Dictionary = {}
	for p in others:
		total[p] = 0.0
	var entries: Array = []
	var item_list: Array = items(by_id, ids, run.people, run.row)
	var values: Dictionary = {}
	part = Profiler.open("items")
	run["section"] = "items"
	for it in item_list:
		var v: Dictionary = value(run, it)
		values[it.key] = v
		var entry: Dictionary = {"key": it.key, "kind": it.kind, "cards": it.ids, "ctx": it.ctx, "lean": v.lean}
		if v.impossible:
			entry["impossible"] = true
		for p in v.lean:
			total[p] += float(v.lean[p])
		entries.append(entry)
	Profiler.close(part)
	# The core: what the listener's own knowledge and the cards tied to it say together,
	# beyond their own values.
	part = Profiler.open("core")
	run["section"] = "core"
	var own: Dictionary = core(run, by_id, item_list, values, ids, core_state)
	Profiler.close(part)
	var memory: Dictionary = own.memory
	own.erase("memory")
	for p in own.lean:
		total[p] += float(own.lean[p])
	# Stored cases: what each says together beyond its cards' own values, at its weight.
	run["by_id"] = by_id
	part = Profiler.open("cases")
	run["section"] = "cases"
	var told: Dictionary = cases(run, item_list, values, own, core_state.get("cases", []), int(core_state.get("day", -1)))
	Profiler.close(part)
	for p in told.lean:
		total[p] += float(told.lean[p])
	var settled: Dictionary = combine(others, baseline, total, own.proved)
	Profiler.count("connections_judgements", int(run.judgements))
	Profiler.count("connections_kept", int(cache_stats.hits) - kept_before)
	Profiler.close(span)
	return {"prior": run.prior, "baseline": baseline, "posterior": settled.posterior, "shift": settled.shift, "row": run.row, "impossible": false,
		"items": entries, "core": own, "core_memory": memory, "cases": told, "judgements": run.judgements}


## Everyone's chance from the baseline and the summed leans: one common shift, so the people
## still in question keep the sum the baseline gave them (the evil count) less whatever the
## listener's own knowledge has proved. People the baseline settles stay where they are, and
## proved people keep their proved chance.
## Returns {"posterior": {id: chance}, "shift": log-odds}.
static func combine(others: Array, baseline: Dictionary, total: Dictionary, proved: Dictionary = {}) -> Dictionary:
	var open: Array = others.filter(func(p): return baseline[p] > FIXED and baseline[p] < 1.0 - FIXED)
	var free: Array = open.filter(func(p): return not proved.has(p))
	var target := 0.0
	for p in open:
		target += float(baseline[p]) - float(proved.get(p, 0.0))
	var scores: Array = []
	for p in free:
		scores.append(logit(baseline[p]) + float(total.get(p, 0.0)))
	var shift: float = common_shift(scores, maxf(target, 0.0)) if not free.is_empty() else 0.0
	var posterior: Dictionary = {}
	for p in others:
		posterior[p] = float(proved[p]) if p in open and proved.has(p) else float(baseline[p])
	for i in range(free.size()):
		posterior[free[i]] = chance(float(scores[i]) + shift)
	return {"posterior": posterior, "shift": shift}


# ------------------------------------------------------------------ stored cases

## How far the listener takes a presenter's word: its trust in the Demonologist (the
## player's credibility, where the listener keeps one), or in the NPC.
static func presenter_trust(listener: Dictionary, presenter: String) -> float:
	if presenter == "player":
		return clampf(float(listener.get("player_credibility", listener.get("trust", 0.5))), 0.0, 1.0)
	return clampf(float(listener.get("npc_trust", {}).get(presenter, 0.5)), 0.0, 1.0)


## A stored case's weight on `day`: trust in its presenter, times `fade` for each day since
## it was presented, halved (Tuning.Workshop.SUSPICIOUS_HEARING) under a "suspicious"
## premise. Presenting it again restores it: the store keeps the latest day.
static func case_weight(listener: Dictionary, cs: Dictionary, day: int, fade: float = CASE_FADE) -> float:
	var w: float = presenter_trust(listener, str(cs.get("presenter", ""))) * pow(fade, maxi(0, day - int(cs.get("day", day))))
	if cs.get("suspicious", false):
		w *= Tuning.Workshop.SUSPICIOUS_HEARING
	return w


## The weight a "suspicious" premise holds back from a case (the half it isn't heard at), 0
## for any other premise. What the case would add at this weight is what presses its
## subject to explain (game/workshop_presentation.gd).
static func case_withheld(listener: Dictionary, cs: Dictionary, day: int, fade: float = CASE_FADE) -> float:
	if not cs.get("suspicious", false):
		return 0.0
	return presenter_trust(listener, str(cs.get("presenter", ""))) * pow(fade, maxi(0, day - int(cs.get("day", day)))) * (1.0 - Tuning.Workshop.SUSPICIOUS_HEARING)


## The store rule for an NPC nominator's cases (the player's presentations keep their own
## store): a case from the same presenter with the same premise and target replaces the
## earlier one, and one too old to count at any trust is dropped.
## cs: {"key", "presenter", "target", "type", "cards": [ids], "day"}.
static func stored_with(list: Array, cs: Dictionary, day: int) -> Array:
	var out: Array = []
	for x in list:
		var replaced: bool = x.presenter == cs.presenter and x.get("target", "") == cs.get("target", "") and x.get("type", "") == cs.get("type", "")
		if not replaced and pow(CASE_FADE_BOUGHT, maxi(0, day - int(x.get("day", day)))) >= CASE_FLOOR:
			out.append(x)
	out.append(cs)
	return out


## The stored cases that count now, oldest first, and what each brings to be judged
## together: the items its held cards sit in (`keys`), and the single cards it cites from
## an always-on connection (`extra`), which never merge.
## case_list: [{"key", "presenter", "day", "cards": [ids], "suspicious": bool,
## "challenges": {reading id: challenge}, "type", "target"}].
## A case is left out when a later case from the same presenter cites every card it cites:
## the later one has taken its place (its key is listed in the later one's "replaces"),
## and the set counts once, at the later case's weight.
## Returns [{"key", "presenter", "day", "weight", "keys", "extra", "challenges", "replaces"}].
## rate_of: when given, called with {"keys", "extra", "challenges", "weight": the case's
## weight the day it was presented} for a case from an earlier day, and returns the share
## of its weight it keeps a day (buy-in; cases() passes it). Without it, `fade` for all.
static func case_plan(case_list: Array, item_list: Array, listener: Dictionary, day: int, fade: float = CASE_FADE, rate_of: Callable = Callable()) -> Array:
	var item_of: Dictionary = {}
	var kind_of: Dictionary = {}
	for it in item_list:
		kind_of[it.key] = it.kind
		if it.kind == "day":
			continue  # its cards belong to their night or Augur day; it only adds the Hexer factor
		for id in it.ids:
			item_of[id] = it.key
	var order: Array = range(case_list.size())
	order.sort_custom(func(a, b): return int(case_list[a].get("day", 0)) < int(case_list[b].get("day", 0)) or (int(case_list[a].get("day", 0)) == int(case_list[b].get("day", 0)) and a < b))
	var out: Array = []
	for i in order:
		var cs: Dictionary = case_list[i]
		var keys: Array = []
		var extra: Array = []
		for id in cs.get("cards", []):
			if not item_of.has(id):
				continue  # a card the listener doesn't hold (or rejects) isn't weighed
			var key: String = item_of[id]
			if kind_of[key] in ALWAYS_ON:
				if id not in extra:
					extra.append(id)
			elif key not in keys:
				keys.append(key)
		if keys.is_empty() and extra.is_empty():
			continue
		var rate: float = fade
		if rate_of.is_valid() and int(cs.get("day", day)) < day:
			rate = float(rate_of.call({"keys": keys, "extra": extra, "challenges": cs.get("challenges", {}), "weight": case_weight(listener, cs, day, 1.0)}))
		var w: float = case_weight(listener, cs, day, rate)
		if w < CASE_FLOOR:
			continue
		out.append({"key": str(cs.get("key", "")), "presenter": str(cs.get("presenter", "")), "day": int(cs.get("day", day)), "weight": w, "rate": rate,
			"keys": keys, "extra": extra, "challenges": cs.get("challenges", {}), "replaces": [], "cited": cs.get("cards", []),
			"suspicious": bool(cs.get("suspicious", false)), "withheld": case_withheld(listener, cs, day, fade)})
	# Oldest first, so a later entry is a later case.
	var kept: Array = []
	for i in range(out.size()):
		var by: int = -1
		for j in range(i + 1, out.size() if reuse_rule else 0):
			# Only a case that counts at least as much takes the earlier one's place. A weaker
			# one (a "suspicious" premise on cards already argued firmly, say) leaves it where it
			# is and adds only what is new (case_step), so the cards keep the larger weight.
			if out[j].presenter == out[i].presenter and out[j].weight >= out[i].weight and out[i].cited.all(func(id): return id in out[j].cited):
				by = j
		if by < 0:
			kept.append(out[i])
		else:
			out[by].replaces.append(out[i].key)
			out[by].replaces.append_array(out[i].replaces)
	for entry in kept:
		entry.erase("cited")
	return kept


## Every reading some stored case challenges, counted or not: with the model on, those
## challenges act through their case alone.
static func challenged_ids(case_list: Array) -> Array:
	var out: Array = []
	for cs in case_list:
		for id in cs.get("challenges", {}):
			if id not in out:
				out.append(id)
	return out


## What a set says when judged together with some of its readings challenged: the
## challenges are assessed on this set alone (their grounds must be in it), and an accepted
## "misled" or "failed gift" discounts the reading here and nowhere else. A "lying"
## challenge changes no reliability; its result still feeds the floor under its teller.
## Returns {"lean", "chance", "impossible", "results": the challenges' assessments}.
static func lean_challenged(run: Dictionary, ids: Array, challenges: Dictionary) -> Dictionary:
	var named: Dictionary = {}
	for id in challenges:
		if id in ids:
			named[id] = challenges[id]
	if named.is_empty():
		var plain: Dictionary = lean(run, ids).duplicate()
		plain["results"] = []
		return plain
	var sorted: Array = ids.duplicate()
	sorted.sort()
	var assessed: Dictionary = ReadingChallenges.assess(run.view, {"reading_challenges": named}, run.listener, sorted.map(func(id): return run.by_id[id]))
	# The case's challenges also go on the judged case itself, as they do today: CaseEval
	# leaves a challenged reading out of the Augur crossing and the Psychologist
	# corroboration (case_data.reading_challenges), whatever the challenge's verdict.
	var names: Array = named.keys()
	names.sort()
	var key: String = ",".join(PackedStringArray(sorted)) + "|challenged:" + ",".join(PackedStringArray(names)) + "|" + str(hash([assessed.reports, assessed.sources]))
	if not run.memo.has(key):
		var listener: Dictionary = run.listener.duplicate()
		if not (assessed.reports.is_empty() and assessed.sources.is_empty()):
			listener["challenge_reports"] = assessed.reports
			listener["challenge_sources"] = assessed.sources
		var template: Dictionary = run.bare.duplicate(true)
		template["reading_challenges"] = named.duplicate(true)
		var out: Dictionary = {"lean": {}, "chance": {}, "impossible": false}
		var started: int = Time.get_ticks_usec() if capture else 0
		var ev: Dictionary = judge(run.view, template, listener, sorted)
		run.judgements += 1
		if capture:
			_captured(run, key, sorted.size(), started, ev.get("people", {}))
		if ev.get("impossible", false):
			out.impossible = true
		else:
			for p in run.others:
				out.chance[p] = float(ev.people.get(p, {}).get("posterior", run.baseline[p]))
				out.lean[p] = logit(out.chance[p]) - logit(run.baseline[p])
		run.memo[key] = out
	var found: Dictionary = run.memo[key].duplicate()
	found["results"] = assessed.results
	return found


## A joint set's interaction: what its items and the cards cited from an always-on
## connection say together, less what each item says by itself and what the cited cards
## say together. The always-on connection already weighs its cards together, in full, so a
## case adds nothing for their meeting each other: only for their meeting the rest.
## Returns {"lean": {id: log-odds} for everyone, "impossible", "results", "cards": int}.
static func interaction(run: Dictionary, by_key: Dictionary, values: Dictionary, keys: Array, extra: Array = [], challenges: Dictionary = {}) -> Dictionary:
	var set_: Dictionary = pool(keys.map(func(k): return by_key[k]))
	# A cited card that already sits in one of the items (a core that holds the movement
	# connection) is counted there.
	extra = extra.filter(func(id): return id not in set_.ids)
	var ids: Array = _union(extra, set_.ids)
	var zero: Dictionary = {}
	for p in run.others:
		zero[p] = 0.0
	# A case of only always-on cards adds nothing for their meeting, but its challenges are
	# still assessed (their discount and the floor under a teller; Codex on #151).
	if keys.size() + ((0 if extra.is_empty() else 1) if held_together_rule else extra.size()) < 2 and challenges.is_empty():
		return {"lean": zero, "impossible": false, "results": [], "cards": ids.size()}
	var outside: Array = set_.ctx.filter(func(c): return c not in ids)
	var together: Dictionary = lean_challenged(run, _union(ids, outside), challenges)
	var context: Dictionary = lean(run, outside)
	var cited: Dictionary = {"lean": zero.duplicate(), "impossible": false}
	if held_together_rule:
		if not extra.is_empty():
			cited = lean(run, extra)
	else:
		# Before the rule: each cited card's own value, so their meeting counted again.
		for id in extra:
			var alone: Dictionary = lean(run, [id])
			cited.impossible = cited.impossible or alone.impossible
			for p in run.others:
				cited.lean[p] += float(alone.lean.get(p, 0.0))
	if together.impossible or context.impossible or cited.impossible:
		return {"lean": zero, "impossible": true, "results": together.get("results", []), "cards": ids.size()}
	var out: Dictionary = {}
	for p in run.others:
		var x: float = float(together.lean.get(p, 0.0)) - float(context.lean.get(p, 0.0)) - float(cited.lean.get(p, 0.0))
		for k in keys:
			x -= float(values[k].lean.get(p, 0.0))
		out[p] = x
	return {"lean": out, "impossible": false, "results": together.results, "cards": ids.size()}


## The rules for what one stored case adds, as joint sets to weigh: the case adds
## (its weight times) the sum of sign x interaction(keys, extra, challenges) over `terms`.
## - A case that shares an item with the set the core judges together is judged with it,
##   and the set grows by the case.
## - A case adds nothing for what an earlier counted case from the same presenter already
##   put together: the interaction of the items both cite is taken off, so only what
##   involves an item new from this presenter counts.
## state: {"keys", "extra", "challenges": the core's growing set, "seen": {presenter:
## {"keys", "extra"}}} (case_state). Returns {"merged", "shared": how many of its items an
## earlier case of the presenter's held, "terms": [[sign, keys, extra, challenges]],
## "next": the state once this case has counted}.
static func case_step(state: Dictionary, cs: Dictionary) -> Dictionary:
	var seen: Dictionary = state.seen.get(cs.presenter, {"keys": [], "extra": []})
	var shared_keys: Array = cs.keys.filter(func(k): return reuse_rule and k in seen["keys"])
	var shared_extra: Array = cs.extra.filter(func(id): return reuse_rule and id in seen["extra"])
	var touches: bool = not state["keys"].is_empty() and cs.keys.any(func(k): return k in state["keys"])
	var next: Dictionary = state.duplicate()
	next["seen"] = state.seen.duplicate()
	next.seen[cs.presenter] = {"keys": _union(seen["keys"], cs.keys), "extra": _union(seen["extra"], cs.extra)}
	var terms: Array = []
	if touches:
		next["keys"] = _union(state["keys"], cs.keys)
		next["extra"] = _union(state["extra"], cs.extra)
		next["challenges"] = state.challenges.merged(cs.challenges)
		terms.append([1.0, next["keys"], next["extra"], next.challenges])
		terms.append([-1.0, state["keys"], state["extra"], state.challenges])
		# What an earlier case of the presenter's put together outside the core is taken off
		# on its own: the core's items meeting those shared ones were never weighed (Codex on
		# #150). Shared items already in the core are counted in the core's term.
		var outside_keys: Array = shared_keys.filter(func(k): return k not in state["keys"])
		var outside_extra: Array = shared_extra.filter(func(id): return id not in state["extra"])
		if not (outside_keys.is_empty() and outside_extra.is_empty()):
			terms.append([-1.0, outside_keys, outside_extra, cs.challenges])
	else:
		terms.append([1.0, cs.keys, cs.extra, cs.challenges])
		if not (shared_keys.is_empty() and shared_extra.is_empty()):
			terms.append([-1.0, shared_keys, shared_extra, cs.challenges])
	return {"merged": touches, "shared": shared_keys.size() + shared_extra.size(), "terms": terms, "next": next}

static func case_state(core_keys: Array) -> Dictionary:
	return {"keys": core_keys.duplicate(), "extra": [], "challenges": {}, "seen": {}}


## The share of its weight a case from an earlier day keeps a day (buy-in): CASE_FADE for
## one that moves this listener little, up to CASE_FADE_BOUGHT for one that moves it by
## CASE_BUYIN_FULL or more. The move is the largest its cards make together on anyone,
## standing alone, at the weight it had the day it was presented. Nothing is stored: it is
## read again at each refresh, so it follows what the listener holds now.
## c: {"keys", "extra", "challenges", "weight"}.
static func buy_in_rate(run: Dictionary, by_key: Dictionary, values: Dictionary, c: Dictionary) -> float:
	var alone: Dictionary = interaction(run, by_key, values, c["keys"], c["extra"], c["challenges"])
	if alone.impossible:
		return CASE_FADE
	var move: float = 0.0
	for p in alone.lean:
		move = maxf(move, absf(float(alone.lean[p])))
	return lerpf(CASE_FADE, CASE_FADE_BOUGHT, clampf(float(c["weight"]) * move / CASE_BUYIN_FULL, 0.0, 1.0))


## What the stored cases add (see the header; case_plan and case_step hold the rules).
## own: this refresh's core (core()). case_list, day: the listener's stored cases and today.
## Returns {"lean": {id: log-odds added}, "entries": [{"key", "presenter", "day", "weight",
## "merged": judged with the core, "cards": how many were judged together, "shared": how
## many of its items an earlier case of the presenter's already held, "replaces": the keys
## of the earlier cases it took the place of, "lean": what this case added, "withheld": for
## a "suspicious" case, what its held-back half would add standing alone}], "floors": [a
## challenge's assessment with its case's "weight" and "case"], "challenged":
## challenged_ids(case_list)}.
static func cases(run: Dictionary, item_list: Array, values: Dictionary, own: Dictionary, case_list: Array, day: int) -> Dictionary:
	var out: Dictionary = {"lean": {}, "entries": [], "floors": [], "challenged": challenged_ids(case_list)}
	if case_list.is_empty():
		return out
	var by_key: Dictionary = {}
	for it in item_list:
		by_key[it.key] = it
	# The set the core judges together grows as cases that touch it merge in.
	var state: Dictionary = case_state([] if own.get("impossible", false) else own.get("seed", []) + own.get("members", []))
	var total: Dictionary = {}
	for cs in case_plan(case_list, item_list, run.listener, day, CASE_FADE, (func(c): return buy_in_rate(run, by_key, values, c)) if buy_in else Callable()):
		var step: Dictionary = case_step(state, cs)
		var entry: Dictionary = {"key": cs.key, "presenter": cs.presenter, "day": cs.day, "weight": cs.weight, "rate": cs.rate, "merged": step.merged, "cards": 0,
			"shared": step.shared, "replaces": cs.replaces, "lean": {}}
		var added: Dictionary = {}
		var impossible: bool = false
		var results: Array = []
		for i in range(step.terms.size()):
			var term: Array = step.terms[i]
			var joint: Dictionary = interaction(run, by_key, values, term[1], term[2], term[3])
			if i == 0:
				entry.cards = int(joint.cards)
				results = joint.results
			if joint.impossible:
				impossible = true
				break
			for p in run.others:
				added[p] = float(added.get(p, 0.0)) + float(term[0]) * float(joint.lean[p])
		if impossible:
			# No world allows these cards together: the case says nothing as a whole.
			entry["impossible"] = true
		else:
			state = step.next
			for p in added:
				var x: float = cs.weight * float(added[p])
				if not is_zero_approx(x):
					entry.lean[p] = x
					total[p] = float(total.get(p, 0.0)) + x
		if float(cs.withheld) > 0.0 and not impossible:
			# What a "suspicious" case would add with its held-back half, standing alone,
			# whatever an earlier case already holds of its cards.
			var alone: Dictionary = interaction(run, by_key, values, cs.keys, cs.extra, cs.challenges)
			if not alone.impossible:
				entry["withheld"] = {}
				for p in run.others:
					var x: float = float(cs.withheld) * float(alone.lean[p])
					if not is_zero_approx(x):
						entry.withheld[p] = x
		for result in results:
			if cs.challenges.has(result.card):
				var floor_entry: Dictionary = result.duplicate()
				floor_entry["weight"] = cs.weight
				floor_entry["case"] = cs.key
				out.floors.append(floor_entry)
		out.entries.append(entry)
	out.lean = total
	return out


## Today's evaluation with everyone's chances replaced by the connections result, so the
## code after it (belief to suspicion, who to hang first, reasons) reads the new chances.
static func overlay(ev: Dictionary, result: Dictionary) -> Dictionary:
	var out: Dictionary = ev.duplicate(true)
	out["impossible"] = bool(result.get("impossible", false))
	var people: Dictionary = out.get("people", {})
	for p in result.posterior:
		people[p] = {"prior": result.prior[p], "posterior": result.posterior[p]}
	out["people"] = people
	return out


## A short form of the breakdown for the dev log: each item and the largest lean it gives.
static func summary(result: Dictionary) -> Dictionary:
	var out: Array = []
	for it in result.get("items", []):
		var top: String = ""
		var size: float = 0.0
		for p in it.lean:
			if absf(float(it.lean[p])) > absf(size):
				size = float(it.lean[p])
				top = p
		out.append({"key": it.key, "kind": it.get("kind", "card"), "cards": it.cards.size(), "on": top, "lean": snappedf(size, 0.001)})
	var short: Dictionary = {"items": out, "row": str(result.get("row", "")), "judgements": int(result.get("judgements", 0)), "shift": snappedf(float(result.get("shift", 0.0)), 0.001)}
	var own: Dictionary = result.get("core", {})
	if not own.get("seed", []).is_empty():
		var top: String = ""
		var size: float = 0.0
		for p in own.lean:
			if absf(float(own.lean[p])) > absf(size):
				size = float(own.lean[p])
				top = p
		short["core"] = {"seed": own.seed, "members": own.members, "cards": int(own.cards), "on": top, "lean": snappedf(size, 0.001),
			"rebuilt": bool(own.rebuilt), "proved": own.proved.keys()}
		if own.impossible:
			short.core["impossible"] = true
	var told: Array = []
	for entry in result.get("cases", {}).get("entries", []):
		var top_c: String = ""
		var size_c: float = 0.0
		for p in entry.lean:
			if absf(float(entry.lean[p])) > absf(size_c):
				size_c = float(entry.lean[p])
				top_c = p
		told.append({"key": entry.key, "presenter": entry.presenter, "day": int(entry.day), "weight": snappedf(float(entry.weight), 0.001), "merged": bool(entry.merged),
			"cards": int(entry.cards), "on": top_c, "lean": snappedf(size_c, 0.001)})
	if not told.is_empty():
		short["cases"] = told
	return short

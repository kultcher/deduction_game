## Offline prototype of the "connections" belief design (Phase 4 of the belief-model
## direction; project doc `claude/belief-model-direction-2026-11-10.md`, "Phase 4 spec" and
## "Decisions, Nov 10 evening").
##
## It replays a dev log and, at chosen moments, computes what each good listener WOULD
## believe if cards were weighed as connections instead of through the attention view. It
## reads game state only: nothing here is called by the game, draws from the world RNG or
## writes to a mind. The game's own beliefs, votes and replies are untouched.
##
##   godot --headless --path . --script res://tools/connections_prototype.gd -- <log.jsonl>
##         [--out results.json] [--declare auto|none|walker|hexer] [--listener a,b] [--quiet] [--check]
##         [--explain listener:person:day] [--fade 0.5,0.7,0.85] [--cap N]
##         [--no-wrong-sightings] [--no-proofs] [--legacy-seed [--movement-seed]]
##
## --explain: at that listener's dawn, which cards carry the read-everything belief about
## that person (what it loses without each, and the smallest build-up that reaches it), and
## which of them the prototype judges together.
##
## The judge is today's shared evaluator (CaseEval over the possible worlds) run on a chosen
## set of cards: for one listener and one set it gives everyone's chance of being evil and of
## being the Demon. Everything below is arithmetic on its answers.
##
##   baseline      the judge on no cards (the listener's standing suspicion, the public
##                 record and knowing it is good are in every run)
##   lean(S)       how far set S moves a person from the baseline, in log-odds
##   solo value    every held card counts once, alone
##   units         structural pairings judged as one card: a night's sightings, alibis and
##                 Lamplighter or Night Watch reports; an Augur reading with that day's
##                 sightings; a Psychologist reading with its statements; a trace with
##                 profile context. A unit's context (claims, confessed secrets, profile
##                 cards) explains it without joining sets together.
##   core          the listener's own knowledge (the seed) judged together with every card or
##                 unit whose interaction with the seed reaches the threshold. Rebuilt on
##                 the first moment of each day; a newly held card is tested on arrival.
##                 The seed, the test and the membership rule are the game's
##                 (Connections.firsthand, seed_keys, candidates, membership); here they run
##                 at several thresholds at once. The seed is every item holding one of the
##                 listener's own readings, or a sighting of it on a night it knows it was
##                 home (--no-wrong-sightings leaves those out). What the firsthand cards
##                 prove by themselves stays proved (--no-proofs: softened to the clip, as
##                 the first prototype did). --legacy-seed is the first prototype's seed:
##                 own readings that sit alone, plus with --movement-seed the night or
##                 movement connection holding an own Night Watch or Lamplighter report.
##   stored cases  a presented case (the player's, or an NPC nominator's cited cards) is a
##                 connection: judged together, merged with the core when they share a card,
##                 and scaled by trust in the presenter. An old case fades: each day it keeps
##                 --fade of its weight (several rates are reported; the first is the main
##                 one). A revision replaces its earlier version. --cap N restores the old
##                 "at most N" rule. Which cases count, in what order and at what weight is
##                 the game's rule (Connections.case_plan). The tool reads the player's
##                 public presentations and NPC nominators' cited cards from the log; it
##                 doesn't see private presentations, and it doesn't weigh the challenges
##                 inside a case (the game does both).
##   caching       solo values and core tests are meant to be cached. Each refresh is
##                 compared with the listener's previous one that day: which items a trust
##                 change, a hearing-weight change or the public record would have
##                 invalidated, and how far the others drifted anyway.
##   combining     baseline + solo values + the core's interaction + each case's scaled
##                 interaction, then one common shift so the chances sum to the baseline's
##                 (the evil count; 1 for the Demon).
##   movement      how it is read follows the town's demon mix (Connections.row). Walker
##                 (declared, or a walker-only script): every movement card forms one
##                 always-on connection that never merges. No declaration on a two-kind
##                 script: the per-night units, with the Hexer factor off. Hexer: the
##                 per-night units, plus the Hexer's day evidence as one always-on day
##                 connection. --declare walker|hexer stands in for a declaration; none
##                 forces the per-night reading.
##
## Moments evaluated: the first command of each day ("dawn", every living good NPC), each
## vote (every good voter, on the nominee) and each public presentation of a filed case
## (with and without that case, on the state just after it).
##
## Output: a summary on stdout and, with --out, every record as JSON for analysis.
extends SceneTree
const Replay = preload("res://tools/log_replay.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Ownership = preload("res://game/workshop_ownership.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Jury = preload("res://workshop/jury.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const Mind = preload("res://sim/mind.gd")
## The in-game model (Phase 6). The tool's judge and its log-odds go through it, so the
## offline numbers and the game's can't drift apart.
const Connections = preload("res://workshop/connections.gd")

const THETAS = [0.2, 0.3, 0.4, 0.8]
const CLIP = Connections.CLIP
const DEMON_CLIP = 0.002
const FIXED = Connections.FIXED
## A stored case whose weight has faded below this no longer counts.
const CASE_FLOOR = 0.05
## A trace "matches" a person when, read with the profile cards, it moves them this far.
const TRACE_MATCH = 0.1
## A cached value counts as changed beyond this (log-odds).
const CACHE_TOLERANCE = 0.02
const CONTEXT_KINDS = Connections.CONTEXT_KINDS
const NIGHT_KINDS = Connections.NIGHT_KINDS
const NIGHT_ROLES = Connections.NIGHT_ROLES
const TRACE_KINDS = Connections.TRACE_KINDS
## Item kinds that are always on and never merge: the movement and day connections.
const ALWAYS_ON = Connections.ALWAYS_ON

## Each day a stored case keeps this share of its weight; the first is the main rate.
var fades: Array = [0.5, 0.7, 0.85]
## 0: no cap on stored cases (they fade). N: the old rule, at most N per listener.
var cap := 0
## --legacy-seed: the first prototype's seed (see the header). With it, --movement-seed: a
## Night Watch's or Lamplighter's own readings seed its core (with the unit they sit in).
var legacy_seed := false
var movement_seed := false
## --no-proofs: what the firsthand cards prove alone can still be argued away.
var proofs := true
## Per listener: the last refresh's per-item values and what they depended on.
var cache_seen: Dictionary = {}
var now_seq := 0
var quiet := false
var check := false
## --explain listener:person:day entries.
var explain: Array = []
var declare := "auto"
var only_listeners: Array = []
var records: Array = []
## Per listener: {theta: {"day", "members": {item key: true}, "known": {card id: true}}}.
var cores: Dictionary = {}
## Per listener: stored cases, oldest first.
var stores: Dictionary = {}
var judge_calls := 0

func _init():
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: connections_prototype.gd <log.jsonl> [--out results.json] [--declare auto|none|walker|hexer] [--listener a,b] [--quiet]")
		quit(1)
		return
	var out_path := ""
	var i := 1
	while i < args.size():
		match args[i]:
			"--out":
				out_path = args[i + 1]; i += 1
			"--declare":
				declare = args[i + 1]; i += 1
			"--listener":
				only_listeners = Array(str(args[i + 1]).split(",")); i += 1
			"--quiet":
				quiet = true
			"--fade":
				fades = Array(str(args[i + 1]).split(",")).map(func(x): return float(x)); i += 1
			"--cap":
				cap = int(args[i + 1]); i += 1
			"--movement-seed":
				movement_seed = true
			"--legacy-seed":
				legacy_seed = true
			"--no-wrong-sightings":
				Connections.seed_wrong_sightings = false
			"--no-proofs":
				proofs = false
			"--check":
				check = true
			"--explain":
				explain.append(str(args[i + 1]).split(":")); i += 1
		i += 1
	var events: Array = Replay.load_events(args[0])
	_run(events)
	if out_path != "":
		var f = FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"log": args[0], "thetas": THETAS, "declare": declare, "fades": fades, "cap": cap, "movement_seed": movement_seed, "legacy_seed": legacy_seed,
			"wrong_sightings": Connections.seed_wrong_sightings, "proofs": proofs, "records": records}))
		f.close()
		print("wrote %d records to %s (%d judge calls)" % [records.size(), out_path, judge_calls])
	quit()

# ---------------------------------------------------------------- replay

func _run(events: Array) -> void:
	var g = Replay.new_game(events)
	var filed: Dictionary = {}
	var last_day := -1
	var diverged := false
	# Events between two command records were produced by the later command.
	var pending: Array = []
	var after_hooks: Array = []
	for idx in range(events.size()):
		var e = events[idx]
		if e.type == "workshop_canvas_filed":
			var number = Canvas.file(g, e.data.case, 0)
			filed[int(e.data.get("card", number))] = e.data.case
			continue
		if not Replay.is_command(e):
			pending.append(e)
			continue
		# State here is just before command e; `pending` is what e will produce.
		now_seq = int(e.seq)
		for hook in after_hooks:
			hook.call(g)
		after_hooks = []
		if int(g.w.day) != last_day:
			last_day = int(g.w.day)
			_dawn(g, int(e.seq))
		var tallies: Array = pending.filter(func(x): return x.type == "vote_tally")
		if not tallies.is_empty():
			_vote(g, tallies[0], pending, int(e.seq))
		# NPC nominations made by this command: the cited cards become a stored case.
		for k in range(pending.size()):
			var x = pending[k]
			if x.type != "nomination" or str(x.get("actor", "")) in ["player", ""]:
				continue
			var cited: Array = []
			for back in range(maxi(0, k - 6), k):
				var y = pending[back]
				if y.type == "think" and str(y.get("actor", "")) == str(x.actor) and str(y.data.get("topic", "")) == "recall_cited":
					cited = y.data.get("cards", [])
			var nominator: String = str(x.actor)
			var nominee: String = str(x.get("target", ""))
			var seq_n: int = int(x.seq)
			var day_n: int = int(g.w.day)
			after_hooks.append(func(g2): _store_all(g2, {"presenter": nominator, "target": nominee, "type": "evil", "cards": cited.duplicate(), "challenges": {}, "seq": seq_n, "day": day_n, "label": "%s nominates %s" % [nominator, nominee]}))
		# The player's public presentation of a filed case.
		var cmd: String = str(e.data.cmd)
		var number := _presented(cmd, filed)
		var took_floor: bool = str(e.data.get("output", "")).begins_with("You take the floor") or cmd.begins_with("nominate")
		if number > 0 and took_floor:
			var case_data: Dictionary = filed[number]
			var before: Dictionary = _snapshot_cards(g)
			var seq_p: int = int(e.seq)
			after_hooks.append(func(g2): _present(g2, number, case_data, before, seq_p))
		var out: String = g.command(cmd)
		var want: String = str(e.data.get("output", "")).strip_edges()
		if not diverged and want != "" and not (want in out):
			diverged = true
			print("NOTE: the command output first differs from the log at seq %d (%s). The vote check at the end says whether the game still follows the log." % [int(e.seq), cmd])
		pending = []
	for hook in after_hooks:
		hook.call(g)
	var votes: Array = Replay.votes(events, g)
	print("replay: command outputs %s; every vote tally %s" % ["differ somewhere" if diverged else "match the log", "matches the log" if votes[0] == votes[1] else "DIFFERS from the log"])
	records.append({"kind": "replay", "diverged": diverged, "votes_match": votes[0] == votes[1], "truth": _truth(g)})

func _presented(cmd: String, filed: Dictionary) -> int:
	var words: PackedStringArray = cmd.split(" ", false)
	if words.size() >= 2 and words[0] == "present" and words[1].is_valid_int() and filed.has(int(words[1])):
		return int(words[1])
	if words.size() >= 3 and words[0] == "nominate" and words[2].begins_with("#") and filed.has(int(words[2].substr(1))):
		return int(words[2].substr(1))
	return 0

func _truth(g) -> Dictionary:
	var out: Dictionary = {}
	for n in g.w.npcs:
		out[n.id] = {"evil": n.is_evil(), "role": str(n.role), "demon": n.has_method("is_demon") and n.is_demon()}
	return out

func _listeners(g) -> Array:
	return g.w.npcs.filter(func(n): return n.alive and not n.is_evil() and (only_listeners.is_empty() or n.id in only_listeners))

# ---------------------------------------------------------------- the judge

## Everything the listener holds, as the union prepares it when it reads every card.
func _state(g, n) -> Dictionary:
	var ws: Dictionary = n.workshop_state
	var kept := [Shared.last_reason_ctx, Jury._eval_memo, Reasoner.capture_attention, Reasoner.unlimited_cards, Reasoner.reuse_preparations]
	Reasoner.capture_attention = false
	Reasoner.unlimited_cards = true
	Reasoner.reuse_preparations = false
	var outside: Dictionary = Ownership._candidate_outside(n, ws)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var plan: Dictionary = Shared.prepare(input, ws.get("presentations", {}), n.ledger, ws.get("withdrawn", {}), [])
	var st: Dictionary = {"ready": false, "id": n.id}
	if plan.get("ready", false) and not plan.get("empty", false):
		var doubt: Dictionary = SourceDoubt.derive(plan, n.ledger, ws.get("manual_source_doubt", {}))
		var prepared: Dictionary = Shared._doubt_adjusted(plan, outside, doubt.pre_eval, doubt.full)
		st = _make_state(n.id, prepared.view, prepared.case, prepared.listener)
	Shared.last_reason_ctx = kept[0]
	Jury._eval_memo = kept[1]
	Reasoner.capture_attention = kept[2]
	Reasoner.unlimited_cards = kept[3]
	Reasoner.reuse_preparations = kept[4]
	return st

func _make_state(id: String, view: Dictionary, case_data: Dictionary, listener: Dictionary) -> Dictionary:
	var people: Array = Solver.person_ids(view)
	var others: Array = people.filter(func(p): return p != id)
	var template: Dictionary = Connections.template(case_data, others[0])
	var by_id: Dictionary = {}
	for c in view.cards:
		by_id[c.id] = c
	# As in the game's refresh, the cards the listener rejects from its own knowledge (a
	# Night Watch list that wrongly names it, say) are left out of the weighing.
	var rejected: Array = Reasoner.direct_checks(view, case_data, listener.get("knowledge", {})).get("rejected", [])
	var held: Array = case_data.cards.filter(func(c): return by_id.has(c) and c not in rejected)
	# How movement is read (Connections.row): the view's own demon mix, unless --declare
	# stands in for a declaration. Then the tool's copy of the view carries it, so its
	# judgements use that mix; the replayed game itself is untouched.
	if declare in ["walker", "hexer"]:
		view = view.duplicate()
		view["declared_demon_type"] = declare
	var declared: String = Connections.row(view) if declare != "none" else "none"
	return {"ready": true, "id": id, "view": view, "template": template, "listener": listener, "by_id": by_id, "held": held,
		"people": people, "others": others, "memo": {}, "declared": declared, "universe": Solver.universe(view),
		"has_demon": not Solver.universe(view).is_empty() and Solver.universe(view)[0].has("demon")}

## The judge on a set of held cards: everyone's chance of being evil and the Demon.
func _judge(st: Dictionary, ids: Array, hex: bool = false) -> Dictionary:
	var sorted: Array = ids.duplicate()
	sorted.sort()
	var key: String = ("hex|" if hex else "") + ",".join(PackedStringArray(sorted))
	if st.memo.has(key):
		return st.memo[key]
	judge_calls += 1
	var was_capture: bool = CaseEval.capture_worlds
	var kept: Array = CaseEval.captured
	CaseEval.capture_worlds = true
	CaseEval.captured = []
	var ev: Dictionary = Connections.judge(st.view, st.template, st.listener, sorted, hex)
	var worlds := PackedFloat64Array()
	if not CaseEval.captured.is_empty():
		worlds = CaseEval.captured[-1].worlds
	CaseEval.capture_worlds = was_capture
	CaseEval.captured = kept
	var pe: Dictionary = {}
	var pd: Dictionary = {}
	for p in st.others:
		pe[p] = float(ev.people.get(p, {}).get("posterior", 0.0))
		pd[p] = 0.0
	var universe: Array = st.universe
	if worlds.size() == universe.size():
		var total := 0.0
		var sums := PackedFloat64Array()
		sums.resize(st.people.size())
		sums.fill(0.0)
		for k in range(worlds.size()):
			var w: float = worlds[k]
			if w <= 0.0:
				continue
			total += w
			var d: int = int(universe[k].get("demon", -1))
			if d >= 0 and d < sums.size():
				sums[d] += w
		if total > 0.0:
			for j in range(st.people.size()):
				if pd.has(st.people[j]):
					pd[st.people[j]] = sums[j] / total
	var out: Dictionary = {"pe": pe, "pd": pd}
	st.memo[key] = out
	return out

static func _logit(p: float, clip: float) -> float:
	return Connections.logit(p, clip)

## lean(S): per person, {"e": evil log-odds shift, "d": Demon log-odds shift} from baseline.
func _lean(st: Dictionary, ids: Array, hex: bool = false) -> Dictionary:
	var base: Dictionary = _judge(st, [])
	var j: Dictionary = _judge(st, ids, hex)
	var out: Dictionary = {}
	for p in st.others:
		out[p] = {"e": _logit(j.pe[p], CLIP) - _logit(base.pe[p], CLIP), "d": _logit(j.pd[p], DEMON_CLIP) - _logit(base.pd[p], DEMON_CLIP)}
	return out

static func _zero(st: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for p in st.others:
		out[p] = {"e": 0.0, "d": 0.0}
	return out

static func _add(into: Dictionary, x: Dictionary, scale: float = 1.0) -> void:
	for p in into:
		into[p].e += scale * float(x[p].e)
		into[p].d += scale * float(x[p].d)

static func _max_e(x: Dictionary) -> float:
	var m := 0.0
	for p in x:
		m = maxf(m, absf(float(x[p].e)))
	return m

## Value of a set given its context: lean(set + context) - lean(context).
func _value(st: Dictionary, ids: Array, ctx: Array) -> Dictionary:
	var outside: Array = ctx.filter(func(c): return c not in ids)
	var v: Dictionary = _lean(st, _union(ids, outside))
	if not outside.is_empty():
		_add(v, _lean(st, outside), -1.0)
	return v

## An item's value. The day connection (a Hexer declaration) is what the Hexer factor adds
## on the day cards: the same set judged with the factor on and off (Connections.value).
func _item_value(st: Dictionary, it: Dictionary) -> Dictionary:
	if it.kind != "day":
		return _value(st, it.ids, it.ctx)
	var full: Array = _union(it.ids, it.ctx)
	var v: Dictionary = _lean(st, full, true)
	_add(v, _lean(st, full, false), -1.0)
	return v

static func _union(a: Array, b: Array) -> Array:
	var out: Array = a.duplicate()
	for x in b:
		if x not in out:
			out.append(x)
	return out

# ---------------------------------------------------------------- items

static func _names(st: Dictionary, ids: Array) -> Array:
	return Connections._names(st.by_id, ids, st.people)

## Every held card, grouped into the things that count once: plain cards, built-in pairings
## and the always-on connections (Connections.items; the game uses the same grouping).
## Each item: {"key", "ids", "ctx", "kind"}; kind is card, unit, movement or day.
func _items(st: Dictionary) -> Array:
	return Connections.items(st.by_id, st.held, st.people, st.declared)

## The item keys that seed the listener's core: every item holding a card it knows
## firsthand (Connections.seed_keys; the game's rule). --legacy-seed: the first prototype's.
func _seed(st: Dictionary, items: Array) -> Array:
	if not legacy_seed:
		return Connections.seed_keys(items, Connections.firsthand(st.by_id, st.held, st.listener))
	var out: Array = []
	for it in items:
		if it.kind == "card":
			var c: Dictionary = st.by_id[it.ids[0]]
			if c.kind == "report" and str(c.get("source", "")) == st.id:
				out.append(it.key)
		elif movement_seed and it.ids.any(func(id): return st.by_id[id].kind == "report" and str(st.by_id[id].get("source", "")) == st.id and str(st.by_id[id].get("role", "")) in NIGHT_ROLES):
			out.append(it.key)
	return out

# ---------------------------------------------------------------- beliefs

## One refresh: every threshold's beliefs for this listener, on the stored cases given.
## cases: oldest first. remember: use and update the listener's remembered core (rebuilt on
## a new day or when its own readings change; otherwise it only grows, by cards that are
## new to it). fixed: use exactly these members per threshold instead (for comparing two
## versions of one moment on the same core).
func _beliefs(st: Dictionary, cases: Array, day: int, remember: bool = true, fixed: Dictionary = {}, fade: float = -1.0) -> Dictionary:
	if fade < 0.0:
		fade = float(fades[0])
	var t0: int = Time.get_ticks_usec()
	var calls0: int = judge_calls
	var items: Array = _items(st)
	var base: Dictionary = _judge(st, [])
	var values: Dictionary = {}
	var solo_sum: Dictionary = _zero(st)
	var by_key: Dictionary = {}
	for it in items:
		by_key[it.key] = it
		values[it.key] = _item_value(st, it)
		_add(solo_sum, values[it.key])
	var seed_keys: Array = _seed(st, items)
	var firsthand: Array = seed_keys.duplicate() if legacy_seed else Connections.firsthand(st.by_id, st.held, st.listener)
	var seed: Dictionary = Connections.pool(seed_keys.map(func(k): return by_key[k]))
	var seed_value: Dictionary = _value(st, seed.ids, seed.ctx) if not seed.ids.is_empty() else _zero(st)
	# Interaction of each candidate with the seed (independent of order): what the two say
	# together, less what each says apart (Connections.core).
	var interaction: Dictionary = {}
	if not seed.ids.is_empty():
		for it in items:
			if it.kind in ALWAYS_ON or it.key in seed_keys:
				continue
			var joint: Dictionary = _value(st, _union(seed.ids, it.ids), _union(seed.ctx, it.ctx))
			_add(joint, seed_value, -1.0)
			_add(joint, values[it.key], -1.0)
			interaction[it.key] = _max_e(joint)
	# What the firsthand cards prove by themselves stays proved (Connections.core).
	var proved: Dictionary = {}
	if proofs and not legacy_seed and not seed_keys.is_empty():
		var own: Dictionary = _judge(st, firsthand)
		for p in st.others:
			var settled: bool = float(base.pe[p]) <= FIXED or float(base.pe[p]) >= 1.0 - FIXED
			if not settled and (float(own.pe[p]) <= FIXED or float(own.pe[p]) >= 1.0 - FIXED):
				proved[p] = float(own.pe[p])
	var t_solo: int = Time.get_ticks_usec()
	if remember:
		_cache_check(st, items, values, day, (t_solo - t0) / 1000.0, judge_calls - calls0)
	var item_of: Dictionary = {}
	for it in items:
		if it.kind == "day":
			continue  # its cards belong to their night or Augur day; it only adds the Hexer factor
		for id in it.ids:
			item_of[id] = it.key
	var out: Dictionary = {"held": st.held.size(), "items": items.size(), "seed": seed_keys.size(), "seed_keys": seed_keys, "firsthand": firsthand,
		"proved": proved, "declared": st.declared, "fade": fade, "thetas": {}, "interactions": interaction.values(), "interaction": interaction}
	for theta in THETAS:
		var mem: Dictionary = _core_memory(st.id, theta) if remember else {}
		var members: Dictionary = {}
		if fixed.has(str(theta)):
			for key in fixed[str(theta)]:
				if by_key.has(key) and key not in seed_keys:
					members[key] = true
		else:
			# The game's rule: rebuilt on a new day or a changed seed; otherwise the members
			# stay and only an item with a newly held card is tested.
			var plan: Dictionary = Connections.candidates(items, seed_keys, firsthand, mem, day)
			var tested: Dictionary = {}
			for key in plan.test:
				if interaction.has(key):
					tested[key] = interaction[key]
			for key in Connections.membership(items, plan.kept, tested, theta):
				members[key] = true
		if remember:
			cores[st.id][theta] = Connections.core_memory(day, seed_keys, firsthand, members.keys(), st.held)
		# The joint sets: the core, then each stored case (merged where they share a card).
		var total: Dictionary = solo_sum.duplicate(true)
		var core_keys: Array = seed_keys + members.keys()
		var sets: Array = []
		var largest: int = 0
		var merged_keys: Array = core_keys.duplicate()
		var merged_extra: Array = []   # movement cards cited by cases already merged into the core
		var merged_i: Dictionary = _interaction(st, merged_keys, by_key, values)
		if not core_keys.is_empty():
			_add(total, merged_i)
			largest = _size(merged_keys, by_key)
		# Which stored cases count, in what order and at what weight, is the game's rule
		# (Connections.case_plan). Challenges inside a case are the game's alone: this tool
		# doesn't weigh them.
		for cs in Connections.case_plan(cases.map(func(x): return x.merged({"key": x.label, "suspicious": str(x.get("type", "")) == "suspicious"})), items, st.listener, day, fade):
			var keys: Array = cs.keys
			var extra_ids: Array = cs.extra
			var w: float = cs.weight
			var touches_core: bool = not merged_keys.is_empty() and keys.any(func(k): return k in merged_keys)
			var entry: Dictionary = {"label": cs.key, "weight": w, "merged": touches_core, "cards": keys.size() + extra_ids.size()}
			if touches_core:
				var next_keys: Array = _union(merged_keys, keys)
				var next_extra: Array = _union(merged_extra, extra_ids)
				var next_i: Dictionary = _interaction(st, next_keys, by_key, values, next_extra)
				var delta: Dictionary = next_i.duplicate(true)
				_add(delta, merged_i, -1.0)
				_add(total, delta, w)
				merged_keys = next_keys
				merged_extra = next_extra
				merged_i = next_i
				largest = maxi(largest, _size(merged_keys, by_key) + merged_extra.size())
				entry["max_shift"] = w * _max_e(delta)
			else:
				var alone: Dictionary = _interaction(st, keys, by_key, values, extra_ids)
				_add(total, alone, w)
				largest = maxi(largest, _size(keys, by_key) + extra_ids.size())
				entry["max_shift"] = w * _max_e(alone)
			sets.append(entry)
		for it in items:
			if it.kind in ALWAYS_ON:
				largest = maxi(largest, it.ids.size())
		var probs: Dictionary = _normalise(st, base, total, proved)
		out.thetas[str(theta)] = {"pe": probs.pe, "pd": probs.pd, "core": members.keys(), "core_cards": _size(core_keys, by_key), "largest": largest, "cases": sets}
	out["ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	out["ms_joint"] = (Time.get_ticks_usec() - t_solo) / 1000.0
	out["judge_calls"] = judge_calls - calls0
	return out

func _core_memory(id: String, theta: float) -> Dictionary:
	if not cores.has(id):
		cores[id] = {}
	if not cores[id].has(theta):
		cores[id][theta] = {}
	return cores[id][theta]

static func _size(keys: Array, by_key: Dictionary) -> int:
	var n := 0
	for k in keys:
		n += by_key[k].ids.size()
	return n

## A joint set's interaction: its value judged together minus the sum of its members' own
## values. extra: single cards cited out of the movement connection.
func _interaction(st: Dictionary, keys: Array, by_key: Dictionary, values: Dictionary, extra: Array = []) -> Dictionary:
	if keys.size() + extra.size() < 2:
		return _zero(st)
	var set_: Dictionary = Connections.pool(keys.map(func(k): return by_key[k]))
	# A cited card that already sits in one of the items (a core holding the movement
	# connection) is counted there, not again as a single card (Connections.interaction).
	var single: Array = extra.filter(func(id): return id not in set_.ids)
	var joint: Dictionary = _value(st, _union(single, set_.ids), set_.ctx)
	for k in keys:
		_add(joint, values[k], -1.0)
	for id in single:
		_add(joint, _lean(st, [id]), -1.0)
	return joint

func _presenter_trust(st: Dictionary, presenter: String) -> float:
	return Connections.presenter_trust(st.listener, presenter)

## One common shift per track so the chances sum to the baseline's own sum.
## proved: the people the listener's firsthand cards settle (their chance of being evil);
## they keep it, and the others share what is left of the sum (Connections.refresh).
func _normalise(st: Dictionary, base: Dictionary, total: Dictionary, proved: Dictionary = {}) -> Dictionary:
	var pe: Dictionary = {}
	var pd: Dictionary = {}
	for track in ["e", "d"]:
		var b: Dictionary = base.pe if track == "e" else base.pd
		var clip: float = CLIP if track == "e" else DEMON_CLIP
		var fix: float = FIXED if track == "e" else DEMON_CLIP * 0.5
		var pinned: Dictionary = proved if track == "e" else {}
		var open: Array = st.others.filter(func(p): return float(b[p]) > fix and float(b[p]) < 1.0 - fix)
		var free: Array = open.filter(func(p): return not pinned.has(p))
		var target := 0.0
		var scores: Dictionary = {}
		for p in open:
			target += float(b[p]) - float(pinned.get(p, 0.0))
		for p in free:
			scores[p] = _logit(float(b[p]), clip) + float(total[p][track])
		var shift: float = Connections.common_shift(free.map(func(p): return scores[p]), maxf(target, 0.0))
		var res: Dictionary = pe if track == "e" else pd
		if track == "d" and not st.has_demon:
			continue
		for p in st.others:
			res[p] = (1.0 / (1.0 + exp(-(scores[p] + shift)))) if p in free else float(pinned.get(p, b[p]))
	# The worlds carry a Demon identity only when some card needs one.
	for p in pd:
		pd[p] = minf(pd[p], pe[p])
	return {"pe": pe, "pd": pd}

# ---------------------------------------------------------------- today's model

func _today(g, n, read_everything: bool) -> Dictionary:
	var ws: Dictionary = n.workshop_state
	var kept := [Shared.last_reason_ctx, Jury._eval_memo, Reasoner.capture_attention, Reasoner.unlimited_cards, Reasoner.reuse_preparations]
	Reasoner.capture_attention = false
	Reasoner.reuse_preparations = false
	Reasoner.unlimited_cards = read_everything
	var t0: int = Time.get_ticks_usec()
	var outside: Dictionary = Ownership._candidate_outside(n, ws)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var plan: Dictionary = Shared.prepare(input, ws.get("presentations", {}), n.ledger, ws.get("withdrawn", {}), [] if read_everything else ws.get("attention_focus", []))
	var pe: Dictionary = {}
	var read: int = 0
	if plan.get("ready", false) and not plan.get("empty", false):
		var doubt: Dictionary = SourceDoubt.derive(plan, n.ledger, ws.get("manual_source_doubt", {}))
		var proposal: Dictionary = Shared.evaluate(plan, outside, doubt.pre_eval, doubt.full, {})
		for id in proposal.get("effects", {}):
			pe[id] = float(proposal.effects[id].get("posterior", proposal.effects[id].get("prior", 0.0)))
		read = proposal.get("reasoning", {}).get("considered", []).size()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	Shared.last_reason_ctx = kept[0]
	Jury._eval_memo = kept[1]
	Reasoner.capture_attention = kept[2]
	Reasoner.unlimited_cards = kept[3]
	Reasoner.reuse_preparations = kept[4]
	return {"pe": pe, "ms": ms, "read": read}

## Which cards carry the read-everything belief about one person, and what the prototype
## does with them.
func _explain(g, st: Dictionary, person: String) -> void:
	var items: Array = _items(st)
	var b: Dictionary = _beliefs(st, _cases_for(st.id), int(g.w.day), false)
	var core: Array = b.thetas["0.4"].core
	var seed: Array = _seed(st, items)
	var all_ids: Array = st.held
	var full: float = float(_judge(st, all_ids).pe[person])
	var base: float = float(_judge(st, []).pe[person])
	var describe := func(it: Dictionary) -> String:
		var parts: PackedStringArray = []
		for id in it.ids.slice(0, 3):
			var c: Dictionary = st.by_id[id]
			parts.append("%s%s by %s%s: %s" % [c.kind, ("/" + str(c.role)) if c.has("role") else "", c.get("source", "?"),
				(" (night %d)" % int(c.night)) if c.has("night") else "", str(c.get("text", c.get("data", ""))).substr(0, 110)])
		var where: String = "seed" if it.key in seed else ("core" if it.key in core else (it.kind if it.kind in ALWAYS_ON else "alone"))
		return "[%s] %s%s" % [where, " || ".join(parts), (" (+%d more)" % (it.ids.size() - 3)) if it.ids.size() > 3 else ""]
	print("\nEXPLAIN %s on %s, day %d: no cards %.0f%%, every held card judged together %.0f%%, prototype %.0f%%" % [st.id, person, int(g.w.day), 100.0 * base, 100.0 * full, 100.0 * float(b.thetas["0.4"].pe[person])])
	var rows: Array = []
	for it in items:
		var rest: Array = all_ids.filter(func(id): return id not in it.ids)
		var solo: float = float(_judge(st, _union(it.ids, it.ctx)).pe[person])
		rows.append({"it": it, "without": float(_judge(st, rest).pe[person]), "solo": solo})
	rows.sort_custom(func(x, y): return absf(x.without - full) > absf(y.without - full))
	print("  Without each (largest change first):")
	for r in rows.slice(0, 8):
		print("    %.0f%% without, %.0f%% alone  %s" % [100.0 * r.without, 100.0 * r.solo, describe.call(r.it)])
	# The smallest build-up: add whichever item moves the belief furthest toward the full
	# answer, until it is within 5 points.
	var chosen: Array = []
	var ids: Array = []
	var now: float = base
	print("  Build-up toward %.0f%%:" % (100.0 * full))
	while absf(now - full) > 0.05 and chosen.size() < 8:
		var best: Dictionary = {}
		var best_p: float = now
		for it in items:
			if it.key in chosen:
				continue
			var p: float = float(_judge(st, _union(_union(ids, it.ids), it.ctx)).pe[person])
			if best.is_empty() or absf(p - full) < absf(best_p - full):
				best = it
				best_p = p
		if best.is_empty():
			break
		chosen.append(best.key)
		ids = _union(_union(ids, best.ids), best.ctx)
		now = best_p
		print("    -> %.0f%%  + %s" % [100.0 * now, describe.call(best)])

## --check: does the judge on a set see only that set? Each card is judged once with the
## whole view behind it and once with every other card removed from the view.
func _self_check(st: Dictionary) -> void:
	var worst := 0.0
	var worst_card := ""
	for id in st.held:
		var a: Dictionary = _judge(st, [id])
		var view2: Dictionary = st.view.duplicate()
		view2.cards = st.view.cards.filter(func(c): return c.id == id)
		var st2: Dictionary = _make_state(st.id, view2, st.template.merged({"cards": [id]}, true), st.listener)
		st2.declared = st.declared
		if st2.universe.size() != st.universe.size():
			print("check %s: the universe changes when the view is cut to one card (%d vs %d worlds)" % [st.id, st2.universe.size(), st.universe.size()])
			return
		var b: Dictionary = _judge(st2, [id])
		for p in st.others:
			if absf(float(a.pe[p]) - float(b.pe[p])) > worst:
				worst = absf(float(a.pe[p]) - float(b.pe[p]))
				worst_card = "%s/%s" % [st.by_id[id].kind, st.by_id[id].get("role", "")]
	print("check %s day-state: judging one card with the whole view behind it vs alone differs by at most %.4f (%s)" % [st.id, worst, worst_card])

# ---------------------------------------------------------------- moments

func _cases_for(id: String) -> Array:
	return stores.get(id, [])

## The store rule: a case from the same presenter with the same premise replaces the
## earlier one. Nothing is pushed out (old cases fade) unless --cap is set.
func _stored_with(list: Array, cs: Dictionary) -> Array:
	var out: Array = list.filter(func(x): return not (x.presenter == cs.presenter and x.target == cs.target and x.type == cs.type))
	out.append(cs)
	while cap > 0 and out.size() > cap:
		out.pop_front()
	return out

## The other fade rates' beliefs for the same moment, on the same core.
func _other_fades(st: Dictionary, cases: Array, day: int, core: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for rate in fades.slice(1):
		out[str(rate)] = _beliefs(st, cases, day, false, core, float(rate)).thetas
	return out

## What a cached refresh would have had to redo. Compares this refresh's per-item values
## with the listener's previous refresh the same day: an item is invalidated when the public
## record changed, or a card in it (its hearing weight included), the listener's trust in
## one of its tellers, or a reading's reliability did. The rest should be unchanged; how far
## they moved anyway is the cache's error.
func _cache_check(st: Dictionary, items: Array, values: Dictionary, day: int, solo_ms: float, solo_calls: int) -> void:
	var l: Dictionary = st.listener
	# The public record: who has died, and every public event that isn't itself a card
	# someone told (those arrive as cards and are counted there).
	var timeline: Dictionary = st.view.get("timeline", {})
	var public_events: Array = timeline.get("events", []).filter(func(e): return str(e.get("kind", "")) not in ["reading", "claim", "sighting", "alibi", "statement"])
	# Deaths, executions and attacks are the record proper; nominations, accusations and
	# votes are the meeting's talk, tracked apart to see whether solo values depend on them.
	var hard: Array = public_events.filter(func(e): return str(e.get("kind", "")) in ["demon_death", "demon_attack", "execution", "silenced", "death"])
	var record_sig: int = JSON.stringify([timeline.get("deaths", {}), hard]).hash()
	var talk_sig: int = JSON.stringify(public_events.filter(func(e): return e not in hard)).hash()
	var prior_sig: int = JSON.stringify(l.get("suspicion", {})).hash()
	var now: Dictionary = {}
	for it in items:
		var cards: Array = []
		var trust: Array = []
		var rel: Array = []
		for id in _union(it.ids, it.ctx):
			var c: Dictionary = st.by_id[id]
			cards.append(JSON.stringify(c).hash())
			trust.append(float(l.get("npc_trust", {}).get(str(c.get("source", "")), -1.0)))
			for k in [c.get("accuracy_origin", ""), Solver.semantic_key(c), c.get("fact_id", ""), c.get("id", "")]:
				if k != "" and l.get("reading_reliability", {}).has(k):
					rel.append(snappedf(float(l.reading_reliability[k]), 0.0001))
		now[it.key] = {"cards": cards, "trust": trust, "rel": rel, "value": values[it.key]}
	var prev: Dictionary = cache_seen.get(st.id, {})
	if prev.get("day", -99) == day:
		var counts := {"items": items.size(), "new": 0, "record": 0, "hearing": 0, "trust": 0, "kept": 0, "kept_drifted": 0}
		var talk_changed: bool = prev.get("talk", 0) != talk_sig
		var prior_changed: bool = prev.get("prior", 0) != prior_sig
		var worst := 0.0
		var record_changed: bool = prev.record != record_sig
		for key in now:
			if not prev.items.has(key):
				counts.new += 1
				continue
			var was: Dictionary = prev.items[key]
			if record_changed:
				counts.record += 1
			elif was.cards != now[key].cards:
				counts.hearing += 1
			elif was.trust != now[key].trust or was.rel != now[key].rel:
				counts.trust += 1
			else:
				counts.kept += 1
				var drift := 0.0
				for p in now[key].value:
					drift = maxf(drift, absf(float(now[key].value[p].e) - float(was.value[p].e)))
				worst = maxf(worst, drift)
				if drift > CACHE_TOLERANCE:
					counts.kept_drifted += 1
		records.append({"kind": "cache", "seq": now_seq, "day": day, "listener": st.id, "counts": counts, "worst_drift": worst,
			"judgement_ms": solo_ms / maxf(1.0, float(solo_calls)), "since_seq": int(prev.seq), "talk_changed": talk_changed, "suspicion_changed": prior_changed})
	cache_seen[st.id] = {"day": day, "seq": now_seq, "record": record_sig, "talk": talk_sig, "prior": prior_sig, "items": now}

static func _members_of(b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for theta in b.thetas:
		out[theta] = b.thetas[theta].core
	return out

func _store_all(g, cs: Dictionary) -> void:
	if cs.cards.size() < 1:
		return
	for n in g.w.npcs:
		if not n.alive or n.id == cs.presenter:
			continue
		stores[n.id] = _stored_with(stores.get(n.id, []), cs)

func _dawn(g, seq: int) -> void:
	for n in _listeners(g):
		var st: Dictionary = _state(g, n)
		if not st.ready:
			continue
		if check and int(g.w.day) >= 3:
			_self_check(st)
		for ex in explain:
			if ex.size() == 3 and ex[0] == n.id and int(ex[2]) == int(g.w.day) and st.others.has(ex[1]):
				_explain(g, st, ex[1])
		var b: Dictionary = _beliefs(st, _cases_for(n.id), int(g.w.day))
		var again: Dictionary = _beliefs(st, _cases_for(n.id), int(g.w.day))
		var bare: Dictionary = _beliefs(st, [], int(g.w.day), false, _members_of(b)) if not _cases_for(n.id).is_empty() else b
		var other: Dictionary = _other_fades(st, _cases_for(n.id), int(g.w.day), _members_of(b))
		var stable: bool = JSON.stringify(b.thetas) == JSON.stringify(again.thetas)
		# A fresh state object: the cost of a refresh with nothing cached.
		var fresh: Dictionary = _make_state(n.id, st.view, st.template.merged({"cards": st.held}, true), st.listener)
		fresh.declared = st.declared
		var cold: Dictionary = _beliefs(fresh, _cases_for(n.id), int(g.w.day), false)
		var bounded: Dictionary = _today(g, n, false)
		var everything: Dictionary = _today(g, n, true)
		var named: Dictionary = {}
		for id in st.held:
			var c: Dictionary = st.by_id[id]
			named[id] = "%s/%s by %s (day %s)" % [c.kind, c.get("role", ""), c.get("source", ""), str(c.get("observed_at", {}).get("day", "?"))]
		records.append({"kind": "dawn", "seq": seq, "day": int(g.w.day), "listener": n.id, "proto": b, "fades": other, "proto_no_cases": bare.thetas, "stable": stable,
			"cold_ms": cold.ms, "cold_joint_ms": cold.ms_joint, "cold_calls": cold.judge_calls,
			"judge_all": _judge(st, st.held).pe, "today": bounded.pe, "today_ms": bounded.ms, "today_read": bounded.read, "everything": everything.pe, "everything_ms": everything.ms, "cards": named})
		if not quiet:
			print("dawn day %d %-9s held %2d items %2d seed %d core@0.4 %2d largest %2d | today %.0f ms, prototype cold %.0f ms (%d judgements), joint pass %.0f ms" % [int(g.w.day), n.id, b.held, b.items, b.seed,
				b.thetas["0.4"].core.size(), b.thetas["0.4"].largest, bounded.ms, cold.ms, cold.judge_calls, cold.ms_joint])

func _vote(g, tally: Dictionary, pending: Array, seq: int) -> void:
	var nominee: String = str(tally.data.get("nominee", tally.get("target", "")))
	var voters: Array = []
	for x in pending:
		if x.type != "think" or str(x.data.get("topic", "")) != "vote" or not x.data.has("need") or int(x.seq) > int(tally.seq):
			continue
		var n = g.w.by_id.get(str(x.actor))
		if n == null or n.is_evil() or n.id == nominee:
			continue
		var st: Dictionary = _state(g, n)
		if not st.ready or not st.others.has(nominee):
			continue
		var b: Dictionary = _beliefs(st, _cases_for(n.id), int(g.w.day))
		var cached: Dictionary = g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).get("effects", {}).get(nominee, {})
		var p_today: float = float(cached.get("posterior", -1.0))
		if p_today < 0.0:
			p_today = float(_today(g, n, false).pe.get(nominee, -1.0))
		var scale: float = 0.45 * (1.35 if st.listener.get("per_card_source_trust", false) else 1.0)
		var row: Dictionary = {"voter": n.id, "need": float(x.data.need), "total": float(x.data.total), "logged_suspicion": float(x.data.get("suspicion", 0.0)),
			"suspicion_now": Mind.susp(n, nominee), "p_today": p_today, "scale": scale, "proto": {}, "fades": {}}
		for theta in THETAS:
			row.proto[str(theta)] = float(b.thetas[str(theta)].pe[nominee])
		var other: Dictionary = _other_fades(st, _cases_for(n.id), int(g.w.day), _members_of(b))
		for rate in other:
			row.fades[rate] = {}
			for theta in THETAS:
				row.fades[rate][str(theta)] = float(other[rate][str(theta)].pe[nominee])
		voters.append(row)
	var evil: Array = g.w.npcs.filter(func(n): return n.is_evil()).map(func(n): return n.id)
	records.append({"kind": "vote", "seq": seq, "day": int(g.w.day), "nominee": nominee, "by": str(tally.data.get("by", "")), "yes": tally.data.get("yes", []), "no": tally.data.get("no", []),
		"order": tally.data.get("order", []), "threshold": int(tally.data.get("threshold", 0)), "outcome": str(tally.data.get("outcome", "")), "count": int(tally.data.get("count", 0)),
		"evil": evil, "nominee_evil": nominee in evil, "voters": voters})
	if not quiet:
		print("vote day %d on %s by %s: logged %d yes; %d good voters recomputed" % [int(g.w.day), nominee, str(tally.data.get("by", "")), int(tally.data.get("count", 0)), voters.size()])

## For each card: its kind and the item (plain card, unit or movement connection) it sits in.
func _where(st: Dictionary, ids: Array) -> Array:
	var out: Array = []
	var items: Array = _items(st)
	for id in ids:
		var c: Dictionary = st.by_id[id]
		var key := ""
		for it in items:
			if id in it.ids:
				key = it.key if it.kind != "card" else "alone"
		out.append("%s/%s by %s -> %s" % [c.kind, c.get("role", ""), c.get("source", ""), key])
	return out

## What each listener held just before a presentation: the card as held and how far the
## listener trusted it, so the "without this case" side can undo what citing changed.
func _snapshot_cards(g) -> Dictionary:
	var out: Dictionary = {}
	for n in _listeners(g):
		var st: Dictionary = _state(g, n)
		if st.ready:
			out[n.id] = {"cards": st.by_id.duplicate(true), "held": st.held.duplicate(), "reliability": st.listener.get("reading_reliability", {}).duplicate(true)}
	return out

func _present(g, number: int, case_data: Dictionary, before: Dictionary, seq: int) -> void:
	var target: String = str(case_data.conclusion.get("target", case_data.conclusion.get("a", "")))
	var cs: Dictionary = {"presenter": "player", "target": target, "type": str(case_data.conclusion.get("type", "evil")), "cards": case_data.cards.duplicate(),
		"challenges": case_data.get("reading_challenges", {}), "seq": seq, "day": int(g.w.day), "label": "#%d %s %s" % [number, target, str(case_data.conclusion.get("type", ""))]}
	var modes: Array = []
	for id in cs.challenges:
		modes.append(str(cs.challenges[id].get("mode", "")))
	for n in _listeners(g):
		if n.id == target:
			continue
		var st: Dictionary = _state(g, n)
		if not st.ready or not st.others.has(target):
			continue
		# The listener's store as it stood before this presentation, including any earlier
		# version of this case: replacement applies only to the "with" side.
		var earlier: Array = _cases_for(n.id).duplicate()
		var with_cases: Array = _stored_with(_cases_for(n.id), cs)
		# The same moment without the case: its cards as they were held before (cards only
		# the case brought are not held), everything else identical.
		var st0: Dictionary = st
		var was: Dictionary = before.get(n.id, {})
		var new_cards: Array = []
		var cited_changed: Array = []
		if not was.is_empty():
			var view0: Dictionary = st.view.duplicate()
			var listener0: Dictionary = st.listener.duplicate(true)
			var cards0: Array = []
			var held0: Array = []
			for c in st.view.cards:
				if c.id in cs.cards:
					if not was.cards.has(c.id) or c.id not in was.held:
						if c.id in st.held:
							new_cards.append(c.id)
						continue
					if JSON.stringify(was.cards[c.id]) != JSON.stringify(c):
						cited_changed.append(c.id)
					cards0.append(was.cards[c.id])
				else:
					cards0.append(c)
				if c.id in st.held:
					held0.append(c.id)
			view0.cards = cards0
			for key in was.reliability:
				if listener0.reading_reliability.has(key) and cs.cards.any(func(id): return key == id or key.ends_with(id.get_slice(":", 1))):
					if not is_equal_approx(float(listener0.reading_reliability[key]), float(was.reliability[key])):
						cited_changed.append("reliability:" + key)
					listener0.reading_reliability[key] = was.reliability[key]
			st0 = _make_state(n.id, view0, st.template.merged({"cards": held0}, true), listener0)
			st0.declared = st.declared
		var day: int = int(g.w.day)
		# One core for every version of this moment, so only the case differs.
		var with_b: Dictionary = _beliefs(st, with_cases, day, true)
		var core: Dictionary = _members_of(with_b)
		var without: Dictionary = _beliefs(st0, earlier, day, false, core)
		var twice: Dictionary = _beliefs(st, _stored_with(with_cases, cs), day, false, core)
		var other_with: Dictionary = _other_fades(st, with_cases, day, core)
		var other_without: Dictionary = _other_fades(st0, earlier, day, core)
		# Everyone a cited trace matches: read with the profile cards, it moves them.
		var matched: Array = []
		for it in _items(st):
			if it.ids.any(func(id): return id in cs.cards and st.by_id[id].kind in TRACE_KINDS):
				var v: Dictionary = _value(st, it.ids.filter(func(id): return id in cs.cards and st.by_id[id].kind in TRACE_KINDS) if it.kind == "movement" else it.ids, it.ctx)
				for p in v:
					if absf(float(v[p].e)) >= TRACE_MATCH and p not in matched:
						matched.append(p)
		# People the case touches: its target, anyone named in or telling its cards, and
		# anyone named in a core card it joined.
		var touched: Dictionary = {}
		for theta in THETAS:
			var names: Array = _union([target] + _names(st, cs.cards.filter(func(id): return st.by_id.has(id))), matched)
			var th: Dictionary = with_b.thetas[str(theta)]
			if th.cases.any(func(x): return x.label == cs.label and x.merged):
				var core_ids: Array = []
				var items: Array = _items(st)
				var seed: Array = _seed(st, items)
				for it in items:
					if it.key in th.core or it.key in seed:
						core_ids.append_array(it.ids)
				names = _union(names, _names(st, core_ids))
			touched[str(theta)] = names
		records.append({"kind": "present", "seq": seq, "day": day, "case": number, "label": cs.label, "target": target, "listener": n.id, "challenge_modes": modes,
			"cards": cs.cards.size(), "held_cards": cs.cards.filter(func(id): return id in st.held).size(), "new_cards": new_cards.size(), "new_kinds": _where(st, new_cards), "cited_changed": cited_changed.size(),
			"without": without.thetas, "with": with_b.thetas, "fades_with": other_with, "fades_without": other_without, "trace_matched": matched,
			"dropped": earlier.filter(func(x): return x not in with_cases).map(func(x): return x.label), "twice_same": JSON.stringify(twice.thetas) == JSON.stringify(with_b.thetas), "touched": touched,
			"weight": _presenter_trust(st, "player")})
		if not quiet:
			var a: Dictionary = without.thetas["0.4"]
			var b: Dictionary = with_b.thetas["0.4"]
			var worst := 0.0
			var who := ""
			for p in st.others:
				if p not in touched["0.4"] and absf(float(b.pe[p]) - float(a.pe[p])) > worst:
					worst = absf(float(b.pe[p]) - float(a.pe[p]))
					who = p
			print("present %s to %-9s: %s %.0f%% -> %.0f%% (trust in presenter %.2f, merged with core: %s); largest untouched move %.1f points%s" % [cs.label, n.id, target, 100.0 * float(a.pe[target]), 100.0 * float(b.pe[target]),
				_presenter_trust(st, "player"), str(b.cases.any(func(x): return x.label == cs.label and x.merged)), 100.0 * worst, " (%s)" % who if who != "" else ""])
	_store_all(g, cs)

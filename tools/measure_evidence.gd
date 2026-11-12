## Evidence catalog, measured pass (docs/evidence_catalog.md). Plays seeds passively to day 3,
## harvests real readings from their holders, and measures what each does to a listener who
## knows nothing else: heard directly from the source at trust 0.4 and 0.8, and as the
## source's own reading. Also "all of this source's readings" (the partner case for repeat
## readings). Output: one JSON line per measurement, then a per-role summary.
##
## godot --headless --path . --script res://tools/measure_evidence.gd -- [--seeds 1:40] [--size 7] [--out file.jsonl]
##   [--default-script] [--force-demon daykiller] [--no-hexer] [--declare walker|hexer]
##   [--what readings|social|public|player|interactions|premises]
##
## --what interactions: the interaction table (belief-model direction, Phase 3). For pairs of
##   cards A and B on one fresh listener, every person's P(evil) and P(Demon) with no cards,
##   A alone, B alone and both. One row per pair and person.
## --what premises: the same two cards presented by the player under different premises and
##   challenges, against holding them unpresented. One row per variant and person.
## --what crosschecks: cross-teller pairs a player would present, in the interaction-table
##   format: an Archivist pair with a clearing Confessor reading, a Dowser count with a
##   Confessor reading on one of the group, a Psychologist reading with its two statements.
##   The Confessor readings are constructed (true content, a good teller who claims Confessor).
## --what challenges: an accusing reading (Archivist pair, Dowser count of 1+) against
##   constructed Confessor readings clearing everyone it accuses, so the grounds contradict
##   it. Presented with a lying, misled or failed-gift (impaired) challenge and without.
## --force-roles a,b: put these roles on the script and deal them.
## --declare: stands in for the demon-type declaration (LiveActivity.declared_demon_type).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Caches = preload("res://workshop/caches.gd")
const C = preload("res://sim/content.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const GameDayNight = preload("res://game/game_day_night.gd")
const Tuning = preload("res://sim/tuning.gd")
const Views = preload("res://tools/belief_views.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Psych = preload("res://sim/roles/psychologist.gd")
const RC = preload("res://workshop/reading_challenges.gd")

const TRUSTS = [0.4, 0.8]
var STOP_DAY: int = 3 # --day N: measure at the start of day N (default 3)
const FLAT = 0.25
var rows: Array = []
var no_hexer: bool = false
var force_roles: Array = []
var force_bluffs: Array = []
var construct_bluffs: bool = false
var construct_mistakes: bool = false # --construct-mistakes: good tellers' false readings (a failed gift or a misleading registration)
var natural_trust: bool = false
var keep_state: bool = false # --keep-state: the listener keeps what it already holds and believes
var script_roles: Array = []
var last_case: Dictionary = {}

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: Array = range(1, 41)
	var size: int = 7
	var out_path: String = ""
	var dynamic: bool = true
	var force_demon: String = ""
	var what: String = "readings"
	for i in range(args.size()):
		if args[i] == "--seeds" and i + 1 < args.size():
			var ab: PackedStringArray = args[i + 1].split(":")
			seeds = range(int(ab[0]), int(ab[1]) + 1)
		elif args[i] == "--size" and i + 1 < args.size():
			size = int(args[i + 1])
		elif args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
		elif args[i] == "--default-script":
			dynamic = false
		elif args[i] == "--force-demon" and i + 1 < args.size():
			force_demon = args[i + 1]
		elif args[i] == "--what" and i + 1 < args.size():
			what = args[i + 1]
		elif args[i] == "--no-hexer":
			no_hexer = true
		elif args[i] == "--graded-rule" and i + 1 < args.size():
			preload("res://workshop/reading_challenges.gd").graded_rule = args[i + 1]
		elif args[i] == "--clash-rule" and i + 1 < args.size():
			preload("res://workshop/reading_challenges.gd").clash_rule = args[i + 1]
		elif args[i] == "--natural-trust":
			natural_trust = true
		elif args[i] == "--keep-state":
			keep_state = true
		elif args[i] == "--day" and i + 1 < args.size():
			STOP_DAY = int(args[i + 1])
		elif args[i] == "--construct-mistakes":
			construct_mistakes = true
		elif args[i] == "--construct-bluffs":
			construct_bluffs = true
		elif args[i] == "--force-bluffs" and i + 1 < args.size():
			force_bluffs = Array(args[i + 1].split(","))
		elif args[i] == "--script-roles" and i + 1 < args.size():
			script_roles = Array(args[i + 1].split(","))
		elif args[i] == "--force-roles" and i + 1 < args.size():
			force_roles = Array(args[i + 1].split(","))
		elif args[i] == "--declare" and i + 1 < args.size():
			Activity.declared_demon_type = args[i + 1]
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if out_path != "" else null
	for sd in seeds:
		var t0: int = Time.get_ticks_msec()
		var g = _play(int(sd), size, dynamic, force_demon)
		if g == null:
			continue
		var n_rows: int = rows.size()
		match what:
			"readings": _measure_readings(g)
			"social": _measure_social(g)
			"public": _measure_public(g)
			"player": _measure_player(g)
			"interactions": _measure_interactions(g)
			"premises": _measure_premises(g)
			"crosschecks": _measure_crosschecks(g)
			"challenges": _measure_challenges(g)
		for r in rows.slice(n_rows):
			if f != null:
				f.store_line(JSON.stringify(r))
		print("SEED %d: %d measurements, %d ms" % [sd, rows.size() - n_rows, Time.get_ticks_msec() - t0])
	if f != null:
		f.close()
	quit()

## Dynamic scripts (as the sweeps deal them) by default, so every gift turns up; with
## --force-demon, that demon type is dealt and the Demon stays on the script too.
func _play(sd: int, size: int, dynamic: bool = true, force_demon: String = ""):
	var g = Game.new()
	g.detailed_logging = false
	var case_script = ScriptBuilder.dynamic({"seed": sd, "name": "Measure #%d" % sd}) if dynamic else null
	if force_demon != "":
		if case_script == null:
			case_script = ScriptDef.default_script()
		if not force_demon in case_script.demons:
			case_script.demons.append(force_demon)
		case_script.forced = case_script.forced.filter(func(r): return not r in case_script.demons) + [force_demon]
	if no_hexer:
		if case_script == null:
			case_script = ScriptDef.default_script()
		case_script.demons = case_script.demons.filter(func(r): return not C.is_day_demon(r))
		case_script.forced = case_script.forced.filter(func(r): return not C.is_day_demon(r))
		if case_script.demons.is_empty():
			case_script.demons = ["demon"]
	if not force_roles.is_empty():
		if case_script == null:
			case_script = ScriptDef.default_script()
		for r in force_roles:
			if C.ROLES[r].align == "good" and not r in case_script.town:
				case_script.town.append(r)
			elif C.ROLES[r].get("minion", false) and not r in case_script.minions:
				case_script.minions.append(r)
			if not r in case_script.forced:
				case_script.forced.append(r)
	if not script_roles.is_empty():
		# On the script (claimable), not necessarily dealt.
		if case_script == null:
			case_script = ScriptDef.default_script()
		for r in script_roles:
			if C.ROLES[r].align == "good" and not r in case_script.town:
				case_script.town.append(r)
	if not force_bluffs.is_empty():
		# The bluffed gifts must be on the script for a claim of them to be believable.
		if case_script == null:
			case_script = ScriptDef.default_script()
		for r in force_bluffs:
			if not r in case_script.town:
				case_script.town.append(r)
	g.new_case(sd, size, case_script)
	if not force_bluffs.is_empty():
		# Evil bluffs these gifts, the Demon first. A seed that dealt one of them to a
		# townsperson is skipped (the bluff would be a counter-claim).
		if g.w.npcs.any(func(m): return not m.is_evil() and m.role in force_bluffs):
			return null
		var team: Array = g.w.evil_team()
		team.sort_custom(func(a, b): return a.id == g.w.demon_id and b.id != g.w.demon_id)
		for i in range(team.size()):
			g.w.evil_plan.bluffs[team[i].id] = force_bluffs[i % force_bluffs.size()]
	var guard: int = 0
	while g.state != "over" and g.w.day < STOP_DAY and guard < 300:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	if g.state == "over" or g.w.day < STOP_DAY:
		return null
	return g

# ---------------------------------------------------------------- listener isolation

const WIPE = ["ledger", "info_log", "known_claims", "beliefs", "warden_log", "believed_roles", "workshop_state", "applied_info", "npc_trust", "suspicion", "credibility", "trust"]

func _save(n) -> Dictionary:
	var s: Dictionary = {}
	for k in WIPE:
		var v = n.get(k)
		s[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return s

func _restore(n, s: Dictionary) -> void:
	for k in WIPE:
		n.set(k, s[k])

func _wipe(g, n) -> void:
	n.ledger = {}
	n.info_log = []
	n.known_claims = {}
	n.beliefs = []
	n.warden_log = {}
	n.believed_roles = {}
	n.workshop_state = {"reasoning_mode": "bounded"}
	n.applied_info = 0
	for m in g.w.npcs:
		if m.id != n.id:
			n.suspicion[m.id] = FLAT
			n.npc_trust[m.id] = 0.5

## The listener's evidence step per person, from what's in its ledger and info log now.
var drop_events: Callable = Callable()

func _view(g, n) -> Dictionary:
	Caches.clear_all()
	var st: Dictionary = n.workshop_state
	var outside: Dictionary = {}
	for m in g.w.npcs:
		if m.id != n.id:
			outside[m.id] = FLAT
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	if drop_events.is_valid():
		input.public_events = input.public_events.filter(func(e): return not drop_events.call(e))
	var plan = Shared.prepare(input, st.get("presentations", {}), n.ledger, st.get("withdrawn", {}), st.get("attention_focus", []))
	if not plan.ready:
		return {}
	var effects: Dictionary = Shared.evaluate(plan, outside, st.get("source_doubt", {})).effects
	var out: Dictionary = {}
	for id in effects:
		out[id] = float(effects[id].get("requested", 0.0))
	return out

## Step per person caused by inject(n), against the same listener with nothing injected.
## Both sides go through the game's own belief refresh (source doubt, premise shaping, the
## outside layer), and the measure is the listener's resulting suspicion.
func _delta(g, n, trust_in: Dictionary, inject: Callable) -> Dictionary:
	var saved: Dictionary = _save(n)
	_wipe(g, n)
	for id in trust_in:
		n.npc_trust[id] = trust_in[id]
	Caches.clear_all()
	Mind.refresh_beliefs(g.w, n, " (measure base)")
	var base: Dictionary = n.suspicion.duplicate(true)
	inject.call(n)
	Caches.clear_all()
	Mind.refresh_beliefs(g.w, n, " (measure)")
	var after: Dictionary = n.suspicion.duplicate(true)
	var issues: Array = n.workshop_state.get("issues", [])
	_restore(n, saved)
	if not issues.is_empty():
		return {}
	var d: Dictionary = {}
	for id in after:
		if id != n.id:
			d[id] = float(after[id]) - float(base.get(id, after[id]))
	return d

# ---------------------------------------------------------------- readings

func _named(entry: Dictionary) -> Array:
	var out: Array = []
	var d: Dictionary = entry.get("data", {})
	for k in ["pair", "group", "trio", "seen", "nbrs"]:
		for p in d.get(k, []):
			if str(p) not in out:
				out.append(str(p))
	for k in ["executed", "target", "subject", "nominator", "nominee", "attacked"]:
		if d.has(k) and str(d[k]) != "" and str(d[k]) not in out:
			out.append(str(d[k]))
	return out

func _summary(g, d: Dictionary, listener_id: String, named: Array) -> Dictionary:
	var evil: Array = []
	var good: Array = []
	for m in g.w.npcs:
		if m.id == listener_id or not d.has(m.id):
			continue
		(evil if m.is_evil() else good).append(d[m.id])
	var named_d: Array = named.filter(func(p): return d.has(p) and p != listener_id).map(func(p): return d[p])
	var top: String = ""
	var top_v: float = 0.0
	for id in d:
		if id != listener_id and absf(d[id]) > absf(top_v):
			top = id
			top_v = d[id]
	return {"evil_mean": _mean(evil), "good_mean": _mean(good), "separation": _mean(evil) - _mean(good),
		"named_mean": _mean(named_d), "max_abs": absf(top_v), "top": top, "top_evil": g.w.by_id[top].is_evil() if top != "" else false}

func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / a.size()

func _measure_readings(g) -> void:
	var w = g.w
	for s in w.npcs:
		if s.is_evil() or s.info_log.is_empty():
			continue
		var by_role: Dictionary = {}
		for e in s.info_log:
			var role: String = str(e.get("role", ""))
			if role == "" or C.role_def(role) == null:
				continue
			if not by_role.has(role):
				by_role[role] = []
			by_role[role].append(e)
		for role in by_role:
			var entries: Array = by_role[role]
			var listeners: Array = w.npcs.filter(func(m): return m.alive and not m.is_evil() and m.id != s.id)
			for idx in range(mini(entries.size(), 3)):
				var e: Dictionary = entries[idx]
				var named: Array = _named(e)
				var cand: Array = listeners.filter(func(m): return m.id not in named)
				if cand.is_empty():
					cand = listeners
				if cand.is_empty():
					continue
				var l = cand[(idx + s.id.length()) % cand.size()]
				var base_row: Dictionary = {"seed": w.seed_value, "size": w.n_npcs, "demon_type": w.by_id[w.demon_id].role, "evidence": "reading", "role": role, "source": s.id,
					"source_secret": s.secret_mod, "true": bool(e.get("true", true)), "day": int(e.get("day", -1)), "data": e.get("data", {}), "named": named,
					"named_evil": named.filter(func(p): return w.by_id.has(p) and w.by_id[p].is_evil()).size()}
				for t in TRUSTS:
					var d: Dictionary = _delta(g, l, {s.id: t}, func(n):
						Mind.apply_info(w, n, s, e, Mind.heard_weight(n, s))
						Mind.hear_claim(w, n, s.id, role, Mind.heard_weight(n, s), "told"))
					if not d.is_empty():
						var r: Dictionary = base_row.duplicate(true)
						r.merge({"mode": "heard", "trust": t, "listener": l.id}, true)
						r.merge(_summary(g, d, l.id, named), true)
						rows.append(r)
				# Own: the source's own view of just this reading.
				var own: Dictionary = _delta(g, s, {}, func(n):
					n.info_log = [e]
					Mind.apply_info(w, n, n, e, 1.0))
				if not own.is_empty():
					var r2: Dictionary = base_row.duplicate(true)
					r2.merge({"mode": "own", "trust": 1.0, "listener": s.id}, true)
					r2.merge(_summary(g, own, s.id, named), true)
					rows.append(r2)
			# Partner: all of this source's readings of the role, heard at trust 0.8.
			if entries.size() >= 2:
				var named_all: Array = []
				for e2 in entries:
					for p in _named(e2):
						if p not in named_all:
							named_all.append(p)
				var cand2: Array = listeners.filter(func(m): return m.id not in named_all)
				if cand2.is_empty():
					cand2 = listeners
				if not cand2.is_empty():
					var l2 = cand2[0]
					var dd: Dictionary = _delta(g, l2, {s.id: 0.8}, func(n):
						for e2 in entries:
							Mind.apply_info(w, n, s, e2, Mind.heard_weight(n, s))
						Mind.hear_claim(w, n, s.id, role, Mind.heard_weight(n, s), "told"))
					if not dd.is_empty():
						var r3: Dictionary = {"seed": w.seed_value, "size": w.n_npcs, "evidence": "reading", "role": role, "source": s.id,
							"source_secret": s.secret_mod, "true": entries.all(func(x): return bool(x.get("true", true))), "mode": "all_readings", "count": entries.size(),
							"trust": 0.8, "listener": l2.id, "named": named_all,
							"named_evil": named_all.filter(func(p): return w.by_id.has(p) and w.by_id[p].is_evil()).size()}
						r3.merge(_summary(g, dd, l2.id, named_all), true)
						rows.append(r3)

# ---------------------------------------------------------------- shared helpers

func _listener_for(g, exclude: Array):
	var c: Array = g.w.npcs.filter(func(m): return m.alive and not m.is_evil() and m.id not in exclude)
	return c[0] if not c.is_empty() else null

func _row(g, evidence: String, extra: Dictionary, d: Dictionary, listener_id: String, named: Array) -> Dictionary:
	var w = g.w
	var r: Dictionary = {"seed": w.seed_value, "size": w.n_npcs, "demon_type": w.by_id[w.demon_id].role, "evidence": evidence, "listener": listener_id,
		"named": named, "named_evil": named.filter(func(p): return w.by_id.has(p) and w.by_id[p].is_evil()).size()}
	r.merge(extra, true)
	r.merge(_summary(g, d, listener_id, named), true)
	return r

func _tell(w, n, teller_id: String, card: Dictionary, trust: float) -> void:
	var receipt = Mind.WorkshopLedger.Evidence.normalize_card(card)
	var wgt: float = clampf(Tuning.Social.HEARSAY_TRUST_SCALE * trust, 0.0, Tuning.Social.HEARSAY_WEIGHT_CAP)
	Mind.ledger_hear(w, n, "heard:" + receipt.id, [], wgt * 2.0, [str(card.get("source", teller_id)), int(card.get("day", -1)), "report"],
		{"kind": "tell", "workshop_card": receipt, "workshop_teller": teller_id, "workshop_origin": str(card.get("source", teller_id)), "workshop_public": false})

# ---------------------------------------------------------------- social: sightings, alibis, claims

func _measure_social(g) -> void:
	var w = g.w
	# Night sightings an NPC made, told to a listener; and the subject's home alibi for that
	# night, alone and against the sighting.
	var done: Dictionary = {}
	for s in w.npcs:
		if s.is_evil():
			continue
		for b in s.beliefs:
			if b.get("kind", "") != "saw" or int(b.get("phase", -1)) != C.NIGHT:
				continue
			var who: String = str(b.get("who", ""))
			var night: int = int(b.get("day", -1))
			if who == "" or not w.by_id.has(who) or night < 0 or done.has(who + str(night)):
				continue
			done[who + str(night)] = true
			var subj = w.by_id[who]
			var sight = {"kind": "sighting", "source": s.id, "subject": [who], "block": str(b.get("block", "")), "day": night, "phase": C.NIGHT,
				"text": "%s saw %s out on night %d." % [s.name, subj.name, night]}
			var alibi = {"kind": "alibi", "source": who, "subject": [who], "home": true, "block": subj.home_block, "day": night, "phase": C.NIGHT,
				"text": "%s says they were home on night %d." % [subj.name, night]}
			var l = _listener_for(g, [s.id, who])
			if l == null:
				continue
			var extra = {"subject_role": subj.role, "subject_evil": subj.is_evil(), "night": night}
			for t in TRUSTS:
				var d1 = _delta(g, l, {s.id: t, who: 0.5}, func(n): _tell(w, n, s.id, sight, t))
				if not d1.is_empty():
					rows.append(_row(g, "night_sighting", extra.merged({"trust": t, "mode": "heard"}), d1, l.id, [who]))
				var d2 = _delta(g, l, {s.id: 0.5, who: t}, func(n): _tell(w, n, who, alibi, t))
				if not d2.is_empty():
					rows.append(_row(g, "home_alibi", extra.merged({"trust": t, "mode": "heard"}), d2, l.id, [who]))
				var d3 = _delta(g, l, {s.id: t, who: 0.5}, func(n):
					_tell(w, n, s.id, sight, t)
					_tell(w, n, who, alibi, 0.5))
				if not d3.is_empty():
					rows.append(_row(g, "sighting_vs_alibi", extra.merged({"trust": t, "mode": "heard"}), d3, l.id, [who]))
	# Role claims: each person claims their real gift (good) or their cover (evil); and a
	# clash, an evil claimant on a good holder's gift.
	var goods: Array = w.npcs.filter(func(m): return not m.is_evil() and C.ROLES.has(m.role) and C.ROLES[m.role].align == "good")
	for x in w.npcs:
		var role: String = x.role if not x.is_evil() else str(x.claimed_role)
		if role == "" or not C.ROLES.has(role) or C.ROLES[role].align != "good":
			continue
		var l = _listener_for(g, [x.id])
		if l == null:
			continue
		for t in TRUSTS:
			var d = _delta(g, l, {x.id: t}, func(n): Mind.hear_claim(w, n, x.id, role, Mind.Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "told"))
			if not d.is_empty():
				rows.append(_row(g, "role_claim", {"trust": t, "mode": "heard", "claimed": role, "subject_evil": x.is_evil()}, d, l.id, [x.id]))
	var evils: Array = w.npcs.filter(func(m): return m.is_evil())
	for h in goods.slice(0, 2):
		var e = evils[0]
		var l = _listener_for(g, [h.id, e.id])
		if l == null:
			continue
		for t in TRUSTS:
			var d = _delta(g, l, {h.id: t, e.id: t}, func(n):
				Mind.hear_claim(w, n, h.id, h.role, Mind.Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "told")
				Mind.hear_claim(w, n, e.id, h.role, Mind.Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "told"))
			if not d.is_empty():
				rows.append(_row(g, "claim_clash", {"trust": t, "mode": "heard", "claimed": h.role, "holder": h.id, "bluffer": e.id}, d, l.id, [h.id, e.id]))

# ---------------------------------------------------------------- public events

func _measure_public(g) -> void:
	var w = g.w
	var l = _listener_for(g, [])
	if l == null:
		return
	for e in w.public_log:
		if e.kind not in ["demon_death", "silenced"]:
			continue
		var subjects: Array = e.get("subjects", [])
		var day: int = int(e.get("day", -1))
		var key: String = e.kind
		# The listener's view with the event, against the same view without it.
		var saved: Dictionary = _save(l)
		_wipe(g, l)
		drop_events = func(ev): return ev.kind == key and ev.subjects == subjects and int(ev.get("at", {}).get("day", -1)) == day
		var without: Dictionary = _view(g, l)
		drop_events = Callable()
		var with_ev: Dictionary = _view(g, l)
		_restore(l, saved)
		if without.is_empty() or with_ev.is_empty():
			continue
		var d: Dictionary = {}
		for id in with_ev:
			d[id] = with_ev[id] - float(without.get(id, 0.0))
		rows.append(_row(g, key, {"trust": 1.0, "mode": "public", "day": day, "subject_evil": subjects.any(func(p): return w.by_id[p].is_evil())}, d, l.id, subjects))

# ---------------------------------------------------------------- player-found evidence, presented

## Cards the player finds by searching a scene or a spot, presented privately to a fresh
## listener as "X is evil" for the person they point to (the killer, the owner).
func _measure_player(g) -> void:
	var w = g.w
	var finds: Array = []
	for sid in w.scenes.keys():
		var before: int = g.board.size()
		g.loc = sid
		GameDayNight._search(g)
		var nums: Array = range(before + 1, g.board.size() + 1)
		if not nums.is_empty():
			finds.append({"evidence": "trace", "nums": nums, "target": w.demon_id, "scene": sid})
	for loc in w.dropped.keys().duplicate():
		var owners: Array = w.dropped[loc].map(func(it): return str(it.get("owner", ""))).filter(func(o): return o != "")
		var before: int = g.board.size()
		g.loc = loc
		GameDayNight._search(g)
		var nums: Array = range(before + 1, g.board.size() + 1)
		var target: String = owners[0] if not owners.is_empty() else ""
		if not nums.is_empty() and target != "":
			finds.append({"evidence": "dropped_belongings", "nums": nums, "target": target})
	# Partner for traces: everyone's workplace and haunts as profile cards (what a player
	# learns about town), cited with the trace.
	var profile_nums: Array = []
	for m in w.npcs:
		if str(m.get("work")) != "" and C.LOCATIONS.has(str(m.work)):
			profile_nums.append(g.add_profile_receipt({"kind": "work", "subject": [m.id], "source": "town", "loc": m.work, "block": w.loc_block(m.work),
				"day": w.day, "phase": g._phase_now(), "class": "circumstantial", "text": "%s works at %s." % [m.name, w.loc_name(m.work)]}))
		for h in m.haunts:
			if C.LOCATIONS.has(str(h)):
				profile_nums.append(g.add_profile_receipt({"kind": "haunt", "subject": [m.id], "source": "town", "loc": h, "locs": [h], "block": w.loc_block(h),
					"day": w.day, "phase": g._phase_now(), "class": "circumstantial", "text": "%s often goes to %s when off work." % [m.name, w.loc_name(h)]}))
	var with_profile: Array = []
	for f in finds:
		if f.evidence == "trace":
			with_profile.append({"evidence": "trace_with_profiles", "nums": f.nums + profile_nums, "target": f.target, "scene": f.scene})
	finds.append_array(with_profile)
	# The profile cards alone, cited against the Demon, so a trace's interaction with them
	# (both - trace - profiles) can be read off.
	if finds.any(func(f): return f.evidence == "trace"):
		finds.append({"evidence": "profiles_alone", "nums": profile_nums, "target": w.demon_id})
	for f in finds:
		var target: String = f.target
		var l = _listener_for(g, [target])
		if l == null:
			continue
		for t in TRUSTS:
			var d = _delta(g, l, {}, func(n):
				n.credibility = t
				n.trust = t
				var ded: int = g.file_deduction({"type": "evil", "a": target}, f.nums)
				g._evaluate_deduction(n, g.board[ded - 1], 1.0, false))
			if not d.is_empty():
				var kinds: Array = f.nums.filter(func(k): return k > 0).map(func(k): return str(g.board[k - 1].get("kind", "")) + ":" + str(g.board[k - 1].get("trace_family", "")))
				rows.append(_row(g, f.evidence, {"trust": t, "mode": "presented", "cards": kinds, "target": target, "target_evil": w.by_id[target].is_evil(),
					"target_role": w.by_id[target].role}, d, l.id, [target]))

# ---------------------------------------------------------------- interaction table

## Every person's P(evil) and P(Demon) for a fresh listener holding only what `injects` give
## it (the shared model's posterior, tools/belief_views.gd). {} if the refresh had issues.
## `quality_of`: sources whose witness quality to report, measured in the experiment's state
## (injected trust, wiped suspicion) before the listener is restored.
func _beliefs(g, n, trust_in: Dictionary, injects: Array, quality_of: Array = []) -> Dictionary:
	var saved: Dictionary = _save(n)
	if not keep_state:
		_wipe(g, n)
	for id in trust_in:
		n.npc_trust[id] = trust_in[id]
	for f in injects:
		f.call(n)
	Caches.clear_all()
	var v: Dictionary = Views.mind(g, n, 1)
	var issues: Array = n.workshop_state.get("issues", [])
	var q: Dictionary = {}
	for id in quality_of:
		q[id] = _quality(n, id)
	_restore(n, saved)
	Caches.clear_all()
	if not issues.is_empty() or v.get("p_evil", {}).is_empty():
		return {}
	# With no gift or movement card in play the worlds carry no Demon identity: P(Demon) is
	# then not modelled (null), not zero.
	var out: Dictionary = {"e": v.p_evil, "d": v.demon if not v.demon.is_empty() else null}
	if not quality_of.is_empty():
		out["q"] = q
	return out

## Four conditions (context only, +A, +B, +A+B), one row per person. Context cards are held
## in all four. Returns the largest |interaction| in log-odds (joint - A - B + none) on P(evil).
func _pair(g, n, pair_type: String, a_desc: Dictionary, b_desc: Dictionary, a: Callable, b: Callable, ctx: Array, trust_in: Dictionary, extra: Dictionary = {}) -> float:
	var conds: Array = [[], [a], [b], [a, b]]
	var res: Array = []
	for c in conds:
		var r: Dictionary = _beliefs(g, n, trust_in, ctx + c)
		if r.is_empty():
			return -1.0
		res.append(r)
	var w = g.w
	var worst: float = 0.0
	for id in res[0].e:
		if id == n.id or not w.by_id.has(id):
			continue
		var e: Array = res.map(func(r): return float(r.e.get(id, 0.0)))
		var d: Array = res.map(func(r): return float(r.d.get(id, 0.0)) if r.d != null else null)
		var inter: float = _lo(e[3]) - _lo(e[1]) - _lo(e[2]) + _lo(e[0])
		worst = maxf(worst, absf(inter))
		var row: Dictionary = {"seed": w.seed_value, "size": w.n_npcs, "day": w.day, "demon_type": w.by_id[w.demon_id].role,
			"script_demons": w.case_script.demons if w.get("case_script") != null else [], "declared": Activity.declared_demon_type,
			"pair_type": pair_type, "listener": n.id, "listener_role": n.role, "a": a_desc, "b": b_desc, "context": ctx.size(), "trust_in": trust_in,
			"person": id, "person_evil": w.by_id[id].is_evil(), "person_demon": id == w.demon_id,
			"p_evil": e, "p_demon": d, "interaction_lo": snappedf(inter, 0.001)}
		row.merge(extra, true)
		rows.append(row)
	return worst

func _lo(p: float) -> float:
	var q: float = clampf(p, 0.01, 0.99)
	return log(q / (1.0 - q))

func _reading_desc(s, e: Dictionary) -> Dictionary:
	return {"kind": "reading", "role": str(e.get("role", "")), "teller": s.id, "teller_evil": s.is_evil(), "true": bool(e.get("true", true)),
		"day": int(e.get("day", -1)), "data": e.get("data", {}), "named": _named(e)}

func _heard(w, s, e: Dictionary) -> Callable:
	return func(n): Mind.apply_info(w, n, s, e, Mind.heard_weight(n, s))

func _claimed(w, who: String, role: String) -> Callable:
	return func(n): Mind.hear_claim(w, n, who, role, Mind.Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "told")

func _told(w, teller: String, card: Dictionary, t: float) -> Callable:
	return func(n): _tell(w, n, teller, card, t)

## Night sightings good NPCs made: [{teller, who, night, block, card}].
func _sightings(g) -> Array:
	var out: Array = []
	var done: Dictionary = {}
	for s in g.w.npcs:
		if s.is_evil():
			continue
		for b in s.beliefs:
			if b.get("kind", "") != "saw" or int(b.get("phase", -1)) != C.NIGHT:
				continue
			var who: String = str(b.get("who", ""))
			var night: int = int(b.get("day", -1))
			if who == "" or not g.w.by_id.has(who) or night < 0 or done.has(who + str(night)):
				continue
			done[who + str(night)] = true
			out.append({"teller": s.id, "who": who, "night": night, "block": str(b.get("block", "")),
				"card": {"kind": "sighting", "source": s.id, "subject": [who], "block": str(b.get("block", "")), "day": night, "phase": C.NIGHT,
					"text": "%s saw %s out on night %d." % [s.name, g.w.by_id[who].name, night]}})
	return out

## Readings by holder (good and evil alike; an evil holder's are its bluffs if it keeps any).
func _readings(g) -> Array:
	var out: Array = []
	for s in g.w.npcs:
		for e in s.info_log:
			var role: String = str(e.get("role", ""))
			if role != "" and C.role_def(role) != null and int(e.get("day", -1)) <= g.w.day:
				out.append({"s": s, "e": e})
	return out

func _claim_role(x) -> String:
	var role: String = x.role if not x.is_evil() else str(x.claimed_role)
	return role if role != "" and C.ROLES.has(role) and C.ROLES[role].align == "good" else ""

func _measure_interactions(g) -> void:
	var w = g.w
	var reads: Array = _readings(g)
	var sights: Array = _sightings(g)
	var goods: Array = reads.filter(func(r): return not r.s.is_evil())
	# Readings that name people first: they are the ones a pairing can act on.
	goods.sort_custom(func(a, b): return _named(a.e).size() > _named(b.e).size())
	for t in TRUSTS:
		# 1. An own reading with a heard card (the core test).
		var holders: Dictionary = {}
		for r in goods:
			if holders.size() >= 3 and not holders.has(r.s.id):
				continue
			if not holders.has(r.s.id):
				holders[r.s.id] = r
		for hid in holders:
			var own: Dictionary = holders[hid]
			var l = own.s
			if not l.alive:
				continue
			var own_inj: Callable = func(n):
				n.info_log = [own.e]
				Mind.apply_info(w, n, n, own.e, 1.0)
			var others: Array = goods.filter(func(r): return r.s.id != l.id)
			for other in others.slice(0, 2):
				_pair(g, l, "own_reading+heard_reading", _reading_desc(l, own.e), _reading_desc(other.s, other.e), own_inj, _heard(w, other.s, other.e),
					[_claimed(w, other.s.id, str(other.e.role))], {other.s.id: t}, {"trust": t})
			for sg in sights.filter(func(x): return x.teller != l.id).slice(0, 1):
				_pair(g, l, "own_reading+heard_sighting", _reading_desc(l, own.e), {"kind": "sighting", "teller": sg.teller, "who": sg.who, "night": sg.night},
					own_inj, _told(w, sg.teller, sg.card, t), [], {sg.teller: t}, {"trust": t})
		# 2. Two statements from one teller (with its claim as context).
		var by_teller: Dictionary = {}
		for r in reads:
			if not by_teller.has(r.s.id):
				by_teller[r.s.id] = []
			by_teller[r.s.id].append(r)
		var bundles: int = 0
		for tid in by_teller:
			var rs: Array = by_teller[tid]
			if rs.size() < 2 or bundles >= 3:
				continue
			bundles += 1
			var s = rs[0].s
			var l = _listener_for(g, [s.id] + _named(rs[0].e) + _named(rs[1].e))
			if l == null:
				l = _listener_for(g, [s.id])
			if l == null:
				continue
			_pair(g, l, "teller_bundle", _reading_desc(s, rs[0].e), _reading_desc(s, rs[1].e), _heard(w, s, rs[0].e), _heard(w, s, rs[1].e),
				[_claimed(w, s.id, str(rs[0].e.role))], {s.id: t}, {"trust": t})
		# 3. Structural pairings.
		var n_struct: int = 0
		for sg in sights:
			if n_struct >= 3:
				break
			n_struct += 1
			var subj = w.by_id[sg.who]
			var l = _listener_for(g, [sg.teller, sg.who])
			if l == null:
				continue
			var alibi = {"kind": "alibi", "source": sg.who, "subject": [sg.who], "home": true, "block": subj.home_block, "day": sg.night, "phase": C.NIGHT,
				"text": "%s says they were home on night %d." % [subj.name, sg.night]}
			var sd: Dictionary = {"kind": "sighting", "teller": sg.teller, "who": sg.who, "night": sg.night, "who_evil": subj.is_evil(), "who_role": subj.role}
			var ad: Dictionary = {"kind": "home_alibi", "teller": sg.who, "night": sg.night}
			var role: String = _claim_role(subj)
			var claim_ctx: Array = [_claimed(w, sg.who, role)] if role != "" else []
			_pair(g, l, "sighting+alibi", sd, ad, _told(w, sg.teller, sg.card, t), _told(w, sg.who, alibi, 0.5), [], {sg.teller: t, sg.who: 0.5}, {"trust": t})
			if role != "":
				_pair(g, l, "sighting+alibi|claim", sd, ad, _told(w, sg.teller, sg.card, t), _told(w, sg.who, alibi, 0.5), claim_ctx, {sg.teller: t, sg.who: 0.5}, {"trust": t, "claimed": role})
				_pair(g, l, "sighting+claim", sd, {"kind": "claim", "teller": sg.who, "role": role}, _told(w, sg.teller, sg.card, t), claim_ctx[0], [], {sg.teller: t, sg.who: 0.5}, {"trust": t, "claimed": role})
		for r in goods:
			var role: String = str(r.e.role)
			if role not in ["lamplighter", "augur", "psychologist"]:
				continue
			var near: Array = sights.filter(func(x): return x.night == int(r.e.get("day", -1)) or x.night == int(r.e.get("day", -1)) - 1)
			if near.is_empty():
				continue
			var sg: Dictionary = near[0]
			var l = _listener_for(g, [r.s.id, sg.teller, sg.who])
			if l == null:
				continue
			_pair(g, l, role + "+sighting", _reading_desc(r.s, r.e), {"kind": "sighting", "teller": sg.teller, "who": sg.who, "night": sg.night},
				_heard(w, r.s, r.e), _told(w, sg.teller, sg.card, t), [_claimed(w, r.s.id, role)], {r.s.id: t, sg.teller: t}, {"trust": t})
		# 4. A reading with its teller's claim.
		for r in goods.slice(0, 3):
			var l = _listener_for(g, [r.s.id] + _named(r.e))
			if l == null:
				continue
			_pair(g, l, "reading+teller_claim", _reading_desc(r.s, r.e), {"kind": "claim", "teller": r.s.id, "role": str(r.e.role)},
				_heard(w, r.s, r.e), _claimed(w, r.s.id, str(r.e.role)), [], {r.s.id: t}, {"trust": t})
		# 5. Cross-teller pairs that share a named person (what a player would present).
		var crosses: int = 0
		for i in range(goods.size()):
			for j in range(i + 1, goods.size()):
				if crosses >= 4:
					break
				var x: Dictionary = goods[i]
				var y: Dictionary = goods[j]
				if x.s.id == y.s.id or _named(x.e).filter(func(p): return p in _named(y.e)).is_empty():
					continue
				var l = _listener_for(g, [x.s.id, y.s.id] + _named(x.e) + _named(y.e))
				if l == null:
					l = _listener_for(g, [x.s.id, y.s.id])
				if l == null:
					continue
				crosses += 1
				_pair(g, l, "cross_teller", _reading_desc(x.s, x.e), _reading_desc(y.s, y.e), _heard(w, x.s, x.e), _heard(w, y.s, y.e),
					[_claimed(w, x.s.id, str(x.e.role)), _claimed(w, y.s.id, str(y.e.role))], {x.s.id: t, y.s.id: t}, {"trust": t})

# ---------------------------------------------------------------- premises and challenges

## Two readings that share a named person, put on the player's board and presented to a fresh
## listener under each premise, and with a "lying" or "misled" challenge on the first one
## (grounded by the second, premise: its teller is evil). Compared with the listener holding
## the two cards unpresented. One row per variant and person.
func _measure_premises(g) -> void:
	var w = g.w
	var goods: Array = _readings(g).filter(func(r): return not r.s.is_evil() and str(r.e.role) not in ["lamplighter"])
	var pairs: Array = []
	for i in range(goods.size()):
		for j in range(i + 1, goods.size()):
			if pairs.size() >= 3:
				break
			var x: Dictionary = goods[i]
			var y: Dictionary = goods[j]
			var shared: Array = _named(x.e).filter(func(p): return p in _named(y.e))
			if x.s.id != y.s.id and not shared.is_empty():
				pairs.append([x, y, shared[0]])
	# Not enough overlapping pairs: pair readings from different tellers anyway, the target
	# being the first person the first one names.
	for i in range(goods.size()):
		for j in range(i + 1, goods.size()):
			if pairs.size() >= 3:
				break
			var x: Dictionary = goods[i]
			var y: Dictionary = goods[j]
			if x.s.id != y.s.id and not _named(x.e).is_empty() and not pairs.any(func(p): return p[0] == x and p[1] == y):
				pairs.append([x, y, _named(x.e)[0]])
	if OS.has_environment("MEASURE_DEBUG"):
		print("premises: %d readings, %d pairs" % [goods.size(), pairs.size()])
	for pr in pairs:
		var x: Dictionary = pr[0]
		var y: Dictionary = pr[1]
		var target: String = pr[2]
		var nx: int = _board_reading(g, x.s, x.e)
		var ny: int = _board_reading(g, y.s, y.e)
		var l = _listener_for(g, [x.s.id, y.s.id] + _named(x.e) + _named(y.e))
		if l == null:
			l = _listener_for(g, [x.s.id, y.s.id, target])
		if l == null:
			continue
		var claims: Array = [_claimed(w, x.s.id, str(x.e.role)), _claimed(w, y.s.id, str(y.e.role))]
		for t in TRUSTS:
			var trust_in: Dictionary = {x.s.id: 0.5, y.s.id: 0.5}
			var base: Dictionary = {"pair": [_reading_desc(x.s, x.e), _reading_desc(y.s, y.e)], "trust": t, "target": target}
			var variants: Array = [
				["none", claims, {}],
				["held", claims + [_heard(w, x.s, x.e), _heard(w, y.s, y.e)], {}],
				["premise_evil", claims, {"type": "evil", "target": target}],
				["premise_suspicious", claims, {"type": "suspicious", "target": target}],
				["premise_good", claims, {"type": "good", "target": target}],
				["lying_challenge", claims, {"type": "evil", "target": x.s.id, "challenge": "lying"}],
				["misled_challenge", claims, {"type": "evil", "target": x.s.id, "challenge": "misled"}],
				["no_challenge", claims, {"type": "evil", "target": x.s.id}],
			]
			var res: Dictionary = {}
			for v in variants:
				var injects: Array = v[1].duplicate()
				var case_def: Dictionary = v[2]
				if not case_def.is_empty():
					injects.append(func(n):
						n.credibility = t
						n.trust = t
						var filed: int = _file_case(g, case_def, [nx, ny], nx)
						if OS.has_environment("MEASURE_DEBUG"):
							print("    filed %d %s" % [filed, g.last_error])
						if filed > 0:
							var s0: Dictionary = n.suspicion.duplicate(true)
							CaseEval.captured = []
							CaseEval.capture_worlds = true
							var er: Dictionary = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
							CaseEval.capture_worlds = false
							if OS.has_environment("MEASURE_DEBUG"):
								print("    eval keys ", er.keys(), " ", str(er).left(300), " err=", g.last_error)
							# Today a presentation is judged as its own case: its posterior is
							# the case's verdict, and the listener's suspicion step what it did.
							var post: Dictionary = {}
							for cap in CaseEval.captured:
								for id in cap.get("people", {}):
									post[id] = float(cap.people[id].posterior)
							CaseEval.captured = []
							last_case = {"case_p_evil": post, "susp_step": {}, "challenge": {}}
							for res_c in er.get("assessment", {}).get("reading_challenges", []):
								last_case.challenge = {"mode": res_c.get("mode", ""), "multiplier": float(res_c.get("multiplier", 1.0)),
									"effect": float(res_c.get("graded", {}).get("effect", 0.0)), "backfire": bool(res_c.get("backfire", false))}
							for id in n.suspicion:
								last_case.susp_step[id] = float(n.suspicion[id]) - float(s0.get(id, n.suspicion[id])))
				last_case = {}
				var r: Dictionary = _beliefs(g, l, trust_in, injects)
				if not r.is_empty():
					r.merge(last_case, true)
				if OS.has_environment("MEASURE_DEBUG"):
					print("  variant %s: %s %s" % [v[0], "ok" if not r.is_empty() else "EMPTY", g.last_error])
				if not r.is_empty():
					res[v[0]] = r
			if not res.has("none"):
				continue
			for id in res.none.e:
				if id == l.id or not w.by_id.has(id):
					continue
				var row: Dictionary = {"seed": w.seed_value, "size": w.n_npcs, "day": w.day, "demon_type": w.by_id[w.demon_id].role, "declared": Activity.declared_demon_type,
					"evidence": "premises", "listener": l.id, "person": id, "person_evil": w.by_id[id].is_evil(), "person_demon": id == w.demon_id, "p_evil": {}, "p_demon": {}}
				row.merge(base, true)
				row["case_p_evil"] = {}
				row["susp_step"] = {}
				row["challenge"] = {}
				for k in res:
					if res[k].has("case_p_evil"):
						row.case_p_evil[k] = float(res[k].case_p_evil.get(id, -1.0))
						row.susp_step[k] = float(res[k].susp_step.get(id, 0.0))
						if not res[k].get("challenge", {}).is_empty():
							row.challenge[k] = res[k].challenge
					row.p_evil[k] = float(res[k].e.get(id, 0.0))
					row.p_demon[k] = float(res[k].d.get(id, 0.0)) if res[k].d != null else null
				rows.append(row)

func _board_reading(g, s, e: Dictionary) -> int:
	var card: Dictionary = Bridge._reading(s.id, e)
	if str(card.text) == "":
		card.text = "%s's %s reading, day %d: %s" % [s.name, e.role, int(e.get("day", 0)), JSON.stringify(e.get("data", {}))]
	return g.add_card(card)

## File a canvas case: premise (type, target) supported by `support`; with case_def.challenge,
## that challenge on board card `challenged`, grounded by the other support cards.
func _file_case(g, case_def: Dictionary, support: Array, challenged: int) -> int:
	var view: Dictionary = Canvas.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(case_def.target, case_def.type, Vector2(400, 40))
	var nodes: Dictionary = {}
	for number in support:
		nodes[number] = _canvas_node(g, model, view, number)
		if nodes[number] == "":
			return -1
		model.connect_cards(nodes[number], premise)
	if case_def.has("challenge"):
		if model.add_modifier(nodes[challenged], case_def.challenge) != "":
			return -1
		var ch: String = model.selected
		for number in support:
			if number != challenged:
				model.connect_cards(nodes[number], ch)
		model.connect_cards(ch, premise)
	return Canvas.file(g, model.compile(premise))

func _canvas_node(g, model, view: Dictionary, number: int) -> String:
	var text: String = str(g.board[number - 1].text)
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence":
			var c: Dictionary = Solver.card_by_id(view, nd.card)
			if c.get("number", -1) == number or c.get("n", -1) == number or c.get("text", "") == text:
				return id
	return ""

# ---------------------------------------------------------------- constructed cross-checks

## A Confessor reading on `target` by `teller` on night `night`, true to the referee.
func _confession(g, target: String, night: int, good: bool) -> Dictionary:
	var nm: String = g.w.by_id[target].name
	return {"role": "confessor", "data": {"good": good, "target": target}, "day": night, "shared": true,
		"true": good == (not g.w.by_id[target].is_evil()),
		"text": ("I heard %s's confession: their heart was pure and their spirit good" % nm) if good else ("%s's spirit gave me nothing" % nm)}

## A good, living NPC to tell constructed Confessor readings: the real Confessor if good,
## otherwise anyone good outside `exclude`. Returns [npc, claimed role].
func _confessor_teller(g, exclude: Array) -> Array:
	for m in g.w.npcs:
		if m.role == "confessor" and not m.is_evil() and m.id not in exclude:
			return [m, "confessor"]
	# Otherwise a good NPC outside `exclude`, the dead first (leave the living to listen).
	for m in g.w.npcs:
		if not m.alive and not m.is_evil() and m.id not in exclude:
			return [m, "confessor"]
	var c = _listener_for(g, exclude)
	return [c, "confessor"] if c != null else []

## Accusing readings: an Archivist pair, or a Dowser count of one or more. Any teller
## (an evil one's are its bluffs). [{s, e, accused}]
func _accusing(g) -> Array:
	var out: Array = []
	for r in _readings(g):
		var d: Dictionary = r.e.get("data", {})
		match str(r.e.role):
			"archivist":
				out.append({"s": r.s, "e": r.e, "accused": Array(d.get("pair", []))})
			"dowser":
				if int(d.get("count", 0)) >= 1:
					out.append({"s": r.s, "e": r.e, "accused": Array(d.get("group", []))})
			"seer":
				if bool(d.get("yes", false)):
					out.append({"s": r.s, "e": r.e, "accused": Array(d.get("pair", []))})
	if construct_bluffs:
		out = out.filter(func(x): return not x.s.is_evil())
		var cb: Array = _constructed_bluffs(g)
		out.append_array(cb)
	if construct_mistakes:
		out = out.filter(func(x): return not x.s.is_evil() or x.e.get("fake", false))
		out.append_array(_constructed_mistakes(g))
	return out.filter(func(x): return x.accused.size() >= 2 and x.accused.all(func(p): return g.w.by_id.has(p)))

## --construct-bluffs: each living evil NPC tells a false accusation about two good people,
## an Archivist pair (first night) and a Seer "yes" (night 1), so a challenge grounded in
## true Confessor readings has a sample shaped like the honest-reading one.
func _constructed_bluffs(g) -> Array:
	var w = g.w
	var out: Array = []
	# Living goods first, keeping one back to listen. The dead come last: a Demon victim is
	# publicly good, so a bluff naming one is plainly false without any challenge.
	var alive_goods: Array = w.npcs.filter(func(m): return not m.is_evil() and m.alive)
	var goods: Array = alive_goods.slice(0, maxi(0, alive_goods.size() - 1)) + w.npcs.filter(func(m): return not m.is_evil() and not m.alive)
	var minion_role: String = str(w.case_script.minions[0]) if w.get("case_script") != null and not w.case_script.minions.is_empty() else "poisoner"
	var k: int = 0
	for e in w.npcs.filter(func(m): return m.is_evil() and m.alive):
		if goods.size() < 2:
			break
		if k + 1 >= goods.size():
			k = 0
		var a = goods[k % goods.size()]
		var b = goods[(k + 1) % goods.size()]
		k += 2
		var arch: Dictionary = {"role": "archivist", "data": {"pair": [a.id, b.id], "role": minion_role}, "day": 0, "true": false, "fake": true, "shared": true,
			"text": "One of %s and %s is the %s." % [a.name, b.name, C.ROLES[minion_role].name]}
		var seer: Dictionary = {"role": "seer", "data": {"pair": [a.id, b.id], "yes": true}, "day": 1, "true": false, "fake": true, "shared": true,
			"text": "The Demon is %s or %s." % [a.name, b.name]}
		# The fresh listener holds only the claims the harness gives it, so a townsperson
		# really holding the gift doesn't make this a counter-claim in its view.
		out.append({"s": e, "e": arch, "accused": [a.id, b.id]})
		out.append({"s": e, "e": seer, "accused": [a.id, b.id]})
	return out

## --construct-mistakes: up to two good NPCs each tell a false accusation about two other
## good people, an Archivist pair and a Seer "yes": honest mistakes, as from a failed gift
## (a Poisoner on the script) or a misleading registration. Against true Confessor clears,
## "failed gift" or "misled" is the right explanation and "lying" the wrong one.
func _constructed_mistakes(g) -> Array:
	var w = g.w
	var out: Array = []
	var alive_goods: Array = w.npcs.filter(func(m): return not m.is_evil() and m.alive)
	var dead_goods: Array = w.npcs.filter(func(m): return not m.is_evil() and not m.alive)
	if alive_goods.size() < 2:
		return out
	var minion_role: String = str(w.case_script.minions[0]) if w.get("case_script") != null and not w.case_script.minions.is_empty() else "poisoner"
	# The teller is a living good; the last living good is kept back to listen. The accused
	# are other goods, living first (a dead one may be publicly cleared already).
	for ti in range(mini(2, alive_goods.size() - 1)):
		var t = alive_goods[ti]
		var pool: Array = alive_goods.slice(0, alive_goods.size() - 1).filter(func(m): return m.id != t.id) + dead_goods
		if pool.size() < 2:
			continue
		var a = pool[0]
		var b = pool[1]
		var arch: Dictionary = {"role": "archivist", "data": {"pair": [a.id, b.id], "role": minion_role}, "day": 0, "true": false, "mistake": true, "shared": true,
			"text": "One of %s and %s is the %s." % [a.name, b.name, C.ROLES[minion_role].name]}
		var seer: Dictionary = {"role": "seer", "data": {"pair": [a.id, b.id], "yes": true}, "day": 1, "true": false, "mistake": true, "shared": true,
			"text": "The Demon is %s or %s." % [a.name, b.name]}
		out.append({"s": t, "e": arch, "accused": [a.id, b.id]})
		out.append({"s": t, "e": seer, "accused": [a.id, b.id]})
	return out

func _measure_crosschecks(g) -> void:
	var w = g.w
	var night: int = clampi(w.day - 1, 1, 9)
	for t in TRUSTS:
		# Archivist pair or Dowser count, with a true Confessor reading clearing one of the
		# accused (a good one). The pair then points at the other.
		for x in _accusing(g):
			var cleared: Array = x.accused.filter(func(p): return not w.by_id[p].is_evil())
			if cleared.is_empty():
				continue
			var ct: Array = _confessor_teller(g, [x.s.id] + x.accused)
			if ct.is_empty():
				continue
			var c = ct[0]
			var conf: Dictionary = _confession(g, cleared[0], night, true)
			var l = _listener_for(g, [x.s.id, c.id] + x.accused)
			if l == null:
				continue
			_pair(g, l, str(x.e.role) + "+clearing_confessor", _reading_desc(x.s, x.e), _reading_desc(c, conf), _heard(w, x.s, x.e), _heard(w, c, conf),
				[_claimed(w, x.s.id, str(x.e.role)), _claimed(w, c.id, "confessor")], {x.s.id: t, c.id: t}, {"trust": t, "constructed": "b", "focus": x.accused.filter(func(p): return p != cleared[0])})
		# Psychologist pair readings with their two statements (as one card set).
		for r in _readings(g):
			if str(r.e.role) != "psychologist" or str(r.e.get("data", {}).get("mode", "")) != "pair":
				continue
			var facts: Array = Psych.companion_facts(w, r.s, r.e)
			if facts.size() < 2:
				continue
			var srcs: Array = facts.map(func(f): return str(f.source))
			var l = _listener_for(g, [r.s.id] + srcs)
			if l == null:
				continue
			var trust_in: Dictionary = {r.s.id: t}
			for sid in srcs:
				trust_in[sid] = 0.5
			var both: Callable = func(n):
				for f in facts:
					_statement(w, n, f)
			_pair(g, l, "psychologist+its_statements", _reading_desc(r.s, r.e), {"kind": "statements", "sources": srcs, "kinds": facts.map(func(f): return f.kind)},
				_heard(w, r.s, r.e), both, [_claimed(w, r.s.id, "psychologist")], trust_in, {"trust": t})

## Hear one of a Psychologist's statements first-hand from its source.
func _statement(w, n, f: Dictionary) -> void:
	var src = w.by_id[f.source]
	if f.kind == "info":
		var e: Dictionary = {"role": f.role, "data": f.data, "day": f.day, "text": f.text, "shared": true}
		if f.has("phase"):
			e["phase"] = f.phase
		Mind.apply_info(w, n, src, e, Mind.heard_weight(n, src))
		Mind.hear_claim(w, n, src.id, f.role, Mind.Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "told")
	else:
		var card: Dictionary = f.duplicate(true)
		card.erase("via")
		_tell(w, n, src.id, card, 0.5)

# ---------------------------------------------------------------- constructed challenges

func _measure_challenges(g) -> void:
	var w = g.w
	var night0: int = maxi(1, w.day - 2)
	for x in _accusing(g):
		var ct: Array = _confessor_teller(g, [x.s.id] + x.accused)
		if ct.is_empty():
			continue
		var c = ct[0]
		# Clear everyone the reading accuses, one Confessor reading a night: the grounds
		# then contradict it. True grounds if the reading is a bluff.
		var confs: Array = []
		for i in range(x.accused.size()):
			confs.append(_confession(g, x.accused[i], night0 + i, true))
		var l = _listener_for(g, [x.s.id, c.id] + x.accused)
		if l == null:
			continue
		var na: int = _board_reading(g, x.s, x.e)
		var nums: Array = [na]
		for e in confs:
			nums.append(_board_reading(g, c, e))
		var claims: Array = [_claimed(w, x.s.id, str(x.e.role)), _claimed(w, c.id, "confessor")]
		var held_all: Array = claims + [_heard(w, x.s, x.e)] + confs.map(func(e): return _heard(w, c, e))
		var accused0: String = x.accused[0]
		for tp in ([[-1.0, -1.0]] if natural_trust else [[0.4, 0.4], [0.4, 0.8], [0.8, 0.4], [0.8, 0.8]]):
			# Trust in the reading's teller and in the grounds' teller (grounds need
			# witness quality 0.4+, about trust 0.35 with no suspicion). --natural-trust:
			# the listener's own trust (with --keep-state, what it has come to think).
			var t: float = tp[1] if tp[1] >= 0.0 else 0.6
			var trust_in: Dictionary = {} if natural_trust else {x.s.id: tp[0], c.id: tp[1]}
			var variants: Array = [
				["none", claims, {}],
				["held", held_all, {}],
				["evil_teller", claims, {"type": "evil", "target": x.s.id}],
				["evil_teller+lying", claims, {"type": "evil", "target": x.s.id, "challenge": "lying"}],
				["good_accused", claims, {"type": "good", "target": accused0}],
				["good_accused+misled", claims, {"type": "good", "target": accused0, "challenge": "misled"}],
				["good_accused+impaired", claims, {"type": "good", "target": accused0, "challenge": "impaired"}],
			]
			var res: Dictionary = {}
			for v in variants:
				var injects: Array = v[1].duplicate()
				var case_def: Dictionary = v[2]
				if not case_def.is_empty():
					injects.append(func(n):
						n.credibility = t
						n.trust = t
						var filed: int = _file_case(g, case_def, nums, na)
						if filed > 0:
							_present(g, n, filed))
				last_case = {}
				var r: Dictionary = _beliefs(g, l, trust_in, injects, [x.s.id, c.id])
				if not r.is_empty():
					r.merge(last_case, true)
					res[v[0]] = r
			if not res.has("none"):
				continue
			for id in res.none.e:
				if id == l.id or not w.by_id.has(id):
					continue
				var row: Dictionary = {"seed": w.seed_value, "size": w.n_npcs, "day": w.day, "demon_type": w.by_id[w.demon_id].role,
					"evidence": "challenges", "listener": l.id, "trust": t, "trust_reader": tp[0], "trust_grounds": tp[1], "reading": _reading_desc(x.s, x.e), "accused": x.accused,
					"q_reader": float(res.none.q[x.s.id]), "q_grounds": float(res.none.q[c.id]), "grounds_true": confs.all(func(e): return bool(e["true"])), "accused_alive": x.accused.all(func(p): return w.by_id[p].alive), "confessor_teller": c.id, "poisoner_on_script": "poisoner" in w.case_script.minions,
					"person": id, "person_evil": w.by_id[id].is_evil(), "person_demon": id == w.demon_id,
					"role_in_case": "teller" if id == x.s.id else ("accused" if id in x.accused else ("confessor" if id == c.id else "")),
					"p_evil": {}, "case_p_evil": {}, "susp_step": {}, "challenge": {}}
				for k in res:
					row.p_evil[k] = float(res[k].e.get(id, 0.0))
					if res[k].has("case_p_evil"):
						row.case_p_evil[k] = float(res[k].case_p_evil.get(id, -1.0))
						row.susp_step[k] = float(res[k].susp_step.get(id, 0.0))
						if not res[k].get("challenge", {}).is_empty():
							row.challenge[k] = res[k].challenge
				rows.append(row)

## Evaluate a filed case for listener n, recording the case's own verdict, the suspicion
## step and any challenge result in last_case.
func _present(g, n, filed: int) -> void:
	var s0: Dictionary = n.suspicion.duplicate(true)
	CaseEval.captured = []
	CaseEval.capture_worlds = true
	var er: Dictionary = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	CaseEval.capture_worlds = false
	var post: Dictionary = {}
	for cap in CaseEval.captured:
		for id in cap.get("people", {}):
			post[id] = float(cap.people[id].posterior)
	CaseEval.captured = []
	last_case = {"case_p_evil": post, "susp_step": {}, "challenge": {}}
	for res_c in er.get("assessment", {}).get("reading_challenges", []):
		last_case.challenge = {"mode": res_c.get("mode", ""), "supported": bool(res_c.get("supported", false)), "multiplier": float(res_c.get("multiplier", 1.0)),
			"agreement": float(res_c.get("agreement", 0.0)), "accuracy_agreement": float(res_c.get("accuracy_agreement", 0.0)),
			"effect": float(res_c.get("graded", {}).get("effect", 0.0)), "cause": float(res_c.get("graded", {}).get("cause", 0.0)),
			"g_q": float(res_c.get("graded", {}).get("q", -1.0)), "g_f": float(res_c.get("graded", {}).get("f", -1.0)), "g_r": float(res_c.get("graded", {}).get("r", -1.0)),
			"g_wrong": float(res_c.get("graded", {}).get("wrong", -1.0)), "g_evil_share": float(res_c.get("graded", {}).get("evil_share", -1.0)), "graded_ran": not res_c.get("graded", {}).is_empty(),
			"backfire": bool(res_c.get("backfire", false))}
	for id in n.suspicion:
		last_case.susp_step[id] = float(n.suspicion[id]) - float(s0.get(id, n.suspicion[id]))

## ReadingChallenges.quality for an NPC listener (its witness quality of a teller).
func _quality(l, source: String) -> float:
	return RC.quality({"id": l.id, "npc_trust": l.npc_trust, "suspicion": l.suspicion, "trust": l.trust}, source)

## Evidence catalog, measured pass (docs/evidence_catalog.md). Plays seeds passively to day 3,
## harvests real readings from their holders, and measures what each does to a listener who
## knows nothing else: heard directly from the source at trust 0.4 and 0.8, and as the
## source's own reading. Also "all of this source's readings" (the partner case for repeat
## readings). Output: one JSON line per measurement, then a per-role summary.
##
## godot --headless --path . --script res://tools/measure_evidence.gd -- [--seeds 1:40] [--size 7] [--out file.jsonl]
##   [--default-script] [--force-demon daykiller]
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

const TRUSTS = [0.4, 0.8]
const STOP_DAY = 3
const FLAT = 0.25
var rows: Array = []

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
	g.new_case(sd, size, case_script)
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

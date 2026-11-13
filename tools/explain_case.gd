## Why did the town read a case that way? Replays a playtest dev log to the point where a
## Workshop case was filed, then presents that case (and variants of it) to every good mind
## and prints what the solver made of it.
##
## godot --headless --path . --script res://tools/explain_case.gd -- <log.jsonl> --card N [options]
##
## --card N            the case filed as board card N in the log
## --at SEQ            replay up to this seq instead (default: just after card N was filed)
## --drop              also try the case with each card removed (which cards carry it)
## --add X            add every report of person X (or the fact with this id prefix) to the
##                     case before anything else: the base case becomes "as filed + X".
##                     Repeatable.
## --challenge X=MODE  also try it with a reading challenge: X is a person (every report of
##                     theirs in the case) or a fact-id prefix; MODE is lying, misled or unlikely.
##                     Repeatable; "--challenge fenwick=lying" is the "Fenwick lied" case.
## --listener a,b      only these minds
## --why               after each presentation, print why that mind moved as far as it did:
##                     the suspicion the case could add at each step (face value, as heard,
##                     attention, already held, resistance, applied), the biggest loss, the
##                     vote bar, the strongest surviving alternative, and per card its
##                     status, world share and what the premise loses without it
##                     (game/workshop_why.gd). Read-only.
## --json OUT          also write every assessment as JSONL
## --connections       replay with the connections belief model on (logs record it from
##                     Nov 13 and turn it on by themselves); --why then explains its result
##
## Belief mode (no --card): --belief PERSON --at SEQ. Replays to SEQ and, for each good
## mind, removes each thing it has heard (each ledger entry: a reading, claim, defence,
## accusation, case...) one at a time, re-runs its belief refresh and reports how far its
## suspicion of PERSON moves. The biggest movers are why it believes what it does.
##
## For each variant and listener it prints the premise before and after the case (CaseEval
## prior and posterior, likelihood ratio and category), the listener's suspicion of the
## target before and after the presentation, where the probability went instead (rivals),
## and, per card, the listener's reliability for it and how likely it is to be accurate
## given everything (acceptance). Each variant replays the game afresh; presentations are
## real (WorkshopPresentation.present), at the meeting venue, without speech.
extends SceneTree
const Replay = preload("res://tools/log_replay.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const Mind = preload("res://sim/mind.gd")
const WorkshopWhy = preload("res://game/workshop_why.gd")

func _init():
	var args = OS.get_cmdline_user_args()
	var path: String = args[0]
	var card_n := 0
	var at := -1
	var drop := false
	var challenges: Array = []
	var adds: Array = []
	var only: Array = []
	var json_out := ""
	var belief := ""
	var why := false
	var top := 8
	var i := 1
	while i < args.size():
		match args[i]:
			"--card":
				card_n = int(args[i + 1]); i += 1
			"--connections":
				preload("res://workshop/connections.gd").enabled = true
			"--at":
				at = int(args[i + 1]); i += 1
			"--drop":
				drop = true
			"--why":
				why = true
			"--add":
				adds.append(str(args[i + 1])); i += 1
			"--challenge":
				challenges.append(str(args[i + 1])); i += 1
			"--listener":
				only = Array(str(args[i + 1]).split(",")); i += 1
			"--json":
				json_out = args[i + 1]; i += 1
			"--belief":
				belief = str(args[i + 1]); i += 1
			"--top":
				top = int(args[i + 1]); i += 1
		i += 1
	var events: Array = Replay.load_events(path)
	if belief != "":
		_belief_mode(events, belief, at, only, top)
		quit()
		return
	var filed: Array = events.filter(func(e): return e.type == "workshop_canvas_filed" and int(e.data.card) == card_n)
	if filed.is_empty():
		print("FAIL: the log files no card %d" % card_n)
		quit(1)
		return
	var base: Dictionary = filed[0].data.case
	if at < 0:
		at = int(filed[0].seq) + 1
	# The filed card itself is re-filed below for every variant: stop before its filing.
	var stop: int = mini(at, int(filed[0].seq))
	var variants: Array = [{"label": "as filed", "case": base}]
	var probe: Dictionary = Replay.replay(events, stop)
	var cards_info: Dictionary = _card_info(probe.g, base)
	for who in adds:
		var extra: Array = cards_info.keys().filter(func(id): return not id in base.cards and (id.begins_with(who) or (cards_info[id].source == who and cards_info[id].kind == "report")))
		if extra.is_empty():
			print("SKIP --add %s: no matching report the town has heard" % who)
			continue
		base = _with(base, extra)
	if not adds.is_empty():
		variants[0] = {"label": "as filed + " + ", ".join(adds), "case": base}
	if drop:
		for id in base.cards:
			variants.append({"label": "without %s" % _short(id, cards_info), "case": _without(base, id)})
	for spec in challenges:
		var who: String = spec.get_slice("=", 0)
		var mode: String = spec.get_slice("=", 1)
		var targets: Array = base.cards.filter(func(id): return id.begins_with(who) or (cards_info.has(id) and cards_info[id].source == who and cards_info[id].kind == "report"))
		if targets.is_empty():
			print("SKIP --challenge %s: no report in the case matches" % spec)
			continue
		variants.append({"label": "challenge %s %s" % [who, mode], "case": _challenged(base, targets, mode)})
	print("Case: %s %s (%d cards), replayed to seq %d" % [base.conclusion.get("target", "?"), base.conclusion.type, base.cards.size(), stop])
	for id in base.cards:
		print("  %s" % _describe(id, cards_info))
	var out_lines: Array = []
	var summary: Array = []
	for v in variants:
		var run: Dictionary = Replay.replay(events, stop)
		var g = run.g
		var n_card: int = Canvas.file(g, v.case, 0)
		print("\n=== %s ===" % v.label)
		if n_card < 0:
			print("  can't file this case: %s" % g.last_error)
			continue
		var card: Dictionary = g.board[n_card - 1]
		var target: String = str(v.case.conclusion.get("target", ""))
		var posts: Array = []
		for n in g.w.npcs:
			if not n.alive or n.is_evil() or (not only.is_empty() and not n.id in only):
				continue
			var before: float = Mind.susp(n, target)
			var why_was: Dictionary = WorkshopWhy.before(n, g) if why else {}
			var r: Dictionary = g.w.workshop_present.call(n, card, [], "deduction", "meeting", false)
			var after: float = Mind.susp(n, target)
			var a: Dictionary = r.get("assessment", {})
			var ce: Dictionary = a.get("case_eval", {})
			if ce.is_empty():
				print("%s: no assessment (%s)" % [n.id, str(r.get("unavailable", r.keys()))])
				continue
			posts.append(float(ce.posterior))
			var key: String = n.id + ":good"
			var rel: Dictionary = g._workshop_plans[key].prepared.listener.reading_reliability if g._workshop_plans.has(key) else {}
			print("%s  [%s] premise %.2f -> %.2f (LR %.2f, %s)  suspicion of %s %.2f -> %.2f" % [n.id, a.get("stance", "?"),
				float(ce.prior), float(ce.posterior), float(ce.lr), ce.category, target, before, after])
			var rivals: Array = ce.get("rivals", []).map(func(x): return "%s %.2f (%+.2f)" % [x.id, x.posterior, x.shift])
			print("    instead: " + ", ".join(rivals))
			for id in v.case.cards:
				var acc = ce.get("acceptance", {}).get(id, null)
				print("    %-34s reliability %s  accurate %s" % [_short(id, cards_info), "%.2f" % rel[id] if rel.has(id) else " -- ", "%.2f" % acc if acc != null else " -- "])
			if a.has("response"):
				print("    says: %s" % str(a.response).substr(0, 160))
			if why:
				var b: Dictionary = WorkshopWhy.presentation(g, n, card, "meeting", why_was)
				print("    " + str(b.get("text", "; ".join(PackedStringArray(b.get("issues", []))))).replace("\n", "\n    "))
				print("    (breakdown %d ms)" % int(b.get("elapsed_ms", 0)))
			out_lines.append({"variant": v.label, "listener": n.id, "stance": a.get("stance", ""), "prior": ce.prior, "posterior": ce.posterior,
				"lr": ce.lr, "category": ce.category, "suspicion_before": before, "suspicion_after": after,
				"rivals": ce.get("rivals", []), "acceptance": ce.get("acceptance", {}), "reliability": rel})
		var mean: float = 0.0
		for p in posts:
			mean += p
		summary.append([v.label, mean / maxf(1.0, posts.size()), posts.size()])
	print("\n=== summary: mean premise posterior over listeners ===")
	for s in summary:
		print("  %-40s %.2f  (%d listeners)" % [s[0], s[1], s[2]])
	if json_out != "":
		var f = FileAccess.open(json_out, FileAccess.WRITE)
		for l in out_lines:
			f.store_line(JSON.stringify(l))
		f.close()
	quit()

## Leave-one-out over each good mind's ledger: what holds its suspicion of `who` up or down.
func _belief_mode(events: Array, who: String, at: int, only: Array, top: int) -> void:
	if at < 0:
		print("FAIL: --belief needs --at SEQ")
		return
	var g = Replay.replay(events, at).g
	print("Why each mind suspects %s as it does (replayed to seq %d)" % [who, at])
	for n in g.w.npcs:
		if not n.alive or n.is_evil() or n.id == who or (not only.is_empty() and not n.id in only):
			continue
		Mind.refresh_beliefs(g.w, n, " (inspection)")
		var base: float = Mind.susp(n, who)
		var rows: Array = []
		for k in n.ledger.keys():
			var entry = n.ledger[k]
			n.ledger.erase(k)
			Mind.refresh_beliefs(g.w, n, " (inspection)")
			var without: float = Mind.susp(n, who)
			n.ledger[k] = entry
			if absf(without - base) >= 0.005:
				rows.append([base - without, k, entry])
		Mind.refresh_beliefs(g.w, n, " (inspection)")
		rows.sort_custom(func(a, b): return absf(a[0]) > absf(b[0]))
		print("\n%s: suspicion of %s %.2f (%d things heard; %d move it)" % [n.id, who, base, n.ledger.size(), rows.size()])
		for r in rows.slice(0, top):
			print("  %+.2f  %s" % [r[0], _ledger_label(r[1], r[2])])

static func _ledger_label(key: String, entry: Dictionary) -> String:
	var m: Dictionary = entry.get("meta", {})
	var kind: String = str(m.get("kind", "?"))
	var bits: Array = [kind]
	if m.has("move"):
		bits.append(str(m.move))
	var card: Dictionary = m.get("workshop_card", {})
	var text: String = str(m.get("text", card.get("text", "")))
	if m.has("scope") and m.scope.has("reading"):
		bits.append("on " + str(m.scope.reading).substr(5, 6))
	if text != "":
		bits.append('"' + text.substr(0, 90) + '"')
	bits.append("[" + key.substr(0, 48) + "]")
	return " ".join(bits)

## Source, kind, role and text of each fact, as the solver sees the cards: file the case
## and present it to one good mind (on the probe game, which is then discarded).
func _card_info(g, base: Dictionary) -> Dictionary:
	var info := {}
	var n_card: int = Canvas.file(g, base, 0)
	if n_card < 0:
		return info
	for n in g.w.npcs:
		if not n.alive or n.is_evil():
			continue
		g.w.workshop_present.call(n, g.board[n_card - 1], [], "deduction", "meeting", false)
		var key: String = n.id + ":good"
		if not g._workshop_plans.has(key):
			continue
		for c in g._workshop_plans[key].prepared.view.cards:
			if not info.has(c.id):
				info[c.id] = {"source": str(c.get("source", "")), "kind": str(c.get("kind", "")), "role": str(c.get("role", "")),
					"text": str(c.get("text", c.get("statement", "")))}
		if base.cards.all(func(id): return info.has(id)):
			break
	return info

func _short(id: String, info: Dictionary) -> String:
	var tag: String = id.substr(5, 6) if id.begins_with("fact:") else id.substr(0, 6)
	if info.has(id):
		return "%s %s (%s)" % [tag, info[id].source, info[id].role if info[id].role != "" else info[id].kind]
	return tag

func _describe(id: String, info: Dictionary) -> String:
	return "%s: %s" % [_short(id, info), info[id].text.substr(0, 110) if info.has(id) else "?"]

## The case with these cards added as direct support.
func _with(base: Dictionary, ids: Array) -> Dictionary:
	var c: Dictionary = base.duplicate(true)
	var cases: Array = [c] + c.get("arguments", []).map(func(a): return a.case)
	for cc in cases:
		for id in ids:
			if not id in cc.cards:
				cc.cards.append(id)
			if not cc.get("lines", []).is_empty() and not id in cc.lines[0].cards:
				cc.lines[0].cards.append(id)
	for arg in c.get("arguments", []):
		for id in ids:
			if arg.has("cards") and not id in arg.cards:
				arg.cards.append(id)
	return c

## The case with one card removed, everywhere the card appears.
func _without(base: Dictionary, id: String) -> Dictionary:
	var c: Dictionary = base.duplicate(true)
	_strip(c, id)
	for arg in c.get("arguments", []):
		_strip(arg.case, id)
	return c

func _strip(c: Dictionary, id: String) -> void:
	c.cards.erase(id)
	c.answers.erase(id)
	c.get("reading_challenges", {}).erase(id)
	for line in c.get("lines", []):
		line.cards.erase(id)

## The case with these reports challenged (the rest of the case as the grounds).
func _challenged(base: Dictionary, ids: Array, mode: String) -> Dictionary:
	var c: Dictionary = base.duplicate(true)
	var cases: Array = [c] + c.get("arguments", []).map(func(a): return a.case)
	for cc in cases:
		if not cc.has("reading_challenges"):
			cc["reading_challenges"] = {}
		for id in ids:
			cc.reading_challenges[id] = {"mode": mode, "supports": cc.cards.filter(func(x): return x != id)}
	return c

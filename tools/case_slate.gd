## The case benchmark slate (Michael, Nov 19; Quill with Lantern): standard constructed
## cases, each judged by the Test juror (the canvas's Strong / Moderate / Weak badge) and
## presented to the town, so a change to the judge or the belief model can be checked for
## drift and outliers. Like golden, a script plus a stored baseline report
## (docs/case_slate/), run on demand. Not a CI suite.
##
## Each case is built on a real deal (10 NPCs, seeds from 1): the cards are added to the
## board as the player would hold them, the player files the case about its subject and
## presents it to every good listener who isn't one of its sources, at credibility 0.7 with
## suspicion reset to 0.25. Every gift reading comes from that gift's real (good) holder,
## or the seed is skipped for that case. The subject is the Demon unless the case says
## otherwise. Recorded per case: the juror's category and strength (likelihood ratio), and
## the town's mean change in suspicion of the subject.
##
##   godot --headless --path . --script res://tools/case_slate.gd -- [--cases N] [--out FILE] [--only a,b]
##   python3 tools/case_slate_report.py FILE [BASELINE]   (the report; against a baseline)
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const C = preload("res://sim/content.gd")

## Name: what the case is. The order is the report's.
const CASES = {
	"pile": "Two sightings of S, by two witnesses, on two nights (control)",
	"kill_sighting": "A sighting of S on the victim's block on the kill night",
	"vigil_kill": "The player's vigil saw S leave home on the kill night",
	"alibi_sighting": "S's own home alibi + a sighting of S out that night",
	"converging": "The Seer's \"yes\" on S and another + the Dowser's \"1 evil\" among S and a third",
	"impossible": "S's Gravedigger reading of a hanging that never happened",
	"double_claim": "S claims the gift its real holder also claims",
	"gravedigger": "The Gravedigger's reading that the hanged Minion M was a Minion (subject M)",
	"lamp_alibis": "The Lamplighter's \"1 other out\" + everyone else's home alibi (suspicious)",
	"nw_nobody": "The Night Watch saw nobody on S's block + a sighting of S there",
	"guard": "A sighting of S near the guarded door + the Warden's guard, on a quiet night",
}

var _texts: Dictionary = {}

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var per_case: int = 10
	var path: String = "user://case_slate.jsonl"
	var only: Array = CASES.keys()
	var first: int = 1
	var i := 0
	while i < args.size():
		match args[i]:
			"--cases":
				per_case = int(args[i + 1])
				i += 1
			"--out":
				path = args[i + 1]
				i += 1
			"--from":
				first = int(args[i + 1])
				i += 1
			"--only":
				only = args[i + 1].split(",")
				i += 1
		i += 1
	var out = FileAccess.open(path, FileAccess.WRITE)
	for name in only:
		var kept := 0
		var sd := first
		while kept < per_case and sd < first + per_case * 8:
			var r: Dictionary = _one(sd, name)
			sd += 1
			if r.is_empty():
				continue
			out.store_line(JSON.stringify(r))
			out.flush()
			kept += 1
		print("%s: %d cases" % [name, kept])
	out.close()
	print("Written: %s" % path)
	quit()


func _holder(goods: Array, role: String, avoid: Array):
	for n in goods:
		if n.role == role and n not in avoid:
			return n
	return null


func _kill(w, victim, night: int) -> void:
	victim.alive = false
	w.public_log.append({"day": night, "kind": "demon_death", "subjects": [victim.id], "by": ""})


func _one(sd: int, name: String) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 10)
	var w = g.w
	var s = w.by_id[w.demon_id]
	var goods: Array = w.living_good()
	for p in w.npcs:
		p.trust = 0.7
		p.credibility = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
	w.day = 3
	_texts.clear()
	var cited: Array = []
	var sources: Array = []
	var premise := "evil"
	var other := "market" if s.home_block != "market" else "docks"
	match name:
		"pile":
			cited.append(_add(g, _sight(goods[0], s, other, 1)))
			cited.append(_add(g, _sight(goods[1], s, "hill" if s.home_block != "hill" else "square", 2)))
			sources += [goods[0], goods[1]]
		"kill_sighting":
			var victim = null
			for n in goods:
				if n.home_block != s.home_block:
					victim = n
					break
			if victim == null:
				return {}
			_kill(w, victim, 1)
			var wit = goods.filter(func(n): return n != victim)[0]
			cited.append(_add(g, _sight(wit, s, victim.home_block, 1)))
			sources += [wit, victim]
		"vigil_kill":
			_kill(w, goods[0], 1)
			cited.append(_add(g, {"kind": "sighting", "subject": [s.id], "block": s.home_block, "source": "player", "day": 1, "phase": C.NIGHT, "vigil": true,
				"text": "Night 1 vigil on %s: you saw %s go out." % [C.block_name(s.home_block), s.name]}))
			sources += [goods[0]]
		"alibi_sighting":
			cited.append(_add(g, {"kind": "alibi", "subject": [s.id], "source": s.id, "day": 1, "phase": C.NIGHT, "home": true, "block": s.home_block, "text": "%s: at home on night 1" % s.name}))
			cited.append(_add(g, _sight(goods[0], s, other, 1)))
			sources += [goods[0]]
		"converging":
			var seer = _holder(goods, "seer", [])
			var dowser = _holder(goods, "dowser", [seer])
			if seer == null or dowser == null:
				return {}
			var others: Array = goods.filter(func(n): return n != seer and n != dowser)
			cited.append(_add(g, {"kind": "info", "source": seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [s.id, others[0].id], "yes": true}, "text": "%s's Seer: %s or %s is the Demon" % [seer.name, s.name, others[0].name]}))
			cited.append(_add(g, {"kind": "info", "source": dowser.id, "role": "dowser", "day": 2, "phase": C.AFTERNOON, "data": {"group": [s.id, others[1].id], "count": 1}, "text": "%s's Dowser (day 2): 1 evil among %s and %s" % [dowser.name, s.name, others[1].name]}))
			sources += [seer, dowser]
		"impossible":
			cited.append(_add(g, {"kind": "info", "source": s.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": goods[0].id, "role": "seer"}, "text": "%s's Gravedigger: hanged %s was the Seer" % [s.name, goods[0].name]}))
		"double_claim":
			var holder = null
			for n in goods:
				if C.ROLES.get(n.role, {}).get("kind", "") != "evil" and n.role not in ["", "townsfolk"]:
					holder = n
					break
			if holder == null:
				return {}
			cited.append(_add(g, {"kind": "claim", "subject": [s.id], "role": holder.role, "source": s.id, "text": "%s claims the %s" % [s.name, holder.role]}))
			cited.append(_add(g, {"kind": "claim", "subject": [holder.id], "role": holder.role, "source": holder.id, "text": "%s claims the %s" % [holder.name, holder.role]}))
			sources += [holder]
		"gravedigger":
			var gd = _holder(goods, "gravedigger", [])
			var minion = null
			for n in w.npcs:
				if n.is_evil() and n.id != w.demon_id:
					minion = n
					break
			if gd == null or minion == null:
				return {}
			minion.alive = false
			w.public_log.append({"day": 2, "kind": "execution", "subjects": [minion.id], "by": ""})
			cited.append(_add(g, {"kind": "info", "source": gd.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": minion.id, "role": minion.role}, "text": "%s's Gravedigger: hanged %s was the %s" % [gd.name, minion.name, minion.role]}))
			sources += [gd]
			s = minion
		"lamp_alibis":
			var lamp = _holder(goods, "lamplighter", [])
			if lamp == null:
				return {}
			cited.append(_add(g, {"kind": "info", "source": lamp.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "%s: 1 other out on night 1" % lamp.name}))
			for n in w.npcs:
				if n.alive and n != s and n != lamp:
					cited.append(_add(g, {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: at home on night 1" % n.name}))
			sources += [lamp]
			premise = "suspicious"
		"nw_nobody":
			var nw = _holder(goods, "nightwatch", [])
			if nw == null:
				return {}
			var wit = goods.filter(func(n): return n != nw)[0]
			cited.append(_add(g, {"kind": "info", "source": nw.id, "role": "nightwatch", "day": 1, "phase": C.NIGHT, "data": {"block": s.home_block, "seen": []}, "text": "%s watched %s: nobody passed" % [nw.name, s.home_block]}))
			cited.append(_add(g, _sight(wit, s, s.home_block, 1)))
			sources += [nw, wit]
		"guard":
			var target = null
			for n in goods:
				if n.home_block != s.home_block and n.role != "warden":
					target = n
					break
			var warden = _holder(goods, "warden", [target])
			if target == null or warden == null:
				return {}
			var wit = goods.filter(func(n): return n != target and n != warden)[0]
			cited.append(_add(g, _sight(wit, s, target.home_block, 1)))
			cited.append(_add(g, {"kind": "info", "source": warden.id, "role": "warden", "day": 1, "phase": C.NIGHT, "data": {"target": target.id, "saved": true}, "text": "%s guarded %s's door on night 1" % [warden.name, target.name]}))
			sources += [warden, wit, target]
	var listeners: Array = w.npcs.filter(func(p): return p.alive and not p.is_evil() and p != s and p not in sources)
	if listeners.is_empty():
		return {}
	var before_each: Dictionary = {}
	for l in listeners:
		before_each[l.id] = float(l.suspicion.get(s.id, 0.0))
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var p_id: String = model.add_premise(s.id, premise, Vector2(400, 40))
	for num in cited:
		for id in model.nodes:
			var nd = model.nodes[id]
			if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == str(_texts[num]):
				model.connect_cards(id, p_id)
	var value: Dictionary = model.compile(p_id)
	var tj: Dictionary = Live.test_juror(g, value)
	var n_case: int = Live.file(g, value)
	if n_case <= 0:
		print("  %s seed %d: not filed (%s)" % [name, sd, g.last_error])
		return {}
	# A listener who can't assess the case isn't an unconvinced one (Codex on #307): count
	# them apart, with what blocked them, and leave them out of the town's movement.
	var heard: Array = []
	var blocked: Array = []
	for l in listeners:
		var res: Dictionary = g._evaluate_deduction(l, g.board[n_case - 1], 1.0, false)
		if res.get("blocked", false):
			blocked.append("%s: %s" % [l.id, " ".join(PackedStringArray(res.get("lines", [])))])
		else:
			heard.append(l)
	var row: Dictionary = {"case": name, "seed": sd, "category": str(tj.get("category", "")) if tj.get("ready", false) else "not ready",
		"lr": float(tj.get("lr", -1.0)), "town": _mean(heard, s) - _mean_before(heard, before_each), "listeners": heard.size()}
	if not blocked.is_empty():
		row["blocked"] = blocked
		print("  %s seed %d: %d listeners blocked: %s" % [name, sd, blocked.size(), blocked[0]])
	if not tj.get("ready", false):
		# A slate case the juror can't judge is a broken case (or a broken judge): say why.
		row["issues"] = tj.get("issues", [])
		print("  %s seed %d: not ready: %s" % [name, sd, row.issues])
	return row


func _sight(witness, s, block: String, night: int) -> Dictionary:
	return {"kind": "sighting", "subject": [s.id], "block": block, "source": witness.id, "day": night, "phase": C.NIGHT,
		"text": "Night %d: %s saw %s on %s" % [night, witness.name, s.name, C.block_name(block)]}


## The mean suspicion of `s` before the case, over the listeners who heard it.
func _mean_before(heard: Array, before_each: Dictionary) -> float:
	var t := 0.0
	for l in heard:
		t += float(before_each[l.id])
	return t / maxf(1.0, heard.size())


func _mean(ls: Array, s) -> float:
	var t := 0.0
	for l in ls:
		t += float(l.suspicion.get(s.id, 0.0))
	return t / maxf(1.0, ls.size())


func _add(g, card: Dictionary) -> int:
	var n: int = g.add_card(card)
	_texts[n] = card.text
	return n

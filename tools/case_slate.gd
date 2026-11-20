## The case benchmark slate (Michael, Nov 19; Quill with Lantern): standard constructed
## cases, each judged by the Test juror (the canvas's Strong / Moderate / Weak badge) and
## presented to the town, so a change to the judge or the belief model can be checked for
## drift and outliers. Like golden, a script plus a stored baseline report
## (docs/case_slate/), run on demand. Not a CI suite.
##
## Each case is built on a real deal (10 NPCs, seeds from 1): the cards are added to the
## board as the player would hold them, the player files the case about its subject and
## presents it to every living good townsperson but the subject (its sources too), at credibility 0.7 with
## suspicion reset to 0.25. Every gift reading comes from that gift's real (good) holder,
## or the seed is skipped for that case. The subject is the Demon unless the case says
## otherwise; a "<case>_innocent" twin builds the same chain about an innocent, with any lie
## told by a Minion. Recorded per case: the juror's category and strength (likelihood
## ratio), and the town's mean change in suspicion of the subject.
##
##   godot --headless --path . --script res://tools/case_slate.gd -- [--cases N] [--out FILE] [--only a,b]
##   python3 tools/case_slate_report.py FILE [BASELINE]   (the report; against a baseline)
extends SceneTree

const GamePresentation = preload("res://game/game_presentation.gd")
const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const C = preload("res://sim/content.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindVote = preload("res://sim/mind_vote.gd")

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
	"lamp_count": "The Lamplighter's \"1 other out\", alone (suspicious)",
	"nw_nobody": "The Night Watch saw nobody on S's block + a sighting of S there",
	"guard": "A sighting of S near the guarded door + the Warden's guard, on a quiet night",
	# Strong-tier cases (Seneschal, Nov 19): nothing above landed between Moderate and the
	# impossible reading.
	"seer_twice": "The Seer's \"yes\" on S and one other on night 1, and on S and another on night 2",
	"vigil_seer": "The player's vigil saw S leave home on the kill night + the Seer's \"yes\" on S and one other",
	"stack": "The vigil at the kill + a witness's sighting of S on the victim's block + the Seer's \"yes\" on S twice",
	"two_kills_seer": "Two kills (vigil + witness each) + the Seer's \"yes\" on S twice",
	# Misleading cases (Michael, Nov 19): the same chains about an innocent subject I (a
	# good townsperson), built as they could really arise: an innocent out at night, true
	# readings that name I beside the real evil, or a lie told by evil.
	"pile_innocent": "Two sightings of I out at night",
	"kill_sighting_innocent": "A sighting of I on the victim's block on the kill night",
	"vigil_kill_innocent": "The player's vigil saw I leave home on the kill night",
	"alibi_sighting_innocent": "I's home alibi + a Minion's false sighting of I out that night",
	"converging_innocent": "The Seer's \"yes\" on I and the Demon + the Dowser's \"1 evil\" among I and a Minion",
	"double_claim_innocent": "I, the real holder, and the Demon both claim I's gift",
	"gravedigger_innocent": "A Minion's false Gravedigger reading that the hanged I was a Minion",
	"lamp_alibis_innocent": "The Lamplighter's \"1 other out\" + everyone else's home alibi, the Demon's false (suspicious)",
	"lamp_count_innocent": "The Lamplighter's \"1 other out\", alone, filed against I (suspicious)",
	"lamp_bluff_innocent": "A Minion bluffing the Lamplighter: \"1 other out\" + everyone else's true home alibi (suspicious)",
	"nw_nobody_innocent": "The Night Watch saw nobody on I's block + a Minion's false sighting of I there",
	"guard_innocent": "A sighting of I near the guarded door + the Warden's guard, on a quiet night",
	# Word against word (Lantern, Nov 19, for the player's-judgement boost, #352; Seneschal):
	# the player calls one teller's reading a lie, on another teller's clashing reading. Each
	# true call is about the Minion who lied; its "_innocent" twin makes the misleading call,
	# about the real holder, on the Minion's word.
	"lie_seer": "A Minion's Seer \"yes\" on two innocents, called a lie on the real Seer's \"no\" (subject: the Minion)",
	"lie_gravedigger": "A Minion's Gravedigger reading that the hanged innocent was a Minion, called a lie on the real Gravedigger's reading",
	"lie_seer_reversed": "A Minion's Seer \"no\" on the Demon and an innocent, called a lie on the real Seer's \"yes\"",
	"lie_seer_innocent": "The real Seer's \"no\" on two innocents, called a lie on a Minion's \"yes\" (subject: the real Seer)",
	"lie_gravedigger_innocent": "The real Gravedigger's reading of the hanged innocent, called a lie on a Minion's \"a Minion\"",
	"lie_seer_reversed_innocent": "The real Seer's \"yes\" on the Demon and an innocent, called a lie on a Minion's \"no\"",
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


func _one(sd: int, name: String, before_only: bool = false) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 10)
	var w = g.w
	var s = w.by_id[w.demon_id]
	var goods: Array = w.living_good()
	var dem = s
	var min_ev = null
	for n in w.npcs:
		if n.alive and n.is_evil() and n.id != w.demon_id:
			min_ev = n
			break
	# A misleading case is about an innocent: the last living good townsperson, kept out of
	# the witnesses and gift holders the case draws on.
	var innocent: bool = name.ends_with("_innocent")
	var base: String = name.trim_suffix("_innocent")
	var lie_call: bool = base.begins_with("lie_")
	if innocent and not lie_call:
		if min_ev == null:
			return {}
		s = goods[-1]
		goods = goods.filter(func(n): return n != s)
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
	var lie_calls: Dictionary = {}  # board number of the reading called a lie -> its grounds' numbers
	match base:
		"lie_seer", "lie_seer_reversed", "lie_gravedigger":
			# Word against word: the Minion bluffs the gift, the real holder reads, the player
			# calls one of them a liar on the other's reading.
			if min_ev == null:
				return {}
			var gift: String = "gravedigger" if base == "lie_gravedigger" else "seer"
			var real = _holder(goods, gift, [])
			if real == null:
				return {}
			var rest: Array = goods.filter(func(n): return n != real)
			if rest.size() < 2:
				return {}
			var lie_n: int
			var true_n: int
			if gift == "seer":
				var pair: Array = [rest[0].id, rest[1].id] if base == "lie_seer" else [dem.id, rest[0].id]
				var says: bool = base == "lie_seer"  # the Minion's word; the real Seer says the opposite
				var names: String = "%s or %s" % [w.by_id[pair[0]].name, w.by_id[pair[1]].name]
				lie_n = _add(g, {"kind": "info", "source": min_ev.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": pair, "yes": says},
					"text": "%s's Seer: %s %s the Demon" % [min_ev.name, names, "is" if says else "isn't"]})
				true_n = _add(g, {"kind": "info", "source": real.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": pair, "yes": not says},
					"text": "%s's Seer: %s %s the Demon" % [real.name, names, "isn't" if says else "is"]})
			else:
				var hanged = rest[0]
				hanged.alive = false
				hanged.death_cause = "executed"
				w.public_log.append({"day": 2, "kind": "execution", "subjects": [hanged.id], "by": ""})
				lie_n = _add(g, {"kind": "info", "source": min_ev.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": hanged.id, "role": min_ev.role},
					"text": "%s's Gravedigger: hanged %s was the %s" % [min_ev.name, hanged.name, min_ev.role]})
				true_n = _add(g, {"kind": "info", "source": real.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": hanged.id, "role": hanged.role},
					"text": "%s's Gravedigger: hanged %s was the %s" % [real.name, hanged.name, hanged.role]})
			var claim_lie: int = _add(g, {"kind": "claim", "subject": [min_ev.id], "role": gift, "source": min_ev.id, "text": "%s claims the %s" % [min_ev.name, gift]})
			var claim_true: int = _add(g, {"kind": "claim", "subject": [real.id], "role": gift, "source": real.id, "text": "%s claims the %s" % [real.name, gift]})
			cited += [lie_n, true_n, claim_lie, claim_true]
			if innocent:
				s = real
				lie_calls[true_n] = [lie_n]
				sources += [min_ev]
			else:
				s = min_ev
				lie_calls[lie_n] = [true_n]
				sources += [real]
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
			var a_wit = min_ev if innocent else goods[0]
			cited.append(_add(g, _sight(a_wit, s, other, 1)))
			sources += [a_wit]
		"converging":
			var seer = _holder(goods, "seer", [])
			var dowser = _holder(goods, "dowser", [seer])
			if seer == null or dowser == null:
				return {}
			var others: Array = goods.filter(func(n): return n != seer and n != dowser)
			if innocent:
				others = [dem, min_ev]
			cited.append(_add(g, {"kind": "info", "source": seer.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [s.id, others[0].id], "yes": true}, "text": "%s's Seer: %s or %s is the Demon" % [seer.name, s.name, others[0].name]}))
			cited.append(_add(g, {"kind": "info", "source": dowser.id, "role": "dowser", "day": 2, "phase": C.AFTERNOON, "data": {"group": [s.id, others[1].id], "count": 1}, "text": "%s's Dowser (day 2): 1 evil among %s and %s" % [dowser.name, s.name, others[1].name]}))
			sources += [seer, dowser]
		"impossible":
			if innocent:
				return {}  # a good teller can't give an impossible reading (short of poison)
			cited.append(_add(g, {"kind": "info", "source": s.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": goods[0].id, "role": "seer"}, "text": "%s's Gravedigger: hanged %s was the Seer" % [s.name, goods[0].name]}))
		"double_claim":
			var holder = null
			for n in goods:
				if C.ROLES.get(n.role, {}).get("kind", "") != "evil" and n.role not in ["", "townsfolk"]:
					holder = n
					break
			if holder == null:
				return {}
			# The bluffer claims the holder's gift; the case is about the bluffer. In the
			# misleading case the innocent is the real holder and the Demon bluffs.
			var bluffer = s
			if innocent:
				s = holder
				bluffer = dem
			var gift: String = holder.role
			cited.append(_add(g, {"kind": "claim", "subject": [bluffer.id], "role": gift, "source": bluffer.id, "text": "%s claims the %s" % [bluffer.name, gift]}))
			cited.append(_add(g, {"kind": "claim", "subject": [holder.id], "role": gift, "source": holder.id, "text": "%s claims the %s" % [holder.name, gift]}))
			sources += [holder]
		"gravedigger":
			if innocent:
				# The innocent hanged; a Minion, bluffing the Gravedigger, calls them a Minion.
				s.alive = false
				s.death_cause = "executed"
				w.public_log.append({"day": 2, "kind": "execution", "subjects": [s.id], "by": ""})
				cited.append(_add(g, {"kind": "info", "source": min_ev.id, "role": "gravedigger", "day": 2, "phase": C.NIGHT, "data": {"executed": s.id, "role": min_ev.role}, "text": "%s's Gravedigger: hanged %s was the %s" % [min_ev.name, s.name, min_ev.role]}))
				cited.append(_add(g, {"kind": "claim", "subject": [min_ev.id], "role": "gravedigger", "source": min_ev.id, "text": "%s claims the gravedigger" % min_ev.name}))
				sources += [min_ev]
				premise = "evil"
			var gd = null if innocent else _holder(goods, "gravedigger", [])
			var minion = null
			for n in w.npcs:
				if n.is_evil() and n.id != w.demon_id:
					minion = n
					break
			if innocent:
				pass
			elif gd == null or minion == null:
				return {}
			else:
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
		"lamp_count":
			var lc = _holder(goods, "lamplighter", [])
			if lc == null:
				return {}
			cited.append(_add(g, {"kind": "info", "source": lc.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "%s: 1 other out on night 1" % lc.name}))
			sources += [lc]
			premise = "suspicious"
		"lamp_bluff":
			# Only a misleading case: a Minion claims the Lamplighter and gives a false count;
			# everyone else's home alibi is true, so the innocent is the one left without one.
			if not innocent:
				return {}
			cited.append(_add(g, {"kind": "claim", "subject": [min_ev.id], "role": "lamplighter", "source": min_ev.id, "text": "%s claims the lamplighter" % min_ev.name}))
			cited.append(_add(g, {"kind": "info", "source": min_ev.id, "role": "lamplighter", "day": 1, "phase": C.NIGHT, "data": {"count": 1}, "text": "%s: 1 other out on night 1" % min_ev.name}))
			for n in w.npcs:
				if n.alive and n != s and n != min_ev:
					cited.append(_add(g, {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: at home on night 1" % n.name}))
			sources += [min_ev]
			premise = "suspicious"
		"nw_nobody":
			var nw = _holder(goods, "nightwatch", [])
			if nw == null:
				return {}
			var wit = min_ev if innocent else goods.filter(func(n): return n != nw)[0]
			cited.append(_add(g, {"kind": "info", "source": nw.id, "role": "nightwatch", "day": 1, "phase": C.NIGHT, "data": {"block": s.home_block, "seen": []}, "text": "%s watched %s: nobody passed" % [nw.name, s.home_block]}))
			cited.append(_add(g, _sight(wit, s, s.home_block, 1)))
			sources += [nw, wit]
		"seer_twice":
			if innocent:
				return {}
			var seer2 = _holder(goods, "seer", [])
			if seer2 == null:
				return {}
			var others2: Array = goods.filter(func(n): return n != seer2)
			cited.append(_add(g, {"kind": "info", "source": seer2.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [s.id, others2[0].id], "yes": true}, "text": "%s's Seer (night 1): %s or %s is the Demon" % [seer2.name, s.name, others2[0].name]}))
			cited.append(_add(g, {"kind": "info", "source": seer2.id, "role": "seer", "day": 2, "phase": C.NIGHT, "data": {"pair": [s.id, others2[1].id], "yes": true}, "text": "%s's Seer (night 2): %s or %s is the Demon" % [seer2.name, s.name, others2[1].name]}))
			sources += [seer2]
		"vigil_seer":
			if innocent:
				return {}
			var seer3 = _holder(goods, "seer", [])
			if seer3 == null:
				return {}
			var rest3: Array = goods.filter(func(n): return n != seer3)
			_kill(w, rest3[0], 1)
			cited.append(_add(g, {"kind": "sighting", "subject": [s.id], "block": s.home_block, "source": "player", "day": 1, "phase": C.NIGHT, "vigil": true,
				"text": "Night 1 vigil on %s: you saw %s go out." % [C.block_name(s.home_block), s.name]}))
			cited.append(_add(g, {"kind": "info", "source": seer3.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [s.id, rest3[1].id], "yes": true}, "text": "%s's Seer: %s or %s is the Demon" % [seer3.name, s.name, rest3[1].name]}))
			sources += [seer3, rest3[0]]
		"stack":
			if innocent:
				return {}
			var seer4 = _holder(goods, "seer", [])
			if seer4 == null:
				return {}
			var rest4: Array = goods.filter(func(n): return n != seer4 and n.home_block != s.home_block)
			if rest4.size() < 4:
				return {}
			var victim4 = rest4[0]
			_kill(w, victim4, 1)
			cited.append(_add(g, {"kind": "sighting", "subject": [s.id], "block": s.home_block, "source": "player", "day": 1, "phase": C.NIGHT, "vigil": true,
				"text": "Night 1 vigil on %s: you saw %s go out." % [C.block_name(s.home_block), s.name]}))
			cited.append(_add(g, _sight(rest4[1], s, victim4.home_block, 1)))
			cited.append(_add(g, {"kind": "info", "source": seer4.id, "role": "seer", "day": 1, "phase": C.NIGHT, "data": {"pair": [s.id, rest4[2].id], "yes": true}, "text": "%s's Seer (night 1): %s or %s is the Demon" % [seer4.name, s.name, rest4[2].name]}))
			cited.append(_add(g, {"kind": "info", "source": seer4.id, "role": "seer", "day": 2, "phase": C.NIGHT, "data": {"pair": [s.id, rest4[3].id], "yes": true}, "text": "%s's Seer (night 2): %s or %s is the Demon" % [seer4.name, s.name, rest4[3].name]}))
			sources += [seer4, victim4, rest4[1]]
		"two_kills_seer":
			if innocent:
				return {}
			var seer7 = _holder(goods, "seer", [])
			if seer7 == null:
				return {}
			var rest7: Array = goods.filter(func(n): return n != seer7 and n.home_block != s.home_block)
			if rest7.size() < 6:
				return {}
			for night in [1, 2]:
				var victim7 = rest7[(night - 1) * 2]
				_kill(w, victim7, night)
				cited.append(_add(g, {"kind": "sighting", "subject": [s.id], "block": s.home_block, "source": "player", "day": night, "phase": C.NIGHT, "vigil": true,
					"text": "Night %d vigil on %s: you saw %s go out." % [night, C.block_name(s.home_block), s.name]}))
				cited.append(_add(g, _sight(rest7[(night - 1) * 2 + 1], s, victim7.home_block, night)))
				cited.append(_add(g, {"kind": "info", "source": seer7.id, "role": "seer", "day": night, "phase": C.NIGHT, "data": {"pair": [s.id, rest7[3 + night].id], "yes": true}, "text": "%s's Seer (night %d): %s or %s is the Demon" % [seer7.name, night, s.name, rest7[3 + night].name]}))
				sources += [victim7, rest7[(night - 1) * 2 + 1]]
			sources += [seer7]
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
	# Every living good townsperson but the subject hears it, its sources too: a presentation at
	# a meeting reaches the whole town (Seneschal, Nov 19). Before, the sources didn't hear it,
	# and a big case used up much of the town as sources who then voted unheard.
	var listeners: Array = w.npcs.filter(func(p): return p.alive and not p.is_evil() and p != s)
	if listeners.is_empty():
		return {}
	# How the good townsfolk would vote on the subject, nominated by a neutral nominator, the
	# player's vote left out (Michael, Nov 19; Beadle's hook, #347). A vote refreshes each
	# voter's beliefs, as at a meeting, so "before" is taken on a fresh build of the same deal
	# with the same cards, never presented: the columns above stay as they were.
	w.meeting["block"] = ""
	w.meeting["block_count"] = 0
	if before_only:
		return MindVote.would_vote(w, s.id)
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
	if not lie_calls.is_empty():
		var challenges: Dictionary = {}
		for num in lie_calls:
			var rid: String = Live.Evidence.normalize_card(g.board[int(num) - 1]).id
			challenges[rid] = {"mode": "lying", "supports": lie_calls[num].map(func(x): return Live.Evidence.normalize_card(g.board[int(x) - 1]).id)}
		value["reading_challenges"] = challenges
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
		var res: Dictionary = GamePresentation._evaluate_deduction(g, l, g.board[n_case - 1], 1.0, false)
		if res.get("blocked", false):
			blocked.append("%s: %s" % [l.id, " ".join(PackedStringArray(res.get("lines", [])))])
		else:
			heard.append(l)
	var row: Dictionary = {"case": name, "seed": sd, "category": str(tj.get("category", "")) if tj.get("ready", false) else "not ready",
		"lr": float(tj.get("lr", -1.0)), "town": _mean(heard, s) - _mean_before(heard, before_each), "listeners": heard.size()}
	var votes_after: Dictionary = MindVote.would_vote(w, s.id)
	var votes_before: Dictionary = _one(sd, name, true)
	row["yes_before"] = votes_before.yes.size()
	row["yes_after"] = votes_after.yes.size()
	row["voters_good"] = votes_after.yes.size() + votes_after.no.size()
	row["threshold"] = int(votes_after.threshold)
	row["crosses"] = bool(votes_after.crosses)
	# Among the good who heard the case (its sources and the dead don't): a big case uses up
	# much of the town as sources, who vote without having heard it.
	var heard_ids: Array = heard.map(func(l): return l.id)
	row["heard_good"] = heard_ids.size()
	row["yes_heard"] = votes_after.yes.filter(func(id): return id in heard_ids).size()
	row["yes_heard_before"] = votes_before.yes.filter(func(id): return id in heard_ids).size()
	# The average listener's reading behind the badge (Michael, Nov 19): the premise's chance
	# before and after, and whether the subject becomes that listener's top suspect, by what
	# margin (for the fourth tier's measure).
	var lis: Dictionary = tj.get("listener", {})
	if not lis.is_empty():
		row["chance_before"] = float(lis.chance_before)
		row["chance"] = float(lis.chance)
		var pj: Dictionary = preload("res://workshop/connections.gd").judge_for_profile(g, value, {"baseline": "without_cards"})
		var post: Dictionary = pj.get("posterior_after", {})
		var mine: float = float(post.get(s.id, -1.0))
		var rival: float = 0.0
		for id in post:
			if id != s.id and g.w.by_id.has(id) and g.w.by_id[id].alive:
				rival = maxf(rival, float(post[id]))
		row["top"] = mine > rival
		row["margin"] = mine - rival
	if not lie_calls.is_empty():
		# How the average listener takes each lie call (the badge's words): pressed, draw, ...
		row["lie_calls"] = tj.get("listener", {}).get("challenges", []).map(func(c): return str(c.get("kind", "")))
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
	var n: int = GameBoard.add_card(g, card)
	_texts[n] = card.text
	return n

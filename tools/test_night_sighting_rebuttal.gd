## Explicit night-sighting rebuttals (BACKLOG, Michael): a defender seen out at night may say
## "no one died that night" or "the death was on another block", as an attributed defence. It is
## speech only: the judge already reasons from the public death record, so the rebuttal carries no
## weight and must not change what anyone believes.
##
## The game comes from tools/fixture_seeds.gd (any passive game that reaches its day-3 meeting);
## the nights, deaths and claims are hand-built on it.
extends SceneTree
const FixtureSeeds = preload("res://tools/fixture_seeds.gd")
const Mind = preload("res://sim/mind.gd")
const MindDefence = preload("res://sim/mind_defence.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const MindPress = preload("res://sim/mind_press.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	for size in [7, 10]:
		var found: Dictionary = FixtureSeeds.search(3, func(g): return {"ok": true} if g.w.living_good().size() >= 3 and g.w.living().any(func(n): return n.is_evil()) else {}, size)
		check(not found.is_empty(), "%d NPCs: found a game at its day-3 meeting" % size)
		if found.is_empty():
			continue
		_run(found["g"], size)
	print("Night-sighting rebuttal: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## A clean slate for nights 1 and 2: no deaths, no quiet nights, no protective claims or wards.
## Night 1 then gets a death at `victim`'s home; night 2 is quiet.
func _stage(w, victim) -> void:
	w.day = 3
	w.public_log = w.public_log.filter(func(e): return not (str(e.get("kind", "")) == "demon_death" and int(e.get("day", -1)) in [0, 1, 2]))
	w.dlog.entries = w.dlog.entries.filter(func(e): return not (e["type"] in ["quiet_night", "player_ward_context", "warden_tells_save", "protect", "rebuttal"]))
	w.public_claims = w.public_claims.filter(func(pc): return not C.has_role_def(str(pc.get("role", ""))) or not C.role_def(str(pc.get("role", ""))).can_cause_quiet_night)
	w.public_log.append({"day": 1, "kind": "demon_death", "subjects": [victim.id], "by": "town"})
	w.dlog.add("quiet_night", "world", "", {"night": 0}, "test: night 0 announced quiet")
	w.dlog.add("quiet_night", "world", "", {"night": 2}, "test: nobody died on night 2")

func _plain(d) -> void:
	if C.has_role_def(d.role) and C.role_def(d.role).can_cause_quiet_night:
		d.role = "clerk"
	if not d.is_evil():
		d.claimed_role = d.role
	d.claim_public = false
	d.secret = {}
	d.secret_mod = ""
	d.silenced = false

func _off_route(home: String, dest: String) -> String:
	var route: Array = C.route(home, dest)
	for b in C.BLOCKS.keys():
		if not (b in route):
			return b
	return ""

func _run(g, size: int) -> void:
	var w = g.w
	var goods: Array = w.living_good()
	var d = goods[0]
	var accuser = goods[1]
	var victim = goods[2]
	_plain(d)
	_stage(w, victim)
	var tag: String = "%d NPCs:" % size
	var on_b: String = victim.home_block
	var off_b: String = _off_route(d.home_block, victim.home_block)
	check(off_b != "", tag + " the town has a block that is neither %s nor %s" % [d.home_block, victim.home_block])
	d.history[w.time_key(1, C.NIGHT)] = "home:" + d.home_block
	d.history[w.time_key(2, C.NIGHT)] = "home:" + d.home_block

	# The helper itself.
	var r_off: Dictionary = MindDefence.night_route_rebuttal(w, d, 1, off_b)
	check(str(r_off.get("variant", "")) == "other_block" and int(r_off.get("night", -1)) == 1, tag + " an off-route sighting on a death night gives other_block (%s)" % [r_off])
	check(r_off.get("cites", {}).get("deaths", []) == [victim.id], tag + " other_block cites the public death")
	check(MindDefence.night_route_rebuttal(w, d, 1, on_b).is_empty(), tag + " a sighting on the victim's home block gives nothing")
	check(MindDefence.night_route_rebuttal(w, d, 1, d.home_block).is_empty(), tag + " a sighting on the defender's own block gives nothing")
	# A neighbour of the victim, home all night on that block, was on it: never "I was never on".
	var own_home: String = d.home_block
	d.home_block = victim.home_block
	var far_b: String = ""
	for b in C.BLOCKS.keys():
		if b != victim.home_block:
			far_b = b
			break
	check(MindDefence.night_route_rebuttal(w, d, 1, far_b).is_empty(), tag + " a defender living on the victim's block, home that night, gives no other_block")
	d.home_block = own_home
	var r_q: Dictionary = MindDefence.night_route_rebuttal(w, d, 2, off_b)
	check(str(r_q.get("variant", "")) == "no_death", tag + " a quiet night gives no_death (%s)" % [r_q])
	check(MindDefence.night_route_rebuttal(w, d, 0, off_b).is_empty(), tag + " night 0 never")
	check(MindDefence.night_route_rebuttal(w, d, 3, off_b).is_empty(), tag + " tonight (not yet passed) never")
	# A thwart the defender could know of.
	w.public_claims.append({"day": 2, "who": accuser.id, "role": "warden"})
	check(MindDefence.night_route_rebuttal(w, d, 2, off_b).is_empty(), tag + " a quiet night with a public Warden claim gives nothing")
	w.public_claims.pop_back()
	w.public_claims.append({"day": 2, "who": accuser.id, "role": "veteran"})
	check(MindDefence.night_route_rebuttal(w, d, 2, off_b).is_empty(), tag + " a quiet night with a public Veteran claim gives nothing")
	w.public_claims.pop_back()
	w.dlog.add("player_ward_context", "player", victim.id, {"night": 2, "kind": "ward", "listeners": [], "rewarded": [], "public": true})
	check(MindDefence.night_route_rebuttal(w, d, 2, off_b).is_empty(), tag + " a quiet night with a ward the player showed the town gives nothing")
	w.dlog.entries.pop_back()
	w.dlog.add("player_ward_context", "player", victim.id, {"night": 2, "kind": "ward", "listeners": [accuser.id], "rewarded": [], "public": false})
	check(not MindDefence.night_route_rebuttal(w, d, 2, off_b).is_empty(), tag + " a ward shown to someone else is not the defender's to know")
	w.dlog.entries.pop_back()
	w.dlog.add("warden_tells_save", accuser.id, d.id, {"night": 2, "belief": 1.0})
	check(MindDefence.night_route_rebuttal(w, d, 2, off_b).is_empty(), tag + " a quiet night a Warden told them of saving gives nothing")
	w.dlog.entries.pop_back()
	# Truly out on the victim's block: never other_block, whatever the sighting says.
	d.history[w.time_key(1, C.NIGHT)] = "night:" + on_b
	check(MindDefence.night_route_rebuttal(w, d, 1, off_b).is_empty(), tag + " someone truly out on the victim's block never says they were never on it")
	d.history[w.time_key(1, C.NIGHT)] = "home:" + d.home_block

	# Evil: only when true as stated, and logged as true but misleading.
	var e = w.living().filter(func(n): return n.is_evil())[0]
	_plain(e)
	var e_off: String = _off_route(e.home_block, victim.home_block)
	e.history[w.time_key(1, C.NIGHT)] = "night:" + victim.home_block
	check(MindDefence.night_route_rebuttal(w, e, 1, victim.home_block).is_empty(), tag + " evil never claims other_block for a sighting on the route")
	if e_off != "":
		check(MindDefence.night_route_rebuttal(w, e, 1, e_off).is_empty(), tag + " evil that was out on the victim's block never claims other_block, even sighted elsewhere")
		e.history[w.time_key(1, C.NIGHT)] = "home:" + e.home_block
		var e_res: Dictionary = Mind.defend_self(w, e, accuser.id, [_sighting(accuser, e, 1, e_off)])
		check("rebuttal" in e_res.moves, tag + " evil at home, sighted off the route, says it (%s)" % [e_res.moves])
		var thinks: Array = w.dlog.entries.filter(func(x): return x["type"] == "think" and x["actor"] == e.id and x["data"].get("topic", "") == "rebuttal")
		check(not thinks.is_empty() and "misleading" in str(thinks[-1]["reason"]), tag + " evil's rebuttal is logged with its reason")

	# The meeting defence: an added line and ledger entry, and no belief moves.
	for case in [[1, off_b, "other_block", "I was never on"], [2, off_b, "no_death", "no one died that night"]]:
		var nd: int = case[0]
		var lab: String = "%s night %d, %s:" % [tag, nd, case[2]]
		var spoken: Array = [_sighting(accuser, d, nd, case[1])]
		if case[2] == "no_death":
			# Home that night: their account says so, and "I was seen out" would retract it
			# (Codex on #415), so no rebuttal. Then out and owning it: the rebuttal follows.
			var res_home: Dictionary = Mind.defend_self(w, d, accuser.id, spoken)
			check(not ("rebuttal" in res_home.moves) and not res_home.lines.any(func(l): return l is Dictionary and case[3] in str(l.get("statement", ""))), lab + " after a home account, no \"I was seen out\" (%s)" % [res_home.moves])
			_own_outing(w, d, nd, case[1])
		var res: Dictionary = Mind.defend_self(w, d, accuser.id, spoken)
		check("rebuttal" in res.moves, lab + " the defence includes the rebuttal (%s)" % [res.moves])
		check(res.moves.size() >= 2, lab + " it is added to another move, not instead of one (%s)" % [res.moves])
		check(res.lines.any(func(l): return l is Dictionary and case[3] in str(l.get("statement", ""))), lab + " the line is in the defence output")
		var at: int = -1
		for i in range(res.lines.size()):
			if res.lines[i] is Dictionary and case[3] in str(res.lines[i].get("statement", "")):
				at = i
		if case[2] == "no_death":
			# The outing is owned already, so there is no account to give or dispute: the line
			# comes first, added to their other move.
			check(not ("dispute_night" in res.moves) and at == 0, lab + " with the outing owned, it opens the defence without disputing the night (line %d, moves %s)" % [at, res.moves])
		else:
			check("dispute_night" in res.moves and at >= 2, lab + " it follows their account of that night, never replacing it (line %d, moves %s)" % [at, res.moves])
		var entries: Array = []
		for l in w.living():
			if l == d:
				continue
			var mind = l.shadow if l.is_evil() and l.shadow != null else l
			for eid in mind.ledger:
				var meta: Dictionary = mind.ledger[eid].get("meta", {})
				if str(eid).begins_with("def:%s:rebuttal:" % d.id) and meta.get("move", "") == "rebuttal" and str(meta.get("scope", {}).get("variant", "")) == case[2] and int(meta.scope.get("night", -1)) == nd:
					entries.append([l, mind, eid])
		check(entries.size() == w.living().size() - 1, lab + " every listener holds the rebuttal's defence entry (%d)" % entries.size())
		check(entries.all(func(x): return float(x[1].ledger[x[2]].weight) == 0.0), lab + " the entry carries no weight")
		check(entries.all(func(x): return str(x[1].ledger[x[2]].meta.scope.get("sighting", "")).begins_with("sighting:%s:%s:%d:" % [accuser.id, d.id, nd])), lab + " the entry names the sighting it answers")
		# Suspicions with the rebuttal held, then with it taken out again: identical.
		var with_reb: Dictionary = _suspicions(w)
		for x in entries:
			x[1].ledger.erase(x[2])
		var without: Dictionary = _suspicions(w)
		check(with_reb == without, lab + " listeners' suspicions are unchanged by it")

	# Night 0: never at the meeting either.
	var res0: Dictionary = Mind.defend_self(w, d, accuser.id, [_sighting(accuser, d, 0, off_b)])
	check(not ("rebuttal" in res0.moves), tag + " no rebuttal for a night-0 sighting (%s)" % [res0.moves])

	# The podium: pressed with the sighting card.
	var card: Dictionary = _sighting(accuser, d, 1, off_b)
	var pr: Dictionary = MindPodium.press_card(w, d, card, true)
	check(str(pr.get("rebuttal", {}).get("variant", "")) == "other_block", tag + " the podium press of an off-route sighting adds the rebuttal")
	check(pr.lines.any(func(l): return l is Dictionary and "I was never on" in str(l.get("statement", ""))), tag + " the podium line is said")
	var card_on: Dictionary = _sighting(accuser, d, 1, on_b)
	check(MindPodium.press_card(w, d, card_on, true).get("rebuttal", {}).is_empty(), tag + " the podium press of an on-route sighting adds nothing")

	# In private: pressed with the sighting. Home that night, it isn't said; out and owning it,
	# it is.
	d.history[w.time_key(2, C.NIGHT)] = "home:" + d.home_block
	d.dialogue_memory.get("night_accounts", {}).erase("2")
	var priv_home: Dictionary = MindPress.press(w, d, _sighting(accuser, d, 2, off_b))
	check(not priv_home.lines.any(func(l): return l is Dictionary and "no one died that night" in str(l.get("statement", ""))), tag + " the private press after a home account doesn't say \"I was seen out\"")
	_own_outing(w, d, 2, off_b)
	var priv: Dictionary = MindPress.press(w, d, _sighting(accuser, d, 2, off_b))
	check(priv.lines.any(func(l): return l is Dictionary and "no one died that night" in str(l.get("statement", ""))), tag + " the private press over a quiet night, the outing owned, adds the rebuttal")

## Out on `block` that night and already owning it (an admitted walk, reason kept back).
func _own_outing(w, d, nd: int, block: String) -> void:
	d.history[w.time_key(nd, C.NIGHT)] = "night:" + block
	var accounts: Dictionary = d.dialogue_memory.get("night_accounts", {})
	accounts[str(nd)] = {"kind": "alibi", "subject": [d.id], "home": false, "day": nd, "phase": C.NIGHT, "source": d.id, "block": block,
		"text": "%s says they were out on %s on night %d." % [d.name, block, nd]}
	d.dialogue_memory["night_accounts"] = accounts

func _sighting(src, subj, nd: int, block: String) -> Dictionary:
	return {"kind": "sighting", "source": src.id, "subject": [subj.id], "block": block, "day": nd, "phase": C.NIGHT,
		"text": "%s saw %s on %s, night %d." % [src.name, subj.name, block, nd]}

func _suspicions(w) -> Dictionary:
	var out: Dictionary = {}
	var was: bool = w.defer_beliefs
	w.defer_beliefs = false
	for l in w.npcs:
		for mind in [l, l.shadow]:
			if mind == null or not l.alive:
				continue
			Mind.refresh_beliefs(w, mind, "")
			out["%s/%s" % [l.id, "shadow" if mind == l.shadow else "self"]] = mind.suspicion.duplicate()
	w.defer_beliefs = was
	return out

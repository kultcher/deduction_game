## Burdens prototype, stage 2: Ill-Omened (docs/design/burdens.md §9 items 5-10). Nominated,
## the holder cites the omen; only that restatement arms it. Hanged then, every good person
## is poisoned from that night until the next night begins; evil isn't. A bluffer's hanging
## poisons nobody. Claimed, the omen weighs on the vote about as much as the player's yes.
extends SceneTree
const Game = preload("res://game/game.gd")
const Burdens = preload("res://sim/burdens.gd")
const Evil = preload("res://sim/evil.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _case():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 2
	g.w.phase = C.EVENING
	if not "ill_omened" in g.w.case_script.secrets:
		g.w.case_script.secrets.append("ill_omened")
	return g

func _logged(w, type: String) -> Array:
	return w.dlog.entries.filter(func(x): return x["type"] == type)

func _init() -> void:
	_real()
	_bluff()
	_unarmed()
	_turned()
	_turned_unclaimed()
	_passed()
	_evil_knows()
	_omen_list()
	print("Ill-Omened: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _holder(w):
	var o = w.living_good()[0]
	for m in w.npcs:
		if m.secret_mod in ["marked", "unrequited", "ill_omened"]:
			m.secret_mod = ""
	o.secret_mod = "ill_omened"
	o.burden_self_known = true
	Burdens.setup_evil_knows_omen(w)  # evil knows the holder from the deal (Michael, Nov 22)
	return o

func _real() -> void:
	var w = _case().w
	var o = _holder(w)
	var early: Dictionary = Burdens.omen_early_warning(w, o)
	_check(not early.is_empty() and early["fact"].get("at_nomination", true) == false, "accused, a real holder may warn early; that claim isn't the nomination's")
	_check(Burdens.omen_early_warning(w, o).is_empty(), "and only once")
	_check(is_equal_approx(Burdens.omen_vote_cost(w, o.id), -(Tuning.Meeting.PLAYER_VOTE_YES_SLOPE * 0.5 + Tuning.Meeting.PLAYER_VOTE_YES_OFFSET)), "a claimed omen costs a vote about the median player's yes")
	var full: float = Burdens.omen_vote_cost(w, o.id)
	var voter = w.living_good()[1]
	voter.suspicion[o.id] = 0.6
	_check(is_equal_approx(Burdens.omen_vote_cost(w, o.id, voter), full * 0.4), "a voter who suspects the claimant weighs the cost by its belief the claim is true (option A)")
	var rival = w.living_good()[2]
	var pub: Array = w.burden_claims.get("ill_omened:public", [])
	pub.append(rival.id)
	w.burden_claims["ill_omened:public"] = pub
	_check(is_equal_approx(Burdens.omen_vote_cost(w, o.id, voter), full * 0.4 / float(pub.size())), "and rival claimants share it, since only one can hold it")
	pub.erase(rival.id)
	var nom: Dictionary = Burdens.omen_at_nomination(w, o)
	_check(not nom.is_empty() and nom["fact"].get("at_nomination", false) and nom["fact"]["secret_kind"] == "ill_omened", "nominated, the holder restates it, marked as the nomination's claim")
	_check("cost" in str(nom["line"].get("statement", "")) and not "poison" in str(nom["line"].get("statement", "")).to_lower(), "its words name a cost, never the effect")
	var evil: Array = w.npcs.filter(func(m): return m.alive and m.is_evil())
	# A Minion's push (Michael, Nov 21): non-Scion Minions want a real claimant hanged.
	var minions: Array = evil.filter(func(m): return m.id != w.demon_id and not C.is_demon(m.role) and m.role != "scion")
	var demon = w.by_id[w.demon_id]
	_check(not minions.is_empty() and Burdens.omen_push_target(w, minions[0]) == o.id, "a Minion sees a real claimant to push")
	_check(Burdens.omen_push_target(w, demon) == "", "the Demon doesn't push")
	var was: String = minions[0].role
	minions[0].role = "scion"
	_check(Burdens.omen_push_target(w, minions[0]) == "", "nor does the Scion")
	minions[0].role = was
	var mate = evil.filter(func(m): return m != minions[0])[0]
	var pub2: Array = w.burden_claims.get("ill_omened:public", [])
	pub2.push_front(mate.id)
	w.burden_claims["ill_omened:public"] = pub2
	_check(Burdens.omen_push_target(w, minions[0]) == o.id, "a teammate's bluffed claim is never pushed")
	pub2.erase(mate.id)
	pub2.push_front(minions[0].id)
	_check(Burdens.omen_push_target(w, minions[0]) == o.id, "nor its own bluffed claim: it never pushes itself")
	pub2.erase(minions[0].id)
	w.meeting["block"] = ""
	w.meeting["block_count"] = 0
	_check(Evil.evil_vote(w, minions[0], o.id, 0), "a Minion's evil self wants the real claimant hanged")
	_check(Tuning.Evil.OMEN_PUSH_STAKES > 0.0, "with extra stakes to break cover, weighed against its exposure")
	w.execute(o.id, {})
	var goods: Array = w.npcs.filter(func(m): return m.alive and not m.is_evil())
	_check(goods.all(func(m): return m.omen_poisoned_day == 2 and m.gift_broken()), "hanged, every living good person's gift fails")
	_check(evil.all(func(m): return m.omen_poisoned_day == -1), "evil is unaffected")
	_check(_logged(w, "omen_poison").size() == 1 and w.omen_nights.size() == 1 and _logged(w, "omen_hanged").size() == 1, "the town sees the omen fall (omen_hanged, omen_poison, w.omen_nights)")
	Burdens.lift_omen(w)
	_check(goods.all(func(m): return m.omen_poisoned_day == 2), "the night after the hanging, still poisoned")
	w.day = 3
	Burdens.lift_omen(w)
	_check(goods.all(func(m): return m.omen_poisoned_day == -1), "it lifts when the next night begins")

func _bluff() -> void:
	var w = _case().w
	var hb = _holder(w)
	hb.secret_mod = ""
	w.evil_plan["omen_holder"] = ""  # evil bluffs only when it knows none is dealt
	var e = w.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	if not w.evil_plan.has("burden_bluffs"):
		w.evil_plan["burden_bluffs"] = {}
	w.evil_plan["burden_bluffs"][e.id] = "ill_omened"
	if str(w.evil_plan.get("bluffs", {}).get(e.id, "")) == "":
		w.evil_plan["bluffs"][e.id] = "clerk"
	var nom: Dictionary = Burdens.omen_at_nomination(w, e)
	_check(not nom.is_empty(), "evil, set on the bluff, cites the omen when nominated")
	_check(Burdens.omen_early_warning(w, e).is_empty(), "but never warns early: the bluff waits for the nomination")
	w.execute(e.id, {})
	_check(w.npcs.all(func(m): return m.omen_poisoned_day == -1), "a bluffer's hanging poisons nobody")
	_check(_logged(w, "omen_hanged").size() == 1 and _logged(w, "omen_poison").is_empty(), "the town still sees an omen-claimer hanged, and can't tell")
	_check(w.public_log.any(func(e): return str(e.get("kind", "")) == "omen_hanged" and e.get("subjects", []).size() == 1 and int(e.get("phase", -1)) == C.EVENING), "the hanging is a public event, for the judge's view")

func _unarmed() -> void:
	var w = _case().w
	var o = _holder(w)
	Burdens.omen_early_warning(w, o)
	w.execute(o.id, {})
	_check(w.npcs.all(func(m): return m.omen_poisoned_day == -1) and _logged(w, "omen_hanged").is_empty(), "claimed only earlier, not restated at the nomination: hanging them does nothing")

## A holder who claimed it and was then turned evil still brings the omen when hanged
## (Michael, Nov 21: the script's text holds).
func _turned() -> void:
	var w = _case().w
	var o = _holder(w)
	_check(not Burdens.omen_early_warning(w, o).is_empty(), "the holder claims it while good")
	w.turn_evil(o, "test")
	_check(o.is_evil() and o.turned, "then is turned evil")
	var nom: Dictionary = Burdens.omen_at_nomination(w, o)
	_check(not nom.is_empty(), "nominated, the turned holder still restates it")
	w.execute(o.id, {})
	var goods: Array = w.npcs.filter(func(m): return m.alive and not m.is_evil())
	_check(goods.all(func(m): return m.omen_poisoned_day == w.day) and _logged(w, "omen_poison").size() == 1, "hanged, the omen still falls on every good person")

## A real holder always claims at its first nomination (Michael, Nov 21), so evil, once
## nominated without claiming, never bluffs Ill-Omened later.
func _passed() -> void:
	var w = _case().w
	_holder(w)
	var e = w.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	if not w.evil_plan.has("burden_bluffs"):
		w.evil_plan["burden_bluffs"] = {}
	if str(w.evil_plan.get("bluffs", {}).get(e.id, "")) == "":
		w.evil_plan["bluffs"][e.id] = "clerk"
	w.evil_plan["burden_bluffs"][e.id] = "marked"  # not set on the omen at its first nomination
	_check(Burdens.omen_at_nomination(w, e).is_empty() and w.omen_unclaimed.has(e.id), "evil nominated without claiming the omen: noted")
	w.evil_plan["burden_bluffs"][e.id] = "ill_omened"
	w.day += 1
	_check(Burdens.omen_at_nomination(w, e).is_empty(), "nominated again, it won't bluff Ill-Omened now")
	var w2 = _case().w
	var o = _holder(w2)
	_check(not Burdens.omen_at_nomination(w2, o).is_empty() and not w2.omen_unclaimed.has(o.id), "a real holder claims at its first nomination")
	var e2 = w2.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	e2.silenced = true
	Burdens.omen_at_nomination(w2, e2)
	_check(not w2.omen_unclaimed.has(e2.id), "a silenced nominee couldn't have claimed, so it isn't noted")

## The evil team knows the Ill-Omened from the deal (Michael, Nov 22).
func _evil_knows() -> void:
	var w = _case().w
	var o = _holder(w)
	_check(str(w.evil_plan.get("omen_holder", "")) == o.id and Burdens.evil_known_omen(w) == o.id, "evil knows who the Ill-Omened is")
	var e = w.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	if str(w.evil_plan.get("bluffs", {}).get(e.id, "")) == "":
		w.evil_plan["bluffs"][e.id] = "clerk"
	_check(not Burdens.evil_burden_bluff(w, e, "ill_omened", "stay off the rope"), "and so never bluffs it while a real one is dealt")
	var minion = w.npcs.filter(func(m): return m.alive and m.is_evil() and m.id != w.demon_id and not C.is_demon(m.role) and m.role != "scion")
	_check(minion.is_empty() or Burdens.omen_push_target(w, minion[0]) == o.id, "a Minion pushes the known holder, claimed or not")
	# The push waits for heat (Michael, Nov 22): never cold on day 1, only once the town is warm.
	if not minion.is_empty():
		var mm = minion[0]
		w.day = 1
		_check(not MindMeeting._omen_push_ready(w, mm, o.id), "no push-nomination on day 1")
		w.day = 2
		w.public_log = w.public_log.filter(func(x): return not (o.id in x.get("subjects", [])))
		for m2 in w.evil_team():
			m2.info_log = m2.info_log.filter(func(x): return not x.get("fake", false))
		w.evil_plan["fake_sightings"] = {}
		_check(not MindMeeting._omen_push_ready(w, mm, o.id), "nor while the town has no heat on the holder")
		# Evil's own bare accusations don't count (Michael, Nov 22)...
		var mates: Array = w.evil_team().filter(func(x): return x != mm)
		for i in range(6):
			w.public_event("accusation", [o.id], (mates[0] if not mates.is_empty() else mm).id)
		_check(not MindMeeting._omen_push_ready(w, mm, o.id), "evil's own bare accusations don't make the holder warm")
		# ...but a planted frame resting on a claim does.
		mm.info_log.append({"role": "seer", "day": 1, "data": {"pair": [o.id, w.living_good()[1].id], "yes": true}, "text": "x", "fake": true, "shared": false})
		var warm: Dictionary = Evil.omen_push_heat(w, mm, o)
		_check(float(warm["heat"]) > Tuning.Evil.PUBLIC_HEAT_BASE, "a fabricated reading against them counts as heat")
		mm.info_log = mm.info_log.filter(func(x): return not x.get("fake", false))
		w.public_log = w.public_log.filter(func(x): return not (o.id in x.get("subjects", [])))
		var accusers: Array = w.living_good().filter(func(x): return x != o)
		for i in range(4):
			w.public_event("accusation", [o.id], accusers[i % accusers.size()].id)
			w.public_event("nomination", [o.id], accusers[(i + 1) % accusers.size()].id)
		_check(MindMeeting._omen_push_ready(w, mm, o.id), "but once the town has turned on them, it may push")
	# The Demon killed the holder anyway (Michael, Nov 22): evil claims it at its nomination.
	var w2 = _case().w
	var o2 = _holder(w2)
	var e2 = w2.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	if str(w2.evil_plan.get("bluffs", {}).get(e2.id, "")) == "":
		w2.evil_plan["bluffs"][e2.id] = "clerk"
	_check(Burdens.omen_at_nomination(w2, e2).is_empty(), "while the holder lives, evil never claims it")
	w2.omen_unclaimed.erase(e2.id)
	o2.alive = false
	_check(not Burdens.omen_at_nomination(w2, e2).is_empty(), "once the holder is dead and never claimed it, evil claims it at its nomination")
	var w3 = _case().w
	var o3 = _holder(w3)
	var e3 = w3.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	if str(w3.evil_plan.get("bluffs", {}).get(e3.id, "")) == "":
		w3.evil_plan["bluffs"][e3.id] = "clerk"
	Burdens.omen_early_warning(w3, o3)
	o3.alive = false
	_check(Burdens.omen_at_nomination(w3, e3).is_empty(), "not if the dead holder had claimed it in public")

## A holder turned evil before it ever claimed still claims at its first nomination, and its
## hanging still brings the omen (Codex on #547).
func _turned_unclaimed() -> void:
	var w = _case().w
	var o = _holder(w)
	w.turn_evil(o, "test")
	_check(o.is_evil() and o.turned and not (o.id in Burdens.public_claimants(w, "ill_omened")), "turned before claiming")
	var nom: Dictionary = Burdens.omen_at_nomination(w, o)
	_check(not nom.is_empty() and not w.omen_unclaimed.has(o.id), "nominated, the turned holder claims it at its first nomination")
	w.execute(o.id, {})
	_check(_logged(w, "omen_poison").size() == 1, "hanged, the omen falls")

## A Night Watch list told on the night after a claimed Ill-Omened's hanging (Codex on #547):
## in worlds where the claimant truly held the omen, the watcher's gift was poisoned, so the
## movement model takes the list as broken there and it pulls less on the person it names
## out than the same list on an ordinary night. Built by hand on seed 692's 7-NPC deal.
func _list_pull(omen: bool) -> float:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	var w = g.w
	if not "ill_omened" in w.case_script.secrets:
		w.case_script.secrets.append("ill_omened")
	var goods: Array = w.living_good()
	var watcher = goods[0]
	watcher.role = "nightwatch"
	if "nightwatch" not in w.case_script.town:
		w.case_script.town.append("nightwatch")
	var listener = goods[1]
	var other = goods[2]
	var claimant = goods[3]
	if omen:
		w.day = 1
		w.phase = C.EVENING
		w.public_event("omen_hanged", [claimant.id], "world")
	w.day = 2
	w.phase = C.MORNING
	listener.history[w.time_key(1, 3)] = "home:" + listener.home_block
	var entry: Dictionary = {"day": 1, "phase": 3, "role": "nightwatch", "shared": true, "true": true,
		"data": {"block": other.home_block, "seen": [other.id]}, "text": "watching on the first night, I saw %s out" % other.name}
	watcher.info_log.append(entry)
	Mind.apply_info(w, listener, watcher, entry, 0.8)
	var key: String = listener.id + ":good"
	g._workshop_evaluations.erase(key)
	w.defer_beliefs = false
	Mind.refresh_beliefs(w, listener, " (test)")
	var eff: Dictionary = g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {})
	var post: float = float(eff.get(other.id, {}).get("posterior", -1.0))
	var prior: float = float(eff.get(other.id, {}).get("prior", -1.0))
	return post - prior

func _omen_list() -> void:
	var plain: float = _list_pull(false)
	var omen: float = _list_pull(true)
	print("Night Watch list's pull on the person it names out: %+.4f on an ordinary night, %+.4f under a fallen omen" % [plain, omen])
	_check(plain > 0.0 and omen < plain, "a Night Watch list under a fallen omen pulls less on the person it names than on an ordinary night (%+.4f < %+.4f)" % [omen, plain])

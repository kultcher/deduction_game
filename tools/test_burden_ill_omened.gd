## Burdens prototype, stage 2: Ill-Omened (docs/design/burdens.md §9 items 5-10). Nominated,
## the holder cites the omen; only that restatement arms it. Hanged then, every good person
## is poisoned from that night until the next night begins; evil isn't. A bluffer's hanging
## poisons nobody. Claimed, the omen weighs on the vote about as much as the player's yes.
extends SceneTree
const Game = preload("res://game/game.gd")
const Burdens = preload("res://sim/burdens.gd")
const Evil = preload("res://sim/evil.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")

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
	print("Ill-Omened: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _holder(w):
	var o = w.living_good()[0]
	for m in w.npcs:
		if m.secret_mod in ["marked", "unrequited", "ill_omened"]:
			m.secret_mod = ""
	o.secret_mod = "ill_omened"
	o.burden_self_known = true
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
	_holder(w)
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

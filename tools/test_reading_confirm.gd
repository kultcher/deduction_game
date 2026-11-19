## Does a reading confirm what the listener knows or strongly believes (workshop/reading_confirm.gd;
## Michael, Nov 19)? A reading clearing the listener itself is a known fact; one pointing at a
## person the listener strongly suspects confirms by belief, by tier; the listener's own reading,
## or one it barely believes, confirms nothing.
##   godot --headless --path . --script res://tools/test_reading_confirm.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Jury = preload("res://workshop/jury.gd")
const Confirm = preload("res://workshop/reading_confirm.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var listener = goods[0]
	var teller = goods[1]
	var other = w.npcs.filter(func(m): return m != listener and m != teller)[0]
	# 1. A Dowser's count of nobody evil in a group of just the listener: it knows that.
	var known: Dictionary = _assess(g, listener, teller, {"group": [listener.id], "count": 0}, {})
	check(known.tier == "known" and known.source == "fact", "a reading clearing the listener itself is a known fact (%s)" % str(known))
	# 2. A Dowser's count of one evil in a group of just `other`: by belief, by how strongly the
	#    listener suspects them.
	#    The listener's own chances (its last refresh) are what it believes; passed directly here.
	var high: Dictionary = _assess(g, listener, teller, {"group": [other.id], "count": 1}, {other.id: 0.9})
	var mid: Dictionary = _assess(g, listener, teller, {"group": [other.id], "count": 1}, {other.id: 0.75})
	var low: Dictionary = _assess(g, listener, teller, {"group": [other.id], "count": 1}, {other.id: 0.3})
	print("agreement at a chance of 0.9 / 0.75 / 0.3: %.3f / %.3f / %.3f" % [float(high.agreement), float(mid.agreement), float(low.agreement)])
	check(high.tier == "moderate" and mid.tier == "small", "a listener 90%% sure the person named is evil is moderately confirmed, 75%% sure slightly (%s / %s)" % [high.tier, mid.tier])
	check(float(high.agreement) > float(mid.agreement) and float(mid.agreement) > float(low.agreement), "the stronger the belief, the more the reading agrees with it")
	check(high.tier in ["moderate", "small"] and high.source == "belief", "pointing at someone strongly suspected confirms by belief (%s)" % str(high))
	check(low.tier == "none" and low.source == "", "pointing at someone barely suspected confirms nothing (%s)" % str(low))
	var tier_ok: bool = true
	for r in [high, mid, low]:
		var a: float = float(r.agreement)
		var want: String = "moderate" if a >= Tuning.Trust.READING_CONFIRM_MODERATE else ("small" if a >= Tuning.Trust.READING_CONFIRM_SMALL else "none")
		tier_ok = tier_ok and r.tier == want
	check(tier_ok, "tiers follow the cutoffs, not a scale")
	# 3. Its own reading confirms nothing about its teller.
	var own: Dictionary = _assess(g, listener, listener, {"group": [other.id], "count": 1}, {other.id: 0.9})
	check(own.tier == "none", "the listener's own reading confirms nothing (%s)" % str(own))
	# 4. A Lamplighter's count of walkers: no world can fail it (the table doesn't check the
	#    count), so it confirms nothing by its content, however little the listener knows.
	var lamp: Dictionary = _assess(g, listener, teller, {"count": 2}, {}, "lamplighter")
	check(lamp.tier == "none", "a reading no world can fail confirms nothing (%s)" % str(lamp))
	# 5. The listener's own readings count (Shared.prepare keeps their ids as attention_reports):
	#    it dowsed `other` and found one evil; `teller` says the same. Its own reading could have
	#    been poisoned, so this is strong belief rather than a known fact, but it agrees far more
	#    than the same reading heard by a listener without one.
	var g0 = Game.new()
	g0.log_dir = "user://test_logs"
	g0.new_case(692, 7)
	var bare: Dictionary = _assess(g0, g0.w.by_id[listener.id], g0.w.by_id[teller.id], {"group": [other.id], "count": 1}, {})
	var g2 = Game.new()
	g2.log_dir = "user://test_logs"
	g2.new_case(692, 7)
	var l2 = g2.w.by_id[listener.id]
	var t2 = g2.w.by_id[teller.id]
	l2.info_log.append({"day": 1, "phase": 0, "role": "dowser", "shared": false, "true": true, "data": {"group": [other.id], "count": 1}, "text": "dowsing"})
	var plan2: Dictionary = _prepare(g2, l2)
	var own_ids: Array = plan2.prepared.listener.knowledge.get("attention_reports", []) if plan2.get("ready", false) else []
	print("own report ids after prepare: %s" % str(own_ids))
	var corrob: Dictionary = _assess(g2, l2, t2, {"group": [other.id], "count": 1}, {})
	print("agreement without / with its own matching reading: %.3f / %.3f" % [float(bare.agreement), float(corrob.agreement)])
	check(not own_ids.is_empty() and float(corrob.agreement) > float(bare.agreement) + 0.2 and corrob.tier in ["moderate", "known"], "another's reading matching the listener's own confirms it (%s, against %s without)" % [str(corrob), str(bare)])
	print("Reading confirm: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## The listener hears `teller`'s Dowser reading `data`, then is asked whether it confirms what
## it holds, with its chances that some people are evil set to `chances`.
func _assess(g, listener, teller, data: Dictionary, chances: Dictionary, role := "dowser") -> Dictionary:
	var w = g.w
	var entry: Dictionary = {"day": 1, "phase": 0, "role": role, "shared": true, "true": true, "data": data,
		"text": "dowsing %s" % str(data)}
	if teller == listener:
		listener.info_log.append(entry)
	else:
		teller.info_log.append(entry)
		Mind.apply_info(w, listener, teller, entry, 0.8)
	var plan: Dictionary = _prepare(g, listener)
	if not plan.get("ready", false):
		return {"tier": "unprepared", "agreement": 0.0, "source": ""}
	var view: Dictionary = plan.prepared.view
	var who: Dictionary = Jury._eval_listener(plan.prepared.listener, plan.prepared.listener.knowledge.get("own_reports", []))
	var cards: Array = view.cards.filter(func(c): return c.get("kind", "") == "report" and str(c.get("role", "")) == role and str(c.get("source", "")) == teller.id and c.get("data", {}).get("group", []) == data.get("group", []))
	if cards.is_empty():
		return {"tier": "no card", "agreement": 0.0, "source": ""}
	return Confirm.assess(view, cards[-1], who, chances)


func _prepare(g, listener) -> Dictionary:
	var input: Dictionary = Bridge.capture(g, [], listener.id, "private", listener)
	var st: Dictionary = listener.workshop_state
	return Shared.prepare(input, st.get("presentations", {}), listener.ledger, st.get("withdrawn", {}), st.get("attention_focus", []))

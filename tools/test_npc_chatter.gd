## NPC chatter (Nov 8): each conversation slot rolls on its own, yesterday's talk reaches the
## tavern, and the day-1 confidant (a private role claim with a lower bar and a trust bump).
##   godot --headless --path . --script res://tools/test_npc_chatter.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Tuning = preload("res://sim/tuning.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _fresh(seed_v: int = 4242, n: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://npc_chatter_tests"
	g.new_case(seed_v, n)
	return g


func _run() -> void:
	_test_confide()
	_test_yesterday_gossip()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _pick_kinds(w, s, l, tries: int) -> Dictionary:
	var kinds: Dictionary = {}
	var saved = w.rng.state
	for i in range(tries):
		var item = Social._pick_item(w, s, l)
		if item != null:
			kinds[item.kind] = kinds.get(item.kind, 0) + 1
	w.rng.state = saved
	return kinds


func _test_confide() -> void:
	var g = _fresh()
	var w = g.w
	# A teller the day-1 confidant bonus can bring to name its gift, and not yet so open that
	# it names it every time by day 2 (when the day's own openness takes over): whether it does
	# also rests on its role's own disclosure score and that day's fear roll, which vary by
	# deal (Beadle, on #remove-drops: the setup reshuffle made the first candidate a Warden
	# afraid on day 1, then a Night Watch whose gift holds back its claims).
	var s = null
	var l = null
	var on_day1: Dictionary = {}
	for cand in w.living_good().filter(func(n): return n.secret.is_empty() and C.hint_package(w, n.role) != ""):
		var lis = w.living_good().filter(func(n): return n != cand)[0]
		cand.claim_public = false
		cand.protect_lock = false
		cand.pressure = 0.0
		cand.traits["privacy"] = 0.5
		cand.npc_trust[lis.id] = 0.5   # a middling listener: a hint is the usual answer
		lis.known_claims.erase(cand.id)
		cand.confided = false
		w.confides_made = 0   # the case's first morning may already have used the town's confidings
		w.day = 1
		var kinds: Dictionary = _pick_kinds(w, cand, lis, 600)
		w.day = 2
		var later: Dictionary = _pick_kinds(w, cand, lis, 600)
		w.day = 1
		# Not so open that it names the gift every time by day 2, or the bonus can't show.
		if kinds.get("role_claim", 0) > 0 and later.get("role_hint", 0) > 0:
			s = cand
			l = lis
			on_day1 = kinds
			break
	if s == null:
		_check(false, "a teller the day-1 confidant bonus can bring to a claim, in this deal")
		return
	w.day = 2
	var on_day2: Dictionary = _pick_kinds(w, s, l, 600)
	_check(on_day1.get("role_claim", 0) > on_day2.get("role_claim", 0), "on day 1 the confidant bonus makes the gift itself likelier (%s vs %s)" % [str(on_day1), str(on_day2)])
	w.day = 1
	w.confides_made = Tuning.Social.CONFIDE_MAX_PER_GAME
	var capped: Dictionary = _pick_kinds(w, s, l, 600)
	_check(capped.get("role_claim", 0) < on_day1.get("role_claim", 0), "once the town has had its confidings, the bonus is gone (%s)" % str(capped))
	w.confides_made = 0
	var lt0: float = l.npc_trust.get(s.id, 0.5)
	var st0: float = s.npc_trust.get(l.id, 0.5)
	var item: Dictionary = {"kind": "role_claim", "about": s.id, "from": s.id, "role": s.role, "key": "role_claim:" + s.id, "lie": false, "confide": true}
	Social._deliver(w, s, l, item)
	_check(s.confided and w.confides_made == 1, "telling one person closes their window and counts toward the town's cap")
	_check(l.npc_trust[s.id] >= lt0 + Tuning.Social.CONFIDE_TRUST_LISTENER - 1e-9, "the listener warms to the one who confided (%.2f -> %.2f)" % [lt0, l.npc_trust[s.id]])
	_check(s.npc_trust[l.id] >= st0 + Tuning.Social.CONFIDE_TRUST_TELLER - 1e-9 and s.npc_trust[l.id] - st0 < l.npc_trust[s.id] - lt0 + 1e-9, "the confider warms a little less")


func _test_yesterday_gossip() -> void:
	var g = _fresh()
	var w = g.w
	w.day = 2
	var a = w.living_good()[0]
	var b = w.living_good()[1]
	w.daily_npc_shares = [{"day": 2, "phase": C.AFTERNOON, "loc": "tavern", "speaker": a.id, "listener": b.id,
		"item": {"kind": "role_hint", "about": a.id, "from": a.id, "package": C.hint_package(w, a.role), "key": "role_hint:" + a.id}},
		{"day": 1, "phase": C.NIGHT, "loc": "tavern", "speaker": b.id, "listener": a.id,
		"item": {"kind": "role_hint", "about": b.id, "from": b.id, "package": C.hint_package(w, b.role), "key": "role_hint:" + b.id}}]
	w.start_new_day()
	var kept: Array = w.daily_npc_shares.filter(func(r): return int(r.day) <= 2)
	_check(kept.size() == 1 and int(kept[0].day) == 2, "a new day keeps yesterday's talk and drops older (%s)" % str(w.daily_npc_shares.map(func(r): return r.day)))

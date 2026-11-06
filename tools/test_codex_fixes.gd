## Fixes from the Codex review of the Nov 5 PRs (game behaviour):
##   - #69: a Sexton already out with their gift tells of a later toll once the bell has worn
##     off, and an account of the toll at the podium tells evil the bell rang.
##   - #69: a refusal about the toll night is reconsidered once pressure rises.
##   - #77: a late relay is public grounds in every mind, the teller's included.
##   godot --headless --path . --script res://tools/test_codex_fixes.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const WorkshopLedger = preload("res://workshop/shared_ledger.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_public_sexton_tolls()
	_test_refusal_reconsidered()
	_test_late_relay_public()
	_test_toll_kept_quiet()
	print("Codex fixes: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _sexton_game(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	var w = g.w
	var sx = w.living_good()[0]
	sx.role = "sexton"
	sx.alignment = "good"
	sx.gift_used = true
	sx.secret = {}
	sx.secret_mod = ""
	sx.pressure = 0.0
	w.sexton_tolled_night = 1
	w.sexton_suppression_night = 1
	var other_block: String = C.BLOCKS.keys().filter(func(b): return b != sx.home_block)[0]
	sx.history[w.time_key(1, C.NIGHT)] = "night:" + other_block
	return [g, sx]


func _test_public_sexton_tolls() -> void:
	var gs = _sexton_game(56789)
	var w = gs[0].w
	var sx = gs[1]
	sx.claimed_role = "sexton"
	sx.claim_public = true   # claimed before the toll
	w.evil_plan.erase("bell_believed")
	w.day = 2
	w.phase = C.EVENING
	var lines: Array = []
	var facts: Array = []
	MindMeeting._go_public(w, sx, lines, facts)
	_check(not w.evil_plan.has("bell_believed") and lines.is_empty(), "while the bell holds, a public Sexton keeps the toll to themself")
	w.day = 3
	MindMeeting._go_public(w, sx, lines, facts)
	_check(int(w.evil_plan.get("bell_believed", -1)) == 1 and facts.any(func(f): return f.get("duty", "") == "sexton" and f.get("public", false)),
		"once it has worn off, they tell the town (and evil believes the bell rang)")
	lines.clear()
	facts.clear()
	MindMeeting._go_public(w, sx, lines, facts)
	_check(lines.is_empty(), "and only once")
	# The podium: pressed on the toll night while the bell still holds.
	gs = _sexton_game(56790)
	w = gs[0].w
	sx = gs[1]
	sx.claimed_role = "sexton"
	sx.claim_public = true
	w.evil_plan.erase("bell_believed")
	w.day = 2
	w.phase = C.EVENING
	var res: Dictionary = MindPodium.press_night(w, sx, 1, true)
	_check(res.get("outcome", "") == "duty" and int(w.evil_plan.get("bell_believed", -1)) == 1,
		"pressed at the podium, their account of the toll tells evil the bell rang (%s)" % res.get("outcome", ""))


func _test_refusal_reconsidered() -> void:
	var gs = _sexton_game(56791)
	var w = gs[0].w
	var sx = gs[1]
	sx.claimed_role = ""
	sx.claim_public = false
	w.day = 2
	w.phase = C.MORNING
	var key: String = "1:2"
	var reconsidered: bool = false
	var held: bool = true
	for i in range(12):
		sx.dialogue_memory.erase("honest_outing")
		sx.pressure = 0.0
		var first: String = MindDialogue._honest_outing(w, sx, 1)
		if first != "withhold":
			continue
		held = held and MindDialogue._honest_outing(w, sx, 1) == "withhold"
		sx.pressure = 1.0
		MindDialogue._honest_outing(w, sx, 1)
		var memo: Dictionary = sx.dialogue_memory["honest_outing"][key]
		reconsidered = is_equal_approx(float(memo.p), 1.0)
		break
	_check(held, "asked twice under the same pressure, one answer")
	_check(reconsidered, "a refusal is reconsidered once their pressure has risen")


func _test_late_relay_public() -> void:
	var g = Game.new()
	g.detailed_logging = false
	var w = null
	var n = null
	var src = null
	var entry: Dictionary = {}
	for sd in range(9101, 9131):
		g.new_case(sd, 7)
		w = g.w
		var goods: Array = w.living_good()
		for s in goods:
			if not s.info_log.is_empty() and not s.info_log[0].get("shared", false):
				src = s
				entry = s.info_log[0]
				break
		if src != null:
			n = goods.filter(func(x): return x != src)[0]
			break
	_check(src != null, "found a townsperson with a private reading")
	if src == null:
		return
	Mind.apply_info(w, n, src, entry, 0.9)   # told privately before they died
	n.known_claims[src.id] = {"role": entry.get("role", src.role), "readings": [entry], "via": src.id}
	src.alive = false
	n.silenced = false
	var told: bool = false
	for i in range(40):
		var lines: Array = []
		var facts: Array = []
		MindMeeting._late_relay(w, n, lines, facts)
		if not lines.is_empty():
			told = true
			break
	_check(told, "the late relay is told at a meeting")
	if not told:
		return
	var public_in: Callable = func(m) -> bool:
		for eid in m.ledger:
			for r in m.ledger[eid].get("meta", {}).get("workshop_receipts", {}).values():
				if str(r.get("source", "")) == src.id and r.get("heard_in_public", false):
					return true
		return false
	var listeners: Array = w.living().filter(func(m): return m != n and not m.is_evil())
	_check(listeners.all(public_in), "every good listener holds it as public grounds")
	_check(public_in.call(n), "so does the teller's own copy")


## Maintenance Nov 6 (A1, A2): the toll isn't gossip while the bell holds, and a reading's text
## carries no time of its own (the sentence says when).
func _test_toll_kept_quiet() -> void:
	var gs = _sexton_game(56795)
	var w = gs[0].w
	var sx = gs[1]
	var rdef = C.role_def("sexton")
	w.day = 2
	_check(not rdef.may_share_reading(w, sx, {}), "the day after the toll, the Sexton won't gossip about it")
	sx.dialogue_memory["toll_told_public"] = true
	_check(rdef.may_share_reading(w, sx, {}), "once told before the town, it's no secret")
	sx.dialogue_memory.erase("toll_told_public")
	w.day = 3
	_check(rdef.may_share_reading(w, sx, {}), "once the bell has worn off, it can be told")
	var e: Dictionary = {"day": 1, "role": "monitor", "data": {"block": "square", "walked": false}, "text": "no one walked by my house"}
	var st: String = MindMeeting._info_intent(w, sx, e)["statement"]
	_check(not ("last night" in st.substr(1)) and st.count("night") == 1, "a first-night Monitor reading told on Day 3 says when once (%s)" % st)

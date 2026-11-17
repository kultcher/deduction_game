## A reading the listener doubts honestly (a poisoned or misled night) speaks through the role
## check only as far as it's trusted (CaseEval._doubted_role_fits, Nov 17). Before, a Seer's
## Red Herring placement, an Archivist's or a Gravedigger's role reading still moved its people
## in full after the listener learned its night was misled, under both belief models.
##   godot --headless --path . --script res://tools/test_role_check_doubt.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Connections = preload("res://workshop/connections.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Tuning = preload("res://sim/tuning.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	# These checks compare the doubt a heard argument brings with none at all; the standing
	# Delusional self-doubt on one's own readings (test_delusional_self_doubt) is off here.
	SourceDoubt.delusional_self_doubt = false
	for role in ["seer", "archivist", "gravedigger"]:
		CaseEval.doubted_role_check = false
		var before: Dictionary = _one(role)
		CaseEval.doubted_role_check = true
		var after: Dictionary = _one(role)
		var moved: float = absf(after.mid - after.pre)
		check(moved > 0.03, "%s: the listener's own reading moves its subject (%.3f -> %.3f)" % [role, after.pre, after.mid])
		check(absf(before.end - before.mid) < 0.005, "%s: with the switch off, doubting it changes nothing (%.3f -> %.3f), as before the fix" % [role, before.mid, before.end])
		check(absf(after.end - after.pre) < 0.35 * moved, "%s: once its night is doubted (0.8), most of what it did goes (%.3f -> %.3f, from %.3f)" % [role, after.mid, after.end, after.pre])
		check(is_equal_approx(before.mid, after.mid), "%s: an undoubted reading is read exactly as before" % role)
	# A night-specific "lied" argument (Codex on #186) is doubt that the teller lied, which the
	# role check already handles by letting an evil teller lie: it must not soften the reading.
	for role in ["seer", "archivist"]:
		CaseEval.doubted_role_check = false
		var off: Dictionary = _one(role, "lied")
		CaseEval.doubted_role_check = true
		var on: Dictionary = _one(role, "lied")
		check(is_equal_approx(off.end, on.end), "%s: a \"lied\" argument isn't read as an honest error (%.3f with the fix, %.3f without)" % [role, on.end, off.end])
	CaseEval.doubted_role_check = true
	print("Role check doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## The listener reads `role` on night 1; its subject's suspicion before, with the reading, and
## after a misled argument doubts that night.
func _one(role: String, doubt_kind: String = "misled") -> Dictionary:
	var t = _setup(5110)
	var w = t["w"]
	var L = t["L"]
	L.role = role
	var evil: Array = w.npcs.filter(func(m): return m.is_evil() and m.id != L.id)
	var good: Array = w.npcs.filter(func(m): return not m.is_evil() and m.id != L.id)
	var minion: Array = evil.filter(func(m): return m.id != w.demon_id)
	var reading: Dictionary
	var subject: String
	if role == "seer":
		reading = _seer(1, w.demon_id, good[0].id)
		subject = good[0].id
	elif role == "archivist":
		var m = minion[0] if not minion.is_empty() else evil[0]
		reading = {"day": 1, "role": "archivist", "data": {"pair": [m.id, good[0].id], "role": m.role}, "text": "archivist test"}
		subject = good[0].id
	else:
		_hang(w, evil[0], 1)
		reading = _verdict(1, evil[0].id, evil[0].role)
		subject = good[0].id
	var pre: float = Mind.susp(L, subject)
	Mind.apply_info(w, L, L, reading, 1.0)
	var mid: float = Mind.susp(L, subject)
	if doubt_kind == "misled":
		_doubt(t, L.id, 1)
	else:
		Mind.ledger_hear(t["w"], L, "arg:test-%s:%s:1" % [doubt_kind, L.id], [], 1.0, [],
			{"kind": "arg", "conclusion": {"type": doubt_kind, "a": L.id, "night": 1}})
	return {"pre": pre, "mid": mid, "end": Mind.susp(L, subject)}

func _setup(sd: int) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_logs"
	g.new_case(sd)
	var w = g.w
	w.day = 3
	for p in w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.known_claims = {}
			m.beliefs = []
			m.ledger = {}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
			Mind.refresh_beliefs(w, m, " (clean)")
	var L = w.living_good()[0]
	var others: Array = w.npcs.filter(func(x): return x != L)
	return {"g": g, "w": w, "L": L, "A": others[0], "B": others[1], "C": others[2], "D": others[3]}

func _seer(night: int, x: String, y: String) -> Dictionary:
	return {"day": night, "role": "seer", "data": {"pair": [x, y], "yes": true}, "text": "seer test"}

func _hang(w, who, day: int) -> void:
	who.alive = false
	who.death_day = day
	who.death_cause = "executed"
	# The public execution is logged on the day it happened, which is what dates the
	# Gravedigger's reading that night (purge 3 rejects a reading with no such execution).
	var today: int = w.day
	w.day = day
	w.public_event("execution", [who.id], "town")
	w.day = today
	w.executions.append({"day": day, "id": who.id, "nominator": "player", "yes": [], "no": [], "player_yes": true, "player_nominated": true})

func _verdict(night: int, who: String, role: String) -> Dictionary:
	return {"day": night, "role": "gravedigger", "data": {"executed": who, "role": role}, "text": "verdict test"}

func _watch(night: int, block: String, seen: Array) -> Dictionary:
	return {"day": night, "role": "nightwatch", "data": {"block": block, "seen": seen}, "text": "watch test"}

func _doubt(t: Dictionary, src: String, night: int) -> void:
	Mind.ledger_hear(t["w"], t["L"], "arg:test-misled:%s:%d" % [src, night], [], 1.0, [],
		{"kind": "arg", "conclusion": {"type": "misled", "a": src, "night": night}})

func _h(t: Dictionary, id: String) -> float:
	var L = t["L"]
	var r_sd: float = Mind.reliability(L, id, -1, "report")
	var s_pen: float = clampf(0.8 * maxf(0.0, Mind.susp(L, id) - 0.1), 0.0, 0.7) if not Mind.demon_victim(t["w"], id) else 0.0
	return minf(r_sd, 1.0 - s_pen)


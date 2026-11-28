## A claim without its readings says so (Michael, Nov 28, item 3): straight after a new public
## claim, if the gift has readings still unshared, the speaker gives their own "keeping my
## readings" line (withhold_readings_privacy, or a voice's withhold_readings_public).
##   godot --headless --path . --script res://tools/test_claim_only_reveal.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Dialogue = preload("res://sim/dialogue.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _texts(lines: Array) -> Array:
	return lines.map(func(l): return str(l.get("text", "")))

func _run() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var guard := 0
	while g.state != "over" and g.w.day < 3 and guard < 300:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	var w = g.w
	# Someone good, not yet public, holding readings of their own.
	var cands: Array = w.living().filter(func(n): return not n.is_evil() and C.has_readings(n.role) and not n.info_log.is_empty())
	if not cands.is_empty():
		# Set the moment up: not yet public, readings unshared (as at a podium outing).
		cands[0].claim_public = false
		for e in cands[0].info_log:
			e["shared"] = false
			e["disowned"] = false
	check(not cands.is_empty(), "found someone holding readings (%d)" % cands.size())
	if cands.is_empty():
		quit(1)
		return
	var n = cands[0]
	var held: String = Dialogue.voice_line(n.id, "withhold_readings_privacy", "What it's shown me, I'll keep to myself for now.")
	var lines: Array = []
	var facts: Array = []
	MindMeeting._go_public(w, n, lines, facts, false)
	var said: Array = _texts(lines)
	check(n.claim_public and said.size() >= 2, "a claim-only reveal: the claim, then more (%s)" % str(said))
	check(said.any(func(t): return held in t), "the follow-up is their own 'keeping my readings' line (%s)" % held)
	# Last words don't keep anything back: no such line on the gallows.
	var lw = cands[1] if cands.size() > 1 else null
	if lw != null:
		lw.claim_public = false
		for e in lw.info_log:
			e["shared"] = false
		var held_lw: String = Dialogue.voice_line(lw.id, "withhold_readings_privacy", "What it's shown me, I'll keep to myself for now.")
		var lw_lines: Array = []
		MindMeeting._public_disclosure(w, lw, lw_lines, facts, false, false)
		check(lw.claim_public and not _texts(lw_lines).any(func(t): return held_lw in t), "last words claim without the 'keeping' line")
	# Already public: an update doesn't repeat it.
	lines = []
	MindMeeting._go_public(w, n, lines, facts, false)
	check(not _texts(lines).any(func(t): return held in t), "a claimant already public doesn't say it again")
	# Sharing everything: nothing held, so no such line.
	var m2: Array = w.living().filter(func(x): return x != n and not x.is_evil() and C.has_readings(x.role) and not x.info_log.is_empty())
	if not m2.is_empty():
		var o = m2[0]
		o.claim_public = false
		for e in o.info_log:
			e["shared"] = false
			e["disowned"] = false
		var held2: String = Dialogue.voice_line(o.id, "withhold_readings_privacy", "What it's shown me, I'll keep to myself for now.")
		lines = []
		MindMeeting._go_public(w, o, lines, facts, true)
		var left: bool = o.info_log.any(func(e): return not e.get("shared", false) and not e.get("disowned", false))
		check(left or not _texts(lines).any(func(t): return held2 in t), "sharing everything says no 'keeping' line")
	# A gift without readings says nothing of readings.
	var plain: Array = w.living().filter(func(x): return not x.is_evil() and not C.has_readings(x.role))
	if not plain.is_empty():
		var p = plain[0]
		p.claim_public = false
		var heldp: String = Dialogue.voice_line(p.id, "withhold_readings_privacy", "What it's shown me, I'll keep to myself for now.")
		lines = []
		MindMeeting._go_public(w, p, lines, facts, false)
		check(not _texts(lines).any(func(t): return heldp in t), "a gift with no readings doesn't claim to be keeping any")
	# Two voices speak to the town in their own form (Michael, Nov 28).
	check(Dialogue.voice_line("fenwick", "withhold_readings_public", "") == "What my gift has revealed must wait for the proper scene, friends." and Dialogue.voice_line("edda", "withhold_readings_public", "").ends_with("if it's all the same to you."), "Fenwick and Edda have their town forms")
	print("Claim-only reveal: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

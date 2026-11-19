## Summarised meeting answers (Michael, Nov 19): listeners who answered a presented case alike
## (stance, kind of reply, movement band on its target) are shown as one: a representative in
## full, the rest as small portraits with an agreement line, at most five and "+N more". The
## target and anyone with more to say speak alone; the log keeps every answer.
##   godot --headless --path . --script res://tools/test_response_bundles.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Bundles = preload("res://game/response_bundles.gd")
const Stage = preload("res://ui/courtroom_stage.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _e(id: String, agreement: float, stance: String, reply: String, delta: float, trust: float, seat: int, extra: Dictionary = {}) -> Dictionary:
	var line: Dictionary = {"speaker": id, "name": id.capitalize(), "text": "%s says their piece." % id.capitalize(), "statement": "x", "reply_key": reply}
	var e: Dictionary = {"id": id, "name": id.capitalize(), "lines": [line], "facts": [], "agreement": agreement, "stance": stance, "delta": delta, "trust": trust, "seat": seat}
	e.merge(extra, true)
	return e

func _run() -> void:
	check(Bundles.movement_band(0.2) == "rose_lot" and Bundles.movement_band(0.08) == "rose" and Bundles.movement_band(0.0) == "still" and Bundles.movement_band(-0.1) == "fell", "four movement bands")
	var entries: Array = [
		_e("agnes", 0.80, "accept", "present_accept_open", 0.10, 0.5, 0),
		_e("bart", 0.70, "accept", "present_accept_open", 0.09, 0.6, 1),
		_e("constance", 0.75, "accept", "present_accept_open", 0.07, 0.4, 2),
		_e("dorian", 0.20, "reject", "present_unmoved", 0.0, 0.5, 3),
		_e("edda", 0.75, "accept", "present_accept_open", 0.20, 0.5, 4),   # moved a lot: its own bundle
		_e("fenwick", 0.10, "reject", "present_unmoved", 0.0, 0.5, 5),
		_e("greta", 0.5, "partial", "present_partial", 0.02, 0.5, 6, {"facts": [{"kind": "x"}]}),  # a fact: alone
		_e("hollis", 0.0, "reject", "present_false_self", 0.0, 0.5, 7),     # the target: last
	]
	var out: Array = Bundles.arrange(entries, "hollis")
	var speakers: Array = out.filter(func(s): return s is Dictionary and s.has("speaker") and not s.get("bundled", false)).map(func(s): return s.speaker)
	var first: Dictionary = out[0]
	check(first.speaker == "constance" and first.agree.map(func(a): return a.speaker) == ["agnes", "bart"], "the accept bundle comes first, its representative nearest its middle (%s with %s)" % [first.speaker, str(first.agree.map(func(a): return a.speaker))])
	check(out.filter(func(s): return s is Dictionary and s.get("bundled", false)).map(func(s): return s.speaker) .has("agnes"), "the others' own words go to the log, marked bundled")
	check(first.agree[0].own == "Agnes says their piece.", "hovering a small portrait shows their own words")
	check(speakers.has("edda") and speakers.has("dorian") and speakers.has("greta"), "a different movement band, the reject bundle and a speaker with a fact all speak (%s)" % str(speakers))
	check(speakers.find("dorian") < speakers.find("greta") and speakers.back() == "hollis", "bundles by agreement, then those alone, the target last (%s)" % str(speakers))
	var reject: Array = out.filter(func(s): return s is Dictionary and s.get("speaker", "") in ["dorian", "fenwick"] and not s.get("bundled", false))
	check(reject.size() == 1 and reject[0].agree.size() == 1, "two who rejected alike are one bundle")
	check(out.any(func(s): return s is Dictionary and s.has("facts") and not s.has("speaker")), "a solo speaker's fact still goes on the board")

	# Alike in words but naming different suspects: not agreement (Codex, #373).
	var alt: Array = [
		_e("agnes", 0.2, "reject", "present_alt_reject_solo", 0.0, 0.5, 0),
		_e("bart", 0.2, "reject", "present_alt_reject_solo", 0.0, 0.5, 1),
		_e("constance", 0.2, "reject", "present_alt_reject_solo", 0.0, 0.5, 2),
	]
	alt[0].lines[0]["reply_named"] = ["dorian"]
	alt[1].lines[0]["reply_named"] = ["edda"]
	alt[2].lines[0]["reply_named"] = ["dorian"]
	var alt_out: Array = Bundles.arrange(alt, "hollis")
	var alt_rows: Array = alt_out.filter(func(s): return s is Dictionary and s.has("speaker") and not s.get("bundled", false))
	check(alt_rows.size() == 2 and alt_rows.any(func(s): return s.speaker == "bart" and s.get("agree", []).is_empty()), "answers naming different suspects don't bundle; the two naming the same one do (%s)" % str(alt_rows.map(func(s): return s.speaker)))

	# At most five small portraits, the rest counted.
	var many: Array = []
	for i in range(8):
		many.append(_e(["agnes", "bart", "constance", "dorian", "edda", "fenwick", "greta", "isolde"][i], 0.8, "accept", "present_accept_open", 0.1, 0.5, i))
	var big: Dictionary = Bundles.arrange(many, "nobody")[0]
	check(big.agree.size() == 5 and int(big.agree_more) == 2, "five portraits and \"+2 more\" (%d, %d)" % [big.agree.size(), int(big.get("agree_more", 0))])
	check(Bundles.agreement_line("bart", 0) == "Aye." and Bundles.agreement_line("bart", 1) == "Same.", "agreement lines alternate in the speaker's voice")

	# A real meeting: every listener's answer is said once, as a representative, a bundled log
	# line, or alone.
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(692, 10)
	if g.state == "approach":
		g.command("decline")
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	g._start_meeting()
	var t = g.w.living_good()[0]
	var cards: Array = g.board.filter(func(c): return c.get("kind", "") in ["sighting", "info", "claim"]).map(func(c): return int(c.n)).slice(0, 2)
	var ded: int = g.file_deduction({"type": "evil", "a": t.id}, cards)
	g.command("present %d" % ded)
	var said: Array = g.last_events.filter(func(e): return e.get("k", "") == "speech")
	var ids: Array = said.map(func(e): return e.speaker)
	var living: Array = g.w.living().filter(func(n): return not n.silenced).map(func(n): return n.id)
	var each_once: bool = living.all(func(id): return ids.count(id) >= 1)
	check(g.presented_today and each_once, "every listener's answer is in the log (%d answers for %d listeners)" % [said.size(), living.size()])
	var reps: Array = said.filter(func(e): return not e.get("agree", []).is_empty())
	var agreed: Array = []
	for r in reps:
		agreed.append_array(r.agree.map(func(a): return a.speaker))
	var bundled: Array = said.filter(func(e): return e.get("bundled", false)).map(func(e): return e.speaker)
	agreed.sort()
	bundled.sort()
	check(agreed == bundled, "those shown agreeing are exactly the bundled log lines (%s)" % str(agreed))
	check(not bundled.has(t.id), "the target never agrees in a row")

	# The stage: a bundled line isn't brought forward; the row is drawn under the speaker.
	var stage = Stage.new()
	root.add_child(stage)
	stage.push([{"k": "speech", "speaker": "agnes", "name": "Agnes", "text": "I believe it.", "agree": [{"speaker": "bart", "name": "Bart", "text": "Aye.", "own": "Bart's own words."}]},
		{"k": "speech", "speaker": "bart", "name": "Bart", "text": "Bart's own words.", "bundled": true}])
	check(stage.current.get("speaker", "") == "agnes" and stage.waiting() == 0, "the stage brings forward the representative only")
	check(stage.agree_row.visible and stage.agree_row.get_child_count() == 1 and stage.agree_row.get_child(0).tooltip_text == "Bart: Bart's own words.", "and draws who agreed, their own words on hover")
	stage.queue_free()
	print("Response bundles: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

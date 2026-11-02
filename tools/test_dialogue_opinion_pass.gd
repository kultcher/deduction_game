## Checks for the Nov 1 dialogue pass: opinion lines that keep suspicion, word credit and
## bonds apart; verbal-tic caps; stance-consistent argument openers; spoken night names;
## and the "ask about" relationship cap.
## godot --headless --path . --script res://tools/test_dialogue_opinion_pass.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Decisions = preload("res://sim/dialogue_decisions.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	_voice_coverage()
	_tics()
	_decision_cues()
	_spoken_nights()
	_opinions()
	print("%d checks, %d failures" % [checks, fails])
	quit()

func _voice_coverage() -> void:
	for id in Voices.VOICES:
		for key in ["opinion_clear", "opinion_word_doubt", "opinion_friend_clear", "opinion_friend_suspect",
				"opinion_rival_clear", "opinion_rival_suspect", "readings_stand"]:
			var line: String = Dialogue.voice_line(id, key, "FALLBACK", {"subject": "Edda"})
			check(line != "FALLBACK" and not "{" in line, "%s has %s" % [id, key])
			check(not ("I trust" in line), "%s/%s doesn't say 'I trust' for a suspicion level" % [id, key])
		check(Voices.VOICES[id].get("rival", []) is Array and Voices.VOICES[id]["rival"].size() == 2, "%s has two rival notes" % id)
		check(not Voices.VOICES[id].has("opinion_trust"), "%s no longer has opinion_trust" % id)
		for key in Decisions.LINES.get(id, {}):
			pass
		for key in ["warming", "cooling"]:
			check(Decisions.LINES[id].has(key), "%s has decision cue %s" % [id, key])

func _tics() -> void:
	var memory = {}
	Dialogue.begin_conversation(memory)
	var first = Dialogue.apply_tics("isolde", "I'll tell you, truly, if only you promise.", memory)
	var second = Dialogue.apply_tics("isolde", "I'm sorry, truly—my gift hasn't shown me anything yet.", memory)
	check("truly" in first, "first 'truly' in a conversation is kept")
	check(not "truly" in second and second == "I'm sorry—my gift hasn't shown me anything yet.", "second 'truly' is removed cleanly: " + second)
	Dialogue.begin_conversation(memory)
	check("truly" in Dialogue.apply_tics("isolde", "It pains me, truly, but I agree.", memory), "a new conversation resets the cap")
	var odette = {}
	Dialogue.begin_scope(odette)
	Dialogue.apply_tics("odette", "Miraculously enough, I actually like Edda.", odette)
	check(Dialogue.apply_tics("odette", "Miraculously, Lian and I agree.", odette) == "Lian and I agree.", "Odette's second 'miraculously' goes")
	var dorian = {}
	Dialogue.begin_scope(dorian)
	var lines = ["Sorry, I can't say.", "I'd rather not, sorry.", "Um, sorry, that's not for me to say."]
	var out = lines.map(func(l): return Dialogue.apply_tics("dorian", l, dorian))
	check(out[0] == lines[0] and out[1] == lines[1] and out[2] == "Um, that's not for me to say.", "Dorian keeps two 'sorry's per scope: " + str(out))
	check(Dialogue.apply_tics("unvoiced", "truly truly truly", {}) == "truly truly truly", "unvoiced speakers are untouched")

func _decision_cues() -> void:
	var memory = {}
	var base = {"kind": "argument", "key": "k", "facts": [1], "stance": "partial", "claim": "Agnes is evil", "reason": "quality"}
	Decisions.render("edda", base, "player", memory)
	var same_stance = base.duplicate(); same_stance["reason"] = "weak"
	var r1 = Decisions.render("edda", same_stance, "player", memory)
	check(not "come round" in r1.text, "a new reason for the same stance isn't a change of mind: " + r1.text)
	var up = base.duplicate(); up["stance"] = "accept"; up["reason"] = ""
	var r2 = Decisions.render("edda", up, "player", memory)
	check(r2.text.begins_with(Decisions.LINES["edda"]["changed"]), "moving to accept uses the 'changed' opener: " + r2.text)
	var down = base.duplicate(); down["stance"] = "reject"
	var r3 = Decisions.render("edda", down, "player", memory)
	check(r3.text.begins_with(Decisions.LINES["edda"]["cooling"]), "moving toward reject uses the cooling opener: " + r3.text)
	var warm = base.duplicate(); warm["stance"] = "partial"; warm["reason"] = "source"
	var r4 = Decisions.render("edda", warm, "player", memory)
	check(r4.text.begins_with(Decisions.LINES["edda"]["warming"]), "reject to partial uses the warming opener: " + r4.text)
	var self_memory = {}
	var mine = {"kind": "argument", "key": "s", "facts": [1], "stance": "reject", "claim": "Agnes is evil", "target_id": "agnes", "special": "I don't buy it: it's about me, and I know it's false."}
	Decisions.render("agnes", mine, "player", self_memory)
	var more = mine.duplicate(); more["facts"] = [1, 2]; more["stance"] = "partial"
	var r5 = Decisions.render("agnes", more, "player", self_memory)
	check(r5.text.begins_with("I don't buy it"), "an argument about the speaker gets no opener: " + r5.text)
	check(Decisions._line("unvoiced", "partial", {"claim": "Lian is the demon"}) == "I can see a case that Lian is the demon, but I'm not convinced.", "default partial reads grammatically")

func _spoken_nights() -> void:
	check(C.spoken_night(0, 3) == "the night before you arrived", "night 0 is named")
	check(C.spoken_when(2, 3) == "last night", "yesterday's night is 'last night'")
	check(C.spoken_when(1, 3) == "the night before last", "two nights back is 'the night before last'")
	check(C.spoken_when(1, 5) == "on night 1", "older nights keep the board's number")

func _opinions() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://opinion_pass_tests"
	g.new_case(4242, 10)
	var w = g.w
	var n = w.living_good()[0]
	var t = w.npcs.filter(func(m): return m != n)[0]
	var setup = func(level: float, bond: String, honesty: float):
		n.friends.erase(t.id)
		n.rivals.erase(t.id)
		n.npc_trust[t.id] = 0.5
		if bond == "friend":
			n.friends.append(t.id)
		elif bond == "rival":
			n.rivals.append(t.id)
			n.npc_trust[t.id] = 0.25
		n.suspicion[t.id] = level
		n.honesty[t.id] = honesty
		n.dialogue_memory = {}
	setup.call(0.1, "rival", 1.0)
	var state = w.rng.state
	var reply = Mind.answer_opinion(w, n, t)
	check(w.rng.state == state, "a bonded opinion draws no extra RNG")
	check(reply.lines[0].statement.begins_with(t.name + " and I have never got on"), "rival + clear says both: " + reply.lines[0].statement)
	check(reply.lines[0].get("relationship", {}).get("kind", "") == "rival", "the rival bond is recorded as spoken")
	setup.call(0.6, "friend", 1.0)
	reply = Mind.answer_opinion(w, n, t)
	check("doubts" in reply.lines[0].statement and "friend" in reply.lines[0].statement, "friend + doubt says both: " + reply.lines[0].statement)
	check(reply.facts.size() == 1, "a bonded doubt still files the distrust fact")
	setup.call(0.1, "", 1.0)
	reply = Mind.answer_opinion(w, n, t)
	check(reply.lines[0].statement == "I don't take %s for one of the evil ones." % t.name, "a neutral clear opinion speaks to suspicion, not trust")
	check(reply.lines[0].get("relationship", {}).is_empty(), "no bond, no relationship")

## Dialogue fixes from playtest 13910 (docs/handoff_log.md, 2026-11-05 Claude-Tally).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Social = preload("res://sim/social.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const RecentSightings = preload("res://game/recent_sightings.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_owned_nights()
	_caught_out_opener()
	_ask_why_free()
	_reading_clause()
	_saw_nobody_markers()
	_public_sighting_subject()
	_own_standouts()
	_meeting_echo()
	_own_sightings_left_out()
	print("Playtest 13910 dialogue: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(seed_v: int = 13910, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, size)
	return g

func _statements(r: Dictionary) -> Array:
	return r.get("lines", []).map(func(l): return str(l.get("statement", l.get("text", ""))) if l is Dictionary else str(l))

## 1: owning a night out follows what they actually said about it.
func _owned_nights() -> void:
	for said in ["refusal", "alibi", ""]:
		var g = _game()
		var w = g.w
		var n = w.living_good()[0]
		n.role = "warden"
		n.claimed_role = "none"
		n.claim_public = false
		n.max_tier = 0
		n.lied_nights = [0]
		n.dialogue_memory["night_accounts"] = {} if said == "" else {"0": {"kind": said}}
		w.day = 2
		var st: Array = _statements(MindDialogue.answer_gift(w, n, 3))
		var joined: String = " ".join(PackedStringArray(st))
		_check(("whatever I told you" in joined) == (said == "alibi"), "owned-lie line only after a false alibi (%s): %s" % [said, joined])
		_check(("wouldn't say where I was" in joined) == (said == "refusal"), "refusal owned as a refusal (%s)" % said)
		_check(("That's the gift's work" in joined) == (said == ""), "an unasked night is just owned (%s)" % said)
		_check(n.lied_nights.is_empty(), "owned nights are cleared (%s)" % said)

## 2: pressed with a night sighting into a gift reveal, no "you doubt what I saw" opener.
func _caught_out_opener() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	n.role = "warden"
	n.claimed_role = "none"
	n.claim_public = false
	n.max_tier = 0
	n.secret = {}
	n.secret_mod = ""
	w.day = 2
	n.history[w.time_key(0, C.NIGHT)] = "night:docks"
	n.info_log.append({"role": "warden", "day": 0, "data": {"target": w.living_good()[1].id}, "text": "I stood guard", "shared": false, "true": true})
	var card = {"kind": "sighting", "phase": C.NIGHT, "day": 0, "source": "player", "subject": [n.id], "block": "docks", "text": "You saw them on the Docks."}
	var st: Array = _statements(MindDialogue.press(w, n, card))
	_check(not st.is_empty() and st[0] == "All right, you saw me. Here's why I was out.", "gift reveal under a night card opens caught out: %s" % str(st))
	var doubted: Array = Voices.VOICES.get(n.id, {}).get("doubted_visual", [])
	_check(not st.any(func(x): return x in doubted), "no doubted-visual stem before a reveal")

## 3: "ask why" with no live hint is free and says so.
func _ask_why_free() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	n.hints = {}
	var before: int = n.pressed_today
	_check(not Mind.has_live_hint(w, n), "no hint on record")
	var victim = w.living_good()[1]
	n.hints = {victim.id: {"day": 1, "src": ""}}
	w._kill(victim)
	_check(not Mind.has_live_hint(w, n), "a dead target's hint is not live")
	_check(n.pressed_today == before, "checking costs nothing")

## 6a: a reading's own time words and full stop aren't doubled by the spoken lead.
func _reading_clause() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	w.day = 2
	var e = {"day": 1, "role": "monitor", "data": {"block": "square", "walked": true, "role": "surveyor"},
		"text": "I learned that a Surveyor was abroad on the Square last night."}
	var st: String = MindMeeting._info_intent(w, n, e)["statement"]
	_check(st == "Last night, I learned that a Surveyor was abroad on the Square.", "one time phrase, one full stop: %s" % st)
	_check(MindMeeting.reading_body("on Chapel Hill I sensed 1 evil..") == "on Chapel Hill I sensed 1 evil", "reading_body strips closing punctuation")

## 6b: an alibi that already says "didn't see a soul" isn't followed by "saw nobody".
func _saw_nobody_markers() -> void:
	var jory_alibi: Array = Voices.VOICES.get("jory", {}).get("alibi", [])
	var marked: bool = jory_alibi.any(func(l): return MindDialogue.SAW_NOBODY_MARKERS.any(func(m): return m in str(l).to_lower()))
	_check(marked, "Jory's 'didn't see a soul' alibi is recognised as already answering")

## 7: a public sighting isn't delivered to the person seen.
func _public_sighting_subject() -> void:
	var g = _game()
	var w = g.w
	var goods: Array = w.living_good()
	var speaker = goods[0]
	var subject = goods[1]
	var other = goods[2]
	var fact = {"kind": "sighting", "phase": C.NIGHT, "source": speaker.id, "subject": [subject.id], "block": "market", "day": 1}
	Social.deliver_public_sighting(w, speaker, fact)
	var shares: Array = w.dlog.entries.filter(func(e): return e["type"] == "npc_share" and e["actor"] == speaker.id)
	_check(not shares.any(func(e): return e["target"] == subject.id), "no share line telling the subject about themselves")
	_check(shares.any(func(e): return e["target"] == other.id), "everyone else is told")

## 10: "my stronger suspicion" names only real standouts.
func _own_standouts() -> void:
	var g = _game()
	var w = g.w
	var me = w.living_good()[0]
	var flat := {}
	for p in w.living():
		flat[p.id] = 0.2
	_check(Presentations._own_standouts(w, me.id, flat)["demon_id"] == "", "flat suspicion names nobody")
	var others: Array = w.living().filter(func(p): return p != me)
	var sharp: Dictionary = flat.duplicate()
	sharp[others[0].id] = 0.5
	var pick: Dictionary = Presentations._own_standouts(w, me.id, sharp)
	_check(pick["demon_id"] == others[0].id and pick["accomplice_id"] == "", "a clear standout is named alone")
	sharp[others[1].id] = 0.42
	pick = Presentations._own_standouts(w, me.id, sharp)
	_check(pick["demon_id"] == others[0].id and pick["accomplice_id"] == others[1].id, "two clear standouts are named")
	_check(Presentations._own_standouts(w, me.id, sharp, [others[0].id])["demon_id"] == others[1].id, "the case's own subject is excluded")

## 15: a reason or "X is lying" already said at this meeting is pointed back to.
func _meeting_echo() -> void:
	var g = _game()
	var w = g.w
	var a = w.living_good()[0]
	var b = w.living_good()[1]
	_check(MindMeeting._said_by_other(w, b, "lying:merrin") == "", "nothing said yet")
	MindMeeting._note_said(w, a, "lying:merrin")
	_check(MindMeeting._said_by_other(w, b, "lying:merrin") == a.id, "a second speaker sees the first")
	_check(MindMeeting._said_by_other(w, a, "lying:merrin") == "", "the first speaker isn't their own echo")
	MindMeeting._note_said(w, b, "lying:merrin")
	_check(MindMeeting._said_by_other(w, b, "lying:merrin") == a.id, "the first speaker stays on record")

## 18: "ask about" leaves out sightings you made yourself.
func _own_sightings_left_out() -> void:
	var g = _game()
	var w = g.w
	var speaker = w.living_good()[0]
	var target = w.living_good()[1]
	speaker.traits["gossip"] = 1.0
	speaker.silenced = false
	w.day = 1
	w.phase = 2
	speaker.beliefs = [{"kind": "saw", "who": target.id, "loc": "", "block": "square", "day": 1, "phase": 1}]
	var mine = [{"kind": "sighting", "source": "player", "subject": [target.id], "day": 1, "phase": 1, "block": "square", "n": 1}]
	var r = {"lines": [], "facts": []}
	RecentSightings.append_to(w, speaker, target, r, mine)
	_check(r.facts.is_empty(), "your own sighting isn't repeated back")
	var r2 = {"lines": [], "facts": []}
	RecentSightings.append_to(w, speaker, target, r2, [])
	_check(not r2.facts.is_empty(), "without your card it is told")

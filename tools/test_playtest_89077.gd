## Routing fixes from playtest 89077 (docs/playtests/89077.md, Claude-Coroner): which
## answer an NPC picks. Checked here: the "with my own eyes" opener only for one's own
## sighting (finding 2), no "no premise" line after a spoken sighting (finding 6a), and
## several readings of one gift recapped as one reason (finding 3, Beadle's half).
## The recap dedupe, the sleepwalk/"reading is wrong" exclusion, the spoken sighting reaching
## the defence and the case-only reading challenge are covered by the meeting suites.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const FixtureSeeds = preload("res://tools/fixture_seeds.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_visual_opener_only_for_own_sighting()
	_no_premise_line_after_a_spoken_sighting()
	_same_gift_reasons_merge()
	_spoken_facts_reach_the_pending_nomination()
	print("Playtest 89077 routing: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(89077, 10)
	return g

func _stems(id: String) -> Array:
	return Voices.VOICES.get(id, {}).get("doubted_visual", [])

## Every voice: pressed with someone else's sighting of them, no "I made sure who I was
## looking at" opener; with their own sighting restated, the visual opener is allowed.
func _visual_opener_only_for_own_sighting() -> void:
	var g = _game()
	for n in g.w.npcs:
		var stems: Array = _stems(n.id)
		if stems.is_empty():
			continue
		for card in [{"kind": "vigil", "source": "player", "subject": [n.id], "day": 1},
				{"kind": "sighting", "source": "player", "subject": [n.id], "day": 1},
				{"kind": "sighting", "source": "someone_else", "subject": [n.id], "day": 1}]:
			n.dialogue_memory.clear()
			var resp: Dictionary = {"lines": [{"speaker": n.id, "name": n.name, "text": "I was at home last night."}]}
			Mind._challenged(n, resp, card)
			var text: String = str(resp.lines[0].get("text", ""))
			_check(not stems.any(func(st): return str(st) in text), "%s: no 'my own eyes' opener against a %s from %s (%s)" % [n.id, card.kind, card.source, text])

func _no_premise_line_after_a_spoken_sighting() -> void:
	var g = _game()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	# Nobody on record against t: the reason list is empty.
	var said: Dictionary = MindMeeting.nomination_case(w, n, t, "I saw them out in the street from my window last night")
	var statements: Array = said.lines.map(func(l): return str(l.get("statement", l.get("text", ""))) if l is Dictionary else str(l))
	_check(not statements.any(func(x): return "can't say better than that" in x or "public premise" in x), "after 'I saw them out', no 'nothing to go on' line (%s)" % str(statements))
	var bare: Dictionary = MindMeeting.nomination_case(w, n, t, "")
	_check(bare.lines.any(func(l): return l is Dictionary and ("can't say better than that" in str(l.get("statement", "")) or str(l.get("statement", "")) != "")), "with no reason at all, the 'nothing to go on' line still comes")

## Constance's three Lamplighter counts against Kiran: one reason, not three sentences.
func _same_gift_reasons_merge() -> void:
	var g = _game()
	var w = g.w
	w.day = 4
	var n = w.living_good()[0]
	var item = func(nd: int, role: String, why: String, src: String = n.id, phase: int = 3) -> Dictionary:
		var en: Dictionary = {"role": role, "day": nd, "data": {}}
		if phase != 3:
			en["phase"] = phase
		return {"eid": "info:%s:%d:%s" % [src, nd, role], "why": why, "kind": "public", "contrib": 0.1, "strength": 0.4, "entry": en}
	var items: Array = [item.call(1, "lamplighter", "my count on the first night"), item.call(2, "lamplighter", "my count on the second night"),
		item.call(3, "lamplighter", "my count last night"), {"eid": "resentment:x:y", "why": "they pushed to hang Ann", "kind": "public", "contrib": 0.05, "entry": {}}]
	var out: Array = MindMeeting._merge_gift_reasons(w, n, items)
	_check(out.size() == 2, "three counts and a resentment become two reasons (%s)" % str(out.map(func(x): return x.why)))
	_check(out[0].why == "what my gift showed me over several nights points at them", "three nights: 'over several nights' (%s)" % out[0].why)
	_check(out[0].get("whys", []).size() == 3, "the merged reason keeps the three sentences it stands for")
	var two: Array = MindMeeting._merge_gift_reasons(w, n, [item.call(1, "lamplighter", "a"), item.call(2, "lamplighter", "b")])
	_check(two.size() == 1 and two[0].why == "what my gift showed me on two nights points at them", "two counts: 'on two nights' (%s)" % str(two.map(func(x): return x.why)))
	var mixed: Array = MindMeeting._merge_gift_reasons(w, n, [item.call(1, "lamplighter", "a"), item.call(1, "seer", "b"), item.call(2, "lamplighter", "c", "someone_else")])
	_check(mixed.size() == 3, "different gifts, or another teller's reading, stay separate")
	# Only readings that were themselves reasons against the nominee fold in: a third count
	# on record (and shared) that isn't among the cited reasons leaves the nights untouched.
	n.info_log = [{"role": "lamplighter", "day": 1, "data": {}, "shared": true}, {"role": "lamplighter", "day": 2, "data": {}, "shared": true},
		{"role": "lamplighter", "day": 3, "data": {}, "shared": true}]
	var cited_two: Array = MindMeeting._merge_gift_reasons(w, n, [item.call(1, "lamplighter", "a"), item.call(2, "lamplighter", "b")])
	_check(cited_two.size() == 1 and cited_two[0].why.contains("on two nights") and cited_two[0].whys == ["a", "b"], "an uncited reading of the same gift isn't folded in (%s)" % str(cited_two.map(func(x): return x.why)))
	var day_r: Array = MindMeeting._merge_gift_reasons(w, n, [item.call(1, "dowser", "a", n.id, 1), item.call(2, "dowser", "b", n.id, 1)])
	_check(day_r.size() == 2, "daytime readings aren't merged into 'nights'")

## A nomination that cites a sighting the nominator already told the town keeps it as a
## spoken fact for the defence to answer (Codex P2 on #205: it was dropped on the way). A
## direct check of the nominator's case, since which seeds give such a nomination moves
## with the belief model; the copy onto the pending nomination is in golden (seed 900_7).
func _spoken_facts_reach_the_pending_nomination() -> void:
	var C = load("res://sim/content.gd")
	for told in [true, false]:
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(9503, 10)
		var w = g.w
		w.day = 2
		var good: Array = w.living().filter(func(p): return not p.is_evil())
		var n = good[0]
		var t = good[1]
		var block: String = t.home_block
		var b: Dictionary = {"kind": "saw", "who": t.id, "day": 1, "phase": C.NIGHT, "block": block, "how": "window"}
		n.beliefs.append(b)
		if told:
			n.told_to[MindMeeting._town_sighting_key(n, b)] = true
		var cs: Dictionary = MindMeeting.nomination_case(w, n, t, "I saw them out in the street from my window last night")
		var spoken: Array = cs.get("spoken_facts", [])
		var new_cards: Array = cs.get("facts", []).filter(func(f): return f.get("kind", "") == "sighting")
		if told:
			_check(spoken.size() == 1 and t.id in spoken[0].get("subject", []), "a sighting already told the town is kept as a spoken fact (%s)" % str(spoken))
			_check(new_cards.is_empty(), "and isn't a new card")
		else:
			_check(spoken.is_empty() and new_cards.size() == 1, "a sighting told for the first time is a new card, not a spoken fact (%d spoken, %d cards)" % [spoken.size(), new_cards.size()])

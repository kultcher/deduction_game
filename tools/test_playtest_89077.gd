## Routing fixes from playtest 89077 (docs/playtests/89077.md, Claude-Coroner): which
## answer an NPC picks. Checked here: the "with my own eyes" opener only for one's own
## sighting (finding 2), and no "no premise" line after a spoken sighting (finding 6a).
## The recap dedupe, the sleepwalk/"reading is wrong" exclusion, the spoken sighting reaching
## the defence and the case-only reading challenge are covered by the meeting suites.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Voices = preload("res://sim/dialogue_voices.gd")

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

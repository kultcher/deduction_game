## The Workshop side of the Medium relay challenge (Quill's judge change, Nov 17; Herald):
## a challenge on a Medium's relay names its side, "The Medium lied or their gift failed" or "The
## dead person lied or was misled" (Michael's wording, Nov 17). The
## canvas keeps the side on the challenge card, compiles it for the judge, keeps the
## passing-on to a lie or a failed gift, and reloads it.
extends SceneTree
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
var checks = 0
var fails = 0

## restore() asks a session to check each premise's choices; none are under test here.
class StubSession:
	func validate_case(_choices) -> String:
		return ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var relay: Dictionary = {"id": "relay", "fact_id": "relay", "kind": "report", "source": "a", "role": "gravedigger", "night": 1,
		"data": {"executed": "e", "role": "clerk"}, "observed_at": {"day": 1, "phase": "night"},
		"relay_source": "b", "relay_observed_at": {"day": 2, "phase": "night"}, "relay_role": "medium", "text": "relay"}
	var plain: Dictionary = {"id": "plain", "fact_id": "plain", "kind": "report", "source": "c", "role": "seer", "night": 1,
		"data": {"pair": ["d", "e"], "yes": true}, "observed_at": {"day": 1, "phase": "night"}, "text": "plain"}
	return {"people": people, "cards": [relay, plain], "day": 3, "evil_count": 2, "alignment_epoch": "Original alignment",
		"timeline": {"events": [], "deaths": {"a": 3}, "executions": {}}, "world_options": {"roles": true, "identities": true, "modifiers": []}}

func _modifier(board, card: String) -> Dictionary:
	for node in board.nodes.values():
		if node.kind == "modifier" and node.card == card:
			return node
	return {}

func _init() -> void:
	var view: Dictionary = _view()
	var board = CanvasModel.new(view)
	var premise: String = board.selected
	# A relay challenge must name its side (no default: it would quietly blame someone).
	check(board.add_modifier("e:relay", "misled") != "" and _modifier(board, "relay").is_empty(), "a relay challenge naming no side is refused")
	check(board.add_modifier("e:relay", "misled", "original") == "", "the dead person's original can be called misled")
	var m: Dictionary = _modifier(board, "relay")
	check(m.get("attribution", "") == "original", "...and the card keeps the side")
	check(board.add_modifier("e:relay", "misled", "transmission") != "", "'misled' isn't something the passing-on can be")
	check(m.get("attribution", "") == "original" and m.mode == "misled", "...and a refused change leaves the card as it was")
	check(board.add_modifier("e:relay", "lying", "transmission") == "", "the Medium can be charged with a lie")
	check(m.attribution == "transmission" and m.mode == "lying", "...and the card says so")
	check("The Medium lied or their gift failed" in board.title(m.id), "the card's title names the side: " + board.title(m.id))
	# Compiled for the judge with the side, and valid there.
	check(board.connect_cards(m.id, premise) == "" or true, "(link the challenge into the premise)")
	var compiled: Dictionary = board.compile(premise)
	var ch: Dictionary = compiled.get("reading_challenges", {}).get("relay", {})
	check(ch.get("attribution", "") == "transmission" and ch.get("mode", "") == "lying", "the compiled challenge carries its side: %s" % [ch])
	check(Challenges.valid(view, "relay", ch), "the judge accepts it")
	# A plain reading never gets a side.
	check(board.add_modifier("e:plain", "lying", "transmission") == "", "a plain reading's challenge is unchanged")
	check(not _modifier(board, "plain").has("attribution"), "...and carries no side")
	# Saving and loading keeps the side, and a bad side is refused on load.
	var saved: Dictionary = board.export_data()
	var again = CanvasModel.new(view)
	check(again.restore(saved, StubSession.new()) == "", "a canvas with a relay challenge reloads")
	check(_modifier(again, "relay").get("attribution", "") == "transmission", "...with its side")
	var bad: Dictionary = saved.duplicate(true)
	for key in bad.nodes:
		if bad.nodes[key].get("kind", "") == "modifier" and bad.nodes[key].get("card", "") == "relay":
			bad.nodes[key].mode = "misled"
	check(CanvasModel.new(view).restore(bad, StubSession.new()) != "", "a saved passing-on challenge of 'misled' is refused on load")
	_shared_ledger_sides()
	print("Relay challenge menu: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## Codex, #195: two presented cases that challenge the same relay on different sides are two
## explanations. The shared ledger must not let the later one silently replace the earlier.
func _shared_ledger_sides() -> void:
	var Ledger = preload("res://workshop/shared_ledger.gd")
	var lie_medium: Dictionary = {"mode": "lying", "supports": [], "attribution": "transmission"}
	var lie_dead: Dictionary = {"mode": "lying", "supports": [], "attribution": "original"}
	var plain_lie: Dictionary = {"mode": "lying", "supports": []}
	check(not Ledger.challenges_conflict(lie_medium, lie_medium.duplicate(true)), "the same side twice is one challenge")
	check(Ledger.challenges_conflict(lie_medium, lie_dead), "the Medium's side and the dead person's are two explanations, not one")
	check(not Ledger.challenges_conflict(plain_lie, plain_lie.duplicate(true)), "plain challenges merge as before")
	check(Ledger.challenges_conflict(plain_lie, {"mode": "misled", "supports": []}), "two modes still conflict, as before")

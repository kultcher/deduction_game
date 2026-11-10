## tools/vote_shape.gd: the belief-model guardrail counts, on a hand-built vote log.
extends SceneTree

const VoteShape = preload("res://tools/vote_shape.gd")

var fails = 0

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _tally(day: int, nominee: String, by: String, yes: Array, no: Array, player_yes: bool, outcome: String) -> Dictionary:
	return {"type": "vote_tally", "day": day, "data": {"nominee": nominee, "by": by, "yes": yes, "no": no, "player_yes": player_yes, "outcome": outcome}}

func _init() -> void:
	var entries: Array = [
		{"type": "nomination", "day": 1, "actor": "b", "target": "a", "data": {}},
		{"type": "nomination", "day": 1, "actor": "e", "target": "c", "data": {}},
		{"type": "nomination", "day": 2, "actor": "player", "target": "d", "data": {}},
		{"type": "nomination", "day": 2, "actor": "a", "target": "c", "data": {}},
		{"type": "nomination", "day": 2, "actor": "c", "target": "d", "data": {}},  # cancelled by clemency: no vote
		_tally(1, "a", "b", ["b", "c", "d"], ["a"], false, "on_block"),        # unanimous but the nominee; evil b on good a
		_tally(1, "c", "e", ["e"], ["a", "b", "c", "d"], false, "fails"),       # only the nominator; evil e on evil c
		_tally(2, "d", "player", [], ["a", "b", "c", "d", "e"], true, "fails"), # only the nominator (the player)
		_tally(2, "c", "a", ["a", "d"], ["b", "c", "e"], true, "fails"),        # neither
	]
	var w = {"initial_evil_ids": ["b", "c", "e"], "executions": [{"day": 1, "id": "a", "nominator": "b"}], "dlog": {"entries": entries}}
	var s: Dictionary = VoteShape.build(w)
	_check(s.votes == 4, "every vote_tally counts as a vote (%d)" % s.votes)
	_check(s.votes_unanimous == 1, "unanimous: every NPC voter but the nominee voted yes")
	_check(s.votes_only_nominator == 2, "only the nominator: an NPC's own lone yes, and the player's")
	_check(s.evil_nominations == 3 and s.evil_nominations_carried == 1 and s.evil_nominations_executed == 1, "evil nominations (a cancelled one included), carried and hanged")
	_check(s.evil_nominations_good_target == 2 and s.evil_nominations_good_target_carried == 1 and s.evil_nominations_good_target_executed == 1, "evil nominations of good targets")
	_check(VoteShape.KEYS.all(func(k): return s.has(k)), "every listed key is reported")
	print("%d checks, %d failed" % [6, fails])
	quit(1 if fails > 0 else 0)

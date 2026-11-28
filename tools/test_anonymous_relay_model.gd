## Passing on hides the source (Michael, Nov 28): the belief model's side. One relayer's unnamed
## accounts stay separate items, since they may come from different readers; and one passed on
## in private counts in full (its ledger weight carries the hearsay discount), while one told
## at the meeting stays at RELAY_WEIGHT.
##   godot --headless --path . --script res://tools/test_anonymous_relay_model.gd
extends SceneTree
const GamePresentation = preload("res://game/game_presentation.gd")
const Game = preload("res://game/game.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Connections = preload("res://workshop/connections.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	var goods: Array = g.w.living_good()
	var listener = goods[0]
	var original = goods[1]
	var teller = goods[2]
	var seen = goods[3]
	var snapshot: Dictionary = GamePresentation.workshop_snapshot(g, [], listener.id)
	# A reading passed on in private keeps its hearsay weight in the ledger and counts in full
	# here; one told at the meeting stays at RELAY_WEIGHT (Michael, Nov 28: hearsay unchanged).
	var rd: Dictionary = Shared.Evidence.normalize_card({"kind": "info", "source": original.id, "role": "surveyor", "day": 0, "phase": 3, "data": {"count": 2}, "text": "", "anonymous": true, "via": teller.id, "hearing": "private"})
	var rcard: Dictionary = Assess.testimony_card(rd, snapshot)
	check(str(rd.source) == "" and rcard.get("private_relay", false) and rcard.get("testimony_only", false) and str(rcard.source) == teller.id,
		"a privately passed-on reading is the relayer's account, marked private")
	var md: Dictionary = Shared.Evidence.normalize_card({"kind": "info", "source": original.id, "role": "surveyor", "day": 0, "phase": 3, "data": {"count": 2}, "text": "", "anonymous": true, "via": teller.id})
	check(not Assess.testimony_card(md, snapshot).get("private_relay", false), "one told at the meeting isn't")
	# Reliability: full for the private one, even when the listener doubts the relayer's own
	# gift that night; RELAY_WEIGHT for the meeting one (Codex on #599).
	var mcard: Dictionary = Assess.testimony_card(md, snapshot)
	var snap_d: Dictionary = snapshot.duplicate(true)
	snap_d.listener["source_doubt"] = {"%s:0" % teller.id: 0.9, "%s:*" % teller.id: 0.9}
	var rel: Dictionary = Assess._listener(snap_d, [rcard, mcard]).reading_reliability
	check(absf(float(rel.get(rcard.id, -1.0)) - 1.0) < 1e-9 and absf(float(rel.get(mcard.id, -1.0)) - Assess.C.RELAY_WEIGHT) < 1e-9,
		"doubt of the relayer's own gift leaves its accounts alone: private %.3f, meeting %.3f" % [float(rel.get(rcard.id, -1.0)), float(rel.get(mcard.id, -1.0))])
	# One relayer's unnamed accounts of one gift stay separate items; its own readings group.
	var people: Array = snapshot.people
	var mk = func(id: String, testimony: bool, night: int) -> Dictionary:
		var c: Dictionary = {"id": id, "fact_id": id, "kind": "report", "source": teller.id, "role": "seer", "subject": "", "data": {"pair": [original.id, seen.id], "yes": night == 1},
			"night": night, "observed_at": {"day": night, "phase": "night"}}
		if testimony:
			c["testimony_only"] = true
		return c
	var by_id: Dictionary = {"t1": mk.call("t1", true, 1), "t2": mk.call("t2", true, 2), "o1": mk.call("o1", false, 1), "o2": mk.call("o2", false, 2)}
	var it_t: Array = Connections.items(by_id, ["t1", "t2"], people, "row")
	var it_o: Array = Connections.items(by_id, ["o1", "o2"], people, "row")
	check(it_t.size() == 2 and it_t.all(func(i): return i.kind == "card"), "two unnamed accounts from one relayer are two items (%s)" % [it_t.map(func(i): return i.key)])
	check(it_o.size() == 1 and str(it_o[0].key).begins_with("teller:"), "the relayer's own readings of one gift are still judged together")
	print("Anonymous relay model: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

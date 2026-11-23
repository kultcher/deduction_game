## Top Demon candidates (workshop/demon_candidates.gd; Lantern, Nov 22, for Beadle's Seer): each
## person's chance of being the Demon given they're evil, from the listener's joint judgement
## over its held cards. A Seer's "yes" on a pair raises both of the pair; a hanged person the
## listener's own Gravedigger reading names the Poisoner sits near 0 (not at 0: its gift may
## have failed); the chances stay chances, and P(Demon) sums to 1 over the town. Synthetic
## seven-person views.
##   godot --headless --path . --script res://tools/test_demon_candidates.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Caches = preload("res://workshop/caches.gd")
const History = preload("res://workshop/live_history.gd")
const DemonCandidates = preload("res://workshop/demon_candidates.gd")

var checks: int = 0
var fails: int = 0
var ids: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _view(cards: Array, executed: String = "") -> Dictionary:
	var people: Array = []
	for i in range(7):
		people.append({"id": ids[i], "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": ids[i] != executed})
	var v: Dictionary = {"people": people, "evil_count": 2, "alignment_epoch": "Original alignment", "cards": cards,
		"world_options": {"modifiers": ["delusional", "marked", "ill_omened", "unrequited"], "roles": true, "identities": true, "bluffs": true}}
	if executed != "":
		v["timeline"] = History.from_events([{"kind": "execution", "subjects": [executed], "at": {"day": 1, "phase": "evening"}}])
	return v

func _claim(who: String, role: String) -> Dictionary:
	return {"id": "claim_" + who, "fact_id": "claim_" + who, "kind": "claim", "source": who, "subject": who, "role": role,
		"observed_at": {"day": 1, "phase": "morning"}, "text": "claims " + role}

func _reading(id: String, who: String, role: String, night: int, data: Dictionary) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "report", "role": role, "source": who, "observed_at": {"day": night, "phase": "night"},
		"reported_at": {"day": night + 1, "phase": "morning"}, "night": night, "data": data, "text": id}

func _listener(me: String, role: String, own: Array) -> Dictionary:
	return {"id": me, "knowledge": {"self": me, "good": [me], "own_role": role, "own_reports": own}}

func _of(view: Dictionary, listener: Dictionary) -> Dictionary:
	Caches.clear_all()
	return DemonCandidates.of(view, listener, view.cards.map(func(c): return c.id))

func _done() -> void:
	print("Demon candidates: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _init() -> void:
	for i in range(7):
		ids.append(C.CAST[i].id)
	var me: String = ids[0]
	var seer: String = ids[1]
	var a: String = ids[2]
	var b: String = ids[3]
	var by: String = ids[4]
	var lis: Dictionary = _listener(me, "clerk", [])

	# Before any reading: everyone else alike.
	var bare: Dictionary = _of(_view([_claim(seer, "seer")]), lis)
	check(not bare.is_empty() and not bare.has(me), "the listener gets a candidate for everyone but itself")
	if bare.is_empty():
		_done()
		return
	var total: float = 0.0
	var in_range: bool = true
	for pid in bare:
		total += float(bare[pid].demon)
		in_range = in_range and float(bare[pid].given_evil) >= 0.0 and float(bare[pid].given_evil) <= 1.0 and float(bare[pid].demon) <= float(bare[pid].evil) + 1e-9
	check(absf(total - 1.0) < 1e-6, "P(Demon) sums to 1 over the town (%.6f)" % total)
	check(in_range, "P(Demon | evil) is a chance, and P(Demon) never exceeds P(evil)")
	print("before: %s %.3f, %s %.3f (P(Demon | evil))" % [a, bare[a].given_evil, b, bare[b].given_evil])

	# A claimed Seer's "yes" on a and b raises both as the Demon, given evil.
	var yes: Dictionary = _reading("s1", seer, "seer", 1, {"pair": [a, b], "yes": true})
	var after: Dictionary = _of(_view([_claim(seer, "seer"), yes]), lis)
	print("after a \"yes\" on them: %s %.3f, %s %.3f; a bystander %s %.3f" % [a, after[a].given_evil, b, after[b].given_evil, by, after[by].given_evil])
	check(float(after[a].given_evil) > float(bare[a].given_evil) and float(after[b].given_evil) > float(bare[b].given_evil),
		"a Seer's \"yes\" on a pair raises both in P(Demon | evil)")
	check(float(after[a].given_evil) > float(after[by].given_evil), "and puts them above a bystander")

	# A hanged person the listener's own Gravedigger reading names the Poisoner: evil, not the Demon.
	var g: String = ids[6]
	var gd: Dictionary = _reading("gd1", me, "gravedigger", 1, {"executed": g, "role": "poisoner"})
	var own: Dictionary = _of(_view([gd], g), _listener(me, "gravedigger", ["gd1"]))
	print("own Gravedigger \"%s was the Poisoner\": P(evil) %.3f, P(Demon | evil) %.4f; a bystander %.3f" % [g, own[g].evil, own[g].given_evil, own[by].given_evil])
	check(float(own[g].evil) > 0.6, "the Gravedigger's own reading makes the hanged person likely evil (%.3f)" % own[g].evil)
	check(float(own[g].given_evil) < 0.1 and float(own[g].given_evil) < 0.2 * float(own[by].given_evil),
		"and they sit near 0 as the Demon, far below a bystander (%.4f against %.3f)" % [own[g].given_evil, own[by].given_evil])
	_done()

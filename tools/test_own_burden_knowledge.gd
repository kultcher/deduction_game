## A good listener knows its own burden unless it's hidden (Michael's design: only the
## Delusional is hidden from its holder; Seneschal on his behalf, Nov 21). Its worlds drop
## the burdens it knows it doesn't hold (CaseEval._own_burden_dead, view.own_burden from
## WorkshopBridge.own_burden), so a good NPC named with one other in a Seer's yes doesn't
## half-explain it as "maybe I'm Marked", and a known holder rules out every other burden.
##   godot --headless --path . --script res://tools/test_own_burden_knowledge.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Caches = preload("res://workshop/caches.gd")

var checks: int = 0
var fails: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var me: String = people[1].id
	var other: String = people[3].id
	var seer_claim = {"id": "sc", "fact_id": "sc", "kind": "claim", "source": people[4].id, "subject": people[4].id, "role": "seer",
		"observed_at": {"day": 1, "phase": "morning"}, "text": "claims Seer"}
	var seer = {"id": "bs1", "fact_id": "bs1", "kind": "report", "role": "seer", "source": people[4].id,
		"observed_at": {"day": 0, "phase": "night"}, "reported_at": {"day": 1, "phase": "morning"}, "night": 0,
		"data": {"pair": [me, other], "yes": true}, "text": "Seer yes on me and another"}
	var cards: Array = [seer_claim, seer]
	var post = func(own, type: String, who: String, mod: String = "") -> float:
		Caches.clear_all()
		var view: Dictionary = {"people": people, "evil_count": 2, "alignment_epoch": "Original alignment", "cards": cards,
			"world_options": {"modifiers": ["delusional", "marked", "ill_omened", "unrequited"], "roles": true, "identities": true, "bluffs": true}}
		if own != null:
			view["own_burden"] = {"self": me, "kind": own}
		var cs = Solver.empty_case()
		cs.conclusion = {"type": type, "target": who, "at": "Original alignment"}
		if mod != "":
			cs.conclusion["mod"] = mod
		cs.cards = cards.map(func(c): return c.id)
		var listener: Dictionary = {"id": me, "knowledge": {"self": me, "good": [me]}}
		return float(CaseEval.evaluate(view, cs, listener).posterior)
	var rows: Dictionary = {}
	for own in [null, "", "ill_omened", "marked"]:
		rows[str(own)] = [post.call(own, "evil", other), post.call(own, "marked", me), post.call(own, "secret_mod", me, "delusional")]
		print("own burden %-10s: the other evil %.4f, me Marked %.4f, me Delusional %.4f" % ["(none given)" if own == null else ("\"\"" if own == "" else own), rows[str(own)][0], rows[str(own)][1], rows[str(own)][2]])
	var old: Array = rows["<null>"]
	var none: Array = rows[""]
	var omen: Array = rows["ill_omened"]
	var marked: Array = rows["marked"]
	check(old[1] > 0.01, "without the field, the listener's own Marked chance stays open (%.3f)" % old[1])
	check(none[1] < 1e-9 and omen[1] < 1e-9, "knowing it holds nothing it would know of, or Ill-Omened, it can't be Marked (%.3f, %.3f)" % [none[1], omen[1]])
	# What it does to the other is small here: the 4 percent of worlds where "I'm Marked"
	# explained the yes go, but the rest of the Seer's yes (an evil or unhealthy Seer) dominates.
	check(absf(none[0] - old[0]) < 0.02, "the other's chance barely moves with a Seer this weakly believed (%.4f against %.4f)" % [none[0], old[0]])
	check(none[2] > 0.0, "a hidden burden stays possible: it may still be the Delusional (%.3f)" % none[2])
	check(omen[2] < 1e-9, "a known holder rules out every other burden, the hidden one too (Delusional %.3f)" % omen[2])
	check(absf(marked[1] - 1.0) < 1e-9 and marked[0] < old[0], "a known Marked holder is Marked in every world, and the yes falls less on the other (%.3f against %.3f)" % [marked[0], old[0]])
	print("Own burden knowledge: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

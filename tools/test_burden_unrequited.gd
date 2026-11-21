## Burdens prototype, stage 2: Unrequited (docs/design/burdens.md §2 and §9 items 11-14). The
## holder trusts the beloved near the maximum, visits their door on some nights (their grave
## once they're dead), holds back a reading that strongly implicates them unless it's itself
## nominated, and a confession names the love: "X admitted they have an unrequited love for Y".
extends SceneTree
const Game = preload("res://game/game.gd")
const Burdens = preload("res://sim/burdens.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var o = goods[0]
	var b = null
	for m in w.npcs:
		if m != o and m.home_block != o.home_block:
			b = m
			break
	for m in w.npcs:
		m.secret_mod = "" if m.secret_mod in ["marked", "unrequited", "ill_omened"] else m.secret_mod
		m.secret = {}
	o.secret_mod = "unrequited"
	o.beloved = b.id
	o.burden_self_known = true
	Burdens.setup_unrequited(w)
	_check(o.secret.get("kind", "") == "unrequited" and o.secret.get("dest", "") == b.home_block, "the holder's errand is the beloved's door")
	_check(o.npc_trust[b.id] >= 0.9, "and it trusts the beloved near the maximum")
	# Visits: about UNREQUITED_VISIT_CHANCE of nights, to the beloved's block.
	var visits: int = 0
	for d in range(1, 41):
		w.day = d
		o.out_last_night = false
		var v: String = Burdens.unrequited_visit(w, o)
		if v != "":
			visits += 1
			if v != b.home_block:
				_check(false, "a visit goes to the beloved's block")
	_check(visits > 8 and visits < 32, "it visits on some nights, not all (%d of 40)" % visits)
	o.out_last_night = true
	_check(Burdens.unrequited_visit(w, o) == "", "not on a night it's already out on other business")
	o.out_last_night = false
	# Withholding: a strong reading against the beloved is held back; a weak one isn't.
	var strong: Dictionary = {"role": "seer", "day": 1, "data": {"pair": [b.id, goods[2].id], "yes": true}, "text": "x", "shared": false}
	var weak: Dictionary = {"role": "dowser", "day": 1, "data": {"group": [b.id, goods[2].id, goods[3].id, goods[4].id], "count": 1}, "text": "x", "shared": false}
	var strong_held: bool = Burdens.withholds_for_beloved(w, o, strong)
	_check(strong_held == (b.id in Burdens.Gifts.implicated(strong) and Burdens.Gifts.implicated(strong).size() <= 2), "a reading naming the beloved among two is held back")
	_check(not Burdens.withholds_for_beloved(w, o, weak), "one naming them among four isn't")
	w.meeting["pending"] = {"nominee": o.id}
	_check(not Burdens.withholds_for_beloved(w, o, strong), "nominated itself, it gives the evidence up")
	w.meeting["pending"] = {}
	# The reveal's card.
	var fact: Dictionary = Burdens.with_errand(w, o, {"kind": "secret", "subject": [o.id], "owner": o.id, "source": o.id, "secret_kind": "unrequited", "text": "old"})
	_check(fact["beloved"] == b.id and fact["burden"] and fact["text"] == "%s admitted they have an unrequited love for %s." % [o.name, b.name], "a confession names the love, and carries the beloved")
	_check(fact.has("observed_at"), "and is dated")
	# The grave.
	b.alive = false
	var grave: String = ""
	for d in range(41, 61):
		w.day = d
		o.out_last_night = false
		var v2: String = Burdens.unrequited_visit(w, o)
		if v2 != "":
			grave = v2
			break
	_check(grave == "hill" and o.secret["dest"] == "hill" and "grave" in o.secret["me"], "once the beloved is dead, it visits their grave on Chapel Hill")
	_evil_bluff()
	print("Unrequited: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _evil_bluff() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var w = g.w
	w.day = 2
	if not "unrequited" in w.case_script.secrets:
		w.case_script.secrets.append("unrequited")
	for m in w.npcs:
		if m.secret_mod == "unrequited":
			m.secret_mod = ""
	var e = w.npcs.filter(func(m): return m.is_evil() and not C.is_demon(m.role))[0]
	if str(w.evil_plan["bluffs"].get(e.id, "")) == "":
		w.evil_plan["bluffs"][e.id] = "clerk"
	var other: String = ""
	for blk in C.BLOCKS.keys():
		if blk != e.home_block and blk != "hill" and not w.npcs.any(func(m): return m.alive and m != e and m.home_block == blk):
			other = blk
	if not w.evil_plan.has("burden_bluffs"):
		w.evil_plan["burden_bluffs"] = {}
	w.evil_plan["burden_bluffs"][e.id] = "unrequited"  # set on the bluff, to test the fit alone
	if other != "":
		_check(Burdens.evil_unrequited_bluff(w, e, 1, other).is_empty(), "evil never answers a sighting on a block no beloved could explain")
	var target = w.living_good().filter(func(m): return m.home_block != e.home_block)[0]
	var ub: Dictionary = Burdens.evil_unrequited_bluff(w, e, 1, target.home_block)
	_check(not ub.is_empty() and w.by_id[ub["fact"]["beloved"]].home_block == target.home_block, "a sighting on a block where someone lives: evil claims to love someone who lives there")
	_check(ub["fact"].get("secret_kind", "") == "unrequited" and "unrequited love" in str(ub["fact"].get("text", "")), "with the same card the real one gives")
	var far: String = ""
	for blk in C.BLOCKS.keys():
		if blk != target.home_block and blk != e.home_block and blk != "hill":
			far = blk
	_check(Burdens.evil_unrequited_bluff(w, e, 2, far).is_empty(), "once claimed, a sighting elsewhere doesn't fit the same beloved")
	_check(not Burdens.evil_unrequited_bluff(w, e, 2, e.home_block).is_empty(), "but one on its own block, leaving home, does")

## The caught-out ladder (Michael, Nov 19; BACKLOG "More rebuttals after a caught lie"): one
## ladder for good and evil, so the answer isn't a tell. An NPC caught out of a home alibi:
##   1. with a claimed walking gift (or evil's claimed walking bluff) tells that duty, and
##      its facts are marked as a "duty" excuse;
##   2. with an unclaimed walking gift or bluff, owns the night and keeps the gift ("Fine, I
##      was out" and the whereabouts refusal, an "admit" excuse);
##   3. pressed again, or nominated, names the gift: a good walker its own, evil its bluff;
##   4. evil with nothing to claim owns the night and says only that being out isn't wicked
##      (a "not_wicked" excuse), or offers the sleepwalk bluff.
## Each excuse fact names its owner and the night it excuses, for the judge's softening.
extends SceneTree
const Game = preload("res://game/game.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const MindPress = preload("res://sim/mind_press.gd")
const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_good_walker()
	_nominated()
	_evil_walking_bluff()
	_evil_claimed_bluff()
	_evil_nothing_to_claim()
	_disclosed_privately()
	print("Caught-out ladder: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 2
	g.w.night_walkers = []
	return g

func _quiet(n) -> void:
	n.claimed_role = ""
	n.claim_public = false
	n.max_tier = 0
	n.secret = {}
	n.secret_mod = ""
	n.lied_nights = [1]
	n.dialogue_memory["night_accounts"] = {"1": {"kind": "alibi", "home": true, "source": n.id}}

func _good(g):
	var n = g.w.living_good()[0]
	n.role = "warden"
	_quiet(n)
	n.history[g.w.time_key(1, C.NIGHT)] = "night:market"
	return n

func _evil(g, bluff: String):
	var n = g.w.minion()
	g.w.evil_plan.bluffs[n.id] = bluff
	_quiet(n)
	n.traits.privacy = 1.0
	n.trust = 0.1
	n.history[g.w.time_key(1, C.NIGHT)] = "night:market"
	return n

func _excuse(r: Dictionary, n, kind: String) -> bool:
	return r.get("facts", []).any(func(f): return f.get("excuse", "") == kind and str(f.get("source", "")) == n.id and int(f.get("excuses_night", -1)) == 1)

func _claims(r: Dictionary) -> bool:
	return r.get("facts", []).any(func(f): return f.get("kind", "") == "claim")

func _good_walker() -> void:
	var g = _game()
	var n = _good(g)
	var first: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(not _claims(first) and n.claimed_role == "" and _excuse(first, n, "admit"), "good hidden walker, first caught: owns the night, keeps the gift")
	# On the board it names no place (Lantern on #368: a blank block crashed the card text).
	var card: Dictionary = first.facts[0].duplicate(true)
	card["block"] = ""
	var names: Dictionary = {}
	for p in g.w.npcs:
		names[p.id] = p.name
	_check(CardModel.short_text(card, names).ends_with("out that night"), "the admission's card reads 'out that night' (%s)" % CardModel.short_text(card, names))
	var second: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(_claims(second) and n.claimed_role == "warden", "good hidden walker, caught again: names its gift")

func _nominated() -> void:
	var g = _game()
	var n = _good(g)
	g.w.meeting["nominated"] = [n.id]
	var r: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(_claims(r) and n.claimed_role == "warden", "nominated, the soft tier is skipped: names its gift at once")

func _evil_walking_bluff() -> void:
	var g = _game()
	var n = _evil(g, "lamplighter")
	var first: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(not _claims(first) and n.claimed_role == "" and _excuse(first, n, "admit"), "evil with a walking bluff, first caught: the same soft tier")
	var second: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(_claims(second) and n.claimed_role == "lamplighter", "evil, caught again: names its planned walking bluff")

func _evil_claimed_bluff() -> void:
	var g = _game()
	var n = _evil(g, "lamplighter")
	n.claimed_role = "lamplighter"
	n.claim_public = true
	n.max_tier = 3
	var r: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(_excuse(r, n, "duty") and r.facts.any(func(f): return f.get("duty_role", "") == "lamplighter"), "evil with a claimed walking bluff tells its duty, marked as a duty excuse")
	_check(not r.facts.any(func(f): return f.get("kind", "") == "alibi" and f.get("home", false)), "and no home alibi")

func _evil_nothing_to_claim() -> void:
	var g = _game()
	var n = _evil(g, "seer")
	_check(MindPress.trapped_explanation(g.w, n, 1).is_empty(), "evil with a non-walking bluff: nothing to explain the night with (the line stands alone)")
	# Pressed with a case that breaks the home alibi: owns the night, or the sleepwalk bluff.
	var contra: Dictionary = {"night": 1, "ruled_out_home_by": ["x"]}
	var r: Dictionary = MindPress._pressed_caught_out(g.w, n, 1, contra)
	var owned: bool = _excuse(r, n, "not_wicked")
	var sleepwalk: bool = r.get("facts", []).any(func(f): return f.get("kind", "") == "secret" and f.get("secret_kind", "") == "sleepwalker")
	_check(owned or sleepwalk, "evil caught out with nothing to claim: being out isn't wicked, or the sleepwalk bluff")
	_check(not r.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and f.get("home", false)), "it doesn't stand by the broken home alibi")

## Named privately to the player already (Codex on #368): no soft tier, the duty, for both.
func _disclosed_privately() -> void:
	var g = _game()
	var n = _good(g)
	n.claimed_role = "warden"
	n.max_tier = 3
	var r: Dictionary = MindPress.trapped_explanation(g.w, n, 1)
	_check(not _excuse(r, n, "admit") and not r.get("lines", []).is_empty(), "a good walker who told the player its gift: no soft tier")
	var g2 = _game()
	var e = _evil(g2, "lamplighter")
	e.claimed_role = "lamplighter"
	e.max_tier = 3
	var r2: Dictionary = MindPress.trapped_explanation(g2.w, e, 1)
	_check(_excuse(r2, e, "duty"), "evil that named its walking bluff privately tells its duty")
	var contra: Dictionary = {"night": 1, "ruled_out_home_by": ["x"]}
	_check(MindPress._pressed_caught_out(g2.w, e, 1, contra).is_empty(), "and pressed with a case, it's left to the duty answer, not 'being out isn't wicked'")

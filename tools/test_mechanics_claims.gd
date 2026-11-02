extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Activity = preload("res://workshop/live_activity.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var listener = g.w.living_good()[0]
	var rival = g.w.npcs.filter(func(p): return p != listener)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.beliefs = []
	listener.ledger = {}
	listener.role = "seer"
	listener.claimed_role = "seer"
	listener.claim_public = true
	Mind.hear_claim(g.w, listener, listener.id, "seer", 1.5, "own")
	Mind.hear_claim(g.w, listener, rival.id, "seer", 0.5, "public")
	var eid: String = Mind.claim_eid(rival.id, "seer")
	check(listener.workshop_state.owned.has(eid) and listener.workshop_state.owned.has(Mind.claim_eid(listener.id, "seer")), "both sides of a double claim acquire shared ownership")
	check(is_zero_approx(Mind.claim_credence(listener, rival.id, "seer")), "owned legacy claim credence is parked")
	var plan = Shared.prepare(g.workshop_snapshot([], listener.id), {}, listener.ledger)
	var claims: Array = plan.prepared.view.cards.filter(func(c): return c.kind == "claim" and c.source == rival.id)
	check(plan.ready and claims.size() == 1 and is_equal_approx(claims[0].hearing_weight, 0.5), "a public rival declaration enters once at its hearing weight")
	var before: Dictionary = listener.workshop_state.requested.duplicate(true)
	Mind.recompute_beliefs(g.w, listener, "empty-effects double-claim probe")
	check(listener.workshop_state.requested == before and listener.ledger.values().all(func(entry): return entry.effects.is_empty()), "claim ledger entries carry empty effects and stable shared requested deltas")
	var original: String = listener.ledger[eid].meta.workshop_card.id
	g.w.day += 1
	Mind.hear_claim(g.w, listener, rival.id, "seer", 0.5, "relayed")
	check(listener.ledger[eid].meta.workshop_card.id == original, "rehearing preserves the original declaration receipt")
	var card = {"kind": "claim", "source": rival.id, "subject": [rival.id], "role": "seer", "day": 1, "phase": 0, "text": "I claim the Seer."}
	Mind.press(g.w, listener, card)
	var counter: String = "own_role:" + Mind.fact_id(card)
	check(listener.workshop_state.owned.has(counter) and listener.ledger[counter].effects.is_empty(), "pressing a rival gift claim records a receipt-only own_role counter")
	var size: int = listener.ledger.size()
	Mind.press(g.w, listener, card)
	check(listener.ledger.size() == size and listener.ledger[counter].times == 2, "repeated pressing has one stable claim owner")
	g.set_workshop_effects(false)
	check(Mind.claim_credence(listener, rival.id, "seer") > 0 and not listener.workshop_state.get("active", false), "disabling shared effects retracts ownership while retaining claim eff weight")
	var report = {"id": "anonymous", "kind": "report", "source": "a", "role": "seer", "testimony_only": true}
	var view = {"cards": [report]}
	check(not Assess.conclusion_issues(view, {"cards": [report.id], "conclusion": {"type": "role", "target": "a", "role": "seer"}}).is_empty(), "an anonymous reading retold by a teller is not their gift declaration")
	var claim = {"kind": "claim", "source": "a", "role": "seer", "hearing_weight": 0.2}
	check(is_equal_approx(Activity.role_hearing([report, claim], "a", "seer"), 0.2), "anonymous reading content cannot strengthen a separate gift claim")
	print("Claim mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

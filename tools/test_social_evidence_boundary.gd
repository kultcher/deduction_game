## The crowd can influence action without supplying alignment evidence.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Live = preload("res://game/workshop_canvas.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = true
	g.new_case(7101, 7)
	var w = g.w
	var listener = w.living_good()[0]
	var target = w.npcs.filter(func(n): return n != listener)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.cleared = {}
	listener.role = "surveyor"
	listener.traits.confidence = 0.5
	w.day = 3
	w.meeting = {"block": "", "nominated": []}
	for id in listener.suspicion:
		listener.suspicion[id] = 0.1
	listener.suspicion[target.id] = 0.45
	var before = JSON.stringify([listener.suspicion, listener.ledger, listener.honesty, listener.discounted, listener.npc_trust, listener.trust, w.rng.state])
	for accuser in w.npcs:
		if accuser != listener and accuser != target:
			w.stances[accuser.id] = {"target": target.id, "day": w.day}
	Mind.refresh_consensus(w, listener, target.id)
	var pressure: float = listener.consensus_pressure[target.id]
	check(pressure > 0.1 and pressure <= Mind.CONSENSUS_CAP, "existing chorus weights and cap remain social pressure")
	check(before == JSON.stringify([listener.suspicion, listener.ledger, listener.honesty, listener.discounted, listener.npc_trust, listener.trust, w.rng.state]), "accusations change no evidence, credibility, trust or randomness")
	var pressured_vote: bool = Mind.vote(w, listener, target.id, "player", false, "", 0)
	var nomination = Mind._good_nomination(w, listener, w.meeting, "")
	listener.consensus_pressure[target.id] = 0.0
	listener.suspicion[target.id] += pressure
	var old_vote: bool = Mind.vote(w, listener, target.id, "player", false, "", 0)
	var old_nomination = Mind._good_nomination(w, listener, w.meeting, "")
	check(pressured_vote == old_vote, "the vote keeps the old score when the same crowd weight is moved out of suspicion")
	check(nomination != null and old_nomination != null and nomination.nominee == old_nomination.nominee and is_equal_approx(nomination.score, old_nomination.score), "nomination ranking, thresholds and score retain the existing crowd weight")
	listener.suspicion[target.id] -= pressure
	listener.consensus_pressure[target.id] = pressure
	var evaluations = w.dlog.trace_events().filter(func(e): return e.type == "decision" and e.data.kind == "vote" and e.data.stage == "evaluation" and e.actor == listener.id)
	check(evaluations.size() == 2 and is_equal_approx(evaluations[0].data.details.score, evaluations[1].data.details.score), "trace scores verify exact action equivalence")
	check(evaluations[0].data.details.parts.town_pressure > 0 and evaluations[1].data.details.parts.town_pressure == 0, "vote explanations distinguish evidence from social pressure")
	listener.suspicion[target.id] = -0.4
	listener.consensus_pressure[target.id] = 0.2
	check(Mind.susp(listener, target.id) == 0 and Mind.action_susp(listener, target.id) == 0, "action clamping uses the raw evidence sum before adding pressure")
	w.stances.clear()
	Mind.refresh_all_consensus(w)
	check(listener.consensus_pressure.get(target.id, 0.0) == 0, "withdrawing the final stance clears the social pressure")
	_opinions()
	print("Social evidence boundary: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _opinions() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(7101, 7)
	var listener = g.w.living_good()[0]
	var others = g.w.npcs.filter(func(n): return n != listener)
	var source = others[0]
	var target = others[1]
	var subject = others[2]
	var before = JSON.stringify([listener.suspicion, listener.ledger, listener.honesty, listener.discounted])
	var trust: float = listener.npc_trust.get(source.id, 0.5)
	var count: int = listener.hearsay.size()
	Social._deliver(g.w, source, listener, {"kind": "opinion", "about": target.id, "from": source.id, "key": "opinion:" + target.id})
	check(before == JSON.stringify([listener.suspicion, listener.ledger, listener.honesty, listener.discounted]), "private opinion gossip adds no evidence effect or credibility penalty")
	check(listener.hearsay.size() == count + 1 and is_equal_approx(listener.npc_trust[source.id], minf(1.0, trust + 0.02)), "opinion gossip retains its social conversation and teller bond")
	listener.suspicion[target.id] = 0.9
	listener.suspicion[subject.id] = 0.9
	var psychology = {"role": "psychologist", "day": 1, "data": {"subject": subject.id, "trusts": target.id, "suspects": source.id}}
	check(Mind._info_effects(g.w, listener, source, psychology, 1.0, false).is_empty(), "learning who trusts whom does not create guilt by association")
	check(Mind.card_strength(g.w, psychology, target) == 0 and Mind.defend_strength(psychology, target.id) == 0, "native compatibility paths do not turn social readings into accusation or defence evidence")
	var relay = {"role": "medium", "day": 1, "data": {"dead": subject.id, "item": {"type": "suspicion", "about": target.id}}}
	check(Mind._info_effects(g.w, listener, source, relay, 1.0, false).is_empty(), "a dead person's opinion has no native alignment effect")
	var number = g.add_card({"kind": "info", "source": source.id, "role": "medium", "day": 1, "data": relay.data, "text": "The deceased distrusted them"})
	var value = preload("res://workshop/solver.gd").empty_case()
	value.cards = [Live.Evidence.normalize_card(g.board[number - 1]).id]
	value.conclusion = {"type": "evil", "target": target.id, "at": "Original alignment"}
	var prepared = Live.Assess.prepare(Live.snapshot(g, value, listener.id))
	check(not prepared.ready and prepared.issues.any(func(issue): return "opinion is not evidence" in issue), "a presented Medium opinion receives an explicit semantic rejection")
	check("opinion is not evidence" in g._presentation_rejection(g.board[number - 1]), "ordinary play rejects a Medium opinion before choosing a fallback engine")
	var wrapper = g.add_card({"kind": "deduction", "conclusion": {"type": "evil", "a": target.id}, "supports": [number], "text": "A wrapper around an opinion"})
	check("opinion is not evidence" in g._presentation_rejection(g.board[wrapper - 1]), "a deduction wrapper cannot turn a relayed opinion into evidence")
	var nested = g.board[number - 1].duplicate(true)
	nested.data.item = {"type": "reading", "entry": {"role": "medium", "day": 1, "data": relay.data}}
	check("opinion is not evidence" in g._presentation_rejection(nested), "nesting the Medium transmission does not hide the original opinion")
	check(Mind.card_strength(g.w, nested, target) == 0 and Mind.defend_strength(nested, target.id) == 0, "native compatibility paths assign no accusation or defence weight to the same opinion")
	check(Mind.Gifts.implicated(g.board[number - 1]).is_empty(), "the common gift summary does not identify an opinion as implicating its target")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)

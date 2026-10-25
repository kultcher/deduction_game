## Channel integration semantics, independent of bot balance or vote thresholds.
extends SceneTree
const Eval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Session = preload("res://workshop/session.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d"]:
		people.append({"id": id, "name": id, "home": "square"})
	var at = {"day": 1, "phase": "night"}
	var view = {"people": people, "evil_count": 1, "alignment_epoch": "Original alignment", "live_activity": true,
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional"]}, "cards": []}
	var listener = Session.new(692).baseline[0].duplicate(true)
	listener.id = "d"
	listener.name = "d"
	listener.knowledge = {"self": "d", "own_role": "warden", "good": ["d"], "own_reports": [], "own_outings": {}}
	listener.suspicion = {"a": 0.2, "b": 0.2, "c": 0.2, "d": 0.0}
	listener.npc_trust = {"a": 0.5, "b": 0.5, "c": 0.5, "d": 1.0}
	listener.reading_reliability = {}
	listener.channel_doubt = {}
	listener.channel_hearing = {}
	listener.confidence_mode = "scale"
	listener.reasoning_mode = "full"
	listener.trust = 0.5
	var bluff = {"id": "bluff", "kind": "claim", "source": "a", "role": "warden", "observed_at": at, "data": {}}
	var alibi = {"id": "alibi", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": 1, "block": "", "observed_at": at}
	var seen = {"id": "seen", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": "square", "observed_at": at}
	var report = {"id": "dowse", "kind": "report", "source": "b", "role": "dowser", "night": -1, "observed_at": {"day": 2, "phase": "morning"}, "data": {"group": ["a", "c"], "count": 1}}
	view.cards = [bluff, alibi, seen, report]
	var value = Solver.empty_case()
	value.cards = [bluff.id]
	value.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	var role_lie = Eval.evaluate(view, value, listener)
	check(not role_lie.impossible and role_lie.model == "source_channels" and role_lie.people.a.posterior > role_lie.people.a.prior, "a bluff of the listener's unique gift is explainable and raises suspicion of its source")
	check(role_lie.acceptance.bluff == 0.0 and role_lie.channel_peak_rows < 128, "the rejected identity remains a heard statement, with zero accepted-content mass")
	value.cards = [alibi.id, seen.id]
	var whereabouts = Eval.evaluate(view, value, listener)
	check(not whereabouts.impossible and whereabouts.acceptance.alibi == 0.0 and whereabouts.people.a.posterior > whereabouts.people.a.prior, "a physically refuted alibi selects testimony dishonesty and increases suspicion without invalidating the refresh")
	value.cards.append(report.id)
	var plus_report = Eval.evaluate(view, value, listener)
	check(not plus_report.impossible and plus_report.acceptance.dowse > 0.0, "a caught liar cannot erase an independent source's evidence")
	var known_good = listener.duplicate(true)
	known_good.knowledge.good.append("a")
	value.cards = [bluff.id, report.id]
	var innocent_liar = Eval.evaluate(view, value, known_good)
	check(not innocent_liar.impossible and innocent_liar.people.a.posterior == 0.0 and innocent_liar.acceptance.bluff == 0.0, "a known good source can lie about a gift without losing separate good knowledge")
	var own_alibi = alibi.duplicate(true)
	own_alibi.id = "own-alibi"
	own_alibi.source = "d"
	own_alibi.subject = "d"
	own_alibi.subjects = ["d"]
	view.cards.append(own_alibi)
	listener.knowledge.own_outings["1"] = true
	value.cards = [own_alibi.id]
	var own_lie = Eval.evaluate(view, value, listener)
	check(not own_lie.impossible and own_lie.acceptance[own_alibi.id] == 0.0, "one's own public cover story cannot contradict firsthand movement and void the whole model")
	listener.knowledge.own_outings = {}
	listener.channel_hearing[report.id] = 0.25
	var inputs = Eval._channel_inputs(view, [report], listener)
	check(is_equal_approx(inputs.rates["transmission:dowse"], 0.25) and is_equal_approx(inputs.rates["gift_accuracy:b:1"].healthy, 1.0 - Eval.DEFAULT_ERR), "weak hearing discounts only that route, not the source's whole poison window")
	listener.channel_hearing = {}
	value.cards = [bluff.id]
	var refresh = Jury.refresh(view, value, listener.duplicate(true))
	var reply = Jury.evaluate(view, value, listener.duplicate(true), {"headline_only": true})
	check(not refresh.reasoning.impossible and not refresh.reasoning.has("contradiction") and refresh.effects.a.applied > 0.0, "the live refresh uses channels without a source-dropping retry")
	check(is_equal_approx(reply.agreement, Eval.shift(reply.case_eval.prior, reply.case_eval.posterior)) and reply.suspicion_delta > 0.0, "spoken agreement and applied belief derive from the same correlated evidence shift")
	print("Live source channels: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)

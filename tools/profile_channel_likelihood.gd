## Exact channel-kernel reference cost on publicly stated native readings. This
## does not measure a live presentation: production still uses CaseEval's kernel.
extends SceneTree
const Game = preload("res://game/game.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Channels = preload("res://workshop/evidence_channels.gd")
const Likelihood = preload("res://workshop/channel_likelihood.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")

func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var count = int(args[args.find("--npcs") + 1]) if "--npcs" in args else 10
	var sources = int(args[args.find("--sources") + 1]) if "--sources" in args else 2
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, count)
	g.w._day_gifts()
	var numbers: Array = []
	var chosen = {}
	for n in g.w.npcs:
		for reading in n.info_log:
			if reading.role not in Assess.ROLES or reading.role == "psychologist" or not chosen.has(n.id) and chosen.size() >= sources:
				continue
			chosen[n.id] = true
			numbers.append(g.add_card({"kind": "info", "source": n.id, "role": reading.role,
				"day": reading.day, "phase": reading.get("phase", 3 if reading.day == 0 else 0), "data": reading.data, "text": reading.text}))
	var observer = g.w.living_good().back()
	var number = g.file_deduction({"type": "evil", "a": g.w.npcs[0].id}, numbers)
	var prepared = Assess.prepare(g.workshop_snapshot([number], observer.id))
	if not prepared.ready:
		push_error("FAIL: " + str(prepared.issues))
		quit(1)
		return
	prepared.view.world_options.roles = true
	var cards: Array = Solver.selected(prepared.view, prepared.case)
	var plan = Channels.compile(prepared.view, cards)
	var rates = {}
	var q = {}
	for channel in plan.channels:
		rates[channel.key] = {"healthy": 0.99, "impaired": 0.0} if channel.kind == "gift_accuracy" else (1.0 if channel.source == observer.id else 0.8)
	for card in cards:
		q[card.get("accuracy_origin", card.get("fact_id", card.id))] = Eval.chance_content(prepared.view, card) if card.kind == "report" else 0.5
	var rng = g.w.rng.state
	var cc: Dictionary = Eval.compile(prepared.view, cards, prepared.case) if "--classes" in args else {}
	var start = Time.get_ticks_usec()
	var result = Likelihood.assess(prepared.view, cards, prepared.listener.knowledge, rates, q, [], true,
		cc.get("rep", PackedInt32Array()), cc.get("count", PackedFloat64Array()))
	var elapsed = Time.get_ticks_usec() - start
	var total = 0.0
	for slot in range(result.post.size()):
		total += result.post[slot] * (1.0 if cc.is_empty() else cc.count[slot])
	print(JSON.stringify({"npcs": count, "sources": chosen.size(), "cards": cards.size(), "channels": plan.channels.size(),
		"states": result.states, "worlds": Solver.universe(prepared.view).size(), "evaluated_classes": result.post.size(), "elapsed_ms": elapsed / 1000.0, "likelihood_mass": total, "issues": result.issues,
		"rng_unchanged": rng == g.w.rng.state}))
	quit(0 if result.issues.is_empty() and total > 0.0 and rng == g.w.rng.state else 1)

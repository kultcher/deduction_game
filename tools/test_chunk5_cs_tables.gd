## Monitor & Confessor (patch_014): the C# report table the game uses agrees, world by world,
## with the content rule in Solver._report_content / _testimony_content (sampled worlds of a
## live 10-person view; every card shape, chip answers, plain and testimony-only cards).
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
func _init():
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	g.w.day = 3
	var obs = g.w.living_good()[0]
	var prepared = Live.Assess.prepare(g.workshop_snapshot([], obs.id))
	var view: Dictionary = prepared.view
	var ids: Array = view.people.map(func(p): return p.id)
	var src: String = ids[1]
	var cards: Array = []
	for blk in ["square", "docks", "nowhere"]:
		for walked in [false, true]:
			for r in ["", "poisoner", "demon", "seer"]:
				var d = {"block": blk, "walked": walked}
				if r != "": d["role"] = r
				cards.append({"role": "monitor", "data": d})
	for t in ids:
		cards.append({"role": "confessor", "data": {"target": t, "good": true}})
	cards.append({"role": "confessor", "data": {"forgot": true}})
	cards.append({"role": "confessor", "data": {}})
	var answers: Array = [[]]
	for p in ids.slice(0, 5): answers.append([p])
	answers.append([ids[2], ids[5]])
	answers.append(["nobody"])
	var universe: Array = Solver.universe(view)
	var checked = 0
	var bad = 0
	for k in range(cards.size()):
		for testimony in [false, true]:
			var card: Dictionary = {"kind": "report", "quoted": false}
			card["id"] = "mc:%d:%s" % [k, testimony]
			card["role"] = cards[k].role
			card["data"] = cards[k].data
			card["source"] = src
			card["observed_at"] = {"day": 2, "phase": "night"}
			card["night"] = 2
			if testimony:
				card["testimony_only"] = true
				card["reported_at"] = {"day": 3, "phase": "evening"}
			for ans in (answers if not testimony else [[]]):
				var table: PackedByteArray = Solver.report_table(view, card, ans)
				var valid: PackedByteArray = Solver.valid_table(view, card)
				for i in range(0, universe.size(), 37):
					var want: bool
					if testimony:
						want = Solver.source_valid(view, universe[i], card) and Solver._testimony_content(view, universe[i], card)
					else:
						want = valid[i] != 0 and Solver._report_content(view, universe[i], card, {"positive": ans})
					checked += 1
					if (table[i] != 0) != want:
						bad += 1
						if bad <= 5:
							print("MISMATCH card=", JSON.stringify(card.data), " role=", card.role, " testimony=", testimony, " ans=", ans, " world=", JSON.stringify(universe[i]), " cs=", table[i], " gd=", want)
	print("Chunk 5 C# tables: %d checks, %d mismatches" % [checked, bad])
	if bad > 0:
		push_error("FAIL: C# Monitor/Confessor report tables disagree with the content rule")
	quit(1 if bad > 0 or checked == 0 else 0)

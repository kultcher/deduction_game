## Oct 30 experiment: run a seed to a day with the current prior, then evaluate every good
## reading holder's own-evidence beliefs under prior_k (-1 = current). Args after --: seed k day out.json
## Aggregate with: python3 tools/probe_prior_aggregate.py <dir of r_*.json>
extends SceneTree
const Game = preload("res://game/game.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
func _init():
	var a = OS.get_cmdline_user_args()
	var sd = int(a[0]); var k = float(a[1]); var day = int(a[2]); var outp = a[3]
	var g = Game.new()
	g.log_dir = "user://prior_logs"
	g.new_case(sd, 10)
	var steps = 0
	while g.w.day < day and g.state != "over" and steps < 300:
		steps += 1
		match g.state:
			"meeting":
				g.command("wait")
				while g.meeting_streaming():
					g.testimony_step()
				g.command("done")
			"nomination":
				g.command("vote no")
			"talk":
				g.command("bye")
			"approach":
				g.command("no")
			"night":
				g.command("sleep")
			_:
				g.command("wait")
	CaseEval.prior_k = k
	var rows = []
	for n in g.w.npcs:
		if not n.alive or n.is_evil() or n.info_log.is_empty() or n.workshop_state.is_empty():
			continue
		var st = n.workshop_state
		var outside: Dictionary = st.get("outside", n.suspicion).duplicate(true)
		var input = Bridge.capture(g, [], n.id, "private", n)
		input.listener.suspicion = outside.duplicate(true)
		var plan = Shared.prepare(input, st.get("presentations", {}), n.ledger, st.get("withdrawn", {}), st.get("attention_focus", []))
		if not plan.ready:
			continue
		var prop = Shared.evaluate(plan, outside, n.discounted)
		var people = {}
		for id in prop.effects:
			if id == n.id or not g.w.by_id.has(id):
				continue
			var e = prop.effects[id]
			people[id] = {"prior": e.prior, "post": e.posterior, "evil": g.w.by_id[id].is_evil(), "demon": id == g.w.demon_id, "susp": outside.get(id, 0.0)}
		var readings = []
		for r in n.info_log:
			readings.append({"text": r.get("text", ""), "true": r.get("true", true)})
		rows.append({"seed": sd, "k": k, "day": g.w.day, "holder": n.name, "role": n.role, "readings": readings, "people": people})
	var f = FileAccess.open(outp, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	quit()

## A "taken together" reason's weight follows what its card moved (playtest 89077, Coroner's
## note 3). The leave-one-out behind those reasons (ReasonAttribution, part B) measured each
## removal against the belief's own shift, which comes from the connections model, while the
## "without" side came from the attribution's own whole-case model. Any gap between the two
## models was credited to every card tested: Constance's three Lamplighter counts, which moved
## her suspicion of Kiran by under 0.005 each, were each cited as a strong reason (0.23). Now
## a removal is measured within one model: since Nov 18 the belief model itself (the
## connections refresh that formed the belief, ReasonAttribution._connections_drop), which
## also credits a card the attribution's own model under-reads (test_meeting_flow: Hollis's
## private Gravedigger reading against Odette, 0.50 -> 0.81 through the core); the
## attribution's model only where those inputs are missing (ReasonAttribution.same_model_loo).
## Games played here (7 NPCs, to the day-3 meeting), on playtest 89077's
## script. For each mind with a "taken together" reason, the reason's weight implies a drop
## (weight / 0.45, before the belief scale); what the same model says removing its card does
## must be at least half of that, less a small allowance. On the earlier measurement 6 of the
## first 11 such reasons fail.
##   godot --headless --path . --script res://tools/test_joint_reasons.gd
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const CaseEval = preload("res://workshop/case_eval.gd")

const ALLOW: float = 0.08
const MINDS: int = 6
const SEEDS_TRIED: int = 20
const Connections = preload("res://workshop/connections.gd")
const Game = preload("res://game/game.gd")
const ScriptDef = preload("res://sim/script_def.gd")
## Playtest 89077's script, as recorded. Its Muddler is dropped on load (ScriptDef.RETIRED_IDS, Nov 20).
const SCRIPT: Dictionary = {"demons": ["demon"], "forced": [], "minions": ["breathstealer", "poisoner", "revenant", "scion"], "name": "Dynamic #89077",
	"secrets": ["delusional", "marked", "muddler", "sleepwalker"], "town": ["archivist", "clerk", "gravedigger", "lamplighter", "magistrate", "medium",
	"nightwatch", "psychologist", "registrar", "rumormonger", "seer", "sexton", "surveyor", "veteran", "warden"]}

var checks := 0
var fails := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		print("FAIL: " + label)
		fails += 1

## [{key, inputs, joint: [[suspect, reason]]}] for the minds at this meeting with "taken
## together" reasons.
func _joint_minds(g) -> Array:
	var out: Array = []
	for p in g.w.living():
		var m = p.shadow if p.is_evil() and p.shadow != null else p
		var key: String = p.id + (":cover" if m != p else ":good")
		var ins: Array = g._workshop_reason_ctx.get(key, {}).get("rctx", {}).get("inputs", [])
		if ins.size() < 9 or not g.w.workshop_reasons.is_valid():
			continue
		m.workshop_state["reasons_pending"] = true
		g.w.workshop_reasons.call(m)
		var joint: Array = []
		for pid in m.workshop_state.get("reasons", {}):
			for r in m.workshop_state.reasons[pid]:
				if str(r.get("channel", "")) == "joint_contradiction" and r.get("root_ids", []).size() >= 1 and str(r.get("card_id", "")) != "":
					joint.append([pid, r])
		if not joint.is_empty():
			out.append({"key": key, "inputs": ins, "joint": joint})
	return out

## Seeds.play_to_meeting on SCRIPT.
func _play(seed_v: int, day: int, npcs: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, npcs, ScriptDef.from_dict(SCRIPT))
	var guard := 0
	while g.state != "over" and guard < 600 and not (g.state == "meeting" and g.w.day >= day):
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	return g if g.state == "meeting" and g.w.day >= day else null

func _init() -> void:
	var seen := 0
	var cited := 0
	# Played as in play.
	var seed_v: int = Seeds.SEEDS_FROM
	while seen < MINDS and seed_v < Seeds.SEEDS_FROM + SEEDS_TRIED:
		var g = _play(seed_v, 3, 7)
		seed_v += 1
		if g == null:
			continue
		var minds: Array = _joint_minds(g)
		if minds.is_empty():
			continue
		var found: Dictionary = {"seed": seed_v - 1, "minds": minds}
		for mi in found.minds:
			if seen >= MINDS:
				break
			seen += 1
			var ins: Array = mi.inputs
			var view: Dictionary = ins[0]
			var attended: Array = ins[2]
			var base_case: Dictionary = ins[1].duplicate(true)
			base_case["cards"] = attended.map(func(c): return str(c.id))
			var full: Dictionary = CaseEval.evaluate(view, base_case, ins[6])
			for pr in mi.joint:
				var pid: String = pr[0]
				var r: Dictionary = pr[1]
				var cid: String = str(r.card_id)
				if not attended.any(func(c): return str(c.id) == cid):
					continue
				cited += 1
				var p_full: float
				var p_wo: float
				var p0: float = float(full.get("people", {}).get(pid, {}).get("prior", 0.5))
				var cx: Dictionary = ins[9] if ins.size() >= 10 else {}
				if not cx.is_empty() and cid in cx.get("held", []):
					# The belief model itself, as the attribution measures it (Nov 18).
					p_full = float(cx.result.posterior.get(pid, 0.0))
					p_wo = float(Connections.refresh(cx.view, cx.value, cx.weigher, cx.held.filter(func(id): return id != cid), cx.state).posterior.get(pid, 0.0))
				else:
					var wo_case: Dictionary = base_case.duplicate(true)
					wo_case["cards"] = attended.filter(func(c): return str(c.id) != cid).map(func(c): return str(c.id))
					var wo: Dictionary = CaseEval.evaluate(view, wo_case, ins[6])
					p_full = float(full.get("people", {}).get(pid, {}).get("posterior", 0.0))
					p_wo = float(wo.get("people", {}).get(pid, {}).get("posterior", 0.0))
				var drop: float = CaseEval.shift(p0, p_full) - CaseEval.shift(p0, p_wo)
				var contrib: float = float(r.get("contrib", 0.0))
				check(drop >= 0.5 * contrib / 0.45 - ALLOW, "seed %d, %s: a reason against %s at %.2f, and removing its card moves them %.3f (%.3f without, %.3f with): \"%s\"" % [int(found.seed), mi.key, pid, contrib, drop, p_wo, p_full, str(r.get("why_own", ""))])
	print("%d minds with \"taken together\" reasons, %d reasons checked" % [seen, cited])
	check(seen >= MINDS and cited > 0, "found %d minds with \"taken together\" reasons to check (wanted %d)" % [seen, MINDS])
	print("Joint reasons: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## Reproduce the controlled worked example in TUNING_NARRATIVE.md.
## godot --headless --path . --script res://tools/explain_ledger.gd
## Uses production card filing, meeting presentation, evaluation and ledger updates.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const NPC = preload("res://sim/npc.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const C = preload("res://sim/content.gd")

const PROFILES = [
	["a", "Open listener", 0.8, 0.5, 0.2, 0.2, 0.2],
	["b", "Loyal skeptic", 0.5, 0.8, 0.8, 0.5, 0.2],
	["c", "Distrustful analyst", 0.2, 0.5, 0.5, 0.8, 0.5],
	["d", "Convinced rival", 0.5, 0.2, 0.8, 0.8, 0.8],
]

var failures = 0
var checks = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _person(id: String, label: String):
	var n = NPC.new()
	n.id = id
	n.name = label
	n.role = "clerk"
	n.home_block = "market"
	n.work = "bakery"
	n.traits = {"privacy": 0.5, "gossip": 0.5, "confidence": 0.5, "insight": 0.5, "composure": 0.5}
	return n

func _fixture():
	var g = Game.new()
	g.w = World.new()
	g.w.rng.seed = 4242
	g.w.day = 2
	g.w.phase = C.EVENING
	g.w.dlog.configure_trace(true)
	g.w.set_log_time()
	var greta = _person("greta", "Greta")
	g.w.npcs.append(greta)
	g.w.by_id[greta.id] = greta
	for p in PROFILES:
		var n = _person(p[0], p[1])
		n.trust = p[2]
		n.trust_at_reconsider = n.trust
		n.npc_trust["greta"] = p[3]
		n.traits["confidence"] = p[4]
		n.traits["insight"] = p[5]
		n.suspicion["greta"] = p[6]
		g.w.npcs.append(n)
		g.w.by_id[n.id] = n
	g.w.scenes["scene"] = {"day": 1, "block": "market"}
	g.add_card({"kind": "sighting", "subject": ["greta"], "block": "market", "day": 1,
		"phase": C.NIGHT, "source": "player", "vigil": true, "text": "Your night-1 vigil saw Greta on Market."})
	g.add_card({"kind": "trace", "subject": [], "block": "market", "day": 1,
		"phase": C.EVENING, "source": "evidence", "text": "The death-scene trace points to Market on evening 1."})
	g.add_card({"kind": "sighting", "subject": ["greta"], "block": "market", "day": 1,
		"phase": C.EVENING, "source": "player", "text": "You saw Greta on Market on evening 1."})
	g.add_card({"kind": "home", "subject": ["greta"], "block": "market", "source": "town",
		"class": "concrete", "text": "Greta lives on Market."})
	return g

func _init() -> void:
	for templated in [true, false]:
		var g = _fixture()
		var supports: Array = [1, 2, 3] if templated else [1, 2]
		var dn = g.file_deduction({"type": "demon", "a": "greta"}, supports)
		_check(dn > 0, "filing succeeds")
		var ded: Dictionary = g.board[dn - 1]
		_check(ded["template"] == ("trace_match" if templated else ""), "expected template")
		_check(not ded["unfounded"], "both versions bear on Greta")
		_check(ded["class"] == "circumstantial", "trace keeps both deductions circumstantial")
		var snapshots = {}
		for p in PROFILES:
			var n = g.w.by_id[p[0]]
			snapshots[n.id] = {"suspicion": n.suspicion["greta"], "trust": n.trust}
		# Real whole-meeting route: handles confidentiality, scale .6 and all listeners.
		g._present_deduction(str(dn))
		for p in PROFILES:
			var n = g.w.by_id[p[0]]
			var eval = {}
			var contest = {}
			for event in g.w.dlog.trace_events():
				if event["actor"] != n.id or event["type"] != "decision":
					continue
				var d: Dictionary = event["data"]
				if d["kind"] == "argument" and d["stage"] == "evaluation":
					eval = d["details"]
				if d["kind"] == "argument" and d["stage"] == "contest":
					contest = d["details"]
			var eid = "arg:" + Argue.conclusion_key(ded["conclusion"])
			var e: Dictionary = n.ledger[eid]
			var old: Dictionary = snapshots[n.id]
			var expected_delta: float = 0.55 * (1.4 - 0.8 * p[4]) * eval["nominal_weight"]
			_check(is_equal_approx(n.suspicion["greta"] - old["suspicion"], expected_delta), "production delta matches pipeline")
			_check(is_equal_approx(e["eff"], eval["nominal_weight"]), "physical/player supports retain full live reliability")
			_check(is_equal_approx(n.trust - old["trust"], 0.02 if eval["agreement"] >= 0.6 and eval["stored_weight_gain"] >= 0.1 else 0.0), "sound-argument trust gate")
			print("LEDGER " + JSON.stringify({"version": "templated" if templated else "generic", "listener": n.name,
				"template": ded["template"], "route": eval["route"], "agreement": eval["agreement"],
				"contest": contest, "quality": eval["quality"], "novelty": eval["novelty"],
				"base": eval["base"], "stored_weight": e["weight"], "effective_weight": e["eff"],
				"support_refs": e["justs"][0]["supports"], "suspicion_before": old["suspicion"],
				"suspicion_after": n.suspicion["greta"], "delta": n.suspicion["greta"] - old["suspicion"],
				"trust_before": old["trust"], "trust_after": n.trust, "honesty_greta": n.honesty.get("greta", 1.0)}))
		# Home knowledge does not replace evidence of evening presence. Nor do all three
		# originally suggested cards form a Demon template without the evening sighting.
		var home_dn = g.file_deduction({"type": "demon", "a": "greta"}, [1, 2, 4])
		_check(g.board[home_dn - 1]["template"] == "", "vigil + trace + home is not a Demon template")
		var home_pair = g.file_deduction({"type": "demon", "a": "greta"}, [2, 4])
		_check(g.board[home_pair - 1]["template"] == "", "trace + home does not prove evening presence")
	print("Ledger example: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)

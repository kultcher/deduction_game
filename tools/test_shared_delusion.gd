## One shared Delusion doubt per reader (Michael, Nov 22; Lantern's pitch with Quill). A good
## listener's chance of being the Delusional is one hypothesis for all its readings: its worlds
## as the world's Delusional holder, weighted to Tuning.Workshop.OWN_DELUSION_PRIOR before any
## evidence (CaseEval._own_counts; CaseEvalKernel.OwnDelusionWeight), in which its readings say
## anything (the role check skips their content; CaseEval prices them at the gift's draw). So
## readings that agree lower it for every night at once, and clashes raise it, night on night.
## Another reader keeps the deal's share. A burden the listener knows it holds rules it out.
## Synthetic seven-person views with no Poisoner on the script, so these are the Delusion alone.
##   godot --headless --path . --script res://tools/test_shared_delusion.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Classes = preload("res://workshop/case_eval_classes.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Caches = preload("res://workshop/caches.gd")
const Tuning = preload("res://sim/tuning.gd")
const Seeds = preload("res://tools/fixture_seeds.gd")
const OwnGiftDoubt = preload("res://workshop/own_gift_doubt.gd")

var checks: int = 0
var fails: int = 0
var people: Array = []
var ids: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _view(cards: Array, me: String, own_kind: String = "") -> Dictionary:
	var v: Dictionary = {"people": people, "evil_count": 2, "alignment_epoch": "Original alignment", "cards": cards,
		"world_options": {"modifiers": ["delusional", "marked", "ill_omened", "unrequited"], "roles": true, "identities": true, "bluffs": true}}
	if me != "":
		v["own_burden"] = {"self": me, "kind": own_kind}
	return v

func _claim(who: String, role: String) -> Dictionary:
	return {"id": "claim_" + who, "fact_id": "claim_" + who, "kind": "claim", "source": who, "subject": who, "role": role,
		"observed_at": {"day": 1, "phase": "morning"}, "text": "claims " + role}

## A gift reading; a Dowser's is a day reading (its night is the day it dowsed).
func _reading(id: String, who: String, role: String, night: int, data: Dictionary) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "report", "role": role, "source": who, "observed_at": {"day": night, "phase": "morning" if role == "dowser" else "night"},
		"reported_at": {"day": night + 1, "phase": "morning"}, "night": night, "data": data, "text": id}

func _listener(me: String, role: String, own: Array) -> Dictionary:
	return {"id": me, "knowledge": {"self": me, "good": [me], "own_role": role, "own_reports": own.map(func(c): return c.id)}}

## {"delusion": P(target Delusional), "believed": {own card id: P(it holds)}}.
func _ask(view: Dictionary, listener: Dictionary, target: String, own: Array) -> Dictionary:
	Caches.clear_all()
	var cs = Solver.empty_case()
	# Every card held, its own readings too, as the connections refresh and OwnGiftDoubt ask.
	cs.cards = view.cards.map(func(c): return c.id)
	cs.conclusion = {"type": "secret_mod", "mod": "delusional", "target": target, "at": "Original alignment"}
	var out: Dictionary = {"delusion": float(CaseEval.evaluate(view, cs, listener).posterior), "believed": {}}
	for c in own:
		var q = Solver.empty_case()
		q.cards = cs.cards.duplicate()
		q.conclusion = {"type": "holds", "report": c.id, "target": str(c.source), "at": "Original alignment"}
		out.believed[c.id] = float(CaseEval.evaluate(view, q, listener).posterior)
	return out

func _fmt(r: Dictionary) -> String:
	var b: Array = r.believed.values().map(func(x): return "%.0f%%" % (100.0 * x))
	return "P(Delusional) %.1f%%, readings believed %s" % [100.0 * r.delusion, str(b)]

func _init() -> void:
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
		ids.append(C.CAST[i].id)
	var me: String = ids[1]
	var p: Array = ids
	_prior(me)
	_case_a(me, p)
	_case_b(me, p)
	_case_c(me, p)
	_case_d(me, p)
	_case_e(me, p)
	_exposed()
	print("Shared Delusion: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

## The prior is OWN_DELUSION_PRIOR, the C# weight matches a GDScript count of the same worlds,
## and an Ill-Omened holder can't be Delusional.
func _prior(me: String) -> void:
	var lis: Dictionary = _listener(me, "seer", [])
	var r: Dictionary = _ask(_view([], me), lis, me, [])
	check(absf(r.delusion - Tuning.Workshop.OWN_DELUSION_PRIOR) < 1e-6, "before any evidence a good Seer is the Delusional at OWN_DELUSION_PRIOR (%.4f)" % r.delusion)
	var omen: Dictionary = _ask(_view([], me, "ill_omened"), lis, me, [])
	check(omen.delusion < 1e-9, "an Ill-Omened holder can't be Delusional (%.4f)" % omen.delusion)
	var chron: Dictionary = _ask(_view([], me), _listener(me, "chronicler", []), me, [])
	check(chron.delusion < 1e-9, "a Chronicler, whom the deal never makes Delusional, can't be (%.4f)" % chron.delusion)
	var flagged: Dictionary = _view([], me)
	flagged.own_burden["delusional_ok"] = false
	check(_ask(flagged, lis, me, []).delusion < 1e-9, "nor can a listener whose own_burden says its gift can't be")
	# Parity: the kernel's weight against the same count in GDScript.
	var view: Dictionary = _view([], me)
	var mi: int = Solver.person_index(view, me)
	var ob: Dictionary = view.own_burden
	var good: int = 0
	var held: int = 0
	for w in Domain.worlds(view):
		if int(w.evil) & (1 << mi) or not Classes._own_burden_ok(ob, mi, w):
			continue
		good += 1
		if int(w.get("marked", -1)) != mi and str(w.get("modifier", "")) == "delusional" and int(w.get("holders", 0)) & (1 << mi):
			held += 1
	var s: float = float(held) / float(good)
	var pr: float = Tuning.Workshop.OWN_DELUSION_PRIOR
	var gd_w: float = Classes.own_delusion_weight(view, pr)
	check(absf(gd_w - (pr / (1.0 - pr)) * ((1.0 - s) / s)) < 1e-9, "the GDScript weight sets the odds as counted here")
	var universe: Array = Solver.universe(view)
	var uh: int = SolverBackend.get_universe_handle(Solver._universe_key(view), universe)
	var fb: PackedInt64Array = SolverBackend.pack_worlds(universe) if uh < 0 else PackedInt64Array()
	var cs_w: float = float(SolverBackend._bridge().CaseEvalOwnDelusionWeight(uh, fb, mi, -1, Classes._own_burden_hidden_mask(), pr))
	print("the deal's own share %.4f; weight %.6f (C#) and %.6f (GDScript)" % [s, cs_w, gd_w])
	check(absf(cs_w - gd_w) < 1e-9, "C# and GDScript agree on the own-Delusion weight")

## (a) Two Seer readings that agree with each other and with a trusted Dowser's "0".
func _case_a(me: String, p: Array) -> void:
	var dow: Dictionary = _reading("a_dow", p[6], "dowser", 1, {"group": [p[2], p[3]], "count": 0, "block": people[2].home})
	var r1: Dictionary = _reading("a_n1", me, "seer", 1, {"pair": [p[2], p[3]], "yes": false})
	var r2: Dictionary = _reading("a_n2", me, "seer", 2, {"pair": [p[2], p[3]], "yes": false})
	var base: Array = [_claim(p[6], "dowser"), dow]
	var curve: Array = []
	for own in [[], [r1], [r1, r2]]:
		var r: Dictionary = _ask(_view(base + own, me), _listener(me, "seer", own), me, own)
		curve.append(r)
		print("(a) agreeing, %d readings: %s" % [own.size(), _fmt(r)])
	# A Seer's "no" can't tell its Red Herring from a draw, so the first barely moves it; the
	# second, agreeing with the first, costs a draw again and explains nothing new.
	check(curve[2].delusion < curve[0].delusion and curve[2].delusion < curve[1].delusion, "(a) two agreeing readings lower the shared doubt (%.3f, %.3f, %.3f)" % [curve[0].delusion, curve[1].delusion, curve[2].delusion])
	check(float(curve[2].believed["a_n1"]) >= float(curve[1].believed["a_n1"]), "(a) the second night's agreement doesn't lower belief in the first night's reading")
	# Held outside the case (the own states), a Seer reading whose content only the role check
	# reads weighs nothing in healthy worlds, so it mustn't weigh in its Delusional ones either.
	Caches.clear_all()
	var v2: Dictionary = _view(base + [r1, r2], me)
	var cs = Solver.empty_case()
	cs.cards = base.map(func(c): return c.id)
	cs.conclusion = {"type": "secret_mod", "mod": "delusional", "target": me, "at": "Original alignment"}
	var outside: float = float(CaseEval.evaluate(v2, cs, _listener(me, "seer", [r1, r2])).posterior)
	check(absf(outside - curve[0].delusion) < 1e-6, "(a) own Seer readings held outside the case leave the doubt as it was (%.4f, %.4f)" % [outside, curve[0].delusion])

## (b) A Seer "no" that clashes with a trusted Dowser's "2 evil" in the same pair.
func _case_b(me: String, p: Array) -> void:
	var dow: Dictionary = _reading("b_dow", p[6], "dowser", 1, {"group": [p[2], p[3]], "count": 2, "block": people[2].home})
	var r1: Dictionary = _reading("b_n1", me, "seer", 1, {"pair": [p[2], p[3]], "yes": false})
	var r: Dictionary = _ask(_view([_claim(p[6], "dowser"), dow, r1], me), _listener(me, "seer", [r1]), me, [r1])
	print("(b) clashing: %s" % _fmt(r))
	check(r.delusion > Tuning.Workshop.OWN_DELUSION_PRIOR, "(b) a clash with a trusted reading raises the doubt (%.3f)" % r.delusion)

## (c) The listener's own Dowser "0" against a trusted Seer "yes" naming one of its group.
func _case_c(me: String, p: Array) -> void:
	var seer: Dictionary = _reading("c_seer", p[6], "seer", 1, {"pair": [p[2], p[5]], "yes": true})
	var r1: Dictionary = _reading("c_n1", me, "dowser", 1, {"group": [p[2], p[3], p[4]], "count": 0, "block": people[2].home})
	var r: Dictionary = _ask(_view([_claim(p[6], "seer"), seer, r1], me), _listener(me, "dowser", [r1]), me, [r1])
	print("(c) own Dowser 0 against a Seer yes: %s" % _fmt(r))
	check(r.delusion > 0.0 and r.delusion < 0.5, "(c) the doubt stays a doubt (%.3f)" % r.delusion)

## (d) Contradicted three nights running by the same trusted Dowser: the curve. Each night's
## "no" agrees with the nights before, so after the first the town's rival explanation (the
## Dowser is wrong) explains them all at once, while the Delusion pays for each night's draw.
func _case_d(me: String, p: Array) -> void:
	var dow: Dictionary = _reading("d_dow", p[6], "dowser", 1, {"group": [p[2], p[3]], "count": 2, "block": people[2].home})
	var nights: Array = []
	for k in range(3):
		nights.append(_reading("d_n%d" % (k + 1), me, "seer", k + 1, {"pair": [p[2], p[3]], "yes": false}))
	var curve: Array = []
	for k in range(4):
		var own: Array = nights.slice(0, k)
		var r: Dictionary = _ask(_view([_claim(p[6], "dowser"), dow] + own, me), _listener(me, "seer", own), me, own)
		print("(d) %d clashes: %s" % [k, _fmt(r)])
		curve.append(r.delusion)
	check(curve[1] > curve[0], "(d) the first clash raises the doubt (%.3f > %.3f)" % [curve[1], curve[0]])
	check(curve[3] < 0.999, "(d) three clashes leave it a doubt, not a certainty (%.3f)" % curve[3])

## (e) Quill's slate case seer_contradiction_burden: another Seer's "yes" then "no" on the same
## pair, heard by a good listener with no gift readings of its own.
func _case_e(me: String, p: Array) -> void:
	var y: Dictionary = _reading("e_n1", p[4], "seer", 1, {"pair": [p[2], p[3]], "yes": true})
	var n: Dictionary = _reading("e_n2", p[4], "seer", 2, {"pair": [p[2], p[3]], "yes": false})
	var before: Dictionary = _ask(_view([_claim(p[4], "seer")], me), _listener(me, "clerk", []), p[4], [])
	var r: Dictionary = _ask(_view([_claim(p[4], "seer"), y, n], me), _listener(me, "clerk", []), p[4], [])
	print("(e) another Seer's yes then no: P(that Seer Delusional) %.1f%% -> %.1f%%" % [100.0 * before.delusion, 100.0 * r.delusion])
	check(r.delusion > before.delusion, "(e) a reader contradicting itself is likelier the Delusional (%.3f)" % r.delusion)

## In play: a good gifted NPC's refresh leaves its own chance and each reader's in workshop_state.
func _exposed() -> void:
	var found: Dictionary = Seeds.search(3, func(g):
		for n in g.w.living_good():
			if float(n.workshop_state.get("own_delusion", 0.0)) > 0.0 and not n.workshop_state.get("delusion_of", {}).is_empty():
				return {"id": n.id}
		return {}, 7, Seeds.SEEDS_FROM, 10)
	check(not found.is_empty(), "found a good NPC at a day-3 meeting with own_delusion and delusion_of set")
	if found.is_empty():
		return
	var n = found.g.w.by_id[found.id]
	var own: float = float(n.workshop_state.own_delusion)
	var of: Dictionary = n.workshop_state.get("delusion_of", {})
	print("seed %d: %s (%s) own_delusion %.3f, delusion_of %s" % [int(found.seed), n.id, n.role, own, str(of)])
	check(own >= 0.0 and own <= 1.0 and of.values().all(func(x): return float(x) >= 0.0 and float(x) <= 1.0), "the chances are chances")
	var st: Dictionary = n.get_meta("own_gift_doubt")
	var t0: int = Time.get_ticks_usec()
	var again: Dictionary = OwnGiftDoubt.delusion(st.view, st.listener, st.held)
	print("one delusion judgement: %d ms" % int((Time.get_ticks_usec() - t0) / 1000))
	check(absf(float(again.own) - own) < 1e-9, "asked again, the judge gives the same own chance (%.4f)" % float(again.own))

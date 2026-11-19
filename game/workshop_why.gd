## Why a presented case moved a listener as far as it did (developer inspection).
##
## The evidence half is workshop/case_why.gd: what the cards are worth and where the
## probability went instead. This is the belief half for a real listener, read back from
## the breakdown the connections model's refresh stored (workshop/connections.gd; nothing is
## re-run): for the premise's subject and whoever the case moved most, each part of the
## chance before and after, the case's own part and its weight, the case's cards alone, the
## core, and the chance and suspicion before and after (`_connections_report`). It draws no
## game RNG, writes to no mind and changes no belief. It runs on demand: the Workshop's Debug
## menu, `g.workshop_why` (one per listener when a case is presented), and
## tools/explain_case.gd --why. (The earlier model's stage-by-stage report went with that
## model, purge phase 5.)

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Jury = preload("res://workshop/jury.gd")
const Solver = preload("res://workshop/solver.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Why = preload("res://workshop/case_why.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const Connections = preload("res://workshop/connections.gd")

const KEEP = 24

## The Workshop's test juror, explained: the same neutral listener and inputs as
## WorkshopCanvas.test_juror, with the evidence breakdown and its text.
static func test_juror(g, value: Dictionary) -> Dictionary:
	# The same case the badge judges, public claims it hears included (WorkshopCanvas.juror_case).
	var juror: Dictionary = Canvas.juror_case(g, value)
	if not juror.ready:
		return {"ready": false, "issues": juror.issues.duplicate(), "text": "This case can't be judged yet:\n• " + "\n• ".join(PackedStringArray(juror.issues))}
	var prepared = juror.prepared
	var b: Dictionary = Why.evidence(prepared.view, juror.case)
	b["ready"] = true
	b["listener"] = "test juror"
	b["text"] = "Test juror: public facts and default trust. It hears every card at full weight; a real listener discounts what they're told (tick \"Record why each listener moved\" and present to see theirs).\n" + Why.describe(prepared.view, b, _numbers(g))
	return b

## Board number of each fact id, for the readout.
static func _numbers(g) -> Dictionary:
	var out: Dictionary = {}
	var Evidence = preload("res://workshop/live_evidence.gd")
	for card in g.board:
		if card.get("kind", "") == "deduction" or card.get("deleted", false):
			continue
		var id: String = Evidence.normalize_card(card).id
		if not out.has(id):
			out[id] = int(card.get("n", 0))
	return out

## The mind that judges for this person: themselves, or an evil NPC's good cover.
static func mind_of(real):
	return real.shadow if real.is_evil() and real.shadow != null else real

## Call just before a case is presented to `real`: what the "without this case" side of
## the breakdown needs that the presentation overwrites (what their attention was on, and
## where their suspicions stood).
## g: the game, so the connections model's last breakdown for this listener is kept too
## (with it on, that is the whole "before" side: nothing is re-run afterwards).
static func before(real, g = null) -> Dictionary:
	var n = mind_of(real)
	if n == null:
		return {}
	var out: Dictionary = {"focus": n.workshop_state.get("attention_focus", []).duplicate(), "suspicion": Mind.suspicion_view(n),
		"stored": n.suspicion.duplicate()}
	if g != null:
		var kept: Dictionary = g._workshop_evaluations.get(n.id + (":cover" if n.is_shadow else ":good"), {}).get("proposal", {}).get("connections", {})
		if not kept.is_empty():
			out["connections"] = _kept(kept)
	return out

## The parts of a connections result the report reads (the core's memory left out).
static func _kept(result: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in ["prior", "baseline", "posterior", "shift", "row", "impossible", "items", "core", "cases"]:
		if result.has(k):
			out[k] = result[k].duplicate(true) if result[k] is Dictionary or result[k] is Array else result[k]
	return out

static func _effect(proposal: Dictionary, target: String) -> Dictionary:
	return proposal.get("effects", {}).get(target, {})

## Everything about how `real` took the filed case `card` (a board deduction with a
## Workshop case), after it was presented to them. {} with "issues" when it can't be read
## (not presented to them, or the shared model isn't active for them).
## was: before(real) taken just before the presentation. Without it the "without this
## case" side assumes their attention was where the case left it.
static func presentation(g, real, card: Dictionary, venue: String = "meeting", was: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var n = mind_of(real)
	if n == null:
		return {"ready": false, "issues": ["No good mind to ask."]}
	var state: Dictionary = n.workshop_state
	var key: String = str(card.get("n", 0))
	var listener_key: String = n.id + (":cover" if n.is_shadow else ":good")
	if not state.get("active", false) or not state.get("presentations", {}).has(key) or not g._workshop_plans.has(listener_key):
		return {"ready": false, "issues": ["%s hasn't been shown case #%s (or the shared model isn't active for them)." % [n.name, key]]}
	var snapshot: Dictionary = state.presentations[key]
	var scoped: Dictionary = Assess.prepare(snapshot)
	if not scoped.get("ready", false):
		return {"ready": false, "issues": scoped.get("issues", [])}
	# The report is read from what the refresh stored. Without a stored breakdown (nothing
	# to weigh) there is no report.
	var applied: Dictionary = g._workshop_evaluations.get(listener_key, {}).get("proposal", {})
	if not applied.has("connections"):
		return {"ready": false, "issues": ["%s's last refresh has no breakdown to read (nothing to weigh)." % n.name]}
	return _connections_report(g, real, n, card, venue, was, started, scoped)

# ------------------------------------------------------------------ the connections model

## A push smaller than this (log-odds) isn't worth a line.
const SMALL = 0.005
## The case's own part must move someone at least this far to list them beside the subject.
const MOVED = 0.05

static func _who(g, id: String) -> String:
	return g.w.by_id[id].name if g.w.by_id.has(id) else str(id)

## "#30 Edda's Clerk reading"; a card that isn't on the Demonologist's board has no number.
static func _card_tag(g, c: Dictionary, nums: Dictionary) -> String:
	var source: String = str(c.get("source", ""))
	var role: String = str(c.get("role", "")).capitalize()
	var what: String = str(c.get("kind", "card"))
	if what == "report":
		what = (role + " reading") if role != "" else "reading"
	elif what in ["claim", "secret_claim"]:
		what = (role + " claim") if role != "" else "claim"
	var body: String = "%s's %s" % [_who(g, source), what] if g.w.by_id.has(source) else what
	return "#%d %s" % [int(nums[c.id]), body] if nums.has(c.id) else body + " (not on your board)"

## What a connections item is, in words: a card, or the cards a built-in pairing reads together.
static func _item_label(g, it: Dictionary, by_id: Dictionary, nums: Dictionary) -> String:
	var n_cards: int = it.cards.size()
	var key: String = str(it.key)
	match str(it.get("kind", "card")):
		"movement":
			return "Every night card, read together (%s)" % _count(n_cards)
		"day":
			return "The Hexer's day evidence, read together (%s)" % _count(n_cards)
		"unit":
			if key.begins_with("night:"):
				return "Night %s's cards, read together (%s)" % [key.trim_prefix("night:"), _count(n_cards)]
			if key.begins_with("augur:"):
				return "Day %s's Augur readings with that day's sightings (%s)" % [key.trim_prefix("augur:"), _count(n_cards)]
			if key.begins_with("claims:"):
				return "Every %s claim, read together (%s)" % [C.role_name(key.trim_prefix("claims:")), _count(n_cards)]
			var first: Dictionary = by_id.get(it.cards[0], {}) if n_cards > 0 else {}
			if key.begins_with("psychologist:") and not first.is_empty():
				return "%s with its statements (%s)" % [_card_tag(g, first, nums), _count(n_cards)]
			if key.begins_with("trace:") and not first.is_empty():
				return "%s with the profile cards" % _card_tag(g, first, nums)
	if n_cards > 0 and by_id.has(it.cards[0]):
		return _card_tag(g, by_id[it.cards[0]], nums)
	return key

static func _count(n_cards: int) -> String:
	return "1 card" if n_cards == 1 else "%d cards" % n_cards

## "#39" for one of the Demonologist's cases, "Nisha's nomination of Odette" for an NPC's.
static func _case_name(g, key: String) -> String:
	if key.begins_with("case:"):
		return "#" + key.trim_prefix("case:")
	var bits: PackedStringArray = key.split(":")
	if bits.size() >= 3 and bits[0] == "nomination":
		return "%s's nomination of %s" % [_who(g, bits[1]), _who(g, bits[2])]
	return key

static func _sum(leans: Array, p: String) -> float:
	var total: float = 0.0
	for l in leans:
		total += float(l.get(p, 0.0))
	return total

## Every part of one person's chance, before and after, in log-odds: the parts add up to the
## chance the refresh gave. res, old: the connections result now and at the listener's last
## refresh before the case ({} when there was none). case_key: this case's key in the store.
## Returns {"rows": [{"stage", "label", "before", "after"}], "pinned": why the common shift
## doesn't apply to them ("" when it does), "before", "after": the chances}.
static func _parts(res: Dictionary, old: Dictionary, p: String, case_key: String, case_ids: Array) -> Dictionary:
	var side := func(r: Dictionary) -> Dictionary:
		if r.is_empty() or not r.get("posterior", {}).has(p):
			return {}
		var base: float = float(r.baseline.get(p, 0.0))
		var pinned: String = ""
		if base <= Connections.FIXED or base >= 1.0 - Connections.FIXED:
			pinned = "settled by the public record or what they know themselves"
		elif r.get("core", {}).get("proved", {}).has(p):
			pinned = "proved by their own knowledge"
		var with_case: Array = []
		var plain: Array = []
		for it in r.get("items", []):
			(with_case if it.cards.any(func(id): return id in case_ids) else plain).append(it.lean)
		var this_case: Array = []
		var other: Array = []
		for e in r.get("cases", {}).get("entries", []):
			(this_case if str(e.key) == case_key else other).append(e.lean)
		var out: Dictionary = {"start": Connections.logit(base), "case_cards": _sum(with_case, p), "other_cards": _sum(plain, p),
			"core": float(r.get("core", {}).get("lean", {}).get(p, 0.0)), "case": _sum(this_case, p), "other_cases": _sum(other, p),
			"other_keys": r.get("cases", {}).get("entries", []).filter(func(e): return str(e.key) != case_key).map(func(e): return str(e.key)), "shift": float(r.get("shift", 0.0)) if pinned == "" else 0.0, "pinned": pinned,
			"chance": float(r.posterior[p]), "fixed": 0.0}
		# A pinned person's chance is set outright (Connections.combine: the proof, or the
		# public record), whatever the parts say. Show that as its own part, so the parts
		# still add up to the chance and none of them seems to move them (Codex, #148).
		if pinned != "":
			var parts_sum: float = 0.0
			for k in ["start", "case_cards", "other_cards", "core", "case", "other_cases"]:
				parts_sum += float(out[k])
			out.fixed = Connections.logit(out.chance) - parts_sum
		return out
	var now: Dictionary = side.call(res)
	var then: Dictionary = side.call(old)
	if now.is_empty():
		return {}
	var rows: Array = []
	for row in [["start", "Where they start (their standing view and the public record)"],
			["case_cards", "This case's cards, each counted by itself"],
			["other_cards", "Every other card they hold, each counted by itself"],
			["core", "Their own knowledge weighed with what bears on it (the core)"],
			["case", "This case's cards weighed together, at its weight"],
			["other_cases", "Other cases put to them"],
			["shift", "Keeping the number of evil people right (the same shift for everyone)"],
			["fixed", "Settled outright, so the parts above don't move them (proof or the public record)"]]:
		rows.append({"stage": row[0], "label": row[1], "before": then.get(row[0], null), "after": float(now[row[0]])})
	return {"rows": rows, "pinned": str(now.pinned), "before": then.get("chance", null), "after": float(now.chance), "other_cases": now.other_keys}

## Why a presented case moved a listener, with the connections model on: read from the
## breakdown the applied refresh stored (and the one before it, from `before`). Nothing is
## re-run except the premise's own single-listener check (Why.evidence), which the switch
## doesn't change.
static func _connections_report(g, real, n, card: Dictionary, venue: String, was: Dictionary, started: int, scoped: Dictionary) -> Dictionary:
	var state: Dictionary = n.workshop_state
	var key: String = str(card.get("n", 0))
	var listener_key: String = n.id + (":cover" if n.is_shadow else ":good")
	var plan: Dictionary = g._workshop_plans[listener_key]
	var applied: Dictionary = g._workshop_evaluations[listener_key].proposal
	var res: Dictionary = applied.connections
	var old: Dictionary = was.get("connections", {})
	var conclusion: Dictionary = scoped.case.conclusion
	var target: String = str(conclusion.get("target", conclusion.get("a", "")))
	var view: Dictionary = plan.prepared.view
	var by_id: Dictionary = {}
	for c in view.cards:
		by_id[c.id] = c
	var nums: Dictionary = _numbers(g)
	var case_key: String = "case:" + key
	var memory: Dictionary = plan.prepared.listener.get("connections", {})
	var stored: Array = memory.get("cases", []).filter(func(x): return str(x.get("key", "")) == case_key)
	var cs: Dictionary = stored[0] if not stored.is_empty() else {}
	var case_ids: Array = cs.get("cards", state.presentations[key].selected).duplicate()
	var entries: Array = res.get("cases", {}).get("entries", []).filter(func(e): return str(e.key) == case_key)
	var entry: Dictionary = entries[0] if not entries.is_empty() else {}
	var out: Dictionary = {"ready": true, "model": "connections", "listener": real.id, "name": real.name, "cover": n.is_shadow, "card": int(card.get("n", 0)),
		"venue": venue, "day": g.w.day, "conclusion": conclusion.duplicate(true), "target": target, "is_subject": target == n.id,
		"row": str(res.get("row", "")), "had_before": not old.is_empty()}

	# The case's own part: its weight, and who it moved.
	var today: int = int(memory.get("day", g.w.day))
	var days: int = maxi(0, today - int(cs.get("day", today)))
	var fade: float = pow(float(entry.get("rate", Connections.CASE_FADE)), days)
	var hedge: float = Tuning.Workshop.SUSPICIOUS_HEARING if cs.get("suspicious", false) else 1.0
	var weight: float = float(entry.get("weight", Connections.case_weight(plan.prepared.listener, cs, today))) if not cs.is_empty() else 0.0
	var moved: Array = entry.get("lean", {}).keys()
	moved.sort_custom(func(a, b): return absf(float(entry.lean[a])) > absf(float(entry.lean[b])) if not is_equal_approx(absf(float(entry.lean[a])), absf(float(entry.lean[b]))) else a < b)
	var held_ids: Array = []
	for it in res.get("items", []):
		for id in it.cards:
			if id in case_ids and id not in held_ids:
				held_ids.append(id)
	var replaced_by: Array = res.get("cases", {}).get("entries", []).filter(func(e): return case_key in e.get("replaces", []))
	var not_counted: String = ""
	if cs.is_empty():
		not_counted = "it isn't in what they remember being put to them"
	elif held_ids.is_empty():
		not_counted = "they hold none of its cards"
	elif entry.is_empty() and not replaced_by.is_empty():
		not_counted = "a later case of yours (%s) cites every card of this one and has taken its place" % _case_name(g, str(replaced_by[0].key))
	elif entry.is_empty():
		not_counted = "its weight (%.2f) is under %.2f" % [weight, Connections.CASE_FLOOR] if weight < Connections.CASE_FLOOR else "none of its cards are theirs to weigh"
	elif entry.get("impossible", false):
		not_counted = "no world allows its cards together, so as a whole it says nothing"
	elif entry.lean.is_empty() and int(entry.get("shared", 0)) >= 2:
		not_counted = "an earlier case of yours already put these cards together, so they add nothing again"
	elif entry.lean.is_empty():
		not_counted = "there is nothing new to weigh together (one card or pairing, or cards the movement connection already weighs together)"
	out["case"] = {"key": case_key, "counted": not_counted == "", "not_counted": not_counted, "weight": weight,
		"trust": weight / (fade * hedge) if fade * hedge > 0.0 else 0.0, "fade": fade, "rate": float(entry.get("rate", Connections.CASE_FADE)), "days": days, "suspicious": bool(cs.get("suspicious", false)),
		"merged": bool(entry.get("merged", false)), "together": int(entry.get("cards", 0)), "lean": entry.get("lean", {}).duplicate(),
		"shared": int(entry.get("shared", 0)), "replaces": entry.get("replaces", []).duplicate(),
		"moved": moved.slice(0, 4).map(func(p): return {"id": p, "lean": float(entry.lean[p])}),
		"challenges": res.get("cases", {}).get("floors", []).filter(func(f): return str(f.get("case", "")) == case_key).duplicate(true)}

	# Who the report follows: the premise's subject, then whoever the case's own part moved most.
	var people: Array = []
	if target != "" and target != n.id and res.get("posterior", {}).has(target):
		people.append(target)
	for p in moved:
		if people.size() < 3 and p not in people and absf(float(entry.lean[p])) >= MOVED:
			people.append(p)
	out["people"] = people
	var parts: Dictionary = {}
	for p in people:
		parts[p] = _parts(res, old, p, case_key, case_ids)
	out["parts"] = parts

	# The case's cards, each as the model counts it alone: a card, or the pairing it sits in.
	var rejected: Array = applied.get("reasoning", {}).get("private_checks", {}).get("rejected", [])
	var old_items: Dictionary = {}
	for it in old.get("items", []):
		old_items[str(it.key)] = it
	var cards: Array = []
	var seen_items: Dictionary = {}
	for id in case_ids:
		var c: Dictionary = by_id.get(id, {})
		var tag: String = _card_tag(g, c, nums) if not c.is_empty() else "a card they were never given"
		var mine: Array = res.get("items", []).filter(func(it): return id in it.cards and str(it.get("kind", "")) != "day")
		if mine.is_empty():
			cards.append({"ids": [id], "label": tag, "status": "rejected" if id in rejected else "not_held", "lean": {}})
			continue
		var it: Dictionary = mine[0]
		if seen_items.has(str(it.key)):
			continue
		seen_items[str(it.key)] = true
		var here: Array = it.cards.filter(func(x): return x in case_ids)
		var brought: bool = here.all(func(x): return not plan.owners.get(x, []).any(func(o): return str(o) != case_key))
		var lean: Dictionary = {}
		var lean_was: Dictionary = {}
		for p in people:
			lean[p] = float(it.lean.get(p, 0.0))
			if old_items.has(str(it.key)):
				lean_was[p] = float(old_items[str(it.key)].lean.get(p, 0.0))
		cards.append({"ids": here, "item": str(it.key), "kind": str(it.get("kind", "card")), "label": _item_label(g, it, by_id, nums) if str(it.get("kind", "card")) != "card" else tag,
			"holds": here.map(func(x): return _card_tag(g, by_id[x], nums)) if str(it.get("kind", "card")) != "card" else [],
			"status": "pairing" if str(it.get("kind", "card")) != "card" else "alone", "brought": brought, "impossible": bool(it.get("impossible", false)),
			"lean": lean, "lean_was": lean_was})
	out["cards"] = cards
	out["held"] = case_ids.filter(func(x): return plan.owners.get(x, []).any(func(o): return str(o) != case_key)).size()
	out["cards_n"] = case_ids.size()

	# The core.
	var own: Dictionary = res.get("core", {})
	var item_by_key: Dictionary = {}
	for it in res.get("items", []):
		item_by_key[str(it.key)] = it
	var label_of := func(k) -> String: return _item_label(g, item_by_key[str(k)], by_id, nums) if item_by_key.has(str(k)) else str(k)
	var core_lean: Dictionary = {}
	for p in people:
		core_lean[p] = float(own.get("lean", {}).get(p, 0.0))
	out["core"] = {"seed": own.get("seed", []).map(label_of), "members": own.get("members", []).map(label_of), "lean": core_lean,
		"proved": own.get("proved", {}).keys(), "impossible": bool(own.get("impossible", false)), "merged": bool(entry.get("merged", false)),
		"case_in_core": own.get("seed", []).any(func(k): return seen_items.has(str(k))) or own.get("members", []).any(func(k): return seen_items.has(str(k)))}

	# Chance and suspicion, before and after, from the refresh itself.
	var e_with: Dictionary = _effect(applied, target)
	out["effect"] = {"prior": float(e_with.get("prior", 0.0)), "posterior": float(e_with.get("posterior", 0.0)),
		"posterior_without": old.get("posterior", {}).get(target, null), "requested": float(e_with.get("requested", 0.0)), "route": str(e_with.get("route", ""))}
	out["suspicion"] = {"now": Mind.susp(n, target) if target != "" else 0.0, "stored": float(n.suspicion.get(target, 0.0)),
		"was": was.get("suspicion", {}).get(target, null), "stored_was": was.get("stored", {}).get(target, null),
		"outside": float(state.get("outside", {}).get(target, 0.0)), "circumstantial": float(state.get("circumstantial_applied", {}).get(target, 0.0))}
	if target != "" and g.w.by_id.has(target) and target != n.id:
		out["action"] = _action(g, n, target)

	# Does the case support its premise? The single-listener check, as this listener hears
	# the cards. The switch doesn't change it.
	out["read_ms"] = Time.get_ticks_msec() - started
	var outside: Dictionary = state.get("outside", n.suspicion).duplicate(true)
	var doubt: Dictionary = SourceDoubt.derive(plan, n.ledger, state.get("manual_source_doubt", {}))
	var adjusted: Dictionary = Shared._doubt_adjusted(plan, outside, doubt.pre_eval, doubt.full, doubt.get("honest", {}))
	var own_reports: Array = adjusted.listener.knowledge.get("own_reports", []).filter(func(id): return id not in scoped.case.cards)
	var evidence: Dictionary = Why.evidence(adjusted.view, scoped.case, Jury._eval_listener(adjusted.listener, own_reports), {"rejected": rejected,
		"held": case_ids.filter(func(x): return plan.owners.get(x, []).any(func(o): return str(o) != case_key))})
	out["evidence"] = evidence
	out["alternative"] = Why.strongest_alternative(adjusted.view, evidence)
	out["text"] = describe_connections(g, out, adjusted.view)
	out["elapsed_ms"] = Time.get_ticks_msec() - started
	return out

static func _push(v) -> String:
	return "     —" if v == null else "%+6.2f" % float(v)

static func _pct(v) -> String:
	return "—" if v == null else "%.0f%%" % (100.0 * float(v))

static func describe_connections(g, b: Dictionary, view: Dictionary) -> String:
	var lines: PackedStringArray = []
	var c: Dictionary = b.conclusion
	var t_name: String = _who(g, b.target) if g.w.by_id.has(b.target) else "(case)"
	var cs: Dictionary = b["case"]
	lines.append("Why %s%s moved on \"%s %s\" (case #%d, %s, day %d; connections model)" % [b.name, " (good cover)" if b.get("cover", false) else "", t_name, str(c.get("type", "")), b.card, b.venue, b.day])
	if b.get("is_subject", false):
		lines.append("%s is the subject: they know their own alignment, so the case can't move them about it." % b.name)
	# The bottom line.
	var sus: Dictionary = b.suspicion
	if not b.parts.get(b.target, {}).is_empty():
		var tp: Dictionary = b.parts[b.target]
		var largest: Dictionary = {}
		for row in tp.rows:
			var change: float = float(row.after) - float(row.before if row.before != null else 0.0)
			if absf(change) > absf(float(largest.get("change", 0.0))):
				largest = {"label": row.label, "change": change}
		var shown: String = ""
		if sus.stored < 0.0 or (sus.stored_was != null and float(sus.stored_was) < 0.0):
			shown = " (the game reads anything below zero as 0.00)"
		var steady: bool = tp.before != null and absf(float(tp.after) - float(tp.before)) < SMALL
		var head: String = "%s's chance that %s is evil %s; suspicion %s." % [b.name, t_name,
			"stayed at %s" % _pct(tp.after) if steady else "went from %s to %s" % [_pct(tp.before), _pct(tp.after)],
			("stayed at %+.2f" % float(sus.stored) if sus.stored_was != null and absf(float(sus.stored) - float(sus.stored_was)) < SMALL
				else "%s to %+.2f" % ["%+.2f" % float(sus.stored_was) if sus.stored_was != null else "?", float(sus.stored)]) + shown]
		if not steady and tp.before != null and absf(float(largest.get("change", 0.0))) >= SMALL:
			head += " The largest part: %s (%+.2f)." % [str(largest.label).to_lower().split(" (")[0], float(largest.change)]
		if cs.counted and not cs.moved.is_empty() and str(cs.moved[0].id) != b.target and absf(float(cs.moved[0].lean)) >= MOVED:
			head += " Weighed together, the case's cards fell mostly on %s (%+.2f), not %s." % [_who(g, str(cs.moved[0].id)), float(cs.moved[0].lean), t_name]
		lines.append("In short: " + head)
	if not b.get("had_before", false):
		lines.append("(No earlier refresh was recorded for %s, so only the \"after\" side is shown.)" % b.name)
	# What the case added as a whole.
	lines.append("")
	if not cs.counted:
		lines.append("The case as a whole added nothing: %s. Its cards still count one by one (below)." % cs.not_counted)
	else:
		var moved: PackedStringArray = []
		for m in cs.moved:
			if absf(float(m.lean)) >= SMALL:
				moved.append("%s %+.2f" % [_who(g, m.id), float(m.lean)])
		lines.append("The case's cards weighed together added: %s." % (", ".join(moved) if not moved.is_empty() else "nothing to speak of"))
		var w: PackedStringArray = ["trust in you %.2f" % float(cs.trust)]
		w.append("x%.2f for %d day%s since it was presented (it keeps %.2f a day; more the further it moved them)" % [float(cs.fade), int(cs.days), "" if int(cs.days) == 1 else "s", float(cs.get("rate", Connections.CASE_FADE))] if int(cs.days) > 0 else "presented today, so no fading")
		if cs.suspicious:
			w.append("x%.2f for a \"suspicious\" premise" % Tuning.Workshop.SUSPICIOUS_HEARING)
		lines.append("  Counted at weight %.2f (%s). At full weight it would be %s." % [float(cs.weight), "; ".join(w),
			", ".join(PackedStringArray(cs.moved.slice(0, 2).map(func(m): return "%s %+.2f" % [_who(g, m.id), float(m.lean) / maxf(float(cs.weight), 1e-6)])))])
		lines.append("  %s weighed together%s." % ["1 card was" if int(cs.together) == 1 else "%d cards were" % int(cs.together), ", along with %s's core (the case shares a card with it)" % b.name if cs.merged else ""])
	if cs.counted and not cs.replaces.is_empty():
		lines.append("  It takes the place of %s, whose cards it all cites: that set now counts once, here." % ", ".join(PackedStringArray(cs.replaces.map(func(k): return _case_name(g, str(k))))))
	if cs.counted and int(cs.shared) >= 2:
		lines.append("  %d of its cards (or pairings) were already together in an earlier case of yours; their meeting each other isn't counted again." % int(cs.shared))
	for ch in cs.challenges:
		lines.append("  Challenge on %s (%s's reading), called \"%s\": they agree at %.2f%s." % [_card_tag(g, _view_card(view, str(ch.get("card", ""))), _numbers(g)), _who(g, str(ch.get("source", ""))),
			str(ch.get("mode", "")), float(ch.get("agreement", 0.0)), "; the reading counts at x%.2f inside this case" % float(ch.multiplier) if ch.has("multiplier") and not is_equal_approx(float(ch.multiplier), 1.0) else ""])
	# Every part of the chance, per person.
	for p in b.people:
		var pp: Dictionary = b.parts[p]
		if pp.is_empty():
			continue
		lines.append("")
		lines.append("%s's chance that %s is evil, part by part (minus clears, plus accuses; 0.7 doubles or halves the odds):" % [b.name, _who(g, p)])
		lines.append("  %-70s %6s  %6s  %6s" % ["", "before", "after", "change"])
		var total_b: float = 0.0
		var total_a: float = 0.0
		for row in pp.rows:
			total_a += float(row.after)
			if row.before != null:
				total_b += float(row.before)
			var change = float(row.after) - float(row.before) if row.before != null else null
			if row.stage != "start" and absf(float(row.after)) < SMALL and (row.before == null or absf(float(row.before)) < SMALL):
				continue
			var label: String = str(row.label)
			if row.stage == "other_cases" and not pp.other_cases.is_empty():
				label += " (%s)" % ", ".join(PackedStringArray(pp.other_cases.map(func(k): return _case_name(g, k))))
			lines.append("  %-70s %s  %s  %s" % [label, _push(row.before), _push(row.after), _push(change) if change != null and absf(change) >= SMALL else ""])
		lines.append("  %-70s %s  %s  %s" % ["Total", _push(total_b) if pp.before != null else _push(null), _push(total_a), _push(total_a - total_b) if pp.before != null else ""])
		lines.append("  %-70s %6s  %6s" % ["Chance %s is evil" % _who(g, p), _pct(pp.before), _pct(pp.after)])
		if pp.pinned != "":
			lines.append("  (%s is %s, so the cards don't move them.)" % [_who(g, p), pp.pinned])
	# The case's cards alone.
	lines.append("")
	lines.append("The case's cards, each counted by itself%s:" % (" (on %s)" % ", ".join(PackedStringArray(b.people.map(func(p): return _who(g, p)))) if not b.people.is_empty() else ""))
	for row in b.cards:
		var head: String = "  " + str(row.label)
		if row.status == "pairing":
			head += ", which holds " + ", ".join(PackedStringArray(row.holds))
		if row.status == "rejected":
			lines.append(head + ": rejected from their own knowledge, so it isn't weighed")
			continue
		if row.status == "not_held":
			lines.append(head + ": not held, so it isn't weighed")
			continue
		var bits: PackedStringArray = []
		for p in b.people:
			var x: float = float(row.lean.get(p, 0.0))
			var note: String = ""
			if row.lean_was.has(p) and absf(x - float(row.lean_was[p])) >= SMALL:
				note = " (was %+.2f)" % float(row.lean_was[p])
			bits.append("%s %+.2f%s" % [_who(g, p), x, note])
		lines.append("%s: %s%s%s" % [head, ", ".join(bits) if not bits.is_empty() else "counted",
			" [new to them: the case brought it]" if row.get("brought", false) else "", " [no world allows it]" if row.get("impossible", false) else ""])
	# The core.
	var core: Dictionary = b.core
	lines.append("")
	if core.seed.is_empty():
		lines.append("%s's core: none (nothing firsthand to weigh other cards against)." % b.name)
	else:
		lines.append("%s's core (their own knowledge and what bears on it):" % b.name)
		lines.append("  Starts from: %s." % "; ".join(PackedStringArray(core.seed)))
		lines.append("  Joined to it: %s." % ("; ".join(PackedStringArray(core.members)) if not core.members.is_empty() else "nothing"))
		var adds: PackedStringArray = []
		for p in b.people:
			adds.append("%s %+.2f" % [_who(g, p), float(core.lean.get(p, 0.0))])
		if core.impossible:
			lines.append("  Their own knowledge doesn't fit together, so the core adds nothing.")
		elif not adds.is_empty():
			lines.append("  It adds: %s." % ", ".join(adds))
		if not core.proved.is_empty():
			lines.append("  It proves outright: %s." % ", ".join(PackedStringArray(core.proved.map(func(p): return _who(g, p)))))
		lines.append("  This case %s." % ("was weighed with it as one set" if core.merged else "shares no card with it, so the two were weighed apart"))
	# Suspicion and the vote.
	if g.w.by_id.has(b.target) and not b.get("is_subject", false):
		lines.append("")
		lines.append("Suspicion of %s as stored: %s before, %+.2f now. The game reads it as %s before, %.2f now (it never reads below zero or above 1.5)." % [t_name,
			"%+.2f" % float(sus.stored_was) if sus.stored_was != null else "?", float(sus.stored),
			"%.2f" % float(sus.was) if sus.was != null else "?", float(sus.now)])
	if b.has("action"):
		var a: Dictionary = b.action
		lines.append("Action: a vote on %s now scores %.2f against a need of %.2f (%s by %.2f); nomination bar %.2f." % [t_name, float(a.vote_score), float(a.vote_need),
			"clears it" if float(a.vote_margin) >= 0.0 else "short", absf(float(a.vote_margin)), float(a.nomination_bar)])
		lines.append("  (suspicion %.2f + town pressure %.2f + execution priority %.2f + resentment %.2f; the player's own vote and statement would add to this)" % [
			float(a.suspicion), float(a.town_pressure), float(a.execution_priority), float(a.resentment)])
	lines.append("")
	lines.append("Does the case support its own premise? (All its cards read together by %s alone; the same check with the model on or off.)" % b.name)
	lines.append(Why.describe(view, b.evidence, _numbers(g)))
	return "\n".join(lines)

static func _view_card(view: Dictionary, id: String) -> Dictionary:
	var c: Dictionary = Solver.card_by_id(view, id)
	return c if not c.is_empty() else {"id": id, "kind": "reading"}

## Where the listener stands against the vote and nomination bars for `target` right now,
## with no statement from the player. The same parts Mind's vote adds up (mind_meeting.gd
## `_vote_impl`, `_good_nomination_impl`), read without rolling or logging anything.
static func _action(g, n, target: String) -> Dictionary:
	var w = g.w
	var score: float = Mind.action_susp(n, target) + Mind.resentment_toward(w, n, target)
	var dead: int = w.npcs.filter(func(m): return not m.alive).size()
	var need: float = Tuning.Meeting.VOTE_BASE_NEED \
		- Tuning.Meeting.VOTE_CONFIDENCE_SCALE * (Mind.trait_of(n, "confidence") - 0.5) * 2.0 \
		+ (Tuning.Meeting.VOTE_DAY1_PENALTY if w.day <= 1 else 0.0) \
		- Tuning.Meeting.VOTE_PARANOIA_WEIGHT * Mind.paranoia(w, n) \
		- Tuning.Meeting.VOTE_URGENCY_PER_DEATH * dead
	var bar: float = maxf(Tuning.Meeting.NOMINATION_FLOOR, Tuning.Meeting.NOMINATION_BASE - Tuning.Meeting.NOMINATION_DAY_SLOPE * w.day) \
		- Tuning.Meeting.NOMINATION_CONFIDENCE_SCALE * (Mind.trait_of(n, "confidence") - 0.5) * 2.0 \
		- Tuning.Meeting.NOMINATION_PARANOIA_SCALE * Mind.paranoia(w, n)
	return {"suspicion": Mind.susp(n, target), "town_pressure": clampf(n.suspicion.get(target, 0.0) + n.consensus_pressure.get(target, 0.0), 0.0, 1.5) - clampf(n.suspicion.get(target, 0.0), 0.0, 1.5),
		"execution_priority": Mind.execution_priority_contribution(n, target), "resentment": Mind.resentment_toward(w, n, target),
		"vote_score": score, "vote_need": need, "vote_margin": score - need, "nomination_bar": bar, "nomination_margin": score - bar}

## Record one breakdown per listener after a real presentation (`g.workshop_why` on).
## Goes to g.workshop_whys (the Workshop's Debug menu shows them), the dev log and the
## trace sidecar. Called after the presentation has been applied; changes nothing.
static func record(g, real, card: Dictionary, venue: String, was: Dictionary = {}) -> void:
	var b: Dictionary = presentation(g, real, card, venue, was)
	if not b.get("ready", false):
		return
	g.workshop_whys.append(b)
	if g.workshop_whys.size() > KEEP:
		g.workshop_whys.pop_front()
	if b.get("model", "") == "connections":
		var tp: Dictionary = b.parts.get(b.target, {})
		var short: Dictionary = {"model": "connections", "card": b.card, "venue": venue, "conclusion": b.conclusion, "people": b.people, "parts": b.parts,
			"case": b["case"], "cards": b.cards, "core": b.core, "held": b.held, "cards_n": b.cards_n, "effect": b.effect, "suspicion": b.suspicion,
			"action": b.get("action", {}), "premise": {"prior": b.evidence.prior, "posterior": b.evidence.posterior, "lr": b.evidence.lr, "chain": b.evidence.chain},
			"alternative": b.alternative, "elapsed_ms": b.elapsed_ms}
		var top: Array = b["case"].moved
		var line: String = "Why %s moved: chance %s -> %s; %s" % [real.name, _pct(tp.get("before", null)), _pct(tp.get("after", null)),
			"the case weighed together added %s at weight %.2f" % [("%+.2f on %s" % [float(top[0].lean), _who(g, str(top[0].id))]) if not top.is_empty() else "nothing", float(b["case"].weight)] if b["case"].counted
			else "the case as a whole added nothing (%s)" % b["case"].not_counted]
		g.w.dlog.add("workshop_why", real.id, b.target, short, line)
		g.w.dlog.trace_event("workshop_why", real.id, b.target, {"text": b.text}, "Read-only breakdown of the applied presentation (connections model).")
		return

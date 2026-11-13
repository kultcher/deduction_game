## Why a case moves a listener as far as it does, and no further (developer inspection).
##
## The solver already knows why an argument is worth what it is: every discount it applies
## is a number it computed. This module reads those numbers back out. It never decides
## anything: it re-runs CaseEval on copies with one thing changed at a time, and reports
## the difference. Nothing here draws from the game's RNG or writes to a mind.
##
## evidence(view, case, listener) answers, for one premise and the cards under it:
##   chain         P(premise) at each step: before the cards; if every teller were honest
##                 and every card exact; allowing that a teller may be evil or deluded (the
##                 "cheap to fake" discount, q); and as this listener actually hears it
##                 (hearing weight, trust in the teller, doubt).
##   cards         per card: its status (counted, fits most worlds, no effect, argues
##                 against, no weight, not attended, rejected), how the listener hears it
##                 (reliability), how likely its content is across the worlds (world_share),
##                 the chance the model itself assumes a false report would say it (q_used;
##                 some gifts use a fixed 0.5), and what the premise loses without it.
##   alternatives  where the probability went instead: the surviving worlds in which the
##                 premise is false, grouped by what they have in common.
##
## The game-side companion (game/workshop_why.gd) adds the belief half for a real listener:
## posterior -> suspicion -> vote.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")

## A card whose content holds in at least this share of worlds says little by holding.
const TYPICAL_SHARE = 0.85
## A card whose removal changes the premise's likelihood ratio by less than this factor
## (either way) has no effect on this case.
const NEGLIGIBLE_RATIO = 1.03
## A card that fits most worlds and moves the ratio by less than this is "functionally
## irrelevant": counted, but it could hardly have said anything else.
const SLIGHT_RATIO = 1.10
## Reliability at or below this: the listener gives the card no weight.
const NO_WEIGHT = 0.02
## Per-world facts about a case that don't depend on how a listener hears it (see _masks).
## A presentation asks every listener about the same case in a row, so the last few are kept.
static var _mask_cache: Dictionary = {}
const MASK_CACHE_MAX = 64
const ACCUSING = ["evil", "suspicious", "demon", "minion", "lied"]
const CLEARING = ["good", "notdemon", "truthful"]

## One CaseEval run on the caller's inputs, optionally with per-world weights. The capture
## switch is a developer flag on CaseEval; it is restored, so a tool that has it on keeps
## its own captures.
static func run(view: Dictionary, case_data: Dictionary, listener: Dictionary, want_worlds: bool = false) -> Dictionary:
	var was: bool = CaseEval.capture_worlds
	var kept: Array = CaseEval.captured
	CaseEval.capture_worlds = want_worlds
	CaseEval.captured = []
	var ev: Dictionary = CaseEval.evaluate(view, case_data, listener)
	var worlds := PackedFloat64Array()
	if want_worlds and not CaseEval.captured.is_empty():
		worlds = CaseEval.captured[-1].worlds
	CaseEval.capture_worlds = was
	CaseEval.captured = kept
	return {"ev": ev, "worlds": worlds}

## The case reduced to these root cards (its premise kept; lines, disputes and hubs that
## need other cards dropped).
static func only(case_data: Dictionary, ids: Array) -> Dictionary:
	var c: Dictionary = case_data.duplicate(true)
	c.cards = ids.duplicate()
	c["lines"] = []
	c["derived"] = []
	c["arguments"] = []
	c["circumstantial"] = []
	c["positions"] = {}
	c["temporal_positions"] = []
	c["citations"] = {}
	c["reasons"] = {}
	c["faults"] = {}
	c["test_factors"] = []
	c["disputes"] = case_data.get("disputes", []).filter(func(d): return d.get("reports", []).all(func(id): return id in ids)).duplicate(true)
	var answers: Dictionary = {}
	for id in case_data.get("answers", {}):
		if id in ids:
			answers[id] = case_data.answers[id].duplicate(true)
	c["answers"] = answers
	var challenges: Dictionary = {}
	for id in case_data.get("reading_challenges", {}):
		var ch: Dictionary = case_data.reading_challenges[id]
		if id in ids and ch.get("supports", []).all(func(s): return s in ids):
			challenges[id] = ch.duplicate(true)
	c["reading_challenges"] = challenges
	return c

## The case with one root card removed everywhere it appears.
static func without(case_data: Dictionary, id: String) -> Dictionary:
	var c: Dictionary = case_data.duplicate(true)
	_strip(c, [id])
	return c

static func _strip(c: Dictionary, ids: Array) -> void:
	c.cards = c.get("cards", []).filter(func(x): return x not in ids)
	for id in ids:
		c.get("answers", {}).erase(id)
		c.get("reading_challenges", {}).erase(id)
	for key in c.get("reading_challenges", {}).keys():
		var ch: Dictionary = c.reading_challenges[key]
		if ch.has("supports"):
			ch.supports = ch.supports.filter(func(x): return x not in ids)
	for line in c.get("lines", []):
		line.cards = line.get("cards", []).filter(func(x): return x not in ids)
		for id in ids:
			line.get("answers", {}).erase(id)
	c["lines"] = c.get("lines", []).filter(func(line): return not line.get("cards", []).is_empty() or line.has("test_factor"))
	c["disputes"] = c.get("disputes", []).filter(func(d): return not d.get("reports", []).any(func(x): return x in ids) and d.get("challenged", "") not in ids)
	for hub in c.get("circumstantial", []):
		hub.cards = hub.get("cards", []).filter(func(x): return x not in ids)
	for key in c.get("citations", {}).keys():
		if c.citations[key] in ids:
			c.citations.erase(key)

## The listener as if every one of these cards were heard at full weight from a fully
## trusted teller, with nothing doubted. Returns [view, listener] (copies).
static func face_value(view: Dictionary, listener: Dictionary, cards: Array) -> Array:
	var l: Dictionary = listener.duplicate(true)
	if not l.has("reading_reliability"):
		l["reading_reliability"] = {}
	l["challenge_reports"] = {}
	l["challenge_sources"] = {}
	var ids: Dictionary = {}
	for card in cards:
		ids[card.id] = true
		for key in [card.get("accuracy_origin", ""), Solver.semantic_key(card), card.get("fact_id", ""), card.id]:
			if key != "":
				l.reading_reliability[key] = 1.0
	var v: Dictionary = view.duplicate(false)
	var out_cards: Array = []
	for card in view.cards:
		if ids.has(card.id) and (card.has("hearing_weight") or card.has("base_hearing_weight")):
			var c: Dictionary = card.duplicate(true)
			c["hearing_weight"] = 1.0
			c.erase("base_hearing_weight")
			out_cards.append(c)
		else:
			out_cards.append(card)
	v["cards"] = out_cards
	return [v, l]

## Can this card's teller be taken at their word in this world? A report needs a good,
## healthy source able to read then (Solver.source_valid); other testimony needs a good
## teller. Evidence with no personal source (a trace, the player's own finds) always can.
static func teller_ok(view: Dictionary, world: Dictionary, card: Dictionary, listener_id: String = "") -> bool:
	if card.get("kind", "") == "report":
		return Solver.source_valid(view, world, card)
	var source: String = str(card.get("source", ""))
	if source in ["", "player", "town", "evidence", listener_id]:
		return true
	var idx: int = Solver.person_index(view, source)
	if idx < 0:
		return true
	return (int(world.get("evil", 0)) >> idx) & 1 == 0

## For each world of the universe: does the premise hold there (`premise`), can each card's
## teller be taken at their word (`by_card_ok`, one mask per card), and can all of them
## (`all_ok`)? The premise's own subject is left out of "every teller is honest": a case
## built on their statements argues about exactly that.
## The first two read the worlds, the premise and what a card is, never how the listener
## hears it, so each mask is kept and reused while those are the same (_mask).
static func _masks(view: Dictionary, conclusion: Dictionary, cards: Array, universe: Array, listener_id: String) -> Dictionary:
	var subject: String = _premise_person(conclusion)
	# What the masks read of the view: who is in it and the worlds (the universe's key),
	# and the public record of deaths (whether a reader was alive to read).
	var about: String = "%d:%d" % [hash([Solver._universe_key(view), view.get("timeline", {})]), universe.size()]
	var premise: PackedByteArray = _mask("%s:premise:%d" % [about, hash(conclusion)], universe,
		func(world: Dictionary) -> bool: return conclusion.get("type", "") != "conflict" and Solver.holds(view, world, conclusion))
	var by_card_ok: Array = []
	for card in cards:
		# What teller_ok and Solver.source_valid read of a card. A listener takes their own
		# word for anything but a reading, so their own such card has a mask of its own.
		var sig: Array = [card.id, card.get("kind", ""), card.get("source", ""), card.get("role", ""), card.get("observed_at", {}),
			card.get("reported_at", null), card.get("testimony_only", false)]
		var mine: bool = card.get("kind", "") != "report" and str(card.get("source", "")) == listener_id
		by_card_ok.append(_mask("%s:card:%d:%s" % [about, hash(sig), listener_id if mine else ""], universe,
			func(world: Dictionary) -> bool: return teller_ok(view, world, card, listener_id)))
	var all_ok := PackedByteArray()
	all_ok.resize(universe.size())
	all_ok.fill(1)
	for j in range(cards.size()):
		if str(cards[j].get("source", "")) == subject:
			continue
		var ok: PackedByteArray = by_card_ok[j]
		for i in range(universe.size()):
			if ok[i] == 0:
				all_ok[i] = 0
	return {"premise": premise, "all_ok": all_ok, "by_card_ok": by_card_ok}

static func _mask(key: String, universe: Array, holds_in: Callable) -> PackedByteArray:
	if _mask_cache.has(key):
		return _mask_cache[key]
	var mask := PackedByteArray()
	mask.resize(universe.size())
	for i in range(universe.size()):
		mask[i] = 1 if holds_in.call(universe[i]) else 0
	if _mask_cache.size() >= MASK_CACHE_MAX:
		_mask_cache.clear()
	_mask_cache[key] = mask
	return mask

static func _premise_person(conclusion: Dictionary) -> String:
	return str(conclusion.get("target", conclusion.get("a", "")))

## +1 when the premise accuses its subject, -1 when it clears them, 0 otherwise.
static func direction(conclusion: Dictionary) -> int:
	var t: String = str(conclusion.get("type", ""))
	return 1 if t in ACCUSING else (-1 if t in CLEARING else 0)

static func _log_ratio(a: float, b: float) -> float:
	return log(maxf(a, 1e-12) / maxf(b, 1e-12))

## The whole evidence-side breakdown. listener: a CaseEval listener ({} for the neutral
## reference listener, as the Workshop's test juror). opts:
##   attended   ids this listener actually reads (omit: all of the case's cards)
##   rejected   ids its own direct checks threw out
##   held       ids it already held before this case was put to it
##   per_card   false to skip the per-card runs (world share and leave-one-out)
static func evidence(view: Dictionary, case_data: Dictionary, listener: Dictionary = {}, opts: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	if listener.is_empty():
		listener = CaseEval.neutral_listener(view)
	var compiled: Dictionary = Graph.compile_case(view, case_data)
	var cards: Array = Solver.selected(view, compiled)
	var conclusion: Dictionary = compiled.conclusion
	var listener_id: String = str(listener.get("id", ""))
	var actual: Dictionary = run(view, case_data, listener, true)
	var ev: Dictionary = actual.ev
	var out: Dictionary = {"conclusion": conclusion.duplicate(true), "impossible": bool(ev.get("impossible", false)),
		"prior": float(ev.get("prior", 0.0)), "posterior": float(ev.get("posterior", 0.0)), "lr": float(ev.get("lr", 1.0)),
		"category": str(ev.get("category", "")), "rivals": ev.get("rivals", []).duplicate(true)}
	# If every card were heard at full weight from a trusted teller.
	var fv: Array = face_value(view, listener, cards)
	var face: Dictionary = run(fv[0], case_data, fv[1], true)
	var universe: Array = Solver.universe(view)
	var subject: String = _premise_person(conclusion)
	var others: String = ""
	if cards.any(func(c): return str(c.get("source", "")) == subject and subject != ""):
		others = " but %s" % Solver.person_name(view, subject)
	var masks: Dictionary = _masks(view, conclusion, cards, universe, listener_id)
	var premise: PackedByteArray = masks.premise
	var all_ok: PackedByteArray = masks.all_ok
	var by_card_ok: Array = masks.by_card_ok
	# If, further, every teller were honest and healthy: the face-value weights restricted
	# to the worlds where they all are.
	var honest_yes: float = 0.0
	var honest_all: float = 0.0
	var fw: PackedFloat64Array = face.worlds
	for i in range(mini(fw.size(), universe.size())):
		if all_ok[i] == 1:
			honest_all += fw[i]
			if premise[i] == 1:
				honest_yes += fw[i]
	var p_honest: float = honest_yes / honest_all if honest_all > 0.0 else float(face.ev.get("posterior", 0.0))
	# The starting point is the premise with no cards at all: the listener's prior plus
	# the public record (deaths, silences), which the model folds into every case.
	var none: Dictionary = run(view, only(compiled, []), listener).ev
	var start: float = float(none.get("posterior", out.prior))
	out["start"] = start
	var has_start: bool = start > 0.0 and start < 1.0
	var versus := func(p: float) -> float: return CaseEval._odds(p) / CaseEval._odds(start) if has_start else 1.0
	var p_face: float = float(face.ev.get("posterior", 0.0))
	out["chain"] = [
		{"stage": "before", "label": "With no cards (their starting view and the public record)", "p": start, "lr": 1.0},
		{"stage": "honest", "label": "If every teller%s is honest and every card exact" % others, "p": p_honest, "lr": versus.call(p_honest)},
		{"stage": "face", "label": "Allowing that a teller may be evil or deluded", "p": p_face, "lr": versus.call(p_face),
			"loss_label": "a teller may be evil or deluded (their card then proves nothing)"},
		{"stage": "heard", "label": "As this listener hears it (hearing weight, trust, doubt)", "p": out.posterior, "lr": versus.call(out.posterior),
			"loss_label": "hearing weight, trust in the tellers and doubt"},
	]
	out["alternatives"] = _alternatives(view, conclusion, cards, universe, premise, by_card_ok, actual.worlds)
	out["cards"] = _card_rows(view, case_data, compiled, cards, listener, ev, opts, universe, by_card_ok)
	out["elapsed_ms"] = Time.get_ticks_msec() - started
	return out

static func _card_rows(view: Dictionary, case_data: Dictionary, compiled: Dictionary, cards: Array, listener: Dictionary, ev: Dictionary, opts: Dictionary, universe: Array, by_card_ok: Array) -> Array:
	var rows: Array = []
	var own_ids: Array = listener.get("knowledge", {}).get("own_reports", [])
	var attended = opts.get("attended", null)
	var rejected: Array = opts.get("rejected", [])
	var held: Array = opts.get("held", [])
	var per_card: bool = bool(opts.get("per_card", true))
	var neutral: Dictionary = CaseEval.neutral_listener(view)
	var base_worlds := PackedFloat64Array()
	if per_card:
		base_worlds = run(view, only(compiled, []), neutral, true).worlds
	for j in range(cards.size()):
		var card: Dictionary = cards[j]
		var row: Dictionary = {"id": card.id, "kind": str(card.get("kind", "")), "role": str(card.get("role", "")),
			"source": str(card.get("source", "")), "text": str(card.get("text", card.get("statement", ""))),
			"held": card.id in held, "challenged": compiled.get("reading_challenges", {}).has(card.id),
			"quoted": bool(card.get("quoted", false)) or card.id in compiled.get("quoted_cards", [])}
		# How the listener hears it.
		if row.kind == "report":
			row["reliability"] = 1.0 - CaseEval.reading_error(view, card, listener, own_ids)
			row["q_used"] = CaseEval.chance_content(view, card)
			row["q_fixed"] = row.role in CaseEval.ROLE_CONTENT_FIXED
		elif card.has("hearing_weight"):
			row["reliability"] = float(card.hearing_weight)
		if ev.get("acceptance", {}).has(card.id):
			row["accurate"] = float(ev.acceptance[card.id])
		if per_card:
			# How likely is this card's content across the worlds? The neutral listener
			# hears it alone at full weight; in the worlds where its teller can be taken at
			# their word, the weight it leaves is the chance it holds there.
			var single: Dictionary = only(compiled, [card.id])
			var fv: Array = face_value(view, neutral, [card])
			var alone: Dictionary = run(fv[0], single, fv[1], true)
			var ok: PackedByteArray = by_card_ok[j]
			var kept: float = 0.0
			var total: float = 0.0
			var n_ok: int = 0
			for i in range(mini(alone.worlds.size(), base_worlds.size())):
				if ok[i] == 1:
					n_ok += 1
					total += base_worlds[i]
					kept += alone.worlds[i]
			if total > 0.0 and not alone.ev.get("impossible", false):
				var share: float = kept / total
				if row.kind == "report" and row.has("q_used"):
					# Undo the 1% "an honest reading is still wrong" allowance the model adds.
					var err: float = CaseEval.DEFAULT_ERR
					share = (share - err * float(row.q_used)) / (1.0 - err)
				row["world_share"] = clampf(share, 0.0, 1.0)
			row["teller_ok_share"] = float(n_ok) / float(maxi(1, universe.size()))
			row["alone_lr"] = float(alone.ev.get("lr", 1.0))
			# What the premise loses without it.
			var less: Dictionary = run(view, without(case_data, card.id), listener).ev
			row["without_posterior"] = float(less.get("posterior", 0.0))
			row["without_lr"] = float(less.get("lr", 1.0))
			row["adds"] = float(ev.get("lr", 1.0)) / maxf(float(less.get("lr", 1.0)), 1e-12)
		row["status"] = _status(row, attended, rejected)
		rows.append(row)
	return rows

static func _status(row: Dictionary, attended, rejected: Array) -> String:
	if row.id in rejected:
		return "rejected"
	if attended != null and row.id not in attended:
		return "not_attended"
	if row.has("reliability") and float(row.reliability) <= NO_WEIGHT:
		return "no_weight"
	if row.has("adds"):
		var adds: float = float(row.adds)
		var negligible: bool = adds < NEGLIGIBLE_RATIO and adds > 1.0 / NEGLIGIBLE_RATIO
		var slight: bool = adds < SLIGHT_RATIO and adds > 1.0 / SLIGHT_RATIO
		if slight and float(row.get("world_share", 0.0)) >= TYPICAL_SHARE:
			return "fits_most_worlds"
		if negligible:
			return "no_effect"
		# The likelihood ratio is on the premise as stated (accusing or clearing), so a
		# card that lowers it argues against the premise either way.
		if adds < 1.0:
			return "argues_against"
	return "counted"

const STATUS_TEXT = {
	"counted": "counted",
	"fits_most_worlds": "counted, but it fits most worlds, so it says little",
	"no_effect": "counted, but changes nothing here",
	"argues_against": "counted, and argues against the premise",
	"no_weight": "heard, but given no weight (doubted or disowned)",
	"not_attended": "not attended by this listener",
	"rejected": "rejected by this listener's own checks",
}

## Where the probability went: the surviving worlds in which the premise is false.
static func _alternatives(view: Dictionary, conclusion: Dictionary, cards: Array, universe: Array, premise: PackedByteArray, by_card_ok: Array, weights: PackedFloat64Array) -> Dictionary:
	var ctype: String = str(conclusion.get("type", ""))
	var target: String = _premise_person(conclusion)
	var t_idx: int = Solver.person_index(view, target) if target != "" else -1
	var ids: Array = Solver.person_ids(view)
	var total: float = 0.0
	var left: float = 0.0
	var groups: Dictionary = {}
	var evil_instead: Dictionary = {}
	var demon_instead: Dictionary = {}
	var doubted: Dictionary = {}
	for i in range(mini(weights.size(), universe.size())):
		var w: float = weights[i]
		if w <= 0.0:
			continue
		total += w
		if premise[i] == 1:
			continue
		left += w
		var world: Dictionary = universe[i]
		var evil: int = int(world.get("evil", 0))
		for j in range(ids.size()):
			if j != t_idx and (evil >> j) & 1 == 1:
				evil_instead[ids[j]] = float(evil_instead.get(ids[j], 0.0)) + w
		var demon: int = int(world.get("demon", -1))
		if demon >= 0 and demon < ids.size() and demon != t_idx:
			demon_instead[ids[demon]] = float(demon_instead.get(ids[demon], 0.0)) + w
		# Which of this case's tellers can't be taken at their word here?
		var bad: Array = []
		for j in range(cards.size()):
			if by_card_ok[j][i] == 0:
				var s: String = str(cards[j].get("source", ""))
				if s != "" and s not in bad:
					bad.append(s)
		for s in bad:
			doubted[s] = float(doubted.get(s, 0.0)) + w
		var key: String = "other"
		if not bad.is_empty():
			key = "teller:" + bad[0]
		elif t_idx >= 0 and ctype in ["evil", "suspicious", "demon", "minion"] and (evil >> t_idx) & 1 == 0 and _is_marked(world, t_idx):
			key = "marked"
		elif t_idx >= 0 and ctype == "demon" and (evil >> t_idx) & 1 == 1:
			key = "minion"
		elif t_idx >= 0 and ctype == "minion" and (evil >> t_idx) & 1 == 1:
			key = "demon"
		groups[key] = float(groups.get(key, 0.0)) + w
	var out: Dictionary = {"left": left / total if total > 0.0 else 0.0, "groups": [], "evil_instead": [], "demon_instead": [], "doubted": []}
	if left <= 0.0:
		return out
	var t_name: String = Solver.person_name(view, target) if t_idx >= 0 else "the subject"
	for key in groups:
		var label: String = "The cards are true as told and still fit someone else"
		if key.begins_with("teller:"):
			label = "%s is evil or can't read true (so their card proves nothing)" % Solver.person_name(view, key.trim_prefix("teller:"))
		elif key == "marked":
			label = "%s is good but Marked, and only registers as evil" % t_name
		elif key == "minion":
			label = "%s is evil, but a Minion, not the Demon" % t_name
		elif key == "demon":
			label = "%s is evil, but the Demon, not a Minion" % t_name
		out.groups.append({"key": key, "share": groups[key] / left, "label": label})
	out.groups.sort_custom(func(a, b): return a.share > b.share if not is_equal_approx(a.share, b.share) else a.key < b.key)
	out.evil_instead = _ranked(evil_instead, left)
	out.demon_instead = _ranked(demon_instead, left)
	out.doubted = _ranked(doubted, left)
	return out

static func _is_marked(world: Dictionary, idx: int) -> bool:
	if str(world.get("modifier", "marked")) != "marked":
		return false
	if world.has("holders"):
		return (int(world.holders) >> idx) & 1 == 1
	return int(world.get("marked", -1)) == idx

static func _ranked(masses: Dictionary, left: float, limit: int = 4) -> Array:
	var keys: Array = masses.keys()
	keys.sort_custom(func(a, b): return masses[a] > masses[b] if not is_equal_approx(masses[a], masses[b]) else a < b)
	return keys.slice(0, limit).map(func(k): return {"id": k, "share": masses[k] / left})

## The largest single drop along a chain of {stage, label, value} rows, as
## {from, to, label, loss}; {} when nothing drops.
static func biggest_loss(chain: Array, field: String) -> Dictionary:
	var best: Dictionary = {}
	for i in range(1, chain.size()):
		var loss: float = float(chain[i - 1][field]) - float(chain[i][field])
		if loss > float(best.get("loss", 1e-9)):
			best = {"from": chain[i - 1].stage, "to": chain[i].stage, "label": str(chain[i].get("loss_label", chain[i].label)), "loss": loss}
	return best

## The strongest surviving alternative, in a sentence ("" when the premise is settled).
static func strongest_alternative(view: Dictionary, breakdown: Dictionary) -> String:
	var alt: Dictionary = breakdown.get("alternatives", {})
	if alt.get("groups", []).is_empty() or float(alt.get("left", 0.0)) < 0.005:
		return ""
	var top: Dictionary = alt.groups[0]
	var line: String = "%s (%d%% of what's left)" % [top.label, roundi(100.0 * float(top.share))]
	var who: Array = alt.demon_instead if str(breakdown.get("conclusion", {}).get("type", "")) in ["demon", "notdemon"] else alt.evil_instead
	if top.key == "other" and not who.is_empty():
		line = "The cards fit %s just as well (%s in %d%% of what's left)" % [Solver.person_name(view, who[0].id),
			"the Demon" if who == alt.demon_instead else "evil", roundi(100.0 * float(who[0].share))]
	return line

## Plain-text readout of an evidence() result.
static func describe(view: Dictionary, b: Dictionary, numbers: Dictionary = {}) -> String:
	var lines: PackedStringArray = []
	var c: Dictionary = b.conclusion
	var subject: String = _premise_person(c)
	lines.append("Premise: %s %s" % [Solver.person_name(view, subject) if Solver.person_index(view, subject) >= 0 else "(case)", str(c.get("type", ""))])
	if b.get("impossible", false):
		lines.append("No world survives these cards together: something here must be false.")
	lines.append("Chance the premise is true, step by step:")
	for step in b.chain:
		lines.append("  %-58s %5.1f%%   (strength x%s)" % [step.label, 100.0 * float(step.p), _ratio(float(step.lr))])
	var drop: Dictionary = biggest_loss(b.chain.slice(1), "p")
	if not drop.is_empty():
		lines.append("  Biggest loss: %s (-%.1f points)" % [drop.label.to_lower(), 100.0 * float(drop.loss)])
	var alt: String = strongest_alternative(view, b)
	if alt != "":
		lines.append("What's left (%.1f%%) is mostly: %s" % [100.0 * float(b.alternatives.left), alt])
		for g in b.alternatives.groups.slice(1, 4):
			if float(g.share) >= 0.01:
				lines.append("  also: %s (%d%%)" % [g.label, roundi(100.0 * float(g.share))])
	lines.append("Cards:")
	for row in b.cards:
		var n: String = "#%d " % int(numbers[row.id]) if numbers.has(row.id) else ""
		var head: String = "  %s%s%s: %s" % [n, row.source.capitalize() if row.source != "" else "(record)",
			" " + row.role if row.role != "" else " " + row.kind, STATUS_TEXT.get(row.status, row.status)]
		if row.get("held", false):
			head += " [already held]"
		lines.append(head)
		var bits: PackedStringArray = []
		if row.has("world_share"):
			bits.append("holds in %d%% of worlds" % roundi(100.0 * float(row.world_share)))
		if row.has("q_used"):
			bits.append("model's chance a false report says this: %d%%%s" % [roundi(100.0 * float(row.q_used)), " (fixed)" if row.get("q_fixed", false) else ""])
		if row.has("reliability"):
			bits.append("heard at %.2f" % float(row.reliability))
		if row.has("accurate"):
			bits.append("judged accurate %d%%" % roundi(100.0 * float(row.accurate)))
		if row.has("adds"):
			bits.append("premise strength x%s with it" % _ratio(float(row.adds)))
		if not bits.is_empty():
			lines.append("      " + "; ".join(bits))
		if row.text != "":
			lines.append("      \"%s\"" % row.text.substr(0, 110))
	return "\n".join(lines)

static func _ratio(lr: float) -> String:
	if lr >= 100.0:
		return "%.0f" % lr
	return "%.2f" % lr

## Shared by the conversation modules (`mind_dialogue`, `mind_press`, `mind_answers`): their
## preloads and constants, lazy loaders for each other, and the delegates to `Mind`. Each
## module extends this script, so these are callable bare.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Observations = preload("res://sim/dialogue_observations.gd")
const Burdens = preload("res://sim/burdens.gd")
static var _mind_script
static var _dialogue_script
static var _press_script
static var _answers_script



## Phrases in an alibi line that already answer "who did you see?" with nobody.
const SAW_NOBODY_MARKERS = ["see a soul", "saw a soul", "saw nobody", "saw no one", "seen nobody", "didn't see anyone", "didn't see anybody"]

static func _mind():
	if _mind_script == null:
		_mind_script = load("res://sim/mind.gd")
	return _mind_script


const GREET_COLD_EXP = {
	"agnes": "concerned", "dorian": "concerned", "isolde": "concerned", "merrin": "concerned",
}
const GREET_MURDER_EXP = {
	"isolde": "sorrowful", "greta": "harsh",
}
const GREET_EXEC_EXP = {
	"bart": "neutral", "greta": "neutral", "kiran": "neutral", "lian": "neutral",
	"nisha": "neutral", "jory": "concerned",
}
const GREET_FRICTION_EXP = {
	"dorian": "concerned", "isolde": "concerned",
}
const WORD_DOUBT_BELOW = Tuning.Dialogue.WORD_DOUBT_BELOW
const OPINION_BONDED = {
	"opinion_friend_clear": "%s is a friend of mine, and I don't believe they're evil.",
	"opinion_friend_suspect": "%s is a friend of mine, and it pains me, but I have my doubts about them.",
	"opinion_rival_clear": "%s and I have never got on, but I don't take them for a killer.",
	"opinion_rival_suspect": "%s and I have never got on, so weigh this as you will, but I have my doubts about them.",
}


static func _dialogue():
	if _dialogue_script == null:
		_dialogue_script = load("res://sim/mind_dialogue.gd")
	return _dialogue_script

static func _press():
	if _press_script == null:
		_press_script = load("res://sim/mind_press.gd")
	return _press_script

static func _answers():
	if _answers_script == null:
		_answers_script = load("res://sim/mind_answers.gd")
	return _answers_script

# ---------------------------------------------------------------- Mind delegates

static func _append_distrust(w, n, lines: Array) -> void:
	_mind()._append_distrust(w, n, lines)

static func _challenged(n, response: Dictionary, card: Dictionary) -> Dictionary:
	return _mind()._challenged(n, response, card)

static func _unshared_fake_on(n, t_id: String) -> Dictionary:
	return _mind()._unshared_fake_on(n, t_id)

static func card_weight_against(w, card: Dictionary, target_id: String) -> float:
	return _mind().card_weight_against(w, card, target_id)

static func citable_reason(w, n, t_id: String, audience: String = "town") -> String:
	return _mind().citable_reason(w, n, t_id, audience)

## RoleDef.honest_outing for the asker's real role, decided once per night asked and day
## (so the reveal/withhold branches above agree, and asking twice gets one answer). A
## refusal is reconsidered once their pressure has risen or they've been nominated since
## (Codex review of PR #69: a press with evidence must be able to change a refusal).
static func _honest_outing(w, n, nd: int) -> String:
	if n.is_evil() or not C.has_role_def(n.role):
		return ""
	var memo: Dictionary = n.dialogue_memory.get("honest_outing", {})
	var key: String = "%d:%d" % [nd, w.day]
	var nominated: bool = n.id in w.meeting.get("nominated", []) or str(w.meeting.get("block", "")) == n.id
	var prev = memo.get(key)
	var stale: bool = prev is Dictionary and prev.v == "withhold" and (n.pressure > float(prev.p) + 1e-6 or (nominated and not prev.nom))
	if prev == null or stale:
		memo[key] = {"v": C.role_def(n.role).honest_outing(w, n, nd, _mind(), false), "p": n.pressure, "nom": nominated}
		n.dialogue_memory["honest_outing"] = memo
	var got = memo[key]
	return str(got.v) if got is Dictionary else str(got)


static func decide(w, n, topic: String, parts: Dictionary, why: String) -> bool:
	return _mind().decide(w, n, topic, parts, why)

static func evil_override(w, n, act: String, stakes: float, deviation: float, detail: String) -> bool:
	return _mind().evil_override(w, n, act, stakes, deviation, detail)

static func fact_id(card: Dictionary) -> String:
	return _mind().fact_id(card)

static func info_fact(w, n, e: Dictionary) -> Dictionary:
	return _mind().info_fact(w, n, e)

static func info_lines(w, n, entries: Array, audience: String = "player", preceded: bool = false, speech_act: String = "answer") -> Array:
	return _mind().info_lines(w, n, entries, audience, preceded, speech_act)

static func ledger_hear(w, n, eid: String, _effects: Array = [], weight: float = 1.0, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	return _mind().ledger_hear(w, n, eid, [], weight, rel, meta)

static func paranoia(w, n) -> float:
	return _mind().paranoia(w, n)

static func reason_status(w, n, t_id: String) -> Dictionary:
	return _mind().reason_status(w, n, t_id)

static func reveal_cost(w, n) -> Dictionary:
	return _mind().reveal_cost(w, n)

static func say(n, text: String) -> Dictionary:
	return _mind().say(n, text)

static func say_voiced(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	return _mind().say_voiced(n, key, fallback, slots)

static func set_trust(w, n, value: float, why: String) -> void:
	_mind().set_trust(w, n, value, why)

static func shadow_eval(w, n, f: Callable):
	return _mind().shadow_eval(w, n, f)

static func susp(n, target_id: String) -> float:
	return _mind().susp(n, target_id)

static func trait_of(n, t: String) -> float:
	return _mind().trait_of(n, t)

static func voiced(n, kind: String, statement: String, event_id: String = "", context: Dictionary = {}) -> Dictionary:
	return _mind().voiced(n, kind, statement, event_id, context)

static func whereabouts_refusal(n, nd: int) -> Dictionary:
	return _mind().whereabouts_refusal(n, nd)

static func gift_refusal(n) -> Dictionary:
	return _mind().gift_refusal(n)

static func home_alibi(w, n, nd: int) -> Dictionary:
	return _mind().home_alibi(w, n, nd)

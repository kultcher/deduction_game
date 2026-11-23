## Shared by the town-meeting modules (`mind_meeting`, `mind_nomination`, `mind_defence`,
## `mind_vote`): their preloads, the consensus constants, lazy loaders for each other, and the
## delegates to `Mind`. Each module extends this script, so these are callable bare.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Recency = preload("res://sim/recency.gd")
const Connections = preload("res://workshop/connections.gd")
const Burdens = preload("res://sim/burdens.gd")
const CaseGraph = preload("res://workshop/case_graph.gd")
static var _mind_script

const CONSENSUS_BASE = Tuning.Meeting.CONSENSUS_BASE
const CONSENSUS_FADE = Tuning.Meeting.CONSENSUS_FADE
const CONSENSUS_CAP = Tuning.Meeting.CONSENSUS_CAP
const CONSENSUS_HINT = Tuning.Meeting.CONSENSUS_HINT  # "I have a reason, but I'm not ready to share it": a little more than a bare accusation

static var _meeting_script
static var _nomination_script
static var _defence_script
static var _vote_script


static func _mind():
	if _mind_script == null:
		_mind_script = load("res://sim/mind.gd")
	return _mind_script


static func _meeting():
	if _meeting_script == null:
		_meeting_script = load("res://sim/mind_meeting.gd")
	return _meeting_script

static func _nomination():
	if _nomination_script == null:
		_nomination_script = load("res://sim/mind_nomination.gd")
	return _nomination_script

static func _defence():
	if _defence_script == null:
		_defence_script = load("res://sim/mind_defence.gd")
	return _defence_script

static func _vote():
	if _vote_script == null:
		_vote_script = load("res://sim/mind_vote.gd")
	return _vote_script

# ---------------------------------------------------------------- Mind delegates

static func _add_observation(groups: Array, observation: Dictionary) -> void:
	_mind()._add_observation(groups, observation)

static func _afraid(w, n) -> bool:
	return _mind()._afraid(w, n)

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool, first_relation: String = "independent") -> Array:
	return _mind()._observation_lines(n, groups, audience, speech_act, preceded, first_relation)

static func action_susp(n, id: String) -> float:
	return _mind().action_susp(n, id)

static func apply_info(w, listener, source, entry: Dictionary, weight: float, via: String = "", anonymous: bool = false, public: bool = false) -> void:
	_mind().apply_info(w, listener, source, entry, weight, via, anonymous, public)

static func decide(w, n, topic: String, parts: Dictionary, why: String) -> bool:
	return _mind().decide(w, n, topic, parts, why)

static func decision_line(n, approved: Dictionary, audience: String = "player") -> Dictionary:
	return _mind().decision_line(n, approved, audience)

static func evil_override(w, n, act: String, stakes: float, deviation: float, detail: String) -> bool:
	return _mind().evil_override(w, n, act, stakes, deviation, detail)

static func execution_priority(n, id: String) -> float:
	return _mind().execution_priority(n, id)

static func execution_priority_contribution(n, id: String) -> float:
	return _mind().execution_priority_contribution(n, id)

static func flush_beliefs(w, only = null) -> void:
	_mind().flush_beliefs(w, only)

static func hear_claim(w, l, who: String, role: String, weight: float, how: String, original: Dictionary = {}) -> void:
	_mind().hear_claim(w, l, who, role, weight, how, original)

static func heard_weight(listener, speaker) -> float:
	return _mind().heard_weight(listener, speaker)

static func implicated(e: Dictionary) -> Array:
	return _mind().implicated(e)

static func info_eid(src: String, entry: Dictionary) -> String:
	return _mind().info_eid(src, entry)

static func ledger_hear(w, n, eid: String, _effects: Array = [], weight: float = 1.0, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	return _mind().ledger_hear(w, n, eid, [], weight, rel, meta)

static func paranoia(w, n) -> float:
	return _mind().paranoia(w, n)

static func ranked_suspects(w, n, social_pressure: bool = false) -> Array:
	return _mind().ranked_suspects(w, n, social_pressure)

static func refresh_beliefs(w, n, note: String) -> void:
	_mind().refresh_beliefs(w, n, note)

static func reconsider(w, n, why: String) -> void:
	_mind().reconsider(w, n, why)

static func say(n, text: String) -> Dictionary:
	return _mind().say(n, text)

static func say_voiced(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	return _mind().say_voiced(n, key, fallback, slots)

static func shadow_eval(w, n, f: Callable):
	return _mind().shadow_eval(w, n, f)

static func shadow_run(w, n, f: Callable) -> void:
	_mind().shadow_run(w, n, f)

static func sighting_report(w, n, b: Dictionary, nd: int) -> Dictionary:
	return _mind().sighting_report(w, n, b, nd)

static func susp(n, target_id: String) -> float:
	return _mind().susp(n, target_id)

static func trait_of(n, t: String) -> float:
	return _mind().trait_of(n, t)

static func voiced(n, kind: String, statement: String, event_id: String = "", context: Dictionary = {}) -> Dictionary:
	return _mind().voiced(n, kind, statement, event_id, context)

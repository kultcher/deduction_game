## Base class for role descriptors and role-specific simulation hooks.
##
## Architecture boundary:
## - `sim/` (cold/warm paths: once per night, dialogue turn, or reading heard) calls
##   method hooks on RoleDef subclasses (`sim/roles/<role>.gd`).
## - `workshop/` (hot 5,040-world bitmask loops) reads declarative shape fields
##   (`shape`, `marked_registers`, `red_herring_registers`, `role_group_key`,
##   `role_target_pool`, `site_mode`, `site_group_key`, `count_mode`, etc.) without
##   per-world virtual dispatch.
extends RefCounted

# Core identity & script metadata (mirrors C.ROLES dictionary entries)
var id: String = ""
var display_name: String = ""
var align: String = "good"
var kind: String = "info"
var desc: String = ""
var first_night: bool = false
var night_walk: bool = false
var day: bool = false
var minion: bool = false

# Reading shape & solver metadata
# Shapes: "GROUP_COUNT", "ROLE_AT_SITE", "PING", "ROLE_IN_GROUP", "SECRET_PAIR", "SOCIAL_PAIR", "NIGHT_ROUTE", "NIGHT_EVENT", "NONE"
var shape: String = "NONE"
var produces_readings: bool = false
var marked_registers: bool = false
var red_herring_registers: bool = false
var can_cause_quiet_night: bool = false
var quiet_night_effect: float = 0.0
var requires_execution: bool = false

# World & evil AI declarative metadata
var cannot_hold_solo_secret: bool = false
var conversation_nudge: float = 0.0
var hard_to_kill: bool = false
var public_threat_bonus: float = 0.0
var public_threat_key: String = ""

# ROLE_IN_GROUP shape parameters:
# - role_group_key: "pair" (2-person array in data["pair"]) or "executed" (1-person id in data["executed"])
# - role_target_pool: "good" (Clerk), "minion" (Archivist), "demon", or "any" (Gravedigger)
var role_group_key: String = "pair"
var role_target_pool: String = "good"

# ROLE_AT_SITE shape parameters:
# - site_mode: "group_count" (Dowser: crowd on a block; Hearthwitch: living lane neighbours)
#              or "hearth_relay" (Medium: visits a dead victim's hearth and relays one item)
# - site_group_key: "group" (Dowser) or "nbrs" (Hearthwitch)
var site_mode: String = "group_count"
var site_group_key: String = "group"

# GROUP_COUNT shape parameters:
# - count_mode: "group" (subset in group/nbrs), "blocks" (Surveyor: blocks with evil resident),
#               or "walkers" (Lamplighter: other people out at night)
var count_mode: String = "group"

# Player gift-request agreement template ("" if role does not take night requests)
var request_agree_line: String = ""

static var _content_script


static func content():
	if _content_script == null:
		_content_script = load("res://sim/content.gd")
	return _content_script


func to_role_dict() -> Dictionary:
	var out: Dictionary = {
		"name": display_name,
		"align": align,
		"kind": kind,
		"desc": desc,
	}
	if first_night:
		out["first_night"] = true
	if night_walk:
		out["night_walk"] = true
	if day:
		out["day"] = true
	if minion:
		out["minion"] = true
	return out


func has_readings() -> bool:
	return kind == "info" or produces_readings


static func group_of(d: Dictionary) -> Array:
	return d.get("group", d.get("nbrs", []))


static func _names(ids: Array, nm: Callable) -> String:
	return " / ".join(PackedStringArray(ids.map(nm)))


func _role_group_list(d: Dictionary) -> Array:
	if role_group_key == "pair":
		return d.get("pair", [])
	return [d[role_group_key]] if d.has(role_group_key) else []


# ---------------------------------------------------------------- reading semantics (gifts.gd)

## People the reading points toward evil (shape-driven default; override for bespoke roles).
func implicated(d: Dictionary) -> Array:
	match shape:
		"PING":
			return d.get("pair", []) if d.get("yes", false) else []
		"GROUP_COUNT":
			if count_mode == "group":
				return group_of(d) if d.get("count", 0) > 0 else []
		"ROLE_AT_SITE":
			if site_mode == "group_count":
				return group_of(d) if d.get("count", 0) > 0 else []
		"ROLE_IN_GROUP":
			if role_target_pool in ["minion", "demon"]:
				return _role_group_list(d)
			if role_target_pool == "good":
				return []
			var r_align: String = content().ROLES.get(d.get("role", ""), {}).get("align", "good")
			return _role_group_list(d) if r_align == "evil" else []
		"NIGHT_ROUTE":
			return d.get("seen", [])
	return []


## People the reading speaks for (shape-driven default; override for bespoke roles).
func clears(d: Dictionary) -> Array:
	match shape:
		"PING":
			return [] if d.get("yes", false) else d.get("pair", [])
		"SECRET_PAIR":
			return d.get("pair", [])
		"GROUP_COUNT":
			if count_mode == "group":
				return group_of(d) if d.get("count", 0) == 0 else []
		"ROLE_AT_SITE":
			if site_mode == "group_count":
				return group_of(d) if d.get("count", 0) == 0 else []
		"ROLE_IN_GROUP":
			if role_target_pool == "good":
				return _role_group_list(d)
			if role_target_pool in ["minion", "demon"]:
				return []
			var r_align: String = content().ROLES.get(d.get("role", ""), {}).get("align", "good")
			return _role_group_list(d) if r_align == "good" else []
	return []


## One-line summary for the board (override per role or use shape default).
func short_text(_d: Dictionary, src: String, _nm: Callable) -> String:
	return "%s %s reading" % [src, display_name]


# ---------------------------------------------------------------- belief & social weights (mind.gd)

## How strongly one reading points at t_id (0..1) when deciding what to cite or disclose.
func reading_strength(d: Dictionary, t_id: String) -> float:
	match shape:
		"PING":
			return 0.9 if d.get("yes", false) else 0.0
		"GROUP_COUNT":
			if count_mode == "group":
				var g: Array = group_of(d)
				return clampf(0.9 * d.get("count", 0) / maxf(1.0, g.size()), 0.0, 0.8) if t_id in g else 0.0
		"ROLE_AT_SITE":
			if site_mode == "group_count":
				var g: Array = group_of(d)
				return clampf(0.9 * d.get("count", 0) / maxf(1.0, g.size()), 0.0, 0.8) if t_id in g else 0.0
		"NIGHT_ROUTE":
			return 0.35
	return 0.3


## How incriminating a board info card is on its own (0..1.4), before credibility and trust.
func card_strength(d: Dictionary, suspect_id: String) -> float:
	if suspect_id in implicated(d):
		return 0.6
	return 0.0


## How strongly an info card speaks *for* a nominee during defence.
func defend_strength(d: Dictionary, nominee: String) -> float:
	if nominee in clears(d):
		return 0.5
	return 0.15


## Belief effects when `listener` hears `entry` from `source`.
func info_effects(_w, _listener, _source, _entry: Dictionary, _weight: float, _fresh: bool, _mind) -> Array:
	return []


# ---------------------------------------------------------------- night choices, day gifts & world events (mind.gd / world.gd / evil.gd)

## World setup hook called at case creation when this role is in play.
func setup_world(_w, _holder) -> void:
	pass


## Daytime gift execution hook called in `World._day_gifts()`.
func run_day_gift(_w, _holder, _mind, _evil) -> void:
	pass


## Whether poisoning a public claimant of this role tonight would stop anything (`Evil.gift_live_tonight`).
func gift_live_tonight(w, _n) -> bool:
	if first_night:
		return w.day == 0
	if requires_execution:
		return w.executed_today != ""
	return true


## Night or day target selection hook for good holders.
func pick_targets(_w, _n, _mind):
	return null


## Adjust decision parts when the player asks `n` to use this gift on `targets` tonight.
func score_gift_request(_w, _n, _targets: Array, _top: String, _parts: Dictionary, _mind) -> void:
	pass


## Optional counter-proposal line when `n` refuses the player's gift request but trusts them.
func counter_gift_request(_w, _n, _targets: Array, _top: String) -> String:
	return ""


## Format target names for player gift requests.
func request_target_text(w, targets: Array, _block_name_fn: Callable) -> String:
	return " and ".join(PackedStringArray(targets.map(func(t): return w.by_id[t].name)))


## Hook called in Evil.make_fake_info when an evil bluffer has an agreed player request tonight.
func on_evil_agreed_request(_w, _n, _asked: Array) -> void:
	pass


## Whether a good holder `v` survives a demon attack through their own gift (`World.attack_outcome`).
func survives_demon_attack(_v) -> bool:
	return false


## Hook called when a holder survives a demon attack (`World._veteran_survives`).
func on_survive_attack(_w, _v) -> void:
	pass


## Hook called when the Sexton considers tolling the death knell in the evening.
func try_knell(_w, _sx, _mind) -> bool:
	return false


## Whether `holder` substitutes for `target_id` at the gallows (`World.execute`).
func can_substitute_execution(_w, _holder, _target_id: String) -> bool:
	return false


## Execute gallows substitution when `holder` dies in `saved`'s place (`World._martyr_dies`).
func on_substitute_execution(_w, _holder, _saved, _res: Dictionary, _mind) -> void:
	pass


## Hook called on a living Martyr when someone is executed without substitution (`World.execute`).
func on_chosen_executed(_w, _holder, _executed_npc) -> void:
	pass


## Hook called when a holder of this role is executed (`World.execute`, e.g. Revenant curse).
func on_executed(_w, _n, _res: Dictionary, _mind) -> void:
	pass


## Whether an evil teammate `v` should vote to let `nom_n` hang (`Evil.evil_vote`, e.g. Revenant with totem).
func should_evil_vote_to_hang(_w, _nom_n, _v) -> bool:
	return false


## Whether `holder` rises to replace an executed Demon (`World.execute`, e.g. Scion).
func can_promote_to_demon(_holder, _alive_before: int) -> bool:
	return false


## Promote `holder` to Demon (`World._scion_rises`).
func promote_to_demon(_w, _holder) -> void:
	pass


# ---------------------------------------------------------------- alibis, sightings & gift answers (mind.gd)

## Whether `n` has a logged gift outing on `night` (used by Mind._gift_outing).
func has_gift_outing(_n, _night: int) -> bool:
	return false


## Whether an evil bluffer claiming this role can volunteer a night sighting `b`.
func public_sighting_allowed(_w, _n, _b: Dictionary) -> bool:
	return false


## Optional custom handler for `Mind.answer_gift` (returns {} to use standard reading disclosure).
func answer_gift_custom(_w, _n, _first_time: bool, _tier: int, _lines: Array, _facts: Array, _mind, _night_name_fn: Callable, _block_name_fn: Callable) -> Dictionary:
	return {}


## Whether this role overrides `Mind.answer_night` when claimed.
func uses_night_duty_alibi(_w, _n, _nd: int, _was_out: bool) -> bool:
	return false


## Optional custom handler for `Mind.answer_night` when claiming this role.
## Returns {} if this role does not override night whereabouts alibis.
func night_duty_alibi(_w, _n, _nd: int, _was_out: bool, _block: String, _mind, _block_name_fn: Callable) -> Dictionary:
	return {}


# ---------------------------------------------------------------- reading generation & bluffs (world.gd / evil.gd)

## Produce tonight's real reading entry for `n` in `World._receive_info` ({} if none).
func generate_reading(_w, _n, _ctx: Dictionary, _mind) -> Dictionary:
	return {}


## Produce tonight's fake reading entry and devlog reason `{"entry": ..., "why": ...}` in `Evil.make_fake_info`.
func generate_bluff_reading(_w, _n, _plan: Dictionary, _scapegoat: String, _mate, _asked: Array) -> Dictionary:
	return {}


## Produce a fake Medium relay item `{"entry": ..., "why": ..., "frames": bool}` for a dead holder `dd`.
func fake_medium_reading(_w, _n, _dd, _s: String, _sg, _d, _goods: Array, _other: Callable, _e: Dictionary, _demon_implicated: bool) -> Dictionary:
	return {}

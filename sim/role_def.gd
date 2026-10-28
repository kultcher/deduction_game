## Base class for modularized Role definitions in Demonologist.
##
## Architecture:
## - `sim/` (cold/warm paths: once per night, dialogue turn, or reading heard) calls
##   method hooks on RoleDef subclasses (`sim/roles/<role>.gd`).
## - `workshop/` (hot 5,040-world bitmask loops) reads declarative shape fields
##   (`shape`, `marked_registers`, `red_herring_registers`, `role_group_key`,
##   `role_target_pool`, `site_mode`, `site_group_key`, `count_mode`, etc.) once outside the loop.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")

# Core identity & script metadata (mirrors C.ROLES dictionary entries)
var id: String = ""
var display_name: String = ""
var align: String = "good"        # "good" | "evil"
var kind: String = "info"         # "info" | "protect" | "passive" | "evil"
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
var quiet_night_claim_weight: float = 0.0
var quiet_night_once: bool = false
var requires_execution: bool = false
var evening_or_night: bool = false
var min_gift_day: int = 0

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


func is_ongoing_info() -> bool:
	return kind == "info" and not first_night and not requires_execution


func names_good_role_in_pair() -> bool:
	return shape == "ROLE_IN_GROUP" and role_group_key == "pair" and role_target_pool == "good"


func is_valid_gift_time(observed_at: Dictionary) -> bool:
	if id == "hearthwitch" or align != "good":
		return false
	if evening_or_night:
		return observed_at.day >= min_gift_day and observed_at.phase in ["evening", "night"]
	if day:
		return observed_at.day >= min_gift_day and observed_at.phase in ["morning", "afternoon", "evening"]
	if first_night:
		return observed_at.day == 0 and observed_at.phase == "night"
	return observed_at.day >= min_gift_day and observed_at.phase == "night"


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


## One-line summary for the case board and logs.
func short_text(_d: Dictionary, src: String, _nm: Callable) -> String:
	return "%s %s reading" % [src, display_name]


# ---------------------------------------------------------------- belief & social weights (mind.gd)

## How strongly an NPC's own reading implicates `t_id` (0..1) when deciding whether to reveal.
func reading_strength(d: Dictionary, t_id: String) -> float:
	match shape:
		"PING":
			return Tuning.Roles.PING_YES_READING_STRENGTH if d.get("yes", false) else 0.0
		"GROUP_COUNT":
			if count_mode == "group":
				var g: Array = group_of(d)
				return clampf(Tuning.Roles.GROUP_READING_STRENGTH_SCALE * d.get("count", 0) / maxf(1.0, g.size()), 0.0, Tuning.Roles.GROUP_READING_STRENGTH_CAP) if t_id in g else 0.0
		"ROLE_AT_SITE":
			if site_mode == "group_count":
				var g: Array = group_of(d)
				return clampf(Tuning.Roles.GROUP_READING_STRENGTH_SCALE * d.get("count", 0) / maxf(1.0, g.size()), 0.0, Tuning.Roles.GROUP_READING_STRENGTH_CAP) if t_id in g else 0.0
		"NIGHT_ROUTE":
			return Tuning.Roles.NIGHT_ROUTE_READING_STRENGTH
	return Tuning.Roles.DEFAULT_READING_STRENGTH


## How strongly a board `info` card speaks against `suspect_id` (0..1).
func card_strength(d: Dictionary, suspect_id: String) -> float:
	if suspect_id in implicated(d):
		return Tuning.Roles.DEFAULT_CARD_STRENGTH
	return 0.0


## How strongly a board `info` card speaks for `nominee` (0..1).
func defend_strength(d: Dictionary, nominee: String) -> float:
	if nominee in clears(d):
		return Tuning.Roles.DEFAULT_DEFEND_STRENGTH
	return Tuning.Roles.FALLBACK_DEFEND_STRENGTH


## Native suspicion effects (`[[who_id, delta, can_cite, internal_tag, spoken_reason], ...]`)
## when `listener` hears `entry` from `source`. May also apply side-effects (e.g. `listener.cleared`,
## `Mind.set_trust` on Gravedigger confirmation).
func info_effects(_w, _listener, _source, _entry: Dictionary, _weight: float, _fresh: bool, _mind) -> Array:
	return []


## Role-specific terms when `n` decides whether to publicly claim this role at a meeting (`Mind._public_claim_decision`).
func score_public_claim(w, _n, parts: Dictionary) -> void:
	if kind != "info":
		parts["hides_from_demon"] = Tuning.Roles.HIDE_FROM_DEMON_CLAIM
	if is_ongoing_info() and w.day <= 2:
		parts["gift_keeps_giving"] = Tuning.Roles.ONGOING_INFO_EARLY_CLAIM
	elif first_night:
		parts["one_shot_gift"] = Tuning.Roles.ONE_SHOT_GIFT_CLAIM


## Role-specific terms when `n` weighs the cost of revealing their gift (`Mind.reveal_cost`).
func score_reveal_cost(w, _n, parts: Dictionary) -> void:
	if kind != "info":
		parts["hides_from_demon"] = -Tuning.Roles.HIDE_FROM_DEMON_CLAIM
	if is_ongoing_info() and w.day <= 2:
		parts["gift_keeps_giving"] = -Tuning.Roles.ONGOING_INFO_EARLY_CLAIM


## Role-specific terms when `n` computes their gift disclosure tier (`Mind._target_tier`).
func score_disclosure_tier(w, _n, gift_terms: Dictionary) -> void:
	if kind != "info":
		gift_terms["hides_from_demon"] = Tuning.Roles.HIDE_FROM_DEMON_CLAIM
	if is_ongoing_info() and w.day <= 2:
		gift_terms["gift_keeps_giving"] = Tuning.Roles.ONGOING_INFO_EARLY_CLAIM
	elif first_night:
		gift_terms["one_shot_gift"] = Tuning.Roles.ONE_SHOT_GIFT_CLAIM


## Role-specific vote reluctance when `v` votes on `nominee` (`Mind._vote_impl`, e.g. Martyr).
func score_vote_reluctance(_w, _v, _nominee: String, _base: float, _panic: float, _parts: Dictionary) -> void:
	pass


## Role-specific reading defence when `d` defends against a reading `rd` by `src` (`Mind.defend`, e.g. Seer red herring).
func try_reading_defence(_w, _d, _src, _src_id: String, _rd: Dictionary, _mind, _workshop_ledger) -> Dictionary:
	return {}


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


## Score modifiers for `Mind.consider_gift_request` when the player asks `n` to use their gift on `targets`.
func score_gift_request(_w, _n, _targets: Array, _top: String, _parts: Dictionary, _mind) -> void:
	pass


## Counter-proposal line when `n` refuses the player's gift request because they prefer `top`.
func counter_gift_request(_w, _n, _targets: Array, _top: String) -> String:
	return ""


## Format `targets` for the player's gift request prompt/response.
func request_target_text(w, targets: Array, _block_name_fn: Callable) -> String:
	return " and ".join(PackedStringArray(targets.map(func(t): return w.by_id[t].name)))


## Generate a night/day reading entry (`{data, true, text, why?}`) for a good holder `n`.
func generate_reading(_w, _n, _ctx: Dictionary, _mind) -> Dictionary:
	return {}


## Generate a fabricated bluff reading entry (`{entry: {data, text}, why: String}`) for an evil bluffer `n`.
func generate_bluff_reading(_w, _n, _plan: Dictionary, _s: String, _mate, _asked: Array) -> Dictionary:
	return {}


## Hook called in `Evil.make_fake_info` when an evil bluffer has agreed to a player gift request.
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


## Pre-gate check in `Mind._public_sighting_allowed` before standard night-account checks.
## Returns 0 for no pre-gate, 1 to allow immediately, or -1 to disallow immediately.
func check_public_sighting_pregate(_w, _n, _b: Dictionary, _mind) -> int:
	return 0


## Whether an evil bluffer claiming this role can publicly volunteer sighting `b` at a meeting.
func public_sighting_allowed(_w, _n, _b: Dictionary) -> bool:
	return false


## Custom tier-4 gift answer (e.g. Warden reporting guarded doors instead of info_log readings).
## Returns `{}` if standard `info_log` reading disclosure should run, or `{"lines": ..., "facts": ...}` if handled.
func answer_gift_custom(_w, _n, _first_time: bool, _tier: int, _lines: Array, _facts: Array, _mind, _night_name_fn: Callable, _block_name_fn: Callable) -> Dictionary:
	return {}


## Whether a claimant of this role uses their night-duty alibi on night `nd`.
func uses_night_duty_alibi(_w, _n, _nd: int, _was_out: bool) -> bool:
	return false


## Night-whereabouts alibi for a claimant of this role on night `nd`.
## Returns `{"handled": true, "line": Dictionary, "fact": Dictionary, "vantage": String, "how": String}` or `{}`.
func night_duty_alibi(_w, _n, _nd: int, _was_out: bool, _block: String, _mind, _block_name_fn: Callable) -> Dictionary:
	return {}


## If non-empty, withholds night sightings in `Mind.answer_night` with the returned spoken line (e.g. undisclosed Night Watch report).
func withholds_night_sightings(_n, _nd: int, _mind) -> String:
	return ""


## Optional override for `reported` night sightings in `Mind.answer_night` (e.g. evil Night Watch matching fake watch report).
func override_night_sightings(_w, _n, _nd: int) -> Dictionary:
	return {}


## Pressed-night reconfirmation line for a duty/guard/watch fact in `Mind._answer_pressed_night`.
func pressed_night_line(_w, _n, _fact: Dictionary, _night: int, _when: String, _alternate: bool, _block_name_fn: Callable) -> String:
	return ""

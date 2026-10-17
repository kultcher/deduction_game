## One townsperson's state for a single case. Pure data; logic lives in world/mind/evil.
extends RefCounted

var id = ""
var name = ""
var pron = "they"
var style = "plain"
var blurb = ""
var traits = {}          # rolled case values, 0..1 (privacy, gossip, confidence, insight, composure)
var trait_base = {}      # cast baseline, for the dev log

var occupation = ""
var work = ""            # work location id
var work_phases: Array = []   # day phases they always work (known to the player)
var home_block = ""
var ring = 0             # position on the lane ring (neighbours for the Hearthwitch)

var role = ""            # true role id
var alignment = "good"
var alive = true
var death_day = -1
var death_cause = ""     # "demon" | "executed"
var poisoned = false

var loc = ""             # current location id, "home", or "night:<block>"
var working = false      # at work this phase
var busy_with = ""       # npc id they're in conversation with this phase
var pair_day = -1        # day they last had an NPC conversation (max one per day)
var night_block = ""
var night_path: Array = []   # blocks walked through last night (home -> destination)
var out_last_night = false
var history = {}         # "d:p" -> location id (or "home:<block>" / "night:<block>")

var friends: Array = []  # seeds for npc_trust
var rivals: Array = []
var secret = {}          # personal reason to be out at night (good NPCs only), may be empty

## Suspicion of each other NPC id (0 = trusting, 1+ = convinced evil).
var suspicion = {}
## Player-readable reason for the most recent large rise in suspicion, per target.
var sus_why = {}
var applied_info = 0

## Trust in the player, 0..1, capped by trust_cap (lowered by serious betrayals).
var trust = 0.5
var trust_cap = 1.0
## Trust in each other NPC, 0..1 (0.5 neutral). Replaces the old loyalty trait.
var npc_trust = {}
## Scrutiny from accusations and nominations; decays each night.
var pressure = 0.0
## Suspicion currently applied from the town's public accusations (Mind.refresh_consensus), per target.
var consensus_applied = {}
var pressed_today = 0
var role_asks = 0           # times the player has asked them about a particular gift
var talked_day = -1      # last day the player had a conversation with them
var cleared = {}         # ids their own Seer reading said are not the demon
var heard = {}           # card text -> times the player has used it on them (diminishing returns)

## Beliefs: list of dictionaries, e.g. {kind:"saw", who, loc, block, day, phase}
var beliefs: Array = []
## Ability results: {day, role, data, text, true:bool, why, shared}
var info_log: Array = []
var warden_log = {}          # Warden only: "night" -> who they guarded

## Claims.
var claimed_role = ""        # "" = not claimed; "none" = denies a gift
var claim_public = false
var max_tier = 0             # highest disclosure tier shared with the player (0 = never asked)
var told_readings = 0        # how many info_log entries have been told to the player privately

## Player knowledge about them.
var revealed_traits = {}     # trait -> tier string
var secret_known = false     # the player learned their secret from them
var secret_spread = false    # the player used it against them

## Social knowledge (stage 2). Every item records where it came from.
var hearsay: Array = []      # facts heard from other NPCs: {kind, about, from (original source), via, day, ...}
var known_claims = {}        # npc id -> {role, readings: [entries], via}
var known_secrets = {}       # owner id -> who told them (owner id if confided directly)
var player_cases: Array = [] # cards the player used to make a case to them
var told_to = {}             # "listener|key" -> true: what they've already told whom
var secret_spread_by_npc = false   # someone other than the player spread their secret
## Effects of the player's arguments (stage 3).
var protect_pref = {}        # id -> how strongly they've been persuaded to protect/keep them
var spare_pref = {}          # id -> how strongly they've been persuaded not to execute them
var believed_roles = {}      # id -> role they've been persuaded someone holds
var discounted = {}          # derived: "source:night|*" -> doubt in that source's readings (0..0.9)
## Evidence ledger (see Mind.ledger_hear): eid -> {effects, weight, rel, applied, meta, times}.
var ledger = {}
var used_facts = {}          # "fact>target" -> true: evidence already used against target
var remarks: Array = []      # things they've come round to, to mention to the player
var trust_at_reconsider = 0.5
var honesty = {}             # derived: id -> how far they credit that person's word (from evidence)
## Evil only: what this member knows (own observations and what they were told).
var intel = {}               # key -> {kind, about, score, why, day, from}

## Seer only: the good NPC who falsely reads as demon.
var red_herring = ""

func is_evil() -> bool:
	return alignment == "evil"

func at_home() -> bool:
	return loc.begins_with("home")

func available() -> bool:
	return alive and busy_with == "" and not at_home()

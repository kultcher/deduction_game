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
var haunts: Array = []   # favourite places when not working (town knowledge)
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
var secret_mod = ""      # secret modifier on top of their gift: delusional | marked | lovers | sleepwalker
var lover = ""           # Secret Lovers: the other lover's id
var withdrawn_since = ""   # the Lover whose death left them withdrawn (visible in the profile)

## The player relationship beyond trust.
var fear_eased = false       # the player kept a ward/vigil promise to them: fear term halved
var protect_lock = false     # promised to tell the player their gift once protected: slower to go public
var request_day = -1         # day they last asked the player for something (one request a day)
var grievances: Array = []   # player actions that cost trust: {key, why, drop, day, serious, evidence, apologised, repaired}
var friction = 0.0           # rapport lost to slights too small to be grievances; fades nightly
var gift_request = {}        # an agreed player request for tonight: {night, role, target|pair|block}

## Gift state.
var vet_used = false         # Veteran: survived their one attack
var martyr_target = ""       # Martyr: whom they chose ("" = not yet)
var gift_used = false        # one-shot gifts spent (Sexton's knell)
var medium_visited: Array = []   # Medium: the dead whose homes they've visited
var talked_today: Array = []     # NPCs they talked with today (Psychologist picks from these)
var dowsed_day = -1          # Dowser: day they last read a block
var breath_day = -1          # Breathstealer: day they last silenced someone
var breath_last = ""         # Breathstealer: whom they silenced last
var silenced = false         # can't speak (from a meeting until the next evening)
var silence_day = -1         # day the silence began (at that evening's meeting)
var silence_pending = -1     # day they were chosen (takes hold at that evening's meeting)
var turned = false           # turned evil by the Revenant's curse
var turned_day = -1

## Suspicion of each other NPC id (0 = trusting, 1+ = convinced evil).
## Unclamped totals; use Mind.susp / Mind.suspicion_view when reading beliefs.
var suspicion = {}
## Player-readable reason for the most recent large rise in suspicion, per target.
var sus_why = {}
## Where each of those reasons came from: the evidence-ledger entry id ("" = no record).
## Decides whether the reason can be cited, and to whom (Mind.reason_status).
var sus_src = {}
## Hints they've dropped at the meeting: target id -> {day, src} ("I have a reason to
## suspect X, but I'm not ready to share it"). The player can ask them why (Mind.answer_hint).
var hints = {}
var applied_info = 0

## Rapport with the player, 0..1, capped by trust_cap (lowered by serious betrayals):
## how they feel about you. Governs disclosure, requests and confidences.
var trust = 0.5
## Credibility of the player, 0.1..0.9: how much your word counts, from your track record
## (game/credibility.gd). Used wherever your evidence, votes or stance are weighed.
var credibility = 0.5
## Conclusions the player argued to them: target id -> {type: "evil"|"good", day}.
var claim_record = {}
var trust_cap = 1.0
## Trust in each other NPC, 0..1 (0.5 neutral). Replaces the old loyalty trait.
var npc_trust = {}
## Scrutiny from accusations and nominations; decays each night.
var pressure = 0.0
## Public accusations influence action as social pressure, never evidence or priors.
var consensus_pressure = {}
var pressed_today = 0
var role_guesses = 0        # times the player has asked 'are you the <gift>?' and guessed wrong
var talked_day = -1      # last day the player had a conversation with them
var cleared = {}         # ids their own Seer reading said are not the demon
var heard = {}           # card text -> times the player has used it on them (diminishing returns)

## Beliefs: list of dictionaries, e.g. {kind:"saw", who, loc, block, day, phase}
var beliefs: Array = []
## Ability results: {day, role, data, text, true:bool, why, shared}
var info_log: Array = []
var warden_log = {}          # Warden only: "night" -> who they guarded
var warden_saves = {}        # Warden only: "night" -> {target, belief}: quiet nights they take as their save

## Claims.
var claimed_role = ""        # "" = not claimed; "none" = denies a gift
var claim_public = false
var max_tier = 0             # highest disclosure tier shared with the player (0 = never asked)
var told_readings = 0        # how many info_log entries have been told to the player privately

## Player knowledge about them.
var revealed_traits = {}     # trait -> tier string
var secret_known = false     # the player learned their secret from them
var secret_spread = false    # the player used it against them
var secret_kept_nights = 0   # nights the player has kept it so far (the rapport bonus shrinks)

## Social knowledge (stage 2). Every item records where it came from.
var hearsay: Array = []      # facts heard from other NPCs: {kind, about, from (original source), via, day, ...}
var known_claims = {}        # npc id -> {role, readings: [entries], via}
var known_secrets = {}       # owner id -> who told them (owner id if confided directly)
var player_cases: Array = [] # cards the player used to make a case to them
var lied_nights: Array = []  # nights they told you they were home when they weren't (good NPCs hiding a gift or secret)
var told_to = {}             # "listener|key" -> true: what they've already told whom
var dialogue_memory = {}     # presentation only: delivered statements / variant counts per audience
var secret_spread_by_npc = false   # someone other than the player spread their secret
## Effects of the player's arguments (stage 3).
var protect_pref = {}        # id -> how strongly they've been persuaded to protect/keep them
var spare_pref = {}          # id -> how strongly they've been persuaded not to execute them
var believed_roles = {}      # id -> role they've been persuaded someone holds
var discounted = {}          # derived: "source:night|*" -> doubt in that source's readings (0..0.9)
## Evidence ledger (see Mind.ledger_hear): eid -> {effects, weight, rel, applied, meta, times}.
var ledger = {}
## Experimental shared reading owner. Separate outside baseline makes its layer
## retractable even after later independent suspicion changes hit a clamp.
var workshop_state = {}
var used_facts = {}          # "fact>target" -> true: evidence already used against target
var remarks: Array = []      # things they've come round to, to mention to the player
# Presentation only: strongest remembered player action, never a hidden-state reason.
var distrust_memory = {}
var distrust_explained_day = -1
var trust_at_reconsider = 0.5
var honesty = {}             # derived: id -> how far they credit that person's word (from evidence)
## Evil only: what this member knows (own observations and what they were told).
var intel = {}               # key -> {kind, about, score, why, day, from}
## Evil only: the shadow good self (Mind.shadow_run): what they'd believe if they were the
## good townsperson they pretend to be. A separate NPC object, never in the town's lists.
var shadow = null
var is_shadow = false        # true on the shadow object itself
var shadow_rng = null        # on the shadow: its own random stream (never the world's)
var shadow_seen = {}         # on the real NPC: how far each list has been mirrored

## Seer only: the good NPC who falsely reads as demon.
var red_herring = ""

## Their gift does nothing real tonight/today: poisoned, or Delusional.
func gift_broken() -> bool:
	return poisoned or secret_mod == "delusional"

func is_evil() -> bool:
	return alignment == "evil"

func at_home() -> bool:
	return loc.begins_with("home")

func available() -> bool:
	return alive and busy_with == "" and not at_home()

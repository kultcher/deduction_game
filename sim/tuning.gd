## Centralized gameplay and solver balancing parameters for Demonologist.
##
## Architecture:
## - Pure data (`extends RefCounted` with zero `preload(...)` dependencies) so any script in
##   `sim/`, `sim/roles/`, `workshop/`, or `game/` can safely `preload("res://sim/tuning.gd")`
##   (or access `C.Tuning`) without circular preload chains.
## - Organized into 9 domain inner classes (`Setup`, `Roles`, `Mind`, `Trust`, `Social`,
##   `Meeting`, `Dialogue`, `Evil`, `Workshop`) matching `tuning_catalogue.md`.
## - Existing `const` names on `C`, `Mind`, `MindMeeting`, `Evil`, `CaseEval`, `Roles`,
##   `Activity`, `Public`, and `Speech` remain aliased to `Tuning.*` for backward compatibility.
extends RefCounted


# ---------------------------------------------------------------- 1. World Setup, Movement & Night Traces
class Setup:
	## The Muddler's Gossip trait is at least this (world._assign_secret_mod): their secret
	## only shows when they relay what they've heard.
	const MUDDLER_GOSSIP_FLOOR = 0.7
	## Case sizes: townsfolk (one carries the secret), minions, demon.
	const SETUPS = {
		7: {"town": 5, "minions": 1, "secrets": 1},
		10: {"town": 7, "minions": 2, "secrets": 1},
	}

	## Rule & mechanic toggles
	const ALLOW_NO_GIFT_DENIAL = false
	const SHADOW_SELF = true
	const INFO_BEFORE_KILL = true
	const DEFENCE_MOVES = true
	const USE_FLAVOR_SECRETS = false
	const SHARED_EXECUTION_PRIORITY_WEIGHT = 0.22

	## Marked registration probabilities
	const MARKED_EVIL_CHANCE = 0.5
	const MARKED_DEMON_CHANCE = 0.5
	const GRAVEDIGGER_MARKED_EVIL_CHANCE = 0.3

	## Schedule & relationship generation
	const EXTRA_WORK_SHIFT_CHANCE = 0.0  # Nov 10: everyone works a single shift (was 0.3)
	const FRIEND_PAIR_CUTOFF = 0.2
	const RIVAL_PAIR_CUTOFF = 0.32

	## Initial NPC-to-NPC suspicion & trust priors
	const INITIAL_SUSPICION_BASE = 0.1
	# Bonds live in npc_trust only (Oct 30, docs/social_trust_pass.md): no suspicion offset.
	const INITIAL_SUSPICION_RIVAL = 0.0
	const INITIAL_SUSPICION_FRIEND = 0.0
	const INITIAL_TRUST_BASE = 0.5
	const INITIAL_TRUST_JITTER = 0.05
	const INITIAL_TRUST_RIVAL = -0.25
	const INITIAL_TRUST_FRIEND = 0.25
	const INITIAL_TRUST_LOVER = 0.9

	## Initial NPC-to-Player trust prior
	# Starting rapport no longer depends on Privacy (Oct 30): the old mean at privacy 0.5.
	const PLAYER_TRUST_BASE = 0.425
	const PLAYER_TRUST_OPENNESS_SCALE = 0.0
	const PLAYER_TRUST_JITTER_MIN = -0.05
	const PLAYER_TRUST_JITTER_MAX = 0.1
	const PLAYER_TRUST_MIN = 0.1
	const PLAYER_TRUST_MAX = 0.9

	## First-hand knowledge weight of an NPC's own true gift
	const OWN_ROLE_CLAIM_WEIGHT = 1.5

	## Conversation & movement rates
	const IDLE_HAUNT_CHANCE = 0.4
	# Learning a haunt by seeing someone idle there, on this many different days (the tavern
	# takes more: in the evening much of the town goes there anyway).
	const HAUNT_SIGHTING_DAYS = 2
	const HAUNT_SIGHTING_DAYS_TAVERN = 3
	const TOWN_HALL_USES_PER_CASE = 3
	const PAIR_SILENCED_WEIGHT = 0.02
	const PAIR_TRUST_PIVOT = 0.3
	const PAIR_TRUST_SLOPE = 2.0
	const PAIR_MAX_WEIGHT = 2.0
	const PRE_PHASE_CHAT_CHANCE = 0.65
	const POST_PHASE_PAIR_MULT = 0.4
	const SAME_BLOCK_SIGHTING_CHANCE = 0.4
	const SLEEPWALK_CHANCE = 0.5
	const FLAVOR_SECRET_WALK_CHANCE = 0.55

	## Night drops, sightings & crime scene traces
	const DROP_CHANCE_DEMON = 0.35
	const DROP_CHANCE_WALKER = 0.15
	const LEGACY_MUD_DROPS_ENABLED = false
	const DROP_OWNED_CHANCE = 0.12
	const NIGHT_SIGHTING_STREET_CHANCE = 0.5
	const NIGHT_SIGHTING_WINDOW_CHANCE = 0.15
	const NIGHT_NEIGHBOUR_ALIBI_CHANCE = 0.2
	const MISLEADING_TRACE_CHANCE = 0.4  # retired structured-trace era constant (kept for compatibility)
	const TRACE_TOKEN_PROB = 0.67
	const TRACE_CAST_BAND_LO = 0.6
	const TRACE_CAST_BAND_HI = 0.85
	const TRACE_LOCATIONS_BASE_WEIGHT = 3.5
	const TRACE_QUARTER_BASE_WEIGHT = 0.0
	const TRACE_CONNECTION_BASE_WEIGHT = 0.0
	const TRACE_FRESH_FAMILY_WEIGHT = 1.25
	const EXTRA_TRACE_CHANCE = 0.45
	const TRACE_MATCH_WEIGHT = 3.0
	const TRACE_UNKNOWN_WEIGHT = 1.6
	const TRACE_CONTRADICT_WEIGHT = 1.0
	const TRACE_CONNECTION_MISS_WEIGHT = 1.5
	const TRACE_PASSER_PRIOR_FLOOR = 0.05
	const NIGHT_PRESSURE_DECAY = 0.6
	const PSYCH_EVIL_TEAMMATE_TRUST_PROB = 0.75


# ---------------------------------------------------------------- 2. Role Definitions & Per-Role Strengths
class Roles:
	## Default public-claim / reveal-cost / disclosure-tier modifiers (`sim/role_def.gd`)
	const HIDE_FROM_DEMON_CLAIM = -0.5
	const HIDE_FROM_DEMON_CLAIM_D2 = -0.3
	const HIDE_FROM_DEMON_CLAIM_D3 = -0.1
	const WARDEN_HIDE_CLAIM_FLOOR = -0.35
	const ONGOING_INFO_EARLY_CLAIM = -0.4  # Nov 10: was -0.45 (case 12926's day-1 wall)
	const ONGOING_INFO_CLAIM_D2 = -0.2
	const ONE_SHOT_GIFT_CLAIM = 0.3

	## Per-role tuning blocks (`sim/roles/*.gd`)
	const SEER = {
		"public_threat_bonus": 1.0,
		"red_herring_defence_eff": -0.12,
		"focus_base": 0.3,
		"focus_insight_scale": 0.5,
		"sharp_insight_threshold": 0.6,
		"req_already_wondering": 0.3,
		"req_doubting_friend": -0.25,
		"req_already_looked": -0.3,
		"bluff_clear_mate_prob": 0.4,
	}

	const WARDEN = {
		"quiet_night_effect": -0.15,
		"quiet_night_claim_weight": 0.06,
		"pick_noise": 0.3,
		"pick_trust_scale": 0.8,
		"pick_susp_scale": 0.5,
		"pick_pref_scale": 1.2,
		"req_trust_scale": 1.0,
		"req_susp_scale": 1.0,
	}

	const DOWSER = {
		"bluff_two_evil_prob": 0.35,
		"bluff_crowd_one_prob": 0.25,
	}

	const HEARTHWITCH = {
	}

	const CLERK = {
	}

	const ARCHIVIST = {
	}

	const GRAVEDIGGER = {
		"marked_evil_chance": Setup.GRAVEDIGGER_MARKED_EVIL_CHANCE,
		"trust_backed_innocent": -0.06,
		"trust_proven_right_base": 0.08,
		"trust_proven_right_insight": 0.06,
	}

	const NIGHTWATCH = {
		"req_already_wondering": 0.3,
	}

	const RUMORMONGER = {
	}

	const MEDIUM = {
		"relay_reading_scale": 0.6,
		"dead_suspicion_min": 0.35,
	}

	const VETERAN = {
		"quiet_night_effect": -0.06,
		"quiet_night_claim_weight": 0.025,
	}

	const MARTYR = {
		"claim_chosen_bonus": 0.4,
		"pick_min_score": 0.62,
		"pick_susp_scale": 0.5,
		"pick_pref_scale": 0.5,
		"reluctance_base": 0.6,
		"reluctance_panic_scale": 0.4,
		"reluctance_pressure_scale": 0.3,
		"reluctance_susp_pivot": 0.8,
		"reluctance_susp_scale": 0.4,
		"substitute_clear_eff": -2.0,
	}

	const SEXTON = {
		"toll_few_left": 0.35,
		"toll_per_dead": 0.1,
		# Telling of the toll. The bell is not public: the Sexton keeps it quiet while the
		# suppression runs (the toll night and the day after), then is open about it from
		# the morning after that. Pressure, a nomination or the podium make them tell early.
		"reveal_early_base": -1.1,
		"reveal_early_pressure": 2.2,
		"reveal_early_nominated": 1.6,
		"reveal_early_podium": 0.9,
		"reveal_early_trust": 0.8,
		"claim_wait": 2.5,       # meeting claim term while the bell still holds
		"claim_after_toll": 1.4,  # meeting claim term once it has worn off
	}

	const PSYCHOLOGIST = {
		"conversation_nudge": 0.5,
	}

	const BREATHSTEALER = {
		"phase_probs_high": [0.3, 0.5, 1.0],
		"phase_probs_low": [0.15, 0.3, 0.7],
		"high_score_threshold": 1.0,
		"noise": 1.0,
		# Cover in a crowd (Nov 9): this many others at the Breathstealer's place adds the bonus.
		"crowd_size": 3,
		"crowd_bonus": 0.3,
	}

	const REVENANT = {
		"place_totem_probs": [0.45, 0.6, 1.0],
		"curse_voter_eff": 0.15,
		"evil_vote_hang_prob": 0.55,
	}


	## Warden credit for quiet nights (Oct 30): belief = 1 / (1 + known alternatives).
	const WARDEN_SAVE_BELIEF_MIN = 0.5
	const WARDEN_SAVE_TRUST = 0.1   # trust gained (x belief) by the Warden in the protectee, and back if believed
	const WARDEN_TELL_TRUST = 0.6   # the Warden tells the protectee when trusting them at least this much
	const WARDEN_SAVE_RELIABILITY = 0.7  # how far the model trusts a claimed save (an inference, not a sighting)

# ---------------------------------------------------------------- 3. NPC Mind, Belief Ledger & Credence
class Mind:
	const SIGMOID_SLOPE = 4.0
	const PARANOIA_PER_DEAD = 0.07
	const PARANOIA_COMPOSURE_DAMP = 0.6
	const CONFIDENCE_SCALE_BASE = 1.4
	const CONFIDENCE_SCALE_SLOPE = 0.8
	const MAX_SUSPICION = 1.5

	## Credibility (honesty) discounting from evidence against a source (retired legacy aliases retained)
	const HONESTY_K = 0.8
	const HONESTY_CAP = 0.5
	const NIGHT_DOUBT_CAP = 0.9

	## Role-claim & sighting ledger weights
	const RIVAL_CLAIM_EFF = 0.6  # retired legacy claim-collision weight (shared model owns claims)
	const PUBLIC_CLAIM_HEARING_WEIGHT = 0.5
	const DEMON_VICTIM_CLAIM_BOOST = 1.95
	const BELIEVED_ROLE_MIN_EFF = 0.12
	const HEARD_READING_WEIGHT = 0.5

	## Reconsideration, gift requests, apologies & shadow self
	const RECONSIDER_TRUST_DELTA = 0.1
	const RECONSIDER_MIN_SHIFT = 0.03
	const RECONSIDER_ENTRY_MIN_DELTA = 0.02
	const RECONSIDER_CONFIDENCE_DAMP = 0.6
	const SHADOW_OWN_READING_WEIGHT = 1.2
	const APOLOGY_EVIDENCE_INSIGHT_PIVOT = 0.4
	const APOLOGY_EVIDENCE_INSIGHT_SLOPE = 1.2
	const APOLOGY_EVIDENCE_DAMP_CAP = 0.6
	const GIFT_REQ_TRUST_SLOPE = 2.0
	const GIFT_REQ_BASE = 0.2
	const GIFT_REQ_COUNTER_MIN_TRUST = 0.35


# ---------------------------------------------------------------- 4. Player Trust Deltas & Grievances
class Trust:
	const SERIOUS_GRIEVANCE = 0.12
	const GRIEVANCE_MIN_DROP = 0.03
	const APOLOGY_SHARE_SERIOUS = 0.25
	const APOLOGY_SHARE_MINOR = 0.5
	## Fading slights (Oct 30): each night a grievance recovers this share of its drop;
	## serious ones only up to SERIOUS_FADE_LIMIT of it (an apology's repair counts toward
	## the same limit). Drops too small to be grievances collect as friction, same rate.
	const GRIEVANCE_FADE = 0.25
	const SERIOUS_FADE_LIMIT = 0.5
	## Credibility (Oct 30): how much the player's word counts, from their track record.
	## target = 0.5 + CRED_SPAN * mean agreement; moves CRED_STEP of the way each dawn.
	const CREDIBILITY_START = 0.5
	const CRED_SPAN = 0.4
	const CRED_STEP = 0.5
	const CRED_MIN = 0.1
	const CRED_MAX = 0.9
	## Minimum independent posterior movement from baseline prior before an NPC scores
	## a recorded player claim at Dawn (unless public alignment proof already exists).
	const CRED_CORROBORATION_MIN = 0.06
	## Track-record weights: formal deductions/nominations vs bare meeting statements.
	const CRED_WEIGHT_FORMAL = 1.0
	const CRED_WEIGHT_STATEMENT = 0.35
	const CRED_WEIGHT_BARE_NOMINATION = 1.0
	const DISTRUST_EXPLAIN_THRESHOLD = 0.35

	## Overnight secret-keeping recovery
	const SECRET_KEPT_BASE = 0.03
	const SECRET_KEPT_PRIVACY_SCALE = 0.04
	const SECRET_KEPT_RUMOR_MULT = 0.4
	const SECRET_KEPT_DECAY = 0.5
	## No grief for a hanged friend the mourner already believed evil (Oct 30).
	const GRIEF_BELIEVED_EVIL = 0.6  # each later night is worth half the one before (Oct 30)
	const GRIEF_FRIEND_MIN_TRUST = 0.62
	const GRIEF_NPC_NOMINATOR_DROP = 0.2
	const GRIEF_PLAYER_NOMINATOR_DROP = 0.3
	const GRIEF_PLAYER_NOMINATOR_CAP = 0.55
	const GRIEF_PLAYER_VOTER_DROP = 0.2
	## Private mourning resentment (Phase 2b): action-only score terms that fade nightly
	## and clear immediately if the hanged friend is later shown/believed evil.
	const RESENTMENT_NOMINATOR_SCALE = 0.30
	const RESENTMENT_VOTER_SCALE = 0.12
	const RESENTMENT_FADE = 0.35
	const RESENTMENT_CAP = 0.45

	## Post-refresh execution reading rapport gates (`World.on_execution_reading_heard`)
	const EXEC_READING_MAX_SOURCE_SUSP = 0.40
	const EXEC_READING_MIN_SOURCE_REL = 0.55
	const EXEC_READING_MIN_SOURCE_TRUST = 0.45
	const EXEC_READING_MIN_EVIL_SUSP = 0.22

	## Broken confidence & spread secrets
	const CONFIDENCE_BROKEN_BASE = 0.05
	const CONFIDENCE_BROKEN_PRIVACY = 0.2
	const SECRET_SPREAD_BASE = 0.08
	const SECRET_SPREAD_PRIVACY = 0.4
	const SECRET_SPREAD_REPEAT_MULT = 0.4
	const SECRET_CAP_HIGH_PRIVACY = 0.3
	const SECRET_CAP_MID_PRIVACY = 0.6

	## Conversation, pressing, promises, nominations, clemency & presentations
	const CIVIL_TALK_BASE = 0.04
	const CIVIL_TALK_PRIVACY_DAMP = 0.5
	const QUESTION_FATIGUE_LIMIT = 3
	const QUESTION_FATIGUE_BASE = 0.03
	const QUESTION_FATIGUE_PRIVACY = 0.05
	const QUESTION_FATIGUE_COMPOSURE_DAMP = 0.5
	const PRESSED_EVIDENCE_BASE = 0.03
	const PRESSED_EVIDENCE_PRIVACY = 0.06
	const WRONG_ROLE_GUESS_STEP = 0.02
	const SHARED_GIFT_FIRST_TIME_BONUS = 0.03
	const PROMISE_OFFER_BONUS = 0.03
	const PROMISE_KEPT_BONUS = 0.06
	const PROMISE_BROKEN_DROP = 0.15
	const WARD_SIGIL_BONUS = 0.05
	const WARD_SIGIL_TARGET_BONUS = 0.15
	const SELF_SUPPORT_BONUS = 0.03
	const PRESENTATION_REWARD = 0.02
	## Premises pass step 1: a clearly wrong premise costs what a good one earns. Agreement is
	## CaseEval.shift (-1..1, how far the evidence moved toward the premise), so "clearly
	## wrong" is the evidence moving a quarter of the way toward the premise being false.
	const PRESENTATION_WRONG_COST = 0.02
	const PRESENTATION_WRONG_AGREEMENT = -0.25
	const NOMINATED_PRESSURE = 0.4
	const NOMINATED_BY_PLAYER_DROP = 0.15
	const NOMINATED_NPC_TRUST_DROP = 0.25
	const CLEMENCY_SPARED_BONUS = 0.15
	const CLEMENCY_OVERRULED_DROP = 0.08
	const CLEMENCY_OVERRULED_HIGH_SUSP_DROP = 0.10
	const CLEMENCY_HIGH_SUSP_MIN = 0.6
	const CLEMENCY_LOW_SUSP_MAX = 0.35
	const CLEMENCY_TRUSTED_BONUS = 0.06
	const CLEMENCY_SUSPECTED_DROP = 0.1
	const VOTED_YES_ON_ME_DROP = 0.08
	const SPEAK_DEFEND_BONUS = 0.06
	const SPEAK_AGAINST_NOMINATOR_DROP = 0.04
	const SPEAK_AGAINST_NOMINEE_DROP = 0.08


# ---------------------------------------------------------------- 5. Background Social Gossip & Approaches
class Social:
	const NEWS_BONUS_EVIL = 0.6
	const NEWS_BONUS_GOOD = 0.5
	const GOOD_NEWS_TRUST_MIN = 0.6
	const PLANTER_WHISPER_BONUS = 0.65
	const PLANTER_TARGET_GOSSIP_MIN = 0.45
	const PLANTER_TARGET_TRUST_MIN = 0.48
	const MURDER_RELAY_BONUS = 0.35
	const IDLE_CHAT_WEIGHT = 0.18  # was 0.30 (meeting plan M1: more leads, less weather)
	const DAY_RUMOR_WEIGHT = 0.45
	const UNEASE_SUSP_MIN = 0.34
	const HEARSAY_TRUST_SCALE = 0.75
	const HEARSAY_WEIGHT_CAP = 0.55
	const SHARE_TRUST_BUMP = 0.02  # superseded Oct 30 by GOSSIP_BOND
	const SHARE_READING_OPENNESS_SCALE = 1.2
	const SHARE_READING_BOND_FLOOR = 0.3
	const SHARE_READING_BOND_SLOPE = 2.0
	const SHARE_READING_PRESSURE_SCALE = 0.3
	## Trusted listeners get readings far more readily (Nov 5, Michael): on top of the base
	## formula, + slope x (bond - pivot) for bonds above the pivot. Friends start at 0.75.
	const SHARE_READING_TRUSTED_PIVOT = 0.6
	const SHARE_READING_TRUSTED_SLOPE = 4.0
	## A conversation can pass on more than one thing (Nov 5). Item k (0-based) needs bond at
	## least SHARE_EXTRA_ITEM_BOND[k]: the first is open to anyone, more need more trust.
	const SHARE_EXTRA_ITEM_BOND = [0.0, 0.5, 0.65]
	## Relaying what a dead person told you: weight per unit of the trust you had in them,
	## scanned across all hearsay (not just the latest).
	const SHARE_DEAD_RELAY_SLOPE = 1.5
	const SHARE_SECRET_BOND_FLOOR = 0.6
	const SHARE_SECRET_SLOPE = 3.0
	const SHARE_OPINION_MIN_SUSP = 0.5
	const SHARE_OPINION_GOSSIP_SCALE = 0.6
	const SHARE_OPINION_CONF_SCALE = 0.4
	const SHARE_CASE_GOSSIP_SCALE = 0.5
	const SHARE_SIGHTING_GOSSIP_SCALE = 0.8
	const SHARE_SIGHTING_SCENE_BONUS = 0.4
	const SHARE_ALIBI_WEIGHT = 0.22
	const MUDDLER_CHANCE = 0.65
	## Peer role hints and claims (meeting plan M1). A hint names only the gift's family
	## (HINT_PACKAGES); a claim names the role, even for gifts with no readings to share.
	const SHARE_ROLE_HINT_BOND_MIN = 0.45  # was 0.55 (Nov 5: acquaintances, not only friends)
	const SHARE_ROLE_HINT_OPENNESS_SCALE = 0.9
	const SHARE_ROLE_HINT_BOND_OFFSET = 0.15
	const SHARE_ROLE_HINT_GOSSIP_SCALE = 0.35  # was 0.2 (Nov 8: 2-3 hints a game)
	const SHARE_ROLE_CLAIM_BOND_MIN = 0.58  # was 0.68 (Nov 5)
	const SHARE_ROLE_CLAIM_PRESSURED_BOND_MIN = 0.5  # was 0.55 (Nov 5)
	const SHARE_ROLE_CLAIM_PRESSURE_MIN = 0.55
	const SHARE_ROLE_CLAIM_SLOPE = 1.8
	const SHARE_ROLE_CLAIM_BOND_FLOOR = 0.45  # was 0.55 (Nov 5)
	const SHARE_ROLE_CLAIM_MIN_WEIGHT = 0.05
	## Day-1 confidant (Nov 8, BotC's "find one person to trust"): until they've told someone,
	## and only on day 1, an NPC will tell a less-trusted listener their gift, and is likelier
	## to. Target: once or twice a game. The pair warms to each other.
	const SHARE_ROLE_CONFIDE_BONUS = 0.15        # added to the gift roll's openness
	const CONFIDE_MAX_PER_GAME = 2
	## The gift topic in NPC talk (Social._gift_disclosure, Nov 8): how often it comes up, and
	## the roll's spread (the Demonologist's version uses a daily mood of +-OPENNESS_JITTER).
	const SHARE_GIFT_TOPIC_BASE = 0.3
	const SHARE_GIFT_TOPIC_OPENNESS = 0.5
	const SHARE_GIFT_TOPIC_GOSSIP = 0.2
	const SHARE_GIFT_JITTER = 0.2
	const SHARE_GIFT_PEER_OFFSET = -0.1   # a touch more guarded with a neighbour than with the Demonologist
	const CONFIDE_TRUST_LISTENER = 0.08  # the listener toward the one who confided
	const CONFIDE_TRUST_TELLER = 0.04    # the confider toward the listener
	## Good NPCs with an untold gift count as having news on these early days.
	const ROLE_NEWS_LAST_DAY = 2
	## What an evil listener makes of a peer's role hint / claim (a target worth watching).
	const EVIL_ROLE_HINT_THREAT = 0.5
	const EVIL_ROLE_CLAIM_THREAT = 1.5
	const SHARE_RELAY_GOSSIP_SCALE = 0.45
	const SHARE_RELAY_SECRET_GOSSIP_SCALE = 0.4
	const SHARE_RELAY_SECRET_COMPOSURE_BASE = 1.3
	const TAVERN_WHISPER_MIN_CROWD = 4
	const TAVERN_WHISPER_CHANCE = 0.5
	const TAVERN_OVERHEAR_MIN_SUSP = 0.4
	const TAVERN_GOSSIP_MIN_ITEMS = 3
	const TAVERN_GOSSIP_MAX_ITEMS = 5
	## The town's vibe check on the Demonologist (always told at evening tavern gossip):
	## the average rapport (trust) and competence (credibility) of the living good townsfolk,
	## in 0.1-wide bands centred on neutral 0.5. A move of TOWN_VIBE_TREND since the player
	## last heard it is called out; one good townsfolk TOWN_VIBE_OUTLIER below the average
	## rapport (and below neutral) gets a 'not everyone agrees'.
	const TOWN_VIBE_TREND = 0.03
	const TOWN_VIBE_OUTLIER = 0.2
	const TAVERN_UNHEARD_SPOKEN_WEIGHT = 4.0
	const TAVERN_BACKFILL_PROFILE_WEIGHT = 1.2
	const TAVERN_HEARD_SPOKEN_WEIGHT = 0.2
	## Yesterday's NPC-to-NPC talk still circulates at the tavern, less than today's (Nov 8).
	const TAVERN_YESTERDAY_MULT = 0.6
	## Gossip and the teller (Oct 30): +GOSSIP_BOND trust when believed (suspicion of the teller
	## below GOSSIP_BELIEVED_BELOW), -GOSSIP_BOND when it runs down someone the listener
	## trusts at least GOSSIP_SMEAR_TRUST, otherwise nothing.
	const GOSSIP_BOND = 0.02
	const GOSSIP_BELIEVED_BELOW = 0.4
	const GOSSIP_SMEAR_TRUST = 0.65
	## NPC-to-NPC trust reacting to the meeting (Oct 30): a nominee's trust in each voter.
	const TRUST_VOTED_AGAINST = 0.1
	const TRUST_VOTED_FOR = 0.03
	const TRUST_ACCUSED_ME = 0.1
	const PARANOIA_DRIFT_RATE = 0.06  # unused since Oct 30 (drift removed; see VOTE_URGENCY_PER_DEATH)
	const APPROACH_PHASE_CHANCE = 0.4
	const APPROACH_SCORE_THRESHOLD = 0.35
	const APPROACH_NOISE = 0.2
	const APPROACH_NEWS_MIN_TRUST = 0.5
	const APPROACH_NEWS_OFFSET = 0.6
	const APPROACH_GOSSIP_MIN = 0.6
	const APPROACH_GOSSIP_OFFSET = 0.3
	const APPROACH_PROTECT_COMPOSURE_SCALE = 0.5
	const APPROACH_PROTECT_OFFSET = 0.4
	const APPROACH_SECRET_DIRECT_BASE = 0.5
	const APPROACH_SECRET_DIRECT_GOSSIP_SCALE = 0.3
	const PROTECTION_MIN_TRUST = 0.45
	const ROLE_OWN_UP_BASE = 0.15
	const ROLE_OWN_UP_TRUST_SCALE = 0.2
	const ROLE_WILLING_GOSSIP_SCALE = 0.7
	const ROLE_WILLING_TRUST_SCALE = 0.5
	const ROLE_WILLING_PRESSURE_SCALE = 0.3
	const ROLE_WILLING_THRESHOLD = 0.55
	const CORRECT_ROLE_GUESS_BONUS_PROB = 0.5


# ---------------------------------------------------------------- 6. Town Meeting: Claims, Consensus, Nominations & Votes
class Meeting:
	## Meeting plan M2a: opening testimony reacts to what's said, and private townsfolk
	## fade once a wagon is rolling (docs/meeting_flow_plan.md sections 2.2-2.3).
	const REACTIVE_OPENNESS_BONUS = 0.35
	const CROWD_FADE_PRIVACY_FLOOR = 0.45
	const CROWD_FADE_SLOPE = 0.18
	const CROWD_FADE_SIGHTING_BAR = 0.10
	## Block safety (Step 2): how safe a nominee is because someone else is firmly on the block.
	const BLOCK_SAFETY_FULL_MARGIN = 3.0
	const BLOCK_SAFETY_HEAT_BASE = 0.15
	const BLOCK_SAFETY_HEAT_PER_ACCUSER = 0.15
	const BLOCK_SAFETY_HEAT_CREDIBILITY = 0.30
	const BLOCK_SAFETY_DEFENCE_RELIEF = 0.75
	const BLOCK_SAFETY_PRESS_RELIEF = 0.65
	## Podium press (Step 3, sim/mind_podium.gd): being asked before the whole town, on
	## trial, pushes toward an answer; a hint costs less than a claim; being seen out pushes
	## a hidden walking gift to explain itself. A refusal raises pressure, and costs a little
	## trust with the Demonologist when the press had no grounds or the nominee was safe.
	const PODIUM_PRESS_URGENCY = 0.5
	const PODIUM_HINT_EASE = 0.6
	const PODIUM_SEEN_OUT = 0.4
	const PODIUM_PRESS_PRESSURE_GAIN = 0.1
	const PODIUM_FRICTION_SAFETY = 0.5
	## Supporters (Step 4, sim/mind_support.gd, meeting plan M2c): bystanders decide for
	## themselves, in seat order, whether to speak for or against the nominee. At most
	## MAX_SUPPORTERS_SHOWN speak. A self-exposing defence (an unshared clearing reading)
	## weighs belief the nominee is good, what their role is still worth, what speaking
	## costs the bystander, and how much danger the nominee is in (`support_reveal`).
	const MAX_SUPPORTERS_SHOWN = 3
	const SUPPORT_BASE = -0.6
	const SUPPORT_GOOD_PIVOT = 0.9
	const SUPPORT_GOOD_SLOPE = 2.0
	const SUPPORT_CLEARING_READING = 0.5
	const SUPPORT_TRUST_SLOPE = 2.0
	const SUPPORT_DANGER_DEFENCE_DAMPING = 0.7
	const SUPPORT_DANGER_PER_ACCUSER = 0.15
	## How much the bystander's own reveal cost (Mind.reveal_cost, tuned for accusations,
	## where a reading's strength sits beside it) counts against speaking up for someone.
	const SUPPORT_REVEAL_COST_SCALE = 3.0
	const SUPPORT_HINT_FRACTION = 0.5
	const SUPPORT_PILE_ON_MIN_SUSP = 0.45
	const SUPPORT_PILE_ON_BASE = -0.8
	const SUPPORT_PILE_ON_SLOPE = 4.0
	## What the nominee's role is still worth (RoleDef.score_protect_value).
	const PROTECT_VALUE_ONGOING = 1.2
	const PROTECT_VALUE_PROTECTION = 0.8
	const PROTECT_VALUE_SPENT = 0.15
	const PROTECT_VALUE_OTHER = 0.4
	const PROTECT_VALUE_UNKNOWN = 0.4
	const PROTECT_VALUE_HORIZON_DAYS = 6
	## A friend vouching for a gift the nominee confided before today (M1's peer gossip).
	const VOUCH_MIN_TRUST = 0.6
	const VOUCH_MAX_SUSP = 0.25
	const VOUCH_BASE = -0.4
	## Plain liking or distrust, said aloud; a small social nudge, not evidence.
	const VIBES_TRUST_MIN = 0.62
	const VIBES_SUSP_MIN = 0.55
	const VIBES_BASE = -0.9
	const VIBES_SWAY = 0.04
	## Evil bystanders: the worth of defending a teammate in danger, or of piling onto the
	## scapegoat, before cover (Mind.evil_override). Words are the cheap place to keep cover,
	## so speaking up for a teammate is rare until the team is desperate (a Demon's stakes
	## 0.6 against caution 0.8 falling to 0.45).
	const SUPPORT_EVIL_DEFEND_STAKES = 0.3
	const SUPPORT_EVIL_PILE_STAKES = 0.6
	## Vote resistance lines (Step 6, M2d): after the tally, at most this many voters say why.
	## Someone who accepted the Demonologist's case and still voted no explains; failing
	## that, the voter who swung a close count. A "short of rope" no needs a close margin.
	# A late relay marks the teller's own copy public; this weight only names the receipt
	# (ledger weights merge by max, so it never lowers what they already held).
	const LATE_RELAY_TELLER_MARK = 0.02
	const MAX_VOTE_RESISTANCE_SPEAKERS = 2
	const VOTE_RESISTANCE_CLOSE_MARGIN = 0.35
	## Player nominations: with a filed case (anchored) or without (raw). A raw nomination
	## still counts at the formal track-record weight (unchanged; revisit in M4's sweep).
	const ALLOW_UNANCHORED_PLAYER_NOMINATION = true
	const VOLUNTEER_SIGHTING_BASE = 1.2
	const PUBLIC_CLAIM_BASE = -0.35
	const PUBLIC_CLAIM_OPENNESS_SLOPE = 1.2
	const PUBLIC_CLAIM_DAY_SLOPE = 0.4
	const PUBLIC_CLAIM_PRESSURE_SLOPE = 0.8
	const PUBLIC_CLAIM_COMPOSURE_DAMP = 0.5
	const PUBLIC_CLAIM_FEW_LEFT = 0.8
	const REVEAL_COST_PRIVACY_SLOPE = 0.8
	const REVEAL_COST_BASE = 0.2
	const REVEAL_COST_AFRAID = 0.35
	const REVEAL_COST_DAY_SLOPE = -0.12
	const REVEAL_COST_FEW_LEFT = -0.6
	const REVEAL_STRENGTH_PIVOT = 0.45
	const REVEAL_STRENGTH_SLOPE = 1.4
	const REVEAL_SUSPICION_PIVOT = 0.45
	const REVEAL_SUSPICION_SLOPE = 1.5
	const REVEAL_CONFIDENCE_SLOPE = 0.6
	const ACCUSE_SUSPICION_PIVOT = 0.6
	const ACCUSE_SUSPICION_SLOPE = 1.5
	const ACCUSE_CONFIDENCE_SLOPE = 0.8
	const ACCUSE_PRESSURE_DEFLECT = 0.4
	const ACCUSE_RESENTMENT_SLOPE = 1.5
	const ACCUSE_PRESSURE_BASE = 0.15
	const ACCUSE_PRESSURE_DECAY = 0.5

	## Anonymous reading relays
	const RELAY_WEIGHT = 0.3
	## Telling the town what a dead person privately told you (MindMeeting._late_relay).
	const LATE_RELAY_BASE = 0.3
	const LATE_RELAY_TRUST_SLOPE = 2.0
	const LATE_RELAY_OPENNESS_SLOPE = 0.8
	const RELAY_CORROBORATE = 0.05

	## Social consensus bandwagon pressure
	const CONSENSUS_BASE = 0.09
	const CONSENSUS_FADE = 0.6
	const CONSENSUS_CAP = 0.22
	const CONSENSUS_HINT = 1.15

	## Self-defence moves
	const DEFENCE_ROPE = 1.1
	const DEFENCE_LIE_BLOWBACK = 0.02
	const DEFENCE_REVEAL_CAP = 0.35
	const DEFENCE_SECRET_CAP = 0.3
	const DEFENCE_PAIR_OTHER_DELTA = 0.06
	const DEFENCE_LYING_RELIEF = -0.05
	const DEFENCE_MISLED_RELIEF = -0.06
	const DEFENCE_PLEA_RELIEF = -0.02

	## Nomination threshold, evil counter-nominations & failed-vote cooloff
	const NOMINATION_BASE = 0.65
	const NOMINATION_DAY_SLOPE = 0.05
	const NOMINATION_FLOOR = 0.40
	const NOMINATION_CONFIDENCE_SCALE = 0.20
	const NOMINATION_PARANOIA_SCALE = 0.5
	const NOMINATION_OWN_CLEAR_RELIEF = 0.2
	const NOMINATION_COOLOFF_SELF = 0.28
	const NOMINATION_COOLOFF_ROOM = 0.10
	const EVIL_COUNTER_MIN_HEAT = 0.40
	const EVIL_NOMINATION_STAKES_BASE = 0.45
	const EVIL_RESCUE_DEMON_BONUS = 0.45
	const EVIL_RESCUE_MINION_BONUS = 0.20
	const EVIL_VOTE_RESCUE_DEMON = 0.65
	const EVIL_VOTE_RESCUE_MINION = 0.30
	const EVIL_VOTE_LANDSLIDE_PIVOT = 0.20
	const EVIL_VOTE_NONPIVOTAL_TEAMMATE = 0.55
	const EVIL_VOTE_SCION_COVER_MULT = 0.70

	## Voting threshold & player ballot leverage
	const VOTE_BASE_NEED = 0.52
	const VOTE_CONFIDENCE_SCALE = 0.12
	const VOTE_DAY1_PENALTY = 0.1
	const VOTE_PARANOIA_WEIGHT = 0.20
	## Urgency (Oct 30, replaces paranoia drift): the bar drops per death; Composure doesn't cancel it.
	const VOTE_URGENCY_PER_DEATH = 0.02
	const PLAYER_VOTE_YES_SLOPE = 0.18
	const PLAYER_VOTE_YES_OFFSET = -0.04
	const PLAYER_DEFEND_SLOPE = -0.25
	const PLAYER_ACCUSE_SLOPE = 0.15
	const VOTE_DISTRUST_NOMINATOR_MIN_SUSP = 0.7
	const VOTE_DISTRUST_NOMINATOR_OFFSET = -0.15
	const VOTE_SPARE_PREF_SLOPE = -0.5
	const VOTE_PREFERS_BLOCK_OFFSET = -0.4
	const VOTE_SELF_NOMINATION_MARGIN = 0.02


# ---------------------------------------------------------------- 7. One-on-One Dialogue, Pressing & Disclosure
class Dialogue:
	const OPENNESS_BASE_OFFSET = -0.72
	const OPENNESS_PRIVACY_WEIGHT = 1.0
	const OPENNESS_TRUST_WEIGHT = 1.2
	const OPENNESS_PRESSURE_WEIGHT = 0.6
	const OPENNESS_COMPOSURE_DAMP = 0.5
	const OPENNESS_DAY_SLOPE = 0.1
	const OPENNESS_JITTER = 0.1  # was 0.2; a daily sample since Oct 30
	const TIER_VAGUE = 0.15
	const TIER_PARTIAL = 0.45
	const TIER_FULL = 0.75

	## Hint follow-ups, protection & confidence requests
	const HINT_FOLLOWUP_TRUST_PIVOT = 0.45
	const HINT_FOLLOWUP_TRUST_SLOPE = 2.0
	const HINT_FOLLOWUP_PRIVACY_SLOPE = 0.8
	const HINT_FOLLOWUP_AFRAID_OFFSET = -0.3
	const PROTECTION_REQ_MIN_TRUST = 0.45
	const PROTECTION_REQ_BASE = 0.35
	const PROTECTION_REQ_TRUST_SLOPE = 1.5
	const PROTECTION_REQ_CAP = 0.85
	const PROTECTION_DISCLOSE_MULT = 1.6
	const PROTECTION_DISCLOSE_MIN = 0.05
	const PROTECTION_DISCLOSE_MAX = 0.85
	const CONFIDENCE_REQ_MIN_TRUST = 0.4
	const CONFIDENCE_REQ_BASE = 0.15
	const CONFIDENCE_REQ_TRUST_SLOPE = 0.8
	const CONFIDENCE_REQ_COMPOSURE_SLOPE = 0.5
	const CONFIDENCE_REQ_CAP = 0.5

	## Fear of the Demon when considering disclosure
	const FEAR_BASE = 0.2
	const FEAR_COMPOSURE_SCALE = 0.3
	const FEAR_PRESSURE_SCALE = 0.5
	const FEAR_EASED_MULT = 0.5
	const FEAR_CAP = 0.85

	## Pressing with evidence
	## Press strength (purge phase 4b): the shared model's weight for the card, floored here;
	## a pressed deduction lands at a fixed strength; cards the model has no entry for
	## count this much against someone they structurally implicate.
	const PRESS_STRENGTH_MIN = 0.3
	const PRESS_DEDUCTION_STRENGTH = 0.6
	const UNMODELLED_CARD_WEIGHT = 0.5
	const PRESS_NERVES_HIDING = 0.6
	const PRESS_NERVES_HONEST = 0.2
	const PRESS_PRESSURE_GAIN = 0.35

	## Night whereabouts, confession, stonewalling & slip rates
	const CONFESS_TRUST_PIVOT = 0.6
	const CONFESS_TRUST_SLOPE = 1.5
	const CONFESS_PRIVACY_PIVOT = 0.4
	const CONFESS_PRIVACY_SLOPE = 1.0
	const CONFESS_PRESSURE_SLOPE = 0.8
	const CONFESS_COMPOSURE_DAMP = 0.5
	const LIE_BOLD_CONF_SLOPE = 1.5
	const LIE_BOLD_PRIVACY_SLOPE = 0.6
	const SLIP_COMPOSURE_SCALE = 0.25
	const SLIP_PRESSURE_SCALE = 0.15
	const DIRECT_NIGHT_SIGHTING_SHARE_PROB = 0.95

	## Daytime memory, opinion caveats & profile-note sharing
	const GOSSIP_SHARE_PRESSURE_SCALE = 0.5
	const GOSSIP_SHARE_MULT = 3.0
	const DAY_MEMORY_BASE = 2
	const DAY_MEMORY_INSIGHT_SCALE = 4.0
	const WORD_DOUBT_BELOW = 0.75
	const SHARE_HAUNTS_BASE = 0.15
	const SHARE_HAUNTS_GOSSIP_SCALE = 0.55
	const SHARE_HAUNTS_TRUST_SCALE = 0.5
	const SHARE_HAUNTS_CAP = 0.9
	const SHARE_HAUNTS_ALL_SHARE = 0.4
	## Added to the haunt roll when you know none of that person's haunts yet (Nov 10).
	const SHARE_HAUNTS_NONE_KNOWN_BONUS = 0.2
	const SHARE_TRAIT_BASE = 0.1
	const SHARE_TRAIT_GOSSIP_SCALE = 0.35
	const SHARE_TRAIT_TRUST_SCALE = 0.3
	const SHARE_TRAIT_FRIEND_BONUS = 0.15
	const SHARE_TRAIT_CAP = 0.6


# ---------------------------------------------------------------- 8. Evil AI: Bluffs, Scapegoats, Kills & Poison
class Evil:
	const EVIL_HINT_CHANCE = 0.3
	const MEDIUM_USELESS_CHANCE = 0.15
	const EVIL_CAUTION_DEMON = 0.8
	const EVIL_CAUTION_MINION = 0.7
	const MINION_ID_DRIFT = 0.08
	const MINION_CAUTION_FLOOR = 0.25
	const DEMON_CAUTION_FLOOR = 0.45
	const DEMON_CAUTION_DRIFT = 0.03
	const HEAT_FADE = 0.75
	const PUBLIC_HEAT_BASE = 0.15
	const HEAT_ACCUSATION = 0.12
	const HEAT_NOMINATION = 0.2
	const HEAT_READING_SCALE = 0.4
	const HEAT_VOTE_YES = 0.04
	const HEAT_CLEAR = -0.12
	const EXPOSURE_PLAYER_SUSPECTS = 0.3
	const EXPOSURE_PRESSURE_SCALE = 0.5
	const EXPOSURE_ON_BLOCK = 0.2
	const TEAMMATE_VALUE_DEMON = 2.0
	const TEAMMATE_VALUE_DEMON_WITH_SCION = 1.1
	const TEAMMATE_VALUE_SCION_ACTIVE = 1.45
	const TEAMMATE_VALUE_MINION = 1.0
	const TEAMMATE_VALUE_REVENANT_CURSE = 0.25  # a Revenant with its curse ready: let it hang
	const PUBLIC_HOSTILITY_VOTE_WEIGHT = 0.5
	const PUBLIC_HOSTILITY_CAP = 2.5
	const INTEL_THREAT_CAP = 3.0
	const SCAPEGOAT_WALKER_BONUS = 1.0
	const SCAPEGOAT_DISTRUST_CUTOFF = 0.4
	const SCAPEGOAT_DISTRUST_BONUS = 0.5
	const SCAPEGOAT_HARD_TO_KILL_BONUS = 0.2
	const SCAPEGOAT_SHADOW_WEIGHT = 0.5
	const SCAPEGOAT_FAKE_INFO_FIT = 0.25
	const SCAPEGOAT_WALKER_FIT = 0.15
	const SCAPEGOAT_FIT_CAP = 0.6
	const SCAPEGOAT_CLEAR_PENALTY = 0.3
	const SCAPEGOAT_KEEP_BASE = 0.25
	const SCAPEGOAT_KEEP_PER_ACCUSATION = 0.15
	const PLANTER_MINION_BONUS = 1.0
	const PLANTER_GOSSIP_WEIGHT = 0.8
	const PLANTER_EXPOSURE_PENALTY = 0.6
	const PLANTER_OPENNESS_TIEBREAK = 0.01
	const EVIL_NOMINATION_BASE_HEAT = 0.42
	const EVIL_NOMINATION_CONFIDENCE_SCALE = 0.16
	const EVIL_POCKET_FRAME_BONUS = 0.16
	const EVIL_WALKER_INTEL_BONUS = 0.08
	const MAX_DIRECT_PLANTS = 2
	const PLANTER_SCENE_WEIGHT = 0.40
	const FAKE_SIGHTING_INVENT_PROB = 0.5
	const FAKE_GOSSIP_PROB = 0.6
	const CARELESS_BLUFF_INSIGHT_SCALE = 0.5
	const EVIL_VOTE_TIE_BASE = 0.4
	const EVIL_VOTE_TIE_CONF_SCALE = 0.5
	const EVIL_VOTE_NATURAL_BASE = 0.35
	const EVIL_VOTE_NATURAL_CONF_SCALE = 0.2

	## Demon kill target scoring
	const KILL_INFO_CLAIM = 3.0
	const KILL_SPENT_INFO_CLAIM = 1.0
	const KILL_IMPLICATES_US = 2.0
	const KILL_HOSTILITY_SCALE = 0.8
	const KILL_LIVES_ALONE = 0.7
	const KILL_VENGEFUL_BONUS = 1.5
	const KILL_CUNNING_BONUS = 1.5
	const KILL_HUNGRY_MAX = 2.0
	const KILL_KEEP_SCAPEGOAT = -4.0
	const KILL_VETERAN_SPENT = 0.3
	const KILL_VETERAN_WITH_POISON = 0.6
	const KILL_VETERAN_UNPOISONED = -2.0
	const KILL_FAILED_PENALTY = -10.0
	const KILL_SPARED_KEEP = -1.5
	const KILL_LIKELY_WARDED = -0.8
	const KILL_PROMISED_VIGIL_PENALTY = -6.0
	const KILL_PROMISED_WARD_PENALTY = -4.0
	const KILL_CAUTION_PROFILE_CAP = 4.0
	const KILL_CAUTION_SCALE = 0.7
	const KILL_CAUTION_DECAY = 0.5
	const KILL_FAILED_CAUTION_GAIN = 1.0
	const KILL_FAILED_CAUTION_CAP = 1.5
	const KILL_NOISE = 0.8
	const KILL_UNPREDICTABLE_CHANCE = 0.03

	## Poisoner target scoring
	const POISON_GIFT_SPENT = -3.5
	const POISON_HOSTILITY_SCALE = 0.6
	const POISON_WARDEN_INFO = 2.5
	const POISON_PROMISED_VIGIL_PENALTY = -4.5
	const POISON_WARDEN_OTHER = 1.2
	const POISON_NOISE = 1.5


# ---------------------------------------------------------------- 9. Workshop Evaluator, Bounded Reasoner & Presentation
class Workshop:
	## CaseEval report error rates & likelihood-ratio cutoffs (`workshop/case_eval.gd`)
	const DEFAULT_ERR = 0.01
	const OWN_ERR = 0.002
	const NIGHTWATCH_REPORT_ERROR = 0.08
	const LR_WEAK = 1.5
	const LR_MODERATE = 3.0
	const LR_STRONG = 10.0
	## Listener prior (`CaseEval._team_prior`): odds of evil = exp(PRIOR_K * suspicion), a
	## relative nudge from the suspicion the shared model doesn't own. Reading suspicion as a
	## probability (pre Oct 30) let 0.0-vs-0.1 seeds outweigh a Seer reading (about 5x vs 3x).
	const PRIOR_K = 1.5
	## Headline reading (`Jury._headline`): how far a listener takes a strong evil reading at
	## its word, on top of the full model. Effect = model + HEADLINE_WEIGHT * (1 - Insight) *
	## (headline - model) where the headline is higher. The per-role values are the chance
	## each named person is evil "if the reading is simply true" (1.0 = full share).
	const HEADLINE_WEIGHT = 1.0
	## The blend toward the headline grows with the headline's strength, full at this value
	## (about one Seer ping at default trust). Before Nov 6 any positive headline, however
	## faint, pulled by the whole gap, so a faint ping halved a clearing at Insight 0.5.
	const HEADLINE_FULL_AT = 0.1
	## Directional Confidence: below this lean (suspicion minus the listener's average) there
	## is no hunch to defend, so Confidence doesn't resist (Oct 30).
	const LEAN_MIN = 0.05
	const HEADLINE_SEER = 1.0       # "one of A/B is the Demon": each 1/2
	const HEADLINE_ARCHIVIST = 1.0  # "one of A/B holds <evil role>": each 1/2
	const HEADLINE_DOWSER = 1.0     # "c of these n read as evil": each c/n
	## Diminishing confirmation weight for same-source, same-epoch repeat readings in _headline.
	const HEADLINE_REPEAT_BUMP = 0.15
	## Calibrated outer belief scale when source reliability is applied per-card upstream.
	const JURY_BELIEF_SCALE = 1.35
	const JURY_ALIGNMENT_COEFF = 0.45
	const JURY_CHALLENGE_LYING_MIN_AGR = 0.6
	const JURY_CHALLENGE_LYING_SCALE = 0.12
	## Per-card epistemic reliability mapping for spoken reports (0.50 + 0.50 * trust in [0.50, 1.00]).
	const SOURCE_REL_BASE = 0.50
	const SOURCE_REL_SLOPE = 0.50
	const SIGHTING_TRUST_BASE = 0.35
	const SIGHTING_TRUST_SLOPE = 0.65
	const SIGHTING_HEARING_FLOOR = 0.10

	## Witness source quality & reading challenge penalties (`workshop/reading_challenges.gd`, `workshop/support_model.gd`)
	const WITNESS_QUALITY_BASE = 0.2
	const WITNESS_QUALITY_TRUST_SCALE = 0.65
	const WITNESS_QUALITY_SUSP_SCALE = 0.35
	const WITNESS_QUALITY_MIN = 0.05
	const WITNESS_QUALITY_MAX = 0.95
	const CHALLENGE_GROUND_MIN_QUALITY = 0.4
	const CHALLENGE_SOURCE_PENALTY_SCALE = 0.3
	## Premises step 3: a challenge backfires (and costs the presentation trust) when the rest
	## of the evidence moves the reading's content this far toward certainly holding
	## (CaseEval.shift of its share of worlds; the mirror of PRESENTATION_WRONG_AGREEMENT).
	## The plan's "0.1 below the prior" can't be reached: the chance a reading is wrong can
	## only fall to (1 - r) q / ((1 - r) q + r), about 0.09 below the prior at default trust.
	const CHALLENGE_BACKFIRE_SHIFT = 0.25
	## An accepted "the gift failed" challenge raises its Poisoner candidates by this share of
	## its agreement, split among them.
	const CHALLENGE_POISONER_SCALE = 0.12

	## Role constraints, movement & public/speech evidence (`workshop/*.gd`)
	const BLUFF_WEIGHT = 0.92
	## Smallest chance a bluff fits by luck (`CaseEval.chance_content`, the share of worlds
	## where a report's content holds).
	const CHANCE_CONTENT_FLOOR = 0.01
	## A player vigil that should have seen someone and didn't: the town's allowance that
	## the Demonologist missed them (the player can't be wrong; the town doesn't know that).
	## With the walker-claim split below, an empty vigil on a claimed walker's block is about
	## 10:1 against the claim (strong, not certain).
	## Mirrored as `VigilMiss` in `workshop/cs/LiveActivity.cs`.
	const VIGIL_MISS = 0.05
	## A good person who claims a walking gift: how the movement model splits their nights
	## between doing the duty, staying home anyway, and a secret's outing (before Nov 5:
	## 0.7 / 0.2 / 0.1, so a missed vigil barely touched the claim). Lovers and the
	## Sleepwalker never go to walking-gift holders. Mirrored in `LiveActivity.cs`.
	const WALKER_CLAIM_GIFT = 0.95
	const WALKER_CLAIM_HOME = 0.03
	const WALKER_CLAIM_SECRET = 0.02
	const DEMON_DETOUR = 0.05
	const NIGHT_OUT_RATES = {
		"hunt": 1.0,
		"minion": 0.25,
		"gift": 1.0,
		"secret": 0.55,
		"ordinary": 0.05,
	}
	const HAUNT_VISIT_RATE = 0.7
	const DEMON_VICTIM_GOOD = 0.95
	const REFUSAL_LR = 1.5

	## Consequence & Jury conclusion weights and stance thresholds
	const CONCLUSION_COEFFS = {
		"evil": 0.45,
		"demon": 0.45,
		"minion": 0.45,
		"good": -0.4,
		"marked": -0.1,
		"suspicious": 0.3,
		"conflict": 0.0,
	}
	const STANCE_ACCEPT = 0.6
	const STANCE_PARTIAL = 0.35
	const EXECUTION_PRIORITY_TOP_MARGIN = 0.12
	const EXECUTION_PRIORITY_TOP_BONUS = 0.10

	## Shared-model suspicion attribution (`workshop/reason_attribution.gd`)
	const REASON_MIN_SUSPECT_REQUESTED = 0.025
	const REASON_MIN_ITEM_CONTRIB = 0.03
	const REASON_MAX_PER_TARGET = 6
	const REASON_LOO_MIN_SHIFT = 0.08
	const REASON_LOO_COVERED_SHARE = 0.5
	const REASON_LOO_MAX_OTHER_CARDS = 6
	const REASON_CIRCUMSTANTIAL_MIN_APPLIED = 0.01
	const REASON_ELIMINATION_MIN_REQ = 0.15

	## Shared-model source and interval doubt (`workshop/source_doubt.gd`)
	const DOUBT_FALSE_NW_GENERAL = 0.5
	const DOUBT_CAUGHT_ALIBI_NIGHT = 0.75
	const DOUBT_CAUGHT_ALIBI_GENERAL = 0.55
	const DOUBT_GD_MAX_SOURCE_DOUBT = 0.5
	const DOUBT_GD_EVIL_TRUST_MIN = 0.45
	const DOUBT_GD_EVIL_SCALE = 0.85
	const DOUBT_GD_GOOD_TRUST_MIN = 0.60
	const DOUBT_ARG_MISLED_SCALE = 0.8
	const DOUBT_ARG_UNRELIABLE_SCALE = 0.5
	const DOUBT_ARG_DELUSIONAL_SCALE = 0.7
	const DOUBT_ARG_CAP = 0.9
	const DOUBT_CHALLENGE_LYING_MIN_AGR = 0.6
	const DOUBT_CHALLENGE_STRONG_AGR = 0.75

	## Stage 2 Circumstantial Evidence Hub (`workshop/circumstantial.gd`)
	const CIRCUMSTANTIAL_INCIDENT_MAX = 0.015
	const CIRCUMSTANTIAL_TARGET_CAP = 0.045
	const CIRCUMSTANTIAL_GATE_REF = 0.06
	const CIRCUMSTANTIAL_GATE_PRIOR_PIVOT = 0.15
	const CIRCUMSTANTIAL_GATE_PRIOR_WEIGHT = 0.35
	const CIRCUMSTANTIAL_SMEAR_MIN = 0.005
	const CIRCUMSTANTIAL_SMEAR_MAX = 0.015
	const CIRCUMSTANTIAL_SMEAR_FRIEND_BONUS = 0.005
	const CIRCUMSTANTIAL_SMEAR_FRIEND_MIN_TRUST = 0.65
	const CIRCUMSTANTIAL_REFUSAL_FEAR_DISCOUNT = 0.25 / 0.35
	const CIRCUMSTANTIAL_STAGE1_NOISE_FLOOR = 0.01
	const CIRCUMSTANTIAL_ASSOC_MIN_SUSP = 0.32
	const CIRCUMSTANTIAL_HOSTILE_VOTE_MAX_SUSP = 0.28
	const CIRCUMSTANTIAL_HOSTILE_VOTE_MIN_TRUST = 0.45
	const CIRCUMSTANTIAL_SHIELDING_MIN_SUSP = 0.48
	const CIRCUMSTANTIAL_TRUST_MULT_BASE = 0.5
	const CIRCUMSTANTIAL_TRUST_MULT_CAP = 1.25

	## Theory persistence (`workshop/theory.gd`)
	const THEORY_BIAS_BASE = 3.0
	const THEORY_THRESHOLD_BASE = 1.0
	const THEORY_THRESHOLD_SLOPE = 4.0

	## Presentation venue multipliers (`game/workshop_presentation.gd`)
	const VENUE_MULTS = {
		"private": 1.0,
		"meeting": 0.6,
		"nomination": 0.5,
	}
	const STANCE_MOVE = {
		"accept": 0.06,
		"partial": 0.02,
	}

	## Premises pass step 1 (docs/premises_plan.md): a presented case moves its premise's
	## target by the full evidence, and everyone else by this share of the presentation's
	## effect, from the lowest to the highest Insight. Remembered for every refresh.
	const PREMISE_SPILLOVER_MIN = 0.4
	const PREMISE_SPILLOVER_MAX = 0.8
	## Premise types whose target is an alignment question. Marked, secret, misled and
	## conflict premises name no alignment target, so their cards spill over in full.
	const PREMISE_SHAPING_TYPES = ["evil", "demon", "minion", "suspicious", "good", "notdemon", "role", "notrole", "lied", "truthful"]
	## The protect / believed-role preference from a presented premise needs at least this
	## agreement (CaseEval.shift). A rejected "X is good" no longer steers Warden picks.
	const PREMISE_PREF_MIN_AGREEMENT = 0.5
	## Premises pass step 2: "suspicious" hedges, so the cards only suspicious premises
	## brought count at this share for everyone (both directions), and the rest of their
	## full effect on the target becomes pressure, once per filing: the average listener's
	## full-weight rise times this (private / meeting), so a rise of 0.2 gives the conflict
	## premise's +0.1 / +0.2.
	const SUSPICIOUS_HEARING = 0.5
	const SUSPICIOUS_PRESSURE_PER_RISE = {"private": 0.5, "meeting": 1.0}

	## Bounded reasoning attention profiles (`workshop/reasoner.gd`)
	## Attention salience (Reasoner._salience; premises pass step 0b). Naming the target outranks
	## being a gift reading; trust in the source is a tiebreak.
	const SALIENCE_BASE = 1.0
	const SALIENCE_TRUST = 0.1
	const SALIENCE_GIFT = 2.0
	const SALIENCE_TARGET = 4.0
	const SALIENCE_NAMED = 2.0
	const SALIENCE_EXCLUSION = 1.0
	## Recency (sim/recency.gd): attention drifts. A card loses salience by days since it was
	## learned or last brought up, at RECENCY_DECAY_LOW per day for Insight 0 down to
	## RECENCY_DECAY_HIGH for Insight 1, at most RECENCY_AGE_CAP. A card naming (or from)
	## today's topic gains RECENCY_TOPIC_WEIGHT times that person's topic weight (0..1).
	const RECENCY_DECAY_LOW = 0.5
	const RECENCY_DECAY_HIGH = 0.1
	const RECENCY_AGE_CAP = 3.0
	const RECENCY_TOPIC_WEIGHT = 1.5
	## The topic of the day: what each public act adds to a person's topic weight (summed,
	## capped at 1), and how much of it is left each following day.
	const RECENCY_TOPIC_EVENTS = {"nomination": 1.0, "accusation": 0.6, "argued": 0.6, "defence": 0.3}
	const RECENCY_TOPIC_DAILY = 0.5
	const INSIGHT_LOW_CUTOFF = 0.34
	const INSIGHT_MEDIUM_CUTOFF = 0.67
	const PROFILE_LOW = {
		"name": "Low",
		"cards": 4,
		"lines": 2,
		"support": 12,
		"rivals": 3,
		"complete": false,
	}
	const PROFILE_MEDIUM = {
		"name": "Medium",
		"cards": 8,
		"lines": 3,
		"support": 24,
		"rivals": 9,
		"complete": false,
	}
	const PROFILE_HIGH = {
		"name": "High",
		"cards": 12,
		"lines": 4,
		"support": 48,
		"rivals": 27,
		"complete": true,
	}



# ---------------------------------------------------------------- 10. Presentation replies (purge phase 4)

## Speech the Workshop doesn't judge (protect / spare preferences, bare beliefs):
## sim/presentation_reply.gd. Never evidence; only feeds social preferences.
class Presentation:
	## Agreement = trust weight x the listener's trust in the player + belief weight x how
	## far their own suspicion already leans the speaker's way.
	const SOCIAL_TRUST_WEIGHT = 0.5
	const SOCIAL_BELIEF_WEIGHT = 0.5
	## Below this (agreement x venue scale) nothing is recorded.
	const SOCIAL_MIN_BASE = 0.004
	## Trust lost when the player accuses a good listener of something they know is false.
	const SELF_ACCUSED_TRUST_LOSS = 0.05

static var _fingerprint_cache: String = ""


static func fingerprint() -> String:
	if _fingerprint_cache != "":
		return _fingerprint_cache
	var src: String = FileAccess.get_file_as_string("res://sim/tuning.gd")
	if src != "":
		_fingerprint_cache = src.sha256_text().substr(0, 12)
	else:
		_fingerprint_cache = JSON.stringify([
			Setup.SHARED_EXECUTION_PRIORITY_WEIGHT,
			Setup.IDLE_HAUNT_CHANCE,
			Setup.PRE_PHASE_CHAT_CHANCE,
			Workshop.PRIOR_K,
			Workshop.HEADLINE_WEIGHT,
			Workshop.LEAN_MIN,
			Workshop.JURY_BELIEF_SCALE,
			Workshop.JURY_ALIGNMENT_COEFF,
			Workshop.HEADLINE_REPEAT_BUMP,
			Workshop.REASON_MIN_SUSPECT_REQUESTED,
			Workshop.REASON_LOO_COVERED_SHARE,
			Workshop.DOUBT_CAUGHT_ALIBI_NIGHT,
			Workshop.CIRCUMSTANTIAL_SHIELDING_MIN_SUSP,
			Trust.CRED_CORROBORATION_MIN,
			Trust.RESENTMENT_NOMINATOR_SCALE,
			Trust.RESENTMENT_VOTER_SCALE,
			Trust.RESENTMENT_FADE,
			Trust.RESENTMENT_CAP,
			Trust.CIVIL_TALK_BASE,
			Roles.ONGOING_INFO_EARLY_CLAIM,
			Meeting.PUBLIC_CLAIM_DAY_SLOPE,
			Meeting.REVEAL_SUSPICION_PIVOT,
			Meeting.CONSENSUS_BASE,
			Meeting.CONSENSUS_CAP,
			Meeting.NOMINATION_BASE,
			Meeting.VOTE_BASE_NEED,
			Meeting.VOTE_PARANOIA_WEIGHT,
			Meeting.VOTE_URGENCY_PER_DEATH,
			Meeting.PLAYER_VOTE_YES_SLOPE,
			Meeting.PLAYER_ACCUSE_SLOPE,
			Workshop.EXECUTION_PRIORITY_TOP_MARGIN,
			Workshop.EXECUTION_PRIORITY_TOP_BONUS,
			Social.PLANTER_WHISPER_BONUS,
			Social.MURDER_RELAY_BONUS,
			Evil.MAX_DIRECT_PLANTS,
			Evil.PLANTER_MINION_BONUS,
		]).sha256_text().substr(0, 12)
	return _fingerprint_cache

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
	const SHARED_EXECUTION_PRIORITY_WEIGHT = 0.0

	## Marked registration probabilities
	const MARKED_EVIL_CHANCE = 0.5
	const MARKED_DEMON_CHANCE = 0.5
	const GRAVEDIGGER_MARKED_EVIL_CHANCE = 0.3

	## Schedule & relationship generation
	const EXTRA_WORK_SHIFT_CHANCE = 0.3
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
	const PRE_PHASE_CHAT_CHANCE = 0.65
	const POST_PHASE_PAIR_MULT = 0.4
	const SAME_BLOCK_SIGHTING_CHANCE = 0.4
	const SLEEPWALK_CHANCE = 0.5
	const FLAVOR_SECRET_WALK_CHANCE = 0.55

	## Night drops, sightings & crime scene traces
	const DROP_CHANCE_DEMON = 0.35
	const DROP_CHANCE_WALKER = 0.15
	const DROP_OWNED_CHANCE = 0.12
	const NIGHT_SIGHTING_STREET_CHANCE = 0.5
	const NIGHT_SIGHTING_WINDOW_CHANCE = 0.15
	const NIGHT_NEIGHBOUR_ALIBI_CHANCE = 0.2
	const MISLEADING_TRACE_CHANCE = 0.4
	const TRACE_TOKEN_PROB = 0.67
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


# ---------------------------------------------------------------- 2. Role Definitions & Per-Role Strengths
class Roles:
	## Shape-driven default strengths (`sim/role_def.gd`)
	const DEFAULT_READING_STRENGTH = 0.3
	const PING_YES_READING_STRENGTH = 0.9
	const GROUP_READING_STRENGTH_SCALE = 0.9
	const GROUP_READING_STRENGTH_CAP = 0.8
	const NIGHT_ROUTE_READING_STRENGTH = 0.35
	const DEFAULT_CARD_STRENGTH = 0.6
	const DEFAULT_DEFEND_STRENGTH = 0.5
	const FALLBACK_DEFEND_STRENGTH = 0.15

	## Default public-claim / reveal-cost / disclosure-tier modifiers (`sim/role_def.gd`)
	const HIDE_FROM_DEMON_CLAIM = -0.5
	const ONGOING_INFO_EARLY_CLAIM = -0.4
	const ONE_SHOT_GIFT_CLAIM = 0.3

	## Per-role tuning blocks (`sim/roles/*.gd`)
	const SEER = {
		"public_threat_bonus": 1.0,
		"reading_strength_yes": 0.9,
		"card_strength_yes": 1.0,
		"defend_strength_no": 0.8,
		"eff_yes_pair": 0.45,
		"eff_yes_solo": 0.85,
		"eff_no_own": -0.45,
		"eff_no_heard": -0.3,
		"red_herring_defence_eff": -0.12,
		"focus_base": 0.3,
		"focus_insight_scale": 0.5,
		"sharp_insight_threshold": 0.6,
		"req_already_wondering": 0.3,
		"req_doubting_friend": -0.25,
		"req_already_looked": -0.3,
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
		"eff_zero": -0.25,
		"eff_per_evil": 0.35,
		"eff_per_evil_excluded": 0.7,
		"eff_impossible_source": 0.5,
	}

	const HEARTHWITCH = {
		"card_strength_per_evil": 0.5,
		"defend_strength_zero": 0.6,
		"eff_zero": -0.25,
		"eff_per_evil": 0.35,
		"eff_per_evil_excluded": 0.7,
		"eff_impossible_source": 0.5,
	}

	const CLERK = {
		"defend_strength": 0.5,
		"eff_named_listener": -0.3,
		"eff_pair_good": -0.15,
	}

	const ARCHIVIST = {
		"reading_strength_demon": 0.6,
		"reading_strength_evil": 0.4,
		"reading_strength_good": 0.15,
		"card_strength": 0.8,
		"eff_pair": 0.35,
		"eff_solo": 0.75,
	}

	const GRAVEDIGGER = {
		"card_strength": 0.3,
		"marked_evil_chance": 0.3,
		"eff_executed_evil": 1.0,
		"eff_executed_good": -0.4,
		"eff_nominator_of_good": 0.25,
		"eff_nominator_of_evil": -0.2,
		"trust_backed_innocent": -0.06,
		"trust_proven_right_base": 0.08,
		"trust_proven_right_insight": 0.06,
	}

	const NIGHTWATCH = {
		"card_strength_seen": 1.0,
		"defend_strength": 0.0,
		"eff_lied_about_listener": 0.45,
		"eff_seen_out": 0.5,
		"req_already_wondering": 0.3,
	}

	const RUMORMONGER = {
		"eff_pair_good": -0.12,
	}

	const MEDIUM = {
		"reading_strength": 0.5,
		"relay_reading_scale": 0.6,
		"eff_dead_sighting": 0.3,
		"dead_suspicion_min": 0.35,
	}

	const VETERAN = {
		"quiet_night_effect": -0.06,
		"quiet_night_claim_weight": 0.025,
		"eff_attacker_block": 0.12,
	}

	const MARTYR = {
		"claim_chosen_bonus": 0.4,
		"reading_strength_evil": 0.9,
		"eff_chosen_good": -0.2,
		"eff_hanged_evil": 1.0,
		"pick_min_score": 0.62,
		"substitute_clear_eff": -2.0,
	}

	const SEXTON = {
		"toll_few_left": 0.35,
		"toll_per_dead": 0.1,
	}

	const PSYCHOLOGIST = {
		"conversation_nudge": 0.5,
	}

	const BREATHSTEALER = {
		"phase_probs_high": [0.3, 0.5, 1.0],
		"phase_probs_low": [0.15, 0.3, 0.7],
		"high_score_threshold": 1.0,
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

	## Credibility (honesty) discounting from evidence against a source
	const HONESTY_K = 0.8
	const HONESTY_CAP = 0.5
	const NIGHT_DOUBT_CAP = 0.9

	## Role-claim & sighting ledger weights
	const RIVAL_CLAIM_EFF = 0.6
	const DEMON_VICTIM_CLAIM_BOOST = 1.95
	const NIGHT_SIGHTING_NEAR_DEATH = 1.0
	const NIGHT_SIGHTING_ELSEWHERE = 0.12
	const NIGHT_SIGHTING_WALK_DISCOUNT = 0.7
	const HEARD_READING_WEIGHT = 0.5

	## Reconsideration & shadow self
	const RECONSIDER_TRUST_DELTA = 0.1
	const RECONSIDER_MIN_SHIFT = 0.03
	const RECONSIDER_CONFIDENCE_DAMP = 0.6
	const SHADOW_OWN_READING_WEIGHT = 1.2


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
	const DISTRUST_EXPLAIN_THRESHOLD = 0.35

	## Overnight secret-keeping recovery
	const SECRET_KEPT_BASE = 0.03
	const SECRET_KEPT_PRIVACY_SCALE = 0.04
	const SECRET_KEPT_RUMOR_MULT = 0.4
	const SECRET_KEPT_DECAY = 0.5
	## No grief for a hanged friend the mourner already believed evil (Oct 30).
	const GRIEF_BELIEVED_EVIL = 0.6  # each later night is worth half the one before (Oct 30)

	## Broken confidence & spread secrets
	const CONFIDENCE_BROKEN_BASE = 0.05
	const CONFIDENCE_BROKEN_PRIVACY = 0.2
	const SECRET_SPREAD_BASE = 0.08
	const SECRET_SPREAD_PRIVACY = 0.4
	const SECRET_SPREAD_REPEAT_MULT = 0.4
	const SECRET_CAP_HIGH_PRIVACY = 0.3
	const SECRET_CAP_MID_PRIVACY = 0.6

	## Conversation, pressing & presentations
	const CIVIL_TALK_BASE = 0.04
	const CIVIL_TALK_PRIVACY_DAMP = 0.5
	const QUESTION_FATIGUE_LIMIT = 3
	const QUESTION_FATIGUE_BASE = 0.03
	const QUESTION_FATIGUE_PRIVACY = 0.05
	const QUESTION_FATIGUE_COMPOSURE_DAMP = 0.5
	const PRESSED_EVIDENCE_BASE = 0.03
	const PRESSED_EVIDENCE_PRIVACY = 0.06
	const WRONG_ROLE_GUESS_STEP = 0.02
	const WARD_SIGIL_BONUS = 0.05
	const WARD_SIGIL_TARGET_BONUS = 0.15
	const SELF_SUPPORT_BONUS = 0.03
	const PRESENTATION_REWARD = 0.02


# ---------------------------------------------------------------- 5. Background Social Gossip & Approaches
class Social:
	const NEWS_BONUS_EVIL = 0.6
	const NEWS_BONUS_GOOD = 0.5
	const IDLE_CHAT_WEIGHT = 0.3
	const HEARSAY_TRUST_SCALE = 0.75
	const HEARSAY_WEIGHT_CAP = 0.55
	const SHARE_TRUST_BUMP = 0.02
	const TAVERN_WHISPER_MIN_CROWD = 4
	const TAVERN_WHISPER_CHANCE = 0.5
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
	const PROTECTION_MIN_TRUST = 0.45


# ---------------------------------------------------------------- 6. Town Meeting: Claims, Consensus, Nominations & Votes
class Meeting:
	const VOLUNTEER_SIGHTING_BASE = 1.2
	const PUBLIC_CLAIM_BASE = -0.35
	const PUBLIC_CLAIM_FEW_LEFT = 0.8
	const PUBLIC_CLAIM_PROMISED_PLAYER = -0.6

	## Anonymous reading relays
	const RELAY_WEIGHT = 0.3
	const RELAY_CORROBORATE = 0.05

	## Social consensus bandwagon pressure
	const CONSENSUS_BASE = 0.12
	const CONSENSUS_FADE = 0.6
	const CONSENSUS_CAP = 0.3
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

	## Nomination threshold & failed-vote cooloff
	const NOMINATION_BASE = 0.65
	const NOMINATION_DAY_SLOPE = 0.05
	const NOMINATION_FLOOR = 0.40
	const NOMINATION_CONFIDENCE_SCALE = 0.20
	const NOMINATION_PARANOIA_SCALE = 0.5
	const NOMINATION_OWN_CLEAR_RELIEF = 0.2
	const NOMINATION_COOLOFF_SELF = 0.28
	const NOMINATION_COOLOFF_ROOM = 0.10

	## Voting threshold
	const VOTE_BASE_NEED = 0.5
	const VOTE_CONFIDENCE_SCALE = 0.12
	const VOTE_DAY1_PENALTY = 0.1
	const VOTE_PARANOIA_WEIGHT = 0.4
	## Urgency (Oct 30, replaces paranoia drift): the bar drops per death; Composure doesn't cancel it.
	const VOTE_URGENCY_PER_DEATH = 0.02


# ---------------------------------------------------------------- 7. One-on-One Dialogue, Pressing & Disclosure
class Dialogue:
	const OPENNESS_BASE_OFFSET = -0.72
	const OPENNESS_JITTER = 0.1  # was 0.2; a daily sample since Oct 30
	const TIER_VAGUE = 0.15
	const TIER_PARTIAL = 0.45
	const TIER_FULL = 0.75

	## Fear of the Demon when considering disclosure
	const FEAR_BASE = 0.2
	const FEAR_COMPOSURE_SCALE = 0.3
	const FEAR_PRESSURE_SCALE = 0.5
	const FEAR_EASED_MULT = 0.5
	const FEAR_CAP = 0.85

	## Pressing with evidence
	const PRESS_NERVES_HIDING = 0.6
	const PRESS_NERVES_HONEST = 0.2
	const PRESS_PRESSURE_GAIN = 0.35

	## Lying alibi slip rate
	const SLIP_COMPOSURE_SCALE = 0.25
	const SLIP_PRESSURE_SCALE = 0.15


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
	const EVIL_NOMINATION_BASE_HEAT = 0.42
	const EVIL_NOMINATION_CONFIDENCE_SCALE = 0.16
	const EVIL_POCKET_FRAME_BONUS = 0.16
	const EVIL_WALKER_INTEL_BONUS = 0.08

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
	const KILL_NOISE = 0.8
	const KILL_UNPREDICTABLE_CHANCE = 0.03

	## Poisoner target scoring
	const POISON_GIFT_SPENT = -3.5
	const POISON_HOSTILITY_SCALE = 0.6
	const POISON_WARDEN_INFO = 2.5
	const POISON_WARDEN_OTHER = 1.2
	const POISON_NOISE = 1.5


# ---------------------------------------------------------------- 9. Workshop Evaluator, Bounded Reasoner & Presentation
class Workshop:
	## CaseEval report error rates & likelihood-ratio cutoffs (`workshop/case_eval.gd`)
	const DEFAULT_ERR = 0.01
	const OWN_ERR = 0.002
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
	## Directional Confidence: below this lean (suspicion minus the listener's average) there
	## is no hunch to defend, so Confidence doesn't resist (Oct 30).
	const LEAN_MIN = 0.05
	const HEADLINE_SEER = 1.0       # "one of A/B is the Demon": each 1/2
	const HEADLINE_ARCHIVIST = 1.0  # "one of A/B holds <evil role>": each 1/2
	const HEADLINE_DOWSER = 1.0     # "c of these n read as evil": each c/n

	## Role constraints, movement & public/speech evidence (`workshop/*.gd`)
	const BLUFF_WEIGHT = 0.92
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

	## Stage 2 Circumstantial Evidence Hub (`workshop/circumstantial.gd`)
	const CIRCUMSTANTIAL_INCIDENT_MAX = 0.015
	const CIRCUMSTANTIAL_TARGET_CAP = 0.045
	const CIRCUMSTANTIAL_GATE_REF = 0.06
	const CIRCUMSTANTIAL_SMEAR_MIN = 0.005
	const CIRCUMSTANTIAL_SMEAR_MAX = 0.015

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

	## Bounded reasoning attention profiles (`workshop/reasoner.gd`)
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

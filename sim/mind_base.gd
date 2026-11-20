## Shared by the Mind chain (`mind_shadow` <- `mind_cases` <- `mind_ledger` <- `mind`): the
## preloads, every module constant, and `_mind()`. Split from `sim/mind.gd`.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const WorkshopLedgerProfiler = preload("res://workshop/profiler.gd")

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindNomination = preload("res://sim/mind_nomination.gd")
const MindDefence = preload("res://sim/mind_defence.gd")
const MindVote = preload("res://sim/mind_vote.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const MindPress = preload("res://sim/mind_press.gd")
const MindAnswers = preload("res://sim/mind_answers.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")

static func _mind():
	return load("res://sim/mind.gd")


## Fields copied once, when the shadow is made (a turned NPC's good mind carries over).
const SHADOW_COPY = ["traits", "trait_base", "work_phases", "haunts", "friends", "rivals",
	"suspicion", "npc_trust", "ledger", "honesty", "discounted", "believed_roles",
	"cleared", "protect_pref", "spare_pref", "known_claims", "known_secrets", "heard", "used_facts", "workshop_state", "consensus_pressure", "claim_record", "resentments"]
const SHADOW_SAME = ["id", "name", "pron", "style", "blurb", "occupation", "work", "home_block", "ring"]
const SERIOUS_GRIEVANCE = Tuning.Trust.SERIOUS_GRIEVANCE
const CONSENSUS_BASE = MindMeeting.CONSENSUS_BASE
const CONSENSUS_FADE = MindMeeting.CONSENSUS_FADE
const CONSENSUS_CAP = MindMeeting.CONSENSUS_CAP
const CONSENSUS_HINT = MindMeeting.CONSENSUS_HINT

## Shared by the Social chain (`social_approaches` <- `social_tavern` <- `social`): the
## preloads, every module constant and the small helpers. Split from `sim/social.gd`.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const PsychologistRole = preload("res://sim/roles/psychologist.gd")
const Burdens = preload("res://sim/burdens.gd")

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

static func _told(s, l, key: String) -> bool:
	return s.told_to.has(l.id + "|" + key)

static func _mark(s, l, key: String) -> void:
	s.told_to[l.id + "|" + key] = true

static func _implicated(e: Dictionary) -> Array:
	return Gifts.implicated(e)

## The gift this NPC would name to a peer: their own, or evil's agreed bluff.
static func _my_role(w, s) -> String:
	var r: String = str(w.evil_plan.get("bluffs", {}).get(s.id, "")) if s.is_evil() else str(s.role)
	return r if C.ROLES.has(r) else ""

## Has a good NPC told any trusted friend about their gift yet (hint or claim)?
static func _gift_told_a_friend(w, n) -> bool:
	for l in w.living():
		if l == n or n.npc_trust.get(l.id, 0.5) < Tuning.Social.GOOD_NEWS_TRUST_MIN:
			continue
		if _told(n, l, "role_hint:" + n.id) or _told(n, l, "role_claim:" + n.id):
			return true
	return false

const TAVERN_LEADS = [
	"Word about town is that ",
	"Someone at the bar mentioned that ",
	"Talk in the taproom has it that ",
	"Over the clink of tankards, you hear that ",
	"Rumour making the rounds says that ",
]
const HINT_TOPICS = {
	"official": "records and official town business",
	"night_sight": "seeing things in the dark hours",
	"the_dead": "the dead",
	"shelter": "sheltering people from the Demon and those who serve it",
	"people": "reading people",
	"affairs": "the town's affairs",
	"justice": "the gallows",
	"true_gifts": "people's true callings",
	"chosen": "looking into whomever they choose",
	"against_dark": "bringing to light what the night hides",
	"conquer_death": "cheating death",
}
## The town's vibe check on the Demonologist: rapport (trust in you) and competence (your
## credibility) averaged over the living good townsfolk. Evil's private view is left out on
## purpose (a deliberate fudge: the town's mood, not the demon's). No RNG draws.
## Returns {line, rapport, credibility, rapport_band, credibility_band, trend} or {}.
const VIBE_RAPPORT = ["the town is openly hostile to you", "folk mostly distrust you", "folk are wary of you",
	"the town hasn't made up its mind about you", "folk are warming to you", "you're well liked", "the town is fond of you"]
const VIBE_COMPETENCE = ["most take you for a fraud", "your word counts for little", "few put much stock in your judgement",
	"your judgement is still unproven", "your judgement shows promise", "they think you're sharp", "they reckon you're the real thing"]

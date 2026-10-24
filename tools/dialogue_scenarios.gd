## Explicit, synthetic fixtures shared by the comparison scene and transcript.
## They are not events from a real case, and do not reveal actual cast assignments.
extends RefCounted

const IDS = ["agnes", "bart", "constance"]
const SCENARIOS = [
	{
		"title": "Reporting information", "kind": "report", "event_id": "reading:seer:2",
		"statement": "On night 2, my sight showed that either Edda or Jory is the demon.",
		"context": {},
		"note": "A reported Seer result, not a certification of truth. Try asking again, lowering trust, or changing audience.",
	},
	{
		"title": "Being doubted", "kind": "doubted", "event_id": "challenge:night:2",
		"statement": "From my window, I saw Jory pass through the Square on night 2.",
		"context": {"challenged": true},
		"note": "The player has challenged this account. The response must retain its source, person, place and night.",
	},
	{
		"title": "Discussing a friend", "kind": "friend", "event_id": "opinion:edda",
		"statement": "I have my doubts about Edda.",
		"context": {"close": true, "subject": "Edda"},
		"note": "The speaker is close to Edda but has doubts. Affection must not erase suspicion. Remove the relationship to test the guard.",
	},
	{
		"title": "Concealing a secret", "kind": "conceal", "form": "whereabouts", "event_id": "whereabouts:2",
		"statement": "Where I go at night is my own business.",
		"context": {"withholding": true},
		"note": "The simulation has chosen to refuse. The composer does not receive the secret, location, or actual alignment.",
	},
	{
		"title": "Revising a belief", "kind": "revise", "form": "reconsideration", "event_id": "reconsider:poison:edda:2",
		"argument": "your argument that Edda was poisoned on night 2",
		"statement": "I didn't put much stock in your argument that Edda was poisoned on night 2. After all that's happened since... perhaps I should have.",
		"context": {"reconsidered": true},
		"note": "An existing reconsideration event authorizes this line. It acknowledges more weight, not proof that the claim is true.",
	},
	{
		"title": "Accepting a case",
		"kind": "argument",
		"key": "demon:edda",
		"claim": "Edda is the demon",
		"stance": "accept",
		"facts": [
			"reading:2"
		],
		"target_id": "edda",
		"accusing": true,
		"statement": "Edda is the demon",
		"context": {
			"decided": true
		},
		"note": "Synthetic resolved decision: controls change audience, not the underlying evidence assessment."
	},
	{
		"title": "A competing explanation",
		"kind": "argument",
		"key": "demon:isolde",
		"claim": "Isolde is the demon",
		"stance": "partial",
		"facts": [
			"reading:2"
		],
		"target_id": "isolde",
		"accusing": true,
		"statement": "Isolde is the demon",
		"context": {
			"decided": true
		},
		"note": "Synthetic resolved decision: controls change audience, not the underlying evidence assessment.",
		"reason": "alternative",
		"alternative": "another visitor left the trace",
		"preferred": "Hollis"
	},
	{
		"title": "Weak support",
		"kind": "argument",
		"key": "notrole:edda:surveyor",
		"claim": "Edda is not the Surveyor",
		"stance": "reject",
		"facts": [
			"claim:surveyor",
			"sighting:day:2"
		],
		"target_id": "edda",
		"accusing": true,
		"statement": "Edda is not the Surveyor",
		"context": {
			"decided": true
		},
		"note": "Synthetic resolved decision: controls change audience, not the underlying evidence assessment.",
		"reason": "weak"
	},
	{
		"title": "Distrusting a source",
		"kind": "argument",
		"key": "demon:jory",
		"claim": "Jory is the demon",
		"stance": "partial",
		"facts": [
			"reading:2"
		],
		"target_id": "jory",
		"accusing": true,
		"statement": "Jory is the demon",
		"context": {
			"decided": true
		},
		"note": "Synthetic resolved decision: controls change audience, not the underlying evidence assessment.",
		"reason": "source",
		"source": "Hollis"
	},
	{
		"title": "Same evidence, changed assessment",
		"kind": "argument",
		"key": "demon:edda",
		"claim": "Edda is the demon",
		"stance": "accept",
		"facts": [
			"reading:2"
		],
		"target_id": "edda",
		"accusing": true,
		"statement": "Edda is the demon",
		"context": {
			"decided": true
		},
		"note": "Earlier rejection is seeded as delivered history. The new assessment is supplied explicitly; the composer does not decide to change its mind.",
		"prior": [
			{
				"title": "Accepting a case",
				"kind": "argument",
				"key": "demon:edda",
				"claim": "Edda is the demon",
				"stance": "reject",
				"facts": [
					"reading:2"
				],
				"target_id": "edda",
				"accusing": true,
				"statement": "Edda is the demon",
				"context": {
					"decided": true
				},
				"note": "Synthetic resolved decision: controls change audience, not the underlying evidence assessment.",
				"reason": "weak"
			}
		]
	},
	{
		"title": "New evidence for an existing case",
		"kind": "argument",
		"key": "demon:edda",
		"claim": "Edda is the demon",
		"stance": "accept",
		"facts": [
			"reading:2",
			"sighting:night:3"
		],
		"target_id": "edda",
		"accusing": true,
		"statement": "Edda is the demon",
		"context": {
			"decided": true
		},
		"note": "Earlier acceptance is seeded. Same conclusion, additional evidence: this is not a duplicate argument.",
		"prior": [
			{
				"title": "Accepting a case",
				"kind": "argument",
				"key": "demon:edda",
				"claim": "Edda is the demon",
				"stance": "accept",
				"facts": [
					"reading:2"
				],
				"target_id": "edda",
				"accusing": true,
				"statement": "Edda is the demon",
				"context": {
					"decided": true
				},
				"note": "Synthetic resolved decision: controls change audience, not the underlying evidence assessment."
			}
		]
	},
	{
		"title": "Nominating with a reason",
		"kind": "nomination",
		"target": "Greta",
		"reason_text": "Jory's sight pointed at them.",
		"statement": "Nominate Greta, citing Jory.",
		"context": {
			"decided": true
		},
		"note": "The target and citation were already chosen by the simulation."
	},
]

## Multi-line examples test flow separately from the decision that approved each fact.
## "relation" is a rhetorical relation explicitly supplied by the caller, never
## inferred by inspecting a possibly fabricated account.
const FLOW_SCENARIOS = [
	{
		"title": "Role reveal and three readings",
		"note": "One speaker turn after an already-spoken role disclosure: no fresh opening on each reading.",
		"lead_in": "I'll trust you with this. I'm the Seer.",
		"preceded": true,
		"parts": [
			{"kind": "report", "event_id": "flow:seer:0", "statement": "On night 0, Edda or Jory read as the demon."},
			{"kind": "report", "event_id": "flow:seer:1", "statement": "On night 1, neither Greta nor Fenwick read as the demon."},
			{"kind": "report", "event_id": "flow:seer:2", "statement": "On night 2, Hollis or Isolde read as the demon."},
		],
	},
	{
		"title": "Developing and qualifying a thought",
		"note": "The relationship between sentences is approved explicitly; the renderer does not decide that a statement is contradictory.",
		"parts": [
			{"kind": "report", "event_id": "flow:account:0", "statement": "I saw Jory near the square."},
			{"kind": "report", "event_id": "flow:account:1", "relation": "development", "statement": "I saw Fenwick there as well."},
			{"kind": "report", "event_id": "flow:account:2", "relation": "contrast", "statement": "I could not tell whether they arrived together."},
		],
	},
	{
		"title": "Changing topic and correcting an account",
		"note": "An explicit topic transition and correction, without changing the approved facts.",
		"parts": [
			{"kind": "report", "event_id": "flow:topic:0", "statement": "I was at home that evening."},
			{"kind": "report", "event_id": "flow:topic:1", "relation": "transition", "statement": "I heard that Greta was seen by the wharf."},
			{"kind": "report", "event_id": "flow:topic:2", "relation": "correction", "statement": "To be precise, that report concerned the afternoon."},
		],
	},
]

## Synthetic sequences across *separate* player/NPC exchanges. The player's
## immediately preceding spoken act is supplied explicitly; it is not inferred.
const EXCHANGE_SCENARIOS = [
	{
		"title": "Gift reveal after pressure",
		"mode": "gift", "previous_action": "challenge_gift", "role": "Seer",
		"statement": "I'm the Seer.",
		"note": "Player just challenged this person's gift. The simulation now independently approved a first-time Seer claim. No alignment or truth is supplied.",
	},
	{
		"title": "Opinion after accusation",
		"mode": "opinion", "previous_action": "accusation", "subject_id": "edda", "subject_name": "Edda",
		"statement": "I have my doubts about Edda.",
		"note": "Player just accused Edda in a private exchange. The next response acknowledges that subject without asserting agreement with the accusation.",
	},
	{
		"title": "Repeated refusal about someone",
		"mode": "refusal", "previous_action": "opinion", "subject_id": "edda", "subject_name": "Edda",
		"statement": "It's not my place to say.",
		"note": "NPC refused the previous question about Edda. On a repeat, they still refuse, but do not recite the same boilerplate.",
	},
]

## Seed only explicit fictional prior speech, once per scenario/audience. Preview callers
## pass copied memory, so inspecting a scenario never delivers it to the real history.
static func prime(id: String, scenario: Dictionary, audience: String, memory: Dictionary) -> void:
	if not scenario.has("prior"):
		return
	var token = "fixture:" + scenario["title"] + ":" + audience
	if memory.has(token):
		return
	for prior in scenario["prior"]:
		preload("res://sim/dialogue.gd").decision(id, prior, audience, memory)
	memory[token] = true

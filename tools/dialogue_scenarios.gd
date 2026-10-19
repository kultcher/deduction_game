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
	{
		"title": "Accepting evidence, withholding a vote",
		"kind": "vote",
		"target": "Edda",
		"target_id": "edda",
		"yes": false,
		"reason": "trust",
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
		],
		"statement": "Vote no on Edda, despite accepting the earlier case.",
		"context": {
			"decided": true
		},
		"note": "Acceptance is remembered, but the resolved vote is no. Trust in the nominee was a contributing factor."
	},
	{
		"title": "Keeping someone else on the block",
		"kind": "vote",
		"target": "Edda",
		"target_id": "edda",
		"yes": false,
		"reason": "block",
		"block": "Hollis",
		"statement": "Vote no on Edda; prefer Hollis on the block.",
		"context": {
			"decided": true
		},
		"note": "The existing block preference contributed to a no vote."
	},
	{
		"title": "The player tips a vote",
		"kind": "vote",
		"target": "Greta",
		"target_id": "greta",
		"yes": true,
		"reason": "accuse",
		"statement": "Vote yes on Greta; the player accusation contributed.",
		"context": {
			"decided": true
		},
		"note": "The actual decision has already been made. No extra suspicion or RNG is added."
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

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
]

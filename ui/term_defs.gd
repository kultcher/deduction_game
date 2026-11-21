## Learning resources, layer 1 (BACKLOG "Learning resources", [decided: direction]): the
## mechanics terms that the text formatter marks with a tooltip, and the tooltips on UI
## controls. One registry, so the later field manual (layer 2) reads the same words.
## Wording approved by Michael, Nov 18.
extends RefCounted

## Each term: id, label, aliases (as in TextTerms.register_term) and a tooltip.
## Common words match only capitalized, so ordinary prose ("a ward of the parish") is left alone.
const MECHANICS = [
	{"id": "on_the_block", "label": "On the Block", "aliases": [{"text": "on the block"}],
		"tooltip": "On the Block: the person the town will hang at the day's end, unless a later nomination draws more votes. A tie clears the block."},
	{"id": "vigil", "label": "Vigil", "aliases": [{"text": "Vigil", "case_sensitive": true}, {"text": "vigil", "case_sensitive": true}],
		"tooltip": "Vigil: you spend the night watching one block. You only see if its residents leave home. You do not see people arrive on this block from elsewhere."},
	{"id": "ward", "label": "Ward", "aliases": [{"text": "Ward", "case_sensitive": true}],
		"tooltip": "Ward: once per case, you sign a door at night and the Demon cannot kill there. A stopped kill leaves a scorched sigil, which you can show the town."},
	{"id": "clemency", "label": "Clemency", "aliases": [{"text": "Clemency"}],
		"tooltip": "Clemency: once per case, you cancel a nomination as it is made. The one you spare trusts you more; the others judge you by what they think of them."},
	{"id": "trace", "label": "Trace", "aliases": [{"text": "Trace", "case_sensitive": true}, {"text": "Traces", "case_sensitive": true}],
		"tooltip": "Trace: something the killer left at the scene. A token names two places and a scent names three; it points at whoever frequents them."},
	{"id": "speech", "label": "Speech", "aliases": [{"text": "Speech", "case_sensitive": true}],
		"tooltip": "Speech: what someone said, whether a claim, an opinion, an accusation or an alibi. Easy to say, so it weighs least."},
	{"id": "circumstantial", "label": "Circumstantial", "aliases": [{"text": "Circumstantial", "case_sensitive": true}, {"text": "circumstantial", "case_sensitive": true}],
		"tooltip": "Circumstantial: what others report having seen or read, and the traces at a scene. It weighs more than talk, less than what you saw yourself."},
	{"id": "concrete", "label": "Concrete", "aliases": [{"text": "Concrete", "case_sensitive": true}],
		"tooltip": "Concrete: what you witnessed yourself, items that name their owner, and the Town Hall's records."},
	{"id": "night_order", "label": "Night order", "aliases": [{"text": "night order"}],
		"tooltip": "Night order: walkers set out, then the gifts give their readings, then the Demon kills. So a reading from the night someone died was taken while they lived."},
	{"id": "trait_privacy", "label": "Privacy", "aliases": [{"text": "Privacy", "case_sensitive": true}],
		"tooltip": "Privacy: how readily they talk about their own affairs."},
	{"id": "trait_gossip", "label": "Gossip", "aliases": [{"text": "Gossip", "case_sensitive": true}],
		"tooltip": "Gossip: how readily they pass on what they have heard."},
	{"id": "trait_confidence", "label": "Confidence", "aliases": [{"text": "Confidence", "case_sensitive": true}],
		"tooltip": "Confidence: how firmly they hold their views once formed."},
	{"id": "trait_insight", "label": "Insight", "aliases": [{"text": "Insight", "case_sensitive": true}],
		"tooltip": "Insight: how hard they are to sway with a weak argument."},
	{"id": "trait_composure", "label": "Composure", "aliases": [{"text": "Composure", "case_sensitive": true}],
		"tooltip": "Composure: how much their face gives away."},
	# Burdens (Michael, Nov 21: approved).
	{"id": "burden", "label": "Burden", "aliases": [{"text": "Burden", "case_sensitive": true}, {"text": "Burdens", "case_sensitive": true},
		{"text": "burden", "case_sensitive": true}, {"text": "burdens", "case_sensitive": true}],
		"tooltip": "Burden: something that weighs on a townsperson, on top of their gift. The script lists the possible burdens and how many are in play. A hidden burden's holder doesn't know they carry it."},
	# The Ill-Omened board marker's tooltip is the burden's rules text (Michael, Nov 21).
	{"id": "omen", "label": "Ill-Omened", "aliases": [{"text": "omen", "case_sensitive": true}, {"text": "Omen", "case_sensitive": true}],
		"tooltip": "Ill-Omened: If hanged after claiming this burden, every good person is poisoned that night until the start of the next night."},
]

## Mistaken (Michael, Nov 19): the honest-failure label for a reading. Its tooltip names
## only the causes this town's script allows (ReadingChallenges.game_honest_causes), so it
## is built per game: TextTerms.set_honest_causes.
const MISTAKEN = {"id": "mistaken", "label": "Mistaken", "aliases": [{"text": "Mistaken", "case_sensitive": true}]}
const CAUSE_NAMES = {"poison": "poison", "delusion": "delusion", "red_herring": "a Red Herring", "marked": "a Marked soul"}

## The Mistaken tooltip for these causes (ReadingChallenges.HONEST_CAUSES ids, in order).
static func mistaken_tip(causes: Array) -> String:
	var names: Array = []
	for c in causes:
		if CAUSE_NAMES.has(c):
			names.append(CAUSE_NAMES[c])
	var head = "Mistaken: a reading that was wrong but honestly told."
	if names.is_empty():
		return head + " Nothing in this town can fool a gift."
	var listed: String = names[0] if names.size() == 1 else "%s or %s" % [", ".join(PackedStringArray(names.slice(0, names.size() - 1))), names[-1]]
	return head + " Something fooled the gift; in this town that could be %s." % listed

## Tooltips for action buttons, by the start of the button's label.
const CONTROLS = [
	["Let the town speak", "Let the next townsperson have their say. It costs you nothing."],
	["Nominate", "Put someone forward to be hanged. The town then votes."],
	["Close the meeting", "End the meeting, once the town has fallen quiet."],
	["Vote to execute", "Your vote counts like anyone's."],
	["Vote to spare", "Your vote counts like anyone's."],
	["Present a case about them", "Put one filed case about the nominee to the town before the vote. It doesn't use your Present."],
	["Invoke Clemency", "Cancel this nomination. Once per case; the one you spare trusts you more."],
	["Keep vigil on", "Watch one block tonight: you see its residents leave home."],
	["Ward", "Sign a door tonight so the Demon cannot kill there. Once per case."],
	["Sleep", "Spend the night at home."],
	["Present a deduction", "Put a filed case to the whole town. Once per meeting."],
	["Take back a case", "Withdraw a filed case in public. If the town still thinks it wrong at dawn, it may cost you some of their trust."],
	["Show the grimoire", "See who everyone truly was."],
]

## The tooltip for a button labelled `text`, or "".
static func control_tip(text: String) -> String:
	for pair in CONTROLS:
		if text.begins_with(pair[0]):
			return pair[1]
	return ""

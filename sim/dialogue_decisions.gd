## Presentation only. The caller supplies a resolved decision and approved public reasons.
## No world, role, secret, evidence evaluator, or gameplay RNG belongs here.
extends RefCounted

const LINES = {
	"default": {
		"accept": "That makes sense to me: {claim}.",
		"already": "I'd come to that already: {claim}.",
		"partial": "I can see a case for {claim}, but I'm not convinced.",
		"reject": "I'm not persuaded that {claim}.",
		"repeat": "We've discussed this evidence. My answer is the same.",
		"changed": "I've reconsidered what you showed me.",
		"new_evidence": "That's something more to consider.",
		"reframed": "You're making the case with fewer of the same facts.",
		"alternative": "I find another explanation more likely: {alternative}.",
		"possible_alternative": "There's still another possibility: {alternative}.",
		"weak": "The evidence you've cited doesn't establish that.",
		"quality": "I'm not confident enough in the evidence behind it.",
		"source": "I'm doubtful of {source}'s account.",
		"preferred": "I'm more suspicious of {preferred}.",
		"nominate": "I nominate {target}.",
	},
	"agnes": {
		"accept": "Yes, I follow you: {claim}.",
		"already": "I'd got there myself, love: {claim}.",
		"partial": "I understand your argument that {claim}. I'm just not sure yet.",
		"reject": "I can't agree that {claim}.",
		"repeat": "I remember, love. I still see that evidence the same way.",
		"changed": "I've been thinking about what you showed me. I see it differently now.",
		"new_evidence": "All right, that gives us something more to work with.",
		"alternative": "What seems likelier to me is this: {alternative}.",
		"possible_alternative": "But we must leave room for this: {alternative}.",
		"weak": "I don't think those pieces quite get us there.",
		"quality": "I wish I felt surer of the evidence we're relying on.",
		"source": "I'm having trouble trusting {source}'s account.",
		"preferred": "It's {preferred} I'm more worried about.",
		"nominate": "I'll put the name forward: {target}.",
	},
	"bart": {
		"accept": "Fair case: {claim}.",
		"already": "Knew that already. {claim}, aye.",
		"partial": "Could be that {claim}. I'm not certain.",
		"reject": "Not convinced that {claim}.",
		"repeat": "Same evidence. Same answer.",
		"changed": "Thought it over. Changed my view.",
		"new_evidence": "That's new. Worth weighing.",
		"alternative": "More likely: {alternative}.",
		"possible_alternative": "Still possible: {alternative}.",
		"weak": "Those facts don't get you there.",
		"quality": "Shaky evidence to build on.",
		"source": "Don't put much stock in {source}'s account.",
		"preferred": "I'd look harder at {preferred}.",
		"nominate": "Put {target} up for a vote.",
	},
	"constance": {
		"accept": "I accept the argument that {claim}.",
		"already": "I had already concluded that {claim}.",
		"partial": "The proposition that {claim} deserves consideration, though I remain uncertain.",
		"reject": "I cannot endorse the conclusion that {claim}.",
		"repeat": "You have supplied the same evidence. My assessment stands.",
		"changed": "I have revised my assessment of that evidence.",
		"new_evidence": "This adds to the account. Let us consider it.",
		"alternative": "I consider the following explanation more likely: {alternative}.",
		"possible_alternative": "An alternative remains open: {alternative}.",
		"weak": "The cited facts do not establish the conclusion.",
		"quality": "The reliability of the supporting evidence concerns me.",
		"source": "I have reservations about {source}'s account.",
		"preferred": "My greater suspicion rests with {preferred}.",
		"nominate": "I propose {target} for execution.",
	},
	"dorian": {
		"accept": "Wait—yes, when you lay it out like that, {claim}.",
		"already": "I'd actually worked out that {claim} already, though I wasn't sure I should say so.",
		"partial": "I can see why you'd think {claim}—really, I do—I'm just afraid of jumping too fast.",
		"reject": "Sorry, I really don't think {claim} holds together yet.",
		"repeat": "Sorry, that's the exact same case you showed me before, and I'm still stuck in the same place.",
		"changed": "Okay, wait—looking at it again, I think I talked myself out of it too fast.",
		"new_evidence": "Oh—that's a new piece, isn't it? Let me rethink how that fits.",
		"alternative": "Couldn't it just be that {alternative}?",
		"possible_alternative": "I keep worrying that {alternative} instead.",
		"weak": "I don't think those pieces quite prove what you want them to prove, sorry.",
		"quality": "I'm nervous about leaning so hard on shaky testimony.",
		"source": "I'm not sure we can take {source}'s word at face value here.",
		"preferred": "Honestly, {preferred} worries me a lot more right now.",
		"nominate": "I hate doing this, sorry, but I'm nominating {target}.",
	},
	"edda": {
		"accept": "That rings true enough to me, dear: {claim}.",
		"already": "I'd already settled on that myself: {claim}.",
		"partial": "There's some sense in {claim}, dear, though it's not baked through yet.",
		"reject": "No, dear, I can't make {claim} out of that.",
		"repeat": "Turning the same loaf over won't bake it any further, love.",
		"changed": "Well now, looking at it fresh, I've come round on this.",
		"new_evidence": "Now that's another ingredient in the bowl.",
		"alternative": "Plain sense says {alternative}.",
		"possible_alternative": "We've still got to allow that {alternative}.",
		"weak": "There's not enough meat on those bones yet, dear.",
		"quality": "I wouldn't hang a kettle on testimony that shaky.",
		"source": "I'm taking {source}'s word with a pinch of salt.",
		"preferred": "If we're minding the hearth, {preferred} is the one to watch.",
		"nominate": "No sense putting it off: I nominate {target}.",
	},
	"fenwick": {
		"accept": "Bravo! The pieces snap together: {claim}.",
		"already": "You're preaching to the choir, my friend—I'd already deduced that {claim}.",
		"partial": "A compelling draft that {claim}, though the third act still wants proof.",
		"reject": "Alas, the plot has too many holes to conclude that {claim}.",
		"repeat": "A familiar refrain, my friend, and my review remains unchanged.",
		"changed": "Ah, a dramatic reversal on my part—I see the pattern now!",
		"new_evidence": "Now there's a fresh twist for the chronicle!",
		"alternative": "Consider a rival staging of the scene: {alternative}.",
		"possible_alternative": "The curtain hasn't closed on another reading: {alternative}.",
		"weak": "A grand leap, my friend, on remarkably slender footing.",
		"quality": "The witnesses in this tale hardly inspire blind faith.",
		"source": "I suspect {source} may be embellishing more than I do.",
		"preferred": "For my coin, the true villain of the piece is {preferred}.",
		"nominate": "Let the town hear the name: I nominate {target}!",
	},
	"greta": {
		"accept": "Fine. The receipts line up: {claim}.",
		"already": "I didn't need you to spell it out—I already knew {claim}.",
		"partial": "You've got half a case that {claim}, outsider, not the whole thing.",
		"reject": "You're reaching if you think that proves {claim}.",
		"repeat": "Shoving the same cards in my face won't buy a different answer.",
		"changed": "All right, I've looked at the ledger again. I'm changing my stance.",
		"new_evidence": "Now that's an actual new fact on the table.",
		"alternative": "Here's the simpler read: {alternative}.",
		"possible_alternative": "You haven't ruled out that {alternative}.",
		"weak": "Come back when your facts actually pin the target down.",
		"quality": "You're building on word-of-mouth I wouldn't pay a copper for.",
		"source": "And why should I take {source}'s word for gospel?",
		"preferred": "Stop barking up the wrong tree and look at {preferred}.",
		"nominate": "Put {target} on the block and let them answer for it.",
	},
	"hollis": {
		"accept": "The inference is sound and well-supported: {claim}.",
		"already": "My own deduction had already arrived at the conclusion that {claim}.",
		"partial": "The hypothesis that {claim} is plausible, though not yet demonstrative.",
		"reject": "The premises supplied do not entail that {claim}.",
		"repeat": "Restating an identical syllogism yields the identical evaluation.",
		"changed": "Upon re-weighing the evidentiary chain, I must revise my conclusion.",
		"new_evidence": "Ah—an additional datum alters the inferential weight.",
		"alternative": "Parsimony favors a competing hypothesis: {alternative}.",
		"possible_alternative": "We cannot yet exclude the corollary that {alternative}.",
		"weak": "The evidentiary nexus here is altogether too tenuous.",
		"quality": "The epistemic pedigree of the underlying reports is questionable.",
		"source": "I attach considerable epistemic doubt to {source}'s testimony.",
		"preferred": "A rigorous accounting directs greater suspicion toward {preferred}.",
		"nominate": "On the weight of the record, I nominate {target}.",
	},
	"isolde": {
		"accept": "It pains me to say it, truly, but I must agree that {claim}.",
		"already": "I was already afraid in my heart that {claim}.",
		"partial": "I see why you fear that {claim}, though I pray there's still room for doubt.",
		"reject": "Please, I can't condemn anyone on the claim that {claim} with so little.",
		"repeat": "Please don't ask me again on the very same cards—my heart hasn't changed.",
		"changed": "Forgive me, I tried to resist it before, but I see your case differently now.",
		"new_evidence": "Oh, dear... that new piece does make it harder to look away.",
		"alternative": "Surely it is gentler—and likelier—that {alternative}.",
		"possible_alternative": "Might it still be that {alternative}?",
		"weak": "Those pieces are too slender to risk a neighbor's neck upon.",
		"quality": "I'm afraid the reports behind this are too uncertain to trust.",
		"source": "I'm sorry, truly, but I fear {source} may not be reliable here.",
		"preferred": "If I must name whom I fear most, it is {preferred}.",
		"nominate": "May heaven forgive me, I nominate {target}.",
	},
	"jory": {
		"accept": "Oh! Yeah, that tracks—{claim}!",
		"already": "Way ahead of you! Already figured {claim}.",
		"partial": "Maybe {claim}? Sort of fits, still feels a jump.",
		"reject": "Nah, wait—that doesn't prove {claim}.",
		"repeat": "Hey, same cards as last time! Still where I was.",
		"changed": "Wait, hold on—flipping my answer on this one!",
		"new_evidence": "Ooh, new card! That changes the picture.",
		"alternative": "Bet it's actually that {alternative}.",
		"possible_alternative": "Could still be that {alternative}, right?",
		"weak": "Missing a link there—doesn't quite connect!",
		"quality": "Shaky sources, though—hard to bet on that.",
		"source": "Not sure I'm buying {source}'s story here.",
		"preferred": "Honestly? I'm looking way harder at {preferred}.",
		"nominate": "Let's do it—I'm nominating {target}!",
	},
	"kiran": {
		"accept": "Cleanly played, Demonologist—I'll buy that {claim}.",
		"already": "Flattering to see you catch up: I'd already settled on {claim}.",
		"partial": "An intriguing gambit that {claim}, though I wouldn't bet the house on it yet.",
		"reject": "Charming theory, truly, but I'm not sold that {claim}.",
		"repeat": "Dealing the exact same hand twice won't change my bet, my friend.",
		"changed": "Consider me persuaded on the rematch—I've shifted my odds.",
		"new_evidence": "Ah, a new card from up your sleeve.",
		"alternative": "The smarter money says {alternative}.",
		"possible_alternative": "Unless, of course, {alternative}.",
		"weak": "A bit thin for a hanging offense, don't you think?",
		"quality": "Your witnesses are doing a great deal of heavy lifting there.",
		"source": "I'd check {source}'s sleeves before trusting that account.",
		"preferred": "If we're placing wagers, my eye is on {preferred}.",
		"nominate": "Let's make it interesting: I nominate {target}.",
	},
	"lian": {
		"accept": "Confirmed: {claim}.",
		"already": "Already logged: {claim}.",
		"partial": "Plausible that {claim}, but unverified.",
		"reject": "Unproven that {claim}. Bring tighter links.",
		"repeat": "Same inputs, same output. Move on.",
		"changed": "Updated my read on this case.",
		"new_evidence": "New evidence logged. Re-evaluating.",
		"alternative": "Better fit for the facts: {alternative}.",
		"possible_alternative": "Open gap in the chain: {alternative}.",
		"weak": "Insufficient support to act on.",
		"quality": "Source reliability is too low to act on.",
		"source": "{source}'s report doesn't hold up.",
		"preferred": "Higher-priority suspect is {preferred}.",
		"nominate": "Putting {target} to the vote.",
	},
	"merrin": {
		"accept": "Oh, heaven preserve us, it's true: {claim}!",
		"already": "I knew it in my bones already—{claim}!",
		"partial": "A chilling thought that {claim}, though I daren't swear to it yet!",
		"reject": "No, no, even in my darkest dread I cannot see how {claim}!",
		"repeat": "Showing me the same grim omen twice does not alter the reading!",
		"changed": "Oh, how blind I was! Looking again, the truth stares right back at us!",
		"new_evidence": "Another fateful sign added to the pile!",
		"alternative": "Far likelier this dreadful turn: {alternative}.",
		"possible_alternative": "Yet what if the dark truth is that {alternative}?",
		"weak": "A frightful accusation built on cobwebs!",
		"quality": "How can we stake our lives on such doubtful whispers?",
		"source": "I tremble to rely upon {source}'s word in this dark hour.",
		"preferred": "My every waking dread points straight at {preferred}!",
		"nominate": "Before another night claims us all, I nominate {target}!",
	},
	"nisha": {
		"accept": "The constraints lock in: {claim}.",
		"already": "That matches my working model: {claim}.",
		"partial": "The hypothesis that {claim} fits part of the board, but leaves branches open.",
		"reject": "The premise that {claim} fails against the current constraints.",
		"repeat": "Identical evidence set. My evaluation is unchanged.",
		"changed": "Re-running that evidence against the board changes my conclusion.",
		"new_evidence": "Adding that constraint narrows the remaining worlds.",
		"alternative": "The stronger competing model is that {alternative}.",
		"possible_alternative": "You haven't eliminated the branch where {alternative}.",
		"weak": "The cited cards don't isolate the target variable.",
		"quality": "The premise relies on uncorroborated testimony.",
		"source": "Discounting for {source}'s credibility weakens the chain.",
		"preferred": "The stronger signal on the board points to {preferred}.",
		"nominate": "To test the leading hypothesis, I nominate {target}.",
	},
	"odette": {
		"accept": "Much as I hate agreeing with a crowd, yes: {claim}.",
		"already": "I arrived at {claim} some time ago, without the fanfare.",
		"partial": "I grant you {claim} is amusingly plausible, though hardly proven.",
		"reject": "You'll forgive me if I don't applaud the theory that {claim}.",
		"repeat": "Presenting the same exhibit twice doesn't make it sharper.",
		"changed": "How tiresome—upon reflection, you've actually changed my mind.",
		"new_evidence": "Well, well. An actual new fact.",
		"alternative": "A far less strained explanation is that {alternative}.",
		"possible_alternative": "There remains the inconvenient possibility that {alternative}.",
		"weak": "A bold conclusion, considering the threadbare premises.",
		"quality": "I wouldn't buy a loaf of bread on testimony that flimsy.",
		"source": "Relying on {source}'s account is a brave choice.",
		"preferred": "If you want a sensible target, look at {preferred}.",
		"nominate": "Since someone must be the adult in the room, I nominate {target}.",
	},
}

## Single pass: names and quoted content cannot become template instructions.
static func _line(id: String, key: String, slots: Dictionary) -> String:
	var template: String = LINES.get(id, {}).get(key, LINES["default"].get(key, ""))
	var pattern = RegEx.new()
	pattern.compile("\\{([a-z_]+)\\}")
	var out = ""
	var cursor = 0
	for found in pattern.search_all(template):
		out += template.substr(cursor, found.get_start() - cursor)
		out += str(slots.get(found.get_string(1), ""))
		cursor = found.get_end()
	return out + template.substr(cursor)

static func render(id: String, d: Dictionary, audience: String, memory: Dictionary) -> Dictionary:
	var kind: String = d.get("kind", "")
	var result = {"text": "", "intent": kind, "cue": kind, "repeated": false, "statement": d.get("statement", ""), "voice": id}
	var chunks: Array = []
	if kind == "argument":
		var history: Dictionary = memory.get("decisions", {})
		var key = JSON.stringify([audience, d.get("key", "")])
		var prior: Dictionary = history.get(key, {})
		var signature = JSON.stringify([d.get("stance", "partial"), d.get("reason", ""), d.get("alternative", ""), d.get("source", ""), d.get("preferred", ""), d.get("special", "")])
		var same_facts = not prior.is_empty() and prior.get("facts", []) == d.get("facts", [])
		var cue = ""
		if not prior.is_empty():
			if prior.get("signature", "") != signature:
				cue = "changed"
			elif same_facts:
				cue = "repeat"
			elif d.get("facts", []).any(func(f): return not f in prior.get("facts", [])):
				cue = "new_evidence"
			else:
				cue = "reframed"
		if cue != "":
			chunks.append(_line(id, cue, d))
		if not str(d.get("special", "")).is_empty():
			chunks.append(d["special"])
		else:
			chunks.append(_line(id, "already" if d.get("already", false) and d.get("stance", "") == "accept" else d.get("stance", "partial"), d))
			if not str(d.get("reason", "")).is_empty():
				chunks.append(_line(id, d["reason"], d))
		if not str(d.get("preferred", "")).is_empty():
			if d.get("reason", "") in ["alternative", "possible_alternative"]:
				chunks.append("Looking at the case as a whole:")
			chunks.append(_line(id, "preferred", d))
		var sequence = int(memory.get("decision_sequence", 0)) + 1
		var entry = d.duplicate(true)
		entry["signature"] = signature
		entry["sequence"] = sequence
		history[key] = entry
		memory["decisions"] = history
		memory["decision_sequence"] = sequence
		result["cue"] = cue if cue != "" else d.get("stance", "partial")
		result["repeated"] = same_facts
	elif kind == "nomination":
		chunks.append(_line(id, "nominate", d))
		if not str(d.get("reason_text", "")).is_empty():
			chunks.append(d["reason_text"])
	result["text"] = " ".join(PackedStringArray(chunks.filter(func(x): return not str(x).is_empty())))
	return result

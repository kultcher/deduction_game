## Presentation only. The caller supplies a resolved decision and approved public reasons.
## No world, role, secret, evidence evaluator, or gameplay RNG belongs here.
extends RefCounted

const LINES = {
	"default": {
		"accept": "That makes sense to me: {claim}.",
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
		"vote_yes": "Yes, to executing {target}.",
		"vote_no": "No, to executing {target}.",
		"self": "I won't vote for my own execution.",
		"trust": "I still trust {target}.",
		"distrust": "I don't trust {target}.",
		"block": "I'd rather keep {block} on the block.",
		"spare": "I'm still persuaded we should spare {target}.",
		"defend": "Your defence gives me pause.",
		"accuse": "Your accusation adds to my doubts about {target}.",
		"backing": "Your vote adds weight to the case for me.",
		"nominator": "I distrust the person bringing this nomination.",
		"enough": "The case is strong enough for my vote.",
		"insufficient": "I don't have enough reason to hang {target}.",
		"accepted_but_no": "I took your case against {target} seriously, but that isn't a promise to hang them.",
	},
	"agnes": {
		"accept": "Yes, I follow you: {claim}.",
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
		"vote_yes": "Yes. I vote to hang {target}.",
		"vote_no": "No. I won't vote to hang {target}.",
		"accepted_but_no": "I heard your case against {target}. I'm still not ready to send them to the gallows.",
	},
	"bart": {
		"accept": "Fair case: {claim}.",
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
		"vote_yes": "Yes. Hang {target}.",
		"vote_no": "No. Not {target}.",
		"accepted_but_no": "Your case against {target} had weight. Doesn't mean I'll hang them.",
	},
	"constance": {
		"accept": "I accept the argument that {claim}.",
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
		"vote_yes": "I vote in favour of executing {target}.",
		"vote_no": "I vote against executing {target}.",
		"accepted_but_no": "I acknowledged your case against {target}; I did not commit to their execution.",
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
			chunks.append(_line(id, d.get("stance", "partial"), d))
			if not str(d.get("reason", "")).is_empty():
				chunks.append(_line(id, d["reason"], d))
		if not str(d.get("preferred", "")).is_empty():
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
	elif kind == "vote":
		chunks.append(_line(id, "vote_yes" if d["yes"] else "vote_no", d))
		# Latest expressed stance, not whichever older acceptance happens to be found first.
		var last = {}
		for entry in memory.get("decisions", {}).values():
			if entry.get("target_id", "") == d.get("target_id", "") and entry.get("accusing", false) and int(entry.get("sequence", 0)) > int(last.get("sequence", -1)):
				last = entry
		if not d["yes"] and last.get("stance", "") == "accept":
			chunks.append(_line(id, "accepted_but_no", d))
		chunks.append(_line(id, d.get("reason", "enough" if d["yes"] else "insufficient"), d))
	result["text"] = " ".join(PackedStringArray(chunks.filter(func(x): return not str(x).is_empty())))
	return result

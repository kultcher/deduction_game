## A bounded dialogue composer. Call only AFTER the simulation chooses what to disclose.
## statement is the already-approved factual sentence, retained verbatim (including lies).
## Two bounded forms can phrase a refusal or reconsideration using authored equivalents;
## their canonical statement is constructed here and never changes the underlying facts.
## Context contains public/expressed delivery cues, never hidden truth or a whole world/NPC.
## memory is owned by one NPC, scoped to the case and listener; no gameplay RNG is used.
extends RefCounted

const Decisions = preload("res://sim/dialogue_decisions.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const INTENTS = ["report", "doubted", "friend", "conceal", "revise"]

static func has_voice(id: String) -> bool:
	return Voices.VOICES.has(id)

static func whereabouts_intent(event_id: String) -> Dictionary:
	return {"kind": "conceal", "form": "whereabouts", "event_id": event_id,
		"statement": "Where I go at night is my own business."}

static func reconsideration_intent(argument: String) -> Dictionary:
	return {"kind": "revise", "form": "reconsideration", "event_id": "reconsider:" + argument, "argument": argument,
		"statement": "I didn't put much stock in %s. After all that's happened since... perhaps I should have." % argument}

static func compose(id: String, intent: Dictionary, context: Dictionary, memory: Dictionary) -> Dictionary:
	if intent.get("kind", "") in ["argument", "nomination"] and context.get("decided", false):
		return decision(id, intent, context.get("audience", "player"), memory)
	var kind: String = intent.get("kind", "")
	var statement: String = intent.get("statement", "")
	var result = {"text": statement, "statement": statement, "voice": id, "intent": kind, "cue": "", "repeated": false}
	if statement.is_empty() or not has_voice(id) or not kind in INTENTS:
		return result
	# These are authorizations from the caller, not deductions made by the renderer.
	if kind == "friend" and (not context.get("close", false) or str(context.get("subject", "")).is_empty()):
		return result
	if kind == "doubted" and not context.get("challenged", false):
		return result
	if kind == "conceal" and not context.get("withholding", false):
		return result
	if kind == "revise" and not context.get("reconsidered", false):
		return result
	var audience: String = context.get("audience", "player")
	var event_id: String = intent.get("event_id", "")
	# Include exact content: a changed account is never described as a repetition.
	var key = JSON.stringify([audience, kind, event_id, statement])
	var seen: Dictionary = memory.get("seen", {})
	var repeated = not event_id.is_empty() and seen.has(key)
	var cue = kind
	# Relationship/reconsideration cues carry meaning; do not replace them with mood.
	if kind == "report":
		if repeated and audience != "town":
			cue = "repeat"
		elif context.get("pressure", 0.0) >= 0.8:
			cue = "pressure"
		elif context.get("trust", 0.5) < 0.3:
			cue = "guarded"
	var counts: Dictionary = memory.get("counts", {})
	var form: String = intent.get("form", "")
	var authored_form = (kind == "conceal" and form == "whereabouts") or (kind == "revise" and form == "reconsideration" and not str(intent.get("argument", "")).is_empty())
	if authored_form:
		cue = form
	# A continuing report belongs to an already-open speaker turn. Suppress fresh
	# introductions, but still track the delivered event and per-audience repetition.
	# Relationship labels are caller-approved, not inferred from the report's text.
	if kind == "report" and context.get("flow_position", "standalone") == "continuation":
		var relation: String = context.get("flow_relation", "continuation")
		var connective = ""
		if relation in ["development", "contrast", "transition", "correction"]:
			var flow_cue = "flow_" + relation
			var options: Array = Voices.VOICES[id].get(flow_cue, [])
			if not options.is_empty():
				var flow_key = audience + ":" + flow_cue
				connective = options[int(counts.get(flow_key, 0)) % options.size()]
				counts[flow_key] = int(counts.get(flow_key, 0)) + 1
		var parts: Array = []
		if connective != "":
			parts.append(connective)
		parts.append(statement)
		if audience != "town" and context.get("request_privacy", false):
			var private_lines: Array = Voices.VOICES[id]["private"]
			parts.append(private_lines[int(counts.get(audience + ":private", 0)) % private_lines.size()])
			counts[audience + ":private"] = int(counts.get(audience + ":private", 0)) + 1
		result["text"] = " ".join(PackedStringArray(parts))
		result["cue"] = "flow_" + relation
		result["repeated"] = repeated
		if not event_id.is_empty():
			seen[key] = true
		memory["seen"] = seen
		memory["counts"] = counts
		return result
	var count_key = audience + ":" + cue
	var choices: Array = Voices.VOICES[id][cue]
	var extra: String = choices[int(counts.get(count_key, 0)) % choices.size()]
	# Single replacement, not general string formatting of player/evidence text.
	extra = extra.replace("{subject}", str(context.get("subject", "")))
	var chunks: Array = [extra, statement]
	if authored_form:
		chunks = [extra.replace("{argument}", str(intent.get("argument", "")))]
	elif kind == "friend":
		chunks = [statement, extra]
	# Confidentiality must be requested explicitly and only in private conversation.
	if kind == "report" and audience != "town" and context.get("request_privacy", false):
		var private_lines: Array = Voices.VOICES[id]["private"]
		chunks.append(private_lines[int(counts.get(count_key, 0)) % private_lines.size()])
	result["text"] = " ".join(PackedStringArray(chunks))
	result["cue"] = cue
	result["repeated"] = repeated
	counts[count_key] = int(counts.get(count_key, 0)) + 1
	if not event_id.is_empty():
		seen[key] = true
	memory["seen"] = seen
	memory["counts"] = counts
	return result

## Compose an uninterrupted NPC turn from already-approved utterances. Nothing here
## chooses disclosures or infers relationships from content. "preceded" means the caller
## has already put spoken material (such as a role claim) in the same speaker turn.
## Each result remains a distinct speech event with its exact statement and event ID.
static func compose_turn(id: String, intents: Array, context: Dictionary, memory: Dictionary, preceded: bool = false) -> Array:
	var results: Array = []
	for i in range(intents.size()):
		var approved: Dictionary = intents[i]
		var cues: Dictionary = context.duplicate()
		cues["flow_position"] = "continuation" if preceded or i > 0 else "opening"
		cues["flow_relation"] = approved.get("relation", "continuation")
		# A request for confidentiality belongs at the end of the turn, not after
		# each individual reading. Standalone compose() retains its existing behavior.
		cues["request_privacy"] = context.get("request_privacy", false) and i == intents.size() - 1
		var delivery: Dictionary = approved.duplicate()
		delivery.erase("relation")
		results.append(compose(id, delivery, cues, memory))
	return results

## The simulation has already approved this descriptor. Never pass private decision logs.
static func decision(id: String, approved: Dictionary, audience: String, memory: Dictionary) -> Dictionary:
	return Decisions.render(id, approved, audience, memory)

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
	# A generic stonewall still acknowledges an earlier refusal; it does not need a voice pack.
	if not has_voice(id) and kind == "conceal" and intent.get("form", "") == "whereabouts" and context.get("withholding", false) and not statement.is_empty():
		var event: String = intent.get("event_id", "")
		if not event.is_empty():
			var refusal_key = JSON.stringify([context.get("audience", "player"), kind, event, statement])
			var refusals: Dictionary = memory.get("seen", {})
			result.repeated = refusals.has(refusal_key)
			if result.repeated:
				result.text = "I told you already: " + statement
				result.cue = "repeat"
			refusals[refusal_key] = true
			memory["seen"] = refusals
		return result
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

## Immediate exchange continuity is deliberately separate from cross-day delivery memory.
## Start a fresh scope when a new talk opens, but keep seen reports/decisions intact.
static func begin_conversation(memory: Dictionary) -> void:
	memory["conversation"] = {"last_action": "", "last_subject": ""}

## Record only the player's expressed action, never hidden reasons, trust, or alignment.
## Called after the NPC has actually spoken a reply to the player.
static func record_exchange(memory: Dictionary, action: String, subject_id: String = "") -> void:
	var current: Dictionary = memory.get("conversation", {})
	if current.is_empty():
		return # A scripted response outside a player conversation has no continuity scope.
	current["last_action"] = action
	current["last_subject"] = subject_id
	memory["conversation"] = current

## Returns a rhetorical relationship, not an assessment of the prior evidence.
static func exchange_cue(memory: Dictionary, action: String, subject_id: String = "") -> String:
	var current: Dictionary = memory.get("conversation", {})
	if current.is_empty():
		return ""
	var last_action: String = current.get("last_action", "")
	var last_subject: String = current.get("last_subject", "")
	if action == "gift" and last_action == "challenge_gift":
		return "gift_after_challenge"
	if action == "opinion" and subject_id != "" and last_subject == subject_id:
		if last_action == "accusation":
			return "opinion_after_accusation"
		if last_action == "opinion":
			return "opinion_again"
	return ""

## When an opinion was already refused, a repeated question should not launch
## the same boilerplate again. This renders the SAME refusal, not a new judgment.
static func repeated_opinion_refusal(id: String, subject_name: String, cue: String, original: String) -> String:
	if cue != "opinion_again" or not has_voice(id):
		return original
	return str(Voices.VOICES[id].get("conversation_opinion_refusal_again", original)).replace("{subject}", subject_name)

## A full alternate first-reveal sentence, selected only when the underlying
## disclosure logic has ALREADY approved the gift being named.
static func gift_reveal(id: String, role_name: String, cue: String) -> String:
	if cue != "gift_after_challenge" or not has_voice(id):
		return ""
	var template: String = Voices.VOICES[id].get("conversation_gift_after_challenge", "")
	return template.replace("{role}", role_name)

## Prefix an approved opinion after a prior spoken exchange about that SAME
## person. Never infer a stance from the prose or the subject's real role.
static func contextualize(id: String, statement: String, cue: String, subject_name: String) -> String:
	if not has_voice(id):
		return statement
	if not cue in ["opinion_after_accusation", "opinion_again"]:
		return statement
	var phrase: String = Voices.VOICES[id].get("conversation_" + cue, "")
	if phrase.is_empty():
		return statement
	return phrase.replace("{subject}", subject_name) + " " + statement

## The simulation has already approved this descriptor. Never pass private decision logs.
static func decision(id: String, approved: Dictionary, audience: String, memory: Dictionary) -> Dictionary:
	return Decisions.render(id, approved, audience, memory)

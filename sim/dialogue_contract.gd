## Presentation boundary shared by reports and resolved decisions. These are public,
## caller-approved fields, never a world/NPC or an invitation to resolve new meaning.
extends RefCounted

const CONTEXT_FIELDS = ["audience", "speech_act", "trust", "pressure", "warm", "close", "subject",
	"challenged", "visual", "withholding", "reconsidered", "decided", "request_privacy",
	"flow_position", "flow_relation", "shared_presence"]
const PAYLOAD_FIELDS = ["kind", "form", "event_id", "statement", "observation", "argument", "when",
	"key", "claim", "stance", "facts", "reason", "alternative", "source", "preferred",
	"target", "target_id", "reason_text", "accusing", "special"]
const RELATIONS = ["independent", "continuation", "development", "contrast", "transition", "correction", "same_scene"]

static func context(supplied: Dictionary) -> Dictionary:
	var public = {}
	for field in CONTEXT_FIELDS:
		if supplied.has(field): public[field] = supplied[field]
	if public.get("speech_act", "") not in ["answer", "volunteer"]: public.erase("speech_act")
	if public.get("flow_relation", "independent") not in RELATIONS: public["flow_relation"] = "independent"
	return public

## Keep payload and delivery distinct on every return path, including generic
## fallback and decisions. Deep copies prevent UI consumers changing source facts.
static func attach(result: Dictionary, approved: Dictionary, delivery: Dictionary) -> Dictionary:
	var canonical = {}
	for field in PAYLOAD_FIELDS:
		if approved.has(field): canonical[field] = approved[field]
	result["canonical"] = canonical.duplicate(true)
	result["audience"] = delivery.get("audience", "player")
	result["speech_act"] = delivery.get("speech_act", "")
	result["relation"] = delivery.get("flow_relation", "independent")
	return result

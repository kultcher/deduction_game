## Test helper: what a spoken line *says*, independent of how a voice renders it.
##
## Voiced lines keep the simulation's unvoiced sentence as `statement` (see
## sim/dialogue.gd and sim/dialogue_contract.gd). Gameplay tests should check that, so
## re-authoring a voice pack or replacing a [PH] placeholder never breaks them. Tests of
## the renderer itself (test_dialogue, the dialogue lab) still check rendered text.
extends RefCounted

static func said(line) -> String:
	if line is Dictionary:
		var s = line.get("statement", "")
		if s is String and not s.is_empty():
			return s
		return str(line.get("text", "")).trim_prefix("[PH] ")
	return str(line).trim_prefix("[PH] ")

## The rendered text without a placeholder marker, for checks that genuinely need it.
static func shown(line) -> String:
	if line is Dictionary:
		return str(line.get("text", "")).trim_prefix("[PH] ")
	return str(line).trim_prefix("[PH] ")

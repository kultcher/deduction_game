## The shape of a finished game's votes, for the belief-model guardrail
## (claude/belief-model-direction-2026-11-10.md, Phase 0): is the town herdable?
## Reads `nomination` and `vote_tally` log entries and `w.executions` only: no RNG, no decisions.
##
## - unanimous: every NPC voter except the nominee voted yes.
## - only_nominator: the only yes vote (NPCs and the player) was the nominator's.
## - evil nominations: by someone evil at case start, counted from `nomination` entries
##   (so a nomination cancelled by clemency, with no vote, still counts). "carried" = put
##   the nominee on the block; "executed" = the nominee hanged on that nomination. Split by the nominee's
##   alignment at case start, so evil herding the town onto a good person shows directly.
extends RefCounted

const KEYS = ["votes", "votes_unanimous", "votes_only_nominator",
	"evil_nominations", "evil_nominations_carried", "evil_nominations_executed",
	"evil_nominations_good_target", "evil_nominations_good_target_carried", "evil_nominations_good_target_executed"]

static func build(w) -> Dictionary:
	var out: Dictionary = {}
	for k in KEYS:
		out[k] = 0
	var evil0: Array = w.initial_evil_ids
	var executed_by: Dictionary = {}   # "day:id" -> nominator
	for ex in w.executions:
		executed_by["%d:%s" % [int(ex.get("day", -1)), str(ex.get("id", ""))]] = str(ex.get("nominator", ""))
	for e in w.dlog.entries:
		if e["type"] == "nomination" and str(e.get("actor", "")) in evil0:
			out["evil_nominations"] += 1
			if not str(e.get("target", "")) in evil0:
				out["evil_nominations_good_target"] += 1
		if e["type"] != "vote_tally":
			continue
		var d: Dictionary = e["data"]
		var nominee: String = str(d.get("nominee", ""))
		var by: String = str(d.get("by", ""))
		var yes: Array = d.get("yes", [])
		var no: Array = d.get("no", []).filter(func(v): return v != nominee)
		var player_yes: bool = bool(d.get("player_yes", false))
		out["votes"] += 1
		if no.is_empty() and not yes.is_empty():
			out["votes_unanimous"] += 1
		var yes_all: Array = yes.duplicate()
		if player_yes:
			yes_all.append("player")
		if yes_all == [by]:
			out["votes_only_nominator"] += 1
		if by in evil0:
			var carried: bool = str(d.get("outcome", "")) == "on_block"
			var executed: bool = executed_by.get("%d:%s" % [int(e.get("day", -1)), nominee], "") == by and carried
			out["evil_nominations_carried"] += 1 if carried else 0
			out["evil_nominations_executed"] += 1 if executed else 0
			if not nominee in evil0:
				out["evil_nominations_good_target_carried"] += 1 if carried else 0
				out["evil_nominations_good_target_executed"] += 1 if executed else 0
	return out

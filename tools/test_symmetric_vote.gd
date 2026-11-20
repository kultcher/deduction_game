## The player's no counts too (Michael, Nov 19): there's no abstaining, so a plain no
##   - pushes every voter toward no, at about two-thirds of the yes push
##     (PLAYER_VOTE_NO_SLOPE x credibility + PLAYER_VOTE_NO_OFFSET);
##   - warms the nominee to the Demonologist (VOTED_NO_ON_ME_RISE), unless the player
##     nominated them;
##   - a dry run (would_vote, a vote outside the meeting's tally) gets no push.
## A yes still pushes toward yes and cools the nominee (VOTED_YES_ON_ME_DROP), and now
## counts as a weak evil claim in each NPC's track record (CRED_WEIGHT_STATEMENT); a no
## records nothing.
extends SceneTree

const Game = preload("res://game/game.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)


func _init() -> void:
	_parts()
	_trust()
	_record()
	print("Symmetric vote: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _last_parts(w, voter) -> Dictionary:
	var evals: Array = w.dlog.trace_events().filter(func(ev): return ev.type == "decision" and ev.data.kind == "vote" and ev.data.stage == "evaluation" and ev.actor == voter.id)
	return evals[-1].data.details.parts if not evals.is_empty() else {}


func _parts() -> void:
	var g = Game.new()
	g.detailed_logging = true
	g.new_case(42, 7)
	var w = g.w
	w.day = 2
	w.begin_meeting()
	var voter = w.living_good()[0]
	var target = w.living_good()[1]
	voter.credibility = 1.0
	voter.suspicion[target.id] = 0.20
	# A real vote with the player's no: the push toward no.
	w.meeting["player_votes_no"] = true
	Mind.vote(w, voter, target.id, w.living_good()[2].id, false, "", 0)
	var no_parts: Dictionary = _last_parts(w, voter)
	var want: float = -(Tuning.Meeting.PLAYER_VOTE_NO_SLOPE * 1.0 + Tuning.Meeting.PLAYER_VOTE_NO_OFFSET)
	_check(is_equal_approx(float(no_parts.get("player_votes_no", 0.0)), want) and not no_parts.has("player_votes_yes"),
		"the player's no pushes toward no (%.2f at credibility 1.0)" % float(no_parts.get("player_votes_no", 0.0)))
	# Two-thirds of the yes, give or take the rounding.
	var yes_push: float = Tuning.Meeting.PLAYER_VOTE_YES_SLOPE + Tuning.Meeting.PLAYER_VOTE_YES_OFFSET
	_check(absf(-want / yes_push - 2.0 / 3.0) < 0.05, "about two-thirds of the yes push at full credibility (%.2f vs %.2f)" % [-want, yes_push])
	# Low credibility: the no backfires, as a low-credibility yes does.
	voter.credibility = 0.1
	Mind.vote(w, voter, target.id, w.living_good()[2].id, false, "", 0)
	_check(float(_last_parts(w, voter).get("player_votes_no", 0.0)) > 0.0, "at low credibility the player's no backfires")
	voter.credibility = 1.0
	# A yes is unchanged and gets no no-push even with the flag set.
	Mind.vote(w, voter, target.id, w.living_good()[2].id, true, "", 0)
	var yes_parts: Dictionary = _last_parts(w, voter)
	_check(yes_parts.has("player_votes_yes") and not yes_parts.has("player_votes_no"), "a yes pushes toward yes only")
	# A dry run, outside the meeting's tally: no push either way.
	w.meeting.erase("player_votes_no")
	Mind.vote(w, voter, target.id, w.living_good()[2].id, false, "", 0)
	var dry: Dictionary = _last_parts(w, voter)
	_check(not dry.has("player_votes_no") and not dry.has("player_votes_yes"), "a vote outside the tally (would_vote) gets no push")


func _trust() -> void:
	for player_yes in [false, true]:
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(692, 10)
		var w = g.w
		w.day = 2
		w.phase = 2
		w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
		var nominee = w.living_good()[0]
		var nominator = w.living_good()[1]
		nominee.trust = 0.5
		w.open_nomination(nominator.id, nominee.id)
		w.vote_pending(player_yes)
		var want: float = 0.5 - Tuning.Trust.VOTED_YES_ON_ME_DROP if player_yes else 0.5 + Tuning.Trust.VOTED_NO_ON_ME_RISE
		_check(is_equal_approx(nominee.trust, want), "the nominee's trust after the player's %s: %.2f" % ["yes" if player_yes else "no", nominee.trust])
		_check(not w.meeting.has("player_votes_no"), "the no-push flag is cleared after the tally (%s)" % ["yes" if player_yes else "no"])
	# The player's own nominee doesn't warm to a no.
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(692, 10)
	var w2 = g2.w
	w2.day = 2
	w2.phase = 2
	w2.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	var own = w2.living_good()[0]
	own.trust = 0.5
	w2.open_nomination("player", own.id)
	var before: float = own.trust
	w2.vote_pending(false)
	_check(is_equal_approx(own.trust, before), "the player's own nominee doesn't warm to the player's no")


func _record() -> void:
	for verb in ["vote yes", "vote no"]:
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(692, 10)
		var w = g.w
		w.day = 2
		w.begin_meeting()
		g.state = "meeting"
		var nominee = w.living_good()[0]
		var nominator = w.living_good()[1]
		for n in w.living():
			n.claim_record.erase(nominee.id)
		w.open_nomination(nominator.id, nominee.id)
		g.state = "nomination"
		g.command(verb)
		var recs: Array = w.living().filter(func(n): return n != nominee).map(func(n): return n.claim_record.get(nominee.id, {}))
		if verb == "vote yes":
			_check(not recs.is_empty() and recs.all(func(r): return str(r.get("type", "")) == "evil" and is_equal_approx(float(r.get("weight", 0.0)), Tuning.Trust.CRED_WEIGHT_STATEMENT)),
				"a yes is on everyone's record as a weak evil claim (%s)" % str(recs[0] if not recs.is_empty() else {}))
		else:
			_check(not w.meeting.get("results", []).is_empty() and recs.all(func(r): return r.is_empty()), "a no records nothing")

## The vote hook for the case slate (Michael, Nov 19: how a case moves votes):
## MindMeeting.would_vote counts how the good townsfolk would vote on a nominee, with the
## player's vote left out, and leaves nothing behind:
##   - no random draw, no log entry (nor trace event or live-feed record), the meeting state as it was;
##   - it agrees with the real vote for each good voter;
##   - raising every good voter's suspicion of the nominee turns them to yes and crosses the
##     threshold; evil voters and the nominee aren't counted.
extends SceneTree

const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Feed = preload("res://sim/decision_feed.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 10)
	var w = g.w
	w.day = 2
	var goods: Array = w.living_good()
	var nominee = goods[0]
	var rng_state = w.rng.state
	var log_size: int = w.dlog.entries.size()
	var meeting_was: Dictionary = w.meeting.duplicate(true)
	var r: Dictionary = MindMeeting.would_vote(w, nominee.id)
	_check(w.rng.state == rng_state, "no random draw")
	_check(w.dlog.entries.size() == log_size, "no log entry")
	_check(w.meeting == meeting_was, "the meeting state as it was")
	var counted: Array = r.yes + r.no
	_check(not (nominee.id in counted) and counted.all(func(id): return not w.by_id[id].is_evil()) and counted.size() == goods.size() - 1,
		"counts every good voter but the nominee, and no evil one (%d)" % counted.size())
	_check(int(r.threshold) == w.vote_threshold() and int(r.voters) == w.voter_count(), "the real meeting's threshold (%d of %d)" % [r.threshold, r.voters])
	# It agrees with the real vote, voter by voter.
	if not w.meeting.has("block"):
		w.meeting["block"] = ""
	var agree := true
	for v in goods:
		if v == nominee:
			continue
		var real: bool = MindMeeting._vote_impl(w, v, nominee.id, "", false, "", 0, 0)
		if real != (v.id in r.yes):
			agree = false
	w.meeting = meeting_was
	_check(agree, "each voter's count matches the real vote")
	# Everyone sure of the nominee: all yes, and it crosses.
	for v in goods:
		if v != nominee:
			v.suspicion[nominee.id] = 1.5
			v.trust_at_reconsider = v.trust
	var sure: Dictionary = MindMeeting.would_vote(w, nominee.id)
	_check(sure.yes.size() >= sure.threshold and sure.crosses, "with every good voter sure of the nominee, it crosses (%d of %d needed)" % [sure.yes.size(), sure.threshold])
	# With detailed logging and a live decision feed on, neither takes the votes (Codex on #347).
	var g2 = Game.new()
	g2.new_case(4242, 10)
	var w2 = g2.w
	w2.day = 2
	w2.dlog.detailed = true
	var feed = Feed.new()
	feed.enabled = true
	w2.attach_decision_feed(feed)
	var trace_n: int = w2.dlog.trace_events().size()
	var feed_n: int = feed.records.size()
	MindMeeting.would_vote(w2, w2.living_good()[0].id)
	_check(w2.dlog.trace_events().size() == trace_n and feed.records.size() == feed_n and w2.dlog.detailed and w2.dlog.live_feed == feed,
		"no detailed trace event or live-feed record, and both are back on after (%d, %d)" % [w2.dlog.trace_events().size() - trace_n, feed.records.size() - feed_n])
	print("Would vote: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

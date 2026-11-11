## Town meeting lifecycle, streamed opening testimony, floor commands,
## nominations, defences, voting, and execution resolution for `Game`.
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Credibility = preload("res://game/credibility.gd")
const Declaration = preload("res://game/demon_declaration.gd")
const CardModel = preload("res://game/card_model.gd")
const Deduction = preload("res://sim/deduction.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const MindSupport = preload("res://sim/mind_support.gd")


static func _start_meeting(g) -> void:
	g.state = "meeting"
	g.town_quiet = false
	g.presented_today = false
	g._hdr("Day %d: the town meeting" % g.w.day)
	g.w.open_meeting()
	for sid in g.w.meeting.get("silenced", []):
		var sn = g.w.by_id[sid]
		g._narr("%s rises to speak, but no sound comes. Their voice has been stolen; they can still vote." % sn.name)
		g._facts([{"kind": "silenced", "subject": [sid], "source": "player", "day": g.w.day, "phase": C.EVENING,
			"text": "Day %d: %s could not speak at the meeting (silenced; can still vote)." % [g.w.day, sn.name]}])
	g._testimony = Mind.testimony_start(g.w)
	g._testimony["spoken"] = 0
	if g.stream_meeting:
		return  # the UI calls testimony_step() until it's done
	while not g._testimony.is_empty():
		_testimony_turn(g)


## The meeting's testimony, streamed: true while the town is still speaking.
static func meeting_streaming(g) -> bool:
	return not g._testimony.is_empty()


## Streamed meeting: the next speaker (or a waiting belief refresh), as rendered text.
## Same order of work as an unstreamed meeting, so the outcome is identical.
static func testimony_step(g) -> String:
	if g._testimony.is_empty():
		return ""
	g.events = []
	g.w.set_log_time()
	g.w.dlog.begin_action("meeting_testimony", {"speaker": g._testimony["i"]})
	_testimony_turn(g)
	return g._finish_command("testimony", "testimony")


static func _testimony_turn(g) -> void:
	var t: Dictionary = Mind.testimony_step(g.w, g._testimony)
	if not t.get("lines", []).is_empty():
		g._testimony["spoken"] += 1
		# Board cards are player knowledge. Give listeners the spoken report before
		# the next speaker reacts; both streamed and immediate meetings use this turn.
		var speaker = g.w.by_id[t.who]
		for fact in t.get("facts", []):
			Social.deliver_public_sighting(g.w, speaker, fact)
		g._lines(t["lines"])
		g._facts(t["facts"])
	if not g._testimony["done"]:
		return
	var spoken: int = g._testimony["spoken"]
	g._testimony = {}
	if spoken == 0:
		g._narr("Nobody has much to say tonight.")
	_meeting_opened(g)


static func _meeting_opened(g) -> void:
	g._narr("")
	g._narr(g.theory_status())
	g._prompt("Before voting, record or update your private demon guess in a profile or with 'guess <name> demon'. A case can end at this meeting; guessing is optional and costs no time.")
	g._prompt("Nominations are open (%d votes needed of %d). 'present <deduction#>' to take the floor (once), 'nominate <name>', or 'wait' to let the town speak." %
		[g.w.vote_threshold(), g.w.voter_count()])
	if Declaration.blocked(g.w) == "":
		var now: String = "The town takes it as %s. " % Declaration.LABEL[g.w.declared_demon_type] if g.w.declared_demon_type != "" else ""
		g._prompt("%s'declare walker' or 'declare hexer' tells the town which kind of Demon it faces (once a day; changing your mind costs credibility)." % now)


static func _meeting_command(g, verb: String, rest: String) -> void:
	match verb:
		"present":
			g._present_deduction(rest)
		"nominate", "nom":
			_player_nomination(g, rest)
		"declare":
			var err: String = Declaration.declare(g, rest)
			if err != "":
				g._err(err)
		"wait":
			if not _next_npc_nomination(g):
				g.town_quiet = true
				g._narr("No one else rises to nominate.")
				var pres = "" if g.presented_today else "'present <deduction#>', "
				if "player" in g.w.meeting["nominators"]:
					g._prompt("%s'done' to close the meeting." % pres)
				else:
					g._prompt("%s'nominate <name>', or 'done' to close the meeting." % pres)
		"done", "pass", "close":
			if not g.town_quiet:
				g._err("Let the town have its say first ('wait').")
				return
			_close_meeting(g)
		_:
			g._err("At the meeting: present <deduction#> (once) | nominate <name> | declare walker|hexer | wait | done")


## The player's nomination (meeting plan M2a). 'nominate <name>' rests on the on-deck case
## (your latest filed case accusing them) when there is one; 'nominate <name> #N' picks
## another case, 'nominate <name> raw' rests on your word alone. The UI offers the same
## choices (and updating the case) before it sends the command.
static func _player_nomination(g, rest: String, progress: Callable = Callable()) -> void:
	var words: PackedStringArray = rest.strip_edges().split(" ", false)
	var choice: String = ""
	if words.size() > 1 and (words[-1].to_lower() == "raw" or words[-1].trim_prefix("#").is_valid_int()):
		choice = words[-1].to_lower()
		words = words.slice(0, words.size() - 1)
	var n = g.find_npc(" ".join(words))
	if n == null:
		g._err("Nominate whom?")
		return
	var why = g.w.can_nominate("player", n.id)
	if why != "":
		g._err(why)
		return
	var card: Dictionary = {}
	if choice == "":
		card = on_deck_case(g, n.id)
	elif choice != "raw":
		var num: int = choice.trim_prefix("#").to_int()
		if num < 1 or num > g.board.size() or g.board[num - 1].get("kind", "") != "deduction" or g.board[num - 1].get("deleted", false):
			g._err("Card #%d isn't one of your filed cases. ('nominate %s', 'nominate %s #<case>' or 'nominate %s raw')" % [num, n.name.to_lower(), n.name.to_lower(), n.name.to_lower()])
			return
		card = g.board[num - 1]
		if not _case_names(card, n.id):
			g._err("Case #%d doesn't name %s as one to suspect." % [num, n.name])
			return
	if not card.is_empty() and not g._presentation_gate(card, g.w.living().filter(func(v): return v != n), [n.id], "deduction", "nomination"):
		return
	g.w.open_nomination("player", n.id)
	Credibility.record_public(g, "evil", n.id, Tuning.Trust.CRED_WEIGHT_FORMAL if not card.is_empty() else Tuning.Trust.CRED_WEIGHT_BARE_NOMINATION)
	g.town_quiet = false
	if card.is_empty():
		g._narr("You stand and nominate %s." % n.name)
		if choice == "" :
			g._ev({"k": "note", "text": "No case of yours names %s yet, so this nomination rests on your word. File a case in the Case Workshop to nominate on its strength." % n.name})
	else:
		g._narr("You stand and nominate %s on the strength of your case (#%d)." % [n.name, card.n])
		var repeat: bool = g.public_presentations.has(int(card.n))
		g.w.meeting["pending"]["case_card"] = int(card.n)
		g.w.meeting["pending"]["case_facts"] = Array(card.get("supports", [])).filter(func(x): return int(x) >= 1 and int(x) <= g.board.size()).map(func(x): return g.board[int(x) - 1])
		g._break_confidences([card.n] + Array(card.get("supports", [])))
		g._secrets_used(card)
		if repeat:
			note_already_public(g, true, false)
		else:
			g.public_presentations[int(card.n)] = true
			for v in g.w.living():
				if v != n:
					if progress.is_valid():
						await progress.call(v.name)
					g._evaluate_deduction(v, card, Tuning.Workshop.VENUE_MULTS.nomination, false, "nomination")
	g.w.dlog.add("player_nomination", "player", n.id, {"case": int(card.get("n", 0)), "raw": card.is_empty()})
	_defend_pending(g)
	_show_nomination(g)


## Does this filed case name `id` as one to suspect (its conclusion accuses them)?
static func _case_names(card: Dictionary, id: String) -> bool:
	var c: Dictionary = card.get("conclusion", {})
	return str(c.get("a", "")) == id and str(c.get("type", "")) in Deduction.ACCUSING


## The case on deck against `id`: the latest live (not deleted, not superseded) filed case
## whose conclusion accuses them. {} when none.
static func on_deck_case(g, id: String) -> Dictionary:
	for i in range(g.board.size() - 1, -1, -1):
		var c: Dictionary = g.board[i]
		if c.get("kind", "") != "deduction" or c.get("deleted", false) or int(c.get("superseded_by", 0)) > 0:
			continue
		if _case_names(c, id):
			return c
	return {}


## Has the town already heard exactly this card or case from you (or, for a plain card,
## at a meeting)? Then citing it again only adds your voice.
static func already_public(g, card: Dictionary) -> bool:
	if card.is_empty():
		return false
	if card.get("kind", "") == "deduction":
		return g.public_presentations.has(int(card.get("n", 0)))
	return g.public_citations.has(int(card.get("n", 0))) or CardModel.disclosure_scope(card) == "public"


## Informational only (never a confirmation): the town already has this.
static func note_already_public(g, is_case: bool, with_voice: bool) -> void:
	var what: String = "case" if is_case else "card"
	var tail: String = ", and your voice still carries weight." if with_voice else "."
	g._ev({"k": "note", "text": "This %s is already public knowledge: citing it again doesn't sway the town further, but it stands on its own merits%s" % [what, tail]})


static func _next_npc_nomination(g) -> bool:
	var nm = Mind.next_nomination(g.w)
	if nm == null:
		return false
	g.w.open_nomination(nm["by"], nm["nominee"], nm["reason"])
	g.w.meeting["pending"]["case_facts"] = nm.get("case_facts", []).duplicate(true)
	g.town_quiet = false
	g._line(nm["speech"])
	for l in nm.get("case_lines", []):
		g._line(l)
	g._facts(nm.get("case_facts", []))
	_defend_pending(g)
	_show_nomination(g)
	return true


## The nominee's defence (meeting-flow step 2), once per nomination.
static func _defend_pending(g) -> void:
	var nm: Dictionary = g.w.meeting["pending"]
	# Step 3 (podium press) opens once the defence is heard; a silenced nominee can't answer.
	nm["press"] = "silenced" if g.w.by_id[nm["nominee"]].silenced else "open"
	if not C.DEFENCE_MOVES:
		g._line(Mind.defence_line(g.w, g.w.by_id[nm["nominee"]]))
		return
	var df = Mind.defend_self(g.w, g.w.by_id[nm["nominee"]], nm["by"], nm.get("case_facts", []))
	for l in df["lines"]:
		g._line(l)
	g._facts(df["facts"])


## Presentation only: describe the existing threshold/high-water rules without changing voting.
static func vote_requirement_text(g) -> String:
	var minimum = g.w.vote_threshold()
	var high: int = g.w.meeting.get("block_count", 0)
	if high < minimum:
		return "%d votes needed to put the nominee on the block." % minimum
	var nominee: String = g.w.meeting.get("pending", {}).get("nominee", "")
	var name: String = g.w.by_id[nominee].name if g.w.by_id.has(nominee) else "the nominee"
	var block: String = g.w.meeting.get("block", "")
	var replacement = " instead of " + g.w.by_id[block].name if g.w.by_id.has(block) else " (the block is empty after a tie)"
	return "%d to put %s on the block%s; %d to tie (no one will be executed)." % [maxi(minimum, high + 1), name, replacement, high]


static func _show_nomination(g) -> void:
	g.state = "nomination"
	g.statement_used = false
	var nm: Dictionary = g.w.meeting["pending"]
	var t = g.w.by_id[nm["nominee"]]
	g._headline("nomination", ("You nominate %s" % t.name) if nm["by"] == "player" else ("%s nominates %s" % [g.w.by_id[nm["by"]].name, t.name]))
	var blk = ""
	if g.w.meeting["block"] != "":
		blk = " %s is on the block with %d votes." % [g.w.by_id[g.w.meeting["block"]].name, g.w.meeting["block_count"]]
	var opts: String = ""
	if nm.get("press", "") == "open":
		opts = "You may press them before the town ('press role', 'press night [N]' or 'press card <#>', once), or 'hear' the town first. "
	else:
		opts = "'hear' the town first, or "
	opts += "'vote yes' / 'vote no' now (the town still speaks before you vote)"
	g._prompt("Vote on %s. %s%s %s." % [t.name, vote_requirement_text(g), blk, opts])


static func _nomination_command(g, verb: String, rest: String, progress: Callable = Callable()) -> void:
	var nm: Dictionary = g.w.meeting["pending"]
	var t = g.w.by_id[nm["nominee"]]
	var r = rest.strip_edges().to_lower()
	match verb:
		"defend", "accuse":
			if g.statement_used:
				g._err("You've already spoken on this nomination.")
				return
			_run_supporters(g)
			var card = {}
			if r != "":
				var num = r.trim_prefix("#").to_int()
				if num < 1 or num > g.board.size():
					g._err("No such card on your board. ('%s' alone, or '%s <card#>')" % [verb, verb])
					return
				card = g.board[num - 1]
			if not card.is_empty() and not g._presentation_gate(card, g.w.living().filter(func(v): return v != t), [t.id], "deduction" if card.kind == "deduction" else verb, "nomination"):
				return
			g.statement_used = true
			if nm.get("press", "") == "open":
				nm["press"] = "closed"  # the statement is Step 5; the press (Step 3) is behind it
			if not card.is_empty():
				var was_public: bool = already_public(g, card)
				if was_public:
					note_already_public(g, card.get("kind", "") == "deduction", true)
				if card.get("kind", "") == "deduction":
					g.public_presentations[int(card.n)] = true
				else:
					g.public_citations[int(card.n)] = true
			var stmt_weight: float = Tuning.Trust.CRED_WEIGHT_FORMAL if not card.is_empty() else Tuning.Trust.CRED_WEIGHT_STATEMENT
			Credibility.record_public(g, "evil" if verb == "accuse" else "good", t.id, stmt_weight)
			nm["statement"] = verb
			if not card.is_empty():
				g._narr("You lay card #%d before the town: %s" % [card["n"], card["text"]])
				g._break_confidences([card["n"]] + Array(card.get("supports", [])))
				if card["kind"] == "deduction":
					g._secrets_used(card)
					for v in g.w.living():
						if v != t:
							if progress.is_valid():
								await progress.call(v.name)
							g._evaluate_deduction(v, card, Tuning.Workshop.VENUE_MULTS.nomination, false, "nomination")
				else:
					Mind.public_case(g.w, t, card, verb)
			if verb == "defend":
				g._narr("You speak in %s's defence." % t.name)
				Mind.set_trust(g.w, t, t.trust + Tuning.Trust.SPEAK_DEFEND_BONUS, "the Demonologist defended me")
				if nm["by"] != "player":
					var nb = g.w.by_id[nm["by"]]
					Mind.set_trust(g.w, nb, nb.trust - Tuning.Trust.SPEAK_AGAINST_NOMINATOR_DROP, "the Demonologist spoke against my nomination")
			else:
				g._narr("You add your voice against %s." % t.name)
				Mind.set_trust(g.w, t, t.trust - Tuning.Trust.SPEAK_AGAINST_NOMINEE_DROP, "the Demonologist spoke against me")
			g.w.dlog.add("player_statement", "player", t.id, {"statement": verb, "card": card.get("n", 0)})
			g._prompt("'vote yes' or 'vote no'%s." % (", or 'clemency'" if g.w.tools["clemency"] > 0 and nm["by"] != "player" else ""))
		"press":
			_press(g, t, r)
		"hear", "listen":
			if nm.get("supporters_done", false):
				g._err("The town has had its say on %s." % t.name)
				return
			_run_supporters(g)
			_player_turn_prompt(g)
		"clemency":
			if g.w.tools["clemency"] <= 0:
				g._err("You have no Clemency left.")
				return
			if nm["by"] == "player":
				g._err("You can't spare someone from your own nomination.")
				return
			_run_supporters(g)
			g.w.clemency()
			g._narr("You raise your hand and invoke Clemency. %s is spared; the nomination is struck." % t.name)
			_after_vote(g)
		"vote", "yes", "no", "y", "n":
			var yes = verb in ["yes", "y"] or (verb == "vote" and r in ["yes", "y", "aye"])
			var no = verb in ["no", "n"] or (verb == "vote" and r in ["no", "n", "nay"])
			if not yes and not no:
				g._err("'vote yes' or 'vote no'.")
				return
			_run_supporters(g)
			g.capture_prediction("before_vote", {"nominee": t.id, "player_yes": yes})
			var res: Dictionary = g.w.vote_pending(yes)
			var yes_names: Array = res["yes"].map(func(i): return g.w.by_id[i].name)
			if res["player_yes"]:
				yes_names.append("you")
			g._narr("Votes to execute %s: %d of %d (%s)." % [t.name, res["count"], g.w.voter_count(),
				", ".join(PackedStringArray(yes_names)) if not yes_names.is_empty() else "nobody"])
			var subj: Array = res["yes"].duplicate()
			subj.append(t.id)
			g._facts([{"kind": "vote", "subject": subj, "source": "player", "day": g.w.day, "phase": C.EVENING,
				"nominee": t.id, "by": res["by"], "yes": res["yes"].duplicate(), "no": res["no"].duplicate(), "player_yes": res["player_yes"],
				"outcome": res["outcome"], "count": res["count"], "threshold": res["threshold"],
				"text": "Day %d vote on %s (nominated by %s): for = %s." % [g.w.day, t.name,
					"you" if res["by"] == "player" else g.w.by_id[res["by"]].name, ", ".join(PackedStringArray(yes_names)) if not yes_names.is_empty() else "nobody"]}])
			match res["outcome"]:
				"on_block":
					g._narr("%s is now on the block." % t.name)
					g._headline("block", "%s is now on the block" % t.name)
				"tie":
					g._narr("That ties the count on the block. Nobody is on the block now.")
				"short_of_block":
					if res["block"] != "":
						g._narr("Not enough to take the block from %s." % g.w.by_id[res["block"]].name)
					else:
						g._narr("Not enough to beat the earlier tie (%d votes)." % res["block_count"])
				_:
					g._narr("The nomination fails.")
			# Step 6: a voter or two who might surprise you say why (meeting plan M2d).
			g._lines(Mind.vote_resistance_lines(g.w, res))
			_after_vote(g)
		_:
			g._err("On this nomination: %sdefend | accuse | %svote yes | vote no" % ["press role | press night [N] | press card <#> | hear | " if nm.get("press", "") == "open" else ("hear | " if not nm.get("supporters_done", false) else ""), "clemency | " if g.w.tools["clemency"] > 0 else ""])


## Step 3, the podium press: one public question to the nominee before the town weighs in.
## 'press role' (or 'press readings' once they've claimed), 'press night [N]', 'press card <#>',
## 'press skip'. Voting or speaking for/against without pressing simply skips it.
static func _press(g, t, r: String) -> void:
	var nm: Dictionary = g.w.meeting["pending"]
	match nm.get("press", ""):
		"silenced":
			g._err("%s can't answer: the Breathstealer has taken their voice." % t.name)
			return
		"open":
			pass
		_:
			g._err("You've already had your chance to press %s on this nomination." % t.name)
			return
	var words: PackedStringArray = r.split(" ", false)
	var mode: String = words[0] if not words.is_empty() else ""
	var arg: String = " ".join(words.slice(1)) if words.size() > 1 else ""
	if mode.begins_with("#") or mode.is_valid_int():
		arg = mode
		mode = "card"
	var opts: Dictionary = MindPodium.options(g.w, t)
	var grounds: bool = not nm.get("case_facts", []).is_empty() or g.w.meeting.get("accusations", []).any(func(a): return a.get("target", "") == t.id)
	var res: Dictionary = {}
	var card: Dictionary = {}
	match mode:
		"skip":
			nm["press"] = "skipped"
			g._narr("You hold your peace.")
			_run_supporters(g)
			_player_turn_prompt(g)
			return
		"role", "gift", "readings":
			if opts.gift == "":
				g._err("%s has already told the town their gift and everything it showed them. Press a night or a card instead." % t.name)
				return
			g._narr("You turn to %s before the town: %s" % [t.name, "what has your gift shown you that we haven't heard?" if opts.gift == "readings" else "what gift do you hold?"])
			res = MindPodium.press_readings(g.w, t) if opts.gift == "readings" else MindPodium.press_role(g.w, t, grounds)
		"night":
			var nd: int = _press_night_default(g, nm)
			if arg != "":
				nd = arg.trim_prefix("n").to_int() if arg.trim_prefix("n").is_valid_int() else -1
			if not (nd in opts.nights):
				g._err("Press them on which night? Nights 0 to %d so far ('press night <N>')." % (g.w.day - 1))
				return
			g._narr("You turn to %s before the town: where were you %s?" % [t.name, C.spoken_when(nd, g.w.day)])
			res = MindPodium.press_night(g.w, t, nd, grounds)
		"card":
			var num: int = arg.trim_prefix("#").to_int()
			if num < 1 or num > g.board.size():
				g._err("Press them with which card? ('press card <#>')")
				return
			card = g.board[num - 1]
			if not MindPodium.card_fits(g.w, t, card):
				g._err("Card #%d isn't about %s, so there's nothing to press them on." % [num, t.name])
				return
			g._narr("You hold up card #%d and turn to %s: %s" % [num, t.name, card.get("text", "")])
			g._break_confidences([num])
			if not already_public(g, card):
				g.public_citations[num] = true
				Mind.public_case(g.w, t, card, "accuse")
			res = MindPodium.press_card(g.w, t, card, true)
		_:
			g._err("Press them on what? 'press role', 'press night [N]', 'press card <#>' or 'press skip'.")
			return
	nm["press"] = "done"
	nm["press_mode"] = res.get("mode", mode)
	g._lines(res.get("lines", []))
	g._facts(res.get("facts", []))
	var cf: Array = nm.get("case_facts", [])
	cf.append_array(res.get("facts", []).map(func(f): return f.duplicate(true)))
	nm["case_facts"] = cf
	g.w.dlog.add("podium_press", "player", t.id, {"mode": nm["press_mode"], "card": int(card.get("n", 0)), "night": int(res.get("night", -1)), "outcome": res.get("outcome", "")},
		"The Demonologist presses %s (%s): %s." % [t.name, nm["press_mode"], res.get("outcome", "")])
	_run_supporters(g)
	_player_turn_prompt(g)


## Step 5, the player's turn: once the town has spoken, a statement (for or against, with a
## card if you like), Clemency, or the vote.
static func _player_turn_prompt(g) -> void:
	var nm: Dictionary = g.w.meeting["pending"]
	var opts: Array = []
	if not g.statement_used:
		opts.append("'accuse' or 'defend' (optionally citing a card; one statement)")
	if g.w.tools["clemency"] > 0 and nm["by"] != "player":
		opts.append("'clemency'")
	opts.append("'vote yes' or 'vote no'")
	g._prompt("Your turn: %s." % ", ".join(PackedStringArray(opts)))


## Step 4, supporters (sim/mind_support.gd): once per nomination, after the press and before
## the player's statement, Clemency or the vote (whichever comes first). The player's word
## comes after the town's (meeting plan M2c/M2d).
static func _run_supporters(g) -> void:
	var nm: Dictionary = g.w.meeting["pending"]
	if nm.get("supporters_done", false):
		return
	nm["supporters_done"] = true
	if nm.get("press", "") == "open":
		nm["press"] = "closed"
	var res: Dictionary = MindSupport.run(g.w, nm["nominee"], nm["by"])
	nm["supporters"] = res.get("speakers", [])
	if res.get("lines", []).is_empty():
		return
	g._lines(res.lines)
	g._facts(res.get("facts", []))


## The night a 'press night' with no number asks about: the latest night the case on the
## floor cites, else last night.
static func _press_night_default(g, nm: Dictionary) -> int:
	var best: int = -1
	for f in nm.get("case_facts", []):
		if f is Dictionary and int(f.get("phase", -1)) == C.NIGHT:
			best = maxi(best, int(f.get("day", -1)))
	return best if best >= 0 and best < g.w.day else g.w.day - 1


static func _after_vote(g) -> void:
	g.state = "meeting"
	var pres = "" if g.presented_today else "'present <deduction#>', "
	g._prompt("%s%s'wait' for the town." % [pres, "" if "player" in g.w.meeting["nominators"] else "'nominate <name>', or "])


static func _last_words(g, n) -> void:
	var response = Mind.last_words(g.w, n)
	g._lines(response.lines)
	g._facts(response.facts)


static func _close_meeting(g) -> void:
	if g.w.meeting.get("closed", false): return
	var frozen = g.capture_prediction("before_execution", {"on_block": g.w.meeting["block"]})
	if g.w.meeting["block"] != "":
		g.w.dlog.add("player_execution_context", "player", g.w.meeting["block"], {"prediction_id": frozen["id"],
			"known_cards": g.board.filter(func(c): return not c.get("deleted", false)).map(func(c): return c["n"])},
			"Evidence and private theory available before execution; no automatic judgement of whether a mistake was reasonable.")
	var ex = g.w.end_meeting(g._last_words)
	if ex != "" and g.w.meeting.has("martyr"):
		var mt = g.w.by_id[g.w.meeting["martyr"]["martyr"]]
		var sv = g.w.by_id[g.w.meeting["martyr"]["saved"]]
		g._narr("The meeting closes. As the noose tightens on %s, %s cries out and falls dead. %s is cut down alive: the Martyr has died in their place." % [sv.name, mt.name, sv.name])
		g._headline("martyr", "%s dies in %s's place" % [mt.name, sv.name])
		g._facts([{"kind": "martyr", "subject": [mt.id, sv.id], "martyr": mt.id, "saved": sv.id, "source": "player", "day": g.w.day, "phase": C.EVENING,
			"text": "Day %d: %s died in %s's place at the gallows. Both are proven good." % [g.w.day, mt.name, sv.name]}])
	elif ex != "":
		var n = g.w.by_id[ex]
		g._narr("The meeting closes. %s is hanged at dusk." % n.name)
		g._headline("execution", "%s is hanged at dusk" % n.name)
		# How many were alive at the hanging: with five or more, a Scion could have taken over.
		g._facts([{"kind": "execution", "subject": [ex], "source": "player", "day": g.w.day, "phase": C.EVENING, "alive_before": g.w.living().size() + 1,
			"text": "%s was executed on day %d." % [n.name, g.w.day]}])
		if g.w.meeting.get("curse", false):
			g._narr("As %s swings, a cold wind moans through Hollowmere. A curse has taken one of those who voted to hang them: someone among you has turned." % n.name)
			g._headline("curse", "A Revenant's curse takes hold", "One of the voters has turned.")
			g._facts([{"kind": "curse", "subject": [ex], "source": "player", "day": g.w.day, "phase": C.EVENING,
				"text": "Day %d: as %s was hanged, a Revenant's curse turned one of those who voted for it. Find its totem to break the curse." % [g.w.day, n.name]}])
	else:
		g._narr("The meeting closes with nobody on the block. Nobody is executed.")
	if g.w.game_over:
		return
	for m in g.w.living():
		if g.w.decision_roll(m, "post_meeting_trait", 0.35 * (1.0 - m.traits["composure"]), {"composure": m.traits["composure"]}):
			var t = Mind.reveal_trait(g.w, m)
			if t != "":
				g._narr(t)
	g.state = "night"
	g._hdr("Night %d" % g.w.day)
	g._narr(g._night_homes())
	if g.w.day == 1: g._narr(C.DEMON_NIGHT_RULE)
	var opts = "'vigil <block>' (watch for activity arriving on a block)"
	if g.w.tools["ward"] > 0:
		opts = "'ward <name>' (shield them from the demon, once per case), " + opts
	g._prompt("Choose your night work: %s, or 'sleep'." % opts)

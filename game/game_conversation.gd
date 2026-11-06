## NPC approaches, 1-on-1 conversations, requests/apologies/promises, and
## spoken haunt/trait/relationship discovery for `Game`.
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const RecentSightings = preload("res://game/recent_sightings.gd")


static func _maybe_approach(g) -> void:
	g.approached_id = ""
	g.approached_loc = ""
	if _maybe_divulge(g):
		return
	var c = Social.approach_candidate(g.w)
	if c == null:
		return
	var n = c["npc"]
	if c["agenda"] == "protect" and _promised_to(g, n):
		return
	g.approach = c
	g.approached_id = n.id
	g.approached_loc = n.loc
	g.state = "approach"
	g.w.dlog.add("approach", n.id, "player", {"agenda": c["agenda"]})
	g._narr("%s the %s approaches you at %s." % [n.name, n.occupation, g.w.loc_name(n.loc)])
	g._line(Mind.say_voiced(n, "approach_word", "Demonologist, a word?"))
	g._line(Social.approach_teaser(g.w, n, c["agenda"]))
	if c["agenda"] == "protect":
		n.request_day = g.w.day
		g._prompt("'yes' (promise it; free) or 'no'.")
	else:
		g._prompt("'accept' (talk now; it uses this phase's action) or 'decline'.")


## Have you already promised them your ward or a vigil tonight?
static func _promised_to(g, n) -> bool:
	return g.offer.get("ward", "") == n.id or g.offer.get("vigil", {}).has(n.id)


## Someone you kept your word to finds you, as they said they would: they tell you their gift
## (and readings, if they'd usually share them) for free. Talking on is optional.
static func _maybe_divulge(g) -> bool:
	for id in g.divulge_due.duplicate():
		var n = g.w.by_id[id]
		if not n.alive:
			g.divulge_due.erase(id)
			n.protect_lock = false
			continue
		if not n.available() or n.silenced:
			continue
		g.divulge_due.erase(id)
		n.protect_lock = false
		g.approach = {"npc": n, "agenda": "divulge"}
		g.approached_id = n.id
		g.approached_loc = n.loc
		g.state = "approach"
		g.w.dlog.add("approach", n.id, "player", {"agenda": "divulge"})
		g._narr("%s the %s finds you at %s, as they promised." % [n.name, n.occupation, g.w.loc_name(n.loc)])
		g._line(Mind.say_voiced(n, "protect_kept_word", "You kept your word. Now I'll keep mine."))
		n.pressed_today = 0  # They initiated this free disclosure, not another interrogation.
		var r: Dictionary = Mind.keep_request(g.w, n, 4 if n.trust >= 0.6 else 3)
		g._lines(r["lines"])
		g._facts(r["facts"])
		g._prompt("(That cost you nothing.) 'accept' to keep talking (uses this phase's action) or 'decline'.")
		return true
	return false


static func _approach_command(g, verb: String, rest: String) -> void:
	var n = g.approach["npc"]
	if g.approach["agenda"] == "protect":
		_protect_approach_answer(g, n, verb, rest)
		return
	match verb:
		"accept", "yes", "y", "talk":
			n.pressed_today = 0  # A new conversation they chose to initiate.
			g.state = "talk"
			g.moved = true
			g.free_move_used = true
			g.loc = n.loc
			g.w.player_loc = g.loc
			g.talk_with = n
			Mind.Dialogue.begin_conversation(n.dialogue_memory)
			g.questions_left = 3
			g.talk_approached = true
			g.free_repeats = 0
			g.w.dlog.add("player_talk", "player", n.id, {"trust": snappedf(n.trust, 0.01), "approach": g.approach["agenda"]})
			g._narr("You step aside with %s at %s." % [n.name, g.w.loc_name(g.loc)])
			# Identical arrival, visible people and observations to an ordinary visit.
			g._observe()
			if g.approach["agenda"] != "divulge":  # they've already told you
				var r: Dictionary = Social.approach_open(g.w, n, g.approach["agenda"])
				g._lines(r["lines"])
				g._facts(r["facts"])
			else:
				g._line(Mind.greeting_line(g.w, n, greeting_context(g, n), false))
			g._prompt(_talk_options(g, n))
		"decline", "no", "n":
			g.state = "day"
			g.w.dlog.add("approach_declined", "player", n.id)
			g._narr("You excuse yourself. %s shrugs and goes about their day." % n.name)
			g._prompt("Where will you spend the %s? ('go <place | block | person>')" % g.w.phase_name().to_lower())
		_:
			# Any other action means declining; carry on with it.
			g.state = "day"
			g.w.dlog.add("approach_declined", "player", n.id, {"implicit": true})
			g._narr("You wave %s off for now." % n.name)
			g._day_command(verb, rest)


## "Watch over me tonight, and I'll tell you": free to answer, nothing else follows.
static func _protect_approach_answer(g, n, verb: String, rest: String) -> void:
	match verb:
		"yes", "y", "accept", "promise", "agree":
			n.pressed_today = 0  # Includes protection requests and their free disclosure.
			g.state = "day"
			_grant_protection(g, n, g.approach["what"] if g.approach.has("what") else Mind.protection_kind(g.w, n))
			g._prompt("Where will you spend the %s? ('go <place | block | person>')" % g.w.phase_name().to_lower())
		"no", "n", "decline", "refuse":
			g.state = "day"
			g.w.dlog.add("protection_declined", "player", n.id)
			g._line(Mind.say_voiced(n, "request_declined", "I see. I'll manage."))
			g._prompt("Where will you spend the %s? ('go <place | block | person>')" % g.w.phase_name().to_lower())
		_:
			g.state = "day"
			g.w.dlog.add("protection_declined", "player", n.id, {"implicit": true})
			g._narr("You leave %s's request unanswered." % n.name)
			g._day_command(verb, rest)


## Yes to a request for protection: the usual promise, then either they tell you now (a
## trust x Composure roll) or once you've kept your word.
static func _grant_protection(g, n, what: String) -> void:
	if what == "ward" and (g.w.tools["ward"] <= 0 or g.offer.has("ward")):
		what = "vigil" if Mind.protection_kind(g.w, n) == "vigil" else ""
	if what == "":
		g._narr("You've nothing left to promise %s tonight." % n.name)
		return
	if not _promised_to(g, n):
		_offer_command(g, n, what, true)
	var p: float = clampf(n.trust * n.traits.get("composure", 0.5) * Tuning.Dialogue.PROTECTION_DISCLOSE_MULT, Tuning.Dialogue.PROTECTION_DISCLOSE_MIN, Tuning.Dialogue.PROTECTION_DISCLOSE_MAX)
	var now: bool = g.w.decision_roll(n, "protection_disclosure", p, {"trust": n.trust, "composure": n.traits.get("composure", 0.5)})
	g.w.dlog.decision(n.id, "protection_disclosure", "outcome", now, {"trust": n.trust,
		"composure": n.traits.get("composure", 0.5), "p": snappedf(p, 0.01)})
	if now:
		g._line(Mind.say_voiced(n, "protect_trust_now", "Then I'll trust you now."))
		var r: Dictionary = Mind.keep_request(g.w, n, 3)
		g._lines(r["lines"])
		g._facts(r["facts"])
	else:
		g.protect_pending[n.id] = true
		n.protect_lock = true
		g._line(Mind.say_voiced(n, "protect_wait_tomorrow", "Keep your word tonight, and I'll find you tomorrow and tell you everything."))


static func _phase_header(g) -> void:
	g._hdr("Day %d, %s" % [g.w.day, g.w.phase_name()])
	g._screen(g._map())
	g._card_workers()
	g._card_conversations()
	g._prompt("Where will you spend the %s? ('go <place | block | person>')" % g.w.phase_name().to_lower())


## Store only the last *spoken* exchange in this talk, separate from the
## case-long report/decision history. A new talk clears the immediate context.
## Do not inspect argument reasoning, evidence truth, role assignments or secrets.
static func _remember_dialogue_exchange(g, n, verb: String, rest: String, response: Dictionary) -> void:
	var spoken: bool = response.get("lines", []).any(func(line): return line is Dictionary and line.get("speaker", "") == n.id)
	if not spoken:
		return
	var action = "other"
	var subject = ""
	var parts: PackedStringArray = rest.split(" ", false)
	if verb in ["ask", "a"] and not parts.is_empty():
		var topic: String = parts[0].to_lower()
		if topic in ["gift", "role", "info", "learned"]:
			action = "gift"
			subject = n.id
		elif topic in ["about", "opinion"] and parts.size() > 1:
			var person = g.find_npc(" ".join(parts.slice(1)), true)
			if person != null:
				action = "opinion"
				subject = person.id
	elif verb in ["press", "confront"]:
		var desc: Dictionary = response.get("dialogue_exchange", {})
		action = desc.get("action", "challenge")
		subject = desc.get("subject", n.id)
	elif verb in ["tell", "accuse"] and not parts.is_empty() and not parts[0].contains(","):
		var person = g.find_npc(parts[0])
		if person != null:
			action = "accusation"
			subject = person.id
	Mind.Dialogue.record_exchange(n.dialogue_memory, action, subject)


## Public/conversation context keys for one-shot VN greetings (never inspects hidden alignment/roles).
static func greeting_context(g, n) -> Dictionary:
	var ctx: Dictionary = {}
	for c_num in g.sigil_heard:
		var heard_list: Array = g.sigil_heard[c_num]
		if n.id in heard_list:
			var rec: Dictionary = g.receipt_by_number(int(c_num))
			if str(rec.get("target", "")) == n.id:
				ctx["protection_key"] = "protect:sigil:%d" % int(c_num)
	if not ctx.has("protection_key") and n.fear_eased:
		ctx["protection_key"] = "protect:promise:%s" % n.id
	if not ctx.has("protection_key"):
		for eid in n.ledger:
			var meta: Dictionary = n.ledger[eid].get("meta", {})
			if meta.get("save_claim", false) and str(meta.get("save_target", "")) == n.id:
				ctx["protection_key"] = "protect:save:%s" % str(eid)
				break
	var open_gr: Array = Mind.open_grievances(n)
	for gr in open_gr:
		if int(gr.get("day", -99)) >= g.w.day - 1:
			ctx["friction_key"] = "friction:grievance:%s:%d" % [str(gr.get("key", "")), int(gr.get("day", 0))]
	var my_claim: Dictionary = n.claim_record.get(n.id, {})
	if not ctx.has("friction_key") and str(my_claim.get("type", "")) == "evil" and int(my_claim.get("day", -99)) >= g.w.day - 1:
		ctx["friction_key"] = "friction:accuse:%d" % int(my_claim.get("day", 0))
	return ctx


static func _talk_options(g, n) -> String:
	var why = " | ask why" if Mind.has_live_hint(g.w, n) else ""
	return "(3 questions: ask gift | ask night | ask seen <today|yesterday [phase]> | ask are <gift> | ask about <name or gift>%s | present <card#> [for|against <name>] | offer ward|vigil (free) | bye)" % why


## A repeated refusal only saves a player question slot. Keep the original NPC
## fatigue, trust, role-guess counters and disclosure/request RNG exactly intact.
static func _repeat_refusal(n, response: Dictionary) -> void:
	if response.has("request") or not response.has("refusal_ask") or int(response.get("refusal_line", -1)) < 0:
		return
	var conversation: Dictionary = n.dialogue_memory.get("conversation", {})
	if conversation.is_empty(): return
	var previous: Dictionary = conversation.get("refusals", {})
	var key: String = response.refusal_ask
	var signature = JSON.stringify(response.get("facts", []))
	var old: Dictionary = previous.get(key, {})
	var count: int = int(old.get("count", 0)) + 1 if old.get("signature", "") == signature else 0
	previous[key] = {"signature": signature, "count": count}
	conversation["refusals"] = previous
	if count == 0: return
	response["repeated"] = true
	var line: Dictionary = response.lines[response.refusal_line]
	if key.begins_with("are:"):
		# Retain both existing patience warnings verbatim, but vary the response.
		var base_stmt: String = str(line.get("statement", line.text))
		var rep_fb: String = "My answer hasn't changed." if count % 2 == 1 else "I've already given you my answer."
		var rep_key: String = "repeat_guess_1" if count % 2 == 1 else "repeat_guess_2"
		var rep_voiced: String = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, rep_key, rep_fb), n.dialogue_memory)
		line.text += " " + rep_voiced
		line["statement"] = base_stmt + " " + rep_fb
	else:
		var refused: Array = response.facts.filter(func(f): return f.get("kind", "") == "refusal")
		var fact: Dictionary = refused[0] if not refused.is_empty() else {}
		var rep_key: String = ""
		var rep_fb: String = ""
		if fact.get("withheld", false):
			rep_key = "repeat_withheld_1" if count % 2 == 1 else "repeat_withheld_2"
			rep_fb = "Those readings are still staying with me." if count % 2 == 1 else "I've not agreed to share any more readings."
		elif fact.get("fear", false):
			rep_key = "repeat_fear_1" if count % 2 == 1 else "repeat_fear_2"
			rep_fb = "Naming my gift now puts a target on my back before it can help. Not yet." if count % 2 == 1 else "Naming my gift still feels too dangerous. Not yet."
		else:
			rep_key = "repeat_gift_1" if count % 2 == 1 else "repeat_gift_2"
			rep_fb = "You've had my answer about my gift. I won't tell you more." if count % 2 == 1 else "I'm still keeping my gift to myself."
		line.text = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, rep_key, rep_fb), n.dialogue_memory)
		line["statement"] = rep_fb


static func _talk_command(g, verb: String, rest: String) -> void:
	var n = g.talk_with
	var r = {}
	if not g.pending_request.is_empty():
		if _answer_request(g, n, verb, rest):
			return
	if verb in ["apologise", "apologize", "sorry"]:
		var gi: int = rest.strip_edges().to_int() - 1 if rest.strip_edges().is_valid_int() else 0
		r = Mind.apologise(g.w, n, gi)
		if r.has("error"):
			g._err("Apologise for what? %s" % _grievance_menu(n))
			return
		verb = "apologise"
	if verb in ["present", "show", "case"]:
		var context_card = g._ward_context_card(rest)
		if not context_card.is_empty():
			r = g._show_ward_context(context_card, [n])
			verb = "ward_context"
	if n.silenced and verb in ["ask", "a", "tell", "t", "present", "accuse", "show", "press"]:
		g.w.observe_decision(n, "conversation", false, {"gate": "silenced; cannot answer; no roll"})
		g._narr("%s opens their mouth, but no sound comes. They can't speak (until tomorrow evening)." % n.name)
		return
	match verb:
		"ward_context":
			pass
		"ask", "a":
			var p = rest.split(" ", false)
			var topic = p[0].to_lower() if p.size() > 0 else ""
			match topic:
				"gift", "role", "info", "learned":
					r = Mind.answer_gift(g.w, n)
					preload("res://sim/muddler.gd").apply_private_disclaimers(g, n, topic, r)
					r["refusal_ask"] = "gift"
				"night", "lastnight":
					r = Mind.answer_night(g.w, n)
					preload("res://sim/muddler.gd").apply_private_disclaimers(g, n, topic, r)
				"today", "seen", "yesterday", "morning", "afternoon", "evening":
					# ask today | ask seen <morning|afternoon|evening> | ask seen yesterday [<phase>]
					var words: Array = Array(p.slice(1)) if topic == "seen" else Array(p)
					words = words.map(func(x): return x.to_lower())
					var frame: String = " ".join(PackedStringArray(words))
					if frame == "today" or frame == "":
						frame = ""
					var ok_frames = ["", "morning", "afternoon", "evening", "yesterday", "yesterday morning", "yesterday afternoon", "yesterday evening"]
					if frame == "last night" or frame == "night":
						r = Mind.answer_night(g.w, n)
					elif not (frame in ok_frames):
						g._err("Ask about when? ('ask seen today | morning | afternoon | evening | yesterday [morning|afternoon|evening]', or 'ask night')")
						return
					elif frame.begins_with("yesterday") and g.w.day <= 1:
						g._err("You only arrived this morning; ask about today or last night.")
						return
					elif frame in ["morning", "afternoon", "evening"] and ["morning", "afternoon", "evening"].find(frame) > g.w.phase:
						g._err("It isn't the %s yet." % frame)
						return
					else:
						r = Mind.answer_today(g.w, n, frame, g.loc, g.seen_pairs())
				"why", "reason", "hint":
					# Only a live hint is worth a question. Otherwise say so, for free.
					if not Mind.has_live_hint(g.w, n):
						var dead: Array = n.hints.keys().filter(func(k): return g.w.by_id.has(k) and not g.w.by_id[k].alive)
						if not dead.is_empty():
							var gone = g.w.by_id[dead[0]]
							var lead: Dictionary = Mind.say_voiced(n, "hint_why_moot", "It was about %s, and that hardly matters now." % gone.name, {"target": gone.name})
							g._narr("%s: \"%s\"  (no question used)" % [n.name, lead["text"]])
						else:
							g._narr("%s hasn't hinted at a reason you could ask about. (No question used.)" % n.name)
						return
					r = Mind.answer_hint(g.w, n)
				"about", "opinion":
					var target = " ".join(p.slice(1))
					var role = g.find_role(target)
					var t = null if role != "" else g.find_npc(target, true)
					if role != "":
						r = Social.answer_about_role(g.w, n, role)
					elif t == null:
						g._err("Ask about whom (a person or a gift)?")
						return
					elif t == n:
						g._narr("%s gives you a flat look." % n.name)
						return
					else:
						r = Mind.answer_opinion(g.w, n, t)
						_maybe_tell_haunts(g, n, t, r)
						_maybe_tell_trait(g, n, t, r)
						_maybe_tell_relationships(g, n, t, r)
						RecentSightings.append_to(g.w, n, t, r, g.board)
				"check", "look", "guard", "watch", "register":
					r = _gift_request(g, n, topic, " ".join(p.slice(1)))
					if r.is_empty():
						return
				"are", "if", "is":
					# "ask are you the seer" / "ask if seer": a guess at their own gift.
					var words: Array = Array(p.slice(1)).filter(func(x): return not (x.to_lower() in ["you", "the", "a", "an", "they", "are"]))
					var grole = g.find_role(" ".join(PackedStringArray(words)))
					if grole == "":
						g._err("Ask if they are which gift? ('ask are seer')")
						return
					var already_told = (n.max_tier >= 3 or n.claim_public) and n.claimed_role == grole
					r = Social.answer_is_role(g.w, n, grole)
					r["refusal_ask"] = "gift" if already_told else "are:" + grole
				_:
					g._err("Ask: gift | night | today | are <gift> | about <name or gift>")
					return
		"present", "show", "case":
			var pr = g._route_present(n, rest)
			if pr.has("error"):
				g._err(pr["error"])
				return
			if pr.has("flat"):
				g._narr(pr["flat"])
				return
			g._narr("(%s)" % pr["note"])
			_talk_command(g, pr["verb"], pr["rest"])
			return
		"convince", "argue":
			var num0 = rest.strip_edges().trim_prefix("#").to_int()
			if num0 < 1 or num0 > g.board.size() or g.board[num0 - 1]["kind"] != "deduction" or g.board[num0 - 1].get("deleted", false):
				g._err("Convince them of which deduction? ('convince <card#>'; to cite a plain card use 'tell <suspect> <card#>')")
				return
			if not g._presentation_gate(g.board[num0 - 1], [n], [], "deduction", "private"):
				return
			g._secrets_used(g.board[num0 - 1])
			g._conflict_pressure(g.board[num0 - 1], 0.1, n)
			r = g._evaluate_deduction(n, g.board[num0 - 1], 1.0)
			r["facts"] = []
			if not r.get("repeated", false) or g.free_repeats >= 1:
				Mind.on_question(g.w, n)
		"trace_ask":
			var numt = rest.strip_edges().trim_prefix("#").to_int()
			if numt < 1 or numt > g.board.size() or g.board[numt - 1].get("deleted", false) or g.board[numt - 1].get("kind", "") != "trace":
				g._err("Show which trace card?")
				return
			r = Mind.react_to_trace(g.w, n, g.board[numt - 1], g.known_haunts)
		"press", "confront":
			var num1 = rest.strip_edges().trim_prefix("#").to_int()
			if num1 < 1 or num1 > g.board.size() or g.board[num1 - 1].get("deleted", false):
				g._err("Press them with which card? ('press <card#>': a card or deduction about them)")
				return
			if g.board[num1 - 1].get("tavern_gossip", false) or not g.board[num1 - 1].get("pressable", true):
				g._err("Card #%d is only an unattributed tavern rumour; you can't press %s with it without a named source." % [num1, n.name])
				return
			var pc: Dictionary = g.board[num1 - 1].duplicate()
			if pc["kind"] == "deduction":
				pc["support_cards"] = g.all_receipts().filter(func(x): return x["n"] in pc["supports"])
				g._secrets_used(pc)
			r = Mind.press(g.w, n, pc, g.known_haunts)
		"defend", "vouch":
			var pd = rest.split(" ", false)
			var numd = pd[pd.size() - 1].trim_prefix("#").to_int() if pd.size() >= 2 else 0
			var sds: Array = []
			if pd.size() >= 2:
				for nm in pd[0].split(","):
					var x = g.find_npc(nm)
					if x != null:
						sds.append(x)
			if sds.is_empty() or numd < 1 or numd > g.board.size() or g.board[numd - 1].get("deleted", false):
				g._err("Usage: present <card#> for <name>")
				return
			if not g._presentation_gate(g.board[numd - 1], [n], sds.map(func(p): return p.id), "defend", "private"):
				return
			r = Mind.hear_defence(g.w, n, sds, g.board[numd - 1])
		"tell", "accuse":
			var p = rest.split(" ", false)
			if p.size() < 2:
				g._err("Usage: tell <suspect> <card#>  (see 'board')")
				return
			if "," in p[0]:
				var grp: Array = []
				for nm in p[0].split(","):
					var x = g.find_npc(nm)
					if x != null and x != n:
						grp.append(x)
				var numg = p[p.size() - 1].trim_prefix("#").to_int()
				if grp.is_empty() or numg < 1 or numg > g.board.size():
					g._err("Usage: present <card#>")
					return
				if not g._presentation_gate(g.board[numg - 1], [n], grp.map(func(p): return p.id), "accuse", "private"):
					return
				r = Mind.hear_group_case(g.w, n, grp, g.board[numg - 1])
			else:
				var s = g.find_npc(p[0])
				var num = p[p.size() - 1].trim_prefix("#").to_int()
				if s == null:
					g._err("Who is suspicious?")
					return
				if s == n:
					g._err("To confront %s with a card about them, use 'press <card#>'." % n.name)
					return
				if num < 1 or num > g.board.size():
					g._err("No such card on your board.")
					return
				if not g._presentation_gate(g.board[num - 1], [n], [s.id], "accuse", "private"):
					return
				r = Mind.hear_accusation(g.w, n, s, g.board[num - 1])
		"offer", "promise":
			_offer_command(g, n, rest.strip_edges().to_lower())
			return
		"apologise":
			pass  # answered above
		"bye", "leave", "done":
			if g.questions_left == 3 and g.free_repeats == 0 and not g.talk_approached and not g.talk_offered:
				# Nothing asked yet: you think better of it, and the phase isn't spent.
				g._narr("You think better of it and leave %s be. (No time spent.)" % n.name)
				g.w.dlog.add("player_talk_cancel", "player", n.id, {})
				g.talk_with = null
				g.state = "day"
				g._prompt("You're still at %s this %s." % [g.w.loc_name(g.loc), g.w.phase_name().to_lower()])
				return
			g._narr("You leave %s to their business." % n.name)
			_close_conversation(g)
			return
		_:
			g._err("In conversation: ask gift | ask night | ask today | ask seen <morning|afternoon|evening|yesterday [phase]> | ask are <gift> | ask about <name or gift> | present <card#> [for|against <name>] | bye")
			return
	# Something they've already heard from you: they say so, and it costs no question.
	_repeat_refusal(n, r)
	var repeat: bool = r.get("repeated", false)
	if repeat and g.free_repeats >= 1:
		repeat = false  # once is a slip; after that it's wasting their time
	if repeat:
		g.free_repeats += 1
	else:
		g.questions_left -= 1
	g._lines(r["lines"])
	g._facts(r["facts"])
	_record_trace_profile_haunts(g, n, r)
	for note in r.get("narration", []):
		g._narr(note)
	_remember_dialogue_exchange(g, n, verb, rest, r)
	if r.has("request") and not (r["request"]["kind"] == "protect" and _promised_to(g, n)):
		g.pending_request = r["request"]
		g.w.dlog.add("npc_request", n.id, "player", {"kind": g.pending_request["kind"]})
		var what: String = "keep it quiet" if g.pending_request["kind"] == "confidence" else ("ward their door" if g.pending_request["what"] == "ward" else "keep a vigil on %s" % C.block_name(n.home_block))
		g._prompt("(They ask you to %s. 'yes' or 'no': answering is free.)" % what)
		if g.questions_left <= 0:
			return  # the answer closes the conversation
	if repeat:
		g._prompt("(No question used. %d question%s left)" % [g.questions_left, "" if g.questions_left == 1 else "s"])
		return
	if g.questions_left <= 0:
		g._narr("%s has other things to do." % n.name)
		_close_conversation(g)
	else:
		g._prompt("(%d question%s left)" % [g.questions_left, "" if g.questions_left == 1 else "s"])


## Yes or no to what they just asked of you (free). Any other command is a no, and goes ahead.
## Returns true when the command was the answer.
static func _record_trace_profile_haunts(g, speaker, r: Dictionary) -> void:
	for ph in r.get("profile_haunts", []):
		var pid: String = ph.get("subject", "")
		var loc_id: String = ph.get("loc", "")
		if pid == "" or loc_id == "" or not g.w.by_id.has(pid):
			continue
		if not (loc_id in g.known_haunts.get(pid, [])):
			g.known_haunts[pid] = g.known_haunts.get(pid, []) + [loc_id]
		g.add_profile_receipt({"kind": "haunt", "subject": [pid], "source": speaker.id, "loc": loc_id, "locs": [loc_id],
			"block": g.w.loc_block(loc_id), "day": g.w.day, "phase": g._phase_now(), "class": "circumstantial",
			"text": "%s says %s often goes to %s when not working." % [speaker.name, g.w.by_id[pid].name, g.w.loc_name(loc_id)]})


static func _answer_request(g, n, verb: String, rest: String) -> bool:
	var rq: Dictionary = g.pending_request
	g.pending_request = {}
	if g.questions_left <= 0:
		# That was their last question: answer, then the conversation ends.
		_answer_request_now(g, n, rq, verb, rest)
		if g.talk_with != null:
			g._narr("%s has other things to do." % n.name)
			_close_conversation(g)
		return true
	return _answer_request_now(g, n, rq, verb, rest)


static func _answer_request_now(g, n, rq: Dictionary, verb: String, rest: String) -> bool:
	var yes: bool = verb in ["yes", "y", "agree", "accept"] or (verb == "promise" and rest.strip_edges() == "")
	var no: bool = verb in ["no", "n", "refuse", "decline"]
	g.w.dlog.add("npc_request_answer", "player", n.id, {"kind": rq["kind"], "yes": yes, "implicit": not (yes or no)})
	if not yes:
		var d: Dictionary = rq.get("decline", {"lines": [], "facts": []})
		g._lines(d["lines"])
		g._facts(d["facts"])
		if no:
			g._prompt("(No question used. %d question%s left)" % [g.questions_left, "" if g.questions_left == 1 else "s"])
		return no
	match rq["kind"]:
		"confidence":
			g._narr("You promise to keep it between you for now.")
			var r: Dictionary = Mind.keep_request(g.w, n, rq["tier"])
			for f in r["facts"]:
				if not f.get("silent", false) and not n.claim_public:
					f["confidential"] = n.id
			g._lines(r["lines"])
			g._facts(r["facts"])
		"protect":
			_grant_protection(g, n, rq["what"])
			return true  # _offer_command already showed the question count
	g._prompt("(No question used. %d question%s left)" % [g.questions_left, "" if g.questions_left == 1 else "s"])
	return true


## "ask check <name>[, <name>]" (a Seer), "ask guard <name>" (a Warden), "ask watch <block>"
## (a Night Watch): ask someone who told you their gift to use it that way tonight.
## {} after an error.
static func _gift_request(g, n, topic: String, target: String) -> Dictionary:
	var role: String = {"check": "seer", "look": "seer", "guard": "warden", "watch": "nightwatch", "register": "registrar"}[topic]
	if topic in ["check", "look"] and n.claimed_role == "registrar":
		role = "registrar"
	var told: bool = (n.max_tier >= 3 or n.claim_public) and n.claimed_role == role
	if not told:
		g._err("%s hasn't told you they're the %s." % [n.name, C.role_name(role)])
		return {}
	var targets: Array = []
	if role == "nightwatch":
		var b: String = g.find_block(target)
		if b == "":
			g._err("Watch which block?")
			return {}
		targets = [b]
	else:
		var names = target.replace(" and ", ",").split(",")
		if role == "seer" and not target.contains(",") and not target.contains(" and "):
			names = target.split(" ", false)
		for nm in names:
			var t = g.find_npc(nm.strip_edges())
			if t == null or not t.alive or t == n:
				g._err("Ask them to %s whom?" % ("look at" if role == "seer" else ("check" if role == "registrar" else "guard")))
				return {}
			if not (t.id in targets):
				targets.append(t.id)
		if targets.is_empty() or targets.size() > (2 if role == "seer" else 1):
			g._err("A Seer looks at one or two people; a Registrar or Warden picks one.")
			return {}
	if g.w.phase == C.NIGHT:
		g._err("It's too late to ask for tonight.")
		return {}
	return Mind.consider_gift_request(g.w, n, role, targets)


## The incidents you could apologise for, for error text and menus.
static func _grievance_menu(n) -> String:
	var open: Array = Mind.open_grievances(n)
	if open.is_empty():
		return "(Nothing you've done to them needs an apology.)"
	var items: Array = []
	for i in range(open.size()):
		items.append("%d: %s" % [i + 1, grievance_text(open[i])])
	return "('apologise <number>': %s)" % "; ".join(PackedStringArray(items))


## A grievance as the player would say it ("for guessing my gift wrong").
static func grievance_text(g: Dictionary) -> String:
	var why: String = g["why"].trim_prefix("the Demonologist ")
	return "day %d, %s" % [g["day"], why]


## "offer ward" / "offer vigil": promise your ward on their door, or a vigil on their block,
## tonight. Costs no question. A little trust now, more if you keep it, a lot lost if not.
## requested: they asked for it (no thanks line: they've their own to say).
static func _offer_command(g, n, what: String, requested: bool = false) -> void:
	match what:
		"ward":
			if g.w.tools["ward"] <= 0:
				g._err("Your ward is spent; you can't offer it.")
				return
			if g.offer.has("ward"):
				g._err("You've already promised your ward tonight to %s." % g.w.by_id[g.offer["ward"]].name)
				return
			g.offer["ward"] = n.id
			g._narr("You promise %s your ward: a sigil on their door tonight. Promising does not spend your ward; keeping the promise does (%d left, once per case)." % [n.name, g.w.tools["ward"]])
		"vigil":
			var vg: Dictionary = g.offer.get("vigil", {})
			if vg.has(n.id):
				g._err("You've already promised %s a vigil tonight." % n.name)
				return
			vg[n.id] = n.home_block
			g.offer["vigil"] = vg
			g._narr("You promise %s you'll keep watch over %s tonight." % [n.name, C.block_name(n.home_block)])
		_:
			g._err("Offer what? ('offer ward' or 'offer vigil')")
			return
	g.talk_offered = g.talk_offered or g.state == "talk"
	if not requested:
		g._line(Mind.say_voiced(n, "offer_thanks", "That's good of you. I'll sleep a little easier."))
	Mind.Dialogue.record_exchange(n.dialogue_memory, "other")
	Mind.set_trust(g.w, n, n.trust + Tuning.Trust.PROMISE_OFFER_BONUS, "the Demonologist offered to watch over me tonight")
	g.w.dlog.add("player_offer", "player", n.id, {"what": what, "block": n.home_block, "requested": requested})
	if n.is_evil():
		Mind.Evil.note_player_offer(g.w, n, what, n.home_block if what == "vigil" else n.id)
	if g.state == "talk":
		g._prompt("(No question used. %d question%s left)" % [g.questions_left, "" if g.questions_left == 1 else "s"])


## What you've promised tonight, for the menus.
static func offer_text(g) -> String:
	var parts: Array = []
	if g.offer.has("ward"):
		parts.append("your ward to %s" % g.w.by_id[g.offer["ward"]].name)
	for id in g.offer.get("vigil", {}):
		parts.append("a vigil on %s to %s" % [C.block_name(g.offer["vigil"][id]), g.w.by_id[id].name])
	return ", ".join(PackedStringArray(parts))


## Keep or break tonight's promises, once your night work is chosen.
static func _settle_offers(g) -> void:
	var promised: Array = []
	if g.offer.has("ward"):
		promised.append([g.offer["ward"], g.ward_log.get(g.w.day, "") == g.offer["ward"], "ward"])
	for id in g.offer.get("vigil", {}):
		var warded: bool = g.ward_log.get(g.w.day, "") == id
		# A ward on their own door fulfils the protection promised by a vigil.
		# When both were promised, the kept ward above already settles it once.
		if warded and g.offer.get("ward", "") == id: continue
		promised.append([id, warded or g.w.player_vigil == g.offer["vigil"][id], "vigil"])
	for p in promised:
		var n = g.w.by_id[p[0]]
		if not n.alive:
			continue
		if p[1]:
			Mind.set_trust(g.w, n, n.trust + Tuning.Trust.PROMISE_KEPT_BONUS, "the Demonologist kept their word (%s)" % p[2])
			g._narr("You keep your word to %s." % n.name)
			n.fear_eased = true  # less afraid to say what they are, from now on
			if g.protect_pending.has(n.id) and not (n.id in g.divulge_due):
				g.divulge_due.append(n.id)
		else:
			Mind.set_trust(g.w, n, n.trust - Tuning.Trust.PROMISE_BROKEN_DROP, "the Demonologist broke their word (%s)" % p[2])
			g._narr("You break your word to %s. They'll know by morning." % n.name)
			n.fear_eased = false  # and the fear comes back
			n.protect_lock = false
		g.protect_pending.erase(n.id)
		g.w.dlog.add("player_offer_settled", "player", n.id, {"what": p[2], "kept": p[1]})
	g.offer = {}


## Asked about someone, a talker may add where that person tends to be off work: one or
## both of their haunts, more likely with Gossip and trust in you.
static func _maybe_tell_haunts(g, n, t, r: Dictionary) -> void:
	if not t.alive or n.silenced:
		return
	var unknown: Array = t.haunts.filter(func(x): return not (x in g.known_haunts.get(t.id, [])))
	if unknown.is_empty():
		return
	var p = clampf(Tuning.Dialogue.SHARE_HAUNTS_BASE + Tuning.Dialogue.SHARE_HAUNTS_GOSSIP_SCALE * n.traits.get("gossip", 0.5) + Tuning.Dialogue.SHARE_HAUNTS_TRUST_SCALE * (n.trust - 0.5), 0.0, Tuning.Dialogue.SHARE_HAUNTS_CAP)
	var roll = g.w.rng.randf()
	g.w.observe_decision(n, "share_haunts", roll < p, {"inputs": {"gossip": n.traits.get("gossip", 0.5), "trust": n.trust}, "probability": p, "draw": roll, "threshold": p, "comparison": "<", "thresholds": {"all": p * Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE, "one": p}, "outcome_chances": {"all": p * Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE, "one": p * (1.0 - Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE), "none": 1.0 - p}}, t.id)
	if roll >= p:
		return
	var tell: Array = unknown if roll < p * Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE else [unknown[0]]
	var names: Array = tell.map(func(x): return g.w.loc_name(x))
	g.known_haunts[t.id] = g.known_haunts.get(t.id, []) + tell
	var places_s: String = " or ".join(PackedStringArray(names))
	r["lines"].append(Mind.say_voiced(n, "tell_haunt", "When %s isn't working, you'll often find them at %s." % [t.name, places_s], {"subject": t.name, "places": places_s}))
	for loc_id in tell:
		g.add_profile_receipt({"kind": "haunt", "subject": [t.id], "source": n.id, "loc": loc_id, "locs": [loc_id],
			"block": g.w.loc_block(loc_id), "day": g.w.day, "phase": g._phase_now(), "class": "circumstantial",
			"text": "%s says %s often goes to %s when not working." % [n.name, t.name, g.w.loc_name(loc_id)]})
	g.w.dlog.add("player_learns_haunts", n.id, t.id, {"locs": tell})


static func _record_trait_receipt(g, target, key: String, tier: String, source_id: String) -> int:
	var withdrawn: bool = target.withdrawn_since != ""
	var suffix: String = " (withdrawn after bereavement)" if withdrawn else ""
	return g.add_profile_receipt({"kind": "trait", "subject": [target.id], "source": source_id,
		"trait": key, "tier": tier, "withdrawn": withdrawn, "day": g.w.day, "phase": g._phase_now(),
		"class": "circumstantial", "text": "%s's %s: %s%s." % [target.name, key, tier, suffix]})


static func sync_bereaved_traits(g, target, source_id: String = "player") -> void:
	if target == null or target.withdrawn_since == "":
		return
	for key in target.revealed_traits.keys():
		var current_tier: String = C.tier(target.traits.get(key, 0.5))
		target.revealed_traits[key] = current_tier
		_record_trait_receipt(g, target, key, current_tier, source_id)


## Asked about someone, a talker may also say what that person is like: one trait,
## unlocking its bar in the profile. Friends know any trait; anyone else only the
## observable ones. The wording follows how the speaker feels about them.
const OBSERVABLE_TRAITS = ["privacy", "gossip", "confidence", "composure"]
const TRAIT_WORDS = {
	"privacy": {"low": ["an open book", "an open book about their own affairs", "someone who can't keep a thing to themselves"],
		"mid": ["willing to share when it suits them", "willing to share about themselves when it suits them", "careful what they share about themselves"],
		"high": ["private, and keeps their own counsel", "someone who keeps their own affairs close", "secretive"]},
	"gossip": {"low": ["discreet", "someone who keeps out of other people's business", "close-mouthed about everyone"],
		"mid": ["happy to pass on news if you ask", "willing to pass on news if asked", "someone who'll talk if you ask"],
		"high": ["always the first to know the news", "someone who loves passing on what they've heard", "a terrible gossip"]},
	"confidence": {"low": ["careful, and thinks twice", "someone who second-guesses themselves", "a pushover"],
		"mid": ["sensible, and open to reason", "neither stubborn nor easily swayed", "set in their ways, now and then"],
		"high": ["principled", "sure of themselves and hard to budge", "pigheaded"]},
	"composure": {"low": ["honest, and wears their heart on their sleeve", "someone who wears every feeling on their face", "jumpy"],
		"mid": ["level-headed enough", "fairly level-headed", "hard to read some days"],
		"high": ["steady as a rock", "someone who gives nothing away", "cold as a fish"]},
	"insight": {"low": ["trusting", "easily swayed by a good speech", "gullible"],
		"mid": ["no fool", "someone who wants a reason before they're convinced", "no fool, I'll grant"],
		"high": ["sharp, and hard to fool", "sharp and hard to fool", "too clever by half"]},
}


static func _maybe_tell_trait(g, n, t, r: Dictionary) -> void:
	if n.silenced:
		return
	var friend: bool = t.id in n.friends
	var rival: bool = t.id in n.rivals
	var allowed: Array = (Mind.C.TRAITS if friend else OBSERVABLE_TRAITS).filter(func(k): return not t.revealed_traits.has(k))
	if allowed.is_empty():
		return
	var p = clampf(Tuning.Dialogue.SHARE_TRAIT_BASE + Tuning.Dialogue.SHARE_TRAIT_GOSSIP_SCALE * n.traits.get("gossip", 0.5) + Tuning.Dialogue.SHARE_TRAIT_TRUST_SCALE * (n.trust - 0.5) + (Tuning.Dialogue.SHARE_TRAIT_FRIEND_BONUS if friend else 0.0), 0.0, Tuning.Dialogue.SHARE_TRAIT_CAP)
	if not g.w.decision_roll(n, "share_observed_trait", p, {"gossip": n.traits.get("gossip", 0.5), "trust": n.trust, "friend": friend}, t.id):
		return
	var key: String = g.w.decision_pick(n, "shared_trait_choice", allowed, {}, t.id)
	var tier: String = Mind.C.tier(t.traits[key])
	var words: String = TRAIT_WORDS[key][tier][0 if friend else (2 if rival else 1)]
	var line: String = ("I'll say this for %s: they're %s." if friend else ("%s is %s, if you ask me." if rival else "From what I've seen, %s is %s.")) % [t.name, words]
	var spoken_trait: Dictionary
	if n == t:
		# Keep the selected trait, its learning and the existing rolls; only person changes.
		var own_words: String = TRAIT_WORDS[key][tier][1].replace("themselves", "myself").replace("their", "my").replace("them", "me").replace("they've", "I've").replace("they're", "I'm")
		line = "I'd call myself %s." % own_words
		spoken_trait = Mind.say_voiced(n, "tell_trait_self", line, {"words": own_words})
	else:
		var trait_key: String = "tell_trait_friend" if friend else ("tell_trait_rival" if rival else "tell_trait_neutral")
		spoken_trait = Mind.say_voiced(n, trait_key, line, {"subject": t.name, "words": words})
	t.revealed_traits[key] = tier
	_record_trait_receipt(g, t, key, tier, n.id)
	r["lines"].append(spoken_trait)
	r["narration"] = r.get("narration", []) + ["(You learn %s's %s: %s.)" % [t.name, key.capitalize(), tier]]
	g.w.dlog.add("trait_reveal", n.id, t.id, {"trait": key, "tier": tier, "value": t.traits[key], "via": n.id, "friend": friend, "rival": rival})


const MAX_BONDS_TOLD = 2


## Town bonds use the haunt disclosure chance, but remain attributed profile notes.
## No relationship card or hidden Lover/private trust information is generated.
static func _maybe_tell_relationships(g, n, t, r: Dictionary) -> void:
	if not t.alive or n.silenced:
		return
	# Bonds the opinion line itself just stated aren't told twice.
	var stated: Array = []
	for line in r.get("lines", []):
		if line is Dictionary and not line.get("relationship", {}).is_empty():
			stated.append(line.relationship)
	var unknown: Array = []
	for bond in g.w.town_relationships:
		var key = bond.kind + ":" + ":".join(PackedStringArray(bond.people))
		if t.id in bond.people and not g.known_relationships.has(key):
			unknown.append({"key": key, "bond": bond})
	if unknown.is_empty():
		return
	var p = clampf(Tuning.Dialogue.SHARE_HAUNTS_BASE + Tuning.Dialogue.SHARE_HAUNTS_GOSSIP_SCALE * n.traits.get("gossip", 0.5) + Tuning.Dialogue.SHARE_HAUNTS_TRUST_SCALE * (n.trust - 0.5), 0.0, Tuning.Dialogue.SHARE_HAUNTS_CAP)
	var roll = g.w.rng.randf()
	g.w.observe_decision(n, "share_relationships", roll < p, {"inputs": {"gossip": n.traits.get("gossip", 0.5), "trust": n.trust}, "probability": p, "draw": roll, "threshold": p, "comparison": "<", "thresholds": {"all": p * Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE, "one": p}, "outcome_chances": {"all": p * Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE, "one": p * (1.0 - Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE), "none": 1.0 - p}}, t.id)
	if roll >= p:
		return
	# Filtered after the roll so the decision draws are unchanged. Ties to the dead belong to
	# grief and gossip, not a "who are they close to" answer; the speaker's own ties come
	# first; never more than two in one answer.
	var living: Callable = func(e): return e.bond.people.all(func(id): return g.w.by_id[id].alive)
	var said: Callable = func(e): return stated.any(func(sb): return sb.kind == e.bond.kind and e.bond.people.all(func(id): return id in sb.people))
	unknown = unknown.filter(func(e): return living.call(e) and not said.call(e))
	if unknown.is_empty():
		return
	unknown.sort_custom(func(a, b): return (n.id in a.bond.people) and not (n.id in b.bond.people))
	var tell: Array = unknown.slice(0, MAX_BONDS_TOLD) if roll < p * Tuning.Dialogue.SHARE_HAUNTS_ALL_SHARE else [unknown[0]]
	var used_keys: Array = []
	for entry in tell:
		var bond: Dictionary = entry.bond
		var name_a: String = g.w.by_id[bond.people[0]].name
		var name_b: String = g.w.by_id[bond.people[1]].name
		var text = "%s and %s %s." % [name_a, name_b,
			"are close" if bond.kind == "friend" else "don't get along"]
		var note = n.name + " says " + text
		var bond_line: Dictionary
		if n.id in bond.people:
			var other: String = bond.people[1] if bond.people[0] == n.id else bond.people[0]
			var other_name: String = g.w.by_id[other].name
			text = "%s and I %s." % [other_name, "are close" if bond.kind == "friend" else "don't get along"]
			note = n.name + ' says "' + text + '"'
			var self_key: String = "tell_bond_self_close" if bond.kind == "friend" else "tell_bond_self_rival"
			bond_line = Mind.say_voiced(n, self_key, text, {"other": other_name})
		else:
			var third_key: String = "tell_bond_third_close" if bond.kind == "friend" else "tell_bond_third_rival"
			# A second bond of the same kind in one answer gets the plain wording, so a
			# voice's idiom ("thick as thieves") isn't said twice in a row.
			bond_line = Mind.say(n, text) if third_key in used_keys else Mind.say_voiced(n, third_key, text, {"a": name_a, "b": name_b})
			used_keys.append(third_key)
		g.known_relationships[entry.key] = {"kind": bond.kind, "people": bond.people.duplicate(), "source": n.id, "text": note}
		var bond_people: Array = bond.people.duplicate()
		bond_people.sort()
		g.add_profile_receipt({"kind": "bond", "subject": bond_people, "bond_kind": bond.kind, "source": n.id,
			"day": g.w.day, "phase": g._phase_now(), "class": "circumstantial", "text": note})
		r.lines.append(bond_line)
		g.w.dlog.add("player_learns_relationship", n.id, t.id, {"kind": bond.kind, "people": bond.people})


## Authored speech can explicitly disclose a bond outside "ask about". Record only
## that disclosure, never infer from suspicion, actual bonds, or hidden Lover state.
static func _remember_spoken_relationship(g, line: Dictionary) -> void:
	var bond: Dictionary = line.get("relationship", {})
	var people: Array = bond.get("people", [])
	var source: String = line.get("speaker", "")
	if bond.get("kind", "") not in ["friend", "rival"] or people.size() != 2 or people[0] == people[1] or source not in people or not people.all(func(id): return g.w.by_id.has(id)):
		return
	for known in g.known_relationships.values():
		if known.kind == bond.kind and people.all(func(id): return id in known.people): return
	people = people.duplicate()
	people.sort()
	var key = bond.kind + ":" + ":".join(PackedStringArray(people))
	g.known_relationships[key] = {"kind": bond.kind, "people": people, "source": source,
		"text": g.w.by_id[source].name + ' says "' + line.text + '"'}
	g.add_profile_receipt({"kind": "bond", "subject": people.duplicate(), "bond_kind": bond.kind, "source": source,
		"day": g.w.day, "phase": g._phase_now(), "class": "circumstantial", "text": g.known_relationships[key].text})
	g.w.dlog.add("player_learns_relationship", source, people[1] if people[0] == source else people[0], {"kind": bond.kind, "people": people, "how": "explicit speech"})


static func known_relationship_notes(g, id: String) -> Array:
	return g.known_relationships.values().filter(func(b): return id in b.people).map(func(b): return b.text)


## Haunts you've been told about, as place names.
static func known_haunt_names(g, id: String) -> String:
	return " or ".join(PackedStringArray(g.known_haunts.get(id, []).map(func(l): return g.w.loc_name(l))))


static func _close_conversation(g) -> void:
	var n = g.talk_with
	g.pending_request = {}
	var before_traits: Dictionary = n.revealed_traits.duplicate() if n != null else {}
	for t in Mind.end_conversation(g.w, n):
		g._narr(t)
	if n != null:
		for key in n.revealed_traits:
			if not before_traits.has(key):
				_record_trait_receipt(g, n, key, n.revealed_traits[key], "player")
		sync_bereaved_traits(g, n, "player")
	g.state = "day"
	g.talk_with = null
	g._end_phase(n.id)

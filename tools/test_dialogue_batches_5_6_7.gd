## Regression suite for Dialogue Batches 5, 6 & 7:
## - Batch 5: 31 Workshop case-presentation & self-support/repeat keys across all 15 cast voices,
##   BotC top-Demon + #2-accomplice rival framing (never naming a 3rd), dead starting-Demon
##   Scion promotion, conditional Marked relevance gating, and Good-vs.-Evil presentation parity.
## - Batch 6: 8 VN conversation greeting keys across all 15 cast voices, 5-state portrait
##   expressions, 5 one-shot contextual overrides, Composure 1-RNG-draw parity with greeting_cue,
##   tic-budget conservation on greet_neutral, DayConversationView consumption, and zero-cost bye.
## - Batch 7: 46 new voice keys + full 15-cast completion of private_reveal_early and
##   doubted_visual (230 symmetric keys per character), wiring all 25 remaining [PH] sites
##   across sim/mind_dialogue.gd, sim/social.gd, sim/mind_meeting.gd, sim/roles/*.gd, and
##   game/game_conversation.gd, plus zero-[PH] repository scan across sim/, game/, workshop/, ui/.
extends SceneTree

const Game = preload("res://game/game.gd")
const GameConversation = preload("res://game/game_conversation.gd")
const C = preload("res://sim/content.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Social = preload("res://sim/social.gd")
const DayConvView = preload("res://ui/day_conversation_view.gd")

const CAST_IDS = [
	"agnes", "bart", "constance", "dorian", "edda",
	"fenwick", "greta", "hollis", "isolde", "jory",
	"kiran", "lian", "merrin", "nisha", "odette",
]

const BATCH5_SLOTS = {
	"present_accept_solid": {},
	"present_accept_open": {"target": "Edda"},
	"present_partial": {"target": "Edda"},
	"present_unmoved": {"target": "Edda"},
	"present_already": {"target": "Edda"},
	"present_alt_accept": {"demon": "Fenwick", "accomplice": "Odette", "target": "Edda"},
	"present_alt_partial": {"demon": "Fenwick", "accomplice": "Odette", "target": "Edda"},
	"present_alt_reject": {"demon": "Fenwick", "accomplice": "Odette"},
	"present_alt_accept_solo": {"demon": "Fenwick", "target": "Edda"},
	"present_alt_partial_solo": {"demon": "Fenwick", "target": "Edda"},
	"present_alt_reject_solo": {"demon": "Fenwick"},
	"present_alt_marked": {"marked": "Isolde"},
	"present_points_elsewhere": {"target": "Edda", "rival": "Fenwick"},
	"present_weighs_against": {"target": "Edda"},
	"present_conflict_found": {},
	"present_conflict_weighing": {},
	"present_conflict_none": {},
	"present_conditional": {},
	"present_lost_thread": {},
	"present_partial_attention": {},
	"present_false_self": {},
	"present_false_known": {},
	"present_circumstantial_only": {},
	"present_move_trace_lean": {},
	"present_seen_elsewhere": {"subject": "Edda", "night": "1"},
	"present_role_fit": {"subject": "Edda", "role": "Warden"},
	"present_repeat_meeting": {},
	"present_repeat_private": {},
	"self_support_thanks": {},
	"self_support_weak": {},
	"self_support_repeat": {},
}

const BATCH6_EVENT_SLOTS = {
	"greet_friend_killed": {"victim": "Rowan"},
	"greet_after_murder": {"victim": "Rowan"},
	"greet_after_execution": {"executed": "Kiran"},
	"greet_after_friction": {},
	"greet_after_protection": {},
}

const BATCH7_SLOTS = {
	"private_reveal_early": {"role": "Surveyor"},
	"hint_why_empty_1": {},
	"hint_why_empty_2": {},
	"hint_why_lead": {"target": "Fenwick"},
	"hint_why_confidential": {},
	"press_not_about_me": {},
	"press_counter_claim": {"role": "Seer", "rival": "Odette"},
	"pressed_home_stand_alt": {"when": "last night"},
	"confess_secret_private_alt": {"secret": "slipped out to mend a shutter"},
	"pressed_refusal_stand_alt": {},
	"pressed_warden_night": {"target": "Agnes", "when": "last night"},
	"pressed_warden_night_alt": {"target": "Agnes", "when": "last night"},
	"pressed_nightwatch_night": {"block": "the Docks", "when": "last night"},
	"pressed_nightwatch_night_alt": {"block": "the Docks", "when": "last night"},
	"pressed_lamplighter_night": {"when": "last night"},
	"pressed_lamplighter_night_alt": {"when": "last night"},
	"pressed_medium_night": {"hearth": "Rowan's hearth", "when": "last night"},
	"pressed_medium_night_alt": {"hearth": "the dead", "when": "last night"},
	"hint_pkg_official": {},
	"hint_pkg_night_sight": {},
	"hint_pkg_the_dead": {},
	"hint_pkg_shelter": {},
	"hint_pkg_people": {},
	"withhold_readings_fear_all": {},
	"withhold_readings_fear_rest": {},
	"protect_trust_now": {},
	"deny_any_gift": {"occupation": "baker"},
	"repeat_guess_1": {},
	"repeat_guess_2": {},
	"repeat_withheld_1": {},
	"repeat_withheld_2": {},
	"repeat_fear_1": {},
	"repeat_fear_2": {},
	"repeat_gift_1": {},
	"repeat_gift_2": {},
	"role_query_public": {"names": "Agnes and Hollis", "role": "Seer"},
	"role_query_private_direct": {"who": "Isolde", "role": "Warden"},
	"role_query_private_via": {"who": "Isolde", "via": "Edda", "role": "Warden"},
	"role_query_reading": {"reading": "neither Agnes nor Jory read as the Demon"},
	"role_already_claimed": {"role": "Archivist"},
	"role_already_claimed_none": {},
	"defence_red_herring": {"source": "Hollis"},
	"warden_doors_report": {"doors": "Night 1 at Agnes's door"},
	"warden_saves_claim": {"saves": "Agnes on night 1"},
	"meeting_relay_reading": {"role": "Seer", "reading": "one of Fenwick and Kiran read as the Demon"},
	"defence_pair_other": {"source": "Hollis", "other": "Fenwick"},
	"defence_fear_plea": {},
}

var checks: int = 0
var fails: int = 0


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		push_error("FAIL: " + msg)


func _game(seed_val: int = 5601, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_dialogue_b567"
	g.new_case(seed_val, size)
	return g


func _init() -> void:
	_test_voice_pack_completeness_and_symmetry()
	_test_botc_rival_pair_and_marked_gate()
	_test_live_presentation_and_evil_parity()
	_test_vn_greetings_expressions_and_rng_parity()
	_test_batch7_conversations_press_roles_and_meetings()
	_test_zero_ph_across_runtime_dirs()
	if fails == 0:
		print("test_dialogue_batches_5_6_7: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_dialogue_batches_5_6_7: %d/%d FAILED" % [fails, checks])
		quit(1)


func _test_voice_pack_completeness_and_symmetry() -> void:
	var ref_keys: Array = Voices.VOICES["agnes"].keys()
	ref_keys.sort()
	_check(ref_keys.size() == 230, "Agnes voice pack contains all 230 keys (got %d)" % ref_keys.size())
	for id in CAST_IDS:
		var ks: Array = Voices.VOICES[id].keys().filter(func(k): return k != "target_epithets")
		ks.sort()
		_check(ks == ref_keys, "%s shares identical 230-key schema with Agnes" % id)

	var all_string_keys: Dictionary = BATCH5_SLOTS.duplicate()
	for k in BATCH6_EVENT_SLOTS:
		all_string_keys[k] = BATCH6_EVENT_SLOTS[k]
	for k in BATCH7_SLOTS:
		all_string_keys[k] = BATCH7_SLOTS[k]
	for key in all_string_keys:
		var slots: Dictionary = all_string_keys[key]
		var seen: Dictionary = {}
		for id in CAST_IDS:
			var rendered: String = Dialogue.voice_line(id, key, "FALLBACK", slots)
			_check(rendered != "FALLBACK" and rendered != "" and not ("{" in rendered) and not ("}" in rendered) and not ("[PH]" in rendered), "%s/%s resolves cleanly without [PH] or leftover slots" % [id, key])
			for v in slots.values():
				_check(str(v) in rendered, "%s/%s preserves slot value %s" % [id, key, str(v)])
			if id != "nisha":
				_check(not ("data" in rendered.to_lower()), "%s/%s keeps 'data' exclusive to Nisha" % [id, key])
			if BATCH7_SLOTS.has(key):
				_check(not ("when it's safer" in rendered.to_lower()), "%s/%s avoids 'when it's safer'" % [id, key])
				_check(not ("stand by it" in rendered.to_lower()), "%s/%s avoids 'stand by it' boilerplate" % [id, key])
			seen[rendered] = true
		_check(seen.size() == CAST_IDS.size(), "all 15 cast voices are distinct for " + key)

	for pool_key in ["greet_neutral", "greet_cold", "greet_warm", "doubted_visual"]:
		var expected_len: int = 3 if pool_key == "greet_neutral" else 2
		var seen_pools: Dictionary = {}
		for id in CAST_IDS:
			var arr = Voices.VOICES[id].get(pool_key, [])
			_check(arr is Array and arr.size() == expected_len, "%s/%s has %d variants" % [id, pool_key, expected_len])
			if arr is Array:
				seen_pools[JSON.stringify(arr)] = true
				for item in arr:
					var s: String = str(item)
					_check(s != "" and not ("[PH]" in s) and not ("{" in s), "%s/%s entry is clean" % [id, pool_key])
					if id != "nisha":
						_check(not ("data" in s.to_lower()), "%s/%s keeps 'data' exclusive to Nisha" % [id, pool_key])
					if pool_key == "greet_neutral":
						var mem: Dictionary = {}
						Dialogue.begin_scope(mem)
						var after_tic: String = Dialogue.apply_tics(id, s, mem)
						_check(mem.get("tics", {}).is_empty() and after_tic == s, "%s/greet_neutral conserves Dialogue.TICS budget (%s)" % [id, s])
		_check(seen_pools.size() == CAST_IDS.size(), "all 15 cast voices have distinct %s pools" % pool_key)


func _test_botc_rival_pair_and_marked_gate() -> void:
	var g = _game(5602, 10)
	var listener = g.w.living_good()[0]
	var others: Array = g.w.npcs.filter(func(p): return p.id != listener.id)
	var d_id: String = others[0].id
	var e2_id: String = others[1].id
	var e3_id: String = others[2].id
	var m_id: String = others[3].id
	var t_id: String = others[4].id
	listener.suspicion[d_id] = 0.45
	listener.suspicion[e2_id] = 0.62
	listener.suspicion[e3_id] = 0.18

	var pair: Dictionary = Presentations._pick_rival_pair(g.w, listener.id, listener.suspicion, {
		"demon": d_id,
		"evil": [d_id, e2_id, e3_id],
		"marked": m_id,
	}, "now")
	_check(pair.demon_id == d_id and pair.accomplice_id == e2_id, "BotC rival pair picks Demon + single highest-suspicion #2 evil and omits 3rd evil")

	g.w.by_id[d_id].alive = false
	var jumped: Dictionary = Presentations._pick_rival_pair(g.w, listener.id, listener.suspicion, {
		"demon": d_id,
		"evil": [d_id, e2_id, e3_id],
		"marked": m_id,
	}, "now")
	_check(jumped.demon_id == e2_id and jumped.accomplice_id == e3_id, "Dead starting Demon promotes living evil successor on 'now' claims")
	g.w.by_id[d_id].alive = true

	var irrelevant_snap = {
		"selected": ["r1"],
		"evidence": [{"id": "r1", "kind": "report", "role": "seer", "data": {"pair": [t_id, e2_id], "yes": true}}],
	}
	_check(not Presentations._is_marked_relevant(m_id, {"type": "evil", "a": t_id}, irrelevant_snap, {"considered": ["r1"]}), "Unmentioned Marked person stays silent")
	var relevant_snap = {
		"selected": ["r1"],
		"evidence": [{"id": "r1", "kind": "report", "role": "seer", "data": {"pair": [t_id, m_id], "yes": true}}],
	}
	_check(Presentations._is_marked_relevant(m_id, {"type": "evil", "a": t_id}, relevant_snap, {"considered": ["r1"]}), "Attended Seer ping mentioning Marked triggers present_alt_marked")


## File a real Workshop case ("target is evil") from board cards, the way the canvas does.
func _file_case(g, target_id: String, board_numbers: Array) -> int:
	var WorkshopCanvas = preload("res://game/workshop_canvas.gd")
	var CanvasModel = preload("res://workshop/canvas_model.gd")
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var root: String = model.selected
	model.nodes[root].conclusion = {"type": "evil", "target": target_id, "at": view.alignment_epoch}
	for num in board_numbers:
		var node: String = "e:" + WorkshopCanvas.Evidence.normalize_card(g.board[int(num) - 1]).id
		if model.nodes.has(node):
			model.connect_cards(node, root)
	return WorkshopCanvas.file(g, model.compile(root), 0)


func _test_live_presentation_and_evil_parity() -> void:
	var g = _game(5603, 7)
	var good_listener = g.w.living_good()[0]
	var evil_listener = g.w.demon()
	var target = g.w.living_good()[1]
	var mate = g.w.minion()
	g.w.day = 2
	g.w.phase = C.EVENING

	var seer_src = g.w.living_good()[2]
	g._facts([{
		"kind": "claim", "source": seer_src.id, "subject": [seer_src.id], "role": "seer",
		"day": 1, "phase": C.MORNING, "private": false,
		"text": "%s claims to be the Seer." % seer_src.name,
	}, {
		"kind": "info", "source": seer_src.id, "subject": [target.id, mate.id], "role": "seer",
		"day": 1, "phase": C.MORNING, "private": false,
		"data": {"pair": [target.id, mate.id], "yes": true},
		"text": "%s (Seer, Night 1): one of %s or %s is the Demon." % [seer_src.name, target.name, mate.name],
	}])
	var ded_num: int = _file_case(g, target.id, [1, 2])
	_check(ded_num > 0, "test case against the target files through the Workshop")
	var ded: Dictionary = g.board[ded_num - 1]
	var r_good: Dictionary = g._evaluate_deduction(good_listener, ded, 1.0, true, "private")
	var r_evil: Dictionary = g._evaluate_deduction(evil_listener, ded, 1.0, true, "private")
	_check(not r_good.lines.is_empty() and not ("[PH]" in r_good.lines[0].text) and r_good.lines[0].has("statement"), "Good Workshop presentation speaks character voice with zero [PH] and canonical statement")
	_check(not r_evil.lines.is_empty() and not ("[PH]" in r_evil.lines[0].text) and r_evil.lines[0].has("statement"), "Evil Workshop presentation speaks character voice with zero [PH] and canonical statement")

	var self_ded_num: int = _file_case(g, evil_listener.id, [1, 2])
	_check(self_ded_num > 0, "test case against the evil listener files through the Workshop")
	var r_self_evil: Dictionary = g._evaluate_deduction(evil_listener, g.board[self_ded_num - 1], 1.0, true, "private")
	var expected_self: String = Dialogue.voice_line(evil_listener.id, "present_false_self", "")
	_check(not r_self_evil.lines.is_empty() and r_self_evil.lines[0].text == expected_self, "Evil self-accusation uses character's present_false_self line")

	# Self-support thanks needs a card that clears the listener (their own claim does).
	var own_claims: Dictionary = {}
	for who in [good_listener, evil_listener]:
		g._facts([{"kind": "claim", "source": who.id, "subject": [who.id], "role": "clerk",
			"day": 2, "phase": C.MORNING, "private": false, "text": "%s claims to be the Clerk." % who.name}])
		own_claims[who.id] = g.board.back()
	var sup_good: Dictionary = Mind.hear_defence(g.w, good_listener, [good_listener], own_claims[good_listener.id])
	var sup_evil: Dictionary = Mind.hear_defence(g.w, evil_listener, [evil_listener], own_claims[evil_listener.id])
	_check(not sup_good.lines.is_empty() and not ("[PH]" in sup_good.lines[0].text) and sup_good.lines[0].statement == "Thank you for believing me.", "Good self-support uses voiced self_support_thanks with canonical statement")
	_check(not sup_evil.lines.is_empty() and not ("[PH]" in sup_evil.lines[0].text) and sup_evil.lines[0].statement == "Thank you for believing me.", "Evil self-support uses voiced self_support_thanks with canonical statement")


func _test_vn_greetings_expressions_and_rng_parity() -> void:
	var g_a = _game(5604, 7)
	var g_b = _game(5604, 7)
	for i in range(g_a.w.npcs.size()):
		Mind.greeting_cue(g_a.w, g_a.w.npcs[i])
		var gl: Dictionary = Mind.greeting_line(g_b.w, g_b.w.npcs[i], {})
		_check(gl.get("text", "") != "" and not ("[PH]" in gl.get("text", "")), "greeting_line produces non-empty [PH]-free speech for " + g_b.w.npcs[i].id)
	_check(g_a.w.rng.state == g_b.w.rng.state, "greeting_line preserves exact 1-draw RNG parity with greeting_cue")

	var g = _game(5605, 7)
	var speaker = g.w.living_good()[0]
	var victim = g.w.living_good()[1]
	g.w.day = 2
	g.w.phase = C.MORNING
	speaker.npc_trust[victim.id] = 0.80
	g.w.deaths_last_night = [victim.id]
	var fk_line: Dictionary = Mind.greeting_line(g.w, speaker, {})
	_check(victim.name in fk_line.text and fk_line.get("expression", "") == "sorrowful" and fk_line.get("expression_strength", 0) == 2, "Friend murdered morning triggers sorrowful greet_friend_killed")

	speaker.traits["composure"] = 0.0
	speaker.trust = 0.85
	var warm_line: Dictionary = Mind.greeting_line(g.w, speaker, {})
	_check(warm_line.get("expression", "") == "warm" and warm_line.text in Voices.VOICES[speaker.id]["greet_warm"], "Second talk after one-shot murder greeting falls back to warm rapport greeting")

	var prot_line: Dictionary = Mind.greeting_line(g.w, speaker, {"protection_key": "protect:promise:" + speaker.id})
	_check(prot_line.text == Voices.VOICES[speaker.id]["greet_after_protection"] and prot_line.get("expression", "") == "warm", "Kept protection triggers warm greet_after_protection")
	var fric_line: Dictionary = Mind.greeting_line(g.w, speaker, {"protection_key": "protect:promise:" + speaker.id, "friction_key": "friction:accuse:2"})
	_check(fric_line.text == Voices.VOICES[speaker.id]["greet_after_friction"] and fric_line.get("expression", "") in ["harsh", "concerned"], "Recent player friction triggers greet_after_friction once protection key was already greeted")

	var g_live = _game(5606, 7)
	var target_npc = null
	for p in g_live.w.living():
		if not p.at_home() and p.busy_with == "":
			target_npc = p
			break
	if target_npc != null:
		g_live.command("go " + target_npc.loc)
		g_live.command("talk " + target_npc.name)
		_check(g_live.state == "talk" and g_live.questions_left == 3, "talk enters conversation with all 3 questions intact")
		var speeches: Array = g_live.last_events.filter(func(e): return e.get("k", "") == "speech" and e.get("speaker", "") == target_npc.id)
		_check(not speeches.is_empty() and not ("Choose a question to begin." in speeches[0].get("text", "")), "talk emits opening greeting speech event for VN stage")
		var view = DayConvView.new()
		root.add_child(view)
		view.begin(target_npc.id, target_npc.name)
		view.consume(g_live.last_events)
		_check(not view.lines.is_empty() and view.lines[0] == speeches[0]["text"], "DayConversationView.consume captures opening greeting line immediately")
		root.remove_child(view)
		view.free()
		var bye_reply: String = g_live.command("bye")
		_check(g_live.state == "day" and "No time spent" in bye_reply, "Leaving immediately after greeting still cancels conversation at zero phase cost")


func _test_batch7_conversations_press_roles_and_meetings() -> void:
	# 1. doubted_visual resolves with cue == "doubted_visual" across all 15 characters.
	for id in CAST_IDS:
		var mem: Dictionary = {}
		var res: Dictionary = Dialogue.compose(id, {"kind": "doubted", "statement": "I saw Fenwick on the Market last night."}, {"challenged": true, "visual": true}, mem)
		_check(res.get("cue", "") == "doubted_visual" and not ("[PH]" in res.get("text", "")), "%s resolves doubted_visual cue cleanly" % id)

	# 2. Day 1 unpressed private_reveal_early works for non-Constance cast members too.
	var g = _game(5701, 10)
	var speaker = g.w.living_good()[0]
	var other = g.w.living_good()[1]
	var third = g.w.living_good()[2]
	speaker.role = "surveyor"
	speaker.claimed_role = ""
	speaker.claim_public = false
	speaker.max_tier = 0
	speaker.trust = 0.95
	speaker.traits["privacy"] = 0.0
	speaker.dialogue_memory = {}
	g.w.day = 1
	g.w.phase = C.MORNING
	speaker.pressed_today = 0
	var early_res: Dictionary = Mind.answer_gift(g.w, speaker)
	var expected_early: String = Dialogue.voice_line(speaker.id, "private_reveal_early", "", {"role": C.role_name("surveyor")})
	_check(not early_res.lines.is_empty() and early_res.lines[0].text == Dialogue.apply_tics(speaker.id, expected_early, {}), "Day 1 unpressed gift disclosure uses private_reveal_early for " + speaker.id)

	# 3. Tier-2 HINT_PACKAGES across all 5 packages.
	var pkg_roles = {
		"official": "archivist",
		"night_sight": "seer",
		"the_dead": "gravedigger",
		"shelter": "warden",
		"people": "dowser",
	}
	for pk in pkg_roles:
		speaker.role = pkg_roles[pk]
		speaker.claimed_role = ""
		speaker.claim_public = false
		speaker.max_tier = 0
		speaker.dialogue_memory = {}
		var r_pkg: Dictionary = Mind.answer_gift(g.w, speaker, 2, false)
		_check(not r_pkg.lines.is_empty() and not ("[PH]" in r_pkg.lines[0].text) and r_pkg.lines[0].has("statement"), "Tier-2 hint package %s renders voiced line without [PH]" % pk)

	# 4. Mind.answer_hint empty alternation + accepted lead & confidentiality tail.
	speaker.hints = {}
	speaker.dialogue_memory = {}
	var eh1: Dictionary = Mind.answer_hint(g.w, speaker)
	var eh2: Dictionary = Mind.answer_hint(g.w, speaker)
	_check(eh1.lines[0].text != eh2.lines[0].text and not ("[PH]" in eh1.lines[0].text) and not ("[PH]" in eh2.lines[0].text), "Empty hint follow-ups alternate between hint_why_empty_1 and hint_why_empty_2 without [PH]")

	var g_hint = _game(5702, 10)
	var h_good: Array = g_hint.w.living_good()
	var h_speaker = h_good[0]
	var h_other = h_good[1]
	var h_third = h_good[2]
	h_speaker.role = "seer"
	h_speaker.claimed_role = ""
	h_speaker.claim_public = false
	h_speaker.max_tier = 0
	h_speaker.trust = 1.0
	h_speaker.traits["privacy"] = 0.0
	h_speaker.ledger = {}
	Mind.hear_claim(g_hint.w, h_speaker, h_speaker.id, "seer", Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")
	h_speaker.info_log = [{"day": 0, "role": "seer", "data": {"pair": [h_other.id, h_third.id], "yes": true}, "text": "I looked at %s and %s: one of them reads as the demon" % [h_other.name, h_third.name], "true": false, "shared": false, "why": "test"}]
	h_speaker.applied_info = 0
	h_speaker.told_readings = 0
	Mind.update_from_own_info(g_hint.w)
	h_speaker.hints = {h_other.id: {"day": g_hint.w.day}}
	var ah_ok: Dictionary = Mind.answer_hint(g_hint.w, h_speaker)
	_check(ah_ok.lines.size() >= 3 and h_other.name in ah_ok.lines[0].text and not ("[PH]" in ah_ok.lines[0].text) and not ("[PH]" in ah_ok.lines.back().text), "Accepted hint follow-up voices hint_why_lead and hint_why_confidential without [PH]")

	# 5. Mind.press: unrelated card & counter-claim confrontation.
	var unrelated_card = {"kind": "sighting", "source": third.id, "subject": [other.id], "block": "market", "day": 1, "phase": C.NIGHT, "text": "Sighting"}
	var p_unrel: Dictionary = Mind.press(g.w, speaker, unrelated_card)
	_check(not p_unrel.lines.is_empty() and not ("[PH]" in p_unrel.lines[0].text) and p_unrel.lines[0].statement == "What has that to do with me?", "Unrelated press card uses voiced press_not_about_me and preserves canonical statement")

	speaker.claim_public = true
	speaker.claimed_role = "seer"
	var rival_claim = {"kind": "claim", "source": other.id, "subject": [other.id], "role": "seer", "day": 1, "phase": C.MORNING, "text": "%s claims Seer." % other.name}
	var p_counter: Dictionary = Mind.press(g.w, speaker, rival_claim)
	var c_speeches: Array = p_counter.lines.filter(func(l): return l is Dictionary)
	_check(not c_speeches.is_empty() and not ("[PH]" in c_speeches[0].text) and other.name in c_speeches[0].text and c_speeches[0].get("expression", "") == "harsh", "Counter-claim press uses harsh voiced press_counter_claim without [PH]")

	# 6. Night-walking duty presses (1st & 2nd press) preserve canonical RoleDef statement while voicing text.
	g.w.day = 2
	for duty_role in ["warden", "nightwatch", "lamplighter", "medium"]:
		var walker = g.w.living_good()[0]
		walker.role = duty_role
		walker.claimed_role = duty_role
		walker.claim_public = true
		walker.max_tier = 4
		walker.dialogue_memory = {}
		if duty_role == "warden":
			walker.warden_log = {"1": other.id}
			walker.warden_saves = {"1": {"target": other.id}}
			walker.history[g.w.time_key(1, C.NIGHT)] = "night:" + other.home_block
			var w_gift: Dictionary = Mind.answer_gift(g.w, walker, 4, false)
			for wl in w_gift.lines:
				_check(not ("[PH]" in wl.text), "Warden door/save disclosure lines have zero [PH]")
		elif duty_role == "nightwatch":
			walker.info_log = [{"day": 1, "role": "nightwatch", "data": {"block": "market", "seen": []}, "text": "I watched the Market and saw nobody", "true": true, "shared": true}]
			walker.history[g.w.time_key(1, C.NIGHT)] = "night:market"
		elif duty_role == "lamplighter":
			walker.history[g.w.time_key(1, C.NIGHT)] = "night:square"
		elif duty_role == "medium":
			walker.history[g.w.time_key(1, C.NIGHT)] = "night:hill"
		var sight_card = {"kind": "sighting", "source": third.id, "subject": [walker.id], "block": "market", "day": 1, "phase": C.NIGHT, "text": "Saw %s out" % walker.name}
		var pr1: Dictionary = Mind.press(g.w, walker, sight_card)
		var pr2: Dictionary = Mind.press(g.w, walker, sight_card)
		var sp1: Array = pr1.lines.filter(func(l): return l is Dictionary)
		var sp2: Array = pr2.lines.filter(func(l): return l is Dictionary)
		_check(not sp1.is_empty() and not sp2.is_empty() and not ("[PH]" in sp1[0].text) and not ("[PH]" in sp2[0].text) and sp1[0].text != sp2[0].text and sp1[0].has("statement") and sp2[0].has("statement"), "1st and 2nd press on %s night duty use distinct voiced lines with canonical statement" % duty_role)

	# 7. Social.answer_about_role (public + private + C.third_person reading) & Social.answer_is_role.
	speaker.role = "clerk"
	speaker.claimed_role = "clerk"
	speaker.claim_public = true
	speaker.max_tier = 4
	speaker.trust = 0.95
	speaker.traits["gossip"] = 0.95
	other.claim_public = false
	speaker.known_claims[other.id] = {
		"role": "seer",
		"via": third.id,
		"readings": [{"day": 1, "role": "seer", "data": {"pair": [speaker.id, third.id], "yes": false}, "text": "I looked at %s and %s: neither reads as the demon" % [speaker.name, third.name], "true": true}],
	}
	var about_r: Dictionary = Social.answer_about_role(g.w, speaker, "seer")
	_check(not about_r.lines.is_empty() and not ("[PH]" in about_r.lines[0].text) and not (" I looked" in about_r.lines[0].text) and about_r.lines[0].has("statement"), "Social.answer_about_role voices relayed claims and normalizes readings via C.third_person")

	var is_r: Dictionary = Social.answer_is_role(g.w, speaker, "warden")
	_check(not is_r.lines.is_empty() and not ("[PH]" in is_r.lines[0].text) and "Clerk" in is_r.lines[0].text, "Social.answer_is_role uses voiced role_already_claimed when another gift was already claimed")

	# 8. Seer Red Herring defence & Meeting relay / pair_other / fear plea.
	var seer_npc = third
	seer_npc.role = "seer"
	seer_npc.claim_public = true
	seer_npc.claimed_role = "seer"
	var entry1 = {"day": 1, "role": "seer", "data": {"pair": [other.id, speaker.id], "yes": true}, "text": "I looked at %s and %s: one reads as the demon" % [other.name, speaker.name], "true": true, "shared": true}
	var entry2 = {"day": 2, "role": "seer", "data": {"pair": [other.id, g.w.demon_id], "yes": true}, "text": "I looked at %s and %s: one reads as the demon" % [other.name, g.w.by_id[g.w.demon_id].name], "true": true, "shared": true}
	seer_npc.info_log = [entry1, entry2]
	var rh_def: Dictionary = C.role_def("seer").try_reading_defence(g.w, other, seer_npc, seer_npc.id, entry1, Mind, Mind.WorkshopLedger)
	_check(rh_def.get("handled", false) and not ("[PH]" in rh_def.line.text) and seer_npc.name in rh_def.line.text, "Seer Red Herring defence uses voiced defence_red_herring without [PH]")

	var relay_lines: Array = []
	var relay_facts: Array = []
	MindMeeting.relay_reading(g.w, speaker, seer_npc, entry1, relay_lines, relay_facts)
	_check(not relay_lines.is_empty() and not ("[PH]" in relay_lines[0].text) and "Seer" in relay_lines[0].text, "MindMeeting.relay_reading uses voiced meeting_relay_reading without [PH]")

	# 9. Repeat refusals in GameConversation._repeat_refusal (including fear refusal without 'safer').
	Dialogue.begin_conversation(other.dialogue_memory)
	var resp_fear1 = {"lines": [Mind.say_voiced(other, "fear_gift_refusal", "Fear")], "facts": [{"kind": "refusal", "fear": true, "source": other.id, "subject": [other.id]}], "refusal_ask": "gift", "refusal_line": 0}
	var resp_fear2 = resp_fear1.duplicate(true)
	var resp_fear3 = resp_fear1.duplicate(true)
	GameConversation._repeat_refusal(other, resp_fear1)
	GameConversation._repeat_refusal(other, resp_fear2)
	GameConversation._repeat_refusal(other, resp_fear3)
	_check(resp_fear2.get("repeated", false) and not ("[PH]" in resp_fear2.lines[0].text) and not ("safer" in resp_fear2.lines[0].text.to_lower()) and resp_fear2.lines[0].text != resp_fear3.lines[0].text, "GameConversation._repeat_refusal voices alternating fear refusals without [PH] or 'safer'")


func _test_zero_ph_across_runtime_dirs() -> void:
	for root_dir in ["res://sim", "res://game", "res://workshop", "res://ui"]:
		_scan_dir_for_ph(root_dir)


func _scan_dir_for_ph(dir_path: String) -> void:
	var d = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path + "/" + entry
			if d.current_is_dir():
				_scan_dir_for_ph(full)
			elif entry.ends_with(".gd") or entry.ends_with(".cs"):
				var txt: String = FileAccess.get_file_as_string(full)
				_check(not ("[PH]" in txt), "%s contains zero [PH] markers" % full)
		entry = d.get_next()
	d.list_dir_end()

extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const Mind = preload("res://sim/mind.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const BotWorkshop = preload("res://tools/autoplay_workshop.gd")

const CAST_IDS = ["agnes", "bart", "constance", "dorian", "edda", "fenwick", "greta", "hollis", "isolde", "jory", "kiran", "lian", "merrin", "nisha", "odette"]

const SLICE5_SLOTS = {
	"trace_fit_locations": {"places": "the Bakery or the Tavern", "item": "a brass farthing"},
	"trace_fit_quarter": {"home_block": "the Square", "evening_block": "Market Lane"},
	"trace_fit_connection": {"victim": "Rowan"},
	"trace_not_me": {},
	"trace_point_haunt": {"loc": "the Tavern", "target": "Edda"},
	"trace_point_work": {"loc": "the Bakery", "target": "Edda"},
	"trace_point_quarter": {"block": "the Square", "target": "Edda"},
	"trace_point_connection": {"target": "Edda"},
	"pressed_multi_trace_case": {},
	"circumstantial_hub_landed": {"target": "Edda"},
	"circumstantial_smear_pushback": {},
}

var checks: int = 0
var fails: int = 0

func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		push_error("FAIL: " + msg)

func _game(seed_val: int = 2501, size: int = 7):
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.known_claims = {}
			m.beliefs = []
			m.ledger = {}
			m.workshop_state = {"enabled": false, "reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
	g.set_workshop_effects(true)
	return g

func _init() -> void:
	_test_all_15_voices_slice5_keys()
	_test_live_voiced_trace_and_hub_delivery()
	_test_autoplay_workshop_and_hub_builder()
	_test_bears_on_trace_no_hidden_truth_leak()
	if fails == 0:
		print("test_workshop_slice5_voices_and_bot: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_workshop_slice5_voices_and_bot: %d/%d FAILED" % [fails, checks])
		quit(1)

func _test_all_15_voices_slice5_keys() -> void:
	for key in SLICE5_SLOTS:
		var slots: Dictionary = SLICE5_SLOTS[key]
		var seen: Dictionary = {}
		for id in CAST_IDS:
			var rendered: String = Dialogue.voice_line(id, key, "FALLBACK", slots)
			_check(rendered != "FALLBACK" and rendered != "" and not "{" in rendered and not "}" in rendered and not "[PH]" in rendered, "%s/%s resolves cleanly without [PH] or leftover slots" % [id, key])
			for slot_val in slots.values():
				_check(str(slot_val) in rendered, "%s/%s preserves slot value %s" % [id, key, str(slot_val)])
			if id != "nisha":
				_check(not ("data" in rendered.to_lower()), "%s/%s keeps 'data' diction exclusive to Nisha" % [id, key])
			if key == "pressed_multi_trace_case":
				_check("frame" in rendered.to_lower(), "%s/pressed_multi_trace_case expresses frame-up denial" % id)
			seen[rendered] = true
		_check(seen.size() == CAST_IDS.size(), "all 15 cast voices have distinct lines for " + key)
		_check(Dialogue.voice_line("unvoiced_npc", key, "FALLBACK", slots) == "FALLBACK", "unvoiced fallback preserved for " + key)
	var agnes_table: Dictionary = Voices.VOICES["agnes"]
	var total_str: int = 0
	var dear_str: int = 0
	for k in agnes_table:
		if agnes_table[k] is String:
			total_str += 1
			var low: String = String(agnes_table[k]).to_lower()
			if "dear" in low or "love" in low:
				dear_str += 1
	_check(total_str > 0 and float(dear_str) / float(total_str) <= 0.30, "Agnes endearment ratio remains restrained (<= 30%%)")

func _test_live_voiced_trace_and_hub_delivery() -> void:
	var g = _game(2502, 7)
	var listener = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var silenced_p = g.w.living_good()[2]
	var victim = g.w.living_good()[3]
	g.w.day = 1
	g.w.phase = C.EVENING
	listener.work = "bakery"
	listener.haunts = ["mill", "well"]
	listener.trust = 0.85
	listener.traits["gossip"] = 0.9
	target.work = "bakery"
	target.haunts = ["tavern", "graveyard"]
	var trace_card = {
		"n": 1, "kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing",
		"text": "Scene trace: brass farthing (the Bakery or the Tavern).",
	}
	var bare: Dictionary = Mind.react_to_trace(g.w, listener, trace_card, {}, true)
	_check(not bare.lines.is_empty() and not "[PH]" in bare.lines[0].text and bare.lines[0].has("statement"), "live react_to_trace uses character voice without [PH] and preserves canonical statement")
	var pressed: Dictionary = Mind.press(g.w, listener, trace_card)
	var p_speeches: Array = pressed.lines.filter(func(l): return l is Dictionary)
	_check(not p_speeches.is_empty() and not "[PH]" in p_speeches[0].text and p_speeches[0].has("statement"), "pressing with a trace card wraps voiced response cleanly and retains canonical statement")

	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [silenced_p.id], "town")
	var death_num: int = g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	var sil_num: int = g.add_card({"kind": "silenced", "source": "player", "subject": [silenced_p.id], "day": 1, "phase": C.EVENING, "text": "Silenced"})
	var conv_num: int = g.add_card({"kind": "conversation", "source": "player", "subject": [target.id, silenced_p.id], "block": "market", "loc": "bakery", "day": 1, "phase": C.MORNING, "text": "Talking before silence"})
	var tr_num: int = g.add_card(trace_card)
	var view: Dictionary = WorkshopCanvas.view(g)
	var board = CanvasModel.new(view)
	var root_id: String = board.selected
	board.nodes[root_id].conclusion = {"type": "evil", "target": target.id, "at": view.alignment_epoch}
	var hub_id: String = board.add_circumstantial_hub()
	for num in [death_num, tr_num, sil_num, conv_num]:
		board.connect_cards("e:" + WorkshopCanvas.Evidence.normalize_card(g.board[num - 1]).id, hub_id)
	var pnode: String = board.add_profile_info(target.id, ["home_work"])
	board.connect_cards(pnode, hub_id)
	board.connect_cards(hub_id, root_id)
	var filed_ok: int = WorkshopCanvas.file(g, board.compile(root_id))
	var pres_ok: Dictionary = g._evaluate_deduction(listener, g.board[filed_ok - 1], 1.0, true)
	var expected_hub_line: String = Dialogue.voice_line(listener.id, "circumstantial_hub_landed", "", {"target": target.name})
	_check(not pres_ok.lines.is_empty() and expected_hub_line in pres_ok.lines[0].text and not "[PH]" in pres_ok.lines[0].text, "grounded Circumstantial Hub presentation speaks listener's bespoke voice line without [PH]")

func _test_autoplay_workshop_and_hub_builder() -> void:
	var g = _game(2503, 7)
	var suspect = g.w.living_good()[0]
	var silenced_p = g.w.living_good()[1]
	var victim = g.w.living_good()[2]
	var cleared_other = g.w.living_good()[3]
	g.w.day = 2
	g.w.phase = C.EVENING
	suspect.work = "bakery"
	suspect.haunts = ["tavern", "mill"]
	cleared_other.work = "chapel"
	cleared_other.haunts = ["well", "graveyard"]
	g.add_profile_receipt({"kind": "haunt", "subject": [cleared_other.id], "loc": "well", "locs": ["well"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 1"})
	g.add_profile_receipt({"kind": "haunt", "subject": [cleared_other.id], "loc": "graveyard", "locs": ["graveyard"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 2"})
	g.w.public_event("demon_death", [victim.id], "town")
	g.w.public_event("silenced", [silenced_p.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "block": victim.home_block, "text": "Public death"})
	g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing",
		"text": "Scene trace: brass farthing (the Bakery or the Tavern).",
	})
	g.add_card({"kind": "sighting", "source": "player", "subject": [suspect.id], "block": victim.home_block, "day": 1, "phase": C.NIGHT, "text": "Player vigil sighting"})
	g.add_card({"kind": "silenced", "source": "player", "subject": [silenced_p.id], "day": 2, "phase": C.EVENING, "text": "Silenced"})
	g.add_card({"kind": "conversation", "source": "player", "subject": [suspect.id, silenced_p.id], "block": "market", "loc": "bakery", "day": 2, "phase": C.MORNING, "text": "Talking before silence"})

	var sc: Dictionary = {}
	for p in g.w.npcs:
		sc[p.id] = 0.0
	sc[suspect.id] = 0.55
	BotWorkshop.apply_trace_and_profile_scores(g, sc)
	_check(sc[suspect.id] > 0.80 and sc[cleared_other.id] < 0.0, "BotWorkshop.apply_trace_and_profile_scores boosts matching suspect and discounts trace-contradicted townsfolk")

	# Stage-1-only mode (--no-hub): files valid Workshop case without Circumstantial Hub
	var sigs_s1: Dictionary = {}
	var last_s1: Dictionary = {}
	var built_s1: Dictionary = BotWorkshop.build_and_file_case(g, sc, false, sigs_s1, last_s1)
	_check(int(built_s1.card) > 0 and not built_s1.used_hub and g.board[int(built_s1.card) - 1].get("workshop_case", {}).get("circumstantial", []).is_empty(), "BotWorkshop builds clean Stage-1-only Workshop case when include_hub is false")

	# Also add a public failed vote where suspect voted yes to hang cleared_other so adapted vote cards are tested too
	g.w.public_event("vote", [cleared_other.id], "town", {"nominee": cleared_other.id, "nominator": suspect.id, "yes": [suspect.id], "no": [silenced_p.id], "player_yes": false, "count": 1, "threshold": 4, "outcome": "fails"})
	var vote_num: int = g.add_card({"kind": "vote", "source": "player", "subject": [suspect.id, cleared_other.id], "day": 2, "phase": C.EVENING, "nominee": cleared_other.id, "by": suspect.id, "yes": [suspect.id], "no": [silenced_p.id], "player_yes": false, "count": 1, "threshold": 4, "outcome": "fails", "text": "Vote tally"})

	# Full mode (with Hub): files valid Workshop case attaching adapted silenced + conversation + vote cards in hub
	var sigs_full: Dictionary = {}
	var last_full: Dictionary = {}
	var built_full: Dictionary = BotWorkshop.build_and_file_case(g, sc, true, sigs_full, last_full)
	var full_hubs: Array = g.board[int(built_full.card) - 1].get("workshop_case", {}).get("circumstantial", []) if int(built_full.card) > 0 else []
	_check(int(built_full.card) > 0 and built_full.used_hub and not full_hubs.is_empty(), "BotWorkshop attaches verified Circumstantial Evidence Hub when Stage 1 grounding and Stage 2 incidents align")
	if not full_hubs.is_empty():
		var hub_cards: Array = full_hubs[0].get("cards", [])
		var vote_cid: String = WorkshopCanvas.Evidence.normalize_card(g.board[vote_num - 1]).id
		_check(hub_cards.size() >= 3 and vote_cid in hub_cards, "BotWorkshop.select_circumstantial_cards selects adapted silenced, conversation, and vote cards via view.timeline.events")

func _test_bears_on_trace_no_hidden_truth_leak() -> void:
	var g = _game(2504, 7)
	var secret_match = g.w.living_good()[0]
	var secret_miss = g.w.living_good()[1]
	var victim = g.w.living_good()[2]
	# Both suspects work at the Chapel (outside trace); secret_match secretly haunts the Bakery, secret_miss does not.
	secret_match.work = "chapel"
	secret_match.haunts = ["bakery", "mill"]
	secret_miss.work = "chapel"
	secret_miss.haunts = ["well", "graveyard"]
	# Sync initial work profile receipts to Chapel for both so player holds identical discovered receipts for both.
	for pr in g.profile_receipts:
		if pr.get("kind", "") == "work" and (secret_match.id in pr.get("subject", []) or secret_miss.id in pr.get("subject", [])):
			pr["loc"] = "chapel"
			pr["block"] = C.LOCATIONS["chapel"]["block"]
	var tnum: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing",
		"text": "Scene trace: brass farthing (the Bakery or the Tavern).",
	})
	var pool_before: Array = g.all_receipts()
	_check(g.Argue.trace_fit_from_receipts(secret_match.id, g.board[tnum - 1], pool_before) == "unknown" and g.Argue.trace_fit_from_receipts(secret_miss.id, g.board[tnum - 1], pool_before) == "unknown", "undiscovered haunts stay in unknown state for both secret-match and secret-miss suspects")
	var d_match: int = g.file_deduction({"type": "demon", "a": secret_match.id}, [tnum])
	var d_miss: int = g.file_deduction({"type": "demon", "a": secret_miss.id}, [tnum])
	_check(d_match > 0 and d_miss > 0 and g.board[d_match - 1]["unfounded"] == g.board[d_miss - 1]["unfounded"] and not g.board[d_miss - 1]["unfounded"], "filing conclude <suspect> because <trace> never leaks undiscovered haunts via unfounded flag")

	# Once both non-matching haunts of secret_miss are learned, relevance flips to contradicts (unfounded = true).
	g.add_profile_receipt({"kind": "haunt", "subject": [secret_miss.id], "loc": "well", "locs": ["well"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 1"})
	g.add_profile_receipt({"kind": "haunt", "subject": [secret_miss.id], "loc": "graveyard", "locs": ["graveyard"], "source": "town", "day": 1, "phase": 0, "text": "Haunt 2"})
	_check(g.Argue.trace_fit_from_receipts(secret_miss.id, g.board[tnum - 1], g.all_receipts()) == "contradicts", "learning all contradicting work + haunts resolves trace_fit_from_receipts to contradicts")
	var d_ruled_out: int = g.file_deduction({"type": "evil", "a": secret_miss.id}, [tnum])
	_check(d_ruled_out > 0 and g.board[d_ruled_out - 1]["unfounded"], "deduction from trace becomes unfounded once discovered profile receipts rule out all prongs")

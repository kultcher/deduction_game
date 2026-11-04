## Verification suite for Chunk 1 Buildings:
##   1. Evening-only Tavern Gossip rework (phase gating, post-evening chat harvest,
##      3-5 items, two-tier source anonymization, unheard priority & haunt/bond profile
##      backfill, Secret Lovers exclusion, non-pressable/non-Workshop card boundaries,
##      attributed sighting non-collision, and dotted timeline markers).
##   2. Town Hall player-only building (Morning/Afternoon gating, 3-per-case cap,
##      6 unique roles, case-start good role persistence across death/curse, evil bluff
##      eligibility, blank-square map layout, Workshop in_play_role toggle, FactoredChannels
##      vs ChannelLikelihood oracle agreement, and GDScript vs C# --tol 0 parity).
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const CardModel = preload("res://game/card_model.gd")
const Social = preload("res://sim/social.gd")
const Caches = preload("res://workshop/caches.gd")
const Solver = preload("res://workshop/solver.gd")
const Roles = preload("res://workshop/role_constraints.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const Oracle = preload("res://workshop/channel_likelihood.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const LiveAssessment = preload("res://workshop/live_assessment.gd")
const MapView = preload("res://ui/map_view.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_location_isolation_and_map_rect()
	_test_tavern_gossip_rework()
	_test_town_hall_building_and_limits()
	_test_town_hall_workshop_and_csharp_parity()
	print("Buildings (Tavern & Town Hall) Suite: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_location_isolation_and_map_rect() -> void:
	_check(C.LOCATIONS.size() == 8 and not C.LOCATIONS.has("town_hall"),
		"C.LOCATIONS retains exact 8 NPC town locations without town_hall")
	_check(C.is_player_building("town_hall") and C.loc_block("town_hall") == "square" and C.loc_name("town_hall") == "the Town Hall",
		"town_hall registered as player-only building on the Square")

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var no_npc_refs: bool = g.w.npcs.all(func(n): return n.work != "town_hall" and not ("town_hall" in n.haunts) and n.loc != "town_hall")
	_check(no_npc_refs, "no NPC works at, haunts, or idles at town_hall")
	_check(g.find_location("town_hall") == "town_hall" and g.find_location("town hall") == "town_hall" and g.find_location("hall") == "town_hall",
		"Game.find_location resolves town_hall aliases")

	var mv = MapView.new()
	mv.g = g
	var sq_rect: Rect2 = MapView.BLOCK_RECTS["square"]
	var r_tav: Rect2 = mv._loc_rect("tavern")
	var r_well: Rect2 = mv._loc_rect("well")
	var r_th: Rect2 = mv._loc_rect("town_hall")
	_check(sq_rect.encloses(r_tav) and sq_rect.encloses(r_well) and sq_rect.encloses(r_th) and not r_tav.intersects(r_well) and not r_well.intersects(r_th),
		"Square map layout fits Tavern, Well, and Town Hall blank square cleanly without overlap")
	mv.free()


func _test_tavern_gossip_rework() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(900, 10)
	if g.state == "approach":
		g.command("decline")

	# Morning & Afternoon gating: must reject without spending phase.
	g.command("go tavern")
	var morning_res: String = g.command("gossip")
	_check(g.w.phase == C.MORNING and g.state == "day" and "evening" in morning_res.to_lower(),
		"Tavern gossip rejected in Morning without spending the phase")
	g.command("wait")
	if g.state == "approach":
		g.command("decline")

	g.command("go tavern")
	var aft_res: String = g.command("gossip")
	_check(g.w.phase == C.AFTERNOON and g.state == "day" and "evening" in aft_res.to_lower(),
		"Tavern gossip rejected in Afternoon without spending the phase")
	g.command("wait")
	if g.state == "approach":
		g.command("decline")

	# Evening setup: put ALL cast NPCs at home so Tavern is physically empty of cast NPCs,
	# and seed controlled NPC-to-NPC shares across different phases and locations.
	for n in g.w.living():
		n.loc = "home"
		n.working = false
		n.busy_with = ""

	var goods: Array = g.w.living_good()
	var speaker_seer = goods[0]
	var listener_b = goods[1]
	var target_c = goods[2]
	var target_d = goods[3]
	var evil_one = g.w.evil_team()[0]

	g.w.daily_npc_shares.clear()
	# 1) Good reading share (must scrub speaker_seer's name, keep target_c & target_d).
	var seer_entry: Dictionary = {
		"role": "seer", "day": 1,
		"data": {"pair": [target_c.id, target_d.id], "yes": false},
		"text": "I looked at %s and %s: neither is the demon" % [target_c.name, target_d.name],
	}
	Social._deliver(g.w, speaker_seer, listener_b, {"kind": "reading", "entry": seer_entry, "from": speaker_seer.id, "key": "reading:1:seer"})
	# 2) Evil frame night sighting (allowed into gossip, scrubs evil_one's name, keeps target_c).
	Social._deliver(g.w, evil_one, listener_b, {"kind": "sighting", "about": target_c.id, "block": "docks", "day": 0, "from": evil_one.id, "key": "sighting:%s:0" % target_c.id, "lie": true})
	# 3) Opinion share (must be excluded!).
	Social._deliver(g.w, listener_b, target_d, {"kind": "opinion", "about": evil_one.id, "why": "gut feeling", "from": listener_b.id, "key": "opinion:" + evil_one.id})

	g.known_haunts.clear()
	g.known_relationships.clear()

	g.command("go tavern")
	var eve_res: String = g.command("gossip")
	_check(g.state == "meeting", "Evening tavern gossip consumes the evening phase and advances to the town meeting")

	var bullets: Array = []
	for ln in eve_res.split("\n"):
		if "• " in ln:
			bullets.append(ln)
	_check(bullets.size() >= 3 and bullets.size() <= 5,
		"Evening tavern gossip yields 3 to 5 items (got %d)" % bullets.size())
	_check(not bullets.any(func(b): return speaker_seer.name in b and "seer reading" in b.to_lower()),
		"Reading gossip hides direct source identity")
	_check(not bullets.any(func(b): return "distrust" in b.to_lower() or "uneasy" in b.to_lower()),
		"Opinion-only chatter never enters Evening tavern gossip")

	var rumour_cards: Array = g.board.filter(func(c): return c.get("tavern_gossip", false))
	_check(not rumour_cards.is_empty() and rumour_cards.all(func(c): return c.get("source", "") == "rumour" and not c.get("workshop_usable", true) and not c.get("pressable", true)),
		"Tavern gossip board cards carry source=rumour, workshop_usable=false, pressable=false")

	# Dotted timeline marker & attributed non-collision check:
	var sight_rumours: Array = rumour_cards.filter(func(c): return c.get("kind", "") == "sighting")
	if not sight_rumours.is_empty():
		var rc: Dictionary = sight_rumours[0]
		var markers: Array = CardModel.place_markers(rc)
		_check(not markers.is_empty() and markers[0]["mark"] == "dotted",
			"Tavern rumour sighting renders 'dotted' outline marker on Places & sightings timeline")
		var tl_txt: String = g._timeline("")
		_check("?" in tl_txt, "CLI timeline marks tavern rumours with '?'")

		# Now add an attributed witness sighting of the exact same event: must NOT merge into the rumour card!
		var board_before: int = g.board.size()
		g._facts([{
			"kind": "sighting", "subject": [target_c.id], "block": "docks", "day": 0, "phase": C.NIGHT,
			"source": listener_b.id,
			"text": "%s saw %s out on the Docks on the night before you arrived." % [listener_b.name, target_c.name],
		}])
		_check(g.board.size() == board_before + 1 and g.board[-1].get("source", "") == listener_b.id and g.board[-1].get("workshop_usable", true),
			"Later attributed witness sighting creates a separate Workshop-usable card without colliding with tavern rumour")

	# Case builder, Workshop, and pressing rejection checks:
	var r_num: int = int(rumour_cards[0]["n"])
	var ded_try: int = g.file_deduction({"type": "suspicious", "a": target_c.id}, [r_num])
	_check(ded_try == -1 and "tavern rumour" in g.last_error.to_lower(),
		"Case builder refuses deductions resting on tavern rumour cards")

	var wc_view: Dictionary = WorkshopCanvas.view(g)
	_check(not wc_view.cards.any(func(c): return c.get("source", "") == "rumour"),
		"WorkshopCanvas.view excludes tavern rumour cards")

	var snap: Dictionary = g.workshop_snapshot([r_num], listener_b.id, "private")
	var prep: Dictionary = LiveAssessment.prepare(snap)
	_check(not prep.ready and prep.issues.any(func(iss): return "Tavern rumours" in str(iss)),
		"LiveAssessment.prepare rejects direct tavern rumour snapshots")

	var press_reply: Dictionary = g.Mind.press(g.w, target_c, rumour_cards[0], g.known_haunts)
	_check(press_reply["facts"].is_empty() and "unattributed" in str(press_reply["lines"][0]).to_lower(),
		"Mind.press rejects tavern rumour cards")

	# Quiet-day profile backfill check (0 spoken shares -> 3-5 haunts/public bonds, never Secret Lovers):
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(42, 7)
	g2.w.phase = C.EVENING
	g2.w.daily_npc_shares.clear()
	g2.w._evening_chats_done_day = g2.w.day # freeze evening chats empty so 100% comes from backfill
	g2.moved = true
	g2.loc = "tavern"
	g2.command("gossip")
	var learned_profile_count: int = 0
	for k in g2.known_haunts:
		learned_profile_count += g2.known_haunts[k].size()
	learned_profile_count += g2.known_relationships.size()
	_check(learned_profile_count >= 3 and learned_profile_count <= 5 and g2.board.filter(func(c): return c.get("tavern_gossip", false)).is_empty(),
		"Quiet day with 0 spoken shares backfills 3 to 5 profile haunts/bonds without adding board cards (got %d)" % learned_profile_count)


func _test_town_hall_building_and_limits() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	if g.state == "approach":
		g.command("decline")

	# Simulate death & Revenant conversion of an initial good townsfolk BEFORE consulting Town Hall:
	var dead_good = g.w.living_good()[0]
	dead_good.alive = false
	dead_good.death_cause = "demon"
	var cursed_good = g.w.living_good()[0]
	g.w.turn_evil(cursed_good, "test: Revenant curse")  # the real conversion (bluff, shadow, turned flag)

	var seen_roles: Dictionary = {}
	for visit in range(3):
		if g.state == "approach":
			g.command("decline")
		if g.w.phase == C.EVENING:
			# Verify Evening rejection on Town Hall before advancing to next Morning!
			g.command("go town_hall")
			var eve_err: String = g.command("records")
			_check(g.w.phase == C.EVENING and "morning and afternoon" in eve_err.to_lower(),
				"Town Hall rejects consultation in the Evening without spending phase or uses")
			g.command("wait")
			while g.state in ["meeting", "nomination"]:
				g.command("done" if g.town_quiet else ("vote no" if g.state == "nomination" else "wait"))
			if g.state == "night":
				g.command("sleep")
			if g.state == "approach":
				g.command("decline")
		g.command("go town_hall")
		var out: String = g.command("records")
		_check("Town Hall" in out, "Town Hall consultation #%d succeeds in Morning/Afternoon" % (visit + 1))

	var th_cards: Array = g.board.filter(func(c): return c.get("kind", "") == "town_hall")
	_check(th_cards.size() == 3 and g.w.town_hall_uses_left == 0,
		"Town Hall mints 3 concrete board cards and reaches 0 remaining uses")

	var exact_one_each: bool = true
	for tc in th_cards:
		var rs: Array = tc.get("roles", [])
		if rs.size() != 2:
			exact_one_each = false
			break
		var in_cnt: int = (1 if rs[0] in g.w.initial_good_roles else 0) + (1 if rs[1] in g.w.initial_good_roles else 0)
		if in_cnt != 1 or not rs.all(func(r): return r in C.GOOD_ROLES):
			exact_one_each = false
		seen_roles[rs[0]] = true
		seen_roles[rs[1]] = true
	_check(exact_one_each and seen_roles.size() == 6,
		"All 3 Town Hall pairs contain 6 unique good roles with exactly 1 case-start in-play role per pair")

	# 4th attempt in Afternoon must fail without spending phase:
	if g.state == "approach":
		g.command("decline")
	if g.w.phase == C.EVENING:
		g.command("wait")
		while g.state in ["meeting", "nomination"]:
			g.command("done" if g.town_quiet else ("vote no" if g.state == "nomination" else "wait"))
		if g.state == "night":
			g.command("sleep")
		if g.state == "approach":
			g.command("decline")
	g.command("go town_hall")
	var fourth: String = g.command("records")
	_check("already consulted" in fourth.to_lower() and g.state == "day",
		"4th Town Hall consultation is refused without spending the phase")


func _test_town_hall_workshop_and_csharp_parity() -> void:
	Caches.clear_all()
	var has_cs: bool = SolverBackend.is_csharp_available()

	# Build a 7-NPC live view (5 good, 2 evil) to test:
	#   (A) Double-claim clash: p0 claims seer, p1 claims clerk, Town Hall says [seer, clerk].
	#   (B) Good-slot saturation: p2..p6 claim 5 other good roles while Town Hall says [seer, clerk].
	#   (C) Optional in_play_role answer toggle & CaseEval._theory_fit + FactoredChannels vs Oracle parity.
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var p0: String = people[0].id
	var p1: String = people[1].id

	var c_th: Dictionary = {"id": "th_1", "fact_id": "th_1", "kind": "town_hall", "source": "player",
		"data": {"roles": ["seer", "clerk"]}, "observed_at": {"day": 1, "phase": "morning"}, "text": "Town Hall: Seer or Clerk."}
	var c_p0: Dictionary = {"id": "cl_0", "fact_id": "cl_0", "kind": "claim", "source": p0, "subject": p0,
		"role": "seer", "data": {}, "observed_at": {"day": 1, "phase": "evening"}, "text": p0 + " claims Seer."}
	var c_p1: Dictionary = {"id": "cl_1", "fact_id": "cl_1", "kind": "claim", "source": p1, "subject": p1,
		"role": "clerk", "data": {}, "observed_at": {"day": 1, "phase": "evening"}, "text": p1 + " claims Clerk."}

	var view: Dictionary = {
		"seed": 101, "day": 1, "people": people, "cards": [c_th, c_p0, c_p1],
		"evil_count": 2, "alignment_epoch": "Original alignment", "history": [],
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
		"timeline": {"events": []},
	}

	SolverBackend.set_mode(SolverBackend.Mode.VERIFY if has_cs else SolverBackend.Mode.GDSCRIPT)
	var solved_clash: Dictionary = Solver.solve(view, [c_th, c_p0, c_p1])
	# The hard solve takes every selected card as true (claims included), so a Town Hall
	# pair plus true claims of both roles is a contradiction; the claims alone are not.
	var solved_claims_only: Dictionary = Solver.solve(view, [c_p0, c_p1])
	_check(solved_clash.worlds.is_empty() and not solved_claims_only.worlds.is_empty(),
		"Town Hall [Seer, Clerk] + true claims of both roles is impossible in the hard solve (claims alone: %d worlds)" % solved_claims_only.worlds.size())

	# Check optional in_play_role answer narrowing:
	# Picking which role is in play: "seer" puts the Clerk out of play, so a true Clerk claim
	# can't stand; picking "clerk" is consistent with it.
	var solved_pick_seer: Dictionary = Solver.solve(view, [c_th, c_p1], {}, {"th_1": {"positive": [], "in_play_role": "seer"}})
	var solved_pick_clerk: Dictionary = Solver.solve(view, [c_th, c_p1], {}, {"th_1": {"positive": [], "in_play_role": "clerk"}})
	_check(solved_pick_seer.worlds.is_empty() and not solved_pick_clerk.worlds.is_empty(),
		"Selecting in_play_role='seer' on a Town Hall card rules out a true Clerk claim; 'clerk' keeps it")

	# Check CaseEval posterior shift & theory_fit:
	var case_d: Dictionary = Solver.empty_case()
	case_d.cards = ["th_1", "cl_0", "cl_1"]
	case_d.answers = {"th_1": {"positive": [], "in_play_role": "seer"}}
	case_d.conclusion = {"type": "evil", "target": p1, "at": "Original alignment"}
	var ev_res: Dictionary = CaseEval.evaluate(view, case_d)
	# Chosen answers are scored in _theory_fit rather than conditioned into post; both
	# roles remain possible in post (either claimant can bluff), so 0 < theory_fit < 1.
	_check(ev_res.posterior > ev_res.prior and ev_res.theory_fit > 0.0 and ev_res.theory_fit < 1.0,
		"CaseEval raises suspicion on rival claimant (%.3f -> %.3f) and computes Town Hall theory_fit (%.3f)" % [
			ev_res.prior, ev_res.posterior, ev_res.theory_fit])

	# Check 5-good slot saturation + FactoredChannels vs exhaustive ChannelLikelihood oracle:
	var other_roles: Array = ["dowser", "warden", "nightwatch", "lamplighter", "medium"]
	var sat_cards: Array = [c_th]
	var rates: Dictionary = {}
	for j in range(5):
		var pj: String = people[2 + j].id
		sat_cards.append({"id": "sat_%d" % j, "fact_id": "sat_%d" % j, "kind": "claim", "source": pj, "subject": pj,
			"role": other_roles[j], "data": {}, "observed_at": {"day": 1, "phase": "evening"}, "text": pj + " claims " + other_roles[j]})
		rates["gift_honesty:" + pj] = 0.8
	var view_sat: Dictionary = view.duplicate(true)
	view_sat.cards = sat_cards
	var solved_sat: Dictionary = Solver.solve(view_sat, sat_cards)
	var all_five_good: bool = solved_sat.worlds.any(func(w): return (int(w.evil) & 0b1111100) == 0)
	_check(not all_five_good,
		"5 good claims disjoint from Town Hall [Seer, Clerk] cannot all be good in a 5-good town")

	var fac: Dictionary = Factored.assess(view_sat, sat_cards, {}, rates, {})
	var ora: Dictionary = Oracle.assess(view_sat, sat_cards, {}, rates, {})
	var max_diff: float = 0.0
	for idx in range(fac.post.size()):
		max_diff = maxf(max_diff, absf(fac.post[idx] - ora.post[idx]))
	_check(max_diff <= 1e-12,
		"FactoredChannels matches exhaustive ChannelLikelihood oracle on Town Hall slot saturation (max diff %.3g)" % max_diff)

	if has_cs:
		_check(SolverBackend.get_verify_mismatches() == 0,
			"GDScript vs C# VERIFY mode recorded 0 mismatches across all Town Hall solver checks")

	# Check CanvasModel.apply_answer toggle round-trip:
	var cm = CanvasModel.new(view)
	var a1: Dictionary = cm.apply_answer(c_th, {}, "th_role", "seer")
	var a2: Dictionary = cm.apply_answer(c_th, a1, "th_role", "clerk")
	var a3: Dictionary = cm.apply_answer(c_th, a2, "th_role", "clerk")
	_check(a1.get("in_play_role", "") == "seer" and a2.get("in_play_role", "") == "clerk" and not a3.has("in_play_role") and a1.get("positive", []) == [],
		"CanvasModel.apply_answer toggles Town Hall in_play_role cleanly")

	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)

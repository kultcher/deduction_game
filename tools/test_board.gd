## Tests for the case-board card model, board layout, shared filter state and theme.
##   godot --headless --path . --script res://tools/test_board.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")
const BoardModel = preload("res://game/board_model.gd")
const CaseState = preload("res://ui/case_state.gd")
const UITheme = preload("res://ui/theme.gd")

var fails = 0

func _init() -> void:
	_test_canonical_time()
	_test_merge_disclosures()
	_test_views_and_markers()
	_test_layout_rows()
	_test_layout_real_game()
	_test_state_filters()
	_test_theme_fallback()
	print("FAILURES: %d" % fails)
	quit()

func _game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd)
	return g

func _ctx(g, rows_by: String = "place") -> Dictionary:
	return {"day": g.w.day, "phase": g._phase_now(), "rows_by": rows_by,
		"people": g.w.npcs.map(func(n): return {"id": n.id, "name": n.name, "alive": n.alive}), "blocks": C.BLOCKS.keys()}

## A reading about night 1, heard on day 3, sits at N1; a claim sits where it was said.
func _test_canonical_time() -> void:
	var g = _game(8101)
	var w = g.w
	var a = w.npcs[0]
	var b = w.npcs[1]
	w.day = 3
	w.phase = C.AFTERNOON
	var n1 = g.add_card({"kind": "info", "role": "seer", "day": 1, "source": a.id, "data": {"pair": [b.id, a.id], "yes": true}, "text": "seer n1"})
	var n2 = g.add_card({"kind": "claim", "subject": [a.id], "role": "seer", "source": a.id, "text": "claim"})
	var n3 = g.add_card({"kind": "death", "subject": [b.id], "night": 2, "source": "player", "text": "death"})
	var c1: Dictionary = g.board[n1 - 1]
	var c2: Dictionary = g.board[n2 - 1]
	var c3: Dictionary = g.board[n3 - 1]
	print("reading when %s learned %s; claim when %s; death when %s" % [CardModel.time_label(c1["when"]), c1["learned"][0], CardModel.time_label(c2["when"]), CardModel.time_label(c3["when"])])
	_check(c1["when"] == {"day": 1, "phase": C.NIGHT} and c1["learned"][0]["day"] == 3, "a reading sits at the night it's about, and remembers when you heard it")
	_check(c2["when"] == {"day": 3, "phase": C.AFTERNOON}, "a claim sits where it was said")
	_check(c3["when"] == {"day": 2, "phase": C.NIGHT}, "a death sits at its night")

## Told privately, then announced at the meeting: one card, two disclosures.
func _test_merge_disclosures() -> void:
	var g = _game(8102)
	var w = g.w
	var a = w.npcs[0]
	var b = w.npcs[1]
	w.day = 1
	w.phase = C.MORNING
	var n1 = g.add_card({"kind": "claim", "subject": [a.id], "role": "seer", "source": a.id, "text": "%s tells you they're the Seer." % a.name})
	w.day = 2
	w.phase = C.AFTERNOON
	var n2 = g.add_card({"kind": "claim", "subject": [a.id], "role": "seer", "source": a.id, "via": b.id, "private": true, "text": "Via %s: %s privately claims to be the Seer." % [b.name, a.name]})
	w.phase = C.EVENING
	g.state = "meeting"
	var n3 = g.add_card({"kind": "claim", "subject": [a.id], "role": "seer", "source": a.id, "text": "%s publicly claims to be the Seer." % a.name})
	g.state = "day"
	var n4 = g.add_card({"kind": "claim", "subject": [a.id], "role": "warden", "source": a.id, "text": "%s claims Warden." % a.name})
	var ls: Array = g.board[n1 - 1]["learned"]
	print("cards %d %d %d %d; disclosures: %s" % [n1, n2, n3, n4, ls])
	_check(n1 == n2 and n2 == n3, "the same claim heard three ways is one card")
	_check(ls.size() == 3 and ls[1]["via"] == b.id and ls[2]["public"] and not ls[0]["public"], "each disclosure is recorded: private, relayed, public")
	_check(n4 != n1, "a different claim is its own card")

func _test_views_and_markers() -> void:
	var a = "x"
	var watch = {"kind": "info", "role": "nightwatch", "source": a, "day": 1, "data": {"block": "docks", "seen": ["p", "q"]}, "text": "w"}
	var saw = {"kind": "sighting", "subject": ["p"], "block": "square", "day": 1, "phase": C.MORNING, "source": "player", "text": "s"}
	var heard = {"kind": "sighting", "subject": ["p"], "block": "hill", "day": 1, "phase": C.NIGHT, "source": "q", "text": "h"}
	_check(CardModel.view_of(watch) == "statements" and CardModel.view_of(saw) == "places", "Night Watch reports are statements; sightings are places")
	var mw: Array = CardModel.place_markers(watch)
	_check(mw.size() == 2 and mw[0]["mark"] == "ability" and mw[0]["block"] == "docks", "a Night Watch report also places who passed (ability markers)")
	_check(CardModel.place_markers(saw)[0]["mark"] == "solid" and CardModel.place_markers(heard)[0]["mark"] == "hollow", "your sightings are solid, reported ones hollow")
	_check(CardModel.view_of({"kind": "vote"}) == "process" and CardModel.view_of({"kind": "deduction"}) == "theory", "votes are process; deductions are theories")

## Statements rows are the people a card is about; Process puts a vote on the nominee and
## each yes voter.
func _test_layout_rows() -> void:
	var g = _game(8103)
	var w = g.w
	w.day = 2
	w.phase = C.EVENING
	var ids: Array = w.npcs.map(func(n): return n.id)
	var seer = g.add_card({"kind": "info", "role": "seer", "day": 1, "source": ids[0], "data": {"pair": [ids[1], ids[2]], "yes": true}, "text": "seer"})
	var vote = g.add_card({"kind": "vote", "subject": [ids[3], ids[4], ids[1]], "nominee": ids[1], "by": ids[2], "yes": [ids[3], ids[4]], "day": 2, "phase": C.EVENING, "outcome": "on_block", "source": "player", "text": "vote"})
	var st: Dictionary = BoardModel.layout(g.board, "statements", _ctx(g))
	var rows_seer: Array = st["items"].filter(func(it): return it["card"] == seer).map(func(it): return it["row"])
	print("Seer reading rows: %s at %s" % [rows_seer, st["items"].filter(func(it): return it["card"] == seer).map(func(it): return it["col"])])
	_check(rows_seer.size() == 2 and ids[1] in rows_seer and ids[2] in rows_seer and not (ids[0] in rows_seer), "a reading shows on the rows of the people it names, not the speaker's")
	var pr: Dictionary = BoardModel.layout(g.board, "process", _ctx(g))
	var marks = {}
	for it in pr["items"]:
		if it["card"] == vote:
			marks[it["row"]] = it["mark"]
	print("vote marks: %s" % marks)
	_check(marks.get(ids[1], "") == "nominated" and marks.get(ids[3], "") == "voted_yes" and marks.get(ids[4], "") == "voted_yes", "a vote marks the nominee and each yes voter")
	_check(st["cols"][0]["label"] == "N0" and st["cols"][-1]["label"] == "D2E", "columns run from night 0 to now")

## Play a few phases and check every board view lays out without stray items.
func _test_layout_real_game() -> void:
	var g = _game(8104)
	for cmd in ["go tavern", "talk %s" % g.w.npcs[0].id, "ask night", "ask today", "ask gift", "go well", "wait", "go tavern", "wait", "wait", "done", "vigil square", "go tavern", "wait"]:
		g.command(cmd)
	var bad = 0
	var counts = {}
	for v in ["places", "statements", "process"]:
		for rb in ["place", "person"]:
			var lay: Dictionary = BoardModel.layout(g.board, v, _ctx(g, rb))
			counts["%s/%s" % [v, rb]] = lay["items"].size()
			var cols = {}
			for c in lay["cols"]:
				cols[c["key"]] = true
			var rows = {}
			for r in lay["rows"]:
				rows[r["id"]] = true
			for it in lay["items"]:
				if not cols.has(it["col"]) or not rows.has(it["row"]):
					bad += 1
	print("board items per view: %s (%d cards)" % [counts, g.board.size()])
	_check(bad == 0, "every item sits on a real row and column")
	_check(counts["places/place"] > 0 and counts["statements/person"] > 0, "a played game fills Places and Statements")

func _test_state_filters() -> void:
	var g = _game(8105)
	for cmd in ["go tavern", "talk %s" % g.w.npcs[0].id, "ask night", "ask today", "go well", "wait", "go tavern", "wait"]:
		g.command(cmd)
	var st = CaseState.new()
	var all_n: int = st.apply(g).size()
	st.set_view("statements")
	var stmt_n: int = st.apply(g).size()
	st.set_view("places")
	st.kinds["sighting"] = true
	st.set_view("statements")
	_check(not st.kinds.has("sighting"), "switching view drops kinds that don't exist there")
	st.set_view("places")
	var places_n: int = st.apply(g).size()
	st.text = "zzzz-nothing"
	st.edited()
	var txt: String = st.status_text(g, st.apply(g).size())
	print("status: %s" % txt)
	_check("Nothing matches your filters" in txt and "Text:" in txt, "an empty view under filters says so, and names the filters")
	_check(st.chips(g).size() == 1, "each active filter is a chip")
	st.remove_chip("text", "")
	_check(st.apply(g).size() == places_n and places_n > 0, "removing the chip restores the view")
	st.set_cell("k1", "Agnes · D1M", [1])
	_check(st.apply(g).size() <= 1 and not st.cell.is_empty(), "a timeline cell narrows the list")
	st.set_cell("k1", "Agnes · D1M", [1])
	_check(st.cell.is_empty(), "clicking the same cell again clears it")
	st.set_cell("k1", "Agnes · D1M", [1])
	st.toggle(st.kinds, "claim")
	_check(st.cell.is_empty(), "another filter replaces the cell selection")
	print("all %d, statements %d, places %d" % [all_n, stmt_n, places_n])
	var total_n: int = g.board.filter(func(x): return not x.get("deleted", false) and x["kind"] != "deduction").size()
	_check(places_n < total_n and stmt_n < total_n, "each view shows a subset of the cards (%d, %d of %d)" % [places_n, stmt_n, total_n])

func _test_theme_fallback() -> void:
	var p = UITheme.panel("popup")
	_check(p is StyleBoxFlat, "without art, panels keep the flat look")
	_check(UITheme.make() is Theme, "a theme builds with no art present")

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

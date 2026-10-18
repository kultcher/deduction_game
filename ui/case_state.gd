## Shared case-board state: the active view, every filter, and what's selected. The card
## list, the board and the profile all read this one object, so a filter can never hide
## cards in one place without showing up (as a chip, and in the status line) in all of them.
## The working set is deliberately not part of it: it survives view and filter changes.
extends RefCounted

signal changed            # view or filters changed
signal selection_changed  # selected card or person changed

const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")

var view = "places"       # "places" | "statements" | "process" | "all" (the list only)
var rows_by = "place"     # Places view rows: "place" | "person"
var text = ""
var kinds = {}            # ticked kinds (OR within the list)
var people = {}           # ticked people
var places = {}           # ticked blocks / locations
var match_all = false     # false: a card fits any ticked list; true: every ticked list
var cell = {}             # a timeline cell: {key, label, cards: [n]}; empty = off
# Hidden cards: g.show_hidden is the one switch (the main screen's board uses it too).

var selected_card = 0
var selected_person = ""

func is_filtered() -> bool:
	return text != "" or not kinds.is_empty() or not people.is_empty() or not places.is_empty() or not cell.is_empty()

func clear() -> void:
	text = ""
	kinds.clear()
	people.clear()
	places.clear()
	cell = {}
	changed.emit()

## Any filter edit replaces a timeline-cell selection rather than narrowing inside it.
func edited() -> void:
	cell = {}
	changed.emit()

func set_view(v: String) -> void:
	if v == view:
		return
	view = v
	# Kinds that don't exist in the new view would silently hide everything: drop them.
	if v != "all":
		for k in kinds.keys():
			if not (k in CardModel.VIEW_KINDS[v]):
				kinds.erase(k)
	cell = {}
	changed.emit()

func toggle(store: Dictionary, key) -> void:
	if store.has(key):
		store.erase(key)
	else:
		store[key] = true
	edited()

func set_cell(key: String, label: String, nums: Array) -> void:
	if cell.get("key", "") == key:
		cell = {}  # clicking the selected cell again turns it off
	else:
		cell = {"key": key, "label": label, "cards": nums.duplicate()}
	changed.emit()

func select_card(n: int) -> void:
	if n != selected_card:
		selected_card = n
		selection_changed.emit()

func select_person(id: String) -> void:
	if id != selected_person:
		selected_person = id
		selection_changed.emit()

## Whether a card belongs to the active view (Places also takes any card that places
## someone, such as a Night Watch report).
func in_view(card: Dictionary) -> bool:
	match view:
		"all":
			return true
		"places":
			return card.get("view", "") == "places" or not CardModel.place_markers(card).is_empty()
	return card.get("view", CardModel.view_of(card)) == view

## Does the card involve this person, in the sense the active view means? Statements: what
## was said about them; Places: where they were; otherwise any involvement.
func _involves(g, card: Dictionary, id: String) -> bool:
	match view:
		"statements", "process":
			return id in CardModel.about(card) or id in card.get("yes", [])
		"places":
			for m in CardModel.place_markers(card):
				if m["who"] == id:
					return true
			return false
	return id in CardModel.about(card) or card.get("source", "") == id or card.get("via", "") == id or id in card.get("yes", [])

## The cards the list (and board) should show, in board order.
func apply(g) -> Array:
	var cards: Array = g.filter_cards(text).filter(func(c): return in_view(c))
	var lists: Array = []
	if not kinds.is_empty():
		var ks = {}
		for c in cards:
			if kinds.has(c["kind"]):
				ks[c["n"]] = true
		lists.append(ks)
	if not people.is_empty():
		var ps = {}
		for c in cards:
			for id in people:
				if _involves(g, c, id):
					ps[c["n"]] = true
		lists.append(ps)
	if not places.is_empty():
		var ls = {}
		for key in places:
			for c in g.filter_cards(key):
				ls[c["n"]] = true
		lists.append(ls)
	if not lists.is_empty():
		cards = cards.filter(func(c):
			var hits = 0
			for st in lists:
				if st.has(c["n"]):
					hits += 1
			return hits == lists.size() if match_all else hits > 0)
	if not cell.is_empty():
		var nums: Array = cell["cards"]
		cards = cards.filter(func(c): return c["n"] in nums)
	return cards

## Removable chips, one per active restriction: [{label, kind, key}].
func chips(g) -> Array:
	var out: Array = []
	if text != "":
		out.append({"label": "Text: \"%s\"" % text, "kind": "text", "key": ""})
	for k in kinds:
		out.append({"label": "Kind: %s" % k, "kind": "kinds", "key": k})
	for id in people:
		var nm: String = g.w.by_id[id].name if g.w.by_id.has(id) else id
		out.append({"label": ("About: %s" if view in ["statements", "process"] else "Person: %s") % nm, "kind": "people", "key": id})
	for p in places:
		out.append({"label": "Place: %s" % (C.block_name(p) if C.BLOCKS.has(p) else C.loc_name(p)), "kind": "places", "key": p})
	if not cell.is_empty():
		out.append({"label": "Timeline: %s" % cell["label"], "kind": "cell", "key": ""})
	return out

func remove_chip(kind: String, key) -> void:
	match kind:
		"text":
			text = ""
		"kinds":
			kinds.erase(key)
		"people":
			people.erase(key)
		"places":
			places.erase(key)
		"cell":
			cell = {}
	changed.emit()

## One line saying what's showing and why: "Showing 4 of 31 · Statements · About: Agnes,
## Kind: info (any)". If nothing shows, says whether filters are the reason.
func status_text(g, shown: int) -> String:
	var total = 0
	var in_v = 0
	for c in g.board:
		if c.get("deleted", false) or (c.get("hidden", false) and not g.show_hidden):
			continue
		total += 1
		if in_view(c):
			in_v += 1
	var parts: Array = ["Showing %d of %d card%s" % [shown, total, "" if total == 1 else "s"]]
	parts.append(CardModel.VIEW_NAMES.get(view, view))
	var ch: Array = chips(g).map(func(x): return x["label"])
	if not ch.is_empty():
		var lists = int(not kinds.is_empty()) + int(not people.is_empty()) + int(not places.is_empty())
		parts.append("Filters: " + ", ".join(PackedStringArray(ch)) + ((" (match all)" if match_all else " (match any)") if lists > 1 else ""))
	else:
		parts.append("no filters")
	if not g.show_hidden:
		var hid = g.board.filter(func(c): return c.get("hidden", false) and not c.get("deleted", false)).size()
		if hid > 0:
			parts.append("%d hidden" % hid)
	var s = " · ".join(PackedStringArray(parts))
	if shown == 0 and total > 0:
		if in_v == 0:
			s += ".  No %s cards yet." % CardModel.VIEW_NAMES.get(view, view)
		elif is_filtered():
			s += ".  Nothing matches your filters: clear or adjust them to see the %d card%s in this view." % [in_v, "" if in_v == 1 else "s"]
	return s

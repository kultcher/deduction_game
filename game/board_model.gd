## The case board's layout as plain data: which cards sit in which row and time column of a
## view, how they stack, and what each one connects to. The board UI only draws this; tests
## check it headless.
##
##   layout(cards, view, ctx) -> {
##     view, rows_by,
##     cols:  [{key, day, phase, label}]          every time slot from night 0 to now
##     rows:  [{id, label, kind}]                 kind: person | place | town
##     items: [{card, row, col, mark, who}]       one per (card, row); mark: solid | hollow |
##                                                ability | trace | statement | process
##     cells: {"row|col": [item indexes]}         for stacking and counts
##     pinned: [card numbers]                     deductions pinned onto this view (card.pins[view] = world position)
##   }
##   ctx: {day, phase (current), people: [{id, name, alive}], blocks: [ids], rows_by,
##         selected_people: [ids], selected_blocks: [ids]}
##
## Connections (for strings drawn on hover) come from links(card).
extends RefCounted

const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")

static func columns(day: int, phase: int) -> Array:
	var cols: Array = [{"key": "0:%d" % C.NIGHT, "day": 0, "phase": C.NIGHT, "label": "N0"}]
	for d in range(1, day + 1):
		for p in [C.MORNING, C.AFTERNOON, C.EVENING, C.NIGHT]:
			if d == day and p > phase:
				break
			var t = {"day": d, "phase": p}
			cols.append({"key": CardModel.time_key(t), "day": d, "phase": p, "label": CardModel.time_label(t)})
	return cols

static func layout(cards: Array, view: String, ctx: Dictionary) -> Dictionary:
	var rows_by: String = ctx.get("rows_by", "place")
	if view != "places":
		rows_by = "person"
	var cols: Array = columns(ctx.get("day", 1), ctx.get("phase", C.MORNING))
	var col_keys = {}
	for c in cols:
		col_keys[c["key"]] = true
	var rows: Array = []
	if rows_by == "place":
		for b in ctx.get("blocks", []):
			rows.append({"id": b, "label": C.block_name(b), "kind": "place"})
	else:
		for p in ctx.get("people", []):
			rows.append({"id": p["id"], "label": p["name"] + ("" if p.get("alive", true) else " †"), "kind": "person"})
	# Stable partition: explicit filters promote headers without changing card membership.
	var selected: Array = ctx.get("selected_people", []) if rows_by == "person" else ctx.get("selected_blocks", [])
	if not selected.is_empty():
		var promoted: Array = rows.filter(func(row): return row.id in selected)
		promoted.append_array(rows.filter(func(row): return row.id not in selected))
		rows = promoted
	var row_ids = {}
	for r in rows:
		row_ids[r["id"]] = true
	var items: Array = []
	var cells = {}
	var pinned: Array = []
	var need_town = false
	for card in cards:
		var cv: String = card.get("view", CardModel.view_of(card))
		if cv == "theory":
			if card.get("pins", {}).has(view):
				pinned.append(card["n"])
			continue
		var t: Dictionary = card.get("when", CardModel.when(card, ctx.get("day", 1), ctx.get("phase", C.MORNING)))
		if view == "places":
			# A card shows in Places if it puts someone (or something) somewhere, even if it
			# lives in another view (a Night Watch report): one card, two representations.
			for m in CardModel.place_markers(card):
				var r: String = m["who"] if rows_by == "person" else m["block"]
				if r == "":
					r = "town"
				_add(items, cells, card["n"], r, CardModel.time_key(m["time"]), m["mark"], m["who"])
				need_town = need_town or r == "town"
			continue
		if cv != view:
			continue
		for r2 in CardModel.rows_for(card, view, rows_by):
			var mark = "process" if view == "process" else "statement"
			if view == "process" and card.get("kind", "") == "vote":
				mark = "nominated" if r2 == card.get("nominee", "") else "voted_yes"
			_add(items, cells, card["n"], r2, CardModel.time_key(t), mark, r2)
			need_town = need_town or r2 == "town"
	if need_town and not row_ids.has("town"):
		rows.append({"id": "town", "label": "Town", "kind": "town"})
	# Drop items whose row or column isn't on the board (a dead block id, a future slot).
	var kept: Array = []
	var cells2 = {}
	for it in items:
		if (row_ids.has(it["row"]) or it["row"] == "town") and col_keys.has(it["col"]):
			var ck = "%s|%s" % [it["row"], it["col"]]
			if not cells2.has(ck):
				cells2[ck] = []
			cells2[ck].append(kept.size())
			kept.append(it)
	return {"view": view, "rows_by": rows_by, "cols": cols, "rows": rows, "items": kept, "cells": cells2, "pinned": pinned}

static func _add(items: Array, cells: Dictionary, n: int, row: String, col: String, mark: String, who: String) -> void:
	for it in items:
		if it["card"] == n and it["row"] == row and it["col"] == col and it["who"] == who:
			return
	items.append({"card": n, "row": row, "col": col, "mark": mark, "who": who})

## What a card connects to, for the strings drawn on hover: who said it (source), whom it's
## about (subjects), and the cards a deduction rests on (supports).
static func links(card: Dictionary) -> Dictionary:
	var src: String = card.get("source", "")
	return {"source": src if not (src in ["player", "evidence", ""]) else "",
		"via": card.get("learned", []).map(func(d): return d["via"]).filter(func(x): return x != "" and x != src and x != "player"),
		"subjects": CardModel.about(card),
		"supports": card.get("supports", []).duplicate()}

## Which cards a layout shows (for "nothing visible" hints and card-list sync).
static func shown_cards(lay: Dictionary) -> Array:
	var out: Array = []
	for it in lay["items"]:
		if not (it["card"] in out):
			out.append(it["card"])
	return out

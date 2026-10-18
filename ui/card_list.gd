## A card list whose rows word-wrap: a one-column Tree with a small ItemList-like API.
extends Tree

signal card_activated(num)
signal selection_changed
signal cards_dropped(nums)   # cards dragged here from the board, the tray or another list

var accept_drops = false

var _root: TreeItem
var _items: Array = []

func _init() -> void:
	hide_root = true
	columns = 1
	select_mode = Tree.SELECT_MULTI
	_root = create_item()
	item_activated.connect(func():
		var it = get_selected()
		if it != null:
			card_activated.emit(it.get_metadata(0)))
	multi_selected.connect(func(_item, _col, _sel): selection_changed.emit())
	item_selected.connect(func(): selection_changed.emit())

func reset() -> void:
	clear()
	_items = []
	_root = create_item()

func add(text: String, meta, tip: String = "", color = null) -> TreeItem:
	var it = create_item(_root)
	it.set_text(0, text)
	it.set_metadata(0, meta)
	it.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)
	if tip != "":
		it.set_tooltip_text(0, tip)
	if color != null:
		it.set_custom_color(0, color)
	_items.append(it)
	return it

## A section heading row (not a card: not counted, not selectable).
func add_header(text: String, color = null) -> void:
	var it = create_item(_root)
	it.set_text(0, text)
	it.set_selectable(0, false)
	if color != null:
		it.set_custom_color(0, color)

func count() -> int:
	return _items.size()

func meta_at(i: int):
	return _items[i].get_metadata(0)

func select_index(i: int) -> void:
	if i >= 0 and i < _items.size():
		_items[i].select(0)

func select_meta(meta) -> void:
	for it in _items:
		if it.get_metadata(0) == meta:
			it.select(0)

func selected_metas() -> Array:
	var out: Array = []
	var it = get_next_selected(null)
	while it != null:
		out.append(it.get_metadata(0))
		it = get_next_selected(it)
	return out

# Drag cards out of the list (to the working set or another list), and accept drops.
func _get_drag_data(_at: Vector2):
	var sel: Array = selected_metas().filter(func(x): return x is int and x > 0)
	if sel.is_empty():
		return null
	var l = Label.new()
	l.text = "#" + ", #".join(PackedStringArray(sel.map(func(x): return str(x))))
	set_drag_preview(l)
	return {"cards": sel, "from": self}

func _can_drop_data(_at: Vector2, data) -> bool:
	return accept_drops and data is Dictionary and data.has("cards") and data.get("from") != self

func _drop_data(_at: Vector2, data) -> void:
	cards_dropped.emit(data["cards"])

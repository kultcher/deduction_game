## The shapes the map draws, in base-map image pixels, shared by the game's map view and the
## layout editor's preview so the two always agree.
extends RefCounted

## The layout nodes draw their preview in the editor only; tools can turn it on elsewhere
## (a headless screenshot of the layout, say).
static var preview_outside_editor := false
static func previewing() -> bool:
	return Engine.is_editor_hint() or preview_outside_editor

## A building drawn on its lot: the lot's centre and size in, the sprite's box out (the art
## is fitted into it, keeping its shape). Roofs rise above the lot; pads near the top edge
## keep the roof on the map.
static func building_box(pad: Array) -> Rect2:
	var w: float = pad[2] * 0.78
	var bottom: float = pad[1] + pad[3] * 0.32
	var h: float = minf(pad[3] * 1.35, bottom - 8.0)
	return Rect2(pad[0] - w / 2.0, bottom - h, w, h)

## The art box for a building: its box with 10% more headroom.
static func building_art_box(pad: Array) -> Rect2:
	var r := building_box(pad)
	return r.grow_individual(0, r.size.y * 0.1, 0, 0)

## A cottage's clickable box from its lot centre.
const COTTAGE_SIZE = 78.0
static func cottage_box(c: Vector2) -> Rect2:
	return Rect2(c.x - COTTAGE_SIZE / 2.0, c.y + 22 - COTTAGE_SIZE, COTTAGE_SIZE, COTTAGE_SIZE)

## A townsperson's own cottage art is drawn a little larger than the clickable box.
static func cottage_art_box(c: Vector2) -> Rect2:
	var r := cottage_box(c)
	return r.grow(r.size.x * 0.22)

## The dirt lot under a cottage, wide and low enough to show round it.
static func cottage_lot(c: Vector2) -> Rect2:
	return Rect2(c.x - 64, c.y - 12, 128, 58)

## Fits a texture into a box keeping its aspect ("contain").
static func contain(tex: Texture2D, box: Rect2) -> Rect2:
	var ts := Vector2(tex.get_width(), tex.get_height())
	var s: float = minf(box.size.x / ts.x, box.size.y / ts.y)
	var sz := ts * s
	return Rect2(box.position + (box.size - sz) / 2.0, sz)

## Art for the editor preview, scaled down the way the game draws it (path relative to
## res://assets/art/, no extension), or null.
static var _art_cache := {}
static func art(rel: String, scale: float = 0.5):
	var key := "%s@%.2f" % [rel, scale]
	if _art_cache.has(key):
		return _art_cache[key]
	var path := "res://assets/art/%s.png" % rel
	var img: Image = null
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			img = r.get_image()
	if img == null and FileAccess.file_exists(path):
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	var t = null
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		if scale != 1.0:
			img.resize(maxi(1, int(img.get_width() * scale)), maxi(1, int(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		t = ImageTexture.create_from_image(img)
	_art_cache[key] = t
	return t

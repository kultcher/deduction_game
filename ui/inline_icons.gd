## Small inline art adapted to its display surface. Original resources stay untouched.
extends RefCounted

const UITheme = preload("res://ui/theme.gd")
var _sources: Dictionary = {}
var _variants: Dictionary = {}

func texture(path: String, surface: String, height: int):
	if path.is_empty():
		return null
	if not _sources.has(path):
		_sources[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	var source = _sources[path]
	if source == null or surface == "paper":
		return source
	height = maxi(1, height)
	var key = "%s:%d" % [path, height]
	if not _variants.has(key):
		var image: Image = source.get_image().duplicate()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var width = maxi(1, roundi(height * float(image.get_width()) / image.get_height()))
		# Adapt only the tiny display image, once per size, rather than full-size art.
		image.resize(width, height, Image.INTERPOLATE_LANCZOS)
		var ink = UITheme.color("paper")
		for y in range(height):
			for x in range(width):
				var pixel = image.get_pixel(x, y)
				var inverse = 1.0 - pixel.get_luminance()
				image.set_pixel(x, y, Color(ink.r * inverse, ink.g * inverse, ink.b * inverse, pixel.a))
		_variants[key] = ImageTexture.create_from_image(image)
	return _variants[key]

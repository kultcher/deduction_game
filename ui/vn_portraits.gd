## The 15-cast VN portraits and their five expressions, shared by the daytime conversation
## view and the meeting's courtroom stage (meeting plan M3a, section 5.1). Presentation
## only: callers pass a public expression cue, never hidden game state.
extends RefCounted

const UITheme = preload("res://ui/theme.gd")

const LARGE = {
	"agnes": preload("res://assets/art/portraits_vn_poc/agnes-vn-poc-v1.png"),
	"bart": preload("res://assets/art/portraits_vn_poc/bartholomew-vn-poc-v1.png"),
	"constance": preload("res://assets/art/portraits_vn_poc/constance-vn-poc-v1.png"),
	"dorian": preload("res://assets/art/portraits_vn_cast/dorian-vn-v1.png"),
	"edda": preload("res://assets/art/portraits_vn_cast/edda-vn-v1.png"),
	"fenwick": preload("res://assets/art/portraits_vn_cast/fenwick-vn-v1.png"),
	"greta": preload("res://assets/art/portraits_vn_cast/greta-vn-v1.png"),
	"hollis": preload("res://assets/art/portraits_vn_cast/hollis-vn-v1.png"),
	"isolde": preload("res://assets/art/portraits_vn_cast/isolde-vn-v1.png"),
	"jory": preload("res://assets/art/portraits_vn_cast/jory-vn-v1.png"),
	"kiran": preload("res://assets/art/portraits_vn_cast/kiran-vn-v1.png"),
	"lian": preload("res://assets/art/portraits_vn_cast/lian-vn-v1.png"),
	"merrin": preload("res://assets/art/portraits_vn_cast/merrin-vn-v1.png"),
	"nisha": preload("res://assets/art/portraits_vn_cast/nisha-vn-v1.png"),
	"odette": preload("res://assets/art/portraits_vn_cast/odette-vn-v1.png"),
}
const EXPRESSIONS = ["neutral", "warm", "harsh", "concerned", "sorrowful"]
const CONSTANCE_EXPRESSIONS = {
	"neutral": "res://assets/art/portraits_vn_poc/constance-vn-poc-v1.png",
	"warm": "res://assets/art/portrait_expression_poc/constance-warm-v1.png",
	"harsh": "res://assets/art/portrait_expression_poc/constance-harsh-v2.png",
	"concerned": "res://assets/art/portrait_expression_poc/constance-worried-v1.png",
	"sorrowful": "res://assets/art/portrait_expression_poc/constance-sorrowful-v1.png",
}


## The portrait for `id` wearing `expression` (falls back to neutral, then the small portrait).
static func texture(id: String, expression: String = "neutral") -> Texture2D:
	var fallback: Texture2D = LARGE.get(id, UITheme.tex("art/portraits/" + id))
	if expression not in EXPRESSIONS:
		expression = "neutral"
	var path: String = CONSTANCE_EXPRESSIONS.get(expression, "") if id == "constance" else "res://assets/art/cast_expressions/%s/%s-v1.png" % [id, expression]
	if ResourceLoader.exists(path):
		return load(path)
	if expression != "neutral":
		return texture(id, "neutral")
	return fallback

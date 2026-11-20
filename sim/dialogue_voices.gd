## Authored presentation only. No roles, secrets, alignment or decision rules belong here.
extends RefCounted

## Each character's lines live in sim/voices/<id>.gd; this file assembles them, in cast order.

const VOICES = {
	"agnes": preload("res://sim/voices/agnes.gd").LINES,
	"bart": preload("res://sim/voices/bart.gd").LINES,
	"constance": preload("res://sim/voices/constance.gd").LINES,
	"dorian": preload("res://sim/voices/dorian.gd").LINES,
	"edda": preload("res://sim/voices/edda.gd").LINES,
	"fenwick": preload("res://sim/voices/fenwick.gd").LINES,
	"greta": preload("res://sim/voices/greta.gd").LINES,
	"hollis": preload("res://sim/voices/hollis.gd").LINES,
	"isolde": preload("res://sim/voices/isolde.gd").LINES,
	"jory": preload("res://sim/voices/jory.gd").LINES,
	"kiran": preload("res://sim/voices/kiran.gd").LINES,
	"lian": preload("res://sim/voices/lian.gd").LINES,
	"merrin": preload("res://sim/voices/merrin.gd").LINES,
	"nisha": preload("res://sim/voices/nisha.gd").LINES,
	"odette": preload("res://sim/voices/odette.gd").LINES,
}

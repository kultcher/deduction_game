## "Call on" (docs/design/withheld_readings.md, Michael, Nov 22): what someone the Demonologist
## calls on at the meeting says. Beadle owns the decision (the normal disclosure rules with a
## light pressure bump); this is the stub Herald's command builds against, and it says only that
## there is nothing more to tell.
##
## respond(w, n) -> {
##   "lines":   spoken lines (say_voiced dictionaries), in order;
##   "facts":   board facts for the player, if any;
##   "outcome": "shared" | "nothing" | "deferred" | "deflected", as the town hears it;
##   "reason":  for a deferral, "friend" | "burden" | "distrust", else "";
##   "lie":     true when "nothing" is said over something unshared (logged with its reason).
## }
extends RefCounted

static func _mind():
	return load("res://sim/mind.gd")

static func respond(w, n) -> Dictionary:
	return {"lines": [_mind().say_voiced(n, "call_on_nothing", "I've told the town all I know.")], "facts": [],
		"outcome": "nothing", "reason": "", "lie": false}

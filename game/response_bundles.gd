## Summarised meeting answers (Michael, Nov 19). After a case is presented at the meeting,
## listeners whose answers match are shown together: a representative speaks in full, and the
## others appear as small portraits with a short agreement line. The log keeps every answer.
##
## Two answers match when they share the stance (accept / partial / reject), the kind of reply
## (the voice pool key it was drawn from), whom the reply names as evil besides the target (two
## answers pointing at different suspects don't agree), and how far the case moved them on its
## target, in four bands. The target, anyone with more than one line or a fact of their own, and any answer
## with no reply kind speak alone.
extends RefCounted

const Dialogue = preload("res://sim/dialogue.gd")

## Most small portraits in one row; the rest are counted ("+2 more").
const MAX_SHOWN = 5

## How far the case moved a listener on its target, in points out of 100 (Michael, Nov 19).
static func movement_band(delta: float) -> String:
	var pts: float = delta * 100.0
	if pts >= 15.0:
		return "rose_lot"
	if pts >= 5.0:
		return "rose"
	if pts > -5.0:
		return "still"
	return "fell"

## entries: [{id, name, lines, facts, agreement, stance, reply_key, delta, trust, seat}] in seat
## order. Returns the lines to speak, in order: each a speech dictionary, the representative's
## carrying "agree" (and "agree_more" past MAX_SHOWN), the bundled members' own lines marked
## "bundled", and {"facts": [...]} entries where a solo speaker added cards.
static func arrange(entries: Array, target: String) -> Array:
	var groups: Dictionary = {}
	var order: Array = []
	var solo: Array = []
	var last: Array = []
	for e in entries:
		if e.lines.is_empty():
			continue
		var line: Dictionary = e.lines[0] if e.lines[0] is Dictionary else {}
		var reply: String = str(line.get("reply_key", ""))
		if e.id == target:
			last.append(e)
		elif e.lines.size() != 1 or not e.facts.is_empty() or reply == "" or line.is_empty():
			solo.append(e)
		else:
			var key: String = "%s|%s|%s|%s" % [e.stance, reply, movement_band(float(e.delta)), ",".join(PackedStringArray(line.get("reply_named", [])))]
			if not groups.has(key):
				groups[key] = []
				order.append(key)
			groups[key].append(e)
	# Most agreeing first; a stable sort keeps seat order among equals.
	var bundles: Array = order.map(func(k): return groups[k])
	bundles.sort_custom(func(a, b): return _mean(a) > _mean(b))
	var out: Array = []
	for b in bundles:
		if b.size() == 1:
			out.append_array(_spoken(b[0]))
			continue
		var rep: Dictionary = _representative(b)
		var others: Array = b.filter(func(e): return e != rep)
		var said: Dictionary = (rep.lines[0] as Dictionary).duplicate()
		var agree: Array = []
		for i in range(others.size()):
			var o: Dictionary = others[i]
			if i < MAX_SHOWN:
				agree.append({"speaker": o.id, "name": o.name, "text": agreement_line(o.id, i),
					"own": str((o.lines[0] as Dictionary).get("text", ""))})
		said["agree"] = agree
		if others.size() > MAX_SHOWN:
			said["agree_more"] = others.size() - MAX_SHOWN
		out.append(said)
		for o in others:
			var own: Dictionary = (o.lines[0] as Dictionary).duplicate()
			own["bundled"] = true
			out.append(own)
	for e in solo + last:
		out.append_array(_spoken(e))
	return out

static func _spoken(e: Dictionary) -> Array:
	var out: Array = e.lines.duplicate()
	if not e.facts.is_empty():
		out.append({"facts": e.facts})
	return out

static func _mean(b: Array) -> float:
	var total: float = 0.0
	for e in b:
		total += float(e.agreement)
	return total / maxf(1.0, float(b.size()))

## The member whose agreement is closest to the bundle's middle; ties go to the higher trust in
## the player, then seat order.
static func _representative(b: Array) -> Dictionary:
	var mid: float = _mean(b)
	var best: Dictionary = b[0]
	for e in b:
		var d: float = absf(float(e.agreement) - mid)
		var bd: float = absf(float(best.agreement) - mid)
		if d < bd - 0.0001 or (absf(d - bd) <= 0.0001 and (float(e.trust) > float(best.trust) + 0.0001 or (absf(float(e.trust) - float(best.trust)) <= 0.0001 and int(e.seat) < int(best.seat)))):
			best = e
	return best

## A short agreement line in the speaker's voice, alternating two so a row doesn't repeat.
static func agreement_line(id: String, i: int) -> String:
	var key: String = "agree_short_a" if i % 2 == 0 else "agree_short_b"
	return Dialogue.voice_line(id, key, "Agreed.")

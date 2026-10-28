## What a reading says, in general terms, whatever gift produced it: who it points at, who
## it speaks for, who it names, and a one-line summary. Every reading's data uses one of a
## few shapes, so reasoning elsewhere keys off these rather than off particular gifts:
##   {pair, yes}               Seer: is either the demon
##   {pair, role}              Archivist (a minion), Clerk (a gift): one of two holds it
##   {pair, secret}            Rumormonger: one of two carries a secret
##   {nbrs|group, count}       Hearthwitch, Dowser: how many of these are evil
##   {block, seen}             Night Watch: who passed
##   {executed, role}          Gravedigger: what the hanged really were
##   {count}                   Surveyor (blocks with an evil resident), Lamplighter (others out)
##   {dead, item}              Medium: something the dead knew (item: reading, sighting,
##                             suspicion, home)
##   {subject, trusts, suspects}  Psychologist
##   {attacked, block}         Veteran: survived an attack; the attacker's last block
##   {target, chosen|evil}     Martyr: whom they chose; or that the chosen was hanged and evil
extends RefCounted

const C = preload("res://sim/content.gd")

static func group_of(d: Dictionary) -> Array:
	return d.get("group", d.get("nbrs", []))

## People the reading points toward evil.
static func implicated(e: Dictionary) -> Array:
	var d: Dictionary = e.get("data", {})
	var role: String = e.get("role", "")
	var rdef = C.role_def(role)
	if rdef != null:
		return rdef.implicated(d)
	match role:
		"nightwatch":
			return d.get("seen", [])
		"martyr":
			return [d["target"]] if d.get("evil", false) else []
	return []

## People the reading speaks for.
static func clears(e: Dictionary) -> Array:
	var d: Dictionary = e.get("data", {})
	var role: String = e.get("role", "")
	var rdef = C.role_def(role)
	if rdef != null:
		return rdef.clears(d)
	match role:
		"rumormonger":
			return d.get("pair", [])
		"martyr":
			return [d["target"]] if d.get("chosen", false) else []
	return []

## Everyone the reading names.
static func subjects(e: Dictionary) -> Array:
	var d: Dictionary = e.get("data", {})
	var out: Array = []
	for k in ["nbrs", "group", "pair", "seen"]:
		for x in d.get(k, []):
			if not (x in out):
				out.append(x)
	for k in ["executed", "subject", "trusts", "suspects", "target", "dead"]:
		var v: String = d.get(k, "")
		if v != "" and not (v in out):
			out.append(v)
	var it: Dictionary = d.get("item", {})
	for x in subjects(it["entry"]) if it.get("type", "") == "reading" else ([it.get("who", ""), it.get("about", "")]):
		if x != "" and not (x in out):
			out.append(x)
	return out

static func _names(ids: Array, nm: Callable) -> String:
	return " / ".join(PackedStringArray(ids.map(nm)))

## A one-line summary for the board (names via nm: id -> display name).
static func short_text(role: String, d: Dictionary, src: String, nm: Callable) -> String:
	var rdef = C.role_def(role)
	if rdef != null:
		return rdef.short_text(d, src, nm)
	match role:
		"nightwatch":
			return "%s Watch %s: %s" % [src, C.block_name(d.get("block", "")), ", ".join(PackedStringArray(d.get("seen", []).map(nm))) if not d.get("seen", []).is_empty() else "nobody"]
		"rumormonger":
			return "%s Rumormonger: %s in %s" % [src, C.secret_name(d.get("secret", "")), _names(d.get("pair", []), nm)]
		"surveyor":
			return "%s Surveyor: %d block%s with evil" % [src, d.get("count", 0), "" if d.get("count", 0) == 1 else "s"]
		"lamplighter":
			return "%s Lamplighter: %d others out" % [src, d.get("count", 0)]
		"psychologist":
			return "%s Psychologist: %s trusts %s, suspects %s" % [src, nm.call(d.get("subject", "")), nm.call(d.get("trusts", "")), nm.call(d.get("suspects", ""))]
		"veteran":
			return "%s Veteran: attacked, from %s" % [src, C.block_name(d.get("block", ""))]
		"martyr":
			if d.get("evil", false):
				return "%s Martyr: %s was evil" % [src, nm.call(d.get("target", ""))]
			return "%s Martyr: chose %s" % [src, nm.call(d.get("target", ""))]
	return "%s %s reading" % [src, C.role_name(role)]

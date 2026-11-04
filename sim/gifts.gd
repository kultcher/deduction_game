## What a reading says, in general terms, whatever gift produced it: who it points at, who
## it speaks for, who it names, and a one-line summary. Every reading's data uses one of a
## few shapes, so reasoning elsewhere keys off these rather than off particular gifts:
##   {pair, yes}               Seer: is either the demon
##   {pair, role}              Archivist (a minion), Clerk (a gift): one of two holds it
##   {pair, secret}            Rumormonger: one of two carries a secret
##   {nbrs|group, count}       Hearthwitch, Dowser: how many of these are evil
##   {block, seen}             Night Watch: who passed
##   {executed, role}          Gravedigger: what the hanged really were
##   {block, same} / {count}   Surveyor (block alignment parity), Lamplighter (others out)
##   {trio}                    Chronicler: case-start townsfolk, secret-holder, and minion
##   {yes}                     Augur: daytime public-block Demon crossing
##   {nominator, nominee, same} Magistrate: first eligible nomination alignment parity
##   {target, assigned|role}   Executor: case-start charge, or post-death role learned
##   {roles[, target, yes]}    Registrar: 3-role slate, or nightly check against slate
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
	return []

## People the reading speaks for.
static func clears(e: Dictionary) -> Array:
	var d: Dictionary = e.get("data", {})
	var role: String = e.get("role", "")
	var rdef = C.role_def(role)
	if rdef != null:
		return rdef.clears(d)
	return []

## Everyone the reading names.
static func subjects(e: Dictionary) -> Array:
	var d: Dictionary = e.get("data", {})
	var out: Array = []
	for k in ["nbrs", "group", "pair", "seen", "trio"]:
		for x in d.get(k, []):
			if not (x in out):
				out.append(x)
	for k in ["executed", "subject", "trusts", "suspects", "target", "dead", "nominator", "nominee"]:
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
	return "%s %s reading" % [src, C.role_name(role)]

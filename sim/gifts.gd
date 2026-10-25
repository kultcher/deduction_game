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
	match e.get("role", ""):
		"seer":
			return d["pair"] if d.get("yes", false) else []
		"hearthwitch", "dowser":
			return group_of(d) if d.get("count", 0) > 0 else []
		"archivist":
			return d.get("pair", [])
		"nightwatch":
			return d.get("seen", [])
		"gravedigger":
			return [d["executed"]] if C.ROLES.get(d.get("role", ""), {}).get("align", "good") == "evil" else []
		"martyr":
			return [d["target"]] if d.get("evil", false) else []
		"medium":
			var it: Dictionary = d.get("item", {})
			match it.get("type", ""):
				"reading":
					return implicated(it["entry"])
				"sighting":
					return [it["who"]]
				"suspicion":
					return [] # Opinions remain opinions when relayed by a gift (Q4).
	return []

## People the reading speaks for.
static func clears(e: Dictionary) -> Array:
	var d: Dictionary = e.get("data", {})
	match e.get("role", ""):
		"seer":
			return [] if d.get("yes", false) else d.get("pair", [])
		"hearthwitch", "dowser":
			return group_of(d) if d.get("count", 0) == 0 else []
		"clerk", "rumormonger":
			return d.get("pair", [])
		"gravedigger":
			return [d["executed"]] if C.ROLES.get(d.get("role", ""), {}).get("align", "good") == "good" else []
		"martyr":
			return [d["target"]] if d.get("chosen", false) else []
		"medium":
			var it: Dictionary = d.get("item", {})
			if it.get("type", "") == "reading":
				return clears(it["entry"])
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
	match role:
		"seer":
			return "%s Seer: %s → %s" % [src, _names(d.get("pair", []), nm), "YES" if d.get("yes", false) else "no"]
		"hearthwitch", "dowser":
			return "%s %s: %d evil of %s" % [src, C.role_name(role), d.get("count", 0), _names(group_of(d), nm)]
		"nightwatch":
			return "%s Watch %s: %s" % [src, C.block_name(d.get("block", "")), ", ".join(PackedStringArray(d.get("seen", []).map(nm))) if not d.get("seen", []).is_empty() else "nobody"]
		"archivist":
			return "%s Archivist: %s in %s" % [src, C.role_name(d.get("role", "poisoner")), _names(d.get("pair", []), nm)]
		"clerk":
			return "%s Clerk: %s in %s" % [src, C.role_name(d.get("role", "")), _names(d.get("pair", []), nm)]
		"rumormonger":
			return "%s Rumormonger: %s in %s" % [src, C.secret_name(d.get("secret", "")), _names(d.get("pair", []), nm)]
		"gravedigger":
			return "%s Gravedigger: %s was %s" % [src, nm.call(d.get("executed", "")), C.role_name(d.get("role", ""))]
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
		"medium":
			var it: Dictionary = d.get("item", {})
			var dead: String = nm.call(d.get("dead", ""))
			match it.get("type", ""):
				"reading":
					return "%s Medium (%s): %s" % [src, dead, short_text(it["entry"]["role"], it["entry"]["data"], dead, nm)]
				"sighting":
					return "%s Medium: %s saw %s out" % [src, dead, nm.call(it.get("who", ""))]
				"suspicion":
					return "%s Medium: %s suspected %s" % [src, dead, nm.call(it.get("about", ""))]
				"home":
					return "%s Medium: %s was home on night %d" % [src, dead, it.get("night", 0)]
				"guard":
					return "%s Medium: %s guarded %s's door on night %d" % [src, dead, nm.call(it.get("who", "")), it.get("night", 0)]
			return "%s Medium: %s had nothing to tell" % [src, dead]
	return "%s %s reading" % [src, C.role_name(role)]

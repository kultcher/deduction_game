## Step 1: shared public terms and deterministic matching, without UI integration.
## godot --headless --path . --script res://tools/test_text_terms.gd
extends SceneTree

const Terms = preload("res://ui/text_terms.gd")
const C = preload("res://sim/content.gd")
var fails = 0

func _init() -> void:
	var registry = Terms.new()
	var person = registry.lookup("person:bart")
	_check(person["label"] == "Bartholomew" and person["color"] == C.npc_color("bart"), "character display metadata comes from the existing cast")
	_check(person["icon_path"] == "" and person["tooltip"] == "", "names do not acquire unsolicited portraits or tooltip behavior")
	var role = registry.lookup("role:nightwatch")
	_check(role["label"] == "Night Watch" and C.ROLES["nightwatch"]["desc"] in role["tooltip"], "role tooltips use the public role definition")
	_check(role["icon_path"] == "res://assets/ui/roles/nightwatch.png" and role["color"] == null, "existing role art is referenced and role text can inherit its surrounding color")
	_check(C.CAST.all(func(n): return not registry.lookup("person:" + n["id"]).is_empty()) and C.ROLES.keys().all(func(id): return not registry.lookup("role:" + id).is_empty()), "all cast members and defined roles are registered without case state")
	person["color"] = Color.BLACK
	person["aliases"].clear()
	_check(registry.lookup("person:bart")["color"] == C.npc_color("bart") and not registry.lookup("person:bart")["aliases"].is_empty(), "lookup results cannot mutate shared definitions")
	_check(registry.lookup("person:missing").is_empty(), "unknown IDs have no fabricated metadata")
	_check(_ids(registry.find_matches("Bartholomew saw Fenwick near the Seer.")) == ["person:bart", "person:fenwick", "role:seer"], "the example speech identifies separate people and a role")
	var text = "Élan: lIaN’s, Fenwick's; Lian."
	var hits = registry.find_matches(text)
	_check(_ids(hits) == ["person:lian", "person:fenwick", "person:lian"], "case variants, straight and curly possessives, and punctuation match")
	_check(hits.all(func(h): return text.substr(h["start"], h["end"] - h["start"]) == h["text"]) and hits[0]["text"] == "lIaN", "Unicode offsets and original capitalization are preserved")
	_check(registry.find_matches("Lianette Fenwickson xLian Lian2 _Lian Lian_ éLian Liané Lian\u0301").is_empty(), "names do not match inside longer Unicode words, numbers or identifiers")
	_check(_ids(registry.find_matches("night watch, Night Watch, NIGHT WATCH")) == ["role:nightwatch", "role:nightwatch", "role:nightwatch"], "the multiword Night Watch alias stays one reference")
	_check(registry.find_matches("medium confidence; a clerk; veteran sailor; a scion of the family").is_empty(), "ambiguous lowercase prose is not mistaken for roles")
	_check(_ids(registry.find_matches("The Medium spoke to the Clerk.")) == ["role:medium", "role:clerk"], "canonical role capitalization is recognized in prose")
	_check(_ids(registry.find_matches("medium clerk nightwatch", {"role_context": true})) == ["role:medium", "role:clerk", "role:nightwatch"], "explicit gift context supports lowercase ambiguous names and role IDs")
	_check(_ids(registry.find_matches("Lian the Clerk", {"kinds": ["person"]})) == ["person:lian"], "occupation-only surfaces can suppress role matching while keeping names")
	_check(registry.find_matches("Lian the Seer", {"enabled": false}).is_empty(), "an input or debug segment can opt out entirely")
	_check(_ids(registry.find_matches("Lian the Seer", {"kinds": ["role"]})) == ["role:seer"], "surfaces can select which term kinds are eligible")
	var custom = Terms.new(false)
	_check(custom.register_term({"id": "place:hill", "kind": "place", "label": "Chapel Hill"}) and custom.register_term({"id": "place:chapel", "kind": "place", "label": "Chapel"}), "new term kinds require only data registration")
	_check(_ids(custom.find_matches("Chapel Hill; Chapel.")) == ["place:hill", "place:chapel"], "the longest phrase wins without hiding later shorter references")
	_check(custom.register_term({"id": "literal", "kind": "test", "label": "C++ (gift)"}) and _ids(custom.find_matches("C++ (gift)")) == ["literal"], "aliases are literal text even when they contain regex punctuation")
	_check(not custom.register_term({"id": "place:hill", "kind": "place", "label": "Changed"}) and custom.lookup("place:hill")["label"] == "Chapel Hill", "duplicate IDs cannot silently replace an existing term")
	_check(not custom.register_term({"id": "broken", "kind": "test", "label": "Broken", "aliases": ["usable", ""]}) and custom.find_matches("usable").is_empty(), "an invalid alias rejects the entire registration without partial matches")
	custom.register_term({"id": "z", "kind": "test", "label": "same"})
	custom.register_term({"id": "a", "kind": "test", "label": "same"})
	_check(_ids(custom.find_matches("same")) == ["a"], "equal-length alias collisions resolve deterministically by stable ID")
	var source = "[color=red]Fenwick[/color]"
	var before = source
	registry.find_matches(source)
	_check(source == before, "matching never changes the supplied plain text or creates markup")
	print("TEXT TERM FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _ids(matches: Array) -> Array:
	return matches.map(func(hit): return hit["id"])

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

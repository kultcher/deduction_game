## Learning resources, layer 1: the mechanics terms carry tooltips through TextTerms, and
## action buttons get theirs from the same registry (ui/term_defs.gd).
##   godot --headless --path . --script res://tools/test_term_defs.gd
extends SceneTree
const Terms = preload("res://ui/text_terms.gd")
const TermDefs = preload("res://ui/term_defs.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL " + label)

func _init() -> void:
	var terms = Terms.new()
	for t in TermDefs.MECHANICS:
		check(str(t.tooltip).begins_with(t.label + ":"), "%s's tooltip names it first" % t.id)
	var found: Array = terms.find_matches("Fenwick is on the block. Keep a vigil, or use your Ward; Clemency is once per case.")
	var ids: Array = found.map(func(r): return r.get("id", ""))
	for want in ["mechanic:on_the_block", "mechanic:vigil", "mechanic:ward", "mechanic:clemency"]:
		check(want in ids, "%s is marked in prose (got %s)" % [want, str(ids)])
	check(not terms.find_matches("a ward of the parish").any(func(r): return r.get("id", "") == "mechanic:ward"), "a lower-case 'ward' in ordinary prose isn't marked")
	check(TermDefs.control_tip("Ward Agnes's door (1 left)") != "" and TermDefs.control_tip("Keep vigil on the Docks") != "", "action buttons find their tooltips by label")
	check(TermDefs.control_tip("Talk to Agnes") == "", "a button with no entry gets none")
	print("Term defs: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

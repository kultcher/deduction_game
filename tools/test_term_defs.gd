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
	# Mistaken: its tooltip names only the causes the case in play allows (Michael, Nov 19).
	Terms.set_honest_causes(null)
	var mk: Array = terms.find_matches("Edda's reading was Mistaken.").filter(func(r): return r.get("id", "") == Terms.MISTAKEN_ID)
	check(mk.size() == 1, "'Mistaken' is marked in prose")
	check(not terms.find_matches("I was mistaken about the hour.").any(func(r): return r.get("id", "") == Terms.MISTAKEN_ID), "a lower-case 'mistaken' isn't marked")
	var all_tip: String = mk[0].tooltip if mk.size() == 1 else ""
	check(all_tip == "Mistaken: a reading that was wrong but honestly told. Something fooled the gift; in this town that could be poison, delusion, a Red Herring or a Marked soul.", "with no case, every cause is named (%s)" % all_tip)
	Terms.set_honest_causes(["poison", "marked"])
	check(terms.lookup(Terms.MISTAKEN_ID).tooltip.ends_with("could be poison or a Marked soul."), "a registry built before the case follows its causes (%s)" % terms.lookup(Terms.MISTAKEN_ID).tooltip)
	Terms.set_honest_causes(["delusion"])
	check(Terms.new().find_matches("Mistaken")[0].tooltip.ends_with("could be delusion."), "one cause stands alone")
	Terms.set_honest_causes([])
	check(terms.lookup(Terms.MISTAKEN_ID).tooltip == "Mistaken: a reading that was wrong but honestly told. Nothing in this town can fool a gift.", "with no cause in this town, it says nothing can fool a gift")
	var RCh = preload("res://workshop/reading_challenges.gd")
	check(RCh.script_honest_causes(["brute"], [], ["dowser"]) == [], "a script with no Poisoner, secrets or Seer allows no cause (a Brute, a Dowser)")
	Terms.set_honest_causes(null)
	print("Term defs: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## Burdens prototype, the UI (Herald; Michael's Nov 21 wording, docs/design/burdens_wording.md):
## the script sheet's burdens section (heading, rules text, the hidden tag, who has claimed
## each burden), the Burden and omen tooltips, the Ill-Omened board marker, and the grim
## reveal's burden tag. Presentation only: none of it moves the world's RNG.
extends SceneTree
const Game = preload("res://game/game.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const MainRoles = preload("res://ui/main_roles.gd")
const TextTerms = preload("res://ui/text_terms.gd")
const RevealPlan = preload("res://ui/reveal/reveal_plan.gd")
const C = preload("res://sim/content.gd")
const RevealOverlay = preload("res://ui/reveal/reveal_overlay.gd")
const GameScreens = preload("res://game/game_screens.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _case():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	return g

func _init() -> void:
	_rules_text()
	_claimers()
	await _sheet()
	_tooltips()
	_omen_marker()
	_reveal_tag()
	_shot_fixes()
	print("Burdens UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _rules_text() -> void:
	_check(MainRoles.burden_heading(1) == "Burdens: one in play, on top of a gift", "the sheet's heading says burdens, and how many are in play")
	_check(MainRoles.burden_heading(2) == "Burdens: 2 in play, on top of a gift", "more than one in play is counted")
	_check(" burden " in MainRoles.setup_summary(10) and not "secret" in MainRoles.setup_summary(10), "the setup summary counts burdens")
	_check(C.SECRET_MODS["unrequited"]["desc"] == "Loves one townsperson, who doesn't know. Visits their home at night, and is slow to suspect them.", "Unrequited's rules text is Michael's")
	_check(C.SECRET_MODS["ill_omened"]["desc"] == "If hanged after claiming this burden, every good person is poisoned that night until the start of the next night.", "Ill-Omened's rules text is Michael's")
	_check(C.SECRET_MODS["marked"]["desc"].ends_with("They know."), "Marked's rules text says its holder knows")

func _claimers() -> void:
	var g = _case()
	var w = g.w
	var a = w.npcs[0]
	var b = w.npcs[1]
	var c = w.npcs[2]
	w.burden_claims = {"marked": [a.id, b.id, c.id], "marked:public": [a.id]}
	w.burden_told = {"%s|player" % b.id: {"day": 1, "phase": 1}, "%s|%s" % [c.id, a.id]: {"day": 1, "phase": 1}}
	var who: Array = MainRoles.burden_claimers(w, "marked")
	_check(who == ["%s (to the town)" % a.name, "%s (told you)" % b.name], "the sheet lists a public claim and one told to you, not one told to someone else")
	_check(MainRoles.burden_claimers(w, "unrequited").is_empty(), "an unclaimed burden lists nobody")

func _sheet() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	await process_frame
	var g = _case()
	scene.g = g
	var w = g.w
	var rng = w.rng.state
	var a = w.npcs[3]
	var b = w.npcs[4]
	var kind: String = w.case_script.secrets[0] if not w.case_script.secrets.is_empty() else "marked"
	w.burden_claims = {kind: [a.id, b.id], kind + ":public": [a.id, b.id]}
	MainRoles.open(scene)
	await process_frame
	var heading_ok: bool = scene.roles_box.find_children("*", "Label", true, false).any(func(l): return l.text == MainRoles.burden_heading(w.case_script.secrets_in_play))
	_check(heading_ok, "the open sheet shows the burdens heading")
	var claims = scene.roles_box.find_child("Claims_" + kind, true, false)
	_check(claims != null and a.name in claims.text and b.name in claims.text, "a double claim shows both names on the sheet")
	if "delusional" in w.case_script.secrets:
		var d = scene.roles_box.find_child("Desc_delusional", true, false)
		_check(d != null and d.text.begins_with("Hidden: "), "the hidden burden carries its tag")
	_check(w.rng.state == rng, "the sheet moves no RNG")
	scene.queue_free()

func _tooltips() -> void:
	var terms = TextTerms.new()
	var found: Array = terms.find_matches("The script lists each Burden.")
	var marker: Array = terms.find_matches("The omen claimed by Agnes may have fallen. Agnes is Ill-Omened.")
	var tip_burden: String = ""
	var tip_omen: String = ""
	for t in preload("res://ui/term_defs.gd").MECHANICS:
		if t.id == "burden":
			tip_burden = t.tooltip
		elif t.id == "omen":
			tip_omen = t.tooltip
	_check(tip_burden == "Burden: something that weighs on a townsperson, on top of their gift. The script lists the possible burdens and how many are in play. A hidden burden's holder doesn't know they carry it.", "the Burden tooltip is Michael's")
	_check(tip_omen.ends_with(C.SECRET_MODS["ill_omened"]["desc"]), "the omen's tooltip is Ill-Omened's rules text")
	_check(found.any(func(r): return str(r.get("id", "")) == "mechanic:burden"), "Burden is a term in prose")
	_check(marker.any(func(r): return str(r.get("id", "")) == "mechanic:omen" and r.text == "omen"), "the marker's \"omen\" carries the rules-text tooltip")
	_check(marker.any(func(r): return str(r.get("id", "")) == "secret:ill_omened"), "and Ill-Omened is still its own burden term")

func _omen_marker() -> void:
	var g = _case()
	var w = g.w
	var n = w.npcs[5]
	var before: int = g.board.size()
	GameMeeting._omen_marker(g, n)
	_check(g.board.size() == before, "no marker without a claimed Ill-Omened's hanging")
	w.public_event("omen_hanged", [n.id], "world")
	var rng = w.rng.state
	GameMeeting._omen_marker(g, n)
	var cards: Array = g.board.filter(func(c): return c.get("kind", "") == "omen")
	_check(cards.size() == 1 and cards[0].get("text", "") == "The omen claimed by %s may have fallen, poisoning the town's gifts." % n.name, "the board marks a claimed Ill-Omened's hanging, in Michael's words")
	_check(cards.size() == 1 and int(cards[0].get("until_day", -1)) == w.day + 1, "the marker covers the night after and the next day")
	_check(w.rng.state == rng, "the marker moves no RNG")

func _reveal_tag() -> void:
	var g = _case()
	var w = g.w
	var n = w.npcs.filter(func(m): return not m.is_evil())[0]
	n.secret_mod = "delusional"
	var step: Dictionary = RevealPlan.step_for(g, n, {})
	_check(step["burden"] == "…and Delusional" and step["burden_name"] == "Delusional", "the reveal card's burden tag reads \"…and Delusional\"")
	var plain = w.npcs.filter(func(m): return m.secret_mod == "")[0]
	_check(RevealPlan.step_for(g, plain, {})["burden"] == "", "no burden, no tag")

## Limner's screenshots (Nov 21): the key moments sat under the paper sheet, and the
## remaining "secret" wording.
func _shot_fixes() -> void:
	var sheet_bottom: float = 0.09 + RevealOverlay.CARD_H + RevealOverlay.SHEET_PAD
	var src: String = FileAccess.get_file_as_string("res://ui/reveal/reveal_overlay.gd")
	_check("_moments.anchor_top = 0.09 + CARD_H + SHEET_PAD" in src and sheet_bottom < 0.9, "the key moments start below the reveal's paper sheet")
	_check(C.ROLES["rumormonger"]["desc"].ends_with("a particular burden."), "the Rumormonger's text says burden")
	var g = _case()
	var typed: String = GameScreens._script(g)
	_check("Burdens: one in play, on top of a gift:" in typed and not "secret " in typed.to_lower() and not "secrets" in typed.to_lower(), "the typed script heads its burdens as the sheet does")
	if "delusional" in g.w.case_script.secrets:
		_check("Hidden: " in typed, "and tags the hidden burden")
	_check(MainRoles.BURDEN_TIP.begins_with("Burden: "), "the sheet's Burdens heading carries the Burden tooltip")

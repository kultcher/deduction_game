## Secrets: Marked, Delusional, Lovers, Sleepwalker, Muddler.
## Merged from: test_chunk4_psychologist_muddler, test_roster.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Domain = preload("res://workshop/world_domain.gd")
const CardList = preload("res://ui/card_list.gd")
const Muddler = preload("res://sim/muddler.gd")
const UITheme = preload("res://ui/theme.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Solver = preload("res://workshop/solver.gd")
const Social = preload("res://sim/social.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_chunk4_psychologist_mudd()
	print("Roles: secrets: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_roster

func _run_roster() -> void:
	_test_marked_and_delusional()
	_test_sleepwalker()
	_test_lovers()
	_test_night_suspicion()


# ---------------------------------------------------------------- from test_chunk4_psychologist_muddler

func _run_chunk4_psychologist_mudd() -> void:
	_test_muddler_simulation_and_debunking()
	_test_muddler_domain_and_channel_parity()


# ---- test_roster


## Pure World setup for multi-hundred-seed role/home/bluff distribution checks.
func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _test_marked_and_delusional() -> void:
	var w = _game(9210).w
	var mk = w.living_good()[0]
	mk.secret_mod = "marked"
	var ev = 0
	for i in range(200):
		if w.registers_evil(mk):
			ev += 1
	print("Marked read as evil %d/200" % ev)
	_check(ev > 60 and ev < 140, "the Marked read as evil about half the time")
	var dl = w.living_good()[1]
	dl.secret_mod = "delusional"
	_check(dl.gift_broken(), "the Delusional's gift is broken")


func _test_sleepwalker() -> void:
	var w = _game(9220).w
	var sw = w.living_good()[0]
	sw.secret_mod = "sleepwalker"
	w.day = 1
	w.resolve_night()
	var out: bool = sw.history[w.time_key(1, C.NIGHT)].begins_with("night:")
	w.day = 2
	var r = Mind.answer_night(w, sw, 1)
	var txt = " ".join(PackedStringArray(r["lines"].map(func(l): return l["text"])))
	_check(out and "home" in txt.to_lower(), "the Sleepwalker walks, and honestly says they were home")


## Being out at night counts in full only near a death; an openly claimed walking gift
## is discounted.
func _test_lovers() -> void:
	var together = 0
	for sd in range(9230, 9250):
		var w = _game(sd).w
		var goods: Array = w.living_good()
		var a = goods[0]
		var b = goods[1]
		for n in w.npcs:
			n.secret_mod = ""
			n.lover = ""
		a.secret_mod = "lovers"
		b.secret_mod = "lovers"
		a.lover = b.id
		b.lover = a.id
		a.secret = {"kind": "lover", "with": b.id, "dest": b.home_block, "text": "slips out to meet %s in secret" % b.name}
		b.secret = {"kind": "lover", "with": a.id, "dest": a.home_block, "text": "slips out to meet %s in secret" % a.name}
		w.day = 1
		w._night_movement("", "", null, "")
		if a.out_last_night and b.out_last_night and a.night_block == b.night_block:
			together += 1
	_check(together == 20, "the Secret Lovers meet in the same place each night")


## Start-knowledge gifts already spent are worth less to kill than live ones.
func _test_night_suspicion() -> void:
	var w = _game(9260).w
	var l = w.living_good()[0]
	var x = w.living_good()[1]
	var sw_out = 0
	for sd in range(9270, 9290):
		var w2 = _game(sd).w
		var sw = w2.living_good()[0]
		for n in w2.npcs:
			n.secret_mod = ""
		sw.secret_mod = "sleepwalker"
		w2.day = 1
		w2._night_movement("", "", null, "")
		if sw.out_last_night:
			sw_out += 1
	print("Sleepwalker out %d/20 nights" % sw_out)
	_check(sw_out > 3 and sw_out < 17, "the Sleepwalker walks on some nights, not all")


# ---- test_chunk4_psychologist_muddler


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]


func _test_muddler_simulation_and_debunking() -> void:
	# 1. Roster & default script separation
	_check("muddler" in C.SECRET_MOD_LIST and "muddler" in ScriptDef.roster().secrets, "Muddler is registered in C.SECRET_MOD_LIST and ScriptDef.roster().secrets")
	_check(ScriptDef.default_script().secrets.size() == 4 and ScriptDef.default_script().is_default(), "Default script keeps 4 starter secrets with zero warnings")

	var g = Game.new()
	g.log_dir = "user://test_logs"
	var sc = ScriptDef.default_script()
	sc.secrets = ["muddler", "marked", "delusional", "sleepwalker"]
	sc.forced = ["muddler"]
	g.new_case(9404, 7, sc)
	var w = g.w
	var muddlers: Array = w.living_good().filter(func(p): return p.secret_mod == "muddler")
	_check(muddlers.size() == 1 and muddlers[0].secret.get("kind", "") != "muddler", "Forced Muddler spawns on one good townsperson who remains unaware of being Muddler")
	var mud = muddlers[0]
	var others_g: Array = w.living_good().filter(func(p): return p != mud)
	var reader = others_g[0]
	var listener = others_g[1]
	var third = others_g[2]
	_give_role(w, reader, "seer")
	reader.info_log.clear()
	var orig_e: Dictionary = {"day": 0, "role": "seer", "data": {"pair": [listener.id, third.id], "yes": false}, "true": true, "shared": false, "text": "I looked at %s and %s: neither is the demon" % [listener.name, third.name]}
	reader.info_log.append(orig_e)

	# 2. Statistical ~65% muddle rate, single-fact mutation preserving source & role, role claims untouched
	var muddle_hits: int = 0
	var trials: int = 200
	for t in range(trials):
		mud.muddled_items.clear()
		var probe_e: Dictionary = orig_e.duplicate(true)
		probe_e["day"] = t
		var out_e: Dictionary = Muddler.maybe_muddle_reading(w, mud, reader.id, probe_e)
		if out_e.get("muddled", false):
			muddle_hits += 1
			_check(out_e.get("role", "") == "seer", "Muddler preserves reading role")
			var diff_pair: bool = out_e.data.pair != probe_e.data.pair
			var diff_yes: bool = bool(out_e.data.yes) != bool(probe_e.data.yes)
			_check(diff_pair != diff_yes, "Muddler mutates exactly one fact (either pair member OR yes/no, never both)")
	_check(muddle_hits >= 100 and muddle_hits <= 160, "Muddler 65%% roll lands within expected band (%d/%d)" % [muddle_hits, trials])

	var claim_item: Dictionary = {"kind": "role_claim", "about": reader.id, "from": reader.id, "role": "seer", "key": "role_claim:" + reader.id, "relay": true}
	_check(not Muddler.maybe_muddle_item(w, mud, claim_item).get("muddled", false), "Muddler leaves role claims untouched")

	# 3. Per-item consistency across relays + private disclaimer on `ask gift`
	mud.muddled_items.clear()
	var forced_m: Dictionary = Muddler.mutate_reading_entry(w, mud, reader.id, orig_e)
	var ckey: String = Muddler._reading_cache_key(reader.id, orig_e)
	mud.muddled_items[ckey] = forced_m.duplicate(true)
	mud.hearsay.append({"kind": "reading", "entry": orig_e.duplicate(true), "from": reader.id, "via": reader.id, "day_heard": 1, "key": "reading:0:seer", "public": false})
	var g_share: Dictionary = Social.gossip_item(w, mud)
	g._facts(g_share["facts"])
	var muddled_card: Dictionary = g.board[-1]
	_check(bool(muddled_card.get("muddled", false)) and muddled_card.get("data", {}) == forced_m.data, "Muddler gossip_item emits cached muddled Via card onto g.board")

	# Private `ask gift` with low trust (tier < 4): reader ALWAYS disclaims the muddled card while withholding real reading!
	reader.trust = 0.15
	reader.max_tier = 0
	reader.claim_public = false
	var low_reply: Dictionary = Mind.answer_gift(w, reader)
	Muddler.apply_private_disclaimers(g, reader, "gift", low_reply)
	g._facts(low_reply["facts"])
	_check(bool(muddled_card.get("deprecated", false)) and str(muddled_card.get("disclaimed_by", "")) == reader.id and not bool(muddled_card.get("workshop_usable", true)), "Reader privately disclaims and deprecates muddled Via card even when withholding their real gift")
	_check(not low_reply["facts"].any(func(f): return f.get("kind") == "info"), "Low-trust reader still withholds their real reading while disclaiming the muddle")
	_check("deprecated" in CardList.line_for(muddled_card) and UITheme.card_color(muddled_card).a < 1.0, "Deprecated card renders dimmed with disclaimed label on Case Board")
	_check("deprecated" in g._presentation_rejection(muddled_card), "Presenting a deprecated muddled card is rejected with a clear message")

	# High trust (tier 4): real reading is shared and links `superseded_by` on muddled cards
	var muddled_num2: int = g.add_card({"kind": "info", "source": reader.id, "via": mud.id, "role": "seer", "day": 0, "data": forced_m.data.duplicate(true), "muddled": true, "subject": forced_m.data.pair.duplicate(), "text": "Via Muddler 2"})
	reader.trust = 0.95
	var high_reply: Dictionary = Mind.answer_gift(w, reader, 4)
	Muddler.apply_private_disclaimers(g, reader, "gift", high_reply)
	g._facts(high_reply["facts"])
	_check(bool(g.board[muddled_num2 - 1].get("deprecated", false)) and int(g.board[muddled_num2 - 1].get("superseded_by", 0)) > muddled_num2, "Disclosing the real reading deprecates the muddled card and links superseded_by to the real card")

	# 4. Public meeting relay: high reveal_cost defers debunking to pending_muddle_debunks, then _go_public includes debunk!
	var g3 = Game.new()
	g3.log_dir = "user://test_logs"
	g3.new_case(9405, 7, sc)
	var w3 = g3.w
	var g3_goods: Array = w3.living_good()
	var mud3 = g3_goods[0]
	var src3 = g3_goods[1]
	mud3.secret_mod = "muddler"
	_give_role(w3, src3, "seer")
	src3.claim_public = false
	src3.traits["privacy"] = 0.98
	src3.traits["confidence"] = 0.05
	w3.day = 1
	var real3: Dictionary = {"day": 0, "role": "seer", "data": {"pair": [g3_goods[2].id, g3_goods[3].id], "yes": false}, "true": true, "shared": false, "text": "I looked at %s and %s: neither is the demon" % [g3_goods[2].name, g3_goods[3].name]}
	src3.info_log = [real3]
	var mud_e3: Dictionary = Muddler.mutate_reading_entry(w3, mud3, src3.id, real3)
	mud3.muddled_items[Muddler._reading_cache_key(src3.id, real3)] = mud_e3.duplicate(true)

	var m_lines: Array = []
	var m_facts: Array = []
	Mind.relay_reading(w3, mud3, src3, real3, m_lines, m_facts)
	if not src3.claim_public:
		_check(not src3.pending_muddle_debunks.is_empty(), "Unclaimed high-reveal-cost source defers muddle debunk into pending_muddle_debunks")
		var pub_lines: Array = []
		var pub_facts: Array = []
		Mind._go_public(w3, src3, pub_lines, pub_facts)
		_check(src3.pending_muddle_debunks.is_empty() and pub_facts.any(func(f): return f.get("kind") == "deprecate_muddle"), "Deferred muddle debunk fires when source later goes public")
	else:
		_check(m_facts.any(func(f): return f.get("kind") == "deprecate_muddle"), "Revealing source immediately debunks muddled public relay")


func _test_muddler_domain_and_channel_parity() -> void:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var view: Dictionary = {
		"people": people,
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
	}
	var worlds: Array = Domain.worlds(view)
	# 7 people, 2 evil (21 teams * 2 demons = 42): per team, over the 5 good people,
	# delusional 5 + marked 5 + lovers C(5,2)=10 + sleepwalker 5 + muddler 5 = 30 layouts -> 42 * 30 = 1260 worlds
	_check(worlds.size() == 1260, "WorldDomain enumerates exact 1,260 worlds with all 5 secrets including Muddler")
	var keys: Dictionary = {}
	for w in worlds:
		keys[Domain.key(view, w)] = true
	_check(keys.size() == worlds.size(), "WorldDomain * 5 radix produces collision-free 64-bit keys across all 5 secret modifiers")

	var rumor_muddler: Dictionary = {
		"id": "rm_mud", "fact_id": "rm_mud", "kind": "report", "role": "rumormonger", "source": people[0].id,
		"observed_at": {"day": 0, "phase": "night"},
		"data": {"pair": [people[1].id, people[2].id], "secret": "muddler"},
		"text": "Rumormonger muddler pair",
	}
	var c_mud = Solver.empty_case()
	c_mud.conclusion = {"type": "secret_mod", "target": people[1].id, "mod": "muddler", "at": "Original alignment"}
	c_mud.cards = ["rm_mud"]
	view["cards"] = [rumor_muddler]
	var ev_mud: Dictionary = CaseEval.evaluate(view, c_mud)
	_check(ev_mud.posterior > ev_mud.prior and ev_mud.lr > 3.0, "CaseEval evaluates secret_mod='muddler' premise from a Rumormonger Muddler report")

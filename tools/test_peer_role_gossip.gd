## Meeting plan M1: peer role hints and role claims (sim/social.gd).
##   - A gift with no readings (empty info_log) can still be claimed to a close friend,
##     and the listener records it (known_claims with first_claimed_day, a claim receipt).
##   - Evil runs the same formulas with its agreed bluff (a lie the listener can't tell).
##   - Moderate bond gives only a hint (the gift's family), no claim on record.
##   - A Warden who promised protection (protect_lock) keeps the claim to themself.
##   - Private gift talk is never echoed back or relayed peer to peer.
##   - The player can hear a second-hand claim or hint (gossip, ask about a role).
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Mind = preload("res://sim/mind.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_claim_without_readings()
	_test_evil_bluff_claim()
	_test_hint_only_at_moderate_bond()
	_test_protect_lock_withholds_claim()
	_test_no_echo_or_relay()
	_test_player_hears_second_hand()
	_test_opinion_mentions_second_hand()
	print("Peer role gossip: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _game(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	return g


## Make `s` open with `l`: trusting, not private, unclaimed, nothing else to say.
func _prime(w, s, l, bond: float) -> void:
	s.npc_trust[l.id] = bond
	s.traits["privacy"] = 0.0
	s.traits["gossip"] = 0.0
	s.claim_public = false
	s.protect_lock = false
	s.pressure = 0.0
	s.info_log = []
	s.secret = {}
	s.known_secrets = {}
	s.hearsay = []
	s.player_cases = []
	s.beliefs = []
	for p in w.npcs:
		s.suspicion[p.id] = 0.1


func _pick_kind(w, s, l, kind: String, tries: int = 80) -> Variant:
	for i in range(tries):
		var item = Social._pick_item(w, s, l)
		if item != null and item["kind"] == kind:
			return item
	return null


func _kind_counts(w, s, l, tries: int = 300) -> Dictionary:
	var seen: Dictionary = {}
	for i in range(tries):
		var item = Social._pick_item(w, s, l)
		if item != null:
			seen[item["kind"]] = seen.get(item["kind"], 0) + 1
	return seen


func _kinds_offered(w, s, l, tries: int = 80) -> Dictionary:
	var seen: Dictionary = {}
	for i in range(tries):
		var item = Social._pick_item(w, s, l)
		if item != null:
			seen[item["kind"]] = true
	return seen


func _good_pair(w, role_pref: Array) -> Array:
	var goods: Array = w.living_good()
	var picks: Array = []
	for r in role_pref:
		picks.append_array(goods.filter(func(n): return n.role == r))
	picks.append_array(goods.filter(func(n): return C.package_of(n.role) != ""))
	var s = picks[0]
	var l = goods.filter(func(x): return x != s)[0]
	return [s, l]


func _test_claim_without_readings() -> void:
	var g = _game(7101)
	var w = g.w
	var pr: Array = _good_pair(w, ["warden", "martyr", "veteran", "sexton"])
	var s = pr[0]
	var l = pr[1]
	_prime(w, s, l, 0.95)
	var item = _pick_kind(w, s, l, "role_claim")
	_check(item != null and item.get("role", "") == s.role and not item.get("lie", true),
		"a close friend can claim a gift with no readings (%s, empty info_log)" % s.role)
	if item == null:
		return
	w.day = 2
	Social._deliver(w, s, l, item)
	var kc: Dictionary = l.known_claims.get(s.id, {})
	_check(kc.get("role", "") == s.role and kc.get("via", "") == s.id and int(kc.get("first_claimed_day", -1)) == 2,
		"the listener records the private claim with first_claimed_day")
	var receipt: bool = l.ledger.keys().any(func(k): return str(k).begins_with("claim:") and s.id in str(k))
	_check(receipt, "the claim enters the listener's ledger as a claim receipt (hear_claim)")
	_check(l.hearsay.any(func(h): return h["kind"] == "role_claim" and h["from"] == s.id), "the listener remembers who told them")
	# A second, later claim keeps the first day it was heard.
	w.day = 3
	s.told_to.erase(l.id + "|role_claim:" + s.id)
	l.known_claims[s.id]["role"] = "nobody"
	Social._deliver(w, s, l, item)
	_check(int(l.known_claims[s.id].get("first_claimed_day", -1)) == 2, "first_claimed_day keeps the earliest day")


func _test_evil_bluff_claim() -> void:
	var g = _game(7102)
	var w = g.w
	var bluffers: Array = w.evil_team().filter(func(n): return C.ROLES.has(str(w.evil_plan["bluffs"].get(n.id, ""))))
	_check(not bluffers.is_empty(), "an evil member with a bluff exists")
	if bluffers.is_empty():
		return
	var e = bluffers[0]
	var l = w.living_good()[0]
	_prime(w, e, l, 0.95)
	var bluff: String = w.evil_plan["bluffs"][e.id]
	var item = _pick_kind(w, e, l, "role_claim")
	_check(item != null and item["role"] == bluff and item.get("lie", false), "evil claims its bluff with the same formulas (a lie)")
	if item != null:
		Social._deliver(w, e, l, item)
		_check(l.known_claims.get(e.id, {}).get("role", "") == bluff, "the good listener records the bluff as a claim")


## One roll since Nov 8 (Social._gift_disclosure): the same openness score as answering the
## Demonologist picks nothing, a hint or the gift, so trust and pressure shift the odds.
func _test_hint_only_at_moderate_bond() -> void:
	var g = _game(7103)
	var w = g.w
	w.day = 2   # past the day-1 confidant window
	var pr: Array = _good_pair(w, ["seer", "warden", "clerk"])
	var s = pr[0]
	var l = pr[1]
	_prime(w, s, l, 0.5)
	s.traits["privacy"] = 0.5
	var kinds: Dictionary = _kind_counts(w, s, l)
	_check(kinds.get("role_hint", 0) > kinds.get("role_claim", 0), "at moderate bond a hint is likelier than the gift (%s)" % str(kinds))
	var item = _pick_kind(w, s, l, "role_hint")
	if item != null:
		Social._deliver(w, s, l, item)
		_check(not l.known_claims.has(s.id) and l.hearsay.any(func(h): return h["kind"] == "role_hint" and h["package"] == C.package_of(s.role)),
			"a hint is remembered by family, with no claim on record")
	s.told_to.erase(l.id + "|role_hint:" + s.id)
	l.hearsay = []
	var calm: Dictionary = _kind_counts(w, s, l)
	s.pressure = 1.0
	var pressed: Dictionary = _kind_counts(w, s, l)
	_check(pressed.get("role_claim", 0) > calm.get("role_claim", 0), "pressure makes the gift itself likelier (%s vs %s)" % [str(pressed), str(calm)])
	s.pressure = 0.0
	_prime(w, s, l, 0.1)
	s.traits["privacy"] = 0.5
	var low: Dictionary = _kind_counts(w, s, l)
	_check(low.get("role_claim", 0) == 0 and low.get("role_hint", 0) < kinds.get("role_hint", 0), "low bond: no gift, and fewer hints (%s)" % str(low))


func _test_protect_lock_withholds_claim() -> void:
	var g = _game(7104)
	var w = g.w
	var pr: Array = _good_pair(w, ["warden"])
	var s = pr[0]
	var l = pr[1]
	_prime(w, s, l, 0.95)
	s.protect_lock = true
	_check(not _kinds_offered(w, s, l).has("role_claim"), "a Warden who promised protection keeps the claim to themself")
	s.claim_public = true
	s.protect_lock = false
	var pub: Dictionary = _kinds_offered(w, s, l)
	_check(not pub.has("role_claim") and not pub.has("role_hint"), "a public claimant has no private gift news")


func _test_no_echo_or_relay() -> void:
	var g = _game(7105)
	var w = g.w
	var pr: Array = _good_pair(w, ["warden", "seer"])
	var s = pr[0]
	var l = pr[1]
	_prime(w, s, l, 0.95)
	var item = _pick_kind(w, s, l, "role_claim")
	if item == null:
		_check(false, "setup: a claim to relay")
		return
	Social._deliver(w, s, l, item)
	var third = w.living_good().filter(func(x): return x != s and x != l)[0]
	_prime(w, l, s, 0.95)
	l.hearsay = [l.hearsay.back()] if not l.hearsay.is_empty() else []
	var back: bool = false
	for i in range(80):
		var it = Social._pick_item(w, l, s)
		if it != null and it.get("from", "") == s.id and it["kind"] in ["role_claim", "role_hint"]:
			back = true
	_check(not back, "a claim is never echoed back to the one who made it")
	l.npc_trust[third.id] = 0.95
	var relayed: bool = false
	for i in range(80):
		var it = Social._pick_item(w, l, third)
		if it != null and it.get("relay", false) and it["kind"] in ["role_claim", "role_hint"]:
			relayed = true
	_check(not relayed, "private gift talk isn't relayed peer to peer")


func _test_player_hears_second_hand() -> void:
	var g = _game(7106)
	var w = g.w
	var pr: Array = _good_pair(w, ["warden", "martyr", "seer"])
	var s = pr[0]
	var l = pr[1]
	_prime(w, s, l, 0.95)
	var item = _pick_kind(w, s, l, "role_claim")
	if item == null:
		_check(false, "setup: a claim for the player to hear")
		return
	Social._deliver(w, s, l, item)
	l.known_secrets = {}
	var got: Dictionary = Social.gossip_item(w, l)
	var f: Array = got.get("facts", [])
	_check(not f.is_empty() and f[0].get("kind", "") == "claim" and f[0].get("role", "") == s.role and f[0].get("via", "") == l.id and f[0].get("private", false),
		"gossip passes the private claim on to the player as a second-hand claim card")
	_check(not got.lines.is_empty() and not ("[PH]" in str(got.lines[0].get("text", ""))), "the gossip line is voiced")
	var again: Dictionary = Social.gossip_item(w, l)
	_check(again.get("facts", []).is_empty() or again.facts[0].get("role", "") != s.role or again.facts[0].get("kind", "") != "claim",
		"the same second-hand claim isn't told to the player twice")
	l.traits["gossip"] = 1.0
	l.trust = 1.0
	l.pressure = 1.0
	var asked: Dictionary = Social.answer_about_role(w, l, s.role)
	_check(asked.facts.any(func(x): return x.get("kind", "") == "claim" and s.id in x.get("subject", [])),
		"asking about the %s surfaces the second-hand private claim" % s.role)


func _test_opinion_mentions_second_hand() -> void:
	var g = _game(7107)
	var w = g.w
	var pr: Array = _good_pair(w, ["warden", "martyr", "seer"])
	var s = pr[0]
	var l = pr[1]
	_prime(w, s, l, 0.95)
	var item = _pick_kind(w, s, l, "role_claim")
	if item == null:
		_check(false, "setup: a claim for the opinion note")
		return
	Social._deliver(w, s, l, item)
	l.traits["gossip"] = 1.0
	l.trust = 1.0
	l.pressure = 1.0
	var op: Dictionary = Mind.answer_opinion(w, l, s)
	_check(op.facts.any(func(x): return x.get("kind", "") == "claim" and x.get("via", "") == l.id and s.id in x.get("subject", [])),
		"asking about someone surfaces the private claim they made to the speaker")
	var op2: Dictionary = Mind.answer_opinion(w, l, s)
	_check(not op2.facts.any(func(x): return x.get("kind", "") == "claim" and s.id in x.get("subject", [])),
		"the second-hand claim isn't repeated on a second ask")
	l.traits["gossip"] = 0.0
	l.trust = 0.0
	l.pressure = 0.0
	l.told_to.erase("player|role_claim:" + s.id)
	var shy: Dictionary = Mind.answer_opinion(w, l, s)
	_check(not shy.facts.any(func(x): return x.get("kind", "") == "claim"), "an unwilling speaker keeps it to themself")

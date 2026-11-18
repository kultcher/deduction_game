## The regression guard for #265's bug (Michael, Nov 18: kept alongside the hand-built
## test_relay_bluff): in played games, an evil relayer's relays don't clear them. Before #265 a
## relayed card counted its dead original as a teller too, so the two-sighter cap could drop the
## relayer from the sighter contest and its invented relay was weighed as the dead's honest
## word (seeds 929 and 100029: Hollis 0.83 -> 0.46 with his relays). The hand-built towns in
## test_relay_bluff don't reach that case (Nov 18: a crowded contest, with and without prior
## suspicion, gave the same numbers before and after #265), so these games are searched for.
##
## A seed search, so a change to play can move it onto another game; it runs on main with the
## full list, not on the fast list. Measured on the relays alone: the relayer's chance with
## every held card against the same refresh with its relays left out (Seeds.relay_effect).
##   godot --headless --path . --script res://tools/test_relay_bluff_games.gd
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var evil_relayer = func(t): return t.is_evil()
	var first: Dictionary = Seeds.relay(4, evil_relayer)
	_relay_case(first, "an evil relayer's relays don't clear them")
	if not first.is_empty():
		# Another game, from the next seed on, at the same day.
		_relay_case(Seeds.relay(4, evil_relayer, false, int(first.seed) + 1), "nor in another game")
	print("Relay bluff games: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## The relayer's chance with every held card isn't more than 5 points below the same refresh
## with its relays left out.
func _relay_case(found: Dictionary, label: String) -> void:
	if found.is_empty():
		check(false, "%s (no seed searched has the case)" % label)
		return
	var eff: Dictionary = Seeds.relay_effect(found.g, str(found.listener), str(found.teller))
	var with_r: float = float(eff.get("with", -1.0))
	var without: float = float(eff.get("without", -1.0))
	check(not eff.is_empty() and with_r >= without - 0.05, "%s (seed %d: %s on %s, %.2f with the relays, %.2f without)" % [label, int(found.seed), found.listener, found.teller, with_r, without])

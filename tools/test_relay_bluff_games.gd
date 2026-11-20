## The regression guard for #265's bug (Michael, Nov 18: kept alongside the hand-built
## test_relay_bluff): in played games, an evil relayer's relays don't clear them. Before #265 a
## relayed card counted its dead original as a teller too, so the two-sighter cap could drop the
## relayer from the sighter contest and its invented relay was weighed as the dead's honest
## word (seeds 929 and 100029: Hollis 0.83 -> 0.46 with his relays). The hand-built towns in
## test_relay_bluff don't reach that case (Nov 18: a crowded contest, with and without prior
## suspicion, gave the same numbers before and after #265), so these games are searched for.
##
## A seed search, so a change to play can move it onto another game; it runs on main with the
## full list, not on the fast list. Measured on the relays alone (Seeds.relay_effect): the
## relayer's chance with every held card, against the same refresh with the relays recast as
## the relayer's own firsthand sightings. The bug weighed a relay as the dead's honest word, so
## it cleared the relayer more than its own word would; a relay counts as the relayer's word,
## no more. Nov 19 (seed 100031, found once #292 moved the search): the check was "no lower than
## with the relays left out", but a relay blaming someone else for a killing lowers its teller
## as far as the listener believes it, as a firsthand sighting would. There Greta, the Demon,
## relays the dead Agnes seeing Dorian at her door the night Greta killed her: Edda's chance of
## Greta 0.50 without it, 0.35 with it, 0.35 as Greta's own sighting, 0.33 as Agnes's own word.
## That is a lie believed in part, which is play; the check is whether the relay launders it.
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


## The relayer's chance with every held card isn't more than 2 points below the same refresh
## with its relayed sightings told as its own, and isn't lower than with its relayed readings
## left out.
func _relay_case(found: Dictionary, label: String) -> void:
	if found.is_empty():
		check(false, "%s (no seed searched has the case)" % label)
		return
	var eff: Dictionary = Seeds.relay_effect(found.g, str(found.listener), str(found.teller))
	var with_r: float = float(eff.get("with", -1.0))
	var without: float = float(eff.get("without", -1.0))
	var firsthand: float = float(eff.get("firsthand", -1.0))
	var readings_without: float = float(eff.get("readings_without", -1.0))
	# Relayed sightings against the relayer's own word; relayed readings against leaving them
	# out (Lantern, Nov 20: recasting a relayed Gravedigger reading as the relayer's own made
	# a role clash, seed 100009). Either alone is checked only if the relays include it.
	var sight_ok: bool = int(eff.get("sightings", 0)) == 0 or (firsthand >= 0.0 and with_r >= firsthand - 0.02)
	var read_ok: bool = int(eff.get("readings", 0)) == 0 or (readings_without >= 0.0 and with_r >= readings_without - 0.01)
	check(not eff.is_empty() and sight_ok and read_ok, "%s (seed %d: %s on %s, %.2f with the relays, %.2f with the sightings as its own, %.2f with the readings left out, %.2f without; %d sightings, %d readings relayed)" % [label, int(found.seed), found.listener, found.teller, with_r, firsthand, readings_without, without, int(eff.get("sightings", 0)), int(eff.get("readings", 0))])

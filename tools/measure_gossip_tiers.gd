## Graded gossip: how much of each value tier the tavern tells today, and how much there is to
## tell (Michael, Nov 19; tiers drafted Nov 20, Social.gossip_tier). For each evening of each
## game it reads what tavern_evening_gossip would give the player (it draws its own seeded
## numbers and changes nothing in the world), and counts the tiers told and offered, against
## TAVERN_TIER1_TARGET and TAVERN_TIER2_TARGET.
##   godot --headless --path . --script res://tools/measure_gossip_tiers.gd -- --seed 1 --games 40 --npcs 10
extends SceneTree

const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Tuning = preload("res://sim/tuning.gd")

func _init() -> void:
	var args: Dictionary = {"seed": 1, "games": 40, "npcs": 10, "days": 5}
	var raw: Array = OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[str(raw[i]).trim_prefix("--")] = int(raw[i + 1])
	# The approved targets (Michael, Nov 19).
	var t1: int = Tuning.Social.TAVERN_TIER1_TARGET
	var t2: int = Tuning.Social.TAVERN_TIER2_TARGET
	var evenings: int = 0
	var told: Array = [0, 0, 0, 0]
	var offered: Array = [0, 0, 0, 0]
	var hit1: int = 0
	var hit2: int = 0
	var both: int = 0
	var could1: int = 0
	var could_both: int = 0
	for sd in range(int(args.seed), int(args.seed) + int(args.games)):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(sd, int(args.npcs))
		var guard := 0
		var last_day := -1
		while g.state != "over" and guard < 2000 and g.w.day <= int(args.days):
			guard += 1
			if g.state == "meeting" and g.w.day != last_day:
				last_day = g.w.day
				var before: int = g.w.dlog.entries.size()
				Social.tavern_evening_gossip(g)
				var logged: Array = g.w.dlog.entries.slice(before).filter(func(e): return e["type"] == "tavern_evening_gossip")
				if not logged.is_empty():
					var d: Dictionary = logged[0]["data"]
					evenings += 1
					var c: Array = [0, 0, 0, 0]
					for t in d.get("tiers", []):
						told[int(t)] += 1
						c[int(t)] += 1
					var o: Array = [0, 0, 0, 0]
					for t in d.get("offered_tiers", []):
						offered[int(t)] += 1
						o[int(t)] += 1
					hit1 += 1 if c[1] >= t1 else 0
					hit2 += 1 if c[2] >= t2 else 0
					both += 1 if (c[1] >= t1 and c[2] >= t2) else 0
					could1 += 1 if o[1] >= t1 else 0
					could_both += 1 if (o[1] >= t1 and o[2] >= t2) else 0
			match g.state:
				"approach": g.command("decline")
				"day": g.command("wait")
				"meeting": g.command("done" if g.town_quiet else "wait")
				"talk": g.command("bye")
				"nomination": g.command("vote no")
				_: g.command("wait")
	var e: float = maxf(1.0, float(evenings))
	print("GOSSIP_TIERS games=%d npcs=%d evenings=%d targets tier1>=%d tier2>=%d" % [int(args.games), int(args.npcs), evenings, t1, t2])
	print("told per evening: tier1 %.2f tier2 %.2f tier3 %.2f" % [told[1] / e, told[2] / e, told[3] / e])
	print("offered per evening: tier1 %.2f tier2 %.2f tier3 %.2f" % [offered[1] / e, offered[2] / e, offered[3] / e])
	print("evenings meeting tier1 target %.0f%%, tier2 %.0f%%, both %.0f%%" % [100.0 * hit1 / e, 100.0 * hit2 / e, 100.0 * both / e])
	print("evenings where the offer could meet tier1 %.0f%%, both %.0f%%" % [100.0 * could1 / e, 100.0 * could_both / e])
	quit()

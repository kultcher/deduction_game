## Prints every voice's answer to "ask about <person>" across suspicion, word-credit and
## bond combinations, for proofreading. Reads no saved state; changes nothing it reports.
## godot --headless --path . --script res://tools/opinion_preview.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

const CASES = [
	["clear", 0.1, "", 1.0],
	["fine", 0.3, "", 1.0],
	["doubt", 0.6, "", 1.0],
	["accuse", 0.9, "", 1.0],
	["clear, word doubted", 0.1, "", 0.6],
	["friend, clear", 0.1, "friend", 1.0],
	["friend, doubt", 0.6, "friend", 1.0],
	["friend, accuse", 0.9, "friend", 1.0],
	["rival, clear", 0.1, "rival", 1.0],
	["rival, doubt", 0.6, "rival", 1.0],
	["rival, accuse", 0.9, "rival", 1.0],
	["rival, clear, word doubted", 0.1, "rival", 0.6],
]

func _init() -> void:
	var done = {}
	var seed = 1
	while done.size() < 15 and seed < 60:
		var g = Game.new()
		g.detailed_logging = false
		g.log_dir = "user://opinion_preview"
		g.new_case(seed, 10)
		var w = g.w
		for n in w.npcs:
			if done.has(n.id):
				continue
			done[n.id] = true
			var t = w.npcs.filter(func(m): return m != n)[0]
			n.alignment = "good"
			print("\n=== %s (about %s) ===" % [n.name, t.name])
			for c in CASES:
				n.friends.erase(t.id)
				n.rivals.erase(t.id)
				n.npc_trust[t.id] = 0.5
				if c[2] == "friend":
					n.friends.append(t.id)
					n.npc_trust[t.id] = 0.75
				elif c[2] == "rival":
					n.rivals.append(t.id)
					n.npc_trust[t.id] = 0.25
				n.suspicion[t.id] = c[1]
				n.honesty[t.id] = c[3]
				n.dialogue_memory = {}
				Mind.Dialogue.begin_conversation(n.dialogue_memory)
				var reply = Mind.answer_opinion(w, n, t)
				print("  [%s] %s" % [c[0], reply.lines[0].text])
		seed += 1
	quit()

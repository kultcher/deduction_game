## Play a case in the terminal.
##   godot --headless --path . --script res://tools/cli.gd -- [--seed N] [--npcs 7] [--log-dir DIR] [--debug] [--echo-log]
## Type commands at the prompt; 'quit' to exit (writes the dev log).
extends SceneTree

const Game = preload("res://game/game.gd")

func _init() -> void:
	var args = _parse(OS.get_cmdline_user_args())
	var seed_v: int = int(args.get("seed", str(Time.get_ticks_usec() % 100000)))
	var g = Game.new()
	g.log_dir = ProjectSettings.globalize_path(args.get("log-dir", "res://logs"))
	g.debug = args.has("debug")
	print(g.new_case(seed_v, int(args.get("npcs", "7"))))
	if args.has("echo-log"):
		g.w.dlog.echo = true
	while true:
		printraw("\n> ")
		var line = OS.read_string_from_stdin(4096).strip_edges()
		if line == "quit" or line == "exit":
			print(g.command("log"))
			break
		if line == "":
			if _eof_count() > 50:
				break
			continue
		_empty = 0
		print(g.command(line))
	quit()

var _empty = 0
func _eof_count() -> int:
	_empty += 1
	return _empty

static func _parse(argv: PackedStringArray) -> Dictionary:
	var out = {}
	var i = 0
	while i < argv.size():
		var a = argv[i]
		if a.begins_with("--"):
			var k = a.substr(2)
			if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
				out[k] = argv[i + 1]
				i += 1
			else:
				out[k] = "true"
		i += 1
	return out

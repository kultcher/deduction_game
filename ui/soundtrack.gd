## Background music (Nov 8, with Michael): one soundtrack from launch to close, ignoring game
## events for now. The two "Whispers in the Town Square" tracks play whole, one after the
## other (A, then the darker B, then A again...). Each track fades out on its own; the next
## one starts a few seconds before the end so they overlap through the tail instead of
## leaving a gap. Volume lives in user://settings.cfg under [audio] (music_volume_db,
## music_enabled) and plays through a "Music" bus so a slider can be added later.
## Headless runs (tests, sweeps, golden captures) stay silent and never load the streams.
extends Node

const TRACKS: Array[String] = [
	"res://assets/audio/music/town_square_a.ogg",
	"res://assets/audio/music/town_square_b.ogg",
]
const BUS := "Music"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_VOLUME_DB := -10.0
## Seconds of overlap: the next track starts while the current one is in its fade-out.
const OVERLAP := 6.0
## Fade-in at launch so the music doesn't start at full volume.
const LAUNCH_FADE := 3.0

var enabled: bool = true
var volume_db: float = DEFAULT_VOLUME_DB
var players: Array[AudioStreamPlayer] = []
var current: int = -1  # index into players of the one now leading
var track: int = -1  # index into TRACKS of the leading track


static func next_track(i: int, count: int) -> int:
	return (i + 1) % count


static func should_start_next(position: float, length: float, overlap: float) -> bool:
	return length > 0.0 and position >= length - overlap


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_load_settings()
	_ensure_bus()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		players.append(p)
	if enabled:
		_play(0)
		var tw := create_tween()
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), -60.0)
		tw.tween_method(_set_bus_db, -60.0, volume_db, LAUNCH_FADE)
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if current < 0:
		return
	var p := players[current]
	if not p.playing:
		# Missed the overlap window (e.g. the window was paused): just move on.
		_play(next_track(track, TRACKS.size()))
		return
	if should_start_next(p.get_playback_position(), p.stream.get_length(), OVERLAP):
		_play(next_track(track, TRACKS.size()))


func _play(i: int) -> void:
	var stream := load(TRACKS[i]) as AudioStream
	if stream == null:
		push_warning("Soundtrack: can't load " + TRACKS[i])
		set_process(false)
		return
	current = 0 if current != 0 else 1
	track = i
	var p := players[current]
	p.stream = stream
	p.play()  # the other player, if still going, plays out its fade-out tail


func set_volume_db(db: float) -> void:
	volume_db = db
	_set_bus_db(db)
	_save_settings()


func set_enabled(on: bool) -> void:
	enabled = on
	if on and current < 0:
		_play(0)
		set_process(true)
	elif not on:
		for p in players:
			p.stop()
		current = -1
		set_process(false)
	_save_settings()


func _set_bus_db(db: float) -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, volume_db)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = bool(cfg.get_value("audio", "music_enabled", true))
		volume_db = float(cfg.get_value("audio", "music_volume_db", DEFAULT_VOLUME_DB))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other sections ([vn] etc.)
	cfg.set_value("audio", "music_enabled", enabled)
	cfg.set_value("audio", "music_volume_db", volume_db)
	cfg.save(SETTINGS_PATH)

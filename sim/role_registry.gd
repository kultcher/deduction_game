## Central registry of RoleDef instances.
##
## Roles registered here delegate their simulation, AI, and reading-shape hooks to
## `sim/roles/<role>.gd`. Unregistered roles fall back to legacy match blocks until
## migrated, allowing incremental verification.
extends RefCounted

const SeerDef = preload("res://sim/roles/seer.gd")
const WardenDef = preload("res://sim/roles/warden.gd")
const ClerkDef = preload("res://sim/roles/clerk.gd")
const ArchivistDef = preload("res://sim/roles/archivist.gd")
const GravediggerDef = preload("res://sim/roles/gravedigger.gd")
const DowserDef = preload("res://sim/roles/dowser.gd")
const HearthwitchDef = preload("res://sim/roles/hearthwitch.gd")
const MediumDef = preload("res://sim/roles/medium.gd")

static var _defs: Dictionary = {}
static var _initialized: bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	for script in [SeerDef, WardenDef, ClerkDef, ArchivistDef, GravediggerDef, DowserDef, HearthwitchDef, MediumDef]:
		var def = script.new()
		_defs[def.id] = def


static func get_def(role_id: String):
	_ensure_init()
	return _defs.get(role_id, null)


static func has_def(role_id: String) -> bool:
	_ensure_init()
	return _defs.has(role_id)


static func all_defs() -> Dictionary:
	_ensure_init()
	return _defs

## Registry of migrated RoleDef instances.
##
## Roles registered here delegate their simulation, AI, and reading-shape hooks to
## their `sim/roles/<role>.gd` script. Unmigrated roles return `null` from `get_def()`
## so callers can fall back incrementally during migration.
extends RefCounted

const SeerDef = preload("res://sim/roles/seer.gd")
const WardenDef = preload("res://sim/roles/warden.gd")
const ClerkDef = preload("res://sim/roles/clerk.gd")
const ArchivistDef = preload("res://sim/roles/archivist.gd")
const GravediggerDef = preload("res://sim/roles/gravedigger.gd")

static var _defs: Dictionary = {}


static func _ensure_init() -> void:
	if not _defs.is_empty():
		return
	for inst in [SeerDef.new(), WardenDef.new(), ClerkDef.new(), ArchivistDef.new(), GravediggerDef.new()]:
		_defs[inst.id] = inst


static func has_def(role: String) -> bool:
	_ensure_init()
	return _defs.has(role)


static func get_def(role: String):
	_ensure_init()
	return _defs.get(role, null)


static func all_defs() -> Dictionary:
	_ensure_init()
	return _defs

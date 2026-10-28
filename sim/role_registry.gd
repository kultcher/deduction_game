## Central registry of RoleDef instances.
##
## Every role in `C.ROLES` is registered here and delegates its simulation, AI, and
## reading-shape hooks to `sim/roles/<role>.gd`.
extends RefCounted

const SeerDef = preload("res://sim/roles/seer.gd")
const WardenDef = preload("res://sim/roles/warden.gd")
const ClerkDef = preload("res://sim/roles/clerk.gd")
const ArchivistDef = preload("res://sim/roles/archivist.gd")
const GravediggerDef = preload("res://sim/roles/gravedigger.gd")
const DowserDef = preload("res://sim/roles/dowser.gd")
const HearthwitchDef = preload("res://sim/roles/hearthwitch.gd")
const MediumDef = preload("res://sim/roles/medium.gd")
const SurveyorDef = preload("res://sim/roles/surveyor.gd")
const LamplighterDef = preload("res://sim/roles/lamplighter.gd")
const NightWatchDef = preload("res://sim/roles/nightwatch.gd")
const RumormongerDef = preload("res://sim/roles/rumormonger.gd")
const PsychologistDef = preload("res://sim/roles/psychologist.gd")
const VeteranDef = preload("res://sim/roles/veteran.gd")
const MartyrDef = preload("res://sim/roles/martyr.gd")
const SextonDef = preload("res://sim/roles/sexton.gd")
const DemonDef = preload("res://sim/roles/demon.gd")
const PoisonerDef = preload("res://sim/roles/poisoner.gd")
const BreathstealerDef = preload("res://sim/roles/breathstealer.gd")
const RevenantDef = preload("res://sim/roles/revenant.gd")
const ScionDef = preload("res://sim/roles/scion.gd")

static var _defs: Dictionary = {}
static var _initialized: bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	for script in [
		SeerDef, WardenDef,
		ClerkDef, ArchivistDef, GravediggerDef,
		DowserDef, HearthwitchDef, MediumDef,
		SurveyorDef, LamplighterDef, NightWatchDef,
		RumormongerDef, PsychologistDef, VeteranDef, MartyrDef, SextonDef,
		DemonDef, PoisonerDef, BreathstealerDef, RevenantDef, ScionDef,
	]:
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

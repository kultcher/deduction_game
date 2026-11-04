## A case's script: the town roles, minions, demons and secrets that may be in play.
## Public, like a Clocktower script: everyone (player and NPCs) knows what is on it, and
## evil never bluffs a role that isn't. The case deals its roles from it (World._assign_roles).
##
## Size: 15 town, 4 minions, 4 secrets, 1-4 demons (one Demon is always dealt). Smaller
## scripts are allowed (an exclusion drops a role) as long as every town size can be dealt;
## anything else only warns. Saved as JSON (`to_dict` / `from_dict`).
extends RefCounted

const C = preload("res://sim/content.gd")
const Registry = preload("res://sim/role_registry.gd")

const TOWN_SIZE = 15
const MINION_SIZE = 4
const SECRET_SIZE = 4
const MAX_DEMONS = 4
const DEFAULT_NAME = "Default"
const USER_DIR = "user://scripts"

## Soft coverage the editor suggests: at least this many town roles with the tag.
const SUGGESTED_TAGS = {
	"first_night_info": 2,
	"ongoing_info": 3,
	"evil_id": 2,
	"demon_id": 1,
	"role_id": 1,
	"protection": 1,
	"night_walker": 1,
}
const TAG_NAMES = {
	"first_night_info": "First-night info",
	"ongoing_info": "Ongoing info",
	"evil_id": "Evil ID",
	"demon_id": "Demon ID",
	"role_id": "Role ID",
	"protection": "Protection",
	"night_walker": "Night-walker",
}

var name: String = DEFAULT_NAME
var town: Array = []
var minions: Array = []
var demons: Array = []
var secrets: Array = []
## Custom games / debug: roles and secrets that must be dealt (they must be on the script).
var forced: Array = []


## Today's script: the whole ready roster, in the order the deal has always used.
static func default_script():
	var s = new()
	s.name = DEFAULT_NAME
	s.town = C.GOOD_ROLES.duplicate()
	s.minions = C.MINION_ROLES.duplicate()
	s.demons = ["demon"]
	s.secrets = C.SECRET_MOD_LIST.duplicate()
	return s


func duplicate_script():
	return from_dict(to_dict())


func is_default() -> bool:
	return forced.is_empty() and town == C.GOOD_ROLES and minions == C.MINION_ROLES \
		and demons == ["demon"] and secrets == C.SECRET_MOD_LIST


func has(id: String) -> bool:
	return id in town or id in minions or id in demons or id in secrets


## Beginner scripts have only the default Demon; Advanced ones list more demon types.
func mode() -> String:
	return "Advanced" if demons.size() > 1 else "Beginner"


func forced_in(list: Array) -> Array:
	return forced.filter(func(r): return r in list)


# ---------------------------------------------------------------- roster

## Every role that could go on a script, by side: {town, minions, demons, secrets}.
## Benched roles are left out; experimental ones are offered and marked.
static func roster() -> Dictionary:
	var out = {"town": [], "minions": [], "demons": [], "secrets": C.SECRET_MOD_LIST.duplicate()}
	var ids: Array = C.GOOD_ROLES.duplicate()
	for id in Registry.all_defs().keys():
		if not id in ids:
			ids.append(id)
	for id in ids:
		var d = Registry.get_def(id)
		if d == null or d.status == "benched":
			continue
		if d.align == "good":
			out.town.append(id)
		elif d.minion:
			out.minions.append(id)
		else:
			out.demons.append(id)
	for id in C.MINION_ROLES:
		if not id in out.minions:
			out.minions.append(id)
	return out


static func tags_of(id: String) -> Array:
	var d = Registry.get_def(id)
	return d.tags if d != null else []


static func display(id: String) -> String:
	return C.secret_name(id) if C.SECRET_MODS.has(id) else C.role_name(id)


# ---------------------------------------------------------------- checks

## {errors: [String], warnings: [String]}. Errors stop the case from being dealt at the
## given town size (or at any size, when count is 0); warnings are advice.
func check(count: int = 0) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var known: Dictionary = roster()
	for pair in [[town, "town"], [minions, "minions"], [demons, "demons"], [secrets, "secrets"]]:
		for id in pair[0]:
			if not id in known[pair[1]]:
				errors.append("%s isn't a known %s." % [id, {"town": "town role", "minions": "minion", "demons": "demon", "secrets": "secret"}[pair[1]]])
	var sizes: Array = [count] if count > 0 else C.SETUPS.keys()
	for n in sizes:
		var cfg: Dictionary = C.SETUPS.get(n, {})
		if cfg.is_empty():
			continue
		if town.size() < cfg.town:
			errors.append("A %d-person town deals %d town roles; the script has %d." % [n, cfg.town, town.size()])
		if minions.size() < cfg.minions:
			errors.append("A %d-person town deals %d minion%s; the script has %d." % [n, cfg.minions, "" if cfg.minions == 1 else "s", minions.size()])
		if forced_in(town).size() > cfg.town:
			errors.append("%d town roles are forced into play, but a %d-person town only deals %d." % [forced_in(town).size(), n, cfg.town])
		if forced_in(minions).size() > cfg.minions:
			errors.append("%d minions are forced into play, but a %d-person town only deals %d." % [forced_in(minions).size(), n, cfg.minions])
	if demons.is_empty():
		errors.append("The script needs a demon.")
	if secrets.is_empty():
		errors.append("The script needs a secret.")
	if forced_in(demons).size() > 1:
		errors.append("Only one demon is dealt; force at most one.")
	if forced_in(secrets).size() > 1:
		errors.append("Only one secret is dealt; force at most one.")
	for id in forced:
		if not has(id):
			errors.append("%s is forced into play but isn't on the script." % display(id))
	if demons.size() > MAX_DEMONS:
		errors.append("At most %d demons can be on a script." % MAX_DEMONS)
	if town.size() != TOWN_SIZE:
		warnings.append("Scripts usually list %d town roles (this one has %d)." % [TOWN_SIZE, town.size()])
	if minions.size() != MINION_SIZE:
		warnings.append("Scripts usually list %d minions (this one has %d)." % [MINION_SIZE, minions.size()])
	if secrets.size() != SECRET_SIZE:
		warnings.append("Scripts usually list %d secrets (this one has %d)." % [SECRET_SIZE, secrets.size()])
	for tag in SUGGESTED_TAGS:
		var have: int = town.filter(func(r): return tag in tags_of(r)).size()
		if have < SUGGESTED_TAGS[tag]:
			warnings.append("Few %s roles: %d (suggested %d or more)." % [TAG_NAMES[tag], have, SUGGESTED_TAGS[tag]])
	if town.filter(func(r): return r in C.START_ROLES).size() < 2 or not town.any(func(r): return r in C.IDENTIFIER_ROLES):
		warnings.append("The deal can't always guarantee two start-knowledge gifts and a Seer, Dowser or Gravedigger.")
	return {"errors": errors, "warnings": warnings}


func ok(count: int = 0) -> bool:
	return check(count).errors.is_empty()


## One line for the New Case screen: what may be in play.
func summary() -> String:
	return "%s · %d town · %d minion%s · %d demon%s · %d secret%s%s" % [
		mode(), town.size(), minions.size(), "" if minions.size() == 1 else "s",
		demons.size(), "" if demons.size() == 1 else "s", secrets.size(), "" if secrets.size() == 1 else "s",
		(" · %d forced" % forced.size()) if not forced.is_empty() else ""]


## Stable identity for logs and traces.
func fingerprint() -> String:
	return JSON.stringify(to_dict(), "", true).md5_text().left(10)


# ---------------------------------------------------------------- files

func to_dict() -> Dictionary:
	return {"name": name, "town": town.duplicate(), "minions": minions.duplicate(), "demons": demons.duplicate(),
		"secrets": secrets.duplicate(), "forced": forced.duplicate()}


static func from_dict(d: Dictionary):
	var s = new()
	s.name = str(d.get("name", "Untitled"))
	for key in ["town", "minions", "demons", "secrets", "forced"]:
		var arr: Array = []
		for x in d.get(key, []):
			arr.append(str(x))
		s.set(key, arr)
	return s


func save(path: String) -> int:
	if path.begins_with(USER_DIR):
		DirAccess.make_dir_recursive_absolute(USER_DIR)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


## null if the file can't be read or isn't a script.
static func load_file(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary or not d.has("town"):
		return null
	return from_dict(d)

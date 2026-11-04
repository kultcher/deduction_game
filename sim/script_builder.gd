## Automatic script building: fills a script up to its usual size from the roster.
## Town slots go first to tags the script is short of (ScriptDef.SUGGESTED_TAGS), then at
## random. Excluded roles are never added; roles already on the base script are kept.
## Uses its own RNG, so building never touches a case's world RNG.
extends RefCounted

const ScriptDef = preload("res://sim/script_def.gd")


## opts:
##   base: ScriptDef to fill (null starts empty)
##   excluded: ids never to add (and removed from the base)
##   demons: how many demon types to aim for (1 = Beginner; up to ScriptDef.MAX_DEMONS)
##   seed: int (0 = random)
##   name: String
static func build(opts: Dictionary = {}):
	var rng = RandomNumberGenerator.new()
	var seed_in: int = int(opts.get("seed", 0))
	if seed_in != 0:
		rng.seed = seed_in
	else:
		rng.randomize()
	var excluded: Array = opts.get("excluded", [])
	var base = opts.get("base", null)
	var s = base.duplicate_script() if base != null else ScriptDef.new()
	s.name = str(opts.get("name", s.name if base != null else "Built script"))
	for key in ["town", "minions", "demons", "secrets"]:
		s.set(key, s.get(key).filter(func(r): return not r in excluded))
	s.forced = s.forced.filter(func(r): return s.has(r))
	var pool: Dictionary = ScriptDef.roster()
	var want_demons: int = clampi(int(opts.get("demons", maxi(1, s.demons.size()))), 1, ScriptDef.MAX_DEMONS)

	# Town: cover the suggested tags first, then fill at random.
	for tag in ScriptDef.SUGGESTED_TAGS:
		while s.town.size() < ScriptDef.TOWN_SIZE and _count_tag(s.town, tag) < ScriptDef.SUGGESTED_TAGS[tag]:
			var cands: Array = pool.town.filter(func(r): return not r in s.town and not r in excluded and tag in ScriptDef.tags_of(r))
			if cands.is_empty():
				break
			s.town.append(cands[rng.randi() % cands.size()])
	_fill(s.town, pool.town, excluded, ScriptDef.TOWN_SIZE, rng)
	_fill(s.minions, pool.minions, excluded, ScriptDef.MINION_SIZE, rng)
	_fill(s.secrets, pool.secrets, excluded, ScriptDef.SECRET_SIZE, rng)
	# The default Demon always leads, so a Beginner script is the plain one.
	if s.demons.is_empty() and "demon" in pool.demons and not "demon" in excluded:
		s.demons.append("demon")
	_fill(s.demons, pool.demons, excluded, want_demons, rng)
	return s


## A dynamic script: a semi-random 15 / 4 / 4 / 1-4 from every ready role. The deal's
## guarantees come first, each with room to spare (ScriptDef.DRAW_RULES: the minimum plus
## `spare` more where the roster has them, at least one more), so the script never gives
## away which roles were dealt; then the suggested tags; then the rest at random.
## opts: seed (0 = random), demons (1 = Beginner, up to MAX_DEMONS), excluded, name.
static func dynamic(opts: Dictionary = {}):
	var rng = RandomNumberGenerator.new()
	var seed_in: int = int(opts.get("seed", 0))
	if seed_in != 0:
		rng.seed = seed_in
	else:
		rng.randomize()
	var excluded: Array = opts.get("excluded", [])
	var pool: Dictionary = ScriptDef.roster()
	var town_pool: Array = pool.town.filter(func(r): return not r in excluded)
	var s = ScriptDef.new()
	s.name = str(opts.get("name", "Dynamic"))
	for rule in ScriptDef.DRAW_RULES:
		var eligible: Array = town_pool.filter(func(r): return r in rule.roles)
		var want: int = mini(rule.min + rule.spare, eligible.size())
		_fill(s.town, eligible, [], mini(s.town.size() + want - s.rule_count(rule), ScriptDef.TOWN_SIZE), rng)
	var built = build({"base": s, "excluded": excluded, "seed": rng.randi() + 1, "name": s.name,
		"demons": int(opts.get("demons", 1))})
	# Alphabetical, so the order on the script says nothing about how it was built.
	built.town.sort()
	built.minions.sort()
	built.secrets.sort()
	return built


## Fill a script back up to size without removing anything the player chose.
static func fill(script_in, excluded: Array = [], seed_in: int = 0):
	return build({"base": script_in, "excluded": excluded, "seed": seed_in, "name": script_in.name})


static func _count_tag(roles: Array, tag: String) -> int:
	return roles.filter(func(r): return tag in ScriptDef.tags_of(r)).size()


static func _fill(have: Array, pool: Array, excluded: Array, size: int, rng: RandomNumberGenerator) -> void:
	var cands: Array = pool.filter(func(r): return not r in have and not r in excluded)
	while have.size() < size and not cands.is_empty():
		var i: int = rng.randi() % cands.size()
		have.append(cands[i])
		cands.remove_at(i)

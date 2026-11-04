## Automatic script building. `build` / `fill` top a script up to its usual size;
## `dynamic` makes a semi-random one from every ready role. Both keep to the script rules
## (ScriptDef.SCRIPT_RULES caps, JINXES), cover the suggested tags, and never add an
## excluded role. Uses its own RNG, so building never touches a case's world RNG.
extends RefCounted

const ScriptDef = preload("res://sim/script_def.gd")

## How much likelier a role marked "favoured" (playtest mode) is to be picked.
const FAVOURED_WEIGHT = 4.0
const SIDES = {"town": ScriptDef.TOWN_SIZE, "minions": ScriptDef.MINION_SIZE, "secrets": ScriptDef.SECRET_SIZE}


## opts:
##   base: ScriptDef to fill (null starts empty)
##   excluded: ids never to add (and removed from the base)
##   demons: how many demon types to aim for (1 = Beginner; up to ScriptDef.MAX_DEMONS)
##   favoured: ids picked FAVOURED_WEIGHT times as often
##   caps: {rule id: max} overriding a SCRIPT_RULES max for this build
##   seed: int (0 = random)
##   name: String
static func build(opts: Dictionary = {}):
	var rng = _rng(opts)
	var excluded: Array = opts.get("excluded", [])
	var base = opts.get("base", null)
	var s = base.duplicate_script() if base != null else ScriptDef.new()
	s.name = str(opts.get("name", s.name if base != null else "Built script"))
	for key in ["town", "minions", "demons", "secrets"]:
		s.set(key, s.get(key).filter(func(r): return not r in excluded))
	s.forced = s.forced.filter(func(r): return s.has(r))
	var pool: Dictionary = ScriptDef.roster()
	var ctx = {"excluded": excluded, "favoured": opts.get("favoured", []), "caps": opts.get("caps", {}), "rng": rng}
	var want_demons: int = clampi(int(opts.get("demons", maxi(1, s.demons.size()))), 1, ScriptDef.MAX_DEMONS)

	# The evil side and secrets first, so their night-walkers count against the town's.
	# The default Demon always leads, so a Beginner script is the plain one.
	if s.demons.is_empty() and "demon" in pool.demons and not "demon" in excluded:
		s.demons.append("demon")
	_fill(s, "demons", pool.demons, want_demons, ctx)
	_fill(s, "minions", pool.minions, ScriptDef.MINION_SIZE, ctx)
	_fill(s, "secrets", pool.secrets, ScriptDef.SECRET_SIZE, ctx)
	# Town: cover the suggested tags, then fill at random.
	for tag in ScriptDef.SUGGESTED_TAGS:
		var with_tag: Array = pool.town.filter(func(r): return tag in ScriptDef.tags_of(r))
		while s.town.size() < ScriptDef.TOWN_SIZE and _count_tag(s.town, tag) < ScriptDef.SUGGESTED_TAGS[tag]:
			if not _add_one(s, "town", with_tag, ctx):
				break
	_fill(s, "town", pool.town, ScriptDef.TOWN_SIZE, ctx)
	return s


## A dynamic script: a semi-random 15 / 4 / 4 / 1-4 from every ready role.
##  1. Playtest marks first: `forced` roles go on the script and are always dealt;
##     `include` roles go on the script. Both may break a cap (the editor will say).
##  2. The deal's guarantees, each with room to spare (ScriptDef.DRAW_RULES: the minimum
##     plus `spare` more where the roster has them), so the script never gives away which
##     roles were dealt.
##  3. Night-walkers to a target picked within the rule's target ± 1.
##  4. Then `build`: suggested tags and the rest at random, within every cap.
## opts: seed (0 = random), demons (1 = Beginner), excluded, favoured, include, forced, name.
static func dynamic(opts: Dictionary = {}):
	var rng = _rng(opts)
	var excluded: Array = opts.get("excluded", [])
	var pool: Dictionary = ScriptDef.roster()
	var ctx = {"excluded": excluded, "favoured": opts.get("favoured", []), "caps": {}, "rng": rng}
	var s = ScriptDef.new()
	s.name = str(opts.get("name", "Dynamic"))
	s.demons = ["demon"] if "demon" in pool.demons and not "demon" in excluded else []
	var forced: Array = opts.get("forced", [])
	for id in opts.get("include", []) + forced:
		var side: String = _side_of(id, pool)
		if side != "" and not s.get(side).has(id) and not id in excluded:
			s.get(side).append(id)
	s.forced = forced.filter(func(r): return s.has(r))
	# Minions and secrets before the town, so their night-walkers count.
	_fill(s, "minions", pool.minions, ScriptDef.MINION_SIZE, ctx)
	_fill(s, "secrets", pool.secrets, ScriptDef.SECRET_SIZE, ctx)
	for rule in ScriptDef.DRAW_RULES:
		var eligible: Array = pool.town.filter(func(r): return r in rule.roles)
		var want: int = mini(rule.min + rule.spare, eligible.filter(func(r): return not r in excluded).size())
		while s.rule_count(rule) < want and s.town.size() < ScriptDef.TOWN_SIZE:
			if not _add_one(s, "town", eligible, ctx):
				break
	for rule in ScriptDef.SCRIPT_RULES:
		if not rule.has("target"):
			continue
		var target: int = clampi(rule.target + [-1, 0, 0, 1][rng.randi() % 4], rule.get("min", 0), rule.get("max", 99))
		var with_tag: Array = pool.town.filter(func(r): return rule.tag in ScriptDef.tags_of(r))
		while s.script_rule_value(rule) < target and s.town.size() < ScriptDef.TOWN_SIZE:
			if not _add_one(s, "town", with_tag, ctx):
				break
		ctx.caps[rule.id] = maxi(target, s.script_rule_value(rule))
	var built = build({"base": s, "excluded": excluded, "favoured": ctx.favoured, "caps": ctx.caps,
		"seed": rng.randi() + 1, "name": s.name, "demons": int(opts.get("demons", 1))})
	# Alphabetical, so the order on the script says nothing about how it was built.
	built.town.sort()
	built.minions.sort()
	built.secrets.sort()
	return built


## Fill a script back up to size without removing anything the player chose.
static func fill(script_in, excluded: Array = [], seed_in: int = 0):
	return build({"base": script_in, "excluded": excluded, "seed": seed_in, "name": script_in.name})


## Whether adding `id` keeps the script within every cap and jinx.
static func allowed(s, side: String, id: String, caps: Dictionary = {}) -> bool:
	for j in ScriptDef.JINXES:
		if id in j.roles and j.roles.any(func(r): return r != id and s.has(r)):
			return false
	var tags: Array = ScriptDef.tags_of(id)
	for rule in ScriptDef.SCRIPT_RULES:
		if not rule.tag in tags or not side in rule.get("sides", ["town"]):
			continue
		var cap: int = int(caps.get(rule.id, rule.get("max", 999)))
		if s.script_rule_value(rule) + 1 > cap:
			return false
	return true


static func _rng(opts: Dictionary) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	var seed_in: int = int(opts.get("seed", 0))
	if seed_in != 0:
		rng.seed = seed_in
	else:
		rng.randomize()
	return rng


static func _side_of(id: String, pool: Dictionary) -> String:
	for side in ["town", "minions", "demons", "secrets"]:
		if id in pool[side]:
			return side
	return ""


static func _count_tag(roles: Array, tag: String) -> int:
	return roles.filter(func(r): return tag in ScriptDef.tags_of(r)).size()


## Add one role from `pool` to `side`, weighted (favoured roles more often) and within the
## rules. False if nothing fits.
static func _add_one(s, side: String, pool: Array, ctx: Dictionary) -> bool:
	var have: Array = s.get(side)
	var cands: Array = pool.filter(func(r): return not r in have and not r in ctx.excluded and allowed(s, side, r, ctx.caps))
	if cands.is_empty():
		return false
	var weights: Array = cands.map(func(r): return FAVOURED_WEIGHT if r in ctx.favoured else 1.0)
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = ctx.rng.randf() * total
	for i in range(cands.size()):
		roll -= weights[i]
		if roll <= 0.0 or i == cands.size() - 1:
			have.append(cands[i])
			return true
	return false


static func _fill(s, side: String, pool: Array, size: int, ctx: Dictionary) -> void:
	while s.get(side).size() < size:
		if not _add_one(s, side, pool, ctx):
			return

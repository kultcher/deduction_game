## Static game content: map, occupations, cast pool, roles, hint packages.
## Pure data. Nothing here holds case state.
extends RefCounted

const PHASES = ["Morning", "Afternoon", "Evening", "Night"]
const MORNING = 0
const AFTERNOON = 1
const EVENING = 2
const NIGHT = 3

const BLOCKS = {
	"square": {"name": "the Square", "trace": "straw from the square stables"},
	"market": {"name": "the Market", "trace": "black soot from the market forges"},
	"docks": {"name": "the Docks", "trace": "river mud from the docks"},
	"hill": {"name": "Chapel Hill", "trace": "pale chalk dust from the hill path"},
}

## Roads between blocks (night walkers follow the shortest route and can be seen, or drop
## things, anywhere along it). The Square is the hub; the Market and Chapel Hill also meet.
const ROADS = [["square", "market"], ["square", "docks"], ["square", "hill"], ["market", "hill"]]

## Shortest route between two blocks, inclusive of both ends.
static func route(a: String, b: String) -> Array:
	if a == b:
		return [a]
	var prev = {a: ""}
	var queue: Array = [a]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for r in ROADS:
			var nxt = ""
			if r[0] == cur:
				nxt = r[1]
			elif r[1] == cur:
				nxt = r[0]
			if nxt != "" and not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	if not prev.has(b):
		return [a, b]
	var path: Array = [b]
	while path[0] != a:
		path.push_front(prev[path[0]])
	return path

const LOCATIONS = {
	"tavern": {"name": "the Drowned Lamb tavern", "block": "square"},
	"well": {"name": "the town well", "block": "square"},
	"smithy": {"name": "the smithy", "block": "market"},
	"bakery": {"name": "the bakery", "block": "market"},
	"wharf": {"name": "the wharf", "block": "docks"},
	"mill": {"name": "the mill", "block": "docks"},
	"chapel": {"name": "the chapel", "block": "hill"},
	"graveyard": {"name": "the graveyard", "block": "hill"},
}

## shifts: day phases this occupation always works (at least one). Known to the player.
const OCCUPATIONS = {
	"innkeeper": {"title": "innkeeper", "work": "tavern", "shifts": [2]},
	"priest": {"title": "priest", "work": "chapel", "shifts": [0]},
	"groundskeeper": {"title": "groundskeeper", "work": "graveyard", "shifts": [1]},
	"smith": {"title": "blacksmith", "work": "smithy", "shifts": [0]},
	"baker": {"title": "baker", "work": "bakery", "shifts": [0]},
	"fisher": {"title": "fisher", "work": "wharf", "shifts": [0]},
	"miller": {"title": "miller", "work": "mill", "shifts": [1]},
	"water_carrier": {"title": "water carrier", "work": "well", "shifts": [1]},
	"ostler": {"title": "ostler", "work": "tavern", "shifts": [0]},
	"net_mender": {"title": "net mender", "work": "wharf", "shifts": [1]},
}

## Social traits, 0..1. Each entry is [base, volatility]: the case value is rolled once as
## base ± volatility and stays constant for the case.
##  privacy:    how closed they are about themselves (role, relationships, whereabouts)
##  gossip:     how readily they talk about others
##  confidence: boldness of lies when pushed; conviction in nominating/voting; slow opinion shifts
##  insight:    keenness of logic; resistance to weak arguments
##  composure:  emotional control; hides attitude cues; resists pressure (and paranoia)
## style is used by dialogue templates.
## Each character's colour (their name and speech), chosen to read well on a dark background
## and to stay distinguishable from each other.
const CAST_COLORS = {
	"agnes": Color(0.98, 0.62, 0.42), "bart": Color(0.55, 0.78, 0.98), "constance": Color(0.86, 0.60, 0.95),
	"dorian": Color(0.62, 0.92, 0.55), "edda": Color(0.98, 0.86, 0.40), "fenwick": Color(0.40, 0.90, 0.85),
	"greta": Color(0.98, 0.52, 0.68), "hollis": Color(0.75, 0.72, 0.98), "isolde": Color(0.95, 0.75, 0.55),
	"jory": Color(0.60, 0.98, 0.78),
}

static func npc_color(id: String) -> Color:
	return CAST_COLORS.get(id, Color(0.85, 0.85, 0.85))

const CAST = [
	{"id": "agnes", "name": "Agnes", "pron": "she", "style": "warm", "blurb": "a widow who knows everyone's business",
		"traits": {"privacy": [0.2, 0.1], "gossip": [0.9, 0.05], "confidence": [0.5, 0.2], "insight": [0.4, 0.15], "composure": [0.3, 0.1]}},
	{"id": "bart", "name": "Bartholomew", "pron": "he", "style": "gruff", "blurb": "a broad-shouldered man of few words",
		"traits": {"privacy": [0.7, 0.1], "gossip": [0.15, 0.1], "confidence": [0.75, 0.1], "insight": [0.4, 0.2], "composure": [0.7, 0.1]}},
	{"id": "constance", "name": "Constance", "pron": "she", "style": "formal", "blurb": "precise, pious and quick to judge",
		"traits": {"privacy": [0.5, 0.2], "gossip": [0.4, 0.2], "confidence": [0.8, 0.05], "insight": [0.6, 0.1], "composure": [0.5, 0.2]}},
	{"id": "dorian", "name": "Dorian", "pron": "he", "style": "nervous", "blurb": "a twitchy young man who sleeps badly",
		"traits": {"privacy": [0.75, 0.15], "gossip": [0.5, 0.25], "confidence": [0.2, 0.1], "insight": [0.5, 0.2], "composure": [0.15, 0.1]}},
	{"id": "edda", "name": "Edda", "pron": "she", "style": "plain", "blurb": "cheerful, practical, hard to rattle",
		"traits": {"privacy": [0.4, 0.25], "gossip": [0.6, 0.1], "confidence": [0.55, 0.1], "insight": [0.55, 0.1], "composure": [0.85, 0.05]}},
	{"id": "fenwick", "name": "Fenwick", "pron": "he", "style": "warm", "blurb": "a jovial storyteller with a loose tongue",
		"traits": {"privacy": [0.15, 0.1], "gossip": [0.8, 0.15], "confidence": [0.6, 0.25], "insight": [0.3, 0.1], "composure": [0.4, 0.2]}},
	{"id": "greta", "name": "Greta", "pron": "she", "style": "gruff", "blurb": "sharp-eyed and suspicious of outsiders",
		"traits": {"privacy": [0.8, 0.05], "gossip": [0.3, 0.2], "confidence": [0.7, 0.15], "insight": [0.75, 0.1], "composure": [0.6, 0.15]}},
	{"id": "hollis", "name": "Hollis", "pron": "he", "style": "formal", "blurb": "an old scholar who weighs every word",
		"traits": {"privacy": [0.6, 0.1], "gossip": [0.25, 0.3], "confidence": [0.45, 0.1], "insight": [0.9, 0.05], "composure": [0.8, 0.1]}},
	{"id": "isolde", "name": "Isolde", "pron": "she", "style": "nervous", "blurb": "soft-spoken and easily frightened",
		"traits": {"privacy": [0.65, 0.2], "gossip": [0.45, 0.15], "confidence": [0.25, 0.15], "insight": [0.45, 0.25], "composure": [0.25, 0.15]}},
	{"id": "jory", "name": "Jory", "pron": "he", "style": "plain", "blurb": "a cheerful lad who never stops moving",
		"traits": {"privacy": [0.3, 0.3], "gossip": [0.7, 0.2], "confidence": [0.5, 0.3], "insight": [0.35, 0.15], "composure": [0.45, 0.25]}},
]

const TRAITS = ["privacy", "gossip", "confidence", "insight", "composure"]

## In-character descriptions for revealed traits. %s = name.
const TRAIT_TEXT = {
	"privacy": {"low": "%s is an open book about their own affairs", "mid": "%s shares about themselves when it suits them",
		"high": "%s keeps their own affairs close"},
	"gossip": {"low": "%s keeps out of other people's business", "mid": "%s will pass on news if asked",
		"high": "%s loves to pass on what they've heard"},
	"confidence": {"low": "%s second-guesses themselves", "mid": "%s holds their views with some conviction",
		"high": "%s is sure of themselves and hard to budge"},
	"insight": {"low": "%s is swayed by a good speech", "mid": "%s wants some reason before they're convinced",
		"high": "%s is sharp and hard to fool"},
	"composure": {"low": "%s wears every feeling on their face", "mid": "%s keeps a fairly level head",
		"high": "%s gives nothing away"},
}

## kind: info roles give information (readings); protect roles act on others; passive roles
## just are; evil roles are the demon's side.
## first_night: info received only on the first night (start knowledge).
## night_walk: the gift takes them out of the house at night (they can be seen, and they
## have a reason to give for being out).
## day: the gift works during the day.
const ROLES = {
	"archivist": {"name": "Archivist", "align": "good", "kind": "info", "first_night": true,
		"desc": "Starts knowing that one of two people is a particular minion."},
	"clerk": {"name": "Clerk", "align": "good", "kind": "info", "first_night": true,
		"desc": "Starts knowing that one of two people holds a particular gift."},
	"dowser": {"name": "Dowser", "align": "good", "kind": "info", "day": true,
		"desc": "The first time each day the Dowser is on a block with two or more others, learns how many of them are evil."},
	"gravedigger": {"name": "Gravedigger", "align": "good", "kind": "info",
		"desc": "Each night after an execution, learns the true role of the executed."},
	"lamplighter": {"name": "Lamplighter", "align": "good", "kind": "info", "night_walk": true,
		"desc": "Each night, walks the lamp route and learns how many other people were out."},
	"martyr": {"name": "Martyr", "align": "good", "kind": "protect",
		"desc": "Once per case, secretly chooses someone. If they are later executed while good, the Martyr dies in their place."},
	"medium": {"name": "Medium", "align": "good", "kind": "info", "night_walk": true,
		"desc": "Each night, visits the home of a dead person and learns something they knew but never said in public."},
	"nightwatch": {"name": "Night Watch", "align": "good", "kind": "info", "night_walk": true,
		"desc": "Each night, watches one block and learns who moved through it. Is out on that block."},
	"psychologist": {"name": "Psychologist", "align": "good", "kind": "info",
		"desc": "Each night, picks someone they talked with that day and learns whom that person trusts and suspects most."},
	"rumormonger": {"name": "Rumormonger", "align": "good", "kind": "info", "first_night": true,
		"desc": "Starts knowing that one of two people carries a particular secret."},
	"seer": {"name": "Seer", "align": "good", "kind": "info",
		"desc": "Each night, picks two people and learns if either is the demon. One good soul reads falsely as the demon."},
	"sexton": {"name": "Sexton", "align": "good", "kind": "protect",
		"desc": "Once per case, with fewer than five alive, may toll the death knell in the evening: that night, no gift that needs walking abroad works."},
	"surveyor": {"name": "Surveyor", "align": "good", "kind": "info", "first_night": true,
		"desc": "Starts knowing how many blocks have an evil resident."},
	"veteran": {"name": "Veteran", "align": "good", "kind": "passive",
		"desc": "The first time the demon attacks the Veteran, they survive and learn the last block the attacker came through."},
	"warden": {"name": "Warden", "align": "good", "kind": "protect", "night_walk": true,
		"desc": "Each night, guards one other person's door against the demon."},
	"hearthwitch": {"name": "Hearthwitch", "align": "good", "kind": "info",
		"desc": "Each night, learns how many of their two living lane-neighbours are evil. (Benched: not in the script.)"},
	"demon": {"name": "Demon", "align": "evil", "kind": "evil",
		"desc": "Kills one person each night (not the first)."},
	"poisoner": {"name": "Poisoner", "align": "evil", "kind": "evil", "minion": true, "night_walk": true,
		"desc": "Each night, poisons one person; their gift fails or lies until the next night."},
	"breathstealer": {"name": "Breathstealer", "align": "evil", "kind": "evil", "minion": true, "day": true,
		"desc": "Once a day, silences someone on the same block, from that evening's meeting until the next evening. Silenced people can still vote."},
	"revenant": {"name": "Revenant", "align": "evil", "kind": "evil", "minion": true, "day": true,
		"desc": "Hides a totem somewhere each day it has none in play. If hanged while a totem is hidden, a good soul who voted for it turns evil until the totem is found."},
	"scion": {"name": "Scion", "align": "evil", "kind": "evil", "minion": true,
		"desc": "If the demon is executed while five or more are alive, the Scion becomes the demon."},
}

## The script: what may be in play in a case. No duplicates.
const GOOD_ROLES = ["archivist", "clerk", "dowser", "gravedigger", "lamplighter", "martyr", "medium", "nightwatch",
	"psychologist", "rumormonger", "seer", "sexton", "surveyor", "veteran", "warden"]
const MINION_ROLES = ["breathstealer", "poisoner", "revenant", "scion"]
const EVIL_ROLES = ["demon", "breathstealer", "poisoner", "revenant", "scion"]
## Gifts that produce readings to share.
const INFO_ROLES = ["archivist", "clerk", "dowser", "gravedigger", "hearthwitch", "lamplighter", "medium", "nightwatch",
	"psychologist", "rumormonger", "seer", "surveyor"]
## Setup protection: at least two start-knowledge gifts and one strong identifier.
const START_ROLES = ["archivist", "clerk", "surveyor", "rumormonger"]
const IDENTIFIER_ROLES = ["seer", "dowser", "gravedigger"]
## Case sizes: townsfolk (one carries the secret), minions, demon.
const SETUPS = {7: {"town": 5, "minions": 1}, 10: {"town": 7, "minions": 2}}

## Gifts with something to tell: readings, or a one-off result (Veteran attacked, Martyr's
## choice, Martyr's grim confirmation).
static func has_readings(r: String) -> bool:
	return r in INFO_ROLES or r in ["veteran", "martyr"]

static func is_minion(r: String) -> bool:
	return ROLES.get(r, {}).get("minion", false)

## Secret modifiers: one per case, laid on a townsfolk (two for the Lovers), on top of
## their gift. Good townsfolk only.
const SECRET_MODS = {
	"delusional": {"name": "Delusional", "desc": "Their gift does not work and gives arbitrary information. They don't know."},
	"marked": {"name": "Marked", "desc": "May register as evil, or as the demon, to gifts that read them."},
	"lovers": {"name": "Secret Lovers", "desc": "Two townsfolk meet in secret at a different place each night."},
	"sleepwalker": {"name": "Sleepwalker", "desc": "Leaves home each night without knowing it."},
}
const SECRET_MOD_LIST = ["delusional", "marked", "lovers", "sleepwalker"]

static func secret_name(k: String) -> String:
	return SECRET_MODS[k]["name"] if SECRET_MODS.has(k) else k

## Flavoured hints. Each package holds 2+ roles so a hint is never a full reveal; a gift
## may sit in two (its hint is from the first).
const HINT_PACKAGES = {
	"official": {"roles": ["archivist", "clerk", "surveyor", "rumormonger"], "name": "a gift of official business",
		"text": "My gift deals in records and reports, the town's official business."},
	"night_sight": {"roles": ["seer", "nightwatch", "lamplighter", "hearthwitch"], "name": "a night-sight gift",
		"text": "My gift shows me things in the dark hours."},
	"the_dead": {"roles": ["gravedigger", "medium", "sexton", "martyr"], "name": "a gift of the dead",
		"text": "My gift has to do with the dead, and with death."},
	"shelter": {"roles": ["warden", "veteran", "martyr"], "name": "a sheltering gift",
		"text": "My gift is a kind of shelter against the demon."},
	"people": {"roles": ["dowser", "psychologist", "rumormonger"], "name": "a gift for reading people",
		"text": "My gift lets me read people, if I'm close enough."},
}

## Demon temperaments shape kill choice.
const DEMON_MOODS = ["vengeful", "cunning", "hungry"]

## Personal reasons a good NPC may be out at night (and hide it).
## (The Secret Lovers are a secret modifier now; see SECRET_MODS.)
const SECRETS = [
	{"kind": "insomnia", "text": "cannot sleep and walks to the chapel to pray", "dest": "hill"},
	{"kind": "smuggling", "text": "trades contraband with river smugglers at the docks", "dest": "docks"},
	{"kind": "debt", "text": "sneaks to the market to pay off a gambling debt", "dest": "market"},
]

static func block_name(b: String) -> String:
	return BLOCKS[b]["name"]

static func loc_name(l: String) -> String:
	if LOCATIONS.has(l):
		return LOCATIONS[l]["name"]
	return l

static func loc_block(l: String) -> String:
	if LOCATIONS.has(l):
		return LOCATIONS[l]["block"]
	return ""

static func role_name(r: String) -> String:
	if r == "" or r == "none":
		return "no gift"
	if SECRET_MODS.has(r):
		return SECRET_MODS[r]["name"]
	return ROLES[r]["name"] if ROLES.has(r) else r

static func package_of(r: String) -> String:
	for p in HINT_PACKAGES:
		if r in HINT_PACKAGES[p]["roles"]:
			return p
	return ""

static func tier(v: float) -> String:
	if v < 0.34:
		return "low"
	if v < 0.67:
		return "mid"
	return "high"

static func phase_list(ps: Array) -> String:
	var names: Array = ps.map(func(p): return PHASES[p].to_lower() + "s")
	return " and ".join(PackedStringArray(names))

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
	"sexton": {"title": "sexton", "work": "graveyard", "shifts": [1]},
	"smith": {"title": "blacksmith", "work": "smithy", "shifts": [0]},
	"baker": {"title": "baker", "work": "bakery", "shifts": [0]},
	"fisher": {"title": "fisher", "work": "wharf", "shifts": [0]},
	"miller": {"title": "miller", "work": "mill", "shifts": [1]},
	"water_carrier": {"title": "water carrier", "work": "well", "shifts": [1]},
}

## Social traits, 0..1. Each entry is [base, volatility]: the case value is rolled once as
## base ± volatility and stays constant for the case.
##  privacy:    how closed they are about themselves (role, relationships, whereabouts)
##  gossip:     how readily they talk about others
##  confidence: boldness of lies when pushed; conviction in nominating/voting; slow opinion shifts
##  insight:    keenness of logic; resistance to weak arguments
##  composure:  emotional control; hides attitude cues; resists pressure (and paranoia)
## style is used by dialogue templates.
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

## kind: info roles give information; protect roles act on others; passive roles just are.
## first_night: info received only on the first night.
const ROLES = {
	"gravedigger": {"name": "Gravedigger", "align": "good", "kind": "info",
		"desc": "Each night after an execution, learns the true role of the executed."},
	"hearthwitch": {"name": "Hearthwitch", "align": "good", "kind": "info",
		"desc": "Each night, learns how many of their two living lane-neighbours are evil."},
	"seer": {"name": "Seer", "align": "good", "kind": "info",
		"desc": "Each night, picks two people and learns if either is the demon. One good soul reads falsely as the demon."},
	"nightwatch": {"name": "Night Watch", "align": "good", "kind": "info",
		"desc": "Each night, watches one block and learns who moved through it. Is out on that block."},
	"archivist": {"name": "Archivist", "align": "good", "kind": "info", "first_night": true,
		"desc": "Begins knowing that one of two people is the Poisoner."},
	"clerk": {"name": "Clerk", "align": "good", "kind": "info", "first_night": true,
		"desc": "Begins knowing that one of two people holds a particular gift."},
	"warden": {"name": "Warden", "align": "good", "kind": "protect",
		"desc": "Each night, shields one other person from the demon."},
	"veteran": {"name": "Veteran", "align": "good", "kind": "passive",
		"desc": "Cannot be killed by the demon."},
	"demon": {"name": "Demon", "align": "evil", "kind": "evil",
		"desc": "Kills one person each night (not the first)."},
	"poisoner": {"name": "Poisoner", "align": "evil", "kind": "evil",
		"desc": "Each night, poisons one person; their gift fails until the next night."},
}

const GOOD_ROLES = ["gravedigger", "hearthwitch", "seer", "nightwatch", "archivist", "clerk", "warden", "veteran"]
const INFO_ROLES = ["gravedigger", "hearthwitch", "seer", "nightwatch", "archivist", "clerk"]

## Flavoured hints. Each package should hold 2+ roles so a hint is never a full reveal.
const HINT_PACKAGES = {
	"night_sight": {"roles": ["seer", "hearthwitch", "nightwatch"], "name": "a night-sight gift",
		"text": "My gift shows me things in the dark hours."},
	"names": {"roles": ["gravedigger", "archivist", "clerk"], "name": "a gift of names",
		"text": "My gift deals in names and records, of the living and the dead."},
	"shelter": {"roles": ["warden", "veteran"], "name": "a sheltering gift",
		"text": "My gift is a kind of shelter against the demon."},
}

## Demon temperaments shape kill choice.
const DEMON_MOODS = ["vengeful", "cunning", "hungry"]

## Personal reasons a good NPC may be out at night (and hide it).
const SECRETS = [
	{"kind": "lover", "text": "slips out to meet %s in secret", "needs_friend": true},
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
	return ROLES[r]["name"]

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

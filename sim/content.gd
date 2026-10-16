## Static game content: map, occupations, cast pool, roles.
## Pure data. Nothing here holds case state.
extends RefCounted

const PHASES := ["Morning", "Afternoon", "Evening", "Night"]
const MORNING := 0
const AFTERNOON := 1
const EVENING := 2
const NIGHT := 3

const BLOCKS := {
	"square": {"name": "the Square", "trace": "straw from the square stables"},
	"market": {"name": "the Market", "trace": "black soot from the market forges"},
	"docks": {"name": "the Docks", "trace": "river mud from the docks"},
	"hill": {"name": "Chapel Hill", "trace": "pale chalk dust from the hill path"},
}

const LOCATIONS := {
	"tavern": {"name": "the Drowned Lamb tavern", "block": "square"},
	"chapel": {"name": "the chapel", "block": "hill"},
	"graveyard": {"name": "the graveyard", "block": "hill"},
	"smithy": {"name": "the smithy", "block": "market"},
	"bakery": {"name": "the bakery", "block": "market"},
	"wharf": {"name": "the wharf", "block": "docks"},
	"mill": {"name": "the mill", "block": "docks"},
	"well": {"name": "the town well", "block": "square"},
}

const OCCUPATIONS := {
	"innkeeper": {"title": "innkeeper", "work": "tavern"},
	"priest": {"title": "priest", "work": "chapel"},
	"sexton": {"title": "sexton", "work": "graveyard"},
	"smith": {"title": "blacksmith", "work": "smithy"},
	"baker": {"title": "baker", "work": "bakery"},
	"fisher": {"title": "fisher", "work": "wharf"},
	"miller": {"title": "miller", "work": "mill"},
	"water_carrier": {"title": "water carrier", "work": "well"},
}

## Personality traits are 0..1.
##  honesty: willingness to confess personal secrets
##  caution: how long they hide a valuable gift
##  gossip:  how much they spread what they know
##  temper:  how sharply they react to pressure or accusation
##  loyalty: how strongly they defend friends
## style is used by dialogue templates.
const CAST := [
	{"id": "agnes", "name": "Agnes", "pron": "she", "style": "warm", "blurb": "a widow who knows everyone's business",
		"traits": {"honesty": 0.7, "caution": 0.3, "gossip": 0.9, "temper": 0.3, "loyalty": 0.6}},
	{"id": "bart", "name": "Bartholomew", "pron": "he", "style": "gruff", "blurb": "a broad-shouldered man of few words",
		"traits": {"honesty": 0.6, "caution": 0.6, "gossip": 0.2, "temper": 0.7, "loyalty": 0.8}},
	{"id": "constance", "name": "Constance", "pron": "she", "style": "formal", "blurb": "precise, pious and quick to judge",
		"traits": {"honesty": 0.8, "caution": 0.5, "gossip": 0.4, "temper": 0.6, "loyalty": 0.4}},
	{"id": "dorian", "name": "Dorian", "pron": "he", "style": "nervous", "blurb": "a twitchy young man who sleeps badly",
		"traits": {"honesty": 0.4, "caution": 0.8, "gossip": 0.5, "temper": 0.4, "loyalty": 0.5}},
	{"id": "edda", "name": "Edda", "pron": "she", "style": "plain", "blurb": "cheerful, practical, hard to rattle",
		"traits": {"honesty": 0.6, "caution": 0.4, "gossip": 0.6, "temper": 0.2, "loyalty": 0.7}},
	{"id": "fenwick", "name": "Fenwick", "pron": "he", "style": "warm", "blurb": "a jovial storyteller with a loose tongue",
		"traits": {"honesty": 0.5, "caution": 0.2, "gossip": 0.8, "temper": 0.3, "loyalty": 0.5}},
	{"id": "greta", "name": "Greta", "pron": "she", "style": "gruff", "blurb": "sharp-eyed and suspicious of outsiders",
		"traits": {"honesty": 0.7, "caution": 0.7, "gossip": 0.3, "temper": 0.8, "loyalty": 0.6}},
	{"id": "hollis", "name": "Hollis", "pron": "he", "style": "formal", "blurb": "an old scholar who weighs every word",
		"traits": {"honesty": 0.9, "caution": 0.6, "gossip": 0.3, "temper": 0.2, "loyalty": 0.4}},
	{"id": "isolde", "name": "Isolde", "pron": "she", "style": "nervous", "blurb": "soft-spoken and easily frightened",
		"traits": {"honesty": 0.5, "caution": 0.7, "gossip": 0.4, "temper": 0.3, "loyalty": 0.8}},
	{"id": "jory", "name": "Jory", "pron": "he", "style": "plain", "blurb": "a cheerful lad who never stops moving",
		"traits": {"honesty": 0.6, "caution": 0.3, "gossip": 0.7, "temper": 0.5, "loyalty": 0.6}},
]

## kind: info roles give information; protect roles act on others; passive roles just are.
## first_night: info received only on the first night.
const ROLES := {
	"gravedigger": {"name": "Gravedigger", "align": "good", "kind": "info",
		"desc": "Each night after an execution, learns the true role of the executed."},
	"hearthwitch": {"name": "Hearthwitch", "align": "good", "kind": "info",
		"desc": "Each night, learns how many of their two living lane-neighbours are evil."},
	"seer": {"name": "Seer", "align": "good", "kind": "info",
		"desc": "Each night, picks two people and learns if either is the demon. One good soul reads falsely as the demon."},
	"nightwatch": {"name": "Night Watch", "align": "good", "kind": "info",
		"desc": "Each night, watches one block and learns who moved through it."},
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

const GOOD_ROLES := ["gravedigger", "hearthwitch", "seer", "nightwatch", "archivist", "clerk", "warden", "veteran"]
const INFO_ROLES := ["gravedigger", "hearthwitch", "seer", "nightwatch", "archivist", "clerk"]

## Demon temperaments shape kill choice.
const DEMON_MOODS := ["vengeful", "cunning", "hungry"]

## Personal reasons a good NPC may be out at night (and lie about it).
const SECRETS := [
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

## One townsperson's state for a single case. Pure data; logic lives in world/mind/evil.
extends RefCounted

var id = ""
var name = ""
var pron = "they"
var style = "plain"
var blurb = ""
var traits = {}

var occupation = ""
var work = ""            # work location id
var home_block = ""
var ring = 0             # position on the lane ring (neighbours for the Hearthwitch)

var role = ""            # true role id
var alignment = "good"
var alive = true
var death_day = -1
var death_cause = ""     # "demon" | "executed"
var poisoned = false

var loc = ""             # current location id, or "home"
var night_block = ""     # block they were on last night
var out_last_night = false
var history = {}         # "d:p" -> location id (or "home:<block>")

var friends: Array = []
var rivals: Array = []
var secret = {}          # personal reason to be out at night (good NPCs only), may be empty

## Suspicion of each other NPC id (0 = trusting, 1+ = convinced evil).
var suspicion = {}
## Player-readable reason for the most recent large rise in suspicion, per target.
var sus_why = {}
## Ids of info entries already applied to this NPC's own suspicion.
var applied_info = 0
## Trust in the player, 0..1.
var trust = 0.5
## Questions the player asked today (pressing too hard sours trust).
var pressed_today = 0

## Beliefs: list of dictionaries. kinds:
##  {kind:"saw", who, loc, block, day, phase}
##  {kind:"info", ...}  ability results (see info_log)
##  {kind:"heard", from, text, ...}
var beliefs: Array = []
## Ability results: {day, role, data, text, true:bool, why}
var info_log: Array = []

## What this NPC claims publicly.
var claimed_role = ""        # "" = not claimed yet; "none" = claims no gift
var claim_public = false     # has spoken their claim at a town meeting
var told_player_role = false

## Seer only: the good NPC who falsely reads as demon.
var red_herring = ""

func display() -> String:
	return name

func is_evil() -> bool:
	return alignment == "evil"

func at_home() -> bool:
	return loc.begins_with("home")

func short_status() -> String:
	return "%s (%s)%s" % [name, occupation, "" if alive else " [dead]"]

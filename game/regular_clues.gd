## What a search turns up of a place's regular (Michael, Nov 28): a thing of theirs left
## behind, not someone's word. One practical thing per character (Michael's picks, Nov 28), tied to the person rather than their
## trade (trades change from case to case). Each reads after "<Name>'s": Michael's wording
## (Nov 28) is "You found <Name>'s <clue> at <place>: a sign they come here when off work."
extends RefCounted

const CLUES = {
	"agnes": ["knitting"],
	"bart": ["whittling knife"],
	"constance": ["prayer book"],
	"dorian": ["sleeping draught"],
	"edda": ["apron"],
	"fenwick": ["book on drama"],
	"greta": ["walking stick"],
	"hollis": ["pocket watch"],
	"isolde": ["pressed flower"],
	"jory": ["battered ball"],
	"kiran": ["deck of cards"],
	"lian": ["account book"],
	"merrin": ["lucky charm"],
	"nisha": ["chessboard"],
	"odette": ["pocket flask"],
}

## One of the person's clues, by the search's own draw; a plain fallback for anyone unlisted.
static func pick(id: String, name: String, rng: RandomNumberGenerator) -> String:
	var options: Array = CLUES.get(id, [])
	if options.is_empty():
		return "belongings"
	return str(options[rng.randi_range(0, options.size() - 1)])

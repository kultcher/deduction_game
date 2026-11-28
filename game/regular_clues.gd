## What a search turns up of a place's regular (Michael, Nov 28): a thing of theirs left
## behind, not someone's word. One or two per character, tied to the person rather than their
## trade (trades change from case to case). Each reads after "<Name>'s": Michael's wording
## (Nov 28) is "You found <Name>'s <clue> at <place>: a sign they come here when off work."
extends RefCounted

const CLUES = {
	"agnes": ["half-finished letter, full of other people's news", "knitting, the needles still in it"],
	"bart": ["whittling knife and a little heap of shavings", "great work gloves, stitched with a B"],
	"constance": ["prayer book", "list of the town's failings, in a neat hand"],
	"dorian": ["sleeping draught", "page with the same line crossed out a dozen times"],
	"edda": ["shawl, mended many times over", "jar of preserves"],
	"fenwick": ["script notes", "book on drama"],
	"greta": ["tally of strangers' comings and goings", "walking stick, worn smooth"],
	"hollis": ["spectacles, folded on an open book", "old treatise, with notes in every margin"],
	"isolde": ["lavender sachet", "pressed flower, tucked into a ribbon"],
	"jory": ["battered ball, scuffed from kicking", "boots, worn through at the toes"],
	"kiran": ["deck of cards", "page of jokes, half of them crossed out"],
	"lian": ["ledger of debts, settled to the penny", "tin cup"],
	"merrin": ["list of omens", "lucky charm, worried smooth"],
	"nisha": ["notebook of careful observations", "chessboard, mid-game"],
	"odette": ["well-thumbed book, with dry remarks pencilled in its margins", "pipe and tobacco tin"],
}

## One of the person's clues, by the search's own draw; a plain fallback for anyone unlisted.
static func pick(id: String, name: String, rng: RandomNumberGenerator) -> String:
	var options: Array = CLUES.get(id, [])
	if options.is_empty():
		return "belongings"
	return str(options[rng.randi_range(0, options.size() - 1)])

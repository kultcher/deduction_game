## What a search turns up of a place's regular (Michael, Nov 28): a thing of theirs left
## behind, not someone's word. One or two per character, tied to the person rather than their
## trade (trades change from case to case). Each reads after "you find ...".
extends RefCounted

const CLUES = {
	"agnes": ["a half-finished letter in Agnes's hand, full of other people's news", "Agnes's knitting, the needles still in it"],
	"bart": ["Bartholomew's whittling knife and a little heap of shavings", "a pair of great work gloves stitched with a B"],
	"constance": ["a prayer book with Constance's name pressed inside the cover", "a list of the town's failings in Constance's neat hand"],
	"dorian": ["a sleeping draught with Dorian's name scratched on the bottle", "a page of Dorian's, the same line crossed out a dozen times"],
	"edda": ["Edda's shawl, mended many times over", "a jar of Edda's preserves, labelled in a plain hand"],
	"fenwick": ["some of Fenwick's script notes", "a book on drama with Fenwick's name inside"],
	"greta": ["a tally of strangers' comings and goings in Greta's blunt hand", "Greta's walking stick, worn smooth"],
	"hollis": ["Hollis's spectacles, folded on an open book", "an old treatise with Hollis's notes in the margins"],
	"isolde": ["a sachet of lavender with Isolde's ribbon round it", "a pressed flower tucked into a note signed Isolde"],
	"jory": ["Jory's battered ball, scuffed from kicking", "a pair of boots worn through at the toes, Jory's by the size"],
	"kiran": ["a deck of cards with Kiran's mark on the box", "a page of Kiran's jokes, half of them crossed out"],
	"lian": ["Lian's ledger of debts, settled to the penny", "a plain tin cup scratched with Lian's initial"],
	"merrin": ["a list of omens in Merrin's dramatic hand", "Merrin's lucky charm, worried smooth"],
	"nisha": ["Nisha's notebook of careful observations", "a chessboard mid-game, with Nisha's notes beside it"],
	"odette": ["a well-thumbed book of Odette's, dry remarks pencilled in its margins", "Odette's pipe and tobacco tin"],
}

## One of the person's clues, by the search's own draw; a plain fallback for anyone unlisted.
static func pick(id: String, name: String, rng: RandomNumberGenerator) -> String:
	var options: Array = CLUES.get(id, [])
	if options.is_empty():
		return "something of %s's" % name
	return str(options[rng.randi_range(0, options.size() - 1)])

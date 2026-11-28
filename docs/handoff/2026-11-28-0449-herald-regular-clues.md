# A search finds the regular's belongings, not someone's word (Michael's Nov 28 item 7)

- **Agent:** Claude-Herald
- **Base:** main at 6770f32e
- **Status:** PR open. Golden is identical to `baseline_1bf8a4b` at `--tol 0` on all five seeds.
- **Next actor:** Bailiff (review, merge). Quill is checking with Seneschal whether the card behind it should change.

## What changed

- **Item 7 (Michael, Nov 28, via Seneschal):** before, searching a social spot had whoever worked there tell you who its regular was, even when that worker wasn't there that phase. Now the search finds a thing of the regular's left behind: "Searching the Drowned Lamb tavern, you find a list of omens in Merrin's dramatic hand. Merrin must spend time here when not working."
  - The logic is unchanged: the same pick by its own seeded draw (`hash(seed, place, "regulars")`), once per place per game, and the same `known_haunts` and haunt receipt. The clue is drawn from that same private generator after the regular, so the world's random rolls don't move.
  - The haunt receipt now reads "(you found <clue> there, day N)" instead of "(you asked after the regulars there, day N)".
  - With more than one unknown regular: "Others leave their traces here too." This replaces "They're not the only one."
- **Clues:** `game/regular_clues.gd` has two per character, tied to the person, not the trade, since trades change between cases. Michael said I could pick them.
- **VN page:** the find comes up as its own page over the place, like a crime-scene trace or the tavern's gossip. Title: "<Place> · left behind". There's no picture of the object yet, as Michael asked. The left panel reads "Searching the place", even at the tavern, where it used to say "Listening to the gossip". `Game.last_search_clue` carries the find to the screen.
- **Flaky tests:** the same `test_day_plaque` / `test_audit_ui` fix as #571, with identical content.

## Small calls made on Michael's behalf

- **The clues** (he delegated the picks):
  - Agnes: a half-finished letter full of other people's news; her knitting.
  - Bartholomew: his whittling knife and shavings; great work gloves stitched with a B.
  - Constance: a prayer book with her name inside; a list of the town's failings.
  - Dorian: a sleeping draught; a page with the same line crossed out a dozen times.
  - Edda: her much-mended shawl; a jar of her preserves.
  - Fenwick: his script notes; a book on drama (both are Michael's examples).
  - Greta: a tally of strangers' comings and goings; her walking stick.
  - Hollis: his spectacles on an open book; a treatise with his margin notes.
  - Isolde: a lavender sachet with her ribbon; a pressed flower in a note.
  - Jory: his battered ball; boots worn through at the toes.
  - Kiran: a deck of cards with his mark; a page of his jokes.
  - Lian: her ledger of debts; a tin cup with her initial.
  - Merrin: a list of omens; their lucky charm.
  - Nisha: her notebook of observations; a chessboard mid-game.
  - Odette: a book with dry remarks in its margins; her pipe and tobacco tin.
- **The sentences:** "Searching <place>, you find <clue>. <Name> must spend time here when not working.", "Others leave their traces here too.", the receipt's "(you found <clue> there, day N)", the page title "<Place> · left behind", and the panel's "Searching the place".

## Measured

- New suite `tools/test_regular_clues.gd` (11 checks, in the fast list; 2 repeat runs):
  - every character has one or two clues;
  - a search at a place with a regular finds one of that person's own clues and teaches you the haunt;
  - the narration is a find, with no "tells you";
  - the receipt says what you found;
  - the page comes up over the place, with no picture;
  - the panel reads "Searching the place".
- Suites passing: `test_regular_clues`, `test_haunt_learning`, `test_npc_fixes_shifts_dead_haunt`, `test_buildings_tavern_town_hall`, `test_gossip_tiers`, `test_meeting_gossip`, `test_peer_role_gossip`, `test_dialogue_fixes_gossip_reasons`, `test_control_flow`, `test_ui`, `test_day_plaque`, `test_audit_ui`.
- Golden: one capture, identical to `baseline_1bf8a4b` at `--tol 0 --ignore engine` on all five seeds. No golden seed searches a social spot.
- Checked by eye at 1280×800 and 1920×1080 (the tavern page).

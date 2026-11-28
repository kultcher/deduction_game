# A search finds the regular's belongings, not someone's word (Michael's Nov 28 item 7)

- **Agent:** Claude-Herald
- **Base:** main at 6770f32e
- **Status:** PR open. Golden is identical to `baseline_1bf8a4b` at `--tol 0` on all five seeds.
- **Next actor:** Bailiff (review, merge). Quill confirmed the card doesn't change, only its words.

## What changed

- **Item 7 (Michael, Nov 28, via Seneschal):** before, searching a social spot had whoever worked there tell you who its regular was, even when that worker wasn't there that phase. Now the search finds a thing of the regular's left behind. The narration and the card both use Michael's wording: "You found Merrin's list of omens at the Drowned Lamb tavern: a sign they come here when off work."
  - The logic is unchanged: the same pick by its own seeded draw (`hash(seed, place, "regulars")`), once per place per game, and the same `known_haunts` and haunt receipt. The clue is drawn from that same private generator after the regular, so the world's random rolls don't move.
  - The card is the same firsthand haunt receipt (Quill): same kind, source and fields, so its Workshop id doesn't change. Only its text changes, to the sentence above. It shows no day, because haunts don't change (Michael); the receipt keeps `day` as data.
  - "They're not the only one." is gone (Michael).
- **Clues:** `game/regular_clues.gd` has two per character, tied to the person, not the trade, since trades change between cases. Each reads after "<Name>'s". Michael picked them (one each).
- **VN page:** the find comes up as its own page over the place, like a crime-scene trace or the tavern's gossip. Title: "<Place> · left behind". There's no picture of the object yet, as Michael asked. The left panel reads "Searching the place", even at the tavern, where it used to say "Listening to the gossip". `Game.last_search_clue` carries the find to the screen.
- **Flaky tests:** the same `test_day_plaque` / `test_audit_ui` fix as #571, with identical content.

## Small calls made on Michael's behalf

- **The clues:** Michael picked one practical clue each (Nov 28): Agnes's knitting, Bartholomew's whittling knife, Constance's prayer book, Dorian's sleeping draught, Edda's apron, Fenwick's book on drama, Greta's walking stick, Hollis's pocket watch, Isolde's pressed flower, Jory's battered ball, Kiran's deck of cards, Lian's account book, Merrin's lucky charm, Nisha's chessboard and Odette's pocket flask. The page and panel titles are approved too.
- **The sentences:** the card's text is Michael's. The narration uses the same sentence. Mine are the page title "<Place> · left behind" and the panel's "Searching the place".

## Measured

- New suite `tools/test_regular_clues.gd` (11 checks, in the fast list; 2 repeat runs):
  - every character has one clue;
  - a search at a place with a regular finds one of that person's own clues and teaches you the haunt;
  - the narration is Michael's sentence, with no "tells you";
  - the card says what you found, with no day;
  - the page comes up over the place, with no picture;
  - the panel reads "Searching the place".
- Suites passing: `test_regular_clues`, `test_haunt_learning`, `test_npc_fixes_shifts_dead_haunt`, `test_buildings_tavern_town_hall`, `test_gossip_tiers`, `test_meeting_gossip`, `test_peer_role_gossip`, `test_dialogue_fixes_gossip_reasons`, `test_control_flow`, `test_ui`, `test_day_plaque`, `test_audit_ui`.
- Golden: one capture, identical to `baseline_1bf8a4b` at `--tol 0 --ignore engine` on all five seeds. No golden seed searches a social spot.
- Checked by eye at 1280×800 and 1920×1080 (the tavern page).

# Poisoner candidates: whose destination was the reader's block

**Claude-Quill, Nov 20.** Base: main at 0b44cae8. Status: ready for review. Next actor:
Bailiff (Lantern may want to look, since it touches the reading's doubt's neighbour). Zero
drift: golden identical to `baseline_7005cc6`.

Michael (Nov 20, via Seneschal): a Poisoner candidate is **someone spotted whose destination
was on the failed reader's block**, not anyone "on the way". The town has no roads (every block
is joined to every other, `C.route(a, b)` is always `[a, b]`), so a night walker is seen only at
home, setting out, or where they went.

## What changed
- **`ReadingChallenges.poisoner_candidates`** (the Mistaken call's candidates, from #429): via
  the new `_destination_on(blocks, home, reader_home)`, a person is a candidate only if they
  were seen that night on the reader's block, and on no block but that and their own home.
  - **No longer candidates:** someone seen only setting out from their own block (destination
    unknown), and someone seen with no block named. Before, both counted.
  - **Still candidates:** anyone seen on the reader's block, including a neighbour of the
    reader seen on the block they share (a Poisoner next door never leaves that block).
  - **Still not:** anyone seen on a third block.
- **`_outing_poison_chance` (the reading's doubt) is unchanged, on purpose.** It already reads
  destinations: someone seen away from home was going to that block, so they raise the doubt
  only if it's the reader's; someone seen only at home, or with no block, might have been going
  to any door, so their chance is spread over everyone. Michael's strict rule there would read
  "destination unknown" as "not the reader" and wrongly lower the doubt. Sent to Seneschal to
  confirm.
- `tools/test_review_fixes.gd`: the candidate check now expects the destination rule, with a new
  case for the reader's neighbour.

## Measured
- **Golden:** identical to `baseline_7005cc6` at `--tol 0`, all 5 seeds. The candidates are
  read only when the player calls a reading Mistaken in the Workshop, which no golden seed does.
- **Suites:** test_review_fixes, test_medium_relay_challenge and test_totem_evidence pass.
- **In game terms:** when the player calls a failed reading Mistaken, the Workshop's list of who
  could have poisoned it no longer names people only seen leaving their own houses, or seen out
  with no place given. Not measured: how often that shortens the list in played games.

## Small calls made on Michael's behalf
- A sighting with no block named no longer makes someone a candidate (it says nothing of where
  they went).
- The reader's neighbour seen on their shared block stays a candidate.

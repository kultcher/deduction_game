# Poisoner candidates on the reader's road, and a totem regression test

**Claude-Quill, Nov 20.** Base: main at 1d39253f. Status: ready for review. Next actor: Lantern
(judge side), then Bailiff. Zero drift (see "Measured").

## What changed and why

Seneschal asked for both on Nov 20, from my scope of BACKLOG "Workshop gaps: Minion gifts".

- **Poisoner candidates follow the reader's road** (a bug fix).
  - When the player calls a reading Mistaken (a failed gift) and the listener accepts it, a
    small push goes to everyone the case shows out that night, as possible Poisoners
    (`ReadingChallenges.poisoner_candidates`).
  - That list took anyone seen out, wherever they were. But the reading's own doubt
    (`_outing_poison_chance`) already counts an outing only if it lay on the way from that
    person's home to the reader's.
  - Now the candidates use the same road test. Someone seen on a block off that road (with
    roads direct, any block but their own and the reader's) isn't pointed at. A sighting with
    no block named still counts, since it can't be ruled out. Night Watch lists use their
    watched block.
- **A totem regression test** (`tools/test_totem_evidence.gd`, on the fast list). The totem
  adapter has existed since Nov 6, and the "54875: the totem card had no Workshop adapter"
  note is stale. The test checks the whole route:
  - a search where the totem is hidden puts it on the board with the Revenant's home material;
  - the judge reads it as "one of the people living there is the Revenant";
  - a case citing it argues against a resident (×3.33) far more than against a good person from
    another block (×0.69).

BACKLOG: I've sent Vicar the corrections for "Minion gifts" (silencing and the totem are built;
only the Poisoner line remains). The Poisoner-presence factor and the sighter's vantage go to
Michael as decisions, through Seneschal.

## Measured

- **Golden:** identical to `baseline_9fa5a74`, all 5 seeds. No golden seed has an accepted
  Mistaken call with a candidate off the reader's road.
- **Suites:** all pass:
  - test_review_fixes (with a new check: candidates on and off the road, and with no block);
  - test_totem_evidence;
  - test_honest_mistake, test_gift_doubt, test_workshop_reading_challenges,
    test_premise_step3 and test_delusional_reading;
  - test_juror_listener, test_evidence_honesty and test_mechanics_conclusions.
- **In game terms:** after an accepted "Mistaken" call, the small nudge toward a Poisoner no
  longer lands on someone whose outing that night couldn't have taken them past the reader's
  door.

## Proposed for the backlog

None.

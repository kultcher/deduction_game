# Vicar: Michael's answers to the burdens feasibility questions

- **Agent:** Claude-Vicar
- **Base:** main (after #469)
- **Status:** docs only
- **Next actor:** Michael, on two small points; then Seneschal, on briefing the first
  prototype; Bailiff merges this

Michael answered the 24 questions in `docs/design/burdens_feasibility.md` directly (Nov 20).
They're in a new section 9 of `docs/design/burdens.md`, which wins where it differs from
sections 1 to 7. The main points:

- **An unclaimed Marked is enumerated** in the judge, not a per-person allowance.
- **Ill-Omened:**
  - drunk works exactly as if poisoned, covering the night after the hanging through the next
    day;
  - the drunk don't know, and that's intended;
  - the claim must be restated at the nomination;
  - the hanging-cost vote term cancels about the player's "yes" bump at median trust;
  - the board marks the possibly-drunk night.
- **Unrequited:**
  - a card "X admitted they have an unrequited love for Y" on reveal;
  - the bluff only answers sightings on the beloved's block or a "leaving home" on its own;
  - it withholds only moderate-to-strong evidence against the beloved;
  - once the beloved is dead it visits the graveyard (Chapel Hill), and a bluffer keeps the
    same cover.
- **Marked:** the private share scales with trust.
- **Evil's burden bluffs:**
  - mostly reactive, and a day 1 bluff is extremely rare;
  - a burden bluff always sits on a bluffed gift.
- **Sleepwalker 2.0 is held.**
- **UI:**
  - the "Hidden" line is approved;
  - burden claims show where secrets do;
  - the "private errand" retires;
  - the tooltip is approved.

**Still to confirm:**
- what Q3's "Explained to the player? Not directly." means for allowance-per-person against
  per-oddity;
- the new constants these imply.

`burdens_feasibility.md`'s status line now points to section 9.

# Quill: the Mistaken call's cause, and the shared-Delusion slate cases (mock/burdens-slot)

- **Agent:** Claude-Quill
- **Base:** `mock/burdens-slot` after 3062841f
- **Status:** pushed. This is the first part of the evidence side of the shared Delusion doubt, which Michael approved on Nov 22. The rest waits for Lantern's core.
- **Next actor:** Lantern, for the core and its stored fields (`workshop_state.own_delusion`, `workshop_state.delusion_of`, to be confirmed). Then me again, to point `source_doubt` and the juror at them.

## What changed

1. **The Mistaken call's cause** (Michael, Nov 22: the player picks it).
   - Under "Mistaken", the reading card offers "Poisoned that night" (the plain Mistaken call, that night's reading only) and "Delusional all along".
   - The live editor's side panel offers the same two as dropdown entries.
   - Both appear only where the script can deal Delusional; elsewhere Mistaken works as before. They aren't offered on a Medium's passing-on.
   - "Delusional all along" uses the existing Delusional challenge mode. That mode used to need a group of readings. On one reading it now covers every reading by the same reader in the case (`reading_challenges.gd` `reader_group`), so all of them take the same discount.
   - A call is refused where the script can't deal Delusional (`delusion_possible`, in `valid` and `canvas_model.add_modifier`).
2. **The slate's before-and-after cases** (3062841f, already pushed):
   - `seer_contradiction`: a Seer's "yes" then "no" on one pair, argued "readings don't fit together: Delusional".
   - `seer_contradiction_burden`: the same cards, argued "carries a hidden burden: Delusional".
   - A slate premise can now carry a cause or burden (`"inconsistent:delusional"`).

## What I measured

- **Suites:** `test_delusional_reading` gained 5 checks (12 in all, 0 failures):
  - the call stands on one reading;
  - it's refused without Delusional on the script;
  - it covers both of one reader's readings and leaves another reader's alone, at the same discount.
- 19 related suites pass, and the 5 Workshop and UI suites again after the final layout.
- **Today's numbers, before Lantern's core** (10 NPCs, seeds 1–6):

| Case | Badge | Strength | Town's suspicion of the Seer |
|---|---|---|---|
| `seer_contradiction` | Moderate | 3.29 | up 0.30–0.41 |
| `seer_contradiction_burden` | none | 0.87 | up 0.00–0.16 |
| `lie_seer_reversed` (the framed reader, corrected by a lying call) | Moderate | 2.12 | up 0.19–0.20 |

- **What the numbers show:**
  - Arguing Delusion still raises the town's suspicion of the reader.
  - The hidden-burden premise grades against itself, because the juror reads it as clearing the person.
- These are the cases to rerun once the shared doubt lands.

## Wording

- **Approved by Michael (Nov 22):** "Poisoned that night", "Delusional all along".
- **Draft tips:**
  - "Something fooled the gift that night only: poison, or a misleading registration."
  - "Their gift has never worked: every reading of theirs in this case is doubted."
- **Put to Michael through Seneschal:** "Poisoned that night" also covers a Red Herring or a Marked misregistration, which aren't poison. "Fooled that night" would cover them.

## Small calls made on Michael's behalf

- The cause choice is shown only where Delusional is on the script. With no Delusional possible, the single Mistaken call stays as it was.
- The two choices sit one per row on the card, as a relay's sides do, because the 300-pixel card is too narrow for both labels.
- A Medium's passing-on doesn't offer "Delusional all along". The relay keeps its own choices.

## Proposed for the backlog

None.

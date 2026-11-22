# Quill: the Mistaken call's cause, and the shared-Delusion slate cases (mock/burdens-slot)

- **Agent:** Claude-Quill
- **Base:** `mock/burdens-slot` after 3062841f
- **Status:** pushed. This is the first part of the evidence side of the shared Delusion doubt, which Michael approved on Nov 22. The rest waits for Lantern's core.
- **Next actor:** Lantern, for the core and its stored fields (`workshop_state.own_delusion`, `workshop_state.delusion_of`, to be confirmed). Then me again, to point `source_doubt` and the juror at them.

## What changed

1. **The Mistaken call's cause** (Michael, Nov 22: the player picks it).
   - Under "Mistaken", the reading card offers "Mistaken that night" (the plain Mistaken call, that night's reading only) and "Delusional all along".
   - The live editor's side panel offers the same two as dropdown entries.
   - Both appear only where the script can deal Delusional; elsewhere Mistaken works as before. They aren't offered on a Medium's passing-on.
   - "Delusional all along" uses the existing Delusional challenge mode. That mode used to need a group of readings. On one reading it now covers every reading by the same reader in the case (`reading_challenges.gd` `reader_group`), so all of them take the same discount.
   - A call is refused where the script can't deal Delusional (`delusion_possible`, in `valid` and `canvas_model.add_modifier`).
2. **The slate's before-and-after cases** (3062841f, already pushed):
   - `seer_contradiction`: a Seer's "yes" then "no" on one pair, argued "readings don't fit together: Delusional".
   - `seer_contradiction_burden`: the same cards, argued "carries a hidden burden: Delusional".
   - A slate premise can now carry a cause or burden (`"inconsistent:delusional"`).

3. **The juror grades "carries a hidden burden" on the chance of being Delusional** (Michael, Nov 22). Until now it graded the premise through the subject's chance of being good, like every clearing premise. Now `listener_reading` asks the listener the premise itself, before and after the case (`_own_question_chance`, beside `_demon_share`), so readings that clash count for it. The badge's top tier still isn't offered, since the premise clears. `test_juror_listener` checks it (31 checks, 0 failures).
   - **On today's judge it overshoots:** `seer_contradiction_burden` goes from no badge (0.87) to Strong (179), with the listener at 2.5% → 82% Delusional. Lantern's worked curve has one strong clash at about 13%. Today's judge skips a Delusional reader's readings, so Delusion explains any clash for free, and it has no poison explanation for others' readings. Lantern's core (the uniform draw, and poison on others' readings) should bring this down. Rerun the case when the core lands. The suite only checks the direction, so it survives the change.

4. **The Test juror's listener holds the doubts a refresh holds** (Nov 22, after Lantern's core e592d23b). `ProfileJudge._evaluate` used to pass no doubt to `Shared.evaluate`, so the average listener never weighed poison on other people's readings, the core's new term. It now derives it with `SourceDoubt.derive`, and the juror's Demon-share and hidden-burden questions get the same doubts (`_ask`). `ProfileJudge.derived_doubt` turns it off for comparison, and the slate has `SLATE_NO_DERIVED_DOUBT=1`.
   - **The full slate both ways** (48 cases, 3 seeds each): one badge changes. `impossible` goes from Damning (177) to Strong (16), because an impossible reading now has an honest explanation, poison.
   - 25 cases move by under 1%. The Gravedigger and Dowser "0" cases lose about a tenth.
   - `seer_contradiction_burden` goes from 179 to 148, still Strong. These deals' scripts have no Poisoner, so lying and Delusion stay the only explanations of a Seer contradicting itself.

5. **An argued "carries a hidden burden: Delusional" moves belief in the burden, not the readings** (option (b), agreed with Lantern; his hook facb7262). In `source_doubt.gd` Pass 3 the flat discount on the subject's readings (0.7 × weight) is gone, because with the core it counted Delusion twice. The same number d = 0.7 × weight (capped at 0.9) becomes the odds 1 / (1 − d) on the subject's Delusional worlds (`case_data.delusion_odds`): about 3.3 at full weight, 10 at most. No new constant; `DOUBT_ARG_DELUSIONAL_SCALE`'s comment says what it means now, and `tuning_catalogue.md` is regenerated.
   - **Effect** on `seer_contradiction_burden`: before, the town's suspicion of the Seer rose by 0.00 to 0.16 when the player argued Delusion. Now it falls on five of six seeds (by 0.01 to 0.17) and rises by 0.01 on one.
   - So arguing Delusion now clears the reader, as the Workshop hint always said. The badge is unchanged, since the juror grades the cards' evidence.
   - **It moves golden,** because NPC refreshes use this doubt. On this branch golden isn't a gate.
   - **Counted once:** a presented case whose arg isn't certified stays unowned, so it reached a listener both as the player's word card and as these odds (Lantern's read of `shared_ledger.gd`). Pass 3 now skips any (X, Delusional) that already has a `word:secret` card.
   - **The 79% traced (Lantern):** it's the player's word, not the core. On a rare burden, the player's own "X carries a hidden burden" multiplies the odds about 60×, and the badge's before side doesn't have it. Without the word, lying wins (6% Delusional, 69% evil).
     - The choice is Michael's, through Seneschal: (a) leave the player's word out of the badge, which Lantern and I both recommend; or (b) set the word's false-arising chance from the burden's share of the deal.
     - Also his: the word or the odds as the single path for NPCs.

6. **"Is Marked" is graded on the listener's chance of the mark, not of being good** (Michael, Nov 22, a bug against the design; Lantern found a Marked case reading Weak with listeners 99% sure of the mark). `listener_reading` asks the premise itself for "marked" as for "secret_mod". `test_juror_listener` checks it (32 checks).
   - `marked_rescue` and `marked_bluff` both go from Weak to Strong, with the listener at 2.5% → 98.7% Marked. The Demon's bluff reads exactly as strong as the real holder's claim, because the player's word drives both. That's Michael's open choice (a).

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

## Status at Michael's soft pause (Nov 22, evening)

Everything is pushed; nothing is in flight.

**Current numbers, tip 70cedf80, which has Lantern's (b′): the player's word at its credibility.** 10 NPCs, seeds 1–6:

| Case | Badge | Strength | Listener's chance of the burden | Town's suspicion of the subject |
|---|---|---|---|---|
| `marked_rescue` | Strong | 205 | 2.5% → 84% Marked | up 0.07–0.23 |
| `marked_bluff` | Strong | 205 | 2.5% → 84% Marked | up 0.17–0.21 |
| `seer_contradiction_burden` | Strong | 10.1 | 2.5% → 20.5% Delusional | up 0.27–0.36 |

- The 98.7% and 79% figures above were measured before (b′) reached the branch, so these numbers replace them.
- Under (b′) the badge rates the burden Strong, while the town comes away more suspicious of the person. That's with Seneschal, for Michael.

**Waiting for Michael:**
- **Playtest 52102:** "nominate X #case" weighs the case silently (`_player_nomination`, speak = false). `case <#>` on an open nomination speaks (`hear_town`). This is for Herald or Beadle, and it's in Coroner's `docs/playtests/52102.md`, PR #526.
- **Card #76:** a block reading presented against a resident finds no subject. That's mine, from the same report, and waits for Michael's read.
- **Pass 3 odds:** they're effectively a dead path, because the player's word card carries burden premises in play. They come out if Michael keeps the word as the single NPC path.

**Next for me:** sign off the evidence area of the Burdens landing PR, after Argon's speed pass merges. Then the Call-on refusal check, once Beadle builds it.

## Wording

- **Approved by Michael (Nov 22):** "Mistaken that night" (Michael: "go with Mistaken", through Seneschal; it was briefly "Poisoned that night") and "Delusional all along".
- **Draft tips:**
  - "Something fooled the gift that night only: poison, or a misleading registration."
  - "Their gift has never worked: every reading of theirs in this case is doubted."
- **Settled:** "Poisoned that night" named only poison, though the call also covers a Red Herring or a Marked misregistration. Michael chose "Mistaken that night", which covers all three.

## Small calls made on Michael's behalf

- The cause choice is shown only where Delusional is on the script. With no Delusional possible, the single Mistaken call stays as it was.
- The two choices sit one per row on the card, as a relay's sides do, because the 300-pixel card is too narrow for both labels.
- A Medium's passing-on doesn't offer "Delusional all along". The relay keeps its own choices.

## Proposed for the backlog

None.

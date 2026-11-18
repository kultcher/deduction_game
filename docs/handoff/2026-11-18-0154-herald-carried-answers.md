# 2026-11-18, Claude-Herald: show carried answers when a case is filed (`claude/herald-carried-answers`)

- **Base:** main `940ce2c`. **Status:** PR open, zero drift. **Next actor:** Bailiff.
- **Source:** BACKLOG "Show carried answers when a case is filed" (playtest 23973, Coroner's note 1). Michael said yes on Nov 18, through Seneschal. The item is marked [decided] and moved to `BACKLOG_COMPLETED.md`.

## What changed

- **The problem:** an answer the player picks on a card stays on it, so a later case citing that card carries the answer along. In 23973, a Dowser answer naming Bart, picked for case #38, rode into case #78 and made Bart's reply clash.
- **Filing now says so.** When a case is filed with an answer identical to one an earlier filed case used, the status line names it: "This case keeps your earlier answer: Kiran's Dowser reading (Bartholomew). Clear it on the card if this case shouldn't use it." That's Michael's wording, Nov 18: my long draft without "picked for case #38". The plural form is "answers … them".
- **Presenting repeats it.** Presenting files first and then replaces the status line, so the presentation's result window shows the same note at its top.
- **What counts as carried:** only an answer identical to one in a different earlier case, and only one that still chooses something. A changed answer says nothing. So does a cleared one, including a selection cleared on the card, which keeps empty lists. Refiling the same case says nothing either, since it and its earlier revisions are followed through `revises`.
- **What the note names:** people picked (and Marked), streets, a Seer registration, a Town Hall role, or a Psychologist statement and why.
- **Code:**
  - `workshop/canvas_model.gd`: `carried_answers()` and `carried_answer_text()`.
  - `ui/live_case_workshop.gd`: a `filed_answers` record of each filed case's answers, kept in `g.workshop_draft` with the canvas, plus `carried_note()` with the wording.
- **New suite:** `tools/test_carried_answers.gd`, 9 checks. It's a UI suite, so it isn't added to the fast list.

## Decisions

- **Wording:** Michael settled the note's wording on Nov 18, as above.
- **Debug-only text:** Michael also said that debug-only text, such as the Test juror readout, needs no approval. That rule is now in `docs/DIALOGUE_DESIGN.md` §1.
- **Small calls made on Michael's behalf:**
  - The note appears on the status line and in the presentation result. It isn't a confirmation dialog, so it never blocks presenting.
  - An answer counts as carried only if it is unchanged.

## Measured

- Suites passed: `test_carried_answers` (new, 16 checks after Codex's three findings), `test_workshop_live_canvas`, `test_workshop_canvas`, `test_triage_nov16` and `test_workshop`.
- Golden is identical to `baseline_44073d9` at `--tol 0` on all 5 seeds.

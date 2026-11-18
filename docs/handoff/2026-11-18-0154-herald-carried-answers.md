# 2026-11-18, Claude-Herald: show carried answers when a case is filed (`claude/herald-carried-answers`)

- **Base:** main `878ddaa`. **Status:** PR open, expected zero drift. **Next actor:** Bailiff.
- **Source:** BACKLOG "Show carried answers when a case is filed" (playtest 23973, Coroner's note 1). Michael said yes on Nov 18, through Seneschal. The item is marked [decided] and moved to `BACKLOG_COMPLETED.md`.

## What changed

- **The problem:** an answer the player picks on a card stays on it, so a later case citing that card carries the answer along. In 23973, a Dowser answer naming Bart, picked for case #38, rode into case #78 and made Bart's reply clash.
- **Filing now says so.** When a case is filed with an answer identical to one an earlier filed case used, the status line names it: "This case keeps your earlier answer: Kiran's Dowser reading (Bartholomew), picked for case #38. Clear it on the card if this case shouldn't use it." The plural form is "answers … them".
- **Presenting repeats it.** Presenting files first and then replaces the status line, so the presentation's result window shows the same note at its top.
- **What counts as carried:** only an answer identical to one in a different earlier case. A changed or cleared answer, or refiling the same case, says nothing. When several earlier cases share the answer, the note names the earliest.
- **Code:**
  - `workshop/canvas_model.gd`: `carried_answers()` and `carried_answer_text()`.
  - `ui/live_case_workshop.gd`: a `filed_answers` record of each filed case's answers, kept in `g.workshop_draft` with the canvas, plus `carried_note()` with the wording.
- **New suite:** `tools/test_carried_answers.gd`, 9 checks. It's a UI suite, so it isn't added to the fast list.

## For Michael

- **The note's wording is a draft.** I recommend it as written. An alternative is shorter: "Kept from case #38: Kiran's Dowser reading (Bartholomew)."
- **Small calls made on Michael's behalf:**
  - The note appears on the status line and in the presentation result. It isn't a confirmation dialog, so it never blocks presenting.
  - An answer counts as carried only if it is unchanged.

## Measured

- See the PR for suites and golden. No sim code changed, so golden should be identical to the baseline.

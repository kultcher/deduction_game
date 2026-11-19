# 2026-11-19, Claude-Lantern: excuses soften a caught "I was home", and "I was out" is read as what it says (`claude/caught-lie-softening`; zero drift)

- **Base:** main `49b17ec`, with `claude/sleepwalk-bluff` (#367) merged in, since they change the
  same SourceDoubt lines. **Status:** PR open. **Next:** Bailiff, after #367. Beadle's #368
  supplies the excuse facts in play. Quill measures the effect once both are in.
- **Why:** Michael, Nov 19 (via Seneschal).
  - **The softening (Quill's form):** while an excuse stands, the good out-but-said-home rate for
    that night goes from 0.2 to 0.35. A contradicted excuse counts as a second caught lie at
    about half weight.
  - **The admission bug fix** (approved as part of the item): an NPC's own "I was out" lost its
    `home` flag on the way into the judge's view, so it read as another "I was home". The route
    check then forced that NPC home. Podium admissions ("Fine, I was out", `mind_podium.gd`)
    produce these today.
- **What changed:**
  - **The view** (`LiveAssessment.activity_card`): a `home: false` alibi becomes the teller's own
    sighting of themselves out (`admitted`), on the block they name, if any. The excuse tags
    (`excuse`, `excuses_night`, `duty_role`) pass through `LiveEvidence.FIELDS`.
  - **The marking** (`LiveAssessment._mark_excuses`, also run for the canvas view): for each
    excuse, that night's own "home" alibi carries `out_rate` = `EXCUSED_OWN_ALIBI_OUT` while the
    excuse stands, or `excuse_contradicted` once it's contradicted.
    - `admit` and `not_wicked` always stand.
    - A `duty` excuse is contradicted once the night is past and the view holds no report of
      that gift from its owner for that night, only the claimed duty.
  - **The movement model:** a good person's own "home" alibi reads the card's `out_rate`, in
    GDScript and in the C# kernel. It's packed in the alibi's spare second slot, and unexcused
    cards pack 0.2 exactly as before.
  - **SourceDoubt:** a contradicted excuse adds a second caught lie at `CONTRADICTED_EXCUSE_WEIGHT`
    of the first, combined as two independent doubts.
  - **The CaseEval compile key now includes `out_rate`.** Without it a softened alibi got the
    unsoftened cached answer, the same kind of hole as #344. The new test caught it.
  - **`card_model.short_text`:** an "I was out" card that names no place no longer crashes
    `C.block_name("")`; it reads "X: out". That's Herald's file, a one-line guard.
- **Two new constants (approved):** `Tuning.Workshop.EXCUSED_OWN_ALIBI_OUT` = 0.35 and
  `CONTRADICTED_EXCUSE_WEIGHT` = 0.5. The catalogue is regenerated.
- **In game terms:**
  - **The player's case against X**, X's "I was home" caught by the player's own sighting, reads
    ×8.0. With X's "Fine, I was out" standing and cited, it reads ×4.6. Part of that drop is the
    admission itself, which now reads as an outing.
  - **Hand-built, judged directly:** the chance X is evil falls from 0.51 to 0.37 with the softer
    rate alone.
  - **A contradicted excuse:** that night's doubt of X's word goes from 0.75 to 0.84, and the
    general doubt from 0.55 to 0.67.
  - **A case is judged on its own cards,** so the excuse counts where the case cites it. An NPC's
    own view holds every card it has heard.
- **An admitted outing is only its teller's word (Codex's finding).** If the teller is good, it
  reads as a sighting of them on the named block. If the teller is evil, they own the outing but
  may name any block: the named block (or no block named) counts in full, any other block at one
  chance in the number of blocks, and home not at all. No new constant. In a 7-person test town
  with a killing on the Square, P(X evil) is 0.33 to start. X admitting the Docks puts it at 0.56,
  where a witness seeing X on the Docks puts it at 0.23. X admitting the Square puts it at 0.79,
  about the same as being seen there (0.78). A tunable rate for lying about the place would be a
  new constant, so that's Michael's call. Like any sighting, it counts only as far as the
  listener credits hearing it (Codex's second finding): one it doesn't credit moves nothing.
- **New `tools/test_caught_lie_softening.gd`** (10 checks, fast list): the admission read as an
  outing; the marking; the softer judgement; a contradicted watch; the second caught lie; an
  admitted place may be a lie; an admission not credited moves nothing.
- **Measured:**
  - **Golden:** identical to `baseline_7a10762` at `--tol 0`; two captures were identical. No
    golden seed has an NPC admit an outing or give an excuse yet.
  - **Suites that pass:** `test_caught_lie_softening`, `test_sleepwalk_bluff`,
    `test_lie_severity`, `test_press_caught_out`, `test_meeting_flow`, `test_connections_core`,
    `test_connections_cache`, `test_workshop_regressions`, `test_evil_owned_lie`,
    `test_framed_defence` and `test_self_sighting`.
- **Not covered yet:** other contradictions of a duty excuse (the listener's own sighting
  elsewhere, a more-trusted holder of the role) only weigh through the existing checks. The
  excuse isn't marked contradicted by them.
- **Proposed for the backlog:** none.

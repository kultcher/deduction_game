# Believable public revisions: the judge and game side

- **Agent:** Claude-Quill
- **Base:** origin/main at the branch point of `claude/public-revisions`
- **Status:** PR open. The judge and game side are built. The UI and wording are Herald's.
- **Next actor:** Bailiff to review and merge. Herald to wire the button and write the line.
- **Item:** BACKLOG "Believable public revisions; withdraw or revise a case" ([decided]
  per Vicar's #254). Credibility rule: option (c) (Michael, Nov 18, via Seneschal).

## What changed

- **Public withdrawal.** `Game.workshop_withdraw_public(number)` (`GamePresentation.workshop_withdraw_public`)
  takes a filed case back for every NPC who heard it.
  - It applies the existing retraction to each of them: their presentation is erased and
    the `arg:workshop:<n>` ledger entry is zeroed. The cards the case cited stay with them
    as their own items.
  - The board card keeps everything and gets `withdrawn: true` and `withdrawn_day`.
  - It returns "" when done, or the reason it can't: already withdrawn, superseded (take
    back the latest version instead), not a filed case, or a presentation running.
  - It drops the case from each NPC's `player_cases`, so they stop gossiping about it, and
    logs `deduction_withdrawn`.
  - The private, one-listener retraction is unchanged, except that it now follows the same
    track-record rule.
- **Withdrawn cases are out of play.**
  - `on_deck_case` and `cases_naming` skip them, so they're no longer offered as the
    case behind a nomination. That was the 25923 symptom.
  - `_presentation_rejection` refuses them with "Case #N was withdrawn."
- **The track record, option (c)** (`game/credibility.gd`):
  - `record()` takes a `case_n` and notes which filed case argued each claim. The failed-gift
    "the reader is good" claim from #252 carries its case too.
  - `retire_case(n, case_n, clear_now)` acts on the claims that case still stands for.
    With `clear_now` it erases them. Otherwise it marks them `withdrawn`.
  - `dawn()` judges withdrawn claims like any other, then erases them.
  - A claim restated in the meantime, by a later case, a nomination or an accusation,
    overwrites the entry, so it stands.
- **Revisions** (`workshop_canvas_retire`): when a listener hears a revision, each older
  version they hold is retracted as before. The difference is in the track record:
  - If the revision cites an original card the old version didn't (`new_evidence`), the
    old version's claims leave at once.
  - Otherwise the old version counts as a bare withdrawal: judged at the next dawn, then
    cleared.
  - Adding a premise alone is not new evidence.
  - Someone who hasn't heard the revision keeps the old claim untouched.
- **Docs:** a DESIGN paragraph under "Rapport and credibility".
- **Tests:** a new suite, `tools/test_public_revisions.gd` (21 checks), added to the fast list.

## For Herald

- **The API:** `g.workshop_withdraw_public(number)` returns "" or a player-facing reason. I
  wrote these reasons as placeholders, so please reword them.
- **Where it goes:** I'd put it beside the case on the board and at the meeting. I haven't
  gated it to the meeting phase, so it works whenever the UI offers it.
- **The board card:** it carries `withdrawn: true`. The card list might show "withdrawn on
  the second day", as it shows "superseded by #N" today.
- **Wording to draft:** "I take back case #N", and an "I've changed my mind, because…"
  line for a revision with new evidence. `GamePresentation.new_evidence(old_card, new_card)`
  says which kind of revision it is.

## What I measured

- **Golden:** identical to `baseline_490cdcf` at `--tol 0`, all five seeds. Nothing in an
  autoplay game withdraws a case, so nothing in golden exercises the new path.
- **Suites:** these 21 pass.
  - Every suite that touches `claim_record`, retraction, supersession, `on_deck_case`,
    `cases_naming` or `credibility.gd`: test_board, test_demon_declaration, test_meeting_m2a,
    test_poison_outing, test_premise_step2, test_presentation_contracts, test_roles_secrets,
    test_roles_shelter, test_shared_model, test_social_credibility, test_social_trust,
    test_workshop_circumstantial_hub, test_workshop_hints, test_workshop_live_canvas,
    test_workshop_live_cognition, test_workshop_ownership, test_workshop_presentation,
    test_workshop_reading_challenges, test_workshop_refusals, test_workshop_tuning_probe.
  - The new test_public_revisions.
- **The #247 scenario**, 10 seeds from 1, about 4 good listeners each. A good Archivist's
  poisoned reading is called a lie in a case against them. Each variant then follows up
  differently, runs two dawns, and counts the good listeners still holding a claim on the
  Archivist:

  | Variant | After dawn 2 |
  |---|---|
  | Do nothing | 4 of 4 |
  | Public withdrawal | 0 of 4 |
  | Revision citing new evidence (a case at the Poisoner) | 0 of 4 |
  | Revision to "the Archivist is good" | 4 of 4, the new "good" claim |

- **Credibility didn't move in any variant.** It stayed at 0.70 over both dawns. The
  listeners' own evidence never shifts the Archivist from where they started, so the dawn
  check abstains on that claim, as it should. This is the same as #247 (credibility moved by
  0.01 at most). So in this scenario a withdrawal mainly changes what NPCs can cite and
  gossip about, not credibility. It would show where an NPC's own evidence does bear on the
  withdrawn conclusion. I haven't measured that case.

## Not done

- **"A revised case must not score below the version it replaces":** this is a Test-juror
  property, and it isn't built here. Adding evidence can lower a case's strength
  legitimately, for example when the new card conflicts with the rest. I'd want Michael's
  reading of the line before building a check.
- **BACKLOG:** not edited while Vicar's #254 restructures it. On merge, the item's "built"
  note can point here.

## Small calls made on Michael's behalf

- **No phase gate:** a public withdrawal isn't restricted to the meeting. The UI decides
  where it's offered.
- **A revision with no new evidence:** treated as a bare withdrawal of the old version, so
  it's judged at the next dawn.
- **Superseded versions:** you can't withdraw one directly. You withdraw the latest
  version, which is the one the town is acting on.

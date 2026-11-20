# 2026-11-19, Claude-Lantern: a Sleepwalker claim excuses a caught "I was home" only as far as its claimant may be good (`claude/sleepwalk-bluff`; zero drift)

- **Base:** main `74e6e74`. **Status:** PR open. **Next:** Bailiff. After that, Beadle's
  caught-out excuse ladder: I wire its softening in the same pass, once Michael has set its
  constants.
- **Why:** Michael approved it as a decided bug fix (Nov 19, via Seneschal). Quill found it in
  the secrets review, by reading the code.
  - **The rule:** when a listener's own sighting puts X out on a night X says it was home,
    SourceDoubt doubts X's word: 0.75 that night and 0.55 in general. That doubt weakens X's
    other sightings and readings.
  - **The bug:** a Sleepwalker claim cancelled the doubt outright, whoever made it. An evil X
    caught lying could say "I've been known to sleepwalk" and keep its other statements
    counting in full.
- **What changed (`SourceDoubt.derive`, the caught-alibi pass):** the excuse now cancels the
  doubt only in proportion to the listener's chance that X is good. The doubt stands at
  `DOUBT_CAUGHT_ALIBI_*` × the listener's suspicion of X.
  - **Why not per world:** the doubt is one number per teller, applied in every world. There's
    no world-dependent hearing weight to carry "excused where X is a good Sleepwalker, not where
    X is evil". So it's weighed by the listener's chance, the expectation over worlds.
  - **No new constant.**
  - **Note for the secrets rework:** if the Sleepwalker stays self-unaware, a good holder
    never knowingly claims it, and this exception goes. The code says so, pointing at
    `docs/design/secrets_rework.md`.
- **In game terms:** take a caught liar whom the listener suspects at 0.5, then bluffing
  Sleepwalker.
  - **Before:** its other sightings and readings counted in full again.
  - **Now:** they count at about 73% in general and about 63% that night (no excuse at all:
    45% and 25%).
  - **A claimant the listener is sure is good** is excused entirely, as before.
- **New `tools/test_sleepwalk_bluff.gd`** (5 checks, hand-built, fast list): the caught lie
  with no excuse; with the claim at suspicion 0, 0.3 and 0.8; a trusted claimant. Two of the
  checks fail on the old code.
- **Measured:**
  - **Golden:** identical to `baseline_ee15238` at `--tol 0`; two captures were identical. No
    golden seed has a caught liar claim Sleepwalker.
  - **Suites:** `test_sleepwalk_bluff`, `test_meeting_flow`, `test_press_caught_out`,
    `test_lie_severity`, `test_connections_core`, `test_gift_doubt` and
    `test_delusional_self_doubt` pass.
- **Proposed for the backlog:** none.

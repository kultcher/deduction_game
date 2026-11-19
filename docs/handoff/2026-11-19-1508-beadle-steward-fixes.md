# Steward's Nov 19 DEEP findings in Beadle's area: A4, A5, A6 and the Augur constant

- **Agent:** Claude-Beadle
- **Base:** main at 4cf1d73 (`baseline_2829999`)
- **Branch:** `claude/beadle-steward-fixes`
- **Status:** PR open. Zero drift.
- **Next actor:** Bailiff (review and merge). Herald, for the line below.
- **Source:** `docs/maintenance/2026-11-19.md` (#328), routed by Seneschal. The silent-skip
  sweep is a separate PR.

## What changed

- **A4, frame memory's reason in the reveal** (`sim/evil.gd`, `generate_fakes`):
  - **Before:** when a bluffer kept its earlier story (`_keep_frame`), the reveal showed the
    swapped-in alternative's own reason, such as `gives the other answer on ["Lian", "Merrin"]`
    or a raw role id, instead of the lie's motive.
  - **Now:** it keeps the motive the reading was made for and adds why it was changed: "its
    first version would have cleared someone its earlier readings pointed at, so it told this
    one instead". This is how the rework path already writes its note (Steward A2-A3, #224).
  - The note is reveal text. Herald may want to word it differently.
- **A5, an evil defender pointing at its own teammate** (`MindMeeting._day_whereabouts_defence`,
  #318):
  - An evil defender no longer picks a teammate as the "so was X" suspect, and doesn't name
    one among those it says were there.
  - With only teammates there, it gives the "seen in the open" line, which never claims it
    was alone, so it tells no new lie.
- **A6, the same defence:**
  - **The dead:** it names only the living. Asking the dead what they saw is no use.
  - **Casing:** the `{Place}`/`{When}` slots raise only the first letter ("Yesterday
    afternoon"). `String.capitalize()` used to give "Yesterday Afternoon" and split camelCase.
- **The Augur's crowd constant:** `DEMON_CROWD := 4` moves from `sim/roles/augur.gd` to
  `Tuning.Evil.AUGUR_DEMON_CROWD`. Seneschal says Michael approved it on Nov 18 (#264), and
  the comment records that. `tuning_catalogue.md` is regenerated.

## Checked, no change

- **The Medium's "why" ids** (`sim/evil.gd`, `_fake_medium_item`). Its reasons do write ids
  (`dd.id`, `s`), but they reach the reveal only through `generate_bluff_reading`, and the one
  caller, `generate_fakes`, passes every `why` through `Evil.named()` before logging it. The
  ids are named there.

## For Herald

- **The boxed-in liar's line** (`MindMeeting._say_gift_doubt`, `doubt_own_gift`) says
  "Something seems off about those readings…" even when the boxed-in reading was its first or
  only one. Fixing that is wording, a singular variant, so it's yours.
- **A6's casing** is now code-side. Every voice's `{Place}`/`{When}` keeps its wording.

## Measured

- **test_day_defence** has 4 new checks:
  - an evil defender leaves out its teammate;
  - with only its teammate there, it names nobody;
  - the dead aren't named;
  - slots raise only their first letter.
- **Also pass:** test_frame_memory, test_evil_play, test_bluff_blend, test_fabrication_check,
  test_too_clean_bluffs, test_roles_people, test_roles_registry, test_meeting_flow and
  test_dialogue_voices.
- **Golden:** identical to `baseline_2829999` at `--tol 0` on all five seeds.

## Proposed for the backlog

None.

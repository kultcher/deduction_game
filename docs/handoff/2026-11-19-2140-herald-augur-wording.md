# Herald: the Augur's reading names the morning or afternoon of its day

- **Agent:** Claude-Herald, with a three-line change in Beadle's `sim/mind_meeting.gd`.
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Michael decided this on Nov 19, through Seneschal. The Augur's reading always mentioned "evening", which sounded like when they crossed paths. The gift speaks in the evening about the morning and afternoon. He set the wording: "I crossed paths with the Demon in the morning or afternoon of <the Nth day>", with the day as an ordinal in speech.

- **`sim/roles/augur.gd`:** `_spoken_text(yes, day)`.
  - Yes: "I crossed paths with the Demon in the morning or afternoon of the second day".
  - No: "I didn't cross paths with the Demon in the morning or afternoon of the second day". This negation is mine; Michael approved it with the per-voice lines.
  - Every path passes the reading's day: the real reading, the bluff, its alternative, and the Medium's made-up relay.
- **`sim/mind_meeting.gd` `_info_intent`** (Beadle's file): a reading that already names its own day ("the second day") is said without the "This evening," / "On day 2, in the evening," lead. Other readings keep the lead.
- **Per-voice versions:** approved by Michael and wired in this PR (see below). The card keeps the canonical text.

## Measured
- **`test_augur_wording`** (new, 6 checks, on the fast list):
  - both wordings;
  - at the meeting, said with no evening in it;
  - days later, still naming the right day;
  - another gift's reading keeping its lead.
- **Passing:** test_case_script, test_connections_cases, test_connections_pairings, test_fixes_crowd_augur_lovers_pan, test_roles_people, test_roles_registry, test_too_clean_bluffs, test_meeting_flow and test_dialogue_voices.
- **Golden:** identical at `--tol 0` on all five seeds, since golden doesn't record this text.

## Proposed for the backlog
None.

## Per-voice lines (Michael approved, Nov 19)
- **The voices:** `augur_yes` / `augur_no` in all 15 voices, with a {day} slot, as drafted. Hollis's are Michael's own edit: "My path converged with the Demon's during the morning or afternoon of {day}." and "…did not converge with…".
- **Where they're used:** at the meeting and in private reports. `_info_intent` uses them when the reading names its own day. The card keeps the canonical text.
- **Tests:**
  - `test_augur_wording` (8 checks) checks every voice has both lines with the day's morning and afternoon, and Hollis's exact line.
  - `test_dialogue_voices`' key count rises from 252 to 254.
- **Golden:** still identical on all five seeds.

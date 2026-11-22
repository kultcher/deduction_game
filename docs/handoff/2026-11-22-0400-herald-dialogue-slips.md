# Herald: three dialogue slips from playtest 51795

- **Agent:** Claude-Herald
- **Base:** main.
- **Status:** PR open.
- **Next actor:** Bailiff. This PR moves golden, in reply text only, and re-baselines to `baseline_e2d39bd`.

## What changed, and why

Coroner's review of playtest 51795 (`docs/playtests/51795.md`) found three mechanical slips. These are corrections, not new wording.

1. **A capital after a run-on lead-in:** "If it helps, Last night, communing with the dead…" (also seen in playtest 23973). Some voices' lead-ins run on into the statement, ending in a comma, a dash or a lowercase word ("If it helps,", "…but", "Um, yes—"). After one of those, the statement now starts lowercase. "I", names and role names keep their capital. This is `Dialogue._continue_after`.
2. **The Martyr's tense:** "Last night, I have given my life over for Isolde". When a report leads with when it happened, the Martyr's line is now in the past: "Last night, I gave my life over for Isolde, should the town ever hang them." The card keeps its text.
3. **A numeral where a spoken day is wanted:** "On day 1, in the morning, on the Market…". It now reads "On the first day, in the morning…".

## Measured

- **Suites:** the dialogue suites (`test_dialogue*`, ten in all), `test_meeting_flow`, `test_augur_wording`, `test_martyr_bluff_quiet` and `test_roles_dead` pass. `test_augur_wording` pinned the old "On day 2" lead, so it's updated.
- **Golden:**
  - 54875, 692 and 98933 differ from `baseline_01f5290` in reply text only.
  - With `--ignore engine,reply`, all five seeds are identical: beliefs, votes and outcomes are unchanged.
  - Two captures were identical.
  - The new baseline is `baseline_e2d39bd`.

## Left for Michael

These are other wording items from Coroner's findings. They're sent to Seneschal as drafts, not built:
- `public_claim` lines that assume a delay on day 1;
- `support_vibes_for`;
- Nisha's register;
- showing carried slot answers when filing.

# Herald: Steward's Nov 19 findings A2, A6, A7, A8 and A9

- **Signed:** Claude-Herald
- **Base:** main at 4cf1d73.
- **Status:** PR open.
- **Next actor:** Bailiff. Beadle may want a look at the one-line casing change in his `sim/mind_meeting.gd`.

## What changed
These are from Steward's DEEP report (`docs/maintenance/2026-11-19.md`), relayed by Seneschal.

- **A2: typed "withdraw" only at the meeting.** `withdraw N` / `takeback N` used to take a case back anywhere. At night or in private, every listener un-heard it with no public moment. It's now refused unless the town is meeting, matching the button. The refusal is a draft with Michael: "You can only take back a case before the whole town, at the meeting." (`Game.WITHDRAW_OUTSIDE_MEETING`).
- **A6: slot casing.** The day-whereabouts defence filled `{Place}` / `{When}` with `String.capitalize()`, which gave "Yesterday Afternoon" and split names. Now only the first letter is capitalised (`MindMeeting._cap_first`). The other half of A6, naming the dead, is Beadle's.
- **A7: carried answers.** The carried-answers note named the false-statement reason by its id ("(lying)"). It now uses the chips' words: "(source lied)" / "(source misled)".
- **A8: accusation cards that aren't accusations.** A counter-claim card now reads "Edda: Kiran's claim is false". A relayed reading now reads "Lian relays a Dowser reading: Kiran". Both used to say "X accused Y". The two new card faces are drafts with Michael.
- **A9: the bare "hinted: ".** When a hint family has no name on this script, the cast list and the profile line leave the hint out instead of showing "hinted: " alone.

## Measured
- **New suite:** `tools/test_card_wording_fixes.gd`, 5 checks, on the fast list.
- **Suites:** `test_withdraw_ui` has a new refusal check, and `test_carried_answers` expects the new words. Both pass, as do test_day_defence, test_hint_cards, test_canvas_card_text, test_dialogue_voices and test_roles_registry.
- **Golden:** identical at `--tol 0` to the CI baseline on all five seeds.

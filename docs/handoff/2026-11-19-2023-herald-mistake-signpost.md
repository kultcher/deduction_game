# Herald: the way back from a wrong lie call, signposted

- **Agent:** Claude-Herald
- **Base:** main at 74e6e74 (after #361)
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Michael approved both options on Nov 19, through Seneschal. BACKLOG: "Recovering from a wrong 'lying' call: signposting". The way back already worked: revise the case, switch the challenge to Mistaken and present it again. Quill measured it on 10 seeds. Nothing pointed the player there, though, and a second case calling the reading Mistaken met only "Conflicting reading challenges need separate alternatives."

**(a) The refusal becomes a signpost.** `game/workshop_canvas.gd`:
- `player_issues` replaces that refusal, where the player reads it, when an earlier live case calls a lie on the same reading the new one calls Mistaken:
  > "You called {name}'s reading a lie in case #{n}. To call it a mistake instead, open case #{n} in the Workshop, change the challenge to Mistaken, and present it again: it replaces the old case for everyone who hears it."
- If that case was never heard: "…To call it a mistake instead, change the challenge in case #{n}."
- **Where it shows:**
  - the "Cannot present" refusal (`_presentation_gate`, and the strict path in `_evaluate_deduction_inner`);
  - the file error;
  - the Workshop's "can't judge" reasons.
- **What doesn't change:** the raw issue text, which is still used to route the refusal (`_all_authoring_validation_issues`).
- **A revision is never sent back to its own old version** (`versions_of`), so the path the signpost recommends is never refused by it.

**(b) "I was wrong: call it a mistake".** `ui/live_case_workshop.gd`:
- **On a lie call's context menu,** it switches the call to Mistaken. It's disabled where Mistaken isn't possible on this script, the same rule as the Mistaken chip.
- **Tooltip:** "Take back the lie: the reading was wrong, but honestly told." For a case someone has heard, it adds " Presenting the revision replaces case #{n} for everyone who hears it."
- **It's offered on lie calls nobody has heard too,** where it only switches the label, per Michael.
- **The Present button:** when the selected premise belongs to a case the town has heard and has changed since filing, it reads "Present the revision (replaces case #{n})". Presenting costs what it did (no free public correction, per Michael).

## Small calls made on Michael's behalf
- **The unheard variant** drops the draft's second "instead" ("To call it a mistake instead, change the challenge in case #{n}"), which read twice.
- **The revision label** shows for any change to a heard case, not only after the new action, since it's the same truth either way.
- **No status-line message after the switch:** that would have been new wording, and the button and the chip already show the change.

## Measured
- **`test_mistake_signpost`** (new, 21 checks, on the fast list). On the first seed with a Poisoner, it checks:
  - the signpost through the real presentation path, to a listener who heard the lie;
  - other issues untouched;
  - a revision that isn't refused by its own old version, filed over it and presentable to the same listener;
  - in the Workshop: the action, its wording and both tooltips, the switch, the Present label, and the action gone once the call is Mistaken.
- **Suites and golden:** in the PR.

## Proposed for the backlog
None.

## Codex fix (#363)
- **The bug:** the signpost took the newest filed case with the same lie call. If that was an unheard draft, it sent the player to revise a case that couldn't be what refused them, since only a heard case's call blocks the new one.
- **The fix:** a heard case now comes first, and an unheard one is named only when none is heard.
- **The check:** `test_mistake_signpost` (23 checks) adds a newer unheard draft with the same call. The check fails without the fix.

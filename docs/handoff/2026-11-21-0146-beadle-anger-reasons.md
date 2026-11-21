# Anger reasons: a distrustful refusal says why

- **Agent:** Claude-Beadle
- **Base:** main at `c2c5653` (`baseline_1d59c5a`, after #412)
- **Branch:** `claude/beadle-anger-reasons`
- **Status:** PR open. Golden is identical at `--tol 0` on all five seeds; no re-baseline.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "Anger reasons" [decided]. The tracking is Beadle's, the lines are Herald's.
  Approved Nov 19: the NPC voices the standing grievance the player has repaired least, and
  that line replaces its refusal line. Lines approved Nov 21.

## What changed

- **The hook:** `Mind._append_distrust` (the once-a-day line that explains a refusal) now
  voices `anger_<id>`, where `id` comes from `Mind.anger_reason(w, n)`. That is the open
  (unapologised) grievance with the most trust still unrepaired (drop minus repaired).
  - With no grievance any line covers, the old `distrust_action` and `distrust_outsider` lines
    stay.
- **The reasons:** `ANGER_REASONS` and `ANGER_PREFIXES` map the known player-action trust
  reasons to Herald's 17 ids. Only known actions are mapped; arbitrary reasoning text is never
  quoted.
  - "Spared X, whom I trust" maps to nothing, since it isn't a grievance.
- **Slots:**
  - `{day}` reads like "second day", because every voice writes "on the {day}".
  - `{subject}` is a name. A line that needs one is skipped when the person can't be found.
  - `{promise}` is "ward" or "vigil".
  - An overruled nomination's reason doesn't name the nominee, so `World` now tags that
    grievance with them (`Mind.tag_grievance`).
- **Fallbacks:** `ANGER_FALLBACKS` holds Michael's approved plain forms (Nov 21, via Herald). It
  is filled with the same slots and used as the line's `statement` and for any speaker without
  a voice.
- **Voices:** Herald's commit with the lines (17 keys, all 15 voices), cherry-picked.

## Measured

- **New:** `tools/test_anger_reasons.gd` (16 checks), on the fast list. It checks:
  - every reason is reachable, and nothing else maps;
  - every voice has every line, and every reason has its plain form;
  - the grievance repaired least speaks, and an apologised one is passed over;
  - slots are filled, including the nominee and the promise;
  - a fully repaid grievance no longer speaks, and the questions line only on its own day;
  - the outsider line still plays with no grievance, and no line at all when trust is high.
- **Codex on #487, fixed:** a grievance fully repaid by fading was still named; yesterday's question
  fatigue was voiced as "today".
- **Fixed fixture:** `tools/test_social_credibility.gd` cleared the remembered slight but not the
  grievance list before checking the outsider line. It now clears both. No game code changed
  for it.
- **Also pass:** test_dialogue.
- **Golden:** a capture against `baseline_1d59c5a` was identical on every seed. The golden
  games never reach a distrust refusal that has a grievance behind it.

## Proposed for the backlog

None.

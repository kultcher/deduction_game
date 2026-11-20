# Vicar: kill-score values approved; five built items closed (Nov 20)

- **Agent:** Claude-Vicar
- **Base:** main 07416df
- **Status:** docs only, ready for Bailiff
- **Next actor:** Bailiff; Beadle's #421 carries the values

## What changed and why

- **"Kill-score pass on every role"** records Michael's approved values (Nov 20), in Beadle's
  #421:
  - `KILL_IDENTIFIER_BONUS` 1.0 for the Seer, Augur, Dowser and Confessor;
  - `KILL_CLAIM_BY_ROLE`: Lamplighter and Psychologist 2.0, Warden 3.0, Sexton 2.0;
  - a spent Chronicler and a spent Executor at 0, with the Gravedigger at 3.0;
  - `REGISTRAR.public_threat_bonus` at 0.75.

  It closes when #421 merges.
- **Closed as built** (checked merged on main):
  - the "not the Demon" badge (#410);
  - the misframed-case hint (#398);
  - summarised answers at a nomination (#411);
  - removing drops (#397);
  - the social presentation route (#395).

  The audit item drops its `LEGACY_MUD_DROPS_ENABLED` line, which went with #397.
- **The contents list** is regenerated.

## Checked

Docs only. The merges were checked in `git log origin/main`.

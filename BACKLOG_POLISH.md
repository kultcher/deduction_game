# Demonologist backlog: polish

Presentation-only work: flavour, wording, voices and visual flair. Nothing here changes what anyone
knows, believes or decides. Moved out of BACKLOG.md on Oct 26; same tags.

- **Headline flair.** (user, Oct 26) The text-only headline notices (Codex batch 3) get more flair:
  animation, icons, sound, per-event treatment. [decided: later]

- **Nominations make a case.** The nominator cites several cards, even weak ones.
  Mostly flavour; it only moves NPCs if it brings new information. [decided]

- **Dialogue voices for the rest of the cast.** The composer is merged (Agnes,
  Bartholomew, Constance × five situations; dialogue lab at `ui/dialogue_lab.tscn`).
  Everyone else uses the plain lines until they get a voice. [decided, later] 54875: on
  day 1 Dorian and Odette gave word-for-word identical gift refusals and night alibis
  ("Whether I have a gift is my own business"; "At home all night, same as any honest
  soul"), which makes the town read as one person.

- **Card zoom and text extension.** Settle card sizing, clipping and zoom/detail
  transitions before extending rich text onto board cards, pinned deductions, the
  tray and Card List. The shared formatter, log and profiles are built (steps 1–3);
  steps 4–5 are deferred. Card List/working-set rows are wrapping Godot Trees with
  one colour per row; richer rows still need custom cells or replacement controls.
  See [the handoff](docs/text_system_handoff.md) for hooks, issues and alternatives.
  [decided: extension deferred; renderer approach open]

- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]

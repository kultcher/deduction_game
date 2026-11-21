# Demonologist backlog: polish

Presentation-only work: flavour, wording, voices and visual flair. Nothing here changes what anyone
knows, believes or decides. Moved out of BACKLOG.md on Oct 26; same tags.

- **Headline flair.** (user, Oct 26) The text-only headline notices (Codex batch 3) get more flair:
  animation, icons, sound, per-event treatment. [decided: later]

- **Card zoom and text extension.** Settle card sizing, clipping and zoom/detail
  transitions before extending rich text onto board cards, pinned cases, the
  tray and Card List. The shared formatter, log and profiles are built (steps 1–3);
  steps 4–5 are deferred. Card List/working-set rows are wrapping Godot Trees with
  one colour per row; richer rows still need custom cells or replacement controls.
  See [the handoff](docs/archive/text_system_handoff.md) for hooks, issues and alternatives.
  [decided: extension deferred; renderer approach open]

- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]

- **Being lied about can pull in evidence that clears the liar** (Michael, Nov 20; seed
  100002).
  - **What happened:** Edda's core, re-anchored on the night she was lied about, takes in a
    rumour that "one of Bart and Jory is Delusional". That undercuts Jory's watch of Hollis,
    and Hollis falls 78% → 71% overall.
  - **Seed 100002 was resolved by #474** ("A sighting places its teller"): Hollis's lie now
    counts against him by about 7 points.
  - **Moved here (Michael, Nov 21),** since it's unlikely to matter much in most games. It's a
    belief item, not presentation, so it's the exception to this file's rule, kept here as
    low priority.
  - **Interim:** #454's check (#139) uses Michael's option (a). It reads the card's effect
    within its own night, and its comment points to this item.

  - **Decided (Michael, Nov 21):** firsthand means only what the NPC itself read, saw or did.
    Someone else's sighting of it on a night it was home no longer seeds its core, but still
    counts fully against the teller. Lantern's figures, as relayed: Lian 82% → 92% on 100100,
    and 62% → 99% on 100027. Built on `mock/burdens-slot`; it lands with Burdens, and
    this item closes then. Still being measured: whether the NPC's own sightings and vigils
    should seed its core. See `docs/belief_model.md`.

  Owner Lantern. [decided; lands with Burdens]

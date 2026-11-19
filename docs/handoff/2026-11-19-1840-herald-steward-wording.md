# Herald: Steward's wording set, as Michael approved it (Nov 19)

- **Signed:** Claude-Herald
- **Base:** main at the time of branching (after #335 and #337).
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed
This is wording from Steward's Nov 19 DEEP report (items in section 5). Michael approved all of it on Nov 19, via Seneschal.

- **Workshop card notes in the player's words** (`game/workshop_canvas.gd`):

  | Was | Now |
  |---|---|
  | "Adapter available · testimony and circumstances, not proof of evil" | "Testimony and circumstance: not proof of evil." |
  | "Adapter available · experimental joint activity/trace comparison" | no note |
  | "Adapter available · Town Hall census (…)" | "Town Hall records: exactly one of these two gifts is in play." |
  | "Adapter available · location context; …" | "Where someone was: not a sign of guilt on its own." |
  | "Adapter available · Medium relay …" | "A passed-on reading: a challenge says which part failed, the passing-on or the original." |
  | "FALLBACK: …" (four of them) | "The Workshop can't weigh this card yet." and its three specific forms |

  - **The `fallback` flag:** whether the Workshop can weigh a card used to be read from the note's "FALLBACK" prefix, in four places. It now comes from a `fallback` flag on the card: the challenge menu, the answer window, the unsupported badge, and two tests.
  - **No "UNSUPPORTED:" relabel:** the UI no longer rewrites "FALLBACK:" to "UNSUPPORTED:".
  - **Empty notes:** an empty note isn't shown.
- **Menu labels:** "Add readings from ▸" / "Add all readings about ▸". These were in capitals.
- **Card list:** "taken back on day N" (was "withdrawn on day N").
- **The "why" panel** (`game/workshop_why.gd`):
  - "Everyone who claims the Seer's gift, read together" (was "Every Seer claim, read together").
  - "All the night cards, read together" (was "Every night card, read together").
- **Numbered nights:** unchanged, as Michael ruled. Numbers on cards and panels, ordinals in speech.

## Not yet worded (proposed to Seneschal)
Three notes of the same kind weren't in Steward's list. They still read as developer notes:
- "Reading adapter available · check whole-case support" (on every reading)
- "Weak teller testimony · no original-source identity or gift proof"
- "BLOCKED: original evidence is missing or changed"

## Measured
- **Suites:** test_roles_night_sight, test_workshop_live_activity, test_withdraw_ui, test_workshop_nav, test_workshop_live_ui, test_workshop_ui, test_workshop_remaining, test_workshop_live_canvas, test_ui, test_canvas_card_text, test_workshop_why and test_connections_why pass.
- **Golden:** identical at `--tol 0` on all five seeds.

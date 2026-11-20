# Herald: remove the social presentation route and every presentation fallback

- **Agent:** Claude-Herald
- **Base:** main (after #391)
- **Status:** PR open
- **Next actor:** Bailiff. When it merges, tell Beadle (the `spare_pref` follow-up) and Vicar (close the item).

## What changed and why

Michael decided two things on Nov 20, relayed by Seneschal:
1. Remove the old social judge for presented cases (`PresentationReply._social` → `refresh_beliefs` + `_conflict_pressure`); don't relabel it.
2. "Confirm that nothing leads down those paths and just purge them and the fallbacks entirely."

Zero drift: golden is identical.

### What I confirmed, by reading the callers

- **`_social`** had one caller: a listener's reply to a filed case, when the shared assessment returned nothing. That only happened for:
  - "protect X" / "spare X" cases, which the player can't file (no Workshop premise type; `conclude`/`deduce` are retired);
  - bare beliefs with no evidence, which the Workshop refuses to file;
  - evil listeners on one of those.

  Golden's 5 games and 8 ten-NPC autoplay games logged none.
- **Delivery "model", "Existing rules (explicit route)", and "existing response rules were used"** could only show for a result the shared assessment didn't weigh. The only remaining source was an evil listener whose good self was refused by a listener-specific exit, which then answered through its mask anyway. That evil listener now refuses too, as a good listener would. So every delivered result is shared, and the field and both strings go.
- **`_conflict_pressure`** returned at once unless its `fallback` flag was set, and only the removed branch set it. Its other two calls already did nothing.
- **"Legacy fallback" reporting** (`shared_fallbacks`, `legacy_fallback`, the `fallbacks` command, the "[dev] The legacy rules judged…" morning note, `case_summary.legacy_fallbacks`) counted listener-specific exits. Those are guards, not a route: no legacy rules exist to judge anything (migration_notes audit B).
- **`fallback_count` / `present_fallbacks`** counted a raw card with no clear direction falling flat. That's live behaviour (the listener says "I'm not sure what you're trying to prove"), not a fallback.

### Deleted

- **The social judge:** `PresentationReply._social`, `_record` and `POSITIVE`. If the shared assessment returns nothing for a good listener, the reply is an empty refusal; that's unreachable in play.
- **The gate's extra branches:** protect/spare and bare speech, `_bare_speech` and game.gd's forward. A bare case now meets the ordinary refusal with its issues.
- **The post-evaluate branch** for an unweighed result (`refresh_beliefs` + `_conflict_pressure`).
- **`_conflict_pressure`:** the function, game.gd's forward, and its two no-op calls.
- **`_workshop_native_social`** and the `{}` branch in game.gd's `workshop_present` callback.
- **"protect" and "spare" conclusion types** in `sim/deduction.gd` (Lantern's OK): the types, their wording and the positive list. In Beadle's `sim/mind.gd` (his OK): their `_apply_conclusion_pref` arms and the two types in the good-leaning list.
- **`Tuning.Presentation`:** its four constants were read only by `_social`. `tuning_catalogue.md` is regenerated.
- **The "model" field:** from deliveries, comparisons and the `argument_stance` log, plus the duplicate comparison key. The delivery list shows each listener's name and issues.
- **The fallback bookkeeping:** `shared_fallbacks`, `_fallbacks_reported`, the `fallbacks` command and its help entry, `_fallbacks_text`, the morning dev note, `fallback_count`, and `case_summary.present_fallbacks` / `legacy_fallbacks`.

### Kept, and why

- **The listener-specific exits stay as guards:** an unprepared plan before or after a refresh, an unready listener at the gate, and "ownership was not activated". Each keeps the listener's last good beliefs, and a presentation to them is refused with the reason. `WorkshopOwnership.fallback` is now `unprepared`. It records the exit once per listener, point, card and day in `g.unprepared_plans`, the `unprepared` dev-log entry and the `workshop_unprepared` trace. That's diagnosis only, since none should happen. I didn't add `push_error`: several suites trigger these exits on purpose, and the error output would read as failures.
- **A directionless raw card still falls flat;** only the names changed (`_present_flat`, log type `present_flat`).
- **The card flag:** the Workshop's per-card `fallback` flag (meaning "the Workshop can't weigh this card") is renamed `unweighable` in game/, ui/ and the tests that read it.
- **Golden's end record keeps its key:** it still writes the list under `"fallbacks"`, which is always empty, so the baselines stay byte-identical.
- **Tools follow the rename:** autoplay prints `unprepared=`, and its metrics, `sweep_record`, `sweep_report` and `replay_54875` read `unprepared_plans`.
- **Untouched (as Seneschal asked):** Beadle's accusation and defence replies, and the ward and vigil requests.

### Follow-up for Beadle

`spare_pref` now has no writer. That leaves the `persuaded_to_spare` vote term, `VOTE_SPARE_PREF_SLOPE`, `spare_preference` in the vote inputs, and the field itself without a writer. `protect_pref` stays live, because a "good" conclusion still writes it.

## Small calls made on Michael's behalf

- **The four `Tuning.Presentation` constants are removed** with the route.
- **An evil listener whose good self was refused now refuses too,** where it used to answer through its mask. Unreachable in golden, it removes a role tell, and it makes "shared" the only result.
- **`unprepared_plans` is kept** as a diagnosis list for the guards. I didn't add `push_error`.
- **Tests:**
  - `test_shared_model` and `test_workshop_ownership` checked preferences derived from ledger metadata. They now use a "good" conclusion and `protect_pref`, and the `spare_pref` part is cut.
  - `test_mechanics_conclusions` loses its protect/spare section.
  - The suites that read the fallback list now read `unprepared_plans`, and their labels say so.
  - `test_workshop_live_canvas` checks deliveries by listener and issues instead of "model".

## Measured

- **Golden:** identical at `--tol 0` on all five seeds, after each stage (route, constants, purge).
- **CI fast and slow lists, plus every touched suite:** run locally; the result is in the PR.

## Proposed for the backlog
None.

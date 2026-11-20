## Nov 20 — Claude-Lantern: purge phase 8, the naming sweep

- **Base:** main `d168c82` (phase 7, #382, and the channel stack, #383, merged).
  **Status:** PR open. **Next:** Bailiff. Zero drift.
- **What this is:** section 6 of `docs/connections_purge_plan.md`, plus audit B's
  belief-related leftovers (decision 7). It catches names, comments, report text, test headers
  and docs that still describe the earlier belief model, its switch, or "today's" model, now
  that only the connections model exists. Every renamed key was checked against golden first:
  golden records no dlog entries and no `case_summary`.
- **Renamed:**

  | Old | New |
  |---|---|
  | `g.shared_fallbacks`, `g._fallbacks_reported` | `g.unprepared_refreshes`, `g._unprepared_reported` |
  | `WorkshopOwnership.fallback()` | `WorkshopOwnership.unprepared()` |
  | dlog type `legacy_fallback` | `unprepared_refresh` |
  | trace event `workshop_fallback` | `workshop_unprepared` |
  | `case_summary.legacy_fallbacks`, sweep record and autoplay metrics | `unprepared_refreshes` (`sweep_report.py` still reads the old key in old records) |
  | `Tuning.Workshop.PREMISE_SHAPING_TYPES` | `PREMISE_ALIGNMENT_TYPES` |

  The dev report now says "N unprepared refreshes" and no longer claims that "the legacy rules
  judged N things". Kept on purpose: golden's end-record key `"fallbacks"`,
  `origin_certainty: "legacy_receipt"` (a data format that is in golden), the `fallbacks` dev
  command, and `fallback_count` / `present_fallback` (still live: cards `present` can't point
  either way).
- **Reworded:**
  - **Comments:** "off by default", "the switch", "with the model on", "today's" and "native
    rules" in `connections.gd`, `shared_ledger.gd`, `workshop_ownership.gd`, `workshop_why.gd`,
    `workshop_canvas.gd`, `workshop_presentation.gd`, `live_assessment.gd`,
    `reason_attribution.gd`, `fixture_seeds.gd`, the profile and replay tools, and about 15 test
    headers.
  - **`sim/tuning.gd`:** the `SUSPICIOUS_*` comments described the deleted half-weight hearing.
    `tuning_catalogue.md` is regenerated; no value changed.
  - **Unused `Connections` preloads:** deleted from five suites.
  - **Archive links:** the links to `docs/legacy_retirement_plan.md` now point at
    `docs/archive/`.
- **Docs:**
  - `docs/DECISION_INSPECTOR.md`'s why section is rewritten around the connections report. The
    earlier stage-by-stage report it described was deleted in phase 5.
  - `README.md`'s `workshop_why` and dev-log rows.
  - `docs/premises_plan.md`: a status line, and a "superseded" note on the half-weight hearing.
  - `docs/balance_sweep.md` and `docs/belief_model.md`'s status.
  - `docs/migration_notes.md` audit B: each item now says where it stands.
- **Fixed on the way:** `tools/profile_workshop_town.gd` stopped parsing in phase 7. It set
  `Support.reuse_comparisons` / `reuse_batches`, which phase 7 deleted. Those two switches are
  now gone from it.
- **Not in this PR:**
  - **`headline` names:** they wait for 6a, which isn't built this round.
  - **The presentation route's `"legacy"` label:** Herald's strict-mode PR renames it to
    `"social"` (it's the social judge) and removes the canvas's `"mode": "legacy"`, so I left both
    alone.
  - **Player-facing wording is Michael's**, with drafts sent to Seneschal: the result label
    "Existing rules (explicit route)", the canvas warning for a case the town can't weigh, and
    DESIGN.md's Insight row, which I recommend settling with 6a.
  - **`legacy_evidence`:** it goes with `ledger_audit.gd` in the Workshop scaffolding PR, after
    Quill's drops removal.
  - **The `legacy_path` stub in `jury.gd`:** it goes once Herald's fixture-mode PR removes its
    only reader.
- **Small calls made on Michael's behalf:**
  - "unprepared refresh" as the name for what the dev report used to call a legacy fallback.
  - `PREMISE_ALIGNMENT_TYPES` as the constant's new name (section 3 of the plan asked for a
    rename).
- **Proposed for the backlog** (sent to Seneschal):
  - retire `tools/connections_prototype.gd`, since the model it prototyped is now the game's;
  - a dead branch at `game/game.gd:335-336`: `_workshop_native_submission` is only ever set
    together with `_workshop_native_social`.
- **Measured:**
  - **Golden:** identical to `baseline_9ea3f99` at `--tol 0` after merging main (2e4c24f); two captures
    were identical.
  - **Before the merge:** 23 suites passed (every edited suite plus the ownership and
    presentation ones).
  - **After the merge:** 14 suites passed: the ownership, presentation, meeting, connections, why and premise suites.

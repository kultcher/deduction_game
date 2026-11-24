# 2026-11-24, Argon: claimed-burden word scale (`0.70`), Mistaken docs, and PR #554 record

- **Agent:** Argon
- **Base:** `main` at `2cc77f1f` (`argon/marked-word-scale`)
- **Status:** PR open against `main`, awaiting green CI and Codex review for merge.
- **Next actor:** Argon (covering merge while Bailiff is paused).

## What changed and why

1. **Claimed-burden player-word scale (`0.70`, Michael, Nov 23 — the Marked "middle option"):**
   - **`sim/tuning.gd`** (`Tuning.Workshop.PLAYER_WORD_CLAIMED_SCALE = 0.70`) & **`tuning_catalogue.md`**: added the scaling factor for `word:secret` cards when the listener already holds an unquoted `secret_claim` for that `(target, mod)`.
   - **`workshop/shared_ledger.gd`** (`_add_player_words`): when `view.cards` already contains an unquoted `secret_claim` matching `(claim.target, claim.mod)`, scales `word_rel = player_weight * Tuning.Workshop.PLAYER_WORD_CLAIMED_SCALE` instead of using full `player_weight`. Unclaimed-burden deductions keep full `player_weight`.
   - **`tools/test_premise_step2.gd`**: added `_claimed_burden_word()` verifying that a claimed burden scales `reading_reliability` by `0.70` (`0.85 -> 0.595` at `cred = 0.7`) while an unclaimed burden retains full `0.85`.
2. **Mistaken documentation updated (`docs/evidence_catalog.md`):**
   - Left Mistaken call behavior unchanged (keeping ungrounded `"Mistaken that night"` calls at the player's credibility via `SourceDoubt._player_failed_gift`, `0.20`–`0.80` honest doubt).
   - Updated `G4` (noting `PLAYER_WORD_CLAIMED_SCALE = 0.70` on already-claimed burdens) and `G7` (replacing the stale `"nothing when ungrounded"` line with the actual rule: ungrounded `"Mistaken that night"` counts at the player's credibility whenever the script allows an honest cause, while ungrounded `"Suspected lie"` and `"Delusional all along"` count for nothing).
3. **Record of PR #554 (`2cc77f1f`, commit `f2a754d3`, Michael, Nov 23 — undocumented on `main`):**
   - **`game/workshop_canvas.gd`** (`test_juror`): gated `points_elsewhere` on **both** the full-weight `CaseEval` shape band (`shape_cat in POINTS_ELSEWHERE_BANDS`) and the dampened `heard` band (`result.category in POINTS_ELSEWHERE_BANDS`). Fixes case `#21798`, where a case whose own shape moderately supported the target was falsely flagged `"points elsewhere"` once hearing weights dampened its band while full-weight `ev.rivals` still cleared the rival bar.
   - **`tools/test_points_elsewhere.gd`**: added the case `#21798` regression fixture verifying that a full-weight-supported, heard-dampened case is not flagged `points_elsewhere`.
   - **`BACKLOG.md`**: added open item *"Drive 'points elsewhere' from `heard` (`ProfileJudge`) instead of full-weight `CaseEval`"* under Small features and tuning → Cases and the Workshop.

## What was measured

- **Marked middle-option probe** (10 NPCs, seeds `1, 3, 4`, initial suspicion `0.25`, `cred = 0.7`):
  - Current `1.00`: `marked_rescue` Marked `2.5% -> 84.0%`, ΔSusp `-0.234` (`0.016`); `marked_bluff` ΔSusp `-0.198` (`0.052`).
  - `0.65`: `marked_rescue` `72.4%`, ΔSusp `+0.001` (`0.251`); `marked_bluff` ΔSusp `+0.031` (`0.281`).
  - `0.75`: `marked_rescue` `75.4%`, ΔSusp `-0.052` (`0.198`); `marked_bluff` ΔSusp `-0.022` (`0.228`).
  - Chosen **`0.70`** sits right between `0.65` and `0.75`.
- **Verification**:
  - 13/13 targeted GDScript suites passed (`0` failures): `test_premise_step2`, `test_juror_listener`, `test_own_burden_knowledge`, `test_burden_corroboration`, `test_burden_ill_omened`, `test_burden_unrequited`, `test_burden_unrequited_walk`, `test_shared_delusion`, `test_delusional_reading`, `test_points_elsewhere`, `test_workshop_presentation`, `test_workshop_reading_challenges`, `test_tuning_hoist`.
  - Passive golden (`baseline_1bf8a4b`) is unaffected (no player presentations run in passive golden; verified by Linux CI `--tol 0`).

## Proposed for the backlog

None (PR #554's `points_elsewhere` follow-up is already in `BACKLOG.md`).

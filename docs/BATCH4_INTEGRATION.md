# Batch 4 and decision-inspector integration

PR #25 (`codex/backlog-batch-4`) reconciles batch head `29ef9b5` with current main `f4383a7` (including inspector PR #24). Main was merged into the feature branch; PR #25 remains unmerged.

## Resolution

The only textual conflict was in `Mind.answer_night`: main instrumented the old 60% trusted-friend sighting-omission check, while batch 4 item 10 deliberately removed it. The resolution keeps the approved batch behavior: one 95% direct-answer willingness roll replaces the old Gossip cutoff/count and trusted-friend omission, with privacy/cover, teammate and withheld-reading protections intact. It does not restore the old filter.

The merged code also observes the new batch decision points:

- `direct_night_sightings` uses the original single willingness draw and reports its exact 0.95 cutoff/chance and eligible-sighting count.
- `refused_whereabouts_slip` reuses the existing slip sample and computed cutoff, with raw Composure/pressure inputs.
- `volunteer_night_sightings` reports Gossip, Confidence, effective paranoia, score and threshold. This gate is deterministic and shows N/A rather than an invented random percentage; subsequent eligibility/cover checks still apply.

Pinned Roles, trait flashes, map-label placement and inspector window/preferences coexist. New-case binding retains independent pin/Debug preferences and replaces the inspector buffer with the new case's setup observations. Capture remains independent of detailed file tracing.

No vote/nomination/request formulas, search behavior or drop odds changed. Scope audit checks the unchanged bodies against the prior batch head (excluding only main's added diagnostic vote-input fields). Evil code matches main's observational instrumentation; no extra evil strategy changes were made. No edits to `workshop/`, `game/workshop_*.gd`, or `test_meeting_stream.gd`.

## Validation on Godot 4.7.2

- Full suite with `--include-slow --timeout 1800`: **84/85 passed**. The additional suite is the imported decision-inspector suite.
- Sole failure: the previously approved `test_workshop_protection` baseline, `disabling shared model restores native quiet-night credit`.
- **474 batch-4 checks** and **68 inspector checks** pass. New inspector regressions cover private willingness success/refusal, low Gossip and trusted friends, exact draw/RNG preservation, private telling/account bookkeeping, deterministic volunteering, refusal slips, pinned Roles plus the inspector, and new-case rebinding.
- All six complete-case trace comparisons pass (45 checks). `test_social`, `test_text_ui`, the UI suites, and unchanged `test_meeting_stream` pass.
- Existing batch behaviors remain tested; no assertions were loosened or seed trajectories tuned during reconciliation.

## Replay 54875

The verified pre-reconciliation run is compared with the combined code with capture disabled and enabled. Both combined runs have identical commands/replies, listener assessments, agreements, vote margins and final outcome to the prior batch. All retain filed #94, nine shared listeners, zero native listeners/fallbacks and **2 yes / 5 needed**.

| Run | Sum of command times | Day 2 meeting entry | Case presentation |
| --- | ---: | ---: | ---: |
| Pre-reconciliation batch | 10.747 s | 2.730 s | 3.393 s |
| Combined, capture off | 10.674 s | 2.769 s | 3.387 s |
| Combined, capture on | 9.898 s | 2.577 s | 3.123 s |

These are sequential single headless samples with console mirroring off; they show no apparent command regression and do not benchmark rendering an open inspector. They do not reverse item 10's earlier measured trajectory change. The original findings and revert boundaries remain in [the item-10 reference](BATCH4_ITEM10_REFERENCE.md). Test/replay artifacts are retained under ignored `logs/batch4-integration/`.

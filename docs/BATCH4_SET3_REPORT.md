# Batch 4, set 3: implementation and validation

Branch: `codex/backlog-batch-4`, continuing from set-2 head `d55119c`; main base `193b636`. Eight feature/verification commits, one per implemented item, plus the item-10 reference and this report. The final narrow-row correction was folded into item 15; commit IDs below are the final IDs. No merge. The separate decision-inspector branch is unchanged.

## Item 10 performance and revert note

[Durable reference](BATCH4_ITEM10_REFERENCE.md) identifies `0558f95`, its two independent behavior changes, tests and revert dependencies. Saved counterfactuals attribute most of the observed slower trajectory to the private-answer half: public-only presentation 3.157 s, private-only 3.588 s, versus 3.154 s before either change. Explanation candidate counts stay at 8,551, while retained facts across nine listeners rise 185 to 210; most additional presentation self-time is in evaluation. Meeting entry was not deeply profiled. These measurements support a changed-context/RNG trajectory mechanism, not a proven cost breakdown for every command. No revert, evaluator optimization or gameplay tuning was applied.

## Implemented items

All listed focused suites passed. `test_backlog_batch4` is cumulative; its final run passes 424 checks.

| Item | Commit | Result | Focused suites |
| --- | --- | --- | --- |
| 15 | `6e4c66e` | Busy cast status comes first so badges cannot clip it away; go warns about the partner without changing movement. | `test_backlog_batch4`, `test_town_ui`, `test_text_ui` |
| 16 | `a3302e3` | Help documents offers, apologies, yes/no requests, gift targeting, gift questions and ward/sigil presentation. | `test_backlog_batch4`, `test_text_ui`, `test_text_terms` |
| 17 | `0383420` | Space, comma and and separators produce identical Seer request targets, decisions and RNG; invalid names still reject before rolling. | `test_backlog_batch4`, `test_npc_interactions`, `test_text_ui` |
| 18 | `a1e6bb6` | Night entry/look lists living home markers by block, matching the planning map without exposing resolved excursions. | `test_backlog_batch4`, `test_text_ui`, `test_outcomes` |
| 20 | `1c5b682` | Grimoire includes each secret modifier alongside the independent personal secret. | `test_backlog_batch4`, `test_fixes`, `test_outcomes` |
| 21 | `389c0fb` | Zero/impossible count reasons name their actual Hearthwitch or Dowser source; strengths and formulas are identical. | `test_backlog_batch4`, `test_dialogue_decisions`, `test_text_ui` |
| 22 | `0aab4fd` | Creation-time causes are retained; healthy Medium fabrication relays are labelled. Missing causes have an honest fallback, including old lies entries. Truth flags and fake generation are unchanged. | `test_backlog_batch4`, `test_text_ui` |
| 23 | `b57bb68` | Original 37291 event 466 becomes a regression fixture. Ordinary go/search finds the owned wharf drop; wrong-location, repeat and deceased-owner cases are checked. Existing search needed no production change. | `test_backlog_batch4`, `test_fixes`, `test_text_ui` |

## Pending item 19

The spec does not define the side-panel interaction, layout defaults or flash duration and says: “Where the spec is silent or conflicts with the code, stop and report rather than choose.” An asynchronous question remains open: approve a “Pin as side panel” Roles toggle beside the profile, session-only placement, collision-aware map-name offsets and a one-second flash using each trait's existing colour; or defer this item. No dependent UI implementation has been applied. This item remains outstanding rather than silently canceled.

## Validation and scope

- Full runner on Godot 4.7.2: **83/84 suites passed** using `--include-slow --timeout 1800`.
- Sole failure: approved existing `test_workshop_protection` baseline, `disabling shared model restores native quiet-night credit`.
- Six complete-case trace pairs passed (45 checks); unchanged `test_meeting_stream`, `test_social`, `test_text_ui`, and other UI suites passed. Final focused busy-layout/batch run: **424 checks**, plus `test_town_ui`.
- Exact-string expectations changed in existing suites: **none** in set 3. New checks were added to the existing batch-4 test suite.
- Audited unchanged function bodies: vote, nomination, gift-request decision, drop odds and search. No edits under `workshop/`, to `game/workshop_*.gd`, evil code, or the streamed-meeting test.
- Item 23's original developer record is checked in as `tests/fixtures/playtest_37291_drop.json`. The original log has the owned wharf drop on night 3 and no recorded `player_search` for the wharf. A never-found item here is not evidence of a discovery-odds bug.

## 54875 replay

Sequential single-run measurements at the start and end of set 3 (headless, detailed logging on):

| Work | Before | After |
| --- | ---: | ---: |
| Sum of all command times | 10.627 s | 10.727 s |
| Day 2 meeting entry (`search`) | 2.644 s | 2.770 s |
| Original two-report case presentation | 3.310 s | 3.367 s |
| Nominate Constance | 1.489 s | 1.473 s |

Both runs: filed #94, nine shared listeners, no native listeners or fallbacks, **2 yes / 5 needed**. Listener presentation assessments, agreements, vote margins and final outcome are identical. These single-run time differences do not establish a performance regression. No replay command exceeds five seconds. Source measurements and test outputs are retained under ignored `logs/batch4-set3/`.

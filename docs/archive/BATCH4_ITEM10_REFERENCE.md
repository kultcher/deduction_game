# Batch 4 item 10: performance and revert reference

Keep this note if item 10 is reconsidered. **No revert or tuning has been applied.**

Implementation: `0558f95646d352e8ab044acac2fcc9a2261ed2b4` (`feat(dialogue): volunteer compatible night sightings during testimony`); preceding commit: `b8e8bf6`. Files: `sim/mind.gd`, `tools/test_backlog_batch4.gd`, the willing-report fixture seed in `tools/test_social.gd`, and its implementation note in `docs/codex_batch4.md`.

## What changed

- Public testimony calls `_volunteer_night_sightings` after each speaker's existing contribution. Eligible good and evil witnesses can report previously untold sightings from any past night when Gossip + Confidence >= 1.2 - paranoia. `_public_sighting_allowed` preserves disclosure/cover/reading protections and excludes evil teammates. `_town_sighting_key` records once-only town reporting; `_append_accusation_sighting` shares that identity.
- `answer_night` records the stated night account in `dialogue_memory.night_accounts`. It replaces the Gossip cutoff/count limit and 60% trusted-friend omission with one 95% willingness roll for eligible direct reports. Existing slip/privacy/cover and withheld-reading guards remain. It marks private telling separately in `told_to`.
- Those private changes intentionally alter game-RNG consumption as well as disclosure. They can change later conversations, public claims, evidence context and voting. They do not change vote or belief formulas.

## Saved measured evidence

These are single frozen replay runs of seed 54875, not statistical benchmarks. Source artifacts remain under ignored `logs/batch4-set2/` (`pre10`, `post10`, `diagnostic-public_only`, `diagnostic-private_only` measurement JSONs; `VOTE_CHANGE.md`).

| Enabled behavior | Day 2 meeting entry | Case presentation | Yes / needed |
| --- | ---: | ---: | --- |
| Neither (`b8e8bf6`) | 1.850 s | 3.154 s | 5 / 5 |
| Public volunteering only | 1.951 s | 3.157 s | 5 / 5 |
| Private-answer changes only | 2.660 s | 3.588 s | 2 / 5 |
| Both (`0558f95`) | 2.692 s | 3.399 s | 2 / 5 |

The original two-report filed payload is identical. In the paired before/after run, retained-fact counts summed across nine listeners rise from 185 to 210; the filed number changes from 83 to 94. Both presentation profiles test 8,551 explanation candidates. Aggregated profiler self-time rises mostly in `consequences` (+112.6 ms) and `headline` (+111.1 ms), rather than a larger candidate count. These nested evaluation stages are reported as recorded self-times, not added inclusive totals.

**Code-backed interpretation:** the volunteer loop scans existing beliefs and constructs ordinary sighting reports; the private path changes draws and disclosures. The saved private-only run reproduces the slower trajectory, including Constance's public Night Watch claim/readings at Day 2. More evidence context costs more downstream evaluation even with the same number of candidates. **Limit:** meeting-entry work was not deeply profiled in these artifacts, and the counterfactual does not separate RNG drift from disclosure changes or establish the correctness of later zero suspicions. Do not attribute all extra time to the volunteering loop or tune the replay to its old vote.

## Revert boundaries

A complete revert starts from the patch of `0558f95` and its focused tests/fixture change, reviewed against whatever has since changed. Inspect `git show 0558f95` first; do not replace all of `sim/mind.gd` with an old file or revert unrelated batch items. Keep the documentation history and mark any future reversal explicitly.

For a **private-only** reversal, restore the original `_gossip_share` cutoff/count and trusted-friend filter and remove the 95% roll, accounting for exact RNG order. Review private `told_to` writes and associated willingness tests. If public volunteering stays, retain the night-account memory it consults: simply deleting all new `answer_night` bookkeeping would weaken its cover/privacy guard. For a **public-only** reversal, remove the testimony hook, volunteer eligibility/helpers and public accusation town-key integration as a unit; retain the independent direct-answer decision if desired. Either partial reversal needs a separately reviewed patch, not a blind whole-commit revert.

Revalidate: focused batch-4 tests and `test_social`, unchanged `test_meeting_stream`, full suite plus slow `test_trace`, and the original 54875 replay with measured timings/outcome. Bot baselines will shift again. Current approved unrelated baseline exception: `test_workshop_protection` — `disabling shared model restores native quiet-night credit`.

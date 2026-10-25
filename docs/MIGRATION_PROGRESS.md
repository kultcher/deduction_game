# Belief evaluation: history and measurements

Updated Oct 25, 2026. Runtime: Godot 4.7.2. Rules and decisions live in
[LEGACY_MIGRATION.md](LEGACY_MIGRATION.md); open coverage work in
[MECHANICS_SUPPORT.md](MECHANICS_SUPPORT.md). The detailed per-slice log (Codex,
Oct 23–24, about 900 lines) is in git history at commit `00c17c0`.

## Timeline

- **Oct 19–23: case reasoning.** The shared judge (`CaseEval` over possible worlds)
  replaced template proofs for player presentations. Playtest 54875 showed it silently
  falling back to the legacy rules for every listener.
- **Oct 23–24: migration (Codex).** Unclamped suspicion and fallback logging (P0); card
  adapters for daytime sightings, conversations, homes, haunts, totems, dropped items,
  death/execution/silence/vote receipts, nested canvas cases, Surveyor block answers,
  secret errands (P1); Q1 crowd pressure out of evidence; Q2 finite demon-victim
  evidence; Q4 opinions excluded, hints and refusals as weak testimony, Psychologist as
  context; shared Martyr proof; relay provenance; canonical reading identity; defence
  dedup; the execution-priority input at zero weight; an offline exact channel
  reference. Each slice was correct to spec; together they slowed things and the town
  played worse.
- **Oct 24: diagnosis (Claude).** A native-vs-shared bot A/B showed good wins 16% vs 7%.
  Cause: hard testimony gates made one lie void a listener's whole evidence set (a third
  or more of Medium/High-Insight refreshes "impossible"), and per-listener attention
  scattered the town's beliefs. Codex's exact live channel model fixed the voiding (case
  #85 5/5 yes) but took presentations from 6.7 s to 151 s; it was stopped and kept on
  `codex/live-channel-validation` as a reference.
- **Oct 24–25: re-baseline (Claude).** Scope reduced to a deliberate hybrid (see
  LEGACY_MIGRATION). Changes and results below.

## Re-baseline results (54875 replay, container timings)

The container runs about 0.7× the user's machine and is noisy.

| Change | Commit | Effect |
|---|---|---|
| Live listeners use `scale` Confidence (no per-person theory loop) | `26cbfd4` | Meeting entry 6.4 → 3.3 s |
| Soft testimony: evil sources may bluff a role (weight 0.35), contradictory routes don't void worlds; source-drop stopgap removed | `2c29c2d` | No impossible refreshes (seed 1005: 0 of 190, was 59); case #85 2/5 → 3/5 yes |
| Per-run CaseEval reuse in `Jury` (exact) | `4252f60` | Presenting 5.1 → 3.8 s |
| Meeting refreshes deferred until a listener speaks | `157270b` | Meeting entry 2.5 → 0.9 s; search into meeting 5.5 → 2.0 s |
| Canvas status once per command (was O(listeners²)) | `3edd6ed` | Presenting 4.1 → 3.2 s |

End state: meeting entry 0.9 s, search into meeting 2.0 s, presenting 3.2 s,
nomination 1.0 s, vote 0.6 s (from 6.4 / 12.9 / 8.0 / 3.7 / 1.9). Estimated on the
user's machine: about 0.6 / 1.4 / 2.2 / 0.7 / 0.4 s. The presentation's remaining cost
is mostly the scoped reply. Full default suite: only the two known failures.

Tried and reverted: memoising `CaseEval.evaluate` on whole inputs (hashing the view cost
more than it saved); a shared public baseline via private readings as own reports with no
card budget (no speed gain; case #85 fell to 0/5).

## Bot measurements

Ten-person passive, seeds 1000–1049 (`autoplay.gd`, Oct 24, before the re-baseline):

| | Native (legacy rules) | Shared, Oct 24 |
|---|---:|---:|
| Good wins | 16% | 7–8% |
| Executions per game (good / evil) | 1.52 / 0.40 | 1.16 / 0.50 |
| Good voters' mean score / need | 0.443 / 0.446 | 0.365 / 0.428 |
| Others with my top suspect (Day 3) | 34% | 23% |
| Top-3 overlap with another NPC (Day 3, of 3) | 1.87 | 1.36 |

Individually, shared NPCs aimed about as well (evil people in their top 3), but at
different people, so votes failed. **Pending:** the same A/B on the re-baselined main.

Legacy baseline (commit `6bce4d4`, seeds 1000–1149, 150 games per row):

| Town | Player | Good wins | Wrongful / all executions | Evil executed |
|---|---|---:|---:|---:|
| 7 | Active | 42 | 157 / 239 | 82 |
| 7 | Passive | 8 | 119 / 147 | 28 |
| 10 | Active | 28 | 318 / 430 | 112 |
| 10 | Passive | 20 | 227 / 307 | 80 |

## Open measurement work

- The A/B on the re-baselined main (parity check, agreement).
- Day 3–4 versions of case #85 in the replay fixture (late-game cost and behaviour).
- Reply/belief coherence: in the replay, Jory and Agnes accept the case numerically while
  saying they couldn't follow it.

## Mechanics support (Codex, Oct 25)

Branch `codex/case-board-mechanics`, based on current local main `8fa8f13`.
`codex/live-channel-validation` remains a dead reference; item 7 belongs to Opus.
Existing local Godot config/UID changes are outside these commits.

- **0, plus 3's challenge prerequisite:** added not-Demon, modifier-holder,
  cited good-gift declaration and identified reading questions to the shared judge
  and live board controls. Protection/mercy preferences are social speech, not
  fallback. Generic innocent-secret and specific Red Herring premises remain explicit
  unsupported questions where no existing fact establishes them (user decision).
  Reading questions use the existing evil-reader/impairment explanations, not new
  hidden honesty states. A role question needs the person's included declaration.
  Challenge counting now shares its baseline and uses integer keys/report/role
  tables; parity against the prior counting routine passes. Targeted conclusion,
  challenge, nested-case and ownership checks cover live delivery and UI filing.
  Replay: 9 shared, 0 fallback, **0 impossible / 89 refreshes**, unchanged 3/5 vote;
  presentation **2698 ms** versus baseline **2695 ms**, meeting search 1647/1601 ms.
  Evidence: `logs/mechanics-support/baseline`, `item-0-final` and targeted-suite logs.
- **1 design approved by the user:** reuse bounded before/during/restored epochs;
  one hypothetical eligible turnee only after a public curse, with eligibility from
  the public execution vote and alive-at-event history. No curse-state cost otherwise.
  Implemented the public boundary/eligibility adapter, time-indexed source validity,
  current versus original premises, restoration and private disowned-memory handling.
  Movement keeps its habitual-block model, with one additional time-varying profile
  per person only in curse games. The native curse-voter bump is parked. Missing vote
  or boundary provenance is explicit. Focused curse, conclusion, public-event and
  checkpoint suites pass. Non-curse replay: 9 shared, 0 fallback, unchanged 3/5;
  presenting 2744 ms versus item 0's 2698 ms, meeting search 1682/1647 ms. Expanded
  cursed-game cost still needs the passive chunk; `logs/mechanics-support/curse-final`
  and `item-1` retain the evidence.
- **2:** NPC sightings now carry original-observer/teller receipts; relayed cases
  contribute endorsed original roots, not another accusation bonus. Native wrappers
  are parked, repeat/second-teller paths deduplicate, and hearing weight reaches
  movement without forcing a walk from weak hearsay. Opinions remain speech.
  Sharing (11 checks), ownership and factor-cache suites pass; `test_social` retains
  its one known false-Night-Watch failure. Replay 9 shared, 0 fallback, unchanged
  3/5; presenting 2720 ms versus item 1's 2744 ms, search 1645/1682 ms.
  Evidence: `logs/mechanics-support/sharing`, `item-2`. First passive chunk is frozen
  after items 0–1; item 2's late-game cost will be measured with the next chunk.
- **First passive chunk (0–1, seeds 1000–1009):** previous shared and new shared
  both 0/10 good wins, 13 good / 6 evil executions, mean Demon rank 3.80, Day-3 same
  top suspect 31.2%, top-3 overlap 1.32. Native: 3/10, 14 / 5, rank 3.98, 35.4%,
  overlap 1.93. No script errors or guards. Shared fallback totals fell 34 -> 27;
  **39 impossible refreshes in both shared runs** (2100 refreshes each), all in
  Hollis's Seer cover on seed 1007. No claim of a passed play/refresh criterion.
  Data: `logs/mechanics-support/batch-01/summary.json`; snapshots and traces retained.
- **3:** defence gift/secret statements and reading challenges use stable receipts;
  original magnitude and regard are hearing weights, as clarified by the user.
  Native defence bonuses are parked; pleas/rival suggestions add no alignment fact.
  Hearing weights enter movement/claim caches, role-bluff likelihoods and challenges.
  The chunk exposed a pre-existing hard gate on joint Seer contents: the existing
  DEFAULT_ERR now keeps erroneous contents finite when role declarations/public
  constraints still fit. Private/public identity contradictions stay hard. Focused
  defence, repeat, case-eval, sharing, role and Lamplighter suites pass.
  Seed 1007: **0 impossible / 99 refreshes**, no script errors, good wins Day 3
  (previously evil Day 7); this is a measured single-seed change, not a tuning target.
  Replay retains 9 shared, 0 fallback, 0 impossible / 89, 3/5 vote.
  **Flagged cost:** valid fixed run search **2342 ms** (previous 1645), present
  **3022 ms** (2720), nomination 999 ms (684). New defence assessments and the
  separate declaration/content validation add work; no hidden source-state domain.
  Earlier item-3 replay attempts printed Lamplighter declaration/count script errors
  despite exit zero; those timings are invalid. Fixed the report-only count check,
  added `run_replay_54875.py` to reject printed script errors, and retained logs under
  `defences-fixed`, `seed1007-after3`, `item-3-fixed` for review. Next passive chunk
  must verify the whole sample; end-of-list full-suite/trace checks remain.

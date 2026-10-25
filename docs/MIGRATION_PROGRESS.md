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
- **4:** unnamed readings and unverified Medium originals become reduced teller
  testimony using the existing RELAY_WEIGHT; no latent source/gift assignment.
  Teller poison does not break ordinary testimony. Identified original readings
  keep their verified relay path; acknowledgement still binds exact receipts.
  Missing original time/content, unattributed activity/protection identities and
  opinions stay explicitly labelled context rather than supplying invented facts.
  Positive recounted Night Watch observations remain weak sightings. Anonymous
  compatibility entries are parked only with exact receipt proof. Relay (8 checks),
  provenance, Medium, Psychologist and sharing suites pass. Replay: 9 shared,
  0 fallback, 0 impossible / 89, unchanged 3/5; presentation 3108 ms versus the
  preceding valid 3022 ms. Evidence: `logs/mechanics-support/relays`, `item-4`.
- **5:** Warden door/night statements are structured gift receipts in the existing
  report and movement tables, including private own guards and verified Medium
  retellings. A healthy accepted guard cannot have protected that night's publicly
  killed door; impairment/error still keeps alternatives finite. Matching quiet
  nights supply bounded support once, with native quiet bonuses parked. Door lookup
  is hoisted out of movement's inner loops. Warden (9 checks), Medium, relay and
  live-adapter suites pass. Replay: 9 shared, 0 fallback, 0 impossible / 89, 3/5;
  present 3063 ms (previous 3108), search 2584 ms. **Flagged vote cost:** 863 ms
  versus 756 ms (~14%); Warden memories now add dated evidence to refreshes. One
  noisy measurement, not a precise cost attribution. Evidence: `warden`, `item-5`.
- **6:** shared sighting ownership parks the native night/gift scaling. A cached
  5% Demon detour sum makes off-route sightings strong, finite counterevidence;
  no new world dimension. Preview and reply notes expose off-route sightings and
  movements compatible with a walking gift. Route normalization, finite likelihood,
  ownership, Lamplighter and Veteran/Seer suites pass. Replay: 9 shared, 0 fallback,
  0 impossible / 89, unchanged 3/5; present 3236 ms (previous 3063), search 2687 ms
  (2584), nomination 1053 ms (984), vote 872 ms (863). No measured step over 10%
  slower. Evidence: `sightings-final`, `item-6`.
- **8:** public/relayed role claims enter as stable declaration receipts, with
  hearing weight. Shared ownership parks both sides of double-claim bumps, legacy
  claim credence and the separate pressed `own_role` bump. Counterclaims now use a
  repeat-safe ledger entry; showing the actual rival's claim reaches that branch.
  Anonymous testimony cannot establish or strengthen the teller's gift declaration.
  Claim (10 checks), ownership, relay, card-adapter and live suites pass. Replay:
  9 shared, 0 fallback, 0 impossible / 89, unchanged 3/5; present 3361 ms (3236).
  **Flagged refresh cost:** search 3563 ms (2687), nomination 1320 ms (1053), vote
  991 ms (872); public declarations now enter the union. No threshold tuning.
  Evidence: `claims-final`, `claims-fixed` (ownership/relay only), `item-8`.
- **8 receipt audit:** the gift claim implied by an NPC-relayed reading now uses
  that exact original reading receipt, time and teller path. It cannot create a
  second current-day declaration (especially across a curse). Sharing tests cover
  the single-fact identity and provenance; claim, curse, ownership and playtest
  regressions pass. The previous final snapshot is retained for comparison; a
  fresh passive chunk will measure this correction too.
- **Passive chunk after 2�5 (seeds 1000�1009):** shared 2/10 good wins versus
  the previous 0/10; native remains 3/10. Shared Day-3 same-top 29.7% (previous
  31.2%; native 35.4%), top-3 overlap 1.33 (1.32; native 1.93), Demon rank 3.97
  (3.80; native 3.98). Fallbacks 27 -> 0; **0 impossible / 1886 refreshes**,
  no guards or script errors. No curse fired, so this chunk doesn't measure
  expanded curse cost. Behaviour acceptance against native is still unmet.
  Evidence: `batch-235/summary.json`; no outcome-based tuning.
- **9:** imported the user's actual Day-3 four-report and Day-4 six-report graphs
  and commands from the archived playtest log. `run_replay_54875.py --stage
  day3-four|day4-six` keeps exact case fact IDs, positions, answers, disputes and
  nested links, resolves ancillary citations by original identity/content, and
  records profiles, judgments, vote margins and impossible refreshes. Extra town
  nominations before a recorded close are voted no and logged. Current history
  kills Hollis before the recorded Day-4 conversation; it remains visibly
  unavailable, then the recorded smithy visit/search is repeated at the evening
  checkpoint. No phase, death or missing case receipt is fabricated.
  Six-stage run: 24 shared, 0 native/fallback, **0 impossible / 298 refreshes**;
  votes Day 2 **3/5**, Day 3 **1/5**, Day 4 **3/4**, all fail. The Day-3 raw
  Night Watch accusation sharply changes the judgments after an accepted case;
  report this surprise, do not tune it. Presentations 3531 / 4799 / 4258 ms;
  these late workloads cost more than the opening. `item-9-six-final` retains
  measurements and all continuation changes; missing graphs/receipts fail loudly.
  Follow-up `item-9-check` validates the final harness diagnostics. Day-4 held
  unions have 39�55 facts, with at most ten selected cards here; this does **not**
  exercise the >16-reading key cliff.
- **Trace suite audit:** its native-argument record test also crashes on the starting
  `8fa8f13` snapshot: shared presentation intercepts the synthetic native argument,
  so the expected native decision is absent. That section now explicitly selects
  native comparison mode; the isolated record/parity checks pass (18 checks).
  Full trace/parity validation subsequently passes (45 checks); this is a test
  setup correction.
- **End-of-list checks:** the first full run found two obsolete assertions:
  anonymous accounts are now supported weak testimony, and Veteran routes now
  permit a small Demon detour. Updated those checks while retaining genuine
  capability-failure/action clearing and the detour's probability bound. Both
  suites pass. The fresh final run passes 73/75 regular suites: only the documented
  false-Night-Watch (`test_social`) and two role-hover (`test_text_ui`) checks fail.
  Corrected full `test_trace` passes all 45 checks, including all twelve traced /
  untraced games. It took about 21.4 minutes. The three ten-person trace sidecars
  also show 0 impossible / 643 refreshes. Trace now prints slow steps and supports `--parity <seed> <npcs>` for focused
  retries. The earlier trace exceeded its 20-minute test limit; no pass claimed.
- **Broader cost flag:** ten-person seed 42, Day-3 meeting entry, **82.9 s** on
  current mechanics versus **28.4 s** on starting `8fa8f13`. Same command point,
  with evolving evidence/history; aggregate cost, not isolated attribution to one
  change. The starting snapshot's profile spends nearly all that step in shared
  consequences. Speed probes were stopped after collecting these samples; they
  are not completed-game validation. Evidence: `trace-speed.txt`,
  `seed42-control.txt` and the starting snapshot's `seed42-profile.json`.

Final passive comparison (10 NPCs, seeds 1000�1009; lower Demon rank is better):

| Snapshot | Good wins | Day-3 same top | Top-3 overlap | Demon rank | Impossible refreshes |
|---|---:|---:|---:|---:|---:|
| Starting `8fa8f13`, shared | 0/10 | 31.2% | 1.32 | 3.80 | 39/2100 |
| After items 2�5, shared | 2/10 | 29.7% | 1.33 | 3.97 | 0/1886 |
| Final mechanics `85fda4e`, shared | 2/10 | 20.1% | 1.30 | 3.94 | 0/1918 |
| Final source, native | 3/10 | 35.4% | 1.93 | 3.98 | 0/100 startup events |

All final games finish without script errors or guards; shared fallback count is
zero. The implied-claim receipt correction preserves this sample's outcomes and
agreement versus the preceding snapshot. No curse fired in either final chunk.
Behaviour acceptance against native remains **unmet**, especially agreement; these
results are reported without tuning. Data and frozen sources:
`logs/mechanics-support/batch-final-receipts/summary.json` (final),
`batch-final/summary.json` (before the receipt audit), `batch-235/summary.json`.

**Final state:** requested mechanics items 0�6, 8 and 9 are implemented within the
approved limits; item 7 remains Opus's work. Mechanical verification is complete,
with the two documented unrelated regular-suite failures retained. Behaviour and
speed acceptance are not signed off: see the A/B table and cost flags above.
Logs: `full-final`, `trace-final`, `contract-final`, `item-9-check`. Everything is
committed locally on `codex/case-board-mechanics`; no push or merge was performed.
The existing user config/UID edits and the dead reference branch remain untouched.


## Late-game speed and merge (Claude, Oct 25)

Codex's opening replay never reached the late game. Seed 42 (ten people, passive)
showed the Day-3 meeting entry at 31 s on main and 95 s on the branch (container).
Almost all of it was the role check: once a listener held a Medium relay card, the
role mask keyed on every modifier holder, splitting each class about 12,000 ways and
recomputing movement routes per world.

| Change | Commit | Effect (container) |
|---|---|---|
| Relay masks key on the Medium's evil bit and Delusion only; routes hoisted | `9cb8782` | Seed 42 Day-3 meeting entry 31 s -> 3.9 s (main), 95 s -> 6.5 s (merged) |
| Merge of `codex/case-board-mechanics` | `0cd2181` | Curse epochs and the relay fix share the mask |
| Declaration-only role pass on failing classes only; hearsay bluff weights test the evil bit directly | (next commit) | 54875 replay: meeting entry 2.0 -> 1.4 s, search into meeting 4.5 -> 3.5 s, nomination 1.6 -> 1.3 s |

All three are exact: suspicions are identical at every step through Day 4 on seeds
42, 1005, 3 and 7 (before/after each change).

Still over budget: presenting (about 4.3 s in the container, mostly the scoped reply)
and search into the meeting (3.5 s; compile cost grew with shared NPC sightings).
Case #85 now gets 2/5 on Day 2 (was 3/5): that came from `83d0f85` (the neutral
belief-refresh target, case 22485 fixes), not from this work.

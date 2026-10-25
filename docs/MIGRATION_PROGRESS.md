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

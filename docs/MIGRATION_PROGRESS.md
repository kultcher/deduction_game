# Legacy migration progress

Oct 23, 2026. Runtime: Godot 4.7.2 (confirmed by the user).

The migration is **in progress**, not finished. P1–P5 still need implementation.
Q3 and Q6 remain deferred. The 95% demon-victim rule and the speech-card rules are
recorded decisions, not yet migrated behavior.

## P0 implementation

- Suspicion stores reversible, unclamped totals. Simulation/UI consumers use bounded
  reads. Owned entries no longer fail capability checks because of saturation.
- Shared assessment starts enabled. Strict rejection is opt-in for tests only.
- Presentation commands check the entire audience before spending a question, floor
  or statement, revealing secrets, or changing beliefs. Unsupported ordinary-play
  submissions explain the reason and use one response engine for the whole audience.
- Presentation and internal ownership failures emit `workshop_fallback` trace events.
- Previews include actual audience readiness alongside the neutral assessment.
- Timing and cache diagnostics live outside NPC belief state.
- Private-reading evaluation stores only states present in legal worlds, rather than
  allocating all 3^readings combinations. Dense-enumeration parity checks pass.
- Identical constraint solves and conflict analyses are memoized. Position filters
  share their common report/role/route solve. Semantic checkpoint tests pass.

P0 is **not signed off**: full validation and bot comparisons are running, and the
historical case exceeds the five-second presentation budget.

## 54875 measurement

`tools/replay_54875.gd` replays the original local playtest's opening commands through
the first Day 2 vote on Constance. The committed fixture was extracted from the
original `case_54875.jsonl`; it contains player actions and the filed graph, without
referee truth. Plain-card references are matched by original fact identity because
board numbering changed since c6ae7a4. Original case #85 is #89 in this build.

Measured while P0 was in progress:

- All nine living listeners used shared assessment; no fallback events.
- The nomination **failed: 1 yes, 5 needed**, with the player's original `vote no`.
  Jory voted yes; Lian accepted the case and voted no.
- Post-presentation suspicion of Constance: Hollis .267, Jory .510, Greta .145,
  Odette .189, Constance's cover .000, Edda's cover .291, Agnes .180, Isolde .293,
  Lian .232. These are measurements, not tuning targets.
- Good-listener vote margins: Agnes -.521, Isolde -.274, Lian -.213, Hollis -.278,
  Jory +.252, Odette -.211.
- Most listeners did not accept the headline: agreement ranged from 0 to .757.
  This differs from the legacy playtest's wording and is reported without tuning.
- Cold presentation cost was initially about 50 seconds. Removing empty private
  states and reusing solver work reduced it to about 18–19 seconds. Further work is
  required; the simple probes do not represent this historical case's workload.

The replay writes full agreement, suspicion, vote margins, actual tally, commands,
timings and profiler output to `logs/migration/replay_54875/measurement.json`.
It deliberately does not assert that the nomination passes. The complete later
playtest, including curse histories, still needs a replay after P2's adapters.

## Validation baseline

Untouched commit: `6bce4d4`. Godot 4.7.2 headless, seeds 1000–1149, 150 games per row.

| Town | Player | Good wins | Wrongful / all executions | Evil executed |
|---|---|---:|---:|---:|
| 7 | Active | 42 | 157 / 239 | 82 |
| 7 | Passive | 8 | 119 / 147 | 28 |
| 10 | Active | 28 | 318 / 430 | 112 |
| 10 | Passive | 20 | 227 / 307 | 80 |

Baseline tests: 43/45 suites passed. Existing failures on this runtime:

- `test_social`: false Night Watch's night story versus fake report (one check).
- `test_text_ui`: enclosing card target on role hover and right-click (two checks).

These were reproduced in an untouched source snapshot. Tests of the native equations
or migration from a disabled baseline explicitly select native mode; integration
tests exercise the new default. Run every suite with
`python tools/run_gd_tests.py --godot <Godot-console-executable>`; the runner also
detects printed failures and script errors when a suite exits zero.

P0 bot runs use a frozen source snapshot under `logs/migration/p0/project`. Results
and comparisons are pending. No post-migration balance claim is made yet.

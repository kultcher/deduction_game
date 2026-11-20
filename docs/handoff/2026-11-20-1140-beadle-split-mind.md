# Split mind.gd into a chain of four modules (Tier 1, last)

- **Agent:** Claude-Beadle
- **Base:** main at 1d39253f (after #417, #427)
- **Status:** PR open. Lantern reviews the case and ledger parts.
- **Next actor:** Lantern to review, then Bailiff.

## What changed

`sim/mind.gd` had 1,845 lines. It is now an inheritance chain:
`mind.gd` extends `mind_ledger.gd` extends `mind_cases.gd` extends `mind_shadow.gd` extends `mind_base.gd`.

| File | Lines | Holds |
|---|---|---|
| `mind_base.gd` | 36 | the preloads, every module constant (SHADOW_COPY/SAME, SERIOUS_GRIEVANCE, CONSENSUS_*), and `_mind()` |
| `mind_shadow.gd` | 245 | the shadow self |
| `mind_cases.gd` | 390 | case and card evaluation |
| `mind_ledger.gd` | 398 | the evidence ledger |
| `mind.gd` | 798 | utilities, trust, suspicion, mourning, night choices, the meeting, pressing |

- Every `Mind.<fn>` is inherited, so no caller changed.
- Code was moved, not rewritten. In a moved file, a call to a function defined higher up the chain now goes through `_mind().`, which is the same loader mind.gd already used (53 calls). That avoids the base-to-subclass bare call, which doesn't parse.
- A line-multiset check, with the `_mind().` prefixes ignored, confirms that every line of the old file is present exactly once. The only new lines are the headers.
- `test_tuning_hoist` now expects its Mind references in `mind_ledger.gd` and `mind_cases.gd`. The README code map has an entry for the new files.

## Measured

- Golden capture against `baseline_9fa5a74` at `--tol 0`: all 5 seeds identical.
- CI fast suites: 153 of 153 pass (`tools/ci_fast_suites.txt`, run in three parallel chunks).

## Note for #423 (spare_pref removal)

#423 removes `spare_pref` from `SHADOW_COPY`, which now lives in `mind_base.gd`. Whichever of the two merges second needs a one-line rebase. I'll do it if this one is second.

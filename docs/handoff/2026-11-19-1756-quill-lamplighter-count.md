# Quill: Lamplighter fix (b) step 1, a count can be broken

Claude-Quill, Nov 19. Base: main at a6b674b (with #344). Status: PR open. Next actor: Lantern
(review), then Bailiff. **Golden moves**, so it re-baselines to `baseline_d33fdae`. Follows
`2026-11-19-1510-quill-lamplighter-parked.md`.

## What changed

A Lamplighter's count is mixed as sound or broken, the way a Night Watch list already is. A
listener weighs the chance that the Lamplighter is evil, poisoned or Delusional, and a broken
count says nothing. Before, every count was taken as sound.

- C#: `ListMixEvilTakesAlt`, `ListMixSoundZero`, set through `LiveAttachCountMix`.
- `SourceDoubt.count_mixable` and `count_broken_chance`.
- `CaseEval._list_broken` stamps `count_mix` and `broken_chance`. Counts take the cap slots
  the lists leave.
- `LiveActivity._list_mix` builds the duty copy and the `sound_zero` flag.
- Connections `_mix_key` is in both judge keys.

The seed-900 cache-parity failure that parked this branch was the handle sharing Lantern
fixed in #344. With main merged in, `test_connections_cache` passes. The one conflict, in
`_ensure_factor_handle`, keeps #344's scale-keyed handles and the count's own attach call.

The case slate gains `lamp_count` (and its twin) and `lamp_bluff_innocent`, and its baseline
is refreshed.

## Measured

Case slate, 10 deals per case, against main without the change:

| Case | Average listener's chance after (from 30%) | Town |
|---|---|---|
| Lamplighter + everyone else's alibi | 47% → 43% | +18 → +14 |
| The same against an innocent (also the board a poisoned or Delusional Lamplighter gives) | 47% → 43% | +20 → +16 |
| A Minion bluffing the Lamplighter, against an innocent | 47% → 43% | +18 → +11 |
| The count alone | 30% → 30% | +1 → +1 |

Golden, against `baseline_ee15238`: 4 of 5 seeds diverge. The winner and the last day are
unchanged on all five. On 98933 the town hangs Merrin (good) on day 2 instead of Dorian (good),
and no one on day 3 instead of Isolde (the Revenant). On 42 the same Demon hanging has a
different nominator. Two captures were identical.

Suites run: `test_connections_cache`, `test_lamplighter_count_mix` (3/3) and
`test_factor_norm_handles`. Earlier, on bd2bbc8, 132 of 133 suites passed; the one failure was
the cache parity now fixed.

## Next

Step 2: weigh the count against each possible world (a Poisson-binomial term). That should
raise the Lamplighter-and-alibis case again. It waits until Michael's pause ends.

## Proposed for the backlog

None.

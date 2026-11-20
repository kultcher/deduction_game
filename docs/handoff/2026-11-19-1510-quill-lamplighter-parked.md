# Lamplighter fix (b) step 1: parked (cache parity)

**Claude-Quill**, Nov 19. Branch `claude/lamplighter-count` (no PR). Status: parked on
Seneschal's word after three attempts. Next actor: Lantern, who has the diagnosis. Quill
resumes only once Lantern finds the cause.

## What the branch does

A Lamplighter's count is mixed as sound or broken as a whole, like a Night Watch list (#273):
- **Where the Lamplighter is good:** the count is sound with chance 1 − b, from its poison and
  Delusional priors. Sound means the routes gate applies and the people it forces out count.
  Otherwise it's broken and says nothing, though the round was still walked.
- **Where the Lamplighter is evil** (or converted, told while cursed): it says nothing.
- **A count no route mask fits** makes the sound branch impossible, so it tells against the
  Lamplighter.
- **The cap:** lists and counts share the mix cap. Counts take the slots the lists leave,
  among the judged cards.

The C# change adds `ListMixEvilTakesAlt`, `ListMixSoundZero` and `LiveAttachCountMix`. New
suite: `tools/test_lamplighter_count_mix.gd`, 3/3.

## Measured

- **On the slate:** the Lamplighter-and-alibis case falls from 2.10 to 1.74 for the juror, and
  from about +20 to +16 points for the town on the same deal.
- **An impossible count** gives ×6 for "the Lamplighter is evil", where it used to give
  nothing.
- **Golden** moves on 4 of 5 seeds, and two captures were identical. 132 of 133 fast suites
  pass.

## The failing check

`tools/test_connections_cache.gd`: "seed 900: so is the whole dev log (441 records)". On the
7-NPC seed 900, played passively for 3 days, Isolde's cover mind ends with different
suspicions with a cache on (Lian 0.282 on, 0.322 off). The first divergence is the
state_digest at log record 394.

## The three attempts, none of which fixed it

1. **`count_mix` in CaseEval's compile key**, beside `broken_chance`. Kept: it's needed.
2. **Counts chosen for the mix among the judged cards only**, not the whole view.
3. **Lantern's `_mix_key`:** each mixed card's broken chance in `Connections.judge_key` and
   `_judge_key_fast`.

## What's known

- With `Connections.cache_verify`, hits are 1654 with 0 wrong.
- With both caches off, two runs are identical.
- With either the Connections cache or the CaseEval cache on alone, the run diverges.
- With `count_mixable` forced false, it matches.

So no cached answer is wrong. The suspects are an order dependence or a shared object that
gets mutated in the mix path: `top = sound.duplicate(false)` in `LiveActivity._list_mix`, and
the flags on factor handles.

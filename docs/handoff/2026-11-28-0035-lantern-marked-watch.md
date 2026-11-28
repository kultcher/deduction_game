# 2026-11-28, Claude-Lantern: Marked watch in sweep records, read-only (claude/marked-watch)

- **Agent:** Claude-Lantern (a worker fork, Task #53, cleared by Seneschal)
- **Base:** origin/main `86f0ed23`
- **Status:** PR open. Read-only instrumentation, zero drift.
- **Next actor:** Bailiff to review and merge.
- **Why:** so a sweep can tell whether evil's Marked claims stick, and what happens to the evil
  claimers once the real holder hangs.

## What changed

- **`tools/sweep_record.gd`:** three new record fields.
  - `burden_claims`: every `burden_claim` dev-log entry, giving who made it, the kind, the day
    and phase, whether it was public, the claimer's alignment and role at the claim, its
    `why`, and `reactive` (true when `why` is a reaction: reading, nominated, turning on me,
    caught out, someone else claimed).
  - `claimer_suspicion`: for each claimer, the good town's mean evil chance on them, sampled
    at dawn and after the meeting each day. It comes from each good NPC's staged
    connections posterior (`OwnGiftDoubt.META`), not from `Mind.susp`.
  - `after_holder`: the real Marked holder, the day they were hanged (or null), and for each
    evil Marked claimer their role, whether they're the Demon, when they were first
    nominated after the hanging, and whether they were hanged or survived.
- **`tools/autoplay.gd`:** takes those samples after each step, read-only.
- **`workshop/demon_candidates.gd`:** adds `evil_chances_of_npc(n)`, a read-only copy of the
  staged posterior.
- **`tools/sweep_report.py`:** a new "Marked watch" section, shown only when a Marked was
  dealt. It reports (a) games with an evil Marked claim whose holder was never hanged, and
  (b) the evil claimers after the holder's hanging: the change in their suspicion, and
  whether they were hanged, survived or won, split by Demon and Minion.
- **`docs/balance_sweep.md`:** the new fields and the new report section.

## Measured

- **Golden:** identical at `--tol 0` to `baseline_1bf8a4b`, on all 5 seeds.
- **Suites:** `test_connections_cache` and `test_demon_candidates` pass through the runner
  (`--timeout 1200`).
- **Records:** for seed 1, `--games 2 --npcs 10 --passive`, the records before and after are
  identical apart from the new fields and `wall_s`.
- **Sample:** 10 games: passive seeds 12, 19 and 20 (Marked dealt) and bot seeds 1–7.
  - 3 games dealt a Marked, and none of them had an evil Marked claim, so (a) is 0 and the
    (b) table is empty.
  - Seed 20's holder was hanged on the fourth day, with no evil claimer.
  - Seed 7 (Unrequited dealt) had an evil Marked bluff, from bart on the third day.
  - A synthetic record check gave the expected numbers for (a) and the suspicion change in (b).
- **Not measured:** a sweep big enough to fill the (b) table. That needs an overnight sweep.

## Proposed for the backlog

None.

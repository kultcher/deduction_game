# Reports from evil or impaired sources count as likelihood 1

Found by Claude on Oct 30, 2026, while making `PRIOR_K` live. **Status: open; needs a design decision.**

## The problem

In a world where a report's source is evil, poisoned or Delusional, `Solver.source_valid` is false. The report then constrains nothing: the world keeps weight 1 for it, whatever it says. In a world where the source is healthy and good, the report gets weight 1 if its content fits that world and roughly 0 if it doesn't.

The true likelihood of an unreliable report is the chance that the lying or impaired process says *exactly this*:
- **Poisoned or Delusional Seer:** the game draws `chance(0.5)`, so 0.5.
- **Dowser or Hearthwitch count:** about 1 over the number of possible counts.
- **Evil sources:** whatever evil's bluffing strategy actually produces.

Counting 1 instead makes "the source is lying or impaired" too cheap an explanation for any surprising reading.

## Why it surfaced now

The old prior read suspicion as a probability. A source at suspicion 0.0 then looked nearly proven good, which hid the problem. With the relative prior (`PRIOR_K` = 1.5), nobody is proven good by low suspicion alone.

`test_workshop_presentation`, "the listener can accept an intermediate alignment claim", now fails because of this. Its case rests on a 4-of-4 Dowser count from a source the listener trusts only through suspicion 0.0. The model now prefers "the Dowser is lying", which costs only the prior of the Dowser being evil, because the lie itself is scored at 1.

Readings from other people lose weight across the board for the same reason. Some true Seer "yes" pairs don't rise even in the holder's own view (seeds 6, 9 and 24 at Day 3). Those could also be other evidence; I haven't traced them.

## Fix options

1. **Per-shape outcome probability.** In worlds where a report's source is invalid, multiply by q(report): 0.5 for a Seer yes/no, 1/(n+1) for a count over n people, and so on.
   - Poison and Delusion follow the game's own generation code, so their q is exact.
   - For evil, use the same q as a first guess, then measure from the simulation. This is the "Evil sometimes tells the truth" backlog item, whose t is measured, not chosen.
   - It costs one factor per report per world, with no new hidden state.
2. **A single weight for the lying explanation.** A tuning knob such as 0.5 for every invalid source. It's simpler but isn't calibrated to each reading's shape.

Option 1 is the principled one. It would also make the calibration test proposed on Oct 30 (game-generated readings against the model's predicted odds) straightforward to write.

# When evil lies: telling the truth on purpose (design note)

**Status: options for Michael, Nov 18, by Claude-Vicar. Nothing decided; nothing built.**
It comes from Michael's wish, relayed by Seneschal, to make evil smarter about *when* it
lies. That is the real substance behind BACKLOG section 2's "Evil sometimes tells the truth
(start by faking it)" `[decided: add; t measured]`. Builders, once he decides: Beadle (evil's
choices) and Quill (the judge side). The code facts below are read from main, not run. The
numbers are Quill's.

---

## 1. Where it stands

**Quill's measurement** (40 passive bot games, 10-NPC town, seeds 1–40): evil's made-up
readings come out true 38% of the time, against 45% for a reading picked at random. They come
out true less often than chance because they're built to frame good people.

| Faked gift | True | By chance |
|---|---|---|
| Archivist | 0 of 10 | (not given) |
| Surveyor | 12% | 51% |
| Seer | 19% | 34% |
| Night Watch, Lamplighter, Psychologist | not measured | |

- **The judge's side already fits.** It treats an evil teller's reading as no better than
  chance. Evil's lies are true less often than that, so the "true with chance t" change in
  the backlog item would do nothing today. It matters only if evil starts telling true but
  useful things on purpose. Quill estimates the judge-side change is small.

**What evil already does** (`sim/evil.gd`, `sim/fabrication_check.gd`):
- **Every reading has a motive.** Each night, each bluffer's gift writes a reading for the
  scapegoat plan (`generate_bluff_reading`), logged with its reason.
- **It checks the public record first.** Before a fake is told, evil asks how the town would
  read it beside what's already public. If the fake would point at the liar or a teammate,
  a roll scaled by Insight decides whether it notices. If it does, it reworks the reading or
  holds it back a day.
- **Blending in versus disruption** (Michael, Nov 18, #264). A Demon or Scion leans towards
  passing as one more honest gift on its first such reading, then towards disruption. A
  Minion leans towards disruption unless it's badly exposed (`Evil.blend_chance`,
  `BLUFF_BLEND_PROB` 0.35). The example in the code: an evil Clerk "confirms" an early good
  claimer instead of covering a teammate. **That is already deliberate truth-telling,** for
  a few gifts, and only on the first reading.
- **Exposure and caution** (`Evil.exposure`, `Evil.caution`): how hot an evil member is
  (town talk, the player's suspicion, pressure, being on the block), against how careful it
  is. The Demon stays careful; Minions loosen as the days pass.

So the pieces exist. What's missing is a reason, beyond the first reading, to say something
true.

## 2. Why truth helps evil

- **Credit.** A reading that checks out makes its teller look good. The judge today reads a
  checked-out reading as near-proof of good, because evil so rarely tells one.
- **Cover for the decisive lie.** One false reading among true ones is harder to spot than
  a run of false ones.
- **Safety.** A lie that a live gift could contradict (a second Seer, an overlapping
  Archivist) is risky. The truth isn't.

## 3. Options

All of them keep "every lie has a reason": each true reading evil tells gets a logged reason
too, so the reveal can say "told the truth to earn trust".

### A. Credit first, lie late (the sleeper)

The bluffer tells the truth early to build trust, and lies when it matters: when the
scapegoat is close to hanging, on a final-three day, or when it's exposed.

- **For:** a clear story the player can read in hindsight, a payoff for the reveal, and
  human.
- **Against:** a pattern the player learns ("the trusted reader's last reading flips"). It
  needs some randomness in when the turn comes, or it becomes a tell. Several fixed-timing
  choices would want new constants (Michael's call).

### B. Lie when it's safe, tell the truth when it's checkable

For each reading, evil weighs how likely it is to be contradicted:
- a living counter-claimer of the same gift;
- an overlapping reading already public;
- a gift that could check it the next night.

When it's checkable, evil tells the truth. When it isn't (the counter-claimer is dead, or
poison could explain a clash), it lies.

- **For:** general, not per role. It extends the existing public-record check, which
  already asks "how would the town read this?" A true reading becomes one more alternative
  it can choose.
- **Against:** harder to see in hindsight than A. The player has to notice *why* this
  reading was safe to fake.

### C. Truth that still serves the plan

Among the readings that serve the plan, evil prefers a true one when one is close enough
in value. Some examples:
- a true Seer "no" on two good people nobody suspects;
- a true Surveyor result on a block where the truth happens to hurt the scapegoat;
- a true Clerk confirmation of a good claimer evil doesn't fear.

Many gifts let the teller pick its subjects, so a true reading can still be aimed.

- **For:** cheap. It's a tie-break in the existing generator, no new behaviour.
- **Against:** subtle. Its effect is mostly on the numbers (how often fakes come out true),
  less on stories the player can see.

### D. Leave it at the blend lean (no change)

The #264 lean already gives a first honest-looking reading for some gifts. Measure how much
truth that adds first, then decide.

### Combinations

**B and C go together naturally,** and A can sit on top: C chooses *what* true thing to say,
B chooses *when* lying is safe, and A adds a "save the lie for when it counts" lean.
**Vicar's lean: B plus C first, A only if playtests show evil is too easy to read.** B and C
are general and extend code that exists. A is the most dramatic, but its timing is the
easiest for a player to learn.

## 4. The judge side (Quill)

- **The "true with chance t" change** in the backlog item becomes real once evil tells the
  truth on purpose. Measure t per gift from the sim, as the item says, and re-measure when
  evil's strategy changes.
- **Don't chase it exactly.** If the judge's t lags evil's real rate, NPCs over-trust a
  reader who has checked out. That's a human mistake, and it's the trap a sleeper sets.
  The guardrails welcome that kind of mistake: NPCs needn't be accurate, and the player can
  see through it. The question for Michael is whether NPCs should be partly fooled by
  credit-building (t set a bit low), or should allow for it fully (t matched).
- **Quill estimates the change is small.** Whether it moves golden depends on t; if it
  does, it's a re-baseline in its PR.

## 5. Guardrails

- **"Every lie has a reason":** the true readings get reasons too. The reveal is where they
  pay off. Its wording is Herald's to draft and yours to approve.
- **"A loss is explainable in hindsight":** A explains best, C least.
- **"NPCs must not out-deduce the player":** none of these makes NPCs sharper. They make
  evil harder to read, which the player has to work through.
- **"General mechanics over per-role special cases":** B and C are general. A is general
  but needs per-game timing.

## 6. For Michael to decide

1. Which options: A, B, C, D, or a mix (Vicar's lean: B plus C, A held in reserve).
2. For A: what counts as "when it matters" (near a hanging, the final days, being exposed)?
3. The judge: should NPCs partly fall for credit-building (t a little low) or allow for it
   fully (t matched to the sim)?
4. Whether the "blend in" lean (#264) should be folded into whatever is chosen, or stay
   as it is.

## 7. Measuring it (once decided)

- **Tally or Quill:** re-run Quill's 40 games. Report how often fakes come out true per
  gift (including the three not yet measured), how often a reader who has checked out is
  later caught lying, and wrongful hangings and win rates before and after.
- **Then a playtest:** in hindsight, could the player tell when the trusted reader turned?

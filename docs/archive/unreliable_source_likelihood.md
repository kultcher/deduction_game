# Reports from evil or impaired sources: checked, no bug (Oct 30)

**Status: closed.** This replaces my earlier note from Oct 30, which was wrong.

## What I claimed

I wrote that a report from an evil, poisoned or Delusional source counted as likelihood 1 in worlds where its source is invalid. That would make "they're lying" a free explanation for any surprising reading.

## What the code does

That isn't the case. Every report gets a likelihood state in `CaseEval.compile`: holds, valid but wrong, or invalid source. For an invalid source the factor is `CaseEval.chance_content(card)`, the chance that a random reading says exactly this:
- **Dowser and Hearthwitch counts:** 1/(n + 1).
- **Surveyor:** 1/(number of blocks + 1).
- **Lamplighter:** 1/(number of people).
- **Night Watch:** 0.25.
- **Everything else, including the Seer and the other role-checked readings:** 0.5.

The role check skipping an evil source's content (`RoleConstraints._fits`) is consistent with that, because the q comes from the state table. Adding a q in the role check would count it twice. I tried it and reverted it.

## Why `test_workshop_presentation` failed

The fixture's case rests on a 4-of-4 Dowser count from Fenwick, trusted only through suspicion 0.0. With the relative prior, Fenwick is evil with prior around 0.25. The two explanations then compare like this:
- **Fenwick is lying:** 0.25 × 0.2 = 0.05.
- **Fenwick is honest:** the count needs three of the four people in the group to be the whole evil team and the fourth to be the Marked. That's roughly 0.004.

So "Fenwick is lying" is the correct Bayesian answer. The old prior hid it by treating 0.0 as near-proven good. The fixture now makes the listener the Dowser, so the case rests on her own reading. The check accepts "partial": the count still leaves Hollis possibly the Marked unless the Rumormonger is right.

## Still open

- **The Seer's rise looks small.** A constructed true Seer "yes" on Day 1 (the Demon plus one good person) raises the pair's combined P(evil) by about +0.11 to +0.14 (`tools/test_prior_mapping.gd`). My hand calculation (one fixed red herring among six good people, two minions) gives about +0.22.
- **Some true Seer pairs don't rise at all** in the holder's own view. On Day 3 that happened on seeds 6, 9 and 24, before the trust change, so other evidence may explain it.
- **Bluffing strategy.** `chance_content` assumes a liar picks uniformly at random. Evil's real bluffing strategy (the "Evil sometimes tells the truth" backlog item) should eventually set these numbers from measured behaviour.

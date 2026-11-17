# 2026-11-17, Claude-Lantern: a double claim raises both claimants (`claude/double-claim-pairing`)

- **Base:** main `c676018` (#186 merged). **Status:** PR open. Golden identical to
  `baseline_a0a378d` (no double claim on the five seeds), so it isn't in the golden-moving
  queue. **Next actor:** Bailiff merges.
- **What Michael asked** (Nov 16, BACKLOG "A double claim of a unique gift raises both
  claimants", [decided]): under connections a claim was only context, so two people
  claiming one gift didn't become more suspicious (in `test_beliefs` both dipped about
  0.01). Make the claims a built-in pairing that raises both, and shifts suspicion onto the
  other when one is shown good.
- **The change** (`Connections.items`): every claim of one gift, when two or more people
  claim it, is one item, `claims:<gift>`. Its context is every other held card that names a
  claimant, except night and trace cards (the movement items read those). Its value is, as
  for any pairing, what the claims say beside that context less what the context says
  alone. So the pairing adds "one of these two lies", and how that splits between them
  follows what else the listener holds. The judge already knows a gift has one holder;
  nothing about any gift is special-cased. The Why tool labels it "Every Seer claim, read
  together (2 cards)" (wording is a draft for Michael, matching the other pairing labels).
- **Measured** (`tools/test_double_claim.gd`, 7 checks, in `ci_fast_suites`; 3 fail without
  the pairing). A good listener, two others claiming Seer:
  | | First claimant | Second claimant |
  |---|---|---|
  | Before | 3% | 33% |
  | One claim | 2% | 33% |
  | Both claim | 17% | 57% |
  | Then a reading implicates the second | 6% | 76% |
  | Or a reading clears the first | 0% | 79% |
  With only the first claim, the reading implicating the second moves the first by 2
  points; with the rival claim, by 11.
- **How often it fires in play:** none of 19 games (seeds 1-10 at 10 NPCs: 10 passive,
  9 bot; the tenth bot game hit the run's time limit) had two people claim one gift. Evil bluffs gifts that aren't in play
  (`World.bluffs`), so today a double claim needs something else to go wrong. The pairing
  is ready for "Evil backs into a bluff" (BACKLOG, [decided], Beadle's), which opens
  double claims.
- **Cost:** one more item per double-claimed gift; nothing when there isn't one.
- **Checked:** `ci_fast_suites` 65/65; golden twice, identical to each other and to
  `baseline_a0a378d` at `--tol 0`.
- **Left:** `test_beliefs` is still pinned to the earlier model on main. With this PR and
  #186 its every check passes under connections (run unpinned on this branch: no failures), so
  once #182 (which pins its checks one by one) and this PR are both in, I unpin the whole
  suite. Not done here, to keep clear of #182's edits to the same lines. The
  BACKLOG item is on #192's branch; I move it to COMPLETED once #192 merges.

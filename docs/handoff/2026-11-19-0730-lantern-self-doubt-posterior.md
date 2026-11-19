# 2026-11-19, Claude-Lantern: self-doubt reads the judge's own doubt (`claude/self-doubt-posterior`; moves golden in stored fields only)

- **Base:** main `64aa1e9` (after #306). **Status:** PR open. **Next:** Bailiff; then Beadle
  re-measures #316 on it.
- **Why:** Michael, Nov 19 (via Seneschal). A prior-only self-doubt climbs night by night for
  every reader alike (about 16% after nights 1-2, 25-32% by nights 4-5), so it says nothing
  about any one reading. "My gift may have been turned" should come from the NPC's own readings
  clashing with its other beliefs. He approved my measured recommendation and the 0.30 trigger.
- **What changed:**
  - **The new number:** `workshop/own_gift_doubt.gd`, `OwnGiftDoubt.posterior(view, listener,
    held)`. For each night of the NPC's own gift readings it gives the judge's chance that the
    reading was wrong. That's CaseEval's "holds" question, with every card the connections
    refresh held. The poison and Delusional prior is its starting point, inside the judge.
  - **Where it's kept:** `WorkshopOwnership` keeps only its inputs, for good NPCs' own minds:
    the cards the connections refresh held, plus the doubt-adjusted view and listener the
    evaluation started from (`Shared.last_adjusted`, opt-in). The judge is asked the first time
    `SourceDoubt.self_doubt(n)` reads it, at most once per refresh. An evil NPC knows whether it
    lied, and its cover mind never speaks this.
  - **Reading it:**
    - `SourceDoubt.self_doubt(n)` returns it.
    - `SourceDoubt.self_doubt_prior(n)` returns the old prior.
    - `SourceDoubt.doubts_own_gift(n)` lists the nights at or above
      `Tuning.Workshop.SELF_DOUBT_TRIGGER` (0.30, new).
  - **Not covered:** readings that hold in every world get no entry: a Warden's quiet night, a
    Lamplighter's count, a Night Watch list, a Psychologist's or Sexton's reading, and a
    Medium's relays. That's now the BACKLOG item "Gift doubt for readings the judge doesn't
    check" ([open], Lantern; Michael accepted, Nov 19).
- **For Beadle (#316):** read `SourceDoubt.doubts_own_gift(n)`, or `self_doubt(n)` against
  `Workshop.SELF_DOUBT_TRIGGER`. The API and its shape ({night: doubt}) are unchanged; only the
  meaning changed.
- **Measured:**
  - **Before the build:** 42 ten-NPC games, seeds 3032-3095, at the day-4 meeting. At 0.30 it
    fires about once in 5 games: for 4 of 10 false readings and 5 of 83 true ones. Half the
    false readings clash with nothing. Details in `docs/belief_model.md`, "Was my gift
    turned?".
  - **As built** (after Codex's fix, which feeds the role check the prior the measurement left
    out): the same seeds, read from the stored self-doubt. It fires on 13 nights in 10 of 39
    games, for 6 of 9 false readings and 4 of 86 true ones.
  - **Golden:** every seed moves from record 1, in the stored self-doubt fields only. The prior
    now sits in `self_doubt_prior`, and the posterior isn't stored, since it's computed when
    read. With those ignored, all five seeds are identical. The two captures were identical.
  - **Cost:** none until something reads it. A whole golden capture takes 166 s, against main's
    167-174 s. Computing it at every refresh had cost about 8% (181-188 s).
  - **Lazy matches eager:** on 8 seeds (3032-3039, the day-4 meeting), computing at the refresh
    and computing when read give identical numbers on all 14 nights.
- **Tests:**
  - `test_poison_self_doubt` (19 checks): the old checks now read the prior, plus a new
    section.
    - The judged doubt with an agreeing teller is 0.079, below its prior of 0.145.
    - One clashing teller gives 0.125, and two clashing tellers 0.134.
    - In this hand-built town two clashers don't cross the trigger: they might as well be
      lying evils.
  - **New `test_own_gift_doubt`** (full list, not fast: a seed search of about 3 minutes):
    - It finds a game where a good NPC doubts its gift: seed 3001, a Surveyor at 0.47 on its
      night-0 reading against a prior of 0.16.
    - Those nights are the ones at or above the trigger, and the clash raised the doubt above
      the prior.
    - Each night is a checkable own reading, and some reading that fits is doubted below its
      prior.
  - The fast list passes (see the PR).
- **Proposed for the backlog:** "Gift doubt for readings the judge doesn't check". Michael
  accepted it through Seneschal on Nov 19, and it's added here as [open], owner Lantern.

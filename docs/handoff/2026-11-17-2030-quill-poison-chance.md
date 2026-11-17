# 2026-11-17, Claude-Quill: the per-night poison chance (`claude/poison-chance`; zero drift)

- **Base:** main. **Status:** PR open. **Next:** Bailiff (review and merge; nothing calls the
  new function yet, so golden can't move). **Then Claude-Lantern:** builds the poison
  self-doubt on it through #216's route, and that PR moves golden.
- **What (BACKLOG "A listener's doubt that its own reading was poisoned", [decided], Michael
  Nov 17; split agreed with Lantern):** `ReadingChallenges.poison_chance(view, listener, night)`.
  It gives the chance, as the listener can tell it, that its own gift was poisoned that night.
  This is the "my reading was poisoned" side of the self-doubt, and the π_T for a teller's
  gift.
  - **Zero** when no Poisoner can be in play (`poisoner_possible`, no minion places), or when
    the listener knows the Poisoner was dead by that night (a public role, or its own
    Gravedigger reading of the hanged Poisoner).
  - **Otherwise** the chance a Poisoner is in play, divided by the number of good people alive
    that night. The first part is the minion places over the script's minions, certain on an
    unknown script. The second is everyone alive less the evil team; the Poisoner chooses one
    good person a night.
  - No new number.
- **In game terms (seven alive, two evil):** one in five when a Poisoner is certainly on the
  script, one in ten when it shares the script with another minion for one place, and one in
  three on the third night after two deaths. None once the town knows the Poisoner hanged.
- **Tests:** new `tools/test_poison_chance.gd` (11 checks, in the fast list).
  `test_workshop_reading_challenges` and `test_medium_relay_challenge` also pass.
- **Not covered:** a Poisoner that is dead but not known to be. The listener can't tell, so it
  still counts it as able to act.

# 2026-11-17, Claude-Lantern: a listener's own home nights reach its movement model (`claude/own-night-knowledge`)

- **Base:** main `9bf568a`, merged in. **Status:** PR open, moves golden, not yet
  re-baselined; queued in Bailiff's golden order. **#216 should land after this one**: with
  #216's play changes, `test_relay_bluff`'s invented-relay check finds a game only this fix
  passes. **Next actor:** Bailiff; Lantern re-baselines on its turn. Beadle: this unblocks
  the Medium night-0 PR.
- **The gap** (Beadle, Nov 17): an evil Medium's invented relay of a listener, "seen out" on
  a night the listener knows it spent at home, counted almost nothing against the relayer.
  1. The listener's home knowledge reached only the role check, not the movement model.
  2. The sighting contests set their balance from the listener's own view, where a sighting
     it knows is false has no honest explanation, which cancelled the relay's weight.
- **The change:**
  - The workshop bridge passes the nights a good listener knows it spent at home as
    knowledge (`view.own_home`, like the known haunts). It never enters the ledger,
    ownership, citations or the world domain.
  - Inside the movement model only, each night becomes a soft alibi
    (`LiveActivity.own_home_cards`, `FlagKnownSelf` in the C# kernel). Being out that night
    is possible only by its self-doubt: the Sleepwalker's 10% when that secret is on the
    script, the own-reading error otherwise.
  - The routes check skips these alibis, so they never make a night impossible. They are
    added only when the listener holds some night evidence.
  - The sighting contests take their balance from what an outsider could know: the same
    profiles with these cards left out.
- **Measured** (`tools/test_own_night_knowledge.gd`, 8 checks; searched cases at 7 NPCs;
  each number is the teller's rise from the card in question):

  | Case | Before | After |
  |---|---|---|
  | An evil Medium's invented relay of a listener who was home (seed 100055) | +1 point | +16 points |
  | An evil planter's street sighting (seed 100012) | +20 | +21 |
  | A real Sleepwalker honestly seen out (seed 100011) | 0 | +1, stays about even on the sighter |

  - Seed 100048: Odette's suspicion of Fenwick after his invented relay goes from 58% to
    95%. Her 10% Sleepwalker self-doubt keeps it short of certain.
  - A planted sighting on the listener's own home block ("seen leaving home") barely counts.
    That's intended: being seen on your own street fits being home.
  - Beadle's seed 100031 can't be checked on main, because his frame-timing change isn't
    merged and that game plays differently there. He should check it on his branch.
- **Golden** vs `baseline_3ef0e2f`:
  - Every seed diverges in beliefs, from day 1 (42, 54875, 692, 900) or day 2 (98933).
  - Outcomes are unchanged: 42 good day 3; 54875 good day 2; 692 and 900 reach day 4; 98933
    good day 3.
  - Two captures identical.
- **Suites:** the whole fast list plus `test_own_night_knowledge`, `test_self_sighting` and
  `test_relay_bluff` (80, all pass). `test_own_night_knowledge` isn't added to the fast list:
  it takes a couple of minutes, mostly seed search, like `test_self_sighting`.
- **Docs:** `docs/belief_model.md`, "A listener's own nights at home".
- **Re-baselined on its turn (Nov 18):** main `65a41b4` merged in; golden `baseline_44073d9`
  (two captures identical); beliefs diverge on all five seeds, outcomes unchanged. Fast list
  plus `test_own_night_knowledge`, `test_self_sighting` and `test_relay_bluff`: 87, all pass.
  Codex reviewed clean (Nov 18, 00:17).

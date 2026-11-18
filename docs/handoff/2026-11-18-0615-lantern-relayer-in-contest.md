# 2026-11-18, Claude-Lantern: a relayed sighting's only teller is its relayer (`claude/relayer-in-contest`; moves golden on one seed; fixes main's `test_relay_bluff`)

- **Base:** main `b65b728` (merged in as `23d0330`). **Status:** PR open, re-baselined
  (`baseline_23d0330`). **Next:** Bailiff (review and merge: the fix for red main, next golden
  slot by Bailiff's call), then my #232.
- **Why:** main went red on `test_relay_bluff` after #216. Bailiff confirmed it passes 4 of 4
  at `7efe0ce` and fails 2 of 4 at `832bd17`.
  - The cause isn't #216's self-doubt. Judging the same game with it on or off gives identical
    numbers. #216 changed play, so the suite's fixture search landed on seed 100029, which
    shows the decided backlog bug "A relayer cut from the sighter contest by the two-sighter
    cap" (Michael, Nov 18; owner Lantern).
  - In that game Hollis (the Demon, bluffing Medium) relays the dead Jory seeing Merrin out
    near Jory's cottage on the night Jory died (an invention, to frame Merrin). Merrin's
    sighters were Fenwick, Jory and Hollis; the cap keeps two, by count then town order, so
    Hollis was cut and his invention was weighed as Jory's honest word: Hollis 0.83 → 0.46 for
    Nisha. With the contests off the relays move him 0.745 → 0.743.
- **The fix (`LiveActivity._sighting_contests`):** a relayed card's only teller is its relayer.
  A Medium learns what the dead knew and never said, so the dead can't have invented it; an evil
  relayer can. This is how a relayed alibi was already handled, and it frees the cap's slot.
- **`test_relay_bluff`:** the evil relayer's relays no longer clear him (seed 100029: 1.00). Its
  second case now searches day 4 from the next seed (seed 100031, Edda on Greta, 0.56 with the
  relays and 0.55 without): with #216 no game in the 120 seeds after 100029 reaches day 5
  holding such a relay, and the check is "another game", not "a later day".
- **Golden:** moves on 98933 only, from record 209 (Agnes's refresh, day 2, after the good
  Medium Agnes's relays), beliefs in the fourth decimal. The other four seeds are identical.
  Outcomes unchanged. Two captures identical.
- **Tests:** the 16 suites that touch the contests or relays pass (`test_sighter_contest`,
  `test_relayed_alibi`, `test_mechanics_relays`, `test_medium_relay_challenge`,
  `test_own_night_knowledge` and the rest), with `test_relay_bluff` 4 of 4.
- **Docs:** `docs/belief_model.md` ("A relayed sighting's teller is its relayer"); BACKLOG item
  marked done. This supersedes my docs-only #240 (which marked the item decided).

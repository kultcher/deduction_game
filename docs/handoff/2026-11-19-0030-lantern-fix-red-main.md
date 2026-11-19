# 2026-11-19, Claude-Lantern: three suites red on main since #246 and #273 (`claude/fix-red-main`, stacked on #290)

- **Base:** `claude/purge-phase3` (#290); merge #290 first. **Status:** PR open. **Next:**
  Bailiff. Then I'm paused, per Seneschal.
- **Why:** main has failed three full-run suites, none of them on the fast list, since my #246
  and #273 (Bailiff, Nov 19). #290 already fixes a fourth, test_self_sighting.
- **test_workshop_consequences and test_workshop_reasoning: wrong behaviour, in the Workshop
  sandbox only (#273).**
  - Since #273, a Night Watch list that wrongly names the listener is kept wherever the
    watcher's gift could have failed. The idea is that the movement model then weighs the
    list as sound or broken as a whole.
  - That weighing happens only on views the live movement model reads (`live_activity`). The
    sandbox's views (workshop/session.gd) don't, so there the kept list was scored name by
    name. The false name cleared the watcher: in the suite, Odette went from 0.27 to 0.08 evil
    and the other names on her list rose. That's what the old rule guarded against.
  - Fix: `SourceDoubt._list_broken_base` gives a list a broken chance only on a live-movement
    view. Elsewhere the list is set aside and its night voided, as before #273.
  - Play views are all live (`game/workshop_canvas.gd`), so play is unchanged.
  - test_self_sighting now asserts both sides.
- **test_workshop_live_cognition: stale expectations (#246, premise centring, Michael's
  option B).**
  - "The same cards aimed at someone else move no one" is the opposite of what centring does.
    Now the cards centre on both targets, and the new target rises.
  - "A Marked question adds no alignment effect" is now false by the documented rule. A Marked
    question names no alignment target, so it leaves its cards unshaped
    (`Shared.brought_by_premise`, carried over from #92). The check asserts that.
  - The premise-type check moved to a game of its own: a later case citing the same cards
    takes the Marked case's place.
- **Held by Michael (Nov 19, via Seneschal): should a Marked question lift a case's centring?**
  - Today it does. Presenting "is Merrin Marked?" on cards an earlier "Odette is evil" case
    brought makes them count in full on everyone, so Merrin rises: about 0.22 to 0.34 in the
    suite.
  - The alternative: owners with no alignment target are ignored in `brought_by_premise`
    unless they're a card's only owners, so the centring stays put. I recommended that.
  - Michael's answer: hold it. Marked will likely change in the secrets rework and may stop
    being a hidden state, so the maths will change anyway. Pick this up then.
  - How often it comes up isn't measured. It needs the player to present a Marked or conflict
    question citing an earlier alignment case's cards.
- **Also pending, for when we resume:** restate test_connections_pairings' framed-sighting
  checks. Measure the fake sighting's own effect, with it held and left out, as
  `Seeds.relay_effect` does for relays. Require a bystander who doesn't already trust the
  sighter. Beadle's #292 lands on seed 100037, where the checks' proxies don't hold (message to
  Beadle, Nov 18).
- **Measured:**
  - The four suites pass: live cognition 68, consequences 46, reasoning 47, self-sighting 10.
    So does test_nightwatch_whole_list (6).
  - Golden and the fast list are in the PR body.
- **Proposed for the backlog:** none.

## Nov 20 — Claude-Lantern: the Sleepwalker's doubt reads what the Rumormonger told her

- **Base:** main `6cccaf4`. **Status:** PR open. **Next:** Seneschal (Michael's OK on the cap),
  then Bailiff. **Moves golden:** re-baselined in this PR (`baseline_922d89c`); queued after #448
  and #444.
- **What this is:** BACKLOG section 6 item 3, `[decided]` (Michael, Nov 20; Seneschal: build it
  with the proposed cap as a placeholder).

### What changed
- `WorkshopBridge.sleepwalk_doubt(w, n)`: on a script with the Sleepwalker, how unsure an NPC is
  that it is not the Sleepwalker. Each Rumormonger reading it holds updates its chance of
  holding the secret, believed as far as it trusts the teller (`npc_trust`):
  - a relayed reading is believed as far as the mean of its trust in the source and in whoever
    passed it on, as the shared ledger weighs the card (Codex on #459);
  - a reading naming it for the Sleepwalker makes it, if true, a coin flip with the other name;
  - any other reading (another pair, or another secret) would rule it out if true, since a case
    has one secret on one townsfolk (the Lovers on two).
- The doubt is `SLEEPWALK_SELF_DOUBT` scaled by that chance against the starting chance, kept
  between the own-reading error and `SLEEPWALK_CHANCE`. With no Rumormonger reading it is
  `SLEEPWALK_SELF_DOUBT`, as before. There are no new constants.
- `own_home` carries it on each home night (the movement model) and as `sleep_doubt`, which
  `CaseEval`'s "am I the Sleepwalker?" mix of the role fits now reads.
- `WorkshopBridge.rumour_moves_sleepwalk_doubt`: a test switch.

### Measured
A scan of seeds 100000–100239 (7 NPCs, day 2 meeting) found 4 Sleepwalkers seen out by an honest
good sighter. Each was given a reading from a half-trusted Rumormonger naming her. Her chance that
the sighter is evil:

| Seed | Before the reading | With it, doubt held at 10% | With it, doubt at the cap |
|---|---|---|---|
| 100045 | 0.92 | 0.67 | 0.20 |
| 100011 | 0.19 | 0.035 | 0.010 |
| 100019 | 0.51 | 0.55 | 0.54 |
| 100109 | 0.28 | 0.24 | 0.23 |

None of the 4 had a real Rumormonger reading naming her. The 0.99 case from earlier (seed 100153)
no longer comes up on main.

### Golden
Only 98933 moves: Lian's day 2 refresh, in the fifth decimal place. Outcomes are unchanged. See
`docs/golden_baseline.md`.

### Tests
- New `tools/test_sleepwalk_doubt.gd`:
  - with no reading, the doubt is `SLEEPWALK_SELF_DOUBT`;
  - named by a trusted teller, it rises, capped at `SLEEPWALK_CHANCE`;
  - a barely trusted teller moves it less, and so does a reading passed on by someone it distrusts;
  - the Sleepwalker named elsewhere, or another secret named, lowers it;
  - the home nights and the role fits carry the same value;
  - in play, the honest sighter's guilt falls.
- Passed: `test_sleepwalk_doubt`, `test_self_sighting`, `test_own_night_knowledge`,
  `test_connections_pairings`.

### Open for Michael
- The cap (a coin flip) is a placeholder. A trusted Rumormonger who names her already takes her
  to it.

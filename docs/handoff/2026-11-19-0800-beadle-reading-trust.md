# Trust from readings that confirm what I know or strongly believe

- **Agent:** Claude-Beadle
- **Base:** main, merged up to the latest on Nov 19
- **Branch:** `claude/beadle-reading-trust`
- **Status:** PR open. It moves golden and re-baselines in the PR. It queues behind the
  golden-moving PRs already waiting, and re-baselines again on its turn.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "Trust from readings that confirm what I know or strongly believe"
  (Michael, Nov 19). The sizes and the built note are added. The false "their readings agree
  with what I know" is added to Tabled.

## What changed

**Reading trust.** A good listener gains trust in a teller whose reading confirms what it knows
or strongly believes.
- **How it's judged:** Lantern's `ReadingConfirm.assess` (#309), on the listener's chances from
  its previous refresh, so a reading is judged on what the listener believed before hearing it.
- **When:** each reading is judged once for each listener, at its first refresh holding the
  reading (`Social.reading_confirm_trust`, called from `WorkshopOwnership._confirm_readings`). A
  Medium's relay of a reading already heard is the same reading, by its logical origin (Codex on
  #319).
- **In the same solve:** the readings are judged in the refresh's first half. When trust moves,
  the listener is captured and prepared again, so the gain counts in that refresh's solve and a
  repeated refresh changes nothing. Bailiff's full run caught `test_workshop_action` failing on
  this. The 40-game numbers below were measured before that fix, which moves the gain one
  refresh earlier.

| Tier (`ReadingConfirm`) | When | Trust (`Tuning.Trust`) |
|---|---|---|
| small | the listener is 70% or more sure the reading is right | `READING_TRUST_SMALL` 0.06 |
| moderate | 85% or more | `READING_TRUST_MODERATE` 0.12 |
| known | it holds by the listener's own knowledge | `READING_TRUST_KNOWN` 0.20 |

**Agreement rebalanced.** #292's agreement step (a vote the same way, or nominating or accusing
someone already suspected) is now its own constant, `Trust.AGREEMENT_STEP` = 0.02, down from 0.03.
`Social.TRUST_VOTED_FOR` stays 0.03, the nominee's thanks to those who spared it.

**The record.** Each NPC keeps `workshop_state.confirmed_readings`: for each teller, its best
confirmation (tier, card, day, fact or belief). It's for the next PR, "their readings agree with
what I know", already approved.
- **Evil NPCs:** an evil NPC's good self keeps a record too, so the evil NPC can say it honestly.
- **Evil NPCs' own trust:** it doesn't move (its shadow copies the real NPC's).
- **The log:** each gain is an `npc_trust` entry with its tier, step, card and source.

All four constants are new, and Michael approved them on Nov 19 (set R3).

## Measured

- **New suite:** `tools/test_reading_trust.gd` (7 checks, two played games), on the fast list.
  - Confirmations raise trust by the tier's size, once for each reading and listener.
  - An evil NPC's own trust never moves for it, and a listener's own reading confirms nothing.
  - The record names teller and tier, and evil good selves keep one.
- **Suites that pass:** test_workshop_action, test_workshop_ownership, test_dialogue_decisions,
  test_agreement_trust (now on `AGREEMENT_STEP`), test_reading_confirm,
  test_social, test_social_trust, test_connections, test_connections_pairings, test_meeting_flow,
  test_evil_play, test_held_signals, test_relay_bluff, test_relay_bluff_games and test_social.
- **Trust distribution:** `tools/measure_npc_trust.gd`, 15 passive 10-NPC games, seeds 3000-3014.

  | End of day 4 | Main (agreement 0.03 only) | Here |
  |---|---|---|
  | Pairs near full trust (0.85+) | 12.6% | 12.2% |
  | Median trust | 0.59 | 0.59 |
  | Top tenth | 0.88 | 0.89 |
  | Lowest tenth | 0.24 | 0.30 |

  - **Day 4:** Michael's soft goal, some NPCs near full trust by about day 4, holds as it was.
  - **The lowest tenth** rises a little. Distrust wears down slightly, which was flagged with the
    proposal.
- **In play:** 40 passive 10-NPC games, seeds 4000-4039, main against this branch.

  | | Main | Here |
  |---|---|---|
  | Agreement gains a game | 94 (2.8 trust) | 93 (1.9 trust) |
  | Reading confirmations a game | — | 12.7 (1.4 trust): 1.7 known, 5.9 moderate, 5.0 small |
  | Readings' share of trust gained | — | 42% |
  | Evil's share: agreement / readings | 32% / — | 33% / 31% |
  | Winners | 22 good, 18 evil | 24 good, 16 evil |
  | Hangings (good hanged) | 91 (34) | 91 (34) |

- **Golden:** see `docs/golden_baseline.md`.

## Proposed for the backlog

None.

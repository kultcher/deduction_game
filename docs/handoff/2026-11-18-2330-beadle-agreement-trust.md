# Backing a case builds trust

- **Agent:** Claude-Beadle
- **Base:** main at 6fcdc32
- **Branch:** claude/beadle-agreement-trust
- **Status:** PR open. It moves golden and re-baselines to `baseline_e881c2f` in the PR.
- **Next actor:** Bailiff (review and merge). Michael, through Seneschal, for the reused
  numbers below.
- **BACKLOG item:** "Backing a strong case builds trust" (Michael, Nov 18; owner Beadle).
  BACKLOG isn't edited while Vicar restructures it.

## What changed

Nothing raised one NPC's trust in another for agreeing with it. The only positive step was a
nominee's thanks to those who voted to spare it. This change applies to good NPCs; evil NPCs'
own trust doesn't move, and their shadow copies it as before.

- **Agreement.** A good NPC warms a little to an ally who:
  - votes the same way it does on a nominee, to hang or to spare. A vote to spare is how one
    NPC stands up for another, so this covers defences: NPCs make no other defence of someone
    else;
  - nominates or accuses someone it already suspects, about as much as it would take to
    nominate them itself.

  It's at most once a day for each ally, so a day of agreeing ballots counts as one agreement.
- **Confirmation.** The first time a good NPC hears a reading, it gains trust in the teller if
  the reading:
  - clears the NPC itself (it knows it's good). This is the larger step, a teller vouching for
    it;
  - agrees with the NPC's own reading, pointing at someone it pointed at or clearing someone it
    cleared. This is the smaller step.

  An evil teller who clears someone buys that person's trust too. That's a realistic lie with
  a reason, and it's in the log.

## Numbers (existing constants, reused, flagged for Michael)

| Step | Constant reused | Value | Its existing use |
|---|---|---|---|
| Agreement (a vote, a nomination, an accusation) | `Social.TRUST_VOTED_FOR` | 0.03 | A nominee's thanks to a voter who spared it |
| "Suspects them too" | `Meeting.NOMINATION_FLOOR` | 0.40 | The lowest suspicion an NPC nominates on |
| A reading that clears me | `Roles.WARDEN_SAVE_TRUST` | 0.1 | A protectee's trust in the Warden who says it guarded them |
| A reading that agrees with mine | `Social.TRUST_VOTED_FOR` | 0.03 | As above |

No new constant. If Michael wants these tuned apart from their original uses, they'd become
named constants of their own.

## Small calls made on Michael's behalf

- **The daily cap per ally.** Without it, a pair that voted together through a day's several
  ballots gained up to 0.49 trust in one game. That's half the scale, not "small".
- **Defences** are covered by vote agreement, because NPCs only ever defend themselves.
- **Evil NPCs' own trust isn't moved** (as with gossip trust).

## Measured

- **New suite:** `tools/test_agreement_trust.gd`, 15 checks, on the fast list.
- **Suites that pass:** test_execution_aftermath, test_evil_play, test_lie_severity_votes,
  test_meeting_flow, test_meeting_m2c, test_npc_chatter, test_mechanics_sharing,
  test_roles_people, test_peer_role_gossip, test_held_signals, test_social,
  test_social_credibility, test_dialogue_opinion_pass, test_conversation_gifts and
  test_gift_doubt.
- **In play:** 15 passive 10-NPC games, seeds 3000-3014, main 6fcdc32 against this branch with
  the cap.

| | Main | Here |
|---|---|---|
| Winners | 9 good, 6 evil | 8 good, 7 evil |
| Hangings (good hanged) | 42 (14) | 38 (14) |
| Agreement gains a game: votes / accusations / nominations | — | 87.5 / 11.4 / 4.3 |
| Confirmation gains a game: cleared me / agrees with mine | — | 4.2 / 2.7 |
| A typical pair's total gain over a game (median) | — | 0.06 (0.03 to 0.09 by game) |
| The largest pair's gain in a game | — | median 0.22, at most 0.36 |
| Share of gains toward evil NPCs | — | 33% (evil is 30% of the town) |

- **Golden:** two captures were identical, and every seed diverges. 42, 692 and 900 keep their
  outcomes. 54875 now hangs only Jory, on day 3. 98933 is a good win on day 2. Details are in
  `docs/golden_baseline.md`.

## Proposed for the backlog

None.

# Meetings feed the gossip network

- **Agent:** Claude-Beadle
- **Base:** main at 2823c17
- **Branch:** `claude/beadle-evil-confer`
- **Status:** PR open. It moves golden and re-baselines to `baseline_d6a93f1`, on main with #292
  and #306.
- **Next actor:**
  - Bailiff: review and merge.
  - Herald: the second-hand line below.
- **BACKLOG item:** "Evil meetings are over-weighted and always visible" (54875). Updated here
  with Michael's Nov 18 and Nov 19 guidance.

## Michael's direction

- **The gossip network (Nov 18):** every meeting goes into the gossip network.
- **The pairing (Nov 19, through Seneschal):** "Visible" means seen before the player chooses.
  Keep today's visible rate, and "don't add new meetings or anything, keep the same numbers of
  meetings". The before/after-choice bonus split stays as it is.

## What changed

The pairing is unchanged from main. What's new is what people learn from a meeting.

- **Witnesses after the player has gone.**
  - A meeting before the player's choice was already seen by everyone there (the day sightings'
    "with" field).
  - Now a meeting after the player's choice is seen too, by those at the same place. That
    includes evil teammates who confer in the same place.
  - (`World._witness_meeting`)
- **Gossip.**
  - In conversation, a witness may pass on the latest meeting it saw, from today or yesterday:
    "X and Y were talking at Z". The listener keeps it as hearsay.
  - It goes one step only; hearsay of a meeting isn't relayed again.
  - Never to one of the two who talked.
  - Evil never passes on its teammates' meetings.
  - (`Social._pick_item`, kind `meeting`)
- **Asked about either person.** The answer to "what do you think of X" can end with a meeting
  of X's from today or yesterday (`MindDialogue._meeting_note`):
  - first hand: "I saw X at the mill, talking with Y, this morning";
  - second hand: "Lian told me they saw X and Y talking at the mill, this morning".

  The player gets a `conversation` fact: a location report for each of the two and a "talked"
  link. Second hand, it comes through the speaker (`via`), as other hearsay does. It's said once
  per meeting. Evil keeps quiet about its teammates' meetings, and no one repeats a meeting the
  player is looking at.

## Tried and set aside (Nov 19)

A first version did two things:
- dropped the evil bonus before the player chooses;
- added a pass after the player left, in which teammates conferred.

It halved the visible rate and cut evil meetings from 21 to 12 on seeds 3000-3014. Michael's
"same numbers" ruled it out. Main already lets teammates confer after the player leaves, when
they are in the same place.

## Wording (Herald)

- **First hand:** reuses the canonical "I saw %s at %s, talking with %s, %s." that
  `answer_today` already says.
- **Second hand:** "%s told me they saw %s and %s talking at %s, %s." is new and unvoiced.
  Herald, please voice it or replace it. Michael approves the wording.

## Measured

- **Suites:**
  - New: `tools/test_meeting_gossip.gd` (13 checks), on the fast list.
  - Also pass: test_social, test_social_credibility, test_social_evidence_boundary,
    test_social_trust, test_npc_chatter, test_dialogue_opinion_pass, test_peer_role_gossip,
    test_mechanics_relays, test_meeting_flow, test_relay_bluff and test_evil_play.
- **In play:** 40 passive 10-NPC games, seeds 4000-4039, main 2823c17 against this branch.

  | | Main | Here |
  |---|---|---|
  | Visible evil meetings (before the player chooses) | 59 (0.34 a day) | 51 (0.30 a day) |
  | Evil meetings after the player leaves | 5 | 5 |
  | Meetings passed on in gossip | — | 52 (0.31 a day) |
  | Winners | 22 good, 18 evil | 23 good, 17 evil |
  | Hangings (good hanged) | 93 (37) | 87 (35) |

  The meeting counts move only because games play out differently from the first changed draw;
  no meeting is added. Passive games don't ask NPCs about each other, so the answers to the
  player aren't measured here; the suite covers them.
- **Golden:** two captures were identical. 692 now also hangs Greta on day 2; the other seeds
  keep their outcomes. Details are in `docs/golden_baseline.md`.

## Small calls made on Michael's behalf

- **The gossip weight:** a meeting is offered in conversation with the existing daytime-rumour
  weight (`Social.DAY_RUMOR_WEIGHT`). No new constant.
- **How far it spreads:** one step of gossip, today's and yesterday's meetings, once per
  meeting to the player.

## Proposed for the backlog

None.

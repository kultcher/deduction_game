# The player's no counts too

- **Agent:** Claude-Beadle
- **Base:** main at `39a57d2` (with #390)
- **Branch:** `claude/beadle-symmetric-vote`
- **Status:** PR open. Golden moves on every seed and is re-baselined to `baseline_7792e9a`.
  Golden-moving PRs merge one at a time.
- **Next actor:** Bailiff (review and merge).
- **Decision:** Michael, Nov 19. A vote is yes or no, with no abstaining, so the player's no should
  sway the town as their yes does, at about two-thirds the strength.

## What changed

- **The no pushes later voters** (`MindMeeting._vote_impl`).
  - **What:** the player's vote is declared before the NPCs vote. A no now adds a `player_votes_no`
    part to each voter's weighing. It mirrors the yes, scaled by the voter's view of the player's
    credibility.
  - **Constants (new):**
    - `Tuning.Meeting.PLAYER_VOTE_NO_SLOPE` 0.12
    - `PLAYER_VOTE_NO_OFFSET` -0.03

    The yes uses 0.18 and -0.04. As with a yes, a player whose credibility is below about a quarter
    pushes voters the other way.
  - **Scope:** only a real tally sets it (`World.vote_pending` sets `meeting["player_votes_no"]` and
    then clears it). `would_vote` and the other dry runs stay neutral.
  - **Explaining a no:** the vote-resistance lines know the new part. A no it helps along isn't
    explained as the voter's "reluctance".
- **A spared nominee warms to the player.**
  - **What:** a living nominee the player voted no on gains a little trust in the player, unless
    the player nominated them.
  - **Constant (new):** `Tuning.Trust.VOTED_NO_ON_ME_RISE` 0.04. It mirrors `VOTED_YES_ON_ME_DROP`,
    0.08.
  - **Log:** the reason is "the Demonologist voted to spare me".
- **A yes goes on the track record** (`game/game_meeting.gd`).
  - **What:** the player's yes on someone else's nominee is recorded as a weak public statement
    that the nominee is evil, at `CRED_WEIGHT_STATEMENT`.
  - **What doesn't:** a no claims nothing, and the player's own nomination is already on record.

## Measured

**Suites:**
- **New:** `tools/test_symmetric_vote.gd` (12 checks), on the fast list:
  - the no's part and its sign at high and low credibility;
  - that dry runs stay neutral;
  - the nominee's trust rise and when it's skipped;
  - the track-record yes.
- **Also pass:** test_meeting_m2d, test_meeting_flow and test_double_claim_response.

**In play:** 10-NPC games, seeds 4000-4039, 40 per side. Main is the Nov 20 main before #390 (the passive
run at `74e6e74`); the branch is that main plus this change. A tally is "decided by the player" when the
outcome would flip without the player's own vote and its push on the NPCs.

| | Main, active | Branch, active | Main, passive | Branch, passive |
|---|---|---|---|---|
| Winners | 30 good, 10 evil | 29 good, 11 evil | 21 good, 19 evil | 24 good, 16 evil |
| Hangings, evil and good | 71 and 26 | 71 and 27 | 55 and 33 | 62 and 28 |
| Tallies the player decided | 28 of 303 | 39 of 320 | 0 of 384 | 11 of 388 |
| NPC votes the player's no turned to no | none | 15 | none | 51 |

- **Active** is autoplay's player, who votes yes and no on its read. **Passive** votes no on every
  tally.
- **With an active player,** the no decided 5 of the 39 tallies the player decided. It's the
  difference a no can now make, and winners and hangings barely move.
- **With a passive player,** the no sways about one NPC vote per tally in eight. It saves 11
  nominees across 40 games. Fewer good were hanged, and more evil. At 40 games, the winner shift is
  within noise.

**Golden:** re-baselined to `baseline_7792e9a`. Two captures were identical. Every seed diverges at
its first tally where the player votes no.
- **54875:** good now wins on day 3, hanging Constance after Greta.
- **692:** hangs only Constance (day 3). Before, it also hung Greta on day 2.
- **42, 900 and 98933:** they keep their hangings and outcomes.

See "Current baseline" in `docs/golden_baseline.md`.

## Small calls made on Michael's behalf

- **No push from the player's own nomination:** when the player nominated someone, the no gets no
  extra trust rise. The player's yes there has no trust drop either.
- **No track-record entry for a no:** a no records nothing, since a no is the default and claims
  nothing about the nominee.

## Proposed for the backlog

None.

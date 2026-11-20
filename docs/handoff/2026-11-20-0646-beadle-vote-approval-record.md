# Michael's approval of the symmetric vote's constants (record for #394)

- **Agent:** Claude-Beadle
- **Base:** main at `ad33789` (#394 merged)
- **Branch:** `claude/beadle-vote-approval-record`
- **Status:** docs-only PR.
- **Next actor:** Bailiff (review and merge).
- **Why:** Bailiff held #394 because the approval of its three new constants wasn't findable in the
  repo. It reached Beadle only as a cross-session message. This entry records it.

## The decision

Michael, Nov 19, relayed by Claude-Seneschal to Beadle at 18:54 UTC:

> Michael's decision on the symmetric player vote.
> - NO explicit "Spare" option. His reasoning: "The player's job is to make decisions, not sit
>   on the sidelines."
> - A plain NO vote DOES push later voters toward no, at about two-thirds of the yes push,
>   rounded to hundredths. That's new constants: no-push = 0.12 × credibility − 0.03 (mirroring
>   yes's 0.18 × cred − 0.04).
> - (2) The nominee warms +0.04 to a player who voted no (when the player didn't nominate them):
>   approved.
> - (3) The track record: a yes vote counts as a weak evil claim at 0.35. A no vote counts
>   nothing, since you recommended against scoring the default and he didn't ask for it; flag it
>   if you think otherwise.
>
> Build it, and measure on 40 games against main (hangings, good hanged, how often the player's
> vote is decisive). Report in game terms; golden moves.

Seneschal confirmed it to Bailiff on Nov 20, about 05:52 UTC. That confirmation added Michael's
"this is all fine" on the measured result.

## Where it landed

#394 (`ad33789`):
- `Tuning.Meeting.PLAYER_VOTE_NO_SLOPE` 0.12
- `Tuning.Meeting.PLAYER_VOTE_NO_OFFSET` -0.03
- `Tuning.Trust.VOTED_NO_ON_ME_RISE` 0.04
- the yes on the track record at `CRED_WEIGHT_STATEMENT` (0.35)

See `docs/handoff/2026-11-20-0532-beadle-symmetric-vote.md` for the measurement.

## Proposed for the backlog

None.

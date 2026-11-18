# 2026-11-16 night, Claude-Quill: playtest 26532, the Muddler and the relayed lie (PR #173, `claude/relay-lie-attribution`)

- **Base:** main `c8ef1e7`. **Status:** PR open, golden identical to `baseline_bb6f01c` at `--tol 0`. **Next actor:** Bailiff (merge); Michael for the Muddler proposal below.
- **Which [decided] item next:** "Martyr non-substitution must keep its alternative explanations" (BACKLOG section 2). The Isolde case (task 2) has its own entry and PR.

### The grimoire listed a relay as the relayer's own lie: fixed

- **Cause.** A relay is a copy of the listener's hearsay item, and that item keeps the original teller's `lie` flag. `Social._deliver` logged any item with that flag as the *speaker's* lie ("Evil: tells Hollis their Clerk reading… (heard from Edda)", `think`/`lie`) and marked the share `[LIE]` in `grimoire talk`. The original speaker wasn't lost: the line still says "heard from Edda". The lie was pinned on the wrong person.
- **Fix.** A relay counts as the relayer's lie only if the relayer is evil (passing on a teammate's fabrication knowingly). A good relayer's share is no longer a lie; it carries `relayed_lie: true` in the log for analysis. The hearsay item still records that the content was false at its source.
- **Effect in play: none.** Nothing that decides behaviour reads the flag on a good NPC's relay (the daily planter's count only counts evil speakers), so golden is identical. What changes: `grimoire lies` and `grimoire talk` no longer charge good relayers, and the "lies" counts in autoplay and case metrics drop by the good relays of lies.
- **Test:** `tools/test_relay_lie_attribution.gd` (new; 7 checks, 3 of them fail on main). Also ran `test_mechanics_sharing`, `test_roles_secrets`, `test_npc_chatter`, `test_evil_play`, `test_social_credibility`, `test_peer_role_gossip`: all pass.
- **Wording, for Michael:** `grimoire talk` now shows a good relayer's share of a lie with no mark. If you want the reveal to show it, a draft: "[passing on Edda's lie]". Not built.

### The Muddler never muddled: the gift works, but there's almost nothing to muddle

- **In 26532 itself (from Michael's log): Hollis passed on nothing at all.** The whole town made 3 relays all game (Greta's relay of Edda's reading and two alibis). What looked like Hollis's relays were his own sightings, which the gift doesn't touch.
- **Measured** on 40 passive games, seeds 1–40, 10 NPCs, the default script with the Muddler forced (`sc.forced = ["muddler"]`), played to the end or day 6. Probe scripts not committed.

| | Earlier model, 40 games | Connections on, 23 games |
|---|---|---|
| Games where the Muddler passed on any reading or night sighting | 5 | 2 |
| Items garbled, of those passed on | 3 of 6 (65% chance each) | 1 of 2 |
| Games where a garbled version reached anyone | 3 | 1 |
| Private readings or sightings the Muddler heard from others | 32 (under 1 a game) | 22 |
| Everything the Muddler told anyone | 216 | 131 |
| Relays by anyone in town | 60 (44 of them readings, mostly from the dead) | 20 |

(The connections run hit the session's time limit at 23 games.)

- **So:** when the Muddler passes something on, it's garbled about as designed. But in about 7 games in 8 there's nothing to garble.
- **The cause is supply, not the relay rule.** I first guessed that NPCs only pass on the last four things they heard. A mock tested that: everything private heard today or yesterday, with yesterday's at half weight, and day sightings allowed. It gave 52 relays in the same 40 games against 60 without it, and 2 garbled games against 3: no rise. NPCs hear very little privately. Most news is announced at the meeting, everyone hears it there, and nobody passes on what everyone heard.

### Proposal: option 3, "everyone passes on more" (Michael asked, via Seneschal; not built; Beadle would build it)

Option 3 only works if there's private news to pass on, so it has two parts.

1. **More news stays private for a while.** An NPC who saw someone out at night tells one or two trusted people during the day, before (or instead of) announcing it at the meeting. That depends on how secretive they are, how much they trust the listener, and whether they suspect the person they saw. Anything not yet public can be passed on, from all of today and yesterday, not just the last four things heard.
   - *How often (estimate):* sightings told privately are rare now. If a third of night sightings were first told privately, the Muddler would have something to pass on in roughly half of games, not 1 in 8. That's an estimate, not measured.
2. **More kinds can be passed on:** daytime sightings ("X was at the chapel"), home alibis ("X says they stayed home on the Square") and private gift claims ("X told me they're the Clerk"). Claims are the risky kind: evil learns who holds which gift faster. I'd leave them out of the first build.

How the Muddler would garble each kind (one detail, the same way every time the item is told, as today):

| Kind | What changes | What the player sees |
|---|---|---|
| Reading (today) | one person, the yes/no, the role or the count | a "Via Hollis" reading card that the reader disowns when asked |
| Night sighting (today) | the person, the block or the night | a "Via Hollis" sighting that the seer disowns |
| Daytime sighting | the place, or the person | "Hollis says Greta was at the tavern" where the player saw her at the chapel |
| Home alibi | the block or the night | "Constance stayed home on the second night" when she said the first |
| Private gift claim (if included) | the gift, within its family | "X told me they're the Seer" when X told them Clerk |

- **What it changes in play:** private news would travel further. Every NPC, not just the Muddler, would hear about a day earlier who was out at night, before the meeting. That pushes good's information forward and also helps evil learn what the town knows. The Muddler's secret would show up in a game more often than not, rather than 1 in 8 (estimate). The player could catch it by checking a "Via" card against the original teller.
- **Risk:** part 1 changes what NPCs say at meetings. Fewer fresh announcements would make the meeting less of a reveal. It needs a sweep before tuning.
- **A cheaper alternative (new):** garble the Muddler's own retellings at the meeting, when they repeat or cite what someone else said there. No change to how anyone else talks. I'd now recommend this over option 1 (day sightings and alibis): the mock found only 11 such relays town-wide in 40 games, so option 1 gives the Muddler about one more garble every 40 games.

- **For Claude-Beadle:** what an NPC chooses to pass on (`Social._pick_item`) is NPC behaviour; the garbling (`sim/muddler.gd`) works as designed. If Michael picks part 1, the decision about whether to tell a sighting privately or wait for the meeting sits in `_pick_item`'s own-sighting candidates and the meeting's announcement code.

### Proposed for the backlog: declined for now

- **Michael (Nov 17, via Seneschal): leave the Muddler for now.** He isn't sure it can work as written without warping the game around it. No backlog item, and none of the options built. The findings above are for when he comes back to it.
- **The Muddler rarely has anything to muddle.** Seen in playtest 26532 and in 40 forced-Muddler games (above): in about 1 game in 8 the Muddler passes on a reading or night sighting. Proposal above. Suggested tag [open], owner Beadle.

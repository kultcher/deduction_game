# Working title: Demonologist (single-player social deduction)

Status: early design + text prototype. This doc records the decisions made so far and the
concrete rules the prototype uses. Anything marked **(open)** is unresolved; anything marked
**(prototype)** is a placeholder choice made to get a working baseline.

## Pitch

A single-player social deduction game inspired by Blood on the Clocktower (BotC). Unlike
Demon Bluff / Dupery, information is not handed over up front: a case unfolds over several
days, with night kills, new information, lies, and twists. The town is a small simulated
place with schedules, sightings and relationships, not just a grid of claims.

The player is a **Demonologist**, an outsider summoned to a town where a demon has taken a
host. The player has their own abilities but is not a townsperson, which sidesteps the
"why doesn't the player follow an occupation schedule" problem.

## Pillars

1. **Information arrives over time.** Each day brings new reports, deaths and claims.
2. **Chaos in information, not in outcome.** Misinformation (lies, poisoning) is something
   to reason about. Losing should be explainable in hindsight.
3. **Every lie has a reason.** NPCs lie because they are evil, or because of personal
   motives. The dev log always records why.
4. **Choices cost time, failures don't.** Actions spend a phase; empty results should still
   be informative.
5. **Hindsight reveal.** End of case shows the full grimoire: who was what, who was
   poisoned when, and every lie.

## Structure

- **Run:** a sequence of cases (roguelike). Meta-progression adds variety (new roles,
  demons, modifiers) and knowledge (bestiary), never raw certainty. **(open)**
- **Case:** one town, 12–15 NPCs in the full game; **6–7 NPCs in the prototype**, with
  one demon and one minion.
- **Cast pool:** NPCs are persistent characters with fixed personalities who get dealt
  different occupations/roles each case, or sit a case out. Personality must never
  predict alignment.

## Time

- Each day has **3 day phases (Morning, Afternoon, Evening) and 1 Night phase**.
- The player gets **one action per phase**.
- End of Evening: **town meeting** (nominations and a vote; at most one execution per day).
- Night: evil acts, abilities fire, the player performs one night action.
- Demon kills happen at night by default. Breaking that rule is a future demon trait.

## World

- The town is divided into **blocks**; each block holds 1–2 **locations**.
- Testimony and evidence usually point to **blocks**, not exact locations.
- NPCs have **homes** (on a block) and **occupations** (tied to a location).
- **Schedules:** each NPC has an anchored slot (usually Morning at work) and flexible
  slots. Deviation is normal, so absence alone is not damning.
- **Sightings:** NPCs in the same location see each other; NPCs on the same block may
  notice each other. Sightings are stored as beliefs and can be reported (truthfully or
  not).
- **Night movement:** most NPCs stay home. Evil NPCs go out to act. Some good NPCs go out
  for personal reasons (insomnia, a secret visit), which creates red herrings.

## Occupations vs. gifts

- **Occupation** is public (the undertaker is known to be the undertaker).
- **Gift (role/ability)** is secret and awakened by the demon's presence.
- Occupations loosely correlate with gifts (believable bluffs). **(prototype: one fixed
  occupation per cast member per case, roles independent)**

## Roles (prototype set, BotC-inspired)

Good (Townsfolk-like). Most give information; some protect.

| Role | BotC analogue | Ability |
|---|---|---|
| Gravedigger | Undertaker | Each night after an execution, learns the executed NPC's true role. |
| Hearthwitch | Empath | Each night, learns how many of their two lane-neighbours are evil. |
| Seer | Fortune Teller | Each night, picks two NPCs; learns if either is the demon. Has one good "red herring" who reads as the demon. |
| Night Watch | (new) | Each night, watches a block; learns who passed through it. |
| Archivist | Investigator | Starts knowing that one of two NPCs is the minion (names the minion role). |
| Clerk | Washerwoman | Starts knowing that one of two NPCs holds a specific good role. |
| Warden | Monk | Each night, protects one other NPC from the demon. |
| Veteran | Soldier | Cannot be killed by the demon. |

Evil:

| Role | BotC analogue | Ability |
|---|---|---|
| Demon (Fiend) | Imp | Kills one NPC each night (not the first night). |
| Poisoner | Poisoner | Each night poisons one NPC; their ability malfunctions (false info) until the next night. |

- Evil NPCs know each other and receive **3 bluffs** (good roles not in play).
- Evil NPCs claim a bluff role and produce fake info for it (see Lying).

## Player: the Demonologist

Day actions (one per phase, at the location the player chooses for that phase):

- **Talk** to an NPC present: a conversation of up to 3 questions (role, last night's info,
  whereabouts, sightings, opinion of someone) or one accusation (mad-libs, see below).
- **Search** the location (murder scenes yield physical evidence).
- **Gossip** (tavern only): overhear a rumour, with its source.
- **Wait.**

Night actions:

- **Ward** one NPC: the demon cannot kill them tonight.
- **Vigil** at a block: see who moves through it at night.

The demon cannot target the player directly. **(prototype)**

## Win / loss (prototype)

- **Win:** the demon is executed.
- **Loss:** the demon is alive and only 2 NPCs remain alive, or day 6 ends.
- Executing the minion does not end the game. The executed role is learned by the
  Gravedigger, not the player directly.

## Town meeting

- Each living NPC with high enough suspicion of someone may nominate them.
- The player may nominate one NPC per day.
- Each living NPC votes. The player's vote counts once. A strict majority of living
  voters (NPCs + player) executes. At most one execution per day: the highest vote total
  wins; ties mean no execution.

## NPC minds

- **Belief store:** facts with source, confidence and when learned (sightings, ability
  results, claims heard, evidence shared).
- **Suspicion:** each NPC holds a suspicion score for each other NPC, updated by ability
  info, contradictions (two people claiming one role), sightings near murders, and
  accusations from people they trust.
- **Trust in the player:** gates how much they share and how much accusations move them.
- **Personality traits:** honesty, caution (claims role later), gossip (spreads beliefs),
  temper (reacts to accusations), loyalty (defends friends).
- **Relationships:** friend / rival edges between NPCs bias suspicion and voting.
- **Evil coordination:** demon and minion share a plan: bluffs, a scapegoat to frame,
  and a kill priority.

## Lying

Reasons NPCs lie, always recorded in the dev log:

1. **Evil cover:** an evil NPC claims a bluff role and generates info by running that
   role's ability on a fake world in which a chosen scapegoat is evil. Lies are
   consistent across days and break only where the cover story contradicts reality.
2. **Personal secrets:** a good NPC out at night for a personal reason lies about
   where they were.
3. **Caution:** a good NPC with a high-value role may hide it early (claims "nothing").
4. **Poisoned:** not a lie; the NPC honestly reports false info.

## Demon kill choice

Each candidate is scored on:

- **Threat:** has claimed an info role; suspicion toward the demon; saw the demon at night.
- **Opportunity:** lives alone on a quiet block; not a known Warden target.
- **Motive:** demon personality weights (vengeful: kill rivals of the host; cunning:
  kill to frame the scapegoat; hungry: random). **(prototype)**

Kills are evidence: "why her?" should be reasoned about.

## Mad-libs accusations

`Tell <NPC>: <suspect> is suspicious because <evidence card>`

Evidence cards come from the player's case board. NPCs evaluate structurally: do they
believe the evidence, how much they trust the player, how they feel about the suspect,
and (if evil) whether it threatens their team. Sharing information with an evil NPC
informs the demon.

## Dev logging (required)

Every event is traced to a JSONL log plus a readable text transcript:

- World events (movement, sightings, kills, poisonings, protections, executions).
- NPC "reasoning" snapshots: why a claim was made, why a lie was told, why a vote went
  the way it did, demon target scores, suspicion changes with causes.
- Per-phase snapshots of each NPC's suspicion table and trust in the player.
- Hidden state (who is poisoned, red herrings, bluffs, scapegoat plan).

## Tech

- **Godot 4 / GDScript.** Simulation core is pure logic, separate from presentation,
  deterministic from a seed, and runnable headless.
- Text prototype first: terminal CLI and a minimal in-editor text UI share one command
  interpreter. An autoplay bot runs many seeds for testing and balance.

## Open questions

- Persuasion economy (trust as a resource; how much pressure sours NPCs).
- Evidence planting (Framer-type evil role).
- Demon types with bestiary entries, exorcism/true-name alternate win.
- Solvability verifier and AI-storyteller director.
- How many clues per day feel right (1 vs 2 player actions per phase).

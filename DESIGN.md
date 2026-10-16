# Working title: Demonologist (single-player social deduction)

Status: early design + text prototype. This doc records decisions so far.
Tags: **(prototype)** = what the current build does as a placeholder; **(proposed)** = a
resolution suggested but not yet confirmed; **(open)** = unresolved. Untagged = decided.

## Pitch

A single-player social deduction game inspired by Blood on the Clocktower (BotC). Unlike
Demon Bluff / Dupery, information is not handed over up front: a case unfolds over several
days, with night kills, new information, lies, and twists. The town is a small simulated
place with schedules, sightings and relationships, not just a grid of claims.

The player is a **Demonologist**, an outsider summoned to a town where a demon has taken a
host. The player has their own tools but is not a townsperson, which sidesteps the "why
doesn't the player follow an occupation schedule" problem.

Movement and "being seen" are a core layer that BotC doesn't have. This is a feature,
but it means the game must teach its own way of thinking and make evidence very readable.

## Pillars

1. **Information arrives over time.** Each day brings new reports, deaths and claims.
2. **Chaos in information, not in outcome.** Misinformation (lies, poisoning) is something
   to reason about. Losing should be explainable in hindsight.
3. **Every lie has a reason.** NPCs lie because they are evil, or for personal motives.
   The dev log always records why.
4. **Choices cost time, failures don't.** Actions spend a phase; empty results should still
   be informative.
5. **The player builds the case.** Deduction is expressed by assembling evidence into
   arguments and persuading the town, not by the game drawing conclusions.
6. **Hindsight reveal.** End of case shows the full grimoire: who was what, who was
   poisoned when, and every lie.

## Structure

- **Run:** a sequence of cases (roguelike). Meta-progression adds variety (new roles,
  demons, modifiers, player tools) and knowledge (bestiary), never raw certainty. **(open)**
- **Case:** one town, 12–15 NPCs in the full game; **6–7 in the prototype**, with one
  demon and one minion.
- **Cast pool:** NPCs are persistent characters with fixed personalities who get dealt
  different occupations/roles each case, or sit a case out. Personality must never
  predict alignment.

## Time

- Each day: **3 day phases (Morning, Afternoon, Evening) and 1 Night phase**.
- The player gets **one action per phase**.
- End of Evening: **town meeting** (see below).
- Night: evil acts, abilities fire, the player performs one night action.
- Demon kills happen at night by default. Breaking that rule is a future demon trait.

## World

- The town is divided into **blocks**; each block holds 1–2 **locations**.
- Testimony and evidence usually point to **blocks**, not exact locations.
- NPCs have **homes** (on a block) and **occupations** (tied to a location).
- **Schedules:** each NPC has anchored slots (usually Morning at work) and flexible
  slots. Deviation is normal, so absence alone is not damning. Overall schedules are
  never shown to the player.
- **Sightings:** NPCs in the same location see each other; NPCs on the same block may
  notice each other. Sightings are stored as beliefs and can be reported (truthfully or
  not).
- **Night movement:** most NPCs stay home. Evil NPCs go out to act. Gifts that choose a
  place (e.g. the Night Watch) put the holder out at night, where they can be seen. Some
  good NPCs go out for personal reasons (secrets), which creates red herrings.

### Visibility of NPCs by day

- The map shows where each NPC is **during the current phase**, and whether they are
  **busy** (talking with someone). This lets the player plan, but they still risk
  missing a conversation: if they want two people in the afternoon and pick one, the
  other may be busy by evening.
- **(proposed)** Only the *current* phase is visible. The timeline automatically
  records only what the player saw at their own location. Recording others' positions is
  a deliberate player action (pin/note). This keeps the evening trace and daytime
  testimony meaningful (see conflict note under Evidence).

## Occupations vs. gifts

- **Occupation** is public (the undertaker is known to be the undertaker).
- **Gift (role/ability)** is secret and awakened by the demon's presence.
- Occupations loosely correlate with gifts (believable bluffs). **(prototype: occupation
  and role independent)**

## Roles (prototype set, BotC-inspired)

Good:

| Role | BotC analogue | Ability |
|---|---|---|
| Gravedigger | Undertaker | Each night after an execution, learns the executed NPC's true role. |
| Hearthwitch | Empath | Each night, learns how many of their two lane-neighbours are evil. |
| Seer | Fortune Teller | Each night, picks two NPCs; learns if either is the demon. Has one good "red herring" who reads as the demon. |
| Night Watch | (new) | Each night, watches a block; learns who passed through it. Is out on that block. |
| Archivist | Investigator | Starts knowing that one of two NPCs is the Poisoner. |
| Clerk | Washerwoman | Starts knowing that one of two NPCs holds a specific good role. |
| Warden | Monk | Each night, protects one other NPC from the demon. |
| Veteran | Soldier | Cannot be killed by the demon. |

Evil:

| Role | BotC analogue | Ability |
|---|---|---|
| Demon | Imp | Kills one NPC each night (not the first night). |
| Poisoner | Poisoner | Each night poisons one NPC; their ability malfunctions until the next night. |

- Evil NPCs know each other and receive **3 bluffs** (good roles not in play).
- A demon kill is **strong but not certain** evidence of goodness: future demons may kill
  their own minion to fake a good death. Rules text should not promise otherwise.

## Player: the Demonologist

Day actions (one per phase, at the location chosen for that phase):

- **Talk** to an NPC present: a conversation of up to 3 exchanges (questions or
  `convince` arguments).
- **Search** the location (murder scenes yield physical evidence).
- **Gossip** (tavern only): overhear a rumour, with its source.
- **Wait.**

Night action:

- **Vigil** at a block (default, unlimited for now; watch whether it's too strong): see
  who moves through it at night, including anyone whose gift sent them there.

### Toolbox

- The player has **2 tool slots, each usable once per case**. Tools resemble town gifts
  and become unlockable/customisable through progression.
- Starting tools:
  - **Ward:** at night, shield one person from the demon (once).
  - **Clemency:** spare one person from execution (once). **(proposed)** Used after the
    final tally; nobody is executed that day; the town knows the Demonologist intervened
    (trust cost, especially with those who voted for it).
- Future candidates: Autopsy (learn a dead person's gift), Séance (question the dead; evil
  dead may still lie), Scry (is X the demon? once, foolable at higher difficulty), Binding
  circle (sets up exorcism). Info tools must narrow, never settle. Evil should react to the
  player's loadout. High difficulty may let the Poisoner affect the player's tools.

The demon cannot target the player directly. **(prototype)**

## Arguments: `convince`

All persuasion uses one model:

> **convince** [NPC] **that** [conclusion] **because** [card(s)]

### Conclusions (starting set; expand from playtesting)

- [X] is evil / is good / is the demon
- [X] is (or isn't) the [role]
- [X] lied about [card]
- [X] was poisoned on night [N]
- [X] should be protected / shouldn't be executed

Each conclusion moves a different part of the NPC's mind:

| Conclusion | Effect on listener |
|---|---|
| X is evil / the demon | suspicion of X up |
| X is good | suspicion of X down; Warden more likely to protect X |
| X is / isn't the role | belief about X's claim; affects double-claim reasoning |
| X lied about card | discredits that card; suspicion of X up (less than "evil") |
| X was poisoned on night N | discounts X's info from night N; **no** suspicion change |
| protect X / don't execute X | protection weighting; vote intention |

This needs belief state the prototype lacks: per-source/per-night "possibly poisoned"
discounts, believed roles, and believed-good flags.

### Contradiction cards

- **Player-built**: the player links two (or more) cards; the game creates a
  contradiction card. Contradictions prove nothing by themselves; they state "these can't
  both be true".
- Each contradiction template carries a set of **explanations** (A lied, B lied, A
  poisoned, B mistaken/red herring/misleading trace, ...). The player chooses which
  explanation they argue as their conclusion.
- Templates are a data library (same person in two places at once; double role claim;
  watcher omitted someone seen on their block; info vs. confirmed fact; etc.). Checking all
  card pairs against all templates is cheap. The dev log flags player links no template
  covers, to grow the library.
- **Unfounded arguments are allowed.** If no template supports a link, a sharp NPC rejects
  it; a credulous or trusting one may be swayed anyway. The player can mislead the town by
  mistake.
- **No invisible technicalities:** every card field a template depends on (day/night
  number, phase, block, source) is shown on the card. When an NPC rejects an argument they
  name the reason ("that was night 2; she said night 1").

### The conclusion builder

- Available from the evidence board at any time to draft and file conclusions ahead of
  time, and inside conversations and the meeting to present them.
- Filed conclusions appear on the board and in NPC profiles.

### How NPCs evaluate an argument

- Weigh each possible explanation using their own view: trust in each source, likelihood
  of poison, firsthand knowledge, relationships, trust in the player.
- The argument moves them in proportion to how much their own weighting agrees with the
  player's chosen conclusion.
- **Insight** trait: higher insight checks more explanations and catches unfounded
  arguments; lower insight is easier to persuade (and to mislead).
- **Diminishing returns:** tracked per NPC per card, so hearing the same evidence again,
  or the same card re-wrapped under another conclusion, counts much less. Corroboration
  only counts independent sources.
- Evil NPCs evaluate arguments for what they reveal: arguing your case to a minion tells
  the demon what you know.
- Every evaluation is logged with its explanation weights.

## Town meeting

Follows BotC's structure:

1. **Floor:** the player may present one prepared argument to everyone at once
   **(proposed: one per meeting)**. NPCs give testimony and claims.
2. **Nominations, one at a time.** Each nomination is its own event with a start and an
   end: nominator speaks, the player may make one short statement (accuse or defend)
   **(proposed)**, then everyone votes and the tally is recorded before the next
   nomination.
3. **On the block:** a nomination that reaches the threshold puts that person on the
   block. A later nomination with more votes replaces them (the first is safe). A tie at
   the highest count means no execution.
4. At the end, whoever is on the block is executed (unless the player uses Clemency).

**(proposed)** BotC limits: each person nominates at most once and can be nominated at
most once per day. Threshold: votes from at least half the living (rounded up).
**(open)** Dead NPCs keep one ghost vote, as in BotC?

**(prototype)** All nominations are voted on together and the player can't speak.

## Evidence

- Physical traces at death scenes point to the **block where the killer spent the
  evening** before the kill (75% accurate in the prototype, otherwise a random other block).
  This rewards tracking evening whereabouts. The trace card must state this rule plainly
  (the prototype's card wrongly implies home/work).
- Conflict to watch: if every evening position were automatically recorded, the trace
  would point straight at a suspect. See the visibility proposal above.

## Player UI (target)

Three main views:

1. **Map:** navigation; home and work locations; currently known positions and busy status.
2. **Evidence board / timeline (one screen):** a grid of people × phases. Every
   observation, claim, reading and testimony sits in its time slot; conflicts are
   highlighted. Filter by type, person, location, source. Contradictions and filed
   conclusions live here. Conclusion builder opens from here.
3. **Profiles:** one per NPC: known facts, their claims, player notes, and (later) a
   player-chosen role icon with a confidence colour.

The prototype's text interface (a flat numbered card list) is a stand-in.

## NPC minds

- **Belief store:** facts with source, confidence and when learned.
- **Suspicion:** each NPC holds a suspicion score for every other NPC, updated by ability
  info, contradictions, sightings near murders, and arguments from people they trust.
- **Trust in the player:** gates how much they share and how much arguments move them.
- **Personality traits:** honesty, caution, gossip, temper, loyalty, **insight**
  (argument evaluation), **readability** (how much they let their feelings show).
- **Relationships:** friend/rival edges bias suspicion and voting. Friends of an executed
  NPC resent its nominators, yes-voters and the player (implemented).
- **Evil coordination:** demon and minion share a plan: bluffs, a scapegoat to frame,
  kill priority.

### Showing trust diegetically

- Greetings, refusals, willingness and small body-language lines change by trust tier
  ("What do *you* want?" vs. "Ah, Demonologist. Sit."). Kept subtle.
- An NPC's **readability** decides whether these cues appear in the text at all: some
  people are open books, some give nothing away.

## Lying

Reasons NPCs lie, always recorded in the dev log:

1. **Evil cover:** an evil NPC claims a bluff role and generates info by running that
   role's ability on a fake world in which a scapegoat is evil. Lies stay consistent and
   break only where the cover story contradicts reality.
2. **Personal secrets:** a good NPC out at night for a personal reason lies about where
   they were.
3. **Caution:** a good NPC with a high-value role may hide it early (claims "nothing").
4. **Poisoned:** not a lie; the NPC honestly reports false info.

## Demon kill choice

Each candidate is scored on threat (info claims, suspicion of the demon, saw the demon at
night, confided in the player), opportunity (lives alone, not a known protection target)
and motive (demon temperament: vengeful, cunning, hungry). Kills are evidence.

## Logic depth

- **NPCs reason with templates**: explainable (every judgement fits a log line), fallible,
  personality-driven. They must not out-deduce the player.
- **A full solver exists only for dev and director use**: enumerate possible worlds
  (role assignments × poison targets per night) consistent with the evidence. Uses:
  solvability checks, measuring how certain the player could be by day N, a future
  storyteller director, possibly hints. Feasible at 7–15 NPCs.
- Main risk is tuning sprawl, not computation: keep the conclusion vocabulary small and
  weights in data files.

## Dev logging (required)

Every event is traced to a JSONL log plus a readable text transcript: world events, NPC
reasoning snapshots (claims, lies, votes, kill/poison scores, argument evaluations with
explanation weights), suspicion and trust changes with causes, per-phase snapshots, and
hidden state. Unmatched player contradiction links are flagged for template work.

## Teaching

- General rules over special cases ("gifts that choose a place send you out at night";
  "a demon kill is strong evidence, not proof").
- A tutorial case on a fixed seed, **later**, once mechanics settle.

## Tech

- **Godot 4 / GDScript.** Simulation core is pure logic, separate from presentation,
  deterministic from a seed, runnable headless.
- Text prototype first: terminal CLI and in-editor text console share one command
  interpreter. An autoplay bot runs many seeds for testing.

## Open questions

- Ghost votes for the dead.
- Is unlimited Vigil too strong?
- Persuasion economy beyond trust (how pressure sours NPCs).
- Evidence planting (Framer-type evil role).
- Demon types with bestiary entries; exorcism/true-name alternate win.
- Solvability verifier and storyteller director.
- How many clues per day feel right (1 vs 2 player actions per phase).

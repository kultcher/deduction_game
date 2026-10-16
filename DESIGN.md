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
- **Schedules:** each NPC has **at least one work slot**; their work schedule is known to
  the player, and the player can always find and talk to them at work then, no
  exceptions. Free slots are flexible and not shown in advance. Deviation is normal, so
  absence alone is not damning.
- **Sightings:** NPCs in the same location see each other; NPCs on the same block may
  notice each other. Sightings are stored as beliefs and can be reported (truthfully or
  not).
- **Night movement:** most NPCs stay home. Evil NPCs go out to act. Gifts that choose a
  place (e.g. the Night Watch) put the holder out at night, where they can be seen. Some
  good NPCs go out for personal reasons (secrets), which creates red herrings.

### Visibility of NPCs by day

- The map shows where each NPC is **during the current phase**, and whether they are
  **busy** (in a conversation). This lets the player plan, but they still risk missing a
  conversation: if they want two people in the afternoon and pick one, the other may be
  busy by evening.
- **Availability per phase:** working NPCs are always available at work. Idle NPCs may
  be pre-paired into a visible conversation, but only while the player keeps **at least 3
  people to choose from** (relaxed late in the game). Example (7 NPCs, morning): 2 working,
  5 idle; 2 pair off; the player chooses among 3 idle + 2 working. After the player
  chooses, remaining idles may pair off (a semi-random chance, with partners chosen by
  trust, confidence and paranoia: two who dislike each other rarely talk; of three, the
  two who like each other are likeliest). Each NPC has at most one NPC conversation per
  day; once pre-paired, they can't be pre-paired again that day (but may still be at work).
- Only the *current* phase is shown live. On the map and timeline, positions the player
  witnessed are shown as **confirmed**; positions heard secondhand (testimony, gossip) are
  shown as **tentative** (e.g. low alpha) and carry their source. Recording other
  positions is otherwise a deliberate player action. This keeps the evening trace and
  daytime testimony meaningful (see Evidence).

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

Day actions (one per phase). After choosing a location, the player sees who is there and
who is nearby. They get **one free move within the same block** (e.g. tavern → well) before
acting, as a backup when nobody useful is home, without letting them scout the whole map.
Then one action:

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
  - **Clemency:** spare one person from execution (once). Used **immediately when a
    nomination is made**: the player is given a chance to intervene, and that nomination
    is cancelled. Other nominations that day proceed normally. Trust effects follow each
    NPC's attitude to the spared person: those who trust them think better of the
    player; those who suspect them think worse.
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
- Caution (not a hard rule): avoid cases where the player believes they are proving
  something but the cards disagree on an invisible technicality. Showing the fields a
  template depends on (night number, phase, block, source) and having NPCs name why they
  reject an argument are the expected mitigations.

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

1. **Floor:** the player may present one prepared argument to everyone at once. NPCs
   give testimony and claims.
2. **Nominations, one at a time.** Each nomination is its own event with a start and an
   end: nominator speaks, the player may make one short statement (accuse or defend) or
   use Clemency, then everyone votes and the tally is recorded before the next
   nomination.
3. **On the block:** a nomination that reaches the threshold puts that person on the
   block. A later nomination with more votes replaces them (the first is safe). A tie at
   the highest count means no execution.
4. At the end, whoever is on the block is executed (unless the player uses Clemency).

BotC limits: each person nominates at most once and can be nominated at most once per
day. Threshold: votes from at least half the living (rounded up).

**Dead NPCs (deferred):** no ghost votes for now. In BotC that rule mainly keeps dead
players engaged, which matters less in single player. Keep the door open to the dead
affecting the game, e.g. the final day's vote is a **Séance** in which the dead also vote.

**(prototype)** All nominations are voted on together and the player can't speak.

## Evidence

- Physical traces at death scenes point to the **block where the killer spent the
  evening** before the kill (75% accurate in the prototype, otherwise a random other block).
  This rewards tracking evening whereabouts. The trace card must state this rule plainly
  (the prototype's card wrongly implies home/work).
- **Known issue (evening shifts):** because the trace uses the killer's *evening* block, a
  demon who works an evening shift has a fixed, publicly known evening block, so traces
  converge on their workplace more reliably than for other demons. **(proposed fix, with
  paths)** decouple the trace from day schedules: at night the killer walks a path from a
  starting point (home or a deliberate detour) to the victim; evidence is drawn from that
  path, which the demon chooses (a cunning demon routes through the scapegoat's block).
  Evening whereabouts then matter as alibis rather than as trace input.
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
- **Personality traits:** see *Trait model* (Planned features). Prototype still uses
  honesty, caution, gossip, temper, loyalty.
- **Relationships:** friend/rival edges seed NPC-to-NPC trust and bias suspicion and voting. Friends of an executed
  NPC resent its nominators, yes-voters and the player (implemented).
- **Evil coordination:** demon and minion share a plan: bluffs, a scapegoat to frame,
  kill priority.

### Showing trust diegetically

- Greetings, refusals, willingness and small body-language lines change by trust tier
  ("What do *you* want?" vs. "Ah, Demonologist. Sit."). Kept subtle.
- An NPC's **Composure** decides whether these cues appear in the text at all: low
  composure, open book; high composure, gives nothing away.

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

## Planned features (tentative)

### Trait model

**Defined traits** (rolled once at case start as base ± that trait's volatility, then
constant for the case; low/mid/high tiers):

| Trait | Low | High |
|---|---|---|
| **Privacy** (about self: role, relationships, whereabouts) | shares who they are and what they know even at low trust; claims publicly early | withholds as long as possible; reveals under pressure; stonewalls rather than lies |
| **Gossip** (about others) | keeps out of others' business; at the extreme, won't share even if asked ("none of my business") until under pressure | volunteers what they've seen and heard |
| **Confidence** | opinions shift quickly; stonewalls or cracks when pushed; rarely nominates | opinions shift slowly both ways; lies boldly when pushed (as good or evil); nominates and votes readily |
| **Insight** (logic, impressionability) | swayed by speech alone | swayed only by concrete evidence or a preponderance of circumstantial evidence |
| **Composure** (keeps emotions in check) | attitude cues obvious; strongly affected by pressure and paranoia | almost no cues; resists pressure and paranoia |

- **Privacy decides whether** an NPC discloses; **Confidence decides what they do when
  pushed** (high: lie outright; low: stonewall or crack). This keeps personal-secret lies
  alive for good NPCs.

**Derived traits** (change during the case, always hidden from the player):
- **Pressure** (individual): scrutiny from accusations, nominations, circulating
  evidence. Pushes high-Privacy NPCs to open up and low-Gossip NPCs to deflect.
- **Paranoia** (global): baseline suspicion of everyone not confirmed; rises as bodies pile
  up. Weighs against Insight and Confidence (flimsy nominations get support late).
- **Trust**: toward the player and toward each other NPC. NPC-to-NPC trust replaces the
  old Loyalty trait.
- Composure reduces the effect of Pressure and Paranoia.

**Alignment:** traits apply to both alignments. Evil **overrides content** (lies instead of
truth) but **style follows traits and pressure**: a high-Privacy demon stonewalls (good
cover); a low-Privacy demon volunteers a bluff early. Pressure is the legitimate reason for
behaviour to shift, for both.

**Decisions are weighted rolls:** a score from traits, trust and context becomes a
probability; score breakdowns are logged.

**Trait reveals to the player:** after a private conversation, one trait is revealed with a
roll for a second (Composure lowers it); after each meeting, a chance per attendee
(Composure lowers it) to learn one trait. Reveals show the rolled value, not the cast
member's baseline. Only defined traits are revealable. Tuning: if too fast, make the
conversation reveal a chance and the meeting chance low. Present as tiers, described in
character the first time.

**(prototype)** Traits are mostly hard thresholds on the old set: caution (claim timing,
trust needed to reveal a gift, starting trust), temper (meeting accusations, trust lost
when pressed), loyalty (friends in votes/accusations, grief), honesty (confession
threshold), gossip (tavern speaker pick).

### Evidence classes (for Insight)
- **Speech:** claims, opinions, hearsay.
- **Circumstantial:** reported sightings, traces, readings reported by others.
- **Concrete:** player-witnessed events, owner-identifying items, template-confirmed
  contradictions.

### Statement taxonomy

| # | Statement | Drivers | Evil variant |
|---|---|---|---|
| 1 | Gift disclosure (tiers) | Privacy ↑ lower/later; Trust ↑ and Pressure ↑ raise tier; Composure dampens pressure | same schedule, bluff content |
| 2 | Gift reading | as #1; trust drop stops new readings, with explicit refusal | fabricated; high Confidence frames, low stays harmless |
| 3 | Own whereabouts / alibi | Privacy high stonewalls, low volunteers; if hiding and pushed: Confidence high lies, low cracks/stonewalls; Pressure pushes to lie-or-confess | same; always hiding after a night out |
| 4 | Sighting of others | Gossip high volunteers, low only if asked; high trust in subject may omit friends | omits teammates; Confidence decides inventing |
| 5 | Corroborate / deny an alibi | trust in that person; shared secret: Privacy (quiet) vs Confidence (lie to protect) | may deny a true alibi to frame |
| 6 | Opinion, vibes ("something's off") | low Insight, high Paranoia; Gossip shares | same mix |
| 7 | Opinion, reasoned | Insight ↑; Gossip shares | fabricated reasons |
| 8 | NPC-made argument / contradiction | Insight finds; Confidence airs publicly | built from bluffs |
| 9 | Accusation / nomination | Confidence ↑; Paranoia lowers threshold; Pressure deflects onto others; Composure dampens | pushes scapegoat |
| 10 | Defence of self or another | trust in defended, Confidence; self-defence rises with Pressure | defends teammate, carefully. **(later)** Overrides: a pressured minion distances himself from the demon and tries to look like someone else's minion ("throw under the bus"); the demon goes along with town/player conclusions to build trust |
| 11 | Confession | low Privacy, high Trust, high Pressure, low Confidence | false confessions (fake secrets) |
| 12 | Hearsay / relay | Gossip; distortion with low Insight | seeds lies |
| 13 | Request to the player | low Privacy; trust in player and subject | "protect X" as bait or probe |
| 14 | Reaction to an argument | Insight sets bar by evidence class; Confidence sets shift speed; trust in source and subject | judges what it reveals |
| 15 | Changed story when caught | Confidence high doubles down, low confesses; Composure hides fluster | main improvisation point |
| 16 | Small talk / noise | Gossip | same |
| 17 | Approaching the player | low Privacy or high Gossip, plus an agenda | to frame or probe |
| 18 | Withholding ("I've told you enough") | trust fell below highest shared tier; Composure decides whether a reason is given | same |

Vibes-based opinions (#6) are used by good NPCs too, including about other good NPCs, so
unfounded suspicion is normal town behaviour, not an evil tell. Evil also cites
(fabricated) reasons.

### Reactions

| Event | Effect | Modifiers |
|---|---|---|
| Player airs their secret publicly | trust loss | Privacy low: small; mid: large; high: large + **trust ceiling** (can't rebuild past "wary" this case). High Confidence may retaliate publicly. Composure: visible anger or not |
| Player keeps their secret (end of day) | trust gain | bigger for high Privacy; reduced (not lost) if someone else spread it and the player stayed quiet |
| Neutral chat (once/day) | small gain | high Privacy warms up slower |
| Player argues something they agree with | gain scaled by agreement | high Insight gains less from agreement alone |
| Pressed with too many questions | loss | high Privacy loses more; Composure dampens |
| Player accuses them privately | loss, Pressure ↑ | high Confidence counter-accuses; low cracks (more disclosure) |
| Player accuses someone they trust | loss | scaled by trust in that person and Confidence |
| Publicly nominated / accused | Pressure ↑ and trust loss toward the nominator (and the player, if they nominated or backed it) | Composure dampens; low Confidence discloses, high counter-attacks |
| Caught in a contradiction | Pressure ↑↑; #15 fires | confession + player discretion can raise trust |
| Friend executed | loss toward nominators, yes-voters, player if yes | scaled by trust in friend; trust ceiling if the player nominated |
| Player proven right | gain | bigger for high Insight |
| Ward/Clemency on someone they trust / suspect | gain / loss | Paranoia tilts toward loss |
| Body found; town shrinks | Paranoia ↑ (global) | Composure dampens |
| Evidence against them circulates | Pressure ↑ | Composure dampens |

**Trust ceiling:** serious betrayals cap the maximum trust regainable with that NPC.

### Unified gift/info question and hints
- `ask gift` and `ask info` merge. Disclosure tiers:
  1. Denies having a gift, **or** refuses to say what it is.
  2. **Flavoured hint** (in-world, not metagame) pointing to a role package (e.g.
     protection: Warden/Veteran).
  3. Gift, **or** vague information. **(tabled until the roster is defined)**
  4. Everything.
- No 3-for-3.
- Good NPCs never illogically fall back to a lower tier. If trust drops after sharing,
  they withhold *new* information and say so explicitly ("I've told you enough").
- Roles are flavoured to fit hint packages; keep packages in mind when adding roles
  (aim for 2+ roles per package).

### NPCs approach the player
- At the start of some phases an NPC asks to talk. The approach itself is free: the
  player gets a yes/no prompt. **Having the conversation costs the phase action**; if they
  decline, the slot is used normally. Sussing out who's worth talking to is part of play.
- Who approaches: a good NPC with news, an evil NPC spreading a frame or probing, or a
  **busybody** (high Gossip). Busybodies always give *some* information, usually low
  impact (a sighting), and are a main path to learning others' **secrets** (an affair, a
  reason someone sneaks out).

### Building trust
- Neutral conversation; presenting a case they agree with (even one the player doesn't
  believe); acting in their interest (warding/sparing someone they trust); being proven
  right; keeping their secret (end-of-day bonus). See Reactions for losses.
- Using someone's secret publicly costs trust with its owner regardless of who told the
  player.

### Evil knowledge and coordination
- At baseline evil knows: each other's identities, bluffs, and a shared plan. The first
  night gives free shared knowledge (as in BotC).
- After that, evil knows only what a member **saw or was told**, and must **meet** to
  share: own sightings, what the player argued to them, readings of public behaviour,
  plan updates (scapegoat, kill target, consistent bluffs and alibis).
- This replaces places where the prototype's evil AI reads hidden state directly (private
  suspicion, private night sightings, true night walkers, whom the player confided in).
- If this makes evil too weak (measure with the autoplay bot), add specific knowledge back
  to evil's automatic pile selectively.
- Meetings can be crowded (tavern; slow, hard to observe) or private (fast, riskier).
  Frequency follows personality, not alignment. Good NPCs meet constantly too, so meetings
  aren't a tell on their own.

### Good-to-good social dynamics
- Simple model: two NPCs choose to talk; NPC 1 shares one thing they know (a sighting, a
  reading, an opinion, something the player argued); it affects NPC 2's judgement through
  the same evaluation as player arguments (source trust, diminishing returns).
- Every belief records **who it was heard from**, so it can be traced and disowned.
- Evil can feed lies into the network.
- Limit and scheduling: see *Availability per phase* (World). Pre-paired conversations are
  visible (busy); evil meetups use the same mechanism and each evil NPC's one daily
  conversation, with good pairs as noise. Tune the signal:noise ratio.

### Claims matter to good NPCs
- Good NPCs weigh public claims. A Warden who trusts a claimed strong information role is
  more likely to protect them; NPCs value claimed roles when voting and choosing whom to
  confide in.
- The demon factors in a known Warden claim when choosing targets, and after a failed
  kill almost always switches to a new target the next night.

### Geography, paths and dropped evidence
- Blocks remain the unit of space; the map gains real **paths** (sequences of
  blocks/locations). Night movement follows paths.
- Evidence can be dropped **anywhere along a path**, by the killer or by anyone else out
  for their own reasons (noise). E.g. demon goes chapel → graveyard → victim's house; a
  clue may turn up in the graveyard.
- The death-scene trace (killer's evening block) stays.
- Owner-identifying items (a named scarf) are strong evidence: keep them rare, and later
  plantable by a Framer-type role. Category traces (soot, mud) are common.

### Confrontation, alibis and confessions
- The player can **confront** an NPC with evidence. The NPC may confess the true reason
  (including a personal secret like a gambling debt), lie, or name an alibi.
- Alibis **name a corroborator** ("I was with Jory"). The corroborator confirms or denies,
  which can produce a word-against-word contradiction card.
- Evil may claim a false secret ("I was meeting Jory for an affair"), or name someone they
  really did meet, to throw suspicion on them. Good NPCs may also lie to protect a shared
  secret out of trust in their partner, so a real affair can stay hidden.
- Evil naming each other as alibis is a classic BotC pairing tell; smart evil usually
  avoids it.
- All of these are expressed as cards (alibi claim, confirmation, denial, confession).

### Clemency and the demon
- The demon may deliberately **not** kill someone the player spared, leaving them alive to
  be suspected (fits the existing scapegoat logic).
- **Town paranoia:** as the town shrinks, good NPCs grow more suspicious of everyone not
  yet killed or otherwise confirmed.
- **Urgency:** NPCs become more willing to execute late ("we must hang someone"); the
  player may need to talk them down. Tune paranoia and urgency together so the last days
  don't become random lynchings.

## Rollout plan (proposed)

1. **Foundation (text). [built]** Split game output into structured events/cards with text as a
   rendering layer, so a UI can later consume the same data. Add the trait model,
   schedules/availability with the in-block move, unified gift question with tiers and
   hints, trust building/reactions/ceiling, BotC-style one-at-a-time nominations, the
   two-slot toolbox (Ward, Clemency), demon retargeting, and the opinion-template fix.
2. **The town talks (text).** NPC-to-NPC conversations and belief provenance; evil
   coordination replacing hidden-state reads; NPC approaches (incl. busybody secrets);
   pressure and paranoia. Bot runs to check evil isn't too weak; playtest round.
3. **The case board (thin Godot UI).** `convince` with conclusions, contradiction cards and
   templates, evidence classes, diminishing returns; timeline grid, profiles, filters,
   confirmed vs. tentative positions. Built as a minimal Godot panel because multi-card
   building is painful in pure text. Playtest round.
4. **Full UI.** Map (homes, work, known positions), board/timeline, profiles with role icons
   and confidence. Trait reveals and trust cues presented diegetically.
5. **Geography and confrontation.** Paths, dropped evidence along paths, confrontation,
   alibis and confessions. Benefits from the real map.
6. **Later:** urgency tuning, throw-under-the-bus overrides, Séance final vote, roster
   expansion and hint packages, solver/director, larger towns.

## Playtest findings (3 cases, 2 players)

- Gradual reveal works; relationships and secrets work as intended.
- **Wasted actions:** many day actions were spent searching ordinary empty locations,
  usually because the person sought wasn't there. Addressed by day visibility; consider
  making `go` free to look.
- **Players expect evidence chains:** after a trace pointed to a block, players went and
  searched that block. Candidate: traces lead to a secondary clue at the killer's evening
  location (dropped item, witness), giving `search` a real purpose. **(open)**
- **Players read social patterns** ("Agnes keeps meeting the other evil"). The prototype
  has no daytime evil coordination, so that read was coincidence. Candidate: make it real
  (evil meetups to coordinate, which can be observed; friends and lovers meet too, as
  noise). **(open)**
- **Evil information is the most forthcoming:** evil NPCs claim early and share a
  steady, consistent frame of the scapegoat, which is easy to follow into lynching the
  innocent. Working as intended, but town and player pull may be too strong: a
  player-led nomination of the true Seer passed 7/8. Consider NPCs resisting when their
  own information contradicts the nomination.
- **Vigil is strong:** one well-placed vigil on the kill block (plus an Archivist pair)
  won a case on day 3. Keep watching.
- **Template tell (fixed in stage 1):** evil opinions say "Something's off about them" with no reason,
  while good opinions cite one. Fix both ways: good NPCs give vibes opinions too; evil also
  cites (fabricated) reasons.
- **UX:** `go <block>`/`go <person>` should work (expected to resolve with the real UI);
  asking `info` before `gift` repeats the answer (resolved by the unified question);
  "as I said" is used for claims never said to the player.

## Open questions

- Is unlimited Vigil too strong?
- Persuasion economy beyond trust (how pressure sours NPCs).
- Evidence planting (Framer-type evil role).
- Demon types with bestiary entries; exorcism/true-name alternate win.
- Solvability verifier and storyteller director.
- How many clues per day feel right (1 vs 2 player actions per phase).

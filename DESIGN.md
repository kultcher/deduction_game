# Working title: Demonologist (single-player social deduction)

Status (Nov 4, 2026): playable Godot prototype with a painted town screen, a case board,
a red-string Case Workshop judged by a shared possible-worlds model (its solver kernel in
C#), case scripts with an editor, and a deep NPC social simulation; text CLI and an
analyst autoplay bot alongside. This document describes **how the game works now** and
**which directions are decided**. It is organised by system, not by date; dated build
notes are condensed into [History](#history-and-measurements) at the end.

**Tags.** Untagged text in a system section = built and current. **[decided]** = direction
agreed, not built yet. **[tentative]** = a proposal awaiting design or tuning review.
**[open]** = path not chosen. **[watch]** = no change planned, keep an eye on it.
**[knob]** = a lever kept for balancing, not planned.

**Companion documents**
- `BACKLOG.md`: the to-do list, by effort, plus the Workshop-gap list. The single place
  for "what's next". `BACKLOG_POLISH.md` holds presentation-only polish.
- `TUNING_NARRATIVE.md`: a plain-English account of how the social and evidence systems
  interact. `tuning_catalogue.md`: the code-level companion (where each number lives).
  The numbers themselves live in `sim/tuning.gd`.
- `docs/meeting_flow_plan.md`: the meeting trial, slice by slice (M0–M4).
- `docs/orchestration_plan.md`: work zones and their status.
- `docs/golden_baseline.md`: the golden capture that guards against behaviour drift.
- `docs/handoff_log.md`: notes between the agents working on the code.
- `docs/DIALOGUE_DESIGN.md`: the voice bible and dialogue rules.
- `docs/text_formatting.md`: the shared text system.
- `role_exploration.md`: role ideas, On Deck gifts, relationships, exploratory places.
- `docs/archive/`: finished plans (the legacy retirement, the C# solver migration, the
  evidence rework, the social trust pass, the shadow self, the dialogue prototype).

---

## Pitch

A single-player social deduction game inspired by Blood on the Clocktower (BotC). Unlike
Demon Bluff / Dupery, information is not handed over up front: a case unfolds over several
days, with night kills, new information, lies and twists. The town is a small simulated
place with schedules, sightings and relationships, not just a grid of claims.

The player is a **Demonologist**, an outsider summoned to a town where a demon has taken a
host. The player has their own tools but is not a townsperson, which sidesteps the "why
doesn't the player follow an occupation schedule" problem.

Movement and "being seen" are a core layer that BotC doesn't have. This is a feature, but
it means the game must teach its own way of thinking and make evidence very readable.

## Pillars

1. **Information arrives over time.** Each day brings new reports, deaths and claims.
2. **Chaos in information, not in outcome.** Misinformation (lies, poisoning) is something
   to reason about. Losing should be explainable in hindsight.
3. **Every lie has a reason.** NPCs lie because they are evil, or for personal motives.
   The dev log always records why.
4. **Choices cost time, failures don't.** Actions spend a phase; empty results should still
   be informative.
5. **The player builds the case.** Deduction is expressed by assembling evidence into
   arguments and persuading the town, not by the game drawing conclusions. NPCs must not
   out-deduce the player.
6. **Hindsight reveal.** End of case shows the full grimoire: who was what, who was
   poisoned when, and every lie.

---

## Structure

- **Run:** a sequence of cases (roguelike). Meta-progression adds variety (new roles,
  demons, modifiers, player tools) and knowledge (bestiary), never raw certainty. **[open]**
- **Case:** one town, chosen on the **New Case screen** (town population, then a script).
  Two sizes:
  - **7 townsfolk:** 5 good (one carries the secret), 1 minion, the demon. 6 days.
  - **10 townsfolk:** 7 good (one carries the secret), 2 minions, the demon. 8 days.
  - Larger towns (12–15) only once the core loop works at 7/10. **[watch]**
- **Win:** the demon's host is executed. **Lose:** only two townsfolk remain, or the last
  day ends.
- **Cast pool (15):** persistent characters with fixed personalities (trait baselines in
  `sim/content.gd`) who are dealt different occupations and roles each case, or sit it
  out. Personality must never predict alignment. Agnes, Bartholomew, Constance, Dorian,
  Edda, Fenwick, Greta, Hollis, Isolde, Jory, Kiran, Lian, Merrin, Nisha, Odette; each has
  a portrait (with five expressions), a standee, an ink colour and a voice.

## Time

- Each day: **3 day phases (Morning, Afternoon, Evening) and a Night**.
- The player gets **one action per phase**.
- End of Evening: **town meeting**.
- Night: evil acts, gifts fire, the player takes one night action.
- **Day gifts** fire during the day: the Dowser on its first public block with company,
  the Augur at the start of the Evening (before the player's Evening action and the
  meeting), the Executor's reading in the morning after its charge dies.
- **Night order:** walkers are placed, then readings, then the demon's kill
  (`C.INFO_BEFORE_KILL`, true; false gives BotC's kill-first order). Our dead can't speak,
  so a victim's last reading only reaches the town through a Medium. A night is one
  instant; timing within it isn't modelled.
- Night 0 is "the night before you arrived" in all player-facing text. The demon kills
  from night 1. Spoken references to nights use ordinals ("the second night").

---

## World

### Blocks, places, homes, roads

- The town has **four blocks** (the Square, the Market, the Docks, Chapel Hill); each holds
  two **locations** (the tavern and the well; the smithy and the bakery; the wharf and the
  mill; the chapel and the graveyard). Testimony and evidence usually point to blocks.
- The **Town Hall** on the Square is a player-only building: NPCs never visit, work at,
  haunt or search it.
- Each block has a **home material** (straw, forge soot, river mud, chalk dust) that shows
  up in drops.
- NPCs have **homes** (spread evenly: 10 townsfolk 3/3/2/2, 7 townsfolk 2/2/2/1) and
  **occupations** tied to a workplace. Where everyone lives is common knowledge.
- **Every block has a road to every other.** A night walker goes home → destination, so
  they're seen only on their home block (leaving) or where they went. The Lamplighter is
  the exception: the lamp route passes every block.
- Occupation and gift are independent for now. Occupations should eventually correlate
  loosely with gifts, for believable bluffs. **[open]**
- **Procedural town** (blocks, buildings and roads generated per case). **[open]**

### Schedules and visibility by day

- Each NPC has **at least one work slot**, known to the player; they can always be found
  and talked to at work then. Free slots are flexible and unannounced; deviation is
  normal, so absence alone is not damning.
- **Haunts:** each person has two favourite idle spots (40% of idle hours). Nobody's haunts
  are known at the start; asking someone about a person may reveal one or both. Searching a
  place names one of its regulars (once per place per game), and seeing someone idle at a
  haunt on 2 different days (3 for the tavern; `Tuning.Setup.HAUNT_SIGHTING_DAYS*`) teaches it.
- **Profile receipts.** Where someone lives, works and idles, their learned traits and
  their known bonds are kept as hidden **profile receipts** rather than board cards. They
  show in the person's profile and enter a case through a **Profile Info** node in the
  Workshop. Receipts are immutable: a later haunt reveal or trait shift adds a receipt.
- **Who you can see.** People at work or deep in conversation are visible from anywhere.
  Anyone else is out of sight until the player picks a block for the phase; then everyone
  on that block shows, including who's home (a lit window). Spots you can't see show a
  count ("someone's there"), never a name. At night everyone is home.
- **Availability.** Idle NPCs may be pre-paired into a visible conversation (busy) only
  while the player keeps at least 3 people to choose from. After the player acts, remaining
  idlers may pair off, partners weighted by trust and news. Each NPC has at most one NPC
  conversation a day.
- **Firsthand records.** Each day phase records people visibly working at their workplace
  as firsthand sighting cards. Conversations you see, people you see nearby, and quiet
  nights also become cards.
- Positions the player witnessed are **confirmed** (solid markers); hearsay is
  **tentative** (hollow markers, with source); tavern rumours are **dotted**.
  Observations aren't joined into an implied route.

### Night movement and sightings

- Most NPCs stay home. Evil goes out to act (the demon; the Poisoner). Gifts that choose a
  place put the holder out (Night Watch, Warden at the guarded door, Medium at the hearth,
  Lamplighter on the lamp route). Secrets put some good NPCs out (Lovers, Sleepwalker).
- A walker can be seen by someone out on their route (50%) or from a home window on it
  (15%). Neighbours at home sometimes notice someone stayed in (20%): a weak, true
  **witness alibi** card.
- **Sightings are told from where you say you were.** From home: "from my window, I saw X
  leave their house"; out: "I saw X out on the Docks". Someone who claims home won't report
  what they saw on another block (a rattled few let it slip: a catchable contradiction).
  Evil's invented sightings follow the same rule.
- **How night sightings count** (shared judge, `workshop/live_activity.gd`): a movement
  model gives each possible world a likelihood for every sighting and trace. Good people
  are out about 5% of nights with no walking gift, always on a walking-gift duty, and
  about 55% with a night secret; minions about 25%; the Demon goes to the victim's home on
  kill nights, with a 5% chance of a detour, so being seen elsewhere argues strongly but
  not absolutely against being the killer. Scattered sightings corroborate a walking-gift
  claim; previews and replies name both relationships ("Seen elsewhere", "Scattered
  sightings"). The live Demon never actually detours (BACKLOG).
- **Sighter contests** (#135): in a world where a sighter is evil, their sighting (or a
  Night Watch's "I saw X pass by") counts only `Workshop.EVIL_SIGHTER_TRUTH` (0.15) of the
  time and otherwise as an invented one, as likely on average as an honest one, so a
  sighter's word against a person's own alibi is decided by priors. A sighter converted by
  the Revenant's curse is doubted only for what they told while converted. At most
  `SIGHTER_CONTEST_MAX` (2) sighters a person, the most-cited first.
- **Vigils see destinations:** a player vigil on a block sees walkers arriving there, or
  doing the full Lamplighter tour, not people passing through. The Night Watch still sees
  all traffic.

### Physical evidence

- **Scene traces** (`World._kill`): each murder leaves a trace pointing at places the
  killer frequents (their workplace or haunts): a **token** names two locations ("a
  stamped wooden flour-cask tally; folk carry those around the bakery or the wharf"), a
  **scent** names three. Traces are generated so a match fits roughly 60–85% of the town,
  and later traces avoid repeating or nesting earlier ones. The player reads a trace
  against profile receipts: matches, contradicts or unknown, at a 3:1 likelihood ratio.
- **Second traces:** when another walker passed the victim's cottage that night, 45% of
  scenes carry a second trace from the passer, in random order. The judge scores both
  assignments jointly. The grimoire says who left which.
- **Drops:** each walker may drop something on their route (demon 35%, others 15%): a
  home-block material (88%) or a personal item (12%). `search` finds everything dropped at
  a location. A personal item becomes a night "out" card for its owner.
- Owner-identifying items stay rare (later plantable by a Framer). Category traces are
  common.

### Decided and open directions (world)

- **Passing through vs. stopping** as sighting wording ("heading toward the Docks" vs "out
  on the Docks"). **[open]**
- **Locations as evidence:** a Dowser reading places the Dowser and group on a block but
  isn't a location card; your own visit could prove who *wasn't* at a spot. **[open]**
- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  Players expect this (playtest 1). **[open]**
- **NPCs find evidence and personal items.** **[decided]**

---

## Roles: the script

Role data lives in `sim/roles/<id>.gd` (one `RoleDef` per role, registered in
`sim/role_registry.gd`); what each reading *says* in general terms (who it points at, who
it speaks for, who it names) is its **shape**, so reasoning keys off a few reading shapes
rather than particular gifts. Every role and secret has an icon
(`assets/ui/roles/<id>.png`). The script window opens when a case begins.

### Scripts

- A **script** (`sim/script_def.gd`) lists the roles that may be in play: town gifts,
  secrets, minions and up to 4 demons. It is public. Evil never bluffs or names an
  off-script role.
- The **Default** script is the 15 starter gifts, 4 secrets, 4 minions and the Demon. The
  **script editor** (`ui/script_editor.gd`) adds and removes roles, forces roles in play
  (for debugging and custom games), filters by tag, fills to size and saves to
  `user://scripts/*.json`. **Dynamic scripts** built at random from the full roster are on
  the `claude/dynamic-script` branch.
- **Constraints are soft:** the editor and New Case screen warn when a script doesn't cover
  the suggested tags (first-night info, ongoing info, evil ID, demon ID, role ID,
  protection, night walkers). Only a script that can't be dealt at all is blocked.
- **The deal** keeps a little protection: at least two start-knowledge gifts (Archivist,
  Clerk, Surveyor, Rumormonger) and at least one identifier (Seer, Dowser, Gravedigger,
  Augur, Registrar). It retries up to 200 draws and is best effort when a script can't
  meet it.
- One demon per game; a script lists demon types by difficulty (only the default Demon
  exists so far).

### Good gifts (20)

| Gift | Ability |
|---|---|
| Archivist | Starts knowing that one of two people is a particular minion. |
| Augur | Each evening from day 1, learns whether they crossed paths with the Demon in public on the same block that morning or afternoon. Marked may register as the Demon (50%). |
| Chronicler | On night 3, learns three other people (living or dead): at case start, one was an ordinary townsperson, one carried a secret, one was a minion. Never holds a solo secret. |
| Clerk | Starts knowing that one of two people holds a particular gift. |
| Confessor | Each night (not the first), visits one living person in secret and learns whether their spirit is good. Evil and Marked souls return no memory of the visit. Is out at night. |
| Dowser | The first time each day they're out in public on a block with two or more others also in public, learns how many of those are evil. A day reading, shared with its time. |
| Executor | Starts knowing one other person. If that person dies, learns their role the next morning (Marked reads as an evil role 30% of the time; poison or Delusional corrupts it). |
| Gravedigger | Each night after an execution, learns the hanged person's true role. |
| Lamplighter | Each night walks the lamp route through every block (so is out, and can be seen) and learns how many others were out. |
| Magistrate | Each night from night 1, learns whether the first townsperson (other than the player or the Magistrate) to nominate that day shared an alignment with their nominee. No nomination, no reading. |
| Martyr | Once per case, secretly chooses someone they trust (trust ≥ 0.62, minus suspicion; never night 0). If that person is later executed while good, the Martyr dies in their place: both proven good to everyone. If the chosen is hanged and the Martyr lives, the Martyr learns they were evil. Doesn't cover demon kills. A poisoned Martyr's save fails. Reluctant to vote to hang their chosen. |
| Medium | Each night after the first Demon kill, visits an unvisited Demon victim's hearth (or revisits the most recent victim) and learns one thing they knew but never said in public (see Mediums below). |
| Monitor | Each night (not the first), learns the role of one person who walked abroad on their home block, or that no one walked by their house. Never receives window night sightings. "No one walked by" is a movement fact for the solver (nobody else's route crossed that block); a sighted role is not yet. |
| Night Watch | Each night watches a block; learns who moved through it. Is out on that block. |
| Psychologist | Each night (not the first), learns either two statements they heard directly that day, at least one of them a lie or misreading, or that none of the eligible statements they heard that day were false. Gets a nudge to seek conversations. |
| Registrar | Starts knowing three roles on the script (at most one minion, never the Demon), at least one of them in play. Each night from night 1, checks one person and learns whether they hold one of those roles. Marked gives a false yes 50% of the time when a minion is on the slate. |
| Rumormonger | Starts knowing that one of two people carries a particular secret (two, not one: secret-holders are good, so one name would clear them). |
| Seer | Each night picks two people; learns if either is the demon. One good soul reads falsely as the demon (the red herring), and a Marked soul may. Picks scale with Insight (sharp Seers re-check suspects and pair them with someone unchecked). |
| Sexton | Once per case, from night 1, may toll the church bell at the start of night and walk through every block. For that night and the next day the bell suppresses minion abilities: the Poisoner's poison, the Breathstealer's silencing, the Brute's hunt, the Revenant's totem and curse, the Scion's rise. The toll is not public: the Sexton keeps it quiet while the bell holds (refusing, never lying, when asked where they were) unless pressed hard, and is open about it from the morning after it wears off. Evil plays the bell only once a Sexton has told the town of it (no Scion fallback; a Revenant isn't worth hanging). A poisoned Sexton walks and tolls for nothing. |
| Surveyor | Starts knowing whether all the residents of one random block (not their own, with at least two residents) share the same alignment. Marked registers as evil 50% of the time. |
| Veteran | The first attack fails; they learn the last block the attacker came through (their own if the demon lives there). A second attack kills. |
| Warden | Each night guards one other person's door against the demon. Stands at the door, so can be seen, framed and hunted. After a quiet night they may believe they made a save (see below). |

Players may ask a gift-holder who has told them their gift to use it a particular way
tonight (a Seer to look at someone, a Warden to guard, a Night Watch to watch a block, a
Registrar to check someone). They agree, refuse or counter-propose by trust and their own
plans; evil bluffers answer the same way and fake the result.

**Warden saves.** After a quiet night (Demon alive) on which a good Warden guarded
someone, the Warden believes they made the save with confidence 1 / (1 + living public
Veteran claims other than themselves). At 0.5 or more they believe it: their trust in the
protectee rises, and if they trust the protectee enough they tell them. A Warden report
of a save holds only in worlds where the protectee is good, at reduced reliability (a save
is an inference, not something seen).

**Hint packages** (each gift sits in at least one package of 2+, so a hint is never a full
reveal): official business (Archivist, Clerk, Surveyor, Rumormonger, Chronicler,
Magistrate, Registrar); night sight (Seer, Night Watch, Lamplighter, Monitor); the dead
(Gravedigger, Medium, Sexton, Martyr, Executor); shelter (Warden, Veteran, Martyr);
reading people (Dowser, Psychologist, Rumormonger, Augur, Confessor). Keep packages in mind when
adding roles.

Benched: **Hearthwitch** (learns how many living lane-neighbours are evil; kept in code,
`status = "benched"`, off every script).

### Evil

- **Demon:** kills each night from night 1. Rolls a **temperament** per case that only
  touches kill choice: *vengeful* (+1.5 on anyone it trusts below 0.4), *cunning* (+1.5 on
  the scapegoat's block), *hungry* (random 0–2.0 per person per night).
- **Minions:**

| Minion | Ability |
|---|---|
| Poisoner | Each night poisons one person: their gift fails or lies until the next night. Out at night. With no Poisoner in play the demon is the only evil out at night. |
| Breathstealer | Once a day (any day phase, likelier later), silences someone on the same block, wherever they are on it. It must be out, not at home. The silence takes hold at that evening's meeting and lasts until the next evening. The silenced can't claim, testify, accuse, nominate, defend, answer you or chat with NPCs; they can still vote. You can still call on them: asking costs
nothing, and a card shown to them costs a question and moves their beliefs without a reply. Never the same person twice running. Picks the most dangerous voice. |
| Brute (experimental: not dealt automatically until the solver models it) | While alive, hunts and kills in place of the demon, dropping two traces; the demon stays home. Registers as a minion, not the demon. |
| Revenant | Hides a totem at a location it visits, on any day that began with no totem in play. If hanged with a totem hidden (and not poisoned), a random good yes-voter turns evil; the town is warned. `search` at the totem's location burns it (it's caked with the Revenant's home material, a lead). Found before the hanging: no curse. Found after: the turned soul is good again. Teammates often vote to let a Revenant with a totem hang. |
| Scion | If the demon is executed while five or more are alive, the Scion becomes the demon (no double kill). |

- Evil NPCs know each other and receive bluffs (good roles on the script but not in play,
  at least one more than the evil team's size).
- A demon kill is **strong but not certain** evidence of goodness: future demons may kill
  their own minion. Rules text must not promise otherwise.
- The demon cannot target the player. **(prototype)**

### Secrets (modifiers)

One per case, laid on a good townsfolk on top of their gift (the Lovers affect two but
count as one):

| Secret | Effect |
|---|---|
| Delusional | Their gift doesn't work and gives arbitrary information (they don't know). Protective gifts fail too. |
| Marked | Gifts that read them may see them as evil or the demon: Dowser, Surveyor, Martyr and the Seer 50%, the Augur 50%, the Registrar 50% when a minion is on its slate; a Gravedigger or Executor sees a random evil role 30% of the time. |
| Secret Lovers | Meet at a random block each night (both out), trust each other, know each other's secret, hide it like any secret (may confess). When one dies, the other withdraws: Privacy to the maximum, Gossip to the minimum, Composure up. |
| Sleepwalker | Leaves home on about half of nights to a random block without knowing it: honestly says they were home, sees nothing while out. |

Lovers and the Sleepwalker are never dealt to holders of a night-walking gift, so a
claimed walker's own duty never has to explain a second reason to be out.

The older personal night-outs (insomnia, smuggling, debt) are benched
(`C.USE_FLAVOR_SECRETS = false`): with modifiers in play they put too many innocents out.

### The turned (Revenant's curse)

They keep their gift and keep claiming it; from then on their readings are fabricated the
way evil bluffs are. They know the team and the team knows them. When the totem burns
they're good again, remember nothing of who else was evil, and disown what they said while
turned. Other NPCs still hold what they heard; nobody knows who was turned. A freed soul's
standing is restored.

### How the town reads the special events

All of these are facts in the shared judge, weighed per world: a Demon victim is good in
95% of worlds; a public curse proves the executed Revenant evil and makes good yes-voters a
little suspect; a Martyr's sacrifice proves both good; a silenced person was someone evil
wanted quiet; a quiet night supports a Warden or Veteran claim; a Veteran's "came by way
of X" bears on X's residents; a Medium's report is a relay of the dead source's original
evidence (below).

### Mediums: one menu for real and fake

The shared judge reads a Medium's report as a relay of the dead person's original
evidence: dated to the original night and source, never an independent second origin. Its
reliability depends on doubt about both the Medium and the dead source.

**Real Medium** (`World._medium_item`), in order: if poisoned or Delusional, a false
sighting; the first unshared reading from any information gift; an unreported night
sighting; a Warden's guard history (one night per visit); distrust (real for good dead
above 0.35; the scapegoat for evil dead, a lie); "nothing they hadn't already told us" if
they'd shared readings; otherwise "home". The real Medium has no deliberately empty answer.

**Fake Medium** (`Evil._fake_medium_item`) draws from the same kinds of answer: 15%
something empty (`C.MEDIUM_USELESS_CHANCE`), then a weighted pick: an unshared reading in
the dead's **publicly claimed** gift for their last night (weight 3; e.g. a dead Seer's
"yes" on the scapegoat or carried on from an earlier yes, or clearing a publicly named
demon); a sighting of the scapegoat near the death (1.5); "nothing new" (0.8); the dead's
public stance (0.8); "home" (0.4). After the first frame, framing paths are offered only
about half the time. Both name the hearth ("Communing with the dead at Dorian's hearth").

### Roster directions

- **Roster expansion** **[open]**: On Deck gifts (Tracker, Clairvoyant, Beckon,
  Tallyman, Bellringer…); minions (Framer/Forger with evidence planting, Blackmailer,
  Hexer, Informant); Debtor secret. Each needs a hint package and solver support before
  it goes live.
- **Script follow-ups** **[decided]**: the off-script tell (a claim to an off-script role
  is a lie, in NPC reasoning and the solver); multiple demon types; builder rules
  ("jinxes"); remembering the last script.
- **Relationships** (Bonded, Unrequited, Feuding, Hater) and Lovers relationship mods.
  **[open]**
- **Revenant seeks execution** (draws suspicion on purpose), and **NPCs search for
  totems**. Today the Revenant is often invisible. **[decided]**
- **Breathstealer confirms the good:** it only silences the good, so a silence proves
  innocence. Options: (a) it may silence a suspected teammate as cover; (b) silence goes
  quiet (unannounced; the victim stonewalls with a small tell; evil can feign it); (c)
  both; plus a good secret that inflicts the same silence, and an optional silence that
  may skip days. **[open]**
- **Demon types** with bestiary entries; exorcism / true-name alternate win. **[open]**

---

## The player: the Demonologist

### Day

After choosing a location the player sees who is there and nearby, and gets **one free
move within the same block** before acting (a backup when nobody useful is home, not a
scouting tool). Then one action:

- **Talk** to someone present (see Talking). Leaving before asking anything costs no time
  (except an approach you accepted).
- **Search** the location: crime scenes give the traces; anywhere can turn up drops or a
  totem.
- **Gossip** (the tavern, Evening only): the evening's NPC conversations finish, then you
  overhear 3–5 anonymised items from the day's shares (yesterday's too, at 0.6× weight), backfilled with unlearned haunts and
  public bonds (never the Secret Lovers). These become **rumour** cards: dotted on the
  timeline, not pressable and not usable in the Workshop.
- **Town Hall records** (Morning or Afternoon, 3 times a case): the ledgers name two gifts,
  exactly one of which is in play ("either the Seer or the Augur is in town, not both").
  A concrete card the Workshop can use.
- **Wait.**

**Approaches:** at the start of some phases an NPC asks to talk (news, a frame or probe,
a busybody's gossip, or a fearful NPC asking for your protection in exchange for their
gift). Accepting costs the phase; declining is free. The approach waits for your answer:
no other action is taken until you accept or decline. Someone who came to tell you news,
a frame or their gift shares every sighting they remember in that conversation.

### Night

- **Vigil** at a block (default, unlimited): see who arrives there, including anyone
  whose gift sent them there, and anyone on the full lamp route. Offered vigils build
  trust only; they don't deter the demon. Strength **[watch]**.
- **Ward** (toolbox, below) or **sleep**.

### Toolbox

Two tool slots, each usable once per case. Tools resemble town gifts and become unlockable
through progression.
- **Ward:** at night, shield one person from the demon. A stopped kill leaves a chalk
  sigil on the door, so the demon isn't made cautious by it.
- **Clemency:** used when a nomination is made; that nomination is cancelled (its slots
  stay spent). The spared person's trust rises; others react by how they regard the
  spared. The demon may deliberately leave a spared person alive to be suspected.
- Future candidates **[open]**: Autopsy (a dead person's gift), Séance (question the dead;
  evil dead may lie), Scry (is X the demon? once, foolable at higher difficulty), Binding
  circle (sets up exorcism). Info tools narrow, never settle. Evil should react to the
  loadout; high difficulty may let the Poisoner affect the player's tools.

### Talking

A conversation opens with a voiced greeting in the daytime conversation view (portraits
with expressions; the greeting changes after a murder, an execution, a friend's death,
friction or protection). It has **3 questions**. The menu:
- **Ask about <name>'s gift…**: their gift, or "are you the X?". A right first guess makes
  them own up a little more readily; a wrong guess costs trust (0.02 × wrong guesses so
  far) and gets the same non-answer an unwilling holder gives, so a guess never eliminates
  anyone.
- **Ask them to use their gift** (once they've told you it): look at, guard, watch or
  check someone tonight.
- **Offer…**: your ward on their door, or a vigil on their block, tonight. Free (no
  question). Trust +0.03 on the offer, +0.06 when kept, −0.15 when broken; settled when
  you choose your night work. An evil NPC passes your promise to its team. **[watch]** on
  the numbers.
- **Ask where they were and who they saw…**: earlier today (not the phase you're in;
  first thing in the morning, that means yesterday), last night, yesterday evening /
  afternoon / morning. Daytime answers start with where they were and are truthful
  (daytime whereabouts are open to anyone's eyes). People you can already see are left
  out. Night answers go through the night account (Lying, below).
- **Ask about others…**: "Opinion on…" a person (may add their haunts and recent
  sightings of them, and second-hand gift talk they've heard), or "Heard of a…" gift (who
  claims it, publicly or in private if they'll pass it on; small chance the holder owns
  up).
- **Ask why they suspect X**, after they hinted at the meeting (see Citing reasons).
- **Present a card** (below). A card already shown costs no question, once per
  conversation.
- **Apologise** for a grievance they hold.
- **Leave.**

**Presenting** is the one verb for using the board on someone. The game reads the
direction from the card's structure (does it implicate or clear, and whom) and who it's
about:
- a card or case about the listener **presses** them: pressure rises with the card's
  weight in their own view; a night card makes them account for that night; a card about
  their gift re-runs the disclosure decision (a true Clerk naming opens them up); a rival's
  claim of their gift makes them restate it and turn on the rival. Nerves show with
  probability ~ (hiding ? 0.6 : 0.2) × (1 − Composure) × strength: a hint, not a tell.
  Costs trust unless the card names them favourably.
- a filed case about someone else **argues** it; a plain card about someone else makes a
  case for or against them; multi-person cards apply to the group, split.
- A card with no direction falls flat ("I'm not sure what you're trying to prove"), costs
  no question and is logged.

The meeting's `present` is the same act in public.

---

## Cards and the case board

### Cards

- Everything learned becomes a numbered card with an **evidence class**:
  - **Speech:** claims, opinions, hearsay, refusals, accusations, alibis.
  - **Circumstantial:** reported sightings, traces, readings reported by others.
  - **Concrete:** player-witnessed events, owner-identifying items, Town Hall records.
- **Terms.** A **claim** is any stated piece of information from an NPC: a **role claim**
  (what someone says their gift is), a **reading** (a gift's result; poison can break it),
  a **report** (a sighting, an alibi, an opinion; poison doesn't touch it). **Evidence**
  is what the player saw or found. A **case** is an argument the player files in the
  Workshop and presents.
- Every card carries **when it happened** (canonical; all views place cards here) and
  **when you learned it** (every disclosure: who told you, public or private).
- **One fact, one card:** the same fact reaching you again (privately, relayed, at a
  meeting) is another disclosure on the same card. The same fact from two witnesses is two
  cards that know about each other (`corroborated_by`, "(also seen by Dorian)").
- **Withholding** is a card too ("X claims the Archivist but won't share what it has shown
  them"), weak speech.
- Hidden cards fade (42% opacity) when shown; only filed cases can be deleted.

### The case board

- **Views** (exclusive, each with its own filters): **Places & sightings** (rows by place
  or person), **Statements** (rows by the person a card is about; claims, readings,
  opinions, accusations, Town Hall records), **Process** (nominations, votes, executions,
  deaths, quiet nights, curses, silences). A card may show in two views (a
  Night Watch report is a statement and a set of "ability" markers); it counts once in a
  case.
- Drawn board with pan, zoom, three levels of detail, paper cards with role icons and the
  speaker's colour; solid/hollow/dotted/ability-ring dots in Places; red strings on hover
  or selection (to speakers, relayers, other appearances, a case's supports); day
  navigation (a day includes the night before); Fit day / Fit selection / Whole case.
- **Filters** are removable chips with Clear all and a status line ("Showing 4 of 31 ·
  Statements · Filters: About: Agnes"); text filters combine with `+` and exclude with
  `-`. Shared between the grid and the Card List.
- **Overlays** (minimized by default, movable, resizable, from a bottom-left dock): Card
  List, Profile, Notes, Roles. A shared right-click menu on any card offers Add to Case
  Workshop and Hide/Unhide (Delete and Unpin for filed cases).
- **The Case Workshop** (`ui/workshop_drawer.gd`, `ui/live_case_workshop.gd`) is a sheet
  over the board's right edge: a handle by default, free drag with snaps at half and full
  width. Double-click, drag or right-click adds a card; dragging it back out (or
  right-click) removes it, with one step of undo. Profile Info and Circumstantial Evidence
  nodes are added from buttons.
- **Filed cases** wait in a fold-up tray under the grid and pin to the board where
  dropped.
- Conflicts are never auto-marked (space for an optional hint system later).
- Code: `game/card_model.gd` (times, views, rows, markers), `game/board_model.gd` (layout
  as data), `ui/case_state.gd` (shared view, filters, selection), `ui/board_view.gd`,
  `ui/deduction_tray.gd`, `ui/case_view.gd`; tests in `tools/test_board.gd`.

### UI directions (case board)

- **Card zoom and rich text on cards** **[decided: extension deferred; renderer approach
  open]**: settle card sizing, clipping, badge slots and zoom/detail transitions before
  extending the shared text system to board cards, the tray and Card List. See
  `docs/archive/text_system_handoff.md`.
- **Long dropdowns in columns** (e.g. long "is the <blank>" lists, grouped by category).
  **[tentative]**
- **Claims/reveals timeline** next to the location timeline. **[open]**
- "Stayed home" vs "none of your business" on the boards. **[watch]**
- Free-floating panels. **[open]**

---

## Cases and how the town judges them

Every presented case, every NPC's belief refresh and every reason an NPC gives come from
**one shared model**. The legacy template-and-weights system was retired between Nov 1
and Nov 3 (`docs/archive/legacy_retirement_plan.md`): there are no link templates, no
`link` / `conclude` commands, and no fallback to the old rules.

### Building a case: the Case Workshop

The red-string board (**More > Case Workshop**; `ui/live_case_workshop.gd`):
- **Premise:** a conclusion about a person or a piece of evidence. Supported types
  (`LiveAssessment.CONCLUSIONS`): evil, good, the Demon, not the Demon, a minion, Marked,
  suspicious, a modifier holder, holds / doesn't hold a gift, lied, truthful, misled,
  unreliable, and "something doesn't add up" (conflict). Protect and spare are
  preferences, spoken as social speech. "Has a secret" and "red herring" can't be
  presented: nothing the town can weigh establishes them.
- **Cards with inline answers** (who in this Seer pair? which blocks?); unknown answers
  stay legal.
- **Profile Info** node: a person's unlocked profile facets (home, work, haunts, traits,
  bonds), the premises traces are read against.
- **Circumstantial Evidence** hub: soft patterns (shared a location with a silencing,
  pressure tells, corroborated walking routes) that add at most +0.015 per incident and
  +0.045 per target across all active cases. It needs a premise, can't carry a case alone,
  and is a separate retractable contribution.
- **Links** between evidence and the premise; contradicting statements merge into a
  contradiction card that offers the challenges.
- **Challenges** on a card: unlikely, misled or lying. A gift reading against an alibi
  offers both explanations ("the alibi is false" / "the report is false").
- **File case** turns it into a presentable case, usable as a premise later.
- **Strength while building:** doesn't support / weakly / moderately / strongly, from a
  neutral test juror (public facts, default trust). Feedback names a clashing card, the
  card that weakened the case and who it brings in, collateral ("this mostly raises
  suspicion of X"), idle assumptions and where each assumption came from.

`present` uses it privately or at the meeting. A presentation containing evidence the
model can't read is **blocked with the reason**. A bare belief with no evidence is social
speech. Rumour cards from the tavern can't be used.

### The shared judge

`workshop/case_eval.gd`, reached through `workshop/jury.gd`,
`workshop/shared_ledger.gd` and `game/workshop_ownership.gd`; its hot kernel runs in C#
(`workshop/cs/`). **It judges the
player's case; it doesn't search for theories.**
- **Possible worlds:** every assignment of the evil team, the Demon and the modifier
  holder, enumerated exactly. Each card is a yes/no (or likelihood) fact per world: a
  reading holds or not, a role claim fits, a sighting fits the movement model, a trace
  matches the profile.
- **Listener prior:** each person's odds of evil = exp(1.5 × the suspicion the model
  doesn't own) × a trust factor (full NPC-to-NPC trust halves the odds, none doubles
  them). The outside suspicion is a flat 0.1 seed, so in practice friendships and
  rivalries are what tilt the prior.
- **Readings:** the listener's own readings count nearly as fact (error 0.002), others' at
  error 0.01 (a Night Watch list 0.08), each discounted by source doubt (below). The
  Seer's red herring is averaged over every possible herring, including Marked's 50%.
- **Soft testimony:** a good source's claims bind; an evil source's role declaration may
  be a bluff (bluff weight 0.92, so bare claims count weakly). One lie never voids every
  world.
- **Public facts:** a Demon victim is good in 95% of worlds; refusals and hints are weak
  (likelihood ratio 1.5); opinions and accusations are not evidence; crowd pressure is
  social; votes are public procedure, never guilt by association.
- **Source doubt** (`workshop/source_doubt.gd`): caught lies and impossible claims in the
  listener's view (a unique gift clash, a false sighting of the listener, a Gravedigger
  report about a cursed Revenant) and accepted honest-error challenges ("misled on night
  N", impaired, unlikely) lower how much a source's readings count, per night or for every
  night. An accepted "lying" challenge doesn't: the reading keeps full reliability, so its
  clash with the grounds counts against the reader in the worlds where they're good (#123). Poison belongs
  to the night, not the person; a good NPC never doubts their own honesty but can accept
  that their own reading was poisoned.
- **Bounded attention:** Insight sets how much of what a listener holds they actually
  weigh. Presented cards are always read, and the listener's own readings are pinned
  beside them. The rest is ranked by salience: naming the premise's target (when judging a
  case), naming someone the presented cards name, being a gift reading, trust. The belief
  update has no premise target, so an argument's framing never moves beliefs on its own
  (premises plan, step 0b revised). A duller listener also takes a strong evil reading
  partly at its word ("one of Kiran or Fenwick is the Demon") on top of the full model.
- **Suspicion change** = 0.45 × the shift from prior to posterior, scaled by how far the
  listener trusts the source of the evidence, then by **directional Confidence**: the
  `1.4 − 0.8 × Confidence` factor applies only to moves against the listener's lean (their
  suspicion at the end of the previous day, centred on their own average); fresh and
  reinforcing evidence comes through at full strength. Hard proof (a posterior at 0 or 1)
  isn't resisted.
- **Execution priority:** from the same posteriors, centred on the listener's mean, with a
  bonus for their top two suspects. It enters nominations and votes at weight 0.22, so a
  credible lead makes a target actionable without inflating belief.
- **Two runs per listener:** a belief refresh (everything they hold: how do their
  suspicions move?) and a scoped reply (what they say about this case; its effects are
  never applied). **Replies match beliefs:** the stance they voice comes from how far the
  refresh actually moved the subject (0.06 or more: accept; 0.02: partly), and the scoped
  reply supplies only the reasons. During the meeting refreshes are held until each
  speaker's turn.
- **Cost model:** cost ≈ listeners × refreshes × evaluations × cost per evaluation. A
  per-world fact is cheap; new hidden state multiplies everything. Speed budget (user's
  machine): meeting entry and presenting about 2 s, nominations under 1 s.

### Decided and open directions (cases)

- **The premise should matter** **[decided: direction; numbers open]**: listeners update
  mainly on the argued target, with Insight-scaled spillover; a clearly wrong premise
  costs a little trust; the preview hints when the evidence points elsewhere. Today the
  refresh ignores the premise.
- **Observable actions as evidence (Stage 1B)** **[decided: the split; details open]**:
  votes, nominations and defences as per-world likelihood factors measured from bot runs.
- The running list of patterns the Workshop can't express yet is in BACKLOG ("Workshop
  gaps").

---

## NPC minds

### Traits

Five **defined traits**, rolled once per case as the cast baseline ± that trait's spread,
then constant (low / mid / high tiers at 0.34 / 0.67):

| Trait | Low | High |
|---|---|---|
| **Privacy** (about self: role, relationships, whereabouts) | shares who they are even at low trust; claims early | withholds as long as possible; reveals under pressure; stonewalls rather than lies |
| **Gossip** (about others) | keeps out of others' business | volunteers what they've seen and heard |
| **Confidence** | opinions shift quickly; stonewalls or cracks when pushed; rarely nominates | defends its lean against contrary evidence; lies boldly when pushed; nominates and votes readily |
| **Insight** | weighs only part of what they hold; swayed by headlines | weighs everything; swayed only by what the evidence supports |
| **Composure** | attitude cues obvious; strongly affected by pressure and paranoia | almost no cues; resists pressure and paranoia |

Privacy decides **whether** an NPC discloses; Confidence decides **what they do when
pushed** (lie outright vs stonewall or crack).

**Derived state** (changes during the case, hidden):
- **Pressure** (individual): accusations, nominations, presses, circulating evidence.
  Loosens claims and secrets. Decays ×0.6 each night.
- **Paranoia** (per NPC): 0.07 per death, dampened by Composure; lowers nomination and
  vote bars late. It doesn't touch suspicion.
- **Rapport and credibility with the player** (below), and **NPC-to-NPC trust**
  (relationships: friends and rivals are rolled per pair; Lovers trust each other).
  Friends of an executed NPC lose rapport with the player if the player nominated or
  voted, and privately resent its nominator and yes-voters (an action-only term that
  fades nightly and clears if the friend is later shown evil).

**Alignment:** traits apply to both. Evil overrides **content** (lies) but **style follows
traits and pressure**.

**Decisions are weighted rolls:** named score parts become a probability through one
sigmoid (`Mind.decide`); every breakdown is logged and shown live in the decision
inspector (Debug ▸ Rolls).

**Trait reveals:** after a private conversation one trait is revealed, with a roll for a
second (Composure lowers it); after each meeting, a chance per attendee. Profiles show
learned traits as continuous bars (filling from the midpoint).

**Showing trust diegetically:** greetings, refusals and small body-language lines change
by trust tier ("What do *you* want?" vs "Ah, Demonologist. Sit."). Composure decides
whether these cues show at all.

### Rapport and credibility

The player has two numbers with each NPC (`game/credibility.gd`):
- **Rapport** (`n.trust`) is how the NPC feels about you. It governs disclosure, requests,
  approaches and confidences. Civil conversation, kept promises, first private
  disclosure, keeping a confessed secret (a bonus that halves each night) and being
  proven right raise it; pressing, question fatigue (beyond 3 questions a day), wrong role
  guesses, accusing someone they trust, nominating them, spreading their secret, breaking
  a confidence or a promise, and a friend's execution lower it. **Trust ceilings:**
  spreading a very private person's secret, or nominating someone a good NPC grieves,
  permanently caps it. Slights fade: each night a grievance recovers a quarter of its
  drop (a serious one only up to half). Apologising for a specific grievance repairs some
  of it.
- **Credibility** (`n.credibility`, starts at 0.5) is how much your word counts: in the
  shared model's source trust for your cards and presentations, and in your vote, accuse
  and defend terms. It comes from your track record: the conclusions you argued to that
  NPC, checked each dawn against what they now believe from their own evidence (without
  your presentations, so the check isn't circular).

### Belief: what an NPC holds

- **Receipts.** Each NPC's ledger stores what they actually heard or witnessed, keyed by
  the **underlying fact** (Jory's night-1 reading; Agnes's sighting of Bart on the Docks),
  not by who relayed it: role claims, readings (own and heard), relayed sightings and
  testimony, defences, silences, Demon deaths. Hearing the same fact again adds a
  disclosure, not weight. Each NPC reasons only from what they actually heard.
- **Suspicion** = a flat 0.1 starting seed + the shared model's joint vector over
  everything they hold. Bonds live in NPC-to-NPC trust (which tilts the prior), not in
  suspicion. Crowd pressure, paranoia and grief are **action-only** terms: they move
  nominations and votes, not belief. The shared model owns every ledger entry;
  recomputing without new evidence changes nothing, and mutual accusations can't
  amplify. A refresh that can't be prepared keeps the last good vector and logs why.
- **Role claims** are per-listener records weighed in the worlds: a good NPC's knowledge
  of their own gift is near-certain (a false claimant is a liar to them), and double
  claims resolve by which worlds survive.
- **Debug overlay** (checkbox): each card's influence across the good NPCs who heard it;
  profiles show how the town credits and suspects the person. Turning it on marks the
  case's identification unscored.

### Town consensus: peer pressure, not a pile-on

A public accusation is a social signal, not evidence. Each accuser counts once (their
latest stance), by how much the listener trusts them; each further voice adds about half
the one before (base 0.09); accusations fade to 60% a day; the total is capped (0.22). A
hinted accusation weighs 1.15× a bare one. This **crowd pressure** is added to suspicion
only when an NPC decides to nominate or vote; it's kept out of the shared model, so a
crowd's opinion never moves belief or lowers anyone's credibility. A second accuser says "I agree with X about Y",
adding grounds only if they're their own.

### Citing reasons: provenance

Reasons come from the shared model's own attribution (`workshop/reason_attribution.gd`):
for each active suspect it scores the held evidence through the model's report tables,
role constraints, movement likelihoods, reading challenges and leave-one-out
contradictions. It runs only when a meeting or conversation first asks for a reason.
`MindMeeting.case_against` ranks those reasons, and `_visibility_maps` classifies each by
audience: **public** (the town has it, or citing it reveals nothing of their gift),
**player** (their own reading, told only to the player), **private** (told to nobody),
**relay** (someone else's private reading), and their shared variants. `citable_reason`
returns a reason only if the audience has it; meeting accusations, nominations, tavern
gossip, NPC-to-NPC shares and private opinions all go through it. A gift is never leaked
by a reason.

**Vague is the default for both alignments** ("something's off about them"), so neither
vagueness nor a stated reason is a tell. Good NPCs state a reason only when it's grounded
in something real; evil only when it's grounded in an active bluff.

**Accusation tiers** at the meeting: silent → generic ("I don't trust X") → **hint** ("I
have a reason, but I'm not ready to share it": a hint-marked card) → **reveal** (they
claim their gift and give the reading). Hint vs reveal weighs the reading's strength,
suspicion and confidence against the **reveal cost** (privacy, gifts that hide from the
demon or keep paying off, fear; falling as days pass and when four or fewer are left).
Evil with nothing citable hints 30% of the time (`C.EVIL_HINT_CHANCE`), so a hint isn't
proof of good.

**Following up:** "Ask why they suspect X". If they tell, it's full disclosure; if their
gift isn't public they ask you to keep it between you (the cards are marked confidential;
using one at the meeting costs 0.15 of their rapport, waived once they've gone public).
Declining and evil's stalling draw from the same lines.

**Relays:** a reading told to an NPC in private, not yet public, is passed on unnamed at
the meeting: "Word reached me from the Seer: …". The shared judge takes it as the teller's
testimony at reduced weight; a later "that was me" binds it to the named source, who steps
forward 5% of the time.

### Disclosure: the gift question

One question, four tiers, from Privacy, rapport, pressure and the day:
1. Refuses to say (denials are off: `C.ALLOW_NO_GIFT_DENIAL` **[knob]**; evil almost never
   bluffed it, so it was near-proof of good).
2. A **flavoured hint** pointing to a hint package.
3. Names the gift.
4. The gift and its readings.

- Good NPCs never fall back to a lower tier. If rapport drops after sharing, they withhold
  *new* readings and say so ("I've told you enough").
- **Caution tied to the gift:** Seer, Night Watch and other recurring readers lean quieter
  on days 1–2; start-knowledge gifts lean more open.
- **Fear as cover:** refusals sometimes say "If I say what I am, I'll be dead by morning",
  likelier as deaths mount and for the skittish (same odds for evil bluffers). The fearful
  may instead ask for your ward or vigil in exchange for their gift.
- **Public claims** have their own roll at each meeting (Privacy, day, pressure, gift
  kind; strongly up with four or fewer alive). Going public shares every unshared reading.

### Lying and night accounts

Reasons NPCs lie, always recorded (`think`, topic `lie`):
1. **Evil cover:** a bluff role whose readings come from that gift's bluff rule, framing
   the scapegoat and covering the team. Lies stay consistent and break only where the
   cover contradicts reality.
2. **Personal secrets:** a good NPC out at night for a secret lies about where they were
   (or confesses, or stonewalls: Privacy, rapport and pressure decide whether they
   confess; Confidence whether they lie or stonewall).
3. **Caution:** a good NPC with a high-value gift may hide it.
4. **Poisoned / Delusional / Sleepwalker:** not lies; honest reports of false information.

Asked where they were, an NPC with a disclosed walking gift names its duty (the watch
kept, the door guarded, the hearth visited); evil bluffing a walking gift does the same
from its bluff. A good NPC shown a sound "you lied" about their own statement knows it's
true: open or pressed ones own up, the rest stonewall. A good walker pressed with a
sighting, or disclosing a walking gift later, owns the earlier lie ("So yes: I was out…").
Seen out at night, the real Sleepwalker (under pressure) and evil bluffers can say "I've
been known to sleepwalk"; two claimants prove a liar.

### The town talks (NPC to NPC)

- Two NPCs pair off; each passes one item (an unshared reading, a confided secret, an
  opinion, a case the player made, a night sighting, hearsay, someone else's secret).
  Readings and sightings become receipts in the listener's evidence with who told whom,
  credited by trust in the teller and deduplicated by the underlying fact; opinions stay
  social.
- **Peer role gossip:** NPCs privately hint at their gift's family to friends (bond ≥
  0.55) or claim it outright (bond ≥ 0.68, or ≥ 0.55 under pressure), even with no
  readings; evil uses its agreed bluff with the same formulas. Claims are dated
  (`first_claimed_day`); gift talk isn't relayed peer to peer; no A→B→A echo. The player
  hears second-hand claims and hints through gossip, `ask about <role>` and opinions.
- Every belief records **who it was heard from**, so it can be traced and disowned.
- Evil feeds lies into the network through the same willingness formulas as good.
- **Gossips** relay what they've heard; **busybodies** approach the player, a main path to
  others' secrets. Even discreet townsfolk give an opinion when asked directly.

### Decided and tentative directions (NPC minds)

**[decided]**:
- **Backing a strong case builds trust** with NPCs who agree (what makes throwing a
  teammate under the bus pay for evil).
- **Lie severity** **[open]**: a false gift report weighs more than a whereabouts lie,
  unless the lie puts them near the crime; NPCs who accept a lie but won't hang should say
  so.
- **Ways to discover and confront secrets** (sightings that don't fit, confidants,
  personal items, a "you have a secret" card as leverage) **[open]**; **named
  corroborators** in alibis ("I was with Jory"), word-against-word cards **[open]**.
- **Situational credence modifiers** still to settle: early disclosure, quiet night as a
  credence boost, admission against interest, consistency over time, role-specific
  confirmations. **[open]**
- **Initial general skepticism** **[knob]**: only if the early game gets too decisive.
- **Trust dynamics around sources:** a relayer naming their source at a cost; evil tracing
  an unnamed source. **[open]**
- **NPC-to-NPC credibility:** split NPC-to-NPC trust into liking and believing, as the
  player's is. **[open]**
- **NPC memory and recency bias.** Attention-level recency is on main (#96; `docs/premises_plan.md`,
  "Recency as built"). **[open]**

**Social retuning** **[tentative]** (candidates for one unified retuning proposal; details
in BACKLOG): Privacy without compounding trust penalties; evidence building NPC-to-NPC
trust; diminishing trust changes near the extremes; opinion strength and shared origins;
Martyr urgency; Demon victims' earlier readings.

**Expanded dialogue and trust management** **[tentative]**: suggest general requests that
spread through town chats; responsibility and follow-through as small trust gains;
withdraw or revise a case; ask what would change their mind; explain an execution's
purpose (e.g. for a Gravedigger read); promise confidentiality.

---

## Evil

### Knowledge and coordination

- Evil knows its team, bluffs and a shared plan; the first night gives free shared
  knowledge.
- After that, evil knows only what a member **saw or was told**, plus what they pool when
  they meet (pairs you may see talking, a whisper in a crowded tavern, the meeting). It
  doesn't read hidden state (private suspicion, true night walkers, whom the player
  confided in). A ward or vigil the player promised an evil NPC becomes team intel.
- Evil's sense of public **heat** ignores its own team's accusations and readings.
- **Evil coordination you can see** (daytime meetups, with friends and Lovers meeting too
  as noise). **[open]**

### The shadow good self

Each evil NPC keeps a second, good mind (`n.shadow`) whose gift is its bluff. It runs the
normal good belief pipeline on what that NPC really heard, with its own random stream and
log, never in `w.npcs`. Plan and history: `docs/archive/shadow_self_plan.md`.

- **Secret acts stay on the evil brain:** kill, poison, breath, totem, intel, plan.
- **Public acts follow the shadow:** argument replies, private-case replies, opinions,
  nominations and votes, unless **`Mind.evil_override`** says break cover:
  **stakes − deviation × exposure > caution**.
  - **Stakes:** mostly a teammate's value (demon 2, minion 1; with a live Scion fallback,
    the Scion 1.45 above a replaceable Demon 1.1) × their danger or how pivotal the vote
    is, or the worth of pushing a good nominee (more for the scapegoat). In a landslide
    against a teammate, non-pivotal "no" votes carry little stake, so evil keeps cover.
  - **Exposure:** public talk about them, known player suspicion, pressure, being on the
    block.
  - **Caution:** the demon 0.8 falling 0.03 a day (floor 0.45); minions 0.7 falling 0.08 a
    day after day 2 (floor 0.25). Late in the game minions sow chaos.
  - Every decision is logged (`think`, topic `override`).
- Result: evil's replies differ from the good crowd's about twice as often as good's own
  disagreements (down from about five times), and evil sometimes votes with the town
  against a teammate (bus-throwing).
- `C.SHADOW_SELF` switches it off.

### Plan, scapegoat and bluffs

- **Scapegoat:** picked at setup (walkers the demon knows of, people it distrusts, public
  Warden/Veteran claimants favoured), then **re-picked each morning from day 2** on
  momentum (public heat + the good selves' suspicion), fit (fake readings and sightings
  already naming them), dead ends (public clears) and a switching cost. Evil rides
  mistaken town momentum: intentional, so the player's misdirection can matter.
- **Bluffs** cover every information gift. A Seer bluff never gives a "no" that covers the
  scapegoat and frames every night once five or fewer remain; a lone evil Seer bluffer
  never puts itself in its own pair. Each gift has its own bluff rule
  (`generate_bluff_reading`), built around the scapegoat and the team.
- An evil Gravedigger reporting on a hanged good person calls them a Minion more often the
  surer the town was, read from the hanging vote's yes share (the player's vote counts);
  otherwise it confirms their claim, or guesses a good role (#136; `Evil.GRAVEDIGGER_FRAME_*`).
- Evil bluffing a walking gift says their gift took them out when asked where they were;
  its invented sightings follow the window/route rule.

### Night choices

- **Kill choice:** threat (public info claims, a Seer extra, readings implicating evil,
  hostility), opportunity (lives alone), temperament, minus penalties (preserve the
  scapegoat while more than 4 live; spared by Clemency; previous failures; a door the
  player promised to ward or a block they promised to watch). Noise only matters between
  close candidates. A claimed start-knowledge gift spent after night 0 is worth less than
  one that keeps reporting. 3% of nights the demon skips its top three.
- **After a failed kill** with no visible cause (Warden, Veteran), the demon avoids that
  person and shies from high-profile targets for a couple of nights; anyone it glimpsed
  at the door becomes a likely Warden.
- **Poisoner sense:** skips gifts poisoning wouldn't stop tonight (judged from public
  claims); poisons a suspected Warden on nights the demon goes for someone prominent; can
  poison a claimed Veteran first so the kill lands.
- **Breathstealer** silences the most dangerous voice on its block.
- **On the block**, with no Scion fallback, the Demon backs any live counter-nomination
  (survival overrides cover) and may cast the vote that ties and clears its minion.

### Decided and open directions (evil)

- **Evil backs into a bluff:** an unclaimed evil NPC switches its planned bluff when
  another unclaimed gift would serve better (seen out at night → claim Night Watch).
  Needs double-claim logic; then fake Mediums and others can make bolder lies. **[decided]**
- **Throw a teammate under the bus** beyond what the override gives: a pressured minion
  distances itself; the demon goes along with town conclusions to build trust; deliberate
  Scion succession. Needs team utility, not just vote pivot. **[open]**
- **Evil's cover priorities:** arguing against a case on a teammate breaks cover while a
  vote that isn't close keeps it; words should be the cheap place to keep cover.
  **[decided]**
- **Evil reads as evil** (casting aspersions with no information; doubting sound
  deductions). Largely addressed by the shadow self. **[watch]**

---

## The town meeting

### How it runs now

1. **Testimony**, streamed speaker by speaker (`MindMeeting.testimony_step`): public
   claims (their own roll), readings, accusations through the accusation tiers. Silenced
   people say nothing. **Reactive testimony:** when a statement names someone, claims
   their gift, or touches a clearing reading they hold, that person moves up the queue
   (once per meeting each). **Fading into the crowd:** once claims pile up, private people
   bide their time.
2. **Floor:** the player may present one prepared case to everyone (once per meeting),
   judged by the shared model for each listener.
   - **Demon-type declaration** (`game/demon_declaration.gd`, #131): on a script that deals
     both a walking Demon and a Hexer, `declare walker` or `declare hexer` (once a day)
     tells the town which kind it faces. NPCs don't judge it: every view weighs the
     evidence as if it were true (`LiveActivity.day_demon_share`). The first declaration is
     free; each change costs every living NPC 0.1 credibility
     (`Trust.CRED_DECLARATION_CHANGE`) and stays in their dawn track-record target. A
     one-kind script starts declared.
3. **Nominations, one at a time.** BotC limits: each person nominates at most once and is
   nominated at most once per day. The player may `nominate`, or `wait` to let the town
   nominate; `done` closes the meeting once a `wait` finds nothing. A failed vote cools
   off renominating the same person the next day (less so late in the game).
   - **The player's nomination** rests on the **on-deck case**: the latest live filed case
     accusing that person. `#N` picks another filed case; `raw` (or having no case)
     nominates on the player's word at reduced credibility. A case not yet public is put
     to the town at the nomination. The menu shows each option before you confirm.
     Citing a case or card that's already public is free but adds nothing ("already
     public knowledge").
4. For each nomination:
   - **The nominator's case** (`MindMeeting.nomination_case`): up to two public reasons
     recapped (no ledger effect), and the strongest private reason hinted or revealed, or
     a relay.
   - **The defence** (`MindMeeting.defend_self`): one or two moves from the case against
     them: *reveal* a walking gift to excuse sightings; *confess* a secret (good only); the
     sleepwalk excuse; a good defender sighted only on nights they spent at home (framed)
     gives their account of that night instead (#134); against a reading, *red herring* (named in two+ shared Seer yeses),
     *pair_other*, *lying* (if confident) or *misled*; else a plea. Reveals, confessions
     and reading challenges enter listeners' ledgers as undoable claims and challenges;
     pleas and rival suggestions are speech. **Block safety:** while someone else is
     firmly on the block, defence reveals and confessions are damped. Evil uses its bluff
     and has no secret.
   - **The player's statement:** accuse or defend, optionally citing a card, or Clemency.
   - **The vote**, silent, in BotC order: clockwise from the seat after the nominee,
     nominee last. Each voter compares suspicion + town pressure + execution priority +
     the player's stance (scaled by credibility) + modifiers (relationship, a suspected
     nominator, a spare preference, a preference for whoever is already on the block, role
     reluctance) to a need: a base, lower for the confident, higher on Day 1, lower with
     paranoia and with each death. A nominator commits to their own nomination. Evil votes
     react to the running count.
5. **On the block:** reaching half the voters (rounded up, the player included) puts the
   nominee on the block. A later nomination with more votes replaces them; a tie at the
   highest count clears the block.
6. Whoever is on the block at the end is executed, with **last words** at the gallows. A
   Martyr may die in their place.

**Meeting circle** (`ui/meeting_view.gd`): the living townsfolk's standees in a ring on the
Square (you at the bottom, a candle for your seat), the nominee's portrait in the centre,
nominee framed red and nominator gold. A gold hand sweeps clockwise counting votes: yes
voters step in with a numbered red token, no voters grey out; a tally shows the count
against the threshold, then the outcome. A vote starting brings the circle back from the
map.

**Dead NPCs:** no ghost votes. Keep the door open to the dead affecting the game, e.g. a
final-day **Séance** vote. **[watch]**

### Decided: the meeting as a trial (`docs/meeting_flow_plan.md`) **[decided]**

Target per nomination: the nominator's case → the nominee's defence → **podium press**
(the player challenges the defence on its role, its night or a card; M2b) →
**supporters** (M2c) → **the player's turn** (M2d) → the vote, with selective resistance
lines → last words.

- **Supporters:** each bystander decides for themselves, in seat order, whether to speak,
  weighing how sure they are the nominee is good, what the nominee's role is still worth,
  what speaking costs them (exposure, the value of their own unspent gift) and how much
  danger the nominee is actually in, re-read after every supporter. This includes
  **outing yourself to defend someone** (a Seer "no", a Night Watch who saw them stay in).
  A cap limits how many speak; there's no director picking a minimal set.
- **Resistance lines:** a voter who accepted the case and still votes no says why
  (preferring whoever is on the block, distrusting the nominator, reluctance, short of
  rope); evil voters use the same phrasing.
- **VN courtroom** (M3a): the 15-cast expression portraits staged over the seat ring.
- **Measure and write up** (M4): the bot drives the trial, then 150-seed sweeps at both
  sizes (good win rate, hidden night-walker hang rate, pacing).
- Settled: recapping old evidence has zero impact; new evidence in a case has exactly the
  impact it would have at any other time; revealing concrete information lowers suspicion
  most but goes through normal credibility; other defences sway little.

**Open issues from defence moves:** evil gains more from defences than good (its
"misled"/"lying" answers to real readings and its bluff reveals cost good ~11 wins in 150
at 10 townsfolk, measured Oct 19 on the legacy rules); the defence barely changes how
often good night walkers hang, because their nominations mostly aren't built on
sightings. Re-measure under the shared model.

**Urgency and paranoia:** NPCs grow readier to execute late ("we must hang someone"); tune
paranoia and urgency together so the last days don't become random lynchings. Good NPCs
creating a final-day tie is left as is (social dynamics as intended). **[watch]**

---

## The town screen and presentation

- **New Case screen** (`ui/new_case_screen.gd`): opens at launch and from More ▸ New case:
  town population → script (Default / Load / Custom, with the script editor) → Start.
  Headless runs and `--quick-start` skip it.
- **Title bar:** sun or moon, day and phase, Town / Case board / Notes / Roles / Help, case
  seed, New case, More ▾ (text cast and timeline, card sidebar, dev log), Debug (and Rolls,
  the live decision inspector).
- **Town screen:** the painted map (top left), the townsfolk list (portrait, colour, claim
  icon, your pencilled guess, "at <location>" when visible; dead greyed), the compact
  profile; actions with a context line beside the log at the bottom. Every menu has a
  Close button. **Case notes** and **Roles** (every gift on the script, its icon and who
  has claimed it) are movable windows from either screen.
- **Painted map** (`ui/map_view.gd`): painted block bases, building sprites with signs
  (the Town Hall third on the Square), each townsperson's own cottage (the owner's colour at the
  door where there's no art; crossed out as crime scenes), roads with lamps, paper standees (busy ones marked, your
  conversation partner framed gold), night tint, zoom to a block. Clicking a townsfolk row
  highlights their home, workplace, visible icon and known haunts. Block areas, streets, signs,
  lots and cottage spots live in the editable scene `ui/map_layout/map_layout.tscn`.
- **Daytime conversations** (`ui/day_conversation_view.gd`): a visual-novel view with the
  speaker's portrait in five expressions (neutral, warm, harsh, concerned, sorrowful) and
  paced lines. Talks and searches in a building or the Town Hall sit in its interior; homes and
  crime scenes keep the blurred map.
- **Headline notices** (`ui/headline_overlay.gd`): dawn, nightfall, deaths, nominations,
  executions, curses, burned totems and the end of the case, shown one at a time over the
  game; a click skips.
- **Shared profile** (`ui/profile_panel.gd`), on both screens: portrait, name in their ink,
  occupation and status, their claim with its icon ("Claims: Night Watch (to the town)" /
  "told you privately" / "Hinted at a night-sight gift"), trait bars, and **Your guesses**
  in red pencil (a role and a secret, each with a confidence: Flimsy / Maybe / Likely /
  Confirmed). Tabs: About, Their claims, About them; each entry links to its card. Profile
  receipts can be sent to the Workshop from here.
- **The log:** speaker portraits on speech lines, day headers, a raven on deaths, a card
  icon on new cards; card numbers open the card on the board.
- **Shared text system** (`ui/text_terms.gd`, `ui/text_formatter.gd`,
  `ui/rich_text_renderer.gd`): names and roles bold in their colours (good roles a reserved
  blue, evil a reserved red, ink variants on parchment), role icons and tooltips inline,
  light-ink icon variants on dark surfaces. Built for the log and profiles; cards are
  deferred (above).
- **Papercraft skin** through one theme (`ui/theme.gd`): navy board, cream plaques, gold
  edges, framed paper, serif type; art sliced by `tools/slice_sheets.py`.
- **Dialogue composer** (`sim/dialogue.gd`, `sim/dialogue_voices.gd`,
  `sim/dialogue_presentations.gd`): presentation only. The simulation decides what is said
  (including evil's fabrications); the composer words it in a character's voice. It never
  sees world state or truth and draws no game RNG. All fifteen characters have voice packs;
  every voiced line keeps a canonical statement. Workshop: `ui/dialogue_lab.tscn`. Rules:
  `docs/DIALOGUE_DESIGN.md`.
- **Talking to a group** (3 questions split among anyone at the spot). **[open]**

---

## Outcome tracking and scoring

- **Private theory:** profile guesses form a timestamped revision history, with copies
  frozen before votes, executions and nights. The latest pre-outcome copy is scored at the
  end; abandoned earlier guesses are kept but don't count. One candidate per evil identity.
  Opening a debug grimoire (or the debug overlay) disqualifies identification credit.
- **Results** distinguish identifying the demon, identifying a minion, saving the town and
  preserving good townsfolk. "Identified but lost" is descriptive partial credit.
- **Executions** log nomination, votes and explicit statements; the player's stance is
  `backed`, `opposed` or `mixed`. Earlier arguments aren't assigned causal responsibility.
- **`case_summary`** (`game/case_metrics.gd`, schema 2) adds `loss_hint`
  (`identified_not_persuaded`, `evidence_on_board`, `evidence_reachable`, `no_evidence`),
  night stats (kills, blocked kills, Warden stats), the execution list and good survival.
  The ending lists evidence that pointed at the demon.
- **Scoring system** (identification credit, guess accuracy with confidence, why the
  player lost) **[open]**.
- **Why did the player lose?** Classify in playtests: wrong interpretation, missed
  accessible information, information never available, or failure to persuade. The logs
  can classify the first three; persuasion failures need the player's notes.

### Balance target **[decided]** (Nov 5)

A single-player game shouldn't sit at live BotC's ~50%: that would feel arbitrary. A
skilled player shouldn't win every case either. The point of playing good is "was the
world I theorised correct?", and the grimoire reveal is part of the payoff.

- **A skilled player names the Demon in 85–90% of cases and wins 70–75%.** That makes
  "won, given they named the Demon" about 80–85%. The rest are "I knew and couldn't get
  the votes" losses, which are the good kind.
- **Evil steering the town is a feature.** Coordination, misdirection and the town's
  wrong hangings are what make up for evil being outnumbered. Good NPCs shouldn't be so
  accurate that the player can ride along. What matters is that the steering is
  **visible**: a sharp player can see who pushed a wrongful hang.
- **Arbitrary losses are bugs:** deals where no amount of reasoning finds the Demon, or a
  bluff that can't be broken (the walking-gift bluffs in the Nov 5 sweep).
- **Measuring against it:**
  - the analyst bot is the floor;
  - an oracle bot (knows the grimoire, plays only legal moves with real evidence) is the
    ceiling the town and evil allow (`docs/oracle_sweep_plan.md`);
  - logged human playtests sit between the two.
  - Sweeps report identification rate, win rate and win-given-identified against the
    target.
- Nov 5 sweep, analyst bot at insight 1.0: names the Demon 72%, wins 53–55%, wins
  67–72% once it has named the Demon.

## Dev logging (required)

Every event goes to a JSONL log plus a readable transcript: world events, NPC reasoning
(claims, lies, votes, kill/poison scores, shared-model refreshes and deliveries,
overrides), suspicion and trust changes with causes, per-phase snapshots (including
shadows), and hidden state. With detailed logging on, a `.trace.jsonl` sidecar records
state changes for the case history viewer (`tools/case_viewer.py`,
`docs/case_viewer.md`). Entry types and filters: README "Dev log"; `tools/trace.py`.

## Logic depth

- **The judge is exact, the judging is personal.** The shared model enumerates every
  world consistent with the setup, but each listener weighs the evidence through their
  own prior, trust, attention, own readings and Confidence. NPCs judge the player's case;
  they don't search for theories, so they must not out-deduce the player.
- **Explainable:** every judgement can be traced (`workshop_*` entries in the trace
  sidecar, `suspicion` entries in the dev log, the decision inspector for rolls).
- **Storyteller director** **[open]**: poisoned readings become arbitrary (plausible,
  sometimes coinciding with the truth) rather than always wrong. Today poison makes a
  reading wrong, which a player can invert (playtest 90028). Medium visits chosen by the
  director ("I was called to Hollis's home"). Solvability check, using the same world
  enumeration.
- Main risks: hidden state that multiplies the world count (see the cost model), and
  tuning sprawl. Keep the conclusion vocabulary small and weights in data
  (`sim/tuning.gd`).

## Teaching

- General rules over special cases ("gifts that choose a place send you out at night"; "a
  demon kill is strong evidence, not proof").
- A tutorial case on a fixed seed, later, once mechanics settle.

## Tech and testing

- **Godot 4.7.2 (.NET).** The simulation core (`sim/`) is pure logic, separate from
  presentation, deterministic from a seed, runnable headless. `game/game.gd` is the command
  interpreter and state container; domain logic lives in `game/game_conversation.gd`,
  `game_meeting.gd`, `game_day_night.gd`, `game_screens.gd`, `game_board.gd` and
  `game_presentation.gd` behind one-line forwarders. It emits structured events rendered
  as text. The CLI, the in-engine UI and the bot share one command interpreter.
- **Solver backend:** the shared model's numerical kernel runs in C# (`workshop/cs/`,
  built with `dotnet build Demonologist.csproj`), the only solver since Nov 4. Rebuild C#
  after switching branches.
- **Golden capture** (`tools/golden_capture.gd`, `tools/golden_diff.py`,
  `docs/golden_baseline.md`): fixed seeds captured and diffed against the
  CI baseline at `--tol 0`. A sim-neutral change must be identical; a behaviour change
  re-records the baseline.
- **Autoplay bot** (`tools/autoplay.gd`): plays through the same commands a human uses and
  sees only what a player sees. `--passive` is the control (does nothing). Without it the
  player is the **analyst bot** (`tools/analyst.gd`): a neutral juror reads the board
  through the shared model, ranks suspects, builds Workshop cases greedily, nominates and
  votes. `--insight F` makes it miss a share of cards. `--results` +
  `tools/compare_runs.py` pair seeds.
- **Bot gaps** **[decided]**: the bot doesn't offer wards or vigils, ask about others for
  haunts, choose where to search for drops, or find totems. Since M4 it presses nominees
  at the podium; `--pre-m4` keeps the earlier policy for A/Bs.
- **Tests:** `python3 tools/run_gd_tests.py --godot <exe>` runs every suite and checks
  failure text (some scripts exit 0 on failure); `tools/ci_fast_suites.txt` is the PR
  list.
- **Speed:** `tools/replay_54875.gd` (opening timings and a profile), a late-game probe
  (seed 42, Days 3–4) and `tools/profile_c0.gd` (solver stage timers).

---

## Roadmap

A suggested reading of BACKLOG, not a settled plan:

1. **Measure:** the overnight balance sweep on dynamic scripts (win rates by role, demon
   and minion type, solvability, pace), then a paired baseline before more tuning.
2. **Meeting plan M4:** the sweep. Supporters, the player's turn and resistance lines, the
   VN courtroom and the bot policy are built.
3. **The premise matters.**
4. **The balance pass:** decisive night sightings and the vigil, evil sometimes telling
   the truth, the agreement-to-vote gap, Privacy and the first day.
5. **Speed:** re-measure under the C# backend.
6. Medium features marked [decided]: evil backs into bluffs, backing a strong case builds
   trust, Revenant seeks execution, NPCs find evidence, bot coverage; the script
   follow-ups (off-script tell, more demon types).

Larger open areas: evidence chains, the Breathstealer decision, relationships, roster
expansion (new evidence types must be costed against the judge), the player toolbox, the
director, scoring, procedural and larger towns.

## Open questions

- Is unlimited Vigil too strong? (One well-placed vigil plus an Archivist pair won a case
  on day 3.)
- How many clues per day feel right (1 vs 2 player actions per phase)?
- Persuasion economy beyond trust (how pressure sours NPCs).
- Keep the 7-person town until the core loop reliably works: form a hypothesis, choose an
  investigation that tests it, revise, make a consequential argument.
- Does the Lamplighter's every-block route make the gift too easy to confirm, now that
  nobody else passes through a block?

---

## History and measurements

Condensed from the dated build notes. Bot numbers are good wins out of 150 games, seeds
1000–1149 unless noted; "passive" is the do-nothing control.

**Rollout stages** (all built): 1. foundation (structured events, traits, schedules, the
gift question, trust, BotC nominations, toolbox); 2. the town talks (NPC conversations,
provenance, evil coordination, approaches, pressure and paranoia); 3. the case board
(conclusions, templates, evidence classes, diminishing returns); 4. full UI (map, board,
profiles, then the papercraft skin, painted map, meeting circle and full-screen board);
5. geography and confrontation, partly (roads, drops, causal traces, press, the walking
Warden; named alibis and Framer planting remain).

**Early playtests (3 cases, 2 players; then 90028):** gradual reveal works; wasted actions
searching empty places (fixed by day visibility); players expect evidence chains (open);
players read social patterns that were coincidence (open: visible evil coordination); evil
is the most forthcoming (a player-led nomination of the true Seer passed 7/8: now the
supporters step of the meeting plan); vigil is strong; poison as inversion (director
item); players want to cite cards in meeting statements (built).

**Playtest 13473** (10 townsfolk): led to homes spread evenly, Insight-scaled Seer picks,
withholding cards, fake Surveyor variety, benched flavour secrets, overlap and group
elimination templates, Scion-safe deductions, habitual haunts, unseen counts.

**Oct 18:** all roads joined; off-route replaced the night two-places template; the talk
rework (timeframe questions, offers, learned haunts); corroboration between cards; filing
vs weighing; new statuses; NPCs owning their lies; fear as cover; a vigil deterrent tried
and removed; quick fixes (Medium hearths, Warden doors, Martyr reluctance, the demon's 3%
unpredictable night, "night 0" wording).

**Oct 19:** shadow good self; citing reasons, accusation tiers, hints and follow-up;
Mediums' shared menu; readings before the kill; meeting flow steps 1–2 and relays;
full-screen case board, filters, right-click menus; social bars; recent sightings and
firsthand work sightings; shared text system steps 1–3.

**Oct 20:** TUNING.md audit; tentative social retuning and dialogue ideas; text-system
handoff (card extension deferred); playtest 61251 notes; cases-instead-of-proofs decision.

**Oct 21–23:** playtest 61251/25923 fixes landed; the Case Workshop experiments and the
case-reasoning plan; the exact possible-worlds evaluator (`CaseEval`) replaced template
proofs for presentations.

**Oct 23–25:** the legacy migration (card adapters, fallback logging), then a deliberate
hybrid: shared judge for evidence, native social sim. Soft testimony ended "impossible"
belief refreshes; meeting refreshes were queued. Role-check fixes took a late-game
meeting entry from 95 s to 6.5 s. Playtest 22485: the town executed the Demon on Day 2.

**Oct 26:** Codex batch 3 and a Claude batch: headline notices, the sleepwalk excuse,
"doubt the report instead", Workshop feedback (clash headline, collateral, idle
assumptions), the streamed meeting.

**Oct 27–30:** role definitions (`sim/role_def.gd`, `sim/roles/`); the Seer's red herring
as an exact weight; `sim/tuning.gd` as the single home for numbers (TUNING.md replaced by
`tuning_catalogue.md`); Codex batch 4 (23 items, volunteered night sightings at meetings);
the live decision inspector; destination-only vigils; nomination and evil tuning; the
evidence rework (profile receipts, 3:1 token and scent traces, second traces, the
circumstantial hub); all 15 voice packs; the social trust pass (rapport and credibility,
directional Confidence, Warden credit); the listener prior changed from reading suspicion
as a probability to exp(1.5 × suspicion).

**Nov 1–3:** the legacy belief system retired in phases (`sim/deduction.gd` split out; the
shared model takes over reasons, defences and doubt; legacy effects, the switch and the
fallback removed; `sim/argue.gd`, the link templates and `link` / `conclude` deleted); the
analyst bot; dialogue batches 5–7 (voiced presentations, greetings, the last `[PH]`
lines); the C# solver kernel (slices C0–C3); `game.gd` split into four helpers; the
golden capture in CI.

**Nov 3–4:** the Tavern's evening gossip and the Town Hall; scripts, the script editor and
the New Case screen; five new town gifts (Augur, Chronicler, Executor, Magistrate,
Registrar), the Surveyor rework and the public-only Dowser; meeting plan M1 (peer role
gossip) and M2a (player nominations on a case, reactive testimony, crowd fading, block
safety); Nov 4 playtest fixes (evil aware of your promises, Scion-aware cover).

**Bot baselines over time** (legacy rules, active vs passive where measured):

| Change | 7 townsfolk | 10 townsfolk |
|---|---|---|
| First measurement (7 only) | 33% vs 16% | – |
| Consensus cap, visibility, window-only sightings (300 seeds) | 99/300 vs 47/300 | – |
| New roster, secrets, two sizes | 57 vs 18 | 43 vs 15 |
| Death-tied night suspicion, Sleepwalker 50% | 55 vs 14 | 40 vs 17 |
| Playtest 13473 fixes | 61 vs 12 | 38 vs 13 |
| 13473 follow-up pass | 58 vs 11 | 42 vs 16 |
| Vigil deterrent removed, ask by timeframe (Oct 18) | 41 vs 8 | – |
| Citing reasons / accusation tiers (before → after) | 43 → 44 | 35 → 39 |
| Shadow self, step 5 (off → on) | 57 → 50 | 41 → 43 |
| Readings before the kill (300 seeds, 2000–2299) | 106 → 111 /300 | 87 → 95 /300 |
| Meeting flow step 1 (nominator's case) | 49 → 54 | 37 → 37 |
| Meeting flow step 2 (defence moves) | 53 → 49 | 37 → 26 |

**Since the purge** (seeds 2000–2011, C# backend; 12 seeds is noisy, one game is 8
points; `docs/handoff_log.md` Nov 3):

| Setup | 7 townsfolk | 10 townsfolk |
|---|---|---|
| Passive | 4/12 | 2/12 |
| Analyst bot, insight 0.6 | 5/12 | 3/12 |
| Analyst bot | 7/12 | 6/12 |

Passive runs moved a lot with each later change (M1, chunk 2/3 roles, M2a's reactive
testimony); the overnight sweep is meant to settle them.

Other measured effects worth keeping:
- **Death-tied night suspicion** (10 townsfolk): Lamplighters hanged 57% → 43%, Veterans
  49% → 33%, Sleepwalkers 58% → 40%; Wardens unchanged (48%). Most remaining walker
  hangings follow the bot's nominations after the walker hid its gift.
- **Insight-scaled Seer picks** (10 townsfolk, demon in the pair): night 1 41% → 30%,
  night 3 62% → 43% (random 24% / 34%).
- **Flavour secrets benched:** innocent night walkers per night 1.01 → 0.89 (7) and
  1.47 → 1.13 (10).
- **Habit strength:** at 60% of idle hours the bot found fewer people and won ~8 points
  less at 7 townsfolk; 40% is back to baseline.
- **Shadow self:** evil "off the crowd" 82% → 34% (7) and 69% → 29% (10), against good's
  13–15%.
- **Readings before the kill:** a Medium finds an untold reading at a demon victim's
  hearth 28% → 41% (7) and 23% → 32% (10).
- **Outcome tracking validation** (pre-roster): active 53/150 vs passive 25/150; demon
  identified in 84/150, both identities in 29/150, 36 identified-but-lost.

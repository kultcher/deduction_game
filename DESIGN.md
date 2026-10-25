# Working title: Demonologist (single-player social deduction)

Status (Oct 25, 2026): playable Godot prototype with a painted town screen, a case board,
a red-string Case Workshop judged by a shared possible-worlds model, and a deep NPC social
simulation; text CLI and autoplay bot alongside. This document describes
**how the game works now** and **which directions are decided**. It is organised by
system, not by date; the dated build notes it used to hold are condensed into
[History](#history-and-measurements) at the end.

**Tags.** Untagged text in a system section = built and current. **[decided]** = direction
agreed, not built yet. **[tentative]** = a proposal awaiting design or tuning review.
**[open]** = path not chosen. **[watch]** = no change planned, keep an eye on it.
**[knob]** = a lever kept for balancing, not planned.

**Companion documents**
- `BACKLOG.md`: the to-do list, by effort, plus the template-gap list. The single place
  for "what's next".
- `TUNING.md`: audited formulas, thresholds and numbers for the social model (trust,
  suspicion, persuasion, disclosure, votes, evil cover), with known feedback loops. This
  doc gives the shape; TUNING gives the numbers. **TUNING predates the shared judge** (Oct
  20): its evidence and argument numbers describe the legacy rules. It is updated after
  the balance pass.
- `docs/LEGACY_MIGRATION.md`: the shared judge and the native social sim, the decisions,
  architecture rules and lessons. Read before touching `workshop/` or belief code.
  `docs/MIGRATION_PROGRESS.md` holds the history and measurements;
  `docs/MECHANICS_SUPPORT.md` the evidence-coverage work (done Oct 25).
- `docs/BACKLOG_PREPARATION.md`: a code map and dependency order for working the backlog.
- `role_exploration.md`: role ideas, On Deck gifts, relationships, exploratory places.
- `docs/meeting_flow_plan.md`, `docs/shadow_self_plan.md`: step-by-step plans for the
  meeting trial and evil's good self.
- `docs/text_formatting.md`, `docs/text_system_handoff.md`: the shared text system (card
  extension deferred).
- `docs/dialogue_prototype.md`: the dialogue composer and lab.

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
- **Case:** one town. Two sizes, picked beside the case seed:
  - **7 townsfolk:** 5 good (one carries the secret), 1 minion, the demon. 6 days.
  - **10 townsfolk:** 7 good (one carries the secret), 2 minions, the demon. 8 days.
  - Larger towns (12–15) only once the core loop works at 7/10. **[watch]**
- **Win:** the demon's host is executed. **Lose:** only two townsfolk remain, or the last
  day ends.
- **Cast pool (15):** persistent characters with fixed personalities (trait baselines in
  `sim/content.gd`, listed in TUNING §1) who are dealt different occupations and roles each
  case, or sit it out. Personality must never predict alignment. Agnes, Bartholomew,
  Constance, Dorian, Edda, Fenwick, Greta, Hollis, Isolde, Jory, Kiran, Lian, Merrin,
  Nisha, Odette; each has a portrait, a standee and an ink colour.

## Time

- Each day: **3 day phases (Morning, Afternoon, Evening) and a Night**.
- The player gets **one action per phase**.
- End of Evening: **town meeting**.
- Night: evil acts, gifts fire, the player takes one night action.
- **Night order:** walkers are placed, then readings, then the demon's kill
  (`C.INFO_BEFORE_KILL`, true; false gives BotC's kill-first order). Our dead can't speak,
  so a victim's last reading only reaches the town through a Medium. A night is one
  instant; timing within it isn't modelled.
- Night 0 is "the night before you arrived" in all player-facing text. The demon kills
  from night 1.

---

## World

### Blocks, places, homes, roads

- The town has **four blocks** (the Square, the Market, the Docks, Chapel Hill); each holds
  1–2 **locations**. Testimony and evidence usually point to blocks, not exact locations.
- Each block has a **home material** (straw, forge soot, river mud, chalk dust) that shows
  up in traces and drops.
- NPCs have **homes** (spread evenly: 10 townsfolk 3/3/2/2, 7 townsfolk 2/2/2/1) and
  **occupations** tied to a workplace. Where everyone lives is common knowledge: each case
  opens with a "lives on" card per resident.
- **Every block has a road to every other** (since Oct 18). A night walker goes home →
  destination, so they're seen only on their home block (leaving) or where they went.
  The Lamplighter is the exception: the lamp route passes every block.
- Occupation and gift are independent for now. Occupations should eventually correlate
  loosely with gifts, for believable bluffs. **[open]**
- **Procedural town** (blocks, buildings and roads generated per case). **[open]**

### Schedules and visibility by day

- Each NPC has **at least one work slot**, known to the player; they can always be found
  and talked to at work then. Free slots are flexible and unannounced; deviation is
  normal, so absence alone is not damning.
- **Haunts:** each person has two favourite idle spots (40% of idle hours). Nobody's haunts
  are known at the start; asking someone about a person may reveal one or both (a "haunt"
  card). Profiles, the map and the "can't see them" hint use only learned haunts.
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
  **tentative** (hollow markers, with source). Observations aren't joined into an implied
  route.

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
  are out about 5% of nights with no walking gift, about always on a walking-gift duty,
  and about 55% with a night secret; minions about 25%; the Demon goes to the victim's
  home on kill nights, with a 5% chance of a detour, so being seen elsewhere argues
  strongly but not absolutely against being the killer. Scattered sightings can
  corroborate a walking-gift claim; previews and replies name both relationships. The
  legacy rule (×1.0 on the death block, ×0.12 elsewhere, discounted for claimed walkers;
  TUNING §3) remains only for evidence the native rules still own.

### Physical evidence

- **Death-scene trace:** points to the block where the killer **spent the evening**. It's
  misleading only for a cause: another walker passed the cottage that night (40% then),
  leaving traces from *their* evening. The grimoire says who and why. The victim's own walk
  can't supply it.
- **Drops:** each walker may drop something on their route (demon 35%, others 15%): a
  home-block material (88%) or a personal item (12%). `search` finds everything dropped at
  a location. A personal item becomes a night "out" card for its owner; a material links
  with a resident's home alibi (`dropped_vs_home`).
- Owner-identifying items stay rare (later plantable by a Framer). Category traces are
  common.
- **Known issue: evening shifts.** A demon who works an evening shift has a publicly
  known evening block, so traces converge on their workplace. Fix lives in the night
  movement package below.

### Decided and open directions (world)

- **Night movement and trace model** (one package, **[open]**): the night-proximity rule
  for sightings (count sightings on the route from home to the death block); a route
  limit (home → at most one detour → victim); traces from where the killer *started*
  rather than their evening block (fixes evening shifts). With every block joined,
  "passing vs. stopping" mostly collapses into "seen on own block" vs "seen elsewhere".
  Once settled, check whether home and haunt cards still earn their place. The
  evidence-chain item and the watchtower idea depend on this package.
- **Passing through vs. stopping** as sighting wording ("heading toward the Docks" vs "out
  on the Docks"). **[open]**
- **Locations as evidence:** a Dowser reading places the Dowser and group on a block but
  isn't a location card; your own visit could prove who *wasn't* at a spot. **[open]**
- **Evidence chains:** a trace leads to a second clue at the killer's evening spot. Players
  expect this (playtest 1). **[open]**
- **NPCs find evidence and personal items.** **[decided]**

---

## Roles: the script

Data in `sim/content.gd`. What each reading *says* in general terms (who it points at, who
it speaks for, who it names) lives in `sim/gifts.gd`, so reasoning (NPCs, templates, the
bot) keys off a few reading shapes rather than particular gifts. Every role and secret has
an icon (`assets/ui/roles/<id>.png`). The script window opens when a case begins.

**Setup.** Roles are drawn with no duplicates and a little protection: at least two
start-knowledge gifts (Archivist, Clerk, Surveyor, Rumormonger) and at least one strong
identifier (Seer, Dowser, Gravedigger).

### Good gifts (15)

| Gift | Ability |
|---|---|
| Archivist | Starts knowing that one of two people is a particular minion. |
| Clerk | Starts knowing that one of two people holds a particular gift. |
| Dowser | The first time each day they're on a block with 2+ others (home counts as the home block), learns how many of those are evil. A day reading, shared with its time. |
| Gravedigger | Each night after an execution, learns the hanged person's true role. |
| Lamplighter | Each night walks the lamp route through every block (so is out, and can be seen) and learns how many others were out. |
| Martyr | Once per case, secretly chooses someone they trust (trust ≥ 0.62, minus suspicion; never night 0). If that person is later executed while good, the Martyr dies in their place: both proven good to everyone. If the chosen is hanged and the Martyr lives, the Martyr learns they were evil. Doesn't cover demon kills. A poisoned Martyr's save fails. Reluctant to vote to hang their chosen. |
| Medium | Each night visits the hearth of the most recent dead not yet visited (demon victims first) and learns one thing they knew but never said in public (see Mediums below). |
| Night Watch | Each night watches a block; learns who passed through it. Is out on that block. |
| Psychologist | Each night picks someone they talked with that day and learns whom they trust and suspect most. Evil mostly name a teammate as most trusted and their scapegoat as most suspected. Gets a nudge to seek conversations. |
| Rumormonger | Starts knowing that one of two people carries a particular secret (two, not one: secret-holders are good, so one name would clear them). |
| Seer | Each night picks two people; learns if either is the demon. One good soul reads falsely as the demon (the red herring), and a Marked soul may. Picks scale with Insight (sharp Seers re-check suspects and pair them with someone unchecked). |
| Sexton | Once per case, with fewer than five alive, may toll the death knell in the evening. That night no gift that walks abroad works: the demon's kill, the Poisoner, Warden, Night Watch, Medium, Lamplighter. Secrets still walk. The toll is public; the ringer isn't named. A poisoned Sexton tolls for nothing. |
| Surveyor | Starts knowing how many of the four blocks have an evil resident. |
| Veteran | The first attack fails; they learn the last block the attacker came through (their own if the demon lives there). A second attack kills. |
| Warden | Each night guards one other person's door against the demon. Stands at the door, so can be seen, framed and hunted. |

**Hint packages** (each gift sits in at least one package of 2+, so a hint is never a full
reveal): official business (Archivist, Clerk, Surveyor, Rumormonger); night sight (Seer,
Night Watch, Lamplighter); the dead (Gravedigger, Medium, Sexton, Martyr); shelter (Warden,
Veteran, Martyr); reading people (Dowser, Psychologist, Rumormonger). Keep packages in mind
when adding roles.

Benched: **Hearthwitch** (learns how many living lane-neighbours are evil; kept in code,
out of the script).

### Evil

- **Demon:** kills each night from night 1. Rolls a **temperament** per case that only
  touches kill choice: *vengeful* (+1.5 on anyone it trusts below 0.4), *cunning* (+1.5 on
  the scapegoat's block), *hungry* (random 0–2.0 per person per night).
- **Minions:**

| Minion | Ability |
|---|---|
| Poisoner | Each night poisons one person: their gift fails or lies until the next night. Out at night. With no Poisoner in play the demon is the only evil out at night. |
| Breathstealer | Once a day (any day phase, likelier later), silences someone on the same block, wherever they are on it. It must be out, not at home. The silence takes hold at that evening's meeting and lasts until the next evening. The silenced can't claim, testify, accuse, nominate, defend, talk with you or chat with NPCs; they can still vote. Never the same person twice running. Picks the most dangerous voice. |
| Revenant | Hides a totem at a location it visits, on any day that began with no totem in play. If hanged with a totem hidden (and not poisoned), a random good yes-voter turns evil; the town is warned. `search` at the totem's location burns it (it's caked with the Revenant's home material, a lead). Found before the hanging: no curse. Found after: the turned soul is good again. Teammates often vote to let a Revenant with a totem hang. |
| Scion | If the demon is executed while five or more are alive, the Scion becomes the demon (no double kill). |

- Evil NPCs know each other and receive bluffs (good roles not in play, at least one more
  than the evil team's size).
- A demon kill is **strong but not certain** evidence of goodness: future demons may kill
  their own minion. Rules text must not promise otherwise.
- The demon cannot target the player. **(prototype)**

### Secrets (modifiers)

One per case, laid on a good townsfolk on top of their gift (the Lovers affect two but
count as one):

| Secret | Effect |
|---|---|
| Delusional | Their gift doesn't work and gives arbitrary information (they don't know). Protective gifts fail too. |
| Marked | Each gift that reads them sees them as evil (Dowser, Surveyor, Martyr) or the demon (Seer) half the time; a Gravedigger sees a random evil role 30% of the time. |
| Secret Lovers | Meet at a random block each night (both out), trust each other, know each other's secret, hide it like any secret (may confess). |
| Sleepwalker | Leaves home on about half of nights to a random block without knowing it: honestly says they were home, sees nothing while out. |

Lovers and the Sleepwalker are never dealt to holders of a night-walking gift, so a
claimed walker's own duty never has to explain a second reason to be out.

The older personal night-outs (insomnia, smuggling, debt) are benched
(`C.USE_FLAVOR_SECRETS = false`): with modifiers in play they put too many innocents out.

### The turned (Revenant's curse)

They keep their gift and keep claiming it; from then on their readings are fabricated the
way evil bluffs are. They know the team and the team knows them. When the totem burns
they're good again, remember nothing of who else was evil, and disown what they said while
turned. Other NPCs still hold what they heard; nobody knows who was turned.

### How the town reads the special events

Someone silenced gets a small credit with everyone (evil wanted them quiet); a curse makes
every good yes-voter on the Revenant a little suspect; a Martyr's sacrifice proves both
good; a Veteran's "came by way of X" nudges suspicion toward X's residents; a
Psychologist's reading rubs a little suspicion between a suspect and whom they trust most;
the Rumormonger's pair is mildly cleared; a Medium's report counts at 0.6 of hearing it
from the dead; a quiet night credits a Warden or Veteran claimant. Values in TUNING §3, §11.

### Mediums: one menu for real and fake

The shared judge reads a Medium's report as a relay of the dead person's original
evidence: dated to the original night and source, never an independent second origin.
Without a supported original it is the teller's testimony at reduced weight.

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
about half the time. Each dead visited once, most recent first. Both name the hearth
("Communing with the dead at Dorian's hearth").

### Roster directions

- **Roster expansion** **[open]**: On Deck gifts (Tracker, Clairvoyant, Beckon,
  Tallyman…); minions (Framer/Forger with evidence planting, Blackmailer, Hexer, Informant);
  Debtor secret. Each needs a hint package and template coverage.
- **Relationships** (Bonded, Unrequited, Feuding, Hater) and Lovers relationship mods.
  **[open]**
- **Lovers downside:** when one dies, the other withdraws (Privacy max, Gossip min, plus
  whichever shift hurts the player most, e.g. Composure up). Visible. **[decided]**
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
- **Search** the location: crime scenes give the trace; anywhere can turn up drops or a
  totem.
- **Gossip** (tavern only): overhear a rumour, with its source. Skips what that person
  already told you and readings the whole town heard.
- **Wait.**

**Approaches:** at the start of some phases an NPC asks to talk (news, a frame or probe,
or a busybody's gossip). Accepting costs the phase; declining is free.

### Night

- **Vigil** at a block (default, unlimited): see who moves through it, including anyone
  whose gift sent them there. Offered vigils build trust only; they don't deter the demon
  (a deterrent was tried and removed). Strength **[watch]**.
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

A conversation has **3 questions**. The menu:
- **Ask about <name>'s gift…**: their gift, or "are you the X?". A right first guess makes
  them own up a little more readily; a wrong guess costs trust (0.02 × wrong guesses so
  far) and gets the same non-answer an unwilling holder gives, so a guess never eliminates
  anyone.
- **Offer…**: your ward on their door, or a vigil on their block, tonight. Free (no
  question). Trust +0.03 on the offer, +0.06 when kept, −0.15 when broken; settled when
  you choose your night work. **[watch]** on the numbers.
- **Ask where they were and who they saw…**: today, last night, yesterday evening /
  afternoon / morning. Daytime answers start with where they were and are truthful
  (daytime whereabouts are open to anyone's eyes). People you can already see are left
  out. Night answers go through the night account (Lying, below).
- **Ask about others…**: "Opinion on…" a person (may add their haunts and recent
  sightings of them), or "Heard of a…" gift (who claims it, publicly or in private if
  they'll pass it on; small chance the holder owns up).
- **Ask why they suspect X**, after they hinted at the meeting (see Citing reasons).
- **Present a card** (below). A card already shown costs no question, once per
  conversation.
- **Leave.**

**Presenting** is the one verb for using the board on someone. The game reads the
direction from the card (incriminating vs clearing strength) and who it's about:
- a card or deduction about the listener **presses** them: pressure rises with the card's
  strength; a night card makes them account for that night; a card about their gift
  re-runs the disclosure decision (a true Clerk naming opens them up); a rival's claim of
  their gift makes them restate it and turn on the rival. Nerves show with probability
  ~ (hiding ? 0.6 : 0.2) × (1 − Composure) × strength: a hint, not a tell. Costs trust
  unless the card names them favourably.
- a deduction about someone else **argues** it;
- a plain card about someone else makes a **case** for or against them; multi-person cards
  apply to the group, split; `for` / `against` override.
- A card with no direction falls flat ("I'm not sure what you're trying to prove"), costs
  no question and is logged (`present_fallback`).

The meeting's `present` is the same act in public.

---

## Cards and the case board

### Cards

- Everything learned becomes a numbered card with an **evidence class**:
  - **Speech:** claims, opinions, hearsay, refusals, accusations, alibis.
  - **Circumstantial:** reported sightings, traces, readings reported by others.
  - **Concrete:** player-witnessed events, owner-identifying items, template-backed
    contradictions.
- **Terms.** A **claim** is any stated piece of information from an NPC: a **role claim**
  (what someone says their gift is), a **reading** (a gift's result; poison can break it),
  a **report** (a sighting, an alibi, an opinion; poison doesn't touch it). **Evidence**
  is what the player saw or found. An **argument** is a deduction the player presents.
- Every card carries **when it happened** (canonical; all views place cards here) and
  **when you learned it** (every disclosure: who told you, public or private).
- **One fact, one card:** the same fact reaching you again (privately, relayed, at a
  meeting) is another disclosure on the same card. The same fact from two witnesses is two
  cards that know about each other (`corroborated_by`, "(also seen by Dorian)").
- **Withholding** is a card too ("X claims the Archivist but won't share what it has shown
  them"), weak speech.
- Hidden cards fade (42% opacity) when shown; only deductions can be deleted.

### The case board

- **Views** (exclusive, each with its own filters): **Places & sightings** (rows by place
  or person), **Statements** (rows by the person a card is about; claims, readings,
  opinions, accusations), **Process** (nominations, votes, executions, deaths, quiet
  nights). A card may show in two views (a Night Watch report is a statement and a set of
  "ability" markers); it counts once in a deduction.
- Drawn board with pan, zoom, three levels of detail, paper cards with role icons and the
  speaker's colour; solid/hollow/ability-ring dots in Places; red strings on hover or
  selection (to speakers, relayers, other appearances, a deduction's supports); day
  navigation (a day includes the night before); Fit day / Fit selection / Whole case.
- **Filters** are removable chips with Clear all and a status line ("Showing 4 of 31 ·
  Statements · Filters: About: Agnes"); text filters combine with `+` and exclude with
  `-`. Shared between the grid and the Card List.
- **Overlays** (minimized by default, movable, resizable, from a bottom-left dock): Card
  List, Build case, Profile, Notes, Roles. A shared right-click menu on any card offers Add
  to Deduction, Hide/Unhide, Find Links and Hints (Delete and Unpin for deductions).
- **Deductions** wait in a fold-up tray under the grid and pin to the board where dropped.
- Conflicts are never auto-marked (space for an optional hint system later).
- Code: `game/card_model.gd` (times, views, rows, markers), `game/board_model.gd` (layout
  as data), `ui/case_state.gd` (shared view, filters, selection), `ui/board_view.gd`,
  `ui/deduction_tray.gd`, `ui/case_view.gd`; tests in `tools/test_board.gd`.

### UI directions (case board)

- **Card zoom and rich text on cards** **[decided: extension deferred; renderer approach
  open]**: settle card sizing, clipping and zoom/detail transitions before extending the
  shared text system to board cards, pinned deductions, the tray and Card List. See
  `docs/text_system_handoff.md`.
- **Long dropdowns in columns** (e.g. the builder's ~20-option "is the <blank>" list,
  grouped by its existing categories). **[tentative]**
- **Claims/reveals timeline** next to the location timeline. **[open]**
- "Stayed home" vs "none of your business" on the boards. **[watch]**
- A future "Script" panel and free-floating panels. **[open]**

---

## Cases and how the town judges them

Since Oct 23–25 a presented case is judged by **one shared model** for every listener;
the earlier template-and-weights model survives as the `link` / `conclude` helper and
for the town's social reactions. Architecture, decisions and lessons:
`docs/LEGACY_MIGRATION.md`.

### Building a case: the Case Workshop

The red-string board (**More > Case Workshop**; `ui/live_case_workshop.gd`):
- **Premise:** a conclusion about a person or a piece of evidence. Supported types
  (`LiveAssessment.CONCLUSIONS`): evil, good, the Demon, not the Demon, a minion, Marked,
  suspicious, a modifier holder, holds / doesn't hold a gift, lied, truthful, misled,
  unreliable, and "something doesn't add up" (conflict). Protect and spare are
  preferences, spoken as social speech. A generic innocent secret and a specific Red
  Herring stay unsupported: no fact in the game establishes them.
- **Cards with inline answers** (who in this Seer pair?); unknown answers stay legal.
- **Links** between evidence and the premise; contradicting statements merge into a
  contradiction card that offers the challenges.
- **Challenges** on a card: unlikely, misled or lying.
- **File case** turns it into a presentable card, usable as a premise later.
- **Strength while building:** doesn't support / weakly / moderately / strongly,
  computed by the same model for a neutral listener (public facts, default trust).

`present` uses it privately or at the meeting. A presentation containing evidence the
model can't read is **blocked with the reason**; it never falls back silently to the
legacy rules. A bare belief with no evidence is social speech. Every remaining internal
fallback is visible (`fallbacks`, a morning `[dev]` line, the case summary).

### The shared judge

`workshop/case_eval.gd`, reached through `workshop/jury.gd` and
`workshop/shared_ledger.gd`. **It judges the player's case; it doesn't search for
theories.**
- **Possible worlds:** about 15,000 assignments of the evil team, the Demon and the
  modifier holder, enumerated exactly. Each card is a yes/no (or likelihood) fact per
  world: a reading holds or not, a role claim fits, a sighting fits the movement model.
- **Listener weights:** the prior comes from the listener's own suspicion odds, shifted
  ×½ to ×2 by trust; their own readings count nearly as fact (error 0.002), others' at
  error 0.01, discounted per reading for suspected poison.
- **Soft testimony:** a good source's claims bind; an evil source's role declaration may
  be a bluff (weight 0.35 per declaration). One lie never voids every world.
- **Public facts:** a demon kill is 95:5 evidence of innocence (Q2); hints and refusals
  are weak (likelihood ratio 1.5); opinions and accusations are not evidence (Q4); crowd
  pressure is social (Q1).
- **Suspicion change** = 0.45 × the shift from prior to posterior × (1.4 − 0.8 ×
  Confidence), written as one joint vector that replaces the matching legacy ledger
  entries (no evidence is judged twice).
- **Two runs per listener:** a belief refresh (everything they hold: how do their
  suspicions move?) and a scoped reply (what they say about this case; its effects are
  never applied). During a meeting's testimony refreshes are queued and run just before
  each speaker.
- **Cost model:** cost ≈ listeners × refreshes × evaluations × cost per evaluation. A
  per-world fact is cheap; new hidden state multiplies everything. Speed budget (user's
  machine): meeting entry and presenting about 2 s, nominations under 1 s.

### Decided and open directions (cases)

- **The premise should matter** **[decided: direction; numbers open]**: listeners update
  mainly on the argued target, with Insight-scaled spillover; a clearly wrong premise
  costs a little trust; the preview hints when the evidence points elsewhere. Today the
  refresh ignores the premise.
- **Replies must match beliefs** **[decided]**: the reply's stance should come from the
  same computation as the belief change.
- **Insight as degree** (low Insight follows the evidence less strongly, never in a
  different direction), **attention for replies only**, and **Confidence stickiness**
  (committed conclusions resist reversal but yield to strong evidence) **[decided; not
  built]**.
- **Belief to action (Q3)** **[deferred to the balance pass]**: the legacy vote and
  nomination formulas still decide, including the player's vote/accuse terms; the shared
  execution-priority input exists at weight zero, the home for a rank-aware vote.
- **Supporting evidence: logical where possible, vibes where not**; reactive meetings
  **[open]** (BACKLOG).

### Templates (`link` / `conclude`)

The player can still `link` 1–3 cards and `conclude` an explanation, or write a
conclusion directly (`conclude jory is misled on night 1 because #4 #7`). Statuses
include evil / good / the Demon / not the Demon, a gift, lying, misled, misled or lying,
suspicious, hiding a secret, Marked, the red herring, a secret, an evil role, should be
protected / spared, and "something doesn't add up". Restatements (all supports from the
subject) are refused unless a template matched.

**Templates** (`sim/argue.gd`): the player links cards (or files directly; filing checks
the supports for a template either way) and the game checks them against a library of
three kinds:
- **Contradiction** (can't both be accurate): two places at once by day; out at night vs
  "I was home"; *off-route* (no single way from home passes both blocks, or a named night
  destination doesn't fit a sighting; a claimed lamp route never conflicts); double role
  claim; a watcher who missed someone; a flipped reading; Gravedigger vs a claim; a Veteran
  killed by the demon; a changed story; the Martyr who didn't die.
- **Corroboration**: two witnesses (the player or physical evidence can be one); a Clerk
  reading backing a claim; a quiet night with a Warden/Veteran claim.
- **Inference**: pair elimination (Seer/Archivist pair with one proven good; Scion-safe:
  "hanged without ending the case" only proves "not the demon" with fewer than five
  alive); *overlap* (two evil-pointing readings sharing one person); *group elimination*;
  trace matches someone on that block that evening; association (implicated person seen
  talking with Y); vindication (a Gravedigger poisoned the night they named the Poisoner);
  *pair_both_good*; *martyr_no_save*; *dropped_vs_home*.

Each template lists **explanations**; the player picks the one they argue. In a
contradiction every explanation is fileable. In agreements and inferences, "the reader was
wrong" and "the claim is false" are **rival_only**: rivals the NPC weighs, not offered for
filing. Compatible pairs get a "these fit together" note.

**Builder rules.**
- A deduction needs at least one supporting card.
- **Restatements are refused:** a positive conclusion whose supports all come from the
  subject ("Jory is the Seer because of Jory's claim and reading") can't be filed unless a
  template matched.
- No template is not the same as **unfounded**: a conclusion from cards that bear on the
  person is the player's own inference (at most circumstantial). It's unfounded only when
  the cards don't touch the person; sharp NPCs reject that, credulous ones may be swayed.
- A deduction's class is the weakest of its supports when a template matched; otherwise at
  most circumstantial. A deduction resting on a confessed secret spreads it.
- "What can this be part of?" and Find Links search for templates from a card; the
  builder's live "What these cards suggest" panel updates with the working set.

Caution (not a rule): avoid cases where the player believes they're proving something but
the cards disagree on an invisible technicality. Show the fields a template depends on
(night, phase, block, source) and have NPCs name why they reject an argument.

The running list of patterns no template recognises yet is in BACKLOG ("Template gaps").

Each template lists **explanations**; the player picks the one they argue; "the reader
was wrong" and "the claim is false" are rivals the listener weighs, not offered for
filing. Templates no longer decide how far a presented case moves anyone: that is the
shared judge's job. Patterns no template recognises are in BACKLOG ("Template gaps").

---

## NPC minds

### Traits

Five **defined traits**, rolled once per case as the cast baseline ± that trait's spread,
then constant (low / mid / high tiers at 0.34 / 0.67):

| Trait | Low | High |
|---|---|---|
| **Privacy** (about self: role, relationships, whereabouts) | shares who they are even at low trust; claims early | withholds as long as possible; reveals under pressure; stonewalls rather than lies |
| **Gossip** (about others) | keeps out of others' business; at the extreme won't share even when asked | volunteers what they've seen and heard |
| **Confidence** | opinions shift quickly; stonewalls or cracks when pushed; rarely nominates | opinions shift slowly both ways; lies boldly when pushed; nominates and votes readily |
| **Insight** | swayed by speech alone | swayed only by concrete evidence or a preponderance of circumstantial |
| **Composure** | attitude cues obvious; strongly affected by pressure and paranoia | almost no cues; resists pressure and paranoia |

Privacy decides **whether** an NPC discloses; Confidence decides **what they do when
pushed** (lie outright vs stonewall or crack).

**Derived state** (changes during the case, hidden):
- **Pressure** (individual): accusations, nominations, presses, circulating evidence.
  Loosens claims and secrets. Decays ×0.6 each night.
- **Paranoia** (global): rises with each death (dampened by Composure); raises baseline
  suspicion and lowers nomination/vote bars late.
- **Trust in the player**, and **NPC-to-NPC trust** (relationships: friends and rivals are
  rolled per pair; Lovers trust each other). Friends of an executed NPC resent its
  nominator, yes-voters and the player (grief).

**Alignment:** traits apply to both. Evil overrides **content** (lies) but **style follows
traits and pressure**.

**Decisions are weighted rolls:** named score parts become a probability through one
sigmoid (`Mind.decide`); every breakdown is logged.

**Trait reveals:** after a private conversation one trait is revealed, with a roll for a
second (Composure lowers it); after each meeting, a chance per attendee. Profiles show
learned traits as continuous bars (filling from the midpoint).

**Showing trust diegetically:** greetings, refusals and small body-language lines change
by trust tier ("What do *you* want?" vs "Ah, Demonologist. Sit."). Composure decides
whether these cues show at all.

### Trust in the player

Trust gates disclosure and how far arguments move an NPC. What raises and lowers it (and
caps) is audited line by line in TUNING §2. In brief: civil conversation, kept promises,
first private disclosure, keeping a confessed secret, agreeing arguments and being proven
right raise it; pressing, question fatigue (beyond 3 questions a day), wrong role
guesses, accusing someone they trust, nominating them, spreading their secret, breaking a
confidence or a promise, and a friend's execution lower it. **Trust ceilings:** spreading
a very private person's secret, or nominating someone a good NPC grieves, permanently caps
trust. There's no apology or repair path yet.

### The evidence ledger (belief record)

**Hybrid ownership (Oct 25).** Evidence the shared judge reads (readings, testimony,
sightings, traces, public events, NPC-to-NPC shares with their provenance) is judged
there: its legacy ledger entries are parked and one joint suspicion vector per listener
replaces them. What follows still governs the native, social parts (vibes, grudges,
consensus, trust, defences' social weight) and anything the judge can't read yet.

Each NPC keeps a ledger of the evidence and arguments they've taken in, keyed by the
**underlying fact** (Jory's night-1 reading; Agnes's sighting of Bart on the Docks), not by
who relayed it or which card wrapped it. Each NPC reasons only from what they actually
heard or witnessed.

- **Suspicion** = a social base (vibes, nominations, grudges, consensus) + each ledger
  entry's effects × its weight × how reliable the NPC currently thinks its source is.
- Hearing the same fact again only raises its weight to the stronger hearing; it never
  stacks.
- "Jory is misled on night 1" lowers how much that reading counts, for readings already
  heard and later ones. Trust in a person and confidence in one reading are separate.
- **Credibility** = honesty of the person × doubt about a particular reading.
  - **Honesty:** 1 − a capped share (max 50%) of the *evidence* against them (never vibes
    or grudges).
  - **Reading doubt:** from "X was misled on night N". Poison belongs to the night, not
    the person. A good NPC never doubts their own honesty, but can accept that their own
    reading was poisoned.
- **No circular reasoning:** everything is recomputed from scratch, to a fixed depth,
  whenever anything an NPC believes changes (reading doubt → honesty → arguments scaled by
  their supports' credibility → final doubt → final honesty → effects as differences).
  Recomputing without new evidence changes nothing; mutual accusations can't amplify.
- **Cascades fall out of this:** B says A was evil → A's claims count for less;
  discredit B's report → A's claims recover. Discrediting is not vindicating.
- **Accepted conclusions track their supports**, down chains of deductions. Each distinct
  justification is kept; a conclusion counts as its strongest justification *as it stands
  now*.
- **Shifting trust:** the player's arguments are stored with their weight before trust.
  When trust in the player shifts noticeably, and before every vote, they're re-weighed
  (Confidence sets how far at once). When an old argument finally lands, they say so.
- **Role claims are per-listener records:** credence = hearing weight × the claimant's
  honesty. Each record counts against anyone else that listener knows claims the same
  gift, so double claims resolve by comparing credences. A good NPC's knowledge of their
  own gift is a strong record (a false claimant is a liar to them). A claimant the demon
  killed has their claim counted double.
- **Vindication** relies on poison always making a reading wrong (current rule). Revisit
  if the director makes poisoned results merely plausible.
- **Debug overlay** (checkbox): each card's influence across the good NPCs who heard it;
  profiles show how the town credits and suspects the person. Turning it on marks the
  case's identification unscored.
- Acceptance tests: `tools/test_beliefs.gd`.

### Town consensus: peer pressure, not a pile-on

A public accusation is a social signal, not evidence. Each accuser counts once (their
latest stance), by how much the listener trusts them; each further voice adds half the
one before; accusations fade to 60% a day; the total is capped. It's kept out of the
ledger, so a crowd's opinion never lowers anyone's credibility. A second accuser says "I
agree with X about Y", adding grounds only if they're their own.

### Citing reasons: provenance

Every reason an NPC speaks carries where it came from (`sus_src`), and
`Mind.reason_status` classifies it: **none** (vibes), **public** (the town has it, or
citing it reveals nothing of their gift), **player** (their own reading, told only to the
player), **private** (told to nobody), **relay** (someone else's private reading).
`Mind.citable_reason` returns a reason only if the audience has it; meeting accusations,
nominations, tavern gossip, NPC-to-NPC shares and private opinions all go through it.
A gift is never leaked by a reason.

**Vague is the default for both alignments** ("something's off about them"), so neither
vagueness nor a stated reason is a tell. Good NPCs state a reason only when it's grounded
in something real; evil only when it's grounded in an active bluff.

**Accusation tiers** at the meeting: silent → generic ("I don't trust X") → **hint** ("I
have a reason, but I'm not ready to share it": a hint-marked card, weighs 1.15× a bare
accusation) → **reveal** (they claim their gift and give the reading). Hint vs reveal
weighs the reading's strength, suspicion and confidence against the **reveal cost**
(privacy, gifts that hide from the demon or keep paying off, fear; falling as days pass
and when four or fewer are left). Evil with nothing citable hints 30% of the time
(`C.EVIL_HINT_CHANCE`), so a hint isn't proof of good.

**Following up:** "Ask why they suspect X". If they tell, it's full disclosure; if their
gift isn't public they ask you to keep it between you (the cards are marked
confidential; using one at the meeting costs 0.15 of their trust, waived once they've
gone public). Declining and evil's stalling draw from the same lines.

**Relays:** a reading told to an NPC in private, not yet public, is passed on unnamed at
the meeting: "Word reached me from the Seer: …". The shared judge takes it as the
teller's testimony at reduced weight, with no model of who the hidden source is; a later
"that was me" binds it to the named source, who steps forward 5% of the time.

### Disclosure: the gift question

One question, four tiers, from Privacy, trust, pressure and the day (TUNING §6):
1. Refuses to say (denials are off: `C.ALLOW_NO_GIFT_DENIAL` **[knob]**; evil almost never
   bluffed it, so it was near-proof of good).
2. A **flavoured hint** pointing to a hint package.
3. Names the gift.
4. The gift and its readings.

- Good NPCs never fall back to a lower tier. If trust drops after sharing, they withhold
  *new* readings and say so ("I've told you enough").
- **Caution tied to the gift:** Seer, Night Watch and other recurring readers lean quieter
  on days 1–2; start-knowledge gifts lean more open.
- **Fear as cover:** refusals sometimes say "If I say what I am, I'll be dead by morning",
  likelier as deaths mount and for the skittish (same odds for evil bluffers).
- **Public claims** have their own roll at each meeting (Privacy, day, pressure, gift
  kind; strongly up with four or fewer alive). Going public shares every unshared reading.

### Lying and night accounts

Reasons NPCs lie, always recorded (`think`, topic `lie`):
1. **Evil cover:** a bluff role whose readings are generated by running that role on a
   fake world in which the scapegoat is evil. Lies stay consistent and break only where
   the cover contradicts reality.
2. **Personal secrets:** a good NPC out at night for a secret lies about where they were
   (or confesses, or stonewalls: Privacy, trust and pressure decide whether they confess;
   Confidence whether they lie or stonewall).
3. **Caution:** a good NPC with a high-value gift may hide it.
4. **Poisoned / Delusional / Sleepwalker:** not lies; honest reports of false information.

Asked where they were, an NPC with a disclosed walking gift names its duty (the watch
kept, the door guarded, the hearth visited); evil bluffing a walking gift does the same
from its bluff (a false Night Watch names exactly who its made-up report names; a false
Warden's doors are fixed per night). A good NPC shown a sound "you lied" about their own
statement knows it's true: open or pressed ones own up, the rest stonewall. Disclosing a
walking gift later, they own the earlier lie.

### The town talks (NPC to NPC)

- Two NPCs pair off; each passes one item (an unshared reading, a confided secret, an
  opinion, a case the player made, a night sighting, hearsay, someone else's secret).
  Readings and sightings become receipts in the listener's evidence with who told whom,
  credited by trust in the teller and deduplicated by the underlying fact; opinions stay
  social.
- Every belief records **who it was heard from**, so it can be traced and disowned.
- Evil feeds lies into the network through the same willingness formulas as good
  (otherwise evil was suspiciously forthcoming).
- **Gossips** relay what they've heard; **busybodies** approach the player, a main path to
  others' secrets.
- `ask about <gift>`: a trusting, gossipy NPC may share who claims it and what they said.

### Decided and tentative directions (NPC minds)

From playtest 61251 (an evil team the player had identified won anyway) **[decided]**:
- **A proven lie should hurt an info claimant hard.** A proven whereabouts lie by a public
  info claimant should cut their readings to around 50% credibility (Constance stayed at
  ~90% after an off-route lie, then her fake readings hanged two good people).
- **A Seer's record:** each "yes" pair hanged and shown good should discount that Seer's
  later readings, for everyone who learns it.
- **Repeated trace matches add up** (the first test of the fit checks, above).
- **The player's voice in votes is small at ordinary trust** (0.05–0.14 at trust 0.3–0.5):
  the execution-priority idea applied to the player's nominations.

Other **[decided]**:
- **Offering protection eases fear**, and **the fearful ask for protection** (a ward, a
  vigil, the Warden) instead of only clamming up.
- **Backing a strong case builds trust** with NPCs who agree (what makes throwing a
  teammate under the bus pay for evil).
- **More talk in town**, scaled with population: each pair passes on the most newsworthy
  things the other hasn't heard, never echoing back.
- **Fading into the crowd:** a private character may bide their time when the town is
  already moving.
- **Lie severity** **[open]**: a false gift report weighs more than a whereabouts lie,
  unless the lie puts them near the crime; NPCs who accept a lie but won't hang should say
  so.
- **NPCs push back on nominations their own information contradicts** **[open]**.
- **Ways to discover and confront secrets** (sightings that don't fit, confidants,
  personal items, a "you have a secret" card as leverage) **[open]**; **named
  corroborators** in alibis ("I was with Jory"), word-against-word cards **[open]**.
- **Situational credence modifiers** still to settle: early disclosure, quiet night as a
  credence boost, admission against interest, consistency over time, role-specific
  confirmations. **[open]**
- **Initial general skepticism** **[knob]**: only if the early game gets too decisive.
- **Trust dynamics around sources:** a relayer naming their source at a cost; evil tracing
  an unnamed source. **[open]**
- **NPC memory and recency bias.** **[open]**

**Social retuning** **[tentative]** (Oct 20; candidates for one unified retuning proposal,
see TUNING §12 for the feedback loops behind them):
- Privacy without compounding trust penalties (remove it from starting trust and benign
  gains; keep its disclosure gates; distinguish ordinary questions from repeated prying).
- Evidence can build NPC-to-NPC trust (e.g. a Clerk reading that matches the listener's
  own role), deduplicated by fact.
- Diminishing trust changes near the extremes; review the permanent grief and secret caps
  separately.
- Opinion strength and shared origins: several NPCs repeating one story shouldn't count
  as independent.
- Martyr urgency: lower the commitment threshold as days pass, with a floor.
- Demon victims' earlier readings: more belief in their sincerity without trusting every
  reading's accuracy, based on listener knowledge only.
- TUNING's "what to tune first": make vote resistance say whether it's disbelief,
  distrust or preference for another execution; audit unrepairable caps; align raw-card
  and structured-case treatment of the same evidence; accumulate genuinely independent
  support; then revisit gossip and fatigue boundaries; separate belief from action
  priority.

**Expanded dialogue and trust management** **[tentative]** (pending the retuning
proposal): apologise for a specific incident (scaled by harm and responsibility); suggest
actions to claimed roles (ask a Warden to guard, a Seer to check, a Night Watch to watch;
evil can lie about compliance); general requests that spread through town chats;
responsibility and follow-through as small trust gains; withdraw or revise a case; ask
what would change their mind; explain an execution's purpose (e.g. for a Gravedigger
read); promise confidentiality.

---

## Evil

### Knowledge and coordination

- Evil knows its team, bluffs and a shared plan; the first night gives free shared
  knowledge.
- After that, evil knows only what a member **saw or was told**, plus what they pool when
  they meet (pairs you may see talking, a whisper in a crowded tavern, the meeting). It
  doesn't read hidden state (private suspicion, true night walkers, whom the player
  confided in).
- Evil's sense of public **heat** ignores its own team's accusations and readings.
- **Evil coordination you can see** (daytime meetups, with friends and Lovers meeting too
  as noise). **[open]**

### The shadow good self

Each evil NPC keeps a second, good mind (`n.shadow`) whose gift is its bluff. It runs the
normal good belief pipeline on what that NPC really heard, with its own random stream and
log, never in `w.npcs`. Plan and history: `docs/shadow_self_plan.md`.

- **Secret acts stay on the evil brain:** kill, poison, breath, totem, intel, plan.
- **Public acts follow the shadow:** argument replies, private-case replies, opinions,
  nominations and votes, unless **`Mind.evil_override`** says break cover:
  **stakes − deviation × exposure > caution**.
  - **Stakes:** mostly a teammate's value (demon 2, minion 1) × their danger or how pivotal
    the vote is, or the worth of pushing a good nominee (more for the scapegoat).
  - **Exposure:** public talk about them, known player suspicion, pressure, being on the
    block.
  - **Caution:** the demon 0.8 falling 0.03 a day (floor 0.45); minions 0.7 falling 0.08 a
    day after day 2 (floor 0.25). Late in the game minions sow chaos.
  - Every decision is logged (`think`, topic `override`). Full table: TUNING §10.
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
- **Bluffs** cover every information gift (fake readings in TUNING §10). A Seer bluff
  never gives a "no" that covers the scapegoat and frames every night once five or fewer
  remain. A fake Surveyor count is usually plausible-but-wrong, sometimes true, now and
  then too high for the team (passing for poison or Delusional).
- Evil bluffing a walking gift says their gift took them out when asked where they were;
  its invented sightings follow the window/route rule.

### Night choices

- **Kill choice:** threat (public info claims, a Seer extra, readings implicating evil,
  hostility), opportunity (lives alone), temperament, minus penalties (preserve the
  scapegoat while more than 4 live; spared by Clemency; previous failures). Noise only
  matters between close candidates. A claimed start-knowledge gift spent after night 0 is
  worth less than one that keeps reporting. 3% of nights the demon skips its top three.
- **After a failed kill** with no visible cause (Warden, Veteran), the demon avoids that
  person and shies from high-profile targets for a couple of nights; anyone it glimpsed
  at the door becomes a likely Warden.
- **Poisoner sense:** skips gifts poisoning wouldn't stop tonight (judged from public
  claims); poisons a suspected Warden on nights the demon goes for someone prominent; can
  poison a claimed Veteran first so the kill lands.
- **Breathstealer** silences the most dangerous voice on its block.
- **Demon on the block** may cast the vote that ties and clears its minion.

### Decided and open directions (evil)

- **Evil backs into a bluff:** an unclaimed evil NPC switches its planned bluff when
  another unclaimed gift would serve better (seen out at night → claim Night Watch).
  Needs double-claim logic; then fake Mediums and others can make bolder lies. **[decided]**
- **Throw a teammate under the bus** beyond what the override gives: a pressured minion
  distances itself; the demon goes along with town conclusions to build trust; deliberate
  Scion succession. Needs team utility, not just vote pivot. **[open]**
- **Evil reads as evil** (casting aspersions with no information; doubting sound
  deductions). Largely addressed by the shadow self. **[watch]**
- Tuning candidates: private-case overrides break cover ~9 times in 10; nomination
  overrides grow late at 10 townsfolk. **[watch]**
- The playtest 61251/25923 fixes from `402ac63` (evil won't vote to execute its own
  demon just to follow its shadow, attributed whereabouts cards, and others in TUNING §13)
  landed on main on Oct 21 (PR #17).

---

## The town meeting

### How it runs now

1. **Testimony** (`Mind.meeting_testimony`): public claims (their own roll), readings,
   accusations through the accusation tiers. Silenced people say nothing.
2. **Floor:** the player may present one prepared case or deduction to everyone (once a
   day), judged by the shared model for each listener.
3. **Nominations, one at a time.** BotC limits: each person nominates at most once and is
   nominated at most once per day. The player may `nominate`, or `wait` to let the town
   nominate; `done` closes the meeting once a `wait` finds nothing.
4. For each nomination:
   - **The nominator's case** (`Mind.nomination_case`): up to two public reasons recapped
     (cosmetic: no ledger effect), and the strongest private reason hinted or revealed
     (with a +0.2 push for nominating), or a relay.
   - **The defence** (`Mind.defend_self`): one or two moves from the case against them:
     *reveal* a walking gift to excuse sightings; *confess* a secret (good only); against a
     reading, *red herring* (named in two+ shared Seer yeses), *pair_other*, *lying*
     (if confident) or *misled*; else a plea. Gift reveals, confessed secrets and specific
     reading challenges are judged by the shared model as claims and challenges, with
     regard for the defender as hearing weight; pleas and rival suggestions are speech. Evil uses its bluff and has no secret. `C.DEFENCE_MOVES` brings back
     the one-line protest.
   - **The player's statement:** accuse or defend, optionally citing a card, or Clemency.
   - **The vote**, silent, in BotC order: clockwise from the seat after the nominee,
     nominee last. Evil votes react to the running count. NPC votes compare suspicion plus
     modifiers (the player's stance, relationship, a suspected nominator, spare
     preference, a preference for whoever is already on the block) to a need that falls
     with Confidence and panic (TUNING §8). These are still the legacy formulas (Q3,
     deferred to the balance pass).
5. **On the block:** reaching half the voters (rounded up, the player included) puts the
   nominee on the block. A later nomination with more votes replaces them; a tie at the
   highest count clears the block.
6. Whoever is on the block at the end is executed. A Martyr may die in their place.

**Meeting circle** (`ui/meeting_view.gd`): the living townsfolk's standees in a ring on the
Square (you at the bottom, a candle for your seat), the nominee's portrait in the centre,
nominee framed red and nominator gold. A gold hand sweeps clockwise counting votes: yes
voters step in with a numbered red token, no voters grey out; a tally shows the count
against the threshold, then the outcome. A vote starting brings the circle back from the
map.

**Dead NPCs:** no ghost votes. Keep the door open to the dead affecting the game, e.g. a
final-day **Séance** vote. **[watch]**

### Decided: the meeting as a trial (`docs/meeting_flow_plan.md`, steps 3–6) **[decided]**

Target per nomination: nomination and case → defence → **the player's turn** (accuse,
defend or pass; the natural break in the log; becomes "make a case" under the theory
model) → **supporters** (at most 3 shown) → vote → **last words** if hanged.

- **Supporters (step 3):** others who suspect the nominee pile on (like the nominator's
  case); others defend, including **outing yourself to defend someone** (a Seer "no", a
  Night Watch who saw them stay in), with the same weighing as accusing. Evil supporters
  go through the shadow plus override.
- **The director (step 4):** supporters are queued; the director shows the smallest
  combination that gets the vote where it would land anyway, padded with vibes speakers
  (reminders of existing cover, near-zero sway), in random order. Those not shown simply
  didn't speak and keep their material.
- **Sequence and UI (step 5):** a pacing-only "Continue" when a step runs long; player-turn
  buttons (Accuse… / Defend… / Pass). Comes after the cases-instead-of-proofs design.
- **Measure and write up (step 6).**
- **Vote talk** returns with this work: evil voters draw from the same spread of reasons as
  good ones, and only informative lines are spoken (a reason that differs from the crowd,
  a vote against a stated stance, a swing vote).
- **Last words** for the condemned (flavour).
- Settled: recapping old evidence has zero impact; new evidence in a case has exactly the
  impact it would have at any other time; revealing concrete information lowers suspicion
  most but goes through normal credibility; other defences sway little.

**Open issues from step 2:** evil gains more from defences than good (its "misled"/"lying"
answers to real readings and its bluff reveals cost good ~11 wins in 150 at 10
townsfolk); the defence barely changes how often good night walkers hang, because their
nominations mostly aren't built on sightings. Find what drives those nominations before
tuning further.

**Urgency and paranoia:** NPCs grow readier to execute late ("we must hang someone"); tune
paranoia and urgency together so the last days don't become random lynchings. Good NPCs
creating a final-day tie is left as is (social dynamics as intended). **[watch]**

---

## The town screen and presentation

- **Title bar:** sun or moon, day and phase, Town / Case board / Notes / Roles / Help, case
  seed, New case, More ▾ (text cast and timeline, card sidebar, dev log), Debug.
- **Town screen:** the painted map (top left), the townsfolk list (portrait, colour, claim
  icon, your pencilled guess, "at <location>" when visible; dead greyed), the compact
  profile; actions with a context line beside the log at the bottom. Every menu has a
  Close button. **Case notes** and **Roles** (every gift, its icon and who has claimed it)
  are movable windows from either screen.
- **Painted map** (`ui/map_view.gd`): painted block bases, building sprites with signs,
  cottages with the owner's colour at the door (crossed out as crime scenes), roads with
  lamps, paper standees (busy ones marked, your conversation partner framed gold), night
  tint, zoom to a block. Clicking a townsfolk row highlights their home, workplace,
  visible icon and known haunts.
- **Shared profile** (`ui/profile_panel.gd`), on both screens: portrait, name in their ink,
  occupation and status, their claim with its icon ("Claims: Night Watch (to the town)" /
  "told you privately" / "Hinted at a night-sight gift"), trait bars, and **Your guesses**
  in red pencil (a role and a secret, each with a confidence: Flimsy / Maybe / Likely /
  Confirmed). Tabs: About, Their claims, About them; each entry links to its card.
- **The log:** speaker portraits on speech lines, day headers, a raven on deaths, a card
  icon on new cards; card numbers open the card on the board.
- **Shared text system** (`ui/text_terms.gd`, `ui/text_formatter.gd`,
  `ui/rich_text_renderer.gd`): names and roles bold in their colours (good roles a reserved
  blue, evil a reserved red, ink variants on parchment), role icons and tooltips inline,
  light-ink icon variants on dark surfaces. Built for the log and profiles; cards are
  deferred (above).
- **Papercraft skin** through one theme (`ui/theme.gd`): navy board, cream plaques, gold
  edges, framed paper, serif type; art sliced by `tools/slice_sheets.py`.
- **Dialogue composer** (`sim/dialogue.gd`, `sim/dialogue_voices.gd`): presentation only.
  The simulation decides what is said (including evil's fabrications); the composer words
  it in a character's voice. It never sees world state or truth and draws no game RNG.
  Agnes, Bartholomew and Constance have voices; everyone else uses plain lines. Workshop:
  `ui/dialogue_lab.tscn`. **Voices for the rest of the cast** **[decided, later]**.
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
- **`case_summary`** (schema 2) adds `loss_hint` (`identified_not_persuaded`,
  `evidence_on_board`, `evidence_reachable`, `no_evidence`), night stats and
  `present_fallbacks`. The ending lists evidence that pointed at the demon.
- **Scoring system** (identification credit, guess accuracy with confidence, why the
  player lost) **[open]**.
- **Why did the player lose?** Classify in playtests: wrong interpretation, missed
  accessible information, information never available, or failure to persuade. The logs
  can classify the first three; persuasion failures need the player's notes.

## Dev logging (required)

Every event goes to a JSONL log plus a readable transcript: world events, NPC reasoning
(claims, lies, votes, kill/poison scores, argument evaluations with explanation weights,
overrides), suspicion and trust changes with causes, per-phase snapshots (including
shadows), and hidden state. Unmatched player links are flagged for template work. Entry
types and filters: README "Dev log"; `tools/trace.py`.

## Logic depth

- **The judge is exact, the judging is personal.** The shared model enumerates every
  world consistent with the setup, but each listener weighs the evidence through their
  own priors, trust, own readings and Confidence. NPCs judge the player's case; they
  don't search for theories, so they must not out-deduce the player.
- **Explainable:** every judgement can be traced (`workshop_delivery`, `belief_refresh`
  and suspicion entries in the dev log).
- **Storyteller director** **[open]**: poisoned readings become arbitrary (plausible,
  sometimes coinciding with the truth) rather than always wrong. Today poison makes a
  reading wrong, which a player can invert (playtest 90028). Medium visits chosen by the
  director ("I was called to Hollis's home"). Solvability check, using the same world
  enumeration.
- Main risks: hidden state that multiplies the world count (see the cost model), and
  tuning sprawl. Keep the conclusion vocabulary small and weights in data.

## Teaching

- General rules over special cases ("gifts that choose a place send you out at night"; "a
  demon kill is strong evidence, not proof").
- A tutorial case on a fixed seed, later, once mechanics settle.

## Tech and testing

- **Godot 4.7.2 / GDScript.** The simulation core (`sim/`) is pure logic, separate from
  presentation, deterministic from a seed, runnable headless. `game/game.gd` is the
  command interpreter and case board model; it emits structured events rendered as text.
  The CLI, the in-engine UI and the bot share one command interpreter.
- **Autoplay bot** (`tools/autoplay.gd`): plays through the same commands a human uses and
  sees only what a player sees. `--passive` is the control (does nothing). `--native`
  judges evidence with the legacy rules instead of the shared model (the A/B control);
  it prints per-day suspicion against the truth, town agreement and every good vote's
  score against its need. `--results` + `tools/compare_runs.py` pair seeds. Seed-to-seed
  noise is about ±3 points per 150 seeds.
- **Bot gaps** **[decided]**: the bot doesn't offer wards or vigils or ask about others for
  haunts, ignores traces and dropped materials (and peeks at `w.dropped` when deciding to
  search), never finds totems. Teach it, so bot runs measure these.
- **Tests:** `python tools/run_gd_tests.py --godot <exe>` runs every suite and checks
  failure text (some scripts exit 0 on failure); `--include-slow` adds `test_trace`.
  Known failures: `test_social` (false Night Watch story) and `test_text_ui` (two
  role-hover checks).
- **Speed:** `tools/replay_54875.gd` (opening timings and a profile) and a late-game probe
  (seed 42, Days 3–4); see LEGACY_MIGRATION "Measuring".

---

## Roadmap

Cases instead of proofs is built (Oct 23–25). A suggested reading of BACKLOG, not a
settled plan:

1. **The premise matters**, then **replies match beliefs**: they decide whether
   presenting is a real decision and whether a playtest is readable.
2. **The balance pass:** Q3 (belief to action, a rank-aware vote), Insight as degree,
   Confidence stickiness, the vigil and decisive night sightings, evil sometimes telling
   the truth. Then update TUNING.
3. **Speed:** presenting and search-into-meeting back under budget.
4. **Meeting flow steps 3–6** (supporters, director, sequence and UI, vote talk, last
   words), with "make a case" as the player's turn; reactive meetings.
5. The medium features marked [decided]: evil backs into bluffs, the fearful ask for
   protection, more town talk, Revenant seeks execution, NPCs find evidence, Lovers
   downside, bot coverage; dialogue turn flow (PR #19).

Larger open areas: two-part traces and the trace model, the Breathstealer decision,
relationships, roster expansion (new evidence types must be costed against the judge),
the player toolbox, the director, scoring, procedural and larger towns, Town Hall.

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
is the most forthcoming (a player-led nomination of the true Seer passed 7/8: open, NPC
pushback); vigil is strong; poison as inversion (director item); players want to cite
cards in meeting statements (built).

**Playtest 13473** (10 townsfolk): led to homes spread evenly, Insight-scaled Seer picks,
withholding cards, fake Surveyor variety, benched flavour secrets, overlap and group
elimination templates, Scion-safe deductions, habitual haunts, unseen counts.

**Oct 18:** all roads joined; off-route replaced the night two-places template; the talk
rework (timeframe questions, offers, learned haunts); corroboration between cards; filing
vs weighing (`rival_only`); new statuses; NPCs owning their lies; fear as cover; a vigil
deterrent tried and removed; quick fixes (Medium hearths, Warden doors, Martyr reluctance,
the demon's 3% unpredictable night, "night 0" wording).

**Oct 19:** shadow good self (steps 1, 2, 4, 5); citing reasons, accusation tiers, hints
and follow-up; Mediums' shared menu; readings before the kill; meeting flow steps 1–2 and
relays; full-screen case board, filters, right-click menus; social bars; recent sightings
and firsthand work sightings; shared text system steps 1–3.

**Oct 20:** TUNING.md audit; tentative social retuning and dialogue ideas; text-system
handoff (card extension deferred); playtest 61251 notes; cases-instead-of-proofs decision.

**Oct 21–23:** playtest 61251/25923 fixes landed; the Case Workshop experiments and the
case-reasoning plan; the exact possible-worlds evaluator (`CaseEval`) replaced template
proofs for presentations. Playtest 54875 showed it falling back to the legacy rules for
every listener.

**Oct 23–25:** the legacy migration (card adapters, Q1/Q2/Q4 decisions, fallback
logging), then a re-baseline to a deliberate hybrid: shared judge for evidence, native
social sim (`docs/LEGACY_MIGRATION.md`). Soft testimony ended "impossible" belief
refreshes; meeting refreshes were queued; the exact per-source channel model was stopped
(7 s → 151 s). Mechanics support covered every remaining evidence and conclusion type.
Role-check fixes took a late-game meeting entry from 95 s to 6.5 s. Playtest 22485: the
town executed the Demon on Day 2; fixes for the Breathstealer, claimed walkers' stories
and night secrets on walking gifts.

Bot measurements since the migration are in `docs/MIGRATION_PROGRESS.md`; the table below
is the legacy rules.

**Bot baselines over time** (active vs passive where measured):

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
  13–15%. 600 bot games in about 2 minutes.
- **Readings before the kill:** a Medium finds an untold reading at a demon victim's
  hearth 28% → 41% (7) and 23% → 32% (10).
- **Outcome tracking validation** (pre-roster): active 53/150 vs passive 25/150; demon
  identified in 84/150, both identities in 29/150, 36 identified-but-lost.

# Progression, the player toolbox and perks (design note)

**Status: baseline from a talk with Michael (Nov 21, 2026). Nothing is built.** Written by
Claude-Vicar.
- **Names:** every name here is a placeholder. The ones in quotes ("Super Slayer Shot",
  "Tribunal" and so on) are especially so.
- **What it covers:** the backlog's "Player toolbox" (section 4, `[open]`), and it feeds
  "Scoring system" and "A case archive".
- **Scoring itself** has its own note, drafted and not yet published.

---

## 1. The shape (Michael, Nov 21)

- **Score gives XP, XP gives levels, and levels give rewards:** new content, upgrades and
  challenges.
- **Progress lives in a profile.**
- **Every game gives some XP.** Scoring has fallbacks for smaller objectives, so even a bad
  loss earns something.
- **There's a level cap,** since content isn't infinite. Twenty is a placeholder.

### 1.1 The cadence (Michael's targets)

| Levels | A level comes… |
|---|---|
| 1–3 | even on most losses |
| 4–10 | from most wins |
| 10–20 | every couple of wins |

- **The scoring weights set this pace,** since XP comes from score. Once there are weights,
  Tally can check the curve against real win rates by town size.
- **The difficulty multiplier** in the scoring note does double duty: a bigger town or script
  earns more XP, which gives the player a reason to step up rather than farm the 7-NPC town.
- **The early levels are really the tutorial.** If each one brings one new thing (a
  character, a role, a tool), unlocks do much of the onboarding. That ties into the backlog's
  "Learning resources".

## 2. New content

### 2.1 Characters

- The game has 15 characters, and the starting 7-NPC town needs only 7, so the other 8 are
  rewards.
- **The 10-NPC town unlocks as soon as the player has 10 characters,** three unlocks in.
  That lands around level 3 or 4 at one per level.
- The remaining five spread out later, as variety rather than gates.

### 2.2 Roles

- **The rough launch target:** about 30 townsfolk, 8 burdens, 8 Minions and 4 to 6 Demons.
- **The starting script** has 8 town roles, 1 Minion and 1 Demon. More are added as they
  unlock, until the script reaches the standard split of 15 townsfolk, 4 burdens, 4 Minions
  and one or more Demons.
- **Unlocked roles join the pool automatically** (Michael, Nov 21).
- **Vetoes:** a reward the player can unlock is a limited set of vetoes, each keeping one role
  off dynamic scripts for good.
- **Suggestions (Vicar):**
  - **Unlock each threat with its answer.** A new Minion or Demon arrives alongside a town
    role that pushes back on it, so a new threat never lands with no way to meet it.
  - **The newest role shows up in the next game,** so it's taught right away rather than
    turning up several games later.
  - **The first burden is a known one,** such as Marked, rather than the hidden Delusional,
    which is a harder first lesson.
- **For the builders:** the simulation stays deterministic from its seed. Unlocks only change
  which roles go into the script, passed into the deal. Golden captures and sweeps need an
  "everything unlocked" mode.

## 3. The player toolbox

- **The pattern** (Michael): an alternate, usually single-use, version of a townsfolk ability,
  mostly used at night.
- **Vigil** is the default. **Ward** and **Clemency** unlock early.
- **The player picks two tools** for a case. Slots may be limited until a higher level unlocks
  the second.
- **Tools generate cards** (Michael, Nov 21): most, if not all. A tool's result enters the
  case as the player's own claim, which NPCs weigh by their trust in the player, so the
  player still has to persuade the town. Intuition (below) is the deliberate exception.

### 3.1 Michael's pitches, with first notes

| Tool | What it does | Notes |
|---|---|---|
| **Séance** | Speak with a dead person as if alive, to get the readings or sightings they had before dying. They don't know who killed them. Dead evil can still lie. | Strong fit. Its special trace could be the dead person's last sighting, or where they were the night they died: always true for a good victim, falsifiable for evil. A poisoned reading stays false after death. |
| **Detain** | Take one NPC out of play for a whole day: no abilities, no vote. They're very angry afterwards. | It needs a rule for the Demon. The simplest is that detaining stops day actions and votes only, and the night kill still happens, so a quiet night isn't proof. It overlaps the Breathstealer's silencing, which can help teach both. |
| **"Super Slayer Shot"** | With 5 or fewer alive, name a target. The Demon wins you the game. Anyone else loses it, and the score is set to 0. | Great drama, and an answer to "I knew, but couldn't get the town there". A score of 0 breaks positive-only scoring, so a miss could instead end the case as a loss that keeps only the basic XP. |
| **Autopsy** | Learn a dead person's role (or only their alignment, if that's too strong) and whether they held a burden. | It overlaps the Gravedigger, which reads executed people. Limiting Autopsy to people killed at night separates them. How they died (Demon, Brute…) is a useful extra. |
| **Physician's Kit** | About 3 uses. Learn whether a person was poisoned that day. | Not too strong against Ill-Omened: the board marker already says the omen "may have" fallen. It should report poison only, so a Delusional reader reads as unpoisoned while still wrong. Two uses may be enough. |
| **Intuition** | Learn one important but unciteable fact about the game. | Draw from a curated pool, seeded, so it never solves the case. Examples: "a burden is in play", "the Demon doesn't live on the Hill". |
| **Circle of Protection** | Choose a block. Evil can't act against anyone there that night and must target elsewhere. | It needs a late-game limit, such as no use when the block holds half or more of the living. Decide whether "act against" covers poisoning: if it does, it can shield the Seer's reading. |
| **"Second Chance"** | A "starts knowing" role's ability triggers again tonight, with new information. | Simple and informative. Poison and Delusional still apply. |
| **"Tribunal"** | Choose 3 people; only they vote on the current nomination. | The most dangerous: it lets the player hang someone without persuading the town. Possible limits: the three must be unanimous, no use on day 1, and the voters left out are annoyed. |
| **"Juggle"** | At the start of day 1, name 5 people and a role for each. Learn how many are right. The Demon may not be named. | Before any claims it's close to a lottery, so allow it up to the start of day 2. Dropping the "not the Demon" rule may be simpler. |
| **"Carouse"** | Choose someone who hasn't claimed. Guess their role and learn if you're right. If wrong, they're poisoned that night. | The risk to an innocent is nice. Mind two name clashes: "Carouser" is the on-deck burden, and "drunk" became "poisoned" in player-facing words. |
| **"Balloon"** | Learn how many character types (townsfolk, burden holder, Minion, Demon) were among the people you talked to today. | It rewards talking to people, which the game wants. |
| **"Rechristen"** | Give a person a new role of their alignment. | The most expensive to build: the judge's world model fixes roles at the deal, so this reaches into the C# solver, claims and bluffs. Hold it until Lantern costs it. |

### 3.2 More tool pitches

- **Shadow:** follow a person at night and learn which block they went to. It uses the
  movement checks.
- **Census:** learn how many evil voted yes on the last hanging. Cheap to build, since the
  vote record exists.
- **Mirror:** learn whether two people share an alignment.
- **Curfew:** choose a block; everyone who comes or goes there tonight is seen. It produces
  movement evidence.
- **Oath:** choose a person. Their next statement is honest unless they're evil, so a lie
  proves them evil, but they may not lie at all. Subtle, perhaps too subtle.
- **From the earlier backlog item:** Scry, Binding circle, and an exorcism or true-name
  alternate win.

## 4. Perks

- **Michael's first vision:** three perk slots, each holding a small passive bonus. New perk
  slots and the perks themselves are both level rewards.
- **Simple passives first** (Michael, Nov 21). Trade-offs ("4 questions, but they know you're
  prying") stay an option, to keep a perk that tests too strong rather than nerf it.
- **Suggestions (Vicar):**
  - keep perks away from deduction itself, so the player still builds the case;
  - let the player swap perks freely between cases;
  - watch that perks rising with level don't cancel out scripts growing harder.

### 4.1 Michael's pitches, with first notes

| Perk | What it does | Notes |
|---|---|---|
| **Judgment** | Start knowing one person who isn't the Demon (they may be a Minion). | With First Impression it could nearly solve the 7-NPC town. Either don't unlock both before the 10-NPC town, or have it show a Townsfolk. |
| **First Impression** | Start knowing a role hint about two people. | Links to the tabled "Role hints from workplaces and haunts". |
| **Likeable** | The town likes you a little more at the start. | |
| **Observant** | The first time you visit each block, learn one person's haunt there. | |
| **Imposing** | You generate a little more pressure. | |
| **Discerning** | A slightly lower chance of finding a false trace. | |
| **Convincing** | NPCs are more likely to follow your suggestions. | Keep it small, or NPCs drift toward following like sheep. |
| **Hindsight** | The first time a Minion is nominated with enough votes to hang, but isn't hanged (someone else gets more votes, or ties), you learn this. | Clarified Nov 21: "on the block" meant nominated with enough votes to hang. The perk text should say "nominated", since "block" is also a town block. |
| **Eavesdropper** | You hear more gossip at the tavern. | |
| **Official** | What you learn at the Town Hall is more likely to cover roles in play or evil bluffs, rather than roles out of play. | |
| **Underdog** | On day 3, if no evil has been hanged, you learn this. | A comeback perk, naturally rare. |

### 4.2 More perk pitches

- **Night Owl:** your Vigil shows one extra sighting.
- **Thick Skin:** NPCs' anger at you fades faster.
- **Well-Read:** the Town Hall gives a second item.
- **Tinkerer:** one extra use of a tool that has several.
- **Steady Nerves:** your first nomination of an innocent costs no trust.
- **Familiar Face:** NPCs you've talked to twice share their haunts.

## 5. Other rewards

- **Challenges:** optional rules for a case that raise its XP. Examples: no Vigil, the Demon
  starts with a free bluff, a gossip-heavy town, one fewer question a day. They give late-game
  depth without new content.
- **Choosing the script:** past a certain level, pick which unlocked roles go in, with a full
  editor at the top levels. Custom scripts already exist in code.
- **A bestiary and codex:** an entry for each role once met, with lore and how it plays. It
  ties into the in-game wiki on "Learning resources".
- **Town sizes above 10** as a high-level unlock: the burdens work freed room for them.
- **Character depth:** backstories and relationships between characters (the tabled
  "Relationships" item).
- **Cosmetics:** reveal card backs, board themes, portrait treatments, and player titles.
  Presentation only.
- **The case archive** (on the backlog, Nov 21): past cases per profile, with lifetime stats
  and replay through the grim reveal.
- **Fixed cases:** a daily or named seed everyone plays. Later.

## 6. Open questions

1. **The XP curve:** the exact amounts, once scoring has weights.
2. **What each level gives,** in order: a full unlock table.
3. **Toolbox slots:** when the second slot opens.
4. **Perk slots:** when each of the three opens.
5. **Vetoes:** how many, and when they unlock.
6. **Which tools and perks make the first set,** and which wait.
7. **The rules each tool needs** (section 3.1 notes): Detain against the Demon, the Circle's
   late-game limit, Tribunal's limits, the Slayer Shot's miss.
8. **A reset or "new game+"** for a profile at the cap.
9. **Challenges:** which ones, and how much XP each adds.

## 7. Who would build what

- **Herald:** the profile, the level-up screens, the loadout screen for tools and perks, and
  the case archive.
- **Quill:** tool results as cards, and the evidence each tool produces.
- **Lantern:** how NPCs weigh tool cards, and what Rechristen would cost.
- **Beadle:** NPC reactions (anger at Detain and Tribunal), and evil's answers to tools.
- **Tally:** the XP curve against win rates.
- **Script and unlock plumbing:** whoever owns the deal, keeping the "everything unlocked"
  mode for golden and sweeps.

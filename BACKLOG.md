# Demonologist backlog

The single to-do list. It gathers the deferred and open items from DESIGN.md, the
role_exploration On Deck list, the Project notes and playtests 13473/55774. Items are
sorted by effort. DESIGN.md stays the record of how things work and why.
Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it. Source in parentheses where useful.

---

## 1. Bugs and quick fixes (hours, low risk)

- **"is not evil" files as "is evil".** Confirmed (55774: "Fenwick is evil", deleted,
  then refiled as "good"). The builder's "is not" list maps the status *good* to
  `evil` and *evil* to `good`, but `Argue.from_builder` matches on either column, so
  the stored value `good` hits the first row ("good" → `evil`). Match on the stored
  value only. [decided]
- **Evil Medium bluff gives away where they killed.** A bluffing Medium's "hearth of
  the dead" alibi uses the block they really were on (Greta: the Docks, where she'd
  just killed). It should use the home block of the dead person in that night's fake
  reading. The fake reading also picks a dead person at random, so it repeats
  ("Dorian" on two nights). Visit each dead person once, most recent first, like the
  real Medium. (55774) [decided]
- **Martyr attribution in the case summary.** The saved person's nomination is
  recorded as the Martyr's execution ("Bartholomew, nominated by Agnes"). Record the
  nominee, nominator and votes, plus the Martyr who died in their place. (55774) [decided]
- **Demon identification with a Scion.** Credit the player for naming the *starting*
  demon for now. The single demon guess also stops you marking both Hollis (dead) and
  Greta (risen). (55774) [decided]
- **Remove the "No demon guess recorded…" voting prompt** for now. Fold it into
  scoring later. [decided]
- **Consensus log text.** "town consensus: N voice(s) against them" also prints when
  the effect is shrinking (old stances fading). Say "fading" or skip the line when it
  goes down. [decided]
- **"I reported" vs "they reported"** when an NPC relays someone else's claim. [decided]
- **Gossip repeats.** Gossipers re-tell the player things they've already told them,
  or things the whole town heard. Skip anything they already told you or that was said
  publicly; info you learned privately from others is fine to repeat. [decided]
- **"Night 0" wording.** Use natural phrasing everywhere ("the night before you
  arrived" / "the first night"), including the builder's night list. [decided]
- **Medium wording.** "At Jory's hearth I learned…" → "Communing with the dead at
  Jory's hearth, I learned…" (and the alibi line to match). [decided]
- **Martyr voting.** A Martyr should be reluctant to vote to hang their chosen unless
  evidence, pressure or panic is high (Bartholomew voted yes on Fenwick). [decided]
- **Warden answers "ask gift" with their guarded doors,** not only when asked about the
  night. [decided]

## 2. Small features and tuning (a day or so each)

### Deduction types and templates
- **Martyr results as facts templates can use.** "The Martyr died in X's place" should
  clear both people (good), and work in pair elimination, Archivist/Seer pairs and
  overlap. Today the card matches nothing, and a filed "X is good" doesn't feed templates
  either (deductions only give templates *evil/demon* and *misled* facts). (55774) [decided]
- **The Martyr who doesn't die.** If the chosen person is hanged and the Martyr lives,
  the conclusion options are: the chosen is evil, the chosen is Marked, or the Martyr is
  lying. The player has to commit to one. [decided]
- **Pair reading with both proven good → reading is false.** For example, the
  Archivist's "one of Bartholomew/Fenwick is the Revenant" when both are proven
  good. (55774) [decided]
- **Misregistration conclusions:** "is Marked" and "is the Seer's red herring" as
  options, bundled under one "misread" heading. [decided: add; open: one entry or two,
  discussed 2026-10-18]
- **"Maybe" conclusions:** half the persuasion and half the trust consequences, as an
  alternative to forcing a commitment. [open]
- **"Is suspicious":** a weak, capped push for building pressure (e.g. claims an info
  gift but won't share). Partly covered by the withholding card. [decided: add]
- **"Has a secret":** an innocent explanation that eases pressure; also an option on
  out-at-night/lie conflicts. [decided: add]
- **Builder status list gets headings:** descriptor (lying, suspicious, misread) | good
  role | evil role | secret. Evil roles aren't offered today (only "the demon"). [decided]
- **Template generalization** (one translation table per role, so pair elimination
  etc. work for any gift that makes the same kind of statement). (DESIGN, deferred to
  roster expansion) [decided]

### NPC behaviour
- **Fear as a mild cover for silence:** "If I say what I am, I'll be dead by morning"
  softens the withholding penalty a little. Pairs with rebuttals. [decided]
- **NPCs push back on nominations their own information contradicts** (a player-led
  nomination of the true Seer passed 7/8). (DESIGN playtests) [open]
- **Lie severity:** a false gift report weighs more than a whereabouts lie, unless the
  lie puts them near the crime. NPCs who accept a lie but won't hang should say so.
  (DESIGN) [open]
- **An open Warden: "I saw X out while I stood guard"** (filed; may be too strong).
  [open]
- **Evil reads as evil:** evil casting aspersions with no information stands out; give
  good NPCs reasons (grudges, secrets) or make evil hold back. (playtest 30294) [open]

### Numbers
- **Day limit by town size.** Today: 6 days for 7 townsfolk, 8 for 10. Your formula
  (+1 per 3 over 7) would give 7 for 10, so it would be *tighter* than now. [open]
- **Unlimited Vigil strength.** (DESIGN open question) [watch]
- **Situational credence modifiers** still to settle: early disclosure, quiet night
  as a credence boost, admission against interest, consistency over time,
  role-specific confirmations. (DESIGN) [open]
- **Initial general skepticism:** a lever to pull only if the early game gets too
  decisive. [watch]

### UI
- **People filter shows claims by *and* about that person** (same as the typed
  filter). [decided]
- **Case-board log readability:** clearer font, coloured names, bold action words, more
  spacing between entries. [decided]
- **Selecting an NPC highlights** their standee, home and workplace on the map, with
  lighter highlights for their haunts. [decided]
- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]
- **Endgame dump: an NPC information-exchange tracker** (who told whom what, and when;
  the `npc_share` events already exist). [decided]
- **From Playtest Notes 12553**: checked and done: "I agree with X" in meetings,
  "from my window" wording, home block on "was home" cards. Not checked yet: pin cards
  to the main view; filter out sightings; people who aren't talking or working showing
  on the map; a wrong role guess blocking process of elimination; pressure in the debug
  view; conversations missing from filters; no way back after clicking a timeline node;
  combined text filters ("Greta+Night").

## 3. Medium features (several days; touch a few systems)

- **Rebuttals and excuses.** Someone accused explains with their gift ("I was out
  because I'm the Lamplighter"), which buys some grace with listeners; evil without a
  fitting bluff can claim a fake secret. Biggest open hole: hidden night walkers frame
  themselves (Isolde 55774; Lamplighter/Veteran/Sleepwalker hang rates). (DESIGN)
  [decided: next social pass]
- **Nominations make a case.** The nominator cites several cards, even weak ones.
  Mostly flavour; it only moves NPCs if it brings new information. [decided]
- **Talking to a group:** 3 questions per phase, split among anyone at the spot.
  [open; discussed 2026-10-18]
- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems.** Today the Revenant is often invisible (55774). [decided]
- **NPCs find evidence and personal items** (dropped items, traces). [decided]
- **Lovers downside:** when one dies, the other becomes withdrawn (max Privacy, min
  Gossip, …), or loses their gift. [open; discussed 2026-10-18]
- **Ways to discover and confront secrets:** sightings that don't fit, confidants,
  personal items, a "you have a secret" card used as leverage. (DESIGN) [open]
- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. (DESIGN) [open]
- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (DESIGN, open since playtest 1) [open]
- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers
  meeting too as noise. (DESIGN) [open]
- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  demon; the demon goes along with town conclusions to build trust. (DESIGN) [open]
- **Full-screen case board** with profile, deductions and cards as overlays; ties into
  modular, movable windows (also deferred). [decided]
- **Claims/reveals timeline** next to the location timeline. (DESIGN) [open]
- **Watchtower** (or a belfry or similar in town): spend a phase there to see who is at
  every public spot. [open; discussed 2026-10-18]
- **Dialogue composer** (Codex `codex/dialogue-prototype`, 1 commit): three voices
  (Agnes, Bartholomew, Constance) × five situations, plus a dialogue lab scene. It's 5
  commits behind main and conflicts in `sim/mind.gd`, so it needs a rebase. The new
  cast has no voices. [open: review and merge]

## 4. Major structural work (a week or more; design first)

- **Night movement and trace model.** One package of related items:
  - the deferred night-proximity rule for sightings (route from home to the death
    block);
  - the proposed route limit (home → at most one detour → victim);
  - traces based on where the killer *started* rather than their evening block (this
    fixes the evening-shift demon problem);
  - optionally, timing within the night.

  The watchtower and the evidence-chain items depend on this choice. (DESIGN) [open]
- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration).
  Relationship mods for the Lovers live here too. [open]
- **Roster expansion:** On Deck gifts (Tracker, Clairvoyant, Beckon, Tallyman…); minions
  (Framer/Forger with evidence planting, Blackmailer, Hexer, Informant); Debtor secret.
  Each needs its hint package and template coverage. [open]
- **Player toolbox:** Autopsy, Séance, Scry, Binding circle; demon types with bestiary
  entries; exorcism / true-name alternate win. (DESIGN) [open]
- **Scoring system:** identification credit, accuracy of guesses with confidence, why
  the player lost (wrong read / missed / never available / failed to persuade). Absorbs
  the removed voting prompt and the Scion credit rule. [open]
- **Storyteller/director and solvability check:** poisoned readings become arbitrary
  (chosen plausibly) rather than inverted; check that a case can be solved. (DESIGN)
  [open]
- **Procedural town:** blocks, buildings and roads generated per case. (DESIGN) [open]
- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]
- **NPC memory and recency bias.** (Random ideas) [open]
- **Dead NPCs:** no ghost votes for now. (DESIGN, deferred) [watch]

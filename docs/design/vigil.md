# The vigil: options (design note)

**Status: decided (Michael, Nov 17): option A, the vigil watches who leaves a block. Built
Nov 17 (Quill, `claude/vigil-leavers`).** Written Nov 17 from a talk between Michael and Claude-Vicar. It replaces the option
list under "Unlimited vigil strength" in BACKLOG section 2 (Numbers), now `[decided]`, and
the matching question in DESIGN's "Open questions". Builders: Quill (the vigil's evidence,
the judge, and the bot's vigil policy), Herald (the result wording and UI). The facts below
are read from the code on main, not measured.

## Decision (Michael, Nov 17)

- **The vigil watches who leaves the watched block,** not who arrives (option A below).
- **No comparison sweep first.** Michael is comfortable with the model; it goes straight to
  a build and then playtests.
- **A lower bot win rate is acceptable.**
- **The bot's vigil policy changes in the same build:** it watches the blocks of the people
  it suspects most, not the homes of its likeliest victims.
- **Not taken now:** the other options (B–E). Sleeping in (C) and random misses stay
  in reserve as dials if a sweep of the town by vigil proves too efficient in play.

---

## 1. The problem

Michael (Nov 17): the vigil is still strong after its nerf (it used to see people coming
and going). A player who understands whom the Demon kills has a good chance of catching
the Demon on the kill block, and that sighting is very damning. Playtests 26532 and 54875
both had a vigil on the right block catch the Demon outright.

### Why it's strong, as built

- **What a vigil sees** (`C.vigil_sees_path`, `sim/content.gd`): anyone whose night route
  *ends* on the watched block, plus anyone walking the full lamp route. People passing
  through aren't seen. In play it never misses: `sim/world.gd` `_night_sightings` adds
  every walker it can see. Only the judge allows for a miss: it gives about a 1 in 20 chance
  that someone the vigil should have seen was out anyway, so an empty vigil clears strongly
  but not absolutely (`Workshop.VIGIL_MISS`, `workshop/live_activity.gd`).
- **The town has 4 blocks.** One vigil covers about a quarter of the town, so even a blind
  guess catches the Demon on about 1 kill night in 4.
- **The Demon's target is predictable.** On a kill night the Demon's route ends at the
  victim's home. The kill score (`Evil.choose_kill_target`) puts a living public claimant
  of an information gift far ahead of anyone else. A player who knows that watches the most
  exposed claimant's block. The bot's own vigil policy does exactly this (`tools/autoplay.gd`,
  "keeps vigils where the Demon is likeliest to strike").
- **What the sighting means to the judge:** the movement model has the Demon heading for
  the victim's home on kill nights, while a good person with no walking gift is out about 5%
  of nights. "Arrived on the victim's block the night they died" is about as strong as a
  sighting gets.

## 2. Options

### A. Watch who leaves instead of who arrives *(chosen, Nov 17)*

The vigil sees people leaving their homes on the watched block, not people arriving there.

- **What it fixes:** the player no longer predicts the Demon's target. They watch the 2–3
  people who live on a block, so they aim at suspects: deduction, not knowledge of evil's
  habits. "Went out that night" is much weaker than "arrived at the scene", because
  walking gifts, Lovers, Sleepwalkers and Minions all go out too.
- **What it adds:** an empty vigil clears the residents. The Demon always goes out on a kill
  night, so "nobody left Chapel Hill" means none of its residents was the Demon that night.
  With 4 blocks and 6–8 nights, a methodical player can sweep the town and narrow the
  Demon by elimination. That is slower than today and needs more persuasion, but it is a
  different shape of strength (a check on who stayed in), not a weak tool.
- **Persuading the town:** a player can be sure who the Demon is and still struggle to
  convince the town. That is the intended difficulty: "Fenwick left his house" convicts only
  against his claim (a Clerk has no reason to be out), which is the player building the case.
- **Depends on two backlog items:**
  - "Night sightings are too decisive" (Numbers, `[decided: tune in the balance pass]`):
    the 5% ordinary out-rate makes "a day-gift claimant seen out" read as near-certain,
    and that's exactly what this vigil produces. The two should be tuned together.
  - "Evil backs into a bluff" (NPC behaviour, `[decided]`): a Demon seen leaving home can
    switch to claiming a walking gift. That is evil's natural answer.
- **Cost to build:** small. The sim and the judge read the same rule for what a vigil sees
  (`C.vigil_sees_path`, used in `sim/world.gd` and `workshop/live_activity.gd`,
  `movement_model.gd`), so the judge follows a change automatically. A Demon whose victim
  lives on its own block still "leaves home". The lamp-route clause stays as it is. Golden
  likely doesn't move, since the passive player never keeps vigil.
- **Two dials if a sweep proves too efficient:**
  - **Sleeping in** (option C) on top.
  - **A vigil can miss someone slipping out in the dark.** Today it never misses in play.
    Random misses would need a change to the simulation (which walkers it sees) as well as
    the judge (how much an empty vigil clears, `VIGIL_MISS`), so the two stay matched. An
    empty vigil then clears more weakly. Probably a new constant (Michael's call).

### B. The Demon shows only as a shadowy figure

The vigil reports "a shadowy figure" for the Demon, perhaps with a trace, and still names
everyone else.

- A special case for one role, against "general mechanics over special cases".
- It splits the player's vigil from NPC sightings, which can name the Demon.
- Elimination undoes it: if two arrive and one is a shadow, the shadow is whoever wasn't
  named.
- Better kept as a trait of a particular Demon type later than as the fix.

### C. A vigil makes the player sleep in

Keeping vigil costs the next morning's action.

- Fits "choices cost time, failures don't".
- A hit is still decisive. This rations the vigil rather than weakening it, so it works
  better as a dial on A than as the fix.

### D. Vigils limited like the ward

- One use is still decisive.
- It pushes the player to save it for the predicted kill block, which sharpens the problem.

### E. Unlock the vigil with Hexer scripts (progression)

The vigil unlocks only once the player is playing scripts where the Demon may be the Hexer,
which kills by day, so a vigil is less damning.

- The Hexer is experimental (BACKLOG section 4), and the default script keeps the problem.
- A fit for progression later, not a fix now.

### Earlier ideas still on BACKLOG's list

- **A vigil shows only a count** of the people on the block. That leaves the player relying
  on chance sightings and the Night Watch.
- **Keep watch at one location:** name anyone at that spot and count the rest of the block.

## 3. Measuring it before deciding

- **Tally:** compare today's vigil with option A, using the bot on the same seeds: how
  often a vigil sights the Demon, how decisive the case that follows is, wrongful hangings,
  win rates.
- **The bot's vigil policy has to change for A,** or the comparison is unfair: today it
  watches the trusted claimants' homes, which suits arriving, not leaving. For A it should
  watch the blocks of the people it suspects most.
- **Then a playtest:** tuning is by feel. Was the case too easy, or unsolvable, in hindsight?

## 4. Still open

1. **The result wording** (Herald drafts; the wording is Michael's). A first draft: "You kept
   watch over Chapel Hill. A little after midnight, Greta left her house." and, for an empty
   vigil, "You kept watch over Chapel Hill. Nobody stirred." (the Night Watch already says
   "nobody stirred" for a quiet watch, #178, so the two would match).
2. **Offered and requested vigils.** The player can offer a vigil "on their block", and NPCs
   can ask for one. Today that reads as watching over the NPC's home. Watching who leaves,
   it watches the NPC and their neighbours instead, so the offer's meaning shifts (it already
   builds trust only and doesn't deter the Demon). Whether the offer's wording or its trust
   reward should change is a small call for the build; Herald for the wording.
3. **Random misses:** none, as today, unless playtests show an empty vigil clears too
   cheaply. They'd need a simulation change as well as the judge's.

## 5. What the build should check

- **The sim and the judge stay matched:** both read `C.vigil_sees_path`. Today's
  destination rule also catches walkers whose gift sent them to the block (a Warden at a
  door there, a Medium at a hearth there); under the new rule they're seen only if they live
  there. The judge's exclusion cards (an empty vigil, a complete vigil list against a claimed
  walker, `workshop/live_activity.gd`) must read the same rule.
- **The lamp-route clause** (anyone walking every block is seen) stays, or goes if a
  Lamplighter leaving home is enough. Builder's small call; say which in the PR.
- **Tests that pin the destination rule** (for example `tools/test_workshop_live_activity.gd`,
  `tools/test_evidence_cards.gd`) are updated, not skipped.
- **Golden:** likely unchanged (the passive player never keeps vigil); say so if it moves.
- **The bot:** `tools/autoplay.gd`'s vigil policy targets suspects' blocks. Report the bot's
  win rate and how often its vigils sight the Demon, before and after, in game terms.
- **DESIGN.md** "Vigils see destinations" and the Night section's Vigil line are rewritten
  when it's built.

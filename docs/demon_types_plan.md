# Demon types: the day-killer

Nov 8, 2026 · Michael and Claude-Bailiff. Status: step 1 merged (#105). Step 2 built on
`claude/day-presence`, held until the day-killer (step 3) is tested. Step 3 not started.

## The idea

A script may list more than one possible demon. The first new type is a **day-killer**. It
kills without walking at night, and the town has to work out which demon it's facing. The
script always shows every role that could be in play, including both possible demons, so
the player knows the odds.

## Rules (settled with Michael, Nov 8)

- **It never night-walks.** It still kills at the victim's house, arriving by teleport or
  something like it, so it's never seen walking and vigils don't catch it arriving.
- **Everything at the house works as before.** It leaves a trace. Wards and the Warden
  block it. The Veteran still survives it and still learns a block that points toward the
  killer, even if that's less sensible in-world.
- **It can't kill like the normal demon.** There's no fallback to walking.
- **It marks by day, at a place.** It marks a workplace or haunt it's at during the day.
  That night, a random good NPC who works at or haunts that place dies. The mark itself
  needn't be visible.
- **It can mark in any day phase.** It shouldn't be trapped by its own schedule. Rather
  than restricting the phase, the player gets other ways to narrow it down.
- **There's no "no good regulars" rule.** With marking allowed in any phase, a place with
  no good regulars shouldn't come up in practice.
- **The victim draw ignores wards.** If the demon marks the Smithy and the player wards
  one of its regulars, that person can still be drawn, and the ward then stops the kill.
- **A Scion takes over the dead demon's type.** Not yet discussed; this is the working
  assumption.

## The solver: what changes

The demon's type is one hidden fact for the whole case. Formally, each candidate world
splits into a walking-demon version and a day-killer version, weighted by the script
(equal shares for now: one type of two means a half).

**What doesn't depend on the type:**
- every reading and claim;
- the circumstantial hub;
- traces and the scene tables (either demon is at the victim's house);
- wards, the Warden and the Veteran.

**What does:** the demon's own night movement. The walking demon goes to the victim's house
on kill nights, and its route makes sightings, vigils, Lamplighter counts and Night Watch
reports count against it. The day-killer is out at night like a minion (a 0.25 rate,
anywhere), so night-walking evidence says little about who it is.

In a given world only the demon's own movement factor depends on the type, so the mixture
is exact if it's applied to that person's whole-case likelihood:

    sum over t of pi_t * prod_i L_i^t  =  prod over i != demon of L_i  *  (pi_walk * L_walk + pi_day * L_still)

where L_walk is the demon profile and L_still is the minion profile. Mixing night by night
instead would be wrong: it acts as if the type were redrawn each night, so evidence about
the type wouldn't build up over several nights.

**Example (from `test_demon_types`).** Someone seen on both victims' blocks on both kill nights:
- L_walk = 1.0 and L_still = 0.0039: that's 256:1 in favour of a walking demon.
- With both demons on the script, the demon likelihood is 0.502, so the sighting counts
  about half as much against them.
- The same sightings shift the odds on which type is in play: a walker seen at the scene
  is strong walking-demon evidence. A vigil on the victim's block that sees no one arrive
  pushes the other way.

## Steps

### Step 1: helper, types in the view, the movement mixture (built)

- `C.is_demon(role)` and `C.is_day_demon(role)` in `sim/content.gd`.
  - `DEMON_ROLES = ["demon"]`.
  - `DAY_DEMONS = ["daykiller"]`: an id reserved for the day-killer. It isn't in `C.ROLES`,
    so no script can deal it yet.
  - Role-id checks in the sim, the solver and the tools now go through the helper:
    `mind_meeting`, `mind_dialogue`, `gravedigger`, `solver`, `role_constraints`,
    `live_assessment`, `autoplay`, `sweep_record`.
  - Checks on the demon *slot* (`world.demon`) and on guess or premise types are unchanged.
- The snapshot's rules carry the script's demons (`WorkshopBridge.script_demons`), and the
  live view gets `script_demons`.
- `LiveActivity.day_demon_share(view)` and `mix_demon(...)` work as follows:
  - The demon entry of the joint factor's main profiles is mixed. That's exact, because the
    world's score is linear in the one demon's profile. `LiveActivity._likelihood(..., "demon")`
    is mixed too.
  - The Scion's before/after splits are different: the before and after scores multiply, so
    mixing each profile would add cross terms (a walker before and a day-killer after). The
    splits keep walking profiles, the factor carries `day_demon_share`, and C#
    (`ScoreWorldCore`) mixes the product: `(1-s)·Wpre·Wpost + s·Dpre·Dpost`, where the day
    version puts the minion profile in the demon's slot. (Codex's review on PR #105.)
  - The share is packed as an optional trailing double, and the factor cache keys on it
    only when it's above 0, so a share of 0 packs exactly as before.
- **Behaviour:** with a share of 0, which is every script today, every number is unchanged.
  The golden capture is identical to the baseline.
- **Test:** `tools/test_demon_types.gd` (22 checks, including a hand-built Scion split).

### Step 2: daytime presence (built, branch `claude/day-presence`, held until step 3 is tested)

**The watch record.** When the player spends a day phase somewhere, they see everyone at
every public place on that block (the place itself plus "Nearby"). The game now keeps that
roster per phase (`Game.watched`, recorded in `GameDayNight._note_watch`). The snapshot and
the solver's view carry it as `watched`. This is what makes not being seen count: before,
the solver only had the sightings, so it couldn't tell "nobody saw X" from "nobody looked".

**The presence table** (`workshop/day_presence.gd`). For each person, day and day phase, the
chance they were at each of the 8 town places or at home:
- **Prior:** the sim's own schedule model. A working phase puts someone at their workplace.
  An idle phase follows the per-phase odds in `World._choose_idle_location`, with
  `IDLE_HAUNT_CHANCE` going to their two haunts (known ones from haunt cards; unknown ones
  spread over the places they could be). The afternoon's friend visit is spread over the
  workplaces in use, since friendships aren't known. `test_day_presence` samples the sim's
  function and checks the prior matches it.
- **Evidence:** the watch record (listed is certain; not listed rules that block out), the
  player's own sightings (certain), NPC-reported sightings (trusted at
  `PRESENCE_TESTIMONY_TRUST`, 0.8). The dead are nowhere.
- **Slots are independent.** The sim draws each phase afresh, so there's no coupling to model.
- **Queries:** `at`, `on_block`, `same_block`, `at_any` (at any of some places in any of some
  phases: what step 3's mark needs).

**First user: Breathstealer by presence** (the backlog item). The Breathstealer silences
someone out on its own block, in one of the day phases, so for each silencing the silencer
was on the victim's block in that phase. For each person m:

    A_m = product over silencings of  sum over phases p of  P(not yet before p) * h_p * c_p

where c_p is the chance m and the victim were out on the same block in p, and h_p is the
sim's chance of acting that phase (the mean of its low and high odds). A victim can't be
their own silencer. The per-world factor is the mean of A_m over the world's minions (each is
equally likely to hold the role), mixed with `DEFAULT_ERR`. It's a CaseEval movement factor
(kind 3, scored in C# by `CaseEvalKernel.PresenceScore`, with a GDScript reference
`DayPresence.breath_score`), so it feeds the shared model and case evaluation like the
Augur's daytime-crossing factor. No factor when nobody was silenced or the script has no
Breathstealer.
- It replaces the circumstantial hub's one-day "near a silencing" incident, which couldn't
  build up across silencings. The card still counts as relevant to the hub's target.
- **Limits:** who the Breathstealer picks among the people on its block (the threat ranking)
  isn't modelled, only that they had to be there. The watch record is the player's, so it's
  in every listener's view (like the rest of the shared notebook).
- **Tests:** `tools/test_day_presence.gd`; `test_workshop_circumstantial_hub` updated (being
  near a silencing is Stage 1 now).

### Step 3: the day-killer itself (first pass built, `claude/day-killer`, held with step 2)

**Built (Nov 9):**
- **The role:** `daykiller`, display name **Hexer** (a working name), in `C.ROLES`, with
  its own role file `sim/roles/daykiller.gd`.
  - It's an evil non-minion (`is_demon`), status `experimental`.
  - It's in the roster's demons, so a script built with two or more demon types can carry
    it. The default one-demon scripts never do, so today's deals, golden and sweeps don't
    change.
- **The hex (sim):** in a day phase, standing in a public place that has good regulars, the
  Hexer may hex it, once a day.
  - Its chance rises through the day (`Tuning.Roles.HEXER.phase_probs` 0.25 / 0.4 / 0.6). It
    also rises with the regulars' public threat and with how many there are, and drops
    0.25 at its own workplace.
  - The evening floor is 0.85, so it isn't trapped by its own schedule.
  - Logged as `hex` (the hex itself isn't visible to the player).
- **The kill:** that night a random living good regular of the hexed place is drawn,
  ignoring wards (`hex_victim`). Then the normal attack outcome runs: the player's ward,
  the Warden, the Veteran. A kill builds traces at the house as usual.
  - The Hexer never walks, so no streets, no sightings and no vigils.
  - No hex that day means no kill (`hex_empty` if the place's regulars are gone).
  - An active Brute still hunts in its place.
- **The Veteran** who survives a Hexer learns the Hexer's home block (there's no route).
- **The Scion** who rises takes over the dead demon's type.
- **The solver** (`LiveActivity.hex_kills`, C# `LiveActivityKernel.HexFactor`):
  - With a Hexer on the script (share s > 0), the compiled movement factor keeps walking
    profiles, and `ScoreWorldCore` scores each world twice:
    - as a walking demon;
    - as a Hexer (the demon slot moves like a minion; the Scion's splits likewise).
  - It returns `(1-s)*walk + s*day*HexFactor`.
  - For each demon kill or attack, HexFactor is
    `sum over the victim's known places L of P(demon hexed L that day) * goodAlive / goodRegulars(L)`,
    plus `HEX_UNKNOWN_FLOOR` (0.15) for a regular place nobody's learned. The whole factor
    is relative to a walking demon picking among the living good.
  - P(hexed L) is the demon's presence at L that day (step 2's table), weighted by when a
    Hexer strikes and normalized over the public places it was likely in.
  - At s = 0 nothing changes (golden identical).
  - The Hexer avoids hexing its own workplace, so time a suspect spends at work counts
    `HEX_OWN_WORK_WEIGHT` (0.4) in P(hexed L). Without this, the factor favoured the
    victim's coworkers: they're present all day at the victim's workplace.
  - The solver needs each person's workplace for the regulars, so the bridge now hands
    `work` and `work_phases` (public, as on the board) in the view's people.
- **Tests:** `test_demon_types` (26 checks: the factor against a hand computation, and a
  demon far from the victim's places scores lower).

**First probe (Nov 9):** 12 passive cases, 10 NPCs, forced Hexer. The probe compares the
good NPCs' P(demon) for the Hexer at day 4 with and without the hex factor.
- It's neutral to slightly negative: 8 games ran to day 4. Three were unchanged, four
  went lower (e.g. 0.024 → 0.012, 0.238 → 0.172) and one went higher (0.357 → 0.416).
- Passive play rarely produces a watch at the hexed place, so the factor mostly spreads
  belief over everyone present. Its real test is a player who watches public places.
- `autoplay --force-demon daykiller` deals the Hexer, with the Demon still on the script,
  for bot runs.

**Not yet:**
- The bot testing the type (vigils on likely victims' blocks).
- A Gravedigger or role reading that names the type, fixing s.
- Evil coordination beyond where to hex (minions muddying the hexed place).
- The New Case / editor UI showing both demons. The script view already lists every
  demon on the script.
- Tuning: the hex odds and the floor are first guesses.

### What the town knows about places (Nov 9, with Michael)

**Haunts: regulars know regulars.**
- In conversation, NPCs know everyone's true haunts. They point the Demonologist at
  them, tell them outright, and fill them in through tavern gossip.
- Their reasoning knows less. Each NPC knows its own haunts, plus anyone's haunt that is its
  workplace or one of its own haunts (`WorkshopBridge.known_haunts` →
  `view.regular_haunts`).
- That knowledge is used by the day-presence prior, the Hexer's victim places, the trace
  profiles and the movement trace weight. It never enters the ledger or citations. The
  Demonologist's own view gets none.

**The day log and the Whereabouts solver.**
- **The leak:** listeners used to get the Demonologist's full watch record for free. Now only
  the Demonologist's own view carries `view.watched`.
- **The day log:** each watch adds to a hidden `watch_log` receipt, one per day
  (`game_day_night._record_day_log`). It holds who was at each public place of the watched
  block, each phase, empty places included. A listener hears it only when it's cited, as
  one card (one slot in its reading budget). Day presence reads logs from the considered
  cards, so the budget applies.
- **The solver:** `workshop/location_solver.gd` answers one question:
  - a demon death: who was at the victim's places that day;
  - a silencing: who was out on the victim's block;
  - a place on a day.

  For each person and phase it shows what's known (seen, reported by someone, at work, off
  the watched block, free time). It sorts people into fits / unknown / ruled out, using day
  presence's odds; unknown is never backfilled.
- **The UI:** the Case Board's Whereabouts panel (`ui/location_solver_panel.gd`; also
  reached from the Workshop's "Whereabouts" button) commits a Whereabouts node. The node
  cites the day's log plus the NPC reports that bear on the answer.
- **Tests:** `test_location_solver` (29 checks, including the panel and a screenshot via
  `--screenshot PATH`).
- **Not yet:**
  - The bot never builds a Whereabouts node, so in autoplay the town no longer hears the
    bot's watches. Golden is unchanged.
  - The per-person daytime sighting cards are still on the board. Folding them into the
    day log is a possible UI follow-up.


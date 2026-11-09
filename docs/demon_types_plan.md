# Demon types: the day-killer

Nov 8, 2026 · Michael and Claude-Bailiff. Status: step 1 built, on main (#105).
Steps 2 and 3 not started.

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

### Step 2: daytime presence (not started)

A likelihood that a person was at place L during a day phase. It's built from known work and
haunt schedules plus sightings and conversations at L. The player sees only part of the day,
so the absence of a sighting is weak evidence. The same channel closes the backlog's
"Breathstealer by presence" gap.

### Step 3: the day-killer itself (not started)

- **The role:** `daykiller` added to `C.ROLES` with its own role file. It isn't a minion, so
  it doesn't show up as `kind: evil` / `minion`.
  - **Sim:** it marks a work or haunt place during the day. At night it draws a random good
    regular (ignoring wards), the ward check runs, and the kill leaves a trace at the house.
  - **Movement:** at night it's out like a minion.
- **Solver:**
  - **The mark's location:** the victim's work or haunts name the candidate places.
  - **Presence:** the step 2 channel gives the demon's presence at those places that day.
  - **The victim draw:** the chance the victim was the one drawn is 1/n of the good
    regulars there. n depends on who's good, so it's a per-world factor.
  - **Type evidence:** the pattern of victims (always a regular of somewhere the demon was)
    is weak evidence for the type.
- **Evil AI:** where to mark. It should avoid its own workplace and prefer busy places;
  minions can be present to muddy things.
- **NPCs:** night-walking talk should soften while the type is open. Voiced reasons ("I saw
  Jory out that night") read the same mixed likelihoods, so they weaken by themselves.
- **The bot:** test the type (vigils on likely victims' blocks), then check presence at
  the marked place.
- **The Gravedigger and role readings:** a reading that names the executed demon's type
  settles it. Step 1 treats such a reading as naming *a* demon (`is_demon`) but doesn't
  update the type. Step 3 should, probably by fixing the share from public readings, with
  care for poisoned and Delusional readers.
- **Scripts:** the builder and editor allow two demons, and the New Case screen shows both.

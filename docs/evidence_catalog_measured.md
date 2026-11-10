# Evidence catalog: measured pass

Nov 10 2026, Claude-Quill. Companion to `docs/evidence_catalog.md` (the judged pass) and `docs/evidence_catalog_code.md` (code pointers).

**Base: the day-killer branch** (`claude/day-killer`, PR #111, which includes #107's daytime presence), at `75b4c8e`. It changes how movement and the Breathstealer are weighed, and will land on main soon. Harness: `tools/measure_evidence.gd`; summary: `tools/measure_evidence_summary.py`.

## How this was measured

**Towns.** Dynamic scripts (as the sweeps deal them, so every gift turns up), played passively to the start of day 3:
- 250 seven-person towns and 100 ten-person towns for readings;
- 150 and 60 for sightings, alibis and claims;
- 150 and 60 for player-found evidence;
- 100 seven-person towns for public events;
- 40–60 ten-person towns with the Hexer forced onto the script.

**Real evidence, not hand-built.** Each gift reading is a real reading from its holder's log, true or false as the game dealt it. The night sightings are real ones NPCs made, and the traces and dropped belongings are what searching the real scenes turns up.

**The listener.** A living good NPC, wiped clean (no readings, claims, sightings or ledger; flat suspicion 0.25 on everyone; trust 0.5 in everyone). It's then given the card and refreshed through the game's own belief refresh: source doubt, premise shaping, the outside layer and attention (Insight as dealt). The same listener with nothing added is the baseline. Each measurement is the change in that listener's suspicion of each person.

**Modes:**
- **Heard:** the source tells the listener directly, at the source's hearing weight, with the listener's trust in the source set to 0.4 or 0.8. The source's role claim comes with it, as in the game.
- **Own:** the reader's own view of just that reading.
- **All of a source's readings:** everything that source learned with the gift by day 3, heard at 0.8.
- **Presented:** player-found evidence, presented privately by the player as "X is evil" for the person it points to, with the listener's trust in the player at 0.4 or 0.8.
- **Public:** the listener's view with and without one public event. This one uses the shared model directly, not the full refresh.

**Measures:**
- **Separation:** the mean step on the truly evil minus the mean step on the truly good (listener excluded). It's how far one card pulls evil apart from good across the whole town. Positive is the right way. This is the main strength measure.
- **Step on named people:** the mean step on the people the card names, which shows how hard it pushes its own subjects whichever way they really are.
- **Biggest single move:** the largest change on any one person.

**Tiers (separation, heard at 0.8):**

| Tier | Separation |
|---|---|
| decisive | ≥ 0.20 |
| strong | 0.10–0.20 |
| moderate | 0.05–0.10 |
| weak | 0.02–0.05 |
| negligible | below 0.02 |

Medians throughout.

**Caveats:**
- **Heard readings include what they say about the reader.** A checkable reading makes its claimant look good, and that's often the biggest single move. Own readings have no reader to clear, so they can come out lower than heard ones.
- **Day-3 snapshots** carry the town's public events (deaths, executions) in both baseline and measurement.
- **One listener per reading.** The towns vary a lot, so the spread across hundreds of readings matters more than any one number.

## Gift readings, seven-person towns

| Role | Readings (false) | Separation, heard 0.4 | Separation, heard 0.8 | Separation, own | All of a source's readings | Step on named people | Biggest move | Tier |
|---|---|---|---|---|---|---|---|---|
| Gravedigger | 31 (5) | +0.121 | +0.194 | +0.229 | — | +0.124 | 0.395 | strong |
| Dowser | 70 (8) | +0.077 | +0.108 | +0.030 | +0.261 | −0.014 | 0.202 | strong |
| Surveyor | 112 (17) | +0.073 | +0.088 | +0.138 | — | — | 0.176 | moderate |
| Magistrate | 30 (4) | +0.061 | +0.087 | +0.058 | +0.259 | −0.022 | 0.170 | moderate |
| Clerk | 120 (9) | +0.064 | +0.067 | +0.004 | — | +0.007 | 0.134 | moderate* |
| Executor | 14 (2) | +0.061 | +0.064 | 0.000 | +0.163 | +0.008 | 0.140 | moderate* |
| Monitor | 17 (3) | +0.061 | +0.064 | 0.000 | +0.139 | — | 0.141 | moderate* |
| Registrar | 176 (14) | +0.061 | +0.064 | 0.000 | +0.195 | 0.000 | 0.139 | moderate* |
| Martyr | 12 (0) | +0.061 | +0.063 | 0.000 | — | +0.008 | 0.139 | moderate* |
| Confessor | 77 (6) | +0.047 | +0.054 | +0.018 | +0.186 | −0.359 | 0.071 | moderate |
| Rumormonger | 130 (10) | +0.042 | +0.054 | +0.018 | — | −0.064 | 0.084 | moderate |
| Night Watch | 87 (19) | +0.006 | +0.017 | +0.017 | +0.097 | +0.161 | 0.143 | negligible |
| Seer | 100 (25) | +0.006 | +0.013 | +0.021 | +0.099 | −0.023 | 0.061 | negligible |
| Archivist | 104 (15) | +0.007 | +0.011 | +0.056 | — | +0.154 | 0.164 | negligible† |
| Lamplighter | 130 (11) | +0.009 | +0.008 | 0.000 | +0.008 | — | 0.016 | negligible |
| Psychologist | 39 (2) | +0.009 | +0.008 | 0.000 | +0.008 | — | 0.016 | negligible |
| Sexton | 8 (0) | +0.009 | +0.008 | 0.000 | — | — | 0.016 | negligible |
| Augur | 47 (11) | +0.007 | +0.005 | 0.000 | +0.004 | — | 0.016 | negligible |
| Medium | 37 (3) | +0.004 | +0.004 | 0.000 | — | — | 0.008 | negligible |
| Veteran | 1 | — | — | — | — | — | — | too few |

\* These five come out identical, and nearly all of it is on the reader. They barely move the people they name (under 0.01). See finding 3.

† The Archivist pushes both people it names by about +0.15. Half of that lands on a good person, so the net separation is small. See finding 5.

## Gift readings, ten-person towns

| Role | Readings (false) | Separation, heard 0.4 | Separation, heard 0.8 | Separation, own | All of a source's readings | Step on named people | Biggest move | Tier |
|---|---|---|---|---|---|---|---|---|
| Gravedigger | 24 (10) | +0.088 | +0.120 | +0.137 | — | −0.501 | 0.501 | strong |
| Medium | 19 (2) | +0.074 | +0.063 | 0.000 | — | — | 0.426 | moderate |
| Archivist | 59 (8) | +0.027 | +0.046 | +0.081 | — | +0.176 | 0.188 | weak |
| Clerk | 50 (6) | +0.038 | +0.043 | +0.001 | — | 0.000 | 0.195 | weak* |
| Registrar | 86 (5) | +0.037 | +0.042 | 0.000 | +0.114 | +0.001 | 0.200 | weak* |
| Monitor | 24 (3) | +0.037 | +0.042 | 0.000 | +0.080 | — | 0.200 | weak* |
| Dowser | 36 (4) | +0.033 | +0.041 | +0.058 | +0.230 | +0.013 | 0.158 | weak |
| Martyr | 14 (0) | +0.036 | +0.041 | 0.000 | — | +0.020 | 0.199 | weak* |
| Rumormonger | 57 (3) | +0.026 | +0.037 | +0.042 | — | −0.089 | 0.117 | weak |
| Confessor | 55 (3) | +0.025 | +0.028 | +0.010 | +0.087 | −0.362 | 0.078 | weak |
| Executor | 17 (0) | +0.025 | +0.024 | 0.000 | +0.017 | +0.001 | 0.096 | weak* |
| Surveyor | 50 (10) | +0.015 | +0.018 | +0.024 | — | — | 0.100 | negligible |
| Magistrate | 24 (4) | +0.011 | +0.011 | +0.031 | +0.125 | +0.009 | 0.065 | negligible |
| Night Watch | 102 (8) | +0.003 | +0.010 | +0.013 | +0.069 | +0.042 | 0.091 | negligible |
| Seer | 51 (13) | +0.002 | +0.007 | +0.009 | +0.053 | −0.022 | 0.047 | negligible |
| Augur, Sexton, Lamplighter, Psychologist | 36–95 each | about +0.005 | about +0.004 | 0.000 | about +0.004 | — | 0.015 | negligible |

Everything is weaker in a ten-person town: each card is a smaller share of more people. The Surveyor and Magistrate drop from moderate to negligible.

## How often readings are false

Across both sizes, from the readings' own "true" flag. A false reading comes from a Delusional or poisoned reader, a Marked person registering, or the Seer's Red Herring.

| Role | Readings | False | Of those, Delusional reader |
|---|---|---|---|
| Gravedigger | 55 | 27% | 5 |
| Seer | 151 | 25% (36 of 85 "yes" readings) | 3 |
| Augur | 114 | 18% | 12 |
| Surveyor | 162 | 17% | 8 |
| Magistrate | 55 | 15% | 1 |
| Archivist | 163 | 14% | 8 |
| Night Watch | 210 | 13% | 14 |
| Monitor | 47 | 13% | 0 |
| Lamplighter | 273 | 12% | 1 |
| Dowser | 108 | 11% | 3 |
| Psychologist | 77 | 10% | 2 |
| Medium | 56 | 9% | 0 |
| Clerk | 170 | 9% | 4 |
| Confessor | 144 | 8% | 9 |
| Registrar | 262 | 7% | 12 |
| Rumormonger | 187 | 7% | 0 |
| Executor | 31 | 6% | 1 |
| Martyr, Sexton | 49 | 0% | 0 |

**How far false readings mislead** (separation heard at 0.8, seven-person towns):

| Misleads clearly | Separation |
|---|---|
| Archivist | −0.163 |
| Surveyor | −0.162 |
| Magistrate | −0.115 |
| Dowser | −0.089 |
| Executor | −0.062 |

The rest of the false readings are near zero. The Gravedigger's (+0.209) and the Medium's (+0.174) still separate the right way, which suggests their "false" flag marks something else (a Marked dead person registering, say). To check.

## Other evidence

Steps on the card's subject. For sightings, alibis and claims, trust is in the teller; for presented evidence it's in the player.

| Evidence | Subject | n (7 / 10 NPCs) | 7 NPCs, trust 0.4 | 7 NPCs, trust 0.8 | 10 NPCs, trust 0.8 | Separation, 7 NPCs, 0.8 |
|---|---|---|---|---|---|---|
| Night sighting (heard) | evil | 105 / 97 | +0.079 | +0.203 | +0.145 | +0.110 |
| Night sighting (heard) | good | 155 / 159 | −0.003 | −0.028 | −0.021 | +0.009 |
| Home alibi (from the subject) | evil | 105 / 97 | −0.176 | −0.142 | −0.065 | −0.075 |
| Home alibi (from the subject) | good | 155 / 159 | −0.031 | −0.027 | −0.018 | +0.008 |
| Sighting + contradicting home alibi | evil | 105 / 97 | −0.168 | **0.000** | **0.000** | 0.000 |
| Sighting + contradicting home alibi | good | 155 / 159 | −0.030 | **0.000** | **0.000** | 0.000 |
| Role claim (heard) | evil (cover) | 219 / 129 | −0.010 | −0.008 | −0.007 | −0.004 |
| Role claim (heard) | good | 682 / 395 | −0.010 | −0.008 | −0.007 | +0.004 |
| Claim clash (true holder + evil bluffer, same gift) | both | 272 / 114 | +0.111 | +0.148 | +0.187 | +0.032 |
| Demon victim (public) | the victim | 177 / — | — | −0.603 | — | +0.188 |
| Silenced at the meeting (public) | the silenced | 22 / — | — | −0.163 | — | +0.060 |
| Crime-scene trace (presented alone) | the Demon | 173 / 66 | 0.000 | 0.000 | 0.000 | 0.000 |
| Trace with everyone's work and haunt cards | the Demon | 173 / 65 | +0.028 | +0.028 | +0.012 | +0.008 |
| Dropped belongings (presented) | evil owner | 16 / 6 | +0.204 | +0.204 | +0.154 | +0.106 |
| Dropped belongings (presented) | good owner | 13 / 5 | −0.027 | −0.027 | −0.018 | +0.008 |

Only the "locations" trace family turned up on these scripts. Presented alone, a trace averages +0.008 on the Demon and is 0 at the median.

<!-- HEXER -->

## Findings

These are the places where the measured pass corrects the judged one, plus behaviour that looks wrong.

1. **A sighting loses to the subject's own home alibi.** When a listener hears that X was seen out on a night and also holds X's "I was home that night":
   - **teller trusted at 0.5:** the result is exactly the alibi's effect. The sighting is dropped.
   - **teller trusted at 0.8** (the game caps the sighting's weight at 1.1): neither counts. The result is the baseline.

   It held for every pair tested, at both sizes, and through the game's own refresh. A Poisoner seen out by a trusted teller rises +0.256 on the sighting alone; add her false alibi and she's back to 0. Contradicting evidence should hurt the person whose story fails. **Looks like a bug**; not changed here.
2. **A false home alibi clears an evil person a lot,** by 0.14–0.18 in a seven-person town. Trusting the alibi-giver *less* clears them *more* (−0.176 at 0.4 against −0.142 at 0.8), which looks backwards. Worth a look alongside finding 1.
3. **Clerk, Registrar, Monitor, Executor and Martyr readings barely move the people they name.** Five different gifts give identical numbers, and the step on the people they name is under 0.01. Their whole effect is on the reader, whose checkable reading makes their claim credible. Some of this is expected: a Clerk's "one of A or B holds gift G" says little before anyone claims G, and most Executor entries are "I'm assigned to X". But a Registrar "yes" or a Monitor role read should move their subject. This matches the old playtest 37291 note: role-table readings act only through the role check, and applied to both sides they cancel.
4. **The Seer is weak, and that's the Red Herring working.** 36 of 85 Seer "yes" readings were false, from the Red Herring or the Marked. The solver rightly gives a "yes" only +0.055 on the pair, and a "no" clears by 0.046. The judged pass said "no: strong; yes: moderate". Measured, it's negligible to weak until several readings overlap (+0.099 for all of a Seer's readings). That's a design question, not a bug: is a 40% false "yes" what the Seer should feel like?
5. **The Archivist pushes both people it names** by about +0.15–0.18, the good one included. Net separation is small (+0.011 at 7, +0.046 at 10) until one of the pair is cleared. The judged pass called it strong. It's strong only with a partner.
6. **Inert alone, as judged:** the Augur, Psychologist, Lamplighter, Sexton and Medium (at 7) only show the role claim's tiny effect (about +0.008). The Augur needs that day's sightings, the Psychologist needs both statements held, and the Lamplighter's count names nobody. The Medium does better at 10 (+0.063, biggest move 0.43), when the dead had more to tell.
7. **Traces are weaker than judged.** Presented alone they move nobody. With everyone's work and haunt cards they reach about +0.03 on the Demon, and less at 10. The judged "moderate per trace" was too high, at least for the "locations" family and a listener without the Demon's evening whereabouts.
8. **The strongest single pieces are physical and public:** a Demon victim (−0.60 on the victim, +0.19 separation), dropped belongings (+0.20 on an evil owner), a trusted night sighting of an evil person (+0.20), and the Gravedigger (+0.19 separation, +0.50 on the named person at 10).
9. **Role claims alone move nothing** (about −0.008). A clash raises both claimants by +0.15 to +0.19, the true holder included. Net separation is small (+0.03): the listener can't tell which claimant is lying.
10. **Repetition matters more than any one reading.** All of a Dowser's or Magistrate's readings by day 3 reach +0.26 separation, against +0.09 to +0.11 for one. The same holds for the Registrar (+0.20), Confessor (+0.19) and Executor (+0.16).
11. **Being seen out at night barely hurts a good person,** and often helps a little (−0.02 to −0.03), when the sighting puts them away from the murder.

## What this changes in the catalog

The summary table in `docs/evidence_catalog.md` now carries a measured column. Judged strengths stay as written, with corrections where the two disagree: the Seer, Archivist, traces, role-table readings and the alibi interaction.

## Not measured here

- **Not measured:** vigils, quiet nights, scorched sigils, the Town Hall, the totem and curse, gift hints, secret confessions, refusals, votes, profile context alone, and the player's premises and challenges. Each needs a played action (a vigil, a Town Hall visit) or a filed case that the passive harness doesn't make. Gift hints and secrets that NPCs pass on in gossip go only into the listener's hearsay or known-secrets list, never the ledger the belief model reads, so in gossip they have **no effect on NPC beliefs**. Only a player-presented hint or confession acts.
- **The day log** (the Whereabouts solver's evidence) needs a watched day, which passive play doesn't produce.
- **Hexer kills:** not separated out. The Hexer runs measure the same evidence with a Hexer possible.

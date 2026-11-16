# Ability-less Breathstealer sweep (Nov 15)

Claude-Bailiff. Michael asked: how does a Minion with no ability do, compared with the Breathstealer?

**Setup.** Branch `mock/inert-breathstealer` (88d22cb, on 9b2ca88; not for main) leaves the Breathstealer to be dealt and played as usual, with its team knowledge, bluffs and votes. It never silences and never hunts. Only Breathstealer deals were played. Every other deal plays out the same as in Tally's run 43575857218, so those were skipped.
- Run: `43757505923`, results on `sweep-results/run-43757505923`.
- Seeds: 100000–100999, connections off.
- Comparison: paired seed for seed against Tally's runs 43575847733 (pre-hunt, 5ac25ab) and 43575857218 (hunt, main).

## Good wins on Breathstealer deals

| Cell | Deals | Pre-hunt | Hunt (main) | No ability | No ability − hunt (paired, discordant) | z | Other deals |
|---|---|---|---|---|---|---|---|
| 7 bot | 219 | 78.1% | 80.4% | 65.3% | −15.1 (20 / 53) | −3.9 | 61.7% |
| 7 passive | 219 | 62.6% | 60.7% | 51.1% | −9.6 (26 / 47) | −2.5 | 36.5% |
| 10 bot | 439 | 74.9% | 74.3% | 64.0% | −10.3 (52 / 97) | −3.7 | 53.7% |
| 10 passive | 441 | 54.6% | 59.2% | 40.4% | −18.8 (42 / 125) | −6.4 | 27.5% |

## Where the difference comes from (per game, hunt → no ability)

| Cell | Good hanged | Evil hanged | Breathstealer hanged | Demon hanged |
|---|---|---|---|---|
| 7 bot | 0.32 → 0.70 | 1.41 → 1.08 | 60% → 43% | 80% → 65% |
| 7 passive | 0.51 → 0.70 | 1.13 → 0.89 | 52% → 37% | 61% → 51% |
| 10 bot | 0.71 → 0.97 | 1.81 → 1.60 | 52% → 40% | 78% → 70% |
| 10 passive | 0.92 → 1.33 | 1.68 → 1.26 | 51% → 37% | 61% → 46% |

## Reading

- **The silence is a net gift to good,** worth 10–19 points. Without it, evil does better on every measure. The Breathstealer is hanged 12–15 points less often, the Demon 8–15 points less, and more good people are hanged in their place.
- **Silencing exposes the Breathstealer.** It tells the town someone on that block did it, and the town hangs it far more often over the following days.
  - Tally's "top suspect at the silencing meeting" measure doesn't show this, so the case presumably builds over the days after the silencing.
  - Hanging the Minion then helps toward the Demon.
- **A Breathstealer with no ability still sits 4–14 points above other deals.** The other Minions' abilities help evil, so dealing any blank Minion in their place favours good.

## Follow-up: the "silenced, so likely good" factor

**What the solver does now.** Each silencing multiplies the odds that the silenced person is evil by 0.66 (`PublicEvidence.factors`; 30% → 22%). The circumstantial reference pool also leaves silenced people out. The ability only ever targets the living good, so in truth a silenced person is always good.

**The test.** Branch `mock/silence-no-boost` (d83e90f) silences and hunts as on main, but the factor is 1 and silenced people stay in the reference pool.
- Run: `43773681066`, same seeds, paired.
- One 10-bot timeout (seed 100632), dropped.

| Cell | Hunt (main) | No boost | No ability | No boost − hunt (discordant, z) | Share of the gap | Good hanged (hunt / no boost / none) | Breathstealer hanged (same order) |
|---|---|---|---|---|---|---|---|
| 7 bot | 80.4% | 80.4% | 65.3% | 0.0 (13 / 13, z 0.0) | 0% | 0.32 / 0.38 / 0.70 | 60 / 58 / 43% |
| 7 passive | 60.7% | 59.8% | 51.1% | −0.9 (12 / 14, z −0.4) | ~10% | 0.51 / 0.55 / 0.70 | 52 / 50 / 37% |
| 10 bot | 74.0% | 69.5% | 63.8% | −4.6 (37 / 57, z −2.1) | ~45% | 0.71 / 0.79 / 0.98 | 52 / 55 / 39% |
| 10 passive | 59.2% | 51.2% | 40.4% | −7.9 (26 / 61, z −3.8) | ~40% | 0.92 / 1.05 / 1.33 | 51 / 44 / 37% |

**Reading.**
- **At 7 NPCs, the boost does almost nothing.** Barely any game changes, and the whole gap is the Breathstealer giving itself away.
- **At 10 NPCs, the boost is about 40–45% of the gap.** Games run longer with more silences, and a trusted silenced person matters more in a bigger town.
- **Without the boost, the Breathstealer is still hanged far more than with no ability.** Exposure stays the larger effect everywhere.

## Follow-up 2: no trail, and silences that last (10-NPC bot only)

Michael asked for two more versions, on the same 439 paired Breathstealer deals.
- **Remote** (`mock/breath-remote`, run `43791458383`):
  - Each night it picks its preferred target (the most dangerous good person) from anywhere in town. It silences them at the next meeting, with no hunting and no shared block.
  - The town's presence reasoning (`DayPresence.breath_factor`) and the circumstantial silencing links are off, so a silence leaves no trail.
  - The "silenced, so likely good" boost stays on.
  - It silences on every living day, against about 90% for the hunt.
- **Lasting** (`mock/breath-lasting`, run `43791460944`): as on main, but no silence ends while an evil Breathstealer lives. All of them end at the evening after it dies.

| Version | Good wins | vs hunt (discordant, z) | Good hanged | Evil hanged | Breathstealer hanged | Demon hanged | Silencings / game |
|---|---|---|---|---|---|---|---|
| Hunt (main) | 74.0% | — | 0.71 | 1.81 | 52% | 77% | 2.84 |
| No boost | 69.5% | −4.6 (37 / 57, −2.1) | 0.79 | 1.83 | 55% | 73% | 2.90 |
| Remote, no trail | 70.6% | −3.4 (56 / 71, −1.3) | 0.82 | 1.68 | 42% | 74% | 3.16 |
| Lasting | 71.8% | −2.3 (52 / 62, −0.9) | 0.80 | 1.81 | 52% | 76% | 2.68 |
| No ability | 63.8% | −10.3 (52 / 97, −3.7) | 0.98 | 1.59 | 39% | 70% | 0 |

**Reading (10-NPC bot).**
- **Hiding the trail works on hangings, not on wins.** The remote Breathstealer is hanged about as rarely as one with no ability (42% against 39%). Good still wins 70.6%, seven points above no ability.
  - So at 10-NPC bot the trail is worth about 3 points to good, the boost about 5, and the rest about 2.
  - This corrects the reading above: the exposure shows in who gets hanged more than in who wins.
- **Lasting silences barely help evil.** Victims pile up, yet the result is −2.3 and within noise.
- **The bigger finding is that taking a voice away hardly costs good.** Even with no trail and every silence permanent, no version gets near the no-ability result.
- **A likely reason:** a silenced person keeps their vote, and what they knew has usually spread by talk already. The bot player also does much of the deducing in bot games, so passive games may weigh a lost voice more; they weren't run here.

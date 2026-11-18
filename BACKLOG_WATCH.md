# Demonologist backlog: watching

Items with no change planned, kept in view, and knobs: balancing tools to reach for only if
needed. Split out of [BACKLOG.md](BACKLOG.md) on Nov 18, 2026 (Michael). Each keeps its
original wording and its section heading from BACKLOG.md. An item that needs work moves back
to BACKLOG.md with a new tag.

Tags: **[watch]** = no change, keep an eye on it; **[knob]** = not planned, a balancing tool
to reach for only if needed.

## From "Numbers"

- **Offer trust** (+0.03 offer, +0.06 kept, −0.15 broken): first guesses, tune from play.
  [watch]

## From "Exploration"

- **Occasional free arrival search.** Sometimes grant a free ordinary search when moving
  to a new location. Exclude evidence searches; limit per location and phase so
  revisiting can't farm free actions. (Oct 21) [knob]

## From "Tentative social tuning (Oct 20–21 discussion)"

- **Diminishing trust changes near extremes.** Keep a normal band of 0.30–0.70; soften
  further losses below 0.30 and further gains above 0.70, with recovery toward the middle
  at normal strength. Review permanent grief and confidence caps separately. [knob]

- **Fewer trust penalties for presenting evidence.** Reserve most trust loss for
  nominations, votes and other direct offences rather than merely offering evidence; keep
  consequences for intrusive pressure and betrayed confidences. (Oct 21) [knob]

- **Martyr urgency.** Lower the Martyr's commitment threshold (0.62) from Day 3 on, with a
  floor, keeping candidate preferences and the option to refuse when everyone looks deeply
  suspicious. Decrement and floor open. [tentative]
  Michael (Nov 18): in his playtests the Martyr acts early, maybe too early; watch, possibly
  the other way. **[watch]**

## From "Performance"

- **Late-game meeting and presenting cost.** Budget (user's machine): meeting entry and
  presenting about 2 s or less, nominations under 1 s. The connections model costs more
  per refresh than the earlier one, and its per-listener cache (#151) only halves it.
  Lantern's profile of playtests 44542 and 97626 (Nov 14): late presentations 4–7 s,
  nights 11–21 s. What remains is sets judged for the first time (new cards, and
  everything at dawn), at 9–25 ms each with no single dominant part. Ideas, not built:
  judge single cards for all listeners from one world table a day; spread dawn's refreshes
  over the night screen; skip core tests whose cards and seed didn't change.
  `tools/replay_log.gd --time` and `--profile` show what each command cost. A background
  thread would
  need a thread-safety pass over the solver's static caches first. Port
  `workshop/reason_attribution.gd` to C# (slice C4) only if profiling shows attribution
  above about 150 ms in late meetings. [open]

## From "4. Major structural work (a week or more; design first)"

- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]

- **Dead NPCs:** no ghost votes for now; keep the door open (a final-day Séance vote).
  [watch]

## From "Workshop gaps (NYI)"

- **Succession breaks earlier clears.** A Seer "no" speaks for the Demon only as of that
  night. If a hanging with 5+ alive (so a Scion could rise) falls between two readings,
  "X became the Demon afterwards" must stay an explanation. NPC reasoning and the bot
  should apply the same limit to old clears. Check the shared model handles this.
  (Astra, 55774) [watch]

## From "5. From the Nov 13 playtest triage (moved Nov 16)"

- **The "No new info" note's limits** (triage 5.2, #154): a bigger case on a later day
  that replaces an earlier one gets no note even if its extra cards add little; "Adds no
  new belief, but still presses X" shows only from 0.15 pressure; the "settled" note has
  no test (the fixture has no settled person). **[watch]**

## From "6. The connections model: open items"

- **Whole reversals against the earlier model's beliefs.** Greta on Odette (seed 929,
  0.88 → 0.04) is traced: the earlier model's attention left out the two cards that clear
  Odette. The others, and day 3 of the same game going the other way, aren't. **[watch]**

- **NPC nominators' cases:** no faster fade or cap. Revisit if up to nine live cases per
  listener shows up as a problem in play (Nov 11). **[watch]**

# Playtest brief (for a fresh thread)

Written Oct 30, 2026. The game is `main` at `d5b8c23` or later. Pull it, then run Godot once with `--import`, since the new portrait art isn't loaded until it's imported. As before, Claude drives and the user is at the controls.

## What changed since the last playtest (37291), and what to watch

- **How NPCs read evidence.**
  - Starting suspicion no longer outweighs readings: the relative prior, `PRIOR_K` 1.5.
  - The model scores every reading the NPC holds.
  - Low-Insight NPCs take strong evil readings at their word: the headline (Seer "yes", Archivist, Dowser counts).
  - **Watch:** do holders act on their own readings, and do dull NPCs over-follow fake readings?
- **Trust in you is now two numbers.**
  - **Rapport** (disclosure, requests, confidences) recovers from slights overnight. Grief doesn't.
  - **Credibility** (how much your word counts) follows your track record: whether the NPC's own evidence later agrees with what you argued. The developer case summary (grimoire) shows both.
  - **Watch:** does arguing a correct case early pay off later, and do old slights stop mattering after a couple of nights?
- **Social changes.**
  - Friend and rival bonds no longer seed suspicion.
  - Privacy no longer sets starting rapport.
  - Low-Gossip NPCs share one thing instead of nothing.
  - Disclosure mood is one roll per NPC per day.
  - Secret-keeping gratitude shrinks each night.
  - Gossip only builds trust when believed.
  - A surviving nominee resents yes voters, and accusers lose the target's trust.
  - No grief over a hanged friend the mourner already believed was evil.
  - Confidence only resists moves against an NPC's existing lean.
  - Paranoia drift is gone; the vote bar drops 0.02 per death instead.
- **Warden credit.** After a quiet night, a Warden believes they saved whoever they guarded. They warm to that person, tell them if they trust them, and say so in their guard statements.
  - **Watch:** does it show up in dialogue, and does it make the protectee look good?
- **Traces.** Crime scenes now leave only location traces (work and haunt spots). The new trace solver panel is in the Workshop.
- **Presentation.** Expression portraits and paced text in daytime conversations.

## Known issues to keep an eye on (from the Oct 30 bot runs, 25 games each)

- **The town hangs good people:** about 62% of executions.
- **Yes votes barely tell good from evil:** about 60% yes on evil nominees, about 40% on good ones.
- **An identified Demon often isn't hanged:** about half the games the bot identified the Demon, it still lost.
- **The bot's games show shared-model fallbacks** (the `legacy=` count is non-zero). Note any "couldn't follow" or fallback lines.
- **The full test suite hasn't been run since the Oct 30 merges.**

## Useful references

- `docs/social_trust_pass.md`: the spec plus as-built notes for phases 1 to 3.
- `docs/legacy_retirement_plan.md`: retiring the old belief system, which still needs decisions.
- `claude/status-2026-10-30.md` in this Project.

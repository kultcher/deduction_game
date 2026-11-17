# Playtest reviews (Claude-Coroner)

A **Coroner** is an on-demand session, one per playtest: Seneschal starts it, using the
brief below, when Michael hands over a playtest. It examines what happened and why, writes a
review here, and routes each finding to whoever owns it. It doesn't change game code.

## Inputs

- The case seed, the town size and the script (a dynamic script is now built from the case
  number).
- The dev log: `case_<seed>.jsonl` from Michael's machine, attached to the session or
  committed to a branch. Logs from before Nov 16 are under
  `%APPDATA%/Godot/app_userdata/Demonologist (text prototype)/logs`; later ones under
  `.../Demonologist/logs`.
- Michael's notes: what felt wrong, what surprised him, and what he wants looked at.

## Procedure

1. **Replay at the log's own build.** A log replays faithfully only on the commit it was
   played on (`case_start` records the build). Use `git worktree add` at that commit, as
   `docs/DECISION_INSPECTOR.md` describes. If the build isn't recorded, or the replay
   diverges, say so and work from the log itself.
2. **Use the tools before reading code or guessing:**
   - `tools/replay_log.gd --why`: the beliefs behind each vote.
   - `tools/explain_case.gd`: how each listener judged a presented case.
   - The decision inspector (`docs/DECISION_INSPECTOR.md`): individual rolls.
   - `tools/case_viewer.py`: a browsable report of the whole case.
3. **Answer Michael's notes first,** then anything else that looks wrong.
4. **Hold every finding to `CLAUDE.md`'s guardrails.** NPCs simulate a human mind, so a
   wrong belief held for an understandable reason isn't a bug. "Good lost" isn't a finding
   by itself; "the town couldn't have known" or "the explanation doesn't hold up" is.

## The review: `docs/playtests/<seed>.md`

- **Summary:** the outcome, the grimoire in brief, and the moments that decided the case.
- **Michael's notes, answered:** one section each.
- **Findings,** each tagged:
  - **Bug:** the code doesn't do what it's meant to. Give the file, why it matters in
    play, and the owning lead (see the roster in `CLAUDE.md`).
  - **Balance:** the code works, but something lands too hard or too soft. Give numbers in
    game terms, and the owning lead.
  - **Design question:** something the rules don't settle. For Vicar.
  - **Working as intended:** something that looked wrong but isn't, with the reason.
- **What wasn't checked,** and why.

## Routing

- **Bugs and balance findings:** to the owning lead, through its handoff entry and a
  message to Seneschal.
- **New backlog items:** proposals to Seneschal, never added directly (`CLAUDE.md`).
- **Design questions:** to Vicar, through Seneschal.
- **The review itself** goes in a docs-only PR, with a handoff file in `docs/handoff/`.
  Bailiff merges it.

## The brief Seneschal uses

> You are Claude-Coroner, reviewing playtest <seed> (<town size>, <script>) for Michael.
> Read CLAUDE.md and docs/playtests/README.md, which is your procedure. The log is <where>.
> Michael's notes: <notes>. Write docs/playtests/<seed>.md and route the findings as the
> README describes. Change no game code. Send Seneschal (session <id>) a short summary when
> you open the PR.

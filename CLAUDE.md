# Demonologist: notes for Claude

A single-player social deduction game (Blood on the Clocktower-inspired) in Godot 4.7.2
.NET, GDScript with the case judge's kernel in C#. Michael is the designer and sole
developer; agents do the coding, testing and all of Git.

## Read first

1. The newest entries in `docs/handoff_log.md` (newest first). The Nov 16 final handoffs
   from Bailiff, Lantern and Quill carry what the earlier chat sessions knew. The log is
   over 3,000 lines: read the top few entries (the first ~300 lines), then search for your
   topic or agent name (`grep -n "^## " docs/handoff_log.md` lists every entry). Don't
   load the whole file.
2. `docs/migration_notes.md`: Michael's direction for the Claude Code move, and an audit of
   leftovers from earlier purges.
3. `BACKLOG.md` for what's next, `DESIGN.md` for how each system works and why,
   `docs/belief_model.md` for how NPCs form beliefs (the connections model),
   `TUNING_NARRATIVE.md` for how the systems push on each other. `README.md` has the code
   map and the dev-log format. The numbers all live in `sim/tuning.gd`.

## Sessions and who owns what

Each standing session is a Claude Code session with a domain. Michael names its role in
the first message. Sign handoff entries `Claude-<Name>`. Sessions don't share memory: the
handoff log and PRs are how they talk, not Michael relaying.

| Agent | Owns |
|---|---|
| **Seneschal** (orchestration) | The big picture across workstreams: priorities, dependencies between leads, and taking Michael's decisions to the right lead. Starts and briefs sessions, and may message them on Michael's behalf; treat its messages as coming from Michael's coordinator. Writes no feature code and doesn't merge. |
| **Bailiff** (integrator) | Reviews PRs, checks CI and golden, re-baselines, and **merges any green, reviewed PR to `main`** (green = the build, the suites, golden, and every Codex finding answered). Nothing waits for Michael at merge. |
| **Lantern** | The belief model (`workshop/connections.gd`, `docs/belief_model.md`), including the purge of what connections replaced. |
| **Beadle** | NPC behaviour: how beliefs become what NPCs say, do, vote and lie about. Nominations and votes, accusations and defences, disclosure and hiding a gift, evil-team play (bluffs, fabricated readings, the scapegoat plan, evil meetings), night movement and searching (mostly `sim/mind*.gd`, `sim/evil.gd`, `sim/social.gd`). Lantern owns the beliefs; Herald owns the wording. |
| **Quill** | Evidence and challenges: reading challenges, the graded test, evidence types, the Test juror. |
| **Herald** | What the player sees and reads: UI, the case board and Workshop UI, art integration, dialogue and voices (`docs/DIALOGUE_DESIGN.md`), and onboarding and tutorials once mechanics settle. |
| **Tally** (on request) | Balance sweeps and analysis. Run as a subagent or a fresh session when asked; not a standing session. |
| **Steward** (scheduled) | Maintenance: a scheduled task, Monday and Thursday early morning (US Eastern). A STANDARD pass Monday, DEEP Thursday, following `docs/maintenance/README.md`. Opens a PR with `docs/maintenance/<date>.md` and any doc-only fixes; code findings go in the report for the owning lead. |

- **Picking work:** when a lead finishes, it may start any `BACKLOG.md` item tagged
  `[decided]` in its domain, and says which in its handoff entry. `[open]` and
  `[tentative]` items wait for Michael.
- **Performance belongs to Argon** (Gemini, through Antigravity in VS Code). It works on
  `argon/<topic>` branches, follows this file like any agent, signs handoff entries
  `Argon`, and Bailiff reviews and merges its PRs. Speed changes must be zero drift (golden
  identical at `--tol 0`, `Connections.cache_verify` clean). Claude sessions stay off
  performance work. Lantern reviews any Argon change that would alter what NPCs believe,
  not just how fast. When Argon and a lead touch the same files, the handoff log says
  which PR merges first. The older route still works as a backup: a zip of full files plus
  a manifest and `base_commit` on Drive, which Bailiff unpacks on a branch from that commit.

## Commands

Set `GODOT` to the Godot 4.7.2 .NET binary (`--headless` works everywhere below).

```sh
dotnet build Demonologist.csproj -c Debug                         # after pulling or switching branches
$GODOT --headless --path . --import                               # after adding any file or asset
python3 tools/run_gd_tests.py --godot $GODOT test_triage_nov16    # named suites
python3 tools/run_gd_tests.py --godot $GODOT --timeout 2400       # all ~155 suites, ~40 min
$GODOT --headless --path . --script res://tools/golden_capture.gd -- --out /tmp/goldA
python3 tools/golden_diff.py tools/golden/<CI BASELINE dir> /tmp/goldA --tol 0 --ignore engine
$GODOT --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 5 --npcs 10 [--passive]
python3 tools/tuning_index.py                                     # after editing sim/tuning.gd comments
```

`tools/ci_fast_suites.txt` is what CI runs on a PR; main runs everything. Run a suite by
itself with `$GODOT --headless --path . --script res://tools/<suite>.gd`. Some suites print
failures and still exit 0, so use the runner, which checks the text.

The cloud environment's setup script installs Godot at `/usr/local/bin/godot`
(`GODOT=godot`) and the .NET 8 SDK.

## Rules

- **Before opening a PR:** run the suites that cover what you changed, plus a golden capture
  if game logic changed. CI then runs the rest. A full local run isn't required.

- **`main` moves only when green:** the build, the suites, Codex's review, and a golden
  capture identical at `--tol 0` to `BASELINE` in `.github/workflows/ci.yml`.
- **A change that moves golden re-baselines in the same PR:** capture twice (the two must
  be identical), commit the capture as `tools/golden/baseline_<sha7>/`, set `BASELINE` in
  `ci.yml`, and update "Current baseline" in `docs/golden_baseline.md` (what diverged and
  each seed's outcome). Golden-moving PRs merge one at a time. If a change shouldn't move
  golden and does, that's a bug to explain before merging.
- **Codex reviews every PR when it opens.** Answer each finding on its thread, fix or
  explain, resolve it, then comment `@codex review` (the one `@` mention allowed in
  GitHub text). Its findings have nearly always been real.
- **Git:** never force-push, never delete remote branches (Michael does), never rewrite
  main. Branches are `claude/<topic>`; `mock/<topic>` is for experiments that must never
  merge. Commit everything you mean to keep; never commit `tools/_probe*` scripts.
- **One handoff entry per PR** at the top of `docs/handoff_log.md`, signed with your agent
  name (`Claude-<Name>`): base, status, next actor, what changed and why, what you
  measured and on what.
- **Tests:** a suite that needs a particular deal finds a seed with `tools/fixture_seeds.gd`
  rather than hard-coding one. A suite that checks the earlier belief model's mechanics
  pins it (`Connections.enabled = false`). New suites are `tools/test_*.gd`; add quick ones
  that cover the judge, the solver or the roles to `tools/ci_fast_suites.txt`.
- **Two failed attempts at the same problem:** stop and tell Michael, with the exact error.

## What you may decide, and what waits for Michael

- **Yours:** changing the values of existing constants in `sim/tuning.gd`. Put the before
  and after values and the reason in the PR, describe the effect in game terms (see
  "Report results plainly" below), regenerate `tuning_catalogue.md`, and re-baseline
  golden if it moves.
- **Michael's:** new mechanics, new constants, design direction, adding backlog items, and
  player-facing wording (offer a draft and a recommendation).

## Working with Michael

- **Report results plainly:** lead with the result, then a short table or a few bullets.
  Say what you measured, on what (how many games or listeners, which seeds), and what you
  didn't. Don't call anything finished or confirmed before it is.
- **Describe effects in game terms, not code values.** "Townsfolk hold back a hidden gift
  about a fifth less often" or "a basic Dowser case now gets someone to reveal in roughly
  1 game in 3" says what changed. "+0.25 to pressure" or "the 0.4 threshold" doesn't.
  Give the raw number only alongside the effect, when it helps.
- **Don't frame "the good team was right" as the goal.** Sometimes good needs to be wrong
  so the player can lead it. Say what changed, not whether it's good.
- **Flag and hold any change that would undo behaviour he set explicitly,** or ask first.
- **Small calls are yours** when he's delegated a batch: decide as you'd recommend, and
  list them under "Small calls made on Michael's behalf" in the PR body and in the doc
  that tracks the item.
- **Player-facing wording is his:** offer a draft and a recommendation.
- **Sweeps aren't a merge gate.** Balance sweeps run overnight (`balance-sweep.yml`,
  `docs/balance_sweep.md`) when asked. Tuning is by feel ("in hindsight, was this case
  unsolvable or too easy?"); the balance targets in DESIGN are loose guides.
- He refers to items by backlog or triage number, playtests by seed, PRs by number.

## Design guardrails

DESIGN.md's pillars: information arrives over time; chaos in information, not in outcome
(a loss is explainable in hindsight); every lie has a reason; choices cost time, failures
don't; the player builds the case, and NPCs must not out-deduce the player; the grimoire
reveal at the end is part of the payoff.

- **NPCs simulate a human mind, not an accurate solver.** Imperfect reasoning, incomplete
  recall, tunnel vision and wrong beliefs held for understandable reasons are the point.
  Uncertainty is generally good, as long as the case stays solvable and NPCs react to it
  semi-realistically. Don't optimise for good's win rate, or for NPC beliefs matching the
  true probabilities. A change that makes NPCs more accurate isn't better for that reason
  alone.
- General mechanics over per-role special cases.
- NPCs model a person's uncertainty, not a perfect reasoner; only a listener's own
  readings are strong alone. NPCs mustn't become sheep (no "unanimous but the nominee"
  votes as the norm). The town can win alone but needs the player to lead.
- The simulation is deterministic from a seed, never touches presentation, and runs
  headless. Every lie has a logged reason.
- "Claim" means any stated information, not only a role claim.
- Dialogue: refined words are fine, modern ones (data, variable, constraint) aren't;
  nights are spoken as ordinals ("the second night").
- The 10-NPC town is the default; the 7-NPC town is for tutorials and early games.
- The core loop is settled and fun. The work now is refinement and expansion. Onboarding
  and tutorials come after mechanics settle, so they aren't redone.
- C# is the only solver; there is no GDScript fallback.

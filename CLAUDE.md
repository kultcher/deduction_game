# Demonologist: notes for Claude

A single-player social deduction game (Blood on the Clocktower-inspired) in Godot 4.7.2
.NET, GDScript with the case judge's kernel in C#. Michael is the designer and sole
developer; agents do the coding, testing and all of Git.

## Read first

1. The newest entries in `docs/handoff_log.md` (newest first). The Nov 16 final handoffs
   from Bailiff, Lantern and Quill carry what the earlier chat sessions knew.
2. `docs/migration_notes.md`: Michael's direction for the Claude Code move, and an audit of
   leftovers from earlier purges.
3. `BACKLOG.md` for what's next, `DESIGN.md` for how each system works and why,
   `docs/belief_model.md` for how NPCs form beliefs (the connections model),
   `TUNING_NARRATIVE.md` for how the systems push on each other. `README.md` has the code
   map and the dev-log format. The numbers all live in `sim/tuning.gd`.

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

## Rules

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

## Working with Michael

- **Report results plainly:** lead with the result, then a short table or a few bullets.
  Say what you measured, on what, and what you didn't. Don't call anything finished or
  confirmed before it is.
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

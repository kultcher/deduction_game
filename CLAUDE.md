# Demonologist: notes for Claude

A single-player social deduction game (Blood on the Clocktower-inspired) in Godot 4.7.2
.NET, GDScript with the case judge's kernel in C#. Michael is the designer and sole
developer; agents do the coding, testing and all of Git.

## Read first

1. The newest handoff entries in `docs/handoff/`, one file per entry, named
   `<YYYY-MM-DD-HHMM>-<agent>-<topic>.md` so they sort by time
   (`ls docs/handoff | sort -r | head` lists the newest). Read the newest few, then search
   for your topic or agent name. Entries before Nov 17 are in `docs/handoff_log.md`, which
   is frozen; the Nov 16 final handoffs from Bailiff, Lantern and Quill there carry what
   the earlier chat sessions knew. It's over 3,000 lines: read its top entries or search
   it, but don't load the whole file.
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
| **Limner** (visuals) | Visual art and effects: shaders, portrait art treatment (the line boil, `docs/line_boil.md`), animation, and the art pipeline and its tools. Presentation only: never touches the simulation, and golden stays identical. Herald keeps the UI, layout and wiring screens together; Limner coordinates with Herald wherever its work lands in a UI scene. Keeps shaders cheap and says what they cost (speed belongs to Argon). |
| **Vicar** (design) | Design discussion, brainstorming and documentation, with Michael directly. **Writes no game code.** Owns `DESIGN.md` (its shape and design reasoning; leads still update docs for what they build) and design notes under `docs/design/` (proposals, explorations, options awaiting a decision). Records Michael's decisions, dated, and tells Seneschal which lead should build them. |
| **Coroner** (per playtest) | Playtest review: one fresh session per playtest, started by Seneschal. Replays the log at its own build, explains the decisive moments, and writes `docs/playtests/<seed>.md`, following `docs/playtests/README.md`. Routes bugs and balance findings to the owning lead, proposals to Seneschal, design questions to Vicar. Changes no game code. |
| **Tally** (on request) | Balance sweeps and analysis. Run as a subagent or a fresh session when asked; not a standing session. |
| **Steward** (scheduled) | Maintenance: a scheduled task, Monday and Thursday early morning (US Eastern). A STANDARD pass Monday, DEEP Thursday, following `docs/maintenance/README.md`. Opens a PR with `docs/maintenance/<date>.md` and any doc-only fixes; code findings go in the report for the owning lead. |

- **Picking work:** when a lead finishes, it may start any `BACKLOG.md` item tagged
  `[decided]` in its domain, and says which in its handoff entry. `[open]` and
  `[tentative]` items wait for Michael.
- **New backlog items are proposed, never added.** Don't edit `BACKLOG.md` to add an item,
  even as `[open]`. Send the proposal to Seneschal (a short title, what you saw and where,
  and a suggested tag and owner) and list it under "Proposed for the backlog" in your
  handoff entry. Seneschal collects proposals and puts them to Michael, and whoever owns
  the item adds the ones he accepts. Updating or closing an existing item you worked on
  is fine.
- **Performance belongs to Argon** (Gemini, through Antigravity in VS Code). It works on
  `argon/<topic>` branches, follows this file like any agent, signs handoff entries
  `Argon`, and Bailiff reviews and merges its PRs. Speed changes must be zero drift (golden
  identical at `--tol 0`, `Connections.cache_verify` clean). Claude sessions stay off
  performance work. Lantern reviews any Argon change that would alter what NPCs believe,
  not just how fast. When Argon and a lead touch the same files, a handoff entry says
  which PR merges first. The older route still works as a backup: a zip of full files plus
  a manifest and `base_commit` on Drive, which Bailiff unpacks on a branch from that commit.

## Commands

Set `GODOT` to the Godot 4.7.2 .NET binary (`--headless` works everywhere below).

```sh
dotnet build Demonologist.csproj -c Debug                         # after pulling or switching branches
$GODOT --headless --path . --import                               # after adding any file or asset
python3 tools/run_gd_tests.py --godot $GODOT test_beliefs test_codex_fixes  # named suites
python3 tools/run_gd_tests.py --godot $GODOT --timeout 2400       # all ~155 suites, ~40 min
$GODOT --headless --path . --script res://tools/golden_capture.gd -- --out /tmp/goldA
python3 tools/golden_diff.py tools/golden/<CI BASELINE dir> /tmp/goldA --tol 0 --ignore engine
$GODOT --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 5 --npcs 10 [--passive]
python3 tools/tuning_index.py                                     # after editing sim/tuning.gd comments
```

`tools/ci_fast_suites.txt` is what CI runs on a PR, plus `tools/ci_slow_suites.txt` when the
PR changes `sim/` or `workshop/`; main and the nightly run run everything. Run a suite by
itself with `$GODOT --headless --path . --script res://tools/<suite>.gd`. Some suites print
failures and still exit 0, so use the runner, which checks the text.

The cloud environment's setup script installs Godot at `/usr/local/bin/godot`
(`GODOT=godot`) and the .NET 8 SDK.

## Rules

- **Before opening a PR:** run the suites that cover what you changed, plus a golden capture
  if game logic changed. CI then runs the rest. A full local run isn't required.

- **`main` moves only when green:** the build, the suites, Codex's review, and a golden
  capture identical at `--tol 0` to `BASELINE` in `.github/workflows/ci.yml`.
- **Docs-only PRs** (only `.md` files, which the code doesn't read) skip CI; Bailiff still
  reviews and merges them, and they need no golden check. If you already have an open
  docs-only PR, add further docs changes to it (each with its own handoff file) rather than
  opening another. Don't add docs-only changes to a code PR that's waiting in the golden
  queue.
- **A change that moves golden re-baselines in the same PR:** capture twice (the two must
  be identical), commit the capture as `tools/golden/baseline_<sha7>/`, set `BASELINE` in
  `ci.yml`, and update "Current baseline" in `docs/golden_baseline.md` (what diverged and
  each seed's outcome). Golden-moving PRs merge one at a time. If a change shouldn't move
  golden and does, that's a bug to explain before merging.
- **Codex reviews every PR when it opens.** Answer each finding on its thread, fix or
  explain, resolve it, then comment `@codex review` (the one `@` mention allowed in
  GitHub text). Its findings have nearly always been real. A follow-up commit that changes
  only strings, docs or tests needs no new review (Michael, Nov 19).
- **How Bailiff checks a PR before merging (Michael, Nov 19):**
  - **Zero-drift and text-only PRs:** Bailiff relies on CI, with no local re-run. CI's
    golden diff and suites run on the PR merged with main.
  - **Golden-moving PRs and changes to what NPCs believe (`sim/`, `workshop/`):** Bailiff
    still runs them locally on the current main.
  - **Wording and docs PRs:** may be batched into one merge pass.
- **Git:** never force-push, never delete remote branches (Michael does), never rewrite
  main. Branches are `claude/<topic>`; `mock/<topic>` is for experiments that must never
  merge. Commit everything you mean to keep; never commit `tools/_probe*` scripts.
- **One handoff entry per PR,** as a new file in `docs/handoff/`, named
  `<YYYY-MM-DD-HHMM>-<agent>-<topic>.md` (UTC time; agent and topic in lower case, joined by
  hyphens, e.g. `2026-11-17-0530-quill-lie-severity.md`). Sign it with your agent name
  (`Claude-<Name>`): base, status, next actor, what changed and why, what you measured and
  on what. Never edit another PR's entry and never append to `docs/handoff_log.md`; a
  follow-up gets its own file. One file per entry is what keeps PRs from conflicting.
- **Tests:** a suite that needs a particular deal finds a seed with `tools/fixture_seeds.gd`
  rather than hard-coding one. New suites are `tools/test_*.gd`; add any that runs in
  under about 15 seconds to `tools/ci_fast_suites.txt`, at its alphabetical place (the list
  is kept sorted so that PRs don't all conflict on its last line). A slower suite that tests
  what NPCs do or believe can go on `tools/ci_slow_suites.txt` instead; otherwise it runs
  on main only.
- **Two failed attempts at the same problem:** stop and tell Michael, with the exact error.

## What you may decide, and what waits for Michael

- **Yours:** changing the values of existing constants in `sim/tuning.gd`. Put the before
  and after values and the reason in the PR, describe the effect in game terms (see
  "Report results plainly" below), regenerate `tuning_catalogue.md`, and re-baseline
  golden if it moves.
- **Michael's:** new mechanics, new constants, design direction, new backlog items (propose
  them through Seneschal; see "Picking work" above), and player-facing wording (offer a
  draft and a recommendation).

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

# Demonologist — text prototype

A single-player social deduction game inspired by Blood on the Clocktower. You are a
Demonologist summoned to a small town where a demon has taken a host and a Poisoner serves
it. Over several days you question townsfolk, search crime scenes, listen to gossip and
sway the town's votes, until the demon's host hangs or the town falls.

This is a **text proof of concept** built in Godot 4 (GDScript). The point is to test
whether the deduction is fun before any art exists. See [DESIGN.md](DESIGN.md) for the
design decisions so far.

## Running it

Requires Godot 4.4+ (tested with 4.4.1).

**In the editor:** open the project and press Play. A text console appears: type commands
and press Enter. Buttons along the top cover the common info screens.

**In a terminal:**

```sh
godot --headless --path . --script res://tools/cli.gd -- --seed 42
```

Options: `--seed N`, `--npcs 7`, `--log-dir DIR` (default `logs/`), `--debug`
(unlocks `grimoire` mid-game), `--echo-log` (prints every dev-log entry as it happens).

**Autoplay bot** (for testing and balance):

```sh
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 50
godot --headless --path . --script res://tools/autoplay.gd -- --seed 7 --transcript
```

The bot plays through the same command interface a human uses and prints one line per
case plus a summary (bot win rate is roughly 30–35% at the moment). `--transcript`
prints everything the player would have seen.

## How to play

Each day has three phases (morning, afternoon, evening), then a town meeting, then night.

| When | Commands |
|---|---|
| Any time | `look`, `map`, `cast`, `board [filter]`, `roles`, `help`, `log` |
| Day phase | `go <place>`, then one action: `talk <name>`, `search`, `gossip` (tavern only), `wait` |
| Talking (3 questions) | `ask gift`, `ask info`, `ask night`, `ask today`, `ask about <name>`, `tell <suspect> <card#>`, `bye` |
| Town meeting | `nominate <name>` (once), `vote <name>`, `done` |
| Night | `ward <name>`, `vigil <block>`, `sleep` |
| After the case | `grimoire`, `grimoire lies` |

Names and places accept prefixes (`talk bart`, `go tav`). Crime scenes appear as
locations (`go scene_greta`, or `go greta`).

**The case board.** Everything you learn becomes a numbered card. `tell <suspect> <card#>`
uses a card to make a case to whoever you're talking to (the "mad-libs" accusation). How
far it moves them depends on what kind of card it is, how much they believe its source,
how much they trust you, and whether the suspect is their friend. Telling your case to an
evil NPC warns the demon.

**Win:** the demon's host is executed. **Lose:** only two townsfolk remain, or day 6 ends.

## Code layout

```
sim/content.gd   static data: map, occupations, cast pool, roles, secrets
sim/npc.gd       one NPC's state (beliefs, suspicion, trust, claims, info results)
sim/world.gd     case setup, schedules, sightings, night resolution, votes, executions
sim/mind.gd      NPC reasoning: suspicion updates, claims, testimony, nominations,
                 votes, conversation answers, gossip
sim/evil.gd      evil team AI: plan, bluffs, scapegoat framing, kill/poison choice,
                 fabricated info
sim/devlog.gd    developer trace (JSONL + text)
game/game.gd     command interpreter, case board, all player-facing text
ui/main.gd       in-engine text console
tools/cli.gd     terminal frontend
tools/autoplay.gd  bot player / batch runner
tools/trace.py   dev-log filter for evaluating a playthrough
```

The simulation is deterministic for a given seed and never touches presentation, so it
can run headless for thousands of cases.

## Dev log

Every case writes `case_<seed>.jsonl` and a readable `case_<seed>.txt` (to `logs/` from the
CLI and bot, or `user://logs` from the editor; the path is printed). Each entry has
`seq, day, phase, type, actor, target, data, reason`.

Main entry types:

| type | what it records |
|---|---|
| `grimoire` | hidden setup: roles, alignments, homes, lane order, relationships, secrets, bluffs, evil plan |
| `secret_assigned` | a good NPC's personal reason to be out at night (and lie) |
| `positions`, `night_movement` | where everyone is each phase; who walked at night and why |
| `night_sighting` | who glimpsed whom at night |
| `poison`, `protect`, `protect_failed`, `kill`, `kill_failed` | night actions and outcomes |
| `info` | every ability result, with `true:false` and a `why` when it's wrong |
| `fake_info` | evil fabrications and the reasoning behind each |
| `think` | NPC reasoning, tagged by `data.topic`: `claim`, `lie`, `confess`, `vote`, `nominate`, `accuse`, `opinion`, `persuaded`, `gossip`, `seer_pick`, `watch_pick`, `warden_pick`, `kill_choice` (with every candidate's score breakdown), `poison_choice`, `scapegoat`, `evil_plan`, `evil_learns` |
| `suspicion` | every change ≥ 0.05 in one NPC's suspicion of another, with the cause |
| `trust` | changes in an NPC's trust in the player, with the cause |
| `vote_tally`, `execution`, `no_execution`, `game_over` | meeting outcomes |
| `snapshot` | per-phase table of every living NPC's location, poison, trust, claim and suspicion |
| `player_command` | each command the player typed and the full text they saw |

Every lie has a `think` entry with `topic: "lie"` explaining why (evil cover, a personal
secret, caution about revealing a gift). Filter examples:

```sh
python3 tools/trace.py logs/case_42.jsonl --lies
python3 tools/trace.py logs/case_42.jsonl --npc edda
python3 tools/trace.py logs/case_42.jsonl --suspicion edda
python3 tools/trace.py logs/case_42.jsonl --topic kill_choice --full
python3 tools/trace.py logs/case_42.jsonl --player
```

## Known gaps / next steps

- Dialogue is templated and repetitive; personality mostly affects numbers, not voice.
- Relationships only bias suspicion and votes; no relationship changes yet.
- NPCs don't talk to each other privately (only public testimony and gossip).
- The demon's view of who suspects it is approximated from internal suspicion.
- No solvability check or storyteller director yet.
- Balance is untuned: NPCs execute fairly readily, and games can end by day 3.

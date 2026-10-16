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
and press Enter. Buttons along the top cover the common info screens. The **Board panel**
on the right lists your cards (filterable; double-click a card to add its number to your
command) and a quick profile. **Case view** opens a full-screen board: filters (text, kind,
person, place), the card list with multi-select, the timeline grid (who was where, by
phase; bright = you saw it, dim = you were told; click a cell for its cards), profiles with
your guess, confidence and notes, and the Link / Conclude builder.

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
case plus a summary (bot win rate is roughly 30–35% at the moment), including trait
reveals, disclosure and NPC-conversation counts. `--transcript`
prints everything the player would have seen.

## How to play

Each day has three phases (morning, afternoon, evening), then a town meeting, then night.

| When | Commands |
|---|---|
| Any time | `look`, `map`, `cast`, `profile <name>`, `board [filter]`, `roles`, `tools`, `help`, `log` |
| Day phase | `go <place / block / person>`, optionally one more `go` within the same block, then one action: `talk <name>`, `search`, `gossip` (tavern only), `wait` |
| Talking (3 questions) | `ask gift`, `ask night`, `ask today`, `ask about <name or gift>`, `tell <suspect> <card#>`, `bye` |
| Approached | `accept` (talk now; uses the phase) or `decline` (any other action also declines) |
| Town meeting | `nominate <name>` (once), `wait` (let the town nominate), `done` (close the meeting, once a `wait` finds no more nominations) |
| On a nomination | `defend [card#]` or `accuse [card#]` (one statement, optionally citing a card), `clemency` (once per case), `vote yes` / `vote no` |
| Night | `ward <name>` (once per case), `vigil <block>`, `sleep` |
| Case work (any time) | `link <#> <#> [#]`, `conclude <number>` (after a link), `conclude <type> <name> [role/night/card#] [because <#> ...]`, `timeline [filter]`, `note <name> <text>`, `guess <name> <role/evil/good> [1-3]` |
| In conversation | `convince <deduction#>` (uses a question) |
| At the meeting | `present <deduction#>` (once: everyone hears it) |
| After the case | `grimoire`, `grimoire lies` |

Names and places accept prefixes (`talk bart`, `go tav`). Crime scenes appear as
locations (`go scene_greta`, or `go greta`).

**The town.** Each phase opens with a view of the town: people at work and pairs deep in
conversation are shown exactly; everyone else only by block. `go <person>` takes you to
their exact spot if you know it (working, in conversation, or visible nearby); otherwise
to a location on their block. If they turn out to be next door, `talk <name>` walks you
over using your free move. People at home can be visited: `go <person>` takes you to their
door (it still costs your action to talk). Workers can always be found
at work during their (known) shift. People in conversation can't be talked to.

**Asking about gifts.** `ask gift` answers at one of four levels depending on the NPC's
Privacy, their trust in you, pressure and the day: deny or refuse, a flavoured hint
(night sight / names / shelter), the gift itself, or the gift and its readings. Once
someone has told you something they won't pretend otherwise; if trust drops they say
they're withholding newer readings.

**Traits.** Each NPC has five traits (Privacy, Gossip, Confidence, Insight, Composure),
rolled per case from the character's baseline. You learn them gradually from conversations
and meetings; `profile <name>` shows what you know. Composure also decides whether you
notice how someone feels about you.

**The case board.** Everything you learn becomes a numbered card with an evidence class
(speech, circumstantial, concrete). `tell <suspect> <card#>` makes a case to whoever
you're talking to. How far it moves them depends on the card, its source, their Insight,
their trust in you and in the suspect, and whether they've heard it before. Telling your
case to an evil NPC warns the demon. Using someone's confessed secret against them costs
their trust, permanently for very private people.

**The town talks.** NPCs who pair off actually exchange things: a reading, a night
sighting, an opinion, a case you made to them, or a secret. Everyone remembers who told them
what. Gossips relay what they've heard; busybodies may approach you with it (including
other people's secrets). `ask about <gift>` (e.g. `ask about seer`) asks what someone
knows about that gift: who claims it, and what they've been told privately.

**Evil knows only what it could know:** public events, what each member saw or was told,
and what they pool when they meet (pairs you may see talking) or whisper in a crowded
tavern. Paranoia rises with every death: the town grows quicker to suspect and to hang.

**Building a case.** `link` checks 1–3 cards against a library of contradiction templates
(someone in two places at once; out at night vs. "I was home"; two people claiming one
gift; a watcher who missed someone; your vigil missing someone a witness put there; a
reading that flips; a Gravedigger contradicting a claim; a Veteran killed by the demon;
a reading pointing only at the demon's victims; a changed story). A match lists possible
explanations, and never says which is true. `conclude <number>` files the one you believe
as a **deduction** card. You can also conclude directly from supporting cards; a
conclusion with no contradiction behind it is marked *unfounded*, and sharp (high-Insight)
NPCs will reject it. Conclusion types: evil, demon, good, role, notrole, lied, poisoned,
protect, spare, mistaken.

NPCs weigh a deduction by scoring the same explanations from their own point of view
(whom they suspect or trust, whether an information gift could be poisoned, what they
know firsthand about where they themselves were), compared with the strongest
alternative. "X was poisoned on night N" makes them discount that reading instead of
suspecting X; "protect X" makes a Warden likelier to guard X; "spare X" lowers their vote.

**Meetings** follow Blood on the Clocktower: one nomination at a time; each person
nominates and is nominated at most once a day; a nomination reaching half the voters puts
the nominee on the block, a later one needs more votes to replace them, and a tie clears
the block. Whoever is on the block when the meeting closes is executed.

**Win:** the demon's host is executed. **Lose:** only two townsfolk remain, or day 6 ends.

## Code layout

```
sim/content.gd   static data: map, occupations and shifts, cast pool with trait baselines,
                 roles, hint packages, secrets
sim/npc.gd       one NPC's state (beliefs, suspicion, trust, claims, info results)
sim/world.gd     case setup, schedules, sightings, night resolution, votes, executions
sim/mind.gd      NPC reasoning: suspicion updates, claims, testimony, nominations,
                 votes, conversation answers, gossip
sim/evil.gd      evil team AI: plan, bluffs, scapegoat framing, kill/poison choice,
                 fabricated info
sim/devlog.gd    developer trace (JSONL + text)
game/game.gd     command interpreter, case board; emits structured events (last_events)
                 that are rendered to text
ui/main.gd       in-engine text console
tools/cli.gd     terminal frontend
tools/autoplay.gd  bot player / batch runner
tools/trace.py   dev-log filter for evaluating a playthrough
tools/test_argue.gd  unit checks for the contradiction templates and evaluation
tools/test_ui.gd     headless smoke test of the UI panels
sim/social.gd    NPC-to-NPC exchanges, approaches, role questions, paranoia
sim/argue.gd     card assertions, contradiction templates, conclusions, NPC evaluation
ui/case_view.gd  full-screen case view
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
| `grimoire` | hidden setup: roles, alignments, homes, work shifts, lane order, relationships, rolled traits and baselines, secrets, bluffs, evil plan |
| `secret_assigned` | a good NPC's personal reason to be out at night (and lie) |
| `positions`, `night_movement` | where everyone is each phase (working / busy); who walked at night and why |
| `npc_conversation` | NPC pairs (visible pre-paired or hidden post-choice; evil meetings flagged) |
| `npc_share` | what one NPC told another, the original source, whether it was relayed, and whether it was a lie |
| `evil_intel`, `evil_share` | what an evil member learned and how (own sighting, told by someone, the player's case); when members pool knowledge (first-night conference, meeting, tavern whisper) |
| `approach`, `approach_declined` | an NPC seeking out the player, with their agenda (news / frame / gossip) |
| `player_link` | cards the player linked, templates matched and near-miss reasons (unmatched links flag missing templates) |
| `deduction` | a deduction the player filed: conclusion, supports, template, unfounded or not |
| `argument` | an NPC weighing a deduction: explanation weights, agreement vs. the best alternative, quality, effect |
| `player_present` | the player taking the meeting floor |
| `night_sighting` | who glimpsed whom at night |
| `poison`, `protect`, `protect_failed`, `kill`, `kill_failed` | night actions and outcomes |
| `info` | every ability result, with `true:false` and a `why` when it's wrong |
| `fake_info` | evil fabrications and the reasoning behind each |
| `think` | NPC reasoning, tagged by `data.topic`: `claim`, `lie`, `disclosure` (tier and inputs), `deny_or_refuse`, `confess`, `lie_or_stonewall`, `stonewall`, `withhold`, `omit`, `cue`, `share_sightings`, `vote`, `nominate`, `accuse`, `opinion`, `persuaded`, `gossip`, `approach`, `about_role`, `paranoia`, `poison_belief`, `seer_pick`, `watch_pick`, `warden_pick`, `grief`, `kill_choice` (with every candidate's score breakdown), `poison_choice`, `scapegoat`, `evil_plan`, `evil_learns`. Weighted rolls log every score part and the probability |
| `suspicion` | every change ≥ 0.05 in one NPC's suspicion of another, with the cause |
| `trust`, `trust_cap` | changes in an NPC's trust in the player, and permanent caps, with the cause |
| `npc_trust` | changes in one NPC's trust in another |
| `trait_reveal` | which trait the player learned about whom |
| `nomination`, `player_statement`, `clemency`, `vote_tally`, `execution`, `no_execution`, `game_over` | meeting events (vote tallies include threshold and block state) |
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
- NPC-to-NPC trust biases suspicion, votes and who pairs off; those who trusted an executed NPC resent its nominator, yes-voters and you. NPC conversations happen but carry no content yet (stage 2).
- NPC exchanges are one item each way per conversation and aren't visible to the player except through relays, gossip and approaches.
- The demon's view of who suspects it is approximated from internal suspicion.
- No solvability check or storyteller director yet.
- Balance is untuned: NPCs execute fairly readily, and games can end by day 3.

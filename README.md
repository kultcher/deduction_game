# Demonologist — prototype

A single-player social deduction game inspired by Blood on the Clocktower. You are a
Demonologist summoned to a small town where a demon has taken a host. Minions serve it (one
of the Poisoner, Breathstealer, Revenant and Scion in a 7-person town, two in a 10-person
town), and one innocent townsperson carries a secret (Delusional, Marked, Secret Lovers or
Sleepwalker) that muddies their gift or puts them out at night. Over six days (seven
townsfolk) or eight (ten) you question townsfolk, search crime scenes, listen to gossip and
sway the town's votes, until the demon's host hangs or the town falls.

This is a proof of concept built in Godot 4 (GDScript), with a painted town screen and case
board over a deterministic simulation that also runs headless. The point is to test
whether the deduction is fun. [DESIGN.md](DESIGN.md) describes how every system works and
why; [BACKLOG.md](BACKLOG.md) is the to-do list; [TUNING.md](TUNING.md) has the social
model's numbers (it predates the shared case judge and is updated after the balance
pass). How presented cases are judged: [docs/LEGACY_MIGRATION.md](docs/LEGACY_MIGRATION.md).
This README covers running and playing.

## Running it

Requires Godot 4.7.2 (the version the project and tests use).

**In the editor:** open the project and press Play. Pick a town size (7 or 10 townsfolk)
beside the case seed in the title bar and press **New case**. Everything can be done with
the mouse; the typed prompt still works as a fallback.

- **Title bar:** day and phase, **Town** / **Case board** / **Notes** / **Roles** /
  **Help**, the case seed and town size, **New case**, **More ▾** (text cast and timeline,
  card sidebar, dev log) and **Debug**.
- **The town screen:** the painted map (top left), the townsfolk list (portrait, colour,
  claim icon, your pencilled guess, where they are when you can see them; the dead greyed),
  and the profile of whoever you click or talk to. Below, the actions for the current
  moment sit beside the log.
- **The map:** click a block to zoom in; click a place to spend the phase there, a home to
  call on whoever's in, or a crime scene (a crossed-out cottage) to search it. Clicking a
  person walks you to them and starts a conversation. At night, click a block or person to
  pick your vigil or ward. People at work or in conversation are shown wherever they are;
  everyone else only once you're on their block.
- **Actions:** buttons for what you can do now: talk, search, gossip, wait; in
  conversation, the ask menus, **Offer…** and **Present a card…**; at the meeting,
  nominate, present, wait, close; on a vote, accuse or defend (optionally citing a card),
  clemency, vote; at night, vigil, ward, sleep.
- **The meeting circle:** at the town meeting the map gives way to a ring of standees on
  the Square, with the nominee in the centre and a hand that sweeps round counting votes.
- **The log** colours every name and speech line in the speaker's ink; card numbers open
  the card on the board.
- **The profile** shows occupation, claim, trait bars and **Your guesses** (a role and a
  secret, each with a confidence), with tabs for what they've claimed and what's been said
  about them.
- **The case board** is a full screen of its own: three views (**Places & sightings**,
  **Statements**, **Process**), pan and zoom, day navigation, filter chips, and red strings
  between related cards. Overlays from the bottom-left dock (**Card List**, **Build case**,
  **Profile**, **Notes**, **Roles**) can be moved and resized. Right-click any card to add
  it to a deduction, hide it, find links or get hints. Deductions wait in a tray under the
  grid and pin to the board where you drop them.
- **The Case Workshop** (**More > Case Workshop**) is the red-string board for building
  a case: a premise, linked evidence cards with their questions answered, challenges
  (unlikely, misled, lying), a live strength label, then **File case** to get a
  presentable card. See [Building a case](#how-to-play) below.
- **Debug** shows what NPCs privately make of things (each card's influence on those who've
  heard it; how the town credits and suspects each person). Turning it on mid-case leaves
  your identification unscored.

**Dialogue lab:** open `ui/dialogue_lab.tscn` and press **F6** to compare Agnes,
Bartholomew and Constance across fifteen situations. In normal play these three voice
argument replies and nominations, with memory of what they said earlier; everyone else
uses plain lines. Votes are silent (vote talk returns with the meeting-flow work). See
[the dialogue prototype guide](docs/dialogue_prototype.md).

**In a terminal:**

```sh
godot --headless --path . --script res://tools/cli.gd -- --seed 42
godot --headless --path . --script res://tools/cli.gd -- --seed 42 --npcs 10
```

Options: `--seed N`, `--npcs 7|10` (town size, default 7), `--log-dir DIR` (default
`logs/`), `--debug` (unlocks `grimoire` mid-game), `--echo-log` (prints every dev-log
entry as it happens).

**Autoplay bot** (for testing and balance):

```sh
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1 --games 50
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --npcs 10
godot --headless --path . --script res://tools/autoplay.gd -- --seed 7 --transcript
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --passive
```

The bot plays through the same command interface a human uses, sees only what a player
sees, and prints one line per case plus a summary. `--transcript` prints everything the
player would have seen. `--passive` is the control: a player who does nothing at all
(waits every phase, declines approaches, never nominates, votes no). Compare it with the
normal bot on the same seeds to see how much the player's actions matter. `--native`
judges evidence with the legacy rules instead of the shared model, the control for A/B
runs; each game prints per-day suspicion against the truth, town agreement and every
good vote's score against its need. Chunks of 10 seeds can run in parallel. Measurements
since the shared judge are in [docs/MIGRATION_PROGRESS.md](docs/MIGRATION_PROGRESS.md);
the older legacy-rule history is in DESIGN's
[History and measurements](DESIGN.md#history-and-measurements). Seed-to-seed noise is
about ±3 games per 150.

To compare the same starting towns and keep machine-readable results:

```sh
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --log-dir logs --results logs/active.json
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --passive --log-dir logs --results logs/passive.json
python3 tools/compare_runs.py logs/active.json logs/passive.json
```

Case logs are separated into `active/` and `passive/` beneath the chosen log directory.
The comparison reports paired wins and reversals, wrongful executions per execution,
player backing/opposition, identification, innocent survivors in victories, `loss_hint`
and night stats. Only completed cases enter outcome rates. Same seeds match the starting
setup; player actions change later random draws, so a reversal alone doesn't prove an
intervention caused a loss.

**Tests:** the runner runs every `tools/test_*.gd` suite headless and checks the failure
text too (some suites print failures but exit 0):

```sh
python tools/run_gd_tests.py --godot <path to Godot 4.7.2>
python tools/run_gd_tests.py --godot <exe> --include-slow       # adds test_trace (~20 min)
python tools/run_gd_tests.py --godot <exe> test_beliefs test_case_eval
```

Known failures: `test_social` (a false Night Watch story) and `test_text_ui` (two
role-hover checks). **Speed:** `tools/replay_54875.gd` replays a playtest opening with
timings and a profile.

## How to play

Each day has three phases (morning, afternoon, evening), then a town meeting, then night.
You get one action per phase. `help` lists every command in the current build.

| When | Commands |
|---|---|
| Any time | `look`, `map`, `cast`, `profile <name>`, `board [filter]`, `timeline [filter]`, `theory`, `roles`, `tools`, `help`, `log`, `fallbacks` (dev: anything the legacy rules judged) |
| Day phase | `go <place / block / person>`, optionally one more `go` within the same block, then one action: `talk <name>`, `search`, `gossip` (tavern only), `wait` |
| Talking (3 questions) | `ask gift`, `ask are <gift>`, `ask night`, `ask seen <today / morning / afternoon / evening / yesterday [phase]>`, `ask about <name or gift>`, `ask why`, `present <card#> [for/against <name>]`, `offer ward` / `offer vigil` (free), `bye` |
| Approached | `accept` (talk now; uses the phase) or `decline` (any other action also declines) |
| Town meeting | `present <deduction#>` (once: everyone hears it), `nominate <name>` (once), `wait` (let the town nominate), `done` (close the meeting, once a `wait` finds no more nominations) |
| On a nomination | `accuse [card#]` or `defend [card#]` (one statement), `clemency` (once per case), `vote yes` / `vote no` |
| Night | `vigil <block>`, `ward <name>` (once per case), `sleep` |
| Case work (any time) | `link <#> <#> [#]`, `conclude <number>` (after a link), `conclude <name> <is / is not / should be> <status> [on night N] [because <#> ...]`, `conclude one of these is misled or lying because <#> ...`, `hide <#>`, `unhide <#>`, `showhidden`, `delete <#>` (deductions only), `note <name> <text>`, `guess <name> <role / evil / good> [1-4]` |
| After the case | `grimoire`, `grimoire lies` |

Names and places accept prefixes (`talk bart`, `go tav`). Crime scenes appear as
locations (`go scene_greta`, or `go greta`).

**Win:** the demon's host is executed. **Lose:** only two townsfolk remain, or the last day
(day 6 with seven townsfolk, day 8 with ten) ends.

**The roles.** `roles` (or the **Roles** window) lists every gift in the script, its icon
and who has claimed it. Fifteen good gifts are drawn from (Archivist, Clerk, Dowser,
Gravedigger, Lamplighter, Martyr, Medium, Night Watch, Psychologist, Rumormonger, Seer,
Sexton, Surveyor, Veteran, Warden). The minions:

- **Poisoner:** each night one person's gift fails or lies until the next night.
- **Breathstealer:** once a day silences someone on its block from that evening's meeting
  to the next; the silenced can't claim, testify, nominate or talk with you (they still
  vote).
- **Revenant:** hides a totem somewhere. Hanged with a totem hidden, it turns a good
  yes-voter evil. `search` at the totem's location burns it.
- **Scion:** becomes the demon if the demon is executed while five or more are alive.

Evil knows each other and bluffs good gifts not in play. Full rules: DESIGN
[Roles: the script](DESIGN.md#roles-the-script).

**The town.** Four blocks (the Square, the Market, the Docks, Chapel Hill), each with
one or two places and a home material (straw, soot, mud, chalk). Where everyone lives is
known from the start, and so is everyone's work shift: workers can always be found at
work. People at work or deep in conversation are visible from anywhere; anyone else only
once you pick their block. `go <person>` takes you to them if you know where they are,
otherwise to their block; people at home can be visited. People in conversation can't be
talked to. Asking someone about a person may reveal that person's haunts.

**Talking.** A conversation has three questions. `ask gift` answers at one of four levels
depending on the NPC's Privacy, their trust in you, pressure and the day: deny or refuse, a
flavoured hint at the kind of gift (night sight, shelter, the dead...), the gift itself,
or the gift and its readings. `ask are <gift>` guesses; a wrong guess costs a little
trust. Daytime questions are answered truthfully; night accounts may be lies.
`ask about <gift>` asks who claims it. `offer ward` / `offer vigil` promise to protect
or watch over them tonight: keeping the promise builds trust, breaking it costs more.

**The case board.** Everything you learn becomes a numbered card with an evidence class
(speech, circumstantial, concrete), when it happened and when you learned it. The same
fact heard twice is one card; the same fact from two witnesses is two cards that know
about each other.

**Presenting a card.** `present <card#>` is the one verb for using your board on someone
(it uses a question). The game works out what you mean: a card or deduction about the
person you're talking to **presses** them (raises the pressure and makes them answer it:
account for that night, reconsider revealing their gift, maybe confess a secret; nerves
may show); a deduction about someone else argues it; a plain card about someone else makes
a case for or against them, with the direction read from the card (a Seer "yes" accuses,
a Seer "no" clears). A card naming several people applies to all of them, split. A card
with no direction of its own falls flat ("I'm not sure what you're trying to prove"),
which costs no question. `for <name>` / `against <name>` override the reading. `press`,
`convince`, `tell` and `defend` remain as shortcuts. Using someone's confessed secret
against them costs their trust; making your case to an evil NPC warns the demon.

**Building a case.** The main way is the **Case Workshop**: pin a premise ("Greta is the
Demon", "Constance's readings can't be trusted"), link the evidence cards, answer their
questions on the card, challenge a card you think is wrong, and watch the strength label
(doesn't support / weakly / moderately / strongly). File it, then `present` it privately or
at the meeting. Every listener judges it with the same model, through their own trust,
suspicion and private knowledge; a case containing evidence the model can't read is
refused with the reason. DESIGN
[Cases and how the town judges them](DESIGN.md#cases-and-how-the-town-judges-them).

The older text route still works: `link` checks 1–3 cards against a library of templates:
contradictions (someone in two places at once, out at night vs. "I was home", two people
claiming one gift, a reading that flips...), corroborations and inferences (a Seer pair
where one person is cleared leaves the other). A match lists possible explanations and
never says which is true; `conclude <number>` files the one you believe as a
**deduction** card. Or write the conclusion yourself, e.g. `conclude jory is misled on
night 1 because #4 #7`, `conclude hollis is not the demon because #3`, `conclude edda
should be protected because #9`. Statuses: good, evil, the demon, a gift, lying,
**misled** (their information was wrong: poisoned or mistaken), misled or lying; with
"should be": protected, spared. When the cards conflict but you can't say who is wrong,
**something doesn't add up** (`conclude one of these is misled or lying because #a #b`)
makes NPCs take those people with a pinch of salt and raises the pressure on them. The
**Build case** overlay does all of this with the mouse.

**Night.** Most people stay home. Evil goes out to act, and so does anyone whose gift
chooses a place (Night Watch, the Warden at the door it guards, the Medium, the
Lamplighter) or whose secret takes them out (Lovers, Sleepwalker). Every block is joined to
every other, so a walker is seen only on their own block (leaving home) or where they went;
the Lamplighter walks every block. A vigil shows you who moves through a block. The town
weighs a night sighting by how well it fits the killer's likely route: seen near the
murder counts heavily, seen elsewhere argues strongly (not absolutely) against being the
killer, and scattered sightings can back up a walking gift. Walkers
sometimes drop something on the way: usually their home block's material, rarely a
personal item. **Searching** finds what was dropped there (and the Revenant's totem); a
crime scene gives a trace pointing to where the killer spent the evening.

**The town talks.** NPCs who pair off exchange readings, sightings, opinions, the cases you
made to them, and secrets. Gossips relay what they've heard; busybodies may approach you
with it. Evil knows only what it could know and coordinates when its members meet.
Paranoia rises with every death.

**Meetings** follow Blood on the Clocktower: testimony, then your chance to present one
deduction to everyone, then nominations one at a time. Each person nominates and is
nominated at most once a day. The nominator states their case, the nominee defends
themselves, you may accuse or defend (or spend clemency), and the town votes in seat order,
silently. Reaching half the voters puts the nominee on the block; a later nomination needs
more votes to replace them, and a tie clears the block. Whoever is on the block when the
meeting closes is executed.

**Your private theory.** Record guesses on a profile's **Your guesses**, or with
`guess <name> demon [1-4]` / `guess <name> <minion gift> [1-4]` (Flimsy / Maybe / Likely /
Confirmed). `theory` shows your current candidates. Guesses are private and free, and
snapshots before votes, executions and nights preserve what you believed before the
outcome. The ending reports town survival, demon and minion identification and innocent
lives preserved, lists evidence that pointed at the demon, and writes a machine-readable
`case_summary` to the dev log (see DESIGN
[Outcome tracking and scoring](DESIGN.md#outcome-tracking-and-scoring)).

## Code layout

```
sim/content.gd    static data: map, occupations and shifts, cast pool with trait baselines,
                  roles, secrets, hint packages
sim/gifts.gd      what each reading says in general terms (who it points at, clears, names)
sim/npc.gd        one NPC's state (beliefs, suspicion, trust, claims, readings)
sim/world.gd      case setup, schedules, sightings, night resolution, votes, executions
sim/mind.gd       NPC reasoning: suspicion, claims, testimony, nominations, defences,
                  votes, conversation answers
sim/social.gd     NPC-to-NPC exchanges, approaches, role questions, paranoia
sim/argue.gd      card assertions, templates, conclusions, NPC evaluation of arguments
sim/evil.gd       evil team AI: plan, bluffs, scapegoat, kill/poison choice, fabrications
sim/dialogue.gd, dialogue_voices.gd, dialogue_decisions.gd
                  dialogue composer: words decided statements in a character's voice
sim/devlog.gd     developer trace (JSONL + text)
workshop/         the shared case judge: case_eval.gd (possible worlds), jury.gd and
                  shared_ledger.gd (per-listener runs), role_constraints.gd,
                  live_activity.gd (night movement), live_assessment.gd (card adapters),
                  chronology.gd (curse epochs), canvas_model.gd (the board's case model)
game/workshop_*.gd     bridge between the game and the judge: presentations, belief
                  ownership (parks legacy ledger entries), the filed canvas
game/game.gd      command interpreter and case board; emits structured events
game/card_model.gd     card times, views, rows and markers
game/board_model.gd    case board layout as data
game/case_metrics.gd   post-case outcome and identification analysis
game/recent_sightings.gd  recent sightings an NPC adds when asked their opinion of someone
ui/main.gd        town screen, title bar, actions and log (ui/main.tscn)
ui/map_view.gd    painted map            ui/meeting_view.gd  meeting circle
ui/live_case_workshop.gd  the Case Workshop board
ui/case_view.gd   full-screen case board, with board_view.gd, case_state.gd,
                  deduction_tray.gd, card_list.gd, board_panel.gd, board_icons.gd
ui/profile_panel.gd, cast_list.gd, trait_bars.gd, portrait_badge.gd
                  profiles and the townsfolk list
ui/text_terms.gd, text_formatter.gd, rich_text_renderer.gd, formatted_text_label.gd,
   inline_icons.gd, log_text.gd
                  shared text system (coloured names and roles, inline icons)
ui/theme.gd       papercraft theme      ui/dialogue_lab.gd  dialogue workshop
tools/cli.gd      terminal frontend      tools/autoplay.gd  bot player / batch runner
tools/compare_runs.py  paired active/passive comparison
tools/trace.py    dev-log filter         tools/slice_sheets.py  art sheet slicer
tools/test_*.gd   headless tests     tools/run_gd_tests.py  the test runner
tools/replay_54875.gd  speed replay
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
| `deduction`, `deduction_refused`, `deduction_deleted` | a deduction the player filed (conclusion, supports, template, unfounded, class), one refused and why, one deleted |
| `argument` | an NPC weighing a deduction by the legacy rules: explanation weights, agreement vs. the best alternative, quality, effect |
| `workshop_presentation`, `workshop_delivery`, `workshop_ownership` | a case judged by the shared model: per listener, the reasoning, reply and the suspicion vector that replaced legacy entries |
| `legacy_fallback`, `social_presentation` | something the legacy rules judged (and why); a bare belief taken as social speech |
| `player_present` | the player taking the meeting floor |
| `night_sighting` | who glimpsed whom at night |
| `poison`, `protect`, `protect_failed`, `kill`, `kill_failed` | night actions and outcomes |
| `info` | every ability result, with `true:false` and a `why` when it's wrong |
| `fake_info` | evil fabrications and the reasoning behind each |
| `think` | NPC reasoning, tagged by `data.topic`: `claim`, `lie`, `disclosure` (tier and inputs), `deny_or_refuse`, `confess`, `lie_or_stonewall`, `stonewall`, `withhold`, `omit`, `cue`, `share_sightings`, `vote`, `reconsider`, `nominate`, `accuse`, `opinion`, `persuaded`, `gossip`, `approach`, `about_role`, `paranoia`, `poison_belief`, `seer_pick`, `watch_pick`, `warden_pick`, `grief`, `kill_choice` (with every candidate's score breakdown), `poison_choice`, `scapegoat`, `evil_plan`, `evil_learns`. Weighted rolls log every score part and the probability |
| `suspicion` | every change ≥ 0.05 in one NPC's suspicion of another, with the cause |
| `trust`, `trust_cap` | changes in an NPC's trust in the player, and permanent caps, with the cause |
| `npc_trust` | changes in one NPC's trust in another |
| `trait_reveal` | which trait the player learned about whom |
| `nomination`, `player_statement`, `clemency`, `vote_tally`, `execution`, `no_execution`, `game_over` | meeting events (vote tallies include threshold and block state) |
| `snapshot` | per-phase table of every living NPC's location, poison, trust, claim and suspicion |
| `player_command` | each command the player typed and the full text they saw |
| `player_guess`, `prediction_snapshot`, `prediction_spoiled` | private theory revisions; frozen copies before votes, executions and nights; debug-reveal exclusion |
| `player_execution_context`, `case_summary` | known card IDs and theory before execution; final identity credit, survival, wrongful-execution fraction and player stance |

Every lie has a `think` entry with `topic: "lie"` explaining why (evil cover, a personal
secret, caution about revealing a gift). Filter examples:

```sh
python3 tools/trace.py logs/case_42.jsonl --lies
python3 tools/trace.py logs/case_42.jsonl --npc edda
python3 tools/trace.py logs/case_42.jsonl --suspicion edda
python3 tools/trace.py logs/case_42.jsonl --topic kill_choice --full
python3 tools/trace.py logs/case_42.jsonl --player
```

## Next steps

The to-do list (bugs, deferred and open items, by effort) is [BACKLOG.md](BACKLOG.md);
the agreed direction is in DESIGN's [Roadmap](DESIGN.md#roadmap).

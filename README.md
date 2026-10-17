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

**In the editor:** open the project and press Play. Everything can be done with the mouse:

- **The map** (top left) shows the four blocks and the roads between them. Click a block to
  zoom in; click a place to spend the phase there, a home to call on whoever's in, or a
  crime scene to search it. People are coloured dots: at their exact spot if they're
  working, in conversation, or on your block once you're there; loose in the street if you
  only know their block; in their homes otherwise. **Clicking a person walks you to them
  and starts a conversation.** At night, click a block or person to pick your vigil or
  ward. Right-click or **◀ Whole town** zooms out.
- **The action panel** (right) shows what you can do now, as buttons: talk, search,
  gossip, wait; in conversation, the ask buttons, **Ask about… ▸** (people in one column,
  gifts in the other) and **Present a card…** (pick from your board, optionally "speak
  for/against" someone); at the meeting, nominate, present, wait, close; on a vote, vote,
  accuse or defend with an optional card, clemency; at night, vigil, ward, sleep.
- **The log** (bottom left) colours every character's name and speech in their own colour.
  The typed prompt still works as a fallback.
- **The profile** (bottom right) follows whoever you click or talk to.
- **Board** toggles the card sidebar. **Case view** opens a full-screen board: a text
  filter plus multi-select **Kinds / People / Places** lists (tick several; *match any*
  shows cards fitting any ticked item, *match all* requires each ticked list to match), the
  card list, the timeline grid (who was where, by
phase; bright = you saw it, dim = you were told; click a cell for its cards), profiles with
your guess, confidence and notes, the conclusion builder and Link results. Double-click a
card (or select it and press **>>**) to put it in your **working set**, which stays put
while you filter; Link and the builder use the working set. **◀ Back to
console** (or Esc) returns to the console. Hide / Unhide work on any card (tick **Show
hidden** to see them); **Delete deduction** removes your own deductions only.

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
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --passive
```

To compare the same starting towns and retain machine-readable results:

```sh
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --log-dir logs --results logs/active.json
godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150 --passive --log-dir logs --results logs/passive.json
python3 tools/compare_runs.py logs/active.json logs/passive.json
```

Case logs are separated into `active/` and `passive/` beneath the chosen log directory.
The comparison reports paired wins and reversals, wrongful executions per execution,
player backing/opposition, identification, and innocent survivors in victories. Only
completed cases enter outcome rates. Same seeds match the starting setup; player actions
can change subsequent random draws, so a reversal alone does not prove a particular
intervention caused a loss. The bot records its top living suspicion score as demon and
runner-up as minion; these are diagnostic guesses, not a sophisticated role solver.

`--passive` is the control: a player who does nothing at all (waits every phase, declines
approaches, never nominates, votes no). Compare its win rate with the normal bot on the
same seeds to see how much the player's actions matter.

The bot plays through the same command interface a human uses and prints one line per
case plus a summary (bot win rate is roughly 30–35% at the moment), including trait
reveals, disclosure and NPC-conversation counts. `--transcript`
prints everything the player would have seen.

## How to play

Each day has three phases (morning, afternoon, evening), then a town meeting, then night.

| When | Commands |
|---|---|
| Any time | `look`, `map`, `cast`, `profile <name>`, `board [filter]`, `theory`, `roles`, `tools`, `help`, `log` |
| Day phase | `go <place / block / person>`, optionally one more `go` within the same block, then one action: `talk <name>`, `search`, `gossip` (tavern only), `wait` |
| Talking (3 questions) | `ask gift`, `ask night`, `ask today`, `ask about <name or gift>`, `present <card#> [for/against <name>]`, `bye` |
| Approached | `accept` (talk now; uses the phase) or `decline` (any other action also declines) |
| Town meeting | `nominate <name>` (once), `wait` (let the town nominate), `done` (close the meeting, once a `wait` finds no more nominations) |
| On a nomination | `defend [card#]` or `accuse [card#]` (one statement, optionally citing a card), `clemency` (once per case), `vote yes` / `vote no` |
| Night | `ward <name>` (once per case), `vigil <block>`, `sleep` |
| Case work (any time) | `link <#> <#> [#]`, `conclude <number>` (after a link), `conclude <name> <is / is not / should be> <status> [on night N] [because <#> ...]`, `hide <#>`, `unhide <#>`, `showhidden`, `delete <#>` (deductions only), `timeline [filter]`, `note <name> <text>`, `guess <name> <role/evil/good> [1-3]` |
| At the meeting | `present <deduction#>` (once: everyone hears it) |
| After the case | `grimoire`, `grimoire lies` |

Names and places accept prefixes (`talk bart`, `go tav`). Crime scenes appear as
locations (`go scene_greta`, or `go greta`).

**The Warden walks** to the door it guards at night, so it can be seen by anyone out on
that block or watching it. A demon whose attack fails may realise who was standing there.

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

**Presenting a card in conversation.** `present <card#>` is the one verb for using your
board on someone (it uses a question). The game works out what you mean: a card or
deduction about the person you're talking to presses them (below); a deduction about
someone else argues it; a plain card about someone else makes a case for or against them,
with the direction read from the card itself (a Seer "yes" accuses, a Seer "no" clears). A
card naming several people applies to all of them, split ("it's one of these two"). Cards
with no direction of their own (a daytime sighting) fall flat: "I'm not sure what you're
trying to prove". That costs no question, and is logged. `for <name>` / `against <name>`
override the reading. `press`, `convince`, `tell` and `defend` remain as shortcuts.

**Something doesn't add up.** When Link finds a conflict, the first option files it
without choosing an explanation. In the builder, pick **One of these people** (the people
your working set rests on) and **misled or lying**; or `conclude one of these is misled or
lying because #a #b`. NPCs who accept it take what those people say with a pinch of salt,
and presenting it raises the pressure on them (all of them at the meeting; privately, the
listener if they're one of them), which makes them readier to explain themselves.

**Pressing someone** confronts the person you're talking to with a card
or deduction about them. It raises the pressure on them and makes them answer it: a night
sighting makes them account for that night (a good NPC hiding a secret may confess), and a
card about their gift makes them reconsider revealing it (a Clerk reading naming them
opens them up most). Anyone hiding something may show nerves, and so, less often, may a
rattled innocent; composure decides. Pressing costs a little trust. `ask about <gift>`
put to the person who actually holds it makes them decide whether to own up.

**Night walkers follow the roads**, so they can be seen (and caught on a vigil, or by a
Night Watch) on any block along their route, not just where they end up. They sometimes
drop something on the way: usually a material from their own home block (mud, chalk,
soot, straw), rarely something of theirs. **Searching an ordinary place** finds whatever
was dropped there. A personal item puts its owner out on that block that night; a
material says someone from that block was out (link it with a resident's "I was home").
A misleading death-scene trace now has a cause: someone else passed the cottage that night
and left traces from where *they* spent the evening.

**More evidence.** Conversations you see on the town view, people you see nearby, and
nights when nobody died all become cards. NPCs notice who was talking with whom and may
mention it. A Warden or Veteran claimant gains credit with the town after a quiet night
(evil can bluff these too). `profile` lists what readings on your board say about someone
("possibly the Warden, per Dorian's Clerk reading").

**Your private theory.** Use **Record theory** to jump to a profile's **Your guess**, or
`guess <name> demon [1-3]` / `guess <name> poisoner [1-3]`. `theory` shows your current
candidates. A new demon/minion guess replaces the previous candidate for that identity.
Guesses are optional, private, and cost no action. The persistent banner and meeting
reminders encourage recording them before voting, since a case can end early.

Every revision is logged with confidence, notes and game time. Snapshots before votes,
executions and nights preserve what you believed before the outcome; the latest snapshot
is scored only at the ending. The ending separately reports town survival, demon and
minion identification, and innocent lives preserved. "Identified but lost" recognizes a
correct final demon theory when the town falls; it does not claim why persuasion failed.
Earlier correct guesses remain in the history but do not earn final-theory credit after
being abandoned. Guesses cannot change after the reveal. Opening a debug grimoire before
the ending marks identification as unscored.

`case_summary` is the versioned machine-readable end-of-case event. Execution rows retain
player nomination, yes/no vote and explicit accuse/defend statements. Their stance is
`backed`, `opposed`, or `mixed` (e.g. accused, then voted no); these categories are mutually
exclusive. Public deductions and earlier private persuasion remain available in the trace
but are not automatically attributed as causes of an execution. Zero executions gives a
null wrongful-execution fraction, rather than a misleading zero.

The ending also lists evidence that pointed at the demon: cards on your board, or (if none)
true readings, night sightings or an unsearched trace that never reached you. It's
descriptive, not a verdict. `case_summary` (schema 2) adds `loss_hint`
(`identified_not_persuaded`, `evidence_on_board`, `evidence_reachable`, `no_evidence`),
night stats (kills; attacks stopped by the Warden, Veteran or your ward; Warden hit rate;
Warden spotted or killed) and `present_fallbacks`. `compare_runs.py` prints both.

Tracking regression checks:

```sh
godot --headless --path . --script res://tools/test_outcomes.gd
```

**The town talks.** NPCs who pair off actually exchange things: a reading, a night
sighting, an opinion, a case you made to them, or a secret. Everyone remembers who told them
what. Gossips relay what they've heard; busybodies may approach you with it (including
other people's secrets). `ask about <gift>` (e.g. `ask about seer`) asks what someone
knows about that gift: who claims it, and what they've been told privately.

**Evil knows only what it could know:** public events, what each member saw or was told,
and what they pool when they meet (pairs you may see talking) or whisper in a crowded
tavern. Paranoia rises with every death: the town grows quicker to suspect and to hang.

**Building a case.** `link` checks 1–3 cards against a library of templates of three
kinds. *Contradictions*: someone in two places at once; out at night vs. "I was home"; two
people claiming one gift; a watcher who missed someone; your vigil missing someone a
witness put there; a reading that flips; a Gravedigger contradicting a claim; a Veteran
killed by the demon; a reading pointing only at the demon's victims; a changed story.
*Corroborations*: two witnesses putting someone in the same place; a Clerk reading backing
a claim; a night when nobody died, alongside a Warden or Veteran claim (or a "shelter"
hint). A Clerk naming two people who both claim other gifts is also a conflict. *Inferences* also
include **association** (someone implicated as evil, by a Gravedigger or a deduction you've
argued, seen talking with Y; stronger with more separate conversations, and with how much
each listener believes the first part) and **vindication** (if a Gravedigger was poisoned
on the night they named someone the Poisoner, the Poisoner was alive then, so the hanged
person wasn't it). *Inferences*: a Seer or Archivist pair where one person is cleared (killed by the
demon, or shown good after execution; for a Seer pair, also anyone hanged without ending
the case, since they weren't the demon), which leaves the other; the death-scene trace
matching someone seen on that block that evening. A match lists possible explanations,
and never says which is true. `conclude <number>` files the one you believe
as a **deduction** card. You can also write a conclusion yourself as a sentence, e.g.
`conclude jory is misled on night 1 because #4 #7`, `conclude hollis is not the demon
because #3`, `conclude edda should be protected because #9`. Statuses: good, evil, the
demon, a gift (seer...), lying, **misled** (not lying, but their information was wrong:
poisoned or mistaken), **misled or lying**; with "should be": protected, spared. A
conclusion with no template behind it is your own inference, at most circumstantial and
weighed on how strongly its cards bear on the person; it's *unfounded* only if the cards
don't concern that person at all, and sharp (high-Insight) NPCs reject those. Filing
checks your cards for a template either way, so pressing Link first makes no difference. A deduction needs supporting
cards, and one that only restates what someone said about themselves ("Jory is the
Seer because of Jory's claim and Jory's reading") is refused.

**Credibility.** Every claim counts as much as its source is credible to the listener:
how honest the person seems (from evidence against them, from any source; capped, so
"probably evil" means "take it with salt", not "ignore it") times any doubt about that
particular reading (poison affects the reading, not the person's honesty). Everything is
recomputed from the underlying evidence whenever anything changes, so discrediting the
evidence against someone restores their claims at once, and beliefs can't feed their own
justification. `godot --headless --path . --script res://tools/test_beliefs.gd` runs the
acceptance tests.

**Each NPC keeps an evidence ledger**, keyed by the underlying fact, not the card or
whoever relayed it. Hearing the same reading again, or seeing the same sighting re-wrapped
in another deduction, adds little or nothing. Doubts ("X is misled on night 1") lower how
much that reading counts, including readings they only hear later. When their trust in you
shifts, and before they vote, they re-weigh what you argued earlier (Confidence sets how
far they move at once), and may tell you they've come round.

NPCs weigh a deduction by scoring the same explanations from their own point of view
(whom they suspect or trust, whether an information gift could be poisoned, what they
know firsthand about where they themselves were), compared with the strongest
alternative. "X is misled on night N" makes them discount that reading instead of
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
| `deduction`, `deduction_refused`, `deduction_deleted` | a deduction the player filed (conclusion, supports, template, unfounded, class), one refused and why, one deleted |
| `argument` | an NPC weighing a deduction: explanation weights, agreement vs. the best alternative, quality, effect |
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

## Known gaps / next steps

- Dialogue is templated and repetitive; personality mostly affects numbers, not voice.
- NPC-to-NPC trust biases suspicion, votes and who pairs off; those who trusted an executed NPC resent its nominator, yes-voters and you. NPC conversations happen but carry no content yet (stage 2).
- NPC exchanges are one item each way per conversation and aren't visible to the player except through relays, gossip and approaches.
- The demon's view of who suspects it is approximated from internal suspicion.
- No solvability check or storyteller director yet.
- Balance is untuned: NPCs execute fairly readily, and games can end by day 3.

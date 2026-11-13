# Live NPC decision inspector

Enable **Debug**, then click **Rolls**. The movable window collects NPC decision/stat checks as they happen. Drag the divider to resize the history and calculation panes. Select a row to see the NPC, day/phase, command or trigger, relevant raw stats, weighted contributions, actual sampled value, comparisons/thresholds and outcome. This is spoiler information: the existing Debug rule still makes identification unscored.

Capture is independent of detailed file tracing. It starts when Debug is enabled; it does not reconstruct past checks. Starting a case with Debug already enabled includes first-night decisions. A new case resets the buffer. At most 1,000 checks are retained, with oldest rows evicted.

Use the NPC and decision filters to narrow the view. **Include good-self simulations** exposes the hypothetical good minds evil NPCs consult; these rows are labelled and hidden by default. **Pause scrolling** freezes displayed rows while collection continues; resuming catches up. Selecting an older row keeps its calculation selected when more rows arrive. **Clear** empties history; **Copy visible** copies the currently filtered/frozen rows and their calculations. **Console mirror** prints the same records to Godot's output/console, respecting the good-self checkbox. Console mirroring is off by default and survives New case while this UI session is open.

## Reading the percentage

- Probability/sigmoid checks show the chance of that local check passing, conditional on preceding gates. The actual draw and exact cutoff are retained, rather than resampled or inferred from the response.
- Gift disclosure shows the four raw tier probabilities (refusal, hint, gift, readings), integrating the uniform openness jitter. The compact column shows **Gift+**, the chance of gift or readings. These probabilities are **before** forced disclosure, prior/public-claim floors and subsequent withholding gates. The final-tier row explains what actually happened.
- Weighted/uniform choices show the probability of selecting the observed option, including any residual chance of selecting nothing. The recorded sample uses an index or cumulative weights, rather than a pass/fail threshold.
- Candidate scores with uniform jitter show an approximate chance against the other candidates' **observed** scores. This is conditional on those scores and any other already-observed random terms. It is not the overall probability that the strategy will pick that target. Existing score rounding can make these estimates approximate. Later strategy gates can still override a ranking winner.
- Fear uses an existing fixed NPC/day hash, not fresh game RNG. Its nominal percentage describes the fraction of daily samples under the cutoff; repeating the question does not reroll it.
- Deterministic scores, skip gates and final choices with no additional draw show **N/A (no roll)**. There is no invented probability for an entire conversation, vote or strategy.

## Why the town voted: `tools/replay_log.gd --why`

The inspector shows each roll; this shows the beliefs behind the votes. `tools/replay_log.gd`
replays a playtest dev log (seed, size and script from the log; commands and Workshop
filings in order). With `--why` it also prints, just before each logged vote (or only those
at `--at SEQ,...`), every good mind's view from the shared model:

- **suspicion**: the value the vote and nomination scores read (`Mind.susp`).
- **P(evil)**: that mind's joint-world posterior per person.
- **P(Demon)**: the same posterior summed by who holds the Demon.
- **team**: the likeliest evil teams (`--worlds N`, default 5), with their share of the posterior.

```text
godot --headless --path . --script res://tools/replay_log.gd -- logs/case_13910.jsonl [stop_seq] [--why] [--at 480] [--worlds 5] [--json out.jsonl]
```

It ends by comparing the replay's vote tallies with the log (`votes_match`). Meeting
testimony text can differ, because the UI splits it into separate records; the votes must
match. Each view re-runs that mind's ordinary refresh with `CaseEval.capture_worlds` on,
which only stores per-world weights and changes no result (`tools/belief_views.gd`).

**Which code a log was played on.** Since Nov 6, `case_start` records the git commit in its
`build` field (`sim/build_info.gd`; uncommitted changes aren't reflected). Both tools print a
note when the log's commit differs from the checkout, with the `git worktree add` command to
replay it on its own code. Logs from different code drift as the random rolls shift.

## Why the town read a case that way: `tools/explain_case.gd`

Two modes, both replaying a playtest log (`tools/log_replay.gd`, shared with `replay_log.gd`).

**Case mode** presents a filed Workshop case, and variants of it, to every good mind for
real (`WorkshopPresentation.present`, meeting venue, no speech). Each variant replays
afresh. Per mind it prints the premise before and after (CaseEval prior → posterior,
likelihood ratio, category), the mind's suspicion of the target before and after, where
the probability went instead (rivals), and per card the mind's reliability for it and how
likely it is to be accurate given everything. It ends with a summary across variants.

```text
godot --headless --path . --script res://tools/explain_case.gd -- logs/case_13910.jsonl --card 78 \
    [--add fenwick] [--drop] [--challenge fenwick=lying] [--listener constance,jory] [--json out.jsonl]
```

- `--add X`: add every report of person X (or a fact-id prefix) to the case first.
- `--drop`: also try the case with each card removed, to see which cards carry it.
- `--challenge X=MODE`: also try it with X's reports challenged (`lying`, `misled`, `unlikely`).

**Belief mode** answers "why does each mind suspect this person this much?". At a seq, it
removes each thing a mind has heard (each ledger entry: reading, claim, defence,
accusation, case) one at a time, re-runs the refresh and lists the biggest movers. A
suspicion clamped at 0 understates how far the movers push it.

```text
godot --headless --path . --script res://tools/explain_case.gd -- logs/case_13910.jsonl --belief fenwick --at 372 [--top 8]
```

## Why an argument moved someone this far: the "why" breakdown

`explain_case.gd` shows what a case did. The why breakdown shows where the rest went:
every discount the shared model applied between "this case proves it" and the suspicion
that was actually added, each as its own step. It reads the solver's own numbers back; it
decides nothing. (`workshop/case_why.gd` for the evidence half, `game/workshop_why.gd` for a
real listener; tests in `tools/test_workshop_why.gd`.)

**Where to see it**

- **Workshop, Debug ▾ > "Why this strength? (test juror, per card)"**: the selected
  premise, judged by the test juror. Debug must be on.
- **Workshop, Debug ▾ > "Record why each listener moved, when I present"** (or
  `g.workshop_why = true`): after each presented case, one breakdown per listener goes to
  the dev log (`workshop_why`: the chain, the cards and a one-line reason), the trace sidecar
  (the full text) and **"Show recorded listener breakdowns"**. Off by default.
- **`tools/explain_case.gd ... --why`**: the same breakdown under each listener of a
  replayed log.

**The suspicion chain (a real listener).** The suspicion of the premise's subject the case
could add, with one idealisation dropped per line:

| Step | What it means | The loss to the next step |
|---|---|---|
| If the case settled it outright | the ceiling: a posterior of 1 (or 0 for a defence) | the cards don't settle it: other explanations remain |
| If every card were news, at face value, nothing out of view | every card heard at full weight from a trusted teller; they read everything they hold | hearing weight and trust in the tellers |
| As they hear each card | their real reliabilities (hearing weight, trust, doubt, challenges) | attention: putting these cards in front of them pushed others out of view |
| Within their attention | their real card budget, focused on the presented cards | already held: only new cards add anything |
| Against what they already held | against everything they held before, with their attention where it was | resistance to moving against a lean (Confidence) |
| After resistance | the requested change | the scale's floor and ceiling |
| Applied | what the presentation did | |

Under the chain, three blocks say what else the presentation did:

- **Challenge on #N:** each challenge the case attached, how far the listener agrees, the
  multiplier it puts on the reading, and where the subject (and the challenged reader)
  would stand without it.
- **Citing changed how far they trust:** readings whose reliability moved because the
  case's own copy counts as a way of holding them, and the subject with those readings
  heard as before.
- **Change of view:** the held cards that left and entered what they read, the subject
  with their old view kept, and people the case didn't name who moved by 5 points or more.

Each is one more rerun with that single thing undone, so they don't add up to the total.

Then the **action bars**: where a vote and a nomination on the subject stand now, with the
same parts `MindMeeting._vote_impl` adds up (no statement from the player).

Each step is the listener's own union evaluation, re-run on copies
(`Shared.prepare` / `Jury.refresh`). "Reads everything" uses the existing developer switch
`Reasoner.unlimited_cards`. The "without this case" side needs to know what their attention
was on before the presentation, which the presentation overwrites: recording and
`explain_case --why` capture it first (`WorkshopWhy.before`).

**The premise chain (any listener, including the test juror).** The chance the premise
is true: with no cards (their starting view and the public record); if every teller is
honest and every card exact; allowing that a teller may be evil or deluded; and as this
listener hears it. The test juror hears every card at full weight, so its last two lines
are the same: a real listener's are not.

**What's left.** The surviving worlds where the premise is false, grouped by what they
share: a named teller is evil or can't read true; the cards are true and fit someone else;
the subject is good but Marked; the subject is evil but in the other role. The largest
group is "the strongest surviving alternative".

**Per card**

- **Status:** counted · counted, but it fits most worlds (it could hardly have said
  anything else) · counted, but changes nothing here · argues against the premise · heard,
  but given no weight · not attended by this listener · rejected by their own checks.
  `[already held]` marks a card they had before.
- **Holds in N% of worlds:** how likely the card's content is across the worlds in which
  its teller can be taken at their word. Measured, not looked up: the neutral listener
  hears the card alone at full weight, and the weight it leaves in those worlds is the
  share.
- **The model's chance a false report says this (q):** what CaseEval itself assumes
  (`chance_content`). "(fixed)" marks the gifts that use a flat estimate
  (`ROLE_CONTENT_FIXED`) instead of the share. Where the two numbers differ, an honest
  reading and a bluffed one are being told apart by more (or less) than the worlds justify.
- **Heard at:** this listener's reliability for the card.
- **Premise strength xN with it:** leave-one-out, the case's likelihood ratio with the
  card over the ratio without it.

**It changes nothing.** No game RNG draw, no write to a mind, a plan or a cache switch
(`test_workshop_why`: state compared before and after; the same presentations with
recording on and off leave every mind and the world RNG identical). With recording off
(the default) nothing is computed, so the golden capture is unchanged. Cost: 5 or 6 union
evaluations plus a few CaseEval runs per card: about 0.15 s per listener early in a 7-NPC
case, 0.5 s on day 2 at 10 NPCs and up to 2 s late in a 10-NPC case (so recording adds a
real pause at a late meeting).

### With the connections model on

With `Connections.enabled` (workshop/connections.gd) none of the steps above exist: belief
isn't limited by attention, and what a case adds is what its cards say together. The same
menu items, `g.workshop_why` and `explain_case.gd --why` then give a different report
(`WorkshopWhy._connections_report`; tests in `tools/test_connections_why.gd`). It follows
the premise's subject and whoever the case's own part moved most (up to three people), and
shows:

- **In short:** the chance before and after, the suspicion before and after as stored
  (it can go below zero; the game reads that as 0), and the largest part of the change.
- **The case's cards weighed together:** who that moved, the weight it counted at (trust in
  the presenter, x0.5 a day since it was presented, x0.5 for a "suspicious" premise), how
  many cards were weighed together, and whether that was with the listener's core. If the
  case as a whole added nothing, why (a single card, no held cards, too faded).
- **Part by part, per person,** before and after, in log-odds: where they start; this
  case's cards each counted by itself; every other card; the core; this case weighed
  together; other stored cases (by case number, or "X's nomination of Y"); and the common
  shift that keeps the evil count. The parts add up to the chance.
- **The case's cards, each counted by itself:** a card, or the built-in pairing it sits in
  (a night, an Augur day, a Psychologist reading with its statements, a trace with
  profiles, the movement or day connection). `[new to them: the case brought it]` marks a
  card they didn't hold. "(was ...)" shows a card whose own value changed when it was cited.
- **The core:** what it starts from, what joined it, what it adds, and whether this case
  was weighed with it.
- **Suspicion and the action bars,** as before, and the **premise chain** (unchanged: the
  case's cards read together by this listener alone).

"Before" is the breakdown the listener's last refresh stored (`WorkshopWhy.before(n, g)`
keeps it); "after" is the one the presentation's own refresh stored. Nothing is re-run, so
the model's part of the report costs a few milliseconds. The premise chain is the cost: its
per-world checks (does the premise hold, can each teller be taken at their word) are kept
between listeners (`CaseWhy._masks`), so the first listener of a case pays about 0.4 s at
10 NPCs and the rest about 0.08 s each.

A log played with the model on says so in `case_start` (`"connections": true`), and
`replay_log.gd` and `explain_case.gd` turn it on from that. For an older log, pass
`--connections`.

### What a command cost: `tools/replay_log.gd --time` and `--profile`

`--time` prints how long each replayed command took (those over 100 ms) and the total.
`--profile` adds, under each, the Workshop profiler's spans by their own time and its
counters. With the connections model on the refresh shows as
`.../consequences/connections/{baseline,items,core,cases}`, and `connections_judgements`
counts the judgements made. `Connections.capture` (a developer switch, off) records each
judgement (listener, part, the set judged, time, a hash of the answer), for measuring what a
cache would save.

```text
godot --headless --path . --script res://tools/replay_log.gd -- logs/case_44542.jsonl --connections --profile
```

## Coverage and maintenance

Coverage includes weighted decision checks, gift tiers and withholding gates, protection/confidence requests, pressed nerves, whereabouts slips, opinions, gossip selection, traits/haunts/relationships, approaches and peer-conversation selection, public accusation/nomination/vote calculations, evil cover overrides, and Seer/Night Watch/Warden plus evil target decisions. Actual ability results, setup assignments and incidental flavour/world-generation randomness are outside this inspector's remit. It does not replay alternative decisions.

`sim/decision_feed.gd` owns bounded value snapshots and analytical estimates. `sim/devlog.gd` forwards existing structured decisions independently of its file-trace flag. `sim/world.gd` supplies single-draw wrappers and observation helpers. `ui/decision_window.gd` polls only while visible, at most ten times per second; formatting/filtering does not issue game commands or consume RNG. Observations retain no strong world/NPC references.

For new decision checks, use `World.decision_roll`/`decision_pick` in place of the original single draw, preserving its comparison and lazy evaluation order. For an existing sampled value use `observe_decision`, `observe_weighted` or `observe_ranked`; never draw again for the inspector. Existing `DevLog.decision` records also appear automatically, but must include the actual draw/probability or deterministic score/threshold to support a useful estimate. Pass relevant raw stats as `inputs`, with weighted terms separately in `parts`. Keep pure ability outcomes and evidence evaluation out of this view. Batch 4 follows these conventions: direct night-sighting willingness and refused-whereabouts slips expose their original sampled draws, and volunteering exposes its deterministic threshold. The removed trusted-friend omission check stays removed.

## Verification

`tools/test_decision_inspector.gd` checks analytical distributions, exact draw/state preservation, immutable bounded capture, file-trace independence, shadow labels, UI filtering/pause/detail/copy/reset controls, and paired Debug on/off NPC/shadow/game state through dialogue, a meeting and a night. `test_trace`, which checked file-trace parity through complete cases, was retired Nov 4; the golden capture (`docs/golden_baseline.md`) now guards whole-case determinism. Run with Godot 4.7.2:

```text
python3 tools/run_gd_tests.py --godot <godot-console.exe> test_decision_inspector
python3 tools/run_gd_tests.py --godot <godot-console.exe>
```

The measurements below are from the original Oct 27 build and are kept as a historical control.

A single sequential headless `tools/replay_54875.gd` comparison on Godot 4.7.2, with detailed tracing enabled and console mirroring off:

| Build / capture | Sum of command times | Day 2 case presentation |
| --- | ---: | ---: |
| Main `193b636` control | 10.623 s | 3.138 s |
| Inspector branch, Debug off | 10.661 s | 3.110 s |
| Inspector branch, Debug on | 10.414 s | 3.063 s |

The archived control's tracked GDScript/project/JSON sources were checked against `193b636`. Commands, replies, resulting presentation assessments, vote margins and outcomes matched in all three runs: 5 yes / 5 needed, nine shared listeners, no native listeners or fallbacks. These are single samples; they show no command regression in this replay, not a statistical performance guarantee. The capture-on run is headless and does not measure rendering the open inspector. The inspector's window was separately rendered and checked at normal and compact sizes.

Initial inspector-only validation: 83/84 suites passed with `--include-slow --timeout 1800`, including all six complete-case trace pairs (45 trace checks). The sole failure is the previously approved main-baseline exception in `test_workshop_protection`: `disabling shared model restores native quiet-night credit`. Both `test_social` and `test_text_ui` passed. After the layout/detail review, the focused inspector suite passed 49 checks, including weak-world lifetime and strict/inclusive equality boundaries; `test_town_ui` and `test_ui` also passed after the layout change.


## Batch-4 reconciliation

The inspector is integrated with all 23 batch-4 changes on PR #25. The conflict in `Mind.answer_night` keeps the approved 95% willingness rule, replacing the old discretionary Gossip/friend filters. New live observations cover that exact draw, the existing refusal-slip draw and the deterministic Gossip + Confidence volunteering threshold. Pinned Roles and the inspector coexist and retain their independent preferences across cases.

`tools/test_decision_inspector.gd` additionally checks the merged private-answer/volunteering paths with capture on/off, exact RNG samples/states and bookkeeping, plus the combined UI and new-case binding. See [integration validation](archive/BATCH4_INTEGRATION.md) for full-suite and replay results. The original inspector-only measurements above remain a historical control.

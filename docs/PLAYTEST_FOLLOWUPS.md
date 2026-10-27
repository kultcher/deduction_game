# Playtests 78148 / 77388 follow-ups

Branch: `codex/playtest-ui-followups`, from main `e674193` (Oct 27).
Seven deferred items and their risks/decisions are recorded in BACKLOG.md under
"Playtests 78148 / 77388: deferred follow-ups". This pass covers the remaining UI
and bounded fixes, plus PR #25's volunteered-sighting delivery review.

Validation and implementation notes are added alongside each change. Existing
`test_workshop_protection` failure "disabling shared model restores native
quiet-night credit" remains the user-approved baseline exception. Full runner
skips `test_trace` unless requested explicitly; any skipped coverage is reported.

## Dialogue menu layout

Each section now has one heading spanning its balanced columns. Popup sizing waits
for themed container minimums, removes obsolete picker children synchronously and
bounds the popup to its owner; overflow remains scrollable with focus following.
Native option indices, callbacks, disabled states and keyboard neighbours survive.
Embedded popups and anchors use logical viewport coordinates, including a physical
1600×1200 window stretched from an 800×600 viewport (a reproduced clipping case).
The batch-3 column-count assertion follows the new shared heading container.

## Hide Unselected checkbox

Disabled checkboxes now use the same empty stylebox as enabled checkboxes instead
of inheriting a paper Button plaque with different content margins. Disabled text
uses the board's muted colour. Filtering and the no-selection disabled rule remain
unchanged; the theme correction also keeps other disabled checkboxes consistent.

## Card labels and outlines

Removed visible `context` tags, list prefixes and dashed overlays from the board,
card lists and Workshop canvas. Location dots show their ordinary person/place
labels, and Workshop cards retain normal solid selection borders. Adapter-based
classification survives in explanatory tooltips; evidence, receipt identity and
selection/hit areas are unchanged. The context UI regression suite now checks the
requested ordinary row text and absence of the decorative overlay.

## Headline placement and duration

The title/subtitle block is centered horizontally and vertically, including wrapped
text and title-only notices. Defaults are five seconds, three for phase changes and
seven for endings. More than two queued notices still accelerate, with a three-real-
second floor for defaults; shorter explicit settings overrides remain effective.
Click-to-skip and mouse-transparent input behavior remain covered by batch-3 tests.

## Ward fulfils a vigil promise

A ward spent on that NPC's door that night now fulfils their vigil promise, including
the existing fear relief and promised disclosure. It does not fulfil neighbours'
promises or count a ward from another night. When both offers to one NPC are covered
by that ward, settlement awards the existing kept-promise benefit once. No trust
amounts or tool costs changed. Focused checks cover boundaries and repeated settlement.

## NPC-initiated approach fatigue

Accepting news, gossip, framing or protection approaches clears that NPC's accumulated
question count before the opening response. A promised free disclosure clears it
before speaking, so its optional continuation also starts fresh. Declines preserve
the old count. No old trust loss is repaired, no wrong-guess counter is reset, and
fresh questioning still accrues normal fatigue. Paired fresh/tired fixtures verify
matching post-accept trust and RNG for each agenda, including evil framing.

## Martyr explanation

The existing non-substitution report now says "As the Martyr, I chose <name>. They
were hanged and I still stand: they must have been evil or my gift failed."
Only wording changed: the original report data/truth, generation conditions,
substitution rules and inference remain unchanged. Both reasoning and evil
scapegoat strategy are explicitly deferred in BACKLOG.md.

## Relationship sourcing

The existing profile section is retained. Explicit closeness in opinion replies and
"<name> is my friend" accusation replies now carry structured disclosure metadata;
the game records only emitted speech as an attributed profile note for both people.
Existing friend/rival disclosures deduplicate regardless of pair order, and dead
people can be named. Generic distrust does not imply rivalry; hidden town bonds,
Lovers, NPC trust and suspicion are never scanned to fill the profile.

## PR #25: volunteered sightings reach listeners

Every ordinary night-sighting fact actually spoken in `Game._testimony_turn` now
passes through `Social._deliver` for each other living listener before the next
speaker reacts. This also covers sightings cited in accusations. Good listeners
receive the existing trust-weighted sighting ledger entry, attributed hearsay and
heard/told bookkeeping. Evil receives its existing intel and its good self hears
the report. The exact player-facing receipt identifies the same fact in the shared
model; repeat hearing replaces weight rather than stacking effects. Public delivery
adds no RNG and does not award the private-conversation +0.02 trust benefit.
No disclosure gates, hearing coefficients, vote formulas or evil policies changed.

## Validation (Godot 4.7.2)

- Main baseline: 83/84 ordinary suites passed; only the approved quiet-night-credit
  failure in `test_workshop_protection`.
- Full combined run: `python tools/run_gd_tests.py --godot
  logs/runtime/Godot_v4.7.2-stable_win64_console.exe --include-slow`:
  **85/86 suites passed**. The only failure remains exactly "disabling shared model
  restores native quiet-night credit" (1 of 22 protection checks). No new exception.
- `test_trace`: 45 checks, zero failures across all six complete-case trace pairs.
  `test_meeting_stream`: parity for 42, 7104 and 54875. Social, text UI and the
  decision inspector pass.
- Final focused run after the scaled-window fix: 5/5 suites passed (`test_ui`,
  `test_town_ui`, `test_text_ui`, batch 3 and `test_playtest_followups`); the new
  follow-up suite passes **94 checks**. The full run's earlier follow-up invocation
  passed its then-current 93 checks; the final run adds the scaled-window regression.
- Rendered inspection: wide/narrow/scaled dialogue pickers, enabled/disabled board
  checkbox, card dots and centered headline. Screenshots are local ignored artifacts
  under `logs/playtest-followups/`, not simulation fixtures.
- Scope audit: no edits to `workshop/`, `game/workshop_*.gd` or `sim/evil.gd`.
  Vote/nomination formulas, disclosure/volunteering gates, movement/target choices,
  and existing hearing coefficients are unchanged. Wording/relationship recording
  adds no RNG; paired approach fixtures preserve the original decision draws.

### Replay and cost observations

Before public-sighting delivery, the original 54875 replay completes: filed #94,
9 shared listeners, no fallback/errors, **2 yes / 5 needed**. Sum of command times
was 9.759 s; Day 2 meeting entry 2.442 s; presentation 3.182 s (one headless sample).

With public delivery, the strict replay stops before the original `present 48`:
**"Original evidence is absent for present 48"**. In the later conversation,
Constance says "I saw nobody" rather than supplying the historical Dorian sighting;
Isolde's earlier response differs too. Public hearing now changes NPC knowledge and
subsequent game/RNG trajectories. No report was injected, no behavior tuned, and no
post-change vote/presentation timing is claimed. This replay needs a separately
reviewed continuation if it is to remain a complete comparison fixture.

The public-sighting delivery change is the cost risk in this pass: more held evidence
requires additional shared-model work. A separate fixed-input probe after the full
run delivered one sighting to nine living listeners and flushed nine deferred minds:
0.734 ms enqueue / **386.979 ms including refresh** on the first sample; 0.728 ms /
**25.601 ms** on a second equivalent, cache-warm sample. These are two small-case
samples, not a town-size bound or a benchmark of the changed historical replay.
The full trace parity run contains commands up to **8.776 s** (seed 42, Day 4
meeting entry); they completed and
are retained in the logs. UI presentation changes do not add synchronous evaluator
work. Deferred belief refresh and existing caches remain in use; no performance
or gameplay tuning was included.

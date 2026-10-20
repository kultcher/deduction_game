# Local case history viewer (milestone 3)

This viewer reads exports without executing or modifying the simulation.
Python 3.10+ is the only requirement; no pip packages or CDN are needed.
Standalone generated HTML works offline and can Load another JSONL file through
the browser picker. An optional loopback-only launcher provides a native file
dialog with an exact starting directory; it makes no external network requests.

Milestone 2 was reported passing by the user: 45 trace checks, zero failures.
This milestone changes no Godot files. Python execution and real-browser visual
verification were unavailable during authoring. JavaScript syntax and the
interaction/data harness were checked using the available JavaScript runtime.

## First smoke test

From the repository root:

```sh
python tools/test_case_viewer.py
python tools/case_viewer.py tools/fixtures/case_viewer.trace.jsonl -o case_demo.html --open
```

On Windows, use `py` instead of `python` if that is your Python launcher.
The fixture is synthetic, explicitly labeled as a demo; it is not a playtest.

Expect 12 passing Python tests. The tests intentionally exercise error paths,
so an input-preservation error message during the CLI test is expected; the final
unittest result must say OK. The browser should show Agnes at .60 trust, Jory's
separate shadow at .40, and a demo ledger entry at .50 stored / .45 effective weight.
Click event #5: trust remains .50 in the boundary state while the event explicitly
records the change to .60. At #6 the boundary state catches up. This is intentional:
explanatory events must not be replayed again on top of state deltas.

Select Suspicion toward NPCs: Agnes's view of Jory rises from .10 to .235.
Select Ledger entry: stored and effective weights have separate lines. Turn on
All minds' effective weight to compare observers of the same evidence ID.
Search `kept a promise`, then use Next match. Click the vote event to inspect
its score/threshold and linked decision stages. Linked stages can include later
events; they are labeled accordingly and are not treated as knowledge at the cursor.

Optional (if Node is installed):

```sh
node tools/test_case_viewer.js
```

This exercises the actual viewer JavaScript using a minimal DOM substitute.
It does not verify browser layout, SVG display, or accessibility.

## Load button and default folder

For the easiest workflow, run:

```sh
python tools/case_viewer.py --serve
```

This opens the viewer in your browser. Click **Load log…** to get a native file
dialog starting at `%APPDATA%/Godot/app_userdata/Demonologist (text prototype)/logs`.
For the current Windows account that is:

```text
C:\Users\kultc\AppData\Roaming\Godot\app_userdata\Demonologist (text prototype)\logs
```

The dialog initially filters to `.trace.jsonl`; change its file-type filter to
All JSONL logs if needed. Leave the terminal running while using native Load;
Ctrl+C stops the launcher. You can also supply an initial log before `--serve`,
or set a different folder with `--log-dir "C:/path/to/logs"`. Native dialogs use
Python's standard tkinter component, included in normal Windows Python installs.
The launcher shows the configured folder above the controls.

Existing standalone reports must be regenerated with this version to get the new
Load button. Standalone Load uses the browser file picker; browsers determine its
starting directory. Use `--serve` when you want the exact configured folder.
Loaded files are validated before replacing the current case. Cancellation or an
invalid file leaves the current case displayed. Loading resets the cursor, search,
range and view to the new case. No input logs are modified or uploaded.

## Open a real case

Play or export a case with detailed tracing enabled. Use the game's `log`
command and find the `case_<seed>.trace.jsonl` sidecar beside its ordinary logs.
Use that file, not the ordinary JSONL, for complete tracked boundary history.

```sh
python tools/case_viewer.py "C:/path/to/case_61251.trace.jsonl" --open
```

Output defaults to `case_61251.trace.html` beside the input. Use
`-o case_report.html` to choose another output location. For validation only:

```sh
python tools/case_viewer.py "C:/path/to/case_61251.trace.jsonl" --validate-only
```

## Reading the report

- Choose a real or shadow mind. All state lookup keeps these separate.
- Choose player trust/cap/pressure, suspicion, relationship trust, source honesty,
  reading doubt, protection/spare preference, or a ledger entry.
- Multi-select targets with Ctrl-click (Cmd-click on macOS).
- Click a graph or move the event slider. State, ledger and event details share
  that cursor. First/last event inputs zoom the graph; Full range resets it.
- Search events by type, actor, reason, evidence ID, or raw payload. Previous/next
  match seeks globally; the list shows a window near the current cursor rather
  than inserting thousands of DOM elements.
- Inspect the selected ledger's complete entry, effects, applied amounts,
  justifications, reliability references, and the mind's honesty/doubt maps.
  Ledger times counts recorded hearings; repeated support need not increase weight.
- Decision records show the calculation as exported, including competing
  explanations, gates, rolls, and actual outcomes. The viewer does not recalculate
  gameplay formulas or assume a good-mind threshold for evil tactical choices.
- The raw state panel omits the ledger map to avoid duplicating it; the evidence
  panel shows the selected entry. Other tracked state, including role/knowledge
  maps, remains inspectable.

Charts use recorded boundary observations. Fine-grained value_change events
preserve substeps in the event list but never mutate replay state. A curve
continuing horizontally means "last observed value", not proof that no internal
mutation occurred. Arrays in deltas are replaced atomically; null and absence
remain distinct. Missing values are gaps, never invented zeroes.

Ledger applied amounts are accounting contributions, not necessarily actual
suspicion movement after clamping. Compare their associated value_change events
to see requested/applied deltas. The viewer does not infer agreement from a weight,
or infer causation from changes merely observed at the same boundary.

## Legacy and damaged logs

Ordinary old JSONL files are supported for event inspection and snapshot histories.
Their graphs intentionally use unconnected dots, with a persistent incomplete-history warning.
A blank relationship target list means that map was not recorded for the selected
mind; the viewer now explains this beside the controls. Select `.trace.jsonl`
for full tracked relationships, ledger entries, and connected boundary histories.
Suspicion targets can still appear in legacy logs when their snapshots contain them.
Relationship and ledger history not present in the export remain unknown.
No merging of separately sequenced old real/shadow files is attempted.

Detailed traces must have contiguous increasing sequence numbers, schema 1,
initial checkpoints before deltas, matching delta preconditions, and later
checkpoints identical to replay. Invalid JSON, unsupported/mixed schemas, sequence
gaps, or replay mismatches fail with a line/event error and no new report.
A syntactically complete export that stops outside action_end is allowed with a
warning. A partial final JSON line is rejected; it is not silently discarded.
No parser can detect an export cut cleanly at a completed action; the report only
claims history through the records provided.

The input file is never modified. Rendered data is placed in an escaped inert JSON
element and displayed using textContent; game text cannot inject HTML/scripts.
Reports contain hidden case information, including roles and shadow state.

## Scope and next steps

This first viewer supports one case per report. It has no counterfactual engine,
aggregate tuning dashboard, heatmap, batch export, or automatic ranking of turning
points yet. Reliability and contributions are displayed as recorded rather than
recomputed in Python.

The loader validates with one mutable state per mind; the report stores the
original events, not a deep full-state copy at each point. The browser seeks from
the latest checkpoint and rebuilds selected numeric series on selection changes.
The complete input is still in memory; real-case size/performance measurements
are outstanding. If a report feels slow, report event count, input size, and which
interaction was slow before expanding to large batch runs.

## Load-button validation

The JavaScript data/interaction harness passes 28 checks, including switching
cases, detailed/legacy parsing, malformed replay rejection, target availability,
and the standalone Load route. Python adds tests for the default directory and
native launcher requests, cancellation, invalid files, and preserving the current
case on failure. These Python tests and actual Tk dialogs still require local
execution; no execution environment is available in the authoring session.

The local launcher binds only to 127.0.0.1 on a random port. Its random session
path, same-origin check, Host check, and session header protect the native dialog
endpoint. It exposes no endpoint for arbitrary filesystem paths and only reads
files explicitly selected in the native dialog.

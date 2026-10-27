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

## Coverage and maintenance

Current-main coverage includes weighted decision checks, gift tiers and withholding gates, protection/confidence requests, pressed nerves, whereabouts slips, opinions, gossip selection, traits/haunts/relationships, approaches and peer-conversation selection, public accusation/nomination/vote calculations, evil cover overrides, and Seer/Night Watch/Warden plus evil target decisions. Actual ability results, setup assignments and incidental flavour/world-generation randomness are outside this inspector's remit. It does not replay alternative decisions.

`sim/decision_feed.gd` owns bounded value snapshots and analytical estimates. `sim/devlog.gd` forwards existing structured decisions independently of its file-trace flag. `sim/world.gd` supplies single-draw wrappers and observation helpers. `ui/decision_window.gd` polls only while visible, at most ten times per second; formatting/filtering does not issue game commands or consume RNG. Observations retain no strong world/NPC references.

For new decision checks, use `World.decision_roll`/`decision_pick` in place of the original single draw, preserving its comparison and lazy evaluation order. For an existing sampled value use `observe_decision`, `observe_weighted` or `observe_ranked`; never draw again for the inspector. Existing `DevLog.decision` records also appear automatically, but must include the actual draw/probability or deterministic score/threshold to support a useful estimate. Pass relevant raw stats as `inputs`, with weighted terms separately in `parts`. Keep pure ability outcomes and evidence evaluation out of this view. This branch is based on main; additional checks introduced by the separate batch-4 branch need these same conventions when integrated.

## Verification

`tools/test_decision_inspector.gd` checks analytical distributions, exact draw/state preservation, immutable bounded capture, file-trace independence, shadow labels, UI filtering/pause/detail/copy/reset controls, and paired Debug on/off NPC/shadow/game state through dialogue, a meeting and a night. `tools/test_trace.gd` covers file-trace parity through complete cases. Run with Godot 4.7.2:

```text
python tools/run_gd_tests.py --godot <godot-console.exe> test_decision_inspector
python tools/run_gd_tests.py --godot <godot-console.exe>
python tools/run_gd_tests.py --godot <godot-console.exe> --timeout 1800 test_trace
```

A single sequential headless `tools/replay_54875.gd` comparison on Godot 4.7.2, with detailed tracing enabled and console mirroring off:

| Build / capture | Sum of command times | Day 2 case presentation |
| --- | ---: | ---: |
| Main `193b636` control | 10.623 s | 3.138 s |
| Inspector branch, Debug off | 10.661 s | 3.110 s |
| Inspector branch, Debug on | 10.414 s | 3.063 s |

The archived control's tracked GDScript/project/JSON sources were checked against `193b636`. Commands, replies, resulting presentation assessments, vote margins and outcomes matched in all three runs: 5 yes / 5 needed, nine shared listeners, no native listeners or fallbacks. These are single samples; they show no command regression in this replay, not a statistical performance guarantee. The capture-on run is headless and does not measure rendering the open inspector. The inspector's window was separately rendered and checked at normal and compact sizes.

Final validation: 83/84 suites passed with `--include-slow --timeout 1800`, including all six complete-case trace pairs (45 trace checks). The sole failure is the previously approved main-baseline exception in `test_workshop_protection`: `disabling shared model restores native quiet-night credit`. Both `test_social` and `test_text_ui` passed. After the layout/detail review, the focused inspector suite passed 49 checks, including weak-world lifetime and strict/inclusive equality boundaries; `test_town_ui` and `test_ui` also passed after the layout change.

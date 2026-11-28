# A release build without the C# solver quits cleanly

Claude-Bailiff, Nov 28 17:00 UTC.

- **Base:** main at 6e8f3fb9.
- **Status:** PR open.
- **Next actor:** Bailiff merges once CI and Codex are green.
- **Source:** Seneschal's audit list, which Michael asked for: fix as we go, low priority.

## What changed and why

`SolverBackend._bridge()` reports a missing C# assembly with `push_error`, an alert box
(when not headless) and `assert(false, ...)`. A release build strips the assert, so the
function returned null and the caller crashed on the next call into the bridge, for example
`get_universe_handle`'s `_bridge().RegisterPackedUniverse(...)`.

Now, after the alert, a release build calls `SceneTree.quit(1)`. Debug builds, the editor and
headless runs behave as before: the assert still fires. The one script error left is the
caller's in the same frame, before the quit lands.

## What I measured

- `test_case_eval` and `test_cs_tuning_parity` pass.
- The import shows no script or parse errors.
- Golden is untouched, since the change only runs when the solver is missing. CI checks it.
- **Not tested:** the release path itself, which needs an exported release build without
  the assembly. Debug runs never reach the new lines.

## Also from the audit (no change in the repo)

Export hygiene needs nothing in the repo:
- Nothing in `game/`, `ui/`, `sim/` or `workshop/` reads `tools/`, `docs/` or `tests/`.
  Only the `tools/` suites read `tests/fixtures`, through `FileAccess`.
- `export_presets.cfg`, `out.png.import` and `Claude outputs/` aren't tracked (`*.import`
  is gitignored).
- The fix is in Michael's local export preset: exclude
  `tools/*, docs/*, tests/*, logs/*, Claude outputs/*`, and delete the local
  `out.png.import`.
- A `.gdignore` in `tools/` would break `--script res://tools/...`, so I didn't add one.

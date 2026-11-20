# Herald: remove the dead dev labs

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is step 1 of the cleanup rollout (Michael, Nov 19, via Seneschal). It removes the standalone dev labs that Argon's audit found dead (`docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md`). Zero drift: no game code path changes.

- **Dialogue lab:** `ui/dialogue_lab.tscn`, `ui/dialogue_lab.gd`, `ui/dialogue_vn_preview.gd` and their suite `tools/test_dialogue_vn_preview.gd`. `test_dialogue` loses its lab section (18 checks of the lab's own controls, several of them in loops); its composer checks stay. The headless voice comparison, `tools/dialogue_preview.gd`, stays, and the docs now point to it.
- **Standalone Workshop lab scenes:** `ui/case_workshop.tscn` and `ui/case_workshop_lab.tscn`. Each was a bare full-screen Control holding a script that is still the live Workshop's base. The four suites that loaded them now build the script directly: test_workshop_ui, test_workshop_canvas, test_workshop_consequences and test_workshop_remaining. Every check is kept. A dev status line no longer names the deleted lab scene.
- **The Python trace viewer:** `tools/case_viewer.py` and `.html`, its two tests, its fixture, and `docs/case_viewer.md`. The Coroner's tool list in `docs/playtests/README.md` named it; no playtest review has used it.
- **Docs:** README, DESIGN (the dev-log and composer lines) and DIALOGUE_DESIGN no longer name the removed files.

## Small calls made on Michael's behalf

- **Kept `ui/workshop_comparison.gd`.** The audit listed it with the lab scenes, but `ui/case_workshop_canvas.gd` preloads it and the live Workshop's preview uses it.
- **Kept `tools/trace.py`.** The audit grouped it with the viewer, but it's the dev-log filter that README and TUNING_NARRATIVE document. It reads the main log, not the viewer's sidecar.
- **Kept the `.trace.jsonl` sidecar** (`detailed_logging`, `trace_capture`). The audit says to revisit it once the viewer is gone; that's for whoever owns the dev log to decide.
- **Kept the VN and expression proof-of-concept art.** `ui/vn_portraits.gd` still uses it.

## Not done here (follow-up)

The fixture-mode code in `ui/case_workshop.gd` / `ui/case_workshop_canvas.gd` is now reachable only from the suites: `_load_example`, `_open`, the LoadMockup and WorkshopExperiment controls, and the fixture-692 jury window. Lantern confirmed on Nov 19 that the live Workshop's `_ready` never calls `super`, so none of it runs in play. Removing it, including the jury window's "Show calculation" block that Lantern's phase 7 leaves with nothing to read, is a separate PR. Those suites test that code, so it needs a decision about what to keep.

## Measured

- **CI fast suites:** all 146 pass locally, including test_dialogue and the four Workshop suites.
- **Golden:** identical at `--tol 0` on all five seeds.
- **References:** a repository search finds no remaining reference to the removed files outside the archive, the handoff entries and the maintenance reports.

## Proposed for the backlog
None.

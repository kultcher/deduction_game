# 2026-11-19, Claude-Steward: Maintenance 2026-11-19, DEEP report (`maintenance/2026-11-19`)

- **Base:** origin/main `4e805c7`. **Status:** PR open, docs only. **Next:** Bailiff (merge);
  leads pick up their findings from `docs/maintenance/2026-11-19.md`.
- **What:** the DEEP report for `6e99d80..4e805c7` (118 PRs, #194 to #325), with Michael's
  Nov 19 one-off: the silent-skip sweep (E1b) and the playtest-suite rename (its own PR,
  `claude/rename-playtest-suites`, handoff `2026-11-19-1052-steward-rename-playtest-suites.md`).
- **Doc fixes here:** `tuning_catalogue.md` regenerated; the vigil sentence in `README.md`
  and DESIGN's Night actions brought in line with #233/#300; README code map gains
  `reading_confirm.gd`, `ui/term_defs.gd`, `tools/case_slate.gd`, `tools/measure_*.gd`;
  `docs/migration_notes.md`'s `CONNECTIONS` line updated for #290.
- **Top findings, by owner:**
  - Bailiff: the nightly full run shares `main`'s concurrency group, so a merge can cancel it (A1).
  - Herald: typed `withdraw` works outside a meeting (A2); raw reason ids in the
    carried-answers note (A7); "accused" short form on counter-claims (A8).
  - Lantern: several doubted readings in one judgement are still order-dependent (A3, Nov 17 A4).
  - Beadle: frame memory replaces a lie's motive with raw alternative text (A4); the
    daytime-whereabouts defence can point at a teammate and names the dead (A5, A6);
    `DEMON_CROWD` is a constant outside `tuning.gd` with no approval on record.
  - Quill: "was the Demon when hanged" holds for any evil hanged person (for Michael).
  - All leads: about 27 silent-skip sites in 17 suites (E1b), 7 of them high risk.
- **Measured:** nothing played. The review is from reading. CI on `main` comes from the
  Actions API (last 100 runs). The build was run only for the rename PR's suites.

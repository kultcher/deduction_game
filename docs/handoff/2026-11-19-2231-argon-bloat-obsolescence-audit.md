# 2026-11-19, Argon: Codebase bloat & obsolescence audit (`argon/bloat-and-obsolescence-audit`, docs only)

- **Base:** `origin/main` `17dd113f`.
- **What and why:** Added [docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md](docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md) documenting:
  - **Module split candidates** across `sim/`, `workshop/`, `game/`, and `ui/` (Tier 1–4, noting which files to hold until Lantern's Connections purge Phases 5–6).
  - **Dead code and obsolete systems beyond the Connections purge**, notably the unused `channel_*` factored-evidence stack (~2,420 lines, 0 live callers), the Python/web trace viewer (`tools/trace.py`, `tools/case_viewer.py`, `tools/case_viewer.html`), standalone dev labs, one-off `tools/` scripts, and retired flags/constants in `sim/`.
- **Verification:** Docs only; zero code or golden changes. Line counts and caller references verified directly against `origin/main` `17dd113f`.
- **Overlaps:** None (two new markdown files under `docs/maintenance/` and `docs/handoff/`).

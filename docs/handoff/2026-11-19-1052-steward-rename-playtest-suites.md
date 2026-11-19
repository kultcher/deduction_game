# 2026-11-19, Claude-Steward: playtest-named suites renamed by what they guard (`claude/rename-playtest-suites`)

- **Base:** origin/main `4e805c7`. **Status:** PR open, tests only, zero drift. **Next:** Bailiff.
- **Why:** Michael, Nov 18 (relayed by Seneschal): suites named after old playtests or dates
  looked tied to those playtests. They now say what they guard. Each header keeps its
  provenance and gains a "Named … until Nov 19" line.

| Was | Now |
|---|---|
| `test_playtest_1709` | `test_dialogue_fixes_accusations_votes` |
| `test_playtest_12926` | `test_dialogue_fixes_gossip_reasons` |
| `test_playtest_13910_dialogue` | `test_dialogue_fixes_testimony` |
| `test_npc_behaviour_1110` | `test_npc_fixes_shifts_dead_haunt` |
| `test_small_fixes_1109` | `test_board_fixes_marks_crowd` |
| `test_workshop_ui_1110` | `test_workshop_ui_selection` |
| `test_triage_nov16` | `test_fixes_crowd_augur_lovers_pan` |

- **Also:** the `.uid` files moved with their suites, and the UIDs are unchanged.
  `tools/ci_fast_suites.txt` now lists the new names and is re-sorted. Five entries on
  `main` were already out of order, four of them appended at the end. Sorting moves which
  shard runs some suites, and nothing else. CLAUDE.md's named-suites example used
  `test_triage_nov16`; it now names `test_beliefs test_codex_fixes`.
- **Not changed:** dated records (handoff entries, earlier maintenance reports,
  `docs/handoff_log.md`) keep the old names, since they describe what was true then.
- **Coordination:** no open PR (#282, #289, #316, #319, #320, #321, #324, #326) touches these
  files. Herald's fix to the old `test_workshop_ui_1110` should go on
  `tools/test_workshop_ui_selection.gd`.
- **Measured:** built at this branch (Godot 4.7.2 .NET, Debug) and ran the seven renamed
  suites: 7/7 pass. No golden capture, since only test files and their list changed.

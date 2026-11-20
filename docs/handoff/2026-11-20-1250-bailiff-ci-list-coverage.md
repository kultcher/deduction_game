# 2026-11-20, Claude-Bailiff: CI suite lists widened from Quill's coverage audit (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `dabcb40` (#425).
- **Status:** CI config lists and one CLAUDE.md rule. PR open.
- **Next actor:** Bailiff merges on green. Michael may want to read the CLAUDE.md change.

## Why
On Nov 20, two suites on neither CI list broke main and no PR caught them:
`test_social_credibility` (after #395) and `test_own_gift_doubt` (a fixture fit, fixed by #397).
A third, `test_workshop_live_canvas`, failed only in my local run of #395. Seneschal asked
Quill for an audit of the 83 suites on neither list. All 83 pass on main `d242a1f`, and none
is dead.

## What changed
- **`tools/ci_fast_suites.txt`:** the 61 suites under about 15 seconds, by Quill's timings
  (387 seconds in all, about 1.6 minutes per shard), now run on every PR. The header now
  describes what the list holds. It goes from 153 suites to 214, still sorted.
- **`tools/ci_slow_suites.txt`:** adds Quill's five simulation-heavy suites from 15 to 60
  seconds (`test_trace_solver`, `test_social_credibility`, `test_shadow`,
  `test_conversation_gifts`, `test_npc_interactions`), plus `test_workshop_live_canvas`
  (about 21 seconds), which caught #395. It goes from 4 suites to 10, so each shard on a
  `sim/` or `workshop/` PR runs two or three slow suites instead of one.
- **Main only, as Quill proposed:** the other ten UI and Workshop-view suites from 15 to 60
  seconds, and the six at 60 seconds or more. `test_own_gift_doubt` alone takes over 12
  minutes.
- **`CLAUDE.md`, the Tests rule:** a new suite under about 15 seconds goes on the fast list,
  whatever it covers. A slower one about NPC behaviour or belief may go on the slow list.

## Not measured
Shard times on GitHub's runners after the change. Quill's timings are local, one suite at a
time. This PR's own CI runs the new fast list, but not the slow list, since it touches no
`sim/` or `workshop/` file.

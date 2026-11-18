# 2026-11-18, Claude-Herald: the count line, checked on a constructed reading (`claude/herald-count-line-case`)

- **Base:** main after #204. **Status:** PR open, zero drift. **Next actor:** Bailiff; Lantern may want to look, since it touches `workshop/reason_attribution.gd`.
- **Source:** the follow-up I promised Lantern on #204. Once each card is credited only with what it moves, no natural count reason arises in `test_wording_89077`'s seeds, so its "found" check became informational.

## What changed

- **`workshop/reason_attribution.gd`:** the wording of a "taken together" reason (why_own, why_public) moves unchanged out of `_augment_joint_leave_one_out` into `static func joint_whys(view, cand, pid, csrc, self_id, crole, attended)`. It's a pure move, and golden is identical.
- **`tools/test_wording_89077.gd`:** a new `_count_line_constructed()` that calls `joint_whys` with a Lamplighter count that names nobody, and checks that:
  - its holder says "my count of folk abroad...";
  - the town reads "the Lamplighter's count...";
  - someone else says "Agnes's count...";
  - none of them says "among the likeliest";
  - a Night Watch reading that names the person still "points at them", not the count line.

  The checks on played games stay as they were.

## Measured

- Passed: `test_wording_89077`, `test_joint_reasons`, `test_workshop_why`, `test_workshop_regressions`.
- Golden is identical to main's baseline on all 5 seeds.

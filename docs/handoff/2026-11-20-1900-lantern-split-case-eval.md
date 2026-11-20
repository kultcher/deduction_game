# 2026-11-20, Claude-Lantern: split case_eval.gd into a chain of four modules (claude/split-case-eval)

- **Base:** main at 918a7bd4 (after #414).
- **Status:** PR open. **Next:** Bailiff.
- **Zero drift:** code moved, not rewritten. Golden identical at `--tol 0`.
- Backlog: "File splits, Tier 2", `workshop/case_eval.gd`.

## What changed

`workshop/case_eval.gd` had 1,848 lines. It is now an inheritance chain:
`case_eval.gd` extends `case_eval_classes.gd` extends `case_eval_content.gd` extends `case_eval_base.gd`.

| File | Lines | Holds |
|---|---|---|
| `case_eval_base.gd` | 26 | the preloads and the constants every part uses (DEFAULT_ERR, OWN_ERR, LR_*) |
| `case_eval_content.gd` | 309 | chance of content (`chance_content`, the Rumormonger and Chronicler rates, ROLE_CONTENT_FIXED), the valid tables, the universe index, `neutral_listener`, the premise masks, `reading_error`, and their caches |
| `case_eval_classes.gd` | 1,026 | `compile()` and the class machinery: the C# handle helpers, class likelihoods, own counts, team priors, fits (bare, personal, doubted-role), `_joint`, `_expand`; with SOFT_EVENTS, _MOVEMENT_ROLE_KINDS and their static vars (`cache_enabled`, `prior_k`, `doubted_role_check`, `use_cc_reps_handle`, the caches) |
| `case_eval.gd` | 502 | the public face: `evaluate` and the posterior passes, `shift`, `category`, `category_text`, `_people`, `_rivals`, `_theory_fit`, `_pivotal`, `strength`; `capture_worlds` and `captured` |

- Every `CaseEval.<fn>` and every `preload("res://workshop/case_eval.gd")` caller is unchanged:
  functions, constants and static vars are all inherited.
- **No loader was needed.** With this grouping no function calls one further down the chain
  (checked with a call-graph script), so no call needed a prefix and `_case_eval()` would have
  been dead code. Nothing in the moved code changed.
- **Constants differ slightly from the suggested grouping:** ROLE_CONTENT_FIXED stays in the
  content file, because its doc comment is half of `chance_content`'s, and SOFT_EVENTS and
  _MOVEMENT_ROLE_KINDS stay in the classes file, the only place they're used. The base holds
  the constants used across files. `solver.gd` still reads `CaseEval.ROLE_CONTENT_FIXED`
  through the outer class.
- The README code map has an entry for the new files.

## Static vars

Each of the 18 static vars is declared once, in the file whose functions use it; nothing
redeclares one. Tools and tests set or clear them through `CaseEval` (61 accesses in 10 files,
including `workshop/caches.gd`'s `clear_all()`), and that class is now the outermost subclass.

- A two-class probe in this Godot (4.7.2) showed that a static var declared in a base script and
  set through a subclass's name is one storage: assignment, `+=`, dictionary mutation and
  reassignment through either name are seen through the other.
- A probe on the real chain set every cache, flag and counter through `case_eval.gd`, read them
  back through `case_eval_content.gd` or `case_eval_classes.gd`, and ran `Caches.clear_all()`.
  No mismatches. Both probes were deleted.
- No C# or string lookups target CaseEval functions (`workshop/cs/*.cs` only names the file in a
  comment). Nothing reads case_eval.gd's source text.

## Measured

- **Import:** `godot --headless --path . --import`: no parse or script errors; `.uid` files committed.
- **Pure move:** a script compared the old file (origin/main) with the four new ones. All 100
  declarations (64 functions, 18 static vars, 18 constants) appear exactly once, each with an
  identical body; there are no new declarations. Every non-blank line of the old file is
  present, and the only added lines are the 15 header lines (headers and `extends`).
- **Golden** against `baseline_7005cc6` at `--tol 0 --ignore engine`: all 5 seeds identical
  (42, 900, 692, 54875, 98933).
- **Speed (for Argon):** one golden capture each, run alone on the same machine: origin/main
  183.7 s, split 184.9 s (+0.6%, within noise).
- **Suites:** the whole CI fast list (215 suites, which includes every suite named for the judge, the
  workshop, the premise steps and the Connections cases, and every suite that sets a CaseEval
  static var) plus `test_tuning_hoist`: 216 of 216 pass, run in two parallel chunks.

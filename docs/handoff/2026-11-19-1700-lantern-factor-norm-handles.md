# 2026-11-19, Claude-Lantern: movement factor handles shared only on the same scale (`claude/factor-norm-handles`; golden moves at rounding level only)

- **Base:** main `f831dbe`. **Status:** PR open. **Next:** Bailiff; then Quill merges main into
  `claude/lamplighter-count` and resumes the Lamplighter fix (b), step 1.
- **Why:** Seneschal asked me to diagnose Quill's seed-900 cache-parity failure on the Lamplighter
  branch, and approved this fix (Nov 19). It's correctness, not speed. Argon may want to know,
  since its cache code is next to this.
- **The cause:**
  - When a Night Watch list or Lamplighter count is mixed as sound or broken, the kernel's
    `AttachListMix` calls `SetListNorm`. That writes the sound branch's scale into the broken
    branch's compiled factor, and into everything under it.
  - `LiveActivity._ensure_factor_handle` shared one handle between every factor with the same
    content. So a broken branch identical to a factor used on its own rewrote that factor's
    scale, and the last mix to attach decided how the other factor scored.
  - Turning a cache on changes which judgements run and in what order, so beliefs moved.
    `Connections.cache_verify` couldn't see it, because a fresh judgement reads the same
    rewritten handle.
  - A broken count says nothing, so its branch is the case's factor without the count, which the
    NPC also builds on its own. That's why the Lamplighter branch hit this hard.
- **What changed:**
  - `_ensure_factor_handle(factor, norm)` keys a handle by its content and the scale it's scored
    on. A broken branch takes its mix's own scale, or an outer mix's, since `SetListNorm` runs
    outermost last. A sound branch keeps its parent's scale.
  - The MRU shortcut checks the scale too, and `Caches.clear_all` resets it.
- **New `tools/test_factor_norm_handles.gd`** (3 checks, fast list): a plain factor scores the
  same before and after a mix whose broken branch shares its content, and in either order. It
  fails without the fix (0.500 before, 0.476 after).
- **Measured:**
  - **Quill's branch:** with each broken branch on its own handle (my probe at Quill's `bd2bbc8`),
    `test_connections_cache` passes. Without it, on the same build, it fails.
  - **This branch:** `test_connections_cache` passes, including its `cache_verify` sections, along
    with `test_connections_core`, `test_connections_cases`, `test_nightwatch_whole_list`,
    `test_vigil_nightwatch`, `test_warden_quiet_route`, `test_sighter_contest`,
    `test_demon_types`, `test_relayed_alibi` and `test_workshop_regressions`.
  - **Golden:** moves on seed 42 only, in 2 values at rounding level, the first 3e-17 at
    record 72. That's the same collision on main, between two scales that differed only in the
    last digit. The other four seeds are identical, and seed 42 matches at `--tol 1e-12`.
    Re-baselined to `baseline_1089dd9`; two captures were identical.
- **Proposed for the backlog:** none.

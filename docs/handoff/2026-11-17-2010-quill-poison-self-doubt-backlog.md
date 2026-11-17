# 2026-11-17, Claude-Quill: BACKLOG, the poison self-doubt (`claude/poison-self-doubt-backlog`; docs only)

- **Base:** main. **Status:** PR open, docs only. **Next:** Bailiff (review and merge; docs-only
  PRs skip the suites and golden).
- **What:** adds Michael's Nov 17 decision to BACKLOG as **[decided]**: "A listener's doubt that
  its own reading was poisoned". It's the design Quill and Lantern sent through Seneschal,
  approved with no new number and no confidence dial:
  - Self-doubt is the poison explanation's share against the most trusted clashing teller.
  - The teller is judged without the listener's own reading in view.
  - The doubt applies from the next refresh.
  - When two own readings clash, leave-one-out finds the culprits, and the doubt is split by
    each night's poison chance. It's split equally when there's no single culprit, or for
    Delusional.
  - Confirmed-reading weighting is left for later.
- **Split proposed to Lantern:** Lantern builds the connections side (clash signal, lean
  without the reading, doubt into `honest` via #216, proof exemption, own-against-own, the
  suite and the golden re-baseline). Quill builds the per-night poison chance in `workshop/`
  as a first, zero-drift PR, and the judge-level measurement at fixed states.
- **Order:** after #214 (the #186 role-check fix, merged). It moves golden, so it joins the
  queue when ready.

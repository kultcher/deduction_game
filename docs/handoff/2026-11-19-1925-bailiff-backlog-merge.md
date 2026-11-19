# 2026-11-19, Claude-Bailiff: Beadle's #353 (closing built items) merged on top of Vicar's #354 reconcile (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `4775f4d` (#354), plus #353's head `2c7944b`.
- **Status:** docs only, PR open. It carries #353's commits, so #353 shows as merged with it.
- **Next actor:** Bailiff merges. Seneschal knows.

## Why
Michael asked for the docs-only PRs to merge ahead of the code queue (Nov 19, via Seneschal).
Vicar's #354 (the BACKLOG reconcile) merged first. Beadle's #353 then conflicted with it in
`BACKLOG.md` and `BACKLOG_COMPLETED.md`, because both closed some of the same items.
Seneschal's rule: keep both sets of changes, with Vicar's reconcile as the base.

## How it was resolved
- **`BACKLOG.md`:**
  - Where Vicar moved an item to completed, it stays moved: "The phase advances…" and
    "Backing a strong case builds trust".
  - Vicar's new "on hold" note on bolder lies is kept.
  - Beadle's close of "A bluffer's frame memory" (owner Beadle) is taken.
- **`BACKLOG_COMPLETED.md`:** Vicar's reconciled section comes first, then Beadle's section.
  Six of Beadle's seven entries were already in Vicar's section with Vicar's closing notes:
  - the wave-down;
  - the whereabouts gift refusal;
  - "it's another of us";
  - reading trust;
  - lie severity;
  - the daytime-whereabouts defence.

  They are kept once, in Vicar's form. "A bluffer's frame memory" is added under Beadle's
  heading.
- **Check:** each of those eight items, plus honest forgetting, appears exactly once, in the
  completed file, and none is still open in BACKLOG.md.

## Not changed
- Beadle's handoff entry comes in with #353.
- #349's section 6 edit, which Seneschal mentioned, isn't on main yet. It will rebase onto
  this when #349's turn comes.

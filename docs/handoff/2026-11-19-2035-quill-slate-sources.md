# Case slate: sources hear the case, and a case between Strong and the top tier

**Claude-Quill, Nov 19.** Base: main at 17dd113 (#346 and #355 merged). Status: ready for review. Next actor: Bailiff. This is tooling,
with no game code, so golden doesn't move.

## What changed and why

- **Sources hear the case** (`tools/case_slate.gd`). Each case used to be presented to every
  good listener but its sources. So the witnesses, readers and victims voted without having
  heard it, and the Strong tier looked hardly stronger than Moderate. Among those who
  heard, the badge already separated cleanly. A presentation at a meeting reaches the whole
  town, so cases now go to every living good townsperson but the subject. Seneschal
  approved this on Michael's behalf, as tooling.
- **The "Heard it" and "Of those, yes" columns are kept.** They are the row fields
  `heard_good`, `yes_heard` and `yes_heard_before`, plus a report column.
- **A new case, `two_kills_seer`:** two killings, the vigil and a witness at each, and the
  Seer's "yes" on the Demon on both nights. It's about an 82% chance, ×8.0, and it fills
  the gap between Strong and the top tier. It has no innocent twin, like the other Seer cases.
- **The report knows the Damning badge** (#357), and its own town bands gain one from +45.
- **The baseline is re-made:** `docs/case_slate/baseline.jsonl` and `baseline.md`.
  `README.md` is updated.

## Measured (the full slate: 28 cases, 275 deals, on main at 17dd113)

- The juror's strengths are unchanged on every case. The badges are #357's cut points.
- #346 and #349 move nothing on the slate (within 0.1 of a point).
- On the proposed tiers, the good votes swayed by true cases are:

| Tier | Before | Now |
|---|---|---|
| Weak | 1.6 | 2.0 |
| Moderate | 3.2 | 4.2 |
| Strong | 3.8 | 5.4 |
| Top | 6.9 | 6.9 |

- Strong cases now hang on good votes alone in 100% of deals. Moderate does in 38%, Weak in
  12%.
- No misleading twin hangs an innocent on good votes alone. Moderate twins hang with the
  player's vote 35% of the time, as before.

## Proposed for the backlog

None.

# 2026-11-17, Claude-Bailiff: overnight merges, and what's blocked (`claude/nice-mayer-naok85`)

- **Base:** main `317e040` (#194). **Status:** docs only. **Next actor:** Michael (the items
  under "For Michael"), then Bailiff (the golden queue below).
- **This was meant to be the morning summary.** My session was idle from about 08:10 to
  18:10 UTC, so nothing merged in that window and this note is late.

## What merged (22 PRs, main `c676018` → `317e040`)

**Process**
- #196: handoff entries are one file each in `docs/handoff/`; `docs/handoff_log.md` is frozen.
- #206 (mine): `tools/ci_fast_suites.txt` is kept sorted, so PRs that add a suite rarely
  conflict on it. Same 67 suites; the slowest CI shard goes from about 249 s to 263 s by
  local timings.
- Roster rows for Vicar (#184) and the Coroner (#197, with `docs/playtests/README.md`).

**Game behaviour, zero drift** (golden identical)
- #173: a good NPC passing on someone else's lie is no longer logged as the liar.
- #178: `ask night` can give the night's gift result, behind `ask gift`'s gate.
- #179: the daytime-defence voice lines (your wording).
- #187: purge phase 6b. Four belief signals read every card an NPC holds, not only the
  attended ones.
- #189: tests pinning the Warden failed-protection challenge (no game code).
- #191 and #195: a challenge on a Medium's relay names which side it blames, in the judge
  and in the Workshop menu.
- #192: a no-card case's compile key includes the view's cards.
- #198: the double-claim pairing.
- #202: end-of-case counts leave out the dead.
- #182: purge phase 2. The suites pinned to the earlier model now run on connections (tests
  only).

**Golden moves** (each re-baselined on the main it landed on)
- #193 (Beadle): a liar who notices tells a better lie. Baseline `baseline_85e9b36`.
- #194 (Quill): a Delusional teller's wrong reading is priced once, not twice. Baseline
  `baseline_928cb8b`.
  - On seed 98933 the town now hangs Isolde (the Revenant) on day 2 and Odette (the Demon)
    on day 3, and good wins. Before, it hanged Merrin, a good Surveyor, and the case was
    open at day 4.
  - I caught a real bug in it on the way: a listener doubted their own readings as if
    they might be the Delusional one. Quill fixed it; the test didn't change.

**Docs:** #174, #177, #180, #185, #190.

## How they were checked

GitHub PR CI was stalled all night (jobs queued, never started). Instead, I merged each
group locally on the current main and ran the CI fast list, plus each PR's own suites and
a golden capture at `--tol 0` (two captures for the golden-moving ones). Then I merged in
that order and checked that main's tree matched what I'd tested. Codex had reviewed every
code commit that went in. **Not run: the full ~165-suite set on main** (CI would run it on
each push to main, if Actions were running).

## For Michael

1. **GitHub Actions isn't running jobs.** Every PR's CI sat queued for hours. That looks
   like an Actions minutes or concurrency limit on the account (Settings → Billing →
   Actions). Until it's fixed, local runs are the only gate, and the full suite hasn't run
   on main.
2. **Small call made on your behalf, through Seneschal:** keeping the fast list sorted
   (#206).
3. **Beadle's question from #188** is still open: a held-back fabricated reading is told
   unchanged the next day. Keep it, re-check it on the day it would be told (Beadle's
   recommendation), or drop it after one hold?

## Still open, and on whom

| PR | What | Waiting on |
|---|---|---|
| #203 | Relayed alibi (Lantern), zero drift | My local run on 317e040, in progress |
| #199 | Insight's joining bar (Lantern), golden | Lantern re-baselining on 317e040 (next in the queue) |
| #201 | 89077 wording (Herald), golden | After #199 |
| #205 | 89077 routing (Beadle), golden | After #201 |
| #204 | 89077 count reasons (Lantern), golden | After #205 |

# Backlog sweep against #558 to #602 (Claude-Vicar)

- **Base:** main at 6e8f3fb9 (after #590).
- **Status:** docs only, ready. **Next actor:** Bailiff to merge.

## What I checked

Every PR merged since the last sweep (#557), from #558 to #598, against BACKLOG.md, by reading
each one's handoff and diff. I also checked the PRs still open (#599 to #602, #597, #578, #568,
#282) and every item that carried an in-progress star.

## Closed (moved to BACKLOG_COMPLETED.md, "Built, Nov 28, 2026 (closed by Claude-Vicar)")

| Item | Built in |
|---|---|
| Withheld readings: asking for what someone hasn't said | #542, #545 ("Call on"), #588 (asking, pressing, answers, the refusal record), #592 (the cost) |
| A friend's doubtful defence | Beadle, Nov 22, merged with #547: the line tier, the reluctant yes and the trust damping |
| Graded gossip | #431, #437 (Nov 20); the star was stale |
| Movement wording: "pass by" and "road" | #446, #448 (Nov 20); the star was stale |
| A reason citing a pairing the model didn't weigh | Lantern, #444 (Nov 20); the star was stale |

## Updated

- **Argon's audit: cleanup:** tier 2 of the file splits is done (social #452, and Lantern's
  `live_activity` and `case_eval` splits). The star is removed. What's left is the deferred
  `LEGACY_EXTRA_SHIFT_DRAW` call, and tier 3, which waits for the purge.
- **Passing information on:** starred as in progress, with Lantern's #599 and Quill's #602 open.
- **Release readiness:** the intro no longer says the architecture items are only a proposal,
  since #573 added them. The fix-as-you-go UI items are done (Herald, #579), and so is the
  Workshop cache reset (#574). "Sharp UI plaques" notes that the cache leak is fixed (#579).
  "Architecture cleanup" notes that the single source for tuning values is done (Argon, #577).
- **The contents list** was edited by hand. Its entries are renumbered where items closed.

## For Michael

- **A friend's doubtful defence:** its two values (damping from trust 0.75, up to 0.6 less at
  full trust) were set when it was built. The item said Beadle would propose them, and no
  approval is recorded. They're flagged in the closed entry.

The other merges in this range (Michael's Nov 28 UI items, the 52102 fixes, the Sexton's toll
tour, and the art, tooling and test fixes) had no backlog item to update.

Claude-Vicar

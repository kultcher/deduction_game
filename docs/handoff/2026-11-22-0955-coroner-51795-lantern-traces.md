# 2026-11-22, Claude-Coroner: Lantern's traces added to the 51795 journeys (`claude/playtest-51795`, PR #526)

- **Base:** main. **Status:** docs only, added to the open review PR #526. **Next actor:**
  Bailiff (merge), then Lantern.
- **What:** Lantern replayed the 51795 log at `ac3ec83` and answered three journey
  findings. I added its answers to `docs/playtests/51795_journeys.md`:
  - **Dorian's clash on Fenwick (finding 4):** sound reasoning, not a bug. His own Clerk
    reading half-cleared Fenwick until Fenwick's Archivist claim ruled him out as Medium.
  - **A suspected reader's readings still clear (finding 2):** confirmed over-clearing.
    One teller's readings are weighed one at a time against the listener's dawn view of
    the teller. Lantern will weigh them together on `mock/burdens-slot`.
  - **Odette's day-1 suspicion of Kiran:** confirmed as Merrin's private tip (+0.67 of
    +0.89).
- **Also:** I pushed the log for Lantern to `mock/playtest-51795-log`
  (`logs/playtest_51795.jsonl`, `d08734b4`). That branch never merges.

## Measured, and on what

- Lantern's numbers come from the playtest build, seed 51795 only. It hasn't rechecked
  them at the branch tip. I didn't re-run them.

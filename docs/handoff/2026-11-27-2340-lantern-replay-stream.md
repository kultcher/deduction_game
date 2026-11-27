# 2026-11-27, Claude-Lantern: replay streams meetings like the UI (`claude/replay-stream`)

- **Base:** main `b4cbb60a`. **Status:** PR open. **Next actor:** Bailiff merges. Golden is untouched: the change is tools only.
- **Why:** Coroner, playtest 52102. `tools/replay_log.gd` reported "STATE DIGEST first differs after seq 133 (command yes)", even though every vote and both filed cases matched.
  - The UI streams a meeting one speaker at a time: `ui/main.gd` sets `g.stream_meeting`, and each step is logged as a `player_testimony` record.
  - `tools/log_replay.gd` didn't stream, so the replay's `yes` ran the whole first meeting in one command, and every per-step digest after it differed.
- **What changed (`tools/log_replay.gd`):**
  - A log that has `player_testimony` records now replays with `stream_meeting` on, and replays each such record with `g.testimony_step()`.
  - Logs without them (autoplay) replay unstreamed, as before.
- **Measured:** at the played build f6f0ae58, with the same change as a probe, 44 digests matched through seq 231, against 18 with the old tool.
  - From seq 233, one of the meeting's empty "waiting belief refresh" steps, Merrin's mind alone still differs. The random stream matches, and the votes are unaffected.
  - It isn't the caches. It's likely a UI call between testimony steps that touches Merrin's state (Herald's area). Not pinned down.
- **Suites:** test_state_digest and test_connections_why pass.

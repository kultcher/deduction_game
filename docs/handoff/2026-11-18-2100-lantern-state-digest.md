# 2026-11-18, Claude-Lantern: a state digest in the dev log, and the 16010 drift found: updated cases logged as new (`claude/state-digest`; logging only, zero drift)

- **Base:** main `29a0fba` (main `c60432a` merged in). **Status:** PR open. **Next:** Bailiff. The next playtest's replay will name
  where play and replay part, and replays updated cases correctly.
- **Why:** playtest 16010's replay drifts (Herald, #277). Nisha's suspicion of Isolde rises 0.0224
  on case #88 in the replay, just past the 0.02 that makes her say "partial", where play had her
  reject it. Dorian's vote and the night's kill then change. Every logged record before it
  matches play, so the difference is in state the log doesn't show.
- **What:**
  - `World.state_digest()` hashes, at full precision, each NPC's suspicion, trust, credibility,
    NPC trust and Workshop state (connections memory, presentations, cached reasoning), real mind
    and shadow, plus the world's RNG state.
  - `Game._finish_command` logs a `state_digest` after every command, and the Workshop's
    filing after every filing (switch: `Game.state_digests`, on).
  - `LogReplay.digest_hooks` compares the replay's digest after each command or filing with the
    logged one. `tools/replay_log.gd` prints the first difference: the seq, the command, whose
    mind, and whether the random stream differs.
  - No UI change is needed: the UI runs the same `g.command` and filing.
- **16010, found** (replayed at the played build `832bd17`, with Herald's int fix):
  - **In game terms:** twice the player went back to a filed case in the Workshop and updated
    it from the same premise. #88 (against Isolde) replaced #45 (against Agnes), and #136
    replaced #95. An update supersedes the old case, and listeners judge it that way. The log
    called every filing new (`"revision": false` was hard-coded, with no case replaced), so the
    replay filed #88 and #136 as fresh cases, and the old ones still stood. That was enough to
    move Nisha just past half-accepting #88, and Dorian's vote on Isolde followed.
  - **Measured:** replaying the whole game with #88 revising #45 and #136 revising #95, all 744
    replayed records match play to 1e-9: every stance, vote and tally. (The log's last 4
    records, the final execution and game over, come after the last command the replay drives.)
  - **Fix:** `workshop_canvas_filed` now logs `revision` truly and `revises` (the case number
    replaced, 0 for a new case). `LogReplay` files with it. A filing that the board merged
    into an existing card (`add_card`) is now logged too; it was the only filing that wasn't.
    Logs from before this replay every filing as new. A filing that shares its premise node
    (`argument_root`) with an earlier one is the likely tell, but I didn't add that guess.
  - **Ruled out on the way:** the Test juror and town note, caches (static and per-listener),
    global randomness, time limits, the case's numbers, and writes from `ui/`,
    `game/workshop_canvas.gd` or `game/workshop_why.gd`. Building a new case doesn't touch
    listener state or the RNG.
- **Note:** until #277's int fix is on main, a replay can differ at the first filing (29 against
  29.0 in the case's key). That's the known replay bug, not play.
- **Tests:**
  - New `test_state_digest` (8 checks, on the fast list): a digest after every command; a change
    of a billionth shows; a faithful replay matches every digest; a tampered log is caught at the
    right command and mind; a retargeted case is logged with the case it replaces, and the replay
    files it as a revision (that check fails with the old replay).
  - Golden is untouched: the digest is a dev-log record, and golden doesn't read the dev log.

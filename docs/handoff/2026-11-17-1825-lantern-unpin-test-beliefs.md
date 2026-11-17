# 2026-11-17, Claude-Lantern: test_beliefs runs on connections; the Delusional self-doubt item (`claude/unpin-test-beliefs`)

- **Base:** main `6e99d80` (#198 merged). **Status:** PR open. Tests and docs only; golden
  unchanged. **Next actor:** Bailiff merges.
- **test_beliefs:** its last two checks pinned to the earlier model now run on connections
  (purge phase 2's leftovers): the doubted own reading (fixed by #186) and the double claim
  (the pairing, #198). The suite passes with no failures and no `Connections.enabled = false`.
- **BACKLOG:**
  - New **[decided]** item, Michael's decision of Nov 17 relayed by Seneschal: "A listener's
    small doubt that their own gift is Delusional", about the Sleepwalker's 10%, one new
    constant. Owner Lantern, role-check side Quill; built after #194. The split is being
    agreed with Quill.
  - The double-claim item moves to `BACKLOG_COMPLETED.md` (built in #198).
- **Answered for Michael** (by message): with no challenge heard, NPCs carry no standing
  doubt that their own reading was poisoned (a fixed 0.2% error; poison isn't in the judge's
  worlds). Doubt comes only from an accepted "misled" argument or a contradicted Night Watch
  list; #186 made that doubt reach the role check.

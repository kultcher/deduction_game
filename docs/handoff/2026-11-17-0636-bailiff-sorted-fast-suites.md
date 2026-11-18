# 2026-11-17, Claude-Bailiff: the CI fast list is kept sorted (`claude/nice-mayer-naok85`)

- **Base:** main `6e23428` (#189). **Status:** tools and docs only, PR open. **Next actor:**
  Bailiff merges it, then every open PR that adds a suite merges main in once.
- **Why:** every PR that adds a suite appended it to the end of `tools/ci_fast_suites.txt`,
  so any two such PRs conflicted on the last line (#191, #202, #179, #195, #189 all did
  tonight). Same problem as the single handoff log. Seneschal approved the fix as a small
  call on Michael's behalf (Nov 17), to be listed for him in the morning.
- **What changed:**
  - `tools/ci_fast_suites.txt`: the 67 suites sorted alphabetically (no suite added or
    removed), with a header saying to insert new suites at their place. The old "Measured
    Nov 5: about 2.5 minutes" note is dropped, since the list has grown since.
  - `CLAUDE.md`, the Tests rule: add a fast suite at its alphabetical place.
- **Shards:** CI deals the list to the four shards in file order (suite i goes to shard
  i mod 4), so sorting reshuffles them. From the per-suite times of my local batch-3 run
  (this machine, 4 cores, not CI's runners):

  | | Shard 1 | Shard 2 | Shard 3 | Shard 4 | Slowest |
  |---|---|---|---|---|---|
  | Before (file order) | 151 s | 110 s | 249 s | 199 s | 249 s |
  | Sorted | 203 s | 263 s | 132 s | 111 s | 263 s |

  The slowest shard goes from about 249 s to 263 s, so a PR's CI wait is about the same.
  Not measured on GitHub's runners (PR CI was stalled tonight).
- **Checked:** `tools/test_map.py` still reads the list (165 suites; its fast-list figures are
  unchanged), and the sorted list has the same 67 names as before with no duplicates.
- **For open PRs:** on a `tools/ci_fast_suites.txt` conflict, take main's sorted file and
  insert your suite at its place.

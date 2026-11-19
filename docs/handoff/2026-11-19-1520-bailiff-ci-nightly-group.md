# 2026-11-19, Claude-Bailiff: the nightly CI run gets its own concurrency group (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `f831dbe` (#334).
- **Status:** CI config only, PR open.
- **Next actor:** Bailiff merges on green. Seneschal approved the change (Nov 19).

## Why
Steward's DEEP report (`docs/maintenance/2026-11-19.md`, A1) found that every CI run on `main`
shared one concurrency group, `ci-<ref>`. A group keeps a single pending run, and a newer one
replaces it. So a nightly run queued behind a push run was cancelled by the next merge. That
is the blind spot the nightly run (#221) was added to close: main stayed red unnoticed for
most of Nov 18, while its push runs kept being superseded.

## What changed
In `.github/workflows/ci.yml`, the concurrency group is now
`ci-${{ github.event_name }}-${{ github.ref }}`:
- the scheduled run is in its own group, so pushes can't cancel it;
- push runs still supersede each other, as before;
- pull requests still cancel their own earlier run, since `cancel-in-progress` is unchanged;
- manual runs get their own group too.

## Not measured
The scheduled run can only be seen working at its next firing (09:17 UTC). Check the
first nightly run after this merges to confirm it completes while a merge lands.

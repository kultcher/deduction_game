# Handoff entries

One file per entry, so no two PRs edit the same file. This replaced the single
`docs/handoff_log.md` on Nov 17, 2026; that file is frozen and keeps the history before then.

## Naming

`<YYYY-MM-DD-HHMM>-<agent>-<topic>.md`, for example
`2026-11-17-0530-quill-lie-severity.md`.

- **Time:** UTC, when you write the entry. It's what makes the files sort newest-last, so
  `ls docs/handoff | sort -r | head` lists the newest first.
- **Agent:** your name in lower case (`bailiff`, `lantern`, `argon`, ...).
- **Topic:** a few words joined by hyphens, usually the branch topic.

## What goes in it

The same as before. A heading `# <date>, Claude-<Name>: <title> (<branch or PR>)`, then:

- **Base, status, next actor.**
- What changed and why.
- What you measured, and on what.
- "Proposed for the backlog", if any (see `CLAUDE.md`).

## Rules

- **One file per PR.** A follow-up on the same PR (Codex fixes, a re-baseline) can update
  that PR's own file. A later PR gets a new file.
- **Never edit another agent's entry.** To answer one, write your own and refer to it by
  file name.
- **No index file:** the file names are the index. An index would bring the conflicts back.

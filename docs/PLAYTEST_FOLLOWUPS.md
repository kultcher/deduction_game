# Playtests 78148 / 77388 follow-ups

Branch: `codex/playtest-ui-followups`, from main `e674193` (Oct 27).
Seven deferred items and their risks/decisions are recorded in BACKLOG.md under
"Playtests 78148 / 77388: deferred follow-ups". This pass covers the remaining UI
and bounded fixes, plus PR #25's volunteered-sighting delivery review.

Validation and implementation notes are added alongside each change. Existing
`test_workshop_protection` failure "disabling shared model restores native
quiet-night credit" remains the user-approved baseline exception. Full runner
skips `test_trace` unless requested explicitly; any skipped coverage is reported.

## Dialogue menu layout

Each section now has one heading spanning its balanced columns. Popup sizing waits
for themed container minimums, removes obsolete picker children synchronously and
bounds the popup to its owner; overflow remains scrollable with focus following.
Native option indices, callbacks, disabled states and keyboard neighbours survive.
Embedded popups and anchors use logical viewport coordinates, including a physical
1600×1200 window stretched from an 800×600 viewport (a reproduced clipping case).
The batch-3 column-count assertion follows the new shared heading container.

## Hide Unselected checkbox

Disabled checkboxes now use the same empty stylebox as enabled checkboxes instead
of inheriting a paper Button plaque with different content margins. Disabled text
uses the board's muted colour. Filtering and the no-selection disabled rule remain
unchanged; the theme correction also keeps other disabled checkboxes consistent.

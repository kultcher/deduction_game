# Quill: the case slate reports votes

Claude-Quill, Nov 19. Base: claude/lamplighter-count (#346) with Beadle's vote hook (#347)
merged in. Status: PR open. Next actor: Bailiff, after #346 and #347 merge (this branch
holds both). Tooling and docs only: golden can't move.

## What changed

Michael asked how a case moves votes, the real measure. Each slate row now records how the
good townsfolk would vote on the subject if a neutral nominator put them up, with the
player's vote left out (`MindMeeting.would_vote`, #347): before and after the case.

- "Before" is taken on a fresh build of the same deal, with the cards on the board but never
  presented. That's because a vote refreshes each voter's beliefs, as a real meeting would.
  Taking it in the same game moved the town column, by up to 6 points on one pile deal.
- The report adds a vote table per case. README and `baseline.md` describe it.
- No existing column changed: all 269 rows match the #346 baseline.

## Measured (269 rows, 10 deals per case)

True cases, under the proposed cut points (×1.25 / ×2 / ×3.5, top tier at 90%):

| Tier | Good votes swayed | Hangs with the player's vote too |
|---|---|---|
| bottom | 0.0 | 0% |
| Weak | 1.6 | 17% |
| Moderate | 3.2 | 38% |
| Strong | 3.8 | 90% |
| top | 6.9 (all of them) | 100% |

The misleading twins sway the same as their true cases.

## Proposed for the backlog

None. The badge tiers in vote terms go to Seneschal for Michael.

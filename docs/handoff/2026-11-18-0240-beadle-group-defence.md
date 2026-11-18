# Beadle: "it's another of us", a defence against group readings

- **Base:** main `80f7605`. **Status:** ready for review; lines await Herald's voices and
  Michael's approval. **Next actor:** Herald (lines), then Bailiff.
- **The item:** BACKLOG "A defence against group readings: 'it's another of us'" (89077,
  Coroner finding 1; Michael, Nov 17: approved).

## What changed (`sim/mind_meeting.gd`)
- **The defence:** a nominee named by a reading over a group says it's one of the others,
  the pair defence (`pair_other`) widened. The groups (`_reading_group`): a count over a
  group or site (Dowser, Hearthwitch), a role found within a group, a Chronicler's three, and
  a Surveyor's mixed block (its residents; 89077's Chapel Hill). Not a pair (its own defence)
  and not a Night Watch list (each person on it was seen, not grouped).
  - One or two others: named (`defence_group_named`). More, or an evil nominee whose group
    holds a teammate: "the others" (`defence_group_others`). Evil never names a teammate.
  - A good nominee uses it only when it suspects someone else in the group at least as much
    as the source; otherwise it challenges the reading as before. Like the pair defence, it
    accepts the reading, so it isn't also called wrong.
  - Speech only (scope "rival"), as the pair defence is.
- **A cited group reading reaches the defence** even when it names no one (a Surveyor's
  block): the nomination's info card counts if the nominee is in its group.

## Lines (Michael approved, Nov 18; voiced in Herald's #253)
- `defence_group_named` ({source}, {others}): "{source}'s reading points at one of us. It
  isn't me, so look at {others}."
- `defence_group_others` ({source}): "{source}'s reading points at one of several of us. It
  isn't me, so look among the rest."

## Small calls made on Michael's behalf
- "Small" means one or two others (a group of three at most), a fixed limit in the code,
  not a tuning value. A teammate among them means no names at all.

## Checks
- `tools/test_group_defence.gd`, 10 checks: named (three), unnamed (four), a Surveyor's
  block of two, an evil nominee who never names its teammate, and no group defence when the
  nominee suspects the source more.
- **Golden moves:** re-baselined to `baseline_c3b0f34` (see `docs/golden_baseline.md`):
  54875 and 692, a group defence in place of a "lying" line; outcomes unchanged. Two captures
  were identical.
- **Suites run:** test_group_defence, test_playtest_23973, test_playtest_89077,
  test_meeting_m2c, test_meeting_m2d, test_defence_repeats.

Claude-Beadle

## Also in this PR: two test fixes (Michael, Nov 18, via Seneschal; zero drift)
- `test_playtest_13910_dialogue` `_ask_why_free`: the "checking costs nothing" check read a
  counter nothing had touched. It now asks "why" in a real conversation: a dead target's
  hint costs no question, and a live hint costs one.
- `test_npc_behaviour_1110`: the check pinning `ONGOING_INFO_EARLY_CLAIM == -0.4` is gone, so
  tuning that value can't break the suite.

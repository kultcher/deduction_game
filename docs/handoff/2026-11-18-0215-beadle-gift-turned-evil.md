# Beadle: "my gift may have been turned", part (b) and the listener side

- **Base:** main `d2ffb20`. **Status:** ready for review. **Next actor:** Bailiff; Lantern
  reviews the `SourceDoubt.derive` block (agreed, Nov 18).
- **The item:** BACKLOG "Saying 'my gift may have been turned'" (Michael, Nov 17-18).

## What changed
- **When an evil NPC says it** (`Evil._boxed_in_gift_doubt`, `sim/evil.gd`): a reading it
  has held back twice running (the fabrication check found every telling would turn the
  town on itself or a teammate), for a gift it has claimed in public, is dropped. The NPC
  will say its gift may have been turned instead.
  - Only where a Poisoner (script minions) or Delusional (script secrets) could be in play.
  - At most once a game. No new number.
  - Logged: a "plan" think when it decides, and a "lie" think when it speaks, so the reveal
    lists it with its reason.
- **Saying it** (`MindMeeting._say_gift_doubt`): once, at the next testimony where the NPC
  shares readings, in Herald's per-voice `doubt_own_gift` line, with a public `self_doubt`
  event. No case-board card: a new card kind isn't one the Workshop's evidence takes (Lantern).
- **What listeners make of it** (`SourceDoubt.derive`, `workshop/source_doubt.gd`): honest
  doubt and pre_eval doubt on `<teller>:*` (all its readings, every night), the max with what
  is there, at the unreliable-argument scale (`DOUBT_ARG_UNRELIABLE_SCALE`, 0.5; Quill's
  pick) times 1 minus the listener's suspicion of the teller. The listener's own line is
  skipped. It sits after the sincere-teller pass on purpose: a sincere teller can still have
  a broken gift.
- **The reveal line** (Michael's wording, Nov 18, via Seneschal): "Claimed its gift as the
  {Role} might have been turned, to explain away a made-up reading." The full reason is kept
  in the dev log's "plan" entry and the lie entry's data.
- **Codex P2 (fixed):** the doubt now applies before the Gravedigger proofs (pass 2) and is
  put back after the sincere-teller erase, so a retracted Gravedigger "they were good" no
  longer settles the hanged one as sincere at full trust.

## What it does in play
- 30 passive 10-NPC games (seeds 3000-3029): it fired in 5 (3010, 3011, 3012, 3026, 3028),
  about 1 game in 6, and was said every time it was planned, a day after. Four of the five
  were Gravedigger bluffs (a hanged teammate is hard to report on), one a Dowser.
- Quill's caution: a 50% honest doubt on a decisive role-checked reading (a Gravedigger or
  Archivist naming someone) can move people a long way. A retracted reading that was the only
  thing clearing someone gives most of that back. That is intended, not a bug.
- Not measured: how votes moved in those 5 games.

## Checks
- `tools/test_gift_doubt.gd` (fast list), 27 checks: the trigger and its gates, the line and
  the public event, the reveal's lie in Michael's words, the listener's doubt (trusted,
  suspected, own line), and the retracted Gravedigger proof (Codex).
- **Golden:** zero drift. Two captures identical to each other and to `baseline_44073d9` on
  all 5 seeds (before merging main `d2ffb20`, whose #239 is also zero drift).
- **Suites run:** test_gift_doubt, test_role_check_doubt, test_delusional_reading,
  test_poison_chance, test_connections_core, test_evil_play, test_evil_owned_lie,
  test_fabrication_check, test_meeting_m2d.

## Small calls made on Michael's behalf
- At most once a game per NPC.
- No case-board card for the line (Lantern's advice); the player hears it in the meeting.

## Next
- Part (a), the good NPC at 25% self-doubt, waits on Lantern's rebuilt #232.

Claude-Beadle

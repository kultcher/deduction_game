# Codex batch 4: playtest 37291 follow-ups

Prepared by Claude, Oct 26, 2026, from the playtest 37291 issue list (Claude-driven play, user at the
controls) and the user's answers. This file is the spec; the prompt to paste into Codex is at the end.

## Start from

`main` at the commit that adds this file (after the Oct 26 merges). **Do not** branch from
`claude/own-readings`: that branch holds unfinished evaluator work (see `docs/seer_red_herring.md`) and
one known failing suite.

Expected baseline on `main`: `python3 tools/run_gd_tests.py --godot <godot>` gives **82/82 suites
passing**, and `test_trace` (slow, `--include-slow`) passes. Every failure you see after your changes
is yours to explain.

**Set-1 baseline observation:** untouched main `193b636` reproduced `test_workshop_protection` failing "disabling shared model restores native quiet-night credit" (81/82). The user authorized this exact baseline exception; evaluator/toggle code remains out of scope.

## Out of scope (Claude is doing these)

Do not touch them, even where an item below sits next to them:

- the belief model and evaluator: role-based readings not moving beliefs, the Seer red herring,
  stance/response/belief mismatches (including at the vote), the evil subject of a case "accepting" it,
  case sources "not following" their own evidence, the juror "followed" flag, the shared-model toggle;
- evil fake-info generation (day-gift bluffs like the Dowser, fake Night Watch blocks versus the
  bluffer's real location, fake reports versus known alibis);
- new evidence types (silence overlap and the like) and anything that changes strength numbers.

The standing boundaries still apply: no changes under `workshop/` or to `game/workshop_*.gd`; no vote or
nomination formulas; no belief numbers; no evil strategy beyond wording.

## Items

Each item: what to build, then the gotchas. One commit per item, with focused checks in a new
`tools/test_backlog_batch4.gd`.

### Dialogue and disclosure

1. **A refusal to say where they were must not give away where they were.** Isolde said "Where I go at
   night is my own business." and then "I did see Greta out on the Market" (twice). When
   `Mind.answer_night` refuses whereabouts, drop sightings that reveal the speaker's location (anything
   not seen from their own home street). Keep the existing slip mechanic as the only way such a
   sighting gets out, and when it does, word it as a slip ("…though I did see Greta on the Market,
   not that I was there").
   - Gotchas: `answer_night` has several branches (claimed walkers, evil Night Watch bluff
     `watch_story`, hidden walkers with a `vantage`, Sleepwalkers who honestly believe they were home).
     The fix belongs to the refusal branch only. The slip roll uses `w.rng`: keep the number of draws
     the same where behaviour doesn't change, so existing seeds don't drift.
     `Mind._answer_pressed_night` (batch 3) rewrites the first spoken line after a press: check that it
     still finds the right line.
   - **Implemented (Codex batch 4, set 1):** Only selected off-home sightings after a whereabouts refusal use the existing slip roll and explicit slip wording. Home-street observations and non-refusal, claimed-walker, Sleepwalker and gossip-zero paths retain their RNG behavior. Focused checks cover withholding, slips, fake-watch payloads and pressed responses. Exact-string expectations changed: none.

2. **Repeated refusals: no question charged, a different line.** A second identical refusal to the same
   ask in one conversation costs no question (the same free-repeat rule as `free_repeats` in
   `Game._talk_command`) and uses a varied line. Covers `ask gift` and the not-yet-told `ask are <gift>`.
   - Gotchas: `answer_is_role` already has the second-wrong-guess patience warning (batch 2) and now
     routes a matching disclosed role to `answer_gift` (batch 3). Don't break either. Refusals can now
     also become requests: `_answer_gift_impl` may return `r.request` (confidence or protection) in place
     of a refusal. A request isn't a refusal; leave that path alone.
3. **`ask why` only where it works.** It answers only a withheld meeting hint (`n.hints`). Remove it
   from the generic text help and from the in-conversation prompt string, and show it only when the NPC
   has a hint for someone alive (the UI button already does this). Vary "I've nothing more to tell you".
4. **"Ask about your readings" once a gift is told.** After someone has told you their gift (`max_tier >=
   3` or `claim_public`), relabel the UI's gift ask "Ask about their readings" and drop the
   re-confirmation line ("As you know, I'm the X") when there are readings to give. Same underlying
   `ask gift` and cost.
5. **Shorter answers without losing anything.** Answers ran to 5–6 lines. Condense, don't cut: merge
   several sightings into one sentence ("I saw Greta and Kiran on the Market, and Odette at the well"),
   one line per kind. Every card (fact) is still produced.
   - Gotcha: cards are made from `facts`, not lines; change lines only. `tools/test_text_ui.gd` and
     several dialogue tests match exact strings: update those expectations, and say which in the commit.
6. **No news of people standing in front of you.** Drop current-phase sightings of anyone at the
   player's location ("I saw Agnes at the chapel this evening" with Agnes there).
7. **First person about oneself.** Relationship notes and trait reveals said "Agnes and Edda are close"
   from Edda. When the speaker is one of the pair, say "Agnes and I are close" (or skip it). See
   `Game._maybe_tell_relationships` and `Game._maybe_tell_trait`.
8. **"Keep this between us", then public at the meeting.** When an NPC who asked you to keep a confidence
   goes public, give them a line that marks the change ("I've decided the town should hear it."). The
   confidence already lapses when they go public (`_break_confidences` checks `claim_public`).
   - Gotcha: the meeting testimony now streams (`Mind.testimony_step`, `Game.testimony_step`): add the
     line in `Mind._go_public`'s callers inside the step, not after the meeting.

### Meetings

9. **No empty nomination cases.** "Case against agnes: ." appeared (NPC nominations, 37291 and 1002).
   When the nominator has no reason to cite, they say so plainly ("I don't trust them, and I can't
   say better than that"). Find where `Mind.nomination_case`/`case_against` build the text. Wording
   only: no change to who nominates or why.
10. **Night sightings volunteered at the meeting** (user decision, Oct 26). A good NPC who saw someone
    out at night and hasn't told the town may bring it up during testimony. Check: Gossip plus
    Confidence against a threshold that drops as `Mind.paranoia` rises. Any past night counts, not just
    last night ("I saw Fenwick out on Night 2" can come out on Night 5), and each sighting is told once
    (`told_to` already tracks private telling; add a town key). Asked directly by the player, the same
    sighting is close to certain to come out (`answer_night` / `ask seen`).
    - Gotchas: this changes what the town knows, so it changes trajectories; note bot baselines will
      shift. It runs inside the streamed testimony: put it in `Mind.testimony_step` for the speaker, so
      streamed and one-go meetings stay identical (`tools/test_meeting_stream.gd` must keep passing).
      Use the existing sighting fact shape from `Mind.sighting_report` so the shared model can read it
      (don't invent a new card kind). Evil members don't volunteer true sightings of teammates (same
      rule as `answer_night`).
11. **Explain the vote count.** One line in help that the player's vote counts ("of 11" with ten
    townsfolk).
12. **Which night is the Demon's free night.** Say it in the Roles text and the first night prompt: the
    Demon doesn't kill on the night before you arrive (night 0) and kills from night 1.

### UI and text interface

13. **Approaches: say where.** Accepting an approach moves the player; print the same arrival block as
    `go` ("Present: …"), and name the place in the approach line before accepting.
14. **Looking isn't talking.** Clicking a portrait started a conversation and spent the phase. Make a
    single click select or inspect (profile), and talking an explicit action (button or double click).
    - Gotcha: `test_ui.gd` clicks portraits; update its expectations, and keep `_run_seq` working.
15. **Warn before walking to someone busy.** Show "busy" on the cast row and in the `go` result when the
    person is in a conversation (`busy_with`).
16. **Help text.** Add the newer actions: offer/apologise, promise yes/no, ask them to use their gift
    (`ask check/guard/watch`), `ask about <gift>` ("heard of a…"), presenting a ward or sigil.
17. **`ask check agnes isolde` without a comma** should work like `ask check agnes, isolde`.
18. **Night: who's home.** A line at night listing who is home on each block (what the map shows).
19. Lower priority if time allows: Roles window as a side panel option; offset name labels that overlap
    place labels on the block map; briefly highlight a trait bar when you learn that trait.

### Logging and the developer case summary

20. **The developer case summary (grimoire) shows the secret modifier**, not only the personal secret:
    print `secret_mod` (Marked was missing in 37291).
21. **Stale role name in a reason string:** `own info: hearthwitch count 0` should name the Dowser (find
    the reason text in `Mind`'s own-info effects).
22. **Every false reading carries a cause.** No `why: ?` in the lies list: where a reading is false
    (`true: false`), record why (poisoned, delusional, red herring, Marked, evil fabrication, fallback).
23. **Check dropped personal items are findable.** Fenwick's item at the wharf (37291 seq 466) was never
    found. Confirm `search` at that location finds it; if it can't, report why (don't change search
    odds).

## Test expectations

- Baseline `main`: 82/82 plus `test_trace`.
- Expect to update exact-string expectations for items 2, 3, 4, 5, 7, 9 and 14 (`test_text_ui`,
  `test_ui`, dialogue suites). Change the expectation, not the intent, and list each in the commit.
- Item 10 changes trajectories: tests that replay a seed to a specific later state may drift. Fix the
  setup (seed-independent), as done for `test_ui`'s influence check on Oct 26; never loosen a check.
- `test_meeting_stream.gd` must pass unchanged (streamed and one-go meetings identical).
- `tools/replay_54875.gd`: report timings before and after. Nothing here should cost measurable time.

## Prompt for Codex

> Start a new branch `codex/backlog-batch-4` from `main` (not from `claude/own-readings`). Read
> `docs/codex_batch4.md`: it's the spec for 23 items from playtest 37291, with gotchas for each. Build
> them in order, one commit per item, with focused checks in a new `tools/test_backlog_batch4.gd`.
> Respect the out-of-scope list and the usual boundaries: nothing under `workshop/` or
> `game/workshop_*.gd`, no vote/nomination formulas, no belief numbers, no evil strategy beyond
> wording. Where the spec is silent or conflicts with the code, stop and report rather than choose.
> Baseline on `main` is 82/82 suites plus `test_trace`; run the full suite at the end, explain every
> failure, and list every exact-string expectation you changed. Report timings from
> `tools/replay_54875.gd` before and after. Push the branch and report per item: what changed, the
> tests, anything skipped and why.

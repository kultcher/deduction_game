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

**Set-2 validation observation:** items 8–14 pass 361 focused checks, all 45 trace checks, and 82/83 full suites with only the same approved protection exception. The 54875 replay completes with 9 shared / 0 native listeners and no protocol errors. Its unchanged two-report case now receives 2 yes / 5 needed rather than 5 / 5. A frozen before/after comparison around item 10 confirms the change (case-board number 83 to 94) and a meeting-entry cost increase from 1850 to 2692 ms; presentation is 3154 to 3399 ms in that pair. No replay command exceeds five seconds. The outcome and added time are reported without tuning; bot baselines will shift.

**Set-3 validation observation:** all items 15–23 are implemented, including the user-approved item-19 presentation choices. Final focused checks: 474 passed. Full suite including slow trace: 83/84, with only the approved protection baseline exception; all six trace pairs passed. The original 54875 result remains 2 yes / 5 needed with identical listener assessments and vote margins and no fallbacks. See [set-3 report](BATCH4_SET3_REPORT.md) and the [item-10 performance/revert reference](BATCH4_ITEM10_REFERENCE.md).

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
   - **Implemented (Codex batch 4, set 1):** Repeated gift and undisclosed-role refusals vary their wording and share the existing single free player question per conversation. NPC fatigue, role guesses, trust costs, request handling and RNG remain intact, including the second wrong-guess warning. Exact-string expectations changed: none.

3. **`ask why` only where it works.** It answers only a withheld meeting hint (`n.hints`). Remove it
   from the generic text help and from the in-conversation prompt string, and show it only when the NPC
   has a hint for someone alive (the UI button already does this). Vary "I've nothing more to tell you".
   - **Implemented (Codex batch 4, set 1):** Conversation prompts advertise ask why only for a living hinted target; generic help already omitted it. Empty followups alternate wording without new RNG draws. Existing live-hint decisions and the UI gate are unchanged. Exact-string expectations changed: none.

4. **"Ask about your readings" once a gift is told.** After someone has told you their gift (`max_tier >=
   3` or `claim_public`), relabel the UI's gift ask "Ask about their readings" and drop the
   re-confirmation line ("As you know, I'm the X") when there are readings to give. Same underlying
   `ask gift` and cost.
   - **Implemented (Codex batch 4, set 1):** Private and public gift disclosure relabel both gift-ask UI controls as readings. Delivered readings or Warden door accounts omit the redundant confirmation; first disclosures, empty histories, all claim/readings cards and existing ask costs remain intact. Exact-string expectations changed: none.

5. **Shorter answers without losing anything.** Answers ran to 5–6 lines. Condense, don't cut: merge
   several sightings into one sentence ("I saw Greta and Kiran on the Market, and Odette at the well"),
   one line per kind. Every card (fact) is still produced.
   - Gotcha: cards are made from `facts`, not lines; change lines only. `tools/test_text_ui.gd` and
     several dialogue tests match exact strings: update those expectations, and say which in the commit.
   - **Implemented (Codex batch 4, set 1):** Sightings group people with the same place, time and provenance into shared clauses, with one spoken line per observation kind. Day replies retain conversation partners; private reading reports and recent-sighting followups share lines while every original fact and report date remains intact. Public testimony composition is unchanged. Exact-string expectations changed: none.

6. **No news of people standing in front of you.** Drop current-phase sightings of anyone at the
   player's location ("I saw Agnes at the chapel this evening" with Agnes there).
   - **Implemented (Codex batch 4, set 1):** Current-phase sightings and conversation partners at the player exact location are omitted in day and person-specific replies. Older observations, other places on the same block and independent sightings remain eligible. test_social now sets exact co-location in its existing fixture; assertions are unchanged. Exact-string expectations changed: none.

7. **First person about oneself.** Relationship notes and trait reveals said "Agnes and Edda are close"
   from Edda. When the speaker is one of the pair, say "Agnes and I are close" (or skip it). See
   `Game._maybe_tell_relationships` and `Game._maybe_tell_trait`.
   - **Implemented (Codex batch 4, set 1):** A speaker in a town bond says the other person and I, with quoted attribution in profile notes. Self-trait commentary also uses first person. Original bond identities, trait learning, probabilities and exact RNG draws remain unchanged; third-party wording is retained. Exact-string expectations changed: none.

8. **"Keep this between us", then public at the meeting.** When an NPC who asked you to keep a confidence
   goes public, give them a line that marks the change ("I've decided the town should hear it."). The
   confidence already lapses when they go public (`_break_confidences` checks `claim_public`).
   - Gotcha: the meeting testimony now streams (`Mind.testimony_step`, `Game.testimony_step`): add the
     line in `Mind._go_public`'s callers inside the step, not after the meeting.

   - **Implemented (Codex batch 4, set 2):** Confidence requests and private hint disclosures remember the request for privacy. Each actual first public disclosure announces the change within its speaker turn, including claim, accusation and relay routes. Claim/readings effects, confidence exemption and RNG are unchanged. Exact-string expectations changed: none.

### Meetings

9. **No empty nomination cases.** "Case against agnes: ." appeared (NPC nominations, 37291 and 1002).
   When the nominator has no reason to cite, they say so plainly ("I don't trust them, and I can't
   say better than that"). Find where `Mind.nomination_case`/`case_against` build the text. Wording
   only: no change to who nominates or why.
   - **Implemented (Codex batch 4, set 2):** Nominators with no citable ledger reasons say that they cannot explain their distrust better. The debug case description also names the absence of reasons. Existing grounded recaps, nomination selection, evidence and RNG are unchanged. Exact-string expectations changed: none.

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
    - **Implemented (Codex batch 4, set 2):** Approved gate: Gossip + Confidence >= 1.2 - paranoia; eligible direct reports use a 95 percent willingness roll replacing the Gossip cutoff/count and trusted-friend omission, as the user clarified. Existing privacy, cover, teammate and reading-disclosure protections remain. Both good and evil witnesses volunteer compatible observations from any past night, with evil teammate exclusions. Town and private telling identities are separate; accusation reports also mark town telling. Ordinary sighting facts and streamed testimony are reused without new strength numbers or fake generation. Bot baselines will shift. test_social fixes its willing-report fixture seed; assertions remain unchanged. Exact-string expectations changed: none.

11. **Explain the vote count.** One line in help that the player's vote counts ("of 11" with ten
    townsfolk).
    - **Implemented (Codex batch 4, set 2):** Help explicitly explains that ten living townsfolk plus the player means eleven voters. The existing voter count and all vote/nomination formulas are unchanged. Exact-string expectations changed: none.

12. **Which night is the Demon's free night.** Say it in the Roles text and the first night prompt: the
    Demon doesn't kill on the night before you arrive (night 0) and kills from night 1.

    - **Implemented (Codex batch 4, set 2):** The graphical and typed Roles views and first night prompt share one explanation: night 0 has no Demon kill; killing starts on night 1. Later night prompts stay brief. Text only; resolution rules and RNG are unchanged. Exact-string expectations changed: none.

### UI and text interface

13. **Approaches: say where.** Accepting an approach moves the player; print the same arrival block as
    `go` ("Present: …"), and name the place in the approach line before accepting.
    - **Implemented (Codex batch 4, set 2):** Approach invitations name the place before acceptance. Accepting reuses the ordinary visit observer, showing the same arrival, Present list and visible-person cards as go, while preserving approach question, movement and phase rules. Declining still leaves location and time unchanged. Exact-string expectations changed: none.

14. **Looking isn't talking.** Clicking a portrait started a conversation and spent the phase. Make a
    single click select or inspect (profile), and talking an explicit action (button or double click).
    - Gotcha: `test_ui.gd` clicks portraits; update its expectations, and keep `_run_seq` working.
    - **Implemented (Codex batch 4, set 2):** Map portraits now inspect profiles without moving, spending a phase or starting conversation. The inspected visible person has an explicit Talk action using the existing go/talk sequence. Townsfolk-owned highlighting and night ward targeting retain their separate behavior; map hints and day instructions explain inspection. Sequence error-stop behavior remains covered. Exact-string expectations changed: test_ui: map click inspects without moving; a separate Talk button starts the conversation.

15. **Warn before walking to someone busy.** Show "busy" on the cast row and in the `go` result when the
    person is in a conversation (`busy_with`).
   - **Implemented (Codex batch 4, set 3):** Visible cast rows show busy talking, and a successful go to a busy person names their partner before the ordinary arrival. Hidden locations retain their existing privacy. Movement, time and RNG rules are unchanged. Exact-string expectations changed: none.

16. **Help text.** Add the newer actions: offer/apologise, promise yes/no, ask them to use their gift
    (`ask check/guard/watch`), `ask about <gift>` ("heard of a…"), presenting a ward or sigil.
   - **Implemented (Codex batch 4, set 3):** Help lists apologies, free yes/no answers to pending confidence or protection requests, gift-use requests, heard-of-a-gift questions and private/meeting ward or sigil presentation. Existing offer documentation and command rules are retained. Exact-string expectations changed: none.

17. **`ask check agnes isolde` without a comma** should work like `ask check agnes, isolde`.
   - **Implemented (Codex batch 4, set 3):** Seer requests accept whitespace between names as well as comma or and, retaining the same target validation, decision and RNG draws. Warden parsing is unchanged. Help shows the new syntax and points apologies at the existing numbered command menu. Exact-string expectations changed: none.

18. **Night: who's home.** A line at night listing who is home on each block (what the map shows).
   - **Implemented (Codex batch 4, set 3):** Night entry and night look list every living townsfolk's home by block, matching the existing night-planning map. The list uses home markers rather than hidden resolved excursions; no phase, RNG or visibility rules change. Exact-string expectations changed: none.

19. Lower priority if time allows: Roles window as a side panel option; offset name labels that overlap
    place labels on the block map; briefly highlight a trait bar when you learn that trait.
    - **Implemented (Codex batch 4, set 3):** User-approved session-only Pin as side panel embeds the same Roles content beside the town profile, with live known claims and setup counts. The case board still opens that content as a window; returning to town restores the pin. Map names avoid place signs and each other inside the viewed block, keeping portraits and hit targets fixed. Newly learned traits flash for one second in their existing colours, without restarting on refresh or flashing old knowledge after a person/case change. Focused UI, layout and RNG checks pass. Exact-string expectations changed: none.

### Logging and the developer case summary

20. **The developer case summary (grimoire) shows the secret modifier**, not only the personal secret:
    print `secret_mod` (Marked was missing in 37291).
   - **Implemented (Codex batch 4, set 3):** Each grimoire row includes its secret modifier by display name alongside the independent personal secret. Marked, Delusional, Secret Lovers and Sleepwalker are covered; formatting is read-only. Exact-string expectations changed: none.

21. **Stale role name in a reason string:** `own info: hearthwitch count 0` should name the Dowser (find
    the reason text in `Mind`'s own-info effects).
   - **Implemented (Codex batch 4, set 3):** Shared Hearthwitch/Dowser zero-count and impossible-count explanations now name the reading's actual gift. Effects, strengths, ledger identities and RNG are unchanged. Exact-string expectations changed: none.

22. **Every false reading carries a cause.** No `why: ?` in the lies list: where a reading is false
    (`true: false`), record why (poisoned, delusional, red herring, Marked, evil fabrication, fallback).
   - **Implemented (Codex batch 4, set 3):** False results preserve their creation-time cause, including a healthy Medium relaying an evil fabrication. Missing causes receive an explicit diagnostic fallback; old lies entries get the same display fallback. Truth flags, reports, RNG and evil fake generation are unchanged. Exact-string expectations changed: none.

23. **Check dropped personal items are findable.** Fenwick's item at the wharf (37291 seq 466) was never
    found. Confirm `search` at that location finds it; if it can't, report why (don't change search
    odds).

   - **Implemented (Codex batch 4, set 3):** Verified original case 37291 event 466: Fenwick drops an owned item at the wharf on night 3; the original log records no wharf search. A recorded-event fixture verifies ordinary go/search finds the existing dated evidence, wrong-location searches retain it, repeat searches do not duplicate it and owner death does not hide it. No production search or odds change was needed. Exact-string expectations changed: none.

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

# The "why" breakdown: first results

Nov 10, 2026 · Claude-Lantern · branch `claude/workshop-why` (PR #119), built on main `b40fab1`.

A debug and logging readout of why an argument moved a listener as far as it did. It reads the shared model's own numbers back; it changes no belief and no behaviour. How to use it and what each line means is in `docs/DECISION_INSPECTOR.md` (section "Why an argument moved someone this far").

## What it shows

- **The suspicion chain** for a real listener: how much suspicion of the subject the case could add, from "if the case settled it outright" down to what was applied, with one discount per line:
  1. the cards don't settle it (other explanations remain);
  2. hearing weight and trust in the tellers;
  3. attention (what else is in view);
  4. what they already held;
  5. resistance to moving against a lean;
  6. the scale's floor and ceiling.
- **The biggest loss**, named in one line, and **the strongest surviving alternative**.
- **The vote bar:** where a vote on the subject stands afterwards.
- **Per card:**
  - its status (counted · fits most worlds · changes nothing · argues against · no weight · not attended · rejected · already held);
  - the share of worlds it holds in;
  - the chance the model assumes a false report would say it;
  - what the premise loses without it.

## Where to find it

- **Workshop > Debug ▾ > "Why this strength?"**: the selected premise, judged by the test juror. Debug must be on.
- **Workshop > Debug ▾ > "Record why each listener moved, when I present"**: one breakdown per listener after each presentation, in the dev log (`workshop_why`) and under "Show recorded listener breakdowns". Off by default.
- **`tools/explain_case.gd <log> --card N --why`**: the same, on a replayed log.

## Playtest 12926, replayed on its own commit

The replay reproduces the game's stances and vote scores.

### Day 4, "Kiran is evil" (3 cards; the vote failed 3 to 4)

All three cards were already public, so nothing was new to anyone.

| Listener | Suspicion of Kiran | Vote score vs need (before the player's own vote and accusation) |
|---|---|---|
| Fenwick | 0.14 → 0.29 | 0.36 vs 0.33 |
| Hollis | 0.45 → 0.25 | 0.31 vs 0.44 |
| Edda | 0.00 → 0.14 | 0.14 vs 0.39 |
| Dorian | 0.17 → 0.05 | 0.09 vs 0.46 |

- **Two of four good listeners became less suspicious of Kiran, for two different reasons** (corrected Nov 10, midday; the first version blamed attention for both).
  - **Hollis (69% → 45% that Kiran is evil):** the case put a "lying" challenge on Kiran's Chronicler reading, and Hollis accepted it. Accepting sets the reading aside, so its clash with Hollis's own confessions stopped counting against Kiran; the fixed nudge an accepted "lying" challenge gives the reader (0.12 × agreement, about 0.09) is far smaller. Without the challenge the same presentation puts Kiran at 78%. Attention was not the cause: reading all 45 cards, he goes 69% → 33%.
  - **Dorian (36% → 27%):** he rejected the challenge. The presentation re-centred his 12-card view: the player's night-1 vigil of Nisha and Isolde's two Augur readings left it, and a Dowser reading and a sighting of Fenwick entered. Keeping his old view, the same presentation leaves Kiran at 36%. The swap also took his chance that Nisha is evil from 48% to 10%.
- **Dorian said the case "changes how I see Kiran" while his suspicion fell,** and then voted no. With no new card, the reply keeps the stance of the case on its own, not the belief change.
- **Edda** gained the most on paper (+0.49), but she had started well below zero (a friend she'd cleared), so only +0.14 showed.
- **What's left** for Hollis and Dorian was almost all one alternative: the cards fit Isolde just as well (98%). Isolde was the Scion.

### Day 2, "Lian is evil" (2 cards; the vote passed 9 to 1)

Five of six listeners already thought Lian evil (85–98%). Presenting two cards they already held lowered suspicion for four of six listeners by 0.10 to 0.30. All of them still cleared the vote bar.

### Day 2, "Nisha is the Demon" (2 cards)

This one worked as a case: +0.14 to +0.25 for every listener, and every vote bar cleared. It was wrong, and persuasive.

### Day 5, "Kiran is evil" (9 cards; the vote passed)

It added +0.01 to +0.10. The three listeners already stood at 50–67%, and all three cleared the bar afterwards.

## Findings (nothing here is changed)

1. **Re-presenting cards the town already holds can lower suspicion of the subject, by two routes.**
   - **An accepted "lying" challenge discards the evidence that the reader lied** (Hollis). This looks like a hole in how the challenge is scored.
   - **A presentation re-centres the listener's card budget,** so held cards near the edge swap in and out (Dorian). It can move people the case isn't about more than its subject.
   - The Day 2 Lian case and bot seed 900 haven't been attributed to either route yet.
2. **The reply can say "accept" while the belief falls,** when the case has no new card.
3. **The Workshop's test juror hears every card at full weight; real listeners don't.** Its strength label is a ceiling, not a forecast.
4. **Listeners read a small share of what they hold late in a case:** 8 to 14 of 42 to 50 cards on day 4.
5. **World share against the model's fixed 50%:** an Archivist pair held in 52% of worlds (close). A Clerk pair in a bot game held in 93%, so the flat 50% makes an honest Clerk look more informative than the worlds justify.

## Limits

- It covers filed cases (the Workshop), not single cards shown in conversation.
- The order of the steps is fixed, and the steps aren't independent: a loss is attributed to the first step that shows it.
- Recording costs 0.15 s per listener early at 7 NPCs and up to 2 s per listener late at 10, so it adds a real pause at a late meeting.
- A log replays exactly only on the commit it was played on.

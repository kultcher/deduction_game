# Playtest 54875: trace diagnosis (Oct 23)

10 townsfolk. Constance demon (Night Watch bluff), Edda Revenant (Rumormonger bluff), Greta
Poisoner (Dowser bluff). Dorian was the Sleepwalker. Claude played while the user drove
the game; the case was solved by Day 2–3 and lost anyway: one execution in six days.
Code references are to `claude/case-reasoning` at c6ae7a4, the build that was played
(before main's 61251/25923 fixes were merged in). The resulting to-do items are in
BACKLOG.md under "From playtest 54875".

## 1. Why accepted cases didn't become votes

The vote is `suspicion + player terms + trust term >= need`, with `need` about
0.4–0.5 (`Mind._vote_impl`). Good NPCs who said "that makes sense: Constance is evil"
had suspicion of her of only **0.14–0.26** at the votes. Four causes:

1. **"Accept" is wording, not belief.** Stance comes from agreement (>= 0.6). The belief
   change is `agreement × quality × scale(0.6 at a meeting) × novelty`, then trust.
   Agreement 1.0 became +0.08 to +0.13 suspicion. One bare public accusation
   ("town consensus, 1 voice") moved suspicion **+0.11**, as much as the whole
   accepted case.
2. **A richer case counted for less.** Re-presenting case #85 retires the old ledger
   entry (`_workshop_retract`), then `Argue.evaluate` applies novelty. `used_facts` is
   keyed by fact and target per listener, set by any earlier argument or direct
   tell against that person and never cleared. Facts already in it count 0.35. So each
   richer version replaced the last at a lower weight.
   Hollis: 0.128 (2 reports) → 0.105 (4) → 0.091 (6). Lian: 0.108 → 0.095 → 0.081.
   Adding evidence lowered the town's suspicion. A revision should keep the old
   facts' contribution and add the new ones in full. Also, the ledger reason still
   reads "(2 original reports)", and the revision keeps its old card number, so it
   sorts mid-list.
3. **Defences stack daily, accusations fade.** Defence moves are keyed
   `def:<id>:<day>:<move>`, so Constance's same "look at the other one in the pair" and
   "it's a lie" counted again every day (-0.03 and -0.025 each, per listener). Consensus
   against her faded about 0.05 a day. The player's argument was the one thing that
   never grew.
4. **No urgency.** `need = 0.5 - confidence term + 0.1 on day 1 - 0.4 × paranoia`. Paranoia
   is `0.07 × dead × (1 - 0.6 × composure)`. Lian, Hollis and Odette all had high
   Composure, so `need` barely moved from Day 2 to Day 6 (Lian 0.44 → 0.36) while the
   town lost a person a night.

Not a cause: no NPC nominated Constance because the player always nominated her first
(one nomination per nominee per day).

## 2. The shared evaluator never ran in play

Every in-game presentation used the **legacy** argument rules: `workshop_delivery`
logs "could not use the shared assessment" for every listener. The previews' "+0.450"
and "accept 1.000" were the new model's numbers against a neutral reference listener,
marked "not applied to the game". Nothing like them reached any NPC.

**Root cause (from the trace's `workshop_state.issues` and `workshop/shared_ledger.gd`):**
`Shared.prepare` refuses to take over a listener's legacy ledger when any entry it would
own has touched a person whose suspicion sits at exactly 0.0 or 1.5 ("Saturated legacy
beliefs need a reversible baseline before migration"), or when an entry was clipped
("A legacy contribution was clipped"). Demon victims are cleared to 0.0. Constance's
night-0 Night Watch reading named Dorian, so `info:constance:0:nightwatch` was
"saturated" for every listener from the Day 2 meeting on. Agnes's Clerk and Edda's
Rumormonger entries were clipped. With `prepared.ready` false,
`WorkshopPresentation._present` returns `{}` and `Argue.evaluate` falls through to the
legacy rules.

**Why the check exists.** Suspicion is a clamped running sum: `recompute_beliefs` applies
each entry's difference (`want - have`) to a value clamped to [0, 1.5], and `adjust`
ignores demon victims entirely. Once a value has hit a bound, subtracting an entry's
recorded contribution doesn't restore what it was before, so the shared model can't
cleanly take ownership of that entry. The check protects exact reversibility.

Since early readings often name someone the demon later kills, this will block the
shared model in most games. Fixes, in order of effort:
- skip the dead in the saturation check (their suspicion no longer matters);
- keep the unclamped sum (base + contributions) and clamp only on read, which makes
  every entry removable and lets the checks, the "clipped" flag and the fallback go;
- meanwhile, no silent fallback: block the submission with the reason, log which exit
  fired, and have the preview judge real listeners' readiness.

## 3. Why Insight barely changed the reactions

In the legacy path the canvas case had no root template, so it took the
`generic_support` route. Agreement there comes from `_support_strength`, which ignores
Insight. Insight enters only through `_quality` → `_class_w`, which discounts speech
(to 0.2) and circumstantial evidence (to 0.6) for sharp listeners. The case's supports
were the player's own sightings: concrete (weight 1.0 for everyone) from source
`"player"`, which `_cred` credits at 1.0 regardless of trust. So every listener
computed the same agreement and almost the same quality; the spread came from trust.

Meanwhile, Insight plays no part where it should differ:
- defence moves are weighted `0.5 + 0.5 × trust in the defender`;
- town consensus by trust in the accuser;
- Constance's "it's a lie" and "look at the other one" are pure speech.

Confidence doesn't set how far an argument moves them, although DESIGN says it should.

Directions:
- Insight discounts speech-only moves (pleas, crowd, unsupported accusations).
- Sharp listeners weigh the rival explanations; dull ones take the headline.
- Confidence sets the step size.
- The player's own sightings are the player's word to the listener, so they scale with
  trust (DESIGN's corroboration rule, "0.5 + trust"), not a flat 1.0.

## 4. Evil votes and words disagree

`Mind.evil_override` gives arguments about a teammate stakes 1.7–2.3 against caution
about 0.6, so evil always "rejects" a case against its demon. Votes are worth only
`teammate value × 0.35` when not pivotal, so the same evil NPC keeps cover and votes
**yes**. Edda said "not persuaded" and voted yes on Constance on Days 2 and 4; she was
the only NPC yes besides the player. (Main's 61251/25923 pass already stops evil voting
to execute its own demon; the played branch didn't have it.) The priorities are still
backward for other teammates: words don't hang anyone, so cover is cheap to keep there,
and votes are what matter.

## 5. "(pre)" evil meetings

`_pre_pair` runs before the player chooses and is always visible.
`pair_weight = (mutual trust - 0.3) × 2 + news_bonus`. Evil teammates start at ordinary
trust (0.5), but `news_bonus` gives +0.6 for each evil member with unshared intel, and
evil almost always has night intel. That's about 1.6 against 0.4 for a typical good
pair. Result: 4 of 4 evil meetings were pre and visible, on Days 1–4, the same two
pairs on consecutive days; 6 of 7 good conversations were pre as well. Post-pairs need
the same location and roll `0.4 × weight`, so they're rare for anyone.

## 6. Present costs

Consistent in code: anything the listener has already heard is free once per
conversation (`free_repeats`), and the second repeat costs a question. `present 85` to
Hollis and Lian was free because they'd heard it at a meeting, not because it was a
deduction. Two problems: the free repeat still re-runs the argument (with a repeat
penalty), and the reply doesn't say "you've told me that". Hollis's `present 119` was
the second repeat in that conversation, so it cost his last question.

## 7. Refusals and privacy

- **Gift disclosure:** `openness = -0.72 + (1 - privacy) + 1.2 × trust + 0.6 × pressure
  + 0.1 × (day - 1) + jitter`. Thresholds: hint 0.15, claim 0.45, readings 0.75. Day 1
  results: Dorian 0.03, Odette 0.06, both flat refusals. Privacy counts twice, because
  starting trust is also `0.3 + 0.25 × (1 - privacy)`. **Nobody reached the readings
  tier all case**, so every private claim came with "I'll keep what it's shown me to
  myself". The gift-type terms (`one_shot_gift` +0.3, `hides_from_demon`) exist only in
  the public claim roll, which is why Edda kept her reading from the player and then
  announced it at the meeting.
- **Opinions:** a hard gate at Gossip < 0.2 (`gossip_and_pressure_cutoff`) blocks
  "ask about X" entirely. Hollis (Gossip 0.01) said "It's not my place to say" about
  Constance right after agreeing with the case against her in public.
- **Asked about their own role:** `Social.answer_about_role` falls through to "I couldn't
  tell you who the Archivist is" (the `willing` line) when a holder declines to own up.
  For their own gift that's a lie.
- **Repeated stonewall:** Isolde's press and the `ask night` that followed got the same
  line and the same card, costing two questions.

## 8. Smaller confirmations from the trace

- Jory's scene trace was misleading. Isolde walked the lamp route past the cottage
  and left Square traces; the demon had spent the evening on the Docks.
- The ward on Isolde (night 3) was never tested: the demon ("hungry") took Agnes.
- Dorian really was out on night 0 (Sleepwalker). His "home all night" was honestly
  false, so the evaluator rejecting the "Dorian's alibi vs Constance's report" link
  was right, by luck.
- Constance's two night-1 stories came from separate generators: the alibi-hiding
  window sighting (Isolde) and the bluffed Night Watch reading (Jory).
- Greta poisoned Isolde on nights 1, 3 and 4, and Odette (the Veteran) on night 5 at
  the demon's request.
- Night walkers are seen anywhere on their path, leaving home and at the destination
  (`_night_sightings`).

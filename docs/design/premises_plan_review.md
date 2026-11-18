# What still applies from the premises plan (review)

**Status: a review for Michael, Nov 17, by Claude-Vicar. Nothing decided.** It goes through
`docs/premises_plan.md` (Nov 5–9: the premises pass, steps 0–3, recency and the headline
blend) and asks what's still live now that the connections model has been on in play since
Nov 16. Read from the docs and from the code on main. **"Live" means the code is present and
on the path in play; I didn't run anything to confirm it behaves as described.** Where I
couldn't tell, it says so.

---

## In short

- **The plan's central idea is gone from play,** and it's the one Michael is asking for
  again: a premise shapes how its own cards land. That was step 1's spillover damping. It
  now becomes option B in `docs/design/premise_centring.md`.
- **Most of steps 2 and 3 survive:** the premise menu, the trust cost of a wrong premise,
  challenges and their causes, the canvas changes. Several now act only inside their own
  case.
- **The attention work (steps 0 and 0b, recency, the headline blend) no longer touches
  belief.** Under connections, attention only picks what an NPC cites and explains.
- **Still unbuilt and still relevant:** step 4 (Minion identity and movement premises),
  assumptions as conditional beliefs, and using public facts to pin down which Minions are
  in play.

## 1. Gone from play, or superseded

| Item | Then | Now |
|---|---|---|
| **Step 1: a premise shapes its own cards** (spillover by Insight, 40–80%) | Cards only a presentation brought hit the premise's target in full and everyone else at 40–80% by Insight. It was the Nov 5 answer to "the player mustn't solve the case by presenting everything under a wrong premise". | Never runs with connections on. It's deleted in purge phase 5 (Michael approved), kept as BACKLOG section 6 "Spillover damping" `[tentative]`, and the code is on `archive/legacy-belief-final`. **Michael's Nov 17 goal brings it back:** option B in the centring note is this rule on the new model. |
| **Steps 0 and 0b: attention fixes** (a bare defence cites no grounds; the listener's own readings pinned) | They stopped one defence from turning a listener into a perfect reasoner. | Attention no longer limits belief, so their reason is gone. Every held card counts. The bare-defence part still matters for challenges (a bare defence isn't graded). |
| **"Suspicious" as half-weight hearing,** with the other half as pressure | Cards a suspicious premise brought counted at half weight; the other half pressed the subject. | Replaced. A suspicious case counts at half its weight, and pressure comes from how far its cards lift the subject (#155, about 0.3 from one basic reading at a meeting). The half-weight hearing goes in purge phase 5. |
| **Recency: the topic of the day, card age, calling attention back** | Bounded minds drifted from old facts; re-presenting brought them back. | Live, but only for what NPCs cite and explain, not what they believe. Re-presenting a *case* restores its faded weight, which is the connections model's version of "calling it back". |
| **The headline blend** (a low-Insight listener taking a reading at its word) | Pulled dull listeners toward a reading's literal claim. | Removed everywhere in purge phase 6a (Michael's decision). Insight is out of belief for v1, apart from Option A (Insight sets the core's joining bar), which Lantern is measuring. |
| **"Attention is a big lever on spillover"** (Tally's note) | A warning for the step 1 A/B. | Moot. |
| **Tally's step 1 baseline (case #78, "Fenwick is evil")** | The case moved Fenwick only 0.42 → 0.52, and most of what it moved went to three others. Step 1 should replay it. | Pre-connections logs no longer replay faithfully. The misframed-case test in the centring note is its successor. |

## 2. Still live (built, and on the path in play)

| Item | Now | Note |
|---|---|---|
| **The premise menu, merged** (evil, suspicious, good, conflict, Demon, Minion, not the Demon, holds a secret, holds their claimed gift) | Live | The 15 old types reduce to the 7 questions the judge can ask. |
| **A clearly wrong premise costs a little trust** (the same 0.02 as the reward), and a good one earns it | The code is live on the presentation path | Judged from the presentation's own evaluation, not the connections refresh. **Not checked:** whether its "agreement" still means the same thing with connections on. It matters for option B: it's what makes cycling premises costly. |
| **A rejected case doesn't steer protection** (Warden and Martyr picks follow only an accepted "X is good") | Live | |
| **Movement notes only for killer premises** ("seen elsewhere", "the traces") | Live | Wording. |
| **The preview hint** ("These cards make X look more suspicious, not less") | Live, in the Workshop preview | It warns only for a "good" premise. Under option B, a matching hint for a misframed accusation ("this evidence may say more about someone else") would be the natural partner. That hint was in the original Oct 25 item and never built. |
| **Contradictions as links; claim citations fill themselves** | Live (canvas) | UI only. |
| **Graded challenges** (leave one out, scored against chance), the causes (lied, failed gift, misled), backfire costs trust, the "readings that don't fit together" premise | Live, **inside their own case only** | "Lying" changes no reliability and keeps a small floor under the teller, scaled by the case's weight. "Misled" and "failed gift" discount the reading inside the case. Quill owns these. |
| **A failed-gift challenge points at Poisoner candidates** (people seen out on that night with no reason) | Live (`workshop/jury.gd`), scaled by the case's weight | |
| **A secret premise is the player's word** ("X holds S" adds one card told by the player, weighted by credibility) | The code is live in the presentation path (`SharedLedger._add_player_words`) | **Not checked:** whether the connections refresh reads that card, or treats a secret as context only, which counts for nothing alone. Lantern to confirm. It bears on the secrets rework too (a player arguing an unclaimed secret). |
| **Replies: two sources** (the stance from the case, the listener's own suspects from their beliefs) | Live | |

## 3. Never built, still relevant

| Item | Status | Ties to |
|---|---|---|
| **Step 4: Scion and Revenant identity premises** ("X is the Scion") | Deferred (Michael, Nov 8) | The judge doesn't tell Minions apart, which is also the Breathstealer bug (BACKLOG section 4). The secrets rework could free the room for it (`docs/design/secrets_rework.md`, section 4). |
| **Step 4: movement premises** ("X was out on night N", "X was the killer on night N") | Deferred | The new vigil (watch who leaves) produces exactly "X was out" evidence. A premise that says so might be worth more now. |
| **Proposal 6: assumptions as conditional beliefs** ("assume X is good") | Tabled (Nov 6) | The per-case either/or in the secrets rework is the same machinery: a case weighed in worlds where something holds. |
| **The Minion lineup from public facts** (a silencing proves a Breathstealer, a totem a Revenant) | Only "the script lists a Poisoner" is used | The Breathstealer overhaul. |
| **The preview hint for a misframed accusation** (see section 2) | Never built | Option B in the centring note. |
| **"Unclaimed roles" premises** ("the quiet one is our Seer") | Declined (Nov 5) | Nothing new. |

## 4. Suggestions

1. **Read the centring note as resuming the Nov 5 decision,** not starting a new one. Option B
   is step 1 on the new model, without Insight to start with.
2. **Have Lantern check two things before purge phase 5 deletes step 1's code:**
   - whether its brought-card bookkeeping or its tests are worth reusing for B;
   - whether the wrong-premise trust cost and the player's-word secret card still work as
     intended with connections on.
3. **Mark `docs/premises_plan.md` as history.** Add a header saying which parts were
   superseded by the connections model, pointing at this review. Bailiff recommended archiving
   it on Nov 16, keeping "Recency as built" findable from BACKLOG. I'd do that once Michael has
   decided B, so the plan isn't archived while its core idea is being revived.

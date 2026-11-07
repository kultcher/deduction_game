# Case Workshop: what premises actually do

Nov 5, 2026 · @Michael Smith · revised Nov 5, 22:50 ET (Claude-Bailiff) · step 1 and restored decisions Nov 6 (Claude-Quill)

**Status (Nov 6, afternoon):** Step 0 (a bare defence cites no grounds; PR #81) and step 0b
(one attended set; PR #86) are on main.

**Step 0b revised (Nov 6, with Michael):** the belief update has no premise target, and
nothing about an argument is remembered between presentations. The judging pass (agreement,
reasons, the trust reward) still ranks attention against the premise's target. The belief
update ranks by what was just shown: the people the presented cards name and come from, plus
the listener's pinned own readings.
- **What it replaces:** the night-of-Nov-5 version remembered the last alignment premise's
  target per listener (`attention_target`). That target steered every later refresh, for
  days, and moved beliefs through framing alone (the same cards, a different target,
  different beliefs).
- **The two invariants until step 1:** the same cards under any premise move beliefs the
  same way, and a later refresh isn't steered by an earlier argument's framing (both in
  `test_workshop_live_cognition`).
- **After step 1:** a premise moves beliefs only through its target (step 1, below).

**Step 1 (Nov 6, Claude-Quill, PR #92):** built; see "Step 1 as built" below.
**Step 2 (Nov 6, Claude-Quill, PR #93):** built; see "Step 2 as built".
**Step 3 (Nov 6, Claude-Quill, branch `claude/premises-step3`, on Bailiff's step 2 fixes):**
built; see "Step 3 as built". Its acceptance A/B with the M4 bot is Tally's (overnight), with attention budgets
fixed between arms. Step 4 isn't started. Deliberate recency in attention is a separate
step after step 1 (see "Recency: the topic of the day" below).

**Restored Nov 6:** the Nov 5 late-night decisions (23:10 and 23:35 ET, with Michael) were
lost when this doc was rebuilt from the 22:50 copy. They're back in "Decisions": suspicious as
half-weight hearing, q and f on the same footing, neutral challenges cost nothing, and
"role" stays. The 23:35 attention items (pin all own readings, one attended set, the
salience reshuffle) shipped in 0b and are superseded by "Step 0b revised" above.

Today a premise changes what a listener says, not what they believe. Every person's belief change comes from one pass over the evidence the player presents; the premise picks the reply, the stance, a small trust reward, and two side preferences. Reading challenges reach the numbers only when the player links cards that flatly contradict the reading, and then only slightly.

## At a glance

- **Real today:** which cards you attend. One CaseEval pass over the evidence sets every listener's belief change. The premise, its target, positions, sub-premises and answers don't move beliefs.
- **Premise side effects:** stance and reply text, a small trust reward (0.02) for an agreed case with fresh facts, and a protect or grief preference applied even when the case is rejected.
- **Challenges:** they only count when the reading is impossible against its grounds. The lying raise also needs agreement of at least 0.6, which a default-trust source can't reach (about 0.2).
- **Supportable now:** alignment, Demon/Minion, modifier, conflict, "X really is the role they claim", and the cheap "why the reading is false" explanations. Unclaimed roles and movement premises take medium work. Poison targets and motives need new hidden state.
- **Proposal:** condition the update on the premise, weight it toward the target, add Insight spillover and a small trust cost for a wrong premise, merge the 15 types into 7 questions, and turn challenges into accepted explanations.

## What changes beliefs today

Only the evidence set changes anyone's suspicion. I built one case ("T is evil", citing a Dowser reading and a Seer "yes" on T and A) on a fresh copy of seed 692, changed one option at a time, and recorded every person's change for the listener.

| Workshop option | Changes anyone's belief? | What it does change |
| --- | --- | --- |
| Premise type (Demon, Minion, good, suspicious, Marked, not-Demon, secret, truthful) | No: identical to the base case | Reply wording and stance; whether the trust reward fires |
| Premise target (A or B instead of T) | No | Reply wording; which of the listener's own cards fill leftover attention |
| Assumed positions ("assume A good") | No | Reply may say "follows only if I grant your assumptions" |
| Answers on a card ("the Dowser hit is T") | No | Same "conditional" reply; a theory-fit score nobody reads |
| Sub-premises ("A is good" feeding the root) | No | Nothing visible, not even the reply |
| Adding a card (a conflicting Seer "no") | Yes, roughly doubling the shifts | Everything |
| Premise type "conflict" | Yes | Cards are quoted, not endorsed, so they count differently |
| Lying or misled challenge with a contradicting card linked | Slightly (about 0.03) | A reliability multiplier on that reading; misled and lying gave identical numbers |
| Challenge with nothing linked | No | Reply: "the cited evidence does not establish a problem" |

Three premise effects are real but small:

- **Trust reward.** If the listener's agreement with the premise reaches 0.6 and the case shows them something new, they trust the player 0.02 more. A well-chosen premise earns trust; a wrong one costs nothing.
- **Protection preference.** A filed "X is good" premise makes Warden and Martyr NPCs likelier to protect X, applied whether or not the listener accepted it.
- **Believed role.** A filed "X holds their claimed gift" premise records X's role in the listener's believed roles, which only feeds grief over a friend shown evil.

Filed canvas cases also skip the credibility record that direct accuse and defend commands write, so accusing someone later revealed good never costs you credibility.

## Why reading challenges rarely matter

A challenge counts only when it is "supported", and three things keep that rare.

1. **It needs grounds.** A challenge with no card linked into it is supported only if the reading fits no possible world with a good, healthy reader. Almost every reading fits some world, so in practice nothing happens.
2. **Grounds must flatly contradict.** The linked cards must be consistent alone and impossible together with the reading under the hard solver. A reading that is merely unlikely given the grounds doesn't count. The one exception is the Surveyor's "unlikely count".
3. **The model already handles the conflict.** When two readings clash, the solver already weighs "one reader is evil or impaired". A supported challenge only multiplies the challenged reading's reliability down (to 0.35 to 0.65 of its weight), which shifts blame a little. That is the 0.03 in the table above.

Lying and misled differ only in an extra step that almost never fires. A lying challenge raises the reader's suspicion only if "cause agreement" reaches 0.6, but that value is the accuracy agreement (at most 0.8) times one minus the reader's quality, which is about 0.5 at default trust. It lands near 0.2. It clears 0.6 only in four special cases:

- the grounds rule out the reader's own claimed presence (a Night Watch seen elsewhere);
- a Gravedigger names an execution that never happened;
- an Executor names someone who hadn't died;
- someone claims the unique gift the listener holds.

Even then the raise is at most 0.12. Misled has one real path of its own: a Seer "yes" whose pair the grounds clear of the Demon is explained as a red herring or a Marked registration.

## The 15 premise types reduce to 7 questions

The claim menu offers 15 types, but the solver's truth test (`Solver.holds`) asks only 7 distinct questions of a world. This is the root of the redundant paths, not just the UI.

| Question the solver tests | Premise types that ask it |
| --- | --- |
| X is evil | is evil · is suspicious · lied about a reading · is bluffing their claimed gift |
| X is good | is good · told the truth about a reading · holds their claimed gift |
| X is the Demon | is the Demon |
| X is not the Demon | is not the Demon |
| X is a Minion | is a Minion |
| X holds modifier M | is Marked · has a secret modifier (choose M) |
| X's reading was false though X is good | was misled by a reading · gave an unreliable reading |
| The cited reports can't all be true | these reports conflict |

"Conflict" is an eighth question, about the cards rather than a world. "Suspicious" and "evil" also have different coefficients (0.3 and 0.45), but the coefficient is overwritten by the shared pass, so they behave the same.

## Premises the model can realistically support

A premise can matter only if the solver can check it against a world. A world records who is evil, which evil player is the Demon (with Scion and curse epochs), and one secret modifier with its holders. Beside the worlds, the solver already has three more layers. The role table (`role_constraints.gd`) weighs whether the role claims and role readings (Gravedigger, Executor, Registrar and others) fit together, with 13 fixed role slots. It also tracks each reader's gift health per night and each person's possible routes per night. That gives three tiers, plus a set that needs new hidden state.

| Premise | Tier | Built on | Cost | Today |
| --- | --- | --- | --- | --- |
| X is evil / good (at a chosen time) | 1 | World alignment and curse epochs | Cheap: a yes/no per world | Asked, never acted on |
| X is the Demon / not the Demon / a Minion | 1 | World Demon identity, Scion epochs | Cheap | Asked, never acted on |
| X holds a modifier (Marked, Delusional, Lovers, Sleepwalker, Muddler) | 1 | World modifier holders | Cheap | Asked, never acted on |
| These reports conflict | 1 | Case consistency | Cheap | Works (quotes the cards) |
| X is the role X claims ("X really is the Seer") | 1 | Good claims are binding, so this is "X is good" plus the role table's fit | Cheap | Asked; reduces to "X is good" |
| Reading R is false | 2 | Report truth table per world | Cheap | Partly (via misled) |
| R is false because its reader lied | 2 | Reader evil and R false | Cheap | Asked as "lied", which only tests "evil" |
| R is false because the reader's gift failed that night | 2 | Gift-health variable per reader and night | Medium: condition one channel | Not offered |
| R misled an honest Seer (red herring or Marked) | 2 | Seer red-herring averaging | Cheap | Works for Seer "yes" only |
| X holds role R they haven't claimed ("the quiet one is our Seer") | 2 | The role table, asked per person instead of as one fit weight | Medium: the C# table returns only a weight today | Not offered |
| X was out on night N / at block B | 3 | Route enumeration | Medium: per person and night | Not offered as a premise |
| X was the night-N killer (Demon or Brute) | 3 | Killer's route to the victim | Medium | Not offered |
| X's home alibi is false | 3 | Alibi against routes | Medium | Only as a contradiction card |
| The Poisoner targeted X | needs design | Poison target isn't a world fact; only gift health is | High | Not offered |
| A generic innocent secret, motive or protection plan | needs design | No world fact | High | Not offered (Oct 25 decision) |

Tier 1 and the cheap tier-2 rows need no new hidden state. The medium rows reuse variables the solver already marginalizes, so the cost is conditioning, not enumeration.

## Proposed mechanics

These follow the Oct 25 backlog direction ("The premise should matter") and add the pieces the code review turned up.

1. **Condition on the premise and weight it toward the target.** Compute the listener's posterior over worlds where the premise holds, alongside the usual pass. The listener updates mainly on the premise's question about the target. Changes for everyone else are scaled by the listener's Insight (low Insight: little spillover; high Insight: most of the pass carries over). With this in place, a weak case that names the right person helps more than the same cards aimed at no one.
2. **A clearly wrong premise costs a little trust.** When the listener's agreement is well below 0.5 (say under 0.25), apply a small negative counterpart to `PRESENTATION_REWARD`. Filed canvas cases should go through `credibility.record` like spoken ones, so this sticks.
3. **Preview hint.** When the attended evidence favors a different target or question than the premise, the live preview says so ("the evidence points more at Merrin"). This also fixes the inconsistent replies: the reply text should come from the conditioned result, not the unconditioned pass.
4. **Merge the redundant types.** Offer the 7 questions (evil, good, Demon, not Demon, Minion, holds modifier, conflict), plus "suspicious" as a pressure play (see Decisions). Keep "lied", "misled" and "impaired" as explanations attached to a reading, not as premises (see 5). This also settles most of the redundant-paths UX issue.
5. **Challenges as accepted explanations.** A challenge proposes why a reading is false: the reader lied, the gift failed that night, or the Seer hit a red herring or a Marked player. The listener scores the explanation the same way as a premise (agreement over worlds plus the hidden variable it names). When agreement is high enough, the reading is discounted for that listener and the blame moves: "lied" raises suspicion of the reader, "impaired" raises suspicion of the Poisoner candidates, "misled" moves nothing. That replaces today's "impossible or nothing" test with a graded one, and drops the `(1 − quality)` factor that makes the lying raise unreachable.
6. **Assumptions as conditional beliefs.** Sub-premises ("assume X is good") restrict the worlds the case is scored in. The listener's agreement with the assumption scales how much of the conditioned change they accept, so a case built on an assumption the listener rejects lands softly.
7. **Fix the rejected-case preference.** Apply `_apply_conclusion_pref` only when agreement is at least 0.5. Today a rejected "X is good" still nudges Warden and Martyr picks toward X.
8. **Movement premises later.** Add "out on night N", "passed block B" and "was the night-N killer" once 1 to 7 are in, by conditioning on the LiveActivity routes the solver already enumerates.

The bot A/B is the acceptance test: moderately supported wrong nominations must not get through more often than today, and a correct premise should beat the same cards with no premise.

## Challenge design: leave one out, scored against chance

This is the detailed design for proposal 5. The player's argument is "if we assume this reading is wrong, the rest of the evidence fits much better". The fair way to score that is to compare against chance, not to count worlds. Dropping any reading opens up worlds, because every reading rules some out, so a raw count would let the player discount almost anything.

For the challenged reading R, the listener uses three numbers:

- **r**: the prior chance R is accurate. That's the source being good and healthy, times (1 − err). It's about 0.6 at default trust.
- **f**: the leave-one-out share. Drop R, score the remaining evidence, and take the weighted share of those worlds in which R's content holds.
- **q**: the share of worlds in which R's content holds before any evidence: the same measurement as f, with no evidence instead of "everything but R".

**q and f on the same footing (restored Nov 5, 23:10).** "Neutral" lands at zero only if q and f are measured the same way. Since PR #74, `Eval.chance_content` is a world share except for `ROLE_CONTENT_FIXED` (`workshop/case_eval.gd`): Archivist, Clerk, Executor, Gravedigger, Registrar, Monitor, Martyr, Night Watch, Warden, Veteran and Seer keep fixed constants, because the report table can't say how often their content holds (the role table or movement model decides). These are most of the readings players will challenge. The challenge test measures both q and f with the full world weighting, role table and movement model included (`fits_weights`, the LiveActivity routes): q with no evidence, f with the evidence minus R. CaseEval's own constants stay; only the challenge test gets its own q.

The chance that R is wrong, given everything, is (1 − r)·q ÷ ((1 − r)·q + r·f). This is the same per-card likelihood CaseEval already uses: an evil or impaired source gives q, and otherwise it's (1 − err)·\[holds\] + err·q. `ChannelLikelihood.assess` already returns it per card as `acceptance`. The challenge's strength is how far the chance R is wrong rises above its prior of 1 − r:

| Rest of the evidence | f | Chance R is wrong (prior 0.4) | Challenge |
| --- | --- | --- | --- |
| Argues against R | 0.1 | 0.77 | Strong: discount R |
| Neutral | 0.5 | 0.40 | Nothing gained |
| Backs R up | 0.9 | 0.27 | Backfires: small trust cost |

This replaces the pass/fail world-fraction test in `reading_challenges.gd`, which only says "supported" at a fraction of 0.

**What the challenge adds beyond the posterior the model already computes:**

1. **Attention.** A listener with bounded attention may never look at the cards that conflict with R. The challenge makes them run this comparison with the cited grounds.
2. **A cause, which decides where the blame goes:**
   - "The reader lied" puts all of the drop on the reader being evil, which raises suspicion of the reader.
   - "The reader's gift failed" puts it on impairment, which raises suspicion of Poisoner candidates. It should count only when the listener accepts that a Poisoner (or a Delusional holder) could be in play.
   - "The Seer was misled" puts it on a red herring or a Marked holder. Nobody gains suspicion.
   - The listener's agreement with the cause scales the effect. A cause the worlds can't support ("lied" when the reader is all but proven good) gets low agreement.
3. **A guard against cherry-picking.** The listener computes f from the cited grounds, the cards they're attending to, and their own readings that bear on R (pinned; see "Own readings stay in view" below). So their own support for R still counts against the challenge. It doesn't use everything they've heard: that is what the step 0 bug did.

The effect is the rise above the prior, scaled by agreement with the cause. A neutral challenge does nothing either way; the trust cost applies only when the chance R is wrong falls 0.1 or more below its prior (restored Nov 5, 23:10). `CaseEval.DEFAULT_ERR` stays small, as its comment asks, so "it was just wrong" can't explain away surprising readings. The extra room for error comes only from a named, checked cause.

## Minion premises

Worlds record the evil team and the Demon, but not which Minion each other evil player is. The role table has fixed slots only for the Scion and the Revenant. Poisoning isn't an event in the solver: a poisoned reading falls under the small `err` term. Breathstealer evidence (spoke with, or shared a block with, someone before they were silenced) is a Stage 2 circumstantial heuristic worth +0.015 per incident and +0.045 at most per listener and target. It isn't a solver likelihood.

| Premise | Built on | Cost | Notes |
| --- | --- | --- | --- |
| "There is a Poisoner / Breathstealer / Brute / Revenant / Scion in play" | A new lineup variable: which Minions the script drew. With 5 Minions and 1 or 2 slots, that's at most 10 options. | Low to medium: small, and mostly independent of the worlds | Mostly settled by public events: a silencing proves a Breathstealer, a found totem a Revenant, two traces a Brute. Registrar readings narrow it. |
| "X is the Scion" / "X is the Revenant" | The role table's existing slots, plus Scion succession epochs | Medium: a per-person role-table query (the C# table returns only a fit weight today) | Unclaimed good-role premises were declined (Decisions), so nothing else builds this query: step 4 builds it for these two |
| "X is the Breathstealer" (from day movement and victims) | Minion-role assignment, plus a likelihood for each silencing: the Breathstealer shared the victim's block that day | Medium to high: the assignment can be factored like gift health instead of multiplying worlds, but day positions must become solver evidence | Turns the circumstantial heuristic into real evidence |
| "X is the Brute" | Assignment, plus a likelihood for two traces on nights the Demon stayed home | Medium to high | Reuses night routes |
| "X is the Poisoner" | Assignment, plus poison events tied to failed readings | High | Needs a poison target, which isn't modelled |

A lineup premise is useful even when the town already knows who holds the role:

- "A Poisoner is in play" is what licenses the "gift failed" challenge cause, and only during the nights it covers.
- "A Scion is in play" changes vote strategy: executing the Demon while five or more are alive just passes the role on. That's a voting consequence, not only a belief change.

Suggested order: the lineup variable first (cheap, and it makes impairment challenges fair), then Scion and Revenant through the per-person role query. The Breathstealer and Brute stay circumstantial (Decisions).

## Secret premises and same-source inconsistency

### "These readings from one person don't fit together"

This needs no new structure. CaseEval already treats an evil or impaired source as giving chance content, so all of that source's readings can be wrong together, while a good, healthy source's readings must all hold. The premise is "this source couldn't read healthily", scored with the same leave-one-out comparison as a challenge, applied to the group:

- **f\_joint**: given the rest of the evidence, the weighted share of worlds in which all of the source's cited readings hold.
- **q\_joint**: the same share with no evidence, measured jointly with the full world weighting (restored Nov 5, 23:10); a product of per-reading constants would miss how the readings depend on each other.
- When f\_joint is well below q\_joint, the chance that the source is evil, Delusional or poisoned rises above its prior. The rise, scaled by agreement, is the effect. As with challenges, a neutral result does nothing, and only a clear fall below the prior costs trust.

It can be shown in the circumstantial column for the player, but its math belongs in the solver, where it's cheap and exact. The attached cause decides where the blame goes:

- **"They lied":** the reader is evil, so suspicion of them rises.
- **"They're Delusional":** this clears them of being evil and asserts the case's secret (see below).
- **"They were poisoned that night":** this counts only with the lineup premise "a Poisoner is in play", and only on the nights it covers.

### Secrets as linkable premises

Secrets are far cheaper than Minion identity. Each case has one secret modifier on a townsfolk (two for the Lovers), and every world records its kind and holders (`world.modifier`, `world.holders`). "X is Marked" is a tier-1 premise today (`Solver.holds` for marked and secret\_mod).

The per-card "evil or Marked" pick is decorative: canvas answers are scored for theory fit and never used as facts. The proposal replaces it with a premise node, "X holds secret S", that the player links to the readings it explains:

- **Effect:** the listener scores the linked readings in worlds where X holds S, weighted by their agreement with that premise. Readings that pointed at X being evil stop doing so, to the extent the premise is accepted.
- **Knock-on:** one modifier per case, so accepting "X is Marked" rules out a Delusional or Sleepwalker anywhere. Every other surprising reading loses that excuse. This is the cost that keeps the move honest.
- **It has to earn it:** the prior is low (one holder, and only if S is this case's modifier). Marked people can still register as evil, so "X is Marked" beats "X is evil" only when other evidence says X is good, such as a Dowser clear or a trusted Warden save.

| Secret | Links to | Explains |
| --- | --- | --- |
| Marked | Seer, Gravedigger and other readings of X | X registering evil or as the Demon |
| Delusional | X's own readings | X's readings being wrong, without X being evil |
| Sleepwalker | Sightings of X out at night | X being out without a gift or motive (the movement model already handles Sleepwalker claimants) |
| Lovers | Sightings of the pair together, or away from home | Their secret meetings |
| Muddler | Readings or sightings X passed on | One detail of a relay being wrong |

In the challenge design, these premises are the causes that explain a reading without blaming anyone evil. A challenge with cause "misled by a Marked player" is the same as linking the reading to "X is Marked".

**Flagged change:** this removes the per-card "evil or Marked" pick from the canvas. Today that pick only feeds the theory-fit score, so little behavior is lost, but it's existing UI and needs sign-off.

## UX changes to fold in

These are UX changes to fold into the same work.

### Contradictions: keep both cards, mark the contradicted one

**Today:** linking two contradicting cards merges them into one contradiction node (`CanvasModel.merge`). The node takes over both cards' links. `dispute.preferred` records which card wins. "Doubt the report" (`doubt_report`) unmerges the node and puts a "suspected lie" on the report.

**Proposed:**

- Both cards stay on the canvas with their own links.
- The contradicted card (the one `dispute.preferred` doesn't favor) gets a red border, in the same style as a linked card today, and a "Contradicted by …" label naming the other card.
- The contradiction itself becomes a link between the two cards, not a node. A conflict premise or a challenge can still cite it.
- Doubting the report becomes "swap which card is contradicted" plus a challenge on the report. No merge or unmerge step.

**Model impact:** small. `compile()` already turns a contradiction node into its two cards plus a dispute record. It also already builds disputes with no merge for the home-alibi-versus-outing pair. So the new link only has to produce the same dispute record, and evaluation shouldn't change. The work is in the canvas: the `merged` flag, `prior_links` and the link remapping in `merge()` and `unmerge()` go away, along with their save validation.

### Role-claim citations: include them automatically

**Today:** citing a night outing ("X was out because of their gift") needs the person's walking-role or secret claim card in the case. Otherwise `live_assessment.gd` reports "Activity citations need an included walking-role or applicable secret claim for that person", and the player has to find and add that card.

**Proposed:**

- When the claim is public (the person announced it, or it's on the town board), add the claim card to the case automatically and treat the citation as satisfied, with nothing for the player to do.
- When the only matching claim is private (told to the player alone), still add it automatically, but show it as an added card the player can remove. Presenting it tells the listener something new.
- When no claim exists, keep today's error.

The card should be added, not just skipped as a step. The role table and movement model check the claim against the other claims and against routes. A citation with no claim card would lose that check and quietly change the evaluation.

## Step 1 as built (Nov 6)

Decided with Michael on Nov 6: the shaping is **remembered** (every refresh, not just the
presentation), and the premise's type does nothing to the target's belief beyond the
evidence (**evidence only**). Step 1 does no world conditioning: with "evidence only", the
target's belief already is the evidence's full effect, and conditioning stays for
assumptions (proposal 6, step 2).

- **Shaping** (`SharedLedger.premise_shaping`, applied in `SharedLedger.evaluate` from
  `WorkshopOwnership._refresh`). A card is shaped when only presentations brought it (not
  the listener's own readings, hearsay or the public record) and at least one of them argued
  an alignment premise about someone (`Tuning.Workshop.PREMISE_SHAPING_TYPES`: evil, demon,
  minion, suspicious, good, notdemon, role, notrole, lied, truthful). Each refresh evaluates
  the union twice, with and without the presentations that own a shaped card. The targets
  take the full difference; everyone else takes `spill` of it, from 0.4 at Insight 0 to 0.8
  at Insight 1 (`PREMISE_SPILLOVER_MIN/MAX`). Requested change, posterior and agreement are
  all blended, so execution priority follows the shaped beliefs.
  - Marked, secret, misled and conflict premises name no alignment target: re-presenting
    the same cards under one neither shapes nor unshapes them.
  - Several shaping presentations: every target among them takes the full effect.
  - Cost: one extra union evaluation per refresh, only for listeners holding shaped cards
    (cached with the union's own inputs).
- **Trust cost** (`WorkshopPresentation`): agreement is `CaseEval.shift`, from −1 to 1
  (how far the evidence moved toward the premise), not a probability. "Below 0.25" would
  have charged neutral cases, so the threshold is the mirror of the decision's number:
  **−0.25**, the evidence moving a quarter of the way toward the premise being false
  (`Tuning.Trust.PRESENTATION_WRONG_AGREEMENT`; cost `PRESENTATION_WRONG_COST` 0.02). Judged
  on the case plus own readings, like the reward; not for conflict premises; not on repeats.
- **Rejected-case preference:** a presentation's agreement is stored
  (`workshop_state.presentation_agreement`), and its protect / believed-role preference
  applies only at agreement 0.5 or more (`PREMISE_PREF_MIN_AGREEMENT`).
- **Credibility for filed cases:** already recorded on main (`GamePresentation._evaluate_deduction`
  records every deduction presentation); the "skip" in the analysis above is out of date.
- **Replies:** the stance already follows the belief move of the target (now shaped), and
  the "chief suspicion" lines use the listener's own beliefs (PR #73). New: the movement
  notes ("seen elsewhere", "the traces") only follow killer-side premises
  (`DialoguePresentations.MOVEMENT_NOTE_TYPES`: evil, demon, minion, suspicious, good,
  notdemon). Playtest issue #5.
- **Preview hint:** the test juror already says "If presented, this mostly raises suspicion
  of X" for accusations. New: a "good" premise whose cards raise its subject says "These
  cards make X look more suspicious, not less."
- **Invariants now** (`test_workshop_live_cognition`): another premise type about the same
  target moves beliefs no differently; aiming the same cards at someone else gives that
  person their full effect and leaves the rest as they were; a later refresh reproduces the
  shaping exactly. The 0b rule that a later refresh isn't steered by attention framing still
  holds: shaping is about what the presented cards do, not what the listener attends to.
- **Tests:** `tools/test_premise_step1.gd` (spillover ratio 0.4/0.8 at fixed attention,
  target unchanged by Insight, remembered shaping, wrong-premise cost and no repeat cost,
  the preference gate, movement notes, the preview hint).

## Step 2 as built (Nov 6)

Decided with Michael on Nov 6: both Marked pickers go; "lied", "misled" and "unreliable"
leave the premise menu now (the reading modifiers stay until step 3's challenges); and a
secret premise is **the player's word**, weighted by credibility.

- **Claim menu** (`LiveCaseWorkshop.LIVE_TYPES`): evil, suspicious, good, conflict, Demon,
  Minion, not the Demon, holds a secret (`secret_mod`), holds their claimed gift (`role`).
  Gone from the menu: Marked, bluffing, told the truth, lied, misled, unreliable. Filed
  cases with the old types still evaluate.
- **Marked pickers removed in the live editor** (`CanvasModel.marked_answers = false`,
  `_marked_answers()`): Dowser, Surveyor and Magistrate faces cycle registered -> clear,
  never "registered as Marked"; the Seer registration offers Any / Demon / Red Herring;
  assumed identities offer Good / Evil. The fixture workshop keeps its old controls.
- **Secret premise = the player's word** (`SharedLedger._add_player_words`). A presented
  "X holds S" (the root premise, or a premise inside the case) adds one card per (X, S):
  a secret reading of X alone told by the player (`source` "player", `testimony_only`, a
  one-person Rumormonger shape), reliability = how far the listener takes the player's word
  (`SOURCE_REL_BASE + SLOPE * credibility`, like any card heard only from the player). An
  evil, impaired or Delusional reader can't explain it away; a doubted player's word counts
  for less. It's always in view (pinned in `Reasoner._prepare`). A secret the case's script
  can't have adds nothing. One modifier per case, so "X is Marked" also rules out a
  Delusional or Sleepwalker elsewhere, through the worlds.
  - **Track record:** a presented secret joins `claim_record` as `secret:<target>`;
    at dawn `Credibility._agreement` scores it by how far the NPC's own evidence moved the
    chance that X holds S (abstaining when it hasn't moved), beside the alignment claims.
- **Suspicious = half-weight hearing plus pressure.** Cards that only suspicious premises
  brought count at `SUSPICIOUS_HEARING` (0.5) for everyone, both directions, on top of the
  step 1 spillover (a third union pass when firm and suspicious presentations mix). The
  other half presses the target once per filing (target and cards): the average listener's
  full-weight rise on the target times `SUSPICIOUS_PRESSURE_PER_RISE` (0.5 private, 1.0 at
  a meeting; a 0.2 rise gives the conflict premise's +0.1 / +0.2). Refiled as evil: full
  weight, once, and no more pressure. Refiled as suspicious again: nothing. Direct
  accusations (also "suspicious" internally) are unaffected: their cards are held through
  the told-card ledger too.
- **Contradictions are links** (`connect_cards` adds a `contradicts` link from the card that
  disproves to the card it contradicts; `compile` adds the dispute when either card is in
  the case and pulls in the other). Both cards stay; the contradicted card has a red border
  and a "Contradicted by ..." tag. Inspect on it offers "Doubt the report instead" (the link
  goes, the report gets a suspected lie with the alibi as grounds) and "Remove the
  contradiction". Saved drafts with old merged contradiction cards still load and work.
- **Claim citations fill themselves** (`CanvasModel._auto_citations`): an outing explained by
  a gift (or a private errand) with no chosen claim cites the claim on the board that covers
  that night and brings its card into the case (`auto_cards`). The citation menu's first
  entry is "Automatic"; "No supporting claim" declines it (citation "none").
- **Flagged, not changed:** the headline rule in `Jury` (a dull listener takes a strong
  evil reading at its word) blends toward any positive headline signal, however small,
  when the evidence clears someone. With the secret word, a tiny headline from a Seer
  card heard through the player pulled p3's clearing back by a third (test fixture:
  credibility 0.7 cleared p3 less than credibility 0.2). The posterior is right; the blend
  probably wants a strength floor. Left for a decision.

## Step 3 as built (Nov 6)

Built on Bailiff's step 1 and 2 review fixes (`claude/premises-step2` at `5514f14`).

- **Graded challenges** (`ReadingChallenges.graded_challenge`). For a challenged reading R:
  q and f are one CaseEval question, "R's content holds" (`conclusion.type` "holds",
  `Solver.reading_holds_table`: content only, whoever gave it and however healthy, since r
  carries the source and the reading's error; review fix), before any evidence and after the rest of the attended cards; r
  is the source being good before the case (`good` prior) times one minus R's reading error.
  The chance R is wrong is (1 − r)q ÷ ((1 − r)q + rf); its rise above 1 − r, as a share of
  r, is the challenge's `effect`. Neutral: q = f, effect 0, nothing changes (checked).
  - **The Seer's content is the Demon's place** (the mask is "the Demon is in the pair" for
    a yes, "isn't" for a no). The report table holds a Seer yes wherever anyone good is in
    the pair (the Red Herring is a role-table weight), which made clearing the pair look
    like support. A Red Herring or Marked ping is the "misled" explanation of a false
    reading.
  - The hard cases from before (no world fits, the grounds rule out the reader's presence,
    the Gravedigger's non-execution, the Executor, a claim of the listener's own gift, the
    Seer misled pair) stay as floors; the graded test can only add to them.
  - The effect scales the reading's reliability: `multiplier = 1 − hearing × cause × effect`.
- **Causes** (the reading modifier's mode): **lying** — cause = the share of "R is wrong"
  that the reader being evil explains (`P(source evil | all) ÷ P(R wrong)`); raises the reader
  through the existing source penalty and jury raise once agreement reaches 0.6. **Failed
  gift** (`impaired`, new: "Poisoned" chip, "Failed gift (poisoned)") — cause = the rest of
  the wrong share, and zero when the case's script has no Poisoner
  (`poisoner_possible`, `view.script_minions` from the snapshot's `rules.minions`, the case
  script's own minions; not the solver's possible roles, which list every ready role); points at the **Poisoner candidates**: people
  the attended cards saw out on the reading's night with no gift or errand the case gives
  for it (`poisoner_candidates`), raised by `CHALLENGE_POISONER_SCALE` × agreement, split
  among them, at agreement 0.6 or more. **Misled** — honest but wrong; no one is blamed.
  **Unlikely** (Surveyor) — kept.
- **Backfire costs trust** (`WorkshopPresentation._challenge_backfired`, judged on the
  narrower pass): when the rest of the evidence moves R's content a quarter of the way toward
  certainly holding (`CHALLENGE_BACKFIRE_SHIFT` 0.25, the mirror of the wrong-premise
  threshold). It's charged on top of how the case itself went. **Changed from the plan's "0.1
  below the prior":** that can't be reached; the chance a reading is wrong can only fall to
  (1 − r)q ÷ ((1 − r)q + r), about 0.09 below the prior at default trust.
- **"Has readings that don't fit together"** (premise type `inconsistent`, with a cause:
  any, lied, poisoned, Delusional). The case's readings by its target become one grouped
  challenge, scored jointly (a "yes" then a "no" on the same pair can't both hold: the
  group's multiplier fell to 0.11 in the test). Delusional's cause is the chance the source
  holds Delusional over the chance the readings are wrong. Its premise mask is "not every
  one of their contents holds" (so two readings that can both be true never count, even
  from an evil source).
- **Minion lineup, minimal:** "a Poisoner can be in play" is the case's script listing one.
  Public facts that rule a Minion in or out (a silencing, a found totem, Registrar
  readings) aren't used yet.
- **Tests:** `tools/test_premise_step3.gd` (neutral, strong, backfire, failed gift and
  candidates, the grouped premise).

## Decisions (settled Nov 5)

These answers replace the open questions. Where they differ from the proposed mechanics above, they win.

- **Spillover:** Insight scales it from 40% (lowest Insight) to 80% (highest). The ceiling is there so the player can't present all the evidence under a wrong premise and let a high-Insight listener solve the case.
- **Trust cost:** a clearly wrong premise costs the same as the current reward, 0.02 (`PRESENTATION_REWARD`). The "clearly wrong" threshold starts at agreement below 0.25; as built, that's agreement −0.25 or less, since agreement runs from −1 to 1 (see "Step 1 as built"). For challenges and same-source premises (restored Nov 5, 23:10), the equivalent is the chance the reading is wrong falling 0.1 or more below its prior; a neutral result costs nothing.
- **Type merge** (code names; the menu labels are in `workshop/canvas_model.gd`: "notrole" is "is bluffing their claimed gift", "truthful" is "told the truth about a reading", "role" is "holds their claimed gift", "secret\_mod" is "has a secret modifier"):
  - Drop "marked". It's "secret\_mod" with Marked as the secret, which also covers the other secrets.
  - Drop "notrole" and "truthful". They're the same questions as "evil" and "good".
  - Keep "role" ("holds their claimed gift"), read as "X really is the role they claim": "X is good" plus the role table's fit (restored Nov 5, 23:10).
  - Keep "suspicious" as a pressure play: "something's up here, but I'm not sure what yet." **Restored, settled Nov 5, 23:15 and 23:35 with Michael** (it replaces the earlier "belief doesn't change" wording):
    - Evaluate it exactly like an "evil" premise on the same target: same agreement, spillover, trust reward and trust cost.
    - The player is hedging, so every change the case causes is halved, for everyone and in both directions.
    - Implement it as hearing weight, not a stored halved change. Beliefs are recomputed from the cards a listener holds, each held once at the highest `hearing_weight` among the presentations that own it (`workshop/shared_ledger.gd`: "no additive case awards"). A suspicious presentation owns its new cards at half weight, so refiling is safe by construction: the same cards refiled as "evil" rise to full weight once; one new card added and refiled as "evil" puts all at full weight; refiled as "suspicious" again changes nothing; cards already held at full weight stay there.
    - Check in the A/B that half weight comes out near half the change. If it's far off, temper the case cards' likelihood by a power of 0.5 in CaseEval instead.
    - The other half becomes pressure on the target, from one "case strength" for everyone: the average juror's full-weight rise on the target (the one listener, in private). Start so a full-weight rise of about 0.2 gives the conflict premise's pressure (+0.1 private, +0.2 at a meeting), then tune. No rise, no pressure.
    - Pressure is a one-time event when the filing is first heard. Refiling doesn't push the target again.
- **Poisoner candidates:** for an accepted "gift failed" cause, a candidate is someone with an unexplained night sighting in the window of the failed reading. Nobody without one gains suspicion, and with no candidates the cause only discounts the reading.
- **Unclaimed roles:** no. "X is the role they claim" stays, and claims are still needed for specific roles.
- **Order (Claude's call):**
  0. **Attention:** step 0 (a bare defence cites no grounds), then step 0b, own readings pinned during presentations (see Tally's findings below). Both change attention, so each gets its own baseline before step 1. That keeps the step 1 A/B about the premise alone.
  1. **Core:** condition on the premise, target weighting with 40–80% spillover, the 0.02 trust cost, the rejected-case preference fix, reply text from the conditioned result, and the preview hint. Measure it with the bot A/B before going further.
  2. **Types and secrets:** merge the types, add the suspicious pressure play, add secrets as linkable premises, and remove the per-card "evil or Marked" pick (this removes existing UI, so it needs your sign-off). The contradiction-link and auto-included claim UX changes go here, since they touch the same canvas code.
  3. **Challenges:** graded leave-one-out scoring, same-source inconsistency, the causes and the Poisoner-candidate rule, and the Minion lineup variable that "they were poisoned" depends on.
  4. **Later:** Scion and Revenant identity, then movement premises. Breathstealer and Brute stay circumstantial, as decided.
  - **Recency (after step 1, its own A/B):** the topic of the day, card age decay, and calling attention back. See the section below.

## Recency: the topic of the day (decided Nov 6, built after step 1)

Real Blood on the Clocktower towns lock onto the day's topic, and established facts drift
until someone calls them back. Attention should model that on purpose, not by accident (the
old remembered `attention_target` resembled it but was per listener, set only by the player,
and never faded).
- **A public topic of the day.** People nominated, accused or argued about at today's
  meeting, shared by the whole town. Cards about them rank higher in attention, fading over
  a day or two.
- **Card age decay.** Older cards lose salience, so established facts drift out of a
  bounded mind's attention. Lower Insight drifts more.
- **Calling attention back.** Citing or re-presenting an old card refreshes its age, so the
  player (or an NPC) can say "remember Dorian's Dowser reading?" and it lands.
- **Re-presenting restores attention, never weight** (Nov 6, with Michael). Today's rule,
  "re-presenting evidence they already hold adds nothing", becomes "re-presenting adds no
  evidence; it can bring back what the listener stopped weighing".
  - Its effect is bounded by what full attention to that card would give. A mind that never
    let it drift (high Insight, or the card is recent) doesn't move. A low-Insight mind
    that dropped it moves back toward it.
  - Repeating it again while it's still recent does nothing, so spamming a case can't
    ratchet belief.
  - Cited at a meeting, it refreshes the card for the whole town.
  - Tests: no change while recent; after decay, movement toward the full-attention value
    and never past it.
- **Measure separately.** It likely makes the town worse in long games, so it gets its own
  A/B after step 1, not mixed into step 1's.
- **For the evil-mind work:** evil could steer the topic away from a teammate.

## Tally's Nov 5 findings and how they change the plan

These findings come from Tally's playtest analysis (`claude/playtest-report-2026-11-05.md`, issues 9–10, plus the defence investigation after PR #77).

### The defence attention bug: fix it first (new step 0)

A nominee's bare defence ("X is lying" or "X's gift was turned") becomes a reading challenge whose grounds are every fact the listener holds. In `shared_ledger.gd`, the challenge's `supports` are all facts except the reading. The attention rule in `reasoner.gd` (`_linked_counterparts`, "never attend a challenged report without its challengers") then pulls all of those facts in. From then on, every listener who heard the defence reasons with full attention, about every suspect. In game 13910, Constance went from 8 of 22 cards to all 22, and her chance that Fenwick was evil fell from 0.46 to 0.31.

**Fix (Tally's suggestion, agreed):** give a bare defence empty grounds. Attention stays bounded, and the challenge is judged only on its own merits at its 5% hearing weight. The player's challenges are unaffected, since their grounds are case cards that are already presented. This is a behavior change, so it needs a new baseline and a check against main. It goes before step 1, because the step 1 A/B is meaningless while one defence can switch a listener to full attention.

Since PR #79 (Nov 5), a nominee facing the player's filed case challenges the reading the case rests on ("Your whole case rests on X's reading") through the same defence path. With step 0 that challenge also has no grounds, which is intended: it's a bare objection.

### What this changes in the challenge design

The cherry-picking guard said "compute f from the cited grounds plus the cards the listener already holds". Taken literally, that rebuilds the same bug. Revised:

- **What stays as it is:**
  - Certain knowledge (own alignment, people known to be good, `direct_checks`) always applies, whatever the attention.
  - Outside presentations (belief refreshes, meetings, votes), a listener always keeps their own readings, whatever their attention budget.
  - The bug isn't own readings. It's a bare defence pinning every heard fact, including hearsay, with no budget.
- **Own readings stay in view (step 0b; revised Nov 5 with Michael; replaces "compete for the leftover budget").** Today, during a presentation, the case's cards are always attended and the listener's own readings compete for whatever budget is left (`workshop/reasoner.gd`, `_prepare`). A case with as many cards as the listener's budget leaves nothing over. Then a low-Insight listener judges it without their own reading, even one that flatly contradicts it. The new rule: during any presentation or challenge, the listener's own readings that bear on the premise's target or on a cited card are pinned, outside the budget.
  - It's usually one or two cards, so bounded listeners stay bounded. What made Constance a perfect reasoner was 14 extra cards of hearsay, not her own reading.
  - Hearsay, testimony and cards from other people stay inside the budget. That keeps the attention cap, and Insight, meaningful.
  - It covers plain cases as well as challenges. A case can't crowd out a listener's own clear of its target, and a challenge to a reading the listener's own reading backs up still fails.
- **f is computed over the cited grounds, the listener's attended set and those pinned own readings.** Grounds that aren't case cards, attended or pinned don't get pulled in.
- **The "never attend a challenged report without its challengers" rule only pulls in grounds that are cards in the case.** It never pulls in the listener's other holdings.
- **With empty grounds,** a graded challenge is scored on the listener's attended set plus their pinned own readings. If that evidence argues against the reading, a bare defence can still land, at its small weight. That seems fair, and the bot runs can measure how often it happens.

Graded scoring also fixes Tally's "improbable isn't weighed" case ("a Surveyor was abroad on the Square" needs a rare night-walking secret). It scores high, instead of failing the impossible-only test.

### Attention is a big lever on spillover

The same mind gave 0.46 with 8 cards and 0.31 with 22. The 40–80% spillover applies on top of bounded attention, so the step 1 A/B has to hold attention budgets fixed between arms. Otherwise attention effects get read as premise effects.

### A baseline for step 1

On filed case #78 ("Fenwick is evil"), the average chance Fenwick was evil moved only from 0.42 to 0.52. Removing any one card changed it by 0.03 at most. Most of the probability the case moved went to Kiran, Bartholomew and Jory. Step 1 should replay this case: the target's shift should grow, and the others' should shrink to the 40–80% band. `explain_case.gd` (case mode with `--add`, `--drop` and `--challenge`) and `replay_log.gd --why` are the tools (`docs/DECISION_INSPECTOR.md`).

### Replies: two sources, kept apart

Case replies currently voice the case-scoped evaluation, which is where "Kiran is the Demon" came from. PR #73 moved the "my chief suspicion remains…" lines onto listener beliefs. This refines step 1's "reply text from the conditioned result":

- The stance on the argument (agree or disagree with the premise, and why) comes from the conditioned case result.
- Anything about the listener's own suspects comes from their beliefs.
- `_append_movement_notes` (`sim/dialogue_presentations.gd`) adds the "seen elsewhere, so not the killer" and "the traces incline me" clauses whatever the premise type. They should only appear for premises that talk about the killer. This was playtest issue #5, deferred to this pass.

### Out of scope, noted

- **Self-clearing fabrications:** removing Fenwick's fake Monitor reading raised suspicion of him by 0.12–0.17. This belongs to the backlog item "Evil sometimes tells the truth". The same-source inconsistency premise helps only when the fabrications clash with each other.
- **Vote weight:** the player's "accuse" plus "vote yes" adds 0.125 to every voter's score. That's a voting question, not a premise one.
- **Replay drift:** old logs stop replaying on main as the random rolls shift. If the log's `case_start` recorded its commit, the replay tools could check that commit out automatically. The `build` field already exists (`sim/world.gd`, `setup` and `case_start`) but is empty: what's left is filling it with the commit. It's small, so it can ride with step 0 (the step 0 branch doesn't include it yet).

## Evidence: code paths and probe

**Code paths read:**

- `workshop/jury.gd`: `_consequences_eval` runs a single CaseEval pass over the attended evidence; `_assess_target_eval` and `_eval_listener` only produce agreement and the stance.
- `workshop/case_eval.gd`: `theory_fit` is diagnostic only. The challenge reliability multiplier is at line 322.
- `workshop/reading_challenges.gd`: the "supported" test (impossible, or consistent alone and impossible together, or Surveyor "unlikely").
- `workshop/solver.gd`: `holds` maps 15 types to 7 world questions.
- `workshop/reasoner.gd`: `_prepare`. The premise target only ranks the listener's own cards inside the leftover attention budget.
- `workshop/live_assessment.gd`: `canvas_issues` blocks faults, temporal positions, derived claims and challenges.
- `game/workshop_presentation.gd`: the trust reward, the deduction-case credibility skip and the conflict pressure.
- `sim/mind.gd`: `_apply_conclusion_pref` applies even when the case is rejected.
- `sim/tuning.gd`: `CONCLUSION_COEFFS` is effectively overwritten by the pass.

**Probe (seed 692, 7 people, case "T evil <- dowse + seer\_yes"):**

- Changing type, target, positions, answers and sub-premises: identical belief effects.
- Adding a card (seer\_no): effects changed.
- Conflict type: effects changed (source pressure).
- Grounded challenge: about 0.03 difference. A challenge without grounds: no difference. Lying and misled: identical numbers.
- Replies were sometimes inconsistent with the premise: "Merrin is good" drew a reply naming Merrin as the Demon.

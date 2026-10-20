# Social tuning reference

Audited on 2026-10-20 against [main at 6939e40](https://github.com/kultcher/deduction_game/tree/6939e40d267b435c53a40fe0f4ce2ccf4a37d4ea).

This is a reference for the implemented model, not a proposed rebalance. Values are scattered through code; editing this document does not change the game. It covers player trust, NPC relationships, suspicion and credibility, persuasion, disclosure, meeting decisions, social information flow, and the evil strategies that interact with them. The tactical appendix covers the main kill/poison/silence weights. Combat-free map scheduling and role setup rules are outside its scope.

**Version boundary:** the tested playtest-fix commit `402ac63` was still local when this document was written. Its social changes are listed separately at the end. Tables otherwise describe the audited main revision. The raw logs for cases 61251 and 25923 could not be read in this session because the execution environment was unavailable and their Library text extraction returned no content. Examples below are code-derived illustrations, not reconstructed trust timelines.

**Later clarification supplement:** [section 16](#16-clarification-supplement-and-executed-ledger-example) checks the requested fatigue, fear, pressing, item-search and ledger details directly against `1998c66`. The full narrative walkthrough is in [TUNING_NARRATIVE.md section 16](TUNING_NARRATIVE.md#16-how-the-ledger-works-a-meeting-case-against-greta). This supplement does not revise the historical audit boundary above or apply the requested backlog retuning.

## 1. Quantities and common rules

| Symbol | Meaning | Range / behavior |
| --- | --- | --- |
| P | Privacy | 0–1; protects own information |
| G | Gossip | 0–1; willingness to discuss others |
| C | Confidence | 0–1; conviction and resistance to changes |
| I | Insight | 0–1; evidence discrimination and memory |
| K | Composure | 0–1; hides nerves and dampens pressure/panic |
| T | Trust in the player | 0–trust_cap |
| B(a,b) | a's relationship trust in b | Usually 0–1; independent of T |
| S(a,b) | a's suspicion of b | Clamped 0–1.5; not a probability |
| R | Pressure / scrutiny | Starts at 0, no general upper clamp |
| H | Paranoia | 0.07 × dead NPC count × (1 − 0.6K) |
| F | Confidence multiplier on eligible suspicion effects | 1.4 − 0.8C; ranges 1.4 down to 0.6 |
| W | Player word multiplier | Normally 0.5 + T; ranges 0.5–1.5 |

Source: [mind.gd](sim/mind.gd) `trait_of`, `paranoia`, `adjust`, `word_factor`; [npc.gd](sim/npc.gd).

### Shared percentage roll

`Mind.decide` adds named score parts into x, then rolls:

`p(yes) = 1 / (1 + exp(−4x))`

| Total x | −1.0 | −0.5 | −0.25 | 0 | +0.25 | +0.5 | +1.0 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Yes probability | 1.8% | 11.9% | 26.9% | 50% | 73.1% | 88.1% | 98.2% |

A +0.1 score change is not +10 percentage points. Its effect depends on the current score. Later sections label this a **sigmoid roll**. Direct `chance(p)` calls instead compare a uniform random draw with p; unbounded expressions above 1 become certain and below 0 impossible.

### Initial state

Source: [world.gd](sim/world.gd) `setup`, `_assign_relationships`.

- Each trait = cast baseline + uniform noise within that trait's listed spread; clamp to 0–1 and round to 0.01.
- Initial player trust: `clamp(0.3 + 0.25(1−P) + U(−0.05,+0.10), 0.1, 0.9)`.
- Initial suspicion of another NPC: 0.1; rival +0.15; friend −0.1.
- Initial relationship trust: `0.5 + U(−0.05,+0.05)`; rival −0.25; friend +0.25; round to 0.01.
- Each unordered NPC pair has one roll: <0.20 means friends; 0.20–<0.32 means rivals; otherwise neither. Thus 20% / 12% / 68% before fallback.
- An NPC with no friends gets a random non-rival friend if possible. These additions are reciprocal, so final friend rates exceed 20%.
- Lovers override their relationship trust to 0.9 and suspicion to 0.
- A good NPC's own role claim enters the ledger at weight 1.5.

### Cast trait rolls

Each cell is **baseline ± uniform spread**, before clamping. Source: [content.gd](sim/content.gd) `CAST`.

| NPC | P | G | C | I | K |
| --- | --- | --- | --- | --- | --- |
| Agnes | .20±.10 | .90±.05 | .50±.20 | .40±.15 | .30±.10 |
| Bartholomew | .70±.10 | .15±.10 | .75±.10 | .40±.20 | .70±.10 |
| Constance | .50±.20 | .40±.20 | .80±.05 | .60±.10 | .50±.20 |
| Dorian | .75±.15 | .50±.25 | .20±.10 | .50±.20 | .15±.10 |
| Edda | .40±.25 | .60±.10 | .55±.10 | .55±.10 | .85±.05 |
| Fenwick | .15±.10 | .80±.15 | .60±.25 | .30±.10 | .40±.20 |
| Greta | .80±.05 | .30±.20 | .70±.15 | .75±.10 | .60±.15 |
| Hollis | .60±.10 | .25±.30 | .45±.10 | .90±.05 | .80±.10 |
| Isolde | .65±.20 | .45±.15 | .25±.15 | .45±.25 | .25±.15 |
| Jory | .30±.30 | .70±.20 | .50±.30 | .35±.15 | .45±.25 |
| Kiran | .80±.10 | .85±.10 | .60±.15 | .55±.15 | .70±.10 |
| Lian | .45±.15 | .20±.10 | .60±.15 | .80±.10 | .70±.10 |
| Merrin | .20±.10 | .85±.10 | .60±.20 | .25±.10 | .15±.10 |
| Nisha | .70±.10 | .20±.10 | .85±.05 | .85±.05 | .75±.10 |
| Odette | .70±.10 | .30±.15 | .80±.10 | .60±.15 | .60±.15 |

## 2. Every player-trust mutation

Trust changes below apply to the affected NPC, not automatically to the entire town. Multiple applicable rows can stack during one action. Good/evil qualifications matter: evil's displayed trust also drives its cover/disclosure behavior, while shadow evaluations can mutate the separate good self.

Source functions: [mind.gd](sim/mind.gd) `set_trust`, `cap_trust`, `end_of_day_trust`, `_info_effects`, `press`, `on_question`, `end_conversation`, `answer_gift`, `_secret_used`, `hear_accusation`; [argue.gd](sim/argue.gd) `evaluate`; [social.gd](sim/social.gd) `answer_is_role`; [world.gd](sim/world.gd) `open_nomination`, `clemency`, `vote_pending`, `_grief`; [game.gd](game/game.gd) `_offer_command`, `_settle_offers`, nomination statements, `_break_confidences`.

| Trigger | Trust change | Conditions / repetition |
| --- | --- | --- |
| End a civil conversation | +0.04(1−0.5P), i.e. +.02 to +.04 | Once per NPC per day |
| First private disclosure of their named role | +.03 | First tier-3+ disclosure, before any public claim |
| Offer ward or vigil | +.03 | Per accepted promise; duplicate same promise rejected |
| Keep promised ward/vigil | +.06 | Per promise; total with offer +.09 |
| Break promised ward/vigil | −.15 | Per promise; total with offer −.12 |
| Keep their confessed secret through a day | +.03+.04P | Every night-resolution trust pass while secret_known and not secret_spread; ×.4 if NPCs have spread it |
| Press with relevant evidence | −(.03+.06P) | Good only; Clerk naming the listener is exempt; can combine with question fatigue |
| More than 3 counted questions that day | −(.03+.05P)(1−0.5K) for each further counted call | Range .015–.08; applies inside `on_question` |
| Wrong direct role guess | −.02 × wrong-guess count | Counter persists across days; nth wrong guess costs .02n |
| Accuse someone the listener trusts | −.24(B−.5) | First hearing of card; B>.6; .024–.12 loss |
| Agree with listener's existing suspicion | +.05(1−0.5I), i.e. +.025–.05 | New card, old suspicion ≥.5; does not require a strong or correct case |
| Make a raw private accusation that gains ≥.1 ledger weight | +.02 | Only if previous agreement-reward branch did not run |
| Structured argument: agreement ≥.6 and gain ≥.1 | +.02 | May occur privately or publicly, subject to actual weight gain |
| Argue accusatory conclusion to its good subject's face | −.05 | Types evil/demon/lied/notrole/suspicious, unless earlier own-lie branch handled it |
| Good NPC admits a whereabouts lie | +.02 | Successful admission roll after player catches it |
| Player nominates this NPC | −.15 | Does not itself reduce anyone else's trust |
| Player publicly speaks against nominee | −.08 to nominee | Separate from card evaluation |
| Player publicly defends nominee | +.06 to nominee | Also −.04 to NPC nominator if nomination was theirs |
| Player votes yes on an NPC nomination | −.08 to nominee | Not charged when player was nominator |
| Clemency | +.15 to spared NPC | Even if evil |
| Clemency, other good NPC with S(spared)<.35 | +.06 | Independent of relationship bond |
| Clemency, other good NPC with S(spared)>.6 | −.10 | Exact .35/.6 do not meet these strict comparisons |
| Clemency overrides NPC's nomination | −.08 to nominator | Can stack with that NPC's assessment of the spared person |
| Heard Gravedigger says player-backed execution was good | −.06 | Fresh hearing, not own reading, hearing weight>.2, player nominated or voted yes |
| Heard Gravedigger says player-backed execution was evil | +.08+.06I | Same gates; +.08–.14 |
| Execute someone the good listener trusted at B≥.62, player nominated | −.3 × 2(B−.5) | Also permanently lowers cap to .55; Demon execution exempt |
| Same grief, player only voted yes | −.2 × 2(B−.5) | No grief cap in this branch |
| Cite secret against someone, in public statement, or as deduction support, first time | −(.08+.4P) to owner | Sets secret_spread; also see caps below |
| Use it again | −.4(.08+.4P) | Not a once-only penalty |
| Break a confidential hint disclosure at meeting | −.15 | For a living source whose role remains non-public; recorded confidences are removed when processed |

### Trust caps and recovery

`set_trust` clamps to [0, trust_cap]. `cap_trust` only lowers the cap.

| Cause | Full cap sequence |
| --- | --- |
| Player spreads owner's secret | P<.34: no new cap; .34≤P<.67: cap .60; P≥.67: cap .30 |
| Grief for player-nominated execution | If good mourner's bond to executed ≥.62 and executed is not Demon: cap .55 |
| Multiple caps | Minimum ever applied wins |

There is no ordinary apology, vindication, time decay, or cap-restoration path. A later trust gain stops at the existing cap. For B=.9, grief is −.24 for nominating or −.16 for only voting yes.

Trust events log when the actual clamped delta has magnitude ≥.01; smaller changes can still occur. Values are logged rounded to .01. A requested +.03 at a .55 cap may produce no event or a smaller gain.

### When trust revises earlier arguments

- `set_trust` calls reconsideration when |T − trust_at_reconsider|≥.10.
- Before a good vote, reconsideration is attempted regardless; it returns if the gap is <.03.
- Reweight rate = 1−.6C (.4–1.0).
- Desired player-argument weight = stored base × (.5+T).
- New weight = current + (desired−current) × rate.
- Changes <.02 are skipped. For multiple justifications, each moves toward its own desired weight; strongest wins.
- A renewed-argument remark is queued once weight reaches at least max(original×1.35, original+.05).

Trust does not retroactively alter the truth of evidence or the flat .5 weight for a reading heard directly from an NPC. It revises entries carrying a player-argument base.

## 3. Suspicion from readings, testimony, and public opinion

### Reading effects before weighting

Source: [mind.gd](sim/mind.gd) `_info_effects`.

Numbers are **raw per-target effects**, not final suspicion or probability of evil. Multiply by hearing weight and source reliability, and by F where the confidence column says yes. Own readings normally have weight 1.0; a shadow's fake own readings use 1.2.

| Information | Raw effect | Confidence multiplier |
| --- | --- | --- |
| Seer yes, two unresolved names | +.45 to each | Heard yes; own no |
| Seer yes, only one unresolved name after excluding self/known-good | +.85 to remaining name | Heard yes; own no |
| Seer no | Own −.45; heard −.30 | Heard yes; own no |
| Hearthwitch / Dowser zero | −.25 to each unresolved person | Heard yes; own no |
| Hearthwitch / Dowser count k>0 | +.35k each; +.70k if at least one group member excluded as self/known-good | Heard yes; own no |
| Heard count impossible from listener's view | +.50 against source | Yes |
| Night Watch sighting | +.50 × night scale | Heard yes; own no |
| Night Watch claims listener was out when listener knows they were home | +.45 against source | Yes |
| Archivist | +.35 each for two unresolved names; +.75 if only one | Heard yes; own no |
| Rumormonger pair | −.12 each, excluding listener | Heard yes; own no |
| Martyr claims a chosen person | −.20 to target | Heard yes; own no |
| Martyr reveals evil execution (Martyr survived) | +1.0 to executed target | No |
| Veteran survival gives approach block | +.12 to each other eligible resident there | Heard yes; own no |
| Psychologist association | +.10 if subject or trusted person already S>.5; can affect either half | Heard yes; own no |
| Medium relays reading | .60 × original role's raw effects | Uses inner role's rules |
| Medium relays sighting | +.30 × night scale | Heard yes; own no |
| Medium relays dead person's suspicion | +.12 | Heard yes; own no |
| Clerk correctly identifies listener's own role in pair | −.30 against Clerk | Yes |
| Clerk pair generally | −.15 each, excluding listener | Heard yes; own no |
| Gravedigger says executed was evil/good | +1.0 / −.40 | No |
| Gravedigger verdict, NPC nominator of good/evil executed | +.25 / −.20 against nominator | Yes |
| Someone else claims listener's own gift | +.60 via rival-role effect | No for own-role knowledge; otherwise yes |
| Accepted good-role claim | Role-belief effect 1.0 | No; does not itself clear alignment |

"Unresolved" here means the listener and demon-killed known-good people have been removed. An ordinary role claim or suspicion score of 0 does not trigger the same exclusion.

Gravedigger trust rewards/penalties are additionally applied under the gates in section 2. Their own verdict does not trigger that player-trust row because the code requires a heard reading.

### Night-sighting discount sequence

Source: `night_sighting_scale`.

1. Did someone actually die on that block on that night? Yes: scale 1.0. No: .12.
2. If the subject publicly claims a night-walking role, multiply by `1−.7×clamp(claim_credence,0,1)`.
3. If there is no listener (raw-card strength), public walking-role credence is assumed .5, so this multiplier is .65.
4. Apply the hearing/card route's other multipliers afterward.

A blocked attack does not create the same murder-scene condition. Thus a true sighting at a thwarted attack can receive .12 even though it matters strategically.

### Hearing weights and derived credibility

Source: `apply_info`, `heard_weight`, `ledger_hear`, `recompute_beliefs`, `reliability`.

| Path | Starting weight |
| --- | --- |
| Own reading | 1.0 |
| Shadow's own fabricated reading | 1.2 |
| Directly heard NPC reading, including public sharing | .5 |
| NPC-to-NPC item | clamp(.75×listener's B(teller),0,.55) |
| Anonymous meeting relay | .30 × .5 = .15 |
| Own-role claim at setup | 1.5 |
| Public role claim | .5 |
| Other already-known-good source's role claim | Its raw weight ×2 during recomputation |

Reliability = `(1−max(night-specific doubt, all-night doubt)) × source honesty`.
Doubt only affects **readings**; ordinary reports/role claims do not get poisoned. An NPC does not discount their own honesty, but can doubt their own reading.

- Reading doubt accumulates from relevant ledger effects and caps at .90.
- Honesty = `1−clamp(.8×max(0,evidence grounds),0,.5)`: minimum .50.
- Grounds use evidence effects, not suspicion/vibes/grudges. Negative effects can offset positive grounds.
- Evidence about its own source and the listener is excluded from honesty grounds.
- The calculation has a fixed two-pass source-honesty estimate. It is not iterated to convergence.
- Supports are averaged for source reliability. A reading doubt introduced by the argument itself is excluded from penalizing that argument's supports.
- One fact's ledger hearing retains the **maximum** weight heard. Repeating the same reading does not add another copy.
- An argument retains each distinct support set, but its current influence is the **strongest justification**, not their sum.
- Role belief is installed at total role effect ≥.12; removed when below .12.
- Effect differences smaller than .002 are ignored.
- Suspicion is clamped after each application to 0–1.5. Own suspicion is not adjusted. Demon-killed people are treated as known good; their suspicion is set to 0 and later adjustments ignored.

Recomputation sequence: preliminary reading doubt → two-pass honesty estimate → scale each justification by its supports → final reading doubt → final two-pass honesty → apply effect differences. This limits circular justification, but does not remove every feedback effect elsewhere.

### Town accusations / consensus

Source: `_public_accusation`, `refresh_consensus`.

- Latest stance only per accuser.
- Base .12 × (.5+B(listener,accuser)).
- Hinted private reason: ×1.15.
- Age: ×.60 per elapsed day.
- Sort strongest first, then multiply each next voice by .5^index.
- Cap combined consensus at .30, then apply F to the suspicion adjustment.
- Consensus is outside the evidence ledger, so it does not count as evidence of dishonesty.
- Each actual accusation also adds target pressure .15×.5^(earlier accusations against same target this meeting).

### Other NPC-to-NPC effects

Source: [social.gd](sim/social.gd) `_deliver`, `paranoia_drift`; [world.gd](sim/world.gd) `_grief`.

| Trigger | Effect |
| --- | --- |
| Heard ordinary night sighting | +.40 × night scale × (2×NPC hearing weight), then F and reliability |
| Heard opinion | +.12 × (2×NPC hearing weight), then F and reliability |
| Relayed player case | +.10 × (2×NPC hearing weight), then F |
| Received an item | B(listener,teller)+.02, clamp 0–1; good receiving path |
| NPC nominates someone | Nominee's B(nominator)−.25 |
| Grief, B(executed)≥.62 | Strength=2(B−.5); +.30×strength suspicion against NPC nominator, B(nominator)−.20×strength |
| Same grief against other yes voters | +.12×strength suspicion; excludes mourner and nominator |
| Each new morning | +.06H suspicion of each other living NPC not cleared by own Seer no |

Grief excludes a Demon execution, but can mourn a minion. Grief suspicion changes are not confidence-scaled.

## 4. Raw cards and private/public persuasion

Sources: [mind.gd](sim/mind.gd) `evidence_class`, `card_strength`, `defend_strength`, `card_weight`, `hear_accusation`, `hear_defence`, `hear_group_case`, `public_case`.

### Evidence quality factors

| Factor | Value / sequence |
| --- | --- |
| Player-observed sighting/vigil/death/vote/execution/conversation/quiet card | Concrete |
| Claim/hint/refusal/opinion/accusation/alibi | Speech |
| Other cards | Circumstantial, unless deduction carries a saved class |
| Class multiplier | Speech 1−.8I; circumstantial 1−.4I; concrete 1 |
| Raw-card source credibility | Player 1; physical evidence .9; listener's own words 1; other named NPC .75; unknown .5 |
| Subject relevance | Named subject 1; otherwise .25 |
| Trace relevance | Home or work on trace block 1; otherwise .30 |
| Already has this exact fact in ledger | ×.35 |
| Word factor | .5+T |
| Corroboration of player's observation | At least 1.4 if listener witnessed it; otherwise at least .5+clamp(.9−S(corroborator),.1,.9) |
| Hearing counter repeat factor | .35^times is computed by card_weight, but the current persuasion callers rely on ledger maxima rather than multiplying this factor |

A raw testimony card gets .75 starting credibility plus live ledger reliability; structured arguments use a different source credibility formula (section 5). These two routes are not numerically equivalent.

### Incriminating raw strength

| Card | Strength before quality/trust |
| --- | --- |
| Night sighting | 1.4 × night scale |
| Day sighting | .15 |
| Seer | Yes 1; no 0 |
| Hearthwitch | .5 × count |
| Archivist | .8 |
| Night Watch | 1 if target in seen; otherwise 0 |
| Gravedigger | .3 |
| Other reading | .6 if Gifts.implicated names suspect; otherwise 0 |
| Trace | .7 |
| Home / haunt | 0 |
| Accusation / opinion | .4 |
| Refusal | .25 if fear; otherwise .35 |
| Secret | .5 |
| Role claim | 1 if another public claimant has same role; otherwise .1; absent/none .1 |
| Unhandled kind | .2 |

### Defensive raw strength

If target is not a card subject: .1.

| Card naming target | Defence strength |
| --- | --- |
| Seer no / yes | .8 / 0 |
| Hearthwitch zero / nonzero | .6 / 0 |
| Clerk | .5 |
| Night Watch | 0 |
| Other reading that Gifts.clears names | .5 |
| Claim | .2 |
| Death | 1 |
| Vigil | .4 |
| Secret | .4 |
| Otherwise | .15 |

### Resulting influence

Let q=source credibility × class multiplier × already-known factor. The word multiplier is .5+T; private accusation and public raw-card routes may upgrade it for corroboration. Private defence and group accusation use .5+T directly.

| Route | Base ledger weight before w, live reliability, and F |
| --- | --- |
| Private accusation | .35×q×subject relevance×raw strength |
| Private defence | .30×q×defence strength / group size |
| Private case against a pair/group | .35×q×raw strength / group size |
| Public card-backed accusation | .25×q×subject relevance×raw strength |
| Public card-backed defence | .25×q×defence strength |

Private accusation against a trusted friend (B>.6) additionally multiplies base by `1−1.4(B−.5)` and incurs the first-hearing trust penalty. Private/group/public entries are distinct ledger identities, so they can add across those routes; simply repeating one route does not keep adding.

Raw accusation response thresholds, in order: repeat → self → strength<.3 for named subject → relevance<.3 → friend B>.65 and gain<.1 → speech with I≥.67 and gain<.1 → final S≥.8 → gain≥.15 → tentative. These are speech choices, not an extra evidence roll.

Raw defence response: repeat → strength<.2 reject-clear → gain≥.12 favorable → tentative. Group accusation says favorable at combined gain≥.12.

For orientation: an own Seer yes gives .45 each for two unresolved names. A heard Seer yes starts at .225 each before F/reliability. A fresh player-observed murder-block night sighting presented privately, at T=.4 and C=.5, gives .35×1×1×1.4×.9=.441. These examples illustrate different routes; they are not probabilities or recommended new values.

## 5. Structured deductions and interpretation weights

Source: [argue.gd](sim/argue.gd) `evaluate`, `_expl_weight`, `_quality`, `_support_strength`, `effects_of`, `_apply`.

### Evaluation sequence

This order matters; the first applicable branch determines agreement.

1. Evil listener: strategy mask plus possible shadow override; no real evil suspicion update. See section 10.
2. Conflict ("someone in this group is misled or lying"):
   - Recognized contradiction template: agreement=.55+.35I.
   - Unfounded: with probability I, 0; otherwise .30.
   - Other: clamp((.30+.35T)(1.25−.6I),0,1).
   - Listener in group: cap at .35+.55(1−C).
3. About own reading being misled/unreliable, unless it is a lie they know they told: reinterpret as misled, agreement=.35+.55(1−C).
4. Caught own whereabouts lie: agreement=0; admission handled separately.
5. Accusatory conclusion about self: agreement=0; trust−.05.
6. Other conclusion about self: agreement=1.
7. Recognized template: chosen interpretation weight / (chosen + **strongest non-overlapping rival**), denominator floor .01.
8. Unfounded non-template: probability I of 0; otherwise .35(1−I)+.20T.
9. Other non-template: generic support strength (table below).

"Misled or lying" overlaps the same subject's "lying" and "misled" explanations, so those components do not compete against their own umbrella explanation. This is not a full probability distribution over mutually exclusive worlds.

### Full interpretation-weight table

Let s=S(listener,subject), b=B(listener,subject). Firsthand checks precede this table: an attached assertion the listener knows false gives weight 3; one they know true gives 0 for the competing false-assertion explanation.

| Interpretation | Weight |
| --- | --- |
| Subject lying / not holding claimed role | Self 0; otherwise max(.15+1.2s−.5(b−.5),.02); multiply pre-floor base by .3 if subject is demon-killed known-good |
| Subject misled | .25; +.10 if they publicly claim an info role |
| Association / working together | Self 0; otherwise max(.05+.25×times×cred+.45×cred+.6s,.02) |
| Accuse subject | Self 0; otherwise max(.15+1.2s−.5(b−.5),.02) |
| Innocent alternative / clear | Self 3; otherwise max(.30+.6(.60−s)+.4(b−.5),.05) |
| Seer red herring explanation | .30+.40(1−clamp(S(listener,conclusion subject),0,1)); +.10 if that subject is self |
| Unreliable (misled or lying) | Lying weight + misled weight |
| Unhandled kind | .10 |

Association credence: if its base argument exists, clamp(base ledger weight×1.5,0,1); otherwise .8×source credibility for a named base source; otherwise 0. `times` defaults to 1.

At neutral bond .5 and initial suspicion .1, an accusation interpretation is .27 while an innocent alternative is .60: agreement≈.31 if those are the competitors. At suspicion .6, the same weights become .87 and .30: agreement≈.74. This makes existing suspicion materially influence how new evidence is interpreted.

### Generic, non-template support strength

| Conclusion | Agreement before quality |
| --- | --- |
| evil/demon/lied/notrole | clamp(sum(raw incriminating strength × relevance)/1.2,0,1) |
| good/protect/spare/notdemon/truthful | clamp(sum(defence strengths),0,1) |
| suspicious | clamp(.2+sum(raw strength×relevance)/1.5,0,.8) |
| secret/marked/red_herring/secret_mod | clamp(.25+sum(defence strengths),0,.8) |
| misled/unreliable | .5 if support contains this subject's relevant reading; otherwise .2 |
| role | .5 for a matching self-claim; otherwise .2 |
| Unknown subject / fallback | .2 |

Relevance for generic incrimination: 1 if subject is named **or is the source**; otherwise .3. This differs from raw presentation's .25 off-subject relevance.

### Quality, novelty, application, and response

- Structured source credibility: player 1; evidence .9; own words 1; another NPC clamp(.9−S(source),.1,.9); unknown .5.
- Quality = mean(source credibility × support card's class multiplier). No supports: .3.
- Filed deduction class = weakest support class; generic inference cannot exceed circumstantial.
- Novelty for accusatory types = .35+.65×(fresh underlying facts / all underlying facts). Old evidence bottoms out at .35.
- Base = agreement × quality × presentation scale × novelty.
- Presentation scale: private 1; whole-meeting floor speech .6; deduction used in nomination statement .5.
- Ignore base≤.004. Otherwise ledger weight=base×(.5+T), then apply source reliability and effect-specific F.
- Supporting deductions are recursively followed up to depth 4 for source references.
- Responses: agreement<.35 reject; .35–<.60 partial; ≥.60 accept.
- Accepted but first presentation gain<.02: "already thought so" presentation.
- Sound-argument trust bonus requires agreement≥.60 **and** gain≥.10.
- Source explanation is used when quality<.35 unless an earlier self/alternative branch applies; named doubtful source requires credibility<.30.
- NPC may name preferred overall suspect if that person's suspicion exceeds target by >.05.
- Own-lie admission chance: .20+.45(1−P)+.30R+.30(T−.5), direct roll; admission trust+.02. No clamp in this expression.
- Speaking/withholding lines can differ from numeric agreement. An admitted own lie still took the agreement=0 branch.

### Effects of an accepted conclusion at ledger weight 1

Except where marked, suspicion effects also get F. Actual ledger weight is usually substantially less than 1.

| Conclusion | Effects |
| --- | --- |
| evil | S+.45 |
| demon | S+.55 |
| good | S−.40; protect preference+.50 (no F) |
| protect | protect preference+1 (no F); S−.15 |
| spare | spare preference+1 (no F); S−.15 |
| evil role | role belief+1 (no F); S+.50 |
| good role | role belief+1 (no F); S−.10; rivals claiming that role S+.30 |
| notrole | S+.30 |
| lied | S+.30; if the specified card is a reading, doubt that source/night +.50 (no F) |
| misled | reading doubt +.80 (no F), specific night or all nights |
| unreliable | reading doubt +.50 (no F); S+.12 |
| notdemon | S−.25 |
| truthful | S−.15 |
| conflict | Each member: S+.05; all-night reading doubt +.40/group size (no F) |
| suspicious | S+.15 |
| secret | S−.12 |
| marked | S−.30 |
| red_herring | S−.40 |
| secret_mod=delusional | All-night reading doubt +.70 (no F) |
| Other secret_mod | S−.15 |

No independent numerical action-utility model yet distinguishes "probably Demon" from "worth executing for a Gravedigger result." Execution decisions primarily consume suspicion and preferences.

## 6. Private disclosure, questions, and night accounts

### Role/info disclosure: complete threshold sequence

Source: [mind.gd](sim/mind.gd) `_target_tier`, `answer_gift`.

`openness = (1−P) + 1.2T + .6R(1−.5K) + .1(day−1) − .72 + U(−.2,+.2)`

| Openness | New target tier | What this tier permits |
| --- | --- | --- |
| ≤.15 | 1 | Refuse / possibly deny if optional denial switch enabled |
| >.15 and ≤.45 | 2 | Hint package |
| >.45 and ≤.75 | 3 | Name role |
| >.75 | 4 | Name role and share readings |

Then, in order:

1. Target=max(rolled target, caller's forced tier).
2. Public role claim forces target≥3.
3. Effective tier=max(target, highest tier already disclosed).
4. Withholding flag = target<previous highest tier.
5. Old public/private readings are repeated regardless; newer private readings need effective tier≥4 **and no withholding flag**.
6. Successful fresh tier 4 advances told_readings to end of info_log.
7. Once role is named, a Warden reports known guard doors in its special branch even without normal info-reading handling.
8. Roles with no readings say so; a role claim is retained even if later trust falls.

This is why an NPC can repeat two old readings and still refuse to share the newest. Fear generally chooses the refusal wording; it is not a direct subtraction from this private openness formula.

### Fear and questions

- Fear chance = .15+.10×demon-killed NPCs+.25(1−K).
- Fear outcome uses deterministic hash of NPC id and day, modulo 1000; fixed for that person/day, no game RNG draw. It can exceed 1 late.
- 3 question slots per ordinary conversation. One repeated question is free per conversation; further repeats consume slots.
- The separate pressed_today counter is incremented by `on_question`, even on many repeated calls; after 3, each further call costs trust.
- Night resolution resets pressed_today and multiplies pressure by .60.
- Explicit conflict deduction adds pressure .10 privately to the listener if involved, or .20 publicly to each living involved NPC. This is separate from pressing/nomination/accusation pressure.
- Direct role guesses maintain their own wrong-guess count across days.
- Correct first role guess has 50% chance of +1 disclosure tier. "First" means no earlier wrong guess; a correct but unsuccessful guess does not increment wrong guesses.
- A correct guessed-role tier≥2 delegates to answer_gift with that forced tier, capped 4; otherwise gives a non-answer.
- General "who is the role?" question about their own role: ownership/delegation chance .15+.20T (15–35%), then forced minimum hint tier 2.
- Sharing another NPC's private claim on a role question requires `.7G+.5T+.3R>.55`, plus good alignment; public claims can be repeated regardless.
- Forced hint follow-up calls both answer_hint's on_question and answer_gift's on_question. Unlike the direct role-guess path, it does not cancel the first count. This can charge more fatigue than one displayed question.

### Pressing with a card

Source: `press`.

1. Card must name listener via subject, conclusion, or pair; otherwise ordinary question count and an irrelevant reply.
2. Strength=.6 for deduction; otherwise clamp(raw card strength,.3,1). Clerk naming listener overrides to .5.
3. Nerves probability=(.6 if hiding else .2)×(1−K)×strength.
4. Pressure += .35×strength.
5. Good NPC loses .03+.06P trust unless Clerk-naming exception.
6. Rival public role claim: reaffirm own role; good NPC adds .30 suspicion against rival (F applies).
7. Night challenge: delegates to night account.
8. Gift challenge: disclosure target+1 if correct Clerk naming; cap 4; delegates to answer_gift.

"Hiding" includes evil, a touched personal secret, or an undisclosed gift. Nervousness is therefore soft evidence and can happen to innocent people.

### Night accounts and confession

Source: `answer_night`.

Night-account branch sequence: Sleepwalker believes they stayed home → approved fake Night Watch location if available → actual home account → disclosed Night Watch duty → disclosed Lamplighter/Medium duty → disclosed Warden door → hidden movement handling.

Hidden movement handling:

- Only good NPCs with a personal secret can confess.
- Confession sigmoid score = 1.5(T−.6)+(.4−P)+.8R(1−.5K).
- If no confession: lie-versus-stonewall sigmoid score = 1.5(C−.5)−.6(P−.5).
- A good hidden walker can lie; evil uses the same lie/stonewall choice.
- Sleepwalker is unaware, so their false home account is not a conscious lie.

Sharing observations afterward:

1. Gossip gate G<.2 and R<.5: share none.
2. Otherwise limit = 1+round(3(G+.5R)); no general maximum clamp.
3. Evil omit actual nighttime sightings of teammates.
4. For a person trusted at B>.7: 60% chance to omit seeing them.
5. If sighting block conflicts with claimed vantage: slip chance=.25(1−K)+.15R; otherwise omit.
6. A fabricated Night Watch report replaces ordinary sightings with its cached story; it is not sliced to the normal limit, but limit=0 still blocks it.
7. Other evil speakers may append their cached fake sighting.
8. Return up to limit ordinary sightings.

### Daytime and person-specific reports

Source: `answer_today`; [recent_sightings.gd](game/recent_sightings.gd).

- Same gossip gate and limit as above.
- Daytime memory=2+round(4I): 2–6 unique people, most recent first.
- Whereabouts statement is separate from sharing other people's observations.
- Current-block observations the player can already see can be omitted.
- Person-specific additions use only current and previous two phase frames: 0≤age<3, at most one observation per frame, newest first.
- Night additions require already disclosed walking gift; preserve existing alibi, refuse contradictions, and hide unconscious Sleepwalker movement.
- Evil do not add sightings against teammates.
- No extra displayed question charge or additional random roll for this person-specific append.

### Opinion and attitude thresholds

Source: `answer_opinion`, `greeting_cue`, `end_conversation`.

| Situation | Full sequence |
| --- | --- |
| Private opinion | S<.25 trust; .25–<.45 uncertain/all-right branch; .45–<.8 doubts; ≥.8 strongly accuses |
| Uncertain/all-right branch | "Something off" probability .6−.4I+H; shown level becomes .5, allowing opinion card |
| Opinion card | Generated when shown level≥.5 |
| Gossip refusal | G<.2 and R<.5, before opinion calculation |
| Greeting attitude shown | Probability .9(1−K) |
| Greeting trust language | T<.3 wary; .3–<.5 guarded; .5–<.7 civil; ≥.7 brightens |
| End-conversation second trait reveal | Probability .6(1−K); first available trait is attempted unconditionally |
| Post-meeting trait reveal | Probability .35(1−K) per living NPC |
| Mention closeness | B>.7, with dialogue voice qualifications; not an alignment guarantee |

## 7. Public disclosure and meeting defence

Sources: [mind.gd](sim/mind.gd) `_public_claim_decision`, `reveal_cost`, `_accuse_tier`, `answer_hint`, `defend_self`; [content.gd](sim/content.gd).

### Spontaneous public role claim

Sigmoid score starts with:

`1.2(.5−P) + .3(day−1) + .8R(1−.5K) − .35`

Then add:

| Condition | Score change |
| --- | --- |
| Role kind is not info | −.50 |
| Recurring role (Seer/Hearthwitch/Night Watch/Lamplighter/Medium/Psychologist/Dowser), day≤2 | −.40 |
| Otherwise a START_ROLE | +.30 |
| Otherwise actual good Martyr with chosen target | +.40 |
| Living NPCs≤4 | +.80 |

This public roll does not directly use player trust. It is run for each unsilenced NPC during meeting testimony. Already-public NPCs share their new readings without rerolling willingness. Going public makes role tier at least 3 and shares all non-disowned, unshared readings at direct .5 hearing weight.

### Cost of revealing a hidden gift for another purpose

`reveal_cost` returns no costs for an already-public claimant. Otherwise sum:

| Part | Cost |
| --- | --- |
| Base | +.20 |
| Privacy | +.8(P−.5) |
| Non-info role | +.50 |
| Listed recurring role, day≤2 | +.40 |
| Fear flag | +.35 |
| Day | −.12(day−1) |
| Living NPCs≤4 | −.60 |

These are costs, so callers normally subtract them. The sum can be negative late; it is not clamped.

### Public accusation and what they reveal

1. Silence blocks accusation.
2. Good: choose highest-suspicion living other NPC. Evil: use living scapegoat, from day 2, treating suspicion as .8.
3. Accusation sigmoid score = 1.5(S−.6)+.8(C−.5)+.4R.
4. If own/private reason:
   - Already public/no special reason: generic.
   - Heard another person's private reading: anonymous relay.
   - Own protected reading: reveal-versus-hint sigmoid score = 1.4(reading strength−.45)+1.2(S−.75)+.6(C−.5)−reveal_cost.
5. Evil can give a free private-reason hint when it has a reading bluff, no citable reason, and either a ready fake reading or a 30% roll succeeds.
6. Citable reason can still be omitted with probability .5(1−I), for either alignment.
7. Consensus and pressure then apply (section 3).

Reading strength for this decision: Seer yes .9 (no 0); Martyr evil result .9 (otherwise 0); Dowser/Hearthwitch clamp(.9×count/group size,0,.8) for a group member; Archivist Demon .6, evil minion .4, good role .15; Night Watch .35; Medium .5; fallback .3. These are reveal-decision scores, not the reading's suspicion effects.

### Nominator's supporting case

Source: `case_against`, `nomination_case`.

- Consider positive ledger contributions ≥.03 with a public reason string; sort by contribution and keep at most 3.
- Recap at most 2 public reasons. Recap is cosmetic: the already-known evidence is not applied again.
- If no private reason but a relay exists, relay the strongest available one.
- For private evidence, use reveal-to-accuse formula above **plus .20 nominating score**; success goes public, failure leaves a hint.
- Unknown reason strength defaults .30; own-role wording kept private has strength at least .50.

### Player follows up a hint

- Must have a current living hinted target and an actual protected reason, unless role is already public.
- Sigmoid score = 2(T−.45)+.8(.5−P)−.3 if afraid.
- Success calls answer_gift with forced tier 4.
- If role is not public, returned claims/readings are marked confidential.
- Failure uses one of two refusal phrasings, 50/50. Stalling itself is not a tell of evil.
- An anonymous relay gives reading weight .15; the hidden source steps forward with 5% chance if alive, unsilenced, and still private.

### Nominee's self-defence: full sequence

Silenced: no speech or effects. Otherwise use nominator's evidence (or most suspicious living good NPC if player nominated). `out_weight` is the summed contribution of case items whose reason includes "out" or "night".

1. Walking gift and movement evidence:
   - Already public: explain.
   - Otherwise sigmoid score=1.1 (DEFENCE_ROPE)+.2−reveal_cost.
   - If successful, reveal and reduce raw suspicion by min(.35,out_weight).
2. If no successful move, movement evidence, good NPC with personal secret:
   - Confession sigmoid score=.5+(.4−P)=.9−P.
   - Success reduces raw suspicion by min(.30,out_weight).
3. If fewer than 2 moves, find a reading naming them:
   - Seer has publicly pinged them at least twice: claim red herring, S−.12.
   - Else pair of two including them with living other person: self−.06, other+.06.
   - If still fewer than 2 moves and no red-herring move: C>.6 says source lied (self−.05, source+.02); otherwise says misled (self−.06).
4. No move: fear/desperation plea, S−.02.

Each defence entry weight = .5+.5B(listener,defender), with live source reliability and F on suspicion effects. Separate move identities are per defender/day/move, so repeating the same move that day does not stack.

Legacy one-line defence (when DEFENCE_MOVES=false) selects confident wording at C>.66, nervous wording at C<.34, otherwise neutral; those lines alone are not numeric evidence.

## 8. Nomination and voting: complete decision paths

### Good nomination

Source: [mind.gd](sim/mind.gd) `_good_nomination`, `next_nomination`.

Threshold:

`nom_need = max(.45,.86−.08day) − .30(C−.5) − .5H`

| Day | 1 | 2 | 3 | 4 | 5 | 6 onward |
| --- | --- | --- | --- | --- | --- | --- |
| Base before confidence/panic | .78 | .70 | .62 | .54 | .46 | .45 |

Sequence:

1. Living, unsilenced NPCs who have not nominated today are eligible.
2. Scan other living NPCs in descending suspicion.
3. Skip people already nominated today.
4. Subtract .20 from candidate score if cleared by nominator's own Seer no.
5. Must meet nom_need.
6. If someone is already on block and their suspicion is ≥candidate's adjusted score, stop: content with block.
7. Each nominator offers its first qualifying candidate; across nominators choose largest candidate score.
8. Open nomination adds target pressure .40 and interpersonal penalties from section 2.

### Individual good vote

Source: `vote`. This is deterministic after belief reconsideration; it is not a percentage roll.

Self always votes no. For another nominee, start with S(voter,nominee), then:

| Modifier | Value |
| --- | --- |
| Player declared yes | +.25T−.05; negative below T=.2 |
| Player statement defends | −.25T |
| Player statement accuses | +.20T |
| Relationship to nominee | −.6(B−.5), range +.3 to −.3 |
| NPC nominator is suspected at S>.7 | −.15 |
| Persuaded to spare | −.5×spare preference |
| Another person already on block, with S(block)≥base S(nominee) | −.40 |
| Working Martyr chose nominee | Subtract max(0,.6−.4H−.3R−.4×max(0,base S−.8)) |

Need:

`vote_need = .5 − .24(C−.5) + (.1 if day≤1 else 0) − .4H`

Vote yes when score≥need. At C=.5 and H=0, need=.60 on day 1, then .50. At C=0/1, later need=.62/.38 before panic.

At T=.4, player yes adds .05 and accusing adds .08: combined .13. The −.40 existing-block preference is over three times larger. This can be resistance to replacing an execution, even when the NPC believes some of the case.

### Meeting-wide legality and tally

Source: [world.gd](sim/world.gd) `can_nominate`, `vote_order`, `vote_pending`.

- One nomination per nominator per day; each NPC can be nominated once per day.
- Voters = living NPC count + player. Current code does not include dead ghost votes.
- Minimum tally=ceil(voters/2).
- Votes are evaluated clockwise from seat after nominee; nominee last.
- Player yes/no is known in advance by AI, although tally animation counts their seat.
- If below minimum, nomination fails.
- If at least minimum and strictly above block_count: replace block and save count.
- If equal to block_count: clear block (tie).
- If lower than block_count: short of block.
- Clemency cancels pending nomination and consumes its tool. The nomination/nominator slots already spent remain spent.
- One whole-meeting deduction presentation per day; one nomination statement per pending vote.
- Nomination statement can independently change nominee/nominator trust, update evidence, and add the vote's statement modifier.

## 9. NPC information flow and social percentages

Source: [social.gd](sim/social.gd); [world.gd](sim/world.gd) pairing; [game.gd](game/game.gd) haunt sharing.

### Seeking conversation partners

- Pair weight=clamp(2(mean mutual B−.3)+news bonus+Psychologist nudge,.02,2).
- News bonus, checked each direction: +.60 if evil has new intel and partner evil; +.50 if good has news and trusts partner at B>.60.
- Actual good Psychologist present: +.50 nudge.
- Either silenced: pair weight .02; conversation delivery itself is blocked.
- Each NPC pairs at most once/day and must be idle/non-working.
- Before player action: maximum 1 pair for <10 NPCs, otherwise integer NPC_count/5; each iteration requires 65% roll and leaves at least 3 player conversation options.
- After player action: for each co-located idle group, weighted pair selected, then chance .40×pair weight.
- Candidate pairs are selected proportionally to their weights, not always the highest weight.

### What one NPC tells another

Each speaker chooses one item. Selection weight is relative; total also includes **.30 weather/no-news weight**. Negative candidate weights are treated as zero. Already told items are excluded.

| Candidate | Selection weight / gate |
| --- | --- |
| Unshared own reading, good or fake evil | 1.2(1−P)×2max(0,B(sender,receiver)−.3)+.3R |
| Good confides own personal secret | (1−P)×3max(0,B−.6) |
| Good opinion about top suspect | .6G+.4(C−.5); requires S≥.5 |
| Evil opinion about scapegoat | Same weight; public heat≥.3 |
| Player case, last 2 remembered | .5G |
| Night sighting within previous 2 days | .8G; +.40 if murder block/night |
| Evil fake scapegoat sighting | .8G, subject to fake-sighting availability |
| Hearsay, last 4 items | .45G; excludes source/subject back to recipient and secrets |
| Relay another person's known secret | .4G(1.3−K) |

Delivery uses hearing weights in section 3 and adds +.02 relationship trust in the teller on the good-receiver path, regardless of whether testimony was true.

### Approaching the player

Full sequence:

1. 40% phase-level opportunity.
2. Require living, available, not working, not silenced.
3. New private reading, T≥.5: agenda score=(1−P)+T−.6. Same formula for evil frame.
4. G≥.6 with gossip: candidate score=G−.3; use if above news/frame score.
5. Add U(0,.2) per candidate; choose largest score.
6. Require best score≥.35.
7. Accepted news/frame approach forces disclosure tier 4. It cancels its added question count afterward, but any fatigue already charged inside answer_gift has occurred.

### Gossip and auxiliary percentages

| Check | Probability / sequence |
| --- | --- |
| Gossip secret to player | .50+.30G, 50–80%; then fallback to available hearsay |
| Crowded-tavern evil intel exchange | Tavern≥4 occupants, free evil partners with unshared intel, 50% |
| Tavern speaker | Weighted random by .10+G |
| Tavern evil fake rumor | 60% if living scapegoat |
| Tavern true night sighting | G≥.2 and not told, within last 2 days |
| Tavern suspicion instead | Top S≥.4, not shared for target/day |
| Haunt sharing after applicable player question | p=clamp(.15+.55G+.5(T−.5),0,.9) |
| Haunt detail count | Same roll<p×.4 shares all unknown haunts; p×.4≤roll<p shares one; otherwise none |
| Private observation omission for trusted person | B>.7, 60% |
| Reason omitted / kept vague | .5(1−I), shared rule for good and evil |

The haunt rule does not roll separately for "all": conditional on sharing, 40% gives all unknown haunts.

### Suspicion-driven role target choices

- Seer night 0 or fewer than 3 other living NPCs: two random.
- Otherwise targeted strategy with probability .30+.50I; failure chooses two random.
- If I≥.6, top suspect has at least two yes readings, and at least two unchecked people remain: two fresh people.
- Otherwise top suspect plus another; at I≥.6 prefer unchecked partner if any.
- Night Watch first night/no suspect: random block; afterward top suspect's home block.
- Warden maximizes U(0,.3) + (1−S if public info claimant) + .8(B−.5) − .5S + 1.2×protect preference; never self.
- Martyr maximizes B−.5S+.5×protect preference; must reach .62; selects once.
- Psychologist reading of evil: 75% chance to report a teammate as most trusted when one exists; suspicion tends to scapegoat. This is information generation, not a guarantee of an evil pair.

## 10. Evil cover, team strategy, and fabricated testimony

Sources: [evil.gd](sim/evil.gd); [mind.gd](sim/mind.gd) `evil_override`, evil nomination/vote/private responses; [argue.gd](sim/argue.gd) evil mask.

### Cover override

With SHADOW_SELF=true, evil often starts from its separate good self's answer. Choose strategic evil action instead when:

`stakes − deviation × exposure > caution`

Strict comparison; deterministic.

Exposure sums:

| Component | Amount |
| --- | --- |
| Public talk about this evil NPC | Sum event heat ×.75^age, clamp 0–1; includes evil's own public events |
| Known player suspicion of self | +.30 |
| Pressure | +.50R, rounded .01 |
| On block or already nominated today | +.20 |

Caution:

- Demon: max(.45,.80−.03(day−1)).
- Minion: max(.25,.70−.08×max(0,day−2)).
- Minion sequence days 1/2=.70; 3=.62; 4=.54; 5=.46; 6=.38; 7=.30; 8 onward=.25.
- Teammate value: Demon 2, other teammate 1.
- Shadow own-reading weight 1.2; ordinary own reading 1.0.
- High exposure makes breaking cover more costly, so can make evil follow its shadow more often. The tested local fix adds an unconditional Demon-protection guard specifically for nomination/voting.

Override stakes/deviation:

| Choice | Stakes | Deviation |
| --- | --- | --- |
| Shadow would nominate teammate | .8×teammate value | 1 |
| Strategy wants scapegoat but shadow would not nominate | .4+public heat(scapegoat) | .5 |
| Vote protects teammate | teammate value×pivot, unless strategic vote itself is yes, then .6 | .6 |
| Vote strategically yes on good nominee | (.5 + .3 if scapegoat)×pivot | .6 |
| Other vote disagreement | .3 | .6 |
| Opinion protects teammate | teammate value×(.3+heat) | .5 |
| Raw private case against teammate | teammate value×(.3+heat) | .5 |
| Private group case | Sum .5×teammate value×(.3+heat) for implicated teammates | .5 |
| Private defence of good person | Sum .3, plus .3 per known threat | .5 |
| Structured argument accusing teammate | teammate value×(.3+heat) | Difference in stance rank /2 |
| Structured argument defending teammate | .4×teammate value | Same |
| Structured accusation of good person | .25, +.35 if scapegoat | Same |
| Structured defence of good person | .3, +.2 if known threat | Same |
| Structured argument without target | .2 | Same |

Vote pivot=1 when |already_yes + player_yes + 1 − tally threshold|≤1, otherwise .35. This only sees votes already cast, not estimates of later voters. Stance ranks reject=0, partial=1, accept=2.

Opinion cover: teammate level .2 unless shadow distrusts them at ≥.45 and override is not worth it; scapegoat level .85; others shadow suspicion (or public heat fallback).

### Public heat and scapegoat momentum

Public heat starts .15, adds event contributions ×.75^elapsed days, excludes evil-authored events, and clamps 0–1.

| Event | Heat |
| --- | --- |
| Accusation | +.12 |
| Nomination | +.20 |
| Reading | +.40×published target strength; +.20 fallback |
| Yes vote | +.04 |
| Clear | −.12 |

Initial scapegoat maximizes U(0,1)+1 if demon knows them as a walker+.5 if demon's relationship trust<.4+.2 if public Warden/Veteran.

From day 2, reconsider among living good NPCs:

- Momentum=public heat+.5×mean shadow suspicion across living evil members with shadows.
- Fit=.25 per shared fake reading naming candidate+.15 per walker-intel item, capped .60.
- Clears subtract .30×.75^age per public clear event.
- Current scapegoat retention bonus=.25+.15×number of evil public accusations ever made against them.
- Choose maximum total; no random roll in this review.

Thus town suspicion can steer evil into reinforcing an existing wrong lead. Evil's own events do not directly inflate public_heat, but shadow belief and retention provide other reinforcing paths.

### Strategic nomination and vote sequence before shadow override

- Evil scapegoat nomination: from day 2; scapegoat living/not already nominated/not already block; do not replace a good NPC already on block.
- Nominate if heat≥.45−.15C; candidate score=heat+.20.
- Self vote is always no in Mind.vote before evil strategy.
- Strategic evil vote branches, in order:
  1. Evil Revenant with hidden totem: 55% yes; on failed roll proceed to later branches.
  2. Teammate: normally no. Demon on block can vote for minion to create clearing tie with chance .40+.50C; also joins a minion execution already passing without it.
  3. Another teammate on block: yes on good replacement.
  4. Scapegoat: yes.
  5. yes_so_far≥threshold−2: yes on good nominee.
  6. Otherwise yes chance .35+.20C (35–55%).
- Then compare with shadow vote via override rule. The local playtest fix blocks any evil yes/nomination against its Demon before following cover behavior.

### Mask percentages and bluffs

| Behavior | Check |
| --- | --- |
| Cached fake night sighting | 50% once per NPC/night if living scapegoat and night≥1; cache failure too |
| Fake window sighting detail | If scapegoat lives on claimed block, 50% "leaving home"; otherwise street |
| Fake tavern rumor | 60% |
| Evil free hint | 30% when eligible and no ready fake/citable grounds |
| Raw defence phrase | About evil: 60% "fair enough"; about good: 70% tentative; otherwise alternative wording |
| Raw group-case phrase | 60% tentative, otherwise favorable |
| Raw accusation protecting evil | If speech card, 50% "only talk"; otherwise tentative |
| Raw accusation framing good | Relevance≥.9 and roll<.35: strongest agreement; otherwise roll<.7 favorable, otherwise tentative |
| Structured conflict involving self | 50/50 special partial replies |
| Structured self-misled | 50/50 special partial replies |
| Structured favorable mask | Serves≥.7 and new: 65% accept; if prior same conclusion with other facts, accept as already |
| Structured unfavorable mask | Serves≤.2: 40% reject, otherwise partial |
| Other structured mask | Partial |

"Serves" mask scores: default .5; conflict containing evil .15, only good .75; accusing evil .1 / defending evil .9; accusing good .85 / defending good .3. Self-accusation rejects. These mask scores select policy branches, not probabilities by themselves. Shadow can replace the resulting stance.

### Fake reading generation

- Fake Seer: frame living scapegoat with yes on night 0, odd days, or when living NPCs≤5, if partner available. Otherwise 40% chance to clear teammate when eligible; else harmless no on two others. Never intentionally clears scapegoat.
- Fake Hearthwitch: scapegoat neighbor → count 1. Otherwise eligible good neighbor, day≥1: 30% count 1, else 0.
- Fake Rumormonger: teammate plus good person; secret type uniform across four modifiers, including Lovers/Marked. This supplies cover; it is not evidence from hidden truth.
- Fake Clerk: teammate plus good person and teammate's bluff role.
- Fake Archivist: scapegoat plus another good, names an actual minion role from setup.
- Fake Gravedigger: executed teammate gets its bluff; good executed gets claimed good role if available, otherwise random good role.
- Fake Night Watch: scapegoat's block; include known walkers there, append scapegoat from night 1 if absent; cache watched block.
- Fake Lamplighter: actual walker count + uniform choice −1/0/+1, clamp to plausible bounds.
- Fake Surveyor: one uniform roll: <.60 attempts plausible wrong count; .60–<.85 truth; ≥.85 too-high count if team occupies fewer than four possible blocks, otherwise truth. If no alternate plausible count exists, first branch also retains truth.
- Fake Psychologist: random available person actually talked to; reports scapegoat as most suspected and another random person most trusted.
- Fake Martyr: once after night 0; claims to choose teammate, or good person if alone.

Fake Medium full menu:

1. 15% empty-report branch: 50% random good person on own block if available, otherwise dead person home.
2. Otherwise framing is allowed on first frame, then on 50% roll.
3. Weighted menu: compatible unshared fake reading in dead person's public role 3.0; frame sighting at dead home 1.5; nothing-new if public reading existed .8; repeat dead's public suspicion of living good .8; home fallback .4.
4. Fake dead Seer / Dowser can clear publicly implicated living Demon on 50% roll.
5. Otherwise fake dead Seer continues prior public yes on good person with 50% chance when available, else scapegoat.
6. Fake dead Psychologist reports scapegoat as most suspected with 60%, otherwise alternate.
7. No fake Breathstealer result through dead Archivist/Gravedigger unless living Breathstealer exists. Source role/night already publicly read is excluded.

## 11. Additional event and tactical values

### Public events and observation generation

Source: [world.gd](sim/world.gd) `begin_meeting`, `_quiet_night`, `_martyr_dies`, `_revenant_curse`, `free_turned`, `_night_sightings`, `_kill`.

| Event / check | Value |
| --- | --- |
| Breathstealer silence becomes public | Raw S−.12 in other living good NPCs, ledger weight 1, F applies |
| Quiet night, public living Warden claimant | Raw S−.15, ledger weight 1, F and source honesty |
| Quiet night, public living Veteran claimant | Raw S−.06, same weighting |
| Martyr demonstrably dies in good target's place | Raw S−2 for both, ledger weight 1, F; mark cleared |
| Revenant curse fires | Raw S+.15 against other living yes-voters, ledger weight 1, F |
| Curse lifted, freed NPC's suspicions | Each other suspicion set to min(current,.25), then own-role claim weight 1.5 |
| Night walker seen by another out on its route | 50% |
| Night walker seen from home window on route | 15% |
| Same-block home observer notices someone stayed in | 20% |
| Player vigil | Collects living walkers whose paths cross block; no additional sighting roll |
| Misleading death-scene trace | If another eligible passer exists, 40% choose passer; trace actually differs only if passer's evening block differs from Demon's |
| Sleepwalker movement | 50% per night if not already out; unaware of movement |
| Personal-secret movement | 55% per night if not already out; Lovers use their paired meeting rule instead |
| Night drop | Demon 35%; other walker 15%; on success 12% personal item, otherwise home-block material |
| Ordinary flavor secrets | Disabled (USE_FLAVOR_SECRETS=false); dormant extra-secret assignment uses 50% branches |

The observed trace refers to an **evening block**, not inherently home block. Murder-block sighting refers to the **night**. They support different inferences.

### Kill, poison, and silencing target scores

Source: [evil.gd](sim/evil.gd) `_public_threat`, `choose_kill_target`, `choose_poison_target`, `breath_target`, `note_kill_result`.

These influence who survives to give information and thus the social game.

Shared threat: public info claimant +3; Seer +1 more; shared reading implicates evil +2 (once as a named score part). First-night info claimant's kill value drops to +1 after setup night. Known-intel threat sums to cap 3. Public hostility: each action against evil +1, yes vote +.5, total cap 2.5; clears ignored.

| Kill score part | Value |
| --- | --- |
| Public hostility | ×.8 |
| Known threat | +intel threat |
| Only living resident on block | +.7 |
| Vengeful mood, demon's B(target)<.4 | +1.5 |
| Cunning mood, scapegoat's home block | +1.5 |
| Hungry mood | U(0,2) |
| Preserve scapegoat while living NPCs>4 | −4 |
| Veteran spent after known failed attack | +.3 |
| Veteran with living Poisoner | +.6 |
| Veteran first attack, no Poisoner | −2 |
| Other previous failures | −10 per failure |
| Spared by Clemency and living NPCs>4 | −1.5 |
| Warden claimed, target public info claimant | −.8 |
| Caution after unexplained failed kills | −caution×min(public profile,4)×.7 if caution>.05 |
| General noise | U(0,.8) |
| Unpredictable choice | 3% when >3 candidates: choose random outside top 3 with score>−5 |

Unexplained failed attack adds caution +1 up to 1.5; halves after each target choice. Visible player ward causes no caution/failure-list update through this handler. A witnessed Warden at failed target door generates +2 known threat. Veteran+Poisoner combo overrides poison selection if eligible.

Poison: shared public threat +.6×public hostility +known threat −3.5 if gift spent +U(0,1.5). Poisoning known/suspected Warden to permit tonight's attack adds +2.5 if kill target is public info claimant, otherwise +1.2. Normally exclude kill target, except explicit Veteran combo.

Gift-live gates: unknown claim assumed live; first-night roles only on night 0; Gravedigger only after execution; Veteran not without attack combo; Martyr from day 1; Sexton false for night poisoning because its decision already happened.

Breathstealer: candidates are good, co-located on same block, not previous target and not already silenced/pending. Maximize shared public threat +public hostility +known threat +U(0,1). If best score>1: use chance morning 30%, afternoon 50%, evening 100%; otherwise 15%, 30%, 70%.

Revenant hides totem with chance morning 45%, afternoon 60%, evening 100%.

### Relevant switches

| Constant | Audited value |
| --- | --- |
| ALLOW_NO_GIFT_DENIAL | false; if enabled tier-1 lie/refuse sigmoid score=1.5(C−.5)−.1 |
| SHADOW_SELF | true |
| SHADOW_OWN_READING_WEIGHT | 1.2 |
| EVIL_HINT_CHANCE | .3 |
| MEDIUM_USELESS_CHANCE | .15 |
| INFO_BEFORE_KILL | true; victims retain final night's reading |
| RELAY_WEIGHT | .3 |
| RELAY_CORROBORATE | .05 |
| DEFENCE_MOVES | true |
| DEFENCE_ROPE | 1.1 |
| DEFENCE_LIE_BLOWBACK | .02 |
| EVIL_CAUTION_DEMON | .8 |
| EVIL_CAUTION_MINION | .7 |
| MINION_ID_DRIFT | .08 |
| MINION_CAUTION_FLOOR | .25 |
| USE_FLAVOR_SECRETS | false |
| HONESTY_K / HONESTY_CAP | .8 / .5 |
| CONSENSUS_BASE / FADE / CAP / HINT | .12 / .6 / .3 / 1.15 |

Trait labels: low<.34; mid=.34–<.67; high≥.67. These labels summarize continuous values; thresholds elsewhere may differ.

Case duration is 6 days for fewer than 10 NPCs, 8 days for 10 or more. Exceeding max_days ends the case for evil. This is an external action deadline, independent of NPC belief or trust.

## 12. Feedback loops and tuning risks

These are code-based findings and design judgments, not new parameter changes. Severity refers to likely loss of player agency or recoverability, not whether an NPC reaches the objectively correct answer.

| Mechanism | Why it can reinforce itself | Existing brake | Assessment / possible direction |
| --- | --- | --- | --- |
| Permanent grief trust cap | A friend is executed → player loses trust/cap → later arguments carry less weight → correcting town becomes harder | Only good mourners with B≥.62; Demon execution exempt | **High.** Even a minion can trigger it. Consider evidence-based rehabilitation or a temporary cap; use what NPC accepts publicly, not hidden alignment |
| High privacy starts behind | High P lowers initial T and disclosure, increases pressing/fatigue costs, reduces civil-conversation reward | Day/pressure/public urgency can eventually reveal information | **High.** Same personality trait is charged at several stages; balance total journey, not each penalty alone |
| Pressing to unlock information | Press → pressure rises but T falls; fatigue can add another loss, reducing openness | Pressure helps disclosure; nomination/late days can unlock it | **High.** With strength=.6, P=K=.8, openness changes by −.018 before fatigue: .6×(.35×.6)×.6−1.2×.078. Pressing can make later private disclosure less likely |
| Wrong role-guess spiral | Wrong guesses persist; five cost .02+.04+.06+.08+.10=.30 before fatigue → correct guess harder to disclose | Correct guesses don't incur wrong-guess penalty | **Medium/high.** Anti-enumeration is useful, but recovery/cost ceiling merits review |
| Agreement rewards | Accusing someone already S≥.5 rewards player trust even if card weak → player has more influence when echoing belief | New-card requirement and ledger deduplication | **High.** Supports manipulation and rapport, but can reward parroting a false theory more than correcting it |
| Suspicion informs interpretation | Existing S raises accusing explanation weight and lowers innocent-alternative weight → accepted accusation raises S | Caps, contradictory evidence, source discounting | **High.** Intended bias, but can make a tentative early lead sticky. Preserve misleading gameplay while checking whether fresh strong evidence can overturn it |
| Incompatible credibility formulas | Raw hearing has honesty floor .5; structured support credibility falls as .9−S down to .1 | Ledger honesty ignores vibes and recalculates | **High.** An NPC can dismiss support because of prejudice while still crediting a proven liar's direct reading. Harmonize semantics before raising suspicion globally |
| Strongest justification plateau | Three independent nights supporting same conclusion can stay at strongest single justification → existing leader retains advantage | Prevents repetition/rewrapping from manufacturing proof | **High for the reviewed playtests.** Add diminishing independent support while retaining deduplication; do not let card count stand in for independence |
| Existing-block inertia | First executable nominee gives later candidates −.4 and can prevent nomination outright | Later score/vote can still surpass it; ties can clear block | **High.** This is execution preference, not disbelief. Expose that distinction to player before tuning every belief weight upward |
| Friendly information circles | Friends pair/share more → teller gains +.02 relationship trust per item → friends become more persuasive and harder to accuse | Once/day pairing, per-recipient told tracking, ledger deduplication | **Medium.** Realistic clique behavior, but false as well as true sharing earns relationship trust |
| Secret-keeping accumulation | One confession gives .03–.07 T per night without further interaction → more disclosure/influence | Stops after player spreads it; NPC gossip reduces reward ×.4; trust cap | **Medium.** Strong passive compounding compared with +.02–.04 civil conversation |
| Death/panic escalation | Death raises baseline suspicion and lowers nomination/vote thresholds; executions can increase panic further | Composure dampens; consensus fades | **Medium, likely desirable fiction.** Track wrongful executions separately from final win rate |
| Fear rises alongside urgency | Demon deaths increase fear while making action easier; frightened NPCs withhold reasons | Day and few-left bonuses reduce public reveal cost | **Medium.** Can produce action without explanation; offer protection currently helps through T, not by directly reducing fear |
| Evil rides mistaken town momentum | Public heat/shadow suspicion select scapegoat; fake evidence reinforces that lead | Public clear penalties; fit cap; heat excludes evil events | **Intentional, useful.** Preserve it so player's accidental or deliberate misdirection can matter |
| Exposure makes cover expensive to break | More exposed evil member follows good shadow even when strategically dangerous | Tested local Demon-protection guards | **High for Demon survival.** General Scion sacrifice/minion bussing needs team utility, not just already-cast vote pivot |
| Suspicion clamps lose overage | Ledger remembers full effect, S clamps at 0/1.5, later negative difference may overshoot what an unconstrained total would imply | All scores bounded | **Numerical concern.** Check whether adding then retracting evidence returns expected S near saturation; don't assume incremental clamp is fully reversible |
| Different conclusion IDs stack | evil/demon/evil-role/lied are distinct ledger entries despite overlapping facts | Novelty reduces reused facts to .35 | **Medium.** Prevent synonymous conclusions from multiplying the same case without removing legitimate lie+movement combinations |
| Nominee defence reduces scrutiny through testimony | A trusted speaker gets stronger defence and can lower S enough to preserve credibility | Small defence magnitudes, source honesty | **Watch.** Healthy if it enables plausible lies; risky if benign alternatives repeatedly outweigh independent positive evidence |

### What to tune first

1. Make voting resistance explain whether it is disbelief, distrust, or preference for another execution.
2. Audit permanent trust caps and penalties that later accepted evidence cannot repair.
3. Align raw-card and structured-case treatment of the same evidence.
4. Accumulate genuinely independent support with diminishing returns; keep repeated fact IDs deduplicated.
5. Revisit hard gossip and fatigue boundaries after the above, using personality-specific outcomes.
6. Separate belief strength from action priority. A player-led execution can be worthwhile for information even with uncertainty; acceptance need not mean certainty.

Keep NPC knowledge local. Do not solve a hidden global world and then use it to rescue the town from the player's mistaken case. Use public claims, accepted evidence, personal experience, personality, and player trust. An intentional Gravedigger execution should be discussable as an action goal, rather than forcing NPCs to falsely believe the target is Demon.

### An illustrative Nisha-style disclosure profile

This is a formula illustration, not a reconstructed timeline. At P=.60, T=.38, day 1, pressure 0, openness is .136+U(−.2,+.2): about 53.5% tier 1 and 46.5% tier 2, with no tier 3/4 outcome. With G=.11, sharing other people's sightings is independently blocked until pressure reaches .50, regardless of a modest trust increase. Civil conversation at P=.60 adds .028 once/day, increasing later openness by only .0336. Public disclosure has its own day/pressure roll and may occur even while private information sharing remains limited.

This explains why "build a little trust" and "get information" are not a single smooth progression.

## 13. Playtest-fix changes pending alongside this audit

The following describe tested local commit `402ac63`, not the baseline tables above:

- Explicit support for the listener's own claim/defensive deduction is routed as defence. If defence strength≥.2, T+.03 once per underlying fact. Repeating same support does not farm trust.
- Defensive deduction strength: for target's supported good/notdemon/truthful/spare/protect/secret/marked/red_herring conclusions .3; good-role conclusion .2; unfounded deductions do not get this branch.
- Spoken daytime whereabouts and publicly cited sightings produce attributed cards. This increases available usable evidence, not its certainty.
- Lovers/personal-secret confessions can be linked to movement as a possible explanation; future reported Marked cards can explain eligible evil readings. No automatic Marked self-disclosure was added.
- A withheld Night Watch reading cannot be obtained by switching to whereabouts/person-specific follow-up.
- Evil cannot nominate or vote to execute its Demon merely to follow its shadow. Deliberate Scion succession is deferred.
- Warden bluff targets can include teammates, removing a metagame guarantee.
- Own-role knowledge rejects explanations requiring another role; ordinary self-sightings can match route, not only destination.

The fixes were previously tested with seven Godot suites, including 24 playtest-specific regression checks. Those tests were not rerun during this documentation-only audit. Rendered visual verification was still outstanding.

## 14. How to reconstruct exact trust journeys

Source log schema: [devlog.gd](sim/devlog.gd); [world.gd](sim/world.gd) `_log_grimoire`, `snapshot`.

For each case:

1. Read initial trust/traits from the grimoire event, keeping NPC id, role, alignment and relevant relationships.
2. Sort by seq. Extract type=trust with actor=NPC and target=player, retaining data.from/to/cap and reason.
3. Extract trust_cap events separately; a cap can change without immediately changing T.
4. Join adjacent player commands/statements, nominations, offers, disclosure decisions, grief, Gravedigger readings, and day transitions. One action may trigger several rows.
5. Reconcile against snapshots. Logged values are rounded, and changes below .01 may not be individual trust events; don't force a false exact sum from rounded deltas.
6. Keep actual evil NPC and its good-shadow trust separate. Shadow snapshots are not interchangeable with the NPC's visible behavior or real evil intent.
7. Report start→low/high→end, largest gains/losses, cap changes, and **threshold crossings**: disclosure tiers, T=.5 approach eligibility, meaningful reweight triggers, vote modifiers.
8. Compare a high-privacy NPC, an initially friendly/cooperative NPC, and someone affected by nomination/grief. For these cases, Lian/Fenwick/Jory in 61251 and Nisha/Isolde/Merrin in 25923 are useful candidate subjects, subject to actual event coverage.

An NPC refusing to vote yes is not proof their T fell. Check the vote's score parts, especially existing block, relationship bond, spare preference, and nominee suspicion. Likewise, refusal to gossip is not proof of low T.

## 15. Maintenance checklist

When changing tuning:

- Update the function's entry here and state whether a change affects score, probability, raw effect, or final weight.
- Keep strict > versus ≥ boundaries intact in tests that cover a real edge.
- Compare player-led outcomes and recovery from mistaken theories, not only NPC accuracy.
- Check known information versus hidden ground truth, particularly secrets, fake readings, and shadow minds.
- For future log analysis retain this audit's source revision; playtest binaries may predate some current-main behavior.

## 16. Clarification supplement and executed ledger example

Checked against revision `1998c6615547aaac224ce1f7a240239ca026d55e` on October 20, 2026. Sources: `Mind.on_question`, `_afraid`, `_target_tier`, `press`, `card_strength`, `ledger_hear`, `recompute_beliefs`; `World.resolve_night`, `_walk`, `_maybe_drop`; `Game._talk_command`, `_search`, `file_deduction`, `_present_deduction`; `Argue._expl_weight`, `_quality`, `_support_strength`, `evaluate`, `_apply`.

### Clarifications

- **Fatigue:** all `on_question` calls count, including different topics. After the first three calls per NPC/day, every subsequent call loses trust. Conversation slots and their one-repeat exemption are separate; a free visible repeat can already have charged daily fatigue. Night resolution resets `pressed_today`; reopening a conversation does not. Lifetime wrong-role guesses are separate and persist. Delegated answers can call the counter more than once; free protection offers do not use it.
- **Daytime sighting 0.15:** raw incriminating card strength, not final suspicion or a probability. A fresh private raw accusation using a concrete player observation, T=C=B=.5 and full reliability, adds `.35 × .15 = .0525` suspicion, assuming no concurrent fatigue-induced trust change. Creating the player's board card does not automatically apply that to every NPC.
- **Fear:** `_afraid` uses demon deaths, Composure and the NPC-ID/day hash; it does not use actual or claimed role, gift value, spent state, trust, or evil threat score. Separate public reveal costs do depend on role categories. Equal-Composure Seer and Clerk therefore have equal fear thresholds, even if their individual fixed outcomes differ.
- **Dropped items:** choose a block on the walker's current `night_path`, then a static `C.LOCATIONS` place on that block. Search tavern/well, smithy/bakery, wharf/mill, or chapel/graveyard. No block-search command or home intrusion is needed. Found personal items become attributed night-sighting cards; ordinary material becomes a dropped-material card. The Lamplighter expands its path after `_walk` calls `_maybe_drop`, so its drop selection currently uses its home block only.

For a good NPC, a relevant non-Clerk deduction press has strength .6 and adds R=.21. Before fatigue or clamping, its deterministic openness change is:

`Δopenness = .126(1−.5K) − 1.2(.03+.06P)`.

| Privacy | K=.2 | K=.5 | K=.8 |
| --- | --- | --- | --- |
| .2 | +.0630 | +.0441 | +.0252 |
| .5 | +.0414 | +.0225 | +.0036 |
| .8 | +.0198 | +.0009 | −.0180 |

If the delegated answer also incurs one daily fatigue penalty, subtract `1.2(.03+.05P)(1−.5K)`:

| Privacy | K=.2 | K=.5 | K=.8 |
| --- | --- | --- | --- |
| .2 | +.0198 | +.0081 | −.0036 |
| .5 | −.0180 | −.0270 | −.0360 |
| .8 | −.0558 | −.0621 | −.0684 |

These are deterministic openness-score changes, not full response probabilities. Gift pressing rolls a target and then delegates to `answer_gift` with a forced tier; night pressing delegates to a different account/confession path. Strength .3 can backfire even at P=.2/K=.8 (−.0126 before fatigue); strength 1 helps every representative pre-fatigue combination (P=K=.8 gives +.0324). Correct Clerk naming is exempt from the normal pressing trust loss and has its own tier boost.

### Ledger reproduction

[tools/explain_ledger.gd](tools/explain_ledger.gd) runs production filing and whole-meeting presentation at scale .6, extracts detailed argument decisions, and verifies final suspicion/weight/trust changes. Run `godot --headless --path . --script res://tools/explain_ledger.gd`. Verified on Godot 4.4.1: **36 checks, 0 failures**. It does not simulate a full randomly generated case or assert that controlled profiles are cast baselines.

Cards: (1) player vigil sighting of Greta on Market night 1, where a death occurred; (2) physical trace pointing to Market evening 1; (3) player-observed Greta sighting on Market evening 1. Greta lives/works on Market, is alive and has no public walking-role claim. Supports are fresh, with no earlier ledger contribution or source discount. Other omitted state is held neutral; prior suspicion is explicitly seeded.

Version A cites all three and finds `trace_match` from cards 2/3. Version B cites only 1/2 and uses generic support, not an unfounded branch. The originally proposed vigil+trace+home combination does not match a Demon template: residence is not evening presence. Both filed cards are circumstantial; their support quality still averages individual card classes.

| Listener | T | B(Greta) | C | I | Initial S(Greta) |
| --- | --- | --- | --- | --- | --- |
| Open listener | .8 | .5 | .2 | .2 | .2 |
| Loyal skeptic | .5 | .8 | .8 | .5 | .2 |
| Distrustful analyst | .2 | .5 | .5 | .8 | .5 |
| Convinced rival | .5 | .2 | .8 | .8 | .8 |

P=G=K=.5 for all. The four listeners are good, non-self targets; hidden Greta alignment does not determine their agreement. Each version starts from a fresh fixture. Trust-reconsideration baselines equal initial trust.

| Version | Listener | Agreement | Quality | Stored/effective weight | Actual ΔS | Final S |
| --- | --- | --- | --- | --- | --- | --- |
| A: templated | Open listener | .419355 | .942667 | .308343 | +.210290 | .410290 |
| A: templated | Loyal skeptic | .266667 | .906667 | .145067 | +.060638 | .260638 |
| A: templated | Distrustful analyst | .675676 | .870667 | .247081 | +.135895 | .635895 |
| A: templated | Convinced rival | .954545 | .870667 | .498655 | +.208438 | 1.008438 |
| B: generic | Open listener | 1 | .914000 | .712920 | +.486211 | .686211 |
| B: generic | Loyal skeptic | 1 | .860000 | .516000 | +.215688 | .415688 |
| B: generic | Distrustful analyst | 1 | .806000 | .338520 | +.186186 | .686186 |
| B: generic | Convinced rival | 1 | .806000 | .483600 | +.202145 | 1.002145 |

Version A's rounded accusing/innocent explanation weights are .39/.54, .24/.66, .75/.36, and 1.26/.06. Version B sums raw support `1.4 + .7×.3 = 1.61`; dividing by 1.2 and clamping gives agreement 1 for everyone. **The generic route can therefore beat a better-supported template** by skipping that innocent-alternative comparison. This is implemented behavior to revisit, not a proposed tuning change or a calibrated certainty of guilt.

For both versions, novelty=1, base=agreement×quality×.6, stored weight=base×(.5+T), support reliability=1, and ΔS=.55×weight×(1.4−.8C). No suspicion clamp is reached. The entry ID is `arg:demon:greta::`. Sound-argument trust +.02 goes to the last two listeners in A and all four in B, after application; it does not itself cross the .1 immediate-reconsideration trigger.

**Ledger identities and update rules:** board IDs, underlying fact IDs, conclusion-entry IDs and justification keys are distinct. Current justification keys use sorted source/night/kind references, not underlying fact IDs; distinct direct evidence with the same reference shape can collide. Same-entry hearings retain maximum weight, and distinct justifications contribute their strongest currently reliable influence rather than a sum. Recomputed effects apply only the difference from previously applied contributions. Repeated inputs alone do not add another copy, but changed suspicion/trust can change a later evaluation and a stronger hearing can replace the old weight. Qualified lie conclusions can distinguish cards; unqualified ones may share an entry. This is part of the independent-instance backlog review.

See [the full narrative walkthrough](TUNING_NARRATIVE.md#16-how-the-ledger-works-a-meeting-case-against-greta) for reply thresholds, support provenance, source-honesty feedback, repetition, and discrediting a support. Requested Confidence, ward, secret, Dowser, rebuttal, relationship and memory changes remain in [BACKLOG.md](BACKLOG.md#social-tuning-and-evidence-follow-ups-oct-20).

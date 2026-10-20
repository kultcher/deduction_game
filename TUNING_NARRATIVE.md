# Social tuning, in plain language

A narrative companion to [TUNING.md](TUNING.md), translated on October 20, 2026. The numerical reference remains the place to look up exact implementation details and source functions.

**Scope:** This explains the behavior described by that document's October 20 audit of revision `6939e40`. Its separately listed playtest fixes from `402ac63` remain separate here too. This translation does not re-audit current code, change tuning, or reconstruct a particular playtest. All scenarios below are calculated illustrations.

Throughout, **low / mid / high mean 0.2 / 0.5 / 0.8**. A table varies only the named trait unless stated otherwise. A change of 0.1 trust or suspicion means 0.1 on that internal scale, not a ten-percentage-point change in the chance of an action.

## 1. What the numbers represent

An NPC has several separate attitudes. They can trust the player while distrusting the player's suspect, like another NPC while suspecting them, or believe an accusation without wanting to replace the person already awaiting execution.

**Privacy** protects personal information. It lowers initial player trust and disclosure, makes pressing and betrayal more expensive, and makes ordinary rapport slower. It also makes keeping a confessed secret more rewarding. Several effects therefore push in the same direction.

**Gossip** controls willingness to pass information around. It is particularly important for observations and rumors. Very low Gossip can block an entire kind of sharing, even if trust improves.

**Confidence** makes an NPC harder to move with most outside evidence, but more willing to nominate and execute on the suspicion they already have. Low Confidence means more suggestibility, not necessarily more cooperation.

**Insight** makes speech less convincing relative to concrete observations, improves memory and some targeting decisions, and helps reject unsupported deductions. It does not simply multiply all useful evidence upward.

**Composure** hides nerves and attitudes, reduces fear, and dampens the effect of pressure and deaths. A calm NPC can be harder to read and harder to pressure into disclosure.

Player trust normally lies between 0 and 1, but individual permanent caps can lower the ceiling. Relationship trust between NPCs is separate. Suspicion lies between 0 and 1.5: 0.8 is strong suspicion, not an 80% probability of evil. Pressure starts at zero and has no general ceiling.

Most eligible suspicion changes are multiplied by Confidence:

| Confidence | Low | Mid | High |
| --- | --- | --- | --- |
| Outside suspicion-change multiplier | 1.24 | 1.00 | 0.76 |

Thus the same eligible evidence moves a low-Confidence listener about 63% more than a high-Confidence listener. This affects clearing as well as incrimination. Many firsthand readings are exempt.

Player trust supplies another multiplier. At low, mid, and high trust, eligible player arguments receive 0.7, 1.0, and 1.3 times their base influence. High trust therefore gives about 86% more influence than low trust, before other filters.

### How decision rolls behave

Many decisions add several influences into one score, then turn that score into a probability. A neutral score gives a 50% chance. Scores of −0.25 and +0.25 give about 27% and 73%; −0.5 and +0.5 give about 12% and 88%; −1 and +1 give about 2% and 98%.

Near the middle, a +0.1 score bonus moves a 50% chance to about 60%. Near an already likely outcome, it has less room to help: it moves an 88% chance to about 92%. Bonuses stack **before** that conversion.

Other checks are direct percentages, such as a 50% sighting roll. A direct expression that rises above 100% becomes certain. Voting is different again: good NPCs compare a final score with a threshold, without a final random roll.

## 2. Starting personalities and relationships

Each cast member's traits vary around their written baseline each game, within their individual spread, then are clamped to 0–1 and rounded to hundredths. The cast is recognizable but not identical across cases.

Their broad profiles are: Agnes is open and very gossipy; Bartholomew is private, quiet, confident, and composed; Constance is especially confident; Dorian is private but uncertain and visibly nervous; Edda is unusually composed; Fenwick is open and gossipy; Greta is private and perceptive; Hollis is exceptionally perceptive and composed; Isolde tends toward low Confidence and Composure; Jory varies widely; Kiran combines high Privacy with high Gossip; Lian is quiet and perceptive; Merrin is open, gossipy, and nervous; Nisha is private, quiet, confident, and perceptive; Odette is private and confident. Exact per-trait spreads remain in the source table.

Initial player trust has a Privacy-based starting point plus a fresh per-game random adjustment from −0.05 to +0.10:

| Privacy | Starting point | Possible initial trust |
| --- | --- | --- |
| Low | 0.500 | 0.450–0.600 |
| Mid | 0.425 | 0.375–0.525 |
| High | 0.350 | 0.300–0.450 |

The random adjustment averages +0.025. The low-to-high Privacy gap is 0.15, equal to the entire random range. A high-Privacy NPC's best starting roll only reaches a low-Privacy NPC's worst. These representative cases never hit the initial clamp of 0.1–0.9.

Ordinary NPC relationships start around 0.50, randomly between 0.45 and 0.55. Friends get another 0.25; rivals lose 0.25. Initial suspicion is 0.10 for a neutral person, 0 for a friend, and 0.25 for a rival.

Each pair initially has a 20% chance to be friends and a 12% chance to be rivals; 68% are neither. Anyone without a friend gets a reciprocal fallback friendship where possible, so the final friendship rate is higher than 20%. Lovers override their mutual trust to 0.90 and suspicion to zero.

A good NPC begins with very strong ledger support for their own role: weight 1.5, compared with 0.5 for an ordinary public role claim.

## 3. Building, losing, and capping player trust

Trust changes normally affect the particular NPC involved. One action can trigger several changes, so a seemingly modest confrontation can have a larger combined cost.

### Slow rapport and useful promises

Ending a civil conversation gives a small reward **once per NPC per day**: +0.036 at low Privacy, +0.030 at mid, and +0.024 at high. Several conversations with the same person on one day do not multiply it.

The first private naming of their role gives another +0.03, provided they have not already claimed publicly.

An accepted ward or vigil promise gives +0.03 immediately. Keeping it adds +0.06, for +0.09 total. Breaking it costs −0.15 when settled, leaving a net −0.12 including the initial reward. Duplicate copies of the same promise are rejected.

For a mid-Privacy NPC, keeping one promise is worth three days of civil-conversation rewards. Breaking one wipes out four days' worth.

Keeping a confessed personal secret earns trust on **every night-resolution pass**, without requiring another conversation:

| Privacy | Nightly secret-keeping reward | If NPC gossip has already spread it |
| --- | --- | --- |
| Low | +0.038 | +0.0152 |
| Mid | +0.050 | +0.0200 |
| High | +0.062 | +0.0248 |

This stops if the player spreads the secret. At high Privacy, three ordinary secret-keeping passes give +0.186, nearly eight daily civil-conversation rewards. This is one of the strongest passive rapport loops.

### Pressing, fatigue, and guessing

Pressing a good NPC with relevant evidence costs −0.042 / −0.060 / −0.078 at low/mid/high Privacy. A Clerk card correctly naming their role is exempt.

After three counted questions that day, **each further counted call** also costs trust. At mid Composure, the low/mid/high Privacy penalties are −0.030 / −0.04125 / −0.0525. Across representative Privacy and Composure extremes, they range from −0.024 to −0.063.

Consequently, pressing a high-Privacy NPC after their daily allowance, at mid Composure, can cost 0.1305 trust at once: 0.078 for pressing and 0.0525 for fatigue. That takes over five of their daily civil-conversation rewards to recover, before allowing for other events.

The question system has separate conversation slots and daily fatigue counts. Repeated or delegated questions can count toward fatigue even when they look like a minor follow-up.

Wrong direct role guesses become more expensive: the first costs 0.02 trust, the second 0.04, the third 0.06, and so on. The counter persists across days. Five wrong guesses cost 0.30 total, before fatigue; ten cost 1.10 before clamping. A correct guess does not incur this penalty.

### Agreeing, accusing, and persuasion

Accusing someone the listener trusts above 0.60 costs player trust on first hearing of that card. At relationship trust 0.80, the loss is 0.072; at 0.90, it is 0.096.

Conversely, a new accusation card agreeing with an existing suspicion of at least 0.50 earns +0.045 / +0.0375 / +0.030 at low/mid/high Insight. The case need not be strong or correct. This can reward echoing a mistaken belief.

A raw private accusation that actually adds at least 0.10 ledger weight earns +0.02 if the agreement reward above did not run. A structured argument earns +0.02 when agreement is at least 0.60 and actual weight gain at least 0.10. Verbal acceptance alone is insufficient.

A good NPC directly accused of evil, being Demon, lying, lacking a claimed role, or being suspicious loses 0.05 trust through the structured self-accusation branch. A good NPC who admits a caught whereabouts lie instead gains +0.02 through the admission handling.

### Public actions have personal costs

Nominating someone costs 0.15 of **their** trust. Speaking publicly against them costs another 0.08. Thus a player nomination with an accusatory statement can cost 0.23 before evaluating its evidence. A yes vote costs 0.08 when the player was not the nominator; that vote penalty is not additionally charged to the player-nominator.

Publicly defending the nominee gives them +0.06, but costs 0.04 with an NPC who made the nomination.

Clemency gives the spared person +0.15, even if evil. Other good NPCs gain +0.06 trust if their suspicion of that person is below 0.35, or lose 0.10 if it is above 0.60. Overriding an NPC's own nomination costs them another 0.08. An angry nominator who strongly suspects the spared person can therefore lose 0.18 altogether. Exact boundary values of 0.35 and 0.60 do not qualify for those strict comparisons.

A newly heard Gravedigger verdict can revise trust in the player's execution judgment, if its hearing weight exceeds 0.20 and the player nominated or voted yes. An evil verdict gives +0.092 / +0.110 / +0.128 at low/mid/high Insight. A good verdict costs 0.06. An NPC's own Gravedigger reading does not trigger this particular player-trust adjustment.

### Grief and betrayal can permanently restrict recovery

When a good NPC loses someone they trusted at 0.62 or higher, a player nomination can cause both grief and a permanent trust cap. A Demon execution is exempt; a minion execution is not.

At bond 0.80, grief costs 0.18 trust if the player nominated, or 0.12 if the player only voted yes. At bond 0.90, those losses are 0.24 and 0.16. The nomination branch permanently caps future player trust at 0.55. The vote-only branch has no grief cap.

Using a confessed secret against its owner, in a public statement, or as deduction support is expensive:

| Privacy | First use | Each later use | New trust ceiling |
| --- | --- | --- | --- |
| Low | −0.16 | −0.064 | No additional cap |
| Mid | −0.28 | −0.112 | 0.60 |
| High | −0.40 | −0.160 | 0.30 |

The first use marks the secret as spread. Reuse still hurts. Privacy below 0.34 creates no new cap; 0.34 to below 0.67 caps at 0.60; 0.67 or above caps at 0.30.

Breaking a confidential hint disclosure at a meeting costs another 0.15 for a living source whose role remains non-public. Processed confidence records are removed.

**Caps only move downward.** If several apply, the lowest wins. There is no ordinary apology, vindication, passage of time, or recovery path that restores the ceiling. Future good behavior can recover trust only as far as that ceiling.

### Trust changes can weaken old player arguments

A change of at least 0.10 from the last reconsideration trust level triggers reweighting. Before a good vote, a smaller gap of at least 0.03 can suffice.

Reweighting moves existing player arguments toward the influence appropriate to current trust. Low/mid/high Confidence moves them 88% / 70% / 52% of the remaining distance on each eligible pass. Changes smaller than 0.02 are skipped.

For example, if an argument with stored base 0.50 was weighted at trust 0.70, its desired weight was 0.60. If trust falls to 0.40, the new desired weight is 0.45. A mid-Confidence reconsideration moves the current weight to 0.495. The trust loss can therefore weaken already-accepted cases as well as future ones.

This revises player-argument entries; it does not change what happened or directly rescale the flat starting weight of a reading heard from an NPC.

## 4. How evidence becomes suspicion

### Firsthand information is stronger than hearing a report

Own readings normally start at weight 1.0. A directly heard NPC reading, public or private, starts at 0.5. Evil's separate good-shadow mind gives its fabricated own readings weight 1.2.

NPC-to-NPC testimony depends on the receiver's relationship with the teller. Low/mid/high relationship trust gives starting hearing weights of 0.15 / 0.375 / 0.55; the last hits the hearing cap. An anonymous meeting relay starts at only 0.15.

Before further source discounts, a mid-Confidence listener hearing a Seer yes about two unresolved names gains 0.225 suspicion toward each. At low/high Confidence, that is 0.279 / 0.171. The Seer's own reading gives 0.45 each without that Confidence adjustment.

"Unresolved" excludes the listener and demon-killed known-good people. A plausible role claim, or suspicion reduced to zero, does not provide the same exclusion.

### What each reading contributes

These are raw effects before hearing weight and reliability. Most heard effects also receive the Confidence multiplier; the source reference identifies the exemptions.

- **Seer:** A yes adds 0.45 to each of two unresolved names, or 0.85 to the remaining name when the other is excluded. A no removes 0.45 for its owner, or 0.30 when heard.
- **Hearthwitch and Dowser:** Zero removes 0.25 from each unresolved person. A positive count adds 0.35 per counted evil to each; that doubles to 0.70 per count if at least one group member is excluded as self or known-good. Counts therefore create large, correlated swings. An impossible heard count adds 0.50 suspicion toward its source.
- **Night Watch:** A sighting adds 0.50 before the night-context discount below. Claiming the listener was out when they know they were home adds 0.45 against the source.
- **Archivist:** Adds 0.35 each for two unresolved names, or 0.75 to the sole remaining name.
- **Rumormonger:** Removes 0.12 from each named person other than the listener.
- **Martyr:** A claimed chosen person loses 0.20 suspicion. An evil execution revealed by the Martyr surviving adds 1.0 to the executed person, without Confidence scaling.
- **Veteran:** Survival that identifies an approach block adds 0.12 to each other eligible resident there.
- **Psychologist:** Adds 0.10 through an association when the relevant subject or trusted person is already above 0.50 suspicion. It can affect either side of the association.
- **Medium:** Relayed readings use 60% of the original role's raw effects. A relayed sighting adds 0.30 before night scaling; a relayed suspicion adds 0.12.
- **Clerk:** Generally removes 0.15 from each named person other than the listener. Correctly naming the listener's own role in the pair removes 0.30 suspicion toward the Clerk.
- **Gravedigger:** An evil verdict adds 1.0; a good verdict removes 0.40, without Confidence scaling. A good execution also adds 0.25 against its NPC nominator; an evil execution removes 0.20 against that nominator, with Confidence scaling.
- **Duplicate role claims:** Someone else claiming the listener's own role adds 0.60 against the rival through role conflict. Firsthand own-role knowledge avoids Confidence scaling.
- **Accepted good-role claim:** Adds role-belief support, but does not by itself clear alignment.

### A night sighting's context can matter more than its existence

A sighting on the actual murder block on the actual night keeps full strength. Otherwise it keeps only **12%**. A thwarted attack does not count as a death for this check.

A publicly claimed walking role reduces it again. At walking-role credence 0.2 / 0.5 / 0.8, the sighting retains 86% / 65% / 44% of its previous strength. Full credence leaves 30%. When evaluating raw strength without a listener, the system assumes mid credence.

A non-murder sighting with high walking-role credence therefore keeps only 5.28% of its original strength. This explains why a true sighting can produce little suspicion.

### Reliability, dishonesty, and repetition

A source's **reading doubt** and **honesty** are separate filters. Reading doubt can reach 0.90, leaving only 10% of the reading before honesty. Honesty bottoms out at 0.50. Both together can leave 5% of its initial influence.

Doubt applies to readings, not ordinary reports or role claims. An NPC can doubt their own reading but does not penalize their own honesty.

Honesty is based on evidence grounds, not general suspicion or grudges. Positive grounds of 0.2 / 0.5 / 0.8 produce honesty of 0.84 / 0.60 / 0.50. Clearing grounds can offset incriminating ones. Evidence about its own source or the listener is excluded from this calculation. The calculation makes two estimation passes rather than endlessly updating until agreement.

**Repeating one fact does not keep adding evidence.** The ledger retains its strongest hearing. A deduction can remember several support sets, but uses its strongest justification rather than summing them. Three genuinely different nights supporting the same conclusion can consequently plateau at the strongest single justification.

Role belief appears when total role support reaches 0.12 and disappears below that. Tiny effect changes under 0.002 are ignored. Suspicion is clamped after each adjustment, and known-good demon victims stay at zero. Because clamping discards excess, adding then retracting large effects need not produce a perfectly reversible journey.

### Public opinion and grief add suspicion outside direct readings

One public accuser contributes a relationship-weighted opinion. At relationship trust 0.2 / 0.5 / 0.8, that starts at 0.084 / 0.120 / 0.156. A private-reason hint adds 15%.

Additional voices have sharply diminishing returns: the strongest counts fully, the second at half, the third at a quarter, and so on. Three equal mid-bond accusers contribute 0.21 before Confidence; an unlimited number approaches 0.24. Combined consensus caps at 0.30 before Confidence. Each day's age leaves 60% of the previous contribution. Only the latest stance per accuser counts.

This is social consensus, not evidence that its target is dishonest. Actual accusations also add pressure: 0.15, then 0.075, then 0.0375, and so on against the same meeting target.

NPC-to-NPC ordinary sightings use raw strength 0.40, opinions 0.12, and relayed player cases 0.10, each scaled by twice the NPC hearing weight; sightings also use night context. For example, mid-bond ordinary opinion delivery contributes 0.09 before Confidence and reliability. A good receiver also gains 0.02 relationship trust in the teller per delivered item, whether true or false.

NPC nomination costs 0.25 relationship trust with its target. Grief at bond 0.80 adds 0.18 suspicion toward an NPC nominator and removes 0.12 relationship trust toward them; other yes voters receive 0.072 suspicion. These grief suspicion changes are not Confidence-scaled.

Each death also raises paranoia. At low/mid/high Composure, each dead NPC adds 0.0616 / 0.049 / 0.0364 paranoia. Each new morning, that feeds a smaller suspicion drift toward other living people, except those cleared by the observer's own Seer no. With four dead and mid Composure, drift is 0.01176 per eligible person per morning before any applicable shared adjustment. The larger practical role of paranoia is lowering action thresholds later.

## 5. Presenting cards and building deductions

### Concrete observations survive skepticism better than speech

A raw card's influence combines its inherent strength, source, evidence class, relevance, prior use, player trust, and live reliability.

| Insight | Low | Mid | High |
| --- | --- | --- | --- |
| Speech retains | 84% | 60% | 36% |
| Circumstantial evidence retains | 92% | 80% | 68% |
| Concrete observation retains | 100% | 100% | 100% |

Claims, hints, refusals, opinions, accusations, and alibis are speech. Player-observed sightings, vigils, deaths, votes, executions, conversations, and quiet-night cards are concrete. Other cards are generally circumstantial unless a deduction carries a saved class.

For raw cards, the player's own observations and the listener's own words have source credibility 1.0, physical evidence 0.90, another named NPC 0.75, and an unknown source 0.50. A card that does not name the target normally has only a quarter of its relevance. A trace unrelated to their home or work keeps 30% of trace relevance.

An already-known fact keeps 35% of its quality for a new presentation route. That is a novelty reduction, not permission to farm the same route repeatedly.

Corroboration can improve the word multiplier on private accusations and public raw cards. A listener who witnessed the observation gives at least 1.4. Another corroborator gives at least 1.2 / 0.9 / 0.6 when their suspicion is 0.2 / 0.5 / 0.8; an already higher trust-based multiplier remains higher.

### How much different raw cards say

An incriminating murder-night sighting has raw strength 1.4; an ordinary daytime sighting only 0.15. A Seer yes is 1.0, Archivist 0.8, trace 0.7, accusation/opinion 0.4, and secret 0.5. Hearthwitch adds 0.5 strength per count. Night Watch is 1.0 when the target is named; many other readings are 0.6 if they implicate them. A Gravedigger card's raw accusation strength is 0.3, distinct from directly hearing its verdict.

A fear-based refusal has strength 0.25, other refusal 0.35. A rival duplicate public role claim is 1.0; an ordinary role claim only 0.1. Home/haunt cards have no raw incriminating strength; unhandled cards default to 0.2.

Defensively, Seer no has strength 0.8, Hearthwitch zero 0.6, Clerk or another qualifying clearing reading 0.5, death 1.0, vigil or secret 0.4, and claim 0.2. Night Watch and positive Seer/Hearthwitch readings provide no raw clearing strength. An otherwise unlisted card naming the target gives 0.15, and an off-target card only 0.1.

Private raw accusations start with 35% of the resulting card strength; private defence uses 30%; public card accusation or defence uses 25%. Pair/group presentations divide their influence across the group. All still pass through the applicable filters.

At trust 0.40 and mid Confidence, a fresh player-observed murder-block night sighting gives **0.441 suspicion** privately before any additional applicable corroboration. The same kind of sighting away from a murder gives only **0.05292**. Public presentation's smaller base gives **0.315** for the murder sighting before additional corroboration.

Accusing a trusted friend is harder again. At bond 0.80, private accusation strength keeps 58%; at 0.90, 44%, and the first-hearing trust penalty can apply too.

Private, group, and public presentations have distinct ledger identities, so different routes can add. Repeating an identical route does not keep adding. The code computes another repeat multiplier, but the audited persuasion callers rely on ledger maxima rather than applying that multiplier repeatedly.

Reply wording is threshold-based. A private accusation can sound strong once final suspicion reaches 0.80 or gain reaches 0.15; a defence sounds favorable at gain 0.12; a group accusation uses combined gain 0.12. Self-accusation, repetition, weak or irrelevant cards, trusted friends, and high-Insight skepticism take earlier reply branches. These replies are not extra evidence rolls.

### Structured deductions compare explanations

A recognized argument often compares its chosen explanation with its **strongest non-overlapping rival**. It does not distribute belief across every possible world.

Existing suspicion matters heavily. With neutral relationship trust and suspicion 0.10, an accusing explanation versus an innocent alternative gets about **31% agreement**. At suspicion 0.60, the same comparison gets about **74% agreement**. The new facts can therefore be interpreted through an existing prejudice.

A stronger friendship also favors innocence: each 0.10 extra relationship trust lowers the accusing weight by 0.05 and raises the innocent weight by 0.04. A 0.10 suspicion increase raises the accusing weight by 0.12 and lowers the innocent weight by 0.06. Demon-killed known-good people get an additional strong discount to lying/not-role explanations.

A misled explanation starts at weight 0.25, or 0.35 for a publicly claimed information role. A red-herring explanation gets weight 0.62 / 0.50 / 0.38 at low/mid/high subject suspicion, with another 0.10 if the subject is the listener. Association explanations grow with repeat count, credible base support, and existing suspicion. "Misled or lying" combines those component weights rather than competing against its own parts.

Firsthand knowledge can override the ordinary comparison: an assertion the listener knows false gets strong counter-explanation weight 3; one they know true gives zero to the competing false-assertion explanation.

A recognized conflict template gets 62% / 72.5% / 83% agreement at low/mid/high Insight. Unsupported conflicts are outright rejected with a probability equal to Insight; otherwise they get only 30% agreement. Other conflicts combine player trust and Insight; at mid trust the low/mid/high Insight agreements are about 53.7% / 45.1% / 36.6%. When the listener is involved, self-protection caps agreement at 79% / 62.5% / 46% for low/mid/high Confidence. That same Confidence-based level governs accepting that their own reading was misled.

A caught conscious whereabouts lie takes its own branch. Direct structured accusation of self gets zero agreement; other conclusions about self ordinarily get full agreement before later quality handling. Unsupported non-template arguments are rejected with probability equal to Insight. If not rejected, at mid trust their low/mid/high Insight agreement is only 0.38 / 0.275 / 0.17.

Generic arguments without recognized templates use summed support strengths. Accusations need about 1.2 total relevant raw incriminating strength for full agreement. Defensive arguments add clearing strengths up to full agreement. Generic suspicious and secret-style conclusions cap at 0.8; relevant-reading support gives misled/unreliable agreement 0.5 rather than 0.2. A matching self-role claim gives role agreement 0.5; otherwise 0.2. Off-target incriminating support keeps 30% relevance here, rather than the raw route's 25%.

### Agreement is only the first filter

Structured deductions use source credibility based on suspicion: another NPC's support retains 0.70 / 0.40 / 0.10 at low/mid/high suspicion. Player/evidence/own-word/unknown credibility is 1.0 / 0.9 / 1.0 / 0.5.

This differs materially from raw named testimony's initial 0.75 credibility plus its honesty filter. The same evidence can therefore perform differently depending on presentation.

Quality averages source credibility and evidence class across supports. No supports gives only 0.30 quality. A saved deduction inherits its weakest support class, and a generic inference cannot exceed circumstantial.

Accusatory novelty keeps 100% with entirely fresh facts, 67.5% with half fresh, and 35% with no fresh facts. Private presentation keeps the full presentation base; whole-meeting floor speech keeps 60%; a nomination statement keeps 50%. Supporting deductions are followed for source references up to depth four.

For example: agreement 0.75, quality 0.80, all-fresh private support, trust 0.50, and mid Confidence gives a ledger weight of 0.60. An evil conclusion then adds **0.27 suspicion** before any live reliability discount. The same argument on the whole-meeting floor adds **0.162 per listener** under those assumptions. If entirely reused, the private addition falls to **0.0945**, assuming it is a distinct eligible entry rather than a repeated unchanged justification.

Replies reject below 0.35 agreement, partially agree from 0.35 to below 0.60, and accept from 0.60. Low actual gain can still produce an "already thought so" response. Bad quality can prompt a complaint about the source rather than the logic.

A caught good liar's admission is a separate direct roll. At mid Privacy, trust 0.50, and no pressure, it is 42.5%; each 0.10 pressure adds 3 percentage points and each 0.10 trust adds 3 points. Privacy 0.2 / 0.5 / 0.8 gives 56% / 42.5% / 29% in that scenario. Admission gives +0.02 trust but does not retroactively turn that branch's zero numeric agreement into acceptance.

### What conclusions actually change

At a full ledger weight of 1 and mid Confidence, conclusions have these effects; real weights are usually smaller:

| Conclusion | Practical effect |
| --- | --- |
| Evil / Demon | +0.45 / +0.55 suspicion |
| Good | −0.40 suspicion; +0.50 protection preference |
| Protect / spare | −0.15 suspicion; +1 corresponding preference |
| Evil role | +0.50 suspicion and role support |
| Good role | −0.10 suspicion and role support; rival claimants +0.30 suspicion |
| Not that role / lied | +0.30 suspicion |
| Reading was a lie | Also +0.50 reading doubt for the source/night |
| Misled | +0.80 reading doubt |
| Unreliable | +0.50 reading doubt and +0.12 suspicion |
| Not Demon / truthful | −0.25 / −0.15 suspicion |
| Conflict | +0.05 suspicion each; total 0.40 all-night doubt split across group |
| Suspicious / has secret | +0.15 / −0.12 suspicion |
| Marked / red herring | −0.30 / −0.40 suspicion |
| Delusional | +0.70 all-night reading doubt |
| Other secret modifier | −0.15 suspicion |

Preferences, role support, and doubt do not get the Confidence suspicion multiplier.

Consequently, "misled" can be more consequential than "suspicious": it weakens a source's readings, potentially changing several suspects at once. "Spare" also acts directly on voting preference.

The audited game does not yet have a separate numerical model for "worth executing to learn something." Execution decisions mainly consume suspicion and preferences.

## 6. Getting private information

### Disclosure is a set of steps, with memory

Private openness combines Privacy, player trust, pressure dampened by Composure, the day, and a random adjustment between −0.20 and +0.20.

At day 1, no pressure, and trust 0.50:

| Privacy | Openness before random variation | Outcomes on that call |
| --- | --- | --- |
| Low | 0.68 | 67.5% name role; 32.5% role plus readings |
| Mid | 0.38 | 67.5% hint; 32.5% name role |
| High | 0.08 | 67.5% refuse; 32.5% hint |

These assume no previous disclosure, public claim, or forced tier. Openness at or below 0.15 means refusal; above 0.15 through 0.45 means hint; above 0.45 through 0.75 names the role; above 0.75 permits readings.

Each extra 0.10 trust adds 0.12 openness. Each extra day adds 0.10. Each full point of pressure adds 0.54 / 0.45 / 0.36 at low/mid/high Composure. Pressure can therefore help, but the trust cost of producing it can work against that help.

Already disclosed tiers are remembered. A public role claim guarantees at least role naming. An NPC does not retract their role claim when trust falls, and they can repeat already shared readings. However, a lower current disclosure roll can still block **new** private readings. "They told me yesterday's results, but not tonight's" is a supported outcome.

A fresh maximum-tier disclosure advances which readings have been told. Public and disowned reading handling still applies. Wardens have a special branch for known guard doors once their role is named; roles without readings say so.

### Fear mostly changes how withholding sounds

At zero demon-killed NPCs, fear chance is 35% / 27.5% / 20% at low/mid/high Composure. Each demon-killed NPC adds 10 percentage points. Four such deaths make those chances 75% / 67.5% / 60%.

Fear is fixed for that NPC and day by a deterministic hash. Repeating a question does not reroll it. It is generally not a direct subtraction from ordinary private openness, though it affects other reveal decisions.

### Questions have several overlapping limits

An ordinary conversation gives three question slots. One repeated question per conversation is free in that slot system; later repeats consume slots. The daily fatigue counter is separate and can still rise on many repeated calls.

Night resolution resets the daily question count and leaves 60% of accumulated pressure. With no new pressure, three such reductions leave 21.6% of the original amount.

A conflict deduction involving the listener adds 0.10 pressure privately, or 0.20 to each living involved NPC publicly.

A correct direct role guess has a 50% chance to increase disclosure by one tier if there has been no earlier wrong guess. An unsuccessful correct guess does not increment the wrong-guess counter. A resulting tier of at least hint delegates into normal disclosure, capped at the maximum tier.

Asking generally who holds the listener's own role gives a 19% / 25% / 31% chance at low/mid/high trust to enter their own-role answer with at least a hint.

Sharing another NPC's private role claim requires good alignment and a combined Gossip/trust/pressure threshold. At trust 0.50 and no pressure, low/mid/high Gossip gives scores 0.39 / 0.60 / 0.81 against a requirement **above** 0.55. Mid and high pass, low does not. Public claims can be repeated regardless.

Hint-follow-up handling can call the question counter twice for one displayed question. This can produce more fatigue than the player expects.

### Pressing can increase pressure while making disclosure less likely

Relevant evidence adds pressure according to its strength: 0.105 for minimum-strength material, 0.21 for a deduction, and up to 0.35 for maximum-strength material. Correct Clerk naming uses strength 0.50 and gets the special trust exemption and disclosure boost.

Nervousness depends on Composure and whether something is hidden. With deduction strength 0.60, a hiding NPC's low/mid/high Composure gives **28.8% / 18% / 7.2%** nerves. A non-hiding NPC gets **9.6% / 6% / 2.4%**. Hiding includes an innocent undisclosed gift or personal secret, so nerves do not establish evil.

Consider a good NPC at Privacy 0.80 and Composure 0.80. Pressing with a deduction adds 0.21 pressure, worth +0.0756 openness. Its 0.078 trust loss removes 0.0936 openness. Net: **openness drops by 0.018**, even before fatigue. Late-question fatigue can make that much worse.

An irrelevant card merely produces an irrelevant reply and ordinary question counting. Challenging a rival public role claim can reaffirm the listener's role and add 0.30 raw suspicion toward the rival. Night and gift challenges delegate to their respective answer systems.

### Night accounts distinguish innocence from honesty

The answer sequence first handles unconscious Sleepwalking, approved fake Night Watch stories, actual home accounts, and already-disclosed walking duties. Hidden movement comes afterward.

A good hidden walker with a personal secret can confess. At trust 0.60 and no pressure, low/mid/high Privacy gives **69% / 40% / 17%** confession chances. At mid Privacy and trust 0.50, it is about 27%. Pressure helps, with Composure reducing that help.

If they do not confess, Confidence and Privacy decide whether they lie or stonewall. At mid Privacy, low/mid/high Confidence gives about **14% / 50% / 86%** chances of lying. Higher Privacy shifts toward stonewalling. Evil uses that lie-versus-stonewall choice too. A Sleepwalker who says they stayed home is unaware, so that false statement is not a conscious lie.

### Observations have a hard Gossip gate

If Gossip is **below 0.20** and pressure **below 0.50**, observations are withheld outright. Trust does not bypass this.

At exactly 0.20 Gossip, the gate is already open. Low/mid/high Gossip at zero pressure gives a normal observation limit of **2 / 3 / 3**. At pressure 0.50 it becomes **2 / 3 / 4**. The limit rises with pressure and has no general maximum.

Even after the gate, seeing a person trusted above 0.70 is omitted 60% of the time. Evil omits true nighttime sightings of teammates. If a sighting contradicts the speaker's claimed vantage, mid Composure and zero pressure gives a 12.5% chance of slipping and mentioning it; each 0.10 pressure adds 1.5 percentage points. Otherwise it is omitted.

A fabricated Night Watch report replaces ordinary sightings with its cached story. It is not cut to the ordinary count, though a zero sharing limit still blocks it. Other evil speakers can append cached fake sightings.

Daytime memory holds **3 / 4 / 5 unique people** at low/mid/high Insight, most recent first. A whereabouts answer is separate from gossip about other people. Observations already visible to the player can be omitted.

Person-specific follow-ups can append observations from the current and previous two phase frames, at most one per frame. They add no extra displayed-question charge or new random roll. Night additions require an already disclosed walking gift, respect existing alibis, conceal unconscious Sleepwalking, and avoid exposing evil teammates.

### Attitude language is imperfect evidence

Private opinions sound trusting below suspicion 0.25, uncertain from 0.25 to below 0.45, doubtful from 0.45 to below 0.80, and strongly accusatory at 0.80 or above.

Within the uncertain band, the chance of saying "something off" is 52% / 40% / 28% at low/mid/high Insight before paranoia. Paranoia adds directly to those chances. That wording can produce an opinion card even though underlying suspicion is below 0.45.

A greeting shows attitude with probability **72% / 45% / 18%** at low/mid/high Composure. Its trust language is wary below 0.30, guarded below 0.50, civil below 0.70, and brightens at 0.70 or above. Calm NPCs often hide this cue.

A conversation attempts its first available trait reveal unconditionally; the extra reveal chance is 48% / 30% / 12% at low/mid/high Composure. Post-meeting reveal chances are 28% / 17.5% / 7%. Mentioning closeness requires bond above 0.70 and appropriate dialogue voice; it does not confirm alignment.

## 7. Going public and defending an accusation

### Public role claims have their own urgency

Spontaneous public claiming uses Privacy, day, pressure, role type, and the number left alive. **It does not directly use player trust.**

For a hidden recurring information role, day 1 and no pressure:

| Privacy | Public claim chance |
| --- | --- |
| Low | About 17% |
| Mid | About 4.7% |
| High | About 1.2% |

Each extra day adds 0.30 to the score. The early recurring-role penalty also disappears after day 2, making day 3 a substantial change. At day 3, the same low/mid/high Privacy examples become about **92% / 73% / 39%**.

Non-information roles receive a −0.50 score penalty. Listed recurring information roles receive −0.40 through day 2; otherwise START_ROLE status gives +0.30, or an actual good Martyr with a chosen target can get +0.40. These role adjustments follow the source's branch order rather than all stacking.

Four or fewer living NPCs adds a large +0.80 urgency bonus. Pressure adds 0.72 / 0.60 / 0.48 score per full point at low/mid/high Composure.

Each unsilenced NPC gets this check during meeting testimony. Already-public NPCs share fresh readings without rerolling willingness. Going public sets role disclosure to at least tier 3 and shares eligible unshared readings at ordinary direct-hearing weight 0.50.

### Revealing a role for another purpose has a cost

A hidden role's basic reveal cost at low/mid/high Privacy is **−0.04 / +0.20 / +0.44**. Add 0.50 for a non-information role, 0.40 for an early recurring role, and 0.35 if afraid. Each day after day 1 removes 0.12; four or fewer living NPCs removes another 0.60.

These are costs subtracted from relevant decision scores. They are not probabilities and can become negative, turning into a reveal incentive. Already-public claimants have no reveal cost.

A frightened high-Privacy recurring information holder on day 1 has cost **1.19**. A calm mid-Privacy one has **0.60**. The private, public, and self-defence systems can therefore produce different sharing behavior from the same NPC.

### Accusing someone need not mean revealing why

At mid Confidence and zero pressure, suspicion 0.2 / 0.5 / 0.8 gives about **8% / 35% / 77%** chances of making a public accusation. Low Confidence subtracts 0.24 from that decision score; high adds 0.24. Pressure also encourages speaking.

A good NPC chooses their most suspected living other person. Evil uses its living scapegoat from day 2, with treated suspicion 0.80. Silence blocks accusation.

A private reason can become a public reveal, a hint, or an anonymous relay. Stronger readings, stronger suspicion, and higher Confidence favor revealing; reveal cost resists it. A Seer yes or Martyr evil result has reveal strength 0.90, compared with Night Watch 0.35, Medium 0.50, and an Archivist minion result 0.40. Group counts depend on the count relative to group size.

Even an available citable reason can be omitted: **40% / 25% / 10%** at low/mid/high Insight. Thus vague wording is not exclusive to evil.

Nominators consider up to three useful positive ledger contributions of at least 0.03, recap at most two public reasons, and gain another +0.20 score toward exposing a protected private reason. Recapping known public reasons does not apply them again. A missing private reason can fall back to the strongest relay.

### Following up a hint depends strongly on trust

For a current protected hint, at mid Privacy and without fear, low/mid/high player trust gives about **12% / 60% / 94%** chances of a full private disclosure.

Low Privacy adds 0.24 to the score; high Privacy subtracts 0.24. Fear subtracts 0.30: the mid-trust, mid-Privacy example drops from 60% to about 31%.

Success forces maximum-tier disclosure. If the role remains non-public, the claims and readings are confidential. Failure chooses between two refusal phrasings equally; stalling itself is not an evil tell.

Anonymous public relay supplies only 0.15 reading weight. Its hidden source has just a 5% chance to step forward if alive, unsilenced, and still private.

### Nominees can offer up to two defensive moves

A silenced nominee cannot speak or apply defence effects.

A walking-role holder facing movement evidence first tries to explain it. An already-public one explains automatically. A private one rolls against reveal cost, with a generous base score of 1.30 before costs. Success can remove up to 0.35 raw movement-based suspicion.

If that does not happen, a good secret-holder facing movement evidence can confess. Low/mid/high Privacy gives about **94% / 83% / 60%** chances. This branch does not use the private-night-confession trust formula. Success removes up to 0.30 raw movement suspicion.

Further moves can claim red herring after at least two public Seer pings (−0.12 self suspicion), split a two-person reading (−0.06 self, +0.06 other), or blame a source. Confidence above 0.60 uses "lied" (−0.05 self, +0.02 source); otherwise "misled" (−0.06 self). With no move, a plea removes only 0.02.

Listeners weight each defence at **0.60 / 0.75 / 0.90** for low/mid/high relationship trust in the defender, then apply live reliability and eligible Confidence scaling. These are small-to-moderate adjustments, not automatic acquittals. Repeating the same defender/day/move does not stack.

## 8. Nomination and voting

### Nomination becomes easier as days and deaths accumulate

At mid Confidence and no paranoia, a good NPC needs candidate suspicion of **0.78 on day 1, 0.70 on day 2, 0.62 on day 3, 0.54 on day 4, 0.46 on day 5, and 0.45 from day 6 onward**.

Low Confidence adds 0.09 to the requirement; high removes 0.09. Every 0.10 paranoia removes another 0.05. The day-based minimum is applied before those adjustments, so the final threshold can fall below 0.45.

For example, four deaths and mid Composure produce paranoia 0.196. A day-3, high-Confidence nominator then needs about **0.432**, rather than the neutral 0.62.

Eligible nominators must be alive, unsilenced, and have their daily nomination available. They scan by suspicion, skip already nominated people, and reduce a candidate's score by 0.20 if their own Seer no cleared them.

If an existing block candidate is at least as suspicious as the adjusted new candidate, the nominator can stop, content with the current execution. Each eligible nominator offers their first qualifying target; the town selects the highest candidate score.

Opening a nomination adds 0.40 pressure to its target, besides its interpersonal costs.

### Good votes are score comparisons

Self always votes no. For another nominee, start with the voter's suspicion, then adjust for the player, relationships, competing execution, and preferences.

| Player trust | Low | Mid | High |
| --- | --- | --- | --- |
| Player declares yes | +0.000 | +0.075 | +0.150 |
| Player statement accuses | +0.040 | +0.100 | +0.160 |
| Player statement defends | −0.050 | −0.125 | −0.200 |

A yes declaration becomes a negative influence below trust 0.20. A declared yes and accusatory statement can stack, for combined bonuses of 0.04 / 0.175 / 0.31 at representative trust levels.

Relationship trust toward the nominee adds **+0.18 / 0 / −0.18** at low/mid/high bond. A voter who suspects the NPC nominator above 0.70 subtracts 0.15. A spare preference subtracts half its value.

If another person is already on the block and is at least as suspicious as the nominee's **base** suspicion, the new nominee suffers **−0.40**. This is larger than even the high-trust player's combined direct yes-and-accuse bonus of 0.31.

A working Martyr's choice can also discourage execution by up to 0.60 before urgency and high suspicion reduce that protection. Each 0.10 paranoia reduces it by 0.04, each 0.10 nominee pressure by 0.03, and suspicion above 0.80 reduces it further.

On day 2 onward, without paranoia, low/mid/high Confidence needs final vote score **0.572 / 0.500 / 0.428**. Day 1 adds 0.10. Every 0.10 paranoia lowers the requirement by 0.04.

**Scenario:** Day 2, mid Confidence, no paranoia, neutral relationship, suspicion 0.60, and player trust 0.50. Player yes plus accusation raises the score to 0.775: a yes vote. If an at-least-as-suspicious person is already on the block, the score falls to 0.375: a no vote. This NPC can believe the accusation and still prefer the existing execution.

### The tally can also stop an execution

Each nominator has one nomination per day; each NPC can be nominated once. Voters are living NPCs plus the player; dead ghost votes are not included in the audited implementation. The required tally is half the voters rounded upward: for eight living NPCs plus the player, five yes votes are needed.

Votes are evaluated clockwise from the seat after the nominee, with the nominee last. NPC logic knows the player's vote before the displayed tally reaches the player.

Meeting the minimum is not enough to replace the block: the tally must strictly beat the existing block count. An equal qualifying tally clears the block; a lower one leaves it. Clemency cancels the pending nomination but does not refund the already-spent nomination slots.

The player gets one whole-meeting deduction per day and one statement per pending nomination. A statement can independently change trust, apply evidence, and supply its direct vote modifier.

## 9. How information travels without the player

### Friends are more likely to talk and then trust each other more

Conversation pairing is weighted rather than always choosing the strongest pair. At low/mid/high **mean mutual** relationship trust, ordinary pair weights are **0.02 / 0.40 / 1.00** before bonuses. Unfriendly pairs hit the minimum.

New intel adds 0.60 in each eligible evil-to-evil direction. Good news adds 0.50 in each eligible direction where the sender trusts the recipient above 0.60. An actual good Psychologist adds a 0.50 nudge. Pair weight caps at 2. Silence forces the minimum weight and blocks delivery itself.

Before player actions, each allowed pairing iteration has a 65% opportunity roll, while preserving at least three player conversation options. There is at most one iteration below ten NPCs; otherwise the cap is integer NPC count divided by five. Each NPC pairs at most once a day and must be idle and available.

After player actions, selected co-located pairs get a chance equal to 40% of their weight: **0.8% / 16% / 40%** for the representative ordinary pairs, up to 80% at the cap.

Each delivered item gives a good receiver +0.02 relationship trust in the teller. Friends consequently speak more, then become still more trusted, whether the information is true or false.

### One conversation does not deliver everything

Each speaker selects **one** item by relative weight, competing with a weather/no-news option of weight 0.30. A weight of 0.60 means a 67% selection chance only if weather is the sole alternative; with other items available, the chance is lower.

At mid Privacy, no pressure, and low/mid/high trust in the recipient, a fresh own-reading item's weights are **0 / 0.24 / 0.60**. Each point of pressure adds 0.30. At bond 0.80, changing Privacy from low to high changes that reading weight from **0.96 to 0.24**, a fourfold gap.

Confiding a personal secret requires a good sender and bond above 0.60. At bond 0.80, low/mid/high Privacy gives weights **0.48 / 0.30 / 0.12**.

At mid Confidence, a top-suspect opinion has weights **0.12 / 0.30 / 0.48** at low/mid/high Gossip, provided suspicion is at least 0.50. High Confidence adds 0.12; low removes 0.12. Evil scapegoat opinions instead require public heat at least 0.30.

Player cases have weights **0.10 / 0.25 / 0.40**, considering the last two remembered. Recent night sightings have weights **0.16 / 0.40 / 0.64**, with another 0.40 for an actual murder-block/night sighting. Ordinary hearsay uses **0.09 / 0.225 / 0.36**, from the last four items. Relaying another person's secret at mid Composure uses **0.064 / 0.160 / 0.256**. Lower Composure raises that secret-gossip tendency.

Already-told items are excluded. Hearsay avoids sending back to its source or subject and excludes secrets from that ordinary category.

### Approaching the player has its own gate

There is a 40% phase-level opportunity, then availability and agenda checks.

An NPC with a fresh private reading needs trust **at least 0.50**. At trust 0.50, low/mid/high Privacy gives agenda scores **0.70 / 0.40 / 0.10**, with random addition from 0 to 0.20. The winning score must reach 0.35.

Thus a high-Privacy NPC at exactly 0.50 trust cannot initiate this reading approach even with the best random addition; a mid-Privacy one can. High Gossip, at least 0.60, can instead supply a gossip agenda when gossip is available. Evil uses the corresponding framing agenda.

A successful news/frame approach forces full disclosure. Its added question count is canceled afterward, but any fatigue already charged inside the answer has occurred.

### Other sharing opportunities

Gossiping a secret to the player has a **56% / 65% / 74%** chance at low/mid/high Gossip, before falling back to available hearsay.

A crowded tavern with at least four occupants gives eligible evil intel exchange a 50% chance. Tavern speakers are weighted by 0.10 plus Gossip, making representative high-Gossip speakers three times as likely as low-Gossip speakers among otherwise eligible choices. Evil has a 60% fake-rumor branch when its scapegoat lives. Ordinary true sightings require Gossip at least 0.20 and recent unshared information; fallback suspicion requires at least 0.40.

At mid trust, haunt-sharing chance is **26% / 42.5% / 59%** at low/mid/high Gossip. Low trust removes 15 percentage points; high trust adds 15, with a total cap of 90%. Conditional on sharing, 40% of outcomes give all unknown haunts, otherwise one. This uses one roll, not a separate all-haunts roll.

### Suspicion also shapes future information generation

After the initial random Seer choice, and with enough people alive, low/mid/high Insight gives a **40% / 55% / 70%** chance of targeted rather than random selection. Insight at least 0.60 can switch to unchecked pairs after two yes readings on the top suspect, or prefer an unchecked partner.

Night Watch starts randomly, then tends to watch its top suspect's home block.

Warden protection prefers public information holders, trusted people, low suspicion, and protection preferences. A full unit of protection preference adds 1.20 to target score, compared with ordinary random noise of at most 0.30. Martyr selection uses relationship trust, reduced by suspicion and improved by protection preference, and needs a winning score of at least 0.62.

A Psychologist reading of evil reports a teammate as most trusted 75% of the time when one exists. This is a biased information-generation rule, not proof that every reported pair is evil.

## 10. Evil cover and fabricated evidence

### Evil balances strategy against acting like its good self

With the audited shadow-self setting enabled, an evil NPC has a separate good-style evaluation of the world. It may follow that answer to preserve cover, even when its strategic answer differs.

It switches to strategy only when strategic stakes, after a penalty for how conspicuous the deviation would be, exceed its caution threshold. This is a deterministic comparison, not a percentage roll.

Exposure rises with recent public discussion of the NPC, known player suspicion (+0.30), pressure (+0.50 per point), and already being nominated or on the block (+0.20). Public discussion fades to 75% per elapsed day and caps its own component at 1.

High exposure makes strategic deviation more costly. An exposed evil NPC can therefore behave **more** like its good shadow, rather than automatically becoming more openly evil.

Demon caution starts at 0.80 and falls by 0.03 per day after day 1, with a floor of 0.45. Minion caution stays 0.70 through day 2, then falls much faster: 0.62, 0.54, 0.46, 0.38, 0.30, and finally a 0.25 floor from day 8. Late minions are more willing to abandon cover.

The Demon is worth twice an ordinary teammate in many strategic stakes. Preventing the shadow from nominating a minion has stakes 0.80, versus 1.60 for the Demon, before exposure costs. For structured replies, reject-to-accept is a larger deviation than partial-to-accept.

Voting urgency depends on whether the vote looks pivotal. A pivotal vote counts fully; a remote one uses only 35% stakes. This checks votes already cast plus the player, not a forecast of later voters.

**Important version boundary:** the separate playtest fixes add an unconditional guard against evil nominating or voting to execute its Demon. The baseline cover comparison alone did not guarantee that protection.

### Town mistakes help evil select a scapegoat

Public heat starts at 0.15. Accusations add 0.12, nominations 0.20, yes votes 0.04, and public clears remove 0.12. Reading heat depends on published target strength, up to the specified 0.40 multiplier, with a 0.20 fallback.

Heat fades to 75% per elapsed day and stays between 0 and 1. Evil-authored events are excluded from the scapegoat public-heat calculation, so evil cannot directly manufacture all of its own momentum through that term.

Initial scapegoat choice combines random noise up to 1, a large +1 for a known walker, +0.50 for a disliked person, and +0.20 for a public Warden or Veteran.

From day 2, selection combines public heat with half the average evil-shadow suspicion, compatible existing fake evidence, and walker intel. Fake readings add 0.25 each and walker intel 0.15 each, capped together at 0.60. Public clears impose an additional fading 0.30 penalty each.

The current scapegoat also gets a retention bonus of 0.25 plus 0.15 for every evil public accusation ever made against them. This gives evil an incentive to stick with the story it has already told.

A town's mistaken theory can thus attract evil support, then acquire fake readings and repeated accusations. Public clears and competing momentum are the main brakes.

### Evil nomination and votes

From day 2, evil can nominate its living scapegoat if not already nominated or on the block. It does not strategically replace a good person already on the block.

The required heat is **0.42 / 0.375 / 0.33** at low/mid/high Confidence. Candidate score is heat plus 0.20.

Strategic votes follow an ordered set of rules before cover overrides:

1. A Revenant with a hidden totem first has a 55% yes opportunity; failure continues to later branches.
2. A teammate normally gets no. A Demon already on the block can vote for a minion to create a clearing tie with **50% / 65% / 80%** chance at low/mid/high Confidence, and can join a minion execution already passing without it.
3. If another teammate is on the block, vote yes on a good replacement.
4. Vote yes on the scapegoat.
5. Join a good execution when the yes tally is within two of the threshold.
6. Otherwise, vote yes with **39% / 45% / 51%** chance at low/mid/high Confidence.

Self votes no before this strategy. The separate Demon-protection fix constrains the final behavior.

### Evil's words can be masks

Opinion cover normally gives a teammate a benign level 0.20 and the scapegoat a strongly suspicious 0.85, unless the shadow/override rules lead elsewhere.

Several response percentages shape dialogue rather than real belief. Raw defence of evil sounds favorable 60% of the time; defence of good is tentative 70%. Group cases are tentative 60%. A speech accusation against evil gets a 50% "only talk" response. A highly relevant accusation against good gets strongest agreement on the first 35% of the random range, favorable agreement up to 70%, and tentative wording otherwise.

Structured strategic masks generally favor accusing good, defending evil, and conflicts containing only good people. A favorable new case is accepted 65% of the time; a strongly unfavorable one is rejected 40%, otherwise partially accepted. Self-related conflict/misled replies have 50/50 special wording. Shadow evaluation can replace these masks.

An evil NPC agreeing with the player is therefore not evidence that its underlying strategic interests changed.

### Fake sightings are cached, not rerolled on demand

An eligible evil NPC has a 50% chance per night, from night 1, to prepare a false scapegoat sighting. Success **and failure** are cached. Reasking does not keep rolling until the lie exists.

When the scapegoat lives on the claimed block, the fake detail has a 50% chance to say they were leaving home; otherwise it uses a street sighting. Fake tavern rumors have a 60% branch. Eligible free private-reason hints can use a 30% opportunity.

### Fake readings follow role-specific stories

- **Seer:** Frames the scapegoat with a yes on night 0, odd days, or with five or fewer living NPCs, when a partner is available. Otherwise has a 40% eligible teammate-clear opportunity, then falls back to harmless no results. It never intentionally clears its scapegoat.
- **Hearthwitch:** Reports one when the scapegoat is a neighbor. Otherwise an eligible good neighbor can be implicated with a 30% count-one result from day 1; the alternative is zero.
- **Rumormonger:** Pairs a teammate with a good person and chooses uniformly among four secret modifiers, including Lovers and Marked. These are cover stories, not deductions from hidden truth.
- **Clerk:** Pairs a teammate with a good person and names the teammate's bluff role.
- **Archivist:** Pairs the scapegoat with another good person and names an actual minion role from setup.
- **Gravedigger:** Gives an executed teammate its bluff. For a good execution, uses the person's claimed good role if available, otherwise a random good role.
- **Night Watch:** Watches the scapegoat's block, includes known walkers, and from night 1 inserts the scapegoat if absent. The watched block is cached.
- **Lamplighter:** Uses the actual walker count plus an equally likely −1, 0, or +1, clamped to plausible bounds. Clamping can make exact outcomes less evenly distributed.
- **Surveyor:** A single roll allocates 60% to an attempted plausible wrong count, 25% to truth, and 15% to a too-high count when the team occupies fewer than four possible blocks. Unavailable alternatives fall back to truth, so its actual truth rate can exceed 25%.
- **Psychologist:** Uses an available person actually talked to, names the scapegoat as most suspected, and another random person as most trusted.
- **Martyr:** Once after night 0, claims to choose a teammate, or a good person when alone.
- **Medium:** Has a 15% empty-report branch, choosing between a suitable good person on its block and a dead person's home. Otherwise it strongly prefers a compatible unshared fake reading in the dead person's public role (relative weight 3.0) over a framing home sighting (1.5), nothing-new or repeated public suspicion (0.8 each), or home fallback (0.4). Framing is allowed on the first attempt, then on a 50% check. Fake dead Seer/Dowser stories can clear a publicly implicated living Demon on a 50% check. A fake dead Seer can continue an earlier public yes on good with a 50% opportunity; a fake dead Psychologist names the scapegoat as most suspected 60% of the time. Already-public source role/night readings are excluded, and fake Breathstealer results through dead Archivist/Gravedigger require a living Breathstealer.

Those Medium menu weights are relative preferences among currently eligible stories, not unconditional chances of each outcome.

## 11. Public events, movement, and tactical pressure

### Some public events create small clears; others are decisive

Public Breathstealer silence removes 0.12 raw suspicion from the silenced person in other living good minds, at ledger weight 1 with Confidence scaling. That is **−0.1488 / −0.12 / −0.0912** at low/mid/high Confidence.

A quiet night removes 0.15 raw suspicion from a public living Warden claimant and 0.06 from a Veteran claimant, with Confidence and honesty filters.

A demonstrable Martyr substitution removes a very large 2.0 raw suspicion from both good target and Martyr, then marks them cleared. A Revenant curse adds 0.15 raw suspicion against other living yes voters. Lifting the curse caps the freed NPC's suspicions of others at 0.25 and restores their own-role claim weight 1.5.

These are different strengths of signal: silence offers a soft clear, while the demonstrable Martyr event is designed to overwhelm ordinary suspicion.

### Observation opportunities leave plenty unseen

A night walker has a 50% chance to be seen by another walker along its route, versus 15% from a home window. A same-block home observer has a 20% chance to notice someone stayed in.

These are individual opportunities, not guarantees that useful reports reach the player. For illustration, two independent 15% window opportunities would give a 27.75% chance of at least one sighting, before sharing gates and omissions.

Player vigil collects eligible living walkers whose paths cross its block without an extra sighting roll.

Sleepwalker movement has a 50% nightly chance if not already out, and the walker is unaware. Personal-secret movement has a 55% chance if not already out; Lovers use their paired meeting rule instead.

A death scene has a 40% chance to choose another eligible passer's trace when one exists. It is actually misleading only if that passer's **evening** block differs from the Demon's. A trace identifies an evening block; a murder-block sighting concerns the night. They are not interchangeable premises.

A Demon walker drops something with 35% chance; other walkers with 15%. On a successful drop, 12% are personal items and the rest home-block material. Before other conditions, that is **4.2% personal-item chance per Demon walk** and **1.8% per other walk**.

Ordinary flavor-secret generation is disabled. Its dormant random branches should not be treated as current sources of extra secrets.

### Evil targets information threats, but scores are not probabilities

Kill and poison choices add score parts. A +1 score is a preference contribution, not a one-percentage-point chance.

Public information claimants contribute threat 3, with Seer another +1. A first-night information claimant's special kill value falls to +1 after setup night. A shared reading implicating evil adds +2 as a named threat part. Known-intel threat caps at 3.

Public hostility adds +1 per relevant action against evil and +0.50 per yes vote, capped at 2.50. Kill scoring uses 80% of that hostility; poison uses 60%. Clears are ignored by this hostility count.

For kills, being the only living resident on a block adds 0.70. A vengeful Demon adds 1.50 for a disliked target; a cunning one adds 1.50 for the scapegoat's home block; a hungry one adds random noise up to 2. General kill noise adds up to 0.80.

Preserving a scapegoat while more than four NPCs live subtracts **4**, much larger than ordinary noise. Prior unexplained failures subtract **10 each**, making repeated failed targets exceptionally unattractive. Clemency-spared targets get −1.50 while more than four live. A claimed Warden makes attacking a public information claimant 0.80 less attractive.

Veteran handling is specific: a spent Veteran after a known failure gets +0.30; one with a living Poisoner gets +0.60; a first attack without Poisoner gets −2.

Unexplained failed attacks add caution up to 1.50, halved after each target choice. Caution penalizes high public-profile targets. Visible player wards do not update that failure/caution handler. Witnessing a Warden at a failed target's door adds +2 known threat.

There is a 3% unpredictable-choice branch with more than three candidates: it chooses outside the top three, but only among candidates scoring above −5.

Poison combines public threat, hostility, known threat, random noise up to 1.50, and a −3.50 spent-gift penalty. Poisoning a suspected Warden to enable an attack adds +2.50 when the kill target is a public information claimant, otherwise +1.20. The kill target is normally excluded from poisoning, except for the explicit Veteran combo.

Whether the gift is still useful matters: unknown claims are assumed live; first-night roles are live only on night 0; Gravedigger needs an execution; Veteran needs the combo; Martyr starts on day 1; Sexton is not a night-poison target for a decision already made.

### Breathstealer timing is opportunistic

Breathstealer targets must be good, on its block, not the previous target, and not already silenced or pending silence. It maximizes threat plus hostility plus known intel plus noise up to 1.

If the best target score exceeds 1, use chances are **30% morning, 50% afternoon, and 100% evening**. Otherwise they are **15%, 30%, and 70%**. These are conditional opportunities after eligibility and score selection, not a fixed percentage of all NPCs silenced.

If the same low-score opportunity remained eligible at all three phases with independent rolls, the chance of using the ability by evening would be about 82.15%. Actual availability and state changes can alter that.

Revenant totem hiding chances are 45% morning, 60% afternoon, and 100% evening, subject to the relevant opportunity.

## 12. The interactions most likely to dominate a playthrough

**High Privacy is several obstacles at once.** It means lower starting trust, less disclosure, weaker daily rapport, steeper pressing/fatigue costs, and harsher betrayal. Keeping a confessed secret is unusually rewarding, but the player must first reach confession. Improving a single coefficient may not noticeably change the whole journey.

**Pressure can defeat its own purpose.** It directly helps openness, but pressing costs trust and may add fatigue. A private, composed NPC can become less willing to share after relevant pressing.

**Wrong guesses create a lasting spiral.** Their costs escalate across days, while lower trust makes future disclosure harder. There is no ordinary reset described for the counter.

**Agreement can build trust faster than correction.** New accusations echoing an existing belief can reward rapport without strong evidence. That rapport then increases future player influence.

**Suspicion affects how later facts are interpreted.** An early lead makes accusing explanations more plausible and innocent alternatives less plausible. Structured source credibility also falls with suspicion, even though ordinary hearing's honesty estimate avoids mere vibes.

**Independent support can plateau.** Keeping only the strongest justification prevents repetition exploits, but can also make multiple genuinely independent nights feel surprisingly unpersuasive. Different conclusion identities and presentation routes can still stack, so the model is stricter about some forms of repetition than others.

**Executing someone can damage the player's future ability to correct the town.** Nomination, public opposition, grief, and a permanent trust cap can combine. Even executing a real minion can hurt the player's bond with a good mourner.

**A blocked vote can be an execution preference.** The −0.40 existing-block penalty is large. More evidence does not necessarily answer a refusal whose actual cause is preferring another candidate.

**Friendship creates information circles.** Friends talk more, believe each other more, omit incriminating sightings, and gain relationship trust from delivering items. False information receives that social reward too.

**Death increases both action and withholding.** Paranoia makes nominations and votes easier while fear can keep reasons private. Late public urgency eventually pushes the other way. Protection offers currently help through trust rather than directly reducing fear.

**Evil follows useful town mistakes.** Scapegoat heat, shadow suspicion, fake-reading fit, and retention can reinforce a wrong lead. This is part of the intended local social game, rather than a global solver secretly rescuing the town.

These are implications of the audited tuning, not proposed parameter changes. The source document's suggested priorities are to explain voting resistance, review unrecoverable trust damage, align presentation routes, support independent corroboration with diminishing returns, revisit fatigue/gossip boundaries, and separate execution purpose from certainty of guilt.

The case deadline adds external urgency: fewer than ten NPCs gets six days; ten or more gets eight. Exceeding that limit ends the case for evil, independently of anyone's trust or belief.

## 13. Separately listed playtest fixes

The source lists the following as tested local changes in `402ac63`, outside its baseline tables. This companion preserves that boundary rather than asserting whether each has since reached main.

- Supporting the listener's own claim or defensive deduction can earn **+0.03 trust once per underlying fact**, if defensive strength is at least 0.20. Repetition cannot farm it. This adds a positive route for helping someone, alongside the baseline rewards for agreeing with their suspicion.
- Supported defensive conclusions about good, not-Demon, truthful, spare, protect, secret, Marked, and red herring use strength 0.30; good-role conclusions use 0.20. Unsupported deductions do not get this treatment.
- Spoken daytime whereabouts and publicly cited sightings create attributed cards, increasing usable evidence without increasing its inherent certainty.
- Lovers/personal-secret confessions can support a possible movement explanation. Reported Marked cards can explain eligible evil readings. There is no automatic Marked self-disclosure.
- Withheld Night Watch readings cannot be bypassed through whereabouts or person-specific follow-ups.
- Evil cannot nominate or vote to execute its Demon merely to preserve shadow cover. Deliberate Scion succession remains deferred.
- Warden bluffs can name teammates.
- Own-role knowledge rejects explanations requiring another role; ordinary self-sightings can match a route rather than only a destination.

The numerical reference reports seven Godot suites, including 24 playtest-specific checks, for those earlier fixes; that is historical validation, not a new test run for this translation. Rendered verification was still outstanding in that account.

## 14. Reading logs and maintaining the reference

To understand one NPC's actual journey, start from their initial trust, traits, role, and relationships. Follow ordered trust and trust-cap events, then connect them to questions, promises, accusations, nominations, grief, Gravedigger reports, and day changes.

One action can produce several penalties or rewards. Caps can change without immediately changing trust. Changes smaller than 0.01 may lack individual trust events, and recorded values are rounded. A perfectly exact timeline cannot always be reconstructed by summing displayed deltas.

Keep an evil NPC's visible trust separate from its good shadow's state. Report consequential threshold crossings: full private disclosure, trust 0.50 approach eligibility, reweight triggers, and voting modifiers. A refused vote does not establish falling trust; a refused observation does not establish distrust.

When tuning changes, update both the exact reference and the relevant explanation here. Preserve whether a number is a score, probability, raw suspicion effect, or final weighted result. Recheck representative scenarios and meaningful strict boundaries, especially the Gossip gate below 0.20, the trust cap bands, and the voting comparisons.

The practical question is not only whether NPCs reach the right answer. It is also whether a player can understand resistance, recover from a mistaken theory, and assemble a case from information the NPC actually knows.

## 15. Active settings worth remembering

The audited model uses good-shadow evil evaluation, 1.2 shadow own-reading weight, defence moves, source-honesty filtering, fading/capped public consensus, and information-before-kill ordering. The last setting lets victims retain their final night's reading.

Optional no-gift denial is off, so its dormant lie/refuse roll is not an ordinary tier-1 behavior. If enabled, its low/mid/high Confidence yes probabilities would be about 10% / 40% / 80% for that decision's designated outcome.

Ordinary flavor secrets are off. Anonymous relay starts at 30% of ordinary direct-hearing weight and has a 5% source-corroboration opportunity. Evil hint opportunity is 30%; the Medium empty-report branch is 15%. Defence movement reveal has the +1.10 rope bonus included in section 7, and source-blame defence blowback is 0.02.

Trait labels in dialogue use below 0.34 for low, 0.34 to below 0.67 for mid, and 0.67 upward for high. Those are descriptive labels; mechanics such as the Gossip gate or Confidence-based defence use their own thresholds. The 0.2 / 0.5 / 0.8 examples in this companion are representative points within those bands.

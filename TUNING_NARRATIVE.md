# How the town thinks, in plain language

A plain-English account of how Demonologist's social and evidence systems work and push
on each other. It replaces the October 20 narrative, which described the legacy belief
system (templates, ledger effects, honesty discounts) retired between Nov 1 and Nov 3.

**Checked against** `main` at `e54c2fd` (Nov 4, 2026). The numbers come from
`sim/tuning.gd`, where every tuning value lives; [tuning_catalogue.md](tuning_catalogue.md)
says where each one is used in code. When the two disagree, `sim/tuning.gd` is right.

**Reading the numbers.** Throughout, **low / mid / high** for a trait means **0.2 / 0.5 /
0.8**. Suspicion, rapport and trust are internal scales, not probabilities: a suspicion of
0.6 is "quite suspicious", not "60% likely to be evil". Worked figures are illustrations
calculated from the formulas, not measurements from play.

---

## 1. What an NPC carries around

Every townsperson has five fixed **traits**, rolled once per case around their cast
baseline:

- **Privacy** guards information about themselves (their gift, their whereabouts, their
  secrets). It's the main brake on disclosure.
- **Gossip** governs passing on information about others: sightings, opinions, rumours.
- **Confidence** decides how hard they defend a hunch, how readily they nominate and vote,
  and whether they lie boldly or stonewall when cornered.
- **Insight** decides how much of what they hold they actually think about, and how far a
  strong-sounding headline sways them.
- **Composure** hides their feelings and nerves, and damps pressure, fear and the dread of
  mounting deaths.

On top of those, each NPC tracks things that change during the case:

- **Rapport with you** (`n.trust`, 0 to 1): how they feel about you. It decides whether
  they open up, agree to requests and approach you.
- **Credibility** (`n.credibility`, 0.1 to 0.9, starting at 0.5): how much your word counts
  with them. It's earned by being right, not by being pleasant.
- **Trust in each other NPC** (0 to 1): friendships and rivalries. This tilts how they
  read evidence about that person, and who they talk to.
- **Suspicion of each other NPC** (0 to 1.5): the belief that drives what they say and how
  they act.
- **Pressure** (from 0, no fixed ceiling): accusations, nominations and presses pile it on;
  it decays by 40% each night. Pressure loosens tongues.
- **Paranoia**: 0.07 per death so far, reduced by up to 60% for a composed NPC. It lowers
  the bar for nominating and voting late in the game.

### How decisions become dice rolls

Most choices (disclose a gift, accept an approach, speak at the meeting) add several named
influences into a score, then turn the score into a chance with one curve. A score of 0 is
a coin flip; +0.25 is about 73%, +0.5 about 88%, +1 about 98%; negative scores mirror
that. Every roll, with its parts and the number actually drawn, appears in the live
decision inspector (Debug ▸ Rolls) and the dev log.

Some decisions aren't rolls but plain comparisons: a vote is yes when the voter's score
reaches their need, and a disclosure tier is set by which band the openness score falls
in.

---

## 2. How a case starts

- **Rapport with you** starts around **0.425**, with a little jitter (−0.05 to +0.1),
  clamped to 0.1–0.9. Privacy no longer lowers starting rapport: it does its work later,
  at disclosure.
- **Trust between NPCs** starts at 0.5 ± 0.05. Friends (rolled per pair) get +0.25,
  rivals −0.25; Secret Lovers trust each other at 0.9.
- **Suspicion** starts at a flat **0.1** of everyone. Friendships and rivalries don't
  touch it directly: they live in trust, and trust enters belief through the prior
  (section 4).
- **Credibility** starts at 0.5 for everyone.

So on Day 1 nobody suspects anyone in particular. What separates people is who likes
whom, and what each NPC knows from their own gift.

---

## 3. Rapport: how they feel about you

Rapport moves in small steps. The common ones:

| Event | Change |
| --- | --- |
| A civil conversation | +0.04, less for the private (down to +0.02 at full Privacy) |
| First time they share their gift with you | +0.03 |
| You offer a ward or vigil | +0.03 on the offer, +0.06 when kept, −0.15 when broken |
| Your ward saves someone (the sigil on the door) | +0.05 with the town, +0.15 with the one saved |
| You keep a secret they confided | about +0.03 to +0.07 the first night (more for the private), halving each night after |
| More than 3 questions in a day | up to −0.08 per extra question (more for the private, less for the composed) |
| Pressing them with evidence | −0.03 to −0.09 (more for the private) |
| A wrong guess at their gift | −0.02 × the number of wrong guesses so far |
| You nominate them | −0.15 |
| You spread a secret they told you | −0.08 to −0.48 (much more for the private), and a cap |
| You break a confidence | −0.05 to −0.25 |
| Clemency for them | +0.15 |

**Caps that don't lift.** Spreading a very private person's secret caps their rapport at
0.3 (0.6 for the middling); nominating someone a good NPC is grieving caps theirs at 0.55.
Apologies can't raise a cap.

**Slights fade.** A drop big enough to count as a grievance recovers a quarter of itself
each night; a serious one (0.12 or more) only up to half. Small knocks collect as friction
and fade at the same rate. **Apologising** for a specific grievance repairs a share of it
(half of a minor one, a quarter of a serious one), counted toward the same limit.

**What rapport buys.** Disclosure (section 7), agreeing to requests, approaching you,
confiding in you. It does *not* make them believe you: that's credibility.

---

## 4. How evidence becomes belief: the shared model

This is the heart of the game, and it's one system for everyone: the player's presented
cases, NPCs' own readings, things they heard from each other, the analyst bot.

### What an NPC holds

Each NPC keeps a ledger of **receipts**: what they actually heard or witnessed, filed by
the underlying fact. Jory's night-1 Seer reading is one fact, whether Jory told them, a
friend passed it on, or it came up at the meeting. Hearing it again adds a new disclosure
to the same receipt, never extra weight. Receipts cover role claims, readings, relayed
sightings and testimony, defences, silences and Demon deaths.

### Possible worlds

When anything an NPC holds changes, the model **refreshes** their beliefs. It enumerates
every possible arrangement of the town (who's evil, who's the Demon, who carries the
secret) and asks, for each world, how well everything the NPC holds fits:

- **A reading** holds in a world or it doesn't. The NPC's own readings are treated as
  nearly certain (an error rate of 0.2%); readings they heard from others at 1%; a Night
  Watch list at 8% (easy to get wrong without lying).
- **A role claim** fits a world if the claimant really holds that gift there, or is evil
  there and could be bluffing it. A bluff is weighted at 0.92 of a true claim, so a bare
  claim is weak evidence, but one claim never makes a world impossible.
- **A sighting** gets a likelihood from the movement model (section 12): how likely is it
  that this person was out on that block that night, in this world?
- **A trace** matches, contradicts or can't speak to the suspect's known haunts and
  workplace, at 3:1.
- **A Demon victim** is good in 95% of worlds. **A refusal or a hint** is weak evidence
  (1.5:1). Opinions and accusations aren't evidence at all, and votes are public
  procedure, never guilt by association.

Then each NPC weighs the worlds through their own **prior**: their odds that a person is
evil start from exp(1.5 × suspicion) and are halved for someone they trust fully, doubled
for someone they don't trust at all. Since suspicion starts flat, the prior is mostly
about relationships: a friend at trust 0.75 starts at about 0.7× the neutral odds, a rival
at 0.25 about 1.4×. So the same evidence lands a little softer on friends and harder on
rivals, which is human, and it's the main way relationships colour reasoning.

Out of this comes a **posterior** for every person: how likely they are evil, given
everything this NPC holds.

### From posterior to suspicion

The change in suspicion is the shift from prior to posterior, scaled down and personalised:

1. **The shift** is how far the posterior moved toward certainty, as a share of the room
   left (a move from 0.2 to 0.6 is half of the way to 1).
2. **× 0.45**, so even a big shift is a moderate suspicion change.
3. **× (0.5 + trust in the sources).** Evidence that's someone's word (a reading, a
   sighting, a claim) is scaled by how much the NPC trusts whoever said it: 1.0× at
   middling trust, up to 1.5× at full trust. Records (a death, a trace, the Town Hall)
   come through at the full 1.5×.
4. **Directional Confidence** (below).
5. **A headline nudge for the less sharp** (below).

A refresh with no new evidence changes nothing, and two NPCs accusing each other can't
spiral: everything is recomputed from the receipts each time, not added on top.

### Insight: how much they think about

Insight sets an **attention budget**. A low-Insight NPC (below 0.34) weighs at most 4
cards and tests 3 rival explanations; a middling one 8 cards and 9 rivals; a sharp one
(0.67 and up) 12 cards, 27 rivals, and checks the whole picture. Cards outside the budget
don't count for that NPC.

Duller NPCs also **take strong readings at their word**. "One of Kiran or Fenwick is the
Demon" sounds like a coin flip between two people; the full model may say "or the red
herring, or a poisoned Seer". A listener at Insight 0 moves all the way to the headline
reading when it's stronger than the model's verdict; at Insight 0.5, halfway; at 1, not at
all. This only ever raises suspicion, never lowers it. It's why a fake Seer "yes" hits a
gullible town hard.

### Confidence: defending a hunch

Each NPC has a **lean**: their suspicion of each person at the end of the previous day,
compared with their own average. Evidence that pushes **against** their lean is resisted:
it's multiplied by 1.4 − 0.8 × Confidence (1.24 for the unsure, 0.76 for the confident).
Evidence that agrees with their lean, or concerns someone they had no strong view of (a
lean under 0.05), comes through at full strength. There's no lean on Day 1. Hard proof (a
posterior at 0 or 1) isn't resisted at all.

So a confident NPC isn't hard to convince in general: they're hard to talk out of what
they already think.

### Source doubt: when someone's word stops counting

Some things make an NPC distrust a source's readings, separately from liking them:

- **A caught lie** in what the listener knows: a whereabouts lie (75% doubt for that night,
  55% for every night), a false sighting of the listener themselves, a second claimant to
  a unique gift the listener holds, a false Night Watch report (50%).
- **An accepted challenge**: "Jory was misled on night 2" (80% doubt for that night),
  "Jory is unreliable" (50%), "Jory is Delusional" (70%), "Jory is lying", capped at 90%.

Poison belongs to the night, not the person, so "misled on night 2" doesn't taint night 3.
A good NPC never doubts their own honesty but can accept that their own reading was
poisoned. A Medium's relayed reading is doubted if *either* the Medium or the dead source
is doubted.

---

## 5. Credibility: whether your word counts

Credibility is your track record with each NPC. Every alignment conclusion you argue to
them (a presented case, a nomination, a meeting statement) is recorded. Each dawn the NPC
checks your recorded conclusions against what they now believe **from their own
evidence**, leaving out your presentations and what you told them, so the check can't go
in circles. A conclusion scores only once their own evidence has moved at least a little
(0.06), unless public proof exists.

Their credibility in you then moves halfway toward 0.5 + 0.4 × your average agreement:
consistently right puts you near 0.9, consistently wrong near 0.1. Formal arguments (cases,
nominations) count fully; casual meeting statements count about a third.

Credibility scales your vote, accusation and defence at the meeting (section 9) and how
far your cards move them (as the "trust in the sources" for anything you told them). A
player with high rapport and low credibility is liked and ignored.

---

## 6. Presenting a case

### Building it

In the Case Workshop you pick a **premise** (someone is evil, the Demon, a minion, lied,
was misled, and so on), add **cards**, click their **answers** (which of the Seer pair,
which blocks), and add **challenges** (misled, lying, unlikely). A neutral **test juror**
(public facts, default trust) labels the case's strength while you build: doesn't support,
weakly, moderately, strongly. It also tells you when a card clashes, which card weakened
the case and who it brought in, what the case mostly raises suspicion of, and when an
assumption isn't doing any work.

Two extra nodes:
- **Profile Info** puts a person's known haunts, workplace, home, traits and bonds into the
  case, which is what traces get matched against.
- **Circumstantial Evidence** adds soft patterns (they shared a location with a silencing,
  they looked nervous under pressure, their sightings fit a walking route): at most +0.015
  per incident and +0.045 per target across all your active cases. It needs a premise,
  can't carry a case on its own, and is kept separate so it can be withdrawn cleanly.

Tavern rumours can't be used: they have no source to weigh.

### What presenting does

Presenting hands the case's cards to the listener as receipts, then the listener's beliefs
are refreshed over **everything they now hold**, not just the case. Separately, a **scoped
reply** reads just the case to decide what they say about it.

Two consequences matter for play:

- **Replies match beliefs.** The stance they voice comes from how far the refresh actually
  moved the subject (0.06 or more: they accept; 0.02: partly; less: they reject). The
  scoped reply only supplies the reasons. So "That makes sense to me" means their belief
  really moved.
- **The premise doesn't steer the belief.** If your case says "Isolde is evil" but the
  cards point at Dorian, the refresh raises Dorian, because it reads the evidence, not your
  framing. The preview's collateral warning ("this mostly raises suspicion of Dorian") is
  there for this. Making the premise matter is on the backlog.

Re-presenting evidence they already hold adds nothing: the receipts are the same. Citing a
case or card that's already public is free, and says so.

Speech the Workshop doesn't judge (asking them to protect or spare someone, a bare belief
with no evidence) gets a social reply: agreement from half their rapport and half how far
their own suspicion already leans your way. It only feeds their protect/spare
preferences.

---

## 7. Getting private information

### The gift question

When you ask about their gift, the NPC computes an **openness** score:

> openness = (1 − Privacy) + 1.2 × rapport + 0.6 × pressure × (1 − 0.5 × Composure)
> + 0.1 × (days since Day 1) − 0.72 + a daily jitter of ±0.1 + gift-specific terms

The jitter is fixed per NPC per day, so asking again the same day can't fish for a better
roll. Gift terms make recurring readers cagey early (−0.45 on Day 1, −0.2 on Day 2 for
gifts that keep reporting), gifts the Demon would hunt cagier still (−0.5 on Day 1,
easing to −0.1 by Day 3), and start-knowledge gifts more open (+0.3).

| Openness | What they do |
| --- | --- |
| 0.15 or less | Refuse |
| 0.15 to 0.45 | A flavoured hint at their gift's family ("my gift deals in records") |
| 0.45 to 0.75 | Name their gift |
| above 0.75 | Name their gift and share their readings |

At starting rapport (0.425) on Day 1, with no pressure, before gift terms:

| Privacy | Openness | Tier |
| --- | --- | --- |
| Low (0.2) | about 0.59 | names the gift |
| Mid (0.5) | about 0.29 | a hint |
| High (0.8) | about −0.01 | refuses |

A Day-1 Seer at middling Privacy drops below zero and refuses. By Day 3, with +0.1
rapport and most of the gift penalty gone, the same Seer is around 0.5 to 0.6 and names
the gift.

Good NPCs never fall back to a lower tier once they've told you something. If rapport
drops afterwards, they withhold *new* readings and say so.

### Fear and protection

Some refusals come out as fear ("If I say what I am, I'll be dead by morning"), likelier as
deaths mount and for the skittish, at the same odds for evil hiding behind a bluff, so it
isn't a tell. A fearful NPC who trusts you at least 0.45 may instead ask for your ward or a
vigil on their block in exchange for their gift. Once you've kept a promise to watch over
them, their fear is halved.

### Questions, fatigue and pressing

- A conversation has **3 questions**. Past 3 questions in a day, each extra one costs
  rapport (section 3). Repeated refusals within one conversation are free.
- **Pressing** with a card raises their pressure (by the card's weight in their own view,
  at least 0.3), costs a little rapport, and may show nerves: about 60% × (1 − Composure) ×
  strength if they're hiding something, 20% otherwise. Nerves are a hint, not a tell.
- A card about **their own night** makes them account for that night; a card about
  **their gift** re-runs the disclosure decision (a true Clerk reading naming them opens
  them up); a **rival's claim** of their gift makes them restate it and turn on the rival.

### Night accounts

Asked where they were at night:
- An NPC with a known walking gift names its duty (the watch kept, the door guarded, the
  hearth visited). Evil bluffing a walking gift does the same from its bluff.
- A good NPC out for a secret either confesses, lies or stonewalls. Confessing gets likelier
  with rapport (around 0.6 and up), pressure and low Privacy; Confidence decides lying
  boldly versus stonewalling. The Sleepwalker honestly says "home".
- A rattled NPC who claims home may let slip what they saw elsewhere (more likely at low
  Composure and high pressure): a catchable contradiction.
- Direct questions about who they saw at night get an answer 95% of the time.
- Caught out by a sighting, a good walker owns the earlier "home" story ("So yes: I was
  out…"). The real Sleepwalker (under pressure) and evil bluffers can claim sleepwalking.

### Opinions and gossip about others

Asked their opinion of someone, everyone answers: there's no hard Gossip cutoff on a
direct question any more. How much they add (haunts, recent sightings, second-hand gift
talk) scales with Gossip and rapport. Daytime memory is short for the dull (about 2 people
remembered plus up to 4 more with Insight).

---

## 8. Going public at the meeting

### Testimony

Testimony streams speaker by speaker. Each NPC decides whether to **claim** their gift
publicly (openness, the day, pressure, gift kind, strongly up with four or fewer alive);
going public shares every reading they hadn't shared.

**Accusations** climb tiers: silent → generic ("I don't trust X") → **hint** ("I have a
reason, but I'm not ready to share it") → **reveal** (claim the gift and give the reading).
Accusing at all depends on how far their suspicion of X sits above 0.6, Confidence, and
pressure (an accused NPC may deflect). Hint versus reveal weighs the reading's strength
and their suspicion against a **reveal cost**: Privacy, fear, gifts that hide from the
Demon or keep paying off, falling about 0.12 a day and sharply with four or fewer alive.
Evil with nothing citable hints 30% of the time, so a hint isn't proof of good.

**Reactive testimony:** when a statement names someone, claims their gift, or touches a
clearing reading they hold, that person gets +0.35 openness and moves up the queue, once
per meeting each. **Fading into the crowd:** once several substantive turns have been
taken, private NPCs (Privacy above 0.45) are less inclined to add their own.

### Defences

A nominee answers the case against them with one or two moves: reveal a walking gift to
explain a sighting, confess a secret (good only), the sleepwalk excuse, or against a
reading, "red herring", "it's the other one in the pair", "they're lying" (if confident)
or "they were misled". Reveals, confessions and challenges enter listeners' ledgers as
claims and challenges the model weighs; pleas are just speech and barely move anyone.
A cap keeps a single reveal or confession from undoing a strong case on its own. **Block safety:** when
someone else is already firmly on the block, a nominee is less likely to burn a secret or
reveal a gift to save themselves (they don't need to).

---

## 9. Nominations and votes: the action layer

Belief isn't action. When NPCs nominate or vote, three things are added to suspicion:

- **Crowd pressure:** each accuser at the meetings adds pressure toward their target,
  weighted by how much the listener trusts them (0.09 for the first voice, about half that
  for each further one, ×1.15 for a hinted accusation), fading to 60% a day, capped at
  0.22. It never touches belief.
- **Execution priority:** from the same posteriors as suspicion, how far each person
  stands above the NPC's average, plus a bonus of 0.10 for their top two suspects (if they
  stand at least 0.12 above average). It enters at weight 0.22. This lets a credible lead
  make someone actionable without inflating belief.
- **Private resentment:** a mourning friend of someone hanged resents the nominator and
  the yes-voters, which colours later nominations and votes. It fades nightly and clears if
  the hanged friend is later shown evil.

### Nominating

A good NPC nominates the top candidate whose action score clears a bar:

> bar = max(0.40, 0.65 − 0.05 × day) − 0.2 × (Confidence − 0.5) × 2 − 0.5 × paranoia

So Day 1 needs about 0.60 from a middling NPC, Day 3 about 0.50, Day 5 the floor of 0.40,
lower still for the confident and as deaths mount. After a failed vote, renominating the
same person the next day is harder (more so for the same nominator), easing late in the
game.

### Voting

Each voter adds up:
- action suspicion of the nominee (suspicion + crowd pressure + execution priority);
- your stance, scaled by their **credibility** in you: voting yes adds 0.18 × credibility −
  0.04; accusing adds 0.15 × credibility; defending subtracts 0.25 × credibility;
- −0.15 if they suspect the nominator heavily (0.7 or more);
- a spare preference you talked them into;
- −0.4 if someone they suspect at least as much is already on the block;
- role reluctance (a Martyr hesitates to hang their chosen).

They vote yes if the total reaches their **need**:

> need = 0.52 − 0.12 × (Confidence − 0.5) × 2 + 0.1 (on Day 1) − 0.2 × paranoia − 0.02 × deaths

| Voter | Day 1, no deaths | Day 4, 3 deaths (mid Composure) |
| --- | --- | --- |
| Low Confidence | 0.69 | 0.50 |
| Mid Confidence | 0.62 | 0.43 |
| High Confidence | 0.55 | 0.36 |

A nominator always backs their own nomination (unless they'd rather keep someone else on
the block). The nominee needs half the voters, rounded up, you included.

The gap that playtests keep hitting: an NPC can accept a case (their suspicion moved
0.06+) and still sit well under 0.5, so they vote no. That's the "agreement has to reach the
vote" backlog item, and the reason for execution priority.

---

## 10. Information that travels without you

### Who talks to whom

Each phase some idle NPCs pair off. A pair's weight is about (their mutual trust − 0.3) ×
2, plus a **news bonus** (+0.6 for evil with fresh intel for a teammate, +0.5 for a good
NPC with news for a friend they trust above 0.6), plus a nudge for gifts that seek
conversation (the Psychologist), capped at 2. The silenced barely pair at all. Some pairs
form before you pick where to go (visible from anywhere), others after you act (seen only
from their block, at 0.4 of the weight). Everyone has at most one NPC conversation a day.

### What gets passed on

Each partner passes one item, chosen by how newsworthy it is and how willing they are: an
unshared reading (more open with friends), a confided secret (only to close friends), an
opinion (if their suspicion is 0.5+, scaled by Gossip and Confidence), a case you made, a
night sighting (Gossip-scaled, more for one near a murder scene), hearsay. Readings and
sightings become receipts in the listener's ledger, credited to who told whom. Nothing is
echoed back to the person who told it.

**Gift talk between friends:** an NPC may hint at their gift's family to a friend (bond
0.55+) or claim it outright (0.68+, or 0.55+ under pressure), even with no readings yet.
Good NPCs with an untold gift count as having news on Days 1–2. Evil does the same with its
bluff. Gift talk isn't relayed further, and an evil listener notes the speaker as a
target.

**Gossip and the teller:** passing on gossip the listener believes builds +0.02 trust in
the teller; running down someone the listener trusts (0.65+) costs 0.02.

**Meetings move trust too:** a surviving nominee loses 0.1 trust in each yes voter and
gains 0.03 in each no voter; the target of a public accusation loses 0.1 trust in the
accuser.

### The tavern

In the evening the tavern's conversations finish, and listening there gives you 3–5
anonymised items from the day's shares, backfilled with haunts and public bonds you
haven't learned. They arrive as rumour cards: a lead, not evidence.

### Approaches

At the start of some phases (40% chance) an NPC may come to you: with news (if they trust
you 0.5+), a busybody with gossip (Gossip 0.6+), a fearful NPC wanting protection, or evil
with a frame or a probe. Accepting costs the phase.

---

## 11. Evil

### Two minds

Each evil NPC runs a **shadow good self**: a full good mind whose gift is its bluff, fed
everything that NPC really heard. Its public behaviour (replies, opinions, nominations,
votes) follows the shadow, so evil sounds like a reasonable townsperson. It breaks cover
only when

> stakes − deviation × exposure > caution

- **Stakes:** mostly a teammate's value (Demon 2, minion 1; while a Scion could take over,
  the Scion 1.45 and the Demon 1.1) × how much danger they're in or how pivotal the vote
  is, or the value of pushing a good nominee (more for the scapegoat). In a landslide
  against a teammate, a non-pivotal "no" has little stake, so evil keeps cover.
- **Exposure:** public talk about them, your known suspicion of them (+0.3), their
  pressure, being on the block (+0.2).
- **Caution:** the Demon starts at 0.8 and loses 0.03 a day (floor 0.45); minions start at
  0.7 and lose 0.08 a day after Day 2 (floor 0.25). Late in the game minions throw caution
  away.

Without a Scion to fall back on, a Demon on the block backs any live counter-nomination:
survival beats cover.

### The scapegoat and the frame

Evil picks a scapegoat at setup (people the Demon knows walk at night, people it distrusts,
public Warden or Veteran claimants) and re-picks each morning from Day 2 on momentum
(public heat plus its good selves' suspicion), fit (fake readings and sightings already
naming them), dead ends (public clears) and a cost for switching. Evil rides the town's
own mistakes, so misdirecting the town can matter.

One evil NPC a day may act as a **planter**, whispering to a gossip-prone NPC who trusts
them (at most 2 direct plants a day). Fake sightings are cached, not rerolled, so evil's
story stays consistent.

### Bluffs

Every information gift has its own bluff rule built around the scapegoat and the team. A
fake Seer never clears the scapegoat and frames every night once five or fewer remain; a
lone evil Seer never puts itself in its own pair. A fake Medium relays something useful to
evil about half the time after its first frame.

### The night

**The kill** scores each candidate: +3 for a public info claim (+1 if the gift is spent),
+2 for readings implicating evil, hostility, +0.7 for living alone, +1.5 from temperament
(vengeful toward the distrusted, cunning toward the scapegoat's block, hungry at random),
−4 to keep the scapegoat alive while more than four live, −1.5 for someone spared by
Clemency, −10 after a failed attempt on them, −0.8 for a likely warded door, and −6 / −4
for a vigil or ward **you promised** an evil NPC (the team shares it). Random noise only
matters between close candidates, and 3% of nights the Demon skips its top three.

**The Poisoner** skips gifts poisoning can't stop tonight (−3.5), favours a suspected
Warden when the Demon is going for someone prominent (+2.5), and avoids a promised vigil
block (−4.5).

---

## 12. Movement and physical evidence

### Who's out at night

The movement model's rates, used for every sighting's likelihood: a good person with no
walking gift is out about 5% of nights; on a walking-gift duty, always; with a night
secret (Lovers, Sleepwalker), about 55%; a minion about 25%; the Demon, on a kill night,
goes to the victim's home (with a 5% allowance for a detour).

In the live sim, a walker on the street is seen by someone else out on their route 50% of
the time, from a home window 15%, and a neighbour notices someone stayed in 20% of the
time (a weak, true alibi).

### Why one sighting is so loud

Being seen out on a kill night when you have no walking gift is a 5% event for the good and
close to certain for the Demon, so one sighting is a large likelihood ratio. "Claimed a day
gift, seen out at night" reads as open-and-shut, and that's on the balance watch list.
Being seen on a block away from the murder argues strongly the other way: the Demon had
somewhere to be.

### Vigils

Your vigil sees walkers **arriving** on the block (and anyone doing the full lamp round),
not people passing through. It's unlimited and free, so it's still strong.

### Traces and drops

Each murder leaves a trace pointing at places the killer frequents: a token naming two
locations or a scent naming three, chosen so a match fits roughly 60–85% of the town. A
trace that matches someone's known haunts or workplace is 3:1 evidence; one that
contradicts them argues against. When another walker passed the cottage, 45% of scenes
carry a second trace from the passer, and the model scores both assignments together.

Walkers drop things on their route (the Demon 35% of nights, others 15%): mostly home-block
materials, sometimes (12%) a personal item that puts its owner out that night.

---

## 13. The interactions most likely to decide a case

These are the places where small numbers compound:

1. **Night sightings.** One sighting of a non-walker on a kill night is a big ratio, and
   Insight-light listeners take it near face value. Hidden night walkers (an unclaimed
   Lamplighter, Warden or Sleepwalker) get hanged for it.
2. **Fake Seer yeses and the headline nudge.** The full model hedges a "yes" with the red
   herring and poison; duller listeners don't. A confident, public fake Seer can steer a
   low-Insight town.
3. **Agreement versus action.** Belief moves in small steps (0.45 × shift, trust-scaled),
   while the vote need sits around 0.45–0.6. A town can agree with a case for days and
   never hang anyone. Execution priority and late urgency narrow the gap.
4. **Relationships in the prior.** Trust halves or doubles the starting odds, so evidence
   against a well-liked NPC lands softer, and a rival gets hanged on less.
5. **Privacy on Day 1.** With no rapport built yet, middling and private NPCs hint or
   refuse; how many private characters are dealt sets how fast the first day goes.
6. **Credibility as a slow lever.** It only moves at dawn, toward your track record. Early
   wrong accusations cost you votes for days.
7. **Directional Confidence.** Once a confident NPC leans one way, contrary evidence moves
   them at three-quarters strength. A wrong early lean in a confident voter sticks.
8. **Evil's cover economics.** Evil keeps cover cheaply in votes that aren't close and pays
   for it in arguments; with a Scion in play it protects the Scion over the Demon.

---

## 14. Where to look

- **`sim/tuning.gd`**: every number, in nine classes (`Setup`, `Roles`, `Mind`, `Trust`,
  `Social`, `Meeting`, `Dialogue`, `Evil`, `Workshop`) plus `Presentation`.
- **[tuning_catalogue.md](tuning_catalogue.md)**: which code uses each number.
- **The decision inspector** (Debug ▸ Rolls): every roll with its parts, live.
- **The dev log** (`logs/`): `suspicion` entries show every change with its cause, and
  the `.trace.jsonl` sidecar's `workshop_*` entries show each presentation and ownership
  update; `think` entries show lies, overrides and evil's reasoning;
  `tools/trace.py` filters it.
- **[DESIGN.md](DESIGN.md)** says what each system is for; this file says how the parts
  push on each other.

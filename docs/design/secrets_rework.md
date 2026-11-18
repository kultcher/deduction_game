# Secrets: a rework (design note)

**Status: backlogged (Michael, Nov 17; BACKLOG section 4). Direction in section 2, with Michael's Nov 18 decisions (good NPCs lying about their gift, unique secrets, one hidden kind per script); nothing built.** Started
Nov 17 from a talk between Michael and Claude-Vicar. Whoever builds it: Lantern and
Quill (the judge), Beadle (how NPCs claim, hide and bluff), Herald (wording, UI).
Performance figures here are counts read from the code, not timings; Argon would measure.

---

## 1. Why rework them

Secrets came from an early pitch in which the social side was more pronounced. They read as
a twist on Clocktower's Outsiders. Michael's three problems with them as built (Nov 17):

1. **Inconsistent disclosure.** Three of the defaults (Delusional, Marked, Sleepwalker) are
   hidden even from their holder, while the Lovers can claim at any time. The implied
   social cost of "secret lovers" has no way to show itself. Because most holders don't
   know, the secrets can't interact much with other mechanics.
2. **They don't help evil hide.** Holders must be good, so any confirmed secret is a
   confirmed good. Michael suspects this is why the Lovers win so often. (Not measured in
   the repo; Tally could pull it from sweep records.) It is built into the code: no path
   lets evil fake a Lovers confession, so the judge treats one as proof of both partners
   (`Solver.lovers_needs`, #162). Several gifts are designed around it too: the Rumormonger
   names two people because one name would clear them, and the Chronicler's trio names
   "one carried a secret".
3. **Lost design space.** Outsiders who want or need to hide give good people reasons to
   lie, which muddies the waters. The current secrets mostly can't do that.

## 2. Michael's direction so far (Nov 17)

- **Secrets stay riders on a gift,** not a gift-less character type. "This role × this
  secret" is part of the appeal: a Marked secret on any gift is more interesting than a
  plain Clocktower Recluse.
- **The Muddler: tentatively cut.** It can't work without stretching the rest of the game
  around it (BACKLOG section 4: it had something to muddle in 5 games of 40).
- **The word "secret" may be the limit.** Most secrets work better as something a good NPC
  knows about themselves and doesn't volunteer, but doesn't really try to hide either.
- **Worked example: a Saint** without Clocktower's "you lose if they're executed". It has
  some other penalty. The holder knows, and claims it under pressure or when nominated.
  Evil can bluff it.

### Decided, Nov 18 (Michael, with Claude-Vicar)

1. **Good NPCs may lie about their gift, but only with a reason.** It should be fairly
   uncommon, and possibly tied to Confidence. The main reasons:
   - **avoiding the Demon's attention** (a valuable gift claiming something less
     threatening);
   - **drawing it** (a Veteran-like gift claiming something the Demon wants dead).

   A good liar **doesn't volunteer the lie**; it gives the false claim only under pressure.
   It picks **the most harmless lie it can**. More in section 10.
2. **Every secret is unique:** at most one holder of each kind per game (the Lovers count as
   one pair). Michael: it keeps things fairer. A second claim of the same secret means
   someone is lying, as with gifts.
3. **Some truly hidden (self-unaware) secrets stay,** probably Delusional and Sleepwalker,
   but **they are mutually exclusive at the script level,** to keep the judge's work in
   check. A script carries at most one of them. Marked's place is not settled.

**Not decided yet** (Michael, Nov 18): plain folk (non-gifted townsfolk) and the specifics of
confidants. Both are in section 10.

## 3. The proposed structure: two kinds

| | Self-unaware kinds | Knowing kinds |
|---|---|---|
| Today | Delusional, Marked, Sleepwalker | Lovers (the Muddler is self-unaware but would be cut) |
| Future | (more only if the cost allows) | Saint, and others |
| Holder knows? | No | Yes; doesn't volunteer, claims under pressure |
| Evil can claim it? | No (the holder can't claim it either) | Yes, as a bluff with a logged reason |
| What it does | Bends evidence: a reading is wrong, a person reads as evil, someone is out without knowing | Changes behaviour or outcomes: reasons to be out or to lie, a penalty on hanging |
| How the judge handles it | **Enumerated,** as now: each possible arrangement says who holds it | **Not enumerated.** Once claimed it's an ordinary claim; unclaimed it's a general allowance, plus whatever the player argues |

### Why the judge can skip the knowing kinds

- **Once claimed, the claim does the work,** as gift claims do now. In an arrangement where
  the claimant is good, the secret is real; where they're evil, it's a bluff. No new slot.
- **Unclaimed, a general allowance:** the town allows that "a good person sometimes has a
  quiet reason to be out or to say less". That is softer than today's reading of a caught
  lie, so it touches every case. It also overlaps BACKLOG's "Night sightings are too
  decisive" (which wants a higher ordinary out-rate) and "Good NPCs lie tactically".
- **The cost of skipping:** NPCs stop thinking "maybe he's the Lover" on their own. They
  can only think "people sometimes have reasons", until the player says it (3a).

### 3a. The player can still argue an unclaimed secret

When the player presents "Hollis is a Lover" (or a Saint, or Marked), the listener weighs
that case with one extra either/or: Hollis holds it, or he doesn't. It holds only while the
listener holds the case.

- **Cost:** about double the work for that one case's judgement, not for the whole town.
  Several such cases don't interact.
- **What it buys:** explaining away. If Hollis is a Lover, his false "I was home" and his
  night sighting have an innocent reason, and suspicion of him falls. The case needs
  evidence the secret would leave: out on the nights the partner was, a lie about only
  those nights.
- **Evil can push the same case** for a teammate ("she's only out because she's in love").
- **The two rates must match.** The case's either/or starts from the same rate as the
  town's general allowance, or presenting it counts the innocent explanation twice.
- **Today's nearest thing:** "X is the Marked" can be presented now because the judge
  enumerates the secret; "X has a secret" can't, because nothing establishes it. This
  turns the second into something the player can argue.
- **Cheaper alternatives:** challenge one card ("Hollis had a reason for this lie"), like
  the existing "misled" challenge, which names nobody as a holder; or get a confession by
  pressing the holder with the case (Beadle), which becomes a claim card evil can also fake.

## 4. What it costs, and what it frees

At 10 NPCs the judge works through 120 ways to pick the three evil, times 42 ways to place
the secret (7 good people × 3 one-person secrets, plus 21 Lovers pairs): **5,040
arrangements**, or 15,120 with the Demon told apart from the Minions
(`workshop/cs/WorldDomain.cs`, `EnumerateWorlds`).

| Change | Arrangements per alignment | Effect on the count |
|---|---|---|
| Today | 42 | 5,040 |
| "No secret this game" allowed | 43 | about +2% |
| Up to two secrets | several hundred | about 10× |
| Proposed: only the three self-unaware kinds enumerated | 21 | 2,520 (half) |
| No secrets enumerated at all | 1 | 120 |

- **Riders and character types cost the same.** Either way an arrangement has to name the
  holder. The cost is in how many hidden slots there are, not in what they ride on.
- **The real saving is smaller than the count.** A first-time judgement has no single
  dominant part (Lantern's profile, Nov 14). Some work scales with the arrangements and
  some doesn't. A guess: a few times faster at most, not by the full ratio. Argon to measure.
- **Where freed room could go:** on what the player can argue, not on sharper NPCs
  (CLAUDE.md: a more accurate NPC isn't better for that reason alone). Candidates:
  - **Telling the Minions apart:** roughly doubles the arrangements at 10 NPCs. The judge
    doesn't track which Minion holds which gift today, which is the Breathstealer bug Quill
    found (BACKLOG section 4). It feeds the Breathstealer overhaul.
  - **Larger towns** (12–15, BACKLOG [watch]).
  - **Speed:** late presentations are near the 2-second budget.
- **A code limit:** an arrangement holds one secret kind today (Lovers use two holders of
  the same kind). Two different self-unaware secrets at once would need that format
  reworked.

## 5. Worked example: the Saint

A knowing secret on any good gift.

- **Penalty:** not "good loses". Lantern's Clocktower shortlist
  (`docs/archive/project-docs/role-shortlist-2026-11-11.md`, section F) has "hanging it
  gives evil two kills that night". Other options are open.
- **Behaviour (Beadle):** doesn't volunteer it. Claims it when pressed or nominated. Evil
  bluffs it, most usefully to shield itself from a hanging.
- **The judge:** a claim, plus a public outcome at the hanging. The penalty fired, so the
  claim was true; it didn't, so the claimant lied. That reads like the Martyr's
  promise-then-hanging check (Quill, #183). Before the hanging, "is the Saint" is
  enumerated nowhere.
- **The balance to watch:** the heavier the penalty, the stronger "I'm the Saint" is as a
  shield for evil until someone calls it. A hanged bluffer is exposed when nothing happens.
- **Shared machinery:** the shortlist notes that every "hanging with a consequence" role
  (Goblin, Saint, Fearmonger, Moonchild, Klutz) needs NPCs to weigh what a hanging would
  cost, not only how suspicious someone is. Today a vote weighs suspicion only. Build it
  once, generally (Beadle for votes; Lantern if it enters belief).

## 6. Worked example: a Baron-like Minion

A Minion whose presence adds secrets to the town. Can the extras come from the full list?

- **Knowing kinds: yes, at no cost.** More claims don't add slots. Two things follow:
  - The town's general allowance should know such a Minion may be in play. If the judge
    tracks Minion identities (section 4), that's simply part of each arrangement.
  - Several secret claims in one town become evidence that the Baron is here, as in
    Clocktower.
- **Self-unaware kinds: limited, or costly.** One more slot on a different good person is
  about 9× the arrangements in games where the Baron is present. Three ways:
  1. **The extras are knowing kinds only.** Free and simple; one self-unaware slot per game.
     *(Vicar's lean.)*
  2. **The judge enumerates the first; the player argues any extra** ("X is also Marked"),
     with the either/or of 3a. Risk: once the judge settles one person as Marked, it rules
     out a second for anyone else. Unless the player argues it, a good person can look
     damned with no innocent explanation the town considers. NPCs needn't reason
     perfectly, but it's a solvability risk to watch.
  3. **Enumerate two self-unaware slots in Baron games only.** Accurate and costly. Only
     affordable if the freed room goes here and not to Minion identities.

## 7. What changes for what exists

- **Delusional, Marked, Sleepwalker:** unchanged. They remain the one enumerated slot.
- **The Lovers become a knowing kind.**
  - Evil can claim to be a Lover, so `Solver.lovers_needs` (confession as proof) must go.
    Bailiff's #162 note flags this as a landmine.
  - Their nights out are no longer explained by the judge unless claimed or argued.
  - Their "social cost" still needs a form: what does it cost a Lover to admit it?
- **The Muddler:** tentatively cut.
- **Gifts built on "a secret means good":** the Rumormonger, the Chronicler's trio, and
  any role check on a secret holder (`sim/roles/*.gd`: Augur, Confessor, Executor,
  Gravedigger, Magistrate, Martyr, Monitor and Registrar all read secrets). Each needs a
  look once evil can claim knowing kinds. The Rumormonger's two-name rule may no longer be
  needed for knowing kinds.
- **The benched flavour secrets** (insomnia, smuggling, debt; `C.USE_FLAVOR_SECRETS`) were
  benched because they put too many innocents out. They are knowing kinds by nature, so
  this structure is where they'd return, if ever.

## 8. Open for Michael

1. **The two-kind split itself:** one enumerated slot for self-unaware kinds, everything
   the holder knows about as ordinary claims. *Partly answered Nov 18:* the hidden kinds are
   mutually exclusive by script, probably Delusional and Sleepwalker. Still open: Marked's
   place, and whether the knowing kinds leave the enumeration.
2. **The unclaimed knowing secret:** is the per-case either/or (3a) worth building, or are
   card challenges and confessions enough?
3. **The town's general allowance:** how much a caught lie or a sighting should be
   softened by "good people sometimes have reasons". This touches every case.
4. **The Saint's penalty,** and whether hanging consequences become a shared mechanic.
5. **The Baron's extras:** option 1, 2 or 3 in section 6. With one hidden kind per script
   (Nov 18), a Baron's extras can't be a second hidden kind, which points to option 1.
   Since secrets are unique, the extras must also be kinds not already in play.
6. **The freed budget,** if any: Minion identities, larger towns, or speed.
7. **The Lovers' social cost,** now that they're a knowing kind.
8. **Good lying about a gift** (section 10): how Confidence enters, what counts as "most
   harmless", and how the judge allows for it.
9. **Confidants** (section 10): how many real secrets start known to someone, and how far
   it spreads.
10. **Plain folk** (section 10): whether to bring back non-gifted townsfolk, and their
   counts by town size.

## 9. The staged plan (for when it's picked up)

Backlogged by Michael on Nov 17 (BACKLOG section 4, "The secrets rework"): smaller backlog
items first. The plan below is Seneschal's, as put to him.

**Stage 1: feasibility reports.** Read-only; they can run in parallel.
- **Lantern and Quill:**
  - The per-case either/or (3a): can a case carry it? How does it interact with stored
    cases that fade and are re-weighed? What does it cost?
  - What reads the Lovers if they leave the enumeration: `Solver.lovers_needs` (#162),
    the role checks, tests, golden?
  - Where would the general allowance plug in without counting twice with 3a?
- **Quill:** an audit of the gifts that assume a secret means good (the Rumormonger, the
  Chronicler, and the role checks in `sim/roles/*.gd`).
- **Beadle:** how much of the hide-a-gift and claim-under-pressure code carries over to
  knowing secrets, and what evil needs to bluff one with a logged reason.
- **Argon:** time a judgement with the Lovers dropped, and with no secrets.
- **Tally:** the Lovers' win rate and secret-holder outcomes, from existing sweep records.

**Stage 2: a disruption prototype** on a `mock/` branch.
- The Lovers become a knowing claim that evil can bluff, with no enumeration.
- The general allowance is run at none and at small.
- Paired sweeps against main on the same seeds compare win rates, how decisive night
  sightings are, wrongful hangings, and solvability.
- Then Michael playtests it.

**Stage 3:** Michael and Vicar settle section 8, then Seneschal briefs the builders.

**Timing:** decide it alongside the Breathstealer overhaul, since the room freed here could
go to telling Minions apart, which the overhaul needs.

## 10. Good NPCs lying, confidants and plain folk (Nov 18)

From a talk between Michael and Claude-Vicar on Nov 18. Section 2 has the three decisions;
this section has the reasoning and what's still open. Code facts are read from main, not run.

### 10.1 Good NPCs lying about their gift (decided in direction)

**What changes for the judge.** Today a good, healthy teller's gift claim is taken as true,
and no two people hold the same claimed gift (`WorldDomainKernel.ClaimsCompatible`, the
role check in `ReadingFraction`). So a double claim means one of the two is evil, and that
is one of the player's strongest tells. With good lying, a good person's claim becomes
"very probably true", and a double claim becomes "very probably one evil".

- **Keeping it uncommon keeps the double claim readable.** That's the point of Michael's
  "relatively uncommon".
- **The nearest precedent** is lie severity: a good person's own "I was home" is no longer
  certain (`Tuning.Workshop.GOOD_OWN_ALIBI_OUT`, 0.2, Quill). The same kind of allowance on
  gift claims would add no arrangements to work through. A new constant is Michael's call.
  Tracking *who* is lying would add arrangements: Argon to check the math.
- **Each lie has a logged reason,** as evil's do. The two reasons are avoiding the Demon's
  attention and drawing it.

**Behaviour (Beadle).**
- **Fairly uncommon, possibly tied to Confidence.** Which way it leans is open. A confident
  NPC may be more willing to run a bluff; an unconfident one may be more inclined to hide.
- **The liar doesn't volunteer it.** It keeps its head down and gives the false claim only
  under pressure, through the existing disclosure model (pressure, being nominated, trust,
  Privacy against a reveal cost; `Tuning` "reveal_early_*", `REVEAL_COST_*`).
- **The most harmless lie available.** A suggestion, not decided: claim a gift whose
  readings needn't name anyone, or one that only clears, so the lie frames nobody.
- **Open: when it comes clean.** For example, when it's nominated, or once its reason is
  gone (the Demon's dead or it no longer needs cover). Coming clean reads as a public
  revision, so it ties into "Believable public revisions" (BACKLOG section 2, `[decided]`
  Nov 18). Evil will use the same move.

**For the player.** A new skill: telling which side of a double claim has a reason to lie.
The risk is noisier anchors. Keeping the reasons to two, both about the Demon, keeps them
guessable.

### 10.2 Unique secrets and evil's bluffs (decided: unique)

- **Once secrets are unique, a bluffed secret can be called by its real holder.** This
  splits the knowing kinds by value:
  - **High-value ones (the Saint):** high-risk, high-reward bluffs, best used when cornered
    or when the real holder is likely dead or silent.
  - **Low-value ones:** safe, but they shield less.
- **A collision is fine if it's a reasoned choice** with a logged reason. It gives the
  player something to read, and a counter-claim may drag the real holder down too.
- **The Baron:** evil knows its own team, so it knows whether a Baron is in play. With a
  Baron there are more real holders and a higher chance of collision, so evil should claim
  secrets more warily. A town seeing several secret claims learns a Baron is likely.
- **The tuning target:** evil bluffs a secret often enough that a claim is ambiguous, but
  not so often that bluffing becomes a tell. The no-gift denial
  (`Tuning.Setup.ALLOW_NO_GIFT_DENIAL`, off because evil almost never bluffed it) and
  today's Lovers show what goes wrong when only one side ever makes a claim.

### 10.3 One hidden kind per script (decided)

A rough count, from the code and not timed. Section 4 has today's figures: 42 placements
per evil team at 10 NPCs, so 5,040 arrangements. Suppose two things hold:
- the Lovers leave the enumeration as a knowing kind;
- the script names its single hidden kind (Delusional or Sleepwalker).

Then the judge places one holder among the 7 good people, which is 840 arrangements, or 960
if "not dealt this game" is allowed. That is about a sixth of today, before Minion identities
or larger towns spend the room. As section 4 says, the real speed-up is smaller than the
count; Argon would measure it.

Still open: whether Marked stays as a hidden kind in the same exclusive group, becomes
something else, or goes.

### 10.4 Confidants: secrets known to others (not decided)

Michael's idea: deal some secrets as already known to another townsperson, so that gossip
can expose them. This answers "semi-hidden secrets are annoying" without making the holders
chatty.

- **Code precedent:** the day-1 gift confidant (`npc.confided`, `Social._gift_disclosure`,
  `Tuning.Social.SHARE_ROLE_CONFIDE_BONUS`).
- **What it buys:**
  - The player finds a secret by asking around, not only by pressing the holder.
  - The gossip network gets a job.
  - The self-unaware kinds gain the one route that suits them, someone else noticing (a
    neighbour saw the Sleepwalker out).
- **Risks:**
  - **The silence becomes a tell.** If every real secret has a confidant, a bluff nobody
    has heard of looks fake. Two fixes:
    - only some real secrets start with one;
    - evil can vouch for a teammate's bluff ("she told me weeks ago").
  - **Too fast a spread** makes every secret public by day 2.
  - **The Rumormonger overlaps.** It starts knowing "one of two carries a secret", which
    is less special once confidants exist.
- **The judge:** a confidant's report is hearsay, weighed by trust in the teller, like a
  relay. Nothing new to enumerate.
- **A social cost:** a confidant who blabs loses the holder's trust. That reuses
  "using a confessed secret costs trust" and gives the Lovers' admission a cost. It should
  stay on existing rapport: Michael tabled a second NPC-to-NPC number on Nov 18.
- **Open:** what share of secrets start with a confidant, who is chosen (a friend, a
  relationship), and how far and how fast it spreads.

### 10.5 Plain folk and town sizes (not decided)

**The aim (Michael):** secrets are a balancing knob against good's numbers, short of a
whole extra Minion. Today the setups are fixed (`Tuning.Setup.SETUPS`):
- 7 NPCs: 5 town, 1 Minion, 1 secret;
- 10 NPCs: 7 town, 2 Minions, 1 secret.

Letting the handicap flex would fill the sizes between. A secret is a soft handicap, though:
the holder keeps a working gift (Delusional is the exception). Non-gifted townsfolk would be
a real one.

**Plain folk, as an option:**
- **The no-gift denial comes back with a reason.** If the script says the town has plain
  folk, evil has a reason to bluff "I'm plain": a low-profile claim the Demon has less
  reason to kill. The denial stops being near-proof of good.
- **Outsider math without good having to lie:** "two plain folk" with three claimants
  means one is lying. A Baron could be "two gifts become plain folk".
- **They still play:** they have secrets, relationships, sightings and voices. In "New role
  hint families" (BACKLOG section 3) they'd be the "no gift" answer.
- **For the judge:** several people can hold "plain", so it can't use the
  one-person-per-gift rule. A public count of plain folk becomes a new check (no more good
  claimants than the script allows). It's probably a check on claims, not a new hidden
  slot; Quill and Argon to confirm.
- **Michael (Nov 18):** not ready to decide; possibly a messy can of worms.


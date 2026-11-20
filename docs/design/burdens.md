# Burdens: the secrets rework, scoped (design note)

**Status: draft for Michael (Nov 20, 2026). Scoping only. Nothing is built, and the open
questions are in section 7.** Written by Claude-Vicar from a talk with Michael on Nov 20. It
builds on [secrets_rework.md](secrets_rework.md), which keeps the earlier reasoning: the two
kinds, the Saint and Baron worked examples, confidants and plain folk, and Argon's review.
Where the two disagree, this note is the newer one.

---

## 1. Decided so far (Michael)

- **"Secrets" become "burdens"** (Nov 20). The word contrasts with "gifts": a gift is what
  someone can do, a burden is what weighs on them. It covers things nobody hides, such as a
  hanging penalty or a vow. It's the player-facing name. NPCs name the specific burden
  ("I don't sleep easy"), never "my burden".
- **At most one hidden burden per script** (Nov 20; first decided Nov 18 as "the hidden
  kinds are mutually exclusive by script"). A hidden burden is one its holder doesn't know
  about. Every other burden is known to its holder: it doesn't volunteer it, but it doesn't
  really hide it either. Only the hidden one is enumerated by the judge.
- **Still standing from Nov 18** ([secrets_rework.md](secrets_rework.md) section 2):
  - every burden is unique: at most one holder per game, so a second claim means someone is
    lying;
  - good NPCs may lie about their gift, but only with a reason.
- **The Muddler is cut** (Nov 20).
- **Names** (Nov 20): **Carouser** is locked in. **Ill-Omened** is the working name for the
  hanging-penalty burden.
  - Considered and set aside: Plagued, Omen, Haunted (too close to the Revenant), Forsaken,
    Sinless, Innocent (clashes with "innocent" meaning good), Beloved (collides with
    Unrequited).
  - Carouser's alternatives were Boon Companion, Reveller, Tippler and Barfly.

## 2. The slate

### 2.1 The first slate (Michael, Nov 20)

| Burden | Kind | What it does, in short | Who it tends to help |
|---|---|---|---|
| **Delusional** | hidden | Kept as built: the holder's gift gives false readings and the holder doesn't know. | evil |
| **Marked** | known | Kept as built (may read as evil to gifts), but the holder now knows. | evil, through the bluff |
| **Unrequited** | known | One-sided infatuation with one person, who may be evil. Visits that person's home at night. Won't nominate or vote against them until strongly convinced they're evil. | evil, if the beloved is evil |
| **Ill-Omened** | known | Hang them and every gift fails that night. The holders of the failed gifts know their gifts failed, so the outcome is public. | depends on how heavy the cost is; evil's bluff is the risk |

The test for each burden: on balance, it either helps evil a little or gives evil a bluff
worth making. Michael's read of the old set fails it twice: the Sleepwalker was too weak for
evil, and the Lovers too helpful to good.

Notes on the four:
- **Marked as a known burden.** "I've carried the mark since birth" is the holder's answer
  when a reading calls them evil. Evil can bluff the same line, and the real holder can
  counter it because burdens are unique.
  - The premise-centring problem in [secrets_rework.md](secrets_rework.md) section 7 comes
    due here. A case that argues no one's alignment ("Merrin is Marked") currently undoes
    the centring of the cards it shares with other cases. Lantern recommended that such a
    case leave the centring alone.
- **Unrequited** is the one-sided counterpart to the Lovers. The vote refusal is the main
  effect.
  - Its night visits stay at the beloved's home: following them to wherever they walk was
    considered and dropped. If the beloved is the Demon, a follower would trail it to the
    kill, the same gift to good that the Lovers gave.
- **Ill-Omened** is in the Saint family: a cost at the hanging, checked by what happens
  next. A claim can be checked after the hanging: if nobody's gift failed, the claimant
  lied. That's the claim-then-check pattern sketched for the Saint (section 5 of the earlier
  note), and it reads like the Martyr's promise checked at its hanging.
  - The silent-poison version, where good readings that night are wrong without anyone
    knowing, was set aside: the town could never see the cost, so a bluffer would never be
    exposed.

### 2.2 On deck (mechanics deferred)

- **Carouser** (known): a night-walker who brings a guest to the tavern. Quill and Lantern
  assessed how the walk would work (Nov 20); that assessment is held for when the Carouser
  is picked up.
- **Sleepwalker 2.0** (hidden): it walks several blocks rather than going to one home. It
  would hold the hidden slot instead of Delusional, so a script carries one or the other,
  never both.

### 2.3 For later design

- **Night Caller:** visits a gifted neighbour, who loses that night's reading and knows why.
- **Objector:** won't vote or nominate until strongly convinced.
- **Grudge:** an old grievance against one person; votes against them readily.

Considered on Nov 20 and not taken forward for now: Vigilante (an unmodelled second night
killer; Hothead was the counter-pitch), Distractor (interrupting the player's night action),
Gambler (folds into the Carouser).

## 3. What leaves

- **The Lovers** aren't on the slate, so they retire. That removes the landmine
  `Solver.lovers_needs`, which treats a Lovers confession as proof of both partners because
  evil never fakes one (#162).
- **Sleepwalker 1.0** comes off live scripts. Sleepwalker 2.0 waits on deck.
- **The benched flavour secrets** (insomnia, smuggling, debt; `C.USE_FLAVOR_SECRETS`) and the
  no-gift denial (`Setup.ALLOW_NO_GIFT_DENIAL`) were held for this rework. Each gets a
  decision (Q14).

## 4. The workstreams

These are the major pillars, with owners as the roster stands. They're described at the
level of what has to exist, not how to build it.

1. **Script and deal rules.** What a script holds:
   - how many burdens, by town size (7 and 10 NPCs);
   - whether every script has the hidden slot;
   - which combinations are allowed;
   - uniqueness;
   - whether a Baron-like Minion can add burdens.

   Everything else builds on this. Quill, with Lantern.
2. **The solver.** The judge enumerates the one hidden burden and nothing else.
   - A known burden is an ordinary claim once it's made. Unclaimed, it's a general
     allowance.
   - The rough count in the earlier note: about a sixth of today's arrangements before the
     freed room is spent. Argon would measure.
   - The Lovers' special case goes.

   Lantern and Quill; Argon for speed.
3. **Retiring and migrating.**
   - Section 3, plus an audit of the gifts built on "a secret means good": the Rumormonger,
     the Chronicler's trio, and the role checks that read secrets (`sim/roles/*.gd`: Augur,
     Confessor, Executor, Gravedigger, Magistrate, Martyr, Monitor, Registrar).
   - Also: the Mistaken call's honest causes (`HONEST_CAUSES` lists "marked"), Medium
     relays about a dead burden holder, and the Lamplighter count and Night Watch list
     against a hidden walker.

   Quill, with Lantern.
4. **How the town weighs burdens (belief).**
   - the size of the general allowance ("a good person may carry an unclaimed burden");
   - how a known burden discounts what it explains, such as being out at night;
   - reading the Unrequited's refusal to vote as a bond, not as evidence about the person.

   Lantern.
5. **What a hanging would cost.** NPCs weigh the cost of a hanging as well as how suspicious
   the nominee is. Ill-Omened needs this, and the earlier note says to build it once,
   generally. Beadle for votes; Lantern where it enters belief.
6. **The new burdens' own behaviour.** What Unrequited, Ill-Omened and the known Marked do
   in play. Beadle, with Quill for the cards and outcomes.
7. **Reveals.**
   - **Forced:** to explain an anomaly the holder is confronted with (a sighting, a vote, a
     reading that names them), or when pressed or nominated.
   - **Voluntary:** paced by Privacy. A low-Privacy holder volunteers early, a high one only
     under pressure.
   - **Rumour-seeded:** someone else knows the burden and spreads it, through confidants or
     the Rumormonger.
   - **The cost of revealing:** each burden carries a social cost, or Privacy never matters.
   - **Delusional never reveals,** because the holder doesn't know.

   Reuses the claim-under-pressure path for hidden gifts. Beadle.
8. **Evil and burdens.**
   - **Bluffing** a known burden at the same triggers a real holder uses, so every lie has a
     reason. The counter-claim ladder Michael set for gift double claims applies.
   - **Playing real burdens:** steering the town to hang the Ill-Omened, courting the
     Unrequited's protection.
   - The two existing secret bluffs (the evil Rumormonger's made-up reading, and the
     defender's sleepwalk excuse) are extended, not duplicated.

   Beadle.
9. **The player's tools.**
   - a case that argues an unclaimed burden (the per-case either/or, section 3a of the
     earlier note);
   - premises and cards for burdens;
   - the Test juror;
   - case-slate entries.

   Quill, with Herald for the Workshop.
10. **Wording, voices and the reveal.**
    - each burden's reveal, denial and counter-claim lines, in every voice;
    - the end-of-game grimoire reveal;
    - tooltips;
    - the in-game rename.

    Herald; wording is Michael's.
11. **Measurement.**
    - how much each burden tilts toward good or evil;
    - how often evil bluffs a burden, and whether the bluff becomes a tell;
    - golden re-baselines;
    - the case slate.

    Tally for sweeps; the owning lead for golden.

## 5. Order

1. **Script rules, migration and the solver together** (workstreams 1 to 3). They settle
   what the judge enumerates.
2. **Belief and the cost of a hanging** (4 and 5). Ill-Omened depends on both.
3. **Per burden: behaviour, reveals, bluffing and the player's tools** (6 to 9). Start with
   Marked and Unrequited, which need the least new machinery, then Ill-Omened.
4. **Wording and measurement** (10 and 11), alongside each burden as it lands.

The staged plan in the earlier note's section 9 still fits the first step: read-only
feasibility reports, then a `mock/` prototype with paired sweeps, then Michael playtests.

## 6. How it touches other items

- **Good NPCs lie tactically** (BACKLOG section 2, `[open]`): burdens give good NPCs new
  reasons to lie.
- **The Breathstealer overhaul** (section 4): the room freed in the solver could go to
  telling Minions apart.
- **The self-doubt Poisoner nudge** (#455): any burden that causes self-doubt must carry
  its cause, so listeners skip the Poisoner nudge for it.
- **Believable public revisions:** a holder who denies a burden, then admits it, is a
  public revision.

## 7. Open questions

**Script and deal**
1. **Does every script carry the hidden slot,** or only some? If only some, does the player
   know which?
2. **How many known burdens per script,** at 7 and 10 NPCs? Is the number fixed or does it
   flex, as the earlier note's balancing-knob idea suggested?
3. **A Baron-like Minion:** can it add burdens? The earlier note leaned to known burdens only,
   from those not already in play.

**The slate**

4. **Delusional:** confirm it stays exactly as built.
5. **Marked:**
   - When does the holder say it: only when a reading names them evil, or earlier?
   - Is it bluffable by any evil, or only when an evil reading exists to explain?

   It will likely be evil's strongest bluff, so it needs a measurement plan.
6. **Unrequited:**
   - How is the beloved chosen: at random, or from existing relationships?
   - Does the beloved know?
   - What exactly breaks the vote refusal: strong conviction, or a confirmed evil reading?
   - Does the Unrequited defend the beloved, or only refuse to act against them?
7. **Ill-Omened:**
   - Which gifts fail: every gift, only information gifts, or evil's too (does a hanging
     also stop that night's kill)?
   - Does a night death trigger it, or only a hanging?
   - Does the Demon know who holds it?

   How heavy the cost is sets how strong evil's bluff is.

**Reveals and cost**

8. **Triggers per burden:** the anomaly each one explains, and when the holder gives it up.
9. **Rumour-seeded reveals:**
   - What share of burdens start known to a confidant?
   - Who is the confidant?
   - How fast does it spread?
   - Does the Rumormonger become the main engine for this?

   This is the earlier note's confidants question (10.4).
10. **The cost of revealing,** for each burden. This was the open question about the Lovers'
    social cost; now it's one rule for all.

**Evil**

11. **Which known burdens evil may bluff,** and the target rate: often enough that a claim is
    ambiguous, not so often that bluffing becomes a tell.
12. **Does evil know who holds the real burdens?** It decides whether evil can steer a
    hanging onto the Ill-Omened, and how risky a bluff is.

**Belief and the player**

13. **The general allowance:** how much "good people sometimes have a burden" softens a
    caught lie or a sighting. It touches every case.
14. **The player arguing an unclaimed burden:** build the per-case either/or, or are claims,
    confessions and card challenges enough?

**Migration**

15. **Retire the Lovers and Sleepwalker 1.0 outright,** or keep them selectable for custom
    scripts?
16. **The benched flavour secrets and the no-gift denial:** retire them, or keep them for later
    burdens?
17. **The gifts built on "a secret means good":**
    - The Rumormonger's two-name rule may no longer be needed for known burdens.
    - What does the Chronicler's "one carried a secret" become?

**Scope**
18. **Plain folk** (the earlier note's 10.5): in this rework, or separate?
19. **The rename:** in-game text only, with code keeping "secret"? A full code rename is a
    large, risky diff for little gain.
20. **Where the freed solver room goes:** telling Minions apart (the Breathstealer
    overhaul), larger towns, or speed.

# Burdens: the secrets rework, scoped (design note)

**Status: scoped with Michael (Nov 20, 2026). Every question so far is answered (section 8).
Nothing is built.** Written by Claude-Vicar from a talk with Michael on Nov 20. It
builds on [secrets_rework.md](secrets_rework.md), which keeps the earlier reasoning: the two
kinds, the Saint and Baron worked examples, confidants and plain folk, and Argon's review.
Where the two disagree, this note is the newer one.

---

## 1. Decided so far (Michael)

- **"Secrets" become "burdens"** (Nov 20). The word contrasts with "gifts": a gift is what
  someone can do, a burden is what weighs on them. It covers things nobody hides, such as a
  hanging penalty. It's the player-facing name; code keeps "secret". NPCs name the specific
  burden ("I don't sleep easy"), never "my burden".
- **The script** (Nov 20):
  - **At most one hidden burden per script, and none is required.** A hidden burden is one
    its holder doesn't know about.
  - **What the script shows** (clarified Nov 20). As now, it lists up to four *possible*
    burdens, with the hidden one marked as hidden. The first slate's base script lists:
    Delusional (hidden), Marked, Unrequited, Ill-Omened.
    - It also says how many burdens are in play.
    - It doesn't say which one, or whether the one in play is the hidden one.
    - So if a good townsperson is secretly Delusional, nobody can claim the burden truthfully
      (only a Rumormonger or a Chronicler can point at it), and evil has more room to bluff.
      Evil doesn't know that either, so a bluff is always a risk. It can infer it, though:
      its chance of bluffing a burden rises as the days go by without anyone claiming one.
  - **Every other burden is known to its holder,** who doesn't volunteer it but doesn't really
    hide it either. Only the hidden one is enumerated by the judge.
  - **For now, both town sizes (7 and 10 NPCs) carry one burden.** It may or may not be the
    hidden one.
  - **A Baron-like Minion could add only known burdens.** That's out of scope for the first
    pass: no such Minion is planned.
- **Still standing from Nov 18** ([secrets_rework.md](secrets_rework.md) section 2):
  - every burden is unique: at most one holder per game, so a second claim means someone is
    lying;
  - good NPCs may lie about their gift, but only with a reason.
- **A burden holder is always good** (Nov 20). Evil can now bluff a burden, but a bluff is
  only a bluff. So the gifts that learn about secrets (the Rumormonger, the Chronicler's trio,
  and the role checks) stay as they are: they still confirm a real holder.
- **The Muddler is cut** (Nov 20).
- **Names** (Nov 20): **Carouser** is locked in, and **Ill-Omened** is settled for the
  hanging-penalty burden.
  - Set aside for Ill-Omened: Plagued, Omen, Haunted (too close to the Revenant), Forsaken,
    Sinless, Innocent (clashes with "innocent" meaning good), Beloved (collides with
    Unrequited).
  - Carouser's alternatives were Boon Companion, Reveller, Tippler and Barfly.
- **Scope** (Nov 20):
  - plain folk are a separate question;
  - the room freed in the solver most likely goes to larger towns.

## 2. The slate

### 2.1 The first slate (Michael, Nov 20)

| Burden | Kind | What it does, in short | Who it tends to help |
|---|---|---|---|
| **Delusional** | hidden | Stays exactly as built: the holder's gift gives false readings and the holder doesn't know. | evil |
| **Marked** | known | Kept as built (may read as evil to gifts), but the holder now knows. | evil, through the bluff |
| **Unrequited** | known | A one-sided infatuation with one person, who may be evil. Visits that person's home at night, and takes more to be swayed against them. | evil, if the beloved is evil |
| **Ill-Omened** | known | Hang them and every good gift is drunk that night. Evil's gifts are unaffected. | evil; its bluff is the risk to watch |

The test for each burden: on balance, it either helps evil a little or gives evil a bluff
worth making. Michael's read of the old set fails it twice: the Sleepwalker was too weak for
evil, and the Lovers too helpful to good.

**Delusional:** odd readings that are never explained, because the holder doesn't know. It
never reveals.

**Marked** (Nov 20). Its disclosure is tiered, like other disclosures:

| How it comes out | Share |
|---|---|
| announced publicly | about 15% |
| shared privately with a trusted NPC, or with the player (one tier, trust-based) | about 40% |
| held until the holder is nominated or named in an evil reading | about 45% |

- **Private sharing is trust-based,** so it goes most often to the friend the NPC starts the
  game with, the same person who may be its confidant.
- "I've carried the mark since birth" is the holder's answer to a reading that calls them
  evil. Evil can bluff the same line, and the real holder can counter it, because burdens are
  unique.
- The premise-centring problem in [secrets_rework.md](secrets_rework.md) section 7 comes due
  here. A case that argues no one's alignment ("Merrin is Marked") currently undoes the
  centring of the cards it shares with other cases. Lantern recommended that such a case
  leave the centring alone.

**Unrequited** (Nov 20):
- **The beloved** is assigned at random and doesn't know.
- **No single event turns them against the beloved.** Their trust in the beloved is near the
  maximum, which should naturally damp their suspicion of them: they just take more to be
  swayed. If that damping isn't strong enough to notice, add some of its own.
- **They defend within reason.** They don't fabricate evidence to clear the beloved, but they
  may hide evidence that would implicate them. That's a good NPC withholding, with a logged
  reason, as its own narrow rule rather than part of "Good NPCs lie tactically" (Nov 20). They
  give it up under pressure or when nominated.
- **The anomaly it explains:** odd night movement. They give the burden up when called out
  on those nights, or when their suspicion of the beloved grows enough to break the spell.
- **Night visits** stay at the beloved's home. Following them to wherever they walk was
  considered and dropped: if the beloved is the Demon, a follower would trail it to the
  kill, the same gift to good that the Lovers gave.

**Ill-Omened** (Nov 20). Michael wants to try the "everyone is drunk" version first:
- **What it does:** when the holder is hanged, every good gift is drunk that night. Evil is
  unaffected.
- **Only a hanging sets it off,** and only if the holder **claimed Ill-Omened when
  nominated** (a hard rule, Nov 20). A night death doesn't set it off.
  - So the solver only has to account for the nights after a claimed Ill-Omened is hanged.
    It's never a hidden effect.
- **The Demon doesn't know** who holds it.
- **No anomaly to explain.** It's a deterrent. The holder always cites it before an
  execution, and sometimes earlier, if pressure is high or the town is already turning on
  them.
- It's in the Saint family: a cost at the hanging.
- **Michael's earlier lean was the other version**, in which the affected holders know their
  gifts failed. That makes the outcome public, so a claim can be checked after the hanging.
  The drunk version is the one to try first.

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

## 3. What leaves (Michael, Nov 20)

- **The Lovers retire.** That removes the landmine `Solver.lovers_needs`, which treats a
  Lovers confession as proof of both partners because evil never fakes one (#162).
- **Sleepwalker 1.0 retires.** Keep whatever of its code is useful for Sleepwalker 2.0.
- **The benched flavour secrets retire** (insomnia, smuggling, debt; `C.USE_FLAVOR_SECRETS`),
  and so does the no-gift denial (`Setup.ALLOW_NO_GIFT_DENIAL`).

## 4. The workstreams

These are the major pillars, with owners as the roster stands. They're described at the
level of what has to exist, not how to build it.

1. **Script and deal rules.** Mostly decided (section 1):
   - one burden per script at both sizes;
   - at most one hidden, and none required;
   - a hidden burden is named on the script.

   The script lists the possible burdens and how many are in play, not which one. Everything
   else builds on this. Quill, with Lantern.
2. **The solver.** The judge enumerates the one hidden burden and nothing else.
   - A known burden is an ordinary claim once it's made. Unclaimed, it's a general
     allowance.
   - The rough count in the earlier note: about a sixth of today's arrangements before the
     freed room is spent. Argon would measure.
   - The Lovers' special case goes.

   Lantern and Quill; Argon for speed.
3. **Retiring and migrating.**
   - Section 3.
   - The gifts that read secrets stay as they are (section 1): the Rumormonger, the
     Chronicler's trio, and the role checks (`sim/roles/*.gd`: Augur, Confessor, Executor,
     Gravedigger, Magistrate, Martyr, Monitor, Registrar). Check that each one still reads
     the real burden, and never takes a bluff for one.
   - Also: the Mistaken call's honest causes (`HONEST_CAUSES` lists "marked"), Medium
     relays about a dead burden holder, and the Lamplighter count and Night Watch list
     against a hidden walker.

   Quill, with Lantern.
4. **How the town weighs burdens (belief).**
   - the general allowance: about 10% with nothing known, scaled by burden claims and
     Rumormonger reads (section 7);
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
   - **Rumour-seeded:** a confidant knows the burden and can spread it (section 7). The
     Rumormonger is separate.
   - **The cost of revealing:** a small, town-wide trust cost, from those who only learn
     publicly (section 7).
   - **Per burden:** Marked's tiers and the triggers for Unrequited and Ill-Omened are in
     section 2.1.
   - **Delusional never reveals,** because the holder doesn't know.

   Reuses the claim-under-pressure path for hidden gifts. Beadle.
8. **Evil and burdens.**
   - **Bluffing** a known burden to explain an anomaly or deter a hanging, chosen from public
     knowledge (section 7), so every lie has a reason. The counter-claim ladder Michael set for
     gift double claims applies.
   - **Playing real burdens:** evil doesn't know who holds them (section 7), so it can only
     play a burden once it has been claimed or revealed.
   - The two existing secret bluffs (the evil Rumormonger's made-up reading, and the
     defender's sleepwalk excuse) are extended, not duplicated.

   Beadle.
9. **The player's tools.**
   - a case that argues an unclaimed burden (the per-case either/or, section 3a of the
     earlier note): tentative, built only if needed;
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

## 7. Reveals, bluffing and belief: decided (Michael, Nov 20)

- **The confidant:**
  - one person, chosen as a friend by the usual rules, has a chance to start the game
    knowing the holder's burden;
  - more chances come when the holder talks to someone it trusts.

  The Rumormonger stays separate, mechanically.
- **The cost of revealing:** a small, town-wide trust cost, from those who only learn of it
  publicly. Someone told in confidence doesn't pay it.
- **Evil bluffing:**
  - **Any known burden can be bluffed,** to explain an anomaly or to deter a hanging.
  - **The choice rests on public knowledge:** has anyone else claimed a burden, and is there
    a Rumormonger in play?
  - **Evil grows bolder with silence:** each day that passes with no burden claimed raises
    its chance of bluffing one, since the burden in play may be the hidden one, which no one
    can claim.
- **Evil doesn't know** who holds the real burden.
- **The general allowance** is roughly odds-based:
  - about 10% when nothing is known;
  - it scales with other burden claims, since the script's count is known, and with what the
    Rumormonger reads.
  - **Once someone claims the burden,** the allowance for everyone else drops only a little,
    since almost any claim could be a bluff (Nov 20).
  - **A Rumormonger or Chronicler reading** pushes it closer to zero, but never to certain:
    those readings can be lies or tampered with too.
- **The player arguing an unclaimed burden** (the per-case either/or): tentative, built only
  if needed.

## 7a. Carried in from other work

- **Delusional and Sleepwalker, one per world** (Michael, Nov 20, from seed 100002 via
  Lantern; deferred to this rework).
  - **The rule:** in a world where someone else holds a secret, the listener can't be the
    Sleepwalker.
  - **Frame it as open burden slots** (Michael, Nov 20). The listener can't be the
    Sleepwalker in a world with no open burden slot left. It is not a hard rule about
    someone else claiming or holding a burden. The script says how many burdens are in play,
    and each one held uses a slot. Framed this way, the rule still works with different town
    sizes and with a Baron-like Minion that adds slots.
  - **In the meantime:** #459's adjustment stands. A Rumormonger reading that names another
    secret makes the Sleepwalker surer she was home.
  - **Vicar's note, not checked against the code:** with one burden per script (section 1),
    the world-level exclusivity probably follows from the script rule. The solver work in
    workstream 2 should confirm it.

## 8. Still open

None. Michael settled the five follow-ups on Nov 20; the answers are written into sections 1,
2.1 and 7. Next comes the staged plan (section 5): feasibility reports, then a `mock/`
prototype.

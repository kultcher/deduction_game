# Demonologist backlog

The single to-do list, sorted by effort. DESIGN.md stays the record of how things work
and why. Built, settled and parked items move to [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md);
presentation-only work (flavour, wording, visual flair) lives in
[BACKLOG_POLISH.md](BACKLOG_POLISH.md); exploratory mechanics (new roles, places, ideas
still being shaped) live in role_exploration.md.

**State of play (Nov 16):** the connections belief model is on in play
(`Tuning.Workshop.CONNECTIONS`; design and spec in [docs/belief_model.md](docs/belief_model.md)).
The Nov 13 playtest triage is closed: what's left of it is in
[section 5](#5-from-the-nov-13-playtest-triage-moved-nov-16), and the connections build's
own open items are in [section 6](#6-the-connections-model-open-items). The full triage
record is `docs/archive/playtest_triage_2026-11-13.md`.

Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[tentative]** = proposal for later design or
tuning review; **[knob]** = not planned, a balancing tool to reach for only if needed.
Sources (playtest seeds, dates) are in parentheses.

**Tracked in [docs/meeting_flow_plan.md](docs/meeting_flow_plan.md)** (not repeated here):
rebuttals and excuses at the trial, outing yourself to defend someone, NPCs pushing back
on nominations their own information contradicts (supporters, slice M2c); vote talk and
vote resistance lines, including "when they agree and still vote no, they say why"
(M2d); the VN courtroom (M3a); the bot cutover and balance sweep
(M4).


**Deferred (Michael, Nov 8)** and not on the active list: premises step 4 (Scion/Revenant
and movement premises, `docs/premises_plan.md`); contradiction callouts and poses on the
courtroom stage; the live seat-by-seat player vote (meeting plan stretch A); procedural
towns.

---

## 1. Bugs and quick fixes (hours, low risk)

Four known bugs move golden when fixed, so each needs a re-baseline in its PR (details in
section 6): a sighter cut from the sighter contest by the two-sighter cap; an evil Medium's
relay about the first victim naming night 0; a case with no cards answered from an older
compile; a Night Watch list that wrongly names the listener clearing the rest of the watch.

## 2. Small features and tuning (a day or so each)

### Playtests 78148 / 77388: deferred follow-ups (user, Oct 27)

- **Conversation sightings should also cover location sightings.** An automatic card of
  two people talking already places both at that location. Visiting it in the same
  day/phase shouldn't create redundant solo sighting cards. Suppress only the same
  player's same-person, same-location, same-phase duplicate; keep the talk relationship,
  independent witnesses and provenance. [decided]

  Nov 13 (#152, triage 1.7) went the other way for seen talks: a talk you see now gives
  three cards, each talker's own sighting and the talk. Check whether a same-phase visit
  still makes duplicates before building this. [watch]

- **A whereabouts contradiction gets an irrelevant gift refusal.** (78148, Kiran)
  Presenting "Kiran is suspicious" from alibi/vigil evidence produced "Whether I have a
  gift is my own business." Carry the dated contradiction through the press so a knowing
  walker who withholds their purpose can say "Fine, I was out last night, but what I was
  doing is my own business." Keep distinct responses for the truly home, unaware
  Sleepwalkers and evil cover. [decided]

- **Demon detours exist in inference but not in actual movement.** (77388) The movement
  model gives the Demon a 5% detour, and listeners are told a detour is possible, but the
  Demon never actually detours. Decide which is authoritative, then reconcile the
  evaluator, the movement and the explanatory dialogue; compare inference, votes, RNG
  and timings on fixed replays. [open]

- **Challenge a Night Watch report using a conflicting player vigil.** Let the player
  target the dated report as lying or misled with a vigil as grounds, reusing the existing
  reading-challenge path. Same night and block, complete versus incidental coverage, and
  the watcher excluding themselves matter. A contradiction alone doesn't say which source
  lied, or that impairment caused it. [decided: capability; evaluator details open]

- **Challenge a Warden's particular failed protection claim.** Target "On Night X I
  protected <NPC>" against that night's Demon death, supporting the explanation that a
  real good Warden's gift failed. Separate an honest guard attempt from effective
  protection. **User clarification (Oct 27): lying about a failed Warden protection
  implies the speaker is evil; a good Warden would not fabricate this account and can only
  be misled.** This is specific to this claim, not a general rule that every good
  statement is true. Allow an honest impaired Warden; neither failure nor a misled
  accusation proves poisoning or alignment. [decided: capability and lying implication]

- **Martyr non-substitution must keep its alternative explanations; Martyr promise
  versus later hanging.** (78148) An executed choice dying while the claimed Martyr
  survives must not fully confirm the choice as evil: weigh a Delusional Martyr, a
  poisoned Martyr, a bluffing evil Martyr and a Marked executed person alongside an evil
  choice. Bind the choice, the execution and health to their dates, from public knowledge
  only; don't infer that both times were healthy from the earlier promise. Tests should
  isolate every explanation and avoid counting the same failure twice. [decided]

  Built Nov 17 (Quill, `claude/martyr-alternatives`): the promise and the later hanging are
  read together from public events, keeping all five explanations; the outcome reading
  carries the check when both are held. Not built: dated health (a poisoning on a
  particular night); the promise's failure is priced as the report's error.

- **A Delusional teller's false reading is charged twice by the judge.** (Codex on #183,
  Nov 17) In play the role check skips an evil teller's content but not the Delusional
  holder's, so for every role-checked gift (Archivist, Clerk, Gravedigger, Executor,
  Registrar, Monitor, Martyr, Night Watch, Warden, Veteran) a Delusional reader's wrong
  reading takes a small extra error on top of the false-report likelihood. "They were
  Delusional" then reads weaker than it should next to "they lied". #183 fixed it for the
  Martyr promise only. Build after Lantern's poisoned-reading fix has merged (it waits for
  Argon's #181): both change how the role check treats a doubtful reading. Report in game
  terms how much more often the town accepts "they were Delusional" over "they lied".
  Owner Quill. [decided] (Michael, Nov 17)

- **Evil Martyr bluff can frame a good scapegoat.** (user, Oct 27) Audit the current
  choice policy (the user suspects evil often chooses evil). Make choosing a good person,
  helping execute them and claiming non-substitution as evidence against them an active
  scapegoat route. Depends on the item above. An evil-strategy change: design and measure
  separately. [decided: direction]

### Cases and the Workshop

- **The premise should matter.** (user + Claude, Oct 25, case 22485) A case's premise
  changes only the reply and a small trust reward: the belief update re-weighs all the
  listener's evidence regardless, so "Isolde is evil" with cards pointing at Dorian raises
  suspicion of Dorian as much as "Dorian is evil" would. Wanted: the town can notice what
  the player missed, but not solve the case solo or by accident.
  1. Listeners update mainly on what was argued: full weight on the premise target,
     reduced spillover on others scaled by Insight (a sharp NPC notices "this actually
     points at Dorian").
  2. A clearly wrong premise costs a little trust ("you're accusing the wrong person").
  3. The preview shows qualitative strength for the premise and, when the evidence points
     elsewhere, a hint ("this evidence may say more about someone else") without names.

  Measure with the bot A/B; check this doesn't let moderately supported wrong
  nominations through. [decided: direction; numbers open]

  Built Nov 6 as premises steps 1–3 (PRs #92, #93, #95; `docs/premises_plan.md`). Tally's
  A/B (Nov 7) found no outcome change. Under the connections model (in play since Nov 16)
  the premise type changes what's asked, not how cards are weighed, and people a case
  doesn't touch don't move by construction. Presented cards are still heard at the case's
  agreement (Michael, Nov 13, triage 5.3: keep it), so a weaker framing of the same facts
  lands weaker. [watch]

  **Direction (Michael, Nov 17, from his answer on "Say what a card is offered for"):** when
  a case has a premise, the case's effect should centre on its subject. In a case "Constance
  is evil" that cites a vigil sighting contradicting her alibi, any suspicion the case moves
  onto other people in that sighting should be scaled down, with full weight on Constance.
  This would also cover most of what "Say what a card is offered for" asks. Under the
  connections model it sits in how a stored case adds its joint value (Lantern).

  **Centre a case on its premise (Michael, Nov 17).** Two ways, to be chosen after
  measurement:
  - **A, the joint value only:** on the premise's subject a case adds its joint value (what
    its cards say together, beyond each alone) in full, and on everyone else at a fraction;
    brought cards keep counting in full for everyone they name.
  - **B, the brought cards too:** a card a listener holds only because a case brought it
    also counts in full on the subject and at a fraction on everyone else; cards held some
    other way count as usual.
  In both, there's no centring without a premise, and a "suspicious" premise centres the
  same way. The bystander fraction is a new constant, approved with this decision. Measure
  A and B on the same bot games, at 0.5 and one other value: bystander movement per
  presentation, the subject's own movement, and the others in a vigil sighting like
  Michael's example. Report side by side, then Michael picks. Owner Lantern.
  **[decided]: centre on the premise, A or B to be chosen after measurement**

- **Seen with the silenced.** (user, Oct 25) Being somewhere with a person who was later
  breath-stolen should add a little suspicion, enough to reward noticing it, without the
  player linking every location card. Options: (a) a flat circumstantial amount for
  everyone who shared a location with the silenced that day, scaled by how many others
  were there (a deliberate exception to "NPCs only know what they can see"); (b) a
  presentable "town comings and goings" card sharing the player's sightings of the day at
  once. [decided: add; option open]

  Since Nov 10 the judge weighs "who was near each silencing" itself
  (`DayPresence.breath_factor`), and since #157 (Nov 14) it assumes a Breathstealer that
  hunts. Check what's still missing for the player before choosing an option.

- **Say what a card is offered for.** (54875) Collateral from a sighting card lands on
  everyone it places. Let the player say what a card is offered for ("about Constance's
  alibi"). Deferred from the Oct 26 feedback batch because it changes how evidence
  counts. [open]

- **Killed by the Demon, so credit the victim's alibi.** (54875) A Demon victim's alibi
  should count as modest grounds for challenging a reading against it ("it's likelier
  Constance is lying than that Dorian has a secret night walk"): not zero, never proof.
  Check what weight the shared model gives it now, in the balance pass. [watch]

- **Reading challenges and further gift adapters.** Misled and lying modifiers, Surveyor
  skepticism, alibi support and the Clerk, Archivist and Seer adapters are built. Dated
  outcomes, nested relays and conversion histories are still unsupported. See
  [docs/archive/CASE_WORKSHOP_FINDINGS.md](docs/archive/CASE_WORKSHOP_FINDINGS.md) for the
  expansion checkpoints. [watch; broader adapters open]

- **Believable public revisions; withdraw or revise a case.** Let the player retract a
  public endorsement or explain a changed view without deleting the evidence, while NPCs
  keep the reasons they still believe. Players can re-file a case, but can't retract or
  explain. (25923: a final nomination cited the player's earlier argument after the
  player had adopted a different world.) A revised case must not score below the version
  it replaces. Private guesses stay private. [open]

- **Recovering from a wrong "lying" call.** (Nov 12, Michael; Quill's honest-mistake
  sample, belief-model doc) A "lying" challenge on a poisoned or misregistered good
  teller lands about as often as on a real bluffer, which is intended: the player can push
  the town that way, rightly or not. The way back, read from the code and not yet
  measured: revising the original case to "misled" or "failed gift" replaces it for each
  listener who hears the revision. A separate case challenging the same reading the other
  way is blocked for anyone holding the old one ("Conflicting reading challenges need
  separate alternatives"). Nothing says "X was poisoned"; it can only be argued through
  evidence about the Poisoner.
  1. Test it: a lying challenge on a poisoned good Archivist, then the revised case, then
     a case pointing at the Poisoner. How far do the teller's suspicion and the player's
     credibility come back?
  2. Signposting, or a shortcut: tell the player that revising is the way to take back a
     challenge (for example in the block message), or offer "I was wrong, they were
     poisoned" as one action. Pairs with the revisions item above.

  [decided: test later; signposting open]

- **Quiet-night evidence argued by the player.** Support a player-argued link between
  protection, a suspected attack and movement, without exposing hidden attacks. (61251:
  a successful ward on Fenwick suppressed the apparent value of the sightings.) See the
  "Protection + quiet night + sighting" Workshop gap, and build the two together: a case
  argues protection, a suspected attack and movement as one chain, without revealing
  hidden attacks. Quill builds the judge side; Herald any Workshop UI or wording.
  [decided] (Michael, Nov 17)

### NPC behaviour

- **Kill-score pass on every role.** (Nov 10, Michael) The Demon's target score
  (`Evil._kill_score`, `sim/evil.gd`) gives every publicly claimed info gift the same +3.0.
  It drops to 0 after day 1 for first-night gifts (triage 3.4, Nov 16; was +1.0). Only the Seer (+1.0 more) and the
  Registrar (+0.75 more) have their own bonus. To review role by role:
  - one-shot gifts that keep the full score after their information is spent: the
    Chronicler after night 3, the Executor after its assigned person dies;
  - the Augur, a Demon-identifier like the Seer, has no bonus;
  - protective gifts (Warden, Martyr, Sexton) aren't on the info list. The Veteran is
    handled separately.

  Use the measured strengths in `docs/evidence_catalog_measured.md` as a guide to which
  gifts actually threaten evil. [open]

- **Accusations from starting suspicion read as clues.** (13910) Constance accused Isolde
  on Day 1 at suspicion 0.13 against a 0.10 start: a 12% roll with no reason behind it,
  and the player took it as a lead. A 0.2 floor on good NPCs' accusations was tried and
  reverted (Nov 5): those openers also start the meeting. Naming someone gives them +0.35
  on their turn, which sets off the claims, rebuttals and bluffs, and the loud accuser
  draws the Demon's kill. With the floor, some Day-1 meetings went silent (seed 2011:
  3 reactive turns instead of 20; the Demon then killed the Seer who'd otherwise have
  caught it). A 12-game passive A/B was inconclusive, because skipping a roll reshuffles
  every later random draw. Idea on the table: keep the floor, and while nothing
  substantive has been said, let one speaker voice unease at the old odds ("Something
  about Isolde sits wrong with me"). That gives the target the +0.35 but no pressure,
  chorus, accusation event, trust cost or "ask why". Measure it with a sweep against main.

  [open; Michael to decide]

- **Evil meetings are over-weighted and always visible.** (54875) The pairing that matters
  happens before the player picks a place, and evil gets a large bonus whenever a member
  holds unshared intel (nearly always), so the same evil pairs meet on consecutive days.
  Good NPCs with news for a trusted friend now get a similar bonus. Still open: let evil
  confer after the player commits (unseen, or seen only from that block), cap the evil
  bonus, add a pair cooldown. Keep good NPCs meeting often enough to cover. [decided]

- **The Gravedigger in a reluctant town.** (54875) With no executions the Gravedigger has
  nothing to read. A Gravedigger who knows this could push the town to hang someone ("so
  I can tell you what they were"), which also gives a cautious town a reason to act.
  [open]

- **Lovers as an excuse** ("I was with X"). Evil pairing two of its own is a two-for-one;
  pairing with a good person only works if real Lovers sometimes leave each other out to
  dry. **If evil ever fakes a Lovers confession**, `Solver.lovers_needs` (and its use in
  `Solver._solve` and `CaseEval._compile_impl`) must stop treating a confession as proof.
  [open]

- **Follow-up after a false alibi is established.** The good NPC's first response can
  concede "Fine, I was out. Doesn't mean I was doing anything wrong." Later: pressure
  checks and possible forced revelation of the hidden gift or secret, with proper
  handling of genuine home accounts, unremembered outings and evil cover. (44814)
  [decided; mechanics open]

- **Revenant revelation and reversible town uncertainty.** A publicly recognised haunting
  should establish the executed Revenant as evil (built) and add a small global "anyone
  could be possessed" uncertainty. Today the curse only makes living yes-voters a little
  suspect. Burning the totem should reverse the added uncertainty without undoing
  independent evidence, and the possessed person stays hidden. (Oct 21) [decided;
  amounts open]

- **Secret awareness and bluffing.** Lovers' confessions carry a usable secret type and
  can explain night movement. Since #162 (triage 5.9) a Lovers confession also names the
  partner, and the solver treats it as proof of both, because evil never fakes one
  (`Solver.lovers_needs`). Triage 5.8 belongs here too: presenting a card about someone's
  secret to that person got Lian to disclose her gift. Michael: to an individual, present
  either a case or a card with a defined interaction. Decide whether holders know they're Marked, how one asks
  about it, and how evil can claim it too. Keep these as attributed claims, not alignment
  confirmations. (61251/25923) [open]

- **Good NPCs lie tactically.** (Nov 3 plan v8, zone 17) A good NPC sometimes bends the
  truth for a reason of its own (shielding a friend, hiding a secret errand), so a caught
  lie isn't automatically evil. Needs care: lies currently implicate strongly. [open;
  stretch]

- **Backing a strong case builds trust.** Nominating or voting for someone the town
  strongly suspects (and who turns out evil, or is widely believed so) earns a little
  trust from the NPCs who agree. It makes throwing a teammate under the bus pay for evil
  and rewards good NPCs who stick their necks out. (Oct 19) [decided]

- **Evil backs into a bluff.** An evil NPC that hasn't claimed yet can switch its planned
  bluff when another unclaimed gift would serve better (the Poisoner planned Seer, is
  seen out at night, and nobody has claimed Night Watch). This opens double claims (the
  real Night Watch may just be quiet), which need their own logic; once handled, fake
  Mediums and evil generally can make bolder lies. (Oct 19) [decided]

- **Storyteller-driven Medium visits.** Today the Medium visits the most recent dead it
  hasn't visited (Demon victims first). Eventually: "I was called to Hollis's home to
  commune with his spirit", chosen by a director. (Oct 19) [open]

- **Medium relays: later social consequences.** Relays keep both sources, the original
  and visit times and the original's health. Still open: who gains or loses trust, or is
  blamed, when a relay is challenged. (Oct 23) [open]

- **Medium challenge attribution and nested relays.** Add an explicit choice between
  questioning the Medium's transmission and the dead source's original information. Until
  then, cause modifiers on relay cards stay visibly unavailable. Relays of another Medium's
  relay and relayed opinions are unsupported. (Oct 23)
  Michael (Nov 17): build the choice only, a two-way challenge on a relay ("the Medium
  relayed it wrong" versus "the dead person was wrong in the first place"). Relays of
  relays and relayed opinions stay unsupported. Owner Quill. [decided: the choice only]

- **Lie severity.** A false gift report should weigh more than a whereabouts lie, unless
  the lie puts them near the crime. NPCs who accept a lie but won't hang should say so.
  [open]

- **Evil reads as evil.** Evil casting aspersions with no information stands out. Largely
  addressed by the shadow self; revisit after playtests. (30294) [watch]

- **NPC-to-NPC credibility.** The player now has two numbers with each NPC (rapport and
  credibility). Split NPC-to-NPC trust the same way, so liking someone and believing
  their word can differ; source doubt is the natural place it plugs in. (Nov 1) [open]

- **Rapport and Warden-credit leftovers** (social trust pass, Oct 30):
  - "caught lying about me" as an NPC-to-NPC trust loss (no clean hook yet);
  - evil Wardens faking saves (an evil-strategy change, measured separately);
  - the Warden telling the town about a save at the meeting, beyond ordinary disclosure;
  - player wards the Warden knows about counting as an alternative explanation.

  [decided: direction]

### Exploration

- **Role hints from workplaces and haunts.** Occasionally reward searching an NPC's
  workplace or haunt with an attributed hint about their claimed or possible gift.
  Searches shouldn't become guaranteed hidden-role checks. (Oct 21) [open]

- **Occasional free arrival search.** Sometimes grant a free ordinary search when moving
  to a new location. Exclude evidence searches; limit per location and phase so
  revisiting can't farm free actions. (Oct 21) [knob]

### Numbers

- **Night sightings are too decisive.** (user, Oct 25, case 22485) A good person is out on
  an ordinary night only about 5% of the time, against the Demon heading for the victim's
  house on kill nights, so one sighting is a large likelihood ratio, and "claimed a day
  role, seen out at night" reads as open-and-shut. Don't fix it by biasing the Demon
  toward night-walking roles. Levers, measured with the bot A/B: a higher ordinary
  out-rate, more good NPCs with secret errands, softer Demon routes, vigil yield.
  [decided: tune in the balance pass]

- **Evil sometimes tells the truth (start by faking it).** (user + Claude, Oct 25) A
  reading from a source who is evil in a world is uninformative there, so a reading that
  checks out is near-proof its source is good. Make it partial: an evil source's content
  is true with probability t, noise otherwise. Correct readings then exonerate less;
  false readings still implicate strongly. Same cost. Set t from the simulation (how often
  fake readings happen to be true in a bot run), not by hand, and re-measure whenever
  evil's reading strategy changes. [decided: add; t measured]

- **The Seer's rise looks small.** A constructed true Seer "yes" on Day 1 raises the
  pair's combined P(evil) by about +0.11 to +0.14; a hand calculation gives about +0.22.
  Some true Seer pairs don't rise at all in the holder's own view (Day 3, seeds 6, 9, 24).
  Check against the current prior mapping. (Oct 30) [open]

- **Unlimited vigil strength.** [watch] Vigils now see only walkers arriving on the block
  (or the full Lamplighter tour). (54875: a vigil on the first kill block caught both
  walkers there on nights 1 and 2, near a free Seer reading.) Options discussed, none
  chosen:
  - a vigil makes you sleep in and lose the next morning's action (Claude's favourite);
  - vigils limited like the ward;
  - a vigil shows only a count of people on the block (leaves the player reliant on
    chance sightings and the Night Watch);
  - keep watch at one location: name anyone at that spot, count the rest of the block.

- **Trace weight.** The trace likelihood ratio is 3:1. Compare 1.5:1, 2:1 and 3:1 across
  paired seeds (living candidates, wrongful executions, win rate); the evidence rework's
  planned sweep wasn't recorded. [open]

- **Situational credence modifiers** still to settle: early disclosure, a quiet night as a
  credence boost, admission against interest, consistency over time, role-specific
  confirmations. [open]

- **Offer trust** (+0.03 offer, +0.06 kept, −0.15 broken): first guesses, tune from play.
  [watch]

### Tentative social tuning (Oct 20–21 discussion)

Candidates for a unified retuning proposal, not approved changes.

- **Privacy without compounding trust penalties.** Remove Privacy from initial player
  trust and benign trust changes; let high Privacy scale only what a private person would
  resent (intrusive pressure, revealing secrets). Keep the disclosure gates. Distinguish
  ordinary questions on different topics from repeating a refused question. (54875: on
  Day 1 three of three people stonewalled; Privacy counts in both openness and starting
  trust. The first day swings a lot on how many private characters are dealt.) Consider
  removing the double count or dealing at least one openish person per phase. [tentative]

- **Evidence can build NPC-to-NPC trust.** A relationship gain when credible evidence
  reduces suspicion, especially a Clerk reading matching the listener's own role (about
  +0.20, provisional), or a Seer "no" on someone building that person's trust in the
  Seer. Base it on the listener's knowledge, scale by strength, and deduplicate the
  underlying fact. [tentative]

- **Diminishing trust changes near extremes.** Keep a normal band of 0.30–0.70; soften
  further losses below 0.30 and further gains above 0.70, with recovery toward the middle
  at normal strength. Review permanent grief and confidence caps separately. [knob]

- **Fewer trust penalties for presenting evidence.** Reserve most trust loss for
  nominations, votes and other direct offences rather than merely offering evidence; keep
  consequences for intrusive pressure and betrayed confidences. (Oct 21) [knob]

- **Opinion strength and shared origins.** Weaken the first equal-weight meeting voices
  (0.12 / 0.06 / 0.03 → 0.08 / 0.04 / 0.02), keeping fade and cap. Several NPCs
  repeating one original story should not count as independent. [tentative]

- **Martyr urgency.** Lower the Martyr's commitment threshold (0.62) from Day 3 on, with a
  floor, keeping candidate preferences and the option to refuse when everyone looks deeply
  suspicious. Decrement and floor open. [tentative]

- **Demon victims' earlier information.** Strengthen belief that a Demon victim was
  reporting sincerely without trusting every reading's accuracy. Keep sincerity, claimed
  role and night-specific misdirection distinct; base it on listener knowledge, not hidden
  roles or poison. [tentative]

- **Ward promises should outrank vigil promises.** Raise the value of a kept ward promise
  and add plausible-success credit for a kept ward followed by a deathless night.
  Warden/Veteran intervention stays an alternative, not a reason to deny credit. Base
  credit on what the listener can observe; avoid crediting promise, protection and
  outcome twice. [decided: direction; amounts open]

- **Softer secret breaches.** Secret-keeping rapport now decays nightly. Still to review:
  first-use and repeated breach losses and the permanent caps, keeping a real betrayal
  consequence while allowing proportionate recovery, with apologies and confidentiality
  promises. [decided; values open]

- **Dowser clearing strength.** Evaluate firing only on a positive ping instead of
  producing zero-count group clears. Specify whether "evil" means registered evil
  (including Marked), how poison and Delusional results behave, and when an absent ping
  is observable. [tentative]

- **Explicit night-sighting rebuttals.** Let NPCs argue "I was seen out, but no one died
  that night" or "the death happened on another block", as attributed defences rather
  than hidden scaling. Don't clear all movement or ignore thwarted attacks. [decided]

- **A defence's answer to a daytime-whereabouts case.** (26532, #171) A case resting on
  where someone was by day gets no answer of its own; since #171 the defence frames itself
  on the next reading or night it can answer. Michael (Nov 16): build an answer that names
  others present, from public schedules ("I was at the mill that evening, and so were
  Greta and Jory"); evil can use it too, honestly or with a logged lie. Herald writes the
  wording; Michael approved Herald's drafts (Nov 16), and Herald commits the voice lines
  with the build. Constraint (Michael, Nov
  16): `defend_self` runs only at a nomination today, and some voice lines assume a meeting
  (Odette's "Funny how only one of us is up here"); if the defence fires anywhere else,
  such as a private press, those lines must not appear there; use the generic fallback.
  The PR says where it can fire. Owner Beadle. [decided]

- **More rebuttals after a caught lie.** Beyond admitting or stonewalling: concealed
  walking duties, personal secrets, protecting a confidence. Conceding the statement was
  false need not concede evil. Evil gets the same excuses, open to later corroboration;
  the caught lie itself stays. [decided; options open]

- **Misled versus reading-lie strength.** Compare how far "misled" and "lying" challenges
  move a reading at equal effective weight, with night scope and self-knowledge included.
  [open]

- **Signal honest forgetting.** When memory limits drop people from a report,
  acknowledge it ("There were others, but I can't place them"), distinct from Gossip
  refusal, omitting a friend, or concealment, without exposing the omitted names.
  [decided; presentation open]

### UI

- **Case board visuals.** (user, Oct 26) Board cards are crowded: text runs into the
  "heard" line, type and source icons stack in one corner, the context tag sits on the
  edge. Rework card sizing, text fitting and badge placement (a badge strip or corner
  slots) before adding markers. Waiting on it: "shared with you privately" and "in
  confidence" badges (the data exists; nothing draws them) and the context tag. Coordinate
  with "Card zoom and text extension" in BACKLOG_POLISH.md. [decided: needed; design
  open]

- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main view;
  people who aren't talking or working showing on the map; a wrong role guess blocking
  process of elimination.

### Performance

- **Late-game meeting and presenting cost.** Budget (user's machine): meeting entry and
  presenting about 2 s or less, nominations under 1 s. The connections model costs more
  per refresh than the earlier one, and its per-listener cache (#151) only halves it.
  Lantern's profile of playtests 44542 and 97626 (Nov 14): late presentations 4–7 s,
  nights 11–21 s. What remains is sets judged for the first time (new cards, and
  everything at dawn), at 9–25 ms each with no single dominant part. Ideas, not built:
  judge single cards for all listeners from one world table a day; spread dawn's refreshes
  over the night screen; skip core tests whose cards and seed didn't change.
  `tools/replay_log.gd --time` and `--profile` show what each command cost. A background
  thread would
  need a thread-safety pass over the solver's static caches first. Port
  `workshop/reason_attribution.gd` to C# (slice C4) only if profiling shows attribution
  above about 150 ms in late meetings. [open]

## 3. Medium features (several days; touch a few systems)

- **Evidence-reading bot: searching for drops.** The analyst bot reads trace cards
  through the shared model, but it searches only crime scenes and never chooses where to
  look for drops or totems. Teach it, so bot runs measure what physical evidence is worth.
  The bot also doesn't offer wards or vigils or ask about others for haunts. [decided]

- **Expanded dialogue and trust management** (Oct 20; design candidates). [tentative]
  - **General requests spread through town chats:** "Someone should check Nisha" or
    "Someone should watch the Wharf", without outing a gift-holder. Hearing a request
    isn't volunteering or completing it.
  - **Responsibility and follow-through build trust:** a meaningful accepted task earns a
    small, non-repeatable rapport gain; later credit depends on what the NPC believes was
    accomplished. Don't reward incriminating results by default; prevent request spam.
  - **Responsibility cuts both ways:** an NPC may feel guilt when their information helps
    execute someone who later looks innocent, based on perceived responsibility and known
    outcomes. (Oct 21)
  - **Ask what would change their mind:** expose friendship, conflicting information,
    distrust of the player, or preference for another execution as actionable
    resistance.
  - **Explain an execution's purpose:** propose an information-seeking execution (for a
    Gravedigger read) without asserting the target is the Demon.
  - **Apologise** for a specific incident, scaled by harm and responsibility; **promise
    confidentiality**.

- **NPCs voice doubt about their own readings.** Notice apparently inconsistent results
  (repeated Seer checks of the same pair changing yes/no) and let the NPC say something's
  unusual; higher Insight helps notice a mismatch with their leading explanation. Use only
  what they know, allow legitimate changes such as succession, and keep suspicion of
  misdirection apart from admitting a lie. (Oct 21) [decided; triggers open]

- **Trust dynamics around sources.** A relayer may name their source outright, at the
  cost of that person's trust; evil may try to trace an unnamed source ("the Seer told
  me") back to a person, to kill or frame them. (Oct 19) [open]

- **Talking to a group:** 3 questions per phase, split among anyone at the spot. [open]

- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems**. The Revenant is often invisible. (55774) [decided]

- **The Revenant can hide a new totem each day.** The burned-totem notice now warns that
  the spirit will seek a new hiding place; whether the totem search can keep pace is a
  balance question. (54875) [watch]

- **NPCs find evidence and personal items** (dropped items, traces). [decided]

- **Ways to discover and confront secrets:** sightings that don't fit, confidants,
  personal items, a "you have a secret" card used as leverage. [open]

- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. [open]

- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (open since playtest 1) [open]

- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers meeting
  too as noise. [open]

- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  Demon; the Demon goes along with town conclusions to build trust. [open]

- **Observable actions as evidence (Stage 1B).** Votes, nominations, who defended whom
  and tie-breaks as soft per-world likelihood factors: "voted to execute someone who is
  good in this world" needs only each world's evil mask, so it adds no hidden dimension.
  Each action's rates for evil and good actors come from bot runs, not hand-set values.
  Votes are procedural public events today; the Stage 2 circumstantial hub is built.
  (user, Oct 24) [decided: the split; details open]

## 4. Major structural work (a week or more; design first)

- **Locations as evidence, from both sides.** A Dowser reading places the Dowser and the
  group on a block, but it isn't a location card, so the player can't use it to show a
  fake Medium or Dowser wasn't where they said. Your own visit excludes people: anyone
  not seen at a spot wasn't there that phase (except people at home on that block).
  Low impact while most suspicious activity happens at night. (Oct 19) [open]

- **Passing through vs stopping.** Sightings say whether someone was passing through a
  block or out on it ("heading toward the Docks" vs "out on the Docks"). Two "out on"
  sightings on different blocks are a real contradiction; "passing through" fits a route.
  Open: who can tell the difference (street observers and vigils, not window glimpses).
  [open]

- **The Breathstealer overhaul** (Michael, Nov 17: needs a thorough rework before any
  more tuning; the items below feed it). **The Breathstealer confirms the good.** It only
  silences the good, so a silenced person is proven good. Options: (a) it may silence a suspected teammate as cover; (b)
  silence goes quiet: not announced, the victim stonewalls with a small private tell, and
  evil can feign it; (c) both. Two more routes: a good secret that inflicts the same
  silence (a vow, a sore throat), and an optional silence that may skip days. (96773,
  Oct 19) [open]

  **Measured Nov 14–15** (Tally's sweep and Bailiff's mocks;
  `docs/archive/project-docs/inert-breathstealer-sweep-2026-11-15.md`): Breathstealer deals
  favour good by 18–32 points over other deals, and the hunt (#157, silencing on about 90%
  of days) didn't change that. A Minion with no ability at all does 10–19 points *better*
  for evil than the Breathstealer. At 10 NPCs the "silenced, so likely good" factor
  (`PublicEvidence.factors`, ×0.66 on the odds) is about 40–45% of that gap; at 7 almost
  none. A remote Breathstealer that leaves no trail is hanged as rarely as an inert one but
  still loses about as often as the hunting one; silences that last until it dies barely
  help evil. Hunch: a silenced person keeps their vote and has usually spread what they
  knew already, so taking a voice costs good little. Not run: the remote and lasting
  versions in passive cells. No decision yet.

  **The judge lets a silencing victim be the Breathstealer** (Quill, Nov 17; playtest
  26532, case #90; details in Quill's handoff entries on #173 and #177). The "who was near
  each silencing" factor averages over a world's Minions without asking which one holds
  the gift, so every listener kept "Greta is the Breathstealer" alive although Greta had
  been silenced. A mock fix took the case against Isolde to 92–98% for every listener,
  but on the earlier belief model it also raised suspicion of Isolde before any case was
  presented (Bartholomew 12% → 43%, Fenwick 22% → 60%), so the town got there largely
  without the player. Not measured under connections. Not built: it folds into the
  overhaul.

- **The Muddler rarely has anything to muddle** (Quill, Nov 17; playtest 26532; details in
  Quill's handoff entries on #173 and #177). In 40 games with the Muddler forced in (seeds
  1–40, 10 NPCs, passive player), the Muddler passed on a reading or night sighting in only
  5. When it did, items were garbled at about the designed rate. The limit is supply: news
  is announced at the meeting and nobody repeats what everyone heard, so NPCs hear under
  one private reading or sighting a game. Letting everyone pass on more gave no more
  relays (52 against 60 in 40 games) unless some news also stays private for a while.
  Options measured or estimated: garble the Muddler's retellings at the meeting; keep
  night sightings private for a day (Muddler in about half of games, estimated, but news
  spreads earlier for both sides and the meeting is less of a reveal); garble day
  sightings and alibis too (about one more garble per 40 games). Michael (Nov 17): leave
  it for now; he isn't sure the Muddler can work as written without warping the game
  around it. [open]

- **The secrets rework.** (Michael with Claude-Vicar, Nov 17; design note
  [docs/design/secrets_rework.md](docs/design/secrets_rework.md)) Two kinds: the
  self-unaware secrets (Marked, Delusional, Sleepwalker) stay enumerated by the judge; the
  ones the holder knows about become ordinary claims, which evil can bluff, and the player
  can argue an unclaimed one per case. The Muddler is tentatively cut. Backlogged by
  Michael (Nov 17) in favour of smaller items first; the note's section 9 has the staged
  plan for when it's picked up. Decide it alongside the Breathstealer overhaul: the room
  it frees could go to telling Minions apart. [open]

- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration), and the
  Lovers' relationship mods, including the Lovers downside (when one dies, the other
  withdraws visibly). [open; Lovers downside decided]

- **Roster expansion.** Lantern's shortlist from the Clocktower passes (ideas only):
  `docs/archive/project-docs/role-shortlist-2026-11-11.md`. Built since Oct 30: Augur, Chronicler, Executor, Magistrate,
  Registrar, Psychologist, Monitor, Confessor, Sexton and the Brute. Still to come: On Deck
  gifts (Tracker, Clairvoyant, Beckon, Tallyman, Bellringer, Bellwether…), minions
  (Framer/Forger with evidence planting, Blackmailer, a two-curse Minion (once
  called the Hexer; that name now belongs to the day-killing Demon), Informant, the Sower), the Debtor secret, and Demon resilience (Dusk Compulsion /
  Mesmerize, a daytime "rouse"). Bellwether, the Sower and Dusk Compulsion come from the
  Nov 3 orchestration plan (v8); their designs aren't written up in role_exploration.md
  yet. Each needs a hint package and solver support before it goes live. [open]

- **Scripts, follow-ups** (script builder plan, Nov 4):
  - **Multiple demon types:** step 1 is on main (#105: `C.is_demon` / `C.is_day_demon` and the
    solver's demon-type mix); steps 2 and 3 (daytime presence and the Hexer, experimental)
    merged with #111, and the player's demon-type declaration with #131
    (`docs/demon_types_plan.md`). The Hexer stays experimental. On hold until Michael's
    playtests: the declaration's default and the bot's Hexer call (it calls a Hexer right
    only 54% of the time; every miss is "walker").
  - **Builder rules** beyond tag counts (requires/excludes "jinxes", weights) once the
    roster outgrows one script.

  [decided]

- **A demon that kills during the day** (user concept, Oct 23). Built as the Hexer
  (`sim/roles/daykiller.gd`, experimental; #111, Nov 10), with the player's declaration
  (#131). Its day evidence is weak in passive play: triage 4.6 (Nov 16) found no lean
  away from the true Hexer on current main, but nobody sees the Hexer at the hexed place
  either, so the day connection barely tells it apart. Player day logs are what would
  strengthen it. [watch]

- **The demon lures a victim elsewhere** (user idea, Oct 23): once per case, or under a
  condition, the kill happens somewhere other than the victim's cottage. "Found dead at
  the well" is itself a clue, and it gives location-based night tools something to
  target. [open]

- **Learning resources: tooltips, an in-game wiki and a tutorial.** (Nov 3 plan v8, zone
  18; restored Nov 8) Three layers, from one data registry so they never drift:
  1. **Tooltips and terms:** extend `ui/text_terms.gd` beyond roles and people to the
     mechanics (Marked, Delusional, On the Block, Vigil, Ward, Clemency, Traces,
     Circumstantial, traits, night order), plus tooltips on UI controls.
  2. **In-game wiki / field manual:** replaces the plain Help text with a searchable,
     hyperlinked codex, opened by clicking a term in the log, speech or cards.
  3. **Guided tutorial:** a curated 7-NPC case with light coach marks (moving between
     blocks, vigils and traces, building and framing a Workshop case, the trial). Build it
     after the meeting and premises work settles, so its steps don't churn.

  Layers 1 and 2 are UI and data only and can be built any time. [decided: direction]

- **Player toolbox:** Autopsy, Séance, Scry, Binding circle; demon types with bestiary
  entries; exorcism / true-name alternate win. [open]

- **Scoring system:** identification credit (separating evil alignment, the exact minion
  gift and a useful execution), accuracy of guesses with confidence, and why the player
  lost (wrong read / missed / never available / failed to persuade). Absorbs the removed
  voting prompt and the Scion credit rule. (61251: Jory identified as evil but guessed
  Breathstealer; executing the Revenant turned the last good NPC.) [open]

- **Storyteller/director and solvability check:** poisoned readings become arbitrary
  (chosen plausibly) rather than inverted; check that a case can be solved. [open]

- **Procedural town:** blocks, buildings and roads generated per case. [deferred, Nov 8]

- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]

- **NPC memory and recency bias.** (Random ideas) Attention-level recency is on main (PR
  #96, Nov 9; `docs/premises_plan.md` "Recency as built"). Under the connections model
  attention and recency pick only what an NPC cites and explains, not what it believes.
  [open]

- **Dead NPCs:** no ghost votes for now; keep the door open (a final-day Séance vote).
  [watch]

---

## Workshop gaps (NYI)

Patterns that come up in play, or that the mechanics make meaningful, but that the Case
Workshop and the shared model can't express yet.

- **Time-scoped Revenant possession premise.** "X was possessed by a Revenant on day D"
  as an explicit premise, so testimony and alignment claims are judged for the relevant
  time rather than voiding the person's whole history. Keep suspected possession distinct
  from confirmed knowledge, and don't expose the hidden victim. (Oct 21) [decided]

- **Succession breaks earlier clears.** A Seer "no" speaks for the Demon only as of that
  night. If a hanging with 5+ alive (so a Scion could rise) falls between two readings,
  "X became the Demon afterwards" must stay an explanation. NPC reasoning and the bot
  should apply the same limit to old clears. Check the shared model handles this.
  (Astra, 55774) [watch]

- **Minion gifts.** Someone silenced and the people seen on their block that evening
  (the Breathstealer has to be there); a reading that failed on a night someone was near
  the reader's home (the Poisoner's visit); a totem found and the people who live where
  its material is from (the Revenant). (54875: the totem card had no Workshop adapter.)

- **Breathstealer by presence:** built (#111, Nov 10; a joint factor over the presence
  table), and since #157 (Nov 14) it assumes the Breathstealer hunts. The Breathstealer
  decision (does silence prove the victim good?) is still open, in section 4.

- **Night companions of the proven evil:** out on the same block on the same nights as
  someone proven evil → likely their teammate. (96773: Isolde out with Greta on nights 1
  and 2; Greta was shown to be the Poisoner, but nothing linked Isolde to her.)

- **A Medium's relayed sighting vs the dead's known vantage:** the dead watched or
  guarded a different block that night, so couldn't have seen what the Medium says.

- **Accounting:** a Lamplighter's "N others out" plus home alibis for everyone but one →
  the unaccounted person was out.

- **Walker sightings vs the Lamplighter count:** more people reported out than the
  Lamplighter counted, or a Lamplighter who counted others but was seen nowhere.

- **Duty claim vs reading:** the hearth in the Medium's *reading* ("at Dorian's hearth")
  as a destination, so a reading and a sighting can conflict, not only the alibi and a
  sighting.

- **Protection + quiet night + sighting** (54875): a kept ward or a Warden claim, a quiet
  night and a sighting near the guarded door, argued as one chain. Built with "Quiet-night evidence argued by the
  player" (section 2), [decided] Nov 17.

## 5. From the Nov 13 playtest triage (moved Nov 16)

Everything decided in the triage was built in #149–#162; the record, with the small calls
made on Michael's behalf, is `docs/archive/playtest_triage_2026-11-13.md`. These were left:

- **An NPC defender's challenge isn't stored as a case** (triage 4.5; step 4). With the
  connections model, a defender's challenge keeps today's small floor under the challenged
  teller and does nothing else, so NPC defences barely move belief. Storing the defence as
  a case of its own (the defender's cited cards and challenge, weighted by trust in the
  defender, fading) would make the meeting symmetric: defences start to work for good and
  evil alike, and a trusted evil defender can blunt a true reading. Separately, NPC
  defences should cite exonerating evidence the way accusers cite incriminating evidence;
  that may be a dialogue-level change. Needs a paired sweep cell before deciding.
  **[deferred, Michael, Nov 13: promising, after the connections build]**
- **Presenting a card to one NPC** (triage 5.8): see "Secret awareness and bluffing" in
  section 2. **[design]**
- **A bluffer's frame memory** (triage section 6). The scapegoat is one team-wide choice
  (`evil_plan.scapegoat`), reconsidered each morning with a bonus for keeping it. A
  bluffing Dowser keeps no memory of whom its own earlier counts implicated, so later
  readings can drift away from the frame. Proposal: a bluffer's later readings stay
  consistent with the people its earlier ones implicated, unless the team has switched
  scapegoat and the old reading no longer matters. **[open]**
- **One pass over every bluffer** for the "too clean when an ally is involved" tell that
  gave Kiran's Dowser away in 97626 (the Dowser itself was reworked in #160 to Michael's
  guidelines: within about 1 of the truth, the group size setting the room). For
  comparison, the Surveyor frames the scapegoat's block 60% of the time, clears a
  teammate's block half the rest, or picks at random; the Seer never gives a "no" that
  covers the scapegoat. **[open]**
- **The Demon "before/after" premise for the Scion transfer** (triage 1.6). The alignment
  part was done in #149: the curse "When" field shows only on is evil / suspicious /
  good. The Scion part is new work: a premise time option that means "before / after
  the Scion rose". **[decided: direction]**
- **The Test juror reporting a condition separately** (triage 5.1, the full version). #159
  built the cheap version: a premise → card link means "this card's line runs through that
  premise", labelled "given <premise>". The full version would have the juror say "if
  Fenwick is good, this is strong; Fenwick is good is moderate", which needs new juror
  machinery. **[later]**
- **The "No new info" note's limits** (triage 5.2, #154): a bigger case on a later day
  that replaces an earlier one gets no note even if its extra cards add little; "Adds no
  new belief, but still presses X" shows only from 0.15 pressure; the "settled" note has
  no test (the fixture has no settled person). **[watch]**
- **Lian's stonewall after "let me tell you in my own words"** (triage 2.7): struck by
  Michael on Nov 16. The line isn't in the code as quoted, so it may have changed already;
  revisit if it turns up again.

## 6. The connections model: open items

From the belief-model doc's open items (`docs/belief_model.md`), as of Nov 16.

- **A Night Watch list that wrongly names the listener.** Each name is scored as an
  independent slip, so keeping the list cleared the rest of the watch (−0.36).
  `SourceDoubt` still voids that night's list. Fix: a list that's wrong about the listener
  is suspect as a whole. Moves golden. **[decided: fix]**
- **A relayer cut from the sighter contest by the two-sighter cap** (Lantern, Nov 13).
  Sighters of a person are ranked by how many sightings they told, then by town order, and
  only the first two are doubted (`SIGHTER_CONTEST_MAX`). In seed 929 that left out Kiran,
  an evil Medium who invented a relayed sighting, so it counted as the dead Lian's honest
  word. Raising the cap to 4 as a test changed the reading a lot on a partial card set and
  barely with all cards. Moves golden. **[open]**
- **An evil Medium's relay about the first victim names night 0** (Lantern, Nov 13). The
  bluff says the dead saw the scapegoat out "on their last night"; for the first victim
  that is night 0, when the model's Demon never walks, so the frame *lowers* suspicion of
  its target. Moves golden. **[open]**
- **Honest mistakes against lies in challenges.** "Misled" and "failed gift" land 3–12% of
  the time on honest mistakes; to a listener an honest mistake and a lie are the same
  cards, so no rule separates them. It would need evidence that does (the teller's
  history, signs of poisoning). **[open; Michael]**
- **Whole reversals against the earlier model's beliefs.** Greta on Odette (seed 929,
  0.88 → 0.04) is traced: the earlier model's attention left out the two cards that clear
  Odette. The others, and day 3 of the same game going the other way, aren't. **[watch]**
- **Cost:** see "Late-game meeting and presenting cost" in section 2. **[open]**
- **The spoken reply to a later-day repeat.** Re-presenting a faded case restores its
  weight, but the reply may still say the assessment is unchanged. **[polish]**
- **A reason citing a pairing the model didn't weigh.** Attention picks what is cited, the
  connections model what is believed, so a reason can name cards the belief didn't combine.
  **[polish]**
- **Sleepwalker self-doubt scaled by confidence** (10% flat for now,
  `Workshop.SLEEPWALK_SELF_DOUBT`). **[later]**
- **Adjudicating a muddled card** (the Muddler secret). **[later]**
- **Brute kills scored as hexes on custom scripts.** **[later]**
- **A double claim of a unique gift raises both claimants** (Lantern, Nov 16; Michael, Nov
  16). Under connections a claim is only context, so two people claiming a gift only one can
  hold don't become more suspicious by themselves (in `test_beliefs` both dip about 0.01;
  the earlier model raised them 0.14 and 0.24). Make the two claims a built-in pairing that
  raises suspicion on both claimants, and shifts it onto the other when one is shown good by
  other cards. Report in game terms how much each claimant moves, alone and alongside other
  evidence. Add it to `docs/belief_model.md`'s pairings. Owner Lantern. **[decided]**
- **Insight sets how readily a card joins an NPC's core** (Lantern, Nov 17; Michael chose
  Option A, Nov 17). A sharp NPC links more cards to its own readings and nights, a dull one
  only the glaring ones; nobody connects public cards that don't touch their own knowledge.
  The joining bar runs from 0.8 for the dullest NPC to 0.1 for the sharpest (Michael, Nov
  17, after the wider measurement). DESIGN's Insight row and its new line are approved.
  Building in #199. Owner Lantern. **[decided]**
- **Spillover damping, removed with the earlier belief model** (connections purge, Nov 16;
  Michael asked for it to be kept on the backlog). Premises pass step 1 (`docs/premises_plan.md`)
  had a presented premise shape its own cards' effect: the premise's target took the case's
  full effect, and everyone else took a share that grew with the listener's Insight, from 40%
  to 80% (`PREMISE_SPILLOVER_MIN/MAX`, `SharedLedger.premise_shaping`). Under connections a
  case moves people it doesn't name only through its own cards, so the damping never ran with
  the model on, and it is deleted in purge phase 5 (`docs/connections_purge_plan.md`). The code survives
  on the branch `archive/legacy-belief-final`. Revisit if presentations move bystanders too
  far in play. **[tentative]**
- **NPC nominators' cases:** no faster fade or cap. Revisit if up to nine live cases per
  listener shows up as a problem in play (Nov 11). **[watch]**

## Closed

Closed items live in [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md).

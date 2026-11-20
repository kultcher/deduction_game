# Demonologist backlog

The single to-do list, sorted by effort. DESIGN.md stays the record of how things work
and why. Built, settled and parked items move to [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md);
presentation-only work (flavour, wording, visual flair) lives in
[BACKLOG_POLISH.md](BACKLOG_POLISH.md); exploratory mechanics (new roles, places, ideas
still being shaped) live in role_exploration.md. Items being watched, and knobs to reach for
only if needed (`[watch]`, `[knob]`), live in [BACKLOG_WATCH.md](BACKLOG_WATCH.md); tabled items are
in the Tabled section at the bottom.

**Priorities (Michael, Nov 20 reprioritization):** clear section 2 (small features and
tuning) as far as possible, plus "Graded gossip". The rest of sections 3 and 4 waits.
(Nov 20, later: "Insight helps an NPC notice…" moved into the deferred "What does Insight do
now?".) Each lead has
its owners and order from Seneschal.

**State of play (Nov 16):** the connections belief model is on in play, and since purge
phase 3 (Nov 18) it's the only one (design and spec in [docs/belief_model.md](docs/belief_model.md)).
The Nov 13 playtest triage is closed: what's left of it is in
[section 5](#5-from-the-nov-13-playtest-triage-moved-nov-16), and the connections build's
own open items are in [section 6](#6-the-connections-model-open-items). The full triage
record is `docs/archive/playtest_triage_2026-11-13.md`.

**Contents** (every open item, by section; closed ones are in BACKLOG_COMPLETED.md)

- [1. Bugs and quick fixes (hours, low risk)](#1-bugs-and-quick-fixes-hours-low-risk)
  1. NPC defenders weigh secrets the game can't deal `[decided]`
- [2. Small features and tuning (a day or so each)](#2-small-features-and-tuning-a-day-or-so-each)
  - [Playtests 78148 / 77388: deferred follow-ups (user, Oct 27)](#playtests-78148--77388-deferred-follow-ups-user-oct-27)
    1. Evil Martyr bluff can frame a good scapegoat `[decided]`
  - [Cases and the Workshop](#cases-and-the-workshop)
    1. Argon's audit: cleanup `[decided]`
  - [NPC behaviour](#npc-behaviour)
    1. Accusations from starting suspicion read as clues `[decided]`
    2. The Gravedigger in a reluctant town `[decided]`
    3. Caught out and pressed again: what's left `[decided]`
    4. Good NPCs lie tactically `[open]`
    5. Rapport and Warden-credit leftovers `[decided: direction]`
    6. Anger reasons `[decided]`
  - [Numbers](#numbers)
    1. The Seer's rise looks small `[later: role tuning pass]`
    2. Dowser clearing strength `[later: role tuning pass]`
  - [Tentative social tuning (Oct 20–21 discussion)](#tentative-social-tuning-oct-2021-discussion)
    1. Explicit night-sighting rebuttals `[decided]`
  - [UI](#ui)
  - [Performance](#performance)
- [3. Medium features (several days; touch a few systems)](#3-medium-features-several-days-touch-a-few-systems)
  1. Expanded dialogue and trust management `[tentative]`
  2. Graded gossip `[decided]`
- [4. Major structural work (a week or more; design first)](#4-major-structural-work-a-week-or-more-design-first)
  1. Smarter evil `[deferred]`
  2. Vigil request and reward rework `[deferred]`
  3. What does Insight do now? `[deferred]`
  4. The Breathstealer overhaul `[decided: add; option open]`
  5. The secrets rework `[decided; values open]`
  6. Learning resources: tooltips, an in-game wiki and a tutorial `[decided: direction]`
  7. Player toolbox `[open]`
  8. Scoring system `[open]`
  9. Storyteller/director and solvability check `[open]`
- [Workshop gaps (NYI)](#workshop-gaps-nyi)
  1. Minion gifts: the Poisoner's visit
  2. A Medium's relayed sighting vs the dead's known vantage
  3. Duty claim vs reading
- [5. From the Nov 13 playtest triage (moved Nov 16)](#5-from-the-nov-13-playtest-triage-moved-nov-16)
  1. An NPC defender's challenge isn't stored as a case `[deferred, Michael, Nov 13]`
  2. Presenting a card to one NPC
  3. The Test juror reporting a condition separately `[later]`
  4. Lian's stonewall after "let me tell you in my own words"
- [6. The connections model: open items](#6-the-connections-model-open-items)
  1. Honest mistakes against lies in challenges `[open; Michael]`
  2. The spoken reply to a later-day repeat
  3. A reason citing a pairing the model didn't weigh `[polish]`
  4. The Sleepwalker's doubt, from what the Rumormonger tells her `[decided]`
  5. Brute kills scored as hexes on custom scripts `[later]`
  6. Gift doubt for readings the judge doesn't check `[open]`
  7. Persistence Confidence: a working theory that colours new evidence `[tentative]`
  8. Observable actions as evidence (Stage 1B) `[tentative]`
- [Tabled](#tabled)
- [Closed](#closed)

Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[tentative]** = proposal for later design or
tuning review; **[knob]** = not planned, a balancing tool to reach for only if needed. **[deferred]** = held
for the bigger design work (Michael, Nov 20).
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
towns. The Minion premise was folded into "evil" (Michael, Nov 20); it may return with
step 4.

---

## 1. Bugs and quick fixes (hours, low risk)

No known bug that moves golden is waiting. Fixed since Nov 17: a case with no cards answered
from an older compile (#192); an evil Medium's relay about the first victim naming night 0
(Beadle); a relayer cut from the sighter contest (#265) and a Night Watch list naming the
listener (#273), both Lantern's.

- **NPC defenders weigh secrets the game can't deal.** `workshop/reason_attribution.gd`
  builds the defence view from the whole roster of secrets (`C.SECRET_MOD_LIST`), not from
  the game's `case_script.secrets`. Fix: read the script's secrets, as the rest of the judge
  does. It moves golden wherever a defence is scored. Its own small PR, after Quill's #405
  re-baseline, Lantern's scaffolding PR and the "not the Demon" badge fix. Owner Lantern;
  approved as a bug fix by Seneschal (Nov 20). [decided]

## 2. Small features and tuning (a day or so each)

### Playtests 78148 / 77388: deferred follow-ups (user, Oct 27)

- **Evil Martyr bluff can frame a good scapegoat.** (user, Oct 27) Audit the current
  choice policy (the user suspects evil often chooses evil). Make choosing a good person,
  helping execute them and claiming non-substitution as evidence against them an active
  scapegoat route. Depends on the item above. An evil-strategy change: design and measure
  separately. [decided]
  - **Michael (Nov 20):** today, Martyr bluffers only ever pick evil teammates. It should be
    the opposite: they always pick a good NPC, ideally one with some heat on them, so that if
    that NPC is executed the bluffer can frame it as evil. They shouldn't be loud about
    pushing that person's execution, since that would be an obvious tell. Owner Beadle.

### Cases and the Workshop

- **Argon's audit: cleanup** (Michael, Nov 19, approving all four groups;
  `docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md`). Before any more larger
  features. The parts already done, groups 1 and 4 among them, are in BACKLOG_COMPLETED.md
  (Nov 20). Keep `ALLOW_NO_GIFT_DENIAL` and `USE_FLAVOR_SECRETS` until the secrets rework
  decides. **Left:**
  2. **Golden-moving:**
     - **Removing `LEGACY_EXTRA_SHIFT_DRAW` is deferred** (Michael, Nov 20). It reshuffles
       every deal, about 25 to 30 suite fixes. Michael decides at the reprioritization
       whether to do it at all.
  3. **File splits,** one file per PR, with no change to play:
     - **Tier 1** follows Beadle's in-flight work (#390, the symmetric vote):
       `mind_meeting.gd`, `mind_dialogue.gd`, `world.gd` and `mind.gd` (Beadle, with Lantern
       on `mind.gd`'s case side).
     - **Tier 2** follows Tier 1: the voices (Herald), `social.gd` (Beadle), the Workshop UI
       (Herald), `live_activity` and `case_eval` (Lantern).
     - **Tier 3** waits for the purge.

  [decided]

### NPC behaviour

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

  Michael (Nov 17), in place of the voiced-unease idea: a "pressure of silence" check. If
  everyone has had their turn and the meeting has produced little useful information
  (roughly fewer than 3 claims or readings), go through the speaking order again with a
  bonus to speak that rises as Composure falls: less composed characters speak up to fill
  the silence, even when it isn't the best idea. A full pitch goes to Michael (through
  Seneschal) before building: how it meets the day-1 accusation floor, what counts as
  useful information, the bonus size, what the extra speakers say (Herald writes any new
  lines), and what it does in play, measured on a `mock/` branch if possible. Owner Beadle.
  [decided]
  - **Pitch approved (Michael, Nov 20), "pressure of silence":**
    - the 0.2 floor on good NPCs' accusations, in the first pass;
    - a silence check after everyone's turn: with fewer than 3 useful items (claims, shared
      readings, volunteered sightings, accusations with a reason), the order runs once more;
    - in that pass, a bonus to speak scaled by low Composure, with the floor waived and no
      bonus for evil;
    - constants approved: `GOOD_ACCUSE_MIN_SUSP` 0.2, `SILENCE_USEFUL_MIN` 3,
      `SILENCE_SPEAK_BONUS` 0.6;
    - a silence-breaker opener per voice (Herald). **Herald's 15 lines approved** (Michael,
      Nov 20; fallback "Well, someone ought to say something."). The opener plays for any NPC
      speaking in the second pass, good or evil, once per meeting, so it isn't a tell;
    - Beadle measures it on a `mock/` branch first.

- **The Gravedigger in a reluctant town.** (54875) With no executions the Gravedigger has
  nothing to read. A Gravedigger who knows this could push the town to hang someone ("so
  I can tell you what they were"), which also gives a cautious town a reason to act.
  Michael (Nov 17): as a hidden motive only. A good Gravedigger with nothing to read leans
  a little more toward nominating and voting to hang, but never says so: these are real
  people who wouldn't hang a neighbour to read the body. No new lines; a logged reason
  for the lean, as for any decision. Keep the lean modest. Owner Beadle. [decided]

- **Caught out and pressed again: what's left.** (Michael, Nov 20: one item from two
  remainders.) Owner Beadle.
  - **From "Follow-up after a false alibi is established"** (44814): pressure checks, and a
    possible forced reveal of the hidden gift or secret, handling genuine home accounts,
    unremembered outings and evil cover.
  - **From "More rebuttals after a caught lie"** (closed Nov 20; its decisions are in
    BACKLOG_COMPLETED.md):
    - when pressed again, evil backs into a spare or unknown walking gift (the ladder's step
      3, with the Demon and Scion careful and a Minion bolder);
    - the podium path: the same ladder at the meeting, not only in private.

  The first response, "Fine, I was out", is built (#368), and so is the private ladder that
  follows it.
  - **Plan approved (Michael, Nov 20):**
    - a good NPC that owned the night but kept the reason gets pressure checks that rise
      with each press, and a pass forces the gift or secret reveal;
    - a truly-home NPC stays home and grows irritated;
    - the Sleepwalker keeps its usual "I was at home" lines, and grows irritated the same
      way;
    - evil backs into a spare walking gift, the Demon included rather than stonewalling.
      With no spare, it's wary of a double claim. The Demon and a Scion are careful; a
      Minion is bolder;
    - the same ladder runs at the podium: private first, then the podium.

  [decided]

- **Good NPCs lie tactically.** (Nov 3 plan v8, zone 17; reframed Nov 18, Michael) Hiding a
  secret errand already exists (Beadle verified, Nov 18). Two cases are open:
  - **Shielding a friend:** not built. A good NPC bends the truth to cover someone it trusts.
  - **Lying about one's role:** may a good NPC lie about their gift, for example a Veteran
    falsely claiming another gift to draw the Demon's attack? Michael (Nov 18): yes, with a
    reason (avoiding or drawing the Demon's attention), fairly uncommon, possibly tied to
    Confidence. It doesn't volunteer the lie and picks the most harmless one available.
    Part of the secrets rework (`docs/design/secrets_rework.md`, sections 2 and 10.1).
  - **Retracting a public claim** to back into another gift, for good and evil, belongs here
    (Michael, Nov 19; see "More rebuttals after a caught lie").
  - **Gift-hiding fear should follow the gift's value to the Demon** (Beadle's idea, folded
    in Nov 20). How much a good NPC fears revealing its gift should follow the per-role
    kill-score table, not be the same for every info gift.
  A caught lie still implicates strongly, so both need care. The "holds their claimed
  gift" premise was merged into "is good" (Michael, Nov 20); revisit if this is decided.
  [open]

- **Rapport and Warden-credit leftovers** (social trust pass, Oct 30; Michael, Nov 20, on
  Beadle's proposals):
  - (a) "caught lying about me" as an NPC-to-NPC trust loss: waits for "Anger reasons";
  - (b) evil Wardens faking saves, and (c) the Warden's save as a reason to go public at the
    meeting: **[decided]**, one PR, owner Beadle;
  - (d) player wards the Warden knows about counting as an alternative explanation: closed,
    already built.

  [decided: direction]

- **Anger reasons.** NPCs track why they're angry at the player and say a fitting line.
  (Michael, Nov 19) Owners: Beadle (the tracking), Herald (the lines). [decided]
  - **Approved (Michael, Nov 19):** the NPC voices the standing grievance the player has
    repaired least, and the line replaces its refusal line.

### Numbers

- **The Seer's rise looks small.** A constructed true Seer "yes" on Day 1 raises the
  pair's combined P(evil) by about +0.11 to +0.14; a hand calculation gives about +0.22.
  Some true Seer pairs don't rise at all in the holder's own view (Day 3, seeds 6, 9, 24).
  Check against the current prior mapping. (Oct 30) Michael (Nov 18): saved for a dedicated
  role-tuning pass. [later: role tuning pass]

- **Dowser clearing strength.** Evaluate firing only on a positive ping instead of
  producing zero-count group clears. Specify whether "evil" means registered evil
  (including Marked), how poison and Delusional results behave, and when an absent ping
  is observable.
  Michael (Nov 18): moved to the role-tuning pass with "The Seer's rise looks small".
  [later: role tuning pass]

### Tentative social tuning (Oct 20–21 discussion)

Candidates for a unified retuning proposal, not approved changes.

- **Explicit night-sighting rebuttals.** Let NPCs argue "I was seen out, but no one died
  that night" or "the death happened on another block", as attributed defences rather
  than hidden scaling. Don't clear all movement or ignore thwarted attacks. [decided]

### UI

### Performance

The one performance item, "Late-game meeting and presenting cost", is in
[BACKLOG_WATCH.md](BACKLOG_WATCH.md) (Michael, Nov 18); performance work is Argon's.

## 3. Medium features (several days; touch a few systems)

- **Expanded dialogue and trust management** (Oct 20; design candidates; reworded Nov 18).
  [tentative]
  - **Built:** apologising for a specific incident, and the NPC-asked confidentiality
    promise (verified Nov 18).
  - **General requests spread through town chats:** "Someone should check Nisha" or
    "Someone should watch the Wharf", without outing a gift-holder. Hearing a request
    isn't volunteering or completing it.
  - **NPC credit for completing tasks:** a meaningful accepted task earns a small,
    non-repeatable rapport gain; later credit depends on what the NPC believes was
    accomplished. Don't reward incriminating results by default; prevent request spam.
  - **Responsibility and remorse after a bad hanging:** an NPC may feel guilt when their
    information helps execute someone who later looks innocent, based on perceived
    responsibility and known outcomes. (Oct 21)
  - **Ask what would change their mind:** expose friendship, conflicting information,
    distrust of the player, or preference for another execution as actionable
    resistance.
  - **Explain an execution's purpose:** propose an information-seeking execution (for a
    Gravedigger read) without asserting the target is the Demon.

- **Graded gossip.** Each gossip occasion has a budget of mixed-value items, so the player
  usually gets at least two useful pieces. (Michael, Nov 19) Owner Beadle, with Quill on the
  value tiers; plan first. [decided]
  - **Approved (Michael, Nov 19):** new constants `TAVERN_TIER1_TARGET` = 2 and
    `TAVERN_TIER2_TARGET` = 1. Tavern readings stay anonymous.

## 4. Major structural work (a week or more; design first)

- **Smarter evil** (Michael, Nov 20: three items folded into one, deferred with the bigger
  design features). Options note: [docs/design/evil_truth_timing.md](docs/design/evil_truth_timing.md).

  - **Evil sometimes tells the truth (start by faking it).** (user + Claude, Oct 25) A
    reading from a source who is evil in a world is uninformative there, so a reading that
    checks out is near-proof its source is good. Make it partial: an evil source's content
    is true with probability t, noise otherwise. Correct readings then exonerate less;
    false readings still implicate strongly. Same cost. Set t from the simulation (how often
    fake readings happen to be true in a bot run), not by hand, and re-measure whenever
    evil's reading strategy changes. Quill (Nov 18, 40 bot games): fakes are true 38% of the
    time against 45% by chance, so the judge's side changes nothing today. Michael (Nov 18)
    wants evil smarter about *when* it lies; options in
    [docs/design/evil_truth_timing.md](docs/design/evil_truth_timing.md), awaiting his call.
    [decided: add; t measured]

  - **Throw a teammate under the bus:** a pressured minion distances themselves from the
    Demon; the Demon goes along with town conclusions to build trust. Michael (Nov 17):
    decided, but survey what's already built first (he believes a fair amount exists: a
    Minion distancing itself under pressure, the Demon going along with the town even
    against a Minion), and report what happens and what's missing before building the gaps.
    Owner Beadle. [decided: survey first]

  - **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
    totems**. The Revenant is often invisible. (55774) [decided]

  [deferred]

- **Vigil request and reward rework** (Michael, Nov 20, deferred). It replaces "Ward promises
  should outrank vigil promises": a vigil no longer makes sense as something an NPC requests
  for itself, so how vigils are asked for and rewarded needs rethinking. The old item's
  notes:

  - **Ward promises should outrank vigil promises.** Raise the value of a kept ward promise
    and add plausible-success credit for a kept ward followed by a deathless night.
    Warden/Veteran intervention stays an alternative, not a reason to deny credit. Base
    credit on what the listener can observe; avoid crediting promise, protection and
    outcome twice. [decided: direction; amounts open]

  [deferred]

- **What does Insight do now?** (Michael, Nov 20, deferred) A general pass on what Insight
  does. It bundles two items. Owners Lantern and Beadle.

  - **Insight helps an NPC notice its own readings don't fit** (what's left of "NPCs voice
    doubt about their own readings", Beadle, Nov 20). The doubt and the line are built (#320,
    #316). Lantern says the judge's clash signal already catches a repeated pair flipping yes
    and no. The trigger is a flat 30% for everyone, though, and the item asked for higher
    Insight to notice a mismatch sooner. **Kept, low priority** (Michael, Nov 20). Owners Beadle
    and Lantern. [decided; triggers open]

  - **Higher-Insight NPCs weigh more broken-reading combinations** (Michael, Nov 19, with the
    Steward A3 fix). When a case holds several readings the listener doubts, the role check
    now weighs them symmetrically: all genuine, or exactly one broken
    (`CaseEval._doubted_role_fits`). The exact fix also weighs two or more broken at once,
    at 2^k role checks instead of k. The idea: sharper NPCs take the exact fix, duller ones the
    symmetric approximation. In 2 ten-NPC games (Nov 19), 43% of the role checks holding any
    doubted reading held two or more, up to four. Owner Lantern. **[tentative]**

  [deferred]

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
  - **Seen with the silenced.** (user, Oct 25) Being somewhere with a person who was later
    breath-stolen should add a little suspicion, enough to reward noticing it, without the
    player linking every location card. Options: (a) a flat circumstantial amount for
    everyone who shared a location with the silenced that day, scaled by how many others
    were there (a deliberate exception to "NPCs only know what they can see"); (b) a
    presentable "town comings and goings" card sharing the player's sightings of the day at
    once. [decided: add; option open]

    Since Nov 10 the judge weighs "who was near each silencing" itself
    (`DayPresence.breath_factor`), and since #157 (Nov 14) it assumes a Breathstealer that
    hunts. Check what's still missing for the player before choosing an option. (Folded in Nov 18, Michael.)

- **The secrets rework.** (Michael with Claude-Vicar, Nov 17; design note
  [docs/design/secrets_rework.md](docs/design/secrets_rework.md)) Two kinds: the
  self-unaware secrets (Marked, Delusional, Sleepwalker) stay enumerated by the judge; the
  ones the holder knows about become ordinary claims, which evil can bluff, and the player
  can argue an unclaimed one per case. The Muddler is cut (Michael, Nov 20; "Remove the
  Muddler", section 2). Backlogged by
  Michael (Nov 17) in favour of smaller items first; the note's section 9 has the staged
  plan for when it's picked up. Decide it alongside the Breathstealer overhaul: the room
  it frees could go to telling Minions apart. Michael (Nov 18), in the note's section 2:
  good NPCs may lie about their gift with a reason; every secret is unique; the hidden kinds
  (probably Delusional and Sleepwalker) are mutually exclusive by script. Not decided yet:
  plain folk and confidants (section 10). [open]
  - **Lovers as an excuse** ("I was with X"). Evil pairing two of its own is a two-for-one;
    pairing with a good person only works if real Lovers sometimes leave each other out to
    dry. **If evil ever fakes a Lovers confession**, `Solver.lovers_needs` (and its use in
    `Solver._solve` and `CaseEval._compile_impl`) must stop treating a confession as proof.
    [open] (Folded in Nov 18, Michael.)
  - **Secret awareness and bluffing.** Lovers' confessions carry a usable secret type and
    can explain night movement. Since #162 (triage 5.9) a Lovers confession also names the
    partner, and the solver treats it as proof of both, because evil never fakes one
    (`Solver.lovers_needs`). Triage 5.8 belongs here too: presenting a card about someone's
    secret to that person got Lian to disclose her gift. Michael: to an individual, present
    either a case or a card with a defined interaction. Decide whether holders know they're Marked, how one asks
    about it, and how evil can claim it too. Keep these as attributed claims, not alignment
    confirmations. (61251/25923) [open] (Folded in Nov 18, Michael.)
  - **Ways to discover and confront secrets:** sightings that don't fit, confidants, a
    "you have a secret" card used as leverage. (Personal items came out on Nov 19, when
    Michael decided to remove them.) [open] (Folded in Nov 18, Michael.)
  - **Softer secret breaches.** Secret-keeping rapport now decays nightly. Still to review:
    first-use and repeated breach losses and the permanent caps, keeping a real betrayal
    consequence while allowing proportionate recovery, with apologies and confidentiality
    promises. [decided; values open] (Folded in Nov 18, Michael.)

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
  - **Storyteller-driven Medium visits.** Today the Medium visits the most recent dead it
    hasn't visited (Demon victims first). Eventually: "I was called to Hollis's home to
    commune with his spirit", chosen by a director. (Oct 19) [open] (Folded in Nov 18, Michael.)

---

## Workshop gaps (NYI)

Patterns that come up in play, or that the mechanics make meaningful, but that the Case
Workshop and the shared model can't express yet.

- **Minion gifts: the Poisoner's visit.** A reading that failed on a night someone was near
  the reader's home. Half built: the doubt and the Mistaken call's candidates exist, and
  Quill is narrowing the candidates to people seen on the way to the reader's home (a bug
  fix Seneschal approved). Whether to add a real per-world Poisoner-presence factor goes to
  Michael. The other two Minion gifts are built and closed (Quill, Nov 20). Owner Quill.

- **A Medium's relayed sighting vs the dead's known vantage:** the dead watched or
  guarded a different block that night, so couldn't have seen what the Medium says.
  Still a gap (Quill and Lantern, Nov 20): the movement model checks a sighting against the
  route of the person seen, never against where the sighter was.

- **Duty claim vs reading:** the hearth in the Medium's *reading* ("at Dorian's hearth")
  as a destination, so a reading and a sighting can conflict, not only the alibi and a
  sighting.

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
- **The Test juror reporting a condition separately** (triage 5.1, the full version). #159
  built the cheap version: a premise → card link means "this card's line runs through that
  premise", labelled "given <premise>". The full version would have the juror say "if
  Fenwick is good, this is strong; Fenwick is good is moderate", which needs new juror
  machinery. **[later]**
- **Lian's stonewall after "let me tell you in my own words"** (triage 2.7): struck by
  Michael on Nov 16. The line isn't in the code as quoted, so it may have changed already;
  revisit if it turns up again.

## 6. The connections model: open items

From the belief-model doc's open items (`docs/belief_model.md`), as of Nov 16.

**The purge resumes (Michael, Nov 19).** Owner Lantern.
- Phase 7: **done** (#382).
- Phase 8: **done** (#386).
- Phase 6b: **done** (built Nov 17, 8fecdad). Re-measured on Nov 20: across 1,182 refreshes,
  reading attended cards against held cards changed no one's chance.
- Phase 6a waits for the reprioritization.

 **Argon's bloat and
obsolescence audit** (`docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md`) is to
be done "relatively soon, before we build any more larger features". Michael approved its
four groups on Nov 19; see "Argon's audit: cleanup" (section 2).

- **Honest mistakes against lies in challenges.** "Misled" and "failed gift" land 3–12% of
  the time on honest mistakes; to a listener an honest mistake and a lie are the same
  cards, so no rule separates them. It would need evidence that does (the teller's
  history, signs of poisoning). Since #296, misled and failed gift are one honest-mistake
  label, "Mistaken". **[open; Michael]**
- **The spoken reply to a later-day repeat.** Re-presenting a faded case restores its
  weight, but the reply may still say the assessment is unchanged. **Built** on
  `claude/repeat-reply` (Quill, Nov 20; handoff `2026-11-20-1130-quill-repeat-reply.md`).
  [in review]
- **A reason citing a pairing the model didn't weigh.** Attention picks what is cited, the
  connections model what is believed, so a reason can name cards the belief didn't combine.
  **[polish]**
- **The Sleepwalker's doubt, from what the Rumormonger tells her** (Michael, Nov 20). The
  flat doubt itself stays as it is (`Workshop.SLEEPWALK_SELF_DOUBT`, not scaled by
  confidence; moved to BACKLOG_COMPLETED.md). What's left:
  - **What the Rumormonger tells her.** A Rumormonger she trusts naming
    her as a possible sleepwalker should raise her own doubt, so a sighter who saw her out
    looks less evil to her. A Rumormonger naming a different secret, which implies no
    Sleepwalker is in play, should make that sighter look more evil. Both depend on her trust
    in the Rumormonger. Owner Lantern. **[decided]**, built after the reprioritization.
    - **Not working today** (Lantern, Nov 20): the Sleepwalker's own home doubt is fixed per
      game and never reads what she believes about secrets.
    - **Scope:** her doubt scales with her belief that she holds the Sleepwalker secret:
      - today's value when she has no evidence;
      - higher when a Rumormonger she trusts names her;
      - near zero when another secret is named, or the Sleepwalker is shown to be someone
        else.
    - **Golden** moves only in games with a Sleepwalker on the script and a Rumormonger
      reading.
    - **A possible cap** would be a new constant, Michael's call.
- **Brute kills scored as hexes on custom scripts.** **[later]**
- **Gift doubt for readings the judge doesn't check** (Lantern's proposal; Michael accepted,
  Nov 19). `OwnGiftDoubt` asks whether a reading's content holds, so it never fires for
  readings that hold in every world: a Warden's quiet night, a Lamplighter's count, a Night
  Watch list, a Psychologist's or Sexton's reading, or a Medium's relayed transmission. That
  was about 40% of own readings in the Nov 19 measurement. Their clash is weighed through
  movement, or not at all. Extending the doubt there would use the movement factor's own
  "this list or guard was broken" posterior. Owner Lantern. **[open]**
- **Persistence Confidence: a working theory that colours new evidence** (connections purge,
  Nov 17; Michael asked for it to be kept on the backlog). An experiment for live NPCs: a
  listener committed to a theory about someone (high Confidence) read new evidence through
  it, so moderate contrary evidence left the theory standing while a low-Confidence listener
  revised it. Tunnel vision of this kind fits "simulate a human mind". The connections
  refresh never read through a theory and live play didn't use it by default, so it is
  deleted with the purge. Revisit for the connections model. The code survives on the
  branch `archive/legacy-belief-final`. **[tentative]**
- **Observable actions as evidence (Stage 1B)** (may scale with Insight, like the exact
  broken-reading weighing from Steward A3). Votes, nominations, who defended whom and
  tie-breaks as soft per-world likelihood factors: "voted to execute someone who is good in
  this world" needs only each world's evil mask, so it adds no hidden dimension. Each
  action's rates for evil and good actors come from bot runs, not hand-set values. (user,
  Oct 24)
  - **Michael (Nov 19): don't build it now.** Reading the vote, nomination and defence record
    as evidence is left to the player, who cites votes in cases through the circumstantial
    hub. Later, high-Insight NPCs might read the public record themselves, softly, from
    bot-measured rates.
  - **Today (Quill's report, Nov 19):** NPCs' actions move trust and inclination, not
    suspicion. The exception is votes the player cites through the hub. Quill is fixing a
    double count in the hub.

  **[tentative]**

## Tabled

Kept for the record and a later look; not on the active list (Michael, Nov 18).

- **NPC-to-NPC credibility.** The player now has two numbers with each NPC (rapport and
  credibility). Split NPC-to-NPC trust the same way, so liking someone and believing
  their word can differ; source doubt is the natural place it plugs in. (Nov 1) [open]

  > **Tabled Nov 18 (Michael):** the interpersonal side of NPC relationships is already a bit
  > hard to read, and a second NPC-to-NPC number would dilute it further.

- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. Michael (Nov 17): stays open; it
  overlaps the backlogged secrets rework. [open]

  > **Tabled Nov 18 (Michael):** at night everyone is either home or out walking, and walkers
  > have no guarantee of seeing each other, so a named corroborator has no place as things
  > stand.

- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (open since playtest 1) [open]
  Tabled (Michael, Nov 18).

- **Procedural town:** blocks, buildings and roads generated per case. [deferred, Nov 8]
  Tabled (Michael, Nov 18; deferred since Nov 8).

- **Medium relays: later social consequences.** Relays keep both sources, the original
  and visit times and the original's health. Still open: who gains or loses trust, or is
  blamed, when a relay is challenged. (Oct 23) [open]
  - **Trust dynamics around sources.** A relayer may name their source outright, at the
    cost of that person's trust; evil may try to trace an unnamed source ("the Seer told
    me") back to a person, to kill or frame them. (Oct 19)
  Bundled and tabled (Michael, Nov 18).

- **Role hints from workplaces and haunts.** Occasionally reward searching an NPC's
  workplace or haunt with an attributed hint about their claimed or possible gift.
  Searches shouldn't become guaranteed hidden-role checks. (Oct 21) [open]
  Tabled (Michael, Nov 18).

- **Situational credence modifiers** still to settle: early disclosure, a quiet night as a
  credence boost, admission against interest, consistency over time, role-specific
  confirmations. [open]
  Tabled (Michael, Nov 18).

- **Talking to a group:** 3 questions per phase, split among anyone at the spot. [open]
  Tabled (Michael, Nov 18).

- **A false name in the daytime-whereabouts defence.** (Michael, Nov 19) An evil defender
  answering a daytime-whereabouts case names someone who wasn't there. The place and time
  stay true; only the names are false. It's a lie logged with its reason ("spread the
  suspicion"), and anyone who was there can catch it. Waits until the true-line defence ("A
  defence's answer to a daytime-whereabouts case") is built and played. Owner Beadle.
  Tabled (Michael, Nov 19).

- **A false "their readings agree with what I know".** (Michael, Nov 19) An evil NPC says it of
  a teammate with no such confirmation behind it, to save them at a vote. It would be a lie
  logged with its reason ("cover a teammate"), through `evil_override`. Waits until the honest
  version is built and played. Owner Beadle.
  Tabled (Michael, Nov 19).

- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration), and the
  Lovers' relationship mods, including the Lovers downside (when one dies, the other
  withdraws visibly). [open; Lovers downside decided]
  Tabled (Michael, Nov 20).

## Closed

Closed items live in [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md).

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

**Contents** (every open item, by section; closed ones are in BACKLOG_COMPLETED.md; `*` = in progress: a lead is building it or its PR is open)

- [1. Bugs and quick fixes (hours, low risk)](#1-bugs-and-quick-fixes-hours-low-risk)
- [2. Small features and tuning (a day or so each)](#2-small-features-and-tuning-a-day-or-so-each)
  - [Cases and the Workshop](#cases-and-the-workshop)
    1. \*Argon's audit: cleanup `[decided]`
  - [NPC behaviour](#npc-behaviour)
    1. Legwork that shapes the meeting `[open]`
    2. A friend's doubtful defence `[decided]`
    3. Withheld readings: asking for what someone hasn't said `[decided: direction]`
    4. A hidden Seer seeds its readings into the gossip network `[decided: direction]`
    5. A gift-holder seeks protection before revealing `[decided: direction]`
    6. \*The Gravedigger in a reluctant town `[decided]`
    7. Caught out and pressed again: what's left `[decided]`
    8. Good NPCs lie tactically `[open]`
  - [Numbers](#numbers)
  - [Tentative social tuning (Oct 20–21 discussion)](#tentative-social-tuning-oct-2021-discussion)
  - [UI](#ui)
    1. Show answers carried into the next case when filing `[decided]`
    2. \*Movement wording: "pass by" and "road" `[decided]`
  - [Performance](#performance)
- [3. Medium features (several days; touch a few systems)](#3-medium-features-several-days-touch-a-few-systems)
  1. Expanded dialogue and trust management `[tentative]`
  2. \*Graded gossip `[decided]`
- [4. Major structural work (a week or more; design first)](#4-major-structural-work-a-week-or-more-design-first)
  1. Smarter evil `[deferred]`
  2. Vigil request and reward rework `[deferred]`
  3. What does Insight do now? `[deferred]`
  4. The Breathstealer overhaul `[decided: add; option open]`
  5. \*The secrets rework `[decided; values open]`
  6. Learning resources: tooltips, an in-game wiki and a tutorial `[decided: direction]`
  7. Player toolbox `[open]`
  8. A case archive `[decided: direction]`
  9. Scoring system `[open]`
  10. Storyteller/director and solvability check `[open]`
- [Workshop gaps (NYI)](#workshop-gaps-nyi)
  1. Duty claim vs reading
- [5. From the Nov 13 playtest triage (moved Nov 16)](#5-from-the-nov-13-playtest-triage-moved-nov-16)
  1. An NPC defender's challenge isn't stored as a case `[deferred, Michael, Nov 13]`
  2. Presenting a card to one NPC
  3. The Test juror reporting a condition separately `[later]`
- [6. The connections model: open items](#6-the-connections-model-open-items)
  1. \*A reason citing a pairing the model didn't weigh `[polish]`
  2. Brute kills scored as hexes on custom scripts `[later]`
  3. Gift doubt for readings the judge doesn't check `[open]`
  4. Persistence Confidence: a working theory that colours new evidence `[tentative]`
  5. \*Per-person Demon odds for gifts that target the Demon `[decided]`
  6. "Not being seen out" as evidence `[open]`
  7. Observable actions as evidence (Stage 1B) `[tentative]`
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
listener (#273), both Lantern's; defenders weighing secrets the game can't deal (#432,
Lantern). Nothing is open here.

## 2. Small features and tuning (a day or so each)

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
     - **Tier 1: done.** `mind_meeting.gd` (#404), `mind_dialogue.gd` (#417), `world.gd`
       (#426) and `mind.gd` (#433), Beadle, with Lantern on `mind.gd`'s case side.
     - **Tier 2, under way:** Herald's splits are done: the live Workshop's field editors
       (#438), the canvas's card layouts (#439), and the voices, one file per character in
       `sim/voices/` (#458). `social.gd` is in review (Beadle, #452). Left: `live_activity` and
       `case_eval` (Lantern).
     - **Tier 3** waits for the purge.

  [decided]

### NPC behaviour

- **Legwork that shapes the meeting** (Michael, Nov 22). Today, who the player talks to during
  the day barely changes what's said at the meeting, so a day can feel anticlimactic when
  what NPCs told you comes out at the meeting anyway. The aim isn't to withhold more at
  meetings: hearing things early already helps the player plan and steer. The aim is for some
  of the player's legwork to go public *through* them. Three options, not yet chosen:
  1. **Headlines at the meeting, details from legwork.** Claims, readings and accusations still
     come out at the meeting. Small things (an incidental sighting, a remark, who someone spent
     the afternoon with) surface mostly when asked in private, as the connective tissue of a
     case. Some of this may already be how volunteered sightings work, so check first.
  2. **"You tell them": the confidant hands it to the player.** An NPC that trusts the player a
     lot may leave a private reveal for the player to raise. The player raises it and gets the
     credit, times it, or keeps the source hidden (it ties in with a hidden Seer seeding its
     readings through someone it trusts). The safeguard: if the player stays silent, the NPC
     speaks near the meeting's end ("Well, if you won't say it, I will…"). It's rare by design.
     Vicar's recommendation.
  3. **Private conversations shift what they push for:** an NPC the player has just shown a
     case to raises it itself, or backs the player's nomination.

  Owners when chosen: Beadle, with Herald for the lines. [open]

- **A friend's doubtful defence** (Michael, Nov 22). When a friend of the nominee is close to
  voting yes, it voices a doubtful defence: "I've known Kiran for a long time. He wouldn't be
  capable of something like this... would he?" (Michael's line, approved). It's a new voice tier.
  It replaces the proposal "a same-day defence holds back the vote", which Michael declined.
  Grief not fading stays as intended (Oct 30). Owners: Beadle (the trigger), Herald (the lines
  for each voice).
  - **Revised (Michael, Nov 22): two parts.**
    1. **The line tier,** as above (`support_doubt_for`, triggered for a friend close to yes).
    2. **Social pressure is damped for a voter who strongly trusts the nominee,** above a trust
       level. That covers the player's vote and consensus; evidence-based suspicion isn't
       damped.
  - **Why:** the Coroner found Isolde, at trust 0.95 and suspicion 0.18 toward Kiran, pushed to
    the edge of voting yes by Michael's vote and the consensus.
  - **Next:** Beadle proposes the shape and the constants.
  - **Lines** (Michael, Nov 22): the doubtful-defence lines for all 15 voices are approved, and
    use "they" for the nominee. A yes-side line is added for a friend who votes yes despite the
    bond (the "forgive me, Kiran" beat). Herald drafts it, and Michael approves the wording.

  [decided]

- **Withheld readings: asking for what someone hasn't said** (Michael, Nov 22; playtest 51795).
  Design in [docs/design/withheld_readings.md](docs/design/withheld_readings.md).
  - **NPCs ask in private:** now and then, an NPC asks a claimant for a reading it should
    already have, such as a first-night gift's.
  - **NPCs press at the meeting:** rarely, a confident NPC presses someone it suspects of
    holding back.
  - **The cost:** a deferral with a reason costs a little, a bare deflection more, and the cost
    builds by day.
  - **The player's version:** one softer ask per meeting, outside a nomination. Refusing costs
    some suspicion and makes a circumstantial card.

  Owners: Beadle (behaviour), Lantern (the cost), Herald (the UI and lines), Quill (the card).
  The action's name is Michael's. [decided: direction]

- **A hidden Seer seeds its readings into the gossip network** (Michael, Nov 21). Before
  revealing, a Seer passes its information through someone it trusts, as hearsay, so the town
  is pointed the right way without exposing the Seer. From
  [reading_interpretation.md](docs/design/reading_interpretation.md) section 2.1; it may
  generalise to other gifts as the note grows. Owner Beadle. [decided: direction]

- **A gift-holder seeks protection before revealing** (Michael, Nov 21). A Seer planning to
  reveal looks for protection first, from the player or a known Warden. Same source; it may
  generalise. Owner Beadle. [decided: direction]

- **The Gravedigger in a reluctant town.** (54875) With no executions the Gravedigger has
  nothing to read. A Gravedigger who knows this could push the town to hang someone ("so
  I can tell you what they were"), which also gives a cautious town a reason to act.
  Michael (Nov 17): as a hidden motive only. A good Gravedigger with nothing to read leans
  a little more toward nominating and voting to hang, but never says so: these are real
  people who wouldn't hang a neighbour to read the body. No new lines; a logged reason
  for the lean, as for any decision. Keep the lean modest. Owner Beadle. [decided]
  - **Approved (Michael, Nov 20, later):** `GRAVEDIGGER.nothing_to_read_lean` = 0.08. The
    lean is **permanent** for a good Gravedigger: it doesn't wear off.

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

### Numbers

### Tentative social tuning (Oct 20–21 discussion)

Candidates for a unified retuning proposal, not approved changes.

### UI

- **Show answers carried into the next case when filing** (Michael, Nov 22; playtest 23973).
  An answer the player picked on a Workshop card carries into the next case without being
  shown. Low priority. Owner Herald or Quill, as they agree. [decided]

- **Movement wording: "pass by" and "road"** (Michael, Nov 20). The town moves block to
  block, so:
  - the Night Watch card's "pass by" is reworded, along with the Vigil tooltip's "passing
    through": Herald #448;
  - no voiced line says "road": Herald #446, merged.

  **Wording approved (Michael, Nov 20):**
  - **#446, the no-roads rewording:** approved as drafted, with its kept phrases: the
    Lamplighter's "lamp route", the Augur's "crossed paths", the idiom "a long road from
    murder", and general street flavour.
  - **The Night Watch card:** "I watched {block}: I saw A and B out." With one person, "I saw
    A out." With nobody, "nobody stirred".
  - **The Vigil tooltip:** "You only see if its residents leave home. You do not see people
    arrive on this block from elsewhere."

  The Night Watch card and Vigil tooltip are in Herald's #448, first in the golden queue;
  the item closes when #448 merges. Owner Herald. [decided]

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
  - **The tiers (Michael, Nov 20, later):**
    - **Tier 1:** a reading or other stated information, or a night sighting that names a
      place;
    - **Tier 2:** role claims, hints and secrets;
    - **Tier 3:** everything else.

    The targets stay at 2 and 1, and Beadle's budget calls are approved.
  - **Value tiers built** (Quill, Nov 20, `claude/gossip-tiers`; handoff
    `2026-11-20-1215-quill-gossip-tiers.md`), as approved above. Measured: the targets are
    both met on about 4% of tavern evenings today, though the town's news would allow it on
    about 84%. Merged (#431, Nov 20).
  - **Budget built** (Beadle, Nov 20, #437; handoff `2026-11-20-1400-beadle-gossip-budget.md`):
    each evening fills its tier-1 and tier-2 targets first, then draws as before. Both targets
    are met on about 73% of evenings (from 3%). Merged (#437, Nov 20).

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

  - **Evil's fake self-doubt and the Poisoner nudge** (Beadle's proposal; Michael, Nov 20).
    Since "A reader's self-doubt points at the Poisoner", evil's fake gift self-doubt also
    nudges Poisoner suspicion toward whoever was seen on its block, its own teammate
    included. Smarter evil could aim it (voice the doubt when an innocent was near) or avoid
    it (stay quiet when a teammate was). Owner Beadle.

  - **Fewer bare accusations** (Michael, Nov 22): evil should make roughly 10% fewer accusations
    with no evidence behind them, since they still read a little obvious.

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
  - **A vigil-specific anger line** (Michael, Nov 21): the broken-promise anger line stays
    generic for wards and vigils until this rework settles how vigils are asked for; then
    Herald writes the vigil one.

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
  Muddler", section 2). **Scoping under way (Michael, Nov 20):** secrets become
  "burdens"; at most one hidden burden per script; a first slate of Delusional (hidden),
  Marked, Unrequited and Ill-Omened (known); one burden per script for now. Michael
  answered every open question the same day, and chose judge model A. **Prototype stage 1
  started** (Michael approved, Nov 20) on `mock/burdens-slot`: Lantern on the slot world domain
  with Marked known, Beadle on Marked's disclosure, defence and bluff, and both retiring the
  Lovers and Sleepwalker 1.0. All in
  [docs/design/burdens.md](docs/design/burdens.md). Backlogged by
  Michael (Nov 17) in favour of smaller items first; the note's section 9 has the staged
  plan for when it's picked up. Decide it alongside the Breathstealer overhaul: the room
  it frees could go to telling Minions apart. Michael (Nov 18), in the note's section 2:
  good NPCs may lie about their gift with a reason; every secret is unique; the hidden kinds
  (probably Delusional and Sleepwalker) are mutually exclusive by script. Not decided yet:
  plain folk and confidants (section 10). [open]
  - **Values set (Michael, Nov 21; burdens.md section 14):**
    - the Unrequited walks 65% of nights, at least every other night;
    - the generic 10% secret-errand allowance retires;
    - an Unrequited reveal costs good listeners' trust like a spread secret;
    - the spell breaks at "truly suspects".

    The stage-2 judge model is held for Argon's report.
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
  - **Progression and the toolbox scoped** (Michael, Nov 21):
    [docs/design/progression.md](docs/design/progression.md). Score gives XP and levels,
    which unlock characters, roles, tools, perks and challenges. Two tool slots, and tools
    generate cards. Tool and perk pitches are listed, all with placeholder names.

- **A case archive** (Michael, Nov 21). Past cases are kept per profile, with lifetime
  stats (Demons named, lies caught and so on), and each one can be replayed through the grim
  reveal. It's part of progression and shares the end screen with the reveal and scoring
  ([grim_reveal.md](docs/design/grim_reveal.md)). The details wait for the progression
  design note. Owner Herald. [decided: direction]
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

- **A reason citing a pairing the model didn't weigh.** Attention picks what is cited, the
  connections model what is believed, so a reason can name cards the belief didn't combine.
  **[polish]**
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
- **Per-person Demon odds for gifts that target the Demon** (Michael, Nov 21). A Seer picks
  the person most likely to be the Demon, not the most likely evil. That needs each NPC to hold
  a per-person chance of being the Demon specifically. Being built on the Burdens prototype. From
  [reading_interpretation.md](docs/design/reading_interpretation.md) section 2.1. Owner Lantern;
  Beadle uses it for the Seer's picks. **[decided]**
- **"Not being seen out" as evidence** (Michael, Nov 21). Today nothing clears someone for not
  having been seen out at night: the judge ignores the chance of being spotted, and only a
  complete watch list or coverage says someone wasn't out. It goes under the circumstantial
  hub, since it's hard to confirm and subject to chance. From
  [reading_interpretation.md](docs/design/reading_interpretation.md) section 1.3. Owner
  Lantern. **[open]**
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

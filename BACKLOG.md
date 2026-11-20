# Demonologist backlog

The single to-do list, sorted by effort. DESIGN.md stays the record of how things work
and why. Built, settled and parked items move to [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md);
presentation-only work (flavour, wording, visual flair) lives in
[BACKLOG_POLISH.md](BACKLOG_POLISH.md); exploratory mechanics (new roles, places, ideas
still being shaped) live in role_exploration.md. Items being watched, and knobs to reach for
only if needed (`[watch]`, `[knob]`), live in [BACKLOG_WATCH.md](BACKLOG_WATCH.md); tabled items are
in the Tabled section at the bottom.

**State of play (Nov 16):** the connections belief model is on in play, and since purge
phase 3 (Nov 18) it's the only one (design and spec in [docs/belief_model.md](docs/belief_model.md)).
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

No known bug that moves golden is waiting. Fixed since Nov 17: a case with no cards answered
from an older compile (#192); an evil Medium's relay about the first victim naming night 0
(Beadle); a relayer cut from the sighter contest (#265) and a Night Watch list naming the
listener (#273), both Lantern's.

## 2. Small features and tuning (a day or so each)

### Playtests 78148 / 77388: deferred follow-ups (user, Oct 27)

- **Demon detours exist in inference but not in actual movement.** (77388) The movement
  model gives the Demon a 5% detour, and listeners are told a detour is possible, but the
  Demon never actually detours. Decide which is authoritative, then reconcile the
  evaluator, the movement and the explanatory dialogue; compare inference, votes, RNG
  and timings on fixed replays. Michael (Nov 17): the Demon still never detours, so
  remove the detour from inference: drop it from what NPCs assume and from the
  explanatory dialogue (Herald for any wording), and compare inference and votes on fixed
  replays. Owner Beadle. [decided] **In flight:** Beadle's #365 (open).

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
  **Michael (Nov 18): build B at a bystander share of 1/3,** reusing step 1's
  `premise_shaping` selection (`docs/design/premise_centring.md`; built as
  `Shared.brought_by_premise`, and `premise_shaping` itself was deleted in purge phase 5). No extra trust cost for a
  misframed case: the case not landing is the cost (Michael, Nov 18). Owner Lantern.
  **[decided]: B at a share of 1/3** **Built** (Lantern, #246; Marked's knock-on is in the
  secrets rework). What's left is point 3's preview hint for a misframed case, never built.
  Close once Lantern confirms.

- **Reading challenges and further gift adapters.** Misled and lying modifiers, Surveyor
  skepticism, alibi support and the Clerk, Archivist and Seer adapters are built. Dated
  outcomes, nested relays and conversion histories are still unsupported. See
  [docs/archive/CASE_WORKSHOP_FINDINGS.md](docs/archive/CASE_WORKSHOP_FINDINGS.md) for the
  expansion checkpoints. [watch; broader adapters open]

- **Summarised answers at a nomination.** A case presented at a nomination gets
  summarised answers, the same as at the meeting (#373). (Michael, Nov 19) Owner Herald.
  [decided]

- **Remove drops altogether.** (Michael's own item, Nov 19) Remove:
  - walkers dropping anything on their route, both personal items and the home-block
    material drops (already dead);
  - the search finding them;
  - the night "out" card a personal item makes for its owner;
  - every mechanic that weighs a drop as evidence.

  No measurement first (Michael). It moves golden and ships alone: `LEGACY_EXTRA_SHIFT_DRAW`
  is split off and deferred (Nov 20; see "Argon's audit: cleanup"). Owner Quill, with
  Beadle reviewing the sim side.
  **`search` stays at the eight town locations** (Michael, Nov 19). It still finds the
  Revenant's totem and the place's regulars. [decided]

- **Argon's audit: cleanup** (Michael, Nov 19, approving all four groups;
  `docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md`). Before any more larger
  features.
  1. **Dead code, zero drift:**
     - the Workshop scaffolding used only by fixtures (Lantern);
     - retired flags and constants that nothing reads (Beadle);
     - the dev labs and the trace viewer (Herald);
     - the one-off scripts in `tools/` (Bailiff sweeps).

     Keep `ALLOW_NO_GIFT_DENIAL` and `USE_FLAVOR_SECRETS` until the secrets rework decides.
  2. **Golden-moving:**
     - **Removing `LEGACY_EXTRA_SHIFT_DRAW` is deferred** (Michael, Nov 20). It's split from
       the drops PR, because it reshuffles every deal and would mean about 25 to 30 suite
       fixes. Michael decides at the reprioritization whether to do it at all.
     - Deleting the Muddler is held for the secrets rework.
  3. **The `channel_*` factored-evidence stack:** about 2,400 lines with no live caller.
     Deleting it removes `test_workshop_channels`, `test_workshop_channel_likelihood` and
     `profile_channel_likelihood`. Lantern, alongside the purge phases; Argon is told about
     the profiler. **Done** (Lantern, Nov 20, `claude/delete-channel-stack`): also took
     `test_channel_sum_product`, `test_workshop_class_parity`, and the oracle parity checks in
     four role suites.
  4. **File splits,** one file per PR, with no change to play:
     - **Tier 1** follows Beadle's in-flight work (#365, #327, #368, the symmetric vote,
       the double claims): `mind_meeting.gd`, `mind_dialogue.gd`, `world.gd` and `mind.gd`
       (Beadle, with Lantern on `mind.gd`'s case side). Herald's `ui/main.gd` can go as soon
       as the leads unpause.
     - **Tier 2** follows Tier 1: the voices (Herald), `social.gd` (Beadle), the Workshop UI
       (Herald), `live_activity` and `case_eval` (Lantern).
     - **Tier 3** waits for the purge.
  5. **Point `game.gd`'s passthroughs straight at their modules** (Michael, Nov 19). When
     `game.gd` was split, it kept forwarding functions. About 138 of its 159 functions are
     one-line forwards to `GameBoard`, `GamePresentation` and the other `game_*` modules.
     Callers should use the module directly, and the forwards should go.
     - **Owner:** Herald (`game/` and the UI), with each lead updating callers in its own
       files where that's simpler.
     - **Zero drift.**
     - **Scheduled with the file splits:** it touches many callers (`add_card` alone has
       about 325 call sites, many in tests), so the merge-conflict risk is the same.
     - **Herald scopes it first,** saying which forwards, if any, are worth keeping as the
       game's public interface.
  6. **Two more (Michael, Nov 20):**
     - (a) Retire `tools/connections_prototype.gd`. Owner Lantern.
     - (b) Merge `game.gd`'s `_workshop_native_submission` into `_workshop_native_social`,
       and drop the dead branch. Owner Herald.
  7. **Strict mode, removed** (Herald's #384; Michael, Nov 20). A partly-ready case is moot:
     in play, no listener fails to weigh a case on its own (Herald's check of golden and
     autoplay). The preview's false "fallback" sentence goes, and the preview shows only the
     case's issues.

  [decided]

- **The social presentation route.** (Michael, Nov 20) What's weighed socially when the
  player presents should move onto the current social plumbing, not the old
  `PresentationReply._social` route. Michael doubts the town-wide "protect this person" path
  is worth keeping. Herald scopes it, and a decision follows the scope.
  - **Decided (Michael, Nov 20): remove it.** Herald's scope found the route unreachable in
    play: there are no protect or spare cases and no bare beliefs, and the evil fallback
    only follows from those. Herald deletes it in a zero-drift PR. **[decided]**

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
  gifts actually threaten evil. Michael (Nov 17): review and tune. Adjusting existing
  values is the owner's call; a new per-role bonus constant is new, so propose it through
  Seneschal first. Owner Beadle. [decided]

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
  [decided: pitch first]

- **The Gravedigger in a reluctant town.** (54875) With no executions the Gravedigger has
  nothing to read. A Gravedigger who knows this could push the town to hang someone ("so
  I can tell you what they were"), which also gives a cautious town a reason to act.
  Michael (Nov 17): as a hidden motive only. A good Gravedigger with nothing to read leans
  a little more toward nominating and voting to hang, but never says so: these are real
  people who wouldn't hang a neighbour to read the body. No new lines; a logged reason
  for the lean, as for any decision. Keep the lean modest. Owner Beadle. [decided]

- **Follow-up after a false alibi is established.** The good NPC's first response can
  concede "Fine, I was out. Doesn't mean I was doing anything wrong." Later: pressure
  checks and possible forced revelation of the hidden gift or secret, with proper
  handling of genuine home accounts, unremembered outings and evil cover. (44814)
  [decided; mechanics open]

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
  A caught lie still implicates strongly, so both need care. [open]

- **Evil backs into a bluff.** An evil NPC that hasn't claimed yet can switch its planned
  bluff when another unclaimed gift would serve better (the Poisoner planned Seer, is
  seen out at night, and nobody has claimed Night Watch). This opens double claims (the
  real Night Watch may just be quiet), which need their own logic; once handled, fake
  Mediums and evil generally can make bolder lies. (Oct 19) **On hold** (Michael, Nov 19)
  until "Good NPCs lie tactically" is designed and decided. [decided; on hold]
  - **Hold lifted for one case (Michael, Nov 19):** when someone else claims evil's planned
    bluff first, evil switches to a spare from its bluff list. The list holds only gifts not
    in play, so a spare has no real holder. Owner Beadle. The rest (backing into a walker
    when caught out, and double claims) is in "More rebuttals after a caught lie". Not
    started: Beadle's #368 lists it for its next PR.

- **Rapport and Warden-credit leftovers** (social trust pass, Oct 30):
  - "caught lying about me" as an NPC-to-NPC trust loss (no clean hook yet);
  - evil Wardens faking saves (an evil-strategy change, measured separately);
  - the Warden telling the town about a save at the meeting, beyond ordinary disclosure;
  - player wards the Warden knows about counting as an alternative explanation.

  [decided: direction]

- **A daily nudge to share a gift privately.** Each day past day 1, NPCs who haven't claimed
  a gift publicly get a small boost towards sharing it privately, to feed the gossip
  network. (Michael, Nov 19) Owner Beadle, who proposes the size. **In flight:** Beadle's
  #327 (open). Michael approved its new constant, `Social.SHARE_UNCLAIMED_DAY_BOOST` = 0.15, on
  Nov 19: from day 2, good NPCs share privately about a fifth more often. [decided]
  Built (Nov 19, `claude/beadle-private-share`): the weight of an unclaimed NPC's gift topic
  and its own readings in private NPC talk is multiplied by 1 + 0.15 x (day - 1). NPC-to-NPC
  only; evil's bluffed gift and fake readings get the same. Measured on 40 games: see the PR's
  handoff.

- **Anger reasons.** NPCs track why they're angry at the player and say a fitting line.
  (Michael, Nov 19) Owners: Beadle (the tracking), Herald (the lines). [decided]
  - **Approved (Michael, Nov 19):** the NPC voices the standing grievance the player has
    repaired least, and the line replaces its refusal line.

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
  evil's reading strategy changes. Quill (Nov 18, 40 bot games): fakes are true 38% of the
  time against 45% by chance, so the judge's side changes nothing today. Michael (Nov 18)
  wants evil smarter about *when* it lies; options in
  [docs/design/evil_truth_timing.md](docs/design/evil_truth_timing.md), awaiting his call.
  [decided: add; t measured]

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

- **Privacy without compounding trust penalties.** Remove Privacy from initial player
  trust and benign trust changes; let high Privacy scale only what a private person would
  resent (intrusive pressure, revealing secrets). Keep the disclosure gates. Distinguish
  ordinary questions on different topics from repeating a refused question. (54875: on
  Day 1 three of three people stonewalled; Privacy counts in both openness and starting
  trust. The first day swings a lot on how many private characters are dealt.) Consider
  removing the double count or dealing at least one openish person per phase. [tentative]

- **Ward promises should outrank vigil promises.** Raise the value of a kept ward promise
  and add plausible-success credit for a kept ward followed by a deathless night.
  Warden/Veteran intervention stays an alternative, not a reason to deny credit. Base
  credit on what the listener can observe; avoid crediting promise, protection and
  outcome twice. [decided: direction; amounts open]

- **Explicit night-sighting rebuttals.** Let NPCs argue "I was seen out, but no one died
  that night" or "the death happened on another block", as attributed defences rather
  than hidden scaling. Don't clear all movement or ignore thwarted attacks. [decided]

- **More rebuttals after a caught lie.** Beyond admitting or stonewalling: concealed
  walking duties, personal secrets, protecting a confidence. Conceding the statement was
  false need not concede evil. Evil gets the same excuses, open to later corroboration;
  the caught lie itself stays. [decided; options open]
  - **Michael (Nov 19), on Beadle's options:**
    - **Yes:** an evil NPC borrows the excuses. It claims a walking duty that fits its bluff
      ("I was keeping the watch"), or says "being out isn't wicked". Each gets a logged
      reason and a reveal line.
    - **Yes, as the first line of defence: own the night, keep the gift.** See the shared
      ladder below. Michael: "duties that aren't mine to tell" isn't the right wording; the
      default "I'm not ready to share my gift" line (`gift_refusal`) should work in most
      cases. Herald's call on the final wording.
    - **After the secrets rework:** a vague errand of its own, which becomes "claim a
      knowing secret".
    - **No:** "I gave my word I wouldn't say why". It has no place in the current mechanics.
    - **How much an excuse softens the caught lie:** a little, until something contradicts
      the excuse, such as a claimed watch with no watch report. Then the excuse counts as a
      second caught lie. This needs a new constant; Beadle proposes about half a caught
      lie's weight.
    - **Scope:** lies about being home only. Caught reading lies already have "my gift may
      have been turned".
  - **When to risk a walking-gift claim (Michael, Nov 19): one ladder for good and evil.**
    A good walker who hides its gift should behave the same way, so the response isn't a
    tell.
    - **What exists (read from main):**
      - **Evil whose planned bluff walks** already owns the outing with that duty, as a good
        walker does (`MindDialogue._bluff_outing`).
      - **A good hidden walker** asked about the night can refuse honestly, lie "home", or
        stonewall (`lie_or_stonewall`).
      - **Caught out of a home alibi in private,** a good hidden walker reveals its gift
        outright (`trapped_explanation` to `answer_gift`). No tier sits between stonewalling
        and revealing.
    - **New soft tier, for both:** "Fine, I was out", then the default gift refusal. It
      claims a night duty without saying which. This keeps 78148's fix: the night is owned
      first, never a bare gift refusal to a whereabouts case.
    - **The ladder**, for an NPC caught out of its home alibi:
      1. If its gift (or evil's bluff) already walks and is claimed, it gives that duty.
      2. Not yet claimed: the soft tier above.
      3. Pressed again, in private by the player or at a nomination, it names a gift:
         - a good walker reveals its real gift;
         - evil takes the safe spare from its bluff list, if one walks (that list holds only
           gifts not in play, with one spare beyond the gifts the team uses, `world.gd`
           `bluffs`), for any evil type;
         - evil takes an unknown walking gift: the Demon or a Scion only when badly exposed,
           a Minion when exposed, at the existing blend-or-disrupt odds;
         - a Minion takes a walking gift someone has already claimed: a deliberate double
           claim, when confronted privately by the player or nominated. Michael widened this
           from "nominated only".
      4. Already claimed a non-walking gift: "being out isn't wicked", the sleepwalk bluff, or
         a stonewall.
    - **New: a Minion entering a double claim unprompted.** There's a small chance that an
      unclaimed Minion, never a Scion, claims a gift someone else has claimed, not because
      it's caught out. The rate would be a new constant, for Beadle to propose with a
      measurement.
      - **Michael (Nov 19):** about 0.05 if it's a deliberate opt-in to a double claim, or
        about 0.15 if it's a Minion accepting the risk that its bluff ends in one. Beadle is
        confirming which applies, and the value follows from that.
    - **Retracting a public claim to back into a walker:** Michael (Nov 19) moves it to "Good
      NPCs lie tactically", since the two share the same space.
  - **The town's response to a double claim (Michael, Nov 19).** The true holder counterclaims
    immediately. A Minion's active double claim works in the same framework.
    - **What exists (read from main):**
      - **At a meeting,** a public claim of someone's gift moves that person up to speak next,
        with an openness bonus (`MindMeeting._queue_reactions`, trigger 1;
        `REACTIVE_OPENNESS_BONUS`). Whether they then claim is still the ordinary
        `_public_claim_decision` roll, so it isn't certain. An evil NPC whose planned bluff
        was just claimed gets the same trigger.
      - **At a nomination,** a hidden holder of the gift the nominee claims comes out: "X is
        lying. That gift is mine." (`MindSupport`, `counter_claim`).
      - **Pressed in private** with a rival's claim, a claimant answers "I am the X. If Y says
        otherwise, Y is lying."
      - **Belief:** the two claims of one gift are one pairing that raises both claimants and
        shifts onto the other when one is shown good (#198).
    - **Proposed (Vicar), for Michael:**
      - **The true holder counterclaims at once:** at the same meeting, as the next speaker,
        unless silenced. The trigger-1 reaction becomes a claim, not a roll. If the claim
        reached it outside a meeting (in private, or through gossip), it counterclaims at the
        next meeting. A holder hiding its gift for a reason is "Good NPCs lie tactically"
        territory, not an exception here.
      - **The Minion's active double claim uses the same trigger:** when a good NPC claims a
        gift, an unclaimed non-Scion Minion may treat it as "a rival claim on my gift" and
        counterclaim with the same line, at the small new rate. The rest follows the
        existing pairing and counter-claim reactions.
      - **Evil whose planned bluff is claimed by someone else** drops that bluff for a spare,
        rather than counterclaiming. A Minion may instead take the active double claim above.
    - **Michael (Nov 19):**
      - **Immediately, where possible.** A silenced holder counterclaims at its first chance,
        the next meeting. That's the same rule as for a claim heard outside a meeting.
      - **Heat lowers a Minion's willingness to risk a double claim,** both the active one and
        backing into a claimed or unknown gift. Heat here means already being implicated as
        evil (mainly a Dowser reading, possibly a Surveyor's). Use the general "heat on me"
        calculation, not special logic: `Evil.exposure`, whose public talk includes the
        town's reading of those claims.
      - **A note for the build:** in the ladder, being pressed or nominated is what makes
        evil answer. The heat already on it is what makes a double claim a poor bet. So the
        same exposure parts play two roles: the pressure and on-the-block parts push it to
        answer, and the public-talk part holds it back from a double claim. Beadle to propose
        how they combine.
    - **Evil whose planned bluff is claimed first switches to a spare** (Michael, Nov 19:
      yes). See "Evil backs into a bluff", whose hold is lifted for this case.
    - **The private "they're lying" refutation** (Michael, Nov 19): a caught-out NPC may call
      the witness against it a liar in a private press too. Today it does so only in the
      meeting defence (`mind_meeting.gd`, for Confidence above 0.6). It's a line only, with
      no extra doubt on the witness. Owner Beadle; Herald's `press_witness_lying` lines are
      approved.
    - Owner Beadle; Herald for any new lines.

  Owner Beadle; Herald for the lines.
  - **Progress (Nov 19):**
    - **Built:** Lantern's #367. A sleepwalk claim excuses a caught "I was home" only as far
      as its claimant may be good. That fixes the evil-bluff gap Beadle found.
    - **In flight:**
      - Beadle's #368 (open): the ladder's private side, with the soft tier, the gift named
        when pressed again, evil's walking duty and "being out isn't wicked", and excuse
        facts for the judge.
      - Lantern's #372 (open): excuses soften a caught "I was home", and an NPC's "I was
        out" reads as what it says.
    - **Not started:** the podium path, backing into a spare or unknown gift, the Minion's
      double claims, the true holder's sure counterclaim, the switch when a bluff is taken,
      and the private "they're lying" line.

- **Misled versus reading-lie strength.** Compare how far "misled" and "lying" challenges
  move a reading at equal effective weight, with night scope and self-knowledge included.
  [open]
  Michael (Nov 18): being handled now, with "Recovering from a wrong 'lying' call" and
  "The player's 'poisoned, not lying' call" (section 2, Cases and the Workshop).
  Quill (Nov 18): Michael chose three labels after the label audit. "Misled" and "failed
  gift" are now one honest mistake (honest doubt at the player's credibility, "the reader is
  good"), labelled "Mistaken". Delusional is unchanged. Measurements are in
  `docs/handoff/2026-11-18-2331-quill-honest-mistake.md`.

### UI

- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main view;
  people who aren't talking or working showing on the map; a wrong role guess blocking
  process of elimination.

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

- **NPCs voice doubt about their own readings.** Notice apparently inconsistent results
  (repeated Seer checks of the same pair changing yes/no) and let the NPC say something's
  unusual; higher Insight helps notice a mismatch with their leading explanation. Use only
  what they know, allow legitimate changes such as succession, and keep suspicion of
  misdirection apart from admitting a lie. (Oct 21) [decided; triggers open]

- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems**. The Revenant is often invisible. (55774) [decided]

- **NPCs find evidence** (traces). [decided] Personal items are no longer part of it: they're
  being removed (Michael, Nov 19; "Remove drops altogether", section 2).

- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers meeting
  too as noise. Michael (Nov 17): stays open; finish the [decided] "Evil meetings are
  over-weighted and always visible" first, then see what's left. [open]

- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  Demon; the Demon goes along with town conclusions to build trust. Michael (Nov 17):
  decided, but survey what's already built first (he believes a fair amount exists: a
  Minion distancing itself under pressure, the Demon going along with the town even
  against a Minion), and report what happens and what's missing before building the gaps.
  Owner Beadle. [decided: survey first]

- **Graded gossip.** Each gossip occasion has a budget of mixed-value items, so the player
  usually gets at least two useful pieces. (Michael, Nov 19) Owner Beadle, with Quill on the
  value tiers; plan first. [decided]
  - **Approved (Michael, Nov 19):** new constants `TAVERN_TIER1_TARGET` = 2 and
    `TAVERN_TIER2_TARGET` = 1. Tavern readings stay anonymous.

## 4. Major structural work (a week or more; design first)

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
  - **Storyteller-driven Medium visits.** Today the Medium visits the most recent dead it
    hasn't visited (Demon victims first). Eventually: "I was called to Hollis's home to
    commune with his spirit", chosen by a director. (Oct 19) [open] (Folded in Nov 18, Michael.)

---

## Workshop gaps (NYI)

Patterns that come up in play, or that the mechanics make meaningful, but that the Case
Workshop and the shared model can't express yet.

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
- **One pass over every bluffer** for the "too clean when an ally is involved" tell that
  gave Kiran's Dowser away in 97626 (the Dowser itself was reworked in #160 to Michael's
  guidelines: within about 1 of the truth, the group size setting the room). For
  comparison, the Surveyor frames the scapegoat's block 60% of the time, clears a
  teammate's block half the rest, or picks at random; the Seer never gives a "no" that
  covers the scapegoat. Michael (Nov 17): review every bluff rule against the Dowser's
  #160 guideline (stay close to the truth; the situation sets the room) and fix the tells.
  Pairs with the better-lie rework, which touches every bluff's alternatives. Owner
  Beadle. **[decided]** A pass was built in #264 (Beadle). Close once Beadle confirms it
  covered every bluff rule.
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

**The purge resumes (Michael, Nov 19)** after Lantern's current work: phase 7, then phase 8,
then the phase 6b measurement for Michael, then 6a. Owner Lantern. **Argon's bloat and
obsolescence audit** (`docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md`) is to
be done "relatively soon, before we build any more larger features". Michael approved its
four groups on Nov 19; see "Argon's audit: cleanup" (section 2).

- **Honest mistakes against lies in challenges.** "Misled" and "failed gift" land 3–12% of
  the time on honest mistakes; to a listener an honest mistake and a lie are the same
  cards, so no rule separates them. It would need evidence that does (the teller's
  history, signs of poisoning). Since #296, misled and failed gift are one honest-mistake
  label, "Mistaken". **[open; Michael]**
- **The spoken reply to a later-day repeat.** Re-presenting a faded case restores its
  weight, but the reply may still say the assessment is unchanged. **[polish]**
- **A reason citing a pairing the model didn't weigh.** Attention picks what is cited, the
  connections model what is believed, so a reason can name cards the belief didn't combine.
  **[polish]**
- **Sleepwalker self-doubt scaled by confidence** (10% flat, `Workshop.SLEEPWALK_SELF_DOUBT`).
  **No change** (Michael, Nov 20): a Sleepwalker "should be aware it's a possibility, but I
  think the odds are more likely it's a frame." The flat doubt stays, and it won't be scaled
  by confidence. **[settled]**
  - **What the Rumormonger tells her** (Michael, Nov 20). A Rumormonger she trusts naming
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
- **Adjudicating a muddled card** (the Muddler secret). **[later]**
- **Brute kills scored as hexes on custom scripts.** **[later]**
- **Gift doubt for readings the judge doesn't check** (Lantern's proposal; Michael accepted,
  Nov 19). `OwnGiftDoubt` asks whether a reading's content holds, so it never fires for
  readings that hold in every world: a Warden's quiet night, a Lamplighter's count, a Night
  Watch list, a Psychologist's or Sexton's reading, or a Medium's relayed transmission. That
  was about 40% of own readings in the Nov 19 measurement. Their clash is weighed through
  movement, or not at all. Extending the doubt there would use the movement factor's own
  "this list or guard was broken" posterior. Owner Lantern. **[open]**
- **Higher-Insight NPCs weigh more broken-reading combinations** (Michael, Nov 19, with the
  Steward A3 fix). When a case holds several readings the listener doubts, the role check
  now weighs them symmetrically: all genuine, or exactly one broken
  (`CaseEval._doubted_role_fits`). The exact fix also weighs two or more broken at once,
  at 2^k role checks instead of k. The idea: sharper NPCs take the exact fix, duller ones the
  symmetric approximation. In 2 ten-NPC games (Nov 19), 43% of the role checks holding any
  doubted reading held two or more, up to four. Owner Lantern. **[tentative]**
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

## Closed

Closed items live in [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md).

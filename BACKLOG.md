# Demonologist backlog

The single to-do list. It gathers the deferred and open items from DESIGN.md, the
role_exploration On Deck list, the Project notes and playtests 13473/55774. Items are
sorted by effort. DESIGN.md stays the record of how things work and why.
Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[tentative]** = proposal for later design/tuning review;
**[knob]** = not planned, a balancing tool to
reach for only if needed. Settled, built and parked items move to [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md). Source in parentheses where useful. Exploratory mechanics
(new roles, places, ideas still being shaped) live in role_exploration.md.

Codex's per-entry preparation notes ("Prep B001–B201", Oct 25, against `9cb8782`) and its notes on
entries it skipped now live in [BACKLOG_PREP.md](BACKLOG_PREP.md), grouped by entry title; see also
[the preparation map](docs/BACKLOG_PREPARATION.md). Presentation-only work (flavour, wording, visual
flair) lives in [BACKLOG_POLISH.md](BACKLOG_POLISH.md).

---

## 1. Bugs and quick fixes (hours, low risk)

- **From playtest 54875** (Oct 23; Claude played, the user drove; full trace analysis in
  [docs/playtest_54875_diagnosis.md](docs/playtest_54875_diagnosis.md)). The evil team
  was identified by Day 3 and the town lost anyway: one execution in six days.

  - **The owned lie didn't follow the disclosure.** Constance said "home" twice, then
    claimed Night Watch one question later without "So yes: I was out…". The admission
    fires only after a "you lied" deduction, not after a pressing sighting card. A
    walker who discloses after being caught out by a sighting should own the earlier
    story the same way. Her "What it's shown me, I'll keep to myself" also came after
    she had already told the reading (as the window sighting). [decided]

    > Covered by the batch-3 pressing item above (good walkers). The evil-walker side stays open.

## 2. Small features and tuning (a day or so each)

### Deduction types and templates
- **The premise should matter (with Q3 tuning).** (user + Claude, Oct 25, after case
  22485) Today a case's premise changes only the reply and a small trust reward. The
  belief update re-weighs all the listener's evidence with no premise, so "Isolde is
  evil" with cards pointing at Dorian raises suspicion of Dorian exactly as much as
  "Dorian is evil" would; the player followed the town's reasoning and the preview to the
  right answer. Wanted: the town can notice what the player missed, but not solve the
  case solo or by accident. Proposal:
  1. Listeners update mainly on what was argued: full weight on the premise target;
     effects on other people at reduced strength scaled by Insight (a sharp NPC notices
     "this actually points at Dorian"). Cheap: the per-person effects already exist.
  2. A wrong premise costs a little trust when the listener's belief says the premise is
     weak but the evidence points clearly elsewhere ("you're accusing the wrong person"),
     so the player's later word carries less weight in votes.
  3. The preview shows qualitative strength for the premise (weak / moderate / strong)
     and, when the evidence points elsewhere, a hint ("this evidence may say more about
     someone else") without names or numbers. Naming the other person is left to a sharp
     NPC's reply.

  Measure with the bot A/B. In 22485 the player's vote and accusation added about +0.2
  per voter (legacy Q3 values) and flipped three of six good votes; check this doesn't
  let moderately supported wrong nominations through. [decided: direction; numbers open]
- **Seen with the silenced: circumstantial suspicion.** (user, Oct 25) Being somewhere
  with a person who was later breath-stolen should add a little suspicion, enough to
  reward noticing it, without requiring the player to link every location card. Options:
  (a) a flat vibes-stage amount for everyone who shared a location with the silenced NPC
  that day, scaled by how many others were there too. Here NPCs may know the day's
  comings and goings without seeing them, a deliberate exception to "NPCs only know what
  they can see". (b) A player-presentable "town comings and goings" card that shares the
  player's full knowledge of the day's sightings at once. Either fits the vibes stage in
  "Supporting evidence in a case". It depends on the Breathstealer proximity fix above.
  [decided: add; option open]

- **One evaluation path for generic and structured cases.** In 25923, vigil sighting
  #86 + death #87 (Nisha at Merrin's murder block that night) had no template, while
  the generic support sum capped at 1.0 agreement. `trace_match` is specifically an
  evening trace + evening presence, and faces competing explanations. Add the missing
  night-sighting + murder relationship (the death assertion also needs its location)
  with the broader fit-check work, so recognizing a case cannot make it weaker. [decided]

- **Independent support versus repetition.** The ledger currently takes the strongest
  justification for a conclusion. Preserve duplicate-evidence suppression, but let
  separate nights and independent sources build a cumulative case. Tie this to the
  repeated-trace item below and the belief/action split, rather than raising every
  suspicion increment. (61251) [decided] 54875: repeated presentations of a growing case
  scored lower each time; see the novelty bug in section 1.

- **Template generalization** (now part of "Cases instead of proofs" in section 4: one fit check per evidence type;
  originally: one translation table per role, so pair elimination
  etc. work for any gift that makes the same kind of statement). (DESIGN, deferred to
  roster expansion) [decided]

- **From playtest 54875: case-workshop links that were missing or misread.** [decided]

  - **A reading against an alibi is filed as "Contradicted home alibi"** with the
    reading as the trusted observation, so its only explanation is "the alibi is false".
    A gift reading is a claim and should be the doubtable side, or the card should offer
    both explanations ("Dorian's alibi is false" / "Constance's report is false"). My own
    vigil really is an observation; Constance's Night Watch report isn't.

  - **One person's two accounts of the same night** (Constance told me "I saw Isolde",
    then told the town "I saw Jory" for night 1) should be linkable as a conflict.

  - **"Killed by the demon, so good" should give credence to the victim's alibi** as
    grounds for challenging a reading ("it's likelier Constance is lying than that
    Dorian has a secret night walk"): modest weight, not zero, and never proof. (Dorian
    really was the Sleepwalker here, so the doubt was right by luck.)

  - **Surveyor answers** should let the player pick the evil blocks and a suspect on each
    (it can't express "the Square via Constance, Chapel Hill via Edda"). A block whose
    residents are all demon victims drops out of the count: with the Market clean, Jory's
    "2 blocks" plus Constance and Edda cleared the Docks, which the evaluator did work out
    (Hollis and Lian −0.446) but couldn't say.

  - **A claimed day gift but seen out at night** (Greta claimed Dowser after Isolde saw
    her on the Docks) is a reasonable suspicion pattern.

  > **Decided (user, Oct 26); Claude batch:** a gift reading against an alibi offers both explanations
  > (alibi false / report false; your own vigil stays an observation); one person's two accounts of the
  > same night link as a conflict; "claimed a day gift, seen out at night" becomes a recognised pattern.
  > "Killed by the Demon, so credit the victim's alibi" needs a weight: left for the balance pass.
  > Surveyor answers (blocks and residents) are already built (Workshop overhaul, Oct 25).

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** 'Doubt the report instead' on an alibi-vs-report
  > contradiction (`CanvasModel.doubt_report`); someone's own walking report against their own home alibi
  > links as a contradiction (`CaseGraph.valid_dispute`; the model reads it honestly: a hidden good Night
  > Watch lies about being home too). 'Claimed a day gift, seen out at night' was already weighed by the
  > movement model in live games.

- **From playtest 54875: case-workshop feedback.** [decided]

  > **Session 2026-10-25 (B036): model/warning wording fixed; partial closure proposed.** Shared,
  > unsupported, and explicitly selected existing-rule modes are distinguished. Unsupported-card
  > help no longer advertises ordinary fallback presentation or hard-codes obsolete capability
  > lists. The live support result still decides behavior. Assumption-origin and collateral
  > explanations remain separate work; no evaluator, ownership, or submission rules changed.

  > Focused UI checks: 2/2. Full runner: 73/75; only the two permitted failures.

  - When adding a card lowers agreement, say why ("this also places Isolde on the kill
    block; nothing explains her being there") and what kind of card would help. Adding
    my second vigil dropped the case from 0.68 to 0.57 until Isolde's Lamplighter claim
    sealed it (1.000): correct reasoning, but a player would delete the card.
  - Assumptions are hypotheses, not evidence ("Isolde assumed good" did nothing; her
    claim card did). Say so when an assumption isn't doing any work.
  - A rejected case's supports still push their own way (rejecting my mis-specified case
    raised Isolde +0.379, the person evil was framing). Warn before presenting: "if
    presented, this mostly raises suspicion of Isolde".
  - Collateral from a sighting card lands on everyone it places (my vigil card raised
    Isolde too). Consider letting the player say what a card is offered for ("about
    Constance's alibi").
  - "Answer validity: the selected explanation does not fit" was the real diagnosis but
    sat mid-text; make it the headline and highlight the card.
  - "Assume Edda: evil" appeared on the premise without the player adding it. Show where
    each assumption came from (the board, a derived inference, the private guess).

  > **Decided (user, Oct 26); Claude batch:** all six bullets, presentation only. Deferred: saying what a card is
  > offered for (it changes how evidence counts).

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** clash headline and red-outlined clashing cards,
  > collateral ("mostly raises suspicion of X"), the weakening card named with who it brings in, idle
  > assumptions, and assumption origins (`WorkshopCanvas.feedback`, `LiveCaseWorkshop._explain_change`,
  > `_idle_assumptions`).

### NPC behaviour
- **From playtest 54875: agreement has to reach the vote.** Six or seven good NPCs said
  "That makes sense to me: Constance is evil" at three meetings and voted no; the case
  never passed. At the votes their suspicion of her was 0.14–0.26 against a bar of
  0.4–0.5. [decided; amounts open]

  - **"Accept" is wording, not belief.** Stance comes from agreement (>= 0.6); the belief
    change is agreement × quality × 0.6 at a meeting × novelty, then trust, so agreement
    1.0 became +0.08 to +0.13. A single bare public accusation moved suspicion +0.11.
    An accepted "X is evil" should set a floor (or a vote term) while its support stands.

  - **When they agree and still vote no, they say why** ("I believe you, but not enough
    to hang her"; "Edda first"). Ties to Vote resistance feedback below.

  - **"I'm more suspicious of Edda" is relative** (top suspect more than 0.05 above), so
    it was said by people whose suspicion of Edda was 0.34 and who then wouldn't vote for
    Edda either. Say it only when the preference would actually change a vote.

  - **Urgency.** The vote bar drops only through paranoia (`0.07 × dead × (1 − 0.6 ×
    composure)`), so high-Composure voters barely moved from Day 2 to Day 6 (Lian 0.44 →
    0.36). Add an urgency term from the alive count and days left that Composure doesn't
    cancel, tuned with the existing paranoia/urgency caution against late random hangings.

- **From playtest 54875: Insight and Confidence barely shaped reactions.** Every good
  listener's agreement was 0.92–1.0. [open]

  - The canvas case had no root template, so it took the generic-support route, which
    ignores Insight. Insight only discounts speech and circumstantial supports, and the
    case was built from the player's own sightings: concrete, from source "player",
    which `_cred` credits at 1.0 regardless of trust.
  - Insight plays no part where it should differ: defences (weighted by trust in the
    defender), crowd accusations (trust in the accuser) and pleas like "it's a lie".
  - Confidence doesn't set how far an argument moves them, though DESIGN says it should.
  - Directions: Insight discounts speech-only moves; sharp listeners weigh the rival
    explanations, dull ones take the headline; Confidence sets the step size; the
    player's sightings are the player's word to the listener and scale with trust
    (DESIGN's corroboration rule, 0.5 + trust).
- **From playtest 54875: evil's cover priorities are backward.** Arguing against a case
  on a teammate breaks cover (stakes 1.7–2.3 against caution about 0.6), while a vote
  that isn't close keeps cover (0.7). Words don't hang anyone, so cover is cheap to keep
  there; votes are what matter. Scale argument stakes by how pivotal the listener's
  agreement is, or keep the stance consistent with the vote that follows. (Edda said "not
  persuaded" and voted yes on the demon on Days 2 and 4. The vote itself is fixed on main
  by the 61251/25923 pass, which wasn't on the played branch; the word/vote priority
  question remains for minions and for bussing.) When an evil listener is named in the
  same reading as the accused (Edda, in Dorian's pair with Constance), its rejection
  should use the implicated-listener voice ("it's about me too, and I know I'm good"),
  which blends in with accused good NPCs. (user, Oct 23) [decided]

- **From playtest 54875: evil meetings are over-weighted and always visible.** All
  pairing that matters happens in `_pre_pair`, before the player picks a place, and is
  visible. `pair_weight = (mutual trust − 0.3) × 2 + news_bonus`; evil gets +0.6 per
  member holding unshared intel, which after any night out is nearly always, so an evil
  pair weighs about 1.6 against 0.4 for a typical good pair. 4 of 4 evil meetings were
  pre and visible, Days 1–4, the same two pairs on consecutive days; post-pairing (same
  spot, 0.4 × weight) happened once in 11 conversations. Let evil confer after the
  player commits (unseen, or seen only from that block); cap the evil bonus or give good
  NPCs with news for a trusted friend the same; add a pair cooldown. Keep good NPCs
  meeting often enough to cover. [decided]

- **From playtest 54875: a hidden walker caught out should explain.** Isolde (Lamplighter,
  low Composure) was seen on the kill block on two kill nights, pressed with my sighting,
  and still stonewalled until I guessed "are you the Lamplighter?". Once a walker has been
  caught on a kill block, the reveal cost should collapse: they have nothing left to hide
  and everything to explain. The defence moves do this at the meeting; a private press
  with a sighting card should trigger it too. Ties to Rebuttals and excuses. [decided]

  > Private side covered by the batch-3 pressing item in section 1 ("A press with a sighting…").

- **From playtest 54875: the Gravedigger in a reluctant town.** With no executions the
  Gravedigger has nothing to read; Hollis held a top-value gift and no information all
  game. A Gravedigger who knows this could be the one pushing the town to hang someone
  ("so I can tell you what they were"), which also gives a cautious town a reason to act.
  [open]

- **"I've been known to sleepwalk."** (user + Claude, Oct 26) An excuse for being seen out at
  night, open to both the real Sleepwalker and evil bluffers. Cheap for the shared model: worlds already
  enumerate the modifier and its holder, so the claim is a mask over existing worlds (true if they're the
  Sleepwalker, or evil). Rules: a real Sleepwalker uses it only under pressure (it gives the secret type
  away); an evil bluffer only when its bluff doesn't already explain being out; two claimants prove a
  liar (one secret per case). Needs a shared-model adapter, so Claude builds it. [decided; Claude]
  - **Lovers as an excuse** ("I was with X"): evil pairing two of its own is a two-for-one; pairing
    with a good person only works if real Lovers sometimes leave each other out to dry. Parked. [open]

  > **Decided (user, Oct 26); Claude batch:** build after Codex batch 3 (it overlaps last words and pressing).

  > **Built (Claude, Oct 26):** `Mind.sleepwalk_excuse` (pressed with a sighting, or a nomination defence); shared model: role check plus the claimants' holder bits in `RoleConstraints.coarse_mask`. Lovers (below) stays open.

- **Follow-up after a false alibi is established.** The initial good-NPC response can
  concede "Fine, I was out. Doesn't mean I was doing anything wrong." Later add
  pressure checks and possible forced revelation of the hidden gift/secret, with
  proper handling of genuine home accounts, unremembered outings and evil cover
  behavior. The pressure/revelation extension is deferred. (Oct 23, case 44814.)
  [decided; mechanics open]

- **Reading challenges and next supported gifts.** Track alibi/sighting intent,
  multi-person vigil receipts, Surveyor count generation/skepticism, preview clarity,
  and Clerk/Archivist/Seer integration in the
  reference plan (now summarised in [docs/CASE_WORKSHOP_FINDINGS.md](docs/CASE_WORKSHOP_FINDINGS.md)). Misled and Lying modifiers, Surveyor skepticism, alibi support, clearer feedback and
  the three role adapters are implemented. Further movement, trace, protection and role
  adapters are tracked in the expansion checkpoints (same findings doc). The interpreter is being rebuilt per [docs/CASE_REASONING.md](docs/CASE_REASONING.md);
  dated outcomes, nested relays and conversion histories remain gated. [watch; broader adapters open]

- **Revenant revelation and reversible town uncertainty.** A publicly recognized
  haunting should establish the executed Revenant as evil and add a small global
  suspicion/uncertainty response to "anyone could be possessed." Current curse
  effects add +0.15 only toward living yes-voters; they are not global, and
  `free_turned` does not explicitly retire that curse ledger entry. Decide how
  global anxiety combines with the justified voter-specific suspicion; it does
  not change who can actually be possessed. Destroying the totem should reverse
  the added haunting uncertainty without undoing independent evidence, and the
  possessed person's identity must stay hidden. (Oct 21) [decided; amounts open]

- **Secret awareness and bluffing.** Lovers' existing confessions now carry a usable
  secret type and can explain night movement. The same card/interpretation format can
  represent a reported Marked secret, but no spontaneous Marked confession is added:
  decide whether holders know they're Marked, how one asks about it, and how evil can
  claim it too. Currently only Lovers have an explicit modifier-confession path. Keep
  these as attributed claims, not hard alignment confirmations. (61251/25923) [open]

- **Nisha's reticence.** 25923 used Gossip 0.11, Privacy 0.60, Trust 0.38. The shared
  gossip rule returns zero below Gossip 0.20 unless pressure reaches 0.50; her pressure
  stayed around 0–0.21. This explains repeated refusals without an evil-only penalty.
  Consider a softer minimum-information policy separately from the bug fixes. [watch]
  54875: Hollis (Gossip 0.01) answered "It's not my place to say" about Constance right
  after agreeing with the case against her in public, and Lian (0.18) the same. A stance
  already given in public should be exempt from the gate. [decided for that exemption]

- **Believable public revisions.** Let the player withdraw or revise an earlier case,
  while NPCs may retain reasons they still believe. In 25923 the final Nisha nomination
  cited the player's earlier argument after the player had adopted a different world.
  Private guesses must remain private. [open] Related: a revised case must not score
  below the version it replaces (54875, section 1).

- **Quiet-night evidence.** Sightings outside an actual murder scene currently get
  only 0.12 of normal weight, including failed attacks. Support a player-argued link
  between protection, suspected attack and movement without exposing hidden attacks.
  In 61251 the successful Fenwick ward suppressed the apparent value of the sightings.
  [open] See the "Protection + quiet night + sighting" template gap (54875) for the
  concrete chain.

- **Vote resistance feedback.** Distinguish disbelief from execution priority and
  distrust of the player. In 25923 the -0.4 preference for Lian already on the block
  stopped several good NPCs voting for Nisha despite substantial suspicion. Revisit
  with meeting/vote talk; do not turn every plausible alternative into inaction. [open]
  54875 is the clearest case yet; see "agreement has to reach the vote" above.

- **Evil vote stakes beyond the Demon.** Cover can no longer cause an evil NPC to
  nominate/vote for the Demon. The existing pivot heuristic still considers only
  votes already cast for other nominees. Future tactical bussing (including any
  deliberate Scion succession) needs remaining-voter estimates and a team-benefit
  policy; preserve ordinary minion bussing meanwhile. (25923) [open]

- **Outcome attribution.** Separate identifying evil alignment, identifying an exact
  minion gift, and making a useful execution. 61251 correctly identified Jory as evil
  but guessed Breathstealer; executing the Revenant turned the last good NPC. [open]

- **From playtest 61251** (an evil team the player had identified won anyway). [decided]

  - **A proven lie should hurt an info claimant's credibility hard.** Constance (the
    Breathstealer bluffing Seer) was caught in an off-route lie on day 2, and listeners
    still credited her at about 90% (from 94%). Her fake "yes" readings then hanged Lian
    (+3.1 suspicion across the town) and Edda (+2.6), and a fake "no" cleared the demon.
    A proven whereabouts lie by a public info claimant should cut their readings to
    around 50% credibility. This turns "lie severity" around: the lie itself was minor,
    but it says the claimant's readings can't be trusted.

  - **A Seer's record.** Each "yes" pair that's hanged and shown good (by the
    Gravedigger, the Martyr, or a public clear) should discount that Seer's later
    readings, not just add red-herring talk. In 61251, Lian was shown to be the Warden,
    but only the Gravedigger updated (−0.4), and he was killed that night.

  - **Repeated trace matches add up.** Three kill nights in a row had a trace on the
    Docks with Greta there each time. Each was judged alone ("more likely someone else
    on the Docks"), at about 0.3 agreement. The same suspect matching across several
    nights should compound. This is a natural first test case for the theory and fit
    checks (section 4), and the same shape as the Breathstealer-by-presence pattern.

  - **The player's voice in votes is small at ordinary trust.** At trust 0.3–0.5, "the
    player accuses" added only 0.05–0.14 to votes, while non-template cases got 0.19
    agreement. This is the execution-priority idea (section 4) applied to the player's
    own nominations.

  - **Not the cause:** a failed nomination costs trust only with the nominee (−0.15).
    There's no town-wide penalty, so the early lark nomination of Bart didn't cascade.
    Worth confirming in a conservative playthrough.

- **Backing a strong case builds trust.** Nominating or voting for someone the town
  strongly suspects (and who turns out evil, or is widely believed so) earns a little
  trust from the NPCs who agree. It's what makes throwing a teammate under the bus pay
  for evil, and it rewards good NPCs who stick their necks out. (Oct 19) [decided]

- **More talk in town, especially in bigger towns.** 96773 (10 townsfolk, 4 days): 7
  conversations, 7 shares; three conversations passed nothing on, and one pair swapped
  the same sighting back and forth. Scale conversations with population, let each pass
  on the one or two most newsworthy things the other hasn't heard, never echo back what
  you were just told. Check with bot runs. [decided]

- **Evil backs into a bluff.** Like the scapegoat switch: an evil NPC that hasn't
  claimed yet can change its planned bluff when another gift would serve better, if no
  one has claimed that gift and it would build a frame or deflect suspicion. Example: the
  Poisoner planned to bluff Seer but is seen out at night, and nobody has claimed Night
  Watch, so it claims Night Watch. This opens the door to double claims (the real Night
  Watch may just be quiet), which need their own logic: a classic of the genre, needed
  eventually. Once double claims are handled, fake Mediums (and evil generally) can also
  make bolder lies: fake readings in gifts the dead never claimed. (Oct 19) [decided]

- **Storyteller-driven Medium visits.** Today the Medium visits the most recent dead it
  hasn't visited (demon victims first). Eventually: "I was called to Hollis's home to
  commune with his spirit", chosen by a director. Limit the future director's pool
  to Demon victims if the Oct 21 eligibility change above is implemented.
  (Oct 19; dependency clarified Oct 21) [open]

- **Medium relay: separate later social consequences.** When adding Workshop support,
  reuse supported original-report semantics while retaining the dead source, original
  observation time, Medium receipt time and shared original identity. Account for
  credibility of both the Medium's transmission and the original source; a relay is
  not independent corroboration of that same reading. Defer the richer social response
  (who gains/loses trust or is blamed when a relay is challenged) until after semantic
  support. This does not defer the provenance/credibility safeguards. (Oct 23 evidence
  expansion discussion.) Single-level reading/sighting/home/guard relays now retain
  both sources, original and visit times, and shared original health. Richer social
  consequences remain deferred. [implemented semantics; social policy open]

- **Medium challenge attribution and nested relays.** Add an explicit choice between
  questioning the Medium's transmission and the dead source's original information.
  Until that exists, cause modifiers on relay cards are visibly unavailable; they
  must not silently accuse the wrong speaker. Relays of another Medium's relay and
  relayed opinions still use native fallback. (Oct 23 expansion.) [open]

- **Martyr promise versus later hanging.** The new evaluator handles choice reports,
  explicit evil-registration outcome reports (including Marked), and observed
  substitutions. Combining an earlier choice with a later execution remains on
  explicit fallback until an outcome-time health assumption/receipt can be evaluated
  separately from health at the choice. Do not infer that both times were healthy
  from the earlier promise alone. (Oct 23 expansion.) [decided; adapter open]

- **NPCs push back on nominations their own information contradicts** (a player-led
  nomination of the true Seer passed 7/8). (DESIGN playtests) [open]

- **Lie severity:** a false gift report weighs more than a whereabouts lie, unless the
  lie puts them near the crime. NPCs who accept a lie but won't hang should say so.
  (DESIGN) [open]

- **Evil reads as evil:** evil casting aspersions with no information stands out; give
  good NPCs reasons (grudges, secrets) or make evil hold back. (playtest 30294) Largely
  addressed by the shadow self (evil's replies now differ from the good crowd's about
  twice as often as good's own disagreements, down from about five times); revisit
  after playtests. [watch]

### Exploration
- **Role hints from workplaces and haunts.** Occasionally reward searching an NPC's
  workplace or known haunt with an attributed hint about their claimed/possible
  gift. Coordinate with the evidence/role-hint system; searches should not become
  guaranteed hidden-role verification. (Oct 21) [open; frequency/content open]

- **Occasional free arrival search.** A balancing option to sometimes grant a free
  ordinary search when moving to a new location. Exclude evidence searches; define
  the eligible search types, chance and per-location/phase limits so revisiting
  cannot farm free actions. (Oct 21) [knob]

### Numbers
- **Balance pass watchlist: night sightings are too decisive.** (user, Oct 25, after
  case 22485) The vigil was already on the watchlist as too strong, and "claimed a day
  role, seen out at night" reads as open-and-shut. In the shared movement model a good
  person on an ordinary night is out only 5% of the time (claimed non-walking gift: 90%
  ordinary, 10% secret errand), against the demon heading for the victim's house on
  kill nights, so one sighting is a large likelihood ratio. Don't fix it by biasing the
  demon toward night-walking roles: players would learn to suspect night-walkers instead.
  Levers to try, measured with the bot A/B: a higher ordinary out-rate, more good NPCs
  with secret errands, softer demon routes (detours; see MECHANICS_SUPPORT item 6), and
  vigil yield. [decided: tune in the balance pass]

- **Evil sometimes tells the truth (start by faking it).** (user + Claude, Oct 25) Today
  a reading from a source who is evil in a world is uninformative there: same weight
  whether its content holds or not. So a reading that checks out is near-proof its source
  is good. Make it partial: an evil source's content is true with probability t, noise
  otherwise. Correct readings then exonerate less (more uncertainty, as in BotC, where
  evil may tell the truth to build trust); false readings still implicate strongly. Same
  cost (one per-world factor; no new hidden state). Risk: if t is higher than what the
  simulated evil actually does, the town partially believes frames, a hidden shift toward
  evil. So set t from the simulation: measure how often fake readings happen to be true
  (the grimoire knows) in a bot run, and re-measure whenever evil's reading strategy
  changes (for example a later "tell the truth strategically" behaviour). Belongs with
  the balance pass; the bluff weight (0.35) is the analogous number for role claims.
  [decided: add; t measured, not chosen]

- **Unlimited Vigil strength.** (DESIGN open question) [watch] 54875: a kept vigil on the
  first kill block caught both walkers there on night 1, then again on night 2; that's a
  two-person demon shortlist on night 1, near a free Seer reading. Options discussed
  (Oct 23), none chosen:

  - a vigil makes you sleep in and lose the next morning's action (keeps sightings sharp,
    adds a real cost; the option Claude liked best);
  - vigils limited like the ward;
  - a vigil shows only a count of people on the block, like a local Lamplighter (the user
    noted this leaves the player reliant on chance sightings and the Night Watch);
  - keep watch at one location: name anyone at that spot, count the rest of the block
    (pairs well with a demon that can lure a victim elsewhere, section 4).
- **The Lamplighter contaminates vigils and traces.** It walks every block, so it shows
  up on every vigil of a kill block and is the usual second walker that makes a scene
  trace misleading (54875: Jory's trace pointed at the Square because Isolde passed; the
  demon had spent the evening on the Docks). Fine when the Lamplighter can prove itself;
  hard on a hidden one. [watch]

- **Situational credence modifiers** still to settle: early disclosure, quiet night
  as a credence boost, admission against interest, consistency over time,
  role-specific confirmations. (DESIGN) [open]

- **Offer trust** (+0.03 offer, +0.06 kept, -0.15 broken): first guesses, tune from
  play. [watch]

### Tentative social tuning (Oct 20 discussion)
These are candidates for the player's unified retuning proposal, not approved
implementation changes. See TUNING.md for the audited current values.

- **Privacy without compounding trust penalties.** Remove Privacy from initial player
  trust and benign trust changes. High Privacy should scale consequences only for
  actions a private person would resent, such as intrusive pressure or revealing
  secrets; it should not be a core modifier of rapport gains/losses. Keep direct
  disclosure gates. Distinguish ordinary questions on different topics from
  repeating a refused or intrusive question when applying fatigue.
  54875 evidence: on day 1 Dorian (Privacy 0.69) and Odette (0.78) scored openness 0.03
  and 0.06 against 0.15 for even a hint, because Privacy counts both in openness and in
  starting trust (0.3 + 0.25 × (1 − privacy)). Three of three people stonewalled on day
  1; the user noted the first day swings a lot on how many private characters are dealt.
  Consider removing the double count or dealing at least one openish person per phase.
  (Refined Oct 21) [tentative]

- **Evidence can build NPC-to-NPC trust.** Consider a relationship gain when credible
  evidence reduces suspicion, especially a Clerk reading matching the listener's own
  actual role. Oct 21 examples: that listener currently loses 0.30 suspicion toward
  the Clerk; consider adding about +0.20 relationship trust (provisional), and a
  Seer reporting "no" on a good NPC can similarly build the subject's trust in the
  Seer. Base acceptance on the subject/listener's knowledge, not hidden alignment.
  Scale by evidential strength and deduplicate the underlying fact.
  Distinguish apparent innocence/sincerity from confidence in someone's judgment;
  preserve useful voting blocs without rewarding repeated retellings. [tentative]

- **Diminishing trust changes near extremes.** Consider smaller gains near high trust
  and smaller losses near low trust, retaining a minimum effect and meaningful
  consequences for serious betrayal. Oct 21 knob: keep a normal band of 0.30-0.70;
  soften further losses below 0.30 and further gains above 0.70, while allowing
  recovery toward the middle at normal strength. Exact curve remains open. Review
  permanent grief/confidence caps separately; scaling alone cannot repair them.
  [knob; Oct 21 band specified]

- **Fewer trust penalties for presenting evidence.** A balancing option to reserve
  most trust loss for nominations, votes and other direct offenses, rather than
  merely offering evidence. Preserve meaningful consequences for intrusive pressure
  and betraying confidences. Audit presentation/press routing and fatigue so a
  harmless presentation is not accidentally treated as an accusation or demand.
  Coordinate with the Privacy pass and existing supportive presentations.
  (Oct 21) [knob]

- **Opinion strength and shared origins.** Keep private heard-opinion strength
  (raw 0.12) separate from meeting consensus. Oct 21 proposal: reduce the first
  three equal-weight meeting voices from 0.12 / 0.06 / 0.03 to 0.08 / 0.04 / 0.02
  before relationship/hint/day modifiers, continuing the existing halving sequence.
  Audited current constants are BASE=0.12, FADE=0.6 per day, CAP=0.3; the latter
  two are not the second/third accusation strengths, and the requested reduction
  has not been implemented. Keep fade/cap unchanged unless separately retuned.
  Several NPCs repeating one original story should not count as independent
  evidence; inspect provenance/accumulation alongside the base change.
  [tentative; proposed values specified Oct 21]

- **Martyr urgency.** Gradually lower the commitment threshold as days pass, with a
  floor, while retaining candidate preferences and the possibility of refusing when
  everyone looks deeply suspicious. Avoid a gift wasted solely because no ideal
  confidant emerges. Oct 21 specifies that the decline starts on Day 3; decrement
  and floor remain open. Audited `World._martyr_choice` still requires 0.62 on
  every day, so this has not been implemented. [tentative; Day-3 start specified]

- **Demon victims' earlier information.** Strengthen belief that a Demon victim was
  reporting sincerely without automatically trusting every reading's accuracy.
  Current code clears the victim and doubles role-claim weight on recomputation,
  but does not directly restore source honesty or reweight old readings because of
  the death. Keep sincerity, claimed role, and night-specific misdirection distinct;
  base changes on listener knowledge, not hidden actual roles or poison state.
  [tentative]

### Social tuning and evidence follow-ups (Oct 20)
These record the narrative-tuning review. They are backlog work, not changes to the
implemented model. Explicit directions are marked decided; proposed mechanics and
exact values remain open. The code-derived examples and clarifications are in
[TUNING_NARRATIVE.md](TUNING_NARRATIVE.md#16-how-the-ledger-works-a-meeting-case-against-greta).

- **Confidence should protect convictions, not create general resistance.** A
  confident NPC without an established view should consider fresh evidence at normal
  strength. Scale resistance with the strength of the belief being challenged; low
  suspicion alone does not establish belief in innocence. Include evidence-based
  convictions, relationships and firsthand knowledge without giving NPCs hidden truth.
  Audit direct adjustment, ledger recomputation, trust-based reconsideration,
  own-reading/conflict agreement, and role-specific effects/flags (including Medium
  relays and own versus heard readings), so a global fix does not leave inconsistent
  role paths. Reinforcing evidence should not receive a blanket Confidence penalty.
  Direction [decided]; conviction representation and curve [open].

- **Ward promises should outrank vigil promises.** Increase the relative value of a
  fulfilled ward promise; add substantial plausible-success credit for a kept ward
  followed by a deathless night. Warden/Veteran intervention remains an alternative,
  not a reason to deny player credit. Base credit on the listener's observable facts
  and beliefs, not the hidden attack target or actual blocker; avoid duplicate credit
  for promise, protection, and outcome. Exact amounts and stacking [open; direction decided].

- **Reduce secret-keeping rewards and soften secret breaches.** Review repeated
  nightly gains, first-use and repeated breach losses, and permanent caps together.
  Keep a meaningful betrayal consequence while allowing proportionate recovery;
  coordinate with apologies and confidentiality promises. [decided; values open]

- **Track incrimination versus a suspected misread explanation?** Evaluate a separate
  representation for "a Seer yes implicates this person, but I favor red herring or
  Marked" rather than collapsing everything into net suspicion. It may be competing
  hypotheses rather than another additive suspicion score. Explain apparent
  incrimination, likely cause, and remaining uncertainty; reweight consistently when
  either hypothesis loses support and avoid double-counting. Use accepted evidence,
  never the actual hidden modifier. [open]

- **Dowser clearing strength.** Evaluate only firing on a positive ping instead of
  producing zero-count group clears. Specify whether "evil" means registered evil
  (including Marked), how poison/Delusional results behave, and when a failed/absent
  ping is observable. Absence must not become the same zero-count clear through a
  known guaranteed trigger. Compare weaker zero clears/less frequent checks before
  choosing the design. [tentative]

- **Make night-sighting rebuttals explicit.** Let NPCs argue "I was seen out, but no
  one died that night" or "the death happened on another block." Night-sighting
  strength already falls to 12% away from an actual murder block/night. Add argument
  support and attributed defence, rather than merely hidden scaling. Avoid clearing
  all movement, double-crediting the same contextual discount, or ignoring thwarted
  attacks and other reasons a walker might be evil. [decided]

- **Accumulate discrete independent instances.** Multiple caught lies, trace matches,
  and independent nights should strengthen a case with diminishing returns. Preserve
  event/night/card identities and source provenance; distinguish independent facts
  from several retellings of one origin. Audit conclusion IDs, strongest-justification
  selection, and justification keys based on source/night/kind. In particular, the
  reproduced generic two-card case can beat its better-supported template because
  they use different agreement routes; align those semantics with the section-4
  cases/evidence-fit work. [decided; aggregation design open]

- **More rebuttals after a caught lie.** Beyond admission or stonewalling, allow
  explaining concealed walking duties, personal secrets, protecting a confidence,
  or other supported motives. Conceding the statement was false need not concede
  evil or make future readings worthless. Give evil plausible access to the same
  excuses, with later corroboration/challenges; do not erase the caught lie itself.
  Extends section 3's rebuttal work. [decided; options open]

- **Compare misled and reading-lie strength.** Review 0.80 reading doubt for misled
  versus 0.50 doubt plus 0.30 suspicion for exposing a reading lie. Compare at equal
  effective weight, with honesty feedback, night scope and self-knowledge included;
  those coefficients affect different quantities and are not probabilities. No new
  coefficient selected. [open]

- **Signal honest observation forgetting.** When Insight/recency memory limits remove
  people from a report, acknowledge incomplete recall ("There were others, but I
  can't place them"). Distinguish memory loss from Gossip refusal, deliberate friend
  omission, bluff constraints, and other concealment. The player-facing explanation
  should not expose the omitted names or make hiding mechanically identifiable.
  [decided; exact presentation open]

### UI
- **Case board visuals.** (user, Oct 26) The board cards are crowded: on a small card the text runs
  into the "heard" line, the type and source icons stack in one corner, and the Codex "context" tag
  sits on the edge. Rework card sizing, text fitting and where badges go (a badge strip or corner
  slots) before adding more markers. Badges waiting on it: "shared with you privately" and "in
  confidence" (hook built: `CardModel.disclosure_scope`/`shared_privately`/`badges`, Oct 26; nothing
  draws them yet) and the context tag. Coordinate with "Card zoom and text extension" in
  BACKLOG_POLISH.md. [decided: needed; design open]

- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main
  view; people who aren't talking or working showing on the map; a wrong role guess
  blocking process of elimination.

### Performance

- **Presenting and search-into-meeting are still over budget.** (Claude, Oct 25) Budget
  (user's machine): meeting entry and presenting about 2 s or less, nominations under
  1 s. After the Oct 25 role-check fixes (container, about 0.7x the user's machine), the
  54875 replay shows meeting entry 1.4 s and nomination 1.3 s, but search into the
  meeting 3.5 s and presenting about 4.3 s. Presenting is mostly the scoped reply; the
  search cost grew with shared NPC sightings (more cards per listener, larger compile).
  Late games: seed 42's Day-3 meeting entry is 6.5 s, down from 95 s. Profile with
  `tools/replay_54875.gd` and a late-game probe (seed 42, Days 3 to 4) before adding
  evidence types; the opening replay alone doesn't reach the late game. [open]

  > **Decided (user, Oct 26); Claude batch:** results stay identical throughout. (1) Stream the meeting: show
  > testimony speaker by speaker and compute the next speaker's refresh while the current lines are up
  > (vote rounds the same way); no threads, no change to event order. (2) Background thread for the
  > dawn refreshes (while the morning report and headlines play) and the evening-chat refreshes (while
  > the meeting opens): the solver uses no RNG and caches by exact inputs, so a background result is
  > either exactly what the main thread would compute or discarded; needs thread-safe solver caches.
  > (3) Cheaper refreshes if still needed. Measured Oct 26 (seed 42, day 3): meeting entry 6.5 s = 2.0 s
  > evening-chat refreshes + 4.4 s testimony (10 refreshes); vote rounds 1.4-2.6 s; dawn 2.8 s.

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** the meeting streams speaker by speaker in the UI
  > (`Mind.testimony_step`, `Game.testimony_step`; identical results, `tools/test_meeting_stream.gd`), and
  > refreshes are held from the meeting's opening to each speaker's turn (seed 42 day 3: 17 refreshes ->
  > 11, 5.9 s -> 4.5 s; five full games identical). Holding the night's refreshes the same way changed one
  > game in five for one refresh saved, so it was dropped. Background thread: not done. The solver keeps
  > about 45 static caches and id counters, so running it off the main thread needs a thread-safety pass
  > first; and the dawn work can't overlap reading the morning without deferring refreshes past the
  > point where the morning reads beliefs (not identical). Still open: vote rounds (1.2-2.6 s each),
  > presenting (about 4.9 s on the 54875 replay), dawn (about 2.7 s).

## 3. Medium features (several days; touch a few systems)

- **Evidence-reading bot.** The bot ignores traces and dropped materials entirely (and
  peeks at `w.dropped` when deciding to search), so bot win rates say nothing about
  physical evidence. Teach it to read traces and drops, and stop the peek, to measure
  what evidence is worth. [decided]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** this pass, remove only the hidden `w.dropped` peek in
  > `tools/autoplay.gd::_decide`: the bot searches crime scenes as now and otherwise only on public
  > grounds. Teaching it to read traces and drops stays open. Note in the commit that bot baselines
  > may shift.

  > **Batch 2 verification:** removed only the hidden drop-presence check in `_decide`; public
  > crime-scene searches and the ordinary search/wait roll remain. Bot baselines may shift,
  > including RNG consumption where a hidden drop previously short-circuited the roll.
  > Teaching trace/drop interpretation remains open; no balance claim is made.

- **Expanded dialogue and trust management** (Oct 20; design candidates, pending
  the unified retuning proposal). [tentative]

  - **General requests can spread through town chats:** "Someone should check Nisha"
    or "Someone should watch the Wharf," without outing a gift-holder. Distinguish
    hearing a request from volunteering and completing it; do not assume coverage.

  - **Responsibility and useful follow-through can build trust:** a meaningful
    accepted task may earn a small, non-repeatable rapport gain; later credit depends
    on what the NPC believes was accomplished. A Seer "no" or empty watch can be
    useful; do not reward incriminating results by default. Prevent request spam,
    duplicate credit, and hidden-truth outcome checks. Follow-up dialogue can report
    success, disappointment, or a convincing evil lie.

  - **Responsibility can cut both ways:** an NPC may feel guilt when their information
    helps execute someone, especially when later evidence makes that execution look
    mistaken. Consider this as a core NPC response as well as a request follow-up.
    Base it on perceived responsibility and known outcomes; do not treat an
    execution as vindication merely because the information was acted on.
    (Oct 21) [tentative]

  - **Withdraw or revise a case:** explicitly retract public endorsement or explain
    changed reasoning without deleting the underlying evidence. NPCs may retain
    their own view and explain why. Private role guesses remain private.

    > **Closure check (Claude, Oct 25): kept open.** The withdrawal tested above is the
    > developer tool (Debug menu: "not an in-character retraction"). Players can revise a case by
    > re-filing it, but have no way to retract an endorsement or explain a change of mind.

  - **Ask what would change their mind:** expose friendship, conflicting information,
    player distrust, or preference for another execution as actionable resistance.

  - **Explain an execution's purpose:** propose an information-seeking execution
    (e.g. for a Gravedigger read) without needing to assert the target is the Demon.

- **NPCs voice doubt about their own readings.** Detect apparently inconsistent
  results, such as repeated Seer checks of the same pair changing yes/no, and let
  the NPC acknowledge that something is unusual. Higher Insight can also help
  notice a mismatch with their leading explanation/world. Use information they
  actually have, allow legitimate changes such as succession, and distinguish
  suspicion of misdirection from admitting a lie. Coordinate with source
  credibility and the section-4 case/world model; existing self-reading doubt
  mechanics do not yet provide this general proactive dialogue.
  (Oct 21) [decided; triggers/presentation open]

- **Rebuttals and excuses.** Someone accused explains with their gift ("I was out
  because I'm the Lamplighter"; own-lie admissions are built), which buys some grace with listeners; evil without a
  fitting bluff can claim a fake secret. Biggest open hole: hidden night walkers frame
  themselves (Isolde 55774, Constance 96773; Lamplighter/Veteran/Sleepwalker/Warden hang rates). (DESIGN)
  Now part of the meeting-flow plan (docs/meeting_flow_plan.md, step 2). [decided]

- **Medium relay credibility at both sources.** Audit/fix relayed readings so full
  credence requires trusting both the Medium and the dead source. Current
  `Mind.apply_info` stores the Medium as the ledger reliability source; the Medium
  branch expands the dead reader's effects at 60% but does not retain a separate
  live reliability dependency on that reader. Cover relayed readings, sightings and
  opinions, both sources' sincerity, and each relevant reading's own night-specific
  doubt without double-discounting. Keep relationship hearing weight distinct from
  source honesty; never consult hidden actual poison/alignment for acceptance.
  (Oct 21 code audit) [decided; exact combination open]

- **Trust dynamics around sources (later).** A relayer may name their source outright,
  at the cost of that person's trust; and evil may try to trace an unnamed source ("the
  Seer told me") back to a person, to kill or frame them. (Oct 19) [open]

- **Meeting and vote talk** (returns with the rebuttal work). Votes are silent for now;
  PR #3's vote explanations were removed. When vote talk comes back: evil voters must
  draw from the same spread of reasons as good ones (in PR #3 they all said "the case is
  strong enough"), and only lines that tell you something should be spoken (a reason
  that differs from the crowd, a vote against a stated stance, a swing vote). [decided]

- **Fading into the crowd.** NPCs weigh how much talking is already going on before
  speaking or disclosing. When the town is already moving in a direction, a private
  character may just bide their time and listen. (Oct 19) [decided]

- **Outing yourself to defend someone.** The flip side of the accusation tiers: when an
  NPC holds information that could clear someone on the block (a Seer "no", a Night
  Watch who saw them stay in), when are they willing to come out to defend them? The
  same weighing as accusing (how strong the clearing is, what the reveal costs, how
  close the vote is). (Oct 19) [decided]

- **Talking to a group:** 3 questions per phase, split among anyone at the spot.
  [open; discussed 2026-10-18]

- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems.** Today the Revenant is often invisible (55774). [decided]

- **NPCs find evidence and personal items** (dropped items, traces). [decided]

- **Ways to discover and confront secrets:** sightings that don't fit, confidants,
  personal items, a "you have a secret" card used as leverage. (DESIGN) [open]

- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. (DESIGN) [open]

- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (DESIGN, open since playtest 1) [open]

- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers
  meeting too as noise. (DESIGN) [open]

- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  demon; the demon goes along with town conclusions to build trust. (DESIGN) [open]

- **Bot builds Case Workshop cases.** (user + Claude, Oct 25; deferred) The bot ranks
  suspects with a hand-built heuristic (`autoplay.gd::_scores`, including the legacy
  night-sighting scale) and builds cases only from two-card template matches
  (`_find_or_file_deduction`). Proposal: rank suspects by a neutral test juror's
  posterior over the player's board; build a workshop case against the top suspect
  greedily (add a supported card when it raises the test juror's strength, try the
  card answers, cap about 8 cards, once a day); use the juror for nominations, votes
  and defences. Expect a much stronger bot (near-ideal reader) and slower bot games
  (about 10-30 test-juror evaluations a day); re-baseline old vs new bot on the same
  seeds. Then the `link` / `conclude` text commands can be retired with the templates.
  [deferred]

- **The Revenant can hide a new totem each day.** Burning a totem doesn't make the
  Revenant safe to hang for good: in 54875 the totem burned on Day 4, a new one was
  hidden Day 5, Edda was hanged with it and Isolde turned. When a totem burns, signpost
  that another may follow ("it will seek a new hiding place"), and think about whether
  the totem search can keep pace. [decided: signpost; balance open]

  > **Decided (user, Oct 26); Codex batch 3:** signpost only: the totem-burned receipt adds that the
  > Revenant's spirit "will seek a new hiding place". Balance stays open. Also gets a headline notice.

  > **Implemented (Codex batch 3):** The burned-totem log, receipt and headline warn that the spirit will seek a new hiding place. Search/burn state and RNG are unchanged in focused checks; replacement balance stays open.

- **Reactive meetings: speak up when the last statement concerns you.** (user, Oct 24)
  After each meeting statement, every listener runs cheap yes/no checks: does it name
  me, or name a person or role that's part of my private information (my own gift,
  someone I have a reading about, a claim of my role)? If so, add a situational bonus to
  the usual disclosure decision, so they may respond on the spot: confirm, contradict,
  claim, or defend. Uses the existing disclosure checks (privacy, trust, pressure),
  not a new evaluation, so it's cheap and makes the meeting feel like a conversation.
  Pairs with pacing refreshes behind dialogue. [decided: add; bonus size open]

- **Seen at night away from the murder.** (user, Oct 24) Being seen on a block the
  killer couldn't have used is evidence against being the Demon that night. The two
  models disagree today. Legacy `Mind.night_sighting_scale` only ever *raises* suspicion
  (×0.12 of a near-death sighting, less for claimed walkers), so it's never
  exculpatory. The shared movement model gives the Demon only the route to the victim's
  home on a kill night, so an off-route sighting makes the Demon nearly impossible for
  that person: probably too strong (the Demon could walk elsewhere first), and the
  player can't argue it on the case board or hear NPCs say it. Wanted: a softer Demon
  profile (some chance of a detour), and the "seen elsewhere, so not the killer"
  relationship visible in previews and replies. A Minion stays possible. [decided:
  add; strength open]

- **Corroborated walking-gift claims.** (user, Oct 24) In a playtest, Odette claimed
  Lamplighter and was seen on several different blocks across the town, which lent her
  claim credence. In the shared movement model a claimed Lamplighter's path covers every
  block, so several scattered sightings fit her claim better than a Minion's single
  errand: the support exists numerically but is invisible. Make it visible ("seen all
  over town, as a Lamplighter would be") in previews and replies, and decide whether it
  should also count as support for the claim in the vibes stage (see "Supporting evidence
  in a case" below). [decided: surface it; weight open]

- **Votes and nominations ignore rank (Q3 pass).** (user question, Oct 24) Code check:
  a good vote is an absolute bar (`Mind._vote_impl`: suspicion of the nominee + crowd
  pressure + small terms ≥ about 0.43). The nomination walks `ranked_suspects` in order
  and nominates the first not-yet-nominated person over its own absolute threshold, so a
  second or third choice can be nominated if the first is taken. The only relative term
  is `prefers_block` (−0.4 when the person already on the block is suspected at least as
  much). Nothing lets an NPC say "not my first choice, but among my top suspects, so I'll
  back the town's pick": an NPC with diffuse suspicion (0.3 on three people) can't vote for
  any of them. Candidate: a rank-aware term for a nominee in the voter's top 3 at a
  reasonable share of their top suspicion, through the shared execution-priority input
  (wired at zero weight). Measure first: `autoplay.gd`'s AGREEMENT table (top-3 overlap,
  peers' suspicion of each NPC's top suspect), after the impossible-refresh fix, since
  that bug currently zeroes many voters. [decided: measure; design open]

- **Supporting evidence in a case: logical where possible, vibes where not.** After the
  legacy migration. Example: an accusation that cites the accused's voting history ("she
  voted to hang people you think are good"). (user, Oct 24) [decided: the split;
  details open]

  - **Observable actions go in the evaluator as soft evidence:** votes, nominations,
    who defended whom, tie-breaks. "Voted to execute someone who is good in this world"
    needs only each world's evil mask, so it adds no hidden dimension (cheap; see
    Architecture rules in docs/LEGACY_MIGRATION.md). Each action is a likelihood factor:
    the rate at which evil and good players take it against good targets, measured
    from bot runs, not hand-set. The interaction the user wants ("if the case raises my
    suspicion, her votes against people I trust count more") then follows from the
    joint evaluation: no ordering, no feedback loop, no double counting. This is a
    new decision: Q1 put accusations (speech) outside evidence; votes are actions.

  - **Listener impressions go in a second stage gated on the first:** demeanour,
    nervousness under pressure, "oddly quiet", trust in the presenter. Stage 1 (the
    logical case) runs and is applied. Stage 2 then scores these cards from a snapshot
    of the listener's updated beliefs, scaled by how far stage 1 moved them, so vibes
    can't carry a case alone. Guardrails:

    - read stage 1 once and never iterate;
    - judge the cards by beliefs about *other* people (the targets), never the accused's
      own raised suspicion;
    - keep stage 2 a separate, retractable contribution (like the ownership layer
      today), so the next belief refresh doesn't treat it as a prior and count it
      twice.

    Accept that stage 2 depends on order: the same cards split across two cases can
    total differently from one case.
  - **Existing hook:** `_consequences_eval` already has a circumstantial route
    (`_pattern`), but it takes the larger of the logical and circumstantial signals.
    The gated stage-2 term should add to the logical one instead.

  - Open: which actions qualify, the measured rates, stage-2 weights (ties into the
    deferred Q6 Insight/Confidence pass), and the NPC lines ("your case convinced me,
    and now her votes look worse").

## 4. Major structural work (a week or more; design first)

- **Cases instead of proofs: the player argues a theory** (Oct 19–20 discussion; next up
  after the usage reset, ahead of meeting-flow step 5). [decided, design first]

  - **The problem:** deductions are "these cards prove this", gated by templates. Most
    Clocktower reasoning is cumulative and probabilistic, so a strong case like "Seer
    pair + near a murder + caught in a lie" gets filed as a weak "your inference". The
    space of evidence interactions is too large for templates, and some that fit are
    unintuitive to build.

  - **The direction:** the player proposes a theory, which can be partial:

    - the demon candidate and the suspected evil;
    - optional assumptions ("Edda is the red herring", "Constance's reading was
      poisoned").

    The game scores each card on how well it fits that theory: supports, contradicts,
    or doesn't bear. This answers the question the evidence poses (the Surveyor's "3":
    mark who the evil are, and see if the count fits).
  - **One fit check per evidence type** instead of templates for pairs:

    - Surveyor: N blocks with an evil resident;
    - Seer yes: the demon, the red herring or a Marked person is in the pair;
    - Dowser and Hearthwitch: N evil among a group;
    - Archivist: one of two is that minion;
    - Gravedigger: the hanged person was that role;
    - sightings near deaths: soft fits.

    Partial theories need "fits / could fit / contradicts" (is the count still
    reachable?). Demon victims count as good by default, so a Surveyor check includes
    the dead without extra steps.
  - **Against flooding the zone:** score fit weighted by how surprising it is.
    Irrelevant cards add nothing, loose fits little (a Surveyor count fits many
    theories), tight fits a lot (a Seer yes on the pair), contradictions cost.
    Same-source cards count once. Every assumption weakens the case by the listener's
    doubt in it.

  - **NPCs judge the player's theory; they don't search for theories.** Each listener
    checks it against what they know, at their own credibility weights, and answers two
    questions: does it make it more likely (belief), and is it enough to act on
    (execution priority: urgency, trust in the player, counterevidence)? An accepted
    assumption can become a working belief that later arguments build on, and it's undone
    if it collapses. That keeps the player as the detective and NPCs persuadable and
    plausibly wrong (accidental misdirection and deliberate manipulation, such as
    getting someone hanged for a Gravedigger read, both still work).

  - **Keep:** templates, now as bonuses for rigorous links rather than gates; the evidence
    ledger; cards; provenance; the shadow self. The per-card weighing that private cases
    already use is the starting point for scoring.

  - **Bonuses:** a supports/contradicts view of the board is a strong player tool on its
    own. The private-theory panel (demon and minion guesses) is the natural entry point.
    The bot can use the same checks.

  - **Where it plugs in:** the player's turn in the meeting flow becomes "make a case".

  - **Considered and not chosen:** Astra's full competing-hypotheses rework (every NPC
    tracking demon, minion, red herring and Marked beliefs for everyone). It's sound,
    but it makes NPCs better reasoners, which is the wrong direction, and it's a large
    open-ended core rewrite. Revisit only if playtests keep pointing at "one suspicion
    score" problems, and then as a log-only prototype first.

  - **Related cheap idea, can come first:** an execution-priority term in nominations and
    votes. A credible lead (a Seer yes, a trusted player's case) makes a target
    actionable without inflating belief, scaled by urgency.

- **Pattern-based cases.** Alongside existing deductions, build a case from many
  cards, without the three-card limit: repeated encounters, conflicting stories, or
  other patterns. Offer small observation cards automatically ("Bart was near a
  silencing"), then let the player name a suspect and a role or explanation. Show
  support, counterevidence, gaps, and other people who fit. Unknown whereabouts are
  not an alibi; retellings and observation cards don't count the same evidence again.
  NPCs weigh what was actually presented plus what they know, considering sources
  and alternatives, and explain their response. Reassess when evidence becomes
  doubtful. Use plain-language strength, not exact odds. Prototype one pattern first,
  initially reporting assessments without changing votes. Breathstealer contact is
  one example, not the scope; use actual possible action times (currently any daytime
  phase, with silence starting at the meeting). [decided: prototype; broader design
  open; discussed 2026-10-19]

- **Night movement and trace model.** One package of related items:

  - the deferred night-proximity rule for sightings (route from home to the death
    block);
  - the proposed route limit (home → at most one detour → victim);
  - traces based on where the killer *started* rather than their evening block (this
    fixes the evening-shift demon problem);
  With every block joined, a walker is seen only at home (leaving) or at their
  destination, so "passing vs stopping" mostly collapses into "seen on their own block
  (they went out)" vs "seen elsewhere (where they went)"; homes are what tells the two
  apart.
  When this is settled, check whether the home cards and haunt cards still earn their
  place (with every block joined, a route is just home → destination and homes may say
  little a template needs); remove them if not. The
  evidence-chain item, and the watchtower idea in role_exploration.md, depend on this
  package. (DESIGN) [open]
- **Locations as evidence, from both sides.**

  - A Dowser's "on the Market I sensed 1 evil among A, B, C" places the Dowser and the
    group on that block on the timeline ("ability" marks), but it isn't a location card:
    it doesn't take part in corroboration or the two-places contradiction. So the player
    can't use it to show a (fake) Medium or Dowser wasn't where they said.
  - Your own visit excludes people. Being at a spot shows everyone at that spot (and the
    other spot on the block), so anyone not seen wasn't there that phase. Hearsay can't
    do that. Caveat: people at home on that block aren't shown. A "not there" fact from
    the player's own presence would let templates rule people out.

  Low impact while most suspicious activity happens at night. (Oct 19) [open]
- **Passing through vs. stopping** (potential movement overhaul direction). Sightings say
  whether someone was passing through a block or out on it (their destination). Two
  "out on" sightings on different blocks are a real contradiction; "passing through"
  fits a route. Open: who can tell the difference (street observers and vigils, not
  window glimpses), and the wording ("heading toward the Docks" vs "out on the
  Docks"). Destination sightings on a kill night overlap with the night-proximity rule,
  and it makes vigils stronger. [open]

- **Breathstealer confirms the good.** It only silences the good, so a silenced person
  is proven good, and the role's visible effect becomes a gift to the town. Options:
  (a) the Breathstealer may silence a teammate under suspicion, as cover (a strong evil
  play; silence becomes "probably good"); (b) silence goes quiet: not announced; the
  victim volunteers nothing and stonewalls direct questions, with a small tell you can
  see in private ("…opens her mouth, then shakes her head"); evil can feign it; (c) both.
  [open; see 96773 discussion]

- **Breathstealer ambiguity, two more routes** (for the Breathstealer decision above):

  - a good secret that inflicts the same silence (a vow, a sore throat), so a silence
    isn't proof of the Breathstealer or of the victim's good;
  - make the Breathstealer's silence optional (it may skip days), which also explains
    why the secret's silences come on some days and not others, for maximum
    dastardliness. (Oct 19) [open]
- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration).
  Relationship mods for the Lovers live here too. [open]

- **Roster expansion:** On Deck gifts (Tracker, Clairvoyant, Beckon, Tallyman…); minions
  (Framer/Forger with evidence planting, Blackmailer, Hexer, Informant); Debtor secret.
  Each needs its hint package and template coverage. [open]

- **A demon that kills during the day** (user concept, Oct 23). If added, the protection
  evidence (the "Protection + quiet night + sighting" template gap) must be re-weighed:
  a quiet night no longer means the night attack was stopped, and a night sighting near
  a guarded door says less. Night evidence generally loses some weight while this demon
  may be in play. [open]

- **The demon lures a victim elsewhere** (user idea, Oct 23): once per case, or under a
  condition, the demon kills somewhere other than the victim's cottage. "Found dead at
  the well" is itself a clue (who would go there at night, and who did they trust?),
  and it gives location-based night tools, such as a vigil at one spot, something to
  target. The current demon has no ability beyond the kill. [open]

- **Player toolbox:** Autopsy, Séance, Scry, Binding circle; demon types with bestiary
  entries; exorcism / true-name alternate win. (DESIGN) [open]

- **Scoring system:** identification credit, accuracy of guesses with confidence, why
  the player lost (wrong read / missed / never available / failed to persuade). Absorbs
  the removed voting prompt and the Scion credit rule. [open]

- **Storyteller/director and solvability check:** poisoned readings become arbitrary
  (chosen plausibly) rather than inverted; check that a case can be solved. (DESIGN)
  [open]

- **Procedural town:** blocks, buildings and roads generated per case. (DESIGN) [open]

- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]

- **NPC memory and recency bias.** (Random ideas) [open]

- **Dead NPCs:** no ghost votes for now. (DESIGN, deferred) [watch]

---

## Template gaps (NYI)

A running list of patterns that come up in play, or that the mechanics make meaningful,
but that no link template recognises yet. Add to it whenever a playtest log shows
"no template matched" on a combination that should mean something.

- **Time-scoped Revenant possession premise.** Let "X was possessed by a Revenant
  on day D" be an explicit argument/case premise, so testimony and alignment claims
  can be evaluated for the relevant time rather than invalidating the person's
  whole history. Keep suspected possession distinct from confirmed knowledge and
  do not expose the hidden victim. Deferred to the case-builder/theory work in
  section 4. (Oct 21) [decided; deferred]

- **Succession breaks earlier clears.** A Seer "no" (or any not-the-demon clear) only
  speaks for the demon *as of that night*. If a hanging with 5+ alive (so a Scion could
  rise) falls between two readings, group elimination, overlap and pair elimination
  must keep "X became the demon afterwards" as an explanation instead of "the earlier
  reading clears the rest". In 55774, #150 cleared Edda from Agnes's night-5 "Greta or
  Edda" using the night-4 "Fenwick or Edda: neither", across Hollis's hanging. Greta
  was right, but Edda (evil, an equally possible successor) stayed a live candidate.
  NPC reasoning and the bot should apply the same limit to old clears. (Astra, 55774)

- **Same person in repeated Seer yeses, later proven good** → that person is the
  red herring; drop them from the Seer's later readings. (55774: Jory)

- **Evil reading on a proven-good person** (Dowser count, Archivist pair) → Marked.

- **Minion gifts in templates.** The builder can now conclude "X is the Breathstealer /
  Poisoner / Revenant / Scion", but no template reasons toward a minion: e.g. someone
  silenced, and the people seen on their block that evening (the Breathstealer has to be
  there); a reading that failed on a night someone was near the reader's home (the
  Poisoner's visit); a totem found and the people who live where its material is from
  (the Revenant). Needs "silenced" and "totem" facts that templates read. (54875: the
  totem card had no adapter in the case workshop either.)

- **Breathstealer by presence:** someone silenced, and who was on their block that
  evening (the Breathstealer has to be there); over several silencings, the one person
  present each time. (96773: Bartholomew was nearby for each.) Needs "silenced" facts
  with where the silenced person was. Depends on the Breathstealer decision below.

- **Night companions of the proven evil:** out on the same block on the same nights as
  someone proven evil (a Gravedigger-confirmed Poisoner) → likely their teammate. 96773:
  Hollis's watch put Isolde out with Greta on night 1 (the kill block) and night 2;
  Greta was hanged and shown to be the Poisoner, but nothing linked Isolde to her.

- **A Medium's relayed sighting vs the dead's known vantage:** the dead watched or
  guarded a different block that night, so couldn't have seen what the Medium says.

- **Accounting:** a Lamplighter's "N others out" plus home alibis for everyone but one
  → the unaccounted person was out.

- **Role confirmations:** a Clerk or Gravedigger confirming someone's gift → that claim
  is backed (claim_backed covers the Clerk; the Gravedigger on a living rival claim
  does not).

- **Duty claim vs reading:** the off-route check now tests a named destination (a watch
  kept, a door guarded, the hearth of the dead) against sightings. Still missing: the
  hearth in the Medium's *reading* ("at Dorian's hearth") as the destination, so a
  reading and a sighting can conflict, not only the alibi and a sighting.

- **Walker's sightings vs the Lamplighter count:** more people reported out than the
  Lamplighter counted (or a Lamplighter who counted others but is seen nowhere).

- **NPC at evening location vs. murder evidence trace originating from a different location.**

- **Evening sightings and conversations vs the scene trace** (54875). Seeing someone at
  the tavern in the evening, or two people talking there, should be a location sighting
  that links to "the killer spent the evening on the Square". Conversation cards don't
  count as location sightings today, so the best evening alibis on the board can't touch
  the trace (tried: "Odette and Constance talking at the tavern" with the Square trace at
  Hollis's death scene).

  > **Implemented in Codex batch 2 (Oct 25):** fix the native dedup found below: `Argue.check`'s
  > template-plus-cards key omits the subject, so a trace match against two people in one
  > conversation offers only one. Include the subject in the key; test two participants on one card.

  > **Batch 2 verification:** the native key now includes the subject. One conversation
  > combined with one trace offers both participants, while duplicate matches for the same
  > person still collapse. Focused checks cover both input orders and a repeated receipt.
  > The wider trace-linking/preview item remains open; no evidence weights changed.

## Closed

Closed items now live in [BACKLOG_COMPLETED.md](BACKLOG_COMPLETED.md).
# Demonologist backlog

The single to-do list. It gathers the deferred and open items from DESIGN.md, the
role_exploration On Deck list, the Project notes and playtests 13473/55774. Items are
sorted by effort. DESIGN.md stays the record of how things work and why.
Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[tentative]** = proposal for later design/tuning review;
**[knob]** = not planned, a balancing tool to
reach for only if needed. Settled, built and parked items move to **Closed** at the end. Source in parentheses where useful. Exploratory mechanics
(new roles, places, ideas still being shaped) live in role_exploration.md.

---

## 1. Bugs and quick fixes (hours, low risk)

- **Case 44814: inconsistent pair-reading defenses.** NPCs can both redirect a
  reading toward the other candidate and declare its source a liar, with separate
  mechanical effects. Choose one explanation, or explicitly frame alternatives
  without awarding both as independent defenses. [decided]
- **Case 44814: relayed role claims in the cast list.** Hearing a claim through
  another NPC should appear as an attributed hearsay claim, distinct from direct or
  public disclosure. Do not silently turn a relay into a direct confirmation. [decided]

- **Rumormonger as the sole modifier holder.** The gift excludes its own holder from
  its candidate pool. When a healthy Rumormonger is the sole Marked or Sleepwalker,
  the current fallback produces an arbitrary false pair/secret instead of useful
  information. Decide whether it should explicitly report no valid result or whether
  setup/gift rules should change. This needs coordinated reading/UI/belief handling;
  do not silently assume a healthy report always identifies someone else. The live
  comparison currently preserves the native fallback, with a generator-backed test.
  Found during Oct 22 integration. [open]
- **Voting text when a block already exists.** Replace the generic majority message
  with the actual replacement/tie counts in both the nomination prompt and meeting
  view: "X to put [nominee] on the block instead of [current nominee]; X-1 to tie
  (no one will be executed)." Use the recorded highest vote count plus one for X,
  subject to the normal minimum. Also handle an empty block after an earlier tie,
  where the high count still matters. Current UI and text prompts still display
  only `vote_threshold()`; voting logic already distinguishes these outcomes.
  (Oct 21) [decided]

- **From playtest 54875** (Oct 23; Claude played, the user drove; full trace analysis in
  [docs/playtest_54875_diagnosis.md](docs/playtest_54875_diagnosis.md)). The evil team
  was identified by Day 3 and the town lost anyway: one execution in six days.
  - **The case workshop's evaluator never ran in play.** Every presentation fell back to
    the legacy argument rules (`workshop_delivery`: "could not use the shared
    assessment"). `Shared.prepare` refuses to take over a listener's legacy ledger when
    an entry it would own has touched someone at suspicion 0.0 or 1.5 ("Saturated legacy
    beliefs need a reversible baseline") or was clipped. Demon victims sit at 0.0, and
    Constance's night-0 reading named Dorian, so every listener was blocked from the Day 2
    meeting on. This will happen in most games. [decided]
    - **Quick fix:** skip the dead in the saturation check (a demon victim's suspicion no
      longer matters, and `adjust` already ignores them).
    - **Real fix:** the check exists because suspicion is a clamped running sum: each
      recompute applies differences to a value clamped to [0, 1.5], so removing an entry
      can't restore the value it had before the clamp. Keep the unclamped sum (base +
      contributions) and clamp only when reading it; then any entry can be removed
      exactly, and the reversibility checks, the "clipped" flag and the fallback can go.
    - **No silent fallback (decided Oct 23, at least while testing).** If the evaluator
      can't take a case, block the submission and say why, in the preview and at
      presentation. Never quietly run the legacy rules instead. `_present` has three
      silent `return {}` exits; until they're gone, log which one fired.
    - The preview judges a neutral reference listener, so it showed "accept 1.000,
      Constance +0.450, Edda +0.450" while the real listeners got about +0.10 from the
      legacy rules. The preview should judge with the real listeners' ability to run.
  - **Revising a case makes it weaker.** Re-presenting a revised case retires the old
    entry (`_workshop_retract`), then the legacy `Argue.evaluate` applies novelty:
    `used_facts` (per listener, keyed fact>target, set by any earlier argument or direct
    tell, never cleared) counts each previously used fact at 0.35. The richer case
    replaced the old one at a lower weight (Hollis 0.128 → 0.105 → 0.091 as the case grew
    from 2 to 4 to 6 reports). A revision is the old case plus new support: old facts keep
    what they earned, new facts count in full, and only an identical re-presentation is a
    repeat. The ledger reason also keeps the first version's text ("2 original reports").
    [decided]
  - **A revised case gets a new card number,** so it sorts to the top of the newest-first
    lists; the old version stays, marked superseded. [decided]
  - **Defence moves stack every day.** They're keyed `def:<id>:<day>:<move>`, so the
    same plea ("look at the other one in the pair", "it's a lie") was counted again at
    each meeting (-0.03 and -0.025 per listener each time), while accusations fade about
    0.05 a day. One entry per move per nominee, refreshed and fading like accusations.
    [decided]
  - **Free repeats.** A card the listener already heard is free once per conversation
    (`free_repeats`); the second repeat costs a question. Presenting costs a question
    unless the listener has already heard it, which is the rule the user wants, but the
    reply doesn't say so ("You've heard this from me already"), and the free repeat
    still re-runs the argument. Hollis's `present 119` was the second repeat and cost
    his last question with no explanation. When the earlier hearing was public, say so
    ("I heard you say that at the meeting"). [decided]
  - **Own gift, "ask about <gift>".** A holder who declines to own up falls through to
    "I couldn't tell you who the Archivist is" (`Social.answer_about_role`), which is a
    lie about their own gift. Use the refusal line ("That's not for me to say"). Dorian,
    day 1. [decided]
  - **A press with a sighting replayed the alibi word for word.** `present 48` to
    Constance (my vigil, against her "home") repeated "Home. Where else would I be?" and
    the same window sighting, behind a new lead-in, and cost a question. Pressing should
    change the story, harden it or stonewall in a new line. [decided]
  - **The owned lie didn't follow the disclosure.** Constance said "home" twice, then
    claimed Night Watch one question later without "So yes: I was out…". The admission
    fires only after a "you lied" deduction, not after a pressing sighting card. A
    walker who discloses after being caught out by a sighting should own the earlier
    story the same way. Her "What it's shown me, I'll keep to myself" also came after
    she had already told the reading (as the window sighting). [decided]
  - **Repeated stonewalls.** Isolde's press and the following `ask night` got the same
    line and the same card (#96): two questions for nothing. A second identical refusal
    should escalate ("I told you already…") or cost no question. [decided]
  - **Missing and duplicate cards.**
    - Lian's "Yesterday evening I was at home" (asked about yesterday evening) made no
      card; a stated whereabouts is a card even when they share nothing else.
    - Isolde's private Lamplighter claim made a card; her public claim at the meeting
      didn't update it. One card with a disclosure history (private, then public);
      going public lifts the confidentiality cost.
    - Constance's "I saw them out in the street from my window at night" reused card
      #84 on later days with no night named.
    [decided]
  - **Wording.** [decided]
    - Night sightings in answers say "that night"; say which night (the card does).
    - A vigil "sees X moving through the Market"; with every block joined nobody passes
      through. "Out on the Market".
    - A claimed Night Watch says "I watched the Market…" and then "I saw them … from my
      window": a walker's sighting should be told as seen while out.
    - The town overview's "(1 more at wharf)" followed by "1 other out of sight" reads as
      two people. The cast list's "at Unknown" reads like a place name.
    - At a meeting, a speaker opened with "I will answer that much" with nothing put to
      them.
    - "vote yes / vote no" sits next to "present … for/against", which invites the wrong
      reflex. "Vote to execute / Vote to spare".
  - **`tools/test_social.gd` fails on main:** "a false Night Watch's night story matches
    their fake report (20 cases)". It passes on `claude/case-reasoning` and fails on main
    since the 61251/25923 pass, so the merge carries it. It's the same family as
    Constance's two night-1 stories (private "Isolde", public "Jory"); fix together with
    "evil frames should cohere" in section 2. All 45 test scripts were run on the merge
    (Godot 4.4.1 headless); this is the only failure. [decided]

## 2. Small features and tuning (a day or so each)

### Deduction types and templates
- **Starting secret-count card.** Generate a public setup card stating how many secrets
  are in town. Decide whether the count means modifier types, holders (Lovers count
  twice), or includes ordinary personal secrets; do not expose assignments. (61251/25923)
  [decided: card; count definition open]
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
  - **A watcher's report against the player's vigil of the same block and night**
    (Constance: "I watched the Market and saw Jory"; my vigil saw only Constance and
    Isolde) had no link. A false gift report is the strongest kind of lie.
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
  - **The totem has no adapter:** it should read "a Revenant is in play and lives on
    Chapel Hill", which crossed with an Archivist pair names one person.
  - **A claimed day gift but seen out at night** (Greta claimed Dowser after Isolde saw
    her on the Docks) is a reasonable suspicion pattern.
- **From playtest 54875: case-workshop feedback.** [decided]
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
  - The evaluator toggle is easy to flip unnoticed; the preview headline should say which
    model produced it.
  - "Assume Edda: evil" appeared on the premise without the player adding it. Show where
    each assumption came from (the board, a derived inference, the private guess).

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
- **From playtest 54875: the Gravedigger in a reluctant town.** With no executions the
  Gravedigger has nothing to read; Hollis held a top-value gift and no information all
  game. A Gravedigger who knows this could be the one pushing the town to hang someone
  ("so I can tell you what they were"), which also gives a cautious town a reason to act.
  [open]
- **From playtest 54875: evil frames should cohere.** Constance's private night-1 story
  ("I saw Isolde", from the alibi-hiding window sighting) and her public Night Watch
  reading ("I saw Jory") came from separate generators and conflicted; that crack is
  what unravelled her. Decide whether it's a deliberate crack or should come from one
  plan per scapegoat per night that every bluff draws from. Likewise a side frame
  through one gift (an Archivist or Rumormonger pair) shouldn't be undercut by invented
  night walks aimed at someone else. (user, Oct 23) [open]
- **Case 44814: asking about an already disclosed gift.** Currently "are you the X?"
  repeats confirmation and consumes a question, without requesting withheld results;
  a profile role guess is private bookkeeping only. Decide whether the dialogue
  question should offer a useful route to the withheld readings or clearer feedback
  about asking for them. No automatic extra disclosure from recording a guess. [open]
- **Case 44814: readings after role disclosure.** Once a gift is officially claimed,
  ordinarily share available readings unless trust is very low. Current public
  disclosure guarantees only tier 3 (the role), so fresh readings can remain withheld
  at ordinary trust and then be announced publicly moments later. Preserve valid
  privacy/provenance boundaries when changing the policy. [decided; tuning open]
  54875: nobody reached the readings tier (openness > 0.75) all case, so every private
  claim (Edda, Constance, Isolde, Lian) came with "I'll keep what it's shown me to
  myself". Edda told the player that, then announced the reading at the meeting an hour
  later: the gift-type terms (`one_shot_gift` +0.3, `hides_from_demon`) exist only in the
  public claim roll, not in the private disclosure roll. Give the private roll the same
  terms, and if an NPC will announce something anyway, the player who asked hears it
  first.
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
- **A genuinely neutral opinion.** Add "I'm not sure what to think" between trust
  and suspicion for both good and evil NPCs. `answer_opinion` has several suspicion
  bands, but its middle replies still choose between "seems all right" and
  "something's off"; distinguish uncertainty from a refusal or a veiled accusation.
  Do not create incriminating opinion evidence solely from neutrality.
  (Oct 21) [decided; boundaries/wording open]
- **Explain distrust of the player.** Good and evil NPCs with low player trust should
  be able to say so and, where remembered, cite the reasons: misguided executions,
  accusations, nominations, votes or broken confidences/promises. Use their known
  history and beliefs, with the same presentation options for evil; a refusal alone
  should not be the only signal. Coordinate with apologies and vote-resistance
  feedback. (Oct 21) [decided; delivery/frequency open]
- **Medium visits only Demon victims.** Restrict the gift's eligible dead to people
  killed by the Demon, and update role descriptions, dialogue, target selection
  and real/fake report consistency. Current `_medium_choice` considers every
  unvisited dead person; a same-day tie favors Demon victims, so the requested
  restriction is not implemented. Coordinate with the existing director-driven
  visit proposal and keep misleading results possible. (Oct 21) [decided]
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
- **Offering protection eases fear.** Someone you've offered your ward or a vigil (and
  kept your word to) should be less afraid to say what they are. (96773) [decided]
- **Backing a strong case builds trust.** Nominating or voting for someone the town
  strongly suspects (and who turns out evil, or is widely believed so) earns a little
  trust from the NPCs who agree. It's what makes throwing a teammate under the bus pay
  for evil, and it rewards good NPCs who stick their necks out. (Oct 19) [decided]
- **The fearful ask for protection.** NPCs afraid their gift makes them a target appeal
  to the Demonologist (a ward, a vigil) and/or the Warden for protection, instead of
  only clamming up. Ties into offers easing fear. (Oct 19) [decided]
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
- **Town knowledge of friends and rivals.** NPCs should know other people's public
  friendships/rivalries and sometimes disclose them in the same style as haunt
  locations. Separate that knowledge from exact private trust scores and hidden Lover
  status. Track which relationships the player has learned; avoid duplicate reveals.
  Add conversational wording and useful attribution. [decided; sharing rates open]
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
- **Warn about repeated role guessing.** Before the player continues the escalating
  wrong-guess/patience spiral, have the NPC say something like "Clearly you're just
  grasping at straws, and I'm running out of patience." Make the warning communicate
  their patience without revealing whether a particular bluff/guess is true. Keep
  conversation slots, daily fatigue, and the across-days wrong-guess counter distinct.
  [decided; warning cadence open]
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
- **Limited-use tool warnings.** Clearly warn before spending Ward and other
  limited-use abilities; show remaining uses and that spending one is irreversible.
  Current help and some labels already say "once per case", but the generic
  "Ward someone..." and promise paths do not consistently communicate the limit
  before selection/use. Cover direct targeting and promises; distinguish promising
  a tool from actually consuming it. (Oct 21) [decided; warning presentation open]
- **Selected filter rows first.** On the case board, promote rows explicitly selected
  in the person/place filters above unselected rows; e.g. filtering for Agnes,
  Constance and Dorian puts those three first. Preserve predictable order within
  both groups and coordinate with all/any/exclusion and timeline layout.
  (Oct 21) [decided]
- **Hide Unselected.** Add a case-board toggle to hide rows not explicitly selected
  by the active person/place filters. Keep this distinct from hiding evidence cards,
  showing hidden cards, and the currently focused card/profile; define the
  no-selection behavior and retain pinned-card/filter consistency.
  (Oct 21) [decided; edge cases open]
- **Long dropdowns in columns.** Once a dropdown exceeds roughly eight options,
  consider multiple columns: at most eight options per column for an uncategorized
  list, or columns grouped by existing categories. Example: the deduction planner's
  "is the <blank>" selector has about twenty options across roughly four categories.
  Prefer meaningful existing groups where available; exact threshold/layout remains
  open. Keep category labels, keyboard navigation, and screen bounds usable.
  (Oct 20) [tentative]
- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]
- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main
  view; people who aren't talking or working showing on the map; a wrong role guess
  blocking process of elimination.
- **Card zoom and text extension.** Settle card sizing, clipping and zoom/detail
  transitions before extending rich text onto board cards, pinned deductions, the
  tray and Card List. The shared formatter, log and profiles are built (steps 1–3);
  steps 4–5 are deferred. Card List/working-set rows are wrapping Godot Trees with
  one colour per row; richer rows still need custom cells or replacement controls.
  See [the handoff](docs/text_system_handoff.md) for hooks, issues and alternatives.
  [decided: extension deferred; renderer approach open]

## 3. Medium features (several days; touch a few systems)

- **Expanded dialogue and trust management** (Oct 20; design candidates, pending
  the unified retuning proposal). [tentative]
  - **Apologize for a specific incident:** add Apology under the existing Offer...
    dialogue menu. Cover accusations, nominations against them, votes against them,
    contributing to a loved one's execution, exposed confidence and broken promises.
    (Menu placement and vote/loved-one examples added Oct 21.) Scale forgiveness by actual
    harm/danger (a failed nomination versus nearly being executed), the evidence
    available at the time, and responsibility taken. Insight can recognize either
    an understandable mistake or ignored contradictions; it is not automatic
    forgiveness. Allow partial repair once per incident; serious trust caps may
    recover gradually through later conduct. An apology for treatment need not
    require falsely withdrawing an ongoing suspicion.
  - **Suggest actions based on claimed role:** ask a Warden to protect a person, a
    Seer to check a person/pair, or a Night Watch to watch a block. Track request,
    response/commitment, intended action, actual action, and follow-up separately.
    Trust, Confidence, Composure, danger, competing priorities, and the NPC's
    relationship with the requested target can affect compliance; allow refusal
    or a counterproposal. (Target relationship added Oct 21.) Offer the same dialogue to evil
    bluffers, who can lie about compliance/results, so requests do not verify roles.
    Exact trait interactions remain open.
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
  - **Ask what would change their mind:** expose friendship, conflicting information,
    player distrust, or preference for another execution as actionable resistance.
  - **Explain an execution's purpose:** propose an information-seeking execution
    (e.g. for a Gravedigger read) without needing to assert the target is the Demon.
  - **Promise confidentiality:** one straightforward promise option that can support
    private disclosure, with consequences for keeping or breaking it. Avoid a
    negotiation tree or multiple branching confidentiality terms; coordinate with
    existing confidence/secret-keeping rules rather than awarding duplicate credit.

- **Learn personality through other NPCs.** Asking about someone can reveal one of
  that person's traits and unlock its actual score in their profile, using the
  existing learned-trait presentation. Example: Agnes calls Bartholomew stubborn,
  revealing Confidence. Filter descriptions through the speaker's relationship:
  a confident friend is "principled", a rival "pigheaded". Separate the revealed
  trait/score from that subjective wording, and define which traits the speaker
  can reasonably know and how often this occurs. Coordinate with public
  friends/rivals and haunt disclosure; do not reveal hidden relationships.
  (Oct 21) [decided; discovery rules open]
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
- **Last words.** A condemned NPC gets some final words before the hanging (flavour). (Oct 19) [decided]
- **Nominations make a case.** The nominator cites several cards, even weak ones.
  Mostly flavour; it only moves NPCs if it brings new information. [decided]
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
- **Lovers downside:** when one dies, the other becomes withdrawn: Privacy to max,
  Gossip to min, and whichever other shifts hurt the player most (e.g. Composure up so
  they're harder to read). Visible, so the player can notice the change. [decided]
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
- **Claims/reveals timeline** next to the location timeline. (DESIGN) [open]
- **Dialogue voices for the rest of the cast.** The composer is merged (Agnes,
  Bartholomew, Constance × five situations; dialogue lab at `ui/dialogue_lab.tscn`).
  Everyone else uses the plain lines until they get a voice. [decided, later] 54875: on
  day 1 Dorian and Odette gave word-for-word identical gift refusals and night alibis
  ("Whether I have a gift is my own business"; "At home all night, same as any honest
  soul"), which makes the town read as one person.
- **Bot coverage of the new talk options:** the bot doesn't offer wards or vigils or ask
  about others to learn haunts, so bot runs don't measure them. [decided]
- **Evidence-reading bot.** The bot ignores traces and dropped materials entirely (and
  peeks at `w.dropped` when deciding to search), so bot win rates say nothing about
  physical evidence. Teach it to read traces and drops, and stop the peek, to measure
  what evidence is worth. [decided]

- **The Revenant can hide a new totem each day.** Burning a totem doesn't make the
  Revenant safe to hang for good: in 54875 the totem burned on Day 4, a new one was
  hidden Day 5, Edda was hanged with it and Isolde turned. When a totem burns, signpost
  that another may follow ("it will seek a new hiding place"), and think about whether
  the totem search can keep pace. [decided: signpost; balance open]
- **The ward as evidence, and a visible save.** Your ward isn't a card today, and a ward
  that stops an attack leaves no sign. Make the ward a card (who, door, night) and let a
  held ward leave a mark (a scorched sigil) as physical proof the demon came to that
  door. Feeds the "Protection + quiet night + sighting" template gap. (user, Oct 23)
  [decided]

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
- **Protection + quiet night + sighting** (user, Oct 23). [decided]
  - Ward + "nobody died that night" + someone seen out on the warded block (Night Watch
    report, window sighting, vigil) → strong evidence that walker was the demon at the
    door. The same shape for a Warden (its statement of whose door it guarded, or a claim
    plus a quiet night) and a Veteran (claim + quiet night, or its "came by way of"
    report). Explanations to keep: another walker with an innocent reason (Lovers,
    Sleepwalker, a walking gift), the demon held back, a false protection claim.
  - Today the quiet-night template covers Warden/Veteran claims only, with "your ward" as
    a rival explanation; the ward itself is not a card (section 3).
  - Re-weigh if a day-killing demon is added (section 4).

---

## Closed

- **Player-nominated NPCs already defend themselves (verified Oct 21).**
  Player nominations call `Game._defend_pending` before voting, just as NPC
  nominations do. With `C.DEFENCE_MOVES=true`, this invokes `Mind.defend_self`;
  silenced nominees deliberately cannot speak. The idea-dump request is already
  implemented, so no duplicate open task is added. Any observed missing defence
  should be investigated as a reproduction-specific bug.

- **61251/25923 concrete fixes (Oct 20):** private card targets include the listener;
  speaking for their own claim acknowledges support and grants +0.03 trust once per
  fact, instead of pressing them. Supportive deductions are routed as defence too.
  Verified on current main Oct 21 (`_route_present`, `hear_defence`, private target
  picker); no new support feature needed. Daytime whereabouts produce attributed cards even
  when the speaker withholds other sightings. Publicly cited night sightings produce
  the same evidence cards as private testimony, including evil fabrications.
- **Disclosure consistency:** a Night Watch's withheld reading cannot be obtained by
  switching to whereabouts or person-specific follow-ups. Repeating old readings
  before withholding newer ones now says "the rest of my readings" when citing fear.
- **Secrets as evidence:** existing private, public-defence and gossip confessions
  carry secret metadata; linking a confessed personal secret with night movement
  offers a defeasible explanation. Marked-report support is wired for future disclosure.
- **Own knowledge and evil cover:** NPCs do not entertain another gift as their own
  identity; ordinary sightings can be on their route rather than only at their final
  destination. Evil cover cannot nominate or vote to execute its Demon. A Warden
  bluff may claim to protect a teammate, avoiding a metagame alignment tell.
- **UI and phrasing:** spent nomination button disabled with tooltip; blue X on homes
  of the dead without crime scenes; circular nominee portrait crop; consistent Clear
  filters hover/pressed styles. Alternative-explanation replies label a subsequent
  preferred suspect as a judgement about the whole case, not a trace-specific match.

Settled decisions, built work and parked levers, kept for the record.

- **Checked Oct 23 (54875 questions), working as built:** "are you the X?" already gives
  a right first guess a 50% chance of one extra disclosure tier (`answer_is_role`);
  "ask about X" for their own gift owns up at 0.15 + 0.2 × trust. Night walkers can be
  seen anywhere on their path: leaving home (from a neighbour's window or by someone
  out on that block) and at their destination (`_night_sightings` checks the whole
  path). The demon's night-3 kill of Agnes was the "hungry" temperament, not a plan to
  lower the vote threshold.

- **Evil voting to execute its own demon** (seen in 54875: Edda voted yes on Constance
  on Days 2 and 4). The played branch predated the 61251/25923 fixes on main ("Evil cover
  cannot nominate or vote to execute its Demon"); merged Oct 23. Re-check in the next
  playtest.

- **Oct 22: Lamplighter drop path order.** `_walk` now receives the completed lamp
  route before sampling a drop. Lamp drops can use public locations on all four
  blocks; ordinary walkers retain their shortest routes and one drop roll. Seeded
  route/drop checks cover both paths. No drop probability or inaccessible-home rule
  was changed.

- **Oct 19: relaying another's private reading** is gossip with the source unnamed ("Word reached me from the Seer"). See DESIGN, "The town meeting" (Citing reasons: relays).

- **Oct 19: shadow good self for evil,** steps 1, 2, 4 and 5 of docs/shadow_self_plan.md (step 3, rebuttals, is on hold in section 3). Evil's public acts follow its good self unless breaking cover beats caution; refined heat; daily scapegoat re-pick. See DESIGN, "Shadow good self".
- **Oct 19: Mediums,** a shared menu for real and fake: fake readings fit the dead's public record and claimed gift, frame only some nights, "nothing new" and empty answers for both. See DESIGN, "Mediums".
- **Oct 19: hints at the meeting and following up on them** ("ask why", confidences). See DESIGN, "Citing reasons".

- **Oct 19: meeting opinions cite only what the audience has.** Reasons carry their source; private readings become a hint or a reveal (see DESIGN, "Citing reasons").

- **Oct 18 quick-fix pass:** everything then in this section (see DESIGN, "History and measurements"; the full notes are in git history before Oct 20).
- **Deduction types built Oct 18:** Martyr facts in templates, the Martyr who doesn't die, pair with both proven good, Misread (Marked, red herring), suspicious, hiding a secret, secrets and evil roles as conclusions, builder headings; NPCs owning their own lies; fear as cover.
- **Day limit by town size:** settled, kept as is (6 days for 7 townsfolk, 8 for 10).
- **"Maybe" conclusions** [knob]: half the persuasion and half the trust consequences, if committed conclusions turn out too punishing. If used: "maybe" can't support further deductions or be cited in accuse/defend.
- **Initial general skepticism** [knob]: a lever to pull only if the early game gets too decisive.
- **"No gift" denials** [knob] (C.ALLOW_NO_GIFT_DENIAL, off since Oct 18): evil almost never bluffed it, so a denial was near-proof of good at the cost of the gift.
- **Playtest Notes 12553, done:** "I agree with X", "from my window", home on "was home" cards, pressure in the debug view, combined and excluding filters ("greta+night" / "-sighting"), clicking a timeline cell again clears it.
- **Timing within the night:** settled, not modelled (a night stays one instant).
- **Template gaps built Oct 18:** Martyr saves as proof of good; the chosen hanged with the Martyr standing; a pair reading naming two proven-good people; filed good / Marked / red herring deductions as template inputs; a Seer pair with one proven good.
- **Vigil deterrent:** tried and removed Oct 18 (it cost the bot's vigil catches). Offered vigils build trust only.
- **An open Warden: "I saw X out while I stood guard":** dropped Oct 19.
- **Oct 19: silenced NPC eligibility.** Silenced NPCs are excluded from player
  approaches and tavern gossip. They become eligible again when silence ends. (96773)
- **Oct 19: victim trace filter.** A victim's own night walk cannot supply the
  misleading trace at their cottage. Other passers still can; no balance tuning. (96773)
- **Oct 19: full-screen case board.** The grid fills the canvas. Cards & filters,
  Build case, and Profile start minimized and open as movable, resizable overlays.
  Opening or minimizing them preserves the board's pan/zoom and the working set;
  staging cards opens Build case, and Record theory opens Profile. The deduction
  tray also overlays the grid. Initial zoom waits for the visible layout to settle.
  Checked with rendered views and mouse drags; regression checks: 71 fixes, 28 social,
  and 63 UI checks passed on standard Godot 4.4.1. The UI test's existing synthetic
  card-drag preview and shutdown resource diagnostics remain.
- **Oct 19: case-board layout and filter follow-up.** Fixed recognized text filters
  resizing initially closed tools: filter chips/status keep a stable dock height,
  and overlay sizing waits for container layout to settle. Shared text, kind,
  person, place and any/all filters now live only on the main screen and apply to
  both the grid and Cards. Added the centered title and view tabs, filters with
  day/fit controls below, and a bottom-left dock for Cards, Build case, Profile,
  Notes and Roles, retaining the existing visual style. Timeframes have stronger
  separators and subtle distinct tints, darkest at night; morning/evening use
  sunrise/paler sunset icons. Statement, reading and accusation glyphs supplement
  role icons; no legend. In Statements, left-clicking a name only filters;
  right-click opens its profile, switches to another person, or minimizes the
  already displayed person's profile. Checked rendered layouts and panel mouse
  movement/resizing; 81 UI and 25 board checks passed on standard Godot 4.4.1,
  including recognized/misspelled filters before opening tools and profile toggles.
  The UI test's existing synthetic drag-preview and shutdown diagnostics remain;
  the rendered check completed without errors.
- **Oct 19: case-board UI phase 2.** Bottom rows now run from the grid to removable
  filter chips, the popup toolbar, then the deduction tray. Filter chips wrap in
  their own row without stretching the toolbar buttons; deductions expand beneath
  both rows. Renamed Cards to Card List, starting at its minimum width (340), and
  removed its action buttons. All three board windows use a visible flat line to
  minimize. A shared right-click menu on grid cards, list entries, tray deductions
  and profile card links offers Add to Deduction, Hide/Unhide, Find Links and Hints;
  deductions also offer Delete, with Unpin retained for pinned deductions. Actions
  target the clicked card; Find Links searches for links involving that card.
  Hidden deductions now respect Show hidden in both the grid and tray. Moved Show
  hidden after Clear filters and gave Clear filters a gold border. Verified 108 UI
  and 25 board checks on standard Godot 4.4.1, plus rendered layouts, the card menu,
  and panel mouse movement/resizing. The UI test's previously recorded synthetic
  drag-preview and shutdown diagnostics remain.
- **Oct 19: continuous social bars and town selection.** Learned social traits now
  display their actual scores, filling from the midpoint toward the value; 0.5 is
  a thin center marker. Undiscovered traits remain unknown. Privacy runs from Open
  Book (0) to Secretive (1), matching its actual score. Townsfolk rows have more
  padding, reserve only occupied role-icon slots, and elide long text inside the
  plaque. Living townsfolk show Location: followed by the visible location or
  Unknown, instead of falling back to their occupation. Circular portrait masks
  prevent artwork spilling past its frame; face crops were adjusted, including
  Hollis, Odette and Constance. Only townsfolk-panel clicks own the map highlight:
  select home, workplace, visible icon and known haunts; click again to clear, or
  another person to switch. Map hover, map clicks, profile changes and conversation
  focus cannot take it over. Night ward targeting remains available separately.
  Verified 25 focused town-UI, 108 existing UI and 71 fixes checks on standard Godot
  4.4.1, plus rendered town, portrait and trait-bar views. The existing UI test's
  synthetic drag-preview and shutdown diagnostics remain; rendered checks had no
  errors.
- **Oct 19: hidden-card fading and recent sightings** (`codex/ui-sightings-followup`).
  Shown hidden cards now draw at 42% opacity across board cards, place markers,
  pinned/tray deductions and text card lists, including staged cards. Cast-list
  locations now use "at". Asking about a person can add remembered sightings of
  that specific person from the current and previous two timeframes, keeping their
  original times and speaker attribution. Gossip controls willingness to share;
  the addition uses no extra question. Night reports require a disclosed walking
  gift and respect existing alibis/refusals; evil Night Watch claims reuse their
  approved fake report, and other night bluffs only repeat committed sightings.
  No new bluff generation or shadow-self decision changes. Each daytime phase,
  including the first morning and later dawns, automatically records people
  visibly working at their actual workplace as firsthand sighting cards and
  timeline markers. Repeated looks merge rather than duplicate observations;
  hidden idlers, dead people and night work are excluded. Verified 37 focused
  sighting checks, 110 UI, 25 town UI, 25 board, 89 fixes, 28 social, 102 shadow,
  138 dialogue and 20 dialogue-decision checks on standard Godot 4.4.1, plus
  rendered town, hidden-card and timeline views. The UI test's previously
  documented synthetic drag-preview and shutdown diagnostics remain.
- **Oct 19: shared text system, step 1** (`codex/text-term-registry`). Added a
  public display-term registry seeded from the cast, character colors, role
  descriptions and existing role icons. Stable person/role IDs carry optional
  color, icon and tooltip metadata; other term kinds can register through the
  same API. Matching returns original character ranges, preserves capitalization,
  supports possessives and Unicode word boundaries, and prefers the longest
  phrase. Ambiguous lowercase words such as medium/clerk require explicit role
  context; callers can limit eligible term kinds or opt out. Registry lookups
  return copies. No world/secret-role state is read. API and remaining steps are
  documented in `docs/text_formatting.md`. This is the registry/matching foundation;
  UI formatting and tooltips will be integrated in later steps. Verified 25 focused
  checks and a clean Godot 4.4.1 editor import.
- **Oct 19: shared text system, step 2** (`codex/text-formatter`). Added a formatter
  that covers original plain text with styled spans, preserving source ranges,
  wording and whitespace. A known speaker supplies the surrounding color; named
  characters override only their own spans. Parchment uses readable ink variants,
  and role spans carry public icon/hint metadata with configurable sizes and
  decorations. Overall opacity applies once to text and icons. An isolated native
  RichTextLabel adapter appends literal text, hints and inline images, preserves
  outer formatting contexts and falls back to readable text for missing icons.
  Original text can be reconstructed exactly from the spans. Extended the API
  notes in `docs/text_formatting.md`; game-panel integration remains step 3.
  Verified 24 formatter/adapter and 25 registry checks, a clean Godot 4.4.1 editor
  import, and rendered dark, parchment, faded, compact and literal-text samples.
- **Oct 19: shared text system, step 3 and entity styling**
  (`codex/text-log-profiles`). Names and roles are bold. Good role words use a
  reserved blue darker than Nisha's; evil roles use a reserved red, with ink
  variants on parchment. The speech log now enriches plain passages through the
  shared formatter, keeping speaker colors, portraits, headers, emphasis and
  clickable card references. Typed commands stay literal. Both profile panels
  enrich About, readings, disclosed claim headers, Their claims and About them;
  original times and private/public provenance remain visible. Role icons and
  wrapping paper tooltips supplement role words. Native role hints inside card
  links preserve left-click navigation and right-click card actions. Hidden
  profile entries use the shared fade. Matching font faces preserve the existing
  serif/monospace families when bold or italic. Updated the API notes. Verified
  27 registry, 26 formatter, 17 text-UI, 110 existing UI and 25 town-UI checks,
  including real mouse interaction through role hints and unchanged evidence/RNG
  state, plus editor import and rendered 1920x1080/1280x720 town, profile and
  tooltip views. Existing UI smoke-test drag-preview/shutdown diagnostics remain.
- **Oct 19: small inline icons on dark surfaces.** The shared formatter now carries
  its display surface into the renderer. Dark backgrounds use a cached warm
  light-ink version of each small inline icon, made by inverting luminance while
  preserving transparency; parchment keeps the original art. Processing happens
  once per icon/size on a small image copy, preserving source resources and the
  existing opacity behavior. Portraits and decorative log art retain their
  existing presentation. Documented the variant selection. Verified 29 formatter
  checks (including source/alpha preservation and separate caches), 17 live text-UI
  checks, editor import and rendered log/profile views on Godot 4.4.1.
- **Oct 20: text-system handoff; card extension deferred.** Added
  `docs/text_system_handoff.md` with completed steps 1–3, API/integration hooks,
  remaining steps, existing verification and a resume checklist. Reviewed the
  board/tray/list renderers and documented fixed card heights versus font/line
  budgets, detail thresholds, zoom-dependent row geometry, input and caching
  concerns. Compared custom drawing, reusable native cards, a hybrid and a compact
  board/detail view. Linked the handoff from the API notes and deferred steps 4–5
  until card zoom/presentation is settled. Documentation only; no runtime changes.

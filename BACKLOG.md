# Demonologist backlog

The single to-do list. It gathers the deferred and open items from DESIGN.md, the
role_exploration On Deck list, the Project notes and playtests 13473/55774. Items are
sorted by effort. DESIGN.md stays the record of how things work and why.
Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[tentative]** = proposal for later design/tuning review;
**[knob]** = not planned, a balancing tool to
reach for only if needed. Settled, built and parked items move to **Closed** at the end. Source in parentheses where useful. Exploratory mechanics
(new roles, places, ideas still being shaped) live in role_exploration.md.

<!-- backlog-preparation-start -->
Preparation notes were added on 2026-10-25 against `origin/main` at `9cb8782`, just before the
mechanics-support merge (`0cd2181`); notes that depended on that work were updated after it.
**Prep B001–B201** cover every bold active entry (including proposal subpoints).
They record static code findings and suggested focused checks, not new priorities,
approved tuning, or freshly measured gameplay results. Original wording/tags remain
for context; a “candidate” needs verification before moving to Closed. See
[the preparation map](docs/BACKLOG_PREPARATION.md) for shared dependencies, validation,
and the boundary with unmerged mechanics work. The Closed section is unchanged.
<!-- backlog-preparation-end -->

---

## 1. Bugs and quick fixes (hours, low risk)

- **Case 44814: inconsistent pair-reading defenses.** NPCs can both redirect a
  reading toward the other candidate and declare its source a liar, with separate
  mechanical effects. Choose one explanation, or explicitly frame alternatives
  without awarding both as independent defenses. [decided]

  > **Prep B001 (9cb8782; open):** `sim/mind.gd::defend_self` can emit pair redirection and lying/misled
  > moves together. Choose a single explanation/hearing policy; extend `tools/test_defence_repeats.gd`
  > with the 44814 pair case before changing strengths.

- **Case 44814: relayed role claims in the cast list.** Hearing a claim through
  another NPC should appear as an attributed hearsay claim, distinct from direct or
  public disclosure. Do not silently turn a relay into a direct confirmation. [decided]

  > **Prep B002 (9cb8782; open):** `sim/social.gd::answer_about_role` carries `via`;
  > `ui/cast_list.gd::_claimed` reads direct disclosure only. Reuse
  > `ui/profile_panel.gd::_render_entries` history. Check hearsay, direct confirmation, and public
  > promotion without losing attribution.


- **Rumormonger as the sole modifier holder.** The gift excludes its own holder from
  its candidate pool. When a healthy Rumormonger is the sole Marked or Sleepwalker,
  the current fallback produces an arbitrary false pair/secret instead of useful
  information. Decide whether it should explicitly report no valid result or whether
  setup/gift rules should change. This needs coordinated reading/UI/belief handling;
  do not silently assume a healthy report always identifies someone else. The live
  comparison currently preserves the native fallback, with a generator-backed test.
  Found during Oct 22 integration. [open]

  > **Prep B003 (9cb8782; design):** Coordinate `sim/world.gd::_receive_info`'s self-excluding
  > pool/fallback with `workshop/solver.gd::_report_content` and UI. No-result versus setup changes
  > remains undecided; preserve the generator-backed fallback test until that decision.

- **Voting text when a block already exists.** Replace the generic majority message
  with the actual replacement/tie counts in both the nomination prompt and meeting
  view: "X to put [nominee] on the block instead of [current nominee]; X-1 to tie
  (no one will be executed)." Use the recorded highest vote count plus one for X,
  subject to the normal minimum. Also handle an empty block after an earlier tie,
  where the high count still matters. Current UI and text prompts still display
  only `vote_threshold()`; voting logic already distinguishes these outcomes.
  (Oct 21) [decided]

  > **Prep B004 (9cb8782; open):** `sim/world.gd::vote_pending` retains `block_count` even after a tie
  > empties the block. Share replacement-count logic between `game/game.gd::_show_nomination` and
  > `ui/meeting_view.gd::_draw_tally`; check initial, replacement, tie, and post-tie votes.


- **From playtest 54875** (Oct 23; Claude played, the user drove; full trace analysis in
  [docs/playtest_54875_diagnosis.md](docs/playtest_54875_diagnosis.md)). The evil team
  was identified by Day 3 and the town lost anyway: one execution in six days.

  > **Prep B005 (9cb8782; historical context):** Several child reports are partly resolved.
  > `docs/LEGACY_MIGRATION.md` now specifies a deliberate hybrid; do not read this old diagnosis as a
  > requirement to remove every native social mechanic.

  - **The case workshop's evaluator never ran in play.** Every presentation fell back to
    the legacy argument rules (`workshop_delivery`: "could not use the shared
    assessment"). `Shared.prepare` refuses to take over a listener's legacy ledger when
    an entry it would own has touched someone at suspicion 0.0 or 1.5 ("Saturated legacy
    beliefs need a reversible baseline") or was clipped. Demon victims sit at 0.0, and
    Constance's night-0 reading named Dorian, so every listener was blocked from the Day 2
    meeting on. This will happen in most games. [decided]

    > **Prep B006 (9cb8782; candidate to narrow):** `sim/mind.gd::adjust` now stores unclamped sums;
    > `game/workshop_ownership.gd::_refresh` replaces one reversible joint vector. Verify
    > ownership/revision tests first: unsupported cards remain capability gaps, but the original
    > saturation gate is historical.

    - **Quick fix:** skip **demon victims** (not all the dead) in the saturation check.
      Their suspicion number is pinned at 0.0 when they die (`World._kill`) and
      `Mind.adjust` ignores every later change, so an entry's recorded effect on them
      never actually landed and there's nothing to reverse. The shared model learns
      they're good from the public `demon_death` event, not from that number. What
      their earlier readings and claims are worth is a different quantity (honesty
      plus reading doubt, recomputed from the ledger) and isn't touched by this. The
      executed dead must stay in the check: their suspicion still changes and still
      matters (legacy `Argue._cred` weighs their old claims by it). Caveat: this relies
      on "killed by the demon = good" being certain, which DESIGN says should one day
      be only strong evidence (a demon that kills its own minion); the real fix below
      doesn't.

      > **Prep B007 (9cb8782; superseded proposal):** Do not add this exemption: unclamped storage
      > already addresses reversibility. Death is finite evidence in
      > `workshop/live_assessment.gd::activity_card`, consistent with the agreed 95:5 interpretation; the
      > old certainty assumption is stale.

    - **Related inconsistency:** legacy honesty doesn't exempt demon victims. Evidence
      against Dorian (Constance's frame that he was out on night 0) still lowered how
      much listeners credited his own word after his death, while his suspicion said
      "known good". Decide which one wins. [open]

      > **Prep B008 (9cb8782; partial):** Keep sincerity, role plausibility, and accuracy separate in
      > `sim/mind.gd::_honesty`, `_recompute_beliefs`, and `workshop/solver.gd::report_table`.
      > Consolidate with “Demon victims' earlier information”; death must not make poisoned readings
      > accurate.

    - **Real fix:** the check exists because suspicion is a clamped running sum: each
      recompute applies differences to a value clamped to [0, 1.5], so removing an entry
      can't restore the value it had before the clamp. Keep the unclamped sum (base +
      contributions) and clamp only when reading it; then any entry can be removed
      exactly, and the reversibility checks, the "clipped" flag and the fallback can go.

      > **Prep B009 (9cb8782; candidate to close):** `sim/mind.gd::adjust`/`susp` implement unclamped
      > storage and clamped reads. Validate withdrawal/recompute reversibility in
      > `tools/test_legacy_migration.gd`; do not build a second baseline scheme.

    - **No silent fallback (decided Oct 23, at least while testing).** If the evaluator
      can't take a case, block the submission and say why, in the preview and at
      presentation. Never quietly run the legacy rules instead. `_present` has three
      silent `return {}` exits; until they're gone, log which one fired.

      > **Prep B010 (9cb8782; partial):** `game/game.gd::_presentation_gate` blocks unsupported normal
      > submissions, with explicit unsupported-conclusion/disabled routes. Audit current
      > readiness/preview labels before changing old exits; the hybrid intentionally keeps native social
      > behavior.

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

    > **Prep B011 (9cb8782; partial):** `game/workshop_canvas.gd::file` and
    > `tools/test_legacy_migration.gd::_revisions_and_repeats` cover preserved support on shared
    > revisions. Native `sim/argue.gd::evaluate` has separate novelty semantics; identify the actual
    > delivery path before declaring this entirely unresolved.

  - **A revised case gets a new card number,** so it sorts to the top of the newest-first
    lists; the old version stays, marked superseded. [decided]

    > **Prep B012 (9cb8782; candidate to close):** `game/workshop_canvas.gd::file` allocates a new card
    > with `revises`/`superseded_by`; migration tests assert preserved numbers. Check newest-first lists
    > and labels. Never mutate a version already heard by NPCs.

  - **Defence moves stack every day.** They're keyed `def:<id>:<day>:<move>`, so the
    same plea ("look at the other one in the pair", "it's a lie") was counted again at
    each meeting (-0.03 and -0.025 per listener each time), while accusations fade about
    0.05 a day. One entry per move per nominee, refreshed and fading like accusations.
    [decided]

    > **Prep B013 (9cb8782; partial; stale diagnosis):** `sim/mind.gd::defend_self` now keys
    > person/scope/canonical hash without day. Verify refreshed hearing strength and repeats; the
    > separate shared-defence/alternative-choice work remains open, but deleting a day key is no longer
    > needed.

  - **Free repeats.** A card the listener already heard is free once per conversation
    (`free_repeats`); the second repeat costs a question. Presenting costs a question
    unless the listener has already heard it, which is the rule the user wants, but the
    reply doesn't say so ("You've heard this from me already"), and the free repeat
    still re-runs the argument. Hollis's `present 119` was the second repeat and cost
    his last question with no explanation. When the earlier hearing was public, say so
    ("I heard you say that at the meeting"). [decided]

    > **Prep B014 (9cb8782; partial):** `game/game.gd::_talk_command` already tracks per-conversation
    > `free_repeats`. Explain private/public earlier hearings while preserving the second-repeat cost;
    > migration tests should also confirm a free replay adds no shared effect.

  - **Own gift, "ask about <gift>".** A holder who declines to own up falls through to
    "I couldn't tell you who the Archivist is" (`Social.answer_about_role`), which is a
    lie about their own gift. Use the refusal line ("That's not for me to say"). Dorian,
    day 1. [decided]

    > **Prep B015 (9cb8782; open):** The own-holder decline branch in `sim/social.gd::answer_about_role`
    > can fall through to generic ignorance. Use a refusal without disclosing the actual gift; check
    > repeated-question wording too.

  - **A press with a sighting replayed the alibi word for word.** `present 48` to
    Constance (my vigil, against her "home") repeated "Home. Where else would I be?" and
    the same window sighting, behind a new lead-in, and cost a question. Pressing should
    change the story, harden it or stonewall in a new line. [decided]

    > **Prep B016 (9cb8782; open):** Follow `sim/mind.gd::press` into `answer_night` and dialogue memory.
    > A fresh lead-in can still wrap an unchanged alibi; test the full transcript and question cost, not
    > just a changed prefix.

  - **The owned lie didn't follow the disclosure.** Constance said "home" twice, then
    claimed Night Watch one question later without "So yes: I was out…". The admission
    fires only after a "you lied" deduction, not after a pressing sighting card. A
    walker who discloses after being caught out by a sighting should own the earlier
    story the same way. Her "What it's shown me, I'll keep to myself" also came after
    she had already told the reading (as the window sighting). [decided]

    > **Prep B017 (9cb8782; partial):** `sim/mind.gd::_answer_gift_impl` already admits a good walker's
    > stored `lied_nights`. Check sighting-triggered history and evil cover separately;
    > `reading_disclosed` gates Night Watch results in `answer_night`.

  - **Repeated stonewalls.** Isolde's press and the following `ask night` got the same
    line and the same card (#96): two questions for nothing. A second identical refusal
    should escalate ("I told you already…") or cost no question. [decided]

    > **Prep B018 (9cb8782; partial):** `sim/mind.gd::whereabouts_refusal` uses dialogue memory, while
    > repeat costs live in `game/game.gd::_talk_command`. Test ask/press/ask sequences; wording variation
    > alone does not fix paying twice for identical information.

  - **Missing and duplicate cards.**

    > **Prep B019 (9cb8782; partial):** `sim/mind.gd::answer_today` emits whereabouts cards;
    > `game/game.gd::add_card`/`_disclose` merge facts and disclosure history. Verify those first two
    > examples as closure candidates; keep dated window reports with chronology/wording work.

    - Lian's "Yesterday evening I was at home" (asked about yesterday evening) made no
      card; a stated whereabouts is a card even when they share nothing else.
    - Isolde's private Lamplighter claim made a card; her public claim at the meeting
      didn't update it. One card with a disclosure history (private, then public);
      going public lifts the confidentiality cost.
    - Constance's "I saw them out in the street from my window at night" reused card
      #84 on later days with no night named.
    [decided]
  - **Wording.** [decided]

    > **Prep B020 (9cb8782; mixed):** Check `sim/mind.gd::sighting_report`,
    > `ui/main.gd::_refresh_actions`, and `game/game.gd::_show_nomination`. Card dates already exist.
    > Distinguish spoken text, UI labels, and evidence identity; do not change mechanics just to repair
    > prose.

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

    > **Prep B021 (9cb8782; historical test claim):** Current `sim/mind.gd::answer_night` puts claimed
    > walking duties before home; `sim/evil.gd::fake_night_sighting` caches speaker/night. Re-run
    > `tools/test_social.gd` before calling this a current failure. The cited engine/results are old; no
    > suite was run for this preparation.


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

  > **Prep B022 (9cb8782; design; shared dependency):** `workshop/jury.gd::refresh` now uses a neutral
  > global target; `_assess_target_eval` judges the premise separately. Target-scaled updates need
  > reversible ownership, not another additive effect. Coordinate with Q3 and
  > `ui/workshop_comparison.gd::describe`; numbers remain open.


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

  > **Prep B023 (9cb8782; design):** `sim/evil.gd::breath_target` now enforces same-block contact at
  > possible day phases; silence is applied later by `sim/world.gd::begin_meeting`. Choose the
  > knowledge/card policy first. Evening-only intersections or meeting locations misrepresent possible
  > action times.

- **Starting secret-count card.** Generate a public setup card stating how many secrets
  are in town. Decide whether the count means modifier types, holders (Lovers count
  twice), or includes ordinary personal secrets; do not expose assignments. (61251/25923)
  [decided: card; count definition open]

  > **Prep B024 (9cb8782; design):** Setup distinguishes `_assign_secret_mod` from `_assign_secrets` in
  > `sim/world.gd`; generate a receipt in `game/game.gd::new_case` only after defining type versus holder
  > versus ordinary-secret count. Do not expose assignments.

- **One evaluation path for generic and structured cases.** In 25923, vigil sighting
  #86 + death #87 (Nisha at Merrin's murder block that night) had no template, while
  the generic support sum capped at 1.0 agreement. `trace_match` is specifically an
  evening trace + evening presence, and faces competing explanations. Add the missing
  night-sighting + murder relationship (the death assertion also needs its location)
  with the broader fit-check work, so recognizing a case cannot make it weaker. [decided]

  > **Prep B025 (9cb8782; partial; consolidate):** Shared consequences live in
  > `workshop/shared_ledger.gd::evaluate`; native `sim/argue.gd::assertions` still has a location-poor
  > death assertion and separate link routes. Align evidence-family semantics across adapters, templates,
  > and previews rather than raising generic sums.

- **Independent support versus repetition.** The ledger currently takes the strongest
  justification for a conclusion. Preserve duplicate-evidence suppression, but let
  separate nights and independent sources build a cumulative case. Tie this to the
  repeated-trace item below and the belief/action split, rather than raising every
  suspicion increment. (61251) [decided] 54875: repeated presentations of a growing case
  scored lower each time; see the novelty bug in section 1.

  > **Prep B026 (9cb8782; open; duplicate workstream):** `sim/mind.gd::_final_weight` selects strongest
  > justification; shared facts deduplicate origins. Group with independent instances/repeated traces.
  > New nights must accumulate appropriately, while repeating one origin must not add another posterior
  > contribution.

- **Template generalization** (now part of "Cases instead of proofs" in section 4: one fit check per evidence type;
  originally: one translation table per role, so pair elimination
  etc. work for any gift that makes the same kind of statement). (DESIGN, deferred to
  roster expansion) [decided]

  > **Prep B027 (9cb8782; partial architecture):** Shared family semantics exist in
  > `workshop/solver.gd::report_table`; native filing still uses `sim/argue.gd::check`. Extend adapters,
  > fit checks, and link surfaces together instead of adding isolated role templates.

- **From playtest 54875: case-workshop links that were missing or misread.** [decided]

  > **Prep B028 (9cb8782; mixed coverage):** The children span link recognition, shared likelihoods, and
  > UI expressiveness. Check each separately: a successful posterior does not prove
  > `game/game.gd::find_links` can file the desired explanation.

  - **A reading against an alibi is filed as "Contradicted home alibi"** with the
    reading as the trusted observation, so its only explanation is "the alibi is false".
    A gift reading is a claim and should be the doubtable side, or the card should offer
    both explanations ("Dorian's alibi is false" / "Constance's report is false"). My own
    vigil really is an observation; Constance's Night Watch report isn't.

    > **Prep B029 (9cb8782; open in part):** `sim/argue.gd::_match_pair` builds out-versus-home
    > alternatives through `_place_expls`. Keep player observations distinct from NPC reports; test
    > offered explanations as well as shared report doubt, without upgrading hearsay to observation.

  - **A watcher's report against the player's vigil of the same block and night**
    (Constance: "I watched the Market and saw Jory"; my vigil saw only Constance and
    Isolde) had no link. A false gift report is the strongest kind of lie.

    > **Prep B030 (9cb8782; candidate to narrow):** `sim/argue.gd::_match_pair` now has vigil/watch and
    > omission branches. Verify the exact named-set mismatch, including a watcher present in the vigil;
    > native choices and shared Night Watch content must agree.

  - **One person's two accounts of the same night** (Constance told me "I saw Isolde",
    then told the town "I saw Jory" for night 1) should be linkable as a conflict.

    > **Prep B031 (9cb8782; open):** `sim/argue.gd::_match_pair` detects Seer/Hearthwitch flips, not
    > general Night Watch named-set changes. Preserve full contents, original source, and observed night;
    > two disclosures of one report are not automatically independent readings.

  - **"Killed by the demon, so good" should give credence to the victim's alibi** as
    grounds for challenging a reading ("it's likelier Constance is lying than that
    Dorian has a secret night walk"): modest weight, not zero, and never proof. (Dorian
    really was the Sleepwalker here, so the doubt was right by luck.)

    > **Prep B032 (9cb8782; partial):** Finite death evidence is adapted by
    > `workshop/live_assessment.gd::activity_card`; native honesty/alibi reasoning remains separate.
    > Consolidate victim-information policy, testing Sleepwalker and poison alternatives. Death must not
    > prove a home alibi.

  - **Surveyor answers** should let the player pick the evil blocks and a suspect on each
    (it can't express "the Square via Constance, Chapel Hill via Edda"). A block whose
    residents are all demon victims drops out of the count: with the Market clean, Jory's
    "2 blocks" plus Constance and Edda cleared the Docks, which the evaluator did work out
    (Hollis and Lian −0.446) but couldn't say.

    > **Prep B033 (9cb8782; partial):** `workshop/solver.gd::report_table` accepts blocks/people and
    > `ui/case_workshop_canvas.gd::_refresh_case` has Surveyor controls. Test the exact
    > two-block/two-person expression and cleared-block explanation before changing the answer schema.

  - **The totem has no adapter:** it should read "a Revenant is in play and lives on
    Chapel Hill", which crossed with an Archivist pair names one person.

    > **Prep B034 (9cb8782; candidate to close):** `workshop/live_assessment.gd::activity_card` now
    > adapts totems; `tools/test_workshop_card_adapters.gd::_totem` checks public home/material
    > candidates and shared presentation. This is conditional role consistency, not hidden-owner
    > revelation.

  - **A claimed day gift but seen out at night** (Greta claimed Dowser after Isolde saw
    her on the Docks) is a reasonable suspicion pattern.

    > **Prep B035 (9cb8782; partial; balance dependency):** `workshop/live_activity.gd::_profile_paths`
    > already gives non-walking claims an ordinary/secret mixture. Surface existing support with
    > walking-claim explanations; coordinate strength changes with the sighting balance pass, not a
    > second penalty.

- **From playtest 54875: case-workshop feedback.** [decided]

  > **Prep B036 (9cb8782; partial UI):** `ui/live_case_workshop.gd::_sync` already labels evaluator mode;
  > `_support_details`/`_preview_effectiveness` and `ui/workshop_comparison.gd::describe` expose
  > diagnostics. Check each symptom with a small canvas; assumption origin and collateral warnings are
  > separate from the qualitative-preview proposal.

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

  > **Prep B037 (9cb8782; open):** Trace `workshop/jury.gd::_consequences_eval` through
  > `sim/mind.gd::action_susp`/`_vote_impl`. Belief, crowd/player pressure, preferred block, and voting
  > threshold differ. Pair agreement/vote assertions and explanations. Q3 is deferred, not disabled: the
  > legacy vote/nomination formulas (including the player vote/accuse terms) run today; only the
  > shared execution-priority input sits at weight zero until the design pass. (Claude, after merge)

  - **"Accept" is wording, not belief.** Stance comes from agreement (>= 0.6); the belief
    change is agreement × quality × 0.6 at a meeting × novelty, then trust, so agreement
    1.0 became +0.08 to +0.13. A single bare public accusation moved suspicion +0.11.
    An accepted "X is evil" should set a floor (or a vote term) while its support stands.

    > **Prep B038 (9cb8782; partial):** `workshop/shared_ledger.gd::response` and `evaluate` separate
    > scoped reply from global consequences. Define what “accept” promises and align wording. Applying
    > the scoped vector as well as the owned global vector would double-count evidence.

  - **When they agree and still vote no, they say why** ("I believe you, but not enough
    to hang her"; "Edda first"). Ties to Vote resistance feedback below.

    > **Prep B039 (9cb8782; open):** `sim/mind.gd::_vote_impl` records score parts and margins. Generate
    > explanations from those perceived causes rather than a new calculation; selective spoken reasons
    > versus silent votes belongs to the common meeting-talk decision.

  - **"I'm more suspicious of Edda" is relative** (top suspect more than 0.05 above), so
    it was said by people whose suspicion of Edda was 0.34 and who then wouldn't vote for
    Edda either. Say it only when the preference would actually change a vote.

    > **Prep B040 (9cb8782; open; Q3 batch):** `sim/mind.gd::ranked_suspects`, `_good_nomination_impl`,
    > and `_vote_impl` separate ranking from an absolute voting bar. Test close second choices and a
    > strongly preferred block; relative wording is not a promise to spare.

  - **Urgency.** The vote bar drops only through paranoia (`0.07 × dead × (1 − 0.6 ×
    composure)`), so high-Composure voters barely moved from Day 2 to Day 6 (Lian 0.44 →
    0.36). Add an urgency term from the alive count and days left that Composure doesn't
    cancel, tuned with the existing paranoia/urgency caution against late random hangings.

    > **Prep B041 (9cb8782; design):** Day/paranoia and Confidence already affect
    > `sim/mind.gd::_vote_impl`'s bar. Set urgency scope alongside rank-aware execution/Martyr urgency;
    > lower bars can also approve moderately supported wrong nominations.

- **Replies must match beliefs.** (Claude, Oct 25; 54875 replay) Jory and Agnes accept
  case #85 numerically (their suspicion moves as if convinced) while their replies say
  they couldn't follow it. What an NPC says has to come from the same computation as what
  it believes (LEGACY_MIGRATION lesson 6). The scoped reply and the belief refresh are
  separate jury runs with different attention; decide which one owns the stance wording,
  or derive the reply's stance from the refresh's movement on the premise target.
  Overlaps "Accept is wording, not belief" above and reply-only Insight budgeting below.
  Fix before the next playtest is used to judge persuasion. [decided: direction; approach open]

- **From playtest 54875: Insight and Confidence barely shaped reactions.** Every good
  listener's agreement was 0.92–1.0. [open]

  > **Prep B042 (9cb8782; partial; migration boundary):** `workshop/reasoner.gd::_prepare` still limits
  > evidence used in beliefs; reply-only Insight budgeting is not built. Confidence scaling exists, but
  > conviction protection remains a separate design. Do not restore per-person world searches for varied
  > reactions.

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

  > **Prep B043 (9cb8782; open strategy):** Inspect `sim/evil.gd::review_scapegoat`, `caution`,
  > `teammate_value`, and `sim/mind.gd::_public_claim_decision`. Preserve shadow/public-information
  > boundaries: internal evil stakes may use private intel, but spoken reasoning must not expose it.

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

  > **Prep B044 (9cb8782; partial limits exist):** `sim/world.gd::_pre_pair` weights
  > `sim/social.gd::news_bonus`; `_make_pair` already stamps one pairing per NPC/day. Separate
  > visibility, news weighting, and frequency before adding cooldowns; `_post_pair` also restricts
  > partners by location.

- **From playtest 54875: a hidden walker caught out should explain.** Isolde (Lamplighter,
  low Composure) was seen on the kill block on two kill nights, pressed with my sighting,
  and still stonewalled until I guessed "are you the Lamplighter?". Once a walker has been
  caught on a kill block, the reveal cost should collapse: they have nothing left to hide
  and everything to explain. The defence moves do this at the meeting; a private press
  with a sighting card should trigger it too. Ties to Rebuttals and excuses. [decided]

  > **Prep B045 (9cb8782; partial; duplicate rebuttals):** Admission exists in
  > `sim/mind.gd::_answer_gift_impl`; `defend_self` and disclosure gates control explanation choice.
  > Group false-alibi/hidden-walker work so one incident produces one hearing, not stacked innocence
  > bonuses.

- **From playtest 54875: the Gravedigger in a reluctant town.** With no executions the
  Gravedigger has nothing to read; Hollis held a top-value gift and no information all
  game. A Gravedigger who knows this could be the one pushing the town to hang someone
  ("so I can tell you what they were"), which also gives a cautious town a reason to act.
  [open]

  > **Prep B046 (9cb8782; design):** `sim/mind.gd::_good_nomination_impl`/`nomination_case` consume
  > suspicion and reasons; `sim/world.gd::_receive_info` generates Gravedigger reports.
  > Information-seeking execution needs an explicit purpose, not a false Demon assertion or guaranteed
  > true-role knowledge.

- **From playtest 54875: evil frames should cohere.** Constance's private night-1 story
  ("I saw Isolde", from the alibi-hiding window sighting) and her public Night Watch
  reading ("I saw Jory") came from separate generators and conflicted; that crack is
  what unravelled her. Decide whether it's a deliberate crack or should come from one
  plan per scapegoat per night that every bluff draws from. Likewise a side frame
  through one gift (an Archivist or Rumormonger pair) shouldn't be undercut by invented
  night walks aimed at someone else. (user, Oct 23) [open]

  > **Prep B047 (9cb8782; partial; focused regression):** `sim/evil.gd::make_plan`, `make_fake_info`, and
  > `fake_night_sighting` store cover; `sim/mind.gd::answer_night` now prioritizes claimed duties. Check
  > private/public versions of one night and changing scapegoats. Never rewrite an old report to fit a
  > new frame.

- **Case 44814: asking about an already disclosed gift.** Currently "are you the X?"
  repeats confirmation and consumes a question, without requesting withheld results;
  a profile role guess is private bookkeeping only. Decide whether the dialogue
  question should offer a useful route to the withheld readings or clearer feedback
  about asking for them. No automatic extra disclosure from recording a guess. [open]

  > **Prep B048 (9cb8782; partial):** `sim/social.gd::answer_is_role` repeats known roles without
  > readings; `game/game.gd::_talk_command` routes ordinary gift/info asks elsewhere. Join carefully so
  > confirmation can offer disclosed information without granting a new disclosure tier or repeat credit.

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

  > **Prep B049 (9cb8782; partial):** `sim/mind.gd::_answer_gift_impl` already preserves public floors
  > and offers remaining readings. Reproduce the exact withheld/shared report with privacy/gossip gates;
  > knowing a role is not automatic access to all reports.

- **Follow-up after a false alibi is established.** The initial good-NPC response can
  concede "Fine, I was out. Doesn't mean I was doing anything wrong." Later add
  pressure checks and possible forced revelation of the hidden gift/secret, with
  proper handling of genuine home accounts, unremembered outings and evil cover
  behavior. The pressure/revelation extension is deferred. (Oct 23, case 44814.)
  [decided; mechanics open]

  > **Prep B050 (9cb8782; open; consolidate):** Use `sim/mind.gd::press`, `answer_night`, and
  > `defend_self`. Track one challenged incident, then choose admission, explanation, or refusal. Private
  > and meeting follow-up should share that transition while retaining the false statement.

- **Reading challenges and next supported gifts.** Track alibi/sighting intent,
  multi-person vigil receipts, Surveyor count generation/skepticism, preview clarity,
  and Clerk/Archivist/Seer integration in the
  reference plan (now summarised in [docs/CASE_WORKSHOP_FINDINGS.md](docs/CASE_WORKSHOP_FINDINGS.md)). Misled and Lying modifiers, Surveyor skepticism, alibi support, clearer feedback and
  the three role adapters are implemented. Further movement, trace, protection and role
  adapters are tracked in the expansion checkpoints (same findings doc). The interpreter is being rebuilt per [docs/CASE_REASONING.md](docs/CASE_REASONING.md);
  dated outcomes, nested relays and conversion histories remain gated. [watch; broader adapters open]

  > **Prep B051 (9cb8782; partial):** `workshop/reading_challenges.gd` and
  > `workshop/canvas_model.gd::add_modifier` provide scoped challenges; relay restrictions remain in UI.
  > Extend evidence-family support with adapter/solver checks rather than bypassing unsupported gifts at
  > submission.

- **A genuinely neutral opinion.** Add "I'm not sure what to think" between trust
  and suspicion for both good and evil NPCs. `answer_opinion` has several suspicion
  bands, but its middle replies still choose between "seems all right" and
  "something's off"; distinguish uncertainty from a refusal or a veiled accusation.
  Do not create incriminating opinion evidence solely from neutrality.
  (Oct 21) [decided; boundaries/wording open]

  > **Prep B052 (9cb8782; open):** `sim/mind.gd::answer_opinion` currently chooses reassuring/suspicious
  > wording after willingness gates. Add a neutral perceived state; test uncertainty and middle suspicion
  > without exposing hidden alignment or turning an opinion into evidence.

- **Explain distrust of the player.** Good and evil NPCs with low player trust should
  be able to say so and, where remembered, cite the reasons: misguided executions,
  accusations, nominations, votes or broken confidences/promises. Use their known
  history and beliefs, with the same presentation options for evil; a refusal alone
  should not be the only signal. Coordinate with apologies and vote-resistance
  feedback. (Oct 21) [decided; delivery/frequency open]

  > **Prep B053 (9cb8782; open feedback):** `sim/mind.gd::_vote_impl`, `word_factor`, and `card_weight`
  > already use player trust. Surface relevant resistance through dialogue; distinguish distrust of
  > testimony from dislike of execution. Explaining an existing penalty should not create a new one.

- **Medium visits only Demon victims.** Restrict the gift's eligible dead to people
  killed by the Demon, and update role descriptions, dialogue, target selection
  and real/fake report consistency. Current `_medium_choice` considers every
  unvisited dead person; a same-day tie favors Demon victims, so the requested
  restriction is not implemented. Coordinate with the existing director-driven
  visit proposal and keep misleading results possible. (Oct 21) [decided]

  > **Prep B054 (9cb8782; open):** `sim/world.gd::_medium_choice` considers all unvisited dead, sorted by
  > recency with same-day Demon-victim preference. Apply the eligibility decision to fake Medium paths
  > too; test executed dead, equal-day ordering, and exhausted eligible hearths.

- **Revenant revelation and reversible town uncertainty.** A publicly recognized
  haunting should establish the executed Revenant as evil and add a small global
  suspicion/uncertainty response to "anyone could be possessed." Current curse
  effects add +0.15 only toward living yes-voters; they are not global, and
  `free_turned` does not explicitly retire that curse ledger entry. Decide how
  global anxiety combines with the justified voter-specific suspicion; it does
  not change who can actually be possessed. Destroying the totem should reverse
  the added haunting uncertainty without undoing independent evidence, and the
  possessed person's identity must stay hidden. (Oct 21) [decided; amounts open]

  > **Prep B055 (9cb8782; updated after merge `0cd2181`):** Curse epochs are now on main
  > (`workshop/chronology.gd`; `workshop/live_assessment.gd` handles cursed games): public eligible
  > voters and hypothetical epochs, never the hidden turnee. Check this entry against that work rather
  > than building a second version.

- **Secret awareness and bluffing.** Lovers' existing confessions now carry a usable
  secret type and can explain night movement. The same card/interpretation format can
  represent a reported Marked secret, but no spontaneous Marked confession is added:
  decide whether holders know they're Marked, how one asks about it, and how evil can
  claim it too. Currently only Lovers have an explicit modifier-confession path. Keep
  these as attributed claims, not hard alignment confirmations. (61251/25923) [open]

  > **Prep B056 (9cb8782; partial):** `sim/world.gd::_assign_secret_mod` now excludes walking gifts from
  > Sleepwalker/Lovers; ordinary personal secrets remain possible. Keep awareness, actual errands, and
  > claimed excuses separate in `sim/mind.gd::answer_night` and evil cover.

- **Nisha's reticence.** 25923 used Gossip 0.11, Privacy 0.60, Trust 0.38. The shared
  gossip rule returns zero below Gossip 0.20 unless pressure reaches 0.50; her pressure
  stayed around 0–0.21. This explains repeated refusals without an evil-only penalty.
  Consider a softer minimum-information policy separately from the bug fixes. [watch]
  54875: Hollis (Gossip 0.01) answered "It's not my place to say" about Constance right
  after agreeing with the case against her in public, and Lian (0.18) the same. A stance
  already given in public should be exempt from the gate. [decided for that exemption]

  > **Prep B057 (9cb8782; open):** `sim/mind.gd::answer_opinion` checks low Gossip/pressure before a
  > public-stance exception. Decide whether repeating public opinions bypasses reticence; do not force
  > new private information or count repetitions as evidence.

- **Believable public revisions.** Let the player withdraw or revise an earlier case,
  while NPCs may retain reasons they still believe. In 25923 the final Nisha nomination
  cited the player's earlier argument after the player had adopted a different world.
  Private guesses must remain private. [open] Related: a revised case must not score
  below the version it replaces (54875, section 1).

  > **Prep B058 (9cb8782; partial):** `game/workshop_canvas.gd::file` and
  > `game/game.gd::workshop_retract` support historical revision/withdrawal. NPC stance changes still
  > need reasons/cadence; retract endorsement while preserving underlying learned facts and private
  > guesses.

- **Quiet-night evidence.** Sightings outside an actual murder scene currently get
  only 0.12 of normal weight, including failed attacks. Support a player-argued link
  between protection, suspected attack and movement without exposing hidden attacks.
  In 61251 the successful Fenwick ward suppressed the apparent value of the sightings.
  [open] See the "Protection + quiet night + sighting" template gap (54875) for the
  concrete chain.

  > **Prep B059 (9cb8782; partial):** Quiet/protection support exists in
  > `workshop/live_assessment.gd::activity_card` and `workshop/live_protection.gd::assess`; native
  > `sim/world.gd::_quiet_night` grants credit too. Keep one owner and distinguish no death from a proven
  > blocked attack; save receipts are separate work.

- **Vote resistance feedback.** Distinguish disbelief from execution priority and
  distrust of the player. In 25923 the -0.4 preference for Lian already on the block
  stopped several good NPCs voting for Nisha despite substantial suspicion. Revisit
  with meeting/vote talk; do not turn every plausible alternative into inaction. [open]
  54875 is the clearest case yet; see "agreement has to reach the vote" above.

  > **Prep B060 (9cb8782; open; duplicate feedback):** Reuse `sim/mind.gd::_vote_impl`'s structured
  > reasons. Consolidate agree-but-no, distrust, and “what would change their mind”; check friendship,
  > contradictory readings, and preferred-block refusals without introducing a second resistance score.

- **Evil vote stakes beyond the Demon.** Cover can no longer cause an evil NPC to
  nominate/vote for the Demon. The existing pivot heuristic still considers only
  votes already cast for other nominees. Future tactical bussing (including any
  deliberate Scion succession) needs remaining-voter estimates and a team-benefit
  policy; preserve ordinary minion bussing meanwhile. (25923) [open]

  > **Prep B061 (9cb8782; design):** `sim/mind.gd::_vote_impl` specially protects the actual Demon;
  > `sim/evil.gd::teammate_value`/`public_hostility` provide other stakes. Specify cover-versus-teammate
  > policy before tuning; do not leak strategy truth into shadow beliefs.

- **Outcome attribution.** Separate identifying evil alignment, identifying an exact
  minion gift, and making a useful execution. 61251 correctly identified Jory as evil
  but guessed Breathstealer; executing the Revenant turned the last good NPC. [open]

  > **Prep B062 (9cb8782; partial metrics):** `game/case_metrics.gd::summarize` separates
  > identification/persuasion/outcomes. Audit event-time role/alignment for curse/Scion: reading final
  > state can misattribute earlier executions. Add focused transition cases in `tools/test_outcomes.gd`
  > before aggregate scores.

- **From playtest 61251** (an evil team the player had identified won anyway). [decided]

  > **Prep B063 (9cb8782; historical context):** Keep the 61251 observations, but check the children
  > against current shared ownership and native voting separately. They overlap later social-tuning and
  > evidence-fit work; do not implement them twice.

  - **A proven lie should hurt an info claimant's credibility hard.** Constance (the
    Breathstealer bluffing Seer) was caught in an off-route lie on day 2, and listeners
    still credited her at about 90% (from 94%). Her fake "yes" readings then hanged Lian
    (+3.1 suspicion across the town) and Edda (+2.6), and a fake "no" cleared the demon.
    A proven whereabouts lie by a public info claimant should cut their readings to
    around 50% credibility. This turns "lie severity" around: the lie itself was minor,
    but it says the claimant's readings can't be trusted.

    > **Prep B064 (9cb8782; partial; coefficients undecided):** `sim/mind.gd::_honesty` reweights
    > ledgers; `sim/argue.gd::effects_of` separates doubt/suspicion. Report lies, whereabouts lies, and
    > poison have different scopes. Test downstream old reports, not only immediate increments.

  - **A Seer's record.** Each "yes" pair that's hanged and shown good (by the
    Gravedigger, the Martyr, or a public clear) should discount that Seer's later
    readings, not just add red-herring talk. In 61251, Lian was shown to be the Warden,
    but only the Gravedigger updated (−0.4), and he was killed that night.

    > **Prep B065 (9cb8782; partial):** `sim/mind.gd::_honesty` and `workshop/shared_ledger.gd::evaluate`
    > already re-evaluate evidence. Narrative track records/trust need event identities; semantic
    > correctness includes Red Herring/Marked registration, not just actual Demon membership.

  - **Repeated trace matches add up.** Three kill nights in a row had a trace on the
    Docks with Greta there each time. Each was judged alone ("more likely someone else
    on the Docks"), at about 0.3 agreement. The same suspect matching across several
    nights should compound. This is a natural first test case for the theory and fit
    checks (section 4), and the same shape as the Breathstealer-by-presence pattern.

    > **Prep B066 (9cb8782; open; aggregation duplicate):** Group with independent instances and
    > generic/template parity. `sim/mind.gd::_final_weight` is max-based; trace facts need stable
    > crime/night/source identities in `sim/argue.gd::assertions` and shared adaptation. Retellings are
    > not new matches.

  - **The player's voice in votes is small at ordinary trust.** At trust 0.3–0.5, "the
    player accuses" added only 0.05–0.14 to votes, while non-template cases got 0.19
    agreement. This is the execution-priority idea (section 4) applied to the player's
    own nominations.

    > **Prep B067 (9cb8782; design; Q3 audit):** Player terms are explicit in `sim/mind.gd::_vote_impl`;
    > `execution_priority_contribution` is a separate zero-weight hook. Measure after premise design with
    > wrong-accusation controls. Action modifiers are not evidence likelihoods.

  - **Not the cause:** a failed nomination costs trust only with the nominee (−0.15).
    There's no town-wide penalty, so the early lark nomination of Bart didn't cascade.
    Worth confirming in a conservative playthrough.

    > **Prep B068 (9cb8782; historical finding):** Retain this negative diagnosis, not a task to remove
    > failed-nomination consequences. Use `_vote_impl`'s score parts to distinguish nominator trust,
    > nominee trust, crowd pressure, and evidence in any new reproduction.

- **Offering protection eases fear.** Someone you've offered your ward or a vigil (and
  kept your word to) should be less afraid to say what they are. (96773) [decided]

  > **Prep B069 (9cb8782; open; promise overlap):** `game/game.gd::_offer_command`/`_settle_offers` track
  > promises. Base fear relief on what the NPC heard, keyed once per promise; an offer neither spends a
  > ward nor proves a successful save.

- **Backing a strong case builds trust.** Nominating or voting for someone the town
  strongly suspects (and who turns out evil, or is widely believed so) earns a little
  trust from the NPCs who agree. It's what makes throwing a teammate under the bus pay
  for evil, and it rewards good NPCs who stick their necks out. (Oct 19) [decided]

  > **Prep B070 (9cb8782; design):** `sim/mind.gd::hear_accusation`/`_vote_impl` are social entry points.
  > Define recipient and accepted-evidence credit; prevent rapport farming by repeated cases and never
  > use the simulator's true verdict to decide NPC gratitude.

- **The fearful ask for protection.** NPCs afraid their gift makes them a target appeal
  to the Demonologist (a ward, a vigil) and/or the Warden for protection, instead of
  only clamming up. Ties into offers easing fear. (Oct 19) [decided]

  > **Prep B071 (9cb8782; open):** Add bounded requests through meeting/approach dialogue, reusing
  > `game/game.gd::_offer_command` settlement. Keep requests based on perceived danger; do not reveal
  > secret targets or real gifts just to make the request available.

- **More talk in town, especially in bigger towns.** 96773 (10 townsfolk, 4 days): 7
  conversations, 7 shares; three conversations passed nothing on, and one pair swapped
  the same sighting back and forth. Scale conversations with population, let each pass
  on the one or two most newsworthy things the other hasn't heard, never echo back what
  you were just told. Check with bot runs. [decided]

  > **Prep B072 (9cb8782; design; existing cap):** `sim/world.gd::_pre_pair`, `_post_pair`, `_make_pair`,
  > and `sim/social.gd::converse` already limit pairings and exchange one item/direction. Separate more
  > opportunities from more items; check public visibility as a distinct constraint.

- **Evil backs into a bluff.** Like the scapegoat switch: an evil NPC that hasn't
  claimed yet can change its planned bluff when another gift would serve better, if no
  one has claimed that gift and it would build a frame or deflect suspicion. Example: the
  Poisoner planned to bluff Seer but is seen out at night, and nobody has claimed Night
  Watch, so it claims Night Watch. This opens the door to double claims (the real Night
  Watch may just be quiet), which need their own logic: a classic of the genre, needed
  eventually. Once double claims are handled, fake Mediums (and evil generally) can also
  make bolder lies: fake readings in gifts the dead never claimed. (Oct 19) [decided]

  > **Prep B073 (9cb8782; open):** `sim/evil.gd::make_plan` fixes bluff assignments; `ensure_scapegoat`
  > can change frames. Reactive bluffing requires persistent claims compatible with earlier reports.
  > Coordinate with role requests/coherent frames; never overwrite disclosed history.

- **Storyteller-driven Medium visits.** Today the Medium visits the most recent dead it
  hasn't visited (demon victims first). Eventually: "I was called to Hollis's home to
  commune with his spirit", chosen by a director. Limit the future director's pool
  to Demon victims if the Oct 21 eligibility change above is implemented.
  (Oct 19; dependency clarified Oct 21) [open]

  > **Prep B074 (9cb8782; design):** `sim/world.gd::_medium_choice` is mechanical recent-death selection,
  > not a director. Resolve Demon-victims-only eligibility first, then define selection policy separately
  > from receipt validity and fake Medium behavior.

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

  > **Prep B075 (9cb8782; partial):** `workshop/live_assessment.gd::medium_card` preserves supported
  > originals; native `sim/mind.gd::_info_effects`/social consequences differ. Test faithful relays as
  > one origin, then independently test blame/trust when either source is doubted.

- **Medium challenge attribution and nested relays.** Add an explicit choice between
  questioning the Medium's transmission and the dead source's original information.
  Until that exists, cause modifiers on relay cards are visibly unavailable; they
  must not silently accuse the wrong speaker. Relays of another Medium's relay and
  relayed opinions still use native fallback. (Oct 23 expansion.) [open]

  > **Prep B076 (9cb8782; open):** `workshop/live_assessment.gd::medium_card` handles bounded originals;
  > `workshop/canvas_model.gd::add_modifier`/UI restrict relay challenges. Nested relays need dated
  > source chains, cycle checks, deduplication, and attribution before relaxing gates.

- **Martyr promise versus later hanging.** The new evaluator handles choice reports,
  explicit evil-registration outcome reports (including Marked), and observed
  substitutions. Combining an earlier choice with a later execution remains on
  explicit fallback until an outcome-time health assumption/receipt can be evaluated
  separately from health at the choice. Do not infer that both times were healthy
  from the earlier promise alone. (Oct 23 expansion.) [decided; adapter open]

  > **Prep B077 (9cb8782; open; time boundary):** `workshop/live_protection.gd::assess` and
  > `sim/world.gd::_martyr_choice` concern different moments. Later poison/execution cannot prove an
  > earlier promise false without dated support. The merged mechanics work (`0cd2181`) added dated
  > statement times and Warden guard receipts; build on those rather than duplicating them.

- **NPCs push back on nominations their own information contradicts** (a player-led
  nomination of the true Seer passed 7/8). (DESIGN playtests) [open]

  > **Prep B078 (9cb8782; open):** `sim/mind.gd::nomination_case`/`_good_nomination_impl` have
  > own-information context; `game/game.gd::_nomination_command` handles nominations. Coordinate with
  > reactive meetings for one timely contradiction, without forced disclosure or an extra belief bonus
  > for speaking.

- **Lie severity:** a false gift report weighs more than a whereabouts lie, unless the
  lie puts them near the crime. NPCs who accept a lie but won't hang should say so.
  (DESIGN) [open]

  > **Prep B079 (9cb8782; design; duplicate tuning):** Compare equal hearing weights in
  > `sim/argue.gd::effects_of`, `sim/mind.gd::_honesty`, and `night_sighting_scale`. Coefficients affect
  > different quantities; combine with misled-versus-lie and rebuttal wording, not an isolated severity
  > multiplier.

- **Evil reads as evil:** evil casting aspersions with no information stands out; give
  good NPCs reasons (grudges, secrets) or make evil hold back. (playtest 30294) Largely
  addressed by the shadow self (evil's replies now differ from the good crowd's about
  twice as often as good's own disagreements, down from about five times); revisit
  after playtests. [watch]

  > **Prep B080 (9cb8782; watch):** `sim/mind.gd::shadow_run` and `sim/evil.gd::review_scapegoat`
  > preserve cover/public-information boundaries. The quoted rates are historical, not fresh
  > measurements. Improve believable reason variety without exposing actual evil knowledge to the shadow.


### Exploration
- **Role hints from workplaces and haunts.** Occasionally reward searching an NPC's
  workplace or known haunt with an attributed hint about their claimed/possible
  gift. Coordinate with the evidence/role-hint system; searches should not become
  guaranteed hidden-role verification. (Oct 21) [open; frequency/content open]

  > **Prep B081 (9cb8782; design):** Search routing is `game/game.gd::_search`. Define eligible
  > workplace/haunt locations, attribution, and frequency before adding hints; a clue must not become
  > guaranteed true-role verification or read hidden roles directly into player knowledge.

- **Occasional free arrival search.** A balancing option to sometimes grant a free
  ordinary search when moving to a new location. Exclude evidence searches; define
  the eligible search types, chance and per-location/phase limits so revisiting
  cannot farm free actions. (Oct 21) [knob]

  > **Prep B082 (9cb8782; knob):** `game/game.gd::_search` spends phase actions. Define ordinary versus
  > evidence searches and an arrival/phase receipt first; revisiting must not reset free-search
  > eligibility. Start with action-budget checks rather than broad balance runs.


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

  > **Prep B083 (9cb8782; balance dependency):** Rates/routes live in
  > `workshop/live_activity.gd::_profile_paths`/`_paths`, keyed through `movement_inputs`. Group vigils,
  > detours, and Lamplighter noise. Establish behavioral controls first. Demon detours are on main
  > (`DEMON_DETOUR` = 0.05 in `live_activity.gd`); don't import canceled channel machinery.

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

  > **Prep B084 (9cb8782; measurement trap):** `sim/evil.gd::make_fake_info` stamps fabricated entries
  > `true=false` even if content happens to be correct. Measure semantic correctness per role/world,
  > including registration rules, not that flag. Then change `workshop/solver.gd::report_table` using
  > measured rates and cache/parity checks.

- **Unlimited Vigil strength.** (DESIGN open question) [watch] 54875: a kept vigil on the
  first kill block caught both walkers there on night 1, then again on night 2; that's a
  two-person demon shortlist on night 1, near a free Seer reading. Options discussed
  (Oct 23), none chosen:

  > **Prep B085 (9cb8782; design):** `game/game.gd::_night_command`/`_resolve_night` control vigils;
  > `sim/world.gd::_night_sightings` supplies movement. Choose cost/yield before changing both
  > observations and likelihoods. Check action accounting, empty watches, and victim exclusion before
  > matched balance comparisons.

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

  > **Prep B086 (9cb8782; watch):** `sim/world.gd::_night_movement` and
  > `workshop/live_activity.gd::_profile_paths` give Lamplighter all-block routes. Trace contamination is
  > not independent corroboration. Coordinate provenance and innocent explanations before reducing
  > visibility or increasing suspicion.

- **Situational credence modifiers** still to settle: early disclosure, quiet night
  as a credence boost, admission against interest, consistency over time,
  role-specific confirmations. (DESIGN) [open]

  > **Prep B087 (9cb8782; design):** `sim/mind.gd::reliability`, `_honesty`, and `_night_factor` differ
  > from relationship hearing weight; shared validity is in `workshop/solver.gd::report_table`. Specify
  > observable triggers/lifetimes and check duplicate disclosure/relay credit before adding modifiers.

- **Offer trust** (+0.03 offer, +0.06 kept, -0.15 broken): first guesses, tune from
  play. [watch]

  > **Prep B088 (9cb8782; watch):** Audit `game/game.gd::_offer_command`/`_settle_offers` against
  > `TUNING.md`. Offered, kept, and successful protection are distinct; broken promises, secrecy losses,
  > and trust caps can dominate a small gain.


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

  > **Prep B089 (9cb8782; tentative):** `sim/mind.gd::_target_tier`, `set_trust`, and `press` combine
  > disclosure/rapport inputs. Keep disclosure gates while auditing initialization and fatigue
  > separately. Check new-topic versus repeated intrusive questions; this preparation does not approve
  > retuning values.

- **Evidence can build NPC-to-NPC trust.** Consider a relationship gain when credible
  evidence reduces suspicion, especially a Clerk reading matching the listener's own
  actual role. Oct 21 examples: that listener currently loses 0.30 suspicion toward
  the Clerk; consider adding about +0.20 relationship trust (provisional), and a
  Seer reporting "no" on a good NPC can similarly build the subject's trust in the
  Seer. Base acceptance on the subject/listener's knowledge, not hidden alignment.
  Scale by evidential strength and deduplicate the underlying fact.
  Distinguish apparent innocence/sincerity from confidence in someone's judgment;
  preserve useful voting blocs without rewarding repeated retellings. [tentative]

  > **Prep B090 (9cb8782; tentative):** `sim/social.gd::_deliver` changes bonds;
  > `sim/mind.gd::apply_info`/shared evaluation change beliefs. Any reward needs original-fact/recipient
  > identity. Only the listener's own-role knowledge may establish a Clerk match; hidden roles cannot
  > validate reports for everyone.

- **Diminishing trust changes near extremes.** Consider smaller gains near high trust
  and smaller losses near low trust, retaining a minimum effect and meaningful
  consequences for serious betrayal. Oct 21 knob: keep a normal band of 0.30-0.70;
  soften further losses below 0.30 and further gains above 0.70, while allowing
  recovery toward the middle at normal strength. Exact curve remains open. Review
  permanent grief/confidence caps separately; scaling alone cannot repair them.
  [knob; Oct 21 band specified]

  > **Prep B091 (9cb8782; knob; caps separate):** `sim/mind.gd::set_trust` centralizes changes, but
  > `cap_trust` lowers ceilings and `sim/world.gd::_grief` uses it. A softening curve cannot repair
  > permanent caps. Agree curve and recovery policy before applying changes globally.

- **Fewer trust penalties for presenting evidence.** A balancing option to reserve
  most trust loss for nominations, votes and other direct offenses, rather than
  merely offering evidence. Preserve meaningful consequences for intrusive pressure
  and betraying confidences. Audit presentation/press routing and fatigue so a
  harmless presentation is not accidentally treated as an accusation or demand.
  Coordinate with the Privacy pass and existing supportive presentations.
  (Oct 21) [knob]

  > **Prep B092 (9cb8782; knob):** Trace `game/game.gd::_route_present`/`_talk_command` into
  > `sim/mind.gd::press`/`hear_accusation`. Identify why trust fell before changing magnitude: presenting
  > may also breach confidence or consume patience, which need distinct consequences.

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

  > **Prep B093 (9cb8782; tentative):** `sim/mind.gd::refresh_consensus` owns pressure separately from
  > evidence; `sim/social.gd::_deliver` stores private opinions. FADE/CAP are not second/third voice
  > strengths. Establish source-chain deduplication before treating repeated stories as independent
  > voices.

- **Martyr urgency.** Gradually lower the commitment threshold as days pass, with a
  floor, while retaining candidate preferences and the possibility of refusing when
  everyone looks deeply suspicious. Avoid a gift wasted solely because no ideal
  confidant emerges. Oct 21 specifies that the decline starts on Day 3; decrement
  and floor remain open. Audited `World._martyr_choice` still requires 0.62 on
  every day, so this has not been implemented. [tentative; Day-3 start specified]

  > **Prep B094 (9cb8782; tentative; confirmed gap):** `sim/world.gd::_martyr_choice` still uses fixed
  > 0.62. Day-3 start is specified, decrement/floor remain open. Check good candidates, all-suspicious
  > candidates, and late refusal; coordinate promise-time versus execution-time evidence.

- **Demon victims' earlier information.** Strengthen belief that a Demon victim was
  reporting sincerely without automatically trusting every reading's accuracy.
  Current code clears the victim and doubles role-claim weight on recomputation,
  but does not directly restore source honesty or reweight old readings because of
  the death. Keep sincerity, claimed role, and night-specific misdirection distinct;
  base changes on listener knowledge, not hidden actual roles or poison state.
  [tentative]

  > **Prep B095 (9cb8782; partial; absolute wording stale):** Shared death evidence is finite;
  > `sim/mind.gd::_recompute_beliefs` applies finite role-claim strengthening. Consolidate
  > sincerity/old-report policy with earlier victim-information items. Do not restore “dead means
  > certainly good.”


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

  > **Prep B096 (9cb8782; design):** `sim/mind.gd::adjust`, `_recompute_beliefs`, `reconsider`, and
  > `workshop/reasoner.gd::_prepare` intersect here. Define conviction before a global Confidence change;
  > preserve reinforcement, firsthand knowledge, and exact retraction across native/shared ownership.

- **Town knowledge of friends and rivals.** NPCs should know other people's public
  friendships/rivalries and sometimes disclose them in the same style as haunt
  locations. Separate that knowledge from exact private trust scores and hidden Lover
  status. Track which relationships the player has learned; avoid duplicate reveals.
  Add conversational wording and useful attribution. [decided; sharing rates open]

  > **Prep B097 (9cb8782; open):** `sim/world.gd::_assign_relationships` stores true relationships, not
  > player knowledge. Add attributed learned facts alongside `sim/mind.gd::reveal_trait`/social
  > disclosures; never render private bond scores or hidden Lovers directly from setup arrays.

- **Ward promises should outrank vigil promises.** Increase the relative value of a
  fulfilled ward promise; add substantial plausible-success credit for a kept ward
  followed by a deathless night. Warden/Veteran intervention remains an alternative,
  not a reason to deny player credit. Base credit on the listener's observable facts
  and beliefs, not the hidden attack target or actual blocker; avoid duplicate credit
  for promise, protection, and outcome. Exact amounts and stacking [open; direction decided].

  > **Prep B098 (9cb8782; design):** `game/game.gd::_settle_offers` sees ward/vigil logs;
  > `workshop/live_protection.gd::assess` handles uncertain evidence. Credit observable plausible success
  > once, retaining alternate blockers. Do not read the actual attack target to decide gratitude.

- **Reduce secret-keeping rewards and soften secret breaches.** Review repeated
  nightly gains, first-use and repeated breach losses, and permanent caps together.
  Keep a meaningful betrayal consequence while allowing proportionate recovery;
  coordinate with apologies and confidentiality promises. [decided; values open]

  > **Prep B099 (9cb8782; design):** Audit `sim/mind.gd::end_of_day_trust`/`cap_trust` and
  > `game/game.gd::_break_confidences` together. Resolve recovery with apologies/confidentiality. Give
  > repeated nightly rewards and breaches explicit identities before tuning amounts.

- **Warn about repeated role guessing.** Before the player continues the escalating
  wrong-guess/patience spiral, have the NPC say something like "Clearly you're just
  grasping at straws, and I'm running out of patience." Make the warning communicate
  their patience without revealing whether a particular bluff/guess is true. Keep
  conversation slots, daily fatigue, and the across-days wrong-guess counter distinct.
  [decided; warning cadence open]

  > **Prep B100 (9cb8782; partial):** `sim/social.gd::answer_is_role` already counts wrong guesses and
  > gives a generic repeat response. Add anticipatory patience wording without confirming a guess;
  > distinguish slots/fatigue from this counter and private `game/game.gd::set_guess` guesses.

- **Track incrimination versus a suspected misread explanation?** Evaluate a separate
  representation for "a Seer yes implicates this person, but I favor red herring or
  Marked" rather than collapsing everything into net suspicion. It may be competing
  hypotheses rather than another additive suspicion score. Explain apparent
  incrimination, likely cause, and remaining uncertainty; reweight consistently when
  either hypothesis loses support and avoid double-counting. Use accepted evidence,
  never the actual hidden modifier. [open]

  > **Prep B101 (9cb8782; design):** `workshop/world_domain.gd` and
  > `workshop/jury.gd::_consequences_eval` already represent registered/actual alternatives. Decide which
  > explanation to expose before adding state; a parallel additive incrimination score would duplicate
  > evidence and complicate revisions.

- **Dowser clearing strength.** Evaluate only firing on a positive ping instead of
  producing zero-count group clears. Specify whether "evil" means registered evil
  (including Marked), how poison/Delusional results behave, and when a failed/absent
  ping is observable. Absence must not become the same zero-count clear through a
  known guaranteed trigger. Compare weaker zero clears/less frequent checks before
  choosing the design. [tentative]

  > **Prep B102 (9cb8782; tentative):** Generation is `sim/world.gd::_day_gifts`/`_receive_info`; fitting
  > is `workshop/solver.gd::_report_content`. Define when no ping is observable: a guaranteed trigger
  > with known activation can still produce a zero clear through absence.

- **Make night-sighting rebuttals explicit.** Let NPCs argue "I was seen out, but no
  one died that night" or "the death happened on another block." Night-sighting
  strength already falls to 12% away from an actual murder block/night. Add argument
  support and attributed defence, rather than merely hidden scaling. Avoid clearing
  all movement, double-crediting the same contextual discount, or ignoring thwarted
  attacks and other reasons a walker might be evil. [decided]

  > **Prep B103 (9cb8782; open; duplicate rebuttals):** `sim/mind.gd::night_sighting_scale` discounts
  > native off-kill suspicion; shared movement can exculpate the Demon. Surface context in
  > `defend_self`/replies without applying that discount twice or clearing possible Minions.

- **Accumulate discrete independent instances.** Multiple caught lies, trace matches,
  and independent nights should strengthen a case with diminishing returns. Preserve
  event/night/card identities and source provenance; distinguish independent facts
  from several retellings of one origin. Audit conclusion IDs, strongest-justification
  selection, and justification keys based on source/night/kind. In particular, the
  reproduced generic two-card case can beat its better-supported template because
  they use different agreement routes; align those semantics with the section-4
  cases/evidence-fit work. [decided; aggregation design open]

  > **Prep B104 (9cb8782; open; one aggregation project):** Group independent support, traces, and caught
  > lies. `sim/mind.gd::_final_weight` is max-based; `workshop/shared_ledger.gd::endorsed_facts`
  > deduplicates facts. Compare new night/source, faithful relay, repeat, and withdrawn support as
  > separate acceptance cases.

- **More rebuttals after a caught lie.** Beyond admission or stonewalling, allow
  explaining concealed walking duties, personal secrets, protecting a confidence,
  or other supported motives. Conceding the statement was false need not concede
  evil or make future readings worthless. Give evil plausible access to the same
  excuses, with later corroboration/challenges; do not erase the caught lie itself.
  Extends section 3's rebuttal work. [decided; options open]

  > **Prep B105 (9cb8782; open; duplicate dialogue):** Reuse false-alibi/hidden-walker incident handling
  > in `sim/mind.gd::defend_self`. Innocent-secret and specific Red Herring explanations need established
  > support; plausible wording is not permission to add hidden facts to a listener's case.

- **Compare misled and reading-lie strength.** Review 0.80 reading doubt for misled
  versus 0.50 doubt plus 0.30 suspicion for exposing a reading lie. Compare at equal
  effective weight, with honesty feedback, night scope and self-knowledge included;
  those coefficients affect different quantities and are not probabilities. No new
  coefficient selected. [open]

  > **Prep B106 (9cb8782; design):** Native coefficients are in `sim/argue.gd::effects_of`; shared report
  > validity/source honesty differ. Compare equal hearing weights with
  > `tools/test_argue.gd`/`tools/test_beliefs.gd`. Doubt 0.80 is not simply a probability comparison with
  > 0.50 + 0.30 suspicion.

- **Signal honest observation forgetting.** When Insight/recency memory limits remove
  people from a report, acknowledge incomplete recall ("There were others, but I
  can't place them"). Distinguish memory loss from Gossip refusal, deliberate friend
  omission, bluff constraints, and other concealment. The player-facing explanation
  should not expose the omitted names or make hiding mechanically identifiable.
  [decided; exact presentation open]

  > **Prep B107 (9cb8782; open):** `sim/mind.gd::answer_today`/`answer_night` control recollection;
  > `game/game.gd::add_card` controls receipts. Honest forgetting must be an incomplete account, not a
  > complete negative observation. Check metadata and spoken uncertainty together.


### UI
- **Find Links and Hints inside the Case Workshop.** (user, Oct 25) The case board's
  right-click Find Links and Hints were removed with the old Build case builder: both
  were template helpers that wrote into that panel. Bring the idea back in the Workshop
  as "what connects to this card?" using the shared model (which cards bear on a
  premise, which would merge into a contradiction), not the old template library.
  [decided: direction; design open]
- **Mark circumstantial evidence visually.** (user, Oct 25) Circumstantial or
  vibes-stage case items (co-location with the silenced, demeanour, votes as soft
  evidence, pattern-based support) should look different from hard-logic items:
  readings, sightings and claims the evaluator checks against each possible world. At
  least a different colour on the board, in the case builder and in the preview, so the
  player can tell how a case is made up. [decided]

  > **Prep B108 (9cb8782; open UI):** `game/card_model.gd`, `game/board_model.gd::layout`,
  > `ui/board_view.gd`, and `ui/card_list.gd` share rendering inputs. Define a visible evidence-class
  > marker with source/time detail; circumstantial is not unsupported, and color alone should not
  > communicate the distinction.

- **Limited-use tool warnings.** Clearly warn before spending Ward and other
  limited-use abilities; show remaining uses and that spending one is irreversible.
  Current help and some labels already say "once per case", but the generic
  "Ward someone..." and promise paths do not consistently communicate the limit
  before selection/use. Cover direct targeting and promises; distinguish promising
  a tool from actually consuming it. (Oct 21) [decided; warning presentation open]

  > **Prep B109 (9cb8782; open UI):** `ui/main.gd::_actions_day`/`_offer_picker` expose tools;
  > `game/game.gd::_night_command` spends them. Warn from actual remaining inventory, distinguish
  > offering from spending, and check text commands/canceled menus too.

- **Selected filter rows first.** On the case board, promote rows explicitly selected
  in the person/place filters above unselected rows; e.g. filtering for Agnes,
  Constance and Dorian puts those three first. Preserve predictable order within
  both groups and coordinate with all/any/exclusion and timeline layout.
  (Oct 21) [decided]

  > **Prep B110 (9cb8782; open; layout batch):** `ui/case_state.gd::apply` filters cards;
  > `game/board_model.gd::layout` builds rows. Put selected-first ordering in shared row layout with
  > stable ties and pinned anchors; this is not only a list sort.

- **Hide Unselected.** Add a case-board toggle to hide rows not explicitly selected
  by the active person/place filters. Keep this distinct from hiding evidence cards,
  showing hidden cards, and the currently focused card/profile; define the
  no-selection behavior and retain pinned-card/filter consistency.
  (Oct 21) [decided; edge cases open]

  > **Prep B111 (9cb8782; open; same batch):** Keep hide state in `ui/case_state.gd` and visibility in
  > `game/board_model.gd::layout`. Define empty selection, intersecting filters, and pinned cards on
  > hidden rows; hiding must not remove cards or their links.

- **Long dropdowns in columns.** Once a dropdown exceeds roughly eight options,
  consider multiple columns: at most eight options per column for an uncategorized
  list, or columns grouped by existing categories. Example: the deduction planner's
  "is the <blank>" selector has about twenty options across roughly four categories.
  Prefer meaningful existing groups where available; exact threshold/layout remains
  open. Keep category labels, keyboard navigation, and screen bounds usable.
  (Oct 20) [tentative]

  > **Prep B112 (9cb8782; open UI):** `ui/main.gd::_list_picker`/`_people_picker` share popup
  > construction. Add columns with keyboard focus, screen-edge fitting, and readable labels; check all
  > helper users before changing common dimensions.

- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]

  > **Prep B113 (9cb8782; partial data distinction):** `workshop/live_assessment.gd::activity_card`
  > treats refusal as weak context and home claims separately; `sim/argue.gd::assertions` distinguishes
  > whereabouts. Check `game/board_model.gd::layout` marks before changing mechanics just for visual
  > differentiation.

- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main
  view; people who aren't talking or working showing on the map; a wrong role guess
  blocking process of elimination.

  > **Prep B114 (9cb8782; verify old examples first):** Use `tools/test_board.gd`,
  > `ui/board_view.gd::_gui_input`/`_draw_pinned`, and `game/board_model.gd::layout`. Check
  > pin/map/elimination examples across filters/views; preserve user pins before labeling historical
  > visual reports current bugs.

- **Card zoom and text extension.** Settle card sizing, clipping and zoom/detail
  transitions before extending rich text onto board cards, pinned deductions, the
  tray and Card List. The shared formatter, log and profiles are built (steps 1–3);
  steps 4–5 are deferred. Card List/working-set rows are wrapping Godot Trees with
  one colour per row; richer rows still need custom cells or replacement controls.
  See [the handoff](docs/text_system_handoff.md) for hooks, issues and alternatives.
  [decided: extension deferred; renderer approach open]

  > **Prep B115 (9cb8782; open; renderer decision):** `ui/board_view.gd::_draw_card_item` uses custom
  > Canvas drawing/fixed geometry; `ui/card_list.gd` extends Tree. Rich text requires reflow,
  > hit-testing, and caching/replacement controls. Follow `docs/text_system_handoff.md`; test zoom,
  > links, and pins at several scales.


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

## 3. Medium features (several days; touch a few systems)

- **Expanded dialogue and trust management** (Oct 20; design candidates, pending
  the unified retuning proposal). [tentative]

  > **Prep B116 (9cb8782; tentative package):** These children share incident IDs, promises, and
  > public/private knowledge. Define those contracts before adding actions to `ui/main.gd::_offer_picker`
  > or `game/game.gd::_talk_command`. No tuning values are approved by these notes.

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

    > **Prep B117 (9cb8782; design):** `sim/mind.gd::set_trust`/`cap_trust` and
    > `game/game.gd::_settle_offers` lack a general apology incident ledger. Record perceived
    > harm/responsibility/repair once; a positive delta cannot restore a permanently lowered ceiling
    > without a recovery policy.

  - **Suggest actions based on claimed role:** ask a Warden to protect a person, a
    Seer to check a person/pair, or a Night Watch to watch a block. Track request,
    response/commitment, intended action, actual action, and follow-up separately.
    Trust, Confidence, Composure, danger, competing priorities, and the NPC's
    relationship with the requested target can affect compliance; allow refusal
    or a counterproposal. (Target relationship added Oct 21.) Offer the same dialogue to evil
    bluffers, who can lie about compliance/results, so requests do not verify roles.
    Exact trait interactions remain open.

    > **Prep B118 (9cb8782; design):** Use `game/game.gd::_offer_command`, `sim/world.gd::_receive_info`,
    > and `sim/evil.gd::make_fake_info`. Keep heard/accepted/acted/reported states separate. Hidden
    > actual compliance must not become a dialogue role-verification oracle; bluffers need the same
    > request surface.

  - **General requests can spread through town chats:** "Someone should check Nisha"
    or "Someone should watch the Wharf," without outing a gift-holder. Distinguish
    hearing a request from volunteering and completing it; do not assume coverage.

    > **Prep B119 (9cb8782; design; request schema first):** `sim/social.gd::_pick_item`/`_deliver`
    > exchange information, not general commitments. Define request identity/status before propagating it
    > once per recipient; a relay does not imply a real gift-holder accepted or completed the task.

  - **Responsibility and useful follow-through can build trust:** a meaningful
    accepted task may earn a small, non-repeatable rapport gain; later credit depends
    on what the NPC believes was accomplished. A Seer "no" or empty watch can be
    useful; do not reward incriminating results by default. Prevent request spam,
    duplicate credit, and hidden-truth outcome checks. Follow-up dialogue can report
    success, disappointment, or a convincing evil lie.

    > **Prep B120 (9cb8782; design):** Use `sim/mind.gd::set_trust` and `game/game.gd::_settle_offers` as
    > patterns. Credit perceived useful follow-through once per task/outcome, not incriminating results
    > or repeats; keep rapport separate from source honesty.

  - **Responsibility can cut both ways:** an NPC may feel guilt when their information
    helps execute someone, especially when later evidence makes that execution look
    mistaken. Consider this as a core NPC response as well as a request follow-up.
    Base it on perceived responsibility and known outcomes; do not treat an
    execution as vindication merely because the information was acted on.
    (Oct 21) [tentative]

    > **Prep B121 (9cb8782; design):** `sim/world.gd::_grief` has execution resentment;
    > `game/case_metrics.gd::summarize` is truth-aware post-case diagnostics. NPC guilt needs event-time
    > knowledge and attributed contribution, not metrics' hidden correctness or “execution implies
    > vindication.”

  - **Withdraw or revise a case:** explicitly retract public endorsement or explain
    changed reasoning without deleting the underlying evidence. NPCs may retain
    their own view and explain why. Private role guesses remain private.

    > **Prep B122 (9cb8782; partial; candidate to narrow):**
    > `ui/live_case_workshop.gd::_withdraw_window`, `game/game.gd::workshop_retract`, and
    > `game/workshop_canvas.gd::file` already support withdrawal/revision. Verify UI/ownership first;
    > public explanations and NPC stance changes remain distinct from deleting facts.

  - **Ask what would change their mind:** expose friendship, conflicting information,
    player distrust, or preference for another execution as actionable resistance.

    > **Prep B123 (9cb8782; open feedback):** `sim/mind.gd::_vote_impl` provides resistance parts and
    > `workshop/jury.gd` assessed explanations. Expose actionable known reasons while protecting private
    > information; do not promise that fulfilling one suggestion guarantees a later vote.

  - **Explain an execution's purpose:** propose an information-seeking execution
    (e.g. for a Gravedigger read) without needing to assert the target is the Demon.

    > **Prep B124 (9cb8782; design):** `sim/mind.gd::execution_priority` is a zero-weight extension
    > point; `game/game.gd::_parse_conclusion` is proposition-based. Define information-seeking purpose
    > separately so proposing an execution does not itself assert evil or raise suspicion.

  - **Promise confidentiality:** one straightforward promise option that can support
    private disclosure, with consequences for keeping or breaking it. Avoid a
    negotiation tree or multiple branching confidentiality terms; coordinate with
    existing confidence/secret-keeping rules rather than awarding duplicate credit.

    > **Prep B125 (9cb8782; design):** `game/game.gd::_disclose`/`_break_confidences` and
    > `sim/mind.gd::end_of_day_trust` already handle confidence consequences. Add one explicit
    > promise/settlement identity; avoid duplicate daily reward/loss for the same protected disclosure.


- **Learn personality through other NPCs.** Asking about someone can reveal one of
  that person's traits and unlock its actual score in their profile, using the
  existing learned-trait presentation. Example: Agnes calls Bartholomew stubborn,
  revealing Confidence. Filter descriptions through the speaker's relationship:
  a confident friend is "principled", a rival "pigheaded". Separate the revealed
  trait/score from that subjective wording, and define which traits the speaker
  can reasonably know and how often this occurs. Coordinate with public
  friends/rivals and haunt disclosure; do not reveal hidden relationships.
  (Oct 21) [decided; discovery rules open]

  > **Prep B126 (9cb8782; open):** `sim/mind.gd::reveal_trait` and profile rendering supply the target
  > surface; `sim/mind.gd::answer_opinion` is a possible route. Define speaker knowledge before numeric
  > trait reveals; subjective wording must not expose private bonds/Lovers.

- **NPCs voice doubt about their own readings.** Detect apparently inconsistent
  results, such as repeated Seer checks of the same pair changing yes/no, and let
  the NPC acknowledge that something is unusual. Higher Insight can also help
  notice a mismatch with their leading explanation/world. Use information they
  actually have, allow legitimate changes such as succession, and distinguish
  suspicion of misdirection from admitting a lie. Coordinate with source
  credibility and the section-4 case/world model; existing self-reading doubt
  mechanics do not yet provide this general proactive dialogue.
  (Oct 21) [decided; triggers/presentation open]

  > **Prep B127 (9cb8782; open in part):** `sim/argue.gd::_match_pair` recognizes some flips;
  > `sim/mind.gd::_night_doubt` affects beliefs. Proactive self-doubt still needs own-evidence/chronology
  > triggers. Allow legitimate succession/poison alternatives without consulting actual hidden causes.


- **Rebuttals and excuses.** Someone accused explains with their gift ("I was out
  because I'm the Lamplighter"; own-lie admissions are built), which buys some grace with listeners; evil without a
  fitting bluff can claim a fake secret. Biggest open hole: hidden night walkers frame
  themselves (Isolde 55774, Constance 96773; Lamplighter/Veteran/Sleepwalker/Warden hang rates). (DESIGN)
  Now part of the meeting-flow plan (docs/meeting_flow_plan.md, step 2). [decided]

  > **Prep B128 (9cb8782; partial; consolidate):** Own-lie admission exists in
  > `sim/mind.gd::_answer_gift_impl`; `defend_self` owns native moves. Group hidden walkers, caught-lie
  > motives, and reading challenges. The merged mechanics work (`0cd2181`) maps defence moves to claims,
  > secret cards and reading challenges with hearing weights; extend those, don't rebuild them.

- **Medium relay credibility at both sources.** Audit/fix relayed readings so full
  credence requires trusting both the Medium and the dead source. Current
  `Mind.apply_info` stores the Medium as the ledger reliability source; the Medium
  branch expands the dead reader's effects at 60% but does not retain a separate
  live reliability dependency on that reader. Cover relayed readings, sightings and
  opinions, both sources' sincerity, and each relevant reading's own night-specific
  doubt without double-discounting. Keep relationship hearing weight distinct from
  source honesty; never consult hidden actual poison/alignment for acceptance.
  (Oct 21 code audit) [decided; exact combination open]

  > **Prep B129 (9cb8782; partial; two paths):** Native Medium expansion is `sim/mind.gd::_info_effects`;
  > shared originals use `workshop/live_assessment.gd::medium_card` and
  > `workshop/solver.gd::report_table`. Check both sources and dates. A faithful relay cannot be an
  > independent corroborating origin.

- **Trust dynamics around sources (later).** A relayer may name their source outright,
  at the cost of that person's trust; and evil may try to trace an unnamed source ("the
  Seer told me") back to a person, to kill or frame them. (Oct 19) [open]

  > **Prep B130 (9cb8782; design; later):** `game/game.gd::_disclose` records `via`;
  > `sim/social.gd::_deliver` forwards claims. Anonymous-source inference and retaliation need an
  > attribution policy first. Do not identify an unnamed reader from hidden real role assignments.

- **Last words.** A condemned NPC gets some final words before the hanging (flavour). (Oct 19) [decided]

  > **Prep B131 (9cb8782; open flavor):** Hook between the final decision in `game/game.gd::_after_vote`
  > and `sim/world.gd::execute`, respecting Martyr substitution. Final words must not expose true
  > role/alignment; execution and aftermath must still occur exactly once.

- **Nominations make a case.** The nominator cites several cards, even weak ones.
  Mostly flavour; it only moves NPCs if it brings new information. [decided]

  > **Prep B132 (9cb8782; partial):** `sim/mind.gd::nomination_case`/`case_against` collect reasons;
  > `game/game.gd::_show_nomination` displays events. Cite actual known cards and count only newly heard
  > facts; a flavor recap must not reapply existing evidence effects.

- **Meeting and vote talk** (returns with the rebuttal work). Votes are silent for now;
  PR #3's vote explanations were removed. When vote talk comes back: evil voters must
  draw from the same spread of reasons as good ones (in PR #3 they all said "the case is
  strong enough"), and only lines that tell you something should be spoken (a reason
  that differs from the crowd, a vote against a stated stance, a swing vote). [decided]

  > **Prep B133 (9cb8782; open; meeting batch):** `sim/mind.gd::_vote_impl` records reasons;
  > `game/game.gd::_after_vote` displays results. Use those records for selective explanations/reactive
  > replies, including varied evil cover reasons; never rerun votes to obtain better dialogue.

- **Fading into the crowd.** NPCs weigh how much talking is already going on before
  speaking or disclosing. When the town is already moving in a direction, a private
  character may just bide their time and listen. (Oct 19) [decided]

  > **Prep B134 (9cb8782; design):** `sim/mind.gd::_public_claim_decision` already weighs
  > disclosure/repeated gift value. Coordinate crowd/salience input with reactive meetings, preserving
  > timely contradictions and willingness gates; avoid two contradictory speaking decisions.

- **Outing yourself to defend someone.** The flip side of the accusation tiers: when an
  NPC holds information that could clear someone on the block (a Seer "no", a Night
  Watch who saw them stay in), when are they willing to come out to defend them? The
  same weighing as accusing (how strong the clearing is, what the reveal costs, how
  close the vote is). (Oct 19) [decided]

  > **Prep B135 (9cb8782; design):** `sim/mind.gd::defend_self`/`_public_claim_decision` support some
  > self-disclosure. Defending another needs known clearing evidence and one public event; availability
  > must not reveal an undisclosed true gift.

- **Talking to a group:** 3 questions per phase, split among anyone at the spot.
  [open; discussed 2026-10-18]

  > **Prep B136 (9cb8782; design):** `game/game.gd::_talk_command` has one target and conversation-scoped
  > costs/repeats. Define membership, shared hearing, and phase budget before UI target changes;
  > switching people must not reset the group allowance.

- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems.** Today the Revenant is often invisible (55774). [decided]

  > **Prep B137 (9cb8782; open; split AI tasks):**
  > `sim/evil.gd::place_totem_now`/`sim/world.gd::_revenant_curse` implement lifecycle. Seeking execution
  > and NPC searches need separate strategy/action paths. Preserve voter uncertainty; good NPC search
  > choices must not read hidden totem locations.

- **NPCs find evidence and personal items** (dropped items, traces). [decided]

  > **Prep B138 (9cb8782; open):** `game/game.gd::_search` is player-oriented;
  > `sim/social.gd::_pick_item` lacks a general physical-evidence inventory. Define discovery receipts,
  > provenance, and cost before NPC searches; retelling a discovery is not a second observation.

- **Lovers downside:** when one dies, the other becomes withdrawn: Privacy to max,
  Gossip to min, and whichever other shifts hurt the player most (e.g. Composure up so
  they're harder to read). Visible, so the player can notice the change. [decided]

  > **Prep B139 (9cb8782; open; distinguish grief):** `sim/world.gd::_grief` applies resentment/caps but
  > does not generally maximize Privacy/minimize Gossip. Decide persistent traits and visibility
  > separately; a visible bereavement shift should be a clue, not guaranteed hidden-Lover verification.

- **Ways to discover and confront secrets:** sightings that don't fit, confidants,
  personal items, a "you have a secret" card used as leverage. (DESIGN) [open]

  > **Prep B140 (9cb8782; design):** `sim/world.gd::_assign_secrets` sets secrets;
  > `game/game.gd::_secrets_used`/`_break_confidences` handle leverage/cost. Define discoverable
  > attributed claims before secret cards; do not populate player knowledge directly from hidden
  > assignments.

- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. (DESIGN) [open]

  > **Prep B141 (9cb8782; design):** `sim/mind.gd::answer_night` emits alibis; `sim/evil.gd::make_plan`
  > stores cover. Add named corroborator/date, then an independently heard reply. Two names on one
  > person's statement are not two witnesses.

- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (DESIGN, open since playtest 1) [open]

  > **Prep B142 (9cb8782; design; movement dependency):** `sim/world.gd::_maybe_drop`,
  > `game/game.gd::_search`, and `sim/argue.gd::assertions` cover clues. Settle trace origin/movement
  > first; retain discovery identity so revisits/relays do not multiply chained evidence.

- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers
  meeting too as noise. (DESIGN) [open]

  > **Prep B143 (9cb8782; partial):** `sim/world.gd::_pre_pair`/`_make_pair` and
  > `sim/social.gd::converse` already produce visible encounters and private evil intel. Specify
  > additional coordination against normal friend meetings; separate the observed encounter from secretly
  > exchanged content.

- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  demon; the demon goes along with town conclusions to build trust. (DESIGN) [open]

  > **Prep B144 (9cb8782; design):** `sim/evil.gd::teammate_value`/`public_hostility` and
  > `sim/mind.gd::_vote_impl` govern stakes. Bussing needs observable cover benefits and persistent
  > stance history; preserve prior reports and keep teammate calculations out of good listeners'
  > reasoning.

- **Claims/reveals timeline** next to the location timeline. (DESIGN) [open]

  > **Prep B145 (9cb8782; partial data):** `game/game.gd::_disclose` stores learned histories;
  > `ui/profile_panel.gd::_render_entries` renders attribution. Reuse receipts for the new timeline,
  > distinguishing observed versus disclosed time; location marks alone cannot represent both.

- **Dialogue voices for the rest of the cast.** The composer is merged (Agnes,
  Bartholomew, Constance × five situations; dialogue lab at `ui/dialogue_lab.tscn`).
  Everyone else uses the plain lines until they get a voice. [decided, later] 54875: on
  day 1 Dorian and Odette gave word-for-word identical gift refusals and night alibis
  ("Whether I have a gift is my own business"; "At home all night, same as any honest
  soul"), which makes the town read as one person.

  > **Prep B146 (9cb8782; open content):** Inspect `sim/dialogue.gd`, `sim/dialogue_voices.gd`,
  > `ui/dialogue_lab.tscn`, and `tools/dialogue_scenarios.gd`. Keep approved facts/intent IDs stable
  > while varying lines; test semantic facts and repeats rather than identical wording for every speaker.

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
- **Bot coverage of the new talk options:** the bot doesn't offer wards or vigils or ask
  about others to learn haunts, so bot runs don't measure them. [decided]

  > **Prep B147 (9cb8782; open prerequisite):** `tools/autoplay.gd::_decide` does not cover the whole
  > talk/offer toolbox. Add observable decision coverage/counters before using bot outcomes to measure
  > those features; passive runs do not exercise active offers/haunts.

- **Evidence-reading bot.** The bot ignores traces and dropped materials entirely (and
  peeks at `w.dropped` when deciding to search), so bot win rates say nothing about
  physical evidence. Teach it to read traces and drops, and stop the peek, to measure
  what evidence is worth. [decided]

  > **Prep B148 (9cb8782; open; confirmed oracle):** `tools/autoplay.gd::_decide` peeks at
  > `w.dropped.has(g.loc)`; `_scores` uses hand weights. Remove the hidden-presence peek and add public
  > trace/material reasoning before treating bot outcomes as physical-evidence balance measurements.


- **The Revenant can hide a new totem each day.** Burning a totem doesn't make the
  Revenant safe to hang for good: in 54875 the totem burned on Day 4, a new one was
  hidden Day 5, Edda was hanged with it and Isolde turned. When a totem burns, signpost
  that another may follow ("it will seek a new hiding place"), and think about whether
  the totem search can keep pace. [decided: signpost; balance open]

  > **Prep B149 (9cb8782; open signposting; lifecycle built):**
  > `sim/world.gd::find_totem`/`start_new_day` and `sim/evil.gd::place_totem_now` already permit
  > replacement. Add burn-receipt warning; separately check burn → replacement → execution/curse without
  > implying permanent safety.

- **The ward as evidence, and a visible save.** Your ward isn't a card today, and a ward
  that stops an attack leaves no sign. Make the ward a card (who, door, night) and let a
  held ward leave a mark (a scorched sigil) as physical proof the demon came to that
  door. Feeds the "Protection + quiet night + sighting" template gap. (user, Oct 23)
  [decided]

  > **Prep B150 (9cb8782; open in part):** `game/game.gd::_morning_report` puts ward metadata on quiet
  > cards but has no standalone ward/save receipt. Add spent door/night and separately observable
  > scorched outcome; coordinate quiet/protection adapters to count one save once.

- **Reactive meetings: speak up when the last statement concerns you.** (user, Oct 24)
  After each meeting statement, every listener runs cheap yes/no checks: does it name
  me, or name a person or role that's part of my private information (my own gift,
  someone I have a reading about, a claim of my role)? If so, add a situational bonus to
  the usual disclosure decision, so they may respond on the spot: confirm, contradict,
  claim, or defend. Uses the existing disclosure checks (privacy, trust, pressure),
  not a new evaluation, so it's cheap and makes the meeting feel like a conversation.
  Pairs with pacing refreshes behind dialogue. [decided: add; bonus size open]

  > **Prep B151 (9cb8782; open; scheduling contract):** Use
  > `game/game.gd::_start_meeting`/`_nomination_command` and `sim/mind.gd::_public_claim_decision`.
  > Preserve queued refresh boundaries and one audience capability pass/command; relevance checks must
  > not trigger another world evaluation per reply.

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

  > **Prep B152 (9cb8782; updated after merge `0cd2181`; partial):** `workshop/live_activity.gd` now
  > gives the Demon a small detour chance (`DEMON_DETOUR` = 0.05), so an off-route sighting argues strongly
  > but not absolutely against the killer; native `sim/mind.gd::night_sighting_scale` still serves
  > native-owned paths. Remaining: distinguish Demon exclusion from possible Minion guilt and surface the
  > same model in replies.

- **Corroborated walking-gift claims.** (user, Oct 24) In a playtest, Odette claimed
  Lamplighter and was seen on several different blocks across the town, which lent her
  claim credence. In the shared movement model a claimed Lamplighter's path covers every
  block, so several scattered sightings fit her claim better than a Minion's single
  errand: the support exists numerically but is invisible. Make it visible ("seen all
  over town, as a Lamplighter would be") in previews and replies, and decide whether it
  should also count as support for the claim in the vibes stage (see "Supporting evidence
  in a case" below). [decided: surface it; weight open]

  > **Prep B153 (9cb8782; partial numerical support):** `workshop/live_activity.gd::_profile_paths`
  > already distinguishes Lamplighter all-block routes from Minion errands. Explain those inputs without
  > a second innocence bonus. Optional vibes weight belongs to the separate gated-impressions design.

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

  > **Prep B154 (9cb8782; design; Q3 deferred):** `sim/mind.gd::_good_nomination_impl` walks rank;
  > `_vote_impl` uses an absolute bar plus `prefers_block`. `sim/content.gd` keeps shared
  > execution-priority weight zero. Decide rank/urgency/premise policy, then test strong first, close
  > second, and wrong moderate cases.

- **Supporting evidence in a case: logical where possible, vibes where not.** After the
  legacy migration. Example: an accusation that cites the accused's voting history ("she
  voted to hang people you think are good"). (user, Oct 24) [decided: the split;
  details open]

  > **Prep B155 (9cb8782; design):** `workshop/jury.gd::_consequences_eval` currently takes the larger
  > logical/pattern signal. Action factors and gated impressions are not that implementation. Define
  > separate retractable ownership first, keeping accusations/opinions outside evidence and action rates
  > measured.

  - **Observable actions go in the evaluator as soft evidence:** votes, nominations,
    who defended whom, tie-breaks. "Voted to execute someone who is good in this world"
    needs only each world's evil mask, so it adds no hidden dimension (cheap; see
    Architecture rules in docs/LEGACY_MIGRATION.md). Each action is a likelihood factor:
    the rate at which evil and good players take it against good targets, measured
    from bot runs, not hand-set. The interaction the user wants ("if the case raises my
    suspicion, her votes against people I trust count more") then follows from the
    joint evaluation: no ordering, no feedback loop, no double counting. This is a
    new decision: Q1 put accusations (speech) outside evidence; votes are actions.

    > **Prep B156 (9cb8782; open; measure first):** `sim/world.gd::vote_pending` emits public vote
    > receipts; `workshop/live_assessment.gd::activity_card` adapts them as context. Instrument
    > action/target identities and rates before likelihood changes; do not also retain an independent
    > native bump for the same evidential action.

  - **Listener impressions go in a second stage gated on the first:** demeanour,
    nervousness under pressure, "oddly quiet", trust in the presenter. Stage 1 (the
    logical case) runs and is applied. Stage 2 then scores these cards from a snapshot
    of the listener's updated beliefs, scaled by how far stage 1 moved them, so vibes
    can't carry a case alone. Guardrails:

    > **Prep B157 (9cb8782; design; ownership risk):** `game/workshop_ownership.gd::_refresh` retracts
    > one joint vector. Stage 2 needs a separate reversible contribution from a frozen post-stage-1
    > snapshot, without self-suspicion feedback. Define split presentations, revisions, and withdrawal
    > before choosing weights.

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

    > **Prep B158 (9cb8782; verified hook):** `workshop/jury.gd::_consequences_eval`/`_pattern` are the
    > implementation points. Replacing max with addition alone would double-count overlaps. Classify
    > logical actions/impressions and deduplicate origins across both stages first.

  - Open: which actions qualify, the measured rates, stage-2 weights (ties into the
    deferred Q6 Insight/Confidence pass), and the NPC lines ("your case convinced me,
    and now her votes look worse").

## 4. Major structural work (a week or more; design first)

- **Cases instead of proofs: the player argues a theory** (Oct 19–20 discussion; next up
  after the usage reset, ahead of meeting-flow step 5). [decided, design first]

  > **Prep B159 (9cb8782; partial; milestone stale):** Case canvas/shared evaluation already exist in
  > `game/workshop_canvas.gd`, `workshop/canvas_model.gd`, and `workshop/shared_ledger.gd`. Treat this as
  > an umbrella with remaining gaps, not a fresh rewrite. Current migration documentation supersedes the
  > old “next after reset” sequencing.

  - **The problem:** deductions are "these cards prove this", gated by templates. Most
    Clocktower reasoning is cumulative and probabilistic, so a strong case like "Seer
    pair + near a murder + caught in a lie" gets filed as a weak "your inference". The
    space of evidence interactions is too large for templates, and some that fit are
    unintuitive to build.

    > **Prep B160 (9cb8782; partial):** `game/game.gd::file_deduction` integrates shared cases;
    > `sim/argue.gd::check` still provides templates/compatibility. Reproduce generic/template
    > discrepancies against the actual delivery path before changing a coefficient in only one evaluator.

  - **The direction:** the player proposes a theory, which can be partial:

    > **Prep B161 (9cb8782; partial):** `workshop/canvas_model.gd` compiles partial
    > cases/answers/assumptions for the solver. Live premises remain bounded; generic innocent secrets
    > and a particular Seer Red Herring stay unsupported unless established, consistent with the later
    > mechanics decisions.

    - the demon candidate and the suspected evil;
    - optional assumptions ("Edda is the red herring", "Constance's reading was
      poisoned").

    The game scores each card on how well it fits that theory: supports, contradicts,
    or doesn't bear. This answers the question the evidence poses (the Surveyor's "3":
    mark who the evil are, and see if the count fits).
  - **One fit check per evidence type** instead of templates for pairs:

    > **Prep B162 (9cb8782; partial; absolute wording stale):** `workshop/solver.gd::_report_content`
    > provides family fit checks; `workshop/world_domain.gd` supplies alternatives. Demon death is strong
    > finite evidence, not certain goodness. Check generator/adapter/solver consistency per family before
    > adding templates.

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

    > **Prep B163 (9cb8782; partial):** `workshop/shared_ledger.gd::roots`/`endorsed_facts` preserve
    > canonical origins. “Same source once” must not erase new dated reports. Check origin repeats,
    > multiple nights, dependent relays, contradictions, and withdrawal before adding surprise weights.

  - **NPCs judge the player's theory; they don't search for theories.** Each listener
    checks it against what they know, at their own credibility weights, and answers two
    questions: does it make it more likely (belief), and is it enough to act on
    (execution priority: urgency, trust in the player, counterevidence)? An accepted
    assumption can become a working belief that later arguments build on, and it's undone
    if it collapses. That keeps the player as the detective and NPCs persuadable and
    plausibly wrong (accidental misdirection and deliberate manipulation, such as
    getting someone hanged for a Gravedigger read, both still work).

    > **Prep B164 (9cb8782; partial; canceled-work boundary):** Current jury/reasoner judge bounded cases
    > with shared ownership; attention still affects the evidence set. Use premise salience to clarify
    > listener work. Do not restore per-person latent-channel evaluations or the canceled full hypothesis
    > rewrite.

  - **Keep:** templates, now as bonuses for rigorous links rather than gates; the evidence
    ledger; cards; provenance; the shadow self. The per-card weighing that private cases
    already use is the starting point for scoring.

    > **Prep B165 (9cb8782; constraint):** Retain `sim/argue.gd` links, `game/game.gd::add_card`
    > identities, provenance, and `sim/mind.gd::shadow_run`. A template bonus must not add another
    > likelihood for facts already owned by the posterior; filing help and belief weight differ.

  - **Bonuses:** a supports/contradicts view of the board is a strong player tool on its
    own. The private-theory panel (demon and minion guesses) is the natural entry point.
    The bot can use the same checks.

    > **Prep B166 (9cb8782; partial UI; oracle risk):**
    > `ui/live_case_workshop.gd`/`ui/workshop_comparison.gd` preview assessments;
    > `game/game.gd::set_guess` stores private guesses. Align supports/contradicts with
    > qualitative-preview policy; guesses must not silently become public facts or endorsement
    > assumptions.

  - **Where it plugs in:** the player's turn in the meeting flow becomes "make a case".

    > **Prep B167 (9cb8782; partial):** `game/game.gd::_meeting_command`/`_route_present` and
    > `ui/main.gd::_refresh_actions` already accept case presentations. Reuse the delivery path with
    > explicit public endorsement and queued refresh, rather than a parallel argument executor.

  - **Considered and not chosen:** Astra's full competing-hypotheses rework (every NPC
    tracking demon, minion, red herring and Marked beliefs for everyone). It's sound,
    but it makes NPCs better reasoners, which is the wrong direction, and it's a large
    open-ended core rewrite. Revisit only if playtests keep pointing at "one suspicion
    score" problems, and then as a log-only prototype first.

    > **Prep B168 (9cb8782; parked alternative):** Keep the explicit non-choice. Experimental
    > `workshop/channel_likelihood.gd` is not authorization to revive canceled validation. A future
    > hypothesis prototype needs separate scope and measured cost/benefit; this preparation does neither.

  - **Related cheap idea, can come first:** an execution-priority term in nominations and
    votes. A credible lead (a Seer yes, a trusted player's case) makes a target
    actionable without inflating belief, scaled by urgency.

    > **Prep B169 (9cb8782; partial hook; deferred activation):**
    > `sim/mind.gd::execution_priority_contribution` exists with zero coefficient in `sim/content.gd`.
    > Resolve Q3 rank/urgency/premise design and wrong-nomination controls before activation. Do not
    > invent another hook or conflate action priority with belief.


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

  > **Prep B170 (9cb8782; partial infrastructure):** Reuse `workshop/canvas_model.gd`/live adapters and
  > actual phases from `sim/evil.gd::breath_target`. Start one report-only prototype. Unknown whereabouts
  > and synthetic summaries must not become negative proof or duplicate underlying sightings.

- **Night movement and trace model.** One package of related items:

  > **Prep B171 (9cb8782; design; semantics first):** Generation is
  > `sim/world.gd::_night_movement`/`_walk`/`_maybe_drop`; interpretation is
  > `workshop/live_activity.gd::_paths` and `sim/argue.gd::_match_route`. Settle
  > origin/detour/destination wording before evidence chains. Main now has Demon detours (5%) as well
  > as direct kill routes (merge `0cd2181`).

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

  > **Prep B172 (9cb8782; open in part):**
  > `sim/argue.gd::assertions`/`workshop/live_assessment.gd::activity_card` already adapt some
  > location-bearing cards. Ability groups and visit absences need explicit completeness semantics.
  > Visits omit people at home; hearsay/incomplete recollections cannot create the same exclusion.

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

  > **Prep B173 (9cb8782; design):** `sim/world.gd::_night_sightings` records observations;
  > `sim/argue.gd::_match_route` interprets routes. Define observer ability to identify
  > transit/destination before metadata changes. All-block adjacency collapses many distinctions;
  > preserve old-log interpretation.

- **Breathstealer confirms the good.** It only silences the good, so a silenced person
  is proven good, and the role's visible effect becomes a gift to the town. Options:
  (a) the Breathstealer may silence a teammate under suspicion, as cover (a strong evil
  play; silence becomes "probably good"); (b) silence goes quiet: not announced; the
  victim volunteers nothing and stonewalls direct questions, with a small tell you can
  see in private ("…opens her mouth, then shakes her head"); evil can feign it; (c) both.
  [open; see 96773 discussion]

  > **Prep B174 (9cb8782; design; absolute diagnosis stale):** `sim/evil.gd::breath_target` targets good
  > NPCs, but public silence already has finite native/context impact. Choose teammate targeting,
  > concealment, or both, then change generation and interpretation together; do not restore certainty
  > from silence.

- **Breathstealer ambiguity, two more routes** (for the Breathstealer decision above):

  > **Prep B175 (9cb8782; design; same decision):** Optional use/innocent silence changes observation
  > generation too. Coordinate `sim/evil.gd::breath_target`, `sim/world.gd::begin_meeting`, and public
  > receipts; do not add an invisible exception only in the evaluator.

  - a good secret that inflicts the same silence (a vow, a sore throat), so a silence
    isn't proof of the Breathstealer or of the victim's good;
  - make the Breathstealer's silence optional (it may skip days), which also explains
    why the secret's silences come on some days and not others, for maximum
    dastardliness. (Oct 19) [open]
- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration).
  Relationship mods for the Lovers live here too. [open]

  > **Prep B176 (9cb8782; design):** `sim/world.gd::_assign_relationships`/`_assign_secret_mod` and
  > `sim/npc.gd` own setup state. Relationship variants need disclosure/grief policy before inference
  > support. Reuse learned relationships instead of exposing all setup links.

- **Roster expansion:** On Deck gifts (Tracker, Clairvoyant, Beckon, Tallyman…); minions
  (Framer/Forger with evidence planting, Blackmailer, Hexer, Informant); Debtor secret.
  Each needs its hint package and template coverage. [open]

  > **Prep B177 (9cb8782; design; cross-system checklist):** Definitions are
  > `sim/content.gd`/`sim/gifts.gd`, generation `sim/world.gd::_receive_info`, bluffing
  > `sim/evil.gd::make_fake_info`, fitting `workshop/solver.gd`. Include hints, adapters, UI, fake paths,
  > and ownership tests; dropdown names alone are not support.

- **A demon that kills during the day** (user concept, Oct 23). If added, the protection
  evidence (the "Protection + quiet night + sighting" template gap) must be re-weighed:
  a quiet night no longer means the night attack was stopped, and a night sighting near
  a guarded door says less. Night evidence generally loses some weight while this demon
  may be in play. [open]

  > **Prep B178 (9cb8782; design):** `sim/world.gd::resolve_night`/`attack_outcome` and
  > `workshop/live_protection.gd::assess` assume today's night attack process. Define public death
  > time/cause and quiet-night alternatives first; new Demon rules must change protection interpretation
  > consistently.

- **The demon lures a victim elsewhere** (user idea, Oct 23): once per case, or under a
  condition, the demon kills somewhere other than the victim's cottage. "Found dead at
  the well" is itself a clue (who would go there at night, and who did they trust?),
  and it gives location-based night tools, such as a vigil at one spot, something to
  target. The current demon has no ability beyond the kill. [open]

  > **Prep B179 (9cb8782; design):** `sim/world.gd::_kill`/`_night_movement`,
  > `game/game.gd::_morning_report`, and live adapters couple victims/scenes/routes. Lures need explicit
  > crime location separate from home, consistent traces/protection reach, and old-log compatibility.

- **Player toolbox:** Autopsy, Séance, Scry, Binding circle; demon types with bestiary
  entries; exorcism / true-name alternate win. (DESIGN) [open]

  > **Prep B180 (9cb8782; design):** `game/game.gd::_night_command`, `_search`, and `_outcome_text` are
  > tool/victory seams. Define charges, observable receipts, alternate win, and false-result behavior
  > before UI. Keep toolbox exploration separate from current ward receipt cleanup.

- **Scoring system:** identification credit, accuracy of guesses with confidence, why
  the player lost (wrong read / missed / never available / failed to persuade). Absorbs
  the removed voting prompt and the Scion credit rule. [open]

  > **Prep B181 (9cb8782; partial; candidate to narrow):** `game/case_metrics.gd::summarize`/`aggregate`
  > already report identification, minion ID sets, and loss categories; `tools/test_outcomes.gd` covers
  > outcomes. Exact-gift credit, confidence, and Scion/event-time attribution need explicit rules. ID
  > correctness is not exact-role accuracy.

- **Storyteller/director and solvability check:** poisoned readings become arbitrary
  (chosen plausibly) rather than inverted; check that a case can be solved. (DESIGN)
  [open]

  > **Prep B182 (9cb8782; design):** `sim/world.gd::_receive_info`/`sim/evil.gd::make_fake_info` feed
  > deterministic replay. Define solvability from reachable public evidence in a bounded diagnostic
  > first. A truth-aware director must not leak solutions into beliefs or silently alter reports already
  > heard.

- **Procedural town:** blocks, buildings and roads generated per case. (DESIGN) [open]

  > **Prep B183 (9cb8782; design; topology assumptions):** `sim/content.gd` defines places,
  > `sim/world.gd::_walk` uses topology, and `game/board_model.gd::layout`/map UI expect current rows.
  > Inventory route/material/home/UI assumptions first; validate reachability and seed determinism before
  > balance conclusions.

- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]

  > **Prep B184 (9cb8782; watch; scaling risk):** `workshop/world_domain.gd`,
  > `workshop/role_constraints.gd`, jury, setup, and UI target 7/10-person models. Benchmark isolated
  > solves/refreshes first; avoid multiplying all role-holder masks or per-person theories when adding
  > towns.

- **NPC memory and recency bias.** (Random ideas) [open]

  > **Prep B185 (9cb8782; design):** `sim/dialogue.gd::compose` remembers wording;
  > `sim/mind.gd::ledger_hear` retains facts and `refresh_consensus` fades pressure. Decide what decays
  > before applying recency globally. Forgetting wording must not retract evidence or create an absence.

- **Dead NPCs:** no ghost votes for now. (DESIGN, deferred) [watch]

  > **Prep B186 (9cb8782; watch; no action):** `sim/world.gd::seats`, `vote_order`, and `vote_pending`
  > define current voters. Preserve the explicit no-ghost-votes decision; dead-source credibility/Medium
  > work is not permission to add voting rights.


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

  > **Prep B187 (9cb8782; updated after merge `0cd2181`; built, verify):** The accepted design
  > (public eligible voters, one hypothetical turnee, bounded epochs) is on main in
  > `workshop/chronology.gd` and the live assessment. Candidate to close after a cursed-game playtest and
  > a passive cost check; growth stays bounded to curse histories and the actual victim stays private.


- **Succession breaks earlier clears.** A Seer "no" (or any not-the-demon clear) only
  speaks for the demon *as of that night*. If a hanging with 5+ alive (so a Scion could
  rise) falls between two readings, group elimination, overlap and pair elimination
  must keep "X became the demon afterwards" as an explanation instead of "the earlier
  reading clears the rest". In 55774, #150 cleared Edda from Agnes's night-5 "Greta or
  Edda" using the night-4 "Fenwick or Edda: neither", across Hollis's hanging. Greta
  was right, but Edda (evil, an equally possible successor) stayed a live candidate.
  NPC reasoning and the bot should apply the same limit to old clears. (Astra, 55774)

  > **Prep B188 (9cb8782; partial guard):** `sim/argue.gd::assertions` marks possible succession;
  > `sim/world.gd::execute` actually requires the Demon and healthy Scion. Possibility is not
  > confirmation. Shared chronology needs dated identity alternatives; check old clears across qualifying
  > hangings without reading the hidden successor.

- **Same person in repeated Seer yeses, later proven good** → that person is the
  red herring; drop them from the Seer's later readings. (55774: Jory)

  > **Prep B189 (9cb8782; design):** `workshop/solver.gd::_report_content` models Seer registration; live
  > conclusions do not identify a particular Red Herring. Repeated yeses plus finite innocence do not
  > prove that identity. Keep hypotheses unsupported unless established, retaining
  > poison/lie/Marked/succession alternatives.

- **Evil reading on a proven-good person** (Dowser count, Archivist pair) → Marked.

  > **Prep B190 (9cb8782; partial model):** `workshop/world_domain.gd`/`workshop/solver.gd` distinguish
  > registered evil; `workshop/live_assessment.gd::CONCLUSIONS` now has 15 types (merge `0cd2181`); generic
  > innocent secrets and a specific Red Herring stay unsupported by decision. A finite
  > clear plus an evil report does not force Marked. Test alternatives before adding builder premises.

- **Minion gifts in templates.** The builder can now conclude "X is the Breathstealer /
  Poisoner / Revenant / Scion", but no template reasons toward a minion: e.g. someone
  silenced, and the people seen on their block that evening (the Breathstealer has to be
  there); a reading that failed on a night someone was near the reader's home (the
  Poisoner's visit); a totem found and the people who live where its material is from
  (the Revenant). Needs "silenced" and "totem" facts that templates read. (54875: the
  totem card had no adapter in the case workshop either.)

  > **Prep B191 (9cb8782; partial; adapter diagnosis stale):**
  > `workshop/live_assessment.gd::activity_card` now adapts silence/totems, but typed-minion conclusions
  > remain unsupported there. Native labels do not create typed worlds. Coordinate role confirmations with
  > the merged role/notrole premises (`0cd2181`).

- **Breathstealer by presence:** someone silenced, and who was on their block that
  evening (the Breathstealer has to be there); over several silencings, the one person
  present each time. (96773: Bartholomew was nearby for each.) Needs "silenced" facts
  with where the silenced person was. Depends on the Breathstealer decision below.

  > **Prep B192 (9cb8782; design; duplicate pattern):** `sim/evil.gd::breath_target` can act any day
  > phase; `sim/world.gd::begin_meeting` applies silence later. Evening-only intersection is unsound.
  > Track possible dated contacts/unknown coverage; start the report-only presence prototype described
  > above.

- **Night companions of the proven evil:** out on the same block on the same nights as
  someone proven evil (a Gravedigger-confirmed Poisoner) → likely their teammate. 96773:
  Hollis's watch put Isolde out with Greta on night 1 (the kill block) and night 2;
  Greta was hanged and shown to be the Poisoner, but nothing linked Isolde to her.

  > **Prep B193 (9cb8782; design; weak association):**
  > `sim/world.gd::_night_sightings`/`workshop/live_activity.gd` include innocent routes too. Role
  > confirmation remains dated testimony. Shared presence must not imply guaranteed teammates or gain new
  > weight each time a relay repeats it.

- **A Medium's relayed sighting vs the dead's known vantage:** the dead watched or
  guarded a different block that night, so couldn't have seen what the Medium says.

  > **Prep B194 (9cb8782; partial):** `workshop/live_assessment.gd::medium_card` retains supported
  > source/time; `sim/world.gd::_medium_item` and `sim/evil.gd::_fake_medium_item` generate relays. Check
  > the original observer's claimed duty/vantage then, not the Medium's later location or hidden real
  > role.

- **Accounting:** a Lamplighter's "N others out" plus home alibis for everyone but one
  → the unaccounted person was out.

  > **Prep B195 (9cb8782; open in part):**
  > `workshop/solver.gd::_report_content`/`workshop/live_activity.gd` score supported counts/movement;
  > native rules are `sim/argue.gd::_match_groups`. Complete accounting must distinguish negative alibis
  > from refusals and preserve Lamplighter self-exclusion.

- **Role confirmations:** a Clerk or Gravedigger confirming someone's gift → that claim
  is backed (claim_backed covers the Clerk; the Gravedigger on a living rival claim
  does not).

  > **Prep B196 (9cb8782; partial):** `sim/argue.gd::_match_support` has Clerk `claim_backed`;
  > `_match_pair` covers Gravedigger disagreement. General positive confirmation needs dated
  > reliability/live premises; another claimant's report is not revelation of hidden true role.

- **Duty claim vs reading:** the off-route check now tests a named destination (a watch
  kept, a door guarded, the hearth of the dead) against sightings. Still missing: the
  hearth in the Medium's *reading* ("at Dorian's hearth") as the destination, so a
  reading and a sighting can conflict, not only the alibi and a sighting.

  > **Prep B197 (9cb8782; partial; duty fix present):** `sim/mind.gd::answer_night` now emits claimed
  > Medium/Warden duties consistently; `sim/argue.gd::assertions` handles destinations. A hearth embedded
  > in a Medium reading still needs link/movement propagation with original observation time and relay
  > provenance.

- **Walker's sightings vs the Lamplighter count:** more people reported out than the
  Lamplighter counted (or a Lamplighter who counted others but is seen nowhere).

  > **Prep B198 (9cb8782; open; accounting family):** `sim/argue.gd::assertions` emits out/watch facts;
  > `workshop/solver.gd::_report_content` checks reports. Use one count/set consistency rule with exact
  > night/source/completeness. Lamplighter self-omission is not automatically a contradiction.

- **NPC at evening location vs. murder evidence trace originating from a different location.**

  > **Prep B199 (9cb8782; partial):** `sim/argue.gd::assertions` and
  > `workshop/live_assessment.gd::activity_card` expose evening-presence/trace inputs. Check phase/crime
  > night and generator contamination alternatives. Group with conversation/trace examples rather than
  > inventing a second trace rule.

- **Evening sightings and conversations vs the scene trace** (54875). Seeing someone at
  the tavern in the evening, or two people talking there, should be a location sighting
  that links to "the killer spent the evening on the Square". Conversation cards don't
  count as location sightings today, so the best evening alibis on the board can't touch
  the trace (tried: "Odette and Constance talking at the tavern" with the Square trace at
  Hollis's death scene).

  > **Prep B200 (9cb8782; candidate to narrow; stale assertion):** `sim/argue.gd::assertions` already
  > emits locations for both conversation participants; `workshop/live_assessment.gd::activity_card`
  > adapts evening conversations as movement evidence. Recheck the exact link/preview example; any
  > remaining gap is a specific route/UI issue.

- **Protection + quiet night + sighting** (user, Oct 23). [decided]

  > **Prep B201 (9cb8782; partial; receipt dependency):** `workshop/live_protection.gd::assess` and
  > quiet-card ward metadata already give bounded support. Build standalone spent-ward/save receipts
  > first, then links/replies. Keep innocent walkers, withheld attacks, false claims, and alternate
  > blockers; do not double-credit one quiet outcome.

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

- **Case 22485 quick fixes (Oct 25, Claude).**
  - **Breathstealer:** she must be out in a public place to use the ability; the
    target can be anywhere on the same block (`Evil.breath_target`). In 22485 Odette did
    it from her house on Chapel Hill.
  - **Claimed night roles keep their story** (`Mind.answer_night`): someone who claimed
    Lamplighter, Medium or Warden never answers "home all night" for a night their gift
    had them out. An evil bluff always tells the duty; a real holder tells it whenever
    they were actually out, and still says "home" truthfully if they weren't. The "home"
    branch used to run before the claimed-duty branches.
  - **Sleepwalker and Lovers** go only to holders whose role isn't a night-walking gift
    (`World._assign_secret_mod`).
  - **Approaches give a location card:** accepting an approach adds the same sighting
    card a normal visit gives.
  - **Belief refreshes have no placeholder target** (`Jury.refresh` clears it), so
    attention ranks cards neutrally and no "you're accusing me" check fires on whoever
    is first in the town list.


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

# Demonologist backlog: completed

Items moved out of BACKLOG.md once built, verified or settled. Newest first. Original wording, tags and
session notes are kept for the record; code pointers may have moved since.

## Built Oct 26, 2026 (Codex batch 3 and Claude batch)

Built on `codex/backlog-batch-3` (Codex), `claude/batch-oct26` and `claude/sleepwalk-ward` (Claude), all merged
into main on Oct 26 after review. Full suite at merge: 82/82 suites, plus test_trace. Partly-built entries stay in
BACKLOG.md with notes (meeting speed, Workshop links/feedback, the sleepwalk excuse with its open Lovers part,
the totem balance, the evil-walker side of owned lies).

<!-- was in UI -->
- **Headline notices.** (user, Oct 26) Milestones that get lost in the text window, shown as a
  short headline over the game, one at a time from a queue. Text only for now (flair is in
  BACKLOG_POLISH.md). [decided]

  > **Decided (user, Oct 26); Codex batch 3:** the game emits a `headline` event next to the usual
  > log line; a mouse-transparent overlay plays a queue, one at a time; a click skips; with more than
  > two waiting, durations shorten; never blocks input. Styles (size, colour, duration per kind) in one
  > table that `user://settings.cfg` can override (no settings screen yet). Notices:
  > - dawn ("Day 4 Dawns", big, ~2.5 s, gold); nightfall (big, blue); other phase changes (small, ~1.2 s);
  > - each death at dawn: "<name>, who claimed to be the <gift>, died in the night" (public claim) or
  >   "who told you they were the <gift>" (private), or the name only; subtitle "A Demon hides among
  >   N remaining townsfolk" (red); "No one died in the night" on a quiet night;
  > - nominations and "now on the block" (amber); executions (crimson); the Martyr dying in someone's
  >   place; a curse taking hold (purple); a totem burned (green); your ward holding; the case ending.

  > **Implemented (Codex batch 3):** Game events feed a mouse-transparent queue; click-through skip, queue catch-up, claim-safe text, and settings overrides are covered by focused checks. Presentation defaults were approved in chat. Original log rendering and RNG stay unchanged; baseline and headline-only replay measurements are retained in logs/batch3.

<!-- was in Deduction types and templates -->
- **Starting secret-count card.** Generate a public setup card stating how many secrets
  are in town. Decide whether the count means modifier types, holders (Lovers count
  twice), or includes ordinary personal secrets; do not expose assignments. (61251/25923)
  [decided: card; count definition open]

  > **Decided (user, Oct 26); Codex batch 3:** don't reveal the nature of the secrets. Add one line at the bottom of the
  > script (the roles window, `ui/main.gd::_open_roles`, which already gives the minion count and "one
  > in play" for secrets), counting secrets, not people (Lovers are one secret, two people):
  > "Good: 5 gifted townsfolk / 1 secret · Evil: 1 minion / 1 demon" (7 townsfolk) and
  > "Good: 7 gifted townsfolk / 1 secret · Evil: 2 minions / 1 demon" (10). Counts come from the setup
  > rules, not the assignments. No board card, nothing for the shared model.

  > **Implemented (Codex batch 3):** The roles window ends with the specified good/secret/minion/demon counts from C.SETUPS. Lovers count as one secret; no assignments, board cards or shared-model data are used. Focused checks cover both town sizes and unchanged cards/RNG.

<!-- was in UI -->
- **Limited-use tool warnings.** Clearly warn before spending Ward and other
  limited-use abilities; show remaining uses and that spending one is irreversible.
  Current help and some labels already say "once per case", but the generic
  "Ward someone..." and promise paths do not consistently communicate the limit
  before selection/use. Cover direct targeting and promises; distinguish promising
  a tool from actually consuming it. (Oct 21) [decided; warning presentation open]

  > **Decided (user, Oct 26); Codex batch 3:** every Ward button shows what's left ("1 left, once per case"). Warding someone
  > directly from the UI asks for confirmation ("This spends your only ward. Ward X?"); the typed command
  > goes straight through. Promise text says a promise doesn't spend the ward; keeping it does.

  > **Implemented (Codex batch 3):** Every Ward UI path shows remaining uses, direct UI targeting asks the specified confirmation, and typed commands stay immediate. Promise wording distinguishes offering from spending. Focused checks cover labels, cancel, promises and typed consumption.

<!-- was in UI -->
- **Hide Unselected.** Add a case-board toggle to hide rows not explicitly selected
  by the active person/place filters. Keep this distinct from hiding evidence cards,
  showing hidden cards, and the currently focused card/profile; define the
  no-selection behavior and retain pinned-card/filter consistency.
  (Oct 21) [decided; edge cases open]

  > **Decided (user, Oct 26); Codex batch 3:** nothing selected: the toggle is disabled (with a tooltip). Several filters: show
  > rows matching any of them. Pinned cards on hidden rows stay visible. Hiding never removes cards or links.
  > (Selected-first ordering is already built: B110, BACKLOG_COMPLETED.md.)

  > **Implemented (Codex batch 3):** The row-only toggle reuses B110 selection/order exactly (confirmed in chat): people filters for person rows, places for place rows. It disables without that row selection, ORs selected rows, and preserves pins, cards and links. Focused layout/UI checks cover these cases.

<!-- was in UI -->
- **Long dropdowns in columns.** Once a dropdown exceeds roughly eight options,
  consider multiple columns: at most eight options per column for an uncategorized
  list, or columns grouped by existing categories. Example: the deduction planner's
  "is the <blank>" selector has about twenty options across roughly four categories.
  Prefer meaningful existing groups where available; exact threshold/layout remains
  open. Keep category labels, keyboard navigation, and screen bounds usable.
  (Oct 20) [tentative]

  > **Decided (user, Oct 26); Codex batch 3:** at most 8 options per column; group by the existing categories where there
  > are any, otherwise split evenly. Keep labels, keyboard navigation and screen bounds usable.

  > **Implemented (Codex batch 3):** Shared menu presentation keeps native IDs, indices, metadata and callbacks. Existing categories are retained; uncategorized groups split evenly with at most eight options per column. Both native dropdowns and handcrafted pickers fit in a scrolling screen-bounded popup. Focused checks cover grouping, disabled choices, arrows, bounds and selection parity.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **Last words.** A condemned NPC gets some final words before the hanging (flavour). (Oct 19) [decided]

  > **Decided (user, Oct 26); Codex batch 3:** one or two lines before the hanging (after Martyr substitution, so whoever actually
  > hangs speaks). With nothing left to hide they may claim a gift: good their true gift, evil their bluff;
  > and they name their top suspect (evil: the scapegoat, via the existing plan). Nothing reveals
  > alignment. The claim is an ordinary public claim card; execution and aftermath happen exactly once.

  > **Implemented (Codex batch 3):** After Martyr substitution is decided, the actual condemned speaks before death: true gift or existing bluff as an ordinary public claim, then top suspect or existing scapegoat. Silenced NPCs only try to speak (confirmed in chat). Readings remain withheld. Focused outcome tests verify ordering, substitution, silence and one-time execution/aftermath.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **Bot coverage of the new talk options:** the bot doesn't offer wards or vigils or ask
  about others to learn haunts, so bot runs don't measure them. [decided]

  > **Decided (user, Oct 26); Codex batch 3:** the bot offers wards/vigils, asks about others (haunts,
  > traits, relationships), answers NPC requests (confidence, protection), apologises and makes gift requests,
  > with simple rules, and its run summary counts each. `tools/` only; note that bot baselines shift.

  > **Implemented (Codex batch 3):** tools/autoplay.gd adds public-knowledge rules for offers, request answers, apologies, asking about people and gift requests, and keeps protection promises at night. Each new action is counted in printed/JSON summaries. Focused policy checks and a seed-4242 smoke game pass without guard exhaustion. Bot baselines will shift.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **The ward as evidence, and a visible save.** Your ward isn't a card today, and a ward
  that stops an attack leaves no sign. Make the ward a card (who, door, night) and let a
  held ward leave a mark (a scorched sigil) as physical proof the demon came to that
  door. Feeds the "Protection + quiet night + sighting" template gap. (user, Oct 23)
  [decided]

  > **Decided (user, Oct 26); Codex batch 3:** spending your ward makes a card (who, which door, which
  > night). If it stops an attack, the next morning you alone find a scorched sigil: a card saying the Demon
  > came to that door that night (player-only until shown). Presenting it: at the meeting, +0.05 trust with
  > every living NPC and +0.15 with the protectee; privately, +0.05 with the listener (+0.15 if it's the
  > protectee). Once per sigil, caps hold, evil reacts the same. No adapter for the shared model in this
  > batch (Claude adds it; the card is context until then).

  > **Decided (user, Oct 26); Claude batch:** the shared-model side (after Codex's cards): a held ward counts as a
  > Demon attack at that door that night, with the same route reasoning as a murder. No new weights.
  > Fills the "Protection + quiet night + sighting" template gap.

  > **Implemented (Codex batch 3):** Ward spending records person, door and night; an actual stopped attack yields a private next-morning sigil. Presentations reward each NPC once per sigil (confirmed in chat), +0.05 normally or +0.20 total for the protectee, with caps and equal evil handling. Cards are UI context only; no shared-model adapter or evidence numbers were added. Tests cover an actual save, private-then-public repeats, silent/evil listeners, caps and reset.

  > **Built (Claude, Oct 26):** the sigil becomes a Demon attack on the shared view's timeline (routes as for a murder; knell and Veteran nights checked); the ward receipt is context.

<!-- was in NPC behaviour -->
- **Case 44814: asking about an already disclosed gift.** Currently "are you the X?"
  repeats confirmation and consumes a question, without requesting withheld results;
  a profile role guess is private bookkeeping only. Decide whether the dialogue
  question should offer a useful route to the withheld readings or clearer feedback
  about asking for them. No automatic extra disclosure from recording a guess. [open]

  > **Decided (user, Oct 26); Codex batch 3:** "are you the X?" when they've already told
  > you they're the X is treated as "ask gift": same cost and rules, readings if they're willing. Not counted
  > as a wrong guess.

  > **Implemented (Codex batch 3):** Matching an already disclosed role routes directly to ask gift before fatigue is counted. Public/private and good/evil parity tests cover full replies, readings, trust, fatigue, wrong-guess count and RNG.

<!-- was in NPC behaviour -->
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

  > **Decided (user, Oct 26); Codex batch 3:** give the private disclosure roll (`_target_tier`'s
  > openness) the same gift-type terms the public-claim roll has: `one_shot_gift` +0.3, `gift_keeps_giving`
  > -0.4 (repeating info gifts, day <= 2), `hides_from_demon` -0.5 (non-info gifts), with the same conditions.
  > Drop "the player hears it first" for now. Approved disclosure tuning (user).

  > **Implemented (Codex batch 3):** Private openness adds only the approved +0.3 one-shot, -0.4 early repeating-info and -0.5 non-info terms under the public-roll conditions. All existing base terms, thresholds and the single jitter draw remain; focused good/evil role/day checks verify them.

<!-- was in 1. Bugs and quick fixes (hours, low risk) -->
- **A press with a sighting replayed the alibi word for word.** `present 48` to
  Constance (my vigil, against her "home") repeated "Home. Where else would I be?" and
  the same window sighting, behind a new lead-in, and cost a question. Pressing should
  change the story, harden it or stonewall in a new line. [decided]

  > **Decided (user, Oct 26); Codex batch 3, one item with the next two entries:** pressed with a sighting that contradicts
  > their alibi, nobody repeats the alibi word for word. A good person secretly out on gift business admits
  > it and tells their gift with the owned-lie line ("So yes: I was out…"; the reveal cost collapses, as at
  > the meeting). A good person who really was home stands firm with a new line. Evil gets a new line with
  > the same cover facts (wording only; no change to cover choices).

  > **Implemented (Codex batch 3):** Caught good gift walkers disclose through the existing gift/admission path. Home accounts, evil cover and refusals receive fresh deterministic wording; personal-secret and Sleepwalker choices remain unchanged (confirmed in chat). Paired checks preserve facts, fatigue, trust and RNG for wording-only cases. Broader evil Night Watch consistency stays open.

<!-- was in NPC behaviour -->
- **Replies must match beliefs.** (Claude, Oct 25; 54875 replay) Jory and Agnes accept
  case #85 numerically (their suspicion moves as if convinced) while their replies say
  they couldn't follow it. What an NPC says has to come from the same computation as what
  it believes (LEGACY_MIGRATION lesson 6). The scoped reply and the belief refresh are
  separate jury runs with different attention; decide which one owns the stance wording,
  or derive the reply's stance from the refresh's movement on the premise target.
  Overlaps "Accept is wording, not belief" above and reply-only Insight budgeting below.
  Fix before the next playtest is used to judge persuasion. [decided: direction; approach open]

  > **Decided (user, Oct 26); Claude batch:** the spoken stance comes from the belief refresh itself (how far
  > the target actually moved); the scoped reply only supplies the reasons. No belief changes, only
  > what they say.

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** `WorkshopPresentation._belief_stance_text`: the voiced
  > stance follows how far the refresh moved the subject (0.06 toward the claim: accept; 0.02: partly);
  > the scoped reasons stay; a retold case says it was already taken into account.

<!-- was in NPC behaviour -->
- **From playtest 54875: evil frames should cohere.** Constance's private night-1 story
  ("I saw Isolde", from the alibi-hiding window sighting) and her public Night Watch
  reading ("I saw Jory") came from separate generators and conflicted; that crack is
  what unravelled her. Decide whether it's a deliberate crack or should come from one
  plan per scapegoat per night that every bluff draws from. Likewise a side frame
  through one gift (an Archivist or Rumormonger pair) shouldn't be undercut by invented
  night walks aimed at someone else. (user, Oct 23) [open]

  > **Decided (user, Oct 26); Claude batch:** one night-story per evil member per night, shared by private answers,
  > public readings and frames; old reports are never rewritten. Natural cracks remain (a changed
  > scapegoat; teammates covering a night separately). A bug fix, not tuning. Fixes the `test_social`
  > failure (section 1).

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** an evil member's made-up night sighting repeats that
  > night's own fake watch report (`Evil.fake_night_sighting`). test_social passes (its check predated the
  > watch-result disclosure gate).

<!-- was in 1. Bugs and quick fixes (hours, low risk) -->
- **Case 44814: inconsistent pair-reading defenses.** NPCs can both redirect a
  reading toward the other candidate and declare its source a liar, with separate
  mechanical effects. Choose one explanation, or explicitly frame alternatives
  without awarding both as independent defenses. [decided]

  > **Decided (user, Oct 26); Claude batch:** one incident, one hearing: the NPC picks the explanation that best fits
  > what it knows (redirect to the other person, or the source is lying); the other, if said at all,
  > is wording only.

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** one hearing per incident (`Mind.defend_self`).

<!-- was in 1. Bugs and quick fixes (hours, low risk) -->
- **Related inconsistency:** legacy honesty doesn't exempt demon victims. Evidence
  against Dorian (Constance's frame that he was out on night 0) still lowered how
  much listeners credited his own word after his death, while his suspicion said
  "known good". Decide which one wins. [open]

  > **Decided (user, Oct 26); Claude batch:** death settles sincerity: a known-good victim wasn't lying, so
  > evidence against them no longer lowers how far their word is credited. Accuracy stays doubtable
  > (poisoned readings). A consistency fix, no new numbers.

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** Demon victims are exempt from honesty discounts (`Mind._honesty`
  > `settled`).

<!-- was in 1. Bugs and quick fixes (hours, low risk) -->
- **Rumormonger as the sole modifier holder.** The gift excludes its own holder from
  its candidate pool. When a healthy Rumormonger is the sole Marked or Sleepwalker,
  the current fallback produces an arbitrary false pair/secret instead of useful
  information. Decide whether it should explicitly report no valid result or whether
  setup/gift rules should change. This needs coordinated reading/UI/belief handling;
  do not silently assume a healthy report always identifies someone else. The live
  comparison currently preserves the native fallback, with a generator-backed test.
  Found during Oct 22 integration. [open]

  > **Decided (user, Oct 26); Claude batch:** a setup rule: the secret is never given to the Rumormonger unless it's
  > Lovers (which always involve someone else); the solver's world domain learns the rule. No
  > "no result" reading.

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** `World._assign_secret_mod` and `WorldDomain.rumor`.

<!-- was in UI -->
- **Find Links and Hints inside the Case Workshop.** (user, Oct 25) The case board's
  right-click Find Links and Hints were removed with the old Build case builder: both
  were template helpers that wrote into that panel. Bring the idea back in the Workshop
  as "what connects to this card?" using the shared model (which cards bear on a
  premise, which would merge into a contradiction), not the old template library.
  [decided: direction; design open]

  > **Decided (user, Oct 26); Claude batch:** a "Connections" button on a Workshop card, on demand (no live cost):
  > up to 5 board cards bearing on the same premise, ranked by how far each would move it, contradicting
  > ones marked; one click adds a card.

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** `WorkshopCanvas.connections` and the Connections
  > button in a premise's details.

<!-- was in 1. Bugs and quick fixes (hours, low risk) -->
- **`tools/test_social.gd` fails on main:** "a false Night Watch's night story matches
  their fake report (20 cases)". It passes on `claude/case-reasoning` and fails on main
  since the 61251/25923 pass, so the merge carries it. It's the same family as
  Constance's two night-1 stories (private "Isolde", public "Jory"); fix together with
  "evil frames should cohere" in section 2. All 45 test scripts were run on the merge
  (Godot 4.4.1 headless); this is the only failure. [decided]

  > **Built (Claude, branch `claude/batch-oct26`, Oct 26):** fixed with "evil frames should cohere".

<!-- was in Template gaps (NYI) -->
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

  > **Built (Claude, Oct 26):** via the scorched sigil (see "The ward as evidence" in BACKLOG_COMPLETED.md).

## Closed Oct 26, 2026

<!-- was in 3. Medium features -->
- **Claims/reveals timeline** next to the location timeline. (DESIGN) [open]

  > **Closed (user + Claude, Oct 26):** already covered by the case board's Statements view (claims,
  > hints, refusals, home claims, opinions, accusations per person over time). The one gap, telling
  > a claim told only to you from a public one, has a hook (`CardModel.disclosure_scope`) and waits on
  > "Case board visuals" in BACKLOG.md.

## Built Oct 25, 2026 (NPC interactions and Codex batch 2)

Built on `npc/interactions` (Claude) and `codex/backlog-batch-2` (Codex), both merged into main on
Oct 25 after review. Full suite at merge: 78/79 suites passed, the one failure being the known
`test_social`; `test_text_ui` now passes. New suites: `test_npc_interactions`, `test_backlog_batch2`,
`test_evidence_context`.

<!-- was in 1. Bugs and quick fixes (playtest 54875) -->
- **Wording: a claimed walker's sighting told "from my window".** [decided]
  > **Implemented (Codex batch 2, Oct 25):** wording only, in `Evil` fake sightings (around line 888): a
  > claimed walker tells a sighting as seen while out on their duty, and every fake sighting
  > names its night like real ones do. No change to who evil frames or when.
  > **Batch 2 item 2:** `Evil.bluff_reason` dates fake-sighting reasons and uses
  > duty wording for an already claimed walker. Cached sightings, available frames,
  > their selection and RNG use are unchanged; focused regression checks cover each.

  A claimed Night Watch says "I watched the Market…" and then "I saw them … from my
  window": a walker's sighting should be told as seen while out.
  (The other wording lines in this entry were fixed Oct 25; see BACKLOG_COMPLETED.md.)

<!-- was in 1. Bugs and quick fixes (playtest 54875) -->
- **`tools/test_text_ui.gd` fails on main (two role-hover checks).** Known failure since
  at least Oct 24. Find whether the checks or the UI are wrong; fix the test if it's stale,
  or the hover if it's a real bug, and report which. [decided] (Implemented in Codex batch 2, Oct 25.)

  > **Batch 2 verification:** stale headless fixture, not a UI hover bug. The old test laid out
  > the profile around x=1395 in a 64x64 viewport, and `Viewport.push_input` left the hover
  > pointer at (0, 0). Use a 1920x1080 viewport and `Input.parse_input_event` with real pointer
  > coordinates. All original assertions remain, plus viewport/pointer checks; the suite passes.
  > Full default runs require `test_text_ui` green from this item onward.

<!-- was in 1. Bugs and quick fixes (hours, low risk) -->
- **Fear barely changes from day to day.** `Mind._afraid` rolls on `hash(id + ":" + day)`, but
  Godot's string hash changes only in its low digits when the last character changes, so the
  roll is near-constant for a person across the whole case (e.g. 0.066, 0.067, 0.068 on days
  0-2). "Ask me again when it's safer" is effectively never true. Fix: mix the hash (e.g.
  `hash(str(hash(id)) + ":" + str(day))` or a seeded RNG per person and day). Changes
  trajectories, so do it with the balance pass. (Oct 25, found building protection requests)
  [needs decision: fix now or with the balance pass]

  > **Fixed (Claude, Oct 25, at merge; user decision):** the roll now mixes the person and day
  > properly (`Mind._day_roll`), and fear is tied to pressure and paranoia instead of rising with
  > the dead: `Mind.fear_chance` = 0.2 + 0.3 x (1 - Composure) - 0.5 x Pressure - paranoia,
  > halved after a kept ward/vigil promise, clamped 0-0.85. Pressure: keep withholding and they
  > risk being falsely accused. Paranoia: the town opens up as the dead pile up.

<!-- was in NPC behaviour -->
- **A genuinely neutral opinion.** Add "I'm not sure what to think" between trust
  and suspicion for both good and evil NPCs. `answer_opinion` has several suspicion
  bands, but its middle replies still choose between "seems all right" and
  "something's off"; distinguish uncertainty from a refusal or a veiled accusation.
  Do not create incriminating opinion evidence solely from neutrality.
  (Oct 21) [decided; boundaries/wording open]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** in `Mind.answer_opinion`'s 0.25-0.45 band, keep the existing
  > "something's off" roll; when it doesn't fire, say "seems all right" below 0.35 and "I'm not sure
  > what to think of X yet" from 0.35. Wording only: no change to levels, the roll, what's logged or
  > any evidence (opinions aren't evidence). Same for good and evil.

  > **Prep B052 (9cb8782; open):** `sim/mind.gd::answer_opinion` currently chooses reassuring/suspicious
  > wording after willingness gates. Add a neutral perceived state; test uncertainty and middle suspicion
  > without exposing hidden alignment or turning an opinion into evidence.

  > **Batch 2 verification:** the non-suspicious reply now says "I don't really know X that well"
  > from 0.35, per the user clarification. Both alignments retain the original roll, levels and facts;
  > focused boundary/RNG checks cover 0.34, 0.35 and 0.44.

<!-- was in NPC behaviour -->
- **Explain distrust of the player.** Good and evil NPCs with low player trust should
  be able to say so and, where remembered, cite the reasons: misguided executions,
  accusations, nominations, votes or broken confidences/promises. Use their known
  history and beliefs, with the same presentation options for evil; a refusal alone
  should not be the only signal. Coordinate with apologies and vote-resistance
  feedback. (Oct 21) [decided; delivery/frequency open]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** when an NPC's trust in the player is low (below 0.35) and
  > they refuse the player something (gift, opinion, whereabouts), add one line citing the player
  > action that cost the most trust that they remember (from the reasons already passed to
  > `Mind.set_trust`: a wrong guess, a broken promise, a nominated friend...). At most once per NPC
  > per day. Only the player's own actions are cited, so nothing hidden leaks; evil uses the same
  > rule. Wording only: no new trust change.

  > **Prep B053 (9cb8782; open feedback):** `sim/mind.gd::_vote_impl`, `word_factor`, and `card_weight`
  > already use player trust. Surface relevant resistance through dialogue; distinguish distrust of
  > testimony from dislike of execution. Explaining an existing penalty should not create a new one.

  > **Batch 2 verification:** presentation memory records the strongest actual trust loss for a
  > recognized player action. Gift/opinion/night refusals explain it at most once per NPC/day,
  > using safe action wording or the outsider fallback; no arbitrary private reason is quoted.
  > Focused tests cover both alignments, clamping, all three refusal paths and the daily limit.

<!-- was in NPC behaviour -->
- **Medium visits only Demon victims.** Restrict the gift's eligible dead to people
  killed by the Demon, and update role descriptions, dialogue, target selection
  and real/fake report consistency. Current `_medium_choice` considers every
  unvisited dead person; a same-day tie favors Demon victims, so the requested
  restriction is not implemented. Coordinate with the existing director-driven
  visit proposal and keep misleading results possible. (Oct 21) [decided]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** eligible hearths are Demon victims only. On a night with no
  > unvisited Demon victim, the Medium revisits the most recent Demon victim's hearth (so a real
  > Medium still walks every night after the first kill, as the movement model expects) and learns
  > something new if that person still has unrevealed information; otherwise "nothing they hadn't
  > already told us". Before any Demon kill, no visit (as today). Update the gift text, `World._medium_choice`,
  > `World._medium_item` and the fake Medium (`Evil._fake_medium_item`) so fakes only name Demon
  > victims too. Tests: executed dead never visited; revisit when none are unvisited; a revisit can
  > still surface an untold reading; fakes match.

  > **Prep B054 (9cb8782; open):** `sim/world.gd::_medium_choice` considers all unvisited dead, sorted by
  > recency with same-day Demon-victim preference. Apply the eligibility decision to fake Medium paths
  > too; test executed dead, equal-day ordering, and exhausted eligible hearths.

  > **Batch 2 item 1:** real and fake visits share public Demon-victim eligibility,
  > visit unvisited hearths first, then revisit the latest. Untold readings still surface;
  > exhausted hearths report nothing new. Fake-hearth eligibility was explicitly authorized
  > in chat; fabrication/frame weights remain unchanged. The role description and old
  > once-only fixture now reflect the approved revisit policy.

<!-- was in NPC behaviour -->
- **Offering protection eases fear.** Someone you've offered your ward or a vigil (and
  kept your word to) should be less afraid to say what they are. (96773) [decided]

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** one feature with "The fearful ask for protection". A kept
  > ward/vigil promise halves the fear term in that NPC's disclosure for the rest of the case.

  > **Prep B069 (9cb8782; open; promise overlap):** `game/game.gd::_offer_command`/`_settle_offers` track
  > promises. Base fear relief on what the NPC heard, keyed once per promise; an offer neither spends a
  > ward nor proves a successful save.

<!-- was in NPC behaviour -->
- **The fearful ask for protection.** NPCs afraid their gift makes them a target appeal
  to the Demonologist (a ward, a vigil) and/or the Warden for protection, instead of
  only clamming up. Ties into offers easing fear. (Oct 19) [decided]

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** asking is free to hear and answer (yes becomes the usual
  > vigil/ward promise); no conversation lock-in. In conversation, where they'd give the fear
  > refusal, they may ask instead. A trust x Composure roll decides whether they tell their gift on
  > the promise alone; otherwise the next day, after the promise is kept, they approach the player
  > for free to tell at least their gift (readings if their usual willingness allows). While a
  > promise is pending, their public-claim roll is harder unless they're under serious pressure (a
  > nomination). Broken promise: the existing trust loss, and the fear returns. Evil uses the same
  > flow as cover, except evil that walks at night (Demon, Poisoner) never asks for a vigil unless
  > it bluffs a night-walking gift. Gossip/frame approaches become a free teaser; following up
  > spends the phase as before.

  > **Prep B071 (9cb8782; open):** Add bounded requests through meeting/approach dialogue, reusing
  > `game/game.gd::_offer_command` settlement. Keep requests based on perceived danger; do not reveal
  > secret targets or real gifts just to make the request available.

<!-- was in Social tuning and evidence follow-ups (Oct 20) -->
- **Town knowledge of friends and rivals.** NPCs should know other people's public
  friendships/rivalries and sometimes disclose them in the same style as haunt
  locations. Separate that knowledge from exact private trust scores and hidden Lover
  status. Track which relationships the player has learned; avoid duplicate reveals.
  Add conversational wording and useful attribution. [decided; sharing rates open]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** a profile note only, no board card (the shared model can't
  > read relationship cards). Every rolled friendship and rivalry counts as public town knowledge;
  > Lovers stay secret. Learned the same way and at the same chance as haunts, when the player asks
  > someone about a person, and attributed ("Agnes says Hollis and Merrin are close"). Track what
  > the player has learned; no duplicate reveals; never show trust scores.

  > **Prep B097 (9cb8782; open):** `sim/world.gd::_assign_relationships` stores true relationships, not
  > player knowledge. Add attributed learned facts alongside `sim/mind.gd::reveal_trait`/social
  > disclosures; never render private bond scores or hidden Lovers directly from setup arrays.

  > **Batch 2 verification:** public setup bonds are captured before secret Lovers can add a
  > friendship. Asking about a person uses the haunt disclosure chance and records attributed
  > notes on both profiles, once per bond, with no cards or trust scores. Focused checks cover
  > chance, attribution, duplicate prevention, reset and secret-added bond exclusion.

<!-- was in Social tuning and evidence follow-ups (Oct 20) -->
- **Warn about repeated role guessing.** Before the player continues the escalating
  wrong-guess/patience spiral, have the NPC say something like "Clearly you're just
  grasping at straws, and I'm running out of patience." Make the warning communicate
  their patience without revealing whether a particular bluff/guess is true. Keep
  conversation slots, daily fatigue, and the across-days wrong-guess counter distinct.
  [decided; warning cadence open]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** on the second wrong guess to the same NPC, the reply is the
  > patience warning ("You're grasping at straws, and I'm running out of patience."); from the
  > third, the existing "Why do you keep asking me that?". Wording only: costs and counters
  > unchanged, and the warning never confirms or denies the guess.

  > **Prep B100 (9cb8782; partial):** `sim/social.gd::answer_is_role` already counts wrong guesses and
  > gives a generic repeat response. Add anticipatory patience wording without confirming a guess;
  > distinguish slots/fatigue from this counter and private `game/game.gd::set_guess` guesses.

  > **Batch 2 verification:** the second-guess non-answer warns about patience; first and
  > third-onward replies, costs and counters retain their existing behavior. Focused checks
  > cover both alignments, all three replies, unchanged costs, facts and RNG.

<!-- was in UI -->
- **Mark circumstantial evidence visually.** (user, Oct 25) Circumstantial or
  vibes-stage case items (co-location with the silenced, demeanour, votes as soft
  evidence, pattern-based support) should look different from hard-logic items:
  readings, sightings and claims the evaluator checks against each possible world. At
  least a different colour on the board, in the case builder and in the preview, so the
  player can tell how a case is made up. [decided]

  > **Decided (user, Oct 25); implemented in Codex batch 2:** circumstantial means the cards the shared model treats as
  > context that can't establish guilt alone: those whose live adapter is `context` or `location`
  > (`game/workshop_canvas.gd::view` already labels them "location context; this does not establish
  > guilt"). Everything else the model reads is hard logic. Mark them with a shape, not only a
  > colour: a dashed border plus a small "context" tag, on the board, in the Card List and on
  > Workshop cards, with a tooltip explaining it. Reads the existing adapter result; no judge change.

  > **Session scope 2026-10-25 (B108):** Skipped: the proposed action-factor/vibes-stage split is
  > still a listed design decision and is not a reliable existing display classification. Adding
  > that semantic boundary would require protected evaluator changes; legacy card class is not
  > substituted for it.

  > **Prep B108 (9cb8782; open UI):** `game/card_model.gd`, `game/board_model.gd::layout`,
  > `ui/board_view.gd`, and `ui/card_list.gd` share rendering inputs. Define a visible evidence-class
  > marker with source/time detail; circumstantial is not unsupported, and color alone should not
  > communicate the distinction.

  > **Batch 2 verification:** `ui/evidence_context.gd` reads the existing live adapter result.
  > Board cards/dots, all Card Lists and Workshop evidence cards show dashed borders, a
  > context tag and an explanatory tooltip. Classification is built once per library refresh;
  > evidence identities, judge inputs and simulation randomness are unchanged.

<!-- was in 3. Medium features (several days; touch a few systems) -->
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

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** incidents are the reasons already recorded on that
  > NPC's trust drops. Once per incident: repairs half the trust lost for a minor incident, a quarter
  > for a serious one; a high-Insight NPC forgives less when the player had evidence against what they
  > did. No suspicion is withdrawn; permanent caps hold.

  > **Prep B117 (9cb8782; design):** `sim/mind.gd::set_trust`/`cap_trust` and
  > `game/game.gd::_settle_offers` lack a general apology incident ledger. Record perceived
  > harm/responsibility/repair once; a positive delta cannot restore a permanently lowered ceiling
  > without a recovery policy.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **Suggest actions based on claimed role:** ask a Warden to protect a person, a
  Seer to check a person/pair, or a Night Watch to watch a block. Track request,
  response/commitment, intended action, actual action, and follow-up separately.
  Trust, Confidence, Composure, danger, competing priorities, and the NPC's
  relationship with the requested target can affect compliance; allow refusal
  or a counterproposal. (Target relationship added Oct 21.) Offer the same dialogue to evil
  bluffers, who can lie about compliance/results, so requests do not verify roles.
  Exact trait interactions remain open.

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** Seer (check a person or pair), Warden (guard
  > someone), Night Watch (watch a block), asked of someone who claimed the gift to the player. Costs a
  > question; private only (asking at the meeting waits for the meeting-flow work). Agree, refuse or
  > counter-propose from trust, the target relationship and their own preference; an agreed request
  > replaces their pick for that night only. Evil bluffers get the same surface and fake results.

  > **Prep B118 (9cb8782; design):** Use `game/game.gd::_offer_command`, `sim/world.gd::_receive_info`,
  > and `sim/evil.gd::make_fake_info`. Keep heard/accepted/acted/reported states separate. Hidden
  > actual compliance must not become a dialogue role-verification oracle; bluffers need the same
  > request surface.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **Promise confidentiality:** one straightforward promise option that can support
  private disclosure, with consequences for keeping or breaking it. Avoid a
  negotiation tree or multiple branching confidentiality terms; coordinate with
  existing confidence/secret-keeping rules rather than awarding duplicate credit.

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** an NPC request, not a player offer. Asked something they'd
  > withhold, a nervous NPC may say "I'll tell you, but only if you promise not to reveal it yet." Yes
  > or no is free. Cards from that answer are confidential; using one at a meeting breaks the promise.
  > One penalty for all confidential cards (including "ask why"): 0.05 + 0.2 x Privacy (0.05 open,
  > 0.15 typical, 0.25 very private). The promise lapses when they go public. Private use stays allowed.

  > **Prep B125 (9cb8782; design):** `game/game.gd::_disclose`/`_break_confidences` and
  > `sim/mind.gd::end_of_day_trust` already handle confidence consequences. Add one explicit
  > promise/settlement identity; avoid duplicate daily reward/loss for the same protected disclosure.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **Learn personality through other NPCs.** Asking about someone can reveal one of
  that person's traits and unlock its actual score in their profile, using the
  existing learned-trait presentation. Example: Agnes calls Bartholomew stubborn,
  revealing Confidence. Filter descriptions through the speaker's relationship:
  a confident friend is "principled", a rival "pigheaded". Separate the revealed
  trait/score from that subjective wording, and define which traits the speaker
  can reasonably know and how often this occurs. Coordinate with public
  friends/rivals and haunt disclosure; do not reveal hidden relationships.
  (Oct 21) [decided; discovery rules open]

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** opinion answers sometimes reveal one trait,
  > unlocking its bar in the profile. Friends can reveal any trait; others only the observable ones
  > (Privacy, Gossip, Confidence, Composure). Wording follows the relationship (friend "principled",
  > rival "pigheaded").

  > **Prep B126 (9cb8782; open):** `sim/mind.gd::reveal_trait` and profile rendering supply the target
  > surface; `sim/mind.gd::answer_opinion` is a possible route. Define speaker knowledge before numeric
  > trait reveals; subjective wording must not expose private bonds/Lovers.

<!-- was in 3. Medium features (several days; touch a few systems) -->
- **Lovers downside:** when one dies, the other becomes withdrawn: Privacy to max,
  Gossip to min, and whichever other shifts hurt the player most (e.g. Composure up so
  they're harder to read). Visible, so the player can notice the change. [decided]

  > **Decided (user, Oct 25); built (Claude, branch npc/interactions; move to BACKLOG_COMPLETED on merge):** Lovers only (the friends version is tabled): Privacy max, Gossip
  > min, Composure up, with a profile note. Revealing the Lovers this way is acceptable.
  > 
  > [knob] Evil could fake a bereavement withdrawal; a balance knob, not planned.

  > **Prep B139 (9cb8782; open; distinguish grief):** `sim/world.gd::_grief` applies resentment/caps but
  > does not generally maximize Privacy/minimize Gossip. Decide persistent traits and visibility
  > separately; a visible bereavement shift should be a clue, not guaranteed hidden-Lover verification.


## Verified Oct 25, 2026

Fixed in Codex's small-fixes session (`codex/backlog-small-fixes`, merged into main) or found already
fixed on main. Each closure was checked by Claude against the code and the tests cited in its notes,
with the full test suite passing apart from the two known failures (`test_social`, `test_text_ui`).
Not closed after checking: B122 (withdraw or revise a case). The withdrawal Codex tested is the
developer tool in the Debug menu, not a player-facing retraction. Also not closed: B181 and B200
(partial, per Codex), the rest of B036, and B008.

<!-- B002 · was in Section 1, bugs and quick fixes -->
- **Case 44814: relayed role claims in the cast list.** Hearing a claim through
  another NPC should appear as an attributed hearsay claim, distinct from direct or
  public disclosure. Do not silently turn a relay into a direct confirmation. [decided]

  > **Session 2026-10-25 (B002): implemented; closure proposed.** The cast list now
  > shows player-known relayed claims with a `~` hearsay marker and a tooltip naming
  > the relayer. Direct/public disclosure takes precedence; hidden NPC knowledge is
  > not consulted. `test_town_ui` checks attribution, deletion, promotion, and no
  > mutation of role disclosure, evidence, or RNG. Full runner: 73/75 suites passed;
  > only the permitted `test_social` and `test_text_ui` failures. Entry retained for review.

  > **Prep B002 (9cb8782; open):** `sim/social.gd::answer_about_role` carries `via`;
  > `ui/cast_list.gd::_claimed` reads direct disclosure only. Reuse
  > `ui/profile_panel.gd::_render_entries` history. Check hearsay, direct confirmation, and public
  > promotion without losing attribution.

<!-- B004 · was in Section 1 -->
- **Voting text when a block already exists.** Replace the generic majority message
  with the actual replacement/tie counts in both the nomination prompt and meeting
  view: "X to put [nominee] on the block instead of [current nominee]; X-1 to tie
  (no one will be executed)." Use the recorded highest vote count plus one for X,
  subject to the normal minimum. Also handle an empty block after an earlier tie,
  where the high count still matters. Current UI and text prompts still display
  only `vote_threshold()`; voting logic already distinguishes these outcomes.
  (Oct 21) [decided]

  > **Session 2026-10-25 (B004): implemented; closure proposed.** The prompt and
  > meeting tally share read-only replacement/tie wording, including the empty block
  > after a tie. The tally captures requirements before counting and wraps inside
  > the panel. `test_ui` checks initial, replacement, post-tie, and unchanged state/RNG.
  > Voting and nomination formulas are unchanged. Full runner: 73/75 passed, with
  > only the permitted `test_social` and `test_text_ui` failures.

  > **Prep B004 (9cb8782; open):** `sim/world.gd::vote_pending` retains `block_count` even after a tie
  > empties the block. Share replacement-count logic between `game/game.gd::_show_nomination` and
  > `ui/meeting_view.gd::_draw_tally`; check initial, replacement, tie, and post-tie votes.

<!-- B006 · was in Section 1, from playtest 54875 -->
- **The case workshop's evaluator never ran in play.** Every presentation fell back to
  the legacy argument rules (`workshop_delivery`: "could not use the shared
  assessment"). `Shared.prepare` refuses to take over a listener's legacy ledger when
  an entry it would own has touched someone at suspicion 0.0 or 1.5 ("Saturated legacy
  beliefs need a reversible baseline") or was clipped. Demon victims sit at 0.0, and
  Constance's night-0 reading named Dorian, so every listener was blocked from the Day 2
  meeting on. This will happen in most games. [decided]

  > **Session verification 2026-10-25 (B006):** Verified test_legacy_migration: saturation no
  > longer prevents shared ownership. Propose closure of the takeover/saturation failure. Full
  > default runner: 73/75; only permitted test_social/test_text_ui failures.

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

    > **Session verification 2026-10-25 (B007):** The victim-exemption patch is superseded by
    > reversible storage. Propose retiring this historical workaround; finite death evidence is
    > retained. Full default runner: 73/75; only permitted test_social/test_text_ui failures.

    > **Prep B007 (9cb8782; superseded proposal):** Do not add this exemption: unclamped storage
    > already addresses reversibility. Death is finite evidence in
    > `workshop/live_assessment.gd::activity_card`, consistent with the agreed 95:5 interpretation; the
    > old certainty assumption is stale.


  - **Real fix:** the check exists because suspicion is a clamped running sum: each
    recompute applies differences to a value clamped to [0, 1.5], so removing an entry
    can't restore the value it had before the clamp. Keep the unclamped sum (base +
    contributions) and clamp only when reading it; then any entry can be removed
    exactly, and the reversibility checks, the "clipped" flag and the fallback can go.

    > **Session verification 2026-10-25 (B009):** Verified exact withdrawal beyond both display
    > bounds and victim counterevidence. Propose closure of unclamped-storage work; no belief
    > implementation changed. Full default runner: 73/75; only permitted test_social/test_text_ui
    > failures.

    > **Prep B009 (9cb8782; candidate to close):** `sim/mind.gd::adjust`/`susp` implement unclamped
    > storage and clamped reads. Validate withdrawal/recompute reversibility in
    > `tools/test_legacy_migration.gd`; do not build a second baseline scheme.

  - **No silent fallback (decided Oct 23, at least while testing).** If the evaluator
    can't take a case, block the submission and say why, in the preview and at
    presentation. Never quietly run the legacy rules instead. `_present` has three
    silent `return {}` exits; until they're gone, log which one fired.

    > **Session verification 2026-10-25 (B010):** test_legacy_migration._strict_submission
    > verifies blocking without spending the floor/statement or leaking facts. Propose closure of
    > the core silent-fallback bug; UI wording is covered by B036. Full default runner: 73/75;
    > only permitted test_social/test_text_ui failures.

    > **Prep B010 (9cb8782; partial):** `game/game.gd::_presentation_gate` blocks unsupported normal
    > submissions, with explicit unsupported-conclusion/disabled routes. Audit current
    > readiness/preview labels before changing old exits; the hybrid intentionally keeps native social
    > behavior.

  - The preview judges a neutral reference listener, so it showed "accept 1.000,
    Constance +0.450, Edda +0.450" while the real listeners got about +0.10 from the
    legacy rules. The preview should judge with the real listeners' ability to run.

  > **Closure check (Claude, Oct 25):** Verified (Claude, Oct 25): shared ownership takes over saturated listeners (no saturation gate remains in the code); unclamped storage with clamped reads (`Mind.adjust` / `Mind.susp`); presentations never fall back silently (blocked with reasons, MECHANICS_SUPPORT item 7). The victim-exemption quick fix is superseded, not built. The preview point is settled by decision: strength is judged by a neutral test juror by design, and per-listener readiness is shown separately. Sub-item B008 (demon victims' honesty) stays open in BACKLOG.

<!-- B011 · was in Section 1, from playtest 54875 -->
- **Revising a case makes it weaker.** Re-presenting a revised case retires the old
  entry (`_workshop_retract`), then the legacy `Argue.evaluate` applies novelty:
  `used_facts` (per listener, keyed fact>target, set by any earlier argument or direct
  tell, never cleared) counts each previously used fact at 0.35. The richer case
  replaced the old one at a lower weight (Hollis 0.128 → 0.105 → 0.091 as the case grew
  from 2 to 4 to 6 reports). A revision is the old case plus new support: old facts keep
  what they earned, new facts count in full, and only an identical re-presentation is a
  repeat. The ledger reason also keeps the first version's text ("2 original reports").
  [decided]

  > **Session scope 2026-10-25 (B011):** Normal shared revision parity is verified with B012. Any
  > separate disabled/native novelty retuning is skipped because belief/suspicion behavior is
  > outside this session.

  > **Prep B011 (9cb8782; partial):** `game/workshop_canvas.gd::file` and
  > `tools/test_legacy_migration.gd::_revisions_and_repeats` cover preserved support on shared
  > revisions. Native `sim/argue.gd::evaluate` has separate novelty semantics; identify the actual
  > delivery path before declaring this entirely unresolved.

  > **Closure check (Claude, Oct 25):** Verified for normal play: every presentation goes through the shared model, where a revision equals a fresh hearing of the complete support. The native novelty rule only runs with the shared evaluator switched off (Debug).

<!-- B012 · was in Section 1, from playtest 54875 -->
- **A revised case gets a new card number,** so it sorts to the top of the newest-first
  lists; the old version stays, marked superseded. [decided]

  > **Session 2026-10-25 (B012): completed; closure proposed.** Existing filing
  > already preserves numbers and heard versions. Card List/working-set rows now
  > label both “revision of #N” and “superseded by #N”; current lists are newest
  > first. `test_board` checks readable immutable history; `test_legacy_migration`
  > and `test_workshop_live_canvas` verify preserved strength and heard revisions.
  > No filing, novelty, belief, or ownership implementation was changed. Focused
  > checks: 3/3. Full runner: 73/75; only the permitted two failures.

  > **Prep B012 (9cb8782; candidate to close):** `game/workshop_canvas.gd::file` allocates a new card
  > with `revises`/`superseded_by`; migration tests assert preserved numbers. Check newest-first lists
  > and labels. Never mutate a version already heard by NPCs.

<!-- B013 · was in Section 1, from playtest 54875 -->
- **Defence moves stack every day.** They're keyed `def:<id>:<day>:<move>`, so the
  same plea ("look at the other one in the pair", "it's a lie") was counted again at
  each meeting (-0.03 and -0.025 per listener each time), while accusations fade about
  0.05 a day. One entry per move per nominee, refreshed and fading like accusations.
  [decided]

  > **Session verification 2026-10-25 (B013):** Native test_defence_repeats and shared
  > test_mechanics_defences verify stable cross-day identity, strongest complete hearings, and no
  > repeat stacking. Propose closure of the day-key sub-bug only. Full default runner: 73/75; only
  > permitted test_social/test_text_ui failures.

  > **Prep B013 (9cb8782; partial; stale diagnosis):** `sim/mind.gd::defend_self` now keys
  > person/scope/canonical hash without day. Verify refreshed hearing strength and repeats; the
  > separate shared-defence/alternative-choice work remains open, but deleting a day key is no longer
  > needed.

<!-- B014 · was in Section 1, from playtest 54875 -->
- **Free repeats.** A card the listener already heard is free once per conversation
  (`free_repeats`); the second repeat costs a question. Presenting costs a question
  unless the listener has already heard it, which is the rule the user wants, but the
  reply doesn't say so ("You've heard this from me already"), and the free repeat
  still re-runs the argument. Hollis's `present 119` was the second repeat and cost
  his last question with no explanation. When the earlier hearing was public, say so
  ("I heard you say that at the meeting"). [decided]

  > **Session verification 2026-10-25 (B014):** test_legacy_migration verifies public-hearing
  > acknowledgement, one free repeat, no repeated judge work or belief/trust/RNG change, and
  > second-repeat cost. Propose closure; no repeat accounting changed. Full default runner: 73/75;
  > only permitted test_social/test_text_ui failures.

  > **Prep B014 (9cb8782; partial):** `game/game.gd::_talk_command` already tracks per-conversation
  > `free_repeats`. Explain private/public earlier hearings while preserving the second-repeat cost;
  > migration tests should also confirm a free replay adds no shared effect.

<!-- B015 · was in Section 1, from playtest 54875 -->
- **Own gift, "ask about <gift>".** A holder who declines to own up falls through to
  "I couldn't tell you who the Archivist is" (`Social.answer_about_role`), which is a
  lie about their own gift. Use the refusal line ("That's not for me to say"). Dorian,
  day 1. [decided]

  > **Session 2026-10-25 (B015): implemented; closure proposed.** If the existing
  > disclosure roll declines, the final empty-answer wording refuses rather than
  > claiming ignorance about the holder's own gift. Chance, knowledge sharing,
  > question cost, and facts are unchanged; `test_fixes` covers declined disclosures.
  > Full runner: 73/75 passed, with only the permitted two failures.

  > **Prep B015 (9cb8782; open):** The own-holder decline branch in `sim/social.gd::answer_about_role`
  > can fall through to generic ignorance. Use a refusal without disclosing the actual gift; check
  > repeated-question wording too.

<!-- B018 · was in Section 1, from playtest 54875 -->
- **Repeated stonewalls.** Isolde's press and the following `ask night` got the same
  line and the same card (#96): two questions for nothing. A second identical refusal
  should escalate ("I told you already…") or cost no question. [decided]

  > **Session 2026-10-25 (B018): implemented; closure proposed.** Generic voices
  > now acknowledge a second same-night refusal (“I told you already”), scoped to
  > its audience and approved statement. Authored voices, question costs, refusal
  > facts, trust, beliefs, and RNG are unchanged. `test_dialogue` covers repeat,
  > new-night, other-listener, and unauthorized-context cases. Full runner: 73/75
  > passed, with only the two permitted failures.

  > **Prep B018 (9cb8782; partial):** `sim/mind.gd::whereabouts_refusal` uses dialogue memory, while
  > repeat costs live in `game/game.gd::_talk_command`. Test ask/press/ask sequences; wording variation
  > alone does not fix paying twice for identical information.

<!-- B019 · was in Section 1, from playtest 54875 -->
- **Missing and duplicate cards.**

  > **Session verification 2026-10-25 (B019):** Verified reticent whereabouts in
  > test_playtest_regressions and private/relay/public history in test_board. Added dated-sighting
  > and public-holder confidence checks. Propose closure of the listed card examples; spoken dates
  > were fixed in B020. No disclosure/trust implementation changed. Full default runner: 73/75;
  > only permitted test_social/test_text_ui failures.

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

<!-- B020 · was in Section 1, from playtest 54875 -->
- **Wording.** [decided]

  > **Session 2026-10-25 (B020): wording fixed; closure proposed for these lines.**
  > Spoken sightings name their receipt's night; street reports remain street reports.
  > Vigil narration says “out on”; overview totals explicitly include the anonymous
  > counts; the cast says “location unknown”; vote buttons say execute/spare. Guarded
  > report openings no longer imply a preceding question. No evidence metadata or
  > decision formulas changed. The allowed failing false-Night-Watch consistency
  > case is still separate evil-story work and is skipped under this session's rules.
  > Focused checks: 4/4. Full runner: 73/75; only the two permitted failures.

  > **Prep B020 (9cb8782; mixed):** Check `sim/mind.gd::sighting_report`,
  > `ui/main.gd::_refresh_actions`, and `game/game.gd::_show_nomination`. Card dates already exist.
  > Distinguish spoken text, UI labels, and evidence identity; do not change mechanics just to repair
  > prose.

  - Night sightings in answers say "that night"; say which night (the card does).
  - A vigil "sees X moving through the Market"; with every block joined nobody passes
    through. "Out on the Market".
  - The town overview's "(1 more at wharf)" followed by "1 other out of sight" reads as
    two people. The cast list's "at Unknown" reads like a place name.
  - At a meeting, a speaker opened with "I will answer that much" with nothing put to
    them.
  - "vote yes / vote no" sits next to "present … for/against", which invites the wrong
    reflex. "Vote to execute / Vote to spare".

  > **Closure check (Claude, Oct 25):** Verified: all lines below fixed except the claimed Night Watch told "from my window", which stays open in BACKLOG (it is evil's fake-sighting wording, `Evil` line 888).

<!-- B030 · was in Section 2, deduction types -->
- **A watcher's report against the player's vigil of the same block and night**
  (Constance: "I watched the Market and saw Jory"; my vigil saw only Constance and
  Isolde) had no link. A false gift report is the strongest kind of lie.

  > **Session verification 2026-10-25 (B030):** Added the exact named-set mismatch to test_argue:
  > watcher present, an omitted person, and a different-night control. Propose closure of the
  > missing link; no judge, doubt, or effect weights changed. Full default runner: 73/75; only
  > permitted test_social/test_text_ui failures.

  > **Prep B030 (9cb8782; candidate to narrow):** `sim/argue.gd::_match_pair` now has vigil/watch and
  > omission branches. Verify the exact named-set mismatch, including a watcher present in the vigil;
  > native choices and shared Night Watch content must agree.

<!-- B034 · was in Section 2, deduction types -->
- **The totem has no adapter:** it should read "a Revenant is in play and lives on
  Chapel Hill", which crossed with an Archivist pair names one person.

  > **Session verification 2026-10-25 (B034):** test_workshop_card_adapters._totem verifies public
  > home/material candidates and shared delivery. Propose closure of the no-adapter report, not
  > revelation of the hidden owner. Full default runner: 73/75; only permitted
  > test_social/test_text_ui failures.

  > **Prep B034 (9cb8782; candidate to close):** `workshop/live_assessment.gd::activity_card` now
  > adapts totems; `tools/test_workshop_card_adapters.gd::_totem` checks public home/material
  > candidates and shared presentation. This is conditional role consistency, not hidden-owner
  > revelation.

<!-- B110 · was in Section 2, UI -->
- **Selected filter rows first.** On the case board, promote rows explicitly selected
  in the person/place filters above unselected rows; e.g. filtering for Agnes,
  Constance and Dorian puts those three first. Preserve predictable order within
  both groups and coordinate with all/any/exclusion and timeline layout.
  (Oct 21) [decided]

  > **Session 2026-10-25 (B110): implemented; closure proposed.** Explicit person
  > and place filters promote their rows through a stable partition; a selected
  > location promotes its block. No selection restores normal order. Card membership,
  > cell identities, pins, and any/all filter semantics are unchanged. `test_board`
  > checks every view and stable groups; `test_ui` checks actual filter wiring.
  > Focused checks: 2/2. Full runner: 73/75; only the two permitted failures.

  > **Prep B110 (9cb8782; open; layout batch):** `ui/case_state.gd::apply` filters cards;
  > `game/board_model.gd::layout` builds rows. Put selected-first ordering in shared row layout with
  > stable ties and pinned anchors; this is not only a list sort.

<!-- B036 (part) · was in Section 1, from playtest 54875: case-workshop feedback -->
- **Case-workshop feedback: the evaluator toggle.** (from "From playtest 54875: case-workshop feedback"; the entry's other bullets stay open)
  - The evaluator toggle is easy to flip unnoticed; the preview headline should say which
  model produced it.

## Closed earlier


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

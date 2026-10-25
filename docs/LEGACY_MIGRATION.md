# Migrating belief evaluation off the legacy rules

Status: **re-baselined Oct 24–25** (user + Claude). The full migration is rescoped to a
deliberate hybrid; read "Re-baseline" first. Owner: Claude for the re-baseline work;
Codex for later slices once the user hands them over.
Read first: [CASE_REASONING.md](CASE_REASONING.md) (the target architecture),
[playtest_54875_diagnosis.md](playtest_54875_diagnosis.md),
[MIGRATION_PROGRESS.md](MIGRATION_PROGRESS.md) (measurements, detail) and the
**Performance rules** section below before touching anything in `workshop/`.

## Re-baseline (Oct 24–25)

**North star (check it on every change):** the engine judges evidence; the town is a
cheap social simulation around it. "NPCs judge the player's theory; they don't search
for theories" (BACKLOG, Oct 19–20) was quietly inverted by "migrate every belief
evaluation", and the realism layers that followed multiplied cost (listeners ×
refreshes × people × channels) while scattering the town's beliefs. See the
post-mortem notes in MIGRATION_PROGRESS.

**Scope now: a deliberate hybrid.**
- One judge for anything that is evidence: presentations, readings, testimony,
  public events. Evidence the judge can't read is excluded with a stated reason, never
  judged by both systems.
- Native and permanent: trust, pressure, fear, paranoia as a mood, crowd pressure
  (Q1), the vote and nomination formulas (Q3), disclosure, evil strategy.
- Still to move (it's evidence): defences that are claims or challenges, NPC-to-NPC
  sightings/readings shares (C3–C5), unowned gift readings, the anonymous-relay and
  curse fallbacks. These remain the migration's real work.
- Optional, probably not worth it: priors and paranoia drift into the world prior,
  the full nightly per-NPC solve (P4.1), deleting the ledger (P5 shrinks to deleting
  what's fully replaced).

**Decisions (user, Oct 24, Claude's defaults accepted):**
1. Confidence: no per-person theory loop; live listeners use `scale` Confidence (the
   legacy `1.4 − 0.8 × confidence` that Q6 kept). A stickiness rule (committed
   conclusions resist reversal, but yield to clearly strong evidence) comes later.
2. Insight: differences in degree, not direction (Low follows the shared picture less
   strongly); attention budgets limit what an NPC can explain in a reply. Not yet built.
3. Good people may lie about whereabouts at the existing secret-errand rates.
4. Public = meeting statements, deaths, executions, vote tallies, public claims;
   private conversations (including the player's) are that listener's private evidence.
5. Speed budget on the user's machine: meeting entry and presenting about 2 s or less,
   nominations under 1 s. Speed first, simulation correctness second, until settled.
6. Parity first (shared good-win rate and town agreement at least native's in the
   ten-person passive A/B, no impossible refreshes), then a Q3 tuning pass after
   checking in with the user.

**Done in the re-baseline** (container timings on the 54875 replay; the container is
slower and noisier than the user's machine):

| Change | Effect |
|---|---|
| Live listeners default to `scale` Confidence (`26cbfd4`) | No per-person explanation search / theory / biased CaseEval per refresh. Meeting entry 6.4 → 3.3 s |
| Soft testimony (`2c29c2d`): an evil source's role declaration is a possible bluff (weight 0.35), good sources' claims stay binding, contradictory routes no longer void worlds; stopgap removed | No impossible refreshes (seed 1005: 0 of 190, was 59). Case #85 3/5 yes (was 2/5). Presenting 8.0 → 5.1 s, nomination 3.7 → 0.9 s |
| Per-run CaseEval reuse in `Jury` (`4252f60`, exact) | Presenting 5.1 → 3.8 s, identical margins |
| Meeting refreshes deferred until a listener speaks, flushed when testimony ends | Meeting entry about 2.5 → 0.9 s, search into meeting 5.5 → 2.0 s, same margins |

**Tried and reverted:** memoising `CaseEval.evaluate` on its whole input (hashing the
view cost far more than it saved); moving private readings into `own_reports` with no
card budget plus Insight-as-degree (no speed gain, since the world grouping still wasn't
shared, and the replay fell to 0/5 yes). A real shared public baseline needs a deeper
restructure; it's parked until the speed budget says it's needed.

**Next, in order:**
1. A/B bot run on the re-baselined main (user, locally): parity check and agreement.
2. Reply speed: per-listener setup (about 0.9 s per presentation) and the reply's
   headline work; then Insight-as-degree and attention for replies only.
3. Words match beliefs (a reply's stance from the same result as the belief).
4. Confidence stickiness rule.
5. Q3 tuning (check in first): vote thresholds, a rank-aware vote term.
6. Remaining evidence migration (see Scope).

**Superseded:** the exact live channel integration (Codex's prototype on
`codex/live-channel-validation`: replay presentation 151 s vs 6.7 s control). Keep its
factored kernel and parity tests as an offline reference for the soft-testimony model;
don't wire it live.

## Where things stand (Oct 24)

| Phase | State |
|---|---|
| P0 | Implemented, not signed off. Unclamped suspicion, fallback logging, whole-audience readiness check before a presentation, readiness in the preview and shared effects on by default all landed. Intermediate bot comparisons fail the balance criterion; current/final batches remain. The latest paired #89 measurement is about 5.0 s after finite death evidence. The user authorized continued work above five seconds, with significant increases flagged. |
| P1 | Partly done: revisions get new numbers, free repeats, daytime sightings, conversations, home, haunt, totem, dropped items, public death/execution/silence/vote receipts, weak hints/refusals, secret errand claims, Surveyor block answers and nested canvas cases; opinion and accusation cards rejected as evidence. Self/group bypasses fixed. Remaining: curse events and removing the native presentation routes. |
| Attention correction | Implemented Oct 24: submitted roots are guaranteed in the applied refresh and scoped reply; background/private reports compete for remaining attention. The opening replay still fails 1 yes / 5 needed, with changed agreement and no fallbacks. Day 3–4 fixture expansion awaits the user's signal. |
| P3 consensus slice | Q1 implemented: public accusations remain social pressure in votes/nominations, outside evidence, source honesty and world priors. Existing weights, cap, fade and action thresholds retained. |
| P3 Demon-victim slice | Q2 implemented as finite 95:5 innocence evidence in the shared posterior, including uncited public deaths. Victims no longer enter hard good knowledge or receive a zero reset. Native compatibility entries are retracted when shared ownership is ready; other event/prior migration remains. |
| P3 Martyr proof | Automatic public receipt and gift identity, including uncited substitutions; native proof entries parked for good listeners and covers. A public fact clears the reversible baseline exactly. Curse dating, other NPC shares/defences and priors remain. |
| P3 defence repeats | Stable semantic ownership fixes daily stacking in native compatibility defences, preserving first-hearing strength and Confidence. Conversion to shared claims/challenges remains. |
| P2 Psychologist / Q4 slice | Psychologist social readings (including a Medium relay) are shared context for every listener. Opinions, including relayed opinions and private gossip, supply no alignment evidence. Other P2 reading/channel/history work remains. |
| P2 relay provenance | Named NPC readings retain their teller paths. Unnamed meeting readings redact the hidden original source and explicitly fall back until a public acknowledgement binds that particular telling. A latent anonymous-source assessment remains pending. |
| P2 original reading identity | Native and board reading keys use the exact canonical original. Distinct same-day contents/times get separate owners; old records with exact proof remain compatible, ambiguous old records stay explicit. Repeats and weaker duplicate paths do not stack or weaken a fact. |
| P2 channel foundation | A tested conditional-constraint plan and exact likelihood reference now represent separate gift honesty, poison-window accuracy, testimony honesty and transmission. Compact classes have per-world parity tests. Faithful paths share one original predicate, and repeated declarations supply no extra likelihood. These are not connected to live CaseEval yet; its hard role gate and provisional-conviction path still need replacement together. |
| P4–P5 | P4 execution-priority plumbing is implemented with its coefficient fixed at zero while Q3 is deferred. Nightly baseline solves, reasons and bot work remain. P5 deletion has not started. Remaining P3 event/share/defence work is pending. |

Psychologist remains metagame/context information for now (user, Oct 24); do not
expand its automatic alignment reasoning.

The exact channel-integration brief and its performance guidance (Oct 24) are
superseded by the re-baseline above; see MIGRATION_PROGRESS for the record.

## Terms

- **Legacy rules:** the native belief code in `sim/mind.gd`, `sim/argue.gd`,
  `sim/social.gd` and `sim/world.gd`. Each NPC has a ledger of entries, each with
  hand-tuned effects on suspicion (`Mind.ledger_hear`, `Mind.adjust`,
  `Mind.recompute_beliefs`).
- **Shared model:** the case evaluator in `workshop/` (`case_eval.gd`, `jury.gd`,
  `live_assessment.gd`, `shared_ledger.gd`), reached through
  `game/workshop_presentation.gd` (presentations) and `game/workshop_ownership.gd` (it
  takes over, "owns", matching legacy entries and writes one joint suspicion vector).
- **Fallback:** any path where the shared model declines and the legacy rules run
  instead. Today this is silent.

## Ground rules for the migration

1. **One engine per kind of evidence, for every listener.** Never judge the same case
   with two engines in one meeting (CASE_REASONING, "One evaluation path per gift").
2. **No silent fallback** (user, Oct 23). If the shared model can't take a case, the
   player is told why (in the preview and when presenting) and the submission is
   blocked. Name the unsupported piece ("the totem card isn't supported yet"), so the
   player can remove it and present the rest. Internal fallbacks that remain during the
   migration must log their reason as a trace event.
3. **Social behaviour stays native:** trust, pressure, paranoia as a mood, fear,
   disclosure tiers, the vote and nomination formulas. They read suspicion; they don't
   become part of the evaluator. What changes is where suspicion comes from.
4. **Hidden truth never enters assessment** (CASE_WORKSHOP_FINDINGS). Listener inputs
   come from the snapshot contract only.
5. **Determinism:** no new game-RNG draws in evaluation. Same seed and same commands
   give the same game.
6. **Every phase ends green:** all `tools/test_*.gd` pass on Godot 4.7.2 headless
   (`python tools/run_gd_tests.py --godot <exe>`; known failures on main: `test_social`,
   "a false Night Watch's night story matches their fake report", and `test_text_ui`,
   two role-hover checks; don't add to them), plus bot runs (below) recorded in the
   PR. `test_trace` takes about 10 minutes and is skipped by default; run it with
   `--include-slow` (or by name) before merging and whenever a change touches tracing,
   logging, determinism or whole-game flow.
7. **Small commits, one phase or sub-phase each.** Don't delete legacy code for a kind of
   evidence until its replacement has shipped and been measured.
8. **Follow the performance rules below.** A faster number only counts if every
   listener was evaluated by the shared model (no fallback, no native rules).

## Inventory: every belief evaluation and where it runs today

"Shared?" means: does the shared model handle it today when it's working.

### A. The player persuading NPCs

| # | Evaluation | Code | Shared? | Notes |
|---|---|---|---|---|
| A1 | A filed deduction or canvas case (private, meeting floor, nomination) | `Argue.evaluate` → `w.workshop_present` | Yes, with silent fallback | Fell back for every listener in 54875 (saturation check, see P0) |
| A2 | A card pressed privately against someone (`present <card> against X`) | `Mind.hear_accusation` | Yes, with fallback | |
| A3 | A card presented privately for someone | `Mind.hear_defence` | Yes, with fallback | |
| A4 | A card about a group | `Mind.hear_group_case` | Yes, with fallback | |
| A5 | The player's accuse/defend statement with a card during a vote | `Mind._public_case_hear` | Yes, with fallback | |
| A6 | The player's accuse/defend/vote without a card | vote parts `player_accuses`, `player_defends`, `player_votes_yes` | No (social term) | Stays social; see the execution-priority work in P4 |
| A7 | Revising a case | `_workshop_retract` + legacy novelty (`used_facts`) | Partly | Revisions score lower than the version they replace (54875). Shared path uses `rewarded_facts` / signatures instead |
| A8 | Pressing someone with a card (`press`) | `Mind.press` | No | Pressure and disclosure only; stays social |

### B. Readings and claims

| # | Evaluation | Code | Shared? | Notes |
|---|---|---|---|---|
| B1 | An NPC's own gift readings | `Mind.update_from_own_info` → `apply_info(n, n, …)` | Owned when the reading has an exact receipt | |
| B2 | Readings heard at the meeting | `meeting_testimony` → `apply_info` | Owned if receipt | |
| B3 | Readings relayed NPC to NPC, or relayed unnamed ("word reached me from the Seer") | `Social._deliver` "reading", `Mind.relay_reading` → `apply_info` | Partly | Unnamed relays and second-hand provenance need checking |
| B4 | How each gift's reading translates into suspicion | `Mind._info_effects` (Dowser, Hearthwitch, Seer, Night Watch, Archivist, Rumormonger, Martyr, Veteran, Psychologist, Medium, Clerk, Gravedigger) | Supported roles: Surveyor, Rumormonger, Dowser, Clerk, Archivist, Seer, Night Watch, Gravedigger, Veteran, Lamplighter, Medium, Martyr, Sexton (`LiveAssessment.ROLES`) | Not supported: **Psychologist**, **Hearthwitch** (benched), **Warden** guard statements outside a Medium relay |
| B5 | Night sightings near or away from a death (×1.0 / ×0.12) and walking-gift discounts | `Mind.night_sighting_scale` | Shared uses movement likelihoods | Two different models of the same thing |
| B6 | Role claims: credence, double claims, "they claim my gift" | `Mind.hear_claim`, `claim_credence`, the `own_role` adjust | Claims of good roles are receipts | Rival-claim logic and own-gift certainty are legacy |
| B7 | Doubt about a reading (misled, poisoned) and honesty from evidence | `_night_doubt`, `_honesty` in `recompute_beliefs` | Shared has its own reliability; channels per source still to come (CASE_REASONING step 1) | Demon victims aren't exempt from honesty (54875) |
| B8 | Medium relays of relays, and relayed opinions | | No | Explicit fallback today |
| B9 | Martyr promise followed by a later hanging | | No | Explicit fallback today |
| B10 | Anything after a Revenant curse ("alignment-transition history") | | No | Every case falls back once a curse has fired |

### C. Town talk and events

| # | Evaluation | Code | Shared? | Notes |
|---|---|---|---|---|
| C1 | Public accusations and the town consensus | `Mind.refresh_consensus` (direct `adjust`, not in the ledger) | No | DESIGN keeps it out of the evidence ledger on purpose: a crowd isn't evidence. Decision needed (Q1) |
| C2 | Defence moves at a nomination (reveal, secret, red herring, pair_other, lying, misled, plea) | `Mind.defend_self` → `def:<id>:<day>:<move>` entries | No | Stack daily (bug). Each move is really a claim or a challenge |
| C3 | Sightings heard from another NPC | `Social._deliver` "sighting" → `heard:` | No | |
| C4 | Opinions heard from another NPC | `Social._deliver` "opinion" → `opinion:` | No | |
| C5 | The player's case relayed by an NPC | `Social._deliver` "case" → `relayed-case:` | No | |
| C6 | Silenced by the Breathstealer (credit to the silenced) | `World` → `silenced:` | No (`silenced` cards unsupported) | |
| C7 | Martyr's sacrifice proves both good | `World` → `martyr:` | Martyr event is supported | Check ownership |
| C8 | Revenant curse suspicion on yes-voters; freed soul's reset | `World` → `curse:`; `free_turned` caps suspicion at 0.25 | No | |
| C9 | Quiet night credit to Warden/Veteran claimants | `World` → `quiet:` | Owned when the claim is a receipt (`live_protection.gd`) | |
| C10 | Demon victims cleared | `World._kill` sets suspicion 0.0; `adjust` ignores them | Shared reads the public death event | Fiat, outside the ledger |
| C11 | Paranoia drift (everyone alive a little more suspect) | `Social.paranoia_drift` | No | A prior, not evidence |
| C12 | Starting suspicion from friends and rivals | `World.setup` | No | A prior |

### D. Physical and other cards the shared model can't read yet

Supported receipts today (`SharedLedger.supported`): readings of the supported roles,
claims of good roles, night/evening sightings and alibis, trace, vigil, quiet,
execution, martyr, knell.

Not supported: daytime sightings (morning/afternoon), **conversation**, **home**,
**haunt**, **dropped** items and materials, **totem**, **death** (as a card; the public
event is used), **vote**, **curse**, **curse_lifted**, **silenced**, **secret**,
**hint**, **refusal**, **opinion**, **accusation**, Psychologist and Hearthwitch
readings. Also no adapter for: Surveyor answers that name blocks and suspects, and a
canvas graph cited inside another deduction.

### E. Things that read suspicion (consumers, not evaluations)

These don't migrate, but each must keep working when its input comes from the shared
vector: votes (`_vote_impl`), nominations (`_good_nomination`, `_evil_nomination`),
accusation tiers and cited reasons (`reason_status`, `citable_reason`, `case_against`,
`nomination_case`), opinions (`answer_opinion`), `ranked_suspects`, Seer picks, Warden
targets, the "I'm more suspicious of X" line, the debug overlay, the shadow self
(`shadow_view`), and the bot. Citing reasons is the delicate one: owned entries have
their legacy effect zeroed, so reasons must come from the shared model's attribution
(`Mind` ~line 1060 already returns "the reports considered together point toward
them").

### F. Fallback points inside the shared model

- `WorkshopPresentation._present`: three silent `return {}` exits (snapshot not ready;
  proposals not ready; ownership not active).
- `WorkshopOwnership._refresh`: plan not ready → native fallback.
- `SharedLedger.prepare` issues (about 40 reasons; see `issues.append` in
  `workshop/shared_ledger.gd`, `game/workshop_bridge.gd`, `workshop/live_assessment.gd`).
- `Jury.engine = "legacy"` (model v5 kept for comparison), `support_model.gd`'s 2^u
  mixture, the per-person loop in `consequences.gd` (CASE_REASONING marks these
  for replacement).
- `Game.workshop_effects` is off by default; the player turns it on with a checkbox.

## Plan

### P0. Make the shared model run reliably (do first; small)

1. **Unclamped suspicion.** Suspicion is a running sum clamped to [0, 1.5] at every
   change, so a contribution can't be removed exactly once a bound is hit. That's the
   reason for the "saturated" and "clipped" checks that blocked every listener in 54875.
   Store each NPC's unclamped total (base + contributions) and clamp only when it's
   read (`Mind.susp` and every direct `n.suspicion[...]` read). Then remove the
   saturation and clipped checks and the `workshop_clipped` flag.
   - Direct writes to fold into this: `World._kill` (victims to 0.0), `free_turned`
     (cap at 0.25), `Social.paranoia_drift` (direct write when ownership is inactive),
     `World.setup`.
   - If this turns out large, ship the stopgap first: exempt demon victims (not all the
     dead) from the saturation check. Executed NPCs stay in.
2. **Log every fallback** with its reason (`workshop_fallback` trace event: listener,
   card, exit point, issues).
3. **No silent fallback for presentations.** Run the readiness check for every real
   listener *before* the presentation is accepted. If any can't take it, block the
   submission and show the reasons, naming the unsupported card. Behind a flag
   (`C.STRICT_EVALUATOR`, default on in debug builds and playtests).
4. **The preview reports real readiness:** besides the neutral reference listener's
   strength, say whether every real listener can evaluate it, and if not, why.
5. **Shared effects on by default** once 1–4 pass (`Game.workshop_effects = true`).

Acceptance: replaying case 54875's commands (seed 54875, 10 townsfolk), every
presentation of case #85 is evaluated by the shared model for every listener, with no
fallback events. Tests: extend `test_workshop_ownership.gd` with a demon-victim reading
and a clipped-contribution case; add a strict-mode test that a case with a totem card
is blocked with a named reason.

**P0 measurement checkpoint (user, Oct 23):** check whether case #85 now passes in
the 54875 replay. Record listener agreement, suspicion, vote margins and the actual
tally. Report a surprising result in either direction; do not tune it. Expectations
derived from the code are estimates, not measurements. The replay confirms them.
Q3 and Q6 remain deferred regardless of this result.

### P1. Finish the player-facing paths (A1–A7)

1. **Revisions** (A7): a revised case is the old case plus new support. Old facts keep
   what they already contributed, new facts count in full; only an identical
   re-presentation is a repeat. A revision gets a new card number and the old one is
   marked superseded.
2. **Repeats** are free once per conversation and say so ("You've heard this from me
   already"; "I heard you say that at the meeting"), without re-running the argument.
3. **Card adapters** for the commonest unsupported kinds, each with its own test, in
   this order (most used in play first):
   - daytime sightings and **conversation** cards as location sightings (also unlocks
     "evening sightings vs the scene trace");
   - **home** and **haunt** (context for routes; may only need to be accepted as
     neutral support);
   - **totem** ("a Revenant lives on block X");
   - **dropped** items and materials;
   - **death** and **execution** cards as cards (not only public events);
   - **silenced**, **curse**, **curse_lifted**;
   - Surveyor answers naming blocks and suspects;
   - **secret** (a confessed secret explaining a night walk).
   Cards that are speech about opinions (**opinion**, **accusation**, **hint**,
   **refusal**) should be accepted as weak testimony or rejected with a clear reason.
   Decide per kind with the user (Q4).
4. Remove the legacy route from `Argue.evaluate`, `hear_accusation`, `hear_defence`,
   `hear_group_case` and `_public_case_hear` for everything the shared model supports.
   With strict mode, unsupported cases are blocked, not routed to legacy.

Acceptance: in strict mode, a bot game and the 54875 replay produce no legacy
evaluation of a player presentation. Bot runs (below) within noise of the previous
baseline or better, with the change explained.

### P2. Readings and claims (B1–B10)

1. Make the shared model the only interpreter of readings, for every listener, gift by
   gift (one gift at a time, all listeners at once). Order: the already-supported
   thirteen first (remove their `_info_effects` branches once owned everywhere), then
   **Psychologist**, then **Warden** guard statements, then Hearthwitch if it comes back
   from the bench.
2. **Per-source honesty and accuracy channels** (CASE_REASONING step 1, still open):
   gift honesty, gift accuracy scoped to a poison window, testimony honesty. Fold
   `_night_doubt` and `_honesty` into these. Settle whether demon victims' testimony
   honesty is exempt (54875 inconsistency; Q2).
3. **Night sightings:** one model. Retire `night_sighting_scale` in favour of the
   movement likelihoods, checking the hang rates of walking gifts against the Oct 18
   numbers in DESIGN (Lamplighter 43%, Veteran 33%, Sleepwalker 40%, Warden 48%).
4. **Role claims:** credence, double claims and "they claim my gift" as constraints on
   the role assignment (one holder per gift), not separate suspicion bumps.
5. **Relays:** named and unnamed relays with two-source provenance; nested Medium
   relays; relayed opinions (B3, B8).
6. **Temporal adapters:** Revenant curse histories (B10) and the Martyr promise plus a
   later hanging (B9).

Acceptance: `_info_effects` is only reached for gifts that are explicitly not yet
migrated (none at the end of P2). Seer red herring, Marked, poison windows and the
Sleepwalker behave per CASE_WORKSHOP_FINDINGS (its semantic rules are the test list).

### P3. Town talk and events (C1–C12)

1. **Defence moves** become what they are: a reveal is a walking-gift claim, a confessed
   secret is a secret card, red herring / misled / lying are challenges to a reading,
   pair_other is a rival theory, a plea is speech. Each is judged by the shared model
   once, not re-added every day (fixes the stacking bug). Keep each move's legacy
   strength and weighting (trust in the defender) for now; whether Insight should
   discount speech-only moves is deferred (Q6).
2. **NPC-to-NPC shares** (C3–C5) become receipts in the listener's own evidence with
   provenance (who told whom), credited by trust in the teller, deduplicated by the
   underlying fact.
3. **Events** (C6–C10): silenced, Martyr sacrifice, curse, quiet nights and demon
   victims as public events the shared model reads. `World._kill`'s direct clear goes
   away (the public death event already carries it).
4. **Priors** (C11–C12): starting friend/rival suspicion and paranoia drift become the
   listener's prior over worlds (CASE_REASONING: "prior from suspicion and trust"), not
   additions on top of the posterior.
5. **Consensus** (C1): per Q1. Default if undecided: keep it out of belief, as a
   separate social pressure term in nominations and votes, so a crowd never lowers
   anyone's credibility (DESIGN).

### P4. NPCs' own view and the vote (E)

1. **Nightly solve** per NPC (CASE_REASONING step 4, not built): public rules, public
   evidence, their private readings and accepted claims. It produces their baseline
   suspicion and rival theories, replacing the legacy ledger as the source of suspicion.
   Evil runs it on the shadow. Budget: under 50 ms for the town.
2. **Belief and action:** add the plumbing for an execution-priority term from the
   shared model's action output into nominations and votes (CASE_REASONING; BACKLOG
   "agreement has to reach the vote"), but ship it with weight 0 and the legacy vote
   and nomination formulas unchanged (Q3 deferred). The NPC-says-why lines can come
   with the tuning pass.
3. **Reasons and provenance** for accusations, nominations and opinions come from the
   shared attribution, keeping the citing rules (public / told the player / private).
4. Update the bot to read the same outputs.

### P5. Remove the legacy belief code

Only after P1–P4 have shipped and been measured: delete the migrated branches of
`_info_effects`, `ledger_hear` effect lists, `recompute_beliefs`' effect application,
`Argue`'s legacy evaluation routes, `Jury.engine = "legacy"`, `support_model.gd`'s
mixture, the per-person loop in `consequences.gd`, the ownership/retraction layer
(no longer needed when nothing is legacy) and the `workshop_effects` flag. Keep trust,
pressure, disclosure and the vote formula.

## Performance rules (established Oct 24; don't regress these)

The 54875 replay went from about 50 s to 4–5 s per meeting or presentation. Several
of those gains were lost once by later work and had to be redone, so these are rules,
not suggestions. Each one names what it protects.

**How to measure**
- Continue migration work even when a presentation exceeds five seconds (user,
  Oct 24). Five seconds remains a performance target, not a stop condition. Measure
  against the current checkout and flag change sets that add significant time.
- Speed only counts with full coverage. `tools/replay_54875.gd` and the profiling tools
  (`profile_live_presentation.gd`, `profile_case_eval_town.gd`,
  `profile_workshop_town.gd`) exit with FAIL if any listener fell back or used native
  rules. Don't pass `--allow-fallback` to make a number look better. The concern this
  guards: an early "fast" build was fast partly because evidence wasn't going through
  the shared model at all.
- An optimization is either **exact** (same `measurement.json` agreement, suspicion,
  vote margins and tally, and the same `behavior_hash` from `profile_workshop_town.gd`
  on seeds 692 and 4242) or a **declared behaviour change**, agreed with the user and
  recorded here. Never ship a "speed-up" that silently changes results.
- Profile with `workshop/profiler.gd` spans before optimizing. Twice, a plausible
  hotspot turned out to cost almost nothing (explanation-cache hashing; the explanation
  search's own body), while the real cost sat elsewhere.

**Two jury runs per listener, with different jobs**
- **Belief refresh** (`Shared.evaluate` → `Jury.refresh`, from
  `WorkshopOwnership`): "given everything I hold, how do my suspicions move?" It has no
  headline claim. Every person, including the first in the list, goes through the
  same per-person theory path. It builds no reply, runs no `Solver.analyze`, and makes
  no intermediate-claim or link diagnostics. Don't route the refresh back through
  `Jury.evaluate` or `_assess_target_eval`. (Until Oct 24 it argued a placeholder case,
  "the first person in the list is evil", which gave that one person a differently
  derived theory. Removing it was about speed-neutral: the headline was mostly doing
  that person's theory work, which now happens in the normal per-person loop.)
- **Scoped reply** (`Shared.response`): what the listener says about the presented
  case. It passes `{"headline_only": true}`. Its effects are never applied (the refresh
  owns belief changes), so it computes only the headline target's effect. Don't add
  per-person effects or theories to the reply.
- In persistence mode, `Theory.prepare` checks `Theory.cached()` first. And
  `_consequences_eval` skips `Support.explain` whenever its result would go unused (the
  headline's own theory, a cached decision, or the fixed decisions a scoped reply
  inherits from the refresh).

**Meeting refreshes: deferred until a listener speaks (re-baseline, Oct 25)**
- During meeting testimony (`Mind.meeting_testimony`), `World.defer_beliefs` queues each
  listener's refresh. A speaker is flushed (`Mind.flush_beliefs`) just before their turn,
  so they react to everything said before them; everyone else is flushed once when
  testimony ends. This keeps the meeting reactive (the user's requirement) at about a
  fifth of the refreshes. Not bit-exact: the order in which a refresh records the
  "last reason that raised suspicion" can differ, which can change cited reasons.
- Don't go further (one refresh for the whole meeting, or skipping a speaker's flush)
  without the user's decision. The next step for feel is pacing: run a listener's
  refresh while the previous line of dialogue is on screen.

**Movement model (`workshop/live_activity.gd`), the largest single cost**
- `_likelihood` builds each night's incident list and the per-route products once per
  behaviour profile, then sums them for each habitual block in the original order (bit
  for bit identical to the old nested loops). Keep work that doesn't depend on the
  habitual block or evening block out of those loops. Its cost grows with nights ×
  reports × routes, so a slip here grows with game length.
- `factors()` and `routes()` cache on `movement_inputs()`: the movement-relevant
  cards, relayed cards and each person's claimed role. Listeners who differ only in
  other readings (Dowser, Surveyor, Clerk...) share one cache entry. **Correctness
  hazard:** if you make the movement model read a new kind of card, a new card field,
  or a new source of a person's role, add it to `movement_inputs()` (and `relevant()`
  if it's an observation). Otherwise the cache silently returns another listener's
  result.

**General**
- Exhaustive minimal-conflict enumeration stays out of live paths (only the explicit
  diagnostic UI reads it).
- Cache keys should contain what the computation reads, nothing listener-specific
  beyond that. Too broad, and every listener misses; too narrow is the hazard above.
- Prefer integer or bitmask passes over per-world allocation and filter lambdas in
  per-world loops (see `CaseEval._own_counts`, `Solver.unresolved`).

**Known remaining costs (replay, Oct 24)**
- About 4.5 s to enter a meeting, 5.0 s for the search-then-meeting step, 4.2 s to
  present #89 and 1.1 s to nominate. `CaseEval` is about 65 ms a call, and the movement
  model is still the largest single item.
- Not yet tried: grouping worlds in `CaseEval.compile` independently of the case's
  conclusion. This would help the per-claim checks, but each listener's private
  readings genuinely differ, so it won't remove per-listener misses. It needs a parity
  proof. Also untried: integer keys in `ReadingChallenges.assess`, which matter only for
  cases that challenge a reading.
- Measure scaling on the Day 3–4 replay before deciding the next step.

## Measuring each phase

- `godot --headless --path . --script res://tools/autoplay.gd -- --seed 1000 --games 150`
  at 7 and 10 townsfolk, active and `--passive`, with `--results` and
  `tools/compare_runs.py` against the previous main. Report good wins, wrongful
  executions, evil hanged, and the "evil off the crowd" tell metric.
- `tools/profile_live_presentation.gd`, `tools/profile_case_eval_town.gd` and
  `tools/replay_54875.gd`: stay inside the 5-second whole-town presentation budget,
  with no fallback (see Performance rules).
- Suspicion scale, same source A/B: `tools/autoplay.gd` with and without `--native`
  (legacy belief rules), same seeds and `--results`. It prints per-day good-NPC
  suspicion against the truth (top suspicion, the Demon's suspicion and rank, how many
  could nominate) and every vote's score against its need; the JSON keeps them per
  case. This is the input for the Q3 tuning pass.
- A replay of case 54875's commands as a regression fixture: it records each listener's
  agreement, suspicion and vote margin for case #85. With Q3 and Q6 deferred it doesn't
  assert that a vote passes; the tuning pass will use it.

## Decisions for the user (don't settle these in code)

**Confirmed by the user (Oct 23):**
- **Q1:** public accusations and consensus are social signals, never evidence.
- **Q2:** a demon kill is strong (95%) evidence of innocence, not proof. Victims'
  beliefs and credibility must remain revisable.
- **Q4:** opinions and accusations are not evidence. Hints weakly support a gift
  claim; refusals weakly support suspicion.
- **Q5:** strict mode is for testing only; normal play must report any fallback.
- **Q3 and Q6:** deferred, with the existing values preserved as described below.

**Deferred to a later tuning pass (user, Oct 23): Q3 and Q6.** Until then, port the
legacy values exactly and don't tune them:
- **Q3, agreement to action:** keep `Mind._vote_impl`'s formula and `need`
  (`0.5 − 0.12 × (confidence − 0.5) × 2 + 0.1 on day 1 − 0.4 × paranoia`), the player
  terms (`player_votes_yes 0.25 × trust − 0.05`, `player_accuses 0.2 × trust`,
  `player_defends −0.25 × trust`), `prefers_block −0.4`, Martyr reluctance, and the
  nomination thresholds. The shared model keeps converting agreement into suspicion
  with its current coefficients (CASE_REASONING step 3: stance thresholds, suspicion
  coefficients, trust and confidence factors unchanged). No urgency term yet.
- **Q6, Insight and Confidence:** keep what the legacy rules do today and carry it
  across unchanged. Insight: `Argue._class_w` (speech weight 1.0 → 0.2,
  circumstantial 1.0 → 0.6 as Insight rises), the unfounded and conflict routes, the
  "that's not enough to go on" line, and the shared model's existing Insight attention
  layer (`reasoner.gd`). Confidence: the `1.4 − 0.8 × confidence` scaling on suspicion
  changes, its term in the vote and nomination thresholds, and the existing confidence
  modes in the shared model. Where the legacy rules use neither (defence moves, crowd
  talk), add nothing.
- **Expected consequence (corrected Oct 23):** "port the legacy values" means each path
  keeps its *own* current numbers. The legacy argument route gave an accepted case about
  +0.10 suspicion (agreement × quality × 0.6 at a meeting × novelty). The shared model's
  existing coefficients give about +0.3 to +0.45 for the same accepted "X is evil"
  (`Jury`: weight × (0.5 + trust) × confidence factor × 0.45, with no meeting discount
  and no novelty penalty on revisions). In 54875 the voters sat at 0.14–0.26 against a
  bar of 0.4–0.5, so once presentations stop falling back, an accepted case should
  usually be enough to pass a vote. Things that can still hold it back, all deferred
  or ported unchanged: defences stacking daily (fixed in P3), consensus fading, no
  urgency term, and `prefers_block`. The 54875 replay fixture records each listener's
  agreement, suspicion and vote margin; check after P0 whether case #85 now passes,
  and treat a surprising answer either way as something to report, not tune.
  **Measured (Oct 23, see MIGRATION_PROGRESS.md):** it didn't pass (1 yes of 5), and
  the estimate above was wrong for a reason that isn't tuning: five of nine listeners
  never considered the two presented cards (attention budget; see "Presented cards
  dropped by attention").

- **Q1.** Does a public accusation count as evidence, or stay a social signal outside
  belief (DESIGN today)?
- **Q2.** Is a demon kill proof of good, or strong evidence (DESIGN wants the latter
  eventually)? It decides whether victims' suspicion and honesty can ever move.
- **Q3 (deferred).** The mapping from agreement to action: how much an accepted case
  moves a vote, and the urgency term.
- **Q4.** For each speech-like card (opinion, accusation, hint, refusal): weak
  testimony, or not presentable?
- **Q5.** Strict mode in normal play: block unsupported cases always, or only in
  testing?
- **Q6 (deferred).** The roles of Insight and Confidence in judging (BACKLOG, 54875).

## Related backlog items

From BACKLOG.md: the 54875 section-1 items (evaluator never ran; revisions; defences
stacking; free repeats), "agreement has to reach the vote", "Insight and Confidence
barely shaped reactions", "Independent support versus repetition", "One evaluation
path for generic and structured cases", "Quiet-night evidence", the template gaps
(protection chain, evening sightings vs trace, minion gifts and the totem), and
"Medium relay" / "Martyr promise versus later hanging".

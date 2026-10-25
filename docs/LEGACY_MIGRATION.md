# Belief evaluation: shared judge and native social sim

Status (Oct 25): **re-baselined; the full migration plan is retired.** What remains is
evidence coverage, tracked in [MECHANICS_SUPPORT.md](MECHANICS_SUPPORT.md). History and
measurements: [MIGRATION_PROGRESS.md](MIGRATION_PROGRESS.md). The detailed Oct 23–24
plan (inventory A–F, phases P0–P5) is in git history at commit `00c17c0`.

Read before touching `workshop/` or the belief code in `sim/mind.gd`.

## North star

**The engine judges evidence; the town is a cheap social simulation around it.**
(Original intent, Oct 19–20: "NPCs judge the player's theory; they don't search for
theories.") Check every change against this sentence.

## Terms

- **Shared model (the judge):** the case evaluator in `workshop/` (`case_eval.gd`,
  `jury.gd`, `shared_ledger.gd`, `role_constraints.gd`, `live_activity.gd`), reached
  through `game/workshop_presentation.gd` (presentations) and
  `game/workshop_ownership.gd` (belief refreshes; it parks matching legacy entries and
  writes one joint suspicion vector).
- **Legacy rules:** the native ledger in `sim/mind.gd`, `sim/argue.gd`, `sim/social.gd`.
- **Fallback:** the legacy rules judging something the shared model can't read.

## Scope: a deliberate hybrid

- **The shared model judges anything that is evidence:** presentations, gift readings,
  testimony, sightings and traces, public events.
- **Native, permanently:** trust, pressure, fear, paranoia as a mood, crowd pressure
  (Q1), the vote and nomination formulas (Q3), disclosure, evil strategy, starting
  friend/rival suspicion and paranoia drift.
- **The rule that keeps it honest:** no piece of evidence is judged by both systems.
  Evidence the judge can't read is excluded with a stated reason, never routed silently
  to the legacy rules. Remaining coverage gaps are listed in MECHANICS_SUPPORT.md.
- **Not doing:** a nightly per-NPC solve, moving priors into the world prior, exact
  per-source channel models, deleting the legacy ledger wholesale. Delete legacy code
  only where the shared model fully replaces it.

## Decisions (user)

- **Q1:** public accusations and consensus are social signals, never evidence.
- **Q2:** a demon kill is strong (95:5) evidence of innocence, not proof.
- **Q4:** opinions and accusations are not evidence; hints weakly support a gift claim;
  refusals weakly support suspicion.
- **Q5:** strict mode is for testing only; normal play reports any fallback.
- **Confidence:** live listeners use `scale` mode, the legacy `1.4 − 0.8 × confidence`
  scaling. No per-person theory loop. A stickiness rule (committed conclusions resist
  reversal but yield to clearly strong evidence) is planned.
- **Insight:** NPCs should differ in degree, not direction (Low follows the evidence
  less strongly); attention budgets should limit what an NPC can explain in a reply,
  not what it believes. Planned, not built: belief refreshes still use the card budget.
- **Lies:** an evil source's role declaration is a possible bluff (weight 0.35 per
  declaration); good sources' claims are binding; contradictory routes never void every
  world. Good people may lie about whereabouts at the existing secret-errand rates.
- **Public evidence:** meeting statements, deaths, executions, vote tallies, public
  claims. Anything said in private conversation is that listener's private evidence.
- **Speed budget (user's machine):** meeting entry and presenting about 2 s or less,
  nominations under 1 s.
- **Q3 (agreement to action) is deferred to a tuning pass; check in with the user
  first.** Until then the legacy vote and nomination formulas stand: `need = 0.5 −
  0.12 × (confidence − 0.5) × 2 + 0.1 on day 1 − 0.4 × paranoia`; player terms
  `player_votes_yes 0.25 × trust − 0.05`, `player_accuses 0.2 × trust`,
  `player_defends −0.25 × trust`; `prefers_block −0.4`; Martyr reluctance. The
  execution-priority input exists with weight 0 (`C.SHARED_EXECUTION_PRIORITY_WEIGHT`);
  it's the intended home for a rank-aware vote term.

## Architecture rules (don't regress these)

**Cost model.** Cost ≈ listeners × refreshes × CaseEval calls per refresh × cost of one
CaseEval. Every new feature is costed against it before it's built.

- **Cheap:** a card or factor that is a yes/no fact about each world (who's evil, who's
  the Demon, who holds a modifier, who walked where). It becomes a per-world table.
- **Expensive:** anything that adds hidden state (each source's honesty, which roles are
  in play, which minion type someone is). It multiplies every evaluation. Phrase new
  evidence so it doesn't need one; if it truly does, design it with the user first.
- **One CaseEval per question per run.** `Jury._case_eval` reuses identical (case,
  listener) evaluations within one run; don't route around it.

**Two jury runs per listener, with different jobs.**
- **Belief refresh** (`Shared.evaluate` → `Jury.refresh`): "given everything I hold,
  how do my suspicions move?" No headline, no reply text, no `Solver.analyze`, no
  intermediate claims.
- **Scoped reply** (`Shared.response`, `{"headline_only": true}`): what the listener
  says about the presented case. Its effects are never applied.

**Meetings.** During testimony, refreshes are queued (`World.defer_beliefs`): a speaker
is refreshed just before their turn and everyone once when testimony ends
(`Mind.flush_beliefs`). Speakers still react to everything said before them. Don't
defer further without the user's decision; the next step for feel is pacing refreshes
behind dialogue.

**Movement model** (`live_activity.gd`, the largest cost in long games). Keep work that
doesn't depend on the habitual or evening block out of `_likelihood`'s inner loops. Its
caches key on `movement_inputs()`: if the model starts reading a new card kind, field or
role source, add it there, or the cache returns another listener's result.

**Hard gates.** Nothing an NPC says may void every world. New hard checks in
`role_constraints.gd` apply only to public facts or deductions (mark derived claims
`inferred`); testimony gets the bluff treatment.

**Per-command work.** Anything that already covers the whole audience (like
`WorkshopCanvas.status`) runs once per command, not once per listener.

## Measuring

- **Speed:** `tools/replay_54875.gd` (timings plus a profile of the presentation) and
  `tools/profile_workshop_town.gd`. Numbers only count with full coverage: the tools fail
  if any listener fell back; don't pass `--allow-fallback` to improve a number.
- **Play:** `tools/autoplay.gd`, same seeds with and without `--native` (legacy rules),
  ten-person `--passive`, `--results`. It prints per-day suspicion against the truth
  (top suspect, Demon rank, could-nominate), town agreement (top-3 overlap, peers'
  suspicion of each NPC's top suspect) and every good vote's score against its need.
  `--no-attention` is an experiment switch. Chunks of 10 seeds can run in parallel.
- **Correctness:** `python tools/run_gd_tests.py --godot <exe>`. Known failures:
  `test_social` (false Night Watch story) and `test_text_ui` (two role-hover checks).
  `test_trace` (about 10 min) runs with `--include-slow` before merges that touch
  tracing, logging, determinism or whole-game flow.
- **Acceptance for behaviour work:** shared good-win rate and town agreement at least
  native's on the ten-person passive A/B; no impossible refreshes (each refresh's trace
  reasoning records `impossible`).

## Lessons learned (don't repeat these)

1. **Don't let a cleanup redefine the design.** "Migrate every belief evaluation" read
   as tidying up two engines but inverted the founding intent. Scope changes are design
   decisions; put them to the user as such.
2. **No layer without a cost line and a visible payoff.** Bounded attention, persistence
   theories, private re-derivation and exact channels were each defensible alone; their
   costs multiplied (listeners × refreshes × people × channels), and two of them made the
   town disagree. Ask "would a player notice it gone?" before adding realism.
3. **Never add hidden state casually.** The exact channel model took presentations from
   about 7 s to 151 s because each source's honesty became a hidden fact inside every
   multiplier.
4. **Validate play, not just faithfulness.** Parity tests, exact replays and behaviour
   hashes reward implementing complexity correctly. Run the native-vs-shared bot A/B at
   the end of every phase; it found in an hour what weeks of parity tests missed.
5. **One lie must never void everything.** Hard gates on testimony made a single bluff
   erase a careful listener's beliefs; the smartest NPCs were hit hardest.
6. **What an NPC says must come from the same computation as what it believes.**
   Divergent paths produced "you've convinced me" with no belief change.
7. **Profile before optimizing.** Plausible hotspots (cache hashing, the explanation
   search's body) were wrong twice; the real costs were elsewhere (a per-listener
   status check that already covered the whole audience; repeated CaseEval runs).
8. **Keep caches cheap.** Memoising on whole inputs (hashing the view) cost more than it
   saved; key on the small inputs that actually vary.
9. **Hand-offs carry intent and acceptance criteria, not just steps.** Faithful
   execution of a wrong spec is still wrong ("private reports compete for attention"
   made NPCs forget their own readings).
10. **State a speed budget up front.** Without one, each feature spent the last pass's
    savings and performance became an endless chore.

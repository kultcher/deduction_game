# Case reasoning: the plan

Status: plan (Oct 23). It supersedes the Case Workshop plan and integration docs. The
useful findings from those are summarised in [CASE_WORKSHOP_FINDINGS.md](CASE_WORKSHOP_FINDINGS.md).

## Goal

The player builds cases on a **red-string board**: a premise ("Greta is the demon",
"Constance's readings can't be trusted"), supported by linked evidence cards whose
questions the player answers. Listeners judge the case quickly enough to feel instant,
with reasoning that:
- can see **joint deductions** (Surveyor plus Rumormonger forcing Hollis in seed 692);
- weighs doubtful sources **granularly** (a sleepwalker's whereabouts "lie" doesn't
  discredit their Seer readings);
- leaves NPCs **persuadable and plausibly wrong**, because the player is the detective;
- lets NPCs reason **beyond the player's framing**, from their own evidence.

## The board (UI)

**Final verbs:**
1. **Premises:** a claimed conclusion about a person or about a piece of evidence.
2. **Cards with inline answers:** a card's question ("who in this Seer pair?") answered
   on the card itself. Unknown answers stay legal.
3. **Link:** connects evidence to a premise or to other evidence. Linked statements that
   contradict merge automatically into a contradiction card, which offers the
   challenges directly ("one of these is false: which?").
4. **Challenges** (right-click a card): **unlikely**, **misled** or **lying**. These are
   attached modifier cards, not contradictions of the card's own answers.
5. **File case:** turns the premise into a presentable card, which can become a
   premise in later cases (a day-2 "Constance is unreliable" supports a day-4 case).

**Dropped:** the mock jury, preview effectiveness and save/open. They were test
scaffolding. The fixture canvas and lab scenes go with them once their tests are
ported.

**UX principles:**
- Start from a person: pin the suspect and attach cards to them.
- **Live string colours:** green (fits), red (contradicts), grey (doesn't bear), with a
  one-line reason.
- Soft auto-layout, since positions carry no meaning.
- A tray for new evidence, and clusters collapsed per person, for late game.
- After presenting, show listeners' responses on the board itself.
- One board in the long run: the workshop becomes the case board rather than a copy of
  it.

## Architecture

| Layer | When | Engine |
|---|---|---|
| Analysis: role variance, solvability, seed difficulty | Offline, or at case load | Full solver and batch tools |
| An NPC's own view | Each night (and when private evidence arrives) | One solve on public evidence plus their own knowledge |
| Judging a presented case | At presentation | One solve on the case's linked cards, likelihood-weighted per listener |
| Social behaviour (trust, pressure, votes) | As now | The existing ledger and vote formula, fed by the above |

**One evaluation path per gift.** A gift is either fully supported by the new
interpreter for every listener, or it uses the native rules for every listener. There
is no per-listener fallback: the same case must not be judged by two engines in one
meeting.

### The world solve

- **Domain:** alignments plus modifiers (Marked, red herring, …), from the public setup
  rules (`world_domain.gd`). Movement, traces and timing stay **out of the domain**.
  They're scored as per-world likelihoods, so the domain stays small as roles are added.
- **Hard constraints:** `solver.gd` bitmask filtering. It measured 0.11 ms per solve
  (575 solves, 65 ms total, on the 5,040-world ten-person domain).
- **One solve per presentation** over the linked cards gives the surviving worlds for
  joint deductions. One more solve per listener adds their private knowledge.

### Weighing doubtful evidence without the 2^u mixture

Each surviving world gets a weight, the product over cards of:
- *p* (the card's credibility) if the card holds in that world;
- (1 − *p*) × q (the chance of that false report) if it doesn't.

With independent errors this is exactly the old exhaustive mixture, at worlds × cards
cost. Contradictions just make worlds unlikely; no leave-one-out step is needed.

**Correlated errors are handled per source and per channel, not per card:**
- **Gift honesty** (are their readings knowingly false?) and **gift accuracy** (poisoned,
  Delusional, misread) are separate factors. Accuracy is scoped to an impairment window,
  not the source's whole history.
- **Testimony honesty** (whereabouts, alibis) is another separate factor. Good NPCs lie
  about whereabouts for innocent reasons: secrets, hidden night-walking gifts, and
  sleepwalkers who don't even know. Evil's good self blends in the same way. A caught
  whereabouts lie lowers testimony honesty. It moves gift honesty only a little, and
  more when the lie is close to a crime or contradicts a claimed gift.
- A source whose several readings are wrong together shares one factor, so the cost is
  2^(sources × channels involved) rather than 2^cards. A case rarely involves more
  than three or four sources.
- Keep the granularity, and only coarsen it if measurements require. The budget comes
  from removing the per-person consequence loop, not from collapsing channels.

### What listeners consider (keeping the player the detective)

- **Links are the argument.** A listener combines cards jointly only across links the
  player drew, plus links within their own evidence. Unlinked cards are weighed alone.
- **Insight** limits how many links they follow, how many rivals they look at, and
  whether they notice a contradiction the player didn't merge.
- **Rivals:** besides the player's theory, a listener scores their own best theory (from
  their nightly view) and a few nearby variants: swap the accused with the other person
  in a pair or group, or treat a key reading as misled. Both come from the same
  weighted surviving worlds, at no extra solve.
- **Two outputs per listener:** belief (does this make it more likely?) and action (is
  it enough to act on, given urgency, trust in the player and counterevidence?). Action
  feeds nominations and votes as an execution-priority term.
- **Challenges are questions, not settings.** A player's "misled" or "lying" asks the
  listener to weigh that explanation; supporting cards move it. A listener can agree a
  report is unreliable while rejecting the charge of lying.

### NPCs' own reasoning (beyond the player's framing)

One solve per NPC each night over public evidence plus their private readings,
observations and accepted claims. That gives their shortlist of worlds and leading
suspects, through the same Insight limits. It feeds:
- their own nominations and accusations (with provenance rules intact);
- the rival theories above;
- the patterns from playtest 61251: a Seer's record, repeated trace matches.

Evil NPCs run it on their good self (the shadow); the real evil mind is unchanged.

## Kept and dropped from `codex/case-workshop`

- **Keep:** `solver.gd`, `world_domain.gd`, `role_constraints.gd`, `chronology.gd`, the
  live evidence contract (`Game.workshop_snapshot`, `live_evidence.gd`,
  `workshop_bridge.gd`), the case graph and canvas model, the shared ledger's
  ownership and retraction, the checkpoint specimens, and the semantic tests.
- **Replace:** `support_model.gd`'s 2^u mixture, the per-person loop in
  `consequences.gd`, the jury and ghost juror (test scaffolding), and the per-listener
  fallback in the live assessment.
- **Re-check, then keep or replace:** `reasoner.gd` (bounded attention, now the Insight
  layer) and `movement_model.gd` / `live_activity.gd` (likelihoods; keep them out of the
  domain).

## Performance budget

- **Whole-town presentation target: under 100 ms** (ten listeners), measured on the
  development machine with a cold cache, including the per-listener weighting.
- **Nightly NPC solves:** under 50 ms for the town, off the UI thread if needed.
- Benchmarks are run commands, not committed JSON. Record headline numbers in this doc.
- **Domain growth** (fifteen-person towns, more modifiers) is the main risk. Measure the
  domain size per setup, and prune by evidence dependencies before considering C#.

## Foundation pass (next)

1. **A new `CaseEval` module:**
   - input: a case graph plus the snapshot contract plus a listener view;
   - one solve on the linked cards;
   - likelihood weights with per-source, per-channel honesty and accuracy;
   - output: weighted surviving worlds, then belief and action for the premise, the
     effects on everyone, and rival theories.
2. **Port the checkpoint specimens** as the referee and record where answers differ from
   model v5, case by case: which differences matter to the player?
3. **Wire `Session.present` and the live presentation through `CaseEval`** for the
   supported gifts, removing the per-listener fallback. Unsupported gifts use native
   rules for every listener.
4. **Timing tests:** a ten-person presentation and the nightly solves, against the
   budget.
5. **Then the UI subtraction** (verbs above, inline answers, live string colours), the
   nightly NPC views, and the execution-priority term in votes.

## Risks

- **NPCs too astute:** exact joint results only across drawn links and within Insight
  limits. Validate with three playstyles on the same cases: no guidance, sound guidance
  and persuasive wrong guidance. Each should give a different outcome.
- **Honesty granularity versus budget:** measure before collapsing channels.
- **Domain growth** as roles are added: keep movement and timing as likelihoods.
- **Two systems during migration:** gate whole gifts, never individual listeners.

# Social and trust pass: spec

Agreed with the user on Oct 30, 2026, from Argon's review of the tuning catalogue and Claude's notes. **Phase 1 is structural and is built first. Phase 2 sets numbers and follows a bot baseline. Phase 3 adds a feature.** Items the user didn't comment on use Claude's defaults.

Not changing:
- **Fear:** it suits Clocktower pacing, where people open up by about Day 3.
- **Disclosure growing by day.**
- **Vote formulas based on suspicion.** We'll measure how often NPCs accept a case and then vote no before considering a model-based vote term.

## Phase 1: structure (built Oct 30)

1. **Rapport and credibility.** Trust in the player becomes two numbers.
   - **Rapport** (`n.trust`, unchanged name) is how the NPC feels about you. It governs disclosure, requests, approaches and confidences, and it takes every existing trust gain and loss.
   - **Credibility** (`n.credibility`, new, starts at 0.5) is how much your word counts. It replaces trust in the player wherever your evidence or stance is weighed:
     - the shared model's listener `trust`, which covers presentations, player-sourced cards, the source-trust step, reading challenges and the circumstantial hub;
     - the vote terms when you vote yes, accuse or defend;
     - legacy hearing weights, for consistency until that code is retired.
   - **The track record.** Each NPC records the conclusions you've argued to them (`n.claim_record`): every presented case, plus your nominations and accusations, which everyone present hears. Only alignment conclusions count, evil-leaning or good-leaning, latest per target.
   - **The daily update, at dawn.** The NPC evaluates their own evidence *without* your presentations and without what you told them in conversation, so it isn't circular. For each recorded claim, agreement is how far their own P(evil) for that person now sits from the average, in the claim's direction, between −1 and 1. Then:
     - target = 0.5 + `CRED_SPAN` (0.4) × mean agreement;
     - credibility moves halfway to the target each day (`CRED_STEP` 0.5), clamped to [0.1, 0.9];
     - with no claims, credibility doesn't change.
   - **Proof, when it exists, flows through.** A Demon victim you called evil has low P(evil) in everyone's own view, and a Gravedigger reading or a caught lie lands the same way.
2. **Fading slights (rapport).**
   - **Recorded grievances:** each night, a grievance recovers `GRIEVANCE_FADE` (0.25) of its drop, about a 2.4-night half-life.
     - Minor ones fade completely.
     - Serious ones (≥ 0.12) fade only to `SERIOUS_FADE_LIMIT` (half the drop) and keep any trust cap.
     - An apology's repair counts toward the same limit, so the two never repay more than was lost.
   - **Smaller drops** below the grievance threshold (questions, fatigue) collect as `n.friction` and fade at the same rate.
3. **Friend and rival bonds counted in two places only.** They stay in the listener's starting estimate (npc_trust halving or doubling the odds) and in source credibility (npc_trust in `Jury._source_trust`).
   - The starting-suspicion offsets for friends, rivals and Lovers are removed: everyone starts at the base, 0.1.
   - The vote's `trust_in_nominee` term is removed.
4. **Privacy out of starting rapport:** it becomes base 0.425 + the existing jitter, the old mean at privacy 0.5. Privacy still gates openness.
5. **The Gossip cutoff removed.** Below Gossip 0.2, an NPC no longer shares nothing: the share count formula gives them 1 item.
6. **Paranoia drift becomes urgency.**
   - The nightly flat rise in everyone's suspicion is gone. Under the relative starting estimate it carried no information, and it pushed everyone toward the vote bar.
   - Instead the vote bar drops by `VOTE_URGENCY_PER_DEATH` (0.02) per death, which Composure doesn't cancel, alongside the existing paranoia term.

## Phase 2: numbers (after a bot baseline)

- **Disclosure jitter:** ±0.2 → ±0.1, and one roll per NPC per day (a daily hash, like fear), so asking again the same day can't fish.
- **Secret-keeping rapport:** a one-time bonus, then shrinking each night, instead of the same amount every night.
- **Gossip rapport (+0.02):** only when the listener believes the rumour. A small loss when it attacks someone the listener trusts.
- **NPC-to-NPC trust reacts:**
  - a vote to hang me, a public accusation of me, or being caught lying about me: −;
  - defending me on the block: +.
- **Minion grief:** exempt only once the hanged person is publicly shown to be evil (a Gravedigger reading, Martyr proof).
- **Confidence becomes directional:** it resists only movement against the NPC's current lean. Fresh and reinforcing evidence come through at normal strength. Persistence mode stays off in live play, for speed and town agreement.
- **Measure first:** own evidence now steps about 1.5× as far as before, and the headline weights all start at 1.0. Check both first.

## Phase 3: Warden credit for quiet nights

- **When a Warden believes they saved someone:** a quiet night (the Demon kills every night from night 1) while a Warden guarded someone. The Warden's belief is the chance their guard was the save, which is lower if they know your ward, a Veteran claim or the Sexton's knell could explain it.
- **Claiming credit:** above a threshold, the Warden claims the save, privately or publicly by the normal disclosure rules.
- **The protectee was attacked, so likely good.** That's evidence in the Warden's own view and for anyone who believes the claim. It joins the existing quiet-night protection signal.
- **Trust:**
  - the Warden's trust in the protectee goes up;
  - if the protectee believes the claim, their trust in the Warden goes up.
- **Evil faking saves:** later, as a measured evil-strategy change.

## Testing and measurement

- **Phase 1:** a focused suite plus the regular suite. Tests that pinned the old formulas are updated to the new rules.
- **Before phase 2:** a bot baseline (passive and active, ten-person). Track:
  - good wins;
  - town agreement;
  - how often NPCs accept a case and then vote no;
  - how often evil's frames land;
  - average credibility over the game.

## Phase 1 as built (Oct 30)

- **Credibility** lives in `game/credibility.gd`.
  - `record` is called for every presented case (`GamePresentation._evaluate_deduction`). `record_public` is called for your nominations and your defend or accuse statements.
  - `dawn` runs from `Game._resolve_night`, before the morning report.
  - The check against the NPC's own evidence drops ledger entries carrying your word (`tell:`, `for:`, `arg:`) and your presentations.
  - Evil NPCs are scored on their good-self view.
  - The shared model's listener `trust` is now credibility, and `rapport` rides alongside it.
- **Fading** is `Mind.fade_slights`, at the start of `end_of_day_trust`.
  - Grievances carry `repaired`, and apologies respect the same limit.
  - Small slights are in `n.friction`.
- **Fixes to source trust found while building this:**
  - It now counts only cards that are someone's word: readings, testimony, sightings, claims.
  - A "context" card counts only when it carries a teller's account, not when it re-cites a public record.
  - It reads everything the listener holds, not just what this run attends to.
  - Without those, citing an already public silence changed the weights.
- **Removed:** `Social.paranoia_drift` and the vote's `trust_in_nominee` term.
- **The Gossip cutoff** now means the share count's floor is 1.
- **Tests:** `tools/test_social_trust.gd` (new). Fixtures updated where they pinned old rules:
  - `test_argue`: re-weighing follows credibility;
  - `test_sighting_followup`: the least talkative share one;
  - `test_workshop_clerk_archivist_seer`: the player factor reads credibility;
  - `test_prior_mapping`: uneven starting suspicion now set explicitly;
  - `test_workshop_profile_traces`: the deflection pick set explicitly, since bonds no longer seed suspicion.

## Phase 2 as built (Oct 30, branch `claude/social-phase2`)

- **Disclosure jitter** is ±0.1, a fixed daily sample per NPC (`_day_roll(id, day, 0x0BE7)`) with no world RNG draw. This changes trajectories by removing one draw per ask.
- **Secret-keeping rapport** is the full bonus the first night, then × `SECRET_KEPT_DECAY` (0.5) each night after (`n.secret_kept_nights`).
- **Gossip and the teller** (`Social.gossip_bond`):
  - +0.02 when the listener's suspicion of the teller is below 0.4;
  - −0.02 when the share runs down someone the listener trusts at 0.65 or more (an opinion, a case, a sighting, or an implicating reading);
  - otherwise 0.
- **NPC-to-NPC trust reacts to meetings:**
  - a surviving nominee loses 0.1 trust in each yes voter and gains 0.03 in each no voter;
  - the target of a public accusation loses 0.1 trust in the accuser.

  "Caught lying about me" isn't built: there's no clean hook for it yet.
- **Grief** is skipped when the mourner's own suspicion of the hanged friend is 0.6 or more. This replaces "publicly shown evil", because a Gravedigger reading comes only after the grief.
- **Confidence is directional** (`Jury._directional`).
  - The `1.4 − 0.8 × Confidence` factor applies only to moves against the listener's lean. Every other move gets 1.0.
  - The lean is their suspicion at the end of the previous day, centred on their own average, with a dead zone of `LEAN_MIN` 0.05. It's frozen per day in `workshop_state.committed_lean` (`Game._resolve_night`), so refreshes stay idempotent.
  - On Day 1 there's no lean, so no resistance.
- **Tests:** `tools/test_social_phase2.gd` (new). Updated to the new rules: `test_backlog_batch3` (the jitter is now a daily sample) and `test_workshop_consequences` (the step is now source trust plus directional Confidence).

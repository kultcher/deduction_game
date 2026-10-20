# Meeting flow: nominations, cases, defences, supporters

Status: step 1 built (Oct 19; DESIGN, "Meeting flow, step 1"). Steps 2–6 planned. It absorbs these backlog items:
- "Rebuttals and excuses" (step 3 of docs/shadow_self_plan.md);
- "Nominations make a case";
- "Outing yourself to defend someone";
- "Meeting and vote talk";
- "Last words".

This doc is the step-by-step plan. Each step ends with a check, and steps should land as
separate commits.

## Goal

Today the meeting runs as three blocks:
1. **Testimony** (`Mind.meeting_testimony`): claims, readings, accusations.
2. **Nominations** (`Mind.next_nomination` → `game._show_nomination`): one line of
   reason.
3. **A silent vote** (`Mind.vote`).

The accused never answers, and nobody speaks for them. Hidden night walkers hang for
being seen out (Isolde in 55774, Constance in 96773).

Target: **one nomination at a time**, each run as a small trial:

1. **Nomination and the nominator's case.** They recap the public evidence that drove
   their suspicion (cosmetic) and may bring out new evidence: a hint, or a claim plus a
   reading.
2. **The defence.** The nominee answers, from a set of moves (below).
3. **The player's turn.** Add your voice (accuse or defend, optionally with a card), or
   pass. This is the natural break in the log.
4. **Supporters**, at most 3 speakers, picked by a director so the player sees as little
   as possible while the vote still turns out right.
5. **The vote**, silent as now. If the nominee is hanged, their last words.

There's an optional pacing-only "continue" between steps when the text runs long.

## Settled design decisions (from the user)

- One nomination process at a time (BotC style).
- The player acts after the defence, before the supporters.
- **Recapping old evidence has zero impact**, by construction: the ledger never stacks a
  repeat. **New evidence in a case has exactly the impact it would have at any other
  time,** the same as the opening info dump.
- Provenance rules apply to everything said (`Mind.citable_reason` / `reason_status`).
  A private reason is hinted at or revealed through the accusation tiers (`_accuse_tier`,
  `_go_public`).
- **Revealing concrete information** lowers suspicion most, but isn't a free pass: it goes
  through normal credibility. **Other defences sway little**, mostly with people who trust
  the speaker.
- **Vibes supporters** may remind the town of existing cover ("Isolde could be what the
  Clerk read her as"). These are reminders for the player, near-zero sway with the town.
- **Supporters are queued, at most 3 shown.** The director shows the smallest combination
  that gets the vote to where it would land anyway, in random order, padding with vibes
  speakers. Those not chosen simply didn't speak: no effect on anyone, and they keep
  their material for later.

## What exists today (code pointers)

- **Evidence memory:** `n.ledger` (eid → entry). Each entry holds:
  - `effects`: `[target, delta, conf_scaled, why, public_why]`;
  - `applied`: the current contribution per effect index;
  - `meta.kind`;
  - `rel`, the support source.

  So "what drove my suspicion of X most" means summing `applied` over effects targeting
  X, per entry. **Shared readings use the same eid in every listener's ledger**
  (`info:<src>:<day>:<role>`). That's the common currency for defences.
- **Reasons and provenance:** `n.sus_why`, `n.sus_src`, `reason_status`,
  `citable_reason`, `reading_strength`, `reveal_cost`, `_accuse_tier`, `_go_public`
  (claim plus shared readings, as cards), `n.hints` / `answer_hint`.
- **The meeting:** `game._start_meeting`, `_meeting_command`, `_next_npc_nomination`,
  `_show_nomination`, `_nomination_command` (the player's `accuse`/`defend` statement
  with a card, which calls `Mind.public_case`), `_after_vote`, `_close_meeting`.
  `_present_deduction` is the player's once-a-day floor.
- **NPC nominations:** `_good_nomination`, `_evil_nomination` (shadow plus override),
  `next_nomination`, which picks the top candidate. **Votes:** `Mind.vote` (shadow plus
  override for evil).
- **Existing defensive behaviour to reuse:**
  - `_afraid` (deterministic fear);
  - own-lie admissions (`Argue._own_lie`, `n.lied_nights`);
  - secrets (`n.secret`, confessions in the night answer);
  - the red herring (`n.red_herring` on the Seer);
  - `Gifts.clears` / `Gifts.implicated`;
  - the Martyr's reluctance in votes;
  - the desperation play (planned in the shadow plan).
- **Evil:**
  - `Mind.shadow_eval` / `shadow_run` (the good self);
  - `Mind.evil_override` (stakes − deviation × exposure > caution);
  - `Evil.exposure`, `Evil.caution`, `Evil.teammate_value`;
  - `Evil.bluff_reason`, plus fake readings in `n.info_log` (`fake: true`).
- **Public record:** `w.public_event` / `w.public_log`, which feeds `Evil.public_heat`.
  It has kinds `accusation`, `nomination`, `reading` (with weights), `vote_yes`, `clear`.
  The consensus effect lives in `Mind.refresh_consensus`, via `w.stances`.
- **UI:** `ui/meeting_view.gd` (Codex's meeting circle, with step animation:
  `_start`, `_count_next`) and the meeting buttons in `ui/main.gd`.

## Step 1: the nominator's case (sim only)

1. `Mind.case_against(w, n, t) -> Array` returns the top evidence items for n's
   suspicion of t: ledger entries ranked by summed `applied` toward t, at most 3,
   `delta > 0` only. Each item comes back as
   `{eid, text, kind: public|player|private|none, strength, entry}`, using the same
   classification as `reason_status` but per entry:
   - an own reading's eid → its `info_log` entry;
   - anything else → public.
2. Speaking the case, in `_show_nomination` / `next_nomination`:
   - **Public items:** recap lines, cosmetic. Make no new card if the fact is already on
     the board; otherwise a normal card (no new ledger effect: listeners already have
     it).
   - **The strongest private item** goes through the same hint-or-reveal decision
     (generalise `_accuse_tier` to take an item rather than `sus_why`). A reveal calls
     `_go_public`, giving the usual cards and the usual listener effects. A hint records
     `n.hints` and makes a hint-marked nomination card.
   - **No items:** today's vague line.
3. **Evil nominators** build the case from their good self's ledger
   (`shadow_eval(... case_against(sh, t))`), cite only what the town has, and may reveal a
   fake reading in their bluff through `_go_public`. Evil already does that at claim
   time; a nomination is just another moment for it.
4. Log `think` topic `nomination_case` with the items and their kinds.

**Check:**
- A test: a Seer with an unshared yes on t nominates t, and the case either hints or
  reveals (never cites a private reading). A recap of a public reading leaves listeners'
  suspicion of t unchanged.
- Bot runs (150 games at 7 and 10 townsfolk) comparing win rate and good NPCs hanged.

## Step 2: defence moves (sim only)

`Mind.defend_self(w, d, nominator_case) -> {lines, facts, moves}`. The nominee picks one
or two moves; each one applies **listener-side effects** on the shared eids, weighted by
each listener's trust in d (`npc_trust`) and d's honesty. Moves, strongest first:

1. **Reveal:** claim the gift and share readings (`_go_public`), when that would clear or
   redirect: a reading that clears them, or an alibi a gift explains (the Night Watch was
   out watching; the Lamplighter walked the lamps). The strongest effect, and only
   through normal credibility.
2. **An excuse for being out:** a night-walking gift, or a secret if they have one (a
   confession: reuse the night-answer confession path). It lowers the weight of the
   sightings against them in each listener's ledger. Add a `meta.excused` multiplier
   read by `_final_weight`, so it's undone if the excuse is later disproved.
3. **"Misled":** the source's gift may have failed (poisoned, Delusional). It raises doubt
   on that eid's source (`discounted`), a little.
4. **"Lying":** they accuse the source of lying. A small hit to the source's honesty in
   listeners; more likely when confident, riskier if the source is trusted.
5. **"The other one in the pair":** for a pair reading (Seer, Archivist), push suspicion
   toward the other name, a little.
6. **"I'm the red herring":** when a Seer's yeses keep landing on them.
7. **Fear or desperation:** "If I say what I am, I'll be dead by morning"
   (`_afraid`), or "I don't know what's going on, but I know I'm not evil." Almost no
   sway.

**Choosing:** good NPCs choose by what's true for them (a real gift, a real secret,
whether they know they're misread). **Evil chooses as its good self would**
(`shadow_eval`) **plus override**: an evil defender uses its bluff, a fake secret, or
desperation. This is shadow step 3 folded in.

Each move is logged (`think` topic `defence`) and produces a card when it claims
something checkable (a claim, a secret, an accusation of lying). Fear and desperation make
no card.

**Check:**
- Scenario tests:
  - an accused Lamplighter excuses the sighting, and listeners' suspicion drops (more
    with high trust);
  - a "lying" defence against a trusted Seer barely moves anyone;
  - "the other one in the pair" shifts some suspicion to the other name;
  - an evil defender's move matches its bluff.
- Bots: hang rates of hidden night walkers (Lamplighter, Veteran, Sleepwalker, Warden)
  before and after. **This is the "self-framing" hole, so expect them to drop.**

## Step 3: supporters (sim only)

`Mind.support_queue(w, nominee) -> Array` of candidate statements from the living,
excluding the nominee and nominator. Each candidate is
`{who, side: for|against, kind, strength, est_sway, lines, facts, apply: Callable}`:

- **Exonerating evidence:** a reading that clears the nominee (`Gifts.clears`), the
  speaker's own sighting of them at home, a Warden who guarded them. This uses the
  accusation tiers mirrored: `reveal_cost` against the strength of the clearing, giving
  hint or reveal. It's the backlog's "outing yourself to defend".
- **Piling on:** the same as step 1's case, for others who suspect the nominee.
- **Vibes:** trust in or distrust of the nominee, optionally with a **reminder** of an
  existing card that offers cover ("Isolde could be what the Clerk read her as"). Its
  effect is near zero (`C.VIBES_SWAY`, around 0.02).

Nothing applies at build time. Each candidate's `apply` callable does its effects only if
it's chosen in step 4. Evil supporters go through the shadow plus override, like
everything else.

**Check:** unit tests that each kind builds, that `apply` is the only place effects
happen, and that provenance holds (no private reading quoted without a reveal).

## Step 4: the director (which speakers are shown)

`Mind.pick_supporters(w, nominee, queue) -> Array` returns at most 3 entries.

1. Estimate the vote without supporters: for each voter, the current `vote` decision,
   computed on copies or with a dry-run flag on `vote` so no state changes and no
   `w.rng` draws (use a separate RNG, as the shadow does).
2. `est_sway` per candidate: the summed expected change in yes probability across
   voters, from its effects scaled by each voter's trust.
3. Pick the smallest set of non-vibes candidates (at most 3) that reaches the outcome
   the full queue would reach. Fill the rest with vibes, up to 3 total, shuffled.
   - If no candidate changes anything, show 1–2 at random, preferring vibes.
   - Ties go to the less revealing statement (hint over reveal, public over new).
4. Apply only the chosen ones' `apply`. Unchosen candidates have no effect and keep
   their material: hints stay unspoken, readings unshared.
5. Log `think` topic `director` with the queue, the estimates and the choice. This is the
   first director logic; keep it general (`sim/director.gd`), since storyteller Medium
   visits and solvability checks will live there later.

**Check:**
- A test: with one strong exonerating reading, two medium ones and two vibes, only the
  strong one plus vibes are shown when that's enough, and the two medium readings stay
  unshared.
- Bots: no change in the vote outcome distribution compared with applying the full
  queue (sample both); cards per meeting drop.

## Step 5: the meeting sequence and UI (with Codex)

1. **The game state machine** (`game.gd`): for each nomination, the states
   `case → defence → player_turn → supporters → vote`. `player_turn` reuses the
   existing `accuse` / `defend` statement with an optional card, plus `pass`. A pacing
   `continue` prompt when a step produces more than about 6 lines (a knob).
2. Keep `meeting_testimony` (the opening claims and readings) before the first
   nomination.
3. **Last words** on a hanging: one flavour line (`Dialogue` voice if they have one).
   Good: a plea or a last pointer. Evil: kept in character with the bluff.
4. **UI** (`ui/meeting_view.gd`, `ui/main.gd`): the speaking order and highlights per
   step, a "Continue" button, and the player-turn buttons (Accuse… / Defend… / Pass).
   **Coordinate with Codex,** who owns the meeting view.
5. **Bot** (`tools/autoplay.gd`): drive the new states (pass by default, and use its
   existing accuse/defend logic at `player_turn`).

**Check:**
- `test_ui` and `test_town_ui` updated for the new states, with screenshots of a full
  nomination.
- Bot runs complete without stuck games.

## Step 6: measure and write up

150 games at 7 and 10 townsfolk against the step-0 baseline. Compare:
- good wins, good NPCs hanged, evil hanged;
- hang rates of hidden night walkers;
- cards per meeting, lines per meeting;
- director choices per meeting.

Update DESIGN.md with a section per step and the knobs, and move the absorbed backlog
items to Closed.

## Gotchas and risk areas

- **Double counting.** A case's recap must not re-apply effects. Rely on the ledger's
  no-stack rule, but test it, especially through `public_case` (the player's statement),
  which uses `pub:` eids.
- **Defence effects must be undoable.** Excuses and doubts go into the ledger as
  multipliers or entries that `recompute_beliefs` re-derives, never one-off suspicion
  edits. Otherwise a disproved excuse leaves residue.
- **Provenance everywhere.** Every line in cases, defences and supporters goes through
  `citable_reason` or a reveal. The director never "shows" a private item without the
  speaker's own reveal decision.
- **Director determinism.** Dry-run votes must not draw from `w.rng` or touch NPC
  state. Use copies or a flag, plus a separate RNG. Otherwise picking speakers changes the
  game.
- **Information hiding mustn't be a tell.** Never always showing exactly one strong
  statement would itself become a pattern, so random padding with vibes is part of the
  design. Watch for "only one real speaker = it's decisive".
- **The shadow boundary.** Evil defences and supporters go through `shadow_eval` plus
  `evil_override`, never raw evil logic.
- **Silenced NPCs** can't defend or support (the Breathstealer). The nominee being
  silenced means **no defence**, which is a big deal: log it, and make sure the UI says so.
- **The Martyr:** their reluctance in votes stays. A Martyr whose chosen person is
  nominated is a natural supporter.
- **Text volume:** with 10 townsfolk and several nominations, the pacing `continue` and
  the 3-speaker cap matter. Measure lines per meeting in step 6.
- **The cite rule and hints:** a hint from a case or defence adds to `n.hints`, so the
  player's "ask why" works for these too.

## Out of scope here

- Double claims and their logic (backlog: "evil backs into a bluff"). Defences that
  reveal a gift will create more double claims, so watch for them, but the current
  claim-resolution logic handles them for now.
- Group conversations, vote explanations beyond last words, and the full-screen board.

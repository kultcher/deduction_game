# Mechanics support: evidence the shared judge still can't read

Status: open work list (Oct 25). Owner: Codex, reviewed by the user. Read
[LEGACY_MIGRATION.md](LEGACY_MIGRATION.md) first, especially the north star, the
architecture rules and the lessons learned.

**Goal:** every kind of evidence in the game is judged by the shared model, once.
Anything it can't read is excluded with a stated reason, never silently routed to the
legacy rules. This is coverage work, not new realism: no new cognitive layers, no new
hidden state, no exact source-channel models.

## How to work through this list

- **Order:** top to bottom, unless the user says otherwise.
- **Per item:**
  - targeted tests;
  - `tools/replay_54875.gd` with no step more than about 10% slower than before the item,
    unless the cost is flagged to the user with a reason;
  - no impossible refreshes (each refresh's trace reasoning records `impossible`).
- **Per two or three items:** a ten-person passive A/B (`tools/autoplay.gd` with and
  without `--native`, 10–20 seeds). Report good wins, town agreement and Demon rank
  against the previous run.
- **Keep progress notes short:** what changed, what was measured, in a few lines per
  item, in MIGRATION_PROGRESS.md.
- **Run the full suite** and `test_trace` (`--include-slow`) at the end of the list or
  before a merge, not after every item.
- **Performance rule of thumb:** a card that is a yes/no fact about each world (who's
  evil, who's the Demon, who holds a modifier, who walked where) is cheap. Anything that
  needs a new hidden fact multiplies every evaluation; stop and design it with the user.

## 0. Conclusion types the shared model doesn't judge (top priority)

**Implemented Oct 25 (Codex), within the approved fact-only scope.** Not-Demon,
modifier-holder, cited good-gift declaration, and identified reading questions use
the shared model, including board controls. Protection/mercy preferences count as
social speech. Generic innocent-secret and specific Red Herring premises remain
explicitly unsupported where no existing fact establishes them (user decision);
no hidden state is added for those questions. Challenge table prerequisite from
item 3 is implemented. Tests and replay measurements: MIGRATION_PROGRESS.

**Starting state:** the legacy rules accept 18 conclusion types; the shared model accepts 7
(`evil`, `good`, `demon`, `minion`, `marked`, `suspicious`, `conflict`;
`LiveAssessment.CONCLUSIONS`). A presentation with supported evidence but another
conclusion type is judged by the legacy rules, visibly: an immediate `[dev]` line, a
`conclusion_type` fallback record, and the morning count. In bot games, `lied`,
`secret_mod` and `truthful` came up most.

**Suggested mappings,** all on existing world facts, so all cheap:
- `notdemon` → the `demon` question, negated.
- `lied`, `truthful`, `misled`, `unreliable` → the existing reading-challenge machinery
  (lying / misled / unlikely). Fix its speed first (see item 3).
- `secret_mod`, `secret`, `red_herring` → the modifier facts each world already has
  (`modifier`, `holders`), as `marked` does.
- `role`, `notrole` ("X is the Seer") → a role-declaration question: X is good and
  their claim holds, using the soft-testimony role check. Design it with the user if it
  needs more than that.
- `protect`, `spare` → preferences, not evidence. Keep them native as social speech
  (like bare beliefs) and stop counting them as fallbacks.

## 1. Revenant curse histories

**Implemented Oct 25 (Codex), using the user's approved bounded epoch design.**
Public execution/vote/activation/restoration receipts supply the boundary. Only a
curse expands worlds, by eligible original-good voters; no referee turnee is read.
Original/current premises and reading times stay distinct; native voter bumps are
parked. Incomplete public histories remain explicit. Measurements in MIGRATION_PROGRESS.

**State:** once a curse fires, every case falls back to the legacy rules (inventory
B10, C8), and `curse` / `curse_lifted` cards are unsupported.

**Intent:** a turned NPC changes alignment mid-game. Evidence from before the turn
describes the original alignment; evidence after it describes the new one.

**Approach:** design first, with the user. Prefer epoch boundaries that are public
(the curse event, the vote that triggered it, a freed soul). Use the existing dated
vote receipts for who voted. If who turned is hidden, at most one small extra fact per
world (which of the eligible people turned), only once a curse has fired, and only for
evidence dated across the boundary.

**Performance risk: medium.** That extra fact multiplies worlds by the number of
eligible people. Keep it out of games with no curse.

## 2. NPC-to-NPC sharing as evidence

**Implemented Oct 25 (Codex).** Canonical reading/sighting receipts and endorsed
player-case roots retain teller provenance and hearing weight; native wrappers are
parked. Repeats and additional tellers do not become independent facts. Quoted
accounts and opinions are not promoted to endorsed evidence. See MIGRATION_PROGRESS.

**State:** sightings and readings told NPC to NPC (C3), and the player's case relayed
by an NPC (C5), are legacy ledger entries. Opinions (C4) are already excluded (Q4).

**Intent:** what one NPC tells another becomes a receipt in the listener's evidence,
with provenance (who told whom), credited by trust in the teller and deduplicated by the
underlying fact. This is likely the largest remaining cause of the town disagreeing
(see the agreement numbers in MIGRATION_PROGRESS).

**Performance risk: medium.** Listeners will hold more cards:
- `CaseEval` cost grows with the number of readings weighed, and past 16 readings its
  per-world keys switch to a slower form. Measure late-game cost on the Day 3–4 fixture
  (item 9).
- Shared sightings feed the movement model. Its cache keys already cover sighting
  cards, but check `movement_inputs()` if new fields are read.

## 3. Defence moves as claims and challenges

**Implemented Oct 25 (Codex), pending the next passive chunk.** The user clarified
that legacy strength/regard becomes hearing weight, while the shared posterior
sets the suspicion change. Native bonuses are parked. Gift/secret claims and
specific-reading challenges are canonical; pleas/rival suggestions remain speech.
See MIGRATION_PROGRESS for the report-content hard-gate fix and flagged runtime cost.

**State:** daily stacking is fixed (stable semantic identities), but the moves still go
through the legacy route (C2).

**Intent:**
- a gift reveal becomes a walking-gift claim;
- a confessed secret becomes a secret card;
- red herring, misled and lying become challenges to a specific reading;
- pair_other stays a rival suggestion (speech);
- a plea is speech, not evidence.

Each is judged once, not re-added every day. Keep each move's legacy strength and the
trust-in-defender weighting until the Q3/Q6 tuning pass.

**Performance risk: medium. Fix this before challenges become common:**
`ReadingChallenges.assess` runs a full solve per challenge and builds a string key per
world. Switch it to per-world integer keys and `Solver.report_table` lookups first.

## 4. Unnamed relays, and Medium relays without original evidence

**Implemented Oct 25 (Codex).** Identified tellers supply reduced-weight testimony
without an anonymous gift holder or a gift claim by the teller. Missing original
timing/structured content is labelled context rather than inventing evidence or
falling the whole refresh back. Named acknowledgement and verified Medium routes
retain their existing exact identity rules. See MIGRATION_PROGRESS.

**State:** "word reached me from the Seer" without a named source is an explicit
fallback (B3, B8). Bot games also show frequent belief-refresh fallbacks: "Medium relay
needs supported original evidence, an original observation time, and a publicly
deceased…". A Medium relay whose original isn't supported pushes the listener's whole
refresh onto the legacy rules, so this is high-volume; consider moving it up.

**Approach:** treat it as the teller's testimony about a reading, at reduced weight,
with no model of who the anonymous source might be. A later public "that was me"
binds it to the named source (already implemented).

**Performance risk: low,** provided it adds no latent-source fact.

## 5. Warden guard statements

**Implemented Oct 25 (Codex).** Public statements and the Warden's own guard
memory share exact source/door/night receipts. Routes, matching quiet nights and
the public killed door are judged together; impairment/error remains possible.
Other listeners never receive the private guard log. Hearthwitch remains benched.

**State:** the one active gift still unsupported outside a Medium relay (B4).
Hearthwitch is benched; leave it.

**Approach:** a guard statement (who, which door, which night) as a protection receipt
in `live_protection.gd`, combined with quiet nights and the Demon's movement. Each
world either fits it or doesn't.

**Performance risk: low.**

## 6. One model for night sightings

**Implemented Oct 25 (Codex).** Owned night sightings park the legacy scale.
Demon routes marginalize a 5% detour allowance without extra worlds. Off-route
and scattered-walking-gift relationships appear in previews and replies from the
same movement result. Targeted tests and the opening replay pass; see MIGRATION_PROGRESS.

**State:** the legacy `Mind.night_sighting_scale` (×0.12 away from a death, discounted
for claimed walkers) and the shared movement model still coexist (B5).

**Intent:**
- Retire the legacy scaling wherever the shared model owns sightings, and confirm it's
  parked.
- Add a small chance that the Demon detours, so an off-route sighting argues strongly,
  not absolutely, against being the killer.
- Surface two relationships in previews and replies: "seen elsewhere that night, so
  probably not the killer", and scattered sightings that corroborate a walking-gift
  claim. See the BACKLOG items on off-scene night sightings and corroborated walking-gift
  claims.

**Performance risk: low to medium.** A detour adds a few routes per Demon profile.
Keep `_likelihood`'s loop structure (no work inside the per-block loops that doesn't
depend on the block).

## 7. No legacy route for presentations: done (Oct 25, Claude)

- **Unsupported evidence is blocked:** a presentation containing evidence the shared
  model can't read is blocked with the reason ("Cannot present. Card #N: …"), in normal
  play too, not just strict mode. Mid-presentation failures are blocked for that listener.
- **Unsupported conclusion types** with supported evidence go to the legacy rules,
  loudly (item 0).
- **Two more exceptions stay native, by design:**
  - A bare belief with no evidence ("I believe they're not the Demon") is social speech.
    It's logged as `social_presentation`, not as a fallback.
  - With shared effects switched off by the player, the legacy rules are what they asked
    for.
- **Every remaining fallback is visible.** This covers belief refreshes and NPC-driven
  paths. Each one is recorded in the ordinary developer log (`legacy_fallback`),
  listed by the `fallbacks` command, announced in the next morning report ("[dev] The
  legacy rules judged N things…"), and counted in each game's summary
  (`legacy_fallbacks`, also in autoplay's case lines and `--results`). Each distinct
  fallback counts once per listener per day.
- **The bot** never retries a presentation the game blocked (it used to loop forever).
- **Remaining work:** drive the count to zero through the items above. A playtest's
  `fallbacks` output shows what it didn't test.

## 8. Check: no double counting of role claims

**Implemented Oct 25 (Codex).** Stable declaration receipts own double-claim
effects and the separate pressed-counterclaim ledger entry. Legacy claim credence
is parked under shared ownership; native comparison restores it. Tests and the
opening replay pass, with refresh cost flagged in MIGRATION_PROGRESS.

Soft testimony now handles rival claims (an evil claimant may bluff, weight 0.35 per
declaration). Confirm that the legacy claim effects are fully parked wherever the shared
model owns the claim: `own_role` "they claim my gift", double-claim bumps and
`claim_credence`. Otherwise rival claims are counted twice. Add a regression test.

## 9. Day 3–4 versions of case #85 in the replay fixture

**When:** when the user says so (previously on hold).

**What:** extend `tests/fixtures/playtest_54875_opening.json` and the replay to the
four- and six-report versions of #85. This is the late-game measurement for speed (the
readings cliff, movement model growth) and for behaviour.

## Not on this list

These are covered elsewhere:
- **Re-baseline follow-ups, owned with the user:** Insight as degree, attention for
  replies only, replies matching beliefs, the Confidence stickiness rule, Q3 tuning
  (including a rank-aware vote through the execution-priority input).
- **BACKLOG ideas:** reactive meetings, supporting evidence (votes as soft evidence;
  a gated vibes stage), Town Hall, two-part traces, a day-killing Demon.

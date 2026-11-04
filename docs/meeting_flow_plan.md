# Meeting Flow Overhaul: Trials, Podium Press, Supporters, Peer Role Gossip & VN Courtroom

**Status:** Steps 1 (`nomination_case`), 2 (`defend_self`), streamed `testimony_step`, and gallows `last_words` are live on `main` (`35d319b`, post-Legacy-Purge Phase 3 & Tuning Hoist). Opening reactive pacing, player nominations (anchored or raw), Podium Press, `block_safety`, self-paced Supporters, selective post-vote resistance lines, Peer Role Gossip, and the 15-cast VN Courtroom stage are specified below as the complete implementation plan.  
**Updated:** 2026-11-03 (review pass by Claude with Michael's decisions, same day)  
**Repository location:** `docs/meeting_flow_plan.md`

This specification supersedes the Oct 19 pre-Workshop draft and absorbs these `BACKLOG.md` items:
- *Rebuttals and excuses* & *Nominations make a case* (built on shared Workshop attribution; refined below);
- *Outing yourself to defend someone* & *NPCs push back on nominations their own information contradicts*;
- *Reactive meetings: speak up when the last statement concerns you* & *Fading into the crowd*;
- *Meeting and vote talk* & *Vote resistance feedback* (*"when they agree and still vote no, they say why"*);
- *More talk in town* (peer Tier-2 role hints and dated private role claims feeding second-hand discovery and trial vouches);
- *Last words* (built on `main`);
- *VN / Ace Attorney courtroom integration* into `ui/meeting_view.gd` using all 15 cast 5-expression portrait sets.

Each implementation slice at the end of this document is scoped to land as a clean, testable commit.

### Review decisions (Nov 3)

Michael and Claude reviewed the first version of this plan. What changed:

1. **No Director forecasting.** Step 4 no longer picks a "minimal decisive subset" from
   a dry-run vote. Each bystander decides for themselves, in seat order, whether to
   speak, weighing four things (section 3, Step 4): how sure they are the nominee is
   good, what the nominee's role is still worth, what speaking costs them (their own
   exposure and the value of their own unspent gift), and how much danger the nominee
   is actually in. Danger is re-read after every supporter, so "the last person
   already cleared them, I can keep my reading" falls out of the model. The only
   global rule is a cap on how many supporters speak; nothing restricts what they say.
   `sim/director.gd` is not created.
2. **Raw (unanchored) player nominations are allowed from the start**, at reduced
   credibility. Anchoring to a presented deduction stays the stronger option. The UI
   must show each option's cost before the player confirms (section 3, Step 1).
3. **`block_safety` has a concrete formula** built only from public information
   (section 3, Step 2).
4. **Golden checks are split** into C# parity (csharp vs gdscript at the same commit)
   and regression (vs the fixed baseline), so behaviour-changing slices M1, M2 and M4
   don't collide with the C# migration (section 8).
5. Smaller corrections: vote-resistance lines only use vote parts that exist, Stretch A
   is smaller than described (votes already run in seat order), names marked *new*
   where the code doesn't exist yet, pacing measured in M4.

## 1. Current Baseline on `main` (Post-Purge Code Pointers)

Legacy `effects` arrays, `n.sus_why` / `n.sus_src`, and `workshop_effects` switches are gone (`PR #50`). Every meeting reason, defence, and belief update now flows through the shared Workshop model:

- **Shared Evidence & Attribution (`workshop/` & `sim/mind_meeting.gd`)**:
  - `Mind.ledger_hear` stores normalized `workshop_card` / `workshop_receipts` entries in `n.ledger`; `Mind.refresh_beliefs` (deferred via `w.defer_beliefs` and flushed per speaker via `Mind.flush_beliefs`) recomputes `n.suspicion` and `n.execution_priority` through `WorkshopOwnership`.
  - `MindMeeting.case_against(w, n, t_id, limit)` (`sim/mind_meeting.gd:1101`) queries `w.workshop_reasons` (`workshop/reason_attribution.gd`) on `n` (or `n.shadow` for Evil), resolves audience visibility via `_visibility_maps` and `_resolve_shared_reason` (`public | player | private | relay | shared_player | shared_private`), merges private mourning `resentment`, and ranks reasons by `contrib`.
  - `workshop/source_doubt.gd` and `def:<id>:<type>:<sha256>` entries in `MindMeeting.defend_self` (`sim/mind_meeting.gd:1257`) handle undoable excuses (`gift_claim`, `secret_claim`), `rival` (`pair_other`), `challenge` (`misled`, `lying`), and `plea` (`fear`, `desperation`) without permanent suspicion residue if later disproved.
- **Meeting Controller & World State (`game/game.gd` & `sim/world.gd`)**:
  - `game/game.gd` lines `1798-2094`: `_start_meeting`, `meeting_streaming`, `testimony_step`, `_testimony_turn`, `_meeting_opened`, `_meeting_command` (`present`, `nominate`, `wait`, `done`), `_next_npc_nomination`, `_defend_pending`, `vote_requirement_text`, `_show_nomination`, `_nomination_command` (`defend`, `accuse`, `clemency`, `vote`), `_after_vote`, `_last_words`, and `_close_meeting`.
  - `sim/world.gd` lines `742-915`: `open_meeting`, `can_nominate`, `open_nomination`, `clemency`, `vote_pending`, `end_meeting`, and `execute` (handling Martyr substitution prior to `last_words` and Revenant curse triggers).
- **UI & VN Presentation (`ui/meeting_view.gd`, `ui/day_conversation_view.gd`, `ui/main.gd`)**:
  - `ui/meeting_view.gd` (356 LOC): Custom-drawn dusk town-square ring (`_seats`, `_draw_person`, `_draw_center`, `_draw_tally`) with clockwise BotC hand counting (`STEP = 0.5s`, seat after nominee first, nominee last) and numbered crimson yes-vote tokens (`_token`).
  - `ui/day_conversation_view.gd` (238 LOC): Full-height left portrait stage with `0.15s` expression crossfades across all **15 cast 5-expression portrait sets** (`neutral`, `warm`, `harsh`, `concerned`, `sorrowful` in `res://assets/art/cast_expressions/<id>/<expression>-v1.png` plus Constance's PoC paths), `FormattedLabel` 90 cps span reveal, and `HFlowContainer` controls.
  - `ui/main.gd`: Streams `g.testimony_step()` via `_stream_meeting()` (`STREAM_GAP = 0.15s`) and renders meeting/nomination action buttons in `_refresh_actions` (`ui/main.gd:880-909`).
- **Not yet in the code** (created by this plan): `game/game_meeting.gd`, `ui/vn_portraits.gd`, `MindMeeting.block_safety`, `support_candidates`, `vote_resistance_lines`, `RoleDef.score_protect_value`, `g.public_presentations`.
- **C# Solver Isolation**:
  - All work in this plan sits **above** the `workshop/` numerical kernel (`WorldDomain`, `RoleConstraints`, `LiveActivity`, `Solver`, `CaseEval`), calling only existing public entry points (`w.workshop_reasons`, `ledger_hear`, `refresh_beliefs`, `Mind.vote`). Solver math and C# parity (`--tol 0`) remain untouched.

## 2. Opening Phase Overhaul (Before Nominations)

### 2.1 Short "At the Table" Arrival Pause (`ui/meeting_view.gd`)
When `_start_meeting` opens at dusk, `ui/meeting_view.gd` holds an unobstructed beat (`Tuning.Meeting.ARRIVAL_PAUSE_SECONDS = 1.2`, click-skippable) on the full seat ring **before** the first `testimony_step` speaker takes the stage. This lets the player visually scan who is still alive at the table, where empty gaps sit, who is Breathstealer-silenced (`w.meeting["silenced"]` muted badge on their standee plaque), and that the block is clear.

### 2.2 Reactive Testimony Interjections (`MindMeeting.testimony_step`)
Right now `testimony_start(w)` shuffles `w.living()` once and walks linearly (`st["i"]`). After any speaker `s` emits non-empty `lines` / `facts` in `testimony_step`, scan living non-silenced listeners (`l != s`) using **cheap O(living) metadata checks** (zero solver calls):

1. **Direct Gift Collision**: `s` publicly claimed `role` (`fact.kind == "claim"`), and `(w.evil_plan["bluffs"].get(l.id, "") if l.is_evil() else l.role) == role`.
2. **Direct Personal Implication**: `s`'s `facts` implicated `l.id` (`l.id in fact.subject` for `fact.kind in ["accusation", "info", "sighting"]`).
3. **Subject Contradiction / Cover**: `s` accused or implicated `x`, and `l` holds an unshared clearing reading (`x in Gifts.clears(e)`), a firsthand night home-window alibi for `x` on the cited night, or is a Martyr whose chosen target is `x`.

**Queue & Openness Behaviour**:
- Matching listeners who have **not yet spoken** (`idx >= st["i"]`) are pulled to `st["i"]` (ordered by priority `1 > 2 > 3`) and receive a temporary `st["reactive_context"][l.id] = {"trigger": kind, "by": s.id, "subject": subj, "bonus": Tuning.Meeting.REACTIVE_OPENNESS_BONUS}` applied inside `_public_claim_decision` and `_public_accusation` on their immediate next beat.
- A matching listener who **already spoke earlier** in `testimony_step` may take **at most one** reactive interjection per meeting (`not st["interjected"].has(l.id)`) strictly on triggers `1` (counter-claiming a stolen gift) or `2` (answering a direct accusation/sighting just dropped on them).

### 2.3 Fading into the Crowd (`MindMeeting._public_claim_decision` & `_public_accusation`)
Track `st["substantive_turns"]` (incremented whenever a speaker claims a gift, shares a reading, or makes a fresh accusation). When an NPC `n` has **no** active `reactive_context` entry:
- Apply a crowd-fading term `-st["substantive_turns"] * maxf(0.0, trait_of(n, "privacy") - Tuning.Meeting.CROWD_FADE_PRIVACY_FLOOR) * Tuning.Meeting.CROWD_FADE_SLOPE` to `_public_claim_decision` and `_public_accusation` (plus `+st["substantive_turns"] * Tuning.Meeting.CROWD_FADE_SIGHTING_BAR` to `_volunteer_night_sightings`'s threshold).
- Result: Once a wagon or major claim is already rolling in opening testimony, private townsfolk hold their cards back rather than dumping everything up front, allowing unshared readings and alibis to surface organically during Step 4 (Supporters) of nomination trials.

## 3. The 7-Step Nomination Trial Sequence

Every nomination runs one at a time (BotC style) through a structured state machine on `w.meeting["pending"]["step"]`:

`case -> defence -> podium_press -> supporters -> player_turn -> vote` *(plus `last_words` at meeting close)*

Notice two deliberate ordering shifts from the Oct 19 draft:
1. **Step 3 (`podium_press`) sits immediately after Step 2 (`defence`) and before Step 4 (`supporters`)**, so bystanders react to any claim, confession, or lie the player just pried loose from the nominee.
2. **Step 5 (`player_turn`: Speak For / Against / Clemency) moves after Step 4 (`supporters`)**, so the player never wastes their single public statement or once-per-case Clemency right before an NPC supporter drops a game-changing exonerating reveal.

### Step 1: Nominator's Case (`case`)
- **NPC Nominators (`MindMeeting.nomination_case` - Built)**:
  - Ranks up to 3 reasons from `case_against(w, nom, t.id)` (`workshop_state.reasons[t.id]` + `resentment`).
  - Recaps up to 2 `public` reasons cosmetically (emitting sighting cards via `_append_accusation_sighting` only if unspoken, with zero double-counting in listener ledgers).
  - Evaluates the top `private` / `player` reason via `reveal_to_nominate` (calling `_public_disclosure` + sighting cards) or records `nom.hints[t.id]` (`nomination_held_reason`), falling back to `relay_reading` if holding a direct private relay.
- **Player Nominators (anchored or raw)**:
  - `present <deduction#>` remains an **independent once-per-meeting floor action** (`g.presented_today`). The player can present a case (or a `conflict` / `"is suspicious"` premise) without nominating anyone, and cannot farm extra Workshop presentations by nominating.
  - `nominate <name>` offers up to two ways in, and **the UI shows both with their cost before the player confirms**:
    - **Anchored** (preferred): the motion rests on a deduction the player has already presented publicly (this meeting or an earlier one; tracked on *new* `g.public_presentations: Array[int]`, excluding deleted/withdrawn deductions) whose conclusion or implicated targets include `<name>`. One eligible deduction anchors automatically; with 2+, the picker (or a `<deduction#>` CLI arg) chooses. Anchoring recaps the headline (`"You stand and nominate %s on the strength of your case (#%d)."`), adds **zero** new presentation sway (the town already weighed it), and fills `pending["case_facts"]` with the deduction's root evidence cards so Steps 2 and 3 answer the exact cards in the case.
    - **Raw**: no anchor. Allowed from the start (`Tuning.Meeting.ALLOW_UNANCHORED_PLAYER_NOMINATION = true`). Voters weigh the player's credibility at `Tuning.Trust.CRED_WEIGHT_BARE_NOMINATION`, `case_facts` is empty, and the defence answers in general terms. This keeps Day 1 hunches playable before the player has a presentable case.
  - **UI cost display**: the nomination picker lists each eligible anchor with its headline and a plain-language strength note, then the raw option labelled with its cost (e.g. *"Nominate on a hunch: the town will want more than your word"*). If the player hasn't presented today and has a deduction against `<name>` that isn't public yet, the picker says so (*"Present case #4 first to nominate on its strength"*) rather than silently offering only the raw option.

### Step 2: Initial Nominee Defence (`defence`) & Block-Safety Cushion
- **Breathstealer-Silenced Nominees (`d.silenced`)**:
  - `MindMeeting.defend_self` returns `moves = ["silenced"]`, logs `"silenced_defence"`, stages `d` visibly on the VN Courtroom screen unable to speak, and **skips Step 3 (`podium_press`)** straight to Step 4 (`supporters`), putting full defensive weight on bystanders.
- **Shared Block-Safety Helper (*new* `MindMeeting.block_safety(w, d) -> float` in `0.0 .. 1.0`)**: how safe `d` is because someone else is already firmly on the block. Public information only:
  - `blk = w.meeting.get("block", "")`, `high = int(w.meeting.get("block_count", 0))`, `thr = w.vote_threshold()`.
  - If `blk == ""`, `blk == d.id` or `high < thr`: `block_safety = 0.0`.
  - Otherwise `margin = clampf(float(high - thr + 1) / Tuning.Meeting.BLOCK_SAFETY_FULL_MARGIN, 0.0, 1.0)` (to displace `blk`, `d`'s vote must beat `high`, so a bigger block count is safer), times `1.0 - heat(d)` where `heat(d) = clampf(Tuning.Meeting.BLOCK_SAFETY_HEAT_BASE + Tuning.Meeting.BLOCK_SAFETY_HEAT_PER_ACCUSER * accusers_on(d) + Tuning.Meeting.BLOCK_SAFETY_HEAT_CREDIBILITY * nominator_credibility, 0.0, 1.0)`, counting public accusations of `d` made this meeting (nominator's case, pile-ons, player `accuse`) and the nominator's public credibility.
  - Applied in `defend_self` (`defence_reveal`, `defence_confess`) as a `-block_safety * Tuning.Meeting.BLOCK_SAFETY_DEFENCE_RELIEF` part: an NPC guarding a valuable gift or secret holds back on a low-danger nomination when someone else is already overwhelmingly likely to hang today (`w.dlog.think(d.id, "defence", "Holds back reveal: %s is already strongly on the block (%d votes).")`). The same value feeds `danger` for supporters (Step 4).

- **Shared-Model Defence Moves (`MindMeeting.defend_self` - Built)**:
  - Selects 1 to 2 moves (`reveal`, `secret`, `sleepwalk`, `RoleDef.try_reading_defence` / `red_herring`, `pair_other`, `lying`, `misled`, `fear`, `desperation`) and writes deterministic `def:<d.id>:<scope.type>:<sha256>` entries via `ledger_hear`.

### Step 3: Player Podium Press (`podium_press`)
Once per nomination (whenever `not nominee.silenced`), before bystanders jump in, the player gets one optional **Podium Press** against the nominee (`press <mode> [arg]` or `press skip`):

1. **`press role`** (*"Press them on their gift"*):
   - Publicly asks the nominee what gift they hold (disabled if `nominee.claim_public` is already `true`, in which case it shifts to **`press readings`** if they have unshared nights or have claimed an ongoing info role).
   - Evaluates public disclosure using podium stakes: `openness + Tuning.Meeting.PODIUM_PRESS_URGENCY - block_safety * Tuning.Meeting.BLOCK_SAFETY_PRESS_RELIEF` vs. `reveal_cost(w, nominee)` (Evil evaluates through `w.evil_plan["bluffs"][nominee.id]`).
   - Outcomes: full public claim + readings (`_public_disclosure`), public Tier-2 `HINT_PACKAGES` hint (`facts.append({"kind": "role_hint", ...})`), or public refusal (`gift_refusal`, plus slight `pressure` gain `Tuning.Meeting.PODIUM_PRESS_PRESSURE_GAIN` and minor `trust` friction `Tuning.Trust.PRESSED_EVIDENCE_BASE` when `block_safety` was high or player lacked grounds).
2. **`press night [night#]`** (*"Press their Night K account"*):
   - Defaults to the latest night cited in `pending["case_facts"]` (or `w.day - 1` if none; picker offers specific nights `1 .. w.day - 1`).
   - Routes `MindDialogue._answer_pressed_night` / `answer_night` with `audience = "town"`, recording the public answer in `dialogue_memory["night_accounts"][str(nd)]` and emitting public `alibi`, `sighting`, `secret`, `sleepwalk`, or `claim` cards to the board and every living listener's ledger.
3. **`press card <card#>`** (*"Press a specific contradiction"*):
   - Filtered picker showing board cards (`sighting`, `info`, `trace`, `claim`, `alibi`) that implicate `nominee` or clash with `nominee`'s stated account/claim.
   - Publicly runs `MindDialogue.press` / `react_to_trace` adapted for `"town"` (checking `block_safety` before self-outing), capable of prying loose a walking-gift reveal, secret confession, account revision (`lied_nights`), or reading challenge (`misled` / `lying`), and delivering any newly cited player card publicly (`_break_confidences` applies if the player uses a confidential card!).
4. **`press skip`** (*"Hold your peace"*):
   - Advances immediately to Step 4 with zero trust cost or pressure delta.

All facts/cards emitted in Step 3 append to `pending["case_facts"]` so Step 4 Supporters see them immediately.

### Step 4: Supporters & Exonerating Reveals (`supporters`)
First, flush deferred beliefs (`Mind.flush_beliefs(w)`) so every living bystander's `suspicion`, `reasons` and `cleared` state includes Steps 1 to 3.

There is **no Director forecast**. Bystanders are offered the floor one at a time; each decides for themselves from what they know and what has been said so far, and the town stops listening after `Tuning.Meeting.MAX_SUPPORTERS_SHOWN` (3) speakers. The cap limits how much is said, never what is said.

#### 4A. Who may speak (*new* `MindMeeting.support_candidates(w, nominee, nominator) -> Array`)
Living, non-silenced NPCs other than the nominee and nominator, each with the strongest move available to them (Evil evaluates through `shadow_eval` + `evil_override`, e.g. defending a Demon or minion in real danger, or piling onto the scapegoat):

- **`"counter_claim"` (against)**: the nominee publicly claimed role `r` (often just now in Step 2 or 3), and `s`'s true role (or Evil bluff, if `evil_override` approves contesting) is `r` and not yet public. Always offered first; `apply` calls `_public_disclosure(w, s, ...)`.
- **`"exonerate"` (for)**: `s` holds an unshared clearing reading (`nominee in Gifts.clears(e)`), a firsthand night home-window alibi on a night the nominee is accused of walking, Warden guard/save knowledge of the nominee, or is the Martyr with `martyr_target == nominee`. Decided by the weighing in 4B; yields `reveal` (`_public_disclosure` / public alibi card), `hint` (`s.hints[nominee]`) or silence.
- **`"vouch_claim"` (for, Peer Role Gossip payoff)**: `kc = s.known_claims.get(nominee, {})` with `int(kc.get("first_claimed_day", 99)) <= w.day - 1`, `s.npc_trust.get(nominee, 0.5) >= Tuning.Meeting.VOUCH_MIN_TRUST` and `susp(s, nominee) < Tuning.Meeting.VOUCH_MAX_SUSP`. *Provenance*: if the nominee's claim is already public and matches `kc["role"]`, `s` vouches explicitly (*"%s confided to me back on Day %d that they were the %s, and their word has held steady since."*), emitting a `vouch:` receipt (`Tuning.Meeting.VOUCH_CLAIM_RELIEF`); otherwise `s` vouches for early consistency **without** naming the role (*"%s trusted me with their calling early on, and nothing they've done contradicts it."*). Costs `s` nothing to reveal, so it passes the 4B weighing on benefit alone.
- **`"pile_on"` (against)**: `susp(s, nominee) >= Tuning.Meeting.SUPPORT_PILE_ON_MIN_SUSP` and `case_against(w, s, nominee, 2)` yields a `private`, `relay` or unrecapped `public` reason distinct from `pending["case_facts"]`. Runs the existing `_accuse_tier` (`reveal`, `relay` or `hint`).
- **`"vibes"` (for or against)**: a cover reminder citing a public board card that leaves room for the nominee to be good (*"Don't forget what %s shared: %s could still be who the Clerk read."*), or a plain rapport/distrust line when `npc_trust >= Tuning.Meeting.VIBES_TRUST_MIN` or `susp >= Tuning.Meeting.VIBES_SUSP_MIN`. `apply` writes a tiny `Tuning.Meeting.VIBES_SWAY` consensus nudge. Vibes are ordinary candidates, not forced padding.

#### 4B. The weighing (exonerate and other self-exposing defences)
For bystander `s` considering a self-exposing defence of nominee `d`, the decision runs through the usual `decide(w, s, "support_reveal", parts, ...)` sigmoid with four groups of parts:

1. **Belief the nominee is good**: `(1.0 - susp(s, d)) - Tuning.Meeting.SUPPORT_GOOD_PIVOT`, scaled by `SUPPORT_GOOD_SLOPE`; a clearing reading on `d` counts at full strength. Relationship enters here too: `(s.npc_trust.get(d.id, 0.5) - 0.5) * Tuning.Meeting.SUPPORT_TRUST_SLOPE`.
2. **What the nominee's role is still worth**, as `s` believes it: *new* role hook `RoleDef.score_protect_value(w, holder, believed_role, parts)`, the mirror of the existing `score_reveal_cost`. Ongoing information gifts with nights left (Seer, Gravedigger, Warden) score high; one-shot gifts already spent (a Clerk who has read) score low (`Tuning.Meeting.PROTECT_VALUE_SPENT_SCALE`); unknown role gets `PROTECT_VALUE_UNKNOWN`. Multiplied by the believed-good term, so a valuable role `s` doubts isn't worth much.
3. **What speaking costs `s`**: the existing `reveal_cost(w, s)` parts, negated. It already prices `s`'s own gift (gifts that hide from the Demon or keep paying off cost more), fear, privacy, the day and how few are left. Zero once `s`'s claim is public.
4. **Danger**: how likely `d` is to hang if `s` stays quiet. `danger = clampf((1.0 - block_safety(w, d)) * (1.0 - Tuning.Meeting.SUPPORT_DANGER_DEFENCE_DAMPING * defended) + Tuning.Meeting.SUPPORT_DANGER_PER_ACCUSER * accused, 0.0, 1.0)`, where `defended` is the sum of `s.npc_trust` in each "for" supporter who has already spoken this trial and `accused` counts "against" supporters who have. Multiplies groups 1 and 2: no danger, no reason to burn cover.

The examples this has to reproduce (and the M2 tests check):
- An unrevealed **Clerk** who read a **Seer** as good reveals to keep that Seer off the block: high belief, high protect value, moderate own cost.
- A **Seer** who got a "no" on a **Clerk** usually stays quiet even when they like the Clerk: the Clerk is spent (low protect value) and the Seer's own reveal cost is high.
- After a trusted bystander clears the nominee, the next person holding a clearing reading keeps it: `defended` has cut the danger.

If the decision fails but the benefit side clears `Tuning.Meeting.SUPPORT_HINT_FRACTION` of the cost, `s` gives a `hint` instead.

#### 4C. Order and the cap
1. Any `counter_claim` speaks first.
2. Remaining candidates are offered the floor in seat order (clockwise from the nominee, like the vote). Each one decides at its turn with the current `danger`; one who declines is silent and keeps everything unshared.
3. After each speaker, flush beliefs for the listeners (`Mind.flush_beliefs(w)`) so the next decision sees the updated `defended` / `accused` and suspicions. With the C# solver this is affordable; M2 measures it.
4. Stop after `MAX_SUPPORTERS_SHOWN` speakers or when the queue is exhausted. Log each offer and decision with `w.dlog.decision(s.id, "support_reveal", ...)` like other decisions.

### Step 5: Player Speak For / Against (`player_turn`)
- Reuses existing `_nomination_command` options (`accuse [card#]`, `defend [card#]`, `clemency` if `nm["by"] != "player"` and `w.tools["clemency"] > 0`), or proceeding straight into `vote yes` / `vote no` (`ui/main.gd` displays `Vote to execute`, `Vote to spare`, `Speak against...`, `Speak in defence...`, and `Invoke Clemency` together once Step 4 finishes so zero extra click is needed when the player has nothing to add!).

### Step 6: Recalculate Odds, Clockwise Vote Sweep & Selective Resistance Lines (`vote`)
1. **Flush Belief Updates**: Call `Mind.flush_beliefs(w)` before `w.vote_pending(player_yes)` so every reveal, press admission, supporter exoneration, and player card from Steps 1 to 5 is reflected in final `suspicion` and `execution_priority`.
2. **Capture Per-Voter Breakdown**: Have `w.vote_pending` store lightweight `res["voter_parts"][v.id]` snapshots (from `_vote_impl`, using `shadow_eval` parts for Evil voters so Evil reason metadata is structurally identical to Good).
3. **Clockwise Seat-Ring Sweep**: `ui/meeting_view.gd` pulls back to the full seat ring and sweeps clockwise (`STEP = 0.5s`).
4. **Selective Post-Vote Resistance Lines (`MindMeeting.vote_resistance_lines(w, res) -> Array`, Max 1-2 Speakers)**:
   - Immediately after the tally outcome prints, select **at most `Tuning.Meeting.MAX_VOTE_RESISTANCE_SPEAKERS` (`2`)** voters whose vote warrants a 1-sentence explanation:
     - **Priority 1 - Accepted Case Yet Voted `No`**: Voter `v` voted `no` (`v.id in res["no"]`, `v.id != nominee`), yet accepted (`verdict == "accept"`) an active non-withdrawn player Workshop presentation implicating `nominee` (`v_mind.workshop_state.presentations`). Inspect `res["voter_parts"][v.id]` (the parts `_vote_impl` already builds) to voice the real reason:
       - `prefers_block < 0`: `vote_no_prefers_block` (*"I take your point about {nominee}, truly, but {block} is already on the block and I'd sooner hang {block} tonight."*)
       - `persuaded_to_spare < 0`, or a negative part added by the voter's role hook `score_vote_reluctance` (e.g. the Martyr's): `vote_no_reluctant` (*"Even with what you laid out, I'm not ready to put a rope on {nominee} tonight."*)
       - `distrusts_nominator < 0`: `vote_no_distrust_nominator` (*"The case against {nominee} troubles me, yes, though I don't trust {nominator}'s hand in pushing it."*)
       - otherwise, when the margin was close (`margin > -Tuning.Meeting.VOTE_RESISTANCE_CLOSE_MARGIN`): `vote_no_short_of_rope` (*"Your case against {nominee} has merit, Demonologist, just not enough to hang them today."*). (There is no `early_day` vote part; an early-day reluctance would need adding to `_vote_impl` first.)
     - **Priority 2 - Pivotal Swing / Tie Voter**: If fewer than 2 Priority-1 speakers exist and `absi(res["count"] - maxi(res["threshold"], prev_block_count)) <= 1`, pick 1 swing voter (`yes` on a narrow `on_block`/`tie`, or high-trust `no` on a 1-vote miss) to voice their decisive reason (`citable_reason` for `yes`, or top blocker part for `no`).
   - **Strict Shadow Symmetry**: Evil voters **always** pick their spoken resistance reason from their `shadow` voter parts (or standard `prefers_block` / `short_of_rope` lines when overriding `no` on a teammate), never exposing `evil_override`.

### Step 7: Meeting Close & Gallows Last Words (`_close_meeting` - Built)
- Unchanged mechanically (`w.end_meeting(_last_words)` handles Martyr substitution first, then `MindMeeting.last_words(w, condemned)`). Visually staged on the VN Courtroom overlay before the execution headline and Night transition.

## 4. Companion System: Peer Role-Hint & Role-Claim Gossip (`sim/social.gd`)

Today `Social._pick_item` (`sim/social.gd:73`) shares `info_log` readings, night/day sightings, secrets, `player_cases`, and `>= 0.5` opinions, **but never bare role claims or Tier-2 `HINT_PACKAGES` hints** when `info_log` is empty (leaving Wardens, Veterans, Martyrs, Sextons, Sleepwalkers, and Day 1 Evil bluffers silent about their calling in peer chats).

### 4.1 Higher Good Gossip Baseline (`sim/social.gd` & `sim/tuning.gd`)
- Lower `Tuning.Social.IDLE_CHAT_WEIGHT` (`0.30 -> 0.18`) so paired townsfolk talk about substantive leads rather than weather more often.
- Extend `Social.has_news(w, n)` (`sim/social.gd:29`) so Good NPCs who have not yet shared a `"role_hint"` or `"role_claim"` with any high-trust friend (`npc_trust >= Tuning.Social.GOOD_NEWS_TRUST_MIN`) also register `has_news = true` on Days 1 to 2, increasing organic friend-pair daytime chats via `news_bonus`.
- Anti-echo rule: `_told(s, l, key)` and `h["from"] == l.id` checks extend to `"role_hint"` and `"role_claim"` so listeners never echo a speaker's hint/claim back to them.

### 4.2 Two New Peer Share Kinds in `Social._pick_item` & `_deliver`
Let `my_role = w.evil_plan["bluffs"].get(s.id, "") if s.is_evil() else s.role`:

1. **`"role_hint"` (Moderate Bond `>= 0.55`)**:
   - *Gate*: `not s.claim_public`, `my_role != ""`, `bond >= Tuning.Social.SHARE_ROLE_HINT_BOND_MIN`, `not _told(s, l, "role_hint:" + s.id)`, and `not l.known_claims.has(s.id)`.
   - *Weight*: `(1.0 - priv) * Tuning.Social.SHARE_ROLE_HINT_OPENNESS_SCALE * (bond - Tuning.Social.SHARE_ROLE_HINT_BOND_MIN + 0.15) + gos * 0.2`.
   - *Delivery (`_deliver`)*: Records `hs` on `l.hearsay` (`{"kind": "role_hint", "from": s.id, "about": s.id, "package": C.role_hint_package(my_role), "day_heard": w.day, "lie": s.is_evil()}`) and applies normal `gossip_bond`. (Evil listener records `Evil.intel_from_share` narrowing `s`'s candidate roles!)
2. **`"role_claim"` (High Bond `>= 0.68` or High Pressure, Works with Empty `info_log`)**:
   - *Gate*: `not s.claim_public`, `not s.protect_lock`, `my_role != ""`, `(bond >= Tuning.Social.SHARE_ROLE_CLAIM_BOND_MIN or (bond >= 0.55 and s.pressure >= Tuning.Social.SHARE_ROLE_CLAIM_PRESSURE_MIN))`, and `not _told(s, l, "role_claim:" + s.id)`.
   - *Weight*: `(1.0 - priv) * Tuning.Social.SHARE_ROLE_CLAIM_SLOPE * maxf(0.05, bond - 0.55) + Tuning.Social.SHARE_READING_PRESSURE_SCALE * s.pressure`.
   - *Delivery (`_deliver`)*:
     - Updates `l.known_claims[s.id]` (preserving existing `"readings"` if present, and stamping `"first_claimed_day": mini(int(existing.get("first_claimed_day", w.day)), w.day)`, `"role": my_role`, `"via": s.id`). *Also stamp `"first_claimed_day": w.day` in the existing `"reading"` branch at `sim/social.gd:251`!*
     - Calls `Mind.hear_claim(w, l, s.id, my_role, wgt, "relayed")` so the listener's shared Workshop ledger immediately evaluates role compatibility and collisions (`claim:<s.id>:<my_role>`).
     - Appends `hs` to `l.hearsay` (`kind: "role_claim"`).
     - **Evil Symmetry**: Evil speakers run the **exact same `"role_hint"` and `"role_claim"` candidate formulas** using `w.evil_plan["bluffs"][s.id]`. That allows clever Evil players/NPCs who seed a Day 1 bluff with a trusting Good friend to earn a genuine `"vouch_claim"` supporter in a Day 3 trial (until their bluff is contradicted!), preventing `"vouch_claim"` from ever acting as a mechanical alignment detector.

### 4.3 Daytime Player Discovery Hooks (`gossip`, `ask about <person>`, `ask about <role>`)
- **`Social._gossip_items` & `gossip_item` (`sim/social.gd:473`)**: Include unshared `h["kind"] in ["role_claim", "role_hint"]` (when `not w.by_id[h["from"]].claim_public`) so high-gossip approaches and tavern gossip can pass along *"Between us, Fenwick hinted his gift is one of the protective ones"* or *"Constance told me privately on Day 1 she's the Warden"*, minting the corresponding `role_hint` or `claim` (`via: n.id, private: true`) board card.
- **`Social.answer_about_role` (`sim/social.gd:570`)**: Already iterates `n.known_claims`! With `"role_claim"` populating `known_claims` for non-reading gifts, asking *"Have you heard of a Warden?"* now surfaces second-hand private Warden/Veteran/Martyr/Sexton claims automatically (replace the `[PH]` wrapper at `sim/social.gd:595` with voiced `role_query_heard_private`).
- **`MindDialogue.answer_opinion` (`ask about <person>`)**: When willing (`gossip` + `trust`), append second-hand `role_hint` / `known_claims` note if `n` holds one on the target and hasn't told the player yet.

## 5. VN Courtroom & Seat-Ring Choreography (`ui/meeting_view.gd` & `ui/main.gd`)

### 5.1 Shared 15-Cast Portrait & Expression Helper (`ui/vn_portraits.gd`)
Extract the portrait & 5-expression resolver from `ui/day_conversation_view.gd:9-33, 160-170` into a tiny shared helper `ui/vn_portraits.gd` (`VNPortraits.texture(person_id: String, expression: String) -> Texture2D`). Since **all 15 cast 5-expression portrait sets** (`neutral`, `warm`, `harsh`, `concerned`, `sorrowful`) are already in the repository locally and in Git, both `day_conversation_view.gd` and `meeting_view.gd` resolve every townsperson's expression natively through one path.

### 5.2 Layered Hybrid Stage Inside `ui/meeting_view.gd`
Keep `ui/meeting_view.gd`'s custom `_draw()` seat ring, standees, center medallion, and clockwise vote hand intact as the **base canvas**, and mount a child `courtroom_stage: Control` overlay inside `meeting_view.gd` mirroring `day_conversation_view.gd`'s layout:
- **Dimmed Blur Backdrop**: Same 7x7 screen-texture blur shader (`day_conversation_view.gd:59`), tuned slightly lighter (`* 0.68` with warm dusk tint) so the silhouette of the town circle remains perceptible behind the active speaker.
- **Speaker Portrait + Crossfade (`anchor_left = 0.01 .. 0.46`)**: Full-height `TextureRect` + `previous_portrait` `0.15s` tween crossfade. When a silenced nominee is brought forward in Step 2, display their `concerned` / `sorrowful` portrait with a subtle muted-voice sigil banner.
- **Courtroom Status Pill (Top-Right)**: Compact framed plaque showing the active trial phase (`Opening Testimony`, `Nomination: Accuser's Case`, `Nominee's Defence`, `Podium Press`, `Town Speaks`, `Your Floor`), who is currently on the block (`block_count`), and `g.vote_requirement_text()`.
- **Parchment Speech Box (`anchor_left = 0.46 .. 0.98`, `anchor_top = 0.14 .. 0.68`)**: `Speaker` name header + `FormattedLabel` (`90.0` cps reveal, click to finish reveal, second click or `Continue` button to advance multi-speaker beats).
- **Inline Trial Controls (`anchor_left = 0.46 .. 0.98`, `anchor_top = 0.70 .. 0.98`)**: `HFlowContainer` hosting contextual buttons during `podium_press` and `player_turn` (just like `conversation_view.controls` in daytime talk).

| Meeting Beat | Active Visual Layer | Player Controls |
| :--- | :--- | :--- |
| **1. Dusk Arrival (`1.2s`)** | **Full Seat Ring** unobstructed: living standees, dead gaps, silenced badges. | Click anywhere (or auto-advance after `1.2s`) to begin testimony. |
| **2. Streamed Testimony & Interjections** | **VN Courtroom Stage** over dimmed seat ring; portrait swaps per speaker (sharp crossfade on reactive interjections). | Click dialogue to show all / `Continue` when beat exceeds `MAX_AUTO_LINES`. |
| **3. Open Floor Hub** | **Full Seat Ring** unobstructed (`"The town meets"` / `"X is on the block"`). | `Present a deduction...` (1/day), `Nominate...` (anchored case picker), `Let the town speak (wait)`, `Close the meeting`, `Look at the map`. |
| **4. Trial Steps 1 -> 2 -> 3 -> 4** | **VN Courtroom Stage**: Accuser (`harsh`/`neutral`) -> Nominee Defence -> **Podium Press** -> up to 3 **Supporters** (`warm`/`concerned`/`harsh`). | At **Step 3 (`podium_press`)**: `Press their gift`, `Press Night K account...`, `Press with a card...`, `Hold your peace (skip)`. |
| **5. Trial Step 5 (`player_turn`)** | **Full Seat Ring** (or Nominee framed) with clear block/threshold banner. | `Vote to execute`, `Vote to spare`, `Speak against...`, `Speak in defence...`, `Invoke Clemency` (if available). |
| **6. Vote Sweep & Resistance Lines** | **Full Seat Ring** for clockwise gold hand sweep (`0.5s`/seat) + numbered crimson tokens; brief **VN Callout** if 1-2 voters explain resistance. | Click ring to finish count instantly; `Continue` past resistance callout. |
| **7. Gallows Last Words** | **VN Courtroom Stage** on condemned townsperson (or substituting Martyr) for `last_words`. | `Continue` -> Execution headline & Night transition. |

## 6. New `sim/tuning.gd` Constants (`Tuning.Meeting` & `Tuning.Social`)

All new numeric thresholds live directly in `sim/tuning.gd` (zero inline magic numbers in `sim/`):

| Constant | Class | Initial Value | Purpose |
| :--- | :--- | :--- | :--- |
| `ARRIVAL_PAUSE_SECONDS` | `Meeting` | `1.2` | Unobstructed dusk seat-ring pause before first speaker. |
| `REACTIVE_OPENNESS_BONUS` | `Meeting` | `0.35` | Situational claim/accuse boost when named or gift-claimed in testimony. |
| `CROWD_FADE_PRIVACY_FLOOR` | `Meeting` | `0.45` | Privacy trait above which unprompted speakers fade once momentum builds. |
| `CROWD_FADE_SLOPE` | `Meeting` | `0.18` | Per-substantive-turn penalty on unprompted opening claims/accusations. |
| `CROWD_FADE_SIGHTING_BAR` | `Meeting` | `0.10` | Per-substantive-turn rise in unprompted night-sighting volunteer bar. |
| `ALLOW_UNANCHORED_PLAYER_NOMINATION` | `Meeting` | `true` | Allow raw nominations (at `CRED_WEIGHT_BARE_NOMINATION`) alongside anchored ones. |
| `BLOCK_SAFETY_DEFENCE_RELIEF` | `Meeting` | `0.75` | Max reduction in `DEFENCE_ROPE` urgency when another person is firmly on the block. |
| `BLOCK_SAFETY_FULL_MARGIN` | `Meeting` | `3.0` | Votes above threshold at which the block counts as fully held. |
| `BLOCK_SAFETY_HEAT_BASE` | `Meeting` | `0.15` | Baseline heat on any nominee. |
| `BLOCK_SAFETY_HEAT_PER_ACCUSER` | `Meeting` | `0.15` | Heat per public accusation of the nominee this meeting. |
| `BLOCK_SAFETY_HEAT_CREDIBILITY` | `Meeting` | `0.30` | Heat from the nominator's public credibility. |
| `BLOCK_SAFETY_PRESS_RELIEF` | `Meeting` | `0.65` | Reduction in Step 3 Podium Press disclosure urgency under high `block_safety`. |
| `PODIUM_PRESS_URGENCY` | `Meeting` | `0.45` | Base public spotlight push toward answering a Step 3 Podium Press. |
| `PODIUM_PRESS_PRESSURE_GAIN` | `Meeting` | `0.20` | Scrutiny added when a nominee stonewalls a Podium Press. |
| `SUPPORT_TRUST_SLOPE` | `Meeting` | `0.60` | Bystander `npc_trust` weight when deciding whether to out themselves to exonerate. |
| `SUPPORT_GOOD_PIVOT` / `SUPPORT_GOOD_SLOPE` | `Meeting` | `0.5` / `2.0` | Belief-good term in the supporter weighing. |
| `PROTECT_VALUE_SPENT_SCALE` | `Meeting` | `0.3` | Protect value of a one-shot gift already used. |
| `PROTECT_VALUE_UNKNOWN` | `Meeting` | `0.5` | Protect value when the supporter doesn't know the nominee's role. |
| `SUPPORT_DANGER_DEFENCE_DAMPING` | `Meeting` | `0.6` | How much each trusted defence already spoken cuts the nominee's danger. |
| `SUPPORT_DANGER_PER_ACCUSER` | `Meeting` | `0.15` | Danger added per "against" supporter already spoken. |
| `SUPPORT_HINT_FRACTION` | `Meeting` | `0.6` | Benefit/cost ratio above which a declined reveal becomes a hint. |
| `VIBES_TRUST_MIN` / `VIBES_SUSP_MIN` | `Meeting` | `0.68` / `0.55` | Rapport/distrust needed for a vibes line. |
| `VOTE_RESISTANCE_CLOSE_MARGIN` | `Meeting` | `0.14` | Vote margin counted as "close" for the short-of-rope line. |
| `SUPPORT_PILE_ON_MIN_SUSP` | `Meeting` | `0.58` | Minimum suspicion for a bystander to be offered a "pile_on" against the nominee. |
| `VOUCH_MIN_TRUST` | `Meeting` | `0.62` | Minimum `npc_trust` in nominee to offer an early-claim consistency vouch. |
| `VOUCH_MAX_SUSP` | `Meeting` | `0.38` | Maximum suspicion of nominee to vouch for their early private claim. |
| `VOUCH_CLAIM_RELIEF` | `Meeting` | `0.08` | Listener ledger weight on an early-claim consistency vouch. |
| `VIBES_SWAY` | `Meeting` | `0.02` | Near-zero consensus weight on vibes / cover-reminder supporter lines. |
| `MAX_SUPPORTERS_SHOWN` | `Meeting` | `3` | Cap on supporters who speak per nomination trial. |
| `MAX_VOTE_RESISTANCE_SPEAKERS` | `Meeting` | `2` | Max post-vote explanation speakers after a vote resolves. |
| `IDLE_CHAT_WEIGHT` | `Social` | `0.18` *(was `0.30`)* | Lower weather-chat weight so daytime peer conversations pass more leads. |
| `SHARE_ROLE_HINT_BOND_MIN` | `Social` | `0.55` | Minimum `npc_trust` for peer Tier-2 `HINT_PACKAGES` sharing. |
| `SHARE_ROLE_HINT_OPENNESS_SCALE` | `Social` | `0.90` | Openness multiplier on peer `"role_hint"` sharing. |
| `SHARE_ROLE_CLAIM_BOND_MIN` | `Social` | `0.68` | Minimum `npc_trust` for unpressured peer `"role_claim"` sharing (even with empty `info_log`). |
| `SHARE_ROLE_CLAIM_PRESSURE_MIN` | `Social` | `0.55` | Pressure threshold unlocking peer `"role_claim"` sharing at moderate bond (`>= 0.55`). |
| `SHARE_ROLE_CLAIM_SLOPE` | `Social` | `1.80` | Bond slope on peer `"role_claim"` candidate weight. |

## 7. Stretch Goals (Hooks Preserved, Built Later)

- **Stretch A - Live Per-Seat Player Vote**: `w.vote_pending` already counts in seat order (`vote_order`) and passes `yes.size()` to each voter as `yes_so_far`, so late-seat voters (Evil included) already react to the hands before them. What's left is prompting the player's vote when the hand reaches their seat instead of declaring it up front, which means splitting `vote_pending` around the player's seat and pausing the UI sweep there.
- **Stretch B - Rare NPC Mini-Cases (Max 1-2 Per Case)**: Once the C# solver finishes, allow (at most 1-2 times per case) a high-Insight, high-Confidence NPC with a multi-card joint contradiction (`contrib >= 0.20` in `workshop_state.reasons[target]`) take the floor before nominating to present a 2-card mini-case.

## 8. Implementation Slices & Verification Checks

Slices **M0** and **M3a** must not change behaviour: their golden captures are identical to the current baseline at `--tol 0`. Slices **M1**, **M2** and **M4** change behaviour on purpose. Each of those re-records the baseline from its own commit when it lands (after the passive A/B), and C# parity is checked separately by diffing the `--mode csharp` capture against the `--mode gdscript` capture of the same commit (CI job `parity`; see `docs/golden_baseline.md`). So these slices can land while the C# migration continues, and none of them touches the solver kernel, so none needs C# changes.

1. **Slice M0 - Meeting Controller Extraction (`game/game_meeting.gd`, Sim-Neutral)**:
   - Extract `game/game.gd` lines `1798-2094` into static helper `game/game_meeting.gd` (+ `.uid`) with 1-line forwarders on `Game`, matching `GameBoard` and `GamePresentation`.
   - **Check**: `dotnet build -c Debug`, fast CI suites, and 5-seed golden diff vs. `baseline_82faa5b` at `--tol 0` (`0` diffs).
2. **Slice M3a - Shared VN Portraits & Courtroom Stage on Existing Beats (`ui/vn_portraits.gd`, `ui/meeting_view.gd`, Sim-Neutral)**:
   - Extract `ui/vn_portraits.gd`, add the `1.2s` dusk seat-ring arrival beat, mount the VN Courtroom overlay inside `ui/meeting_view.gd` for streamed testimony, nominator cases, initial defences, and gallows `last_words`, and pull back cleanly to the seat ring for vote sweeps.
   - **Check**: `test_ui`, `test_town_ui`, `test_headline`, and `--tol 0` golden parity (`0` diffs).
3. **(Done Nov 4, Claude: `test_peer_role_gossip`; the `answer_opinion` second-hand note is still to do.)** **Slice M1 - Peer Role-Hint & Role-Claim Gossip (`sim/social.gd`, `sim/mind_dialogue.gd`, `sim/tuning.gd`)**:
   - Add `"role_hint"` and dated `"role_claim"` (`first_claimed_day` on `known_claims`), lower `IDLE_CHAT_WEIGHT`, and wire second-hand player discovery in `gossip_item`, `answer_about_role`, and `answer_opinion` plus voiced lines in `sim/dialogue_voices.gd`.
   - **Check**: New `tools/test_peer_role_gossip.gd` verifying empty-`info_log` Warden/Martyr/Evil-bluff peer claims, `first_claimed_day` timestamps, no A->B->A echo, and second-hand `ask about` cards.
4. **Slice M2 - Trial Engine, Podium Press, Supporters & Resistance Lines (`sim/mind_meeting.gd`, `sim/role_def.gd` + role scripts, `game/game_meeting.gd`, `ui/meeting_view.gd`, `ui/main.gd`)**:
   - Implement opening reactive interjections & crowd-fading, player nominations (anchored and raw, with the cost display), `block_safety`, Step 3 `podium_press` (`role`, `night`, `card`, `skip`), Step 4 `support_candidates` + the four-part weighing + `score_protect_value` role hooks + sequential offers under the cap, repositioned Step 5 `player_turn`, and Step 6 resistance lines, plus the Podium Press and nomination UI pickers.
   - **Check**: New `tools/test_meeting_overhaul.gd` covering:
     - Anchored nomination adds zero new sway and feeds `case_facts` into `defend_self`; raw nomination uses `CRED_WEIGHT_BARE_NOMINATION` and is offered on Day 1 with no presented case;
     - High `block_safety` suppresses premature Seer/secret self-exposure in Steps 2, 3 and 4;
     - The three Step 4 examples: unrevealed Clerk reveals for a Seer; Seer stays quiet on a spent Clerk; second clearing holder stays quiet after a trusted first exoneration;
     - Never more than `MAX_SUPPORTERS_SHOWN` supporters; decliners keep their readings unshared;
     - Case-accepting `no` voter voices the exact blocker (`prefers_block`, `distrusts_nominator`, `reluctant`, `short_of_rope`), and Evil voters use identical shadow phrasing;
     - Breathstealer-silenced nominee skips Steps 2 and 3 cleanly while Step 4 supporters still defend them.

   - **Refresh cost cleanup (done Nov 4, Claude: plan reuse when inputs unchanged + shallow per-person case copy; folding the before/after phases into one call is still open):** M2 adds supporter flushes, so do this first, while `workshop_ownership.gd` and `shared_ledger.gd` are open anyway. Since purge phase 3 deleted the native loop, `Mind._refresh_beliefs` calls `workshop_refresh(n, "before")` and `(n, "after")` back to back (`sim/mind.gd` ~891-894). Each refresh therefore runs `Shared.prepare` twice and `SourceDoubt.derive` twice before the `_workshop_evaluations` cache is even checked. That accounts for 268 of seed 42's 280 `outer_prep` calls (67 refreshes). The second `prepare` is not pure waste: it re-prepares with the source doubt derived from the first plan. It is redundant when that doubt (and the candidate suspicion) is unchanged, which is the common case.
     - Fold the two phases into one `WorkshopOwnership.refresh(g, n)` and drop the phase argument from `w.workshop_refresh`. The golden capture hooks `phase == "after"`; update it to the single call.
     - Re-run `Shared.prepare` only when `pre_bundle.pre_eval` differs from the doubt the first plan was prepared with; otherwise reuse the plan and the bundle (`derive` once).
     - In `Jury._consequences_eval`, stop deep-copying `attention.case` per person just to swap `conclusion.target` (7-10 `duplicate(true)` per refresh): copy the conclusion only, or pass the target separately to `Reasoner.direct_checks`.
     - Expected saving about 0.4-0.5 s of seed 42's 1.0 s `outer_prep` (Argon's estimate; measure with `profile_c0`). Behaviour-neutral: golden identical in both modes before the M2 behaviour work starts.
5. **Slice M4 - Bot Cutover, 150-Seed Balance Sweep & New Golden Baseline (`tools/autoplay.gd`, `DESIGN.md`, `BACKLOG.md`)**:
   - Update `tools/autoplay.gd` to present a case before nominating (anchoring its nomination), drive `podium_press` (`press role` / `press night` / `press card` when holding contradictions, `press skip` otherwise), and act at repositioned `player_turn`.
   - **Check**: 150-seed sweeps at 7 and 10 NPCs measuring Good win rate, hidden night-walker hang rate (expected significant drop), cards/lines per meeting, supporters per trial, and **pacing**: player clicks and seconds per meeting (simulated at UI timings) and solver refreshes per nomination. Re-record the `tools/golden/` baseline from the M4 commit; update `DESIGN.md` and close absorbed `BACKLOG.md` items.

## 9. Gotchas & Invariants

- **Zero Double-Counting on Recaps & Anchored Nominations**: Recapping public reasons or anchoring a player nomination to an already-presented deduction must never re-apply suspicion or credibility weights; `WorkshopLedger` receipt deduplication and `presentations` snapshots already enforce idempotence, and `test_meeting_overhaul.gd` must assert `0.0` suspicion drift on pure recaps.
- **Undoable Ledger-Backed Defences & Vouches**: Every defence, press excuse, and `"vouch_claim"` enters listener ledgers via deterministic `def:` / `vouch:` / `claim:` receipts re-derived by `refresh_beliefs`, never raw `n.suspicion[x] -= ...` edits. If a vouched role claim later collides with a proven truth, the solver discounts it cleanly.
- **Strict Provenance & Role-Name Privacy**: Every spoken reason passes `_visibility_maps` / `citable_reason` or an explicit speaker `_public_disclosure`. Early-claim vouchers in Step 4 name the specific role **only** if `nominee.claim_public` is already `true`; otherwise they vouch for early consistency in the abstract.
- **Supporter Decisions Use Only What the Speaker Knows**: each bystander's Step 4 choice reads their own beliefs and the public record (block, who has spoken, public credibility). No dry-run of other NPCs' votes, no draws from `w.rng` beyond the speaker's own `decide`, so turning a supporter off changes nothing but that speaker's lines.
- **Evil Voucher Symmetry & Vibes Variety**: Evil seeds early bluff claims in `sim/social.gd` so `"vouch_claim"` is a strong social clue rather than an alignment guarantee. Vibes lines need enough variety (and occasional real content, like cover reminders) that players don't learn to skip them; if they do, the speaker count leaks who stayed quiet.
- **Cards Name Subjects Two Ways**: `fact.subject` is sometimes a string and sometimes an array (`subjects`). Reactive-interjection trigger 2 and the Step 4 alibi checks must handle both.
- **Breathstealer Silence Visibility**: A silenced nominee skipping Steps 2 and 3 is a high-drama moment; stage their silent portrait beat explicitly so the player never mistakes a skipped Podium Press for a UI bug.
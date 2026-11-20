# 2026-11-19, Claude-Lantern: the player's judgement in word-against-word lie calls (`claude/judgement-boost`; zero drift)

- **Base:** main `77bad4d`. **Status:** PR open. **Next:** Bailiff. Then Herald drafts the
  badge's draw line ("a stand-off: some may take your word"), and Quill wires it. After #346,
  I add the three word-against-word cases and their twins to the slate (Seneschal, Nov 19).
- **Why:** Michael, Nov 19 (via Seneschal). This replaces lie-call badge options (a) and (b).
  When the player calls B's reading a lie on T's word, the listener's trust in the player's
  judgement adds a little weight to the player's side. A wrong call leading the town astray is
  part of the design: "the town shouldn't be dumb, so keep it small".
- **What changed:**
  - **`ReadingChallenges.judgement_boost(listener)`:** in a clash, the grounds' side counts as
    × (1 + `PLAYER_JUDGEMENT_WEIGHT` × (credibility + `PLAYER_EXPERTISE`)), at most
    `WITNESS_QUALITY_MAX` (0.95), and never lowered.
    - **Two new constants**, both approved: `Tuning.Workshop.PLAYER_JUDGEMENT_WEIGHT` = 0.5 and
      `PLAYER_EXPERTISE` = 0.1.
    - **Size:** ×1.3 from an average listener, ×1.4 at credibility 0.7.
    - **How hard an accepted call presses is unchanged:** that's still the case weight, set by
      credibility.
  - **Not boosted:**
    - An NPC's own grounded defence. `SharedLedger` marks it `npc_defence`, and that is the
      only place NPCs file grounded challenges.
    - A call whose grounds include the player's own word, which already counts at the player's
      credibility.
  - **The cache key:** `assess` now keys `player_credibility`, which it was missing (found during
    the proposal), and the measuring switch `ReadingChallenges.player_judgement`.
  - **`test_juror_listener`'s "agreeing grounds" check:**
    - **The case:** the two Seers' agreeing readings still clash, because both claim the one
      Seer gift.
    - **Why it changed:** before, the call came out "unestablished" only because equal trust
      gave a share of exactly 0. Now it leans a little, a draw.
    - **The check now:** it presses no one either way.
- **New `tools/test_judgement_boost.gd`** (8 checks, fast list; lie calls only, after Codex):
  - the factor, and the switch;
  - a misleading Gravedigger call leans toward the player (agreement 0.163 against 0.125), and
    more with credibility;
  - it stays under the bar for that listener;
  - an NPC's defence gets no boost.
- **Measured:** three word-against-word cases (6 deals each). The listeners are each real good
  NPC's own trust map at credibility 0.7, plus the average listener (the badge). Shown is the
  share of NPCs who press the teller, today and with the boost:
  - **Misleading call on the real Seer**, against a Minion's unlikely-looking "yes": 0% to 19%.
  - **Misleading call on the real Gravedigger**, against a Minion's false role: 0% to 13%. In a
    deal the honest Gravedigger's suspicion rises by up to 7 points.
  - **True call against a Minion's plausible-looking "no"** (the town is fooled here today): 0%
    to 22%.
  - **Calls already pressed by everyone** are unchanged. **The badge** is unchanged in all three.
  - **Golden:** identical to `baseline_ee15238` at `--tol 0`; two captures were identical. No
    golden seed has the player file a grounded word-against-word call.
  - **Suites:** `test_judgement_boost`, `test_juror_listener`, `test_defence_grounds`,
    `test_connections_cases`, `test_medium_relay_challenge`, `test_honest_mistake`,
    `test_player_failed_gift`, `test_juror_claims`, `test_mechanics_conclusions` and
    `test_connections_cache` pass.
- **Small calls made on Michael's behalf:**
  - no boost for NPC defences, nor when the player's own word is a ground;
  - the boost never lowers a ground;
  - the cache-key fix rides along.
- **Proposed for the backlog:** none.

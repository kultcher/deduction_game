# Remove drops altogether

**Claude-Quill, Nov 20.** Base: main at 197640a7 (with #382, #383 and #327). Status: ready for
review. **Golden moves**, so it re-baselines (see the end). Next actor: Bailiff, in the golden queue
behind Beadle's two PRs. Beadle reviewed the `sim/world.gd` side. Merge order with Lantern: this PR
goes first. Lantern's Workshop scaffolding PR (the movement fixture and ledger_audit) follows it,
because it touches `movement_model.gd` after this one.

## What changed and why

Michael chose to remove drops altogether (Nov 19, BACKLOG "Remove drops altogether", option (a)),
with no measurement first. A night walker no longer drops anything on their route.

- **The personal item is gone.** It was 12% of drops, and the only part the player could still find.
- **The home-block material drops are gone too.** They had been off since before Nov 17
  (`LEGACY_MUD_DROPS_ENABLED = false`, a dead branch).

**Removed:**
- **The drops themselves:**
  - the sim: `World._maybe_drop` and `World.dropped`, and the call from `_walk`;
  - the constants: `DROP_CHANCE_DEMON`, `DROP_CHANCE_WALKER`, `DROP_OWNED_CHANCE` and
    `LEGACY_MUD_DROPS_ENABLED`.
- **The search branch for drops.** `search` stays at the town's locations and still finds the
  Revenant's totem and a place's regulars (Michael, Nov 19).
- **The evidence:** the personal-item sighting (a `sighting` with `dropped`), the `dropped` card
  kind, and every place the judge weighed them:
  - `live_assessment` (`activity_card`, and the `item_drop` flag);
  - `live_activity` (the kind lists, the drop-owner matching and the packing);
  - the C# mirror `LiveActivity.cs` (`KindDropped`, `FlagItemDrop`, `DropOwners`; the code
    numbers are left as comments);
  - `movement_model` (the `item` factor);
  - the fixture `item3`;
  - the kind lists in `case_eval`, `connections` (TRACE_KINDS), `solver`, `jury`,
    `circumstantial`, `shared_ledger` and `live_evidence`;
  - `deduction.gd` and `card_model.gd`.
- **The tests and fixtures that set drops up:**
  - `test_evidence_cards` `dropped_item_search`, and `tests/fixtures/playtest_37291_drop.json`;
  - `test_evil_play` section 4;
  - the drop checks in `test_roles_night_sight` (its route checks stay);
  - `test_workshop_card_adapters` `_dropped_material`;
  - `test_workshop_remaining`'s drop calibration;
  - `measure_evidence`'s `dropped_belongings`, and `analyst`'s kind;
  - the `item3` card (a personal item found on a search) in
    `tests/fixtures/workshop_checkpoint_v5.json`'s movement example. Nothing referenced it.
- **Kept on purpose (Michael asked that tests built only for drops go, Nov 20):**
  - `tests/fixtures/playtest_54875_opening.json` still has one accusation that cited a
    dropped card (a `card_spec` on `late_stages` "day4-six", action 39). It's the recording of
    a real playtest, replayed by the `replay_54875` tool, not a drop test, and no suite runs
    it.
  - The word "dropped" elsewhere in the tests means a card left out or forgotten, not a drop.
- **Added:** `test_haunt_learning` checks that searching where the totem is hidden finds it,
  burns it and puts it on the board. Before, only `World.find_totem` was tested directly. The
  regulars were already checked there.
- **The docs:**
  - DESIGN "Drops", including the Framer note;
  - README;
  - `evidence_catalog.md` C5 and C6, and `evidence_catalog_code.md`;
  - `migration_notes.md`;
  - `tuning_catalogue.md`.

Crime-scene traces are separate and unchanged. A Framer planting items was never built.

**Kept: `LEGACY_EXTRA_SHIFT_DRAW`.** Seneschal split it out on Nov 20 (option B). See the next
section.

## The extra-shift roll: tried, split out, and what it needs

Argon's audit said to fold `LEGACY_EXTRA_SHIFT_DRAW` into this re-baseline. Removing it reshuffles
every seed's deal: who gets which gift, home and traits. So every test that hard-codes a seed and
then assumes who holds what breaks. In every case I tested, the suite passes again with the roll
put back, so the drop removal itself breaks none of them. Seneschal chose to ship the drop removal
now and leave the roll for Michael's reprioritization. The fallout is about 25 to 30 suites, for a
change that's only cleanliness.

**Fixed for the reshuffle and kept here as hardening.** Each now picks people by gift, alignment or
state, or searches for a deal, instead of using a fixed seed position:
- `test_agreement_trust`: compares the accused's trust with its own value before.
- `test_beliefs` `_test_other_source`: skips deals whose listener is the Night Watch itself.
- `test_case_metrics_dead`: the listener is a living good townsperson, not `good[2]`, who may be
  the Medium the test kills.
- `test_conversation_nights`:
  - `_where_were_you` finds a deal that reaches day 2 and skips silenced speakers;
  - `_watch_disclosure` takes an evil teller by alignment.
- `test_dialogue_decisions`: votes are silent apart from the no-voters' explanations after the
  tally (meeting plan M2d).
- `test_fixes_crowd_augur_lovers_pan`: the lone game clears the game's own work sightings.
- `test_mechanics_sharing`: restores the exact trust, and the sighting is about a third party.
- `test_npc_interactions`: keeping a promise alternates over the deferred deals, not by seed
  parity.
- `test_npc_chatter` `_test_confide` and `test_peer_role_gossip` `_test_hint_only_at_moderate_bond`
  (Beadle): a teller the day-1 bonus can move, and one that gives hints.
- `test_evidence_cards` `_public_sighting`: an evil teller and a good scapegoat by alignment.
- `test_evil_play`: reads the cursed villager's own grimoire line.
- `test_workshop_regressions`: the real Rumormonger, if there is one, is the speaker.
- `test_connections_pairings`: the two-kind game finds a day-3 deal.
- **Fixture fits (Lantern traced them, Nov 20: none is a belief regression):**
  - `fixture_seeds.framed_sighting`: a bystander must hold the subject's own home alibi for that
    night. A frame must be away from the subject's home (Lantern's filter from #327). There's a new
    optional `subject_trust` floor.
  - `sleepwalker_sighting` searches 3× further.
  - The Sleepwalker checks in `test_own_night_knowledge` and `test_connections_pairings` now
    measure the sighting's own effect against the same game read with no sleepwalking doubt
    (`OWN_ERR`), not an end state. On seed 100153 that's +4.29 against +7.74 log-odds. Michael
    kept the Sleepwalker's strength (Nov 20).
  - `test_own_night_knowledge`'s planter check requires the subject to trust the sighter at least
    0.5, so it hears the sighting nearly in full.
  - `Seeds.cards_effect` takes an optional `view_fn`.

**Fixed for the drop draws themselves.** Even with the roll kept, removing `_maybe_drop` removes
its random draws, so each night after the first walker plays out a little differently. Seven
suites at the merged head failed and all pass on main. With the draws put back (a probe, not
committed), the four quick ones passed, so they're fits to that night, not drop logic:
- `test_premise_step1`: the "clearly wrong premise" sat right on the line (-0.252 against
  -0.25) and tipped to -0.231. It now uses a Dowser count that names the target outright
  (-0.49).
- `test_social_credibility`: the drought pick can also land on the speaker's own home alibi,
  which reaches the ledger. That alibi now counts as told.
- `test_workshop_live_cognition`: after the day advance, the people a case only mentions can
  take up a sliver of slack (+0.001). The check is now on the named group's total.
- `test_relayed_alibi`: the search now skips a listener already sure of the relayer (seed
  100029 had them at 1.00, with no room to rise).
- `test_npc_fixes_shifts_dead_haunt`: the dead-sighting loop counts twelve deals that
  qualify, not twelve seeds. Pressed again, an owned outing may be confessed with its errand
  (`podium_confess`, seed 701), which still owns it.
- `test_own_gift_doubt`: "doubted below its prior" is its own search. The doubting game
  judged only the night it doubts.
- `fixture_seeds.framed_sighting` searches 3× further (`FRAMED_SEEDS`). Its bystander
  home-alibi rule (Lantern's) can be switched off with `bystander_alibi = false`:
  - In 60 seeds, 3 frames were away from home, and in none of them did a bystander also hold
    the subject's alibi.
  - So `test_connections_pairings` searches without the rule and has the bystander hear the
    subject's home alibi itself (`_hear_home_alibi`).
  - `test_own_night_knowledge` keeps the rule.

**Still failing with the roll removed** (not fixed; for whoever picks it up):
- `test_premise_step1` ("the evidence clearly argues against the premise")
- `test_prior_mapping` ("at least two fixture seeds have a good Seer")
- `test_relay_bluff` (the built towns on 692, 42 and 900)
- `test_shadow` ("shadow reasoning lands in the shadow log", 4242)
- `test_social_credibility` (the neutral-boundary wording)
- `test_roles_registry` (the Night Watch NIGHT_ROUTE shape)
- `test_self_sighting`
- `test_poison_self_doubt`, which timed out at 40 minutes under load

About 60 more suites hadn't run when the split was decided. The two partial runs' logs are in my
session only. Roughly a third of all suites were affected, so expect a similar share of the rest.

## Measured

See the PR for the suites run at the head, and the golden re-baseline. No game-terms measurement
of the drop removal was asked for (Michael: just drop it). What the player loses: the rare find of
someone's belongings when searching a place, which placed them out that night.

## Proposed for the backlog

None.

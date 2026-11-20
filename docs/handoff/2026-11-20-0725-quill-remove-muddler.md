# Remove the Muddler

**Claude-Quill, Nov 20.** Base: main at c9fc18a5, with main through #397 merged in. Status: ready for review. Next actor: Beadle
reviews the sim side, Lantern the judge side, then Bailiff. **Golden moves** (see "Measured"):
it joins the golden queue behind #397.

## What changed and why

Michael (Nov 20): "everything to do with the Muddler". It was a custom-script secret: a good
townsperson who, without knowing it, garbled one detail of a reading or night sighting they
passed on. It was never on the default script. In 40 forced games it had something to muddle
in only 5 (BACKLOG, Nov 17).

**Removed:**
- **The secret:**
  - `sim/muddler.gd`;
  - the `muddler` entry in `SECRET_MODS` and `SECRET_MOD_LIST`;
  - the gossip floor in `World._assign_secret_mod`;
  - `MUDDLER_GOSSIP_FLOOR` and `MUDDLER_CHANCE`;
  - the `npc.gd` fields `muddled_items` and `pending_muddle_debunks`.
- **Its hooks:**
  - `social.gd`: the relayed items, the hearsay the player hears, and role-query readings.
    The `muddled` / `muddled_by` card flags go too.
  - `mind_meeting.gd`: the late relay and the anonymous relay at the meeting; the source's
    debunk at the podium (claimed, revealed, or deferred until they reveal);
    `_retire_muddled_reading_in_town`.
- **The judge side:**
  - the `muddler` modifier code in `solver.gd`, `solver_backend.gd` and the C#
    `SolverContext.cs`. Code 4 is left as a comment;
  - the modifier in `case_eval`'s world counts.
- **Adjudicating a muddled card:**
  - the private disclaimer (`Muddler.apply_private_disclaimers`, from `ask gift` and
    `ask night`);
  - the board's auto-disclaim (`game_board._deprecate_muddled_matches` and the
    `deprecate_muddle` fact);
  - the "deprecated: disclaimed by" card line, its dimming, and the presentation refusal for
    a disclaimed card. Withdrawn cases keep their dimming.
- **Tests built only for the Muddler:**
  - `test_roles_secrets` `_test_muddler_simulation_and_debunking`;
  - `test_roles_night_sight` `_test_muddler_monitor_and_confessor`;
  - the forced-Muddler gossip check in `test_dialogue_fixes_gossip_reasons`.
- **Tests switched to another secret:**
  - `test_roles_secrets`'s world count (now 1,050 worlds with four secrets) and the
    Rumormonger secret-pair check, which now uses the Sleepwalker;
  - `test_premise_step2`'s "a secret this case can't have", which now takes the Sleepwalker
    off that game's script;
  - `test_text_terms`'s secret-name sentence.
- **Docs:** DESIGN's secrets table, README, `belief_model`, the evidence catalogues,
  `premises_plan`, `secrets_rework` and `open_questions` ("tentatively cut" is now "cut"),
  and `tuning_catalogue`. BACKLOG: "Remove the Muddler" is marked built, [in review]. Vicar had already folded the old Muddler items into it.

**Added:**
- **`ScriptDef.RETIRED_IDS`** (`["muddler"]`): `from_dict` drops a retired id. An old saved
  custom script that lists the Muddler (or forces it) loads without it and passes its check,
  where before it would have errored with "muddler isn't a known secret".
- **A check for it** in `test_roles_secrets`.
- `test_joint_reasons` keeps playtest 89077's script as recorded, Muddler included, so it
  exercises the drop.

## Small calls made on Michael's behalf

- **The auto-disclaim rule goes with the Muddler** (option A; Seneschal relayed that Michael
  didn't object, Nov 20).
  - **What it did:** when a reader's own reading reached the board, every relayed copy of it
    that differed was greyed out and couldn't be cited. That applied to any relayer, not only
    a Muddler.
  - **Now:** an evil relayer's twisted copy stays usable. Its clash with the real reading is
    evidence against the relayer, which the judge already weighs.
- **Retired ids in saved scripts are dropped quietly** rather than erroring.

## Measured

- **Suites, all pass:**
  - test_roles_secrets, test_roles_night_sight, test_roles_people, test_joint_reasons,
    test_premise_step2, test_text_terms and test_dialogue_fixes_gossip_reasons;
  - test_board, test_ui, test_dialogue_voices, test_social_credibility and test_meeting_flow;
  - test_buildings_tavern_town_hall, test_case_script, test_delusional_self_doubt and
    test_demon_declaration;
  - test_mechanics_conclusions, test_new_case_memory, test_roles_dead, test_roles_evil,
    test_roles_official, test_roles_registry, test_roles_shelter, test_ui_controls and
    test_workshop_integration.
- **Golden moves:** 54875, 900 and 98933 diverge (42 and 692 are identical). The default
  script never dealt the Muddler, but `workshop/reason_attribution.gd`'s defence view (an
  NPC weighing a disclosed fact) built its worlds from the full secret roster
  (`C.SECRET_MOD_LIST`), not the game's script. So every NPC's defence scoring counted worlds
  in which someone is a Muddler, worlds no game on the default script could ever deal.
  - **Removing them** shifts a few close decisions: 54875 from its first refresh, 900 at the
    day-3 meeting, 98933 at the day-2 meeting.
  - **Re-baselined** to `baseline_9fa5a74` once #397 merged. Two captures were identical.
    Divergence from `baseline_58cb94a`: 54875 (day 1), 98933 (day 1), 42 (day 2) and 900
    (day 3); 692 is identical. Every seed's outcome is unchanged.
  - **For Lantern:** that view still uses the whole roster rather than the game's script.
    Making it follow `case_script.secrets` would be a further change.
- **In game terms:** nothing changes on the default script. On a custom script that listed
  the Muddler, the deal now picks among the other secrets.

## Proposed for the backlog

None.

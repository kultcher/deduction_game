# Quill: explicit night-sighting rebuttals

- **Agent:** Claude-Quill
- **Base:** `main` 62bdc8e3, with PR #404 (`claude/beadle-split-meeting`, the defence moved to
  `sim/mind_defence.gd`) merged in first, at Beadle's request
- **Branch:** `claude/night-rebuttals`
- **Status:** built, suites green locally, golden identical; not pushed
- **Next actor:** Bailiff (review and merge after #404); Michael for the wording

**Placeholder wording, for Michael.** The four new voice keys carry the same text in every
voice until he words them.

## What changed and why

BACKLOG "Explicit night-sighting rebuttals" (decided): a defender seen out at night may now
argue from the public death record, in their own words:

- **other_block:** "Someone died on {block} that night; I was never on {block}." (Approved
  wording, Herald's `2026-11-20-1807-herald-night-rebuttal-lines.md`.) When a Demon death was
  announced for that night and the block they were seen on is neither their own home block nor
  the victim's.
- **no_death:** "I was seen out {when}, but no one died that night." When the morning announced a
  quiet night and the defender knows of nothing that could have turned the Demon away.

`MindDefence.night_route_rebuttal(w, d, nd, block)` (sim/mind_defence.gd) decides it. It is said:

- **At the meeting** (`defend_self`): for the case's hinge sighting, read the way 2c reads it,
  else the framed night's sighting, else the heaviest night sighting against them. It's added
  to whatever else they say: it gates none of the existing moves, and it joins the moves list
  last, as `rebuttal`, with strength 0. The line comes straight after their account of that
  night when they give one (2c or the true-sighting account), and otherwise first, before any
  gift reveal or confession. It is a `def:` ledger entry with scope `{"type": "rebuttal",
  "variant", "night", "sighting": eid, "cites"}`.
- **At the podium** (`MindPodium.press_card`, a sighting card): after the account, with the same
  weightless entry for the town.
- **In private** (`MindDialogue.press`, a sighting): after the rest of the answer, with the
  private keys. No one else hears it, so there's no ledger entry.

## Decisions

- **Speech only, no weight.** The judge already reasons from the same record
  (`LiveActivity._profile_paths` sends the Demon to the victim's home by `demon_routes`, straight
  from its home block), so the line carries no belief weight. It has no new constant, no apply_info, and
  no suspicion change. A `rebuttal` scope is a non-claim defence, so `shared_ledger` treats it as
  owned speech.
- **The route notion:** the judge's, for the defender as the Demon: `C.route(d.home_block,
  victim.home_block)` for each Demon victim that night. Every pair of blocks is joined, so that is
  just the defender's home block and the victim's: a sighting on either gets no other_block. An empty block gets none.
- **True as stated, for everyone:** if the defender was really out that night on their own or the
  victim's block, they never say it (good or evil). Evil says it only when it's true as stated. Its dev-log
  reason reads "True but misleading"; good's reads "from the public record".
- **Night 0 is skipped** (no kill), and so is any night not yet past.
- **Knows of a thwart (public signals only):** any public Warden or Veteran claim; a
  `player_ward_context` for that night shown to the town or to them; a Warden telling them of a
  save that night; the player warding them; or their own good protective role. The quiet night
  itself is public (every morning's announcement, `quiet_night` in the dev log). Why it was quiet
  is not public, so the Demon's own knowledge of its failed attack doesn't stop it. The Demon
  may say "no one died", and the log marks that as true but misleading.
- **Deterministic, no decision roll.** This matches 2b, 2c and 2d. No RNG is drawn, so golden
  doesn't move.

## Small calls made on Michael's behalf

- Distinct private keys (`private_night_*`), following `confess_secret_private`/`_public`.
- Any public Warden or Veteran claim counts as a known possible save, not only a claim naming
  that night. It's broader than `World._quiet_night`, which counts only claims living that
  night, and errs toward not making the argument.

## After approval (Nov 20, later)
- **Approved wording** in block terms (Herald, `2026-11-20-1807-herald-night-rebuttal-lines.md`);
  comments, test labels and this entry now say blocks, not roads.
- **"No one died" only after an account that owns the outing** (Codex): it opens "I was seen
  out", so after a home alibi, a refusal or no account it would retract what the defender
  said. `MindDefence.rebuttal_fits_account` gates it at the meeting, the podium and the private
  press; "another block" fits any account.
- **No "I was never on" for a victim's neighbour** (Codex): a defender who lives on a victim's
  block was on it all night, so the other-block line isn't said.
- Golden identical to `baseline_7005cc6` after both; test_night_sighting_rebuttal,
  test_dialogue_voices, test_dialogue, test_meeting_flow and test_confessed_night pass.

## Measured

- **New suite** `tools/test_night_sighting_rebuttal.gd` (in `ci_fast_suites.txt`): 7- and 10-NPC
  games from `fixture_seeds.search`, with the nights hand-built. It covers off-route against
  on-route, a quiet night with and without a known thwart (Warden claim, Veteran claim, a public
  ward, a ward shown to someone else, a told save), night 0, a defender truly on the victim's block, evil
  on the route and evil that walked it, the evil log reason, the ledger entry at weight 0 for
  every listener, listeners' suspicions identical with the entry held and removed, the line
  following the night account, the podium, and the private press.
- **Suites** (`run_gd_tests.py`): 13/13 passed: test_night_sighting_rebuttal,
  test_mechanics_defences, test_framed_defence, test_defence_grounds, test_defence_repeats,
  test_day_defence, test_daytime_defence_lines, test_caught_out_ladder, test_press_caught_out,
  test_press_night_case, test_meeting_reasons, test_dialogue_voices (key count 258 to 262),
  test_meeting_flow.
- **Golden:** identical to `baseline_7792e9a` at `--tol 0 --ignore engine` (all 5 seeds).
- **Not measured:** how often it fires in real games.

## Proposed for the backlog

None.

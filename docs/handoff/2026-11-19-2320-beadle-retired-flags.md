# Cleanup: three retired items removed

- **Agent:** Claude-Beadle
- **Base:** main at `0d426d1` (`baseline_652298a`)
- **Branch:** `claude/beadle-retired-flags`
- **Status:** PR open. Zero drift.
- **Next actor:** Bailiff (review and merge).
- **Source:** the cleanup rollout (Michael, Nov 19, via Seneschal) and Argon's bloat audit
  (`docs/maintenance/bloat_and_obsolescence_audit_2026-11-19.md`, section 5).

## What changed

Three items that nothing reads are removed:
- `Tuning.Social.RIVAL_CLAIM_EFF` (0.6). It was a retired legacy claim-collision weight; the
  shared belief model owns claims.
- `Tuning.Meeting.PARANOIA_DRIFT_RATE` (0.06). It has been unused since Oct 30, when urgency
  replaced paranoia drift.
- `World.knell_night`. It was a legacy field; `sexton_tolled_night` is the one in use.

The catalogue is regenerated.

**Left alone, as Seneschal said:**
- `ALLOW_NO_GIFT_DENIAL` and `USE_FLAVOR_SECRETS`.
- `LEGACY_MUD_DROPS_ENABLED` and `LEGACY_EXTRA_SHIFT_DRAW`, which go in Quill's drops PR.
- `STRICT_EVALUATOR`. Herald is checking whether the strict mode and its fallback still serve
  a purpose.

## Measured

- **Readers:** none in `sim/`, `game/`, `workshop/` or `tools/`, by grep, before removal.
- **Golden:** identical to `baseline_652298a` at `--tol 0` on all five seeds.
- **Suites:** test_tuning_hoist, test_nomination_and_evil_tuning, test_meeting_flow and
  test_social pass.

## Proposed for the backlog

None.

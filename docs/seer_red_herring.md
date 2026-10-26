# Readings that never move beliefs: the Seer red herring

Prepared by Claude, Oct 26, 2026, for a second opinion (another model or a later session). Self-contained:
what's wrong, what's already done, the files to touch and how, and the risks.

## The symptom (playtest 37291)

NPCs ignored their own gift readings. Jory (Seer) got "yes" on Kiran+Fenwick (night 0) and on
Isolde+Fenwick (night 1), and on Day 3 his suspicion of Fenwick was 0.01; he said he trusted Fenwick.
Edda (Archivist: "one of Agnes/Jory is the Breathstealer") voted no on Agnes at 0.08 suspicion.

Reproduce on `main` (seed 37291, ten townsfolk, `wait`/`sleep` to Day 3):

| Mode | Jory's suspicion of the people his "yes" readings named |
| --- | --- |
| shared model on (normal play) | 0.00 to 0.01 |
| shared model off (`set_workshop_effects(false)`, legacy rules) | 0.39 to 0.55 |

The log lines "(shared ownership toggled)" at case start are not the bug: that's the single
`set_workshop_effects(true)` call in `Game.new_case`, retracting each NPC's legacy contribution so the
shared model can own it. The bug is that the shared model then puts back nothing for these readings.

## How the shared model scores a case (just enough to follow the bug)

`workshop/case_eval.gd::evaluate(view, case_data, listener)` works over "classes" of possible worlds
(who is evil, the Demon, the modifier and its holders):

```
w0       = team_prior[team] * fits[class]          # prior from the listener's suspicion, times role fit
base[k]  = counts * w0 * own_like                   # "before the case"
post[k]  = base[k] * case_like * move * test_like   # "after the case"
lr       = odds(post share) / odds(base share)
people   = per-person P(evil) before and after
```

The belief refresh (`workshop/jury.gd::_consequences_eval`, effects per person from
`CaseEval.shift(prior, posterior)`) moves suspicion by how far each person's P(evil) changed.

`fits[class]` comes from the role check, `workshop/role_constraints.gd`: can roles be assigned in this
world so every claim and report is consistent? Several readings get their meaning only there: Seer,
Archivist, Clerk, Gravedigger (via `_assign`), and Seer red-herring bookkeeping. `case_like` covers the
readings with a content table (`Solver.report_table`: Surveyor, Dowser, Night Watch, ...).

## Bug 1: role-checked readings counted on both sides (fixed on a branch)

`fits` multiplied both `base` and `post`, so a reading that only acts through the role check moved
"before" and "after" equally: LR 1, shift 0, no belief change, for anyone (holder or listener).

**Done on branch `claude/own-readings` (commit 97fbf9c, not merged):**

- `case_eval.gd::evaluate`: `base` uses `fits_before = _class_fits(view, cc, [], knowledge)`, the role
  check without the case's own cards; `post` keeps `fits` (with the cards).
- `case_eval.gd::_class_fits`: the fit cache keys (`neutral_key`, `key`) include `bare =
  cards.is_empty()`. Without that, the "before" call returned the cached "with cards" table (same
  `cc.key`) and the fix did nothing.

Result: Edda's Archivist reading now moves her suspicion of Jory 0.10 to 0.43; Clerk readings move the
named pair slightly toward good. Full suite on the branch: 81/82; `tools/test_workshop_protection.gd`
fails, not yet investigated (likely numbers that assumed the old cancellation: quiet-night protection
uses Warden/Veteran claims, which are role-checked).

Check before trusting it: are there other places that compute a before/after from the same
fits (for example `jury.gd` scoped replies via `_case_eval`, `factored_channels.gd` "roles" factors,
`support_model.gd`)? Each needs the same treatment or it will disagree with `evaluate`.

## Bug 2: the Seer's "yes" (and "no") carries almost no information

Even with Bug 1 fixed, Jory's suspicion stays at 0.0. The Seer is modelled in
`role_constraints.gd::_fits_view` (the `elif card.role == "seer":` branch) with a red-herring mask `rh`:

```
rh starts as every good person except the Seer
"no" on pair P:   if the Demon is in P -> impossible; else rh &= ~P
"yes" on pair P:  ping = the answered person, or P
                  registration "demon"   needs the Demon in ping
                  registration "marked"  needs the Marked person in ping
                  red herring (or unanswered and neither Demon nor Marked in ping): rh &= ping
end: if a Seer reported and rh == 0 -> impossible
```

It's a yes/no check. A "yes" with neither the Demon nor Marked in the pair only needs some good person
in the pair to be the red herring, which is possible in almost every world. So "yes" barely narrows the
worlds, and every surviving world counts the same. In truth the red herring is one fixed person, chosen
once (see the native `n.red_herring` in `sim/world.gd`), so a "yes" without the Demon is unlikely
(about 2 in 7), and a "no" is slightly informative too.

The testimony version (a Seer reading relayed by someone else) has the same flaw:
`solver.gd::_testimony_content`, `"seer": return demon or (pair & ~evil) != 0 if data.yes else not demon`.

### The fix: a weight, not a yes/no

For a world where the Seer's source is good (its readings are honest; health is handled separately by
reading error):

```
G       = good people except the Seer (the red herring's candidates, as the native setup picks them;
          verify the exact rule in sim/world.gd: alive at setup? excludes Marked?)
rh      = G narrowed by every reading that relies on the red herring (as the code already does)
weight  = popcount(rh) / popcount(G)     # P(the one red herring is consistent with all readings)
```

This handles "yes" (rh &= ping), "no" (rh &= ~P) and repeated readings sharing a person, with no new
world variables. Worlds where the Demon (or Marked) explains every "yes" keep weight
popcount(G minus the "no" pairs)/popcount(G), close to 1.

Expected size: one "yes" on a pair with no other information makes each pair member roughly 3 to 4
times likelier evil. Two "yes" readings sharing Fenwick should make him a strong suspect for the Seer
himself.

### Files and changes

1. `workshop/role_constraints.gd`
   - `_fits_view(...)`: return a float weight instead of a bool (0.0 = impossible). Compute `G` where
     `rh` is initialised and return `popcount(rh) / popcount(G)` when a Seer reported (1.0 otherwise).
     Keep every other check as 0.0/1.0.
   - `fits(...)`: keep a bool API for existing callers (`weight > 0.0`), and add `fit_weight(...)` if
     needed. The per-mask cache `results[mask]` stores the float.
   - `fits_table(...)`: return a `PackedFloat64Array` (or add `fits_weights(...)` next to it and leave
     the byte version as `weight > 0`). Find every caller (below).
   - `coarse_mask(...)`: the weight depends on the evil set, the Demon, Marked (when a Seer card exists,
     `seer` already adds `marked`) and the source, all in the mask today, so classes stay valid. Check
     this holds once a Seer card is present: if any Seer-relevant world part is missing from the mask,
     classes with different weights would share a cached value.
2. `workshop/case_eval.gd::_fits_over`: multiply by the weight (it already turns bytes into floats and
   applies `bluff_weights`). Mind the "declarations" fallback: when content fails (weight 0) in live
   play, a class can survive as an erroneous reading via the declaration-only check; keep that path
   reading the weight as 0/1.
3. `workshop/solver.gd`: `_solve` filters worlds by `fits_table` (hard constraint). Keep it a filter
   (`> 0`); the weight belongs to likelihoods, not to the possible-world list. Also the Seer
   registration table near `report_table` (around line 757) and `_testimony_content` (apply the same
   weight, or a fixed red-herring factor, to relayed Seer testimony).
4. `workshop/factored_channels.gd`: the "roles" factor stores `rows[signature]` from the role check;
   it must store the weight, not a 0/1, or the factored path disagrees with `evaluate`.
5. `workshop/reading_challenges.gd` (line ~108, `fits_table` on one report, and the misled-Seer case
   at ~61): decide whether a challenge reads the weight or just possibility; keep it consistent.

### Risks

- **Numbers shift everywhere a Seer reading appears.** That's the point, but bot baselines, the
  balance watchlist ("night sightings are too decisive") and several tests with expected numbers will
  move. Expect test updates in `test_workshop_*` suites that use Seer fixtures.
- **Cache keys.** Role fits are cached per class mask in three places (`role_constraints.fits`,
  `fits_table`, `case_eval._class_fits`/`_coarse`). A weight that depends on something outside the
  mask silently reuses the wrong value. The Oct 26 `bare` key bug is the same class of mistake.
- **Hard filter versus weight.** Anywhere a 0/1 is compared with `== 1` or used as a mask must keep
  working (`> 0.0`).
- **Evil bluffing the Seer.** In bluff mode (`bluffs = true`, live play), an evil source's declarations
  constrain nothing: the weight must be 1.0 when the source is evil in that world.
- **Poisoned or Delusional Seer.** Health is modelled by reading error and valid tables, not the role
  check. Don't fold health into the weight, or it's counted twice.
- **Performance.** `popcount` per class is trivial; the risk is cache splits. Re-measure
  `tools/replay_54875.gd` and the seed-42 Day 3 meeting entry (it was 4.5 s before; the budget is about
  2 s for meeting entry and presenting).
- **Two Seers.** Only one real Seer exists; competing Seer claims are already handled (`seer !=
  card.source` fails). Keep that.

### Tests to add

- Seed 37291: by Day 3, Jory's suspicion of Kiran and Fenwick is well above everyone else's (compare
  with legacy mode, 0.39 to 0.55).
- Unit, on a small live view: one "yes" on a pair, neutral otherwise, raises both members and lowers
  everyone else; a "no" slightly lowers the pair; two "yes" readings sharing one person raise that
  person most.
- The holder and a listener who heard the reading both move (Bug 1 covered every listener, not only
  the holder).
- `CaseEval.evaluate` and the factored path give the same per-person result on a Seer case.
- `tools/test_meeting_stream.gd` still identical; `test_trace` still passes.

### Alternative considered

Making the red herring a world variable (like Marked) gives exact answers but multiplies the universe
by about seven and every cache with it. The weight gives the same per-world probability without that
cost, because the red herring is never asked about directly.

## Merge order

1. Finish Bug 2 on `claude/own-readings` (on top of Bug 1).
2. Investigate `test_workshop_protection` and any new failures; re-measure speed.
3. Merge to `main`, then re-run bot batches: every shared-model result before this undercounted
   role-checked readings.

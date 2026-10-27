# Case Workshop: Scaling, Role Integration & Design Guide

This document covers three areas following the October 22 performance pass (`31.1s -> 1.66s` on seed 692; `13.6s -> 2.50s` on seed 4242):

1. **Remaining Optional Hot-Loop Optimizations** (how to cut the remaining `1.66s–2.50s` town presentation time down to `~0.6s–1.0s` without altering cache semantics or behavior hashes).
2. **Integrating the Remaining Script Roles** (how to bring the other 12 good gifts, 4 minions, and physical/movement evidence into the live evaluator without blowing up the 5,040-world domain).
3. **Role Design & Complexity Guidelines** (how to evaluate future role concepts and where to require player specificity vs. automated solver enumeration).

---

## 1. Remaining Optional Hot-Loop Optimizations

In the post-`6707759` profile, constraint solving (`constraint_solve`) is already down to **65–78 ms** across an entire 10-person town presentation. Almost all of the remaining **1.66s–2.50s** is concentrated in three stages:
- `candidate_search` (`Reasoner._find_live`): **764 ms** (692) / **1,181 ms** (4242)
- `world_comparison` (`Support._comparison_inner`): **335 ms** (692) / **559 ms** (4242)
- `priors` (`Support._prior_scores`): **232 ms** (692) / **431 ms** (4242)

None of these require changing cache keys or relaxing exact-input safety checks. They are pure inner-loop reductions:

### A. Hoist Per-Person Weight Lookups & Pre-Score `world.evil` Bitmasks in `Support._prior_scores`
**The Bottleneck:**
When `_prior_scores` builds the ranking table for a listener, it loops over all compatible worlds in `_solve(view, [], listener.knowledge).worlds` (up to **5,040 worlds**). Inside that 5,040-world loop, it runs a nested `for i in range(view.people.size()):` loop, doing `view.people[i].id` and dictionary lookups `listener.suspicion.get(id, 0.1)` and `listener.npc_trust.get(id, 0.5)` plus float math **50,400 times per listener**.

**The Optimization:**
Across all 5,040 live worlds in a 10-person town, there are only $\binom{10}{3} = 120$ unique `world.evil` bitmasks (each repeated up to 42 times across the different secret-modifier holders). Furthermore, a person's `evil_weight[i]` and `good_weight[i]` depend only on `i` (`0..9`), never on `world`:
1. Before looping over `worlds`, precompute two 10-element `PackedFloat64Array`s: `evil_w[i]` and `good_w[i]` for $i \in [0..9]$.
2. When no conversion curse is active (`not view.get("chronology", {}).has("curse")`), a world's base prior score depends **only** on `world.evil` (10-bit integer `0..1023`). Cache the computed product in a local array `mask_scores` of size `1 << n` (initialized to `-1.0`).
3. Inside the 5,040-world loop, look up `var score: float = mask_scores[world.evil]`. It will only compute the 10-person product **120 times** instead of **5,040 times** (a **42× reduction** in float math and zero dictionary lookups inside the world loop), while preserving the exact left-to-right float multiplication order `0..9`.

### B. Compact Matching World Indices in `Reasoner._find_live`
**The Bottleneck:**
In `Consequences._assess`, `Support.explain` is called for all 10 townsfolk. Even though `matches[key]` caches the per-world `PackedByteArray` (`table`) of which worlds satisfy `_matches(...)` and caches completed `(target, type, budget, want)` queries, each of the 10 townsfolk asks about a **different `target`**.
On each new target (and especially when a target's alignment is forced, so the rival search must test all 5,040 worlds before exhausting), `_find_live` loops `for candidate in Domain.worlds(view):` across all **5,040 dictionaries** in GDScript just to check `table[c_idx]` one by one.

**The Optimization:**
1. In `Domain.worlds(view)`, alongside `"worlds": result`, store a parallel `PackedInt32Array` of `evil_masks` (`evil_masks[c_idx] = w.evil`) and `marked_indices` (`marked_indices[c_idx] = w.marked`).
2. In `Reasoner._find_live`, iterate by integer index `for c_idx in range(n_worlds):` using `evil_masks[c_idx]` and `marked_indices[c_idx]` instead of unpacking `candidate` Dictionaries on every skipped world. Only fetch `worlds_arr[c_idx]` when `fits` is `true` (at most once per search!).
3. When `budget >= n_worlds` (exhaustive search in `"full"` mode) and the `table` has already been fully populated (`matches[key].complete == true`), you can pre-record the bitmask of `any_evil_mask` (bitwise OR of `w.evil` for all fitting worlds) and `any_good_mask` (bitwise OR of `~w.evil` for all fitting worlds) plus total fitting count, or still scan the `PackedInt32Array` in ~10× less time than Dictionary iteration.

### C. Integer Unpacking in `Support._comparison_inner`
**The Bottleneck:**
When `_comparison_inner` has a cache miss (or evaluates a new `worlds` subset), it loops over `worlds` and then runs an inner loop `for i in range(scores.size()):` doing dictionary string lookups `scores[i][alignment] = maxf(scores[i][alignment], score)` (`5,040 * 10 * 4` dictionary key accesses).

**The Optimization:**
Accumulate into four local `PackedFloat64Array`s of size `n` (`max_evil`, `max_good`, `max_marked`, `max_unmarked`) using integer index `i` and bitmask check `(world.evil & (1 << i)) != 0`, and only construct the 10 `{"evil": ..., "good": ..., "marked": ..., "unmarked": ...}` dictionaries once after the loop finishes.

---

## 2. Blueprint: Integrating the Remaining Current Roles

Currently, `workshop/live_assessment.gd` restricts live cases to three gift roles (`ROLES = ["surveyor", "rumormonger", "dowser"]`). Expanding to the full 15-role script and physical/movement evidence should **not** multiply the base `world_domain.gd` universe uncontrollably.

Below is how each remaining role maps onto the existing solver architecture.

### Group A: Direct Bitmask Readings (Zero New Worlds in `world_domain.gd`)
These roles can be added directly to `Assess.ROLES` and `Solver._report_holds` using the existing 5,040-world domain `(world.evil, world.modifier, world.holders)`:

| Role | Card Payload (`data`) | Bitwise `_report_holds` Rule (given good, healthy source) |
| :--- | :--- | :--- |
| **Hearthwitch** | `{"nbrs": [id1, id2], "count": c}` | Identical to **Dowser** with `group = data.nbrs` (a 2-bit `nbr_mask`). Check `popcount(pos_mask & nbr_mask) == data.count` across `mark_reads in [false, true]`, and check any player slot answers against `pos_mask`. |
| **Martyr** | `{"target": id, "chosen": id, "evil": bool}` | Public Martyr saves are already injected into `knowledge.good`. As a report card: `chosen` has alignment `evil == data.evil` at `observed_at` (with Marked registration allowed if `data.evil == true` and `chosen == world.marked`). |
| **Veteran** | `{"attacked": bool, "block": b}` | Source must be good (`not (world.evil & (1 << source_idx))`). Does not directly constrain `world.evil` by itself, but corroborates quiet-night survival and claims in `Domain.claims_compatible`. |

### Group B: Demon-Specific Readings (Conditional $\times 3$ Branch Only When Needed)
- **Roles:** **Seer** (`{"pair": [id1, id2], "yes": bool}`) and **Scion** (succession).
- **Why they differ:** A Seer detects **the Demon** (plus **Marked**), not Minions. Currently, `world.evil` in `world_domain.gd` is an unordered 3-bit mask of the evil team (`120` combinations in a 10-person town).
- **How to implement without slowing down non-Seer cases:**
  1. Do **not** expand `Domain.worlds(view)` by $\times 3$ (to 15,120 worlds) when no Seer/Scion/Demon-specific card or conclusion is present.
  2. Even better: you don't need to expand `Domain.worlds(view)` at all for a single Seer card! In any world `w`, `w.evil` has 3 evil bits.
     - A Seer `"no"` (`yes == false`) on `[A, B]` means: **at least one evil bit outside `{A, B}` exists to be the Demon** (which is always true unless 3 evil players are in a 2-person pair, impossible!). Wait—does a Seer `"no"` clear `A` and `B` of being the Demon? Yes, it means the Demon is one of the evil bits *not* in `pair_mask`. If multiple Seer cards are combined (e.g. Seer `"yes"` on `[A, B]` and Seer `"no"` on `[A, C]`), tracking `world.demon` (which of the 3 evil bits is the Demon) is required so cross-card Seer deductions resolve (`A` cannot be the Demon $\implies$ `B` is the Demon or Marked).
  3. Therefore, when `view` contains any `seer` report or a `"demon"` conclusion, include `demon_idx` (3 choices per `evil` mask) in `Domain.worlds(view)` (`15,120` worlds in a 10-person town, `840` in a 7-person town). With the byte-mask solver in `solver.gd`, 15,120 worlds takes ~150 ms instead of 65 ms.

### Group C: Role-Identity Readings (Local Bipartite Check, Zero New Worlds)
- **Roles:** **Archivist** (`{"pair": [id1, id2], "role": r}`), **Clerk** (`{"pair": [id1, id2], "role": r}`), **Gravedigger** (`{"executed": id, "role": r}`).
- **Critical Rule:** **Never enumerate good role assignments in `world_domain.gd`.** Permuting 15 good roles across 7 good players would multiply the universe by $32.4\text{ million}$.
- **How to implement:**
  1. **Gravedigger:**
     - If `data.role` is an evil role (`demon`, `poisoner`, `breathstealer`, `revenant`, `scion`), `executed` must be evil in `world.evil` (and `world.demon == executed_idx` if `data.role == "demon"`).
     - If `data.role` is a good role, `executed` must be good in `world.evil`, and `data.role` must not conflict with `Domain.claims_compatible` (no other accepted healthy report source can hold `data.role`, and `data.role != listener.knowledge.own_role` unless `executed == self`).
  2. **Clerk / Archivist:**
     - If `data.role` is a good gift, at least one person $p \in \text{data.pair}$ (or the player's answered slot $p \in \text{answer.positive}$) must be:
       - **Good** in `world.evil`, AND
       - Compatible with holding `data.role` in `Domain.claims_compatible` (i.e., $p$ is not already required to hold a *different* gift by another accepted report in the active subset, and nobody outside $p$ is required to hold `data.role`).
     - If `data.role` is a Minion/Demon role (if Archivist/Clerk variant ever queries evil roles), at least one $p \in \text{data.pair}$ must be **Evil** in `world.evil`.

### Group D: Night Movement, Alibis & Physical Traces (Factored Likelihoods)
- **Roles & Cards:** **Night Watch**, **Lamplighter**, **Warden**, **Medium**, **Sleepwalker / Lovers**, `sighting`, `vigil`, `alibi`, `trace` (crime-scene material), `dropped` (personal item or home material).
- **How to wire into Live Assessment:**
  1. **Hard Walker Constraints (`Solver._movement`):** `Solver._movement` already solves $2^{10} = 1,024$ walker bitmasks per night for `sighting`, `alibi`, `nightwatch`, and `lamplighter` independently of the 5,040 alignment worlds. Extend `_movement` from `for night in [1, 2]:` to `for night in range(1, view.day + 1):` so it covers all nights up to the current day.
  2. **Soft Route/Trace Likelihoods (`Movement.factors`):** Instead of using hardcoded fixture tables (`view.movement_experiment.scenes`), derive the public movement context in `game/workshop_bridge.gd` / `workshop/live_assessment.gd` from public board data:
     - **Crime-scene blocks per night:** Read from player-known `death` / `trace` cards on the board.
     - **Subject home blocks & evening sightings:** Read from `view.people` and evening `sighting` / `conversation` receipts.
     - **Eligible gift destinations:** Medium can only visit homes of people already dead before that night; Warden/Night Watch can visit any block.

---

## 3. Guidelines for Concepting New Roles & Mechanics

In an exhaustive possible-worlds engine, a role's computational cost is determined by **whether it adds a dimension to `world_domain.gd` or couples two dimensions that are currently factored apart**.

### The 4 Complexity Tiers

1. **Tier 0 — Static World Predicates (Virtually Free):**
   - *Pattern:* Reads alignment, secret modifiers, home blocks, neighbors, or social traits at a known timestamp.
   - *Why it's safe:* Evaluates per-world in `Solver._report_holds` and caches into a 5,040-byte mask once.
2. **Tier 1 — Bounded Public Event Branches (Low Cost, $\times 2$ to $\times 5$):**
   - *Pattern:* A mid-game alignment or role change triggered by a **single, publicly announced event** with a small candidate pool (e.g., Revenant curse on execution branching across `yes_voters`; Scion promotion when the Demon is executed with $\ge 5$ alive).
   - *Design Rule:* Only expand worlds when the public event has actually occurred in `public_events`.
3. **Tier 2 — Unannounced Multi-Night State Machines (High Danger, Exponential in Days):**
   - *Pattern:* Silent night-by-night conversions, silent Demon-jumping on any night, or trying to enumerate "Who did the Poisoner target on Night 1, Night 2, Night 3, Night 4?" inside `world_domain.gd`.
   - *Why it explodes:* Branching 7 choices per night over 4 nights multiplies 5,040 worlds by $7^4 = 2,401$ (**12+ million worlds**).
   - *Design Rule:* **Force Player Specificity + Evidence Gating.** Never enumerate open-ended night faults or unannounced conversions in `world_domain.gd`. Require the player to anchor the hypothesis on the canvas (*"Person X was poisoned/turned on Night N"*, backed by a trigger card or contradiction), which keeps the world multiplier at $\times 1$ to $\times 2$.
4. **Tier 3 — Coupling Alignment Worlds with All-Town Night Routes (Nuclear Hazard):**
   - *Pattern:* A hard constraint that requires simultaneously knowing `(everybody's alignment/role)` $\times$ `(everybody's night path on Nights 1..N)`.
   - *Why it explodes:* Nesting $1,024^{\text{nights}}$ walker masks inside $5,040$ alignment worlds creates billions of states by Day 3.
   - *Design Rule:* Keep hard walker-count constraints (`Solver._movement`) factored apart from alignment (`world.evil`), and bridge them via **player-selected card slots/citations** (*"Who walked?"* / *"Which claim explains this outing?"*) and **per-subject likelihood ratios** (`movement_model.gd`).

### When to Force Player Specificity vs. When to Let the Solver Enumerate

| Player Premise / Situation | Let the Solver Enumerate Automatically? | Force the Player to Specify on the Card/Premise? |
| :--- | :--- | :--- |
| **Count Readings** (Surveyor, Dowser, Hearthwitch, Lamplighter) | **Yes.** The solver can check all valid bitmasks automatically; player answer slots are optional narrowing hypotheses. | Optional (`?` slots remain valid). |
| **General Contradiction** (*"At least one of these 3 readings is lying or poisoned"*) | **Yes, via Two-Step Flow:**<br>1. `Support._assess` already tests $N-1$ active subsets automatically when reliability $< 1.0$.<br>2. Presenting a **Conflict Premise** (`conclusion.type == "conflict"`) proves the reports conflict and applies scrutiny/doubt without needing to name the liar. | Not required for a **Conflict** headline; required if the player wants a **Forced Alignment** headline that depends on dropping one specific report. |
| **Specific Poisoning / Impairment Excuse** | **No.** Do not let the solver invent free poisoning excuses across all nights to rescue a broken accusation. | **Yes.** The player must mark the specific report as impaired and link supporting fault evidence (or establish a conflict first so the listener's `discounted` reliability drops). |
| **Outing & Crime-Scene Trace Explanations** | **No** (do not run a town-wide multi-role route planner). | **Yes.** The player links the specific walking-role claim or secret-errand claim to the sighting (`explains_outing`), or links an evening sighting to a crime-scene trace. |
| **Mid-Game Alignment / Role Transitions** (Revenant, Scion, or future conversion roles) | **Only across small public candidate pools** (e.g., the 3–5 `yes_voters` on a Revenant execution). | **Yes for the Premise Epoch** (`before curse`, `during curse`, `after restoration`) and optional slot answer (*"Who was turned?"*). If a future role has *no* public candidate list, require the player to specify `(who, night)` and link a trigger card. |
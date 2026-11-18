# 2026-11-18, Claude-Lantern: premise centring, option B (`claude/premise-centre-b`; moves golden)

- **Base:** main `ab783c1`, with main `d2ffb20` merged in. **Status:** PR open, waiting its turn in the
  golden queue. **Next:** Bailiff (review). I re-baseline when its turn comes. That's after the
  joint-reasons fix, #216 and #232.
- **What (Michael, Nov 17-18, `docs/design/premise_centring.md`: option B, bystander share 1/3):**
  - A listener hearing "X is evil" weighs how far the case proves that. It under-registers what
    the case implies about everyone else.
  - Which cards count as "brought" reuses step 1's selection (`SharedLedger.brought_by_premise`).
    A card is brought while every owner of it is a presented case that argues someone's alignment.
  - A brought card's lean, and a stored case's cards taken together, count in full on the case's
    target and at a third on everyone else (`Connections.refresh` items, `Connections.cases`).
  - A card the listener holds any other way is never shaped: their own reading, hearsay, or the
    public record.
  - A brought card stays brought after its case fades (the lens stays).
- **New constant, decided by Michael:** `PREMISE_BYSTANDER_SHARE = 1/3` in `sim/tuning.gd`.
  `tuning_catalogue.md` is regenerated.
- **Measured** (`tools/measure_premise_frames.gd`, a constructed case on seed 692's 7-NPC deal; the
  person the cards point at starts at 41%):
  - **Presented as that person:** barely changes. Two Dowser readings 51% → 50%; sightings against
    an alibi 69% → 65%.
  - **Misframed** (presented as someone named in the cards, or someone unconnected): the right person
    gains much less. 51% → about 43%; 69% → about 50%; mixed 58% → about 46%.
  - The wrongly named person doesn't rise in any frame.
  - The presenter's trust is unchanged by a misframe (Michael: the case not landing is the cost).
- **Golden:** moves on all five seeds. Against `baseline_fdaccb0` (stale), the first changes are on
  day 1 or 2: listeners hearing a presented case shift the bystanders less. Re-measured from the
  current baseline at re-baseline time.
- **Tests:**
  - New `tools/test_premise_centring` (15 checks), added to the fast list. It covers the frames, the
    selection, the lens after fading, and that only what a brought item adds by itself is centred.
  - `test_premise_step1`'s two checks still pass with it on.
  - `test_connections_cases` checks case arithmetic on chosen numbers, so it runs with it off
    (`Connections.premise_centring = false`).
  - Fast list: 85 of 85 passed on `ab783c1`. Two captures were identical.
- **Docs:** `docs/belief_model.md`, "Premise centring, option B".
- **Codex on #246 (fixed):** the centred item values were also what the core and the stored
  cases subtracted from their joint judgements, so the suppressed two-thirds came back as a
  false interaction: on the misframed bystander, a case added back about 0.08 of log-odds on
  two Dowser readings. Now `values` keeps the raw value and only the item's own addition to
  the total is centred. A new check catches the old code (2 of 3 constructed cases failed).
  Misframed numbers after the fix: two Dowser readings 43% (was 45%), mixed 46% (was 47%).
- **Codex on #246, second finding (fixed):** a direct presentation can argue about several
  people, but the stored case kept only the first as its target, so the second was centred
  as a bystander and the order mattered. Stored cases now carry `targets` (every argued
  person; `Connections.case_targets`, with a nomination's nominee as its only target), and
  both the brought map and the case centring use the full list.
- **Re-baselined (Nov 18):**
  - Main `2430ea5` (#263) is merged in. The conflicts were only in `ci.yml` and `golden_baseline.md`.
  - Two captures on `a3fd022` were identical. They're committed as `tools/golden/baseline_a3fd022`, set in
    `ci.yml`.
  - Against `baseline_1dd16d5`, 42, 692, 900 and 98933 diverge on day 1 or 2, and 54875 is identical.
  - Executions and winners are unchanged. On 692, Bart rather than Nisha nominates Constance on day 3.
  - `test_relay_bluff` passes 4 of 4. The premise-centring, premise-step-1, connections-cases and
    connections-why suites pass 4 of 4.

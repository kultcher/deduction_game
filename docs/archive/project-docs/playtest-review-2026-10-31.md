# Review of the Oct 31 playtest report

A second look at `claude/playtest-report-2026-10-31.md`, checked against:
- the four logs (97930 and 92974 on main; 98570 and 93047 on the older build);
- the code diff from `b50dfb3` to `main` (`1c97a38`);
- a same-seed passive autoplay A/B at both commits.

## Bottom line

- **No sighting drift.** The report's biggest cross-build story, sightings and volunteered sightings vanishing, isn't a regression. The share and volunteer code is unchanged since `b50dfb3`. Both paths fire at the same rate on main in autoplay. Tonight's two games had almost no *good* witnesses.
- **1.5 has the wrong cause, and the bug is worse than reported.** The ×0.12 discount it blames is the legacy path, and that path only ran before the shared model took over on D1. The real symptom does reproduce under the shared model: a Night Watch's true sighting of the Demon on the kill night *lowers* his suspicion of her.
- **1.3 is rapport, not credibility.** It comes from a legacy Gravedigger side effect that doesn't check whether the listener believes the reading.
- **3b's "friendship still protects through the vote formula" is stale.** `trust_in_nominee` was removed in phase 1, and tonight's vote lines don't have it.
- The rest of the report (evil cover, curse, results screen, UI, dialogue) holds up where I checked it, or is plausible.

## What changed between `b50dfb3` and main

29 sim, game and workshop files changed. The behavioural changes:
- the social trust pass, phases 1–3:
  - credibility and rapport;
  - fading slights;
  - bonds removed from the starting estimate and the vote;
  - urgency;
  - gossip bond;
  - meeting trust reactions;
  - grief gate;
  - directional Confidence;
  - Warden credit;
- the Codex trace solver panel: `trace_solver.gd`, `canvas_model.gd`, quarter trace weight 0;
- workshop caches.

The rest is text only: dialogue voices (`say_voiced` with the same fallback strings) and the request layout fix.

**Untouched:** `sim/evil.gd`, the share picker in `Social._pick_item`, the volunteer gate in `MindMeeting._volunteer_night_sightings`, and all the sighting and walking code in `world.gd`.

## Sightings: setup and seat luck, not code

| | 93047 | 98570 | 97930 | 92974 |
|---|---|---|---|---|
| Days played | 5 | 5 | 5 | **2** |
| Night sightings | 15 | 17 | 4 | 1 |
| …made by good NPCs | 6 | 10 | **0** | 1 |
| Sighting shares | 42 | 57 | 0 | 0 |

**97930.**
- All four sightings were made by evil NPCs:
  - Agnes (the Demon) saw Odette and Hollis while she was out hunting;
  - Isolde and Edda saw Agnes, their own teammate.
- Evil never passes on true sightings of teammates, and the Demon doesn't advertise being out. So there was nothing to share.
- With no Poisoner, the only walkers were the Demon and the Warden.

**92974.**
- The game lasted 2 days, with only 4 conversations.
- The one good witness, Lian (Veteran, Gossip 0.14), had one chance to share, with Merrin. A sighting's weight is Gossip × 0.8 = 0.11, against an idle-chat weight of 0.3, so she shares it about 27% of the time.
- She can't volunteer it at the meeting:
  - Gossip + Confidence = 0.79, below the 1.2 bar;
  - the volunteer path also needs a public night-walking claim, and Lian hadn't claimed.

**Same-seed autoplay A/B** (passive, 10 NPCs, seeds 500–505, same setups; per-game averages):

| | `b50dfb3` | main |
|---|---|---|
| Walkers | 13.0 | 11.0 |
| Sightings (by good NPCs) | 8.8 (5.2) | 8.2 (5.7) |
| Sighting shares | 23.7 | 26.5 |
| Volunteered sightings | 3.0 | 3.8 |
| Evil invents a sighting | 1.3 | 1.2 |

So the report's "volunteered sightings may have been lost in a merge" and "check the invention gate" both come back clean. The report's balance point still stands: **walkers come from the role draw**, and a setup with no walking minion leaves vigils decisive.

## Item by item

**1.1 Evil cover voting — agree.**
- In the code, the vote override uses fixed stakes (0.28), separate from the nomination's.
- It reproduced in autoplay: Odette breaks cover to nominate (stakes 0.96), then scores her vote at 0.28.
- Pre-existing, as the report says.

**1.2 Day-phase bluffs get no fabrication** — plausible. Not independently checked.

**1.3 Fake Gravedigger reading cost the player — real, but mislabelled.**
- The −0.06 lines are `trust` events, meaning rapport (`n.trust`), not credibility.
- Source: `sim/roles/gravedigger.gd:49`, inside the legacy `info_effects`. It fires whenever the legacy hearing weight is above 0.2, whether or not the listener believes the result. Greta held 0.72 suspicion of Edda and still took the hit.
- Credibility's dawn update is logged only in the trace file, which these logs don't include. So the report's end-of-game credibility figures (0.41, 0.45) can't be checked from them.
- **Fix:** gate it on the listener's own shared-model view (do they believe the executed person was innocent?), and move it out of legacy `info_effects`. It's another item for the legacy retirement list.

**1.4 "Shared ownership toggled" — agree it's not a regression. Here's the mechanism.**
- `Game.new_case` calls `set_workshop_effects`, which recomputes every mind with that label.
- The `from→to` lines are the legacy ledger entries being retracted as the shared model takes ownership.
- The snapshots show the shared value restored. It's cosmetic logging, and it isn't the cause of Kiran's 0.00.

**1.5 Holders ignore their own Night Watch sightings — reproduced, with a different cause.**
- **The report's cause doesn't apply.** The ×0.12 line is the legacy path at night 0, before the toggle.
- **Reproduced in passive autoplay, seed 92974, same setup:**
  - Kiran watches the Square on N2 and truly sees Odette, the Demon. It's her home block, on her route to the Market kill.
  - His shared-model suspicion of her drops from **0.22 to 0.00** (trace seq 1953, "Shared original reading evidence", −0.096).
  - It stays there, and he votes no on her on D3 (score 0.00).
- **Where her number sits:** at D3 her P(evil) is 0.285, against a field average of 0.333. Several unseen people (Nisha 0.61, Constance 0.51, Lian 0.49) end up above her.
- **Not yet pinned.** I couldn't get a with-and-without probe to change the result: dropping the reading from `info_log` or the ledger didn't move the shared evaluation. Cards come in through receipts.
- **Leading suspects:**
  - the Night Watch "coverage" side (who wasn't seen) pushing mass onto others;
  - the activity factor's walk rates for good walkers.
- **This is the top item.** It's exactly the "holders act on own readings" watch item, and it fails silently.

**1.6–1.10 and sections 2, 4, 5** — not independently re-verified. Plausible, and consistent with what I saw.

**3b "friendship still protects through the vote formula" — stale.** That was the older build. `trust_in_nominee` was removed in phase 1, and tonight's vote breakdowns have no such term.

## Missed by the report

1. **The sighting "regression" is a setup and witness artifact.** See the A/B above.
2. **Kiran's own true sighting exonerates the Demon,** under the shared model, not the legacy discount.
3. **Legacy role side effects still touch rapport.** The Gravedigger penalty runs on legacy hearing weight. Other roles' `info_effects` may have similar `set_trust` calls worth sweeping.
4. **92974 is a 2-day sample.** Its feature-marker counts (3 shares, 1 sighting) shouldn't be compared one-to-one with 5-day games.
5. **Minor, worth a look:** in 97930 the Warden walked three nights and was seen by the Demon, but never saw anyone herself. Sightings aren't mutual. That may be by design (perception rolls), but it removed the one good walker-witness.

## Suggested order

1. Find why Kiran's N2 Night Watch reading lowers Odette (seed 92974, passive, D2 night).
2. Fix the evil cover vote: inherit the nomination's stakes, and allow abstain instead of acting against a teammate.
3. Gate the Gravedigger rapport effect on belief, and sweep legacy `set_trust` side effects.
4. Re-weight the role picker toward walkers, counting minions.

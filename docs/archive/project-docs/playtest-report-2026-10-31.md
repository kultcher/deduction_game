# Playtest report: Oct 31, 2026

Two Claude-driven playtests on `main` at `d5b8c23` or later, plus a review of both dev logs.

- **Case 92974:** win on day 2. The Demon (Odette) was hanged after one vigil caught her. No wrongful executions.
- **Case 97930:** win on day 5. Isolde (Revenant, curse fired and turned Odette) was hanged, then Agnes (Demon), then Edda (Scion, now the Demon). No wrongful executions. 3 of 6 innocents survived.

Both logs show `legacy_fallbacks: 0`. `present_fallbacks: 1` was the curse card.

---

## 1. Priority bugs (each confirmed in the logs)

### 1.1 Evil "keep cover" logic works against its own team
Evil compares `stakes − exposure cost` with `caution`. When that doesn't clear the bar, they do what their good-self shadow would do.

- **Nomination and vote are scored separately.** Evil breaks cover to counter-nominate (stakes about 0.84–1.31, cost often 0.00), then scores the vote at a fixed **0.28** and keeps cover, voting no on its own nomination. That's 0 yes votes every time.
  - 97930 D2: Agnes nominated Lian.
  - 97930 D4: Odette's counter on Lian, with Agnes on the block.
  - 97930 D5: Odette's counter on Lian, with Edda, the Demon, on the block. This was the final vote.
  - 92974 D2: Nisha's counter on Kiran, with Odette, the Demon, on the block.
  - **Fix idea:** after nominating, the vote inherits the nomination's stakes with near-zero extra cost. A vote that would swap the Demon off the block needs much higher stakes than 0.28.
- **Cover is a binary choice: the evil action or the good-self action. There's no abstain.**
  - 97930 D3: Isolde's shadow holds Hollis's Archivist pair ("Isolde or Edda is the Revenant"), so a good Isolde would be sure it's Edda (shadow suspicion 0.72). She nominated her teammate Edda. Then Edda's shadow nominated Isolde.
  - **The D3 Isolde vote was fully inverted.** Agnes wanted yes ("the totem is hidden; the curse will turn someone"), and cover made her vote no. Edda wanted no, and cover made her vote yes. **Edda's vote was the decisive 6th**, which swapped Isolde in for Agnes. The result happened to favor evil.
  - **Fix idea:** declining to nominate is always consistent with cover. A good-self action that targets a teammate should fall back to doing nothing.

### 1.2 Evil fabrications only run at night, so day-firing bluffs get nothing
- Every `fake_info` entry is made in the Night phase. The real Dowser reads at Day Morning (92974, seq 27).
- Agnes, bluffing Dowser in 97930, **never produced a single count** in four days. I was able to use that as a tell.
- Likely the same bug found earlier, still live. Check every day-phase gift's bluff path.

### 1.3 A fabricated reading penalized the player's track record
- 97930 D5: Kiran, Greta, and Lian each lost 0.06: "the Demonologist backed hanging Agnes, **an innocent**." Agnes was the Demon.
- The source was Edda's fake Gravedigger result ("Agnes was the Dowser"). Greta held 0.72 suspicion of Edda at the time and still accepted it.
- This probably explains the low end-of-game Credibility (Kiran 0.41, Lian 0.45).
- **Fix idea:** weight any reading used for a track-record update by the reader's own credibility of its source. Also consider making a Scion handoff produce a public sign.

### 1.4 "Shared ownership toggled" at first dawn: possible regression of an old bug
- **When:** in both logs, only at **D1 Morning**, on every night-0 reading. In 92974 it also hit a Dowser reading learned that same morning (applied at seq 28–29, toggled at 32–33). Nothing had been shared in between.
- **The log lines say** own-reading effects snap back to the 0.1 prior (for example, Isolde's Seer "no" goes from −0.35 to 0.1, and Hollis's Archivist pair from 0.45 to 0.1).
- **The end-of-phase snapshots mostly show the effect restored:**

  | NPC | Before | After toggle | End of phase |
  |---|---|---|---|
  | Isolde → Hollis, Jory (Seer "no") | −0.35 | 0.1 | 0.01 |
  | Constance → Nisha, Lian (Dowser 0) | −0.15 | 0.1 | 0.00 |
  | Hollis → Edda, Isolde (97930, Archivist pair) | 0.45 | 0.1 | 0.40 / 0.33 |
  | Kiran → Odette (night sighting) | 0.16 | 0.1 | **0.00** |

- **Possible readings:**
  - Partly a ledger re-key that logs a misleading from→to.
  - Partly real loss: Kiran ended **below** baseline on someone he saw out, and Hollis didn't fully recover.
- **Repro:** any seed, D1 Morning.
- **Not a recent regression:** the toggle appears in all four logs reviewed, including both older builds (93047: 4 lines, 98570: 10 lines). Either the earlier fix predates all of them or it never covered the first-dawn path. In 98570, Merrin's own Seer "yes" went from 0.55 to 0.16 at the toggle and stayed there.
- **Caveat on the table above:** in the older 98570 build, snapshot suspicion doesn't match vote-time suspicion at all (for example, Dorian → Bartholomew: snapshot 0.00, vote 0.70). In tonight's build they mostly agree (one mismatch over 0.15), but confirm which store the snapshot reads before trusting the "end of phase" column.

### 1.5 Holders ignore their own walker sightings
- 92974: Kiran (Night Watch) saw Odette out on N0 (a false reading while poisoned) and on **N1, a true reading on the kill night**. His suspicion of Odette at the D2 vote was **0.00**, and he **voted no**.
- The cause is the `x0.12: nowhere near a death` discount. He watched the Square while Agnes died on the Docks, but the Demon passed *through* the Square to get there.
- A walker seen on a kill night, on a block next to the death or on the route to it, shouldn't be discounted almost to zero.

### 1.6 The trace-chain deduction pulls in junk facts (slowdown on D4–5)
- The trace-chain card cited **every haunt and work-schedule fact** (negative IDs like −10038) as support. That's where "38/41/35 original reports" comes from.
- Every `argument_stance` for every NPC used the **entire serialized case** as its cache key, with nested copies. Those log entries are enormous.
- **Fix:** cite the scene traces themselves, not the haunt facts behind them, and hash the stance key.

### 1.7 Results screen and grimoire after a Scion handoff
- **"Demon identified: incorrect"** even though my final guess (Edda) was the Demon who got hanged. The check likely compares against the original Demon.
- **Both Agnes and Edda show as "Demon."** Edda should read "Scion → Demon (D4)."
- **Odette shows "bluffed Warden"** when she was a real Warden turned by the curse. Better: "Warden, turned evil D3 (Revenant curse)."

### 1.8 The Revenant curse doesn't update anyone's beliefs
- After the curse fired, Constance still had "every confidence" in Isolde.
- Edda's fake Gravedigger "Medium" result went unchallenged.
- Kiran and Greta **grieved Isolde** and resented the yes voters. The no-grief-for-known-evil rule should cover a curse reveal.
- The suspicion bump on the yes voters (+0.11 to +0.13) faded within a night or two, and nobody ended up suspecting Odette.
- `present 104` (the curse card) couldn't be connected to anyone: "the card isn't about anyone living."
- **Fix idea:** the curse produces a public, citable "the hanged person was the Revenant" fact. Claims that contradict it become lies, poisonings, or turned-soul tells.

### 1.9 Deal hold-back is chance-based
- 92974: Agnes's claim roll had `promised_player_first: −0.6` and still claimed publicly at p=0.20.
- Jory's refused deal had no hold-back term at all (p=0.50).
- 3 of 3 deal NPCs across both games claimed publicly the same day.
- **Fix idea:** a hard gate until the deal resolves. Decide separately whether a *refused* deal should still hold the claim back.

### 1.10 Smaller mechanical bugs
- **The secrecy deal charged a question penalty:** "pressed with 4 questions today" (−0.06) while the game said "No question used." Keeping the promise also gave no gratitude bump.
- **Clemency was penalized twice:** Greta took −0.10 (spared someone she suspects) *and* −0.08 (overruled her nomination) for one action.
- **Medium timing:** a reading on the same night as the first kill. Seen on Isolde's fabrication. Unclear whether good Mediums do it too.
- **The Seer re-checked the same pair** on consecutive nights (Bartholomew and Odette).
- **Challenging a reading:** the workshop refused "Isolde lied about a reading" with "no readings from this person." **Reproduced in case 77388 (earlier build):** "Constance is lying (card #111)" was refused with "A reading question needs one identified original report by its target," and all 9 NPCs fell back to legacy rules. #111 was Constance's *bluffed* Night Watch reading, stated in her own testimony. So fabricated readings aren't registered as readings by their speaker. A Medium-relayed reading is still untested.
- **Double-booked vigil prompt:** the game offered `yes` to Jory after the vigil was already promised to Agnes.
- **Approach location:** "approaches you at the smithy/bakery" names the NPC's spot, not the player's.
- **Repeated outputs:** `ask are <gift>` returned the identical deflection line and card (#17). "I saw nobody" was reprinted with the same card (#55).

---

## 2. Balance and design observations

### Vigils end games too easily
- In both games, exactly one person entered the kill block on the kill night, and it was the killer. A vigil sighting worked as a verdict.
- Agreed fix: **weight the role picker toward night walkers** (Lamplighter, Night Watch, Secret Lovers, Sleepwalker).
- **Also weight walker destinations.** 92974 N1 had three walkers, but only the Demon entered the kill block.
- Related: Odette rolled a sleepwalk bluff when confronted (p=0.62, rolled no). More ambiguity from walkers would make that bluff land.

### Quiet meetings
- Day 1–2 claim probabilities mostly fall between 0.01 and 0.32. "Gift keeps giving" (−0.4) and "hides from demon" (−0.5) suppress claims hard, and the +0.3/day ramp means most claims arrive on D3–4.
- Townsfolk night sightings exist in the logs but were **never spoken publicly**: Lian saw Hollis out on N1, plus several "went in and didn't come out" alibis.
- The D2 meetings were almost entirely "something's off about X" lines. Nobody raised the dead Clerk, the open Dowser question, or the crime scene.

### Social pressure outweighs evidence
- Each public accusation adds about +0.10–0.17 suspicion in every listener, whether the accuser cited "vibes" or "a hinted private reason."
- Lian (97930) was scapegoated with zero evidence and peaked around 0.25 with everyone. Pressure fades over a day, but the size of each bump doesn't depend on the accuser's credibility or what they cited.

### Evil framing is passive
- The evil plan's `fake_sightings` and `fake_watch` were empty in both games.
- Every frame was "vibes" or "a hinted private reason," except Isolde's single fake Medium reading.

### Evil exposure and bluff hiding (keep as intended)
- Evil bluffing a "hidden" role inherits that role's hiding modifiers. Nisha's prepared Martyr fabrication never surfaced (claim p=0.01–0.04). **Decision: keep it.** A normally-hidden role hard-claiming early to frame or vouch is a big tell.
- Defending a teammate against a case costs 0.00 exposure (Nisha and Hollis broke cover to reject the Odette case). That was readable as a tell, and that may be fine. It's worth deciding whether it's intended.

### Holders and readings
- Constance (high Insight) took her own Delusional Dowser "3 evil" at face value (about 0.6 on Isolde and Merrin) and accused Merrin. That's defensible, since she can't know she's Delusional.
- Constance's own Seer "yes" on Agnes and Greta only lifted them to about 0.25, below her hearsay-based suspicion of Isolde (0.36). Worth checking alongside 1.4.

---

## 3. Brief watch items: results

| Item | Result |
|---|---|
| Holders act on own readings | **No.** See 1.5 (Kiran) and 1.4. Constance did act on her Seer read with player prompting. |
| Dull NPCs over-follow fake readings | Not observed. The fake readings that mattered (Edda's Gravedigger) were taken at face value by everyone, regardless of Insight. |
| Credibility rewards correct early cases | Barely moved (+0.02 per accepted presentation), and the largest move was negative due to 1.3. |
| Slights fade overnight | Yes. "Time softens past slights" fired as expected (Jory 0.52 after a refusal). |
| Warden credit | Untested. Odette turned the same dusk, before her quiet night. |
| The town hangs good people | 0 wrongful executions across both games (small sample). |
| Yes votes tracking alignment | Good in both games. The swing votes were evil cover votes. |
| Identified Demon not hanged | Not observed. Clemency was needed to protect the D4 hanging from a tie. |
| Fallbacks | `legacy_fallbacks: 0` in both. |

**Player influence on votes is meaningful:** an accusation adds about +0.09–0.10 and a player yes vote about +0.07 per NPC. Kiran missed voting yes on Agnes on 97930 D3 by 0.01.

---

## 3b. Comparison with older builds (logs from Oct 30)

Two user-played logs from the night before, on builds that still had paranoia drift and a single trust number.

- **Case 93047:** evil won on day 5. Three good townsfolk hanged (Isolde, Dorian, Kiran), no evil hanged. Felt information-light.
- **Case 98570:** good won on day 5. Bartholomew (Demon) hanged on the player's third nomination of him. 4 of 7 innocents survived.
- **Case 77388 (earlier in the week, legacy fallbacks still live):** evil won on night 7. Greta (Rumormonger) wrongly hanged D5, Constance (Poisoner) hanged D6, Lian (Demon) never hanged despite four true sightings by the Warden.

### Feature markers across all four logs

| Marker | 77388 (earliest) | 93047 (old) | 98570 (old) | 97930 (tonight) | 92974 (tonight) |
|---|---|---|---|---|---|
| `night_sighting` events | 16 | 15 | 17 | 4 | 1 |
| `volunteer_sighting` events | **0** | 5 | 6 | **0** | **0** |
| `npc_share` events | 8 | 46 | 65 | 10 | 3 |
| Evil "invents a night sighting" | 2 | 3 | 1 | **0** | **0** |
| "Shared ownership toggled" | 7 | 4 | 10 | 8 | present |
| Cover override on votes | 26 | 8 | 10 | 11 | present |

The volunteered-sightings path only shows up in the Oct 30 builds: absent earlier in the week, present on Oct 30, absent again tonight. It may have been added and then lost in a later merge.

### Night walkers: the minion draw decides it
- The Poisoner walks every night. Older games had a Poisoner plus a Warden (plus a Lamplighter in 93047), so 3–4 walkers a night.
- 97930's minions were Revenant and Scion. Neither walks, so most nights had 1–2 walkers, and N3–N4 had only the Demon.
- **Role-picker weighting should count minions, not just townsfolk.** A setup with no walking minion needs more walking townsfolk (Lamplighter, Night Watch, Sleepwalker, Secret Lovers) to compensate.
- More walkers also need ways to tell them apart. In 93047 the N1 vigil caught four people with nothing to separate them, and the player later hanged an innocent Sleepwalker partly on that card. 98570's N4 Market vigil (Bartholomew and Dorian both out) worked better because Dorian had claimed Warden.

### Volunteered sightings and framing: possible regressions
- Both older logs have `volunteer_sighting` events (an NPC speaking their own night sighting to the room). Tonight's logs have none. Trace whether the path was cut or its threshold now never fires.
- Older evil invented sightings of the scapegoat ("from their window") and aimed night-bluff fabrications at them (Bartholomew's fake Night Watch added fake sightings of Dorian on top of true ones). Tonight's logs have no "invents" events. Check the gate.
- 98570 also showed good use of a deal by evil: Fenwick (Revenant) asked for a vigil, then paid off with a Clerk bluff vouching for Bartholomew.

### The cover-vote bug predates tonight
- Older logs show evil scripted votes ("Votes to hang the scapegoat," "Coin-flip vote on a good NPC") followed by a cover override that flips them. In 98570, D3 and D4: evil's scapegoat votes on Dorian were scripted yes and overridden to no (stakes 0.28). Same bug, older build.
- `team_survival` ("votes no on the demon") works in every build.

### Holders and friendships protected the Demon (98570)
- Merrin (Seer) got "one of Jory and Bartholomew reads as the Demon" on N1. Her vote-time suspicion of Bartholomew was **0.06** on D2 and **0.03** on D3. She's his friend, her later Seer picks were "a scattered look: two at random," and she refused the player's request to check him ("I'd sooner look at Odette").
- Dorian saw Bartholomew on Chapel Hill on the night Constance died there. His suspicion was 0.14 on D2 and 0.04 on D3.
- `trust_in_nominee` from friendships (−0.13 to −0.17) offset almost all of the evidence. The brief says bonds no longer *seed* suspicion, but friendship still *protects* through the vote formula.
- On D2–D3, good NPCs gave the Bartholomew case stance `accept` but `scoped_stance: reject`, and voted no (2 votes, then 1). It took four independent sightings plus the warded-door reveal before D5 got 4 votes.

### Case 77388: too much ambiguity, no way to resolve it
- 3–4 walkers every night (Demon, Poisoner, Warden, and a Sleepwalker for three nights). The player's vigils caught 2–3 people each time, so the vigil never decided anything.
- Jory (Warden) saw Lian (Demon) out on nights 1, 2, 3, and 5. He shared it once, privately, with Kiran. Nobody volunteered sightings in this build.
- Evil framed Jory *with true sightings*: Constance's fake Night Watch reports and Lian's fake Seer "yes" both named the Warden, who really was out every night. Strong evil play, and it buried the one witness with the truth.
- Lian's friends (Kiran, Edda, Odette, Hollis) held suspicion of her at 0.05–0.12 to the end, with `trust_in_nominee` around −0.13 to −0.17. Only Jory voted for her.
- Most responses to the player's cases were the shared-model failure line ("I could not follow your explanation through…"), and the rebuttal to "Constance is a minion" argued she wasn't *that night's killer*, which a minion claim never said.
- Cover inversions decided the end: on D6 Fenwick's cover *nominated his own teammate Constance* and supplied a yes vote, and all three evil flipped their "replace our teammate on the block" votes to no. Constance hanged. Earlier, Lian's correct "hang the Revenant, the totem is hidden" yes was flipped to no.
- The Poisoner hit Jory (Warden) four nights straight (N2–N5). Same fixation as Edda on Dorian in 98570.

### Other older-build notes
- **Poisoner fixation:** Edda poisoned Dorian (Warden) three nights running, and Dorian guarded Edda (a "trusted info claimant") twice. Warden hit rate 0.
- **Paranoia drift** reached 0.18 by D5. Removing it was the right call.
- **Clemency** read as positive in 98570 ("spared Dorian, whom I trust"), unlike the double penalty in tonight's build.
- **Claim probabilities:** 93047 had Dorian claim at p=0.02 and Jory at p=0.08 on the same D1. Worth confirming the logged `p` is the one used for the roll.
- **Stance key growth** is visible in 98570 too: the key grew from 2,227 to 5,520 characters across the Bartholomew cases.

### Synthesis

| | Older builds | Tonight |
|---|---|---|
| Walkers per night | 3–4 | 1–2 |
| Sightings spoken | Many, volunteered | Almost none |
| Evil framing | Invented sightings, aimed fabrications | Vibes only |
| Info reliability | Heavily poisoned | Mostly clean |
| Town vs evidence | Followed frames; friends shielded the Demon | Followed vibes; vigils carried the game |
| Feel | Information-light, chaotic | Quick, nearly solved by one vigil |

The target is in between: tonight's cleaner reasoning model, plus the older builds' walkers, volunteered sightings, and active framing, with limits on how much one Poisoner can blank out.

---

## 4. UI and UX

- **Block-based travel:** zoom on the first click, then a "Travel to this block" button. Choosing a specific spot is mostly meaningless.
- **"Strong" badge:** it sits on a premise right above an evidence card saying "Circumstantial; does not prove evil." Separate the claim's strength from the strength of its support.
- **"Challenged" badge:** overlaps the card text, with a red strike line across it.
- **Processing:** `present` and `accuse` were slow on D4–5. See 1.6.
- **Trace solver:** good. The 3/3 dots and the color-or-grayscale portraits read instantly, and the "Scion handoff?" divider is excellent.
- **Relationship walls:** five relationship lines in one answer (Kiran on Lian). Cap at about two, prioritizing relevance.
- **Constance's reading history:** she repeats every reading on each `ask gift`. Lead with the new reading and summarize the rest.
- **Non-murder search traces:** the old-model trace at a non-murder search ("river mud at the smithy") shouldn't appear under the new model. But the specific old-style traces were the most useful clue of the game, so consider keeping them for non-murder scenes.

---

## 5. Dialogue

- **Jargon voice:** "unknown variable," "baseline," "audit my threshold," "test the leading hypothesis," "place the relevant variable on the public record." It spans Nisha *and* Hollis. Possibly a trait-combination voice firing too often. Needs a period pass.
- **Verbal tics need per-conversation caps:** Isolde's "truly" (3 of 4 lines) and Odette's "miraculously" (3 times).
- **Mixed persuasion lines:** an agreeing opener stacked on a refusing closer. Examples: Kiran ("more convincing… doesn't change my mind"), Agnes ("that gives us something more to work with. I don't buy it"), and Edda ("I've come round… wouldn't hang a kettle on testimony that shaky").
- **Wrong response template:** Greta answered the Seer-reading card with the "your sighting is disputed" reply ("You think my eyes are going?").
- **Game terms in dialogue:** "on night 1."
- **"The movement and trace evidence"** is cited even when the case had no trace.
- **Present tense for the dead:** "Bartholomew and Lian *are*…"
- **Repeated idioms and templates:** "thick as thieves" twice in a row; identical haunt-line templates back to back.
- **"You have conducted this inquiry properly"** on D1 morning, before the player has done anything.
- **"Fairly firm in their views"** for a Confidence of mid.
- **Good lines worth keeping:** Odette's "this circus," Isolde's "Surely it is gentler—and likelier…," and Constance's "allow for my partiality."

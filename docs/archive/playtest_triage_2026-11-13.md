# Playtest triage: Nov 13

*Archived Nov 16 from the Project doc `claude/playtest-triage-2026-11-13.md`. Everything decided here is built (#149–#162); what's left is in BACKLOG.md, section 5. Kept as the record of the decisions, with the small calls made on Michael's behalf.*

Bailiff, for Michael · every open issue from three playtests, sorted for delegation

**Sources:**
- **44542:** today's first switch-on game.
- **97626:** today's second.
- **Earlier:** Michael's list from an earlier playtest; seed not recorded. Lian, Edda and others appear in it.

The belief-model doc ("Playtest 44542") and the backlog ("Playtest 44542" and "Playtest 97626" follow-ups) hold the measurements. This doc is the one sorted list, with a suggested owner for each item.

**Tags:**
- **[fix]:** clear and ready to build.
- **[decide]:** needs Michael's call first.
- **[design]:** needs a short design pass.
- **[check]:** reproduce or confirm before building.

**Golden:** "moves golden" means it changes passive play, so the PR re-baselines. Player-only and switch-on-only changes don't.

## 1. Quick fixes (one batched PR; Bailiff or Steward)

| # | Item | Source | Notes |
|---|---|---|---|
| 1.1 | A Lover passes on their partner's secret, which is also their own | 97626 (Agnes) | Leave a shared Lovers secret out of what they pass on, or say it as their own confession. Moves golden if a golden seed has Lovers **Done in #149.** |
| 1.2 | "Your whole case rests on X's reading" names a reading the case doesn't cite | 97626 (Jory, Kiran) | `MindMeeting.defend_self` picks the hinge from everything disclosed. Pick it from the case's cards. Player cases only **Done in #149.** |
| 1.3 | Role hints list roles not on the script (the Hearthwitch) | 97626 | Filter `C.HINT_PACKAGES` roles by the case's script **Done in #149.** |
| 1.4 | The burned totem says the spirit will seek a new place even after the Revenant is dead | Earlier | Check whether the Revenant is alive before that line **Done in #149.** |
| 1.5 | The Grim Reveal should show who the Revenant made evil | Earlier | End screen only **Done in #149.** |
| 1.6 | Premise time options: Demon "before/after" should only mean the Scion transfer, and alignment "before/after" only the Revenant curse | Earlier | Offer each only where the script makes it possible **Alignment part done in #149:** the curse "When" field shows only on is evil / suspicious / good. The Demon before/after for the Scion doesn't exist yet; that's new work (backlog). |
| 1.7 | Being seen talking should still give location cards, besides the "…" icon | Earlier | Player-only. Fits the existing backlog item on conversation sightings **Done in #152** (Michael, Nov 13): seeing a talk gives three cards, each talker's own sighting and the talk. |
| 1.8 | An NPC's approach text bleeds into their previous dialogue; the same NPC approaches right after a talk | 97626 | Add a cooldown: no approach by someone you just talked with that phase **Done in #149.** |

## 2. NPC wording and reasons (Steward)

The reason lines need to say *why*, not just "contradicts". Proposed wording for Michael to adjust:

| Case | Today | Proposed |
|---|---|---|
| A reading that really clashes with the target's claim | "My own reading contradicts their account." | "My Clerk reading says one of Nisha and Agnes is the Surveyor. That can't be true if Jory is the Night Watch he claims." (Name the reading and the claim it clashes with.) |
| A reading that only raises them indirectly | "My own reading contradicts their account." | "My reading clears Agnes and Nisha, which leaves Jory among the likeliest of the rest." |
| The listener's self-knowledge | "My own reading contradicts their account." | "I know I'm good, so Fenwick's 'one of me and Jory' points at Jory." |
| A Warden's protection | "My reading was about Fenwick, and that doesn't square with their account." | "I guarded Fenwick that night, and Kiran's account of that night doesn't fit it." |
| A block reading about someone off the block | "Agnes's reading says everyone on the Docks is on the same side, and taken with the other reports that points at them." | "With the Docks all on one side, most likely all good, the evil has to be somewhere else, and Merrin is one of the few left." |
| A many-reason recap | "Recapping the established premises: …" | Drop the opener; give the strongest reason, then "and" one more |

| # | Item | Source | Notes |
|---|---|---|---|
| 2.1 | The reason lines above | 44542, 97626 | `ReasonAttribution` uses "contradicts" whenever the target has any claim and the reading moves them. Moves golden only if golden logs dialogue text; they do, so re-baseline **Done in #149**, close to the proposed wording; the recap kept a short opener (Nisha: "On the record:"). |
| 2.2 | "Your whole case rests on Fenwick's reading. Then Fenwick is lying" (a "Then" that follows nothing) | 44542 | Defence line order **Done in #149.** |
| 2.3 | Hollis: "Because those premises conflict, I am weighing which testimony warrants doubt" (which premises?) | 44542 | Name them, or drop the line **Done in #149.** |
| 2.4 | Nisha opening a reading with "You are missing a premise:" | 44542, 97626 | Wrong register for volunteering a reading **Done in #149.** |
| 2.5 | Every reply to "Fenwick is good" was about "extra guesses" or "unproved slot choices", even from listeners it moved | 44542 | The reply reacts to the case's answers; it should follow the belief change **Done in #159:** the "extra guesses" reply only when the case didn't move the listener. |
| 2.6 | Agnes said "I'm convinced" while her suspicion fell slightly | 44542 | Spoken stance from today's reply code; with the switch on it should read the connections result **Done in #159:** a "nothing new" reply keeps agreement only if belief didn't slip. |
| 2.7 | Lian: "Your case rests on a sighting, so let me tell you in my own words", then stonewalled | Earlier | **[check]** Probably her privacy, or the hiding-a-gift path. A stonewall after that opener reads as a bug **Struck (Michael, Nov 16):** the line isn't in the code as worded, so it may have changed already; revisit if it turns up again. |
| 2.8 | The VN presentation for an NPC approaching you feels disjointed from the usual flow | Earlier | **Decided (Michael, Nov 16):** an interstitial bubble with no portrait covers the phase change ("You part ways with X as the afternoon sun reaches its zenith. As you cross past the mill, Y waves you down."; no parting in the morning), holds on Continue, then the full VN approach and choices **Done in #162.** |

## 3. NPC behaviour (Steward; measured ones with Tally)

| # | Item | Source | Notes |
|---|---|---|---|
| 3.1 | A good NPC hiding a night-walking gift should usually decline to say rather than lie | 44542 (Jory) | **Decided:** keep lying as an option so declining isn't a tell for good; declining reads as only slightly less suspicious than lying. Odds and weights open. Moves golden **Done in #160:** decline bias -0.4 (a lie about 17% at neutral traits); refusal weight unchanged. |
| 3.2 | Promise for information, then going public anyway | 97626 (Odette), Earlier (Edda) | Odette asked for a vigil "and I'll tell you the rest", then claimed at that evening's meeting. Edda gave her role, then asked for a vigil for it. Hold back what was promised until it's paid, and don't offer to trade what's already given. Moves golden **Done in #160:** no public claim on a day they offered you a deal (protect-lock exceptions apply); no protection request once you know their gift. |
| 3.3 | NPCs already public with their role won't share last night's readings with the player | Earlier | **Tuning:** withhold only under major distrust. Moves golden **Done in #160:** public with their gift → readings too, unless trust < 0.3. |
| 3.4 | The Demon should prefer a random target over a spent role who has publicly disclosed their information | Earlier | Fits the backlog's "Kill-score pass on every role". Moves golden; sweep it **Done in #160:** a public first-night gift whose knowledge is out scores like anyone (no sweep, per Michael). |
| 3.5 | Haunts: share only one at a time now that they're guaranteed | Earlier | Moves golden **Done in #160.** |
| 3.6 | A bluffing Dowser covers its allies at all costs | 97626 (Kiran) | See section 6. Moves golden **Done in #160** (section 6 guidelines). |
| 3.7 | The Breathstealer silenced on 2 of 4 days | 44542 | **Decided (Michael, Nov 13): aim for about 90% of days.** It should know its own schedule: if it works evenings, push harder in the morning and afternoon ("take its shot" in case nobody shares its block that evening). Give it the Hexer's hunting: in a free phase, go where the highest-priority info role is working, and on an evening it hasn't silenced, go out to a public place with good regulars (`Daykiller.free_location`, `preferred_target`). Measure the rate on passive seeds. Moves golden **Done in #157** (main `548413f`): it hunts and silences on about 92% of unsuppressed days (main was ~63%); the presence reasoning and the location panel assume it hunts. Tally sweeping overnight. |
| 3.8 | A Medium bluffer saying they were out "because I'm the Medium" on the first kill night | Earlier | **[check]** Bluffer or the real Medium? Related to #134 (framed defenders' night account) **Fixed in #160:** a real Medium out for another reason could claim the duty on a night with no hearth to visit (not confirmed against the playtest log); now only with a reading that night. |

## 4. The connections model (Lantern)

| # | Item | Source | Notes |
|---|---|---|---|
| 4.1 | Caching (step 6) | 44542, 97626 | **Next.** Presenting took 4–7 s on day 1 and 15–35 s by day 3–4. #148's profile: a per-listener cache skips most of nominating and pressing; first-time sets (gossip) need a cheaper judgement too **Done in #153** (#150, #151 merged with it). |
| 4.2 | Cases that reuse the same cards stack | 44542 | **Decided (Michael, Nov 13): replace when the new case contains every card of an older case of yours; otherwise the new case adds nothing for the cards already in a stored case of yours.** Three live cases carried the Fenwick-Surveyor combination. Options: add nothing for cards already in your stored case; the newer replaces the older; both count **Done in #153** (#150, #151 merged with it). |
| 4.3 | A sound conclusion fades overnight | 44542 | **Decided direction:** a slower fade, or one scaled by how much the listener bought it, if that isn't hard **Done in #153** (#150, #151 merged with it). |
| 4.4 | Under Walker, a case of night cards counts their meeting twice | step 4 | **Decided (Michael, Nov 13): add nothing** for cards the movement connection already holds **Done in #153** (#150, #151 merged with it). |
| 4.5 | An NPC defender's challenge isn't stored as a case | step 4 | **Deferred (Michael, Nov 13).** Promising, but after the connections build. Separately, NPC defences should cite exonerating evidence the way accusers cite incriminating evidence; that may be a dialogue-level change |
| 4.6 | The day connection leans away from the true Hexer | step 2 | **Traced (Bailiff, Nov 16): not reproduced on current main.** 8 passive Hexer games (75 listener-kills): the Hexer's day evidence averages +0.02 log-odds on the true Hexer, so it's weak rather than biased. Split: +0.09 when the hexed place is one the listener knows as the victim's, −0.06 when it isn't (an unlearned haunt; the flat floor gives the Hexer no credit for being there). A per-person floor didn't help (0.00). The real limit: in passive games nobody sees the Hexer at the hexed place (its share there 0.23 against 0.19 for others). No change made; player day logs are what would strengthen it. |

## 5. The Workshop and the Test juror (Quill, or Lantern for the connections parts)

| # | Item | Source | Notes |
|---|---|---|---|
| 5.1 | The canvas reverses a premise → card link without saying so | 44542 | **Decided (Michael, Nov 13): the cheap version.** Premise → card means "this card's line runs through that premise": both go into the root's evidence, labelled "given <premise>". The full version (the juror reporting the condition separately) goes on the backlog **Done in #159** (the cheap version): a "given <premise>" link. |
| 5.2 | The strength badge under connections | 44542 | **Decided (Michael, Nov 13): keep the badge; one Workshop warning, "No new info"** (reasons 2, 4 and 7: it rests on cards the town already counts, or repeats an argument you've already made, or its target is already settled). Reason 1 needs no note. Reasons 3, 6, 8 and 10 belong in the NPCs' replies. Reason 5 ("suspicious" halves the weight) is shown on the card itself. Reason 9 may already be the premises hint ("this evidence may say more about someone else"); check before adding anything. **Rulings (Michael, Nov 14):** reason (a) counts only public cards, so a case bringing an unheard card never warns; same-day repeat warns, a later-day repeat shows "Refreshes your day-1 argument"; a "suspicious" case on firmly argued cards says "Adds no new belief, but still presses them"; computed without the player's watch record; hidden with the switch off. Lantern, in progress **Done in #154** (merged); notes follow the stored-case arithmetic (with against without the draft). #155 (merged): "suspicious" pressure by what the cards point at. |
| 5.3 | Presented cards are heard at the case's agreement | 44542 | **Decided (Michael, Nov 13): keep it.** It's part of the premises-matter work: the same facts argued as a weaker case land weaker, which gives the player steering power, for good or ill |
| 5.4 | The Test juror ignores answers and challenges | 44542 | It can't show what a challenge would do. Answers stay theory, not evidence; challenges should apply **Done in #159** (the cheap version): the juror judges as if challenges hold, challenged readings set aside, and says so. |
| 5.5 | A teller's claim should be linked automatically | 44542, 97626 | Nisha's Registrar reading alone was ×1.3 because the juror didn't know Kiran claimed Dowser **Done in #159:** the juror weighs the public claims of everyone the case names. |
| 5.6 | An either/or premise for nominations | 44542 | **Decided (Michael, Nov 13): no either/or premise.** Communicate instead: "suspicious" is your tool to put pressure on someone without necessarily getting them hanged, but you pick a direction and drive it yourself. "One of these two" isn't a case the town sorts out for you. Wording in the Workshop and the premise picker (Quill / UI) **Done in #159:** premise picker tooltips. |
| 5.7 | The juror's verdict drops at a silencing | 44542 | **Checked (Bailiff, Nov 13).** Once anyone is silenced, every judgement carries the Breathstealer-by-presence factor. The big drop is the player's view: the juror reads the player's watch record, which placed nearly everyone, and Fenwick was the one person with both victims in high-odds phases (with Jory morning and evening, on the Square with Isolde in the evening; Edda's afternoon silencing fell in a gap). Fenwick's baseline evil chance 0.33 → 0.71 in that view. NPCs don't get the watch record: their baseline moves 0.33 → 0.44 (Edda 0.38). Model-consistent for today's non-hunting Breathstealer, but too sure of blanks in the record and of the evening odds. **Decided (Michael, Nov 13):** bundle with 3.7 (hunting, ~90% of days) and rework the presence reasoning to match, with Tally measuring (Bailiff) **Done in #157** (main `548413f`): it hunts and silences on about 92% of unsuppressed days (main was ~63%); the presence reasoning and the location panel assume it hunts. Tally sweeping overnight. |
| 5.8 | Presenting a card to one NPC got Lian to disclose her role (a card about her being a secret Lover) | Earlier | **[design]** Michael: to an individual, present either a case, or a card with a defined interaction. Ties into secret awareness |
| 5.9 | No way to prove the other half of Secret Lovers | Earlier | **Done in #162:** a confession now names the partner (it is never faked), and the solver and the juror keep only worlds where both hold the Lovers secret. "Partner has the Lovers secret" with the confession linked reads strong; anyone else reads ×0. |
| 5.10 | Augur evidence: don't name people, but put who the player saw into the hint text | Earlier | **Done in #162** (Michael's wording): the reading's card adds "(Sightings: A, B +at least N unknowns)": who your sightings put on the Augur's block in the phase you placed it, and the unseen counts there. |

## 6. Bluffing gifts (Steward, with Tally measuring)

**How a bluffing Dowser works today** (`sim/roles/dowser.gd`):
- **An evil person is in the group:** it always says 0. Allies are covered at any cost, which is what gave Kiran away: a clean result for five people is itself unlikely.
- **No evil person is in the group:**
  - with the scapegoat present, it says 1 (sometimes 2 in a group of 4 or more);
  - without the scapegoat, in a group of 4 or more it sometimes says 1;
  - otherwise it says 0.

**Michael's guidelines** (broad, not exact): keep the count within about 1 of the truth, with the size of the group setting the room.

| Group | Guideline |
|---|---|
| 2 | 0 or 1, by need: cover an ally under suspicion, or frame the scapegoat |
| 3 | A true 2 should read at least 1 |
| 4+ | Usually the true count + 1, or + 2 when the truth is 0 |

So an ally in the group no longer forces a 0, and large groups lean toward a padded count rather than a clean one.

**Frame memory:** the scapegoat is one team-wide choice (`evil_plan.scapegoat`). Each morning it is reconsidered with a bonus for keeping it, so it is sticky but can switch. A bluffing Dowser keeps no memory of whom its own earlier counts implicated, so later readings can drift away from the frame. Proposal: a bluffer's later readings stay consistent with the people its earlier ones implicated, unless the team has switched scapegoat and the old reading no longer matters.

Other bluffers, for comparison:
- **The Surveyor** frames the scapegoat's block (60%), clears a teammate's block (half the rest), or picks a random block and answer.
- **The Seer** never gives a "no" that covers the scapegoat.

Worth one pass over all bluffers for the same "too clean when an ally is involved" tell.

## 7. Rules questions for Michael

| # | Question | Source |
|---|---|---|
| 7.1 | **Done in #160.** **Decided (Michael, Nov 13): the Warden doesn't act on night 0.** A night-0 outing then counts against a Warden claim. Check every place that assumes a night-0 guard: the movement model, the Warden's own reports, evil's Warden bluff, the Workshop. Moves golden | 97626 |
| 7.2 | The Breathstealer's reliability: decided (3.7) | 44542 |

## 8. UI (UI agent)

| # | Item | Source | Notes |
|---|---|---|---|
| 8.1 | Case Workshop canvas: left-click drag for a selection box, right-click drag to pan | Earlier | **Done in #162** (middle-drag still pans; right-click on a card still opens its menu). |
| 8.2 | Mark "+N people at location" on sightings on the case board | Earlier | **Done in #162:** a sighting from afar adds "(+N people there)" when you couldn't make everyone out. |
| 8.3 | The VN approach flow (2.8) | Earlier | **Done in #162** (see 2.8). |

## Closed today

- **Tavern gossip fills haunts and relationships.** It does: every gossip line in both games was recorded on the profile. If one looked empty, it's the display.
- **Why Kiran's Dowser reading was "strong" alone.** Explained in the belief-model doc: a five-person zero is unlikely to be honest.
- **The Why report under connections.** Merged in #148.
- **Quick fixes 1.1–1.6 and 1.8, wording 2.1–2.4.** Merged in #149 (golden re-baselined to `baseline_4a1a075`).
- **1.7, seen talking gives each talker a sighting.** Merged in #152 (`baseline_b281427`).
- **4.1–4.4, Lantern's caching, case rules and buy-in fade.** Merged in #153 with Bailiff's fixes for Codex's four findings; switch-off golden unchanged.
- **3.7 / 5.7, the Breathstealer hunts.** Merged in #157 (golden unchanged: no golden seed deals one); Codex's three findings fixed with tests.
- **7.1, the Warden on night 0:** in #160 (Nov 16), with the movement model's night-0 gift outing removed.

## Nov 16 (Bailiff): the connections model by default

Michael, Nov 16: commit to connections, new baseline for live testing, and knock out every decided item.
- **#154 merged:** "No new info", with Codex's eleven findings fixed. The note now follows the stored-case arithmetic.
- **#155 merged:** "suspicious" pressure, Lantern's PR.
- **#159 merged** (player side): 2.5, 2.6, 5.1, 5.4, 5.5, 5.6.
- **#160 merged** (main `b99a2fe`, golden `baseline_a713ca5`): 3.1–3.6, 3.8, 6, 7.1, plus `Tuning.Workshop.CONNECTIONS = true`. The earlier model stays available as `--legacy-model`.
  - Seed fixtures are now found by search (`tools/fixture_seeds.gd`).
  - Tests that check the earlier model's mechanics are pinned to it.
- **Still open:** 2.7, 2.8, 4.5 (deferred), 4.6, 5.8–5.10, section 6's frame memory and bluffer pass, section 8.

## Nov 16, second pass (Bailiff): #162 merged

Main `7d87772`, golden `baseline_bb6f01c`. 2.8/8.3 (the approach VN), 5.9, 5.10, 8.1 and 8.2 are in; 4.6 is traced (no change); 2.7 is struck.
- **Golden:** text only on four seeds. Seed 900's Lovers (Greta and Jory) are no longer both hanged: Constance is hanged day 2 and play reaches day 4 (was: evil wins day 3).
- **Small calls made on Michael's behalf:**
  - with nobody to part from in the afternoon or evening, the interstitial opens with the time of day ("The afternoon sun reaches its zenith."); evening reads "the light begins to fail";
  - a promised approach reads "Y finds you at the mill, as they promised.";
  - the Augur hint says "Sightings: nobody" when you placed the Augur but saw no one else there, and gives the larger phase's unseen count when you placed it in both phases.
- **Still open:** 4.5 (deferred), 5.8, section 6's frame memory and bluffer pass.

## Delegation (Michael, Nov 13)

For now only Bailiff and Lantern build, with Tally running sweeps as needed. Bailiff: section 1 and the straightforward wording in section 2. Lantern: section 4 (caching, 4.2–4.4) and the 5.2 warning. The rest waits. The table below was the first suggestion.


| Agent | Work |
|---|---|
| Bailiff | Section 1 as one PR; 5.7 |
| Steward | Sections 2, 3 and 6 (3.4 and 6 with Tally sweeps) |
| Lantern | 4.1 caching now; 4.2–4.5 once Michael decides |
| Quill | Section 5 once Michael decides 5.1–5.3 and 5.6 |
| UI agent | Section 8 |
| Michael | Everything above is decided or deferred (Nov 13) |
| Bailiff or Steward | 7.1 (the Warden on night 0) |

## Clarifications (Bailiff, Nov 13)

### 4.2: discount the repeated cards, or let the newer case replace the older?

Both stop the stacking. They differ in what happens to the older case's weight.

| | Discount (a case adds nothing for cards already in your stored case) | Replace (the newer case takes over the older) |
|---|---|---|
| Same cards, new premise (#40 after #39) | Adds nothing. #39 keeps its weight and fades on its own schedule | #40 replaces #39 at full weight. Re-presenting refreshes the old argument |
| A bigger case containing the old one (#89 = #39's cards + the Archivist reading) | Adds only what the new card brings. The Fenwick combination stays at #39's faded weight (0.25 on day 2) | #89 carries the whole set at today's weight (about 0.5–0.7). The Fenwick part is back to full |
| A case that shares only some cards | Natural: the shared part isn't counted again; the rest counts | Awkward: replacing would drop the old case's own cards, so it needs a fallback rule |
| Your credibility rose since | The old combination stays at the old trust | Today's trust applies |

**Recommendation:** replace when the new case contains every card of an older case of yours, and discount otherwise. That matches the existing rule that presenting a case again restores its weight, and it answers the fade problem in 4.3. A day-1 argument folded into a day-2 case comes back at full weight.

### 4.5: what storing an NPC's defence as a case would change, by direction

Today, with the switch on, a defender's challenge ("Fenwick is lying" against the reading that accuses the nominee) only keeps today's small floor under the challenged teller. Since challenges act only inside a stored case, it discounts nothing, so NPC defences have almost no effect on belief. Stored as a case (the defender's cited cards and challenge, weighted by the listener's trust in the defender, fading):

| Direction | Effect |
|---|---|
| On the nominee | Down, for listeners who trust the defender. Defences start to work |
| On the accusing reading's teller | Up a little more, through the challenge inside the case (as a player's challenge does) |
| Good defending framed good | Fewer wrongful hangs |
| Evil defending a teammate | A trusted evil defender can blunt a true reading; more evil escapes |
| The player's case against a defended nominee | The two cases partly cancel; the more trusted presenter wins |
| Symmetry | NPC nominations are already stored cases; this makes the meeting symmetric |
| Cost | More stored cases per listener, so more judgements per refresh (step 6 matters) |

The net effect on win rate is unknown in either direction, so it needs a Tally cell, defences stored against not stored, before deciding.

### 5.1: what treating premise → card as a condition would involve

- **For the NPCs (connections) it makes no difference.** An NPC weighs a case's cards together; "given Fenwick is good" has no separate meaning unless Fenwick's cards are weighed too. A conditional link compiles to the same set as linking the premise and the card to the root, which is what scored ×2.7.
- **The cheap version:** read premise → card as "this card's line runs through that premise". Fenwick's cards and the Archivist reading go into the root's evidence together, and the canvas labels the line "given Fenwick is good". This is mostly the link-direction fix plus a label.
- **The full version: the juror reports the condition separately** ("if Fenwick is good, this is strong; Fenwick is good is moderate"). That needs new juror machinery. Assumed positions don't condition the juror's ratio today: "assume Fenwick good" left "Odette is evil" at ×2.7.
- **Edge cases either way:**
  - a card that supports the premise and is also conditioned on it (a cycle);
  - contradiction links;
  - a premise of another type used as a condition ("not the Demon", a role);
  - NPC replies still complaining about "unproved slot choices" (2.5).
- **Recommendation:** the cheap version now, and the two-number readout later if the canvas needs it.

### 5.2: why a strong case can move the town little

The reasons, roughly in order of how often they'd show up, with the warning each could give:

1. **They already hold these cards, and already put them together:** their own core combines them, or the movement connection does (Edda on "Fenwick is good"). "Most of the town already weighs these together."
2. **The strength is one card everyone already counts alone,** with little left to combine (Kiran's Dowser reading). "This rests on one card the town already has."
3. **Your credibility is low,** or a particular listener distrusts you; the case is weighed at trust × fade. "The town isn't sure of you yet."
4. **You've already made this argument:** an earlier case of yours holds the same cards (once 4.2 is in). "You made this point on day 1; it still counts at half weight."
5. **"Suspicious" halves the weight.** That's by design; say so.
6. **It clashes with what a listener knows firsthand;** their own readings outweigh the case. "Hollis's own gift says otherwise." Needs care: it mustn't reveal private readings.
7. **The target is already settled:** proved by a listener's own knowledge or by the public record.
8. **The cards are disbelieved:** known false to someone, or heard faintly (a relay, the Muddler).
9. **The cards point at someone else more than at the target** (the Fenwick combination under "Odette is evil"). "These cards say more about Fenwick than about Odette."
10. **No room left:** others are already near certain to be evil, so raising one more is limited by the evil count.

Reasons 1, 2, 4, 5 and 9 can be computed from public cards and your own case history, so they're safe to show. Reasons 3, 6, 7 and 8 depend on individual listeners and should stay general ("some of the town").

### 5.3: what hearing presented cards at the case's agreement does

Today a presentation brings each new card to a listener at the case's agreement (how far that listener finds it supports its premise). And most of what a presentation does is bring cards (step 4: the target's mean chance 0.54 → 0.68 from cards brought, → 0.70 from the joint weighing).

| | Keep (cards heard at agreement) | Drop (cards heard at their usual presented weight) |
|---|---|---|
| Premise choice | Changes how much the new cards count: "Odette is evil" (0.21) brought the same cards more weakly than "Fenwick is good" | Changes only what's asked, the replies, the nomination and credibility. Matches the design ("the premise changes what's asked, not how cards are weighed") |
| A sound argument | Rewarded: its cards land harder | Rewarded through credibility (wrong premises cost a little), not through hearing |
| A wrong or weak premise | Its cards barely spread | Its cards spread fully, so a premise can carry news to the town even when it's wrong |
| "Suspicious" as a pressure tool | The lower bar also lets its cards land | Its cards land the same; "suspicious" differs only in weight and in how far it pushes a vote |
| What a hearing weight is for | Mixes two things | Stays about whether the card was said that way (relays, the Muddler), which agreement has nothing to do with |
| Golden | Player-only, so it doesn't move | The same |

**Recommendation:** drop it, as you're leaning. Keep the premise's say in the replies and in credibility, so a case that doesn't support its premise still costs you a little with the town.

# 2026-11-16 night, Claude-Herald: "ask night" can tell the night's result (`claude/herald-ask-night-gate`)

- **Base:** main `97f51a1`. **Status:** PR open. **Next actor:** Bailiff to merge; Beadle to note the shared gate (below).
- **Why:** Michael, via Seneschal, after #171: asking a claimed night walker about their night should be able to give the gift's result, under the usual gating (trust, Privacy, a hidden gift), not only after "ask gift" has been asked. #171 had made "ask gift" a strict gate on what "ask night" could reveal.

### The gating now

- **"ask night" only speaks of a result once the gift is claimed.** The night's errand (and so its result) comes up only when they've named the gift to the player, or publicly. An unnamed gift still says where they were, or stonewalls, as before.
- **A result not yet told is told when they'd tell their readings to "ask gift" today.** It's one shared rule, `MindDialogue.disclosure_gate`, which `ask gift` now uses too. Their openness comes from Privacy, trust, pressure and the day, plus a fixed daily mood, so asking twice the same day gives the same answer. A public claim has a floor. Once trust has fallen below what they told before, no new readings. The rule has no game random roll.
- **When it opens:** every reading they haven't told comes with it, card and all, as "ask gift" would give them. The night asked about is spoken; earlier untold ones are spoken too.
- **When it's shut:** "What my gift showed me that night, I'll keep to myself for now."
- **Unchanged from #171:** a result already told is said again; a night that showed nothing is said plainly; an evil bluffer with no story ready holds it back.
- **The Night Watch:** its result is the night's sightings. When the gate opens, its reading is told in words ("I watched the Docks: nobody stirred") and on the board, and the sightings aren't then rolled for or told again (Codex's #178 finding: left to the sightings path, a quiet watch said nothing and a refusal roll could withhold a result already carded). When shut, it keeps its own "who I saw, I'm not ready to share" line.
- **Fear:** "ask gift"'s fear and protection-request lines are not used by "ask night". Like "ask gift" at the top tier, fear doesn't stop readings being told; it only changes how a refusal is worded.

### For Beadle (disclosure is your code)

- I moved `ask gift`'s gate into `MindDialogue.disclosure_gate` without changing it, and "ask night" calls it. A change to when NPCs share readings now changes both questions at once, which is the point. Say so if you'd rather own a separate rule for "ask night".

### Measured

- `tools/test_ask_night_results.gd` now has 60 checks (shut gate, open gate, the Night Watch both ways, a quiet watch spoken).
- Golden identical to `baseline_bb6f01c` at `--tol 0` (passive player: it never asks).
- 72/72 suites passed locally: the CI fast list plus the conversation, dialogue, role, meeting and evil-play suites.
- Paired bot games, main against this branch (`autoplay --seed 1 --games 6 --npcs 10`): every sweep-record field is the same in all 6. The new path never fired: no reading was told through "ask night" and no result was held back. So this shows nothing else moved, not how often the new path fires. Unmeasured: how often players will get a result from "ask night" rather than "ask gift".

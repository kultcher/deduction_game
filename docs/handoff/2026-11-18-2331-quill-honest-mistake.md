# Three reading labels: Mistaken, Lying, Delusional

- **Agent:** Claude-Quill
- **Base:** origin/main at 678838f
- **Status:** PR open; golden re-baselined in it. The Lying retune is in its own commit.
  Michael confirmed it (Nov 18, via Seneschal): "the Vicar chat is about NPC behaviour, not
  player interaction with evidence".
- **Next actor:** Bailiff (golden-moving: merge one at a time). Lantern reviews the doubt
  route (`workshop/source_doubt.gd`). Herald points the card text at the label constants. Beadle may
  switch the "gift could have been turned" defence to the merged mode's name (it already
  works through the alias).
- **Decision:** Michael, Nov 18, via Seneschal, after Quill's label audit. "misled" and
  "poisoned" become one honest-mistake label, **Mistaken** ("it's extremely hard to get any
  kind of definitive proof of a poisoner anyway"). It covers any unreliable reading:
  poison, Delusion, a Marked soul, a Red Herring and future mechanics. Lying's do-nothing is
  fixed by retuning existing constants. Delusional is unchanged.

## What changed

- **One honest-mistake mode** (`workshop/reading_challenges.gd`).
  - `ReadingChallenges.HONEST` ("impaired") with `canonical(mode)`: "misled" turns into it
    when a challenge is assessed. Saved cases and NPC defences that say "misled" keep
    working, and results come back as the one mode, so the jury, the consequences and
    the track record read one name.
  - Its cause is any honest failure: the share of the reading being wrong that a lie
    doesn't carry. That counts a Delusional reader, poison, a registration and the gift's
    own error alike, since everything but the reader being evil is in it. Before, a failed gift's cause was zero with no Poisoner possible, and
    "misled" counted only where a registration could explain the reading.
  - The Poisoner candidates (the small nudge at whoever was out that night) are gathered
    only where a Poisoner is possible.
  - A Seer's "yes" that a Red Herring or Marked registration explains keeps its explicit
    rule: no discount, since the gift worked. Any other Seer reading is graded like the
    rest. Before, a Seer "misled" was never graded.
  - "misled" is still refused on a Medium's passing-on. The merged option is offered there
    under its code name.
- **The honest-doubt route** (`SourceDoubt._player_failed_gift`, Lantern's #270 and
  strength build): it takes either name, and no longer needs a Poisoner to be possible.
  The doubt is still the approved strength by credibility, 20% at the lowest to 80% at the
  highest. Where a Poisoner is possible, the one-witness weighing against the poison chance
  can still raise it. A Registrar's night-0 register carries the call but no poison chance;
  before, a call on it carried nothing.
- **The theory check** (`solver.gd`, `chronology.gd`): either name assumes the reader is
  good and drops what the reading said, as "misled" did.
- **Lying retune** (`sim/tuning.gd`; its own commit):
  - `JURY_CHALLENGE_LYING_MIN_AGR`: 0.6 → 0.3.
  - `JURY_CHALLENGE_LYING_SCALE`: 0.12 → 0.4.
  - `tuning_catalogue.md` is regenerated.
- **UI wording:**
  - The label is "Mistaken" and the tip is Herald's, both approved by Michael: "The reading was wrong, but honestly told: something fooled the gift, such
    as poison, delusion, a Red Herring or a Marked soul."
  - Both live in `ReadingChallenges.HONEST_LABEL` and `HONEST_TIP`
    (`workshop/reading_challenges.gd`), and the canvas and live workshop read them.
  - The canvas offers "Mistaken", "Lying" and "Unlikely"; the live workshop "Mistaken",
    "Suspected lie" and "Unlikely reading".
  - The "inconsistent" cause "Poisoned that night" becomes "Mistaken". The older canvas's
    "misled (honest but wrong)" becomes "mistaken". The modifier title is "Mistaken
    reading", and the theory error reads "…conflicts with the Mistaken explanation."
  - Still mine, for Herald to reword: one NPC reply note, "An honest mistake can be a
    failed gift or a misleading registration; it does not establish poisoning."
- **Docs:** the DESIGN "Challenges" bullet now describes the three labels.
- **Tests:**
  - New `tools/test_honest_mistake.gd` (14 checks, fast list). Both names carry the same
    doubt and map to one mode. Both record "the reader is good". With no Poisoner the call
    carries the credibility doubt alone and points at no one. A lie call against a
    contradicted reading raises the teller's suspicion. That last check fails on the old
    constants.
  - Updated, because they pinned the old split: `test_player_failed_gift` (no Poisoner and
    the Registrar's night 0 now carry the call's doubt), `test_premise_step3` (no Poisoner:
    the call still doubts but blames no one) and `test_roles_official` (a Seer same-pair
    flip gets only the graded test's small discount, about half a percent).

## What I measured

The label probe: 10 seeds, 10-NPC town, 2 to 5 good listeners each. A good Archivist's
reading names two good people as possibly the Poisoner, and a Dowser clears them. The
player's case calls the Archivist reading wrong. Figures are the change in suspicion, out of
100, at the player's credibility middling / high:

| Call | Named pair | Reader | Poisoner | Everyone else |
|---|---|---|---|---|
| Misled, before | −0.1 / −0.1 | +0.1 / +0.1 | 0 / 0 | 0 / 0 |
| Failed gift, before | −6.7 / −11.1 | −1.2 / −3.6 | +1.7 / +3.5 | +1.7 / +3.4 |
| Mistaken (either name), after | −6.7 / −11.1 | −1.2 / −3.6 | +1.7 / +3.5 | +1.7 / +3.4 |
| Lying, before | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| Lying, after | 0 / 0 | **+2.9 / +10.9** | 0 / 0 | 0 / 0 |

- **Lying settings tried** (gate, floor), reader change at middling / high:
  - (0.3, 0.12): 0 / 0.
  - (0.3, 0.4): +3 / +11, chosen.
  - (0.3, 0.8): +12 / +34.
  - (0.2, 0.4): +3 / +11.
  - With (0.3, 0.8) a trusted player could all but hang an honest reader on their word.
- **Agreement:** listeners agreed with a contested lie call at 0.30–0.44, under the old
  0.6 gate.
- **The Poisoner nudge** shares the gate, but its agreement (0.12–0.17) stays below 0.3, so
  it didn't change.
- **Golden and suites:** see the PR.

## Evil sometimes tells the truth: starting data (not built)

Michael (Nov 18, via Seneschal) keeps the BACKLOG item open. He sees the real work as evil
NPCs choosing better when to lie, or when to tell a true but damning reading. That waits for
a design chat with Vicar, and this measurement is its starting data. The item asked for t:
how often evil's made-up readings happen to be true.

- **Method:** 40 passive bot games, 10-NPC town, seeds 1 to 40 (`tools/_probe_fake_truth.gd`,
  not committed). Each night, every reading a good listener held from an evil source was
  checked against the worlds matching the real deal (evil team, Demon and secret holder).
  The result was compared with its share of all worlds, the chance rate the judge already
  assumes for a liar.
- **Result:** the 98 checkable fake readings held 38% of the time, against 45% by chance,
  so t ≈ 0. Evil's fakes lean false: they're built to frame good people.

  | Fake gift | Readings | True | By chance |
  |---|---|---|---|
  | Archivist | 10 | 0% | 38% |
  | Surveyor | 8 | 12% | 51% |
  | Seer | 21 | 19% | 34% |
  | Dowser | 36 | 47% | 44% |

- **Not checkable** this way: the Night Watch, Lamplighter and Psychologist, whose content
  the report table doesn't test.
- **Caveat:** the check ignores the Red Herring and poisoning, so good readings scored only
  56% to 100% true. Correcting for that roughly still gives t of 0 to 0.05.
- **Meaning for the judge:** it already prices a liar's reading as true at the chance rate,
  so there's nothing to build at t ≈ 0. A deliberate truth-telling strategy would make t
  real. The judge change would then be one new likelihood state in
  `workshop/cs/CaseEvalKernel.cs` (`Factor`): a reader who can't read healthily scores
  t + (1 − t)·q where the reading holds and (1 − t)·q where it doesn't.

## Not done

- **SourceDoubt's own lying gate** (`DOUBT_CHALLENGE_LYING_MIN_AGR`, 0.6) is unchanged.
  It feeds the earlier belief model's full doubt, not the connections model the probe
  measures.
- **Delusional** is unchanged: it still clears. Michael set that explicitly; Seneschal has
  flagged it to him.

## Small calls made on Michael's behalf

- **The code name:** "impaired", which already carried the doubt route and the
  candidates. "misled" is the alias.
- **A Registrar's night-0 register:** it carries the call's doubt with no poison chance.
- **A Seer reading:** graded, except where a registration explains a "yes".
- **Lying:** I chose (0.3, 0.4) over the stronger (0.3, 0.8). Michael confirmed it.
- **The Seer red-herring rule:** kept, as described above.

## Proposed for the backlog

None.

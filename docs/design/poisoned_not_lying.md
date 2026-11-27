# "Poisoned, not lying": can the player's call sway the town? (design note)

**Status: decided (Michael, Nov 18): option C. Not built.** BACKLOG section 2, "The
player's 'poisoned, not lying' call, and poison evidence from night outings" `[decided]`. Written Nov 18 by Claude-Vicar, from
Michael's question relayed by Seneschal and Quill's measurement on recovering from a wrong
"lying" call (BACKLOG section 2, "Recovering from a wrong 'lying' call"; Quill's handoff PR to
come). Builders: Quill (the challenge, the poison chance, the Poisoner-evidence link) and
Lantern (how a listener's belief takes it). The code facts below are read from main, not run.

---

## Decision (Michael, Nov 18; relayed by Seneschal)

1. **Option C:** build both the evidence link and the player's call as testimony.
2. **The cost of being wrong:** through the existing track record only, nothing stronger.
3. **The Poisoner-evidence reach:** any unexplained night outing on night N counts, more
   strongly if the person could have reached the reader's home.
4. **NPCs making the same call:** not now. Revisit with the deferred "An NPC defender's
   challenge isn't stored as a case" (BACKLOG section 5).
5. **The build** runs the three checks in section 6 first, and reports how far one call moves
   a listener at typical and at high credibility, in game terms.

Builders: Quill (the judge) and Lantern (the belief side).

## 1. The problem

Quill measured it on 10 seeds with a Poisoner, at 7 NPCs. A good Archivist's poisoned reading
falsely names two good people, and a good Dowser's reading contradicts it.

- **The clash alone** raises the Archivist from 25% to 54%. A grounded "lying" call adds
  nothing on top.
- **Revising the call to "failed gift"** is rejected: listeners agree about 3% of the time,
  because nothing makes poison likelier than a lie.
- **A case against the real Poisoner** takes only about 5 points off the Archivist.

So once the town settles on "the Archivist lied", the player has almost no way to say "no, they
were poisoned". **Michael (Nov 18):** evidence about the Poisoner should make "failed gift" more
believable. His caveat is that there's rarely a strong case for a Poisoner beyond intuition. The
one real tell is someone with no night duty being seen out at night.

**His question:** can or should the player's "expertise" sway the town a bit? If the player
challenges a reading as "I think this person was poisoned, not lying", should that change how
the town assigns suspicion, for example by spreading it across the town instead of letting it
settle on the Archivist?

## 2. What already exists

- **The "failed gift" cause on a reading challenge** (premises step 3). It's zero when the
  script has no Poisoner. Accepted, it points a little suspicion at the **Poisoner candidates**:
  people the case's cards show out on the reading's night with no gift or errand to explain it
  (`ReadingChallenges.poisoner_candidates`, `workshop/jury.gd`). That's already half of
  Michael's "caught out at night" link. It acts only once the cause is accepted, and today it
  almost never is.
- **The per-night poison chance** (Quill, Nov 17, `ReadingChallenges.poison_chance`). This is
  the chance, as a listener can tell it, that a given gift was poisoned on a given night: the
  chance a Poisoner is in play, divided by the good people alive. In a seven-NPC town with a
  Poisoner certainly on the script that's about one in five, and none once the town knows the
  Poisoner is dead.
- **Honest doubt** (#216, #232, #245). A listener can weigh a teller's reading with the doubt
  the teller might hold about their own gift ("Something seems off about my readings"), so a
  clash reads as a failed gift rather than a lie. This is the route a teller's own self-doubt
  will use.
- **The player's word as a card** (`SharedLedger._add_player_words`, premises step 2). A secret
  premise ("X holds S") adds one card told by the player, counted as reliably as that listener
  takes the player's word (credibility). This is the precedent for the player asserting
  something the town can't otherwise see.
- **The track record** (`game/credibility.gd`). Each dawn, what the player argued is checked
  against what each NPC now believes from their own evidence, and credibility moves.

## 3. Options

### A. Evidence only: the Poisoner-evidence link

Someone with no night duty who is seen out on night N raises the poison chance for readings
from night N, and more so when that person could have reached the reader's home. The player
argues it the usual way, with the sighting in the case.

- **Fits the pillars cleanly.** The player builds the case from evidence, and nothing rests on
  the player's say-so.
- **It's general:** a rule about unexplained night outings, not about one role.
- **It's weak by Michael's own caveat.** That evidence is often missing, so on its own the
  Archivist stays stuck in most games.

### B. The player's call counts as testimony (honest doubt, by trust in the player)

A "failed gift" challenge, or the revision to it, adds the player's word that "R's reading was
a failed gift", counted at the listener's credibility in the player. It feeds the honest-doubt
route, the same way a teller's own self-doubt would.

- **The clash is then explained by poison more than by a lie.** The Archivist is relieved, and
  the suspicion spreads the way Michael describes: toward the Poisoner candidates if the case
  has any, otherwise thinly across everyone not cleared (the town still has the same number of
  evil to find).
- **Bounded by the setup:** it does nothing on a script with no Poisoner or Delusional, and
  little once the poison chance is low (the Poisoner known dead, many people alive).
- **No new constant** if it reuses the player's-word reliability and the poison chance as its
  prior.
- **The risk:** a trusted player can whitewash any inconvenient reading.

### C. Both, with a cost on being wrong *(Vicar's recommendation)*

Build A, and build B with two guards. Both guards reuse existing machinery.

1. **The setup gate:** only where a Poisoner or Delusional could be in play, scaled by the
   poison chance. This is already true of the "failed gift" cause.
2. **The track record:** a "failed gift" call records "R is good" in the player's track record
   with that listener. If the listener's own evidence later turns against R, credibility falls
   at the next dawn, as it does for any argued conclusion. Calling every awkward reading
   "poisoned" then costs the player.

Not recommended: **diminishing returns with repeated use** (a new rule and a new constant; the
track record already prices misuse), and **an extra cost only when the teller is shown evil**
(the track record covers it, earlier and more gradually).

## 4. Against the guardrails

- **"The player builds the case; NPCs must not out-deduce the player."** C keeps the deduction
  with the player. The town doesn't conclude "poisoned" on its own; it takes the player's
  reading of the clash, as far as it trusts the player.
- **"The player shouldn't win by supplying information"** (premise centring). A "failed gift"
  call supplies an interpretation, not information. It matches the centring decision: how the
  player frames the evidence changes how it lands. A wrong frame costs credibility, which is
  more than Michael's "a misframed case costs nothing beyond not landing", because this frame
  asserts something about a person ("R is good").
- **"NPCs simulate a human mind."** People do defer to someone they trust when an expert says
  "it wasn't her, she was got at". Scaling by credibility keeps that partial.
- **"No sheep."** With high credibility everywhere, one call could move the whole town at once.
  The build should report how far one call moves a listener at typical and high credibility,
  in game terms.
- **Symmetry.** Evil can already say "my gift's been turned" through the self-doubt line
  (Beadle, Nov 18). Under C the player has the same argument from outside, and it can be wrong
  in the same ways.

## 5. Michael's calls

All answered Nov 18; see "Decision" at the top.

## 6. Checks before building (Quill, Lantern)

- Whether a player's-word card can feed the honest-doubt route, or needs a separate path, and
  whether that path is in the connections refresh. Whether the player's-word secret card reaches
  it at all was still unconfirmed in `docs/design/premises_plan_review.md`.
- Re-running Quill's 10-seed measurement under C: how far the Archivist recovers, and where the
  suspicion goes (Poisoner candidates, the real Poisoner, everyone else).
- Whether recording "R is good" for a "failed gift" call misfires when R is Delusional (good,
  but every reading wrong).

## 7. An ungrounded "Mistaken that night" (Michael, Nov 23)

An ungrounded "Mistaken that night" call keeps counting at the player's credibility. This
replaces the Nov 19 "counts for nothing". It's mostly useful for breaking ties between clashing
readings without accusing the reader. Ungrounded "Suspected lie" and "Delusional all along" calls
still count for nothing. As built: `SourceDoubt._player_failed_gift`; recorded in
`docs/evidence_catalog.md` (Argon, #555).


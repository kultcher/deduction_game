# 2026-11-18, Claude-Quill: recovering from a wrong "lying" call, step 1 measured (`claude/wrong-lying-call-measured`; docs only)

- **Base:** main. **Status:** PR open, docs only. **Next:** Bailiff (review and merge). The
  questions are with Michael through Seneschal.
- **What:** BACKLOG "Recovering from a wrong 'lying' call", step 1 (Seneschal's slate,
  Nov 18). The item gains a measured note.
- **Setup:** an uncommitted probe, `tools/_probe_wrong_lying.gd`.
  - **Games:** seeds from 100000, the first 10 whose script has a Poisoner, 7 NPCs.
  - **State:** crafted, with every listener's trust in the player at 0.7 and every suspicion at 0.25.
  - **Readings:**
    - A good Archivist A falsely reads "one of B and C is the Poisoner".
    - A good Dowser reads "no evil among B and C" (night 1).
    - The same Dowser later reads "one evil" on the real Poisoner P (day 2).
  - **The player presents to every listener in turn:**
    1. "A is evil", challenging the reading as a lie, grounded on the clearing reading.
    2. A revision of that case, with the challenge changed to "failed gift". A variant
       defends B instead.
    3. "P is evil", on the Poisoner reading.
  - **Control:** the same cards with no challenge.

| Step (average over good listeners) | Suspicion of A | Suspicion of P | Trust in the player |
|---|---|---|---|
| start | 0.25 | 0.25 | 0.70 |
| lying case (lands with 78% of listeners) | 0.54 | 0.14 | 0.71 |
| revised to failed gift (agreement 0.03) | 0.54 | 0.15 | 0.71 |
| case at the Poisoner | 0.49 | 0.37 | 0.70 |

- **What it shows:**
  - **The clash, not the challenge, raises A.** The no-challenge control gives the same
    numbers at every step. In the connections model a lying challenge adds no lean, by
    design (Lantern: #146/#151, `docs/belief_model.md`). It acts only as a floor under the
    vote-level suspicion of the teller, and here the floor sits below what the clash
    already requests.
  - **The "failed gift" revision doesn't land.** It replaces the lying case for each
    listener, but listeners don't accept it (about 3% agreement). Nothing in it makes
    poison likelier than a lie. The defend-B variant gives the same.
  - **Evidence about the Poisoner is a weak way back.** It takes about 5 points off A.
  - **The player's credibility barely moves:** by at most 0.01 at any step.
- **First pass, without grounds:** it was discarded. The challenge never landed, so it measured nothing.
- **Put to Michael (through Seneschal):**
  - Should evidence about the Poisoner, or that A was poisonable, make "failed gift"
    believable for that teller?
  - Does the signposting half (step 2) still make sense?
- **Proposed for the backlog:** nothing yet; waits on Michael's answer.

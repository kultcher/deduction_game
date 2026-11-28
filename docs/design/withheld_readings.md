# Withheld readings: asking for what someone hasn't said (design note)

**Status: direction from Michael (Nov 22, 2026); values approved Nov 28. "Call on" is built (#542,
#545); the NPC asking, pressing and cost are not yet.** Written by Claude-Vicar,
from a design pass with Michael on the Coroner's question from playtest 51795 (PR #526).
- **What happened:** Fenwick, the Poisoner, claimed Archivist on day 1 and never gave the
  reading the claim implies. A bug caused that, and Beadle has fixed it. Even so, no NPC asked
  him for it or counted the missing reading against him.

**The principle:** chasing missing information is mostly the player's investigation. NPCs do it
now and then, never as a matter of course, so the threads stay the player's to pull.

---

## 1. NPCs ask, in private

- **Who:** an NPC that heard someone claim a gift with a reading it should already have, a
  first-night gift above all (Archivist, Clerk, Rumormonger, Surveyor, Chronicler). It asks
  for the reading: "You claim the Archivist; what did it show you?"
- **How often:** a lowish chance, with no hard limit (Michael). It's likelier when the NPC is
  wary of the claimant, or has high Insight.
- **When:** from the day after the claim.

## 2. NPCs press at the meeting

- **Who:** a confident NPC that's suspicious of someone holding back information can press them
  at the meeting.
- **How often:** relatively rare, and skewed toward confident NPCs (Michael).

## 3. What the holder does

- **Gives it.** That's the normal case.
- **Defers with a reason.** A real holder can have good reasons:
  - an Archivist or Clerk reading names two people, and one may be a friend;
  - a Rumormonger reading exposes a burden holder ("it isn't mine alone to tell"; Michael:
    works);
  - it doesn't trust the asker.
- **Deflects without a reason.** It's rarer.
- **Evil:** since Beadle's fix, a bluffer has a fake reading ready. It will mostly answer, which
  commits it early to something other gifts can contradict.

## 4. The cost

- **A claim alone, never asked about,** costs nothing. The cost comes from being asked and
  dodging.
- **A deferral with a reason** costs a little, and less when the asker trusts the holder. **A
  deflection** costs more.
- **The cost builds by day** (Michael): each day the reading stays out, being asked costs more.
- **Its size** (Michael, Nov 28): a fixed cost, not one sized from bot runs. A deferral costs a
  factor of 1.15, a deflection 1.6, and each day the reading stays out multiplies it by 1.25.
- **Alignment-blind** (Michael): the cost ignores whether good or evil is likelier to dodge.
- **It doesn't stack** over the same claim, and it's discounted by the asker's trust.
- **Once the reading is shared,** a deferral's cost is removed; a deflection's stays.

## 5. The player's version: a softer ask at the meeting

- **The gap:** in meetings, people sometimes don't speak up about their latest readings, just
  because of how the meeting flows. That mirrors real BotC. Today the player can only press
  someone through a nomination.
- **The new action, "Call on"** (name approved by Michael, Nov 22): the player gets one per
  meeting (confirmed), outside a nomination. It's a
  request for information, not an accusation. The NPC is prompted to share anything it hasn't
  shared yet. It can still withhold, if it's stubborn or has a good reason.
- **The cost:**
  - **asking** moves no suspicion by itself;
  - **refusing** moves some, and makes a card for circumstantial use only.
- **What it covers** (Michael, Nov 22): readings not yet shared, night sightings, and even
  secondhand information the NPC hasn't passed on.
- **How the NPC decides:** the normal disclosure rules, with a light pressure bump.

## 6. Who builds what

- **Beadle:** asking in private, pressing at the meeting, and how holders answer, defer or
  deflect.
- **Lantern:** the cost in beliefs, building by day, at the fixed values above.
- **Herald:** the player's action in the meeting UI, and every line (Michael approves the
  wording).
- **Quill:** the refusal card, for circumstantial use.

## 7. Open

Nothing open on the shape. The name ("Call on"), the limit (one per meeting) and the scope
(readings, night sightings, secondhand information) are settled (Michael, Nov 22). Beadle's asking and
pressing values are approved (Nov 28), and both pushes reuse the "Call on" pressure bump.

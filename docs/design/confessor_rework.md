# The Confessor rework (design note)

**Status: direction from Michael (Nov 22, 2026). Held, not shared yet; nothing is built.**
Written by Claude-Vicar.

## Why

Today the Confessor visits one living person in secret each night and learns whether their
spirit is good, and evil and Marked souls return no memory of the visit. The "I forgot who I
saw" reads as clunky. It can also be too strong once the blocks' populations dwindle.

## The rework

- **Each night, the Confessor and one person it chooses meet at a place,** as a summons (it
  builds on the Carouser idea, a "night summoner").
- **If the summoned person is good,** the Confessor learns this.
- **Otherwise, it forgets whose confession it heard.** It still knows where it heard it.
- **Marked** triggers the forgetting at the usual 50% (Michael).
- **The summoned person doesn't learn who the Confessor is.** It knows it was called to
  confession, so it can explain its walk ("I was called to confession"). Evil can say the same.
- **Where they meet:** the summoned person's workplace about half the time, otherwise one of
  their two haunts at random. Michael suggested a slight preference for the workplace; the
  "about half" is Vicar's small call, to tune.
  - **Why the summoned person's places:** "I heard a confession at the Smithy, but can't recall
    who" narrows the field to the people who use the Smithy. That gives haunts real use. It also
    keeps the Confessor's own route varied, so its walks don't form a pattern that exposes it.
  - **Why the workplace:** much of the time, the player learns only a workplace it already
    knows, so the strong role gives little away for free.
  - **The board doesn't auto-fill the haunt** from a reading. It's in the reading's text, so a
    sharp player can note it.
- **Lore:** a hidden confessor who doesn't see the penitent's face.
- **Night movement:** two walkers a night. That's a fair price for a strong gift, now that the
  vigil sees only people leaving home.

## How it plays

- **"I can't remember who came"** implicates someone only if they were seen out. Night-walking
  evil rarely needs the "called to confession" excuse at all, so it mostly catches non-walking
  evil that happened to be spotted, and then it's their word against the Confessor's.
- **The routing bind** (Michael's example): an evil Poisoner claiming Night Watch is out to
  poison and is also called to the bakery.
  - **Seen leaving home:** fine, as expected for a Night Watch.
  - **Seen at the meeting place:** it can deny being the one called ("I was there on my
    watch").
  - **Seen elsewhere too:** that denial can be contradicted.

  Evil doesn't know who saw it, so it picks its excuse without seeing every witness. It's rare,
  and it's catchable, which suits the design.

## For the builders

- **Beadle:**
  - the Confessor's choice of whom to summon;
  - the summoned person's account of its walk;
  - evil choosing its excuse from the sightings it knows are public, and staying exposed to the
    ones it can't know about.
- **Lantern:**
  - a good person summoned out at night is a new reason for good people to be out, so it needs a
    likelihood in the movement model;
  - a sighting at the meeting place fits "called" or "on their own errand".
- **Herald:** the reading's text, and the summoned person's lines.

## Open

1. The workplace and haunt split (about half, to tune).
2. Whether the Confessor can summon the same person twice.

# Passing information on, and two backlog calls (Claude-Vicar)

- **Base:** main at the time of branching (`claude/vicar-passing-on`).
- **Status:** docs only, ready. **Next actor:** Bailiff to merge; then Beadle may build
  "Passing information on".

## What changed

These are Michael's decisions of Nov 28, relayed by Seneschal.

- **BACKLOG.md, "Passing information on: hidden sources and deliberate seeding"** (renamed
  from "A hidden Seer seeds its readings into the gossip network"), now `[decided]`, owner
  Beadle:
  - **the source is always hidden** when information is passed on: in private, to the player
    and at the meeting. A dead person's reading, and anything the source has since said
    publicly, are the exceptions;
  - **deliberate seeding by any good role,** with `SEED_TRUST_MIN` 0.7, `SEED_CHANCE` 0.35
    (×1.5 when the reading points at a suspected Demon) and `SEED_RELAY_CHANCE` 0.4;
  - **"Ask about <person>" no longer depends on that person's gossip.** What surfaces goes by
    role. A heard Seer reading is always given when asked about Seers, with the source hidden,
    and the same goes for every role. The dead's claim and readings always surface, if known.
    Evil surfaces such information 25% of the time, and never when it incriminates the Demon.
- **New item, "Evil seeds made-up information through a trusted townsperson"**,
  `[tentative]`, owner Beadle, a possibility for later. It came from Michael through
  Seneschal; it wasn't proposed by me.
- **The case-strength helper:** not started, and stays on the backlog. Its tag is now
  `[decided: direction; not started, Michael, Nov 28]`.
- **"Not being seen out" as evidence:** `[deferred, Michael, Nov 28]`.
- **docs/design/reading_interpretation.md:** a new section 1.7, "Passing information on",
  since the rules apply to every role. Section 2.1 points to it, and section 3's "Not being
  seen out" line notes the deferral.
- **The contents list** was edited by hand. NPC behaviour items 5 to 7 were renumbered for
  the new item.

The held branch `claude/vicar-reading-held` also edits reading_interpretation.md, in other
sections. It stays held; I'll rebase it on main when Michael releases it.

Claude-Vicar

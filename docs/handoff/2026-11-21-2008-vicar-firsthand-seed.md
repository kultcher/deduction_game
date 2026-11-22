# Firsthand means only what the NPC itself read, saw or did

**Claude-Vicar.** Base: `origin/main`, after #515. Status: docs only, ready for review. Next
actor: Bailiff (review and merge). Lantern builds it on the prototype; it lands with Burdens.

## What changed and why

Michael decided "Being lied about can pull in evidence that clears the liar" (Nov 21, relayed
by Seneschal):
- firsthand means only what the NPC itself read, saw or did; anything someone else said is
  secondhand;
- someone else's sighting of the NPC on a night it knows it was home no longer seeds its core,
  but still counts fully against its teller;
- whether the NPC's own sightings and vigils should seed its core is still being measured.

Files changed:
- **`docs/belief_model.md`:** a new section recording the rule, marked planned since it's built
  on `mock/burdens-slot` and lands with Burdens. The core's seed line gets a pointer to it.
- **`BACKLOG_POLISH.md`:** the item is now `[decided; lands with Burdens]`, and it closes when
  Burdens lands.

The figures (Lian 82% → 92% on 100100, 62% → 99% on 100027) are Lantern's, as relayed.

## What I measured

Nothing; it's docs only.

# Burdens: how the prototype lands

**Claude-Vicar.** Base: `origin/main`, after #505. Status: docs only, ready for review. Next
actor: Bailiff (review and merge). Lantern cuts the landing branch after Michael playtests.

## What changed and why

Records Michael's Nov 21 decisions in `docs/design/burdens.md` section 10, as Seneschal
relayed them:
- **"How it lands":**
  - Burdens reaches main as one PR (two at most, if Bailiff wants the judge separate), with a
    single golden re-baseline, after Michael playtests the prototype;
  - Lantern cuts `claude/burdens` from `mock/burdens-slot`, cleaned of scaffolding, as an
    explicit exception to "mock/ branches never merge";
  - the section records why, and what's given up.
- **"Also settled":**
  - the Unrequited isn't dealt to a night-walking gift, for now;
  - the spell-break threshold is unchanged until player-driven games;
  - the stage-2 world model stays held.
- The section's opening line no longer says the mock branch "never merges".

## What I measured

Nothing; it's docs only.

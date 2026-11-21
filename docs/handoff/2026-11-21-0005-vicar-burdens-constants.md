# Vicar: the burdens constants, and the judge model held for scenarios

- **Agent:** Claude-Vicar
- **Base:** main (after #472)
- **Status:** docs only
- **Next actor:** Lantern, on the worked scenarios; Bailiff merges this

Michael (Nov 20), in `docs/design/burdens.md` section 9:
- **The new constants are estimated, then tuned from data.**
- **The hanging cost** is the midpoint of the player's "yes" vote bump. With today's
  trust-scaled bump (−0.04 to 0.14), that's about 0.05. Vicar read this from the code; the
  builder confirms it.
- **The Unrequited reveal's trust cost** is the same as telling someone's secret.
- **"Bolder with silence":** Beadle estimates it.
- **The judge's world model is held.** Michael asked Lantern for four worked scenarios
  comparing the revised per-burden placement with the cheaper "none" placement.

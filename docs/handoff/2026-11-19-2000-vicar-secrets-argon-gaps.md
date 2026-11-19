# Vicar: secrets rework, gaps in Argon's review

- **Agent:** Claude-Vicar
- **Base:** main
- **Status:** docs only. It's open while the leads' replies come in, then it goes to Bailiff.
- **Next actor:** Lantern, Quill, Beadle and Herald, who reply to Seneschal or Vicar. Then
  Vicar collates their replies into section 11.3.

## What changed and why

Michael asked Argon (Nov 19) how the secrets-rework direction would hit the solver and the
systems around it, and asked the leads to flag what it misses. Vicar collates the gaps.
`docs/design/secrets_rework.md` gets a new section 11:
- Argon's summary;
- Seneschal's first-read gaps (11.1);
- Vicar's design-side gaps (11.2);
- a place for the leads' replies (11.3).

The main design gap: good NPCs lying about their gift (decided Nov 18) is a judge change,
because today a good teller's gift claim is taken as true. The report doesn't cover it.

## Checked

Code pointers were read from main, not run. One of Seneschal's points, that evil already
lends a teammate a harmless secret, I couldn't find in `sim/evil.gd`. It's noted for Beadle
to confirm.

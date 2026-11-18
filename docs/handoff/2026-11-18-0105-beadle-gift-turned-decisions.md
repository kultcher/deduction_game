# Beadle: "my gift may have been turned", Michael's Nov 18 decisions recorded

- **Base:** main `46ed341`. **Status:** docs only, ready for Bailiff. **Next actor:** Bailiff.
- **What changed:** the BACKLOG item "Saying 'my gift may have been turned'" now records
  Michael's two decisions from Nov 18, relayed by Seneschal:
  - **(b), evil:** only for a gift the NPC has publicly claimed. The rest of the sketch
    stands: triggered by a reading held back twice running, no new number, logged with its
    reason, and heard through the listener's honest doubt (Lantern's route, per Quill).
  - **(a), good:** the threshold starts at 25% self-doubt, as a new named constant in
    `sim/tuning.gd`. Michael may raise it after playtesting; the build PR reports how often
    it fires in its tests. It waits for Lantern's rebuilt #232 ("prior only").
- **Measured:** nothing; no code changed.
- **Next:** I build (b) when my queue allows, then (a) once #232 is on main.

Claude-Beadle

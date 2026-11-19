# 2026-11-19, Claude-Lantern: test_relay_bluff_games holds a relay to its relayer's own word (`claude/relay-bluff-firsthand`; test only)

- **Base:** main `dd97121`. **Status:** PR open. **Next:** Bailiff. Merge before #292, which
  fails this suite without it. No game code changes, so golden doesn't move.
- **Why:** with #292, the suite's seed search reaches seed 100031, and the "nor in another game"
  check failed there. Edda's chance that Greta is evil was 0.38 with Greta's relays and 0.52
  without. Bailiff held #292 for it. The same game fails the same way on main (0.35 / 0.50);
  main's search just never reaches it.
- **What happens in 100031:** it's the final three, and Edda is the only good NPC alive. Greta,
  the Demon, claims Medium. She relays the dead Agnes seeing Dorian (dead too) at her door on
  the first night, the night Greta herself was there and killed her. It's a lie, and Edda half
  believes it.
  - The drop doesn't depend on Edda's trust in Greta: it's 0.15 at a trust of 0.2 and at 0.8.
  - The relay counts exactly as Greta's own firsthand sighting would: 0.35 either way.
  - Weighed as Agnes's own honest word (#265's bug), it would be 0.33.
  - So the relayer is the teller, as #265 made it, and the drop is how far Edda believes
    Greta's word. That's a lie with a reason, partly believed, which is play.
- **The change:** the check was "the relays don't lower the relayer more than 5 points below
  leaving them out". A relay that blames someone else lowers its teller as far as it's believed,
  just as a firsthand sighting would, so that check can't tell play from the bug. It's now
  "no more than 2 points below the same cards told as the relayer's own firsthand sightings".
  - `Seeds.relay_effect` adds `firsthand`.
  - `Seeds.cards_effect` gains an optional `recast` callable.
- **Measured:**
  - On main, both checks pass (seeds 100019 and 100027).
  - On #292 (3ab5605), both pass (100027 and 100031; 0.38 relayed, 0.38 firsthand).
  - With #265's fix reverted (the dead counted as a teller too), the new check fails on seed
    100020: 0.97 relayed against 1.00 firsthand. The old check passed that case (0.94 without).
  - test_relay_bluff and test_connections_pairings, which share the fixture, pass.
- **Proposed for the backlog:** none.

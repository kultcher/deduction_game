# 2026-11-28, Claude-Lantern: unnamed relays in the belief model (`claude/anon-relay-model`)

- **Base:** main at 6b338e10.
- **Status:** PR open.
- **Next actor:** Bailiff. After this, Quill's anonymous-sighting card PR, then Beadle's "passing on hides the source" build on top.
- **Design:** Michael, Nov 28: passing on hides the source, everywhere. Beadle's design was reviewed by Lantern and Quill.

## What changed and why

- **`Connections.items`:** `testimony_only` reports (an unnamed account, with source = the relayer) are left out of teller grouping. Grouped, one relayer's accounts from two different readers would be judged as one reader's readings.
- **Private relays at full reliability.** Michael asked for private hearsay weight to stay unchanged. Its discount is already in the ledger weight (`HEARSAY_TRUST_SCALE` × trust in the relayer), so the card shouldn't take `RELAY_WEIGHT` on top. One told at the meeting keeps `RELAY_WEIGHT`.
  - `live_evidence.normalize_card` carries `hearing: "private"` on an unnamed receipt.
  - `live_assessment.testimony_card` marks the card `private_relay`, which a relayed Night Watch sighting also uses for its hearing weight.
  - The `_listener` reliability then skips `RELAY_WEIGHT` for it.
- **No new constant.**

## Left to others

- **Quill:** the unnamed night sighting card (`normalize_card`, the adapter, the board). Lantern's call on its weight is option (1): accept that it can outweigh a named sighting, with no cap. A named witness bears the cost of being placed out that night; an unnamed one can't be checked, and it pays `RELAY_WEIGHT`.
- **Beadle:** the sim side.
  - the anonymous receipts, and `hearing: "private"` on private relays;
  - the eid on the anonymous receipt plus an opaque origin key;
  - no real source in `on_reading_heard`, `on_execution_reading_heard` or the justification key.
- **Michael, through Seneschal:** whether an unnamed relay merges into a reading the listener already holds by name (Lantern recommends yes, matching gift, night and content).

## Measured

- **New:** `tools/test_anonymous_relay_model.gd`, 5 checks, on the fast list. Codex round 1: an unnamed account's reliability ignores doubt about the relayer's own gift (full in private, `RELAY_WEIGHT` at the meeting).
- **Suites:** test_mechanics_relays, test_workshop_provenance, test_gossip_tiers, test_connections_core and test_workshop_regressions pass.
- **Golden:** identical to `baseline_2e97efe` on all five seeds at `--tol 0`. No golden seed has an unnamed relay of a gift reading by one relayer twice, or a private one.

## Proposed for the backlog

None.

# 2026-11-17, Claude-Herald: a night question never opens readings (`claude/herald-ask-night-cap`)

- **Base:** main `518f3c8`. **Status:** PR open. Zero drift, outside the golden queue. **Next actor:** Bailiff.
- **Source:** Steward's report (`docs/maintenance/2026-11-17.md`) found main's full suite red. `test_social` fails on "a false Night Watch's night story matches their fake report", first at `b28d6d7` (my #178). Bailiff confirmed it on main `19d5771`. Michael confirmed on Nov 17, through Seneschal, that the cap holds: someone "not ready to share" keeps their readings back even when asked about a specific night.

## What changed

- **`MindDialogue._night_gift_result`** (#178's "what the gift showed that night"). A result the player hasn't heard is now told only by someone already sharing their readings (tier 4) who would still tell them to "ask gift" today. Before, a good mood that day was enough, so the night question could open readings for someone who had named their gift but kept their readings back (tier 3). A false Night Watch with a fabricated report then recited it, along with every other untold reading. The night question no longer raises the disclosure tier itself.
- **`tools/test_ask_night_results.gd`:** the "told when the gate is open" case now sets tier 4. A new check covers Michael's rule: at tier 3, on an open day, an untold result stays held back in so many words, with no card. The Night Watch's open case is at tier 4.
- **`tools/ci_fast_suites.txt`:** `test_social` and `test_npc_behaviour_1110` are added at their sorted places, as Bailiff asked, so this can't go red on main unseen again.

## Measured

- `test_social` fails on main `518f3c8` (20 cases) and passes here.
- These pass: `test_ask_night_results`, `test_social`, `test_npc_behaviour_1110`, `test_conversation_nights`, `test_conversation_gifts`, `test_dialogue_voices`.
- Golden is identical to `baseline_3ef0e2f` on all 5 seeds. The passive bot never asks about a night.

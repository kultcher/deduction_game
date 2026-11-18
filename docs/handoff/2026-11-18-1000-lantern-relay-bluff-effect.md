# 2026-11-18, Claude-Lantern: test_relay_bluff measures what the relays do (`claude/relay-bluff-effect`; tests only, zero drift)

- **Base:** main `8737e29`. **Status:** PR open. **Next:** Bailiff (merge first, then #269).
- **Why:** main went red on `test_relay_bluff` after #232 ("nor in another game, seed 100031: Edda
  on Greta, 0.47"). It's the check, not behaviour. The evil-relayer checks asked that the relayer's
  overall chance stay at 0.5 or more. #232's poison self-doubt softened Edda's own readings and
  lowered Greta overall from 0.56 to 0.47, while Greta's relays still raise her (0.44 without them,
  0.47 with). #216 broke the same check the same way earlier today.
- **What:** both evil-relayer checks now measure the relays' own effect (`Seeds.relay_effect`).
  They fail if the relays lower the relayer by more than 5 points. The genuine-Medium check already
  works this way.
- **It still catches the bug (Bailiff's ask):** on `832bd17`, before #265's fix, both fail. Hollis
  goes 0.83 → 0.46 with his relays, and Greta 0.54 → 0.37. On main both pass (Hollis 0.84 → 1.00,
  Greta 0.44 → 0.47).
- **Tests:** `test_relay_bluff` 4 of 4 on main. Only that file changes, so golden is untouched.

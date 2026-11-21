# Vicar: the five burdens follow-ups settled

- **Agent:** Claude-Vicar
- **Base:** main (after #464)
- **Status:** docs only
- **Next actor:** Michael and Seneschal, on when to start the staged plan; Bailiff merges this

Michael's answers (Nov 20), written into `docs/design/burdens.md`:
1. **The script lists up to four possible burdens** (the hidden one marked) and how many are
   in play. It never says which one, or whether it's the hidden one. Evil infers from
   silence: its chance of bluffing rises as days pass with no burden claimed.
2. **Ill-Omened only goes off if the holder claimed it when nominated** (a hard rule). The
   solver only accounts for nights after a claimed Ill-Omened is hanged, so it's never a
   hidden effect.
3. **Marked's private sharing** (to an NPC or the player) is one trust-based tier, most often
   to the starting friend.
4. **The Unrequited's evidence-hiding** is its own narrow rule, not part of "Good NPCs lie
   tactically".
5. **After a burden claim,** the allowance for others drops only a little, since a claim can
   be a bluff. A Rumormonger or Chronicler reading pushes it closer to zero, never to certain.

Section 8 now says nothing is open. The BACKLOG line is updated, and the contents list is
regenerated.

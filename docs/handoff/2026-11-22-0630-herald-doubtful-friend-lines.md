# Herald: the doubtful friend's lines, in every voice (mock/burdens-slot)

- **Agent:** Claude-Herald
- **Base:** `mock/burdens-slot`, on top of Beadle's triggers: dbdf41f5 (`support_doubt_for`) and 4c9bcb6b (`vote_yes_doubtful_friend`). They land with Burdens.
- **Status:** pushed to `mock/burdens-slot`. There's no PR of its own.
- **Next actor:** none. They go with the Burdens PR.

## What changed

Two new kinds of line, from Coroner's 51795 journeys: Isolde defended her friend Kiran, then nearly voted to hang him. Beadle owns when each fires; the wording and the voices are mine. Each kind has one line per voice, in `sim/voices/*.gd`.

- **`support_doubt_for`, `{target}`:** a friend of the nominee speaks up for them while their own vote sits close to the yes line. It's a defence that wavers.
  - **Fallback (Michael's own line):** "I've known {target} for a long time. They wouldn't be capable of something like this... would they?"
- **`vote_yes_doubtful_friend`, `{nominee}`:** a good friend of the nominee who only just voted to hang them says so to their face, after the vote. At most one per vote.
  - **Fallback:** "Forgive me, {nominee}. I've known you a long time... but I can't look away from this."

## Approvals (Michael, Nov 22, via Seneschal)

- **Pronouns:** "they" for now, since the sim has no pronoun data. It's easy to replace if he adds a table. The yes-side lines say "you", so they need no pronouns at all.
- **`support_doubt_for`:** the 15 drafts approved as a set.
- **`vote_yes_doubtful_friend`:** approved as a set ("those are generally quite strong"). Two lines are in his words:
  - **Jory:** "Sorry, {nominee}. Really. I just—I wish I could say no."
  - **Nisha:** "Forgive me, {nominee}. I've known you as a friend, but the facts of the case reveal you as something else."

## Measured

- **`test_readings_agree`** checks that every voice says both lines in its own words and names the nominee.
- **`test_dialogue_voices`:** the key count is now 292.
- **Passing:** those two and test_dialogue_fixes_accusations_votes.

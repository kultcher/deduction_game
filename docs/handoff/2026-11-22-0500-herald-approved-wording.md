# Herald: Michael's approved wording (playtest 51795 and Nisha's register)

- **Agent:** Claude-Herald
- **Base:** main at 0b692d4, after #527.
- **Status:** PR open.
- **Next actor:** Bailiff. This PR moves golden, in reply text only, and re-baselines to `baseline_35d96b9`.

## What changed

All of it is wording Michael approved on Nov 22, via Seneschal.

- **`public_claim` lines that fit any day.** They assumed a delay, which read wrong on the first day:
  - Isolde: "Please hear me gently, everyone. I am the {role}."
  - Dorian: "I know everyone's going to read into this, sorry, but here it is: I am the {role}."
  - Bart: "No sense hiding it. I am the {role}."
  - Kiran: "Since we're laying our cards on the table, allow me to oblige: I am the {role}."
- **`support_vibes_for`:** "I've known X long enough. I can't believe them evil." The old line read as doubting the defendant's own statement.
- **Nisha:**
  - her claim, "One less question for the town to puzzle over: I am the {role}.";
  - 31 lines with modern words replaced (`docs/design/nisha_register.md`, #529), approved as a set.

- **Odette's public claim** (Michael's wording): "Are we doing public confessions tonight? Let's get mine over with: I am the {role}." Her two other public lines that say "tonight" stay as they are (Michael: public statements are made in the evening).

## Measured

- **Suites:** the ten `test_dialogue*` suites, `test_meeting_flow` and `test_defence_grounds` pass.
- **Golden:**
  - reply text only on every seed;
  - with `--ignore engine,reply`, all five seeds are identical: beliefs, votes and outcomes are unchanged;
  - two captures were identical.

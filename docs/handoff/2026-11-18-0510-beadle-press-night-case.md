# Beadle: a pressed case resting on night evidence is about that night

- **Base:** main (BASELINE `baseline_490cdcf`). **Status:** ready for review. **Next actor:**
  Bailiff. BACKLOG left alone while Vicar restructures it: this fixes "A whereabouts
  contradiction gets an irrelevant gift refusal" (78148; Michael, Nov 18: a bug, fix it).
- **The bug:** pressing someone in private with a filed case counted the case as being about
  a night only if it concluded "lied" or "unreliable". A "suspicious" case built from an alibi
  or a vigil fell through to the gift answer, so the NPC refused to talk about its gift.
- **The fix** (`MindDialogue.press`): a case whose supporting cards include a night card is
  about that night, whatever it concludes. The NPC answers about the night (owns it, holds to
  its account, or refuses, as for a night sighting).
- **Small call made on Michael's behalf:** it applies to every conclusion ("suspicious", "evil",
  "Demon", "Minion" and the rest), not only "suspicious": a case that rests on a night is about
  that night whatever it argues.
- **Test:** `tools/test_press_night_case.gd`, 4 checks: "suspicious", "evil" and "lied" cases
  on the first night are answered about the night; a case with no night card still gets the
  gift answer. The "suspicious" and "evil" checks fail without the fix.
- **Golden:** zero drift. Two captures identical to each other and to `baseline_490cdcf`.
- **Suites run:** test_press_night_case, test_playtest_13910_dialogue,
  test_conversation_nights, test_conversation_gifts, test_workshop_presentation, test_social.

Claude-Beadle

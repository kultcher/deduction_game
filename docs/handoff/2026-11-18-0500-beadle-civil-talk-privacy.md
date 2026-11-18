# Beadle: Privacy no longer damps the civil-talk trust gain

- **Base:** main (BASELINE `baseline_490cdcf`). **Status:** ready for review. **Next actor:**
  Bailiff. BACKLOG is left alone while Vicar restructures it: this closes "Privacy without
  compounding trust penalties" (Michael, Nov 18, via Seneschal).
- **The change:** `CIVIL_TALK_PRIVACY_DAMP` 0.5 -> 0 (`sim/tuning.gd`; catalogue regenerated).
  The question-fatigue penalty is kept, as Michael asked.
- **In game terms:** the first civil conversation of the day with an NPC now always raises its
  trust in you by 0.04. Before, a very private NPC gave only 0.02 and an average one about
  0.03, so quiet people warmed to you more slowly on top of being slower to share. Now
  Privacy decides only how much they share and how soon they tire of questions.
- **Golden:** zero drift. Two captures identical to each other and to `baseline_490cdcf`: no
  golden game ends a conversation that earns the gain.
- **Suites run:** test_social, test_social_trust, test_social_credibility,
  test_conversation_gifts, test_conversation_nights, test_tuning_hoist.
- **Not measured:** how much sooner a private NPC now opens up in play.

Claude-Beadle

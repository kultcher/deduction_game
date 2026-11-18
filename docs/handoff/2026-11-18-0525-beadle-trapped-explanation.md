# Beadle: "Fine, I was out", then why

- **Base:** main (BASELINE `baseline_490cdcf`). **Status:** ready for review. **Next actor:**
  Bailiff. BACKLOG left alone while Vicar restructures it: this builds Michael's Nov 18 decision
  on "Follow-up after a false alibi is established" (via Seneschal).
- **What I found first:** when a case catches an NPC's false home alibi, its whole reply was
  Herald's `trapped_night_out` line ("Fine, I was out. Doesn't mean I was doing anything
  wrong."). Nothing followed it; an explanation came only later, at the podium if nominated.
- **What changed** (`game/workshop_presentation.gd`, `MindDialogue.trapped_explanation`): after
  the line, a roll on the day's disclosure tier, the one that already decides how much an NPC
  shares (no new constant).
  - **Tier 2 or more:** the NPC explains the night. In private: a good NPC's secret errand
    (confessed, with its secret card) or the gift that took it out. In a meeting: the podium's
    own account (`MindPodium.press_night`, admitted).
  - **Tier 1, an evil NPC, or no honest reason:** the line stands alone (Michael: keep the
    existing line as the stonewall). It never lies "home" again.
- **Wording:** no new lines. One for Herald: the secret confession reuses
  `confess_secret_private`, which opens "...I wasn't home", so after "Fine, I was out" it
  repeats itself a little.
- **Test:** `tools/test_trapped_explanation.gd`, 7 checks: the helper (a secret errand is
  explained; no reason or evil, nothing), and a full presentation: an open NPC (tier 4) says the
  line then explains; a closed one (tier 1) says only the line.
- **Golden:** zero drift. Two captures identical to each other and to `baseline_490cdcf`.
- **Suites run:** test_trapped_explanation, test_workshop_presentation,
  test_workshop_reading_challenges, test_lie_severity_votes, test_conversation_nights,
  test_meeting_m2d.

Claude-Beadle

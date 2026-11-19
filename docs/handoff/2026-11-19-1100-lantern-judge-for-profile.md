# 2026-11-19, Claude-Lantern: Connections.judge_for_profile, a case as an average listener weighs it (`claude/judge-for-profile`; zero drift)

- **Base:** main `aef2ff9`. **Status:** PR open. **Next:** Bailiff; then Quill wires the Test
  juror, its badge and the town note onto it, and Herald adds the tooltip line.
- **Why:** Michael approved juror fix (a), option (i), on Nov 19. The juror, the badge and the
  town note judge a case as a synthetic average listener would hear it put to the town, through
  the full listener path, with no full-weight figure kept anywhere.
- **What changed:**
  - **New `game/profile_judge.gd`**, with the entry point `Connections.judge_for_profile(g,
    value, profile)`. It's loaded at call time, since it needs the game layer.
  - **The listener:** credibility 0.5, trust 0.5, nothing first-hand.
  - **What it hears:** the case's already-public cards and the public claims about the people it
    names, each from its teller. The case's new cards come only through the case. The player's
    earlier public cases count as stored cases, each on its day.
  - **How it's weighed:** `Bridge.capture`, then `Shared.prepare`, then `Shared.evaluate` and
    the connections refresh, once without the case and once with it.
  - **What it returns:** before, after and shift for the target, everyone's chances both ways,
    and the case's stored-case entry.
  - **Nothing calls it in play yet.** Golden is identical.
  - **New `tools/test_judge_for_profile.gd`** (11 checks, fast list, a few seconds).
- **For Quill:** read `before`, `after` and `shift`, and `case` for the weight and lean.
  `profile` overrides `AVERAGE` (`credibility`, `npc_trust` as a number or a map, `insight`,
  `confidence`). Two things worth knowing:
  - On the test case, credibility moves an unheard case only a little (0.353 at 0.1 against 0.358
    at 0.9).
  - A case of already-public cards can nudge its own target down slightly (about -0.005), through
    its stored-case lean. That's the connections arithmetic as a real listener gets it, not this
    wrapper.
- **Measured:** see `docs/belief_model.md`, "Weighing a case as an average listener would".
  Golden is identical to main's baseline.
- **Proposed for the backlog:** none.

# 2026-11-17, Claude-Herald: the Workshop can challenge a Medium's relay, naming its side (`claude/herald-relay-challenge-menu`, stacked on Quill's `claude/medium-relay-challenge`)

- **Base:** Quill's `claude/medium-relay-challenge` (`24239d7`), stacked so the menu didn't wait on that merge. **Status:** PR open. **Next actor:** Bailiff, after Quill's PR merges; Michael for the wording.
- **Why:** Quill's judge change lets a challenge on a relay name its side, but the Workshop still greyed out challenges on relay cards (Seneschal, Nov 17).

### What changed

- **The right-click menu** on a relay card offers two challenges in place of the three plain ones: "Challenge: The Medium passed it on wrong" (starts as a lie) and "Challenge: The dead were wrong to begin with" (starts as an honest mistake). Plain readings are unchanged.
- **The challenge card** on a relay shows the two sides as chips above the usual Misled / Lying / Poisoned / Unlikely chips. On the passing-on side only Lying and Poisoned are offered, as the judge allows. Switching to the passing-on turns a "misled" challenge into a lie. The answer window has the same two choices.
- **The model** (`workshop/canvas_model.gd`): `add_modifier` takes the side, the challenge carries it into the compiled case (`attribution`), saving and loading keep it, and a saved challenge the judge wouldn't accept is refused on load. The card's title names the side.
- **The card's support note** no longer says relays "need separate attribution".
- **The shared ledger** (`workshop/shared_ledger.gd`, Codex's #195 finding): two presented cases that challenge the same relay on different sides now count as conflicting alternatives, like two modes always did. Before, the later one silently replaced the earlier. The comparison is `SharedLedger.challenges_conflict`. Plain challenges carry no side, so they merge as before.
- **A relayed morning reading's night** (`workshop/reading_challenges.gd`, Codex's second #195 finding, in #191's code): a relayed Executor reading carries night -1. A challenge on the dead person's side then named night -1, and source doubt never reached the dead reader. It now falls back to the day the reading was made. **For Quill:** this touches your #191 line; take the same fix there, or let it ride in with #195.

### Wording (settled by Michael, Nov 17, via Seneschal)

- **The two sides:** "The Medium lied or their gift failed" / "The dead person lied or was misled". They're in `CanvasModel.RELAY_SIDE_TEXT`. Like the menu's other entries and the card's chips, neither has a closing full stop.
- **The rule stays:** he kept Quill's rule (the Medium's side is a lie or a failed gift), so the Medium's label changed to match it. The first version, "lied or was misled", offered a choice the judge doesn't allow.
- **Tooltips, both kept as drafted:**
  - Medium's side: "The Medium heard the dead correctly but passed it on wrong: a lie, or a failed gift."
  - Dead person's side: "The Medium passed it on faithfully, but the dead person's own reading was wrong."

### Small calls made on Michael's behalf

- A relay challenge must name its side: there's no default, since an unnamed side would quietly blame one speaker (`test_roles_dead` guards this). Both menu entries name it.
- The passing-on starts as a lie, and the original as an honest mistake.

### Measured

- New `tools/test_relay_challenge_menu.gd` (21 checks, in the CI fast list): the side being required, a relayed morning reading's night, the refused "misled" passing-on, the compiled side the judge accepts, plain readings unchanged, and save and reload.
- Suites: the Workshop canvas, live canvas, UI, relay-challenge, dead-roles and reading-challenge suites, plus the CI fast list, all pass. `test_roles_dead` caught my first version, which defaulted an unnamed side.
- Golden identical to `baseline_a0a378d` at `--tol 0`.
- Not checked: how the two chips look on screen. No screenshot was taken.

# 2026-11-17, Claude-Herald: bluff motives in plain words (`claude/herald-bluff-motives`)

- **Base:** main `af82ca4` (#227 merged). **Status:** PR open; moves golden (text only). **Next actor:** Beadle to review; then Bailiff.
- **Source:** Michael approved my drafts on Nov 17, through Seneschal: the full motive set, the rework note (already in #227), and the coin-flip vote reason. Beadle and I agreed that I'd build both the strings and the slot changes, and that Beadle reviews.

## What changed

- **Every fabricated reading's motive**, in `sim/roles/*.gd` (generate_bluff_reading, fake_medium_reading, the Marked and red-herring notes) and `sim/evil.gd` (the Medium's relays). The reveal prints these as "fabricated: <the reading> (evil fabrication: <motive>)".
  - The new wording follows Michael's rules: "whom evil meant to hang" for the scapegoat, "a fellow evil" for a teammate, and no numbers the player never saw (town certainty, insight, "truth 1", "same=true").
  - It uses street and role names, not codes, and ordinal days ("the second day"). `C.spoken_day` is new for that.
  - People's names still come from #227's `Evil.named`.
  - A false Medium's relay reads "made up a reading from the late Seer Hollis that cleared Kiran, the Demon". The Hearthwitch's relay had said "the dead Dowser"; it now names the Hearthwitch.
- **Evil's vote reason** "Coin-flip vote on a good NPC to look natural." is now "Voted on a good person by chance, to look natural."
- **Tests:** `test_roles_night_sight` and `test_roles_people` pinned the old "a Marked soul read as evil". They now check for "reads as evil".

## Small calls made on Michael's behalf

- Four motives weren't in the approved table. They follow its rules:
  - Augur: "claimed no Demon crossed their path that day"
  - Lamplighter: "made up a plausible count of walkers". The number is dropped, since the reading already says it.
  - Martyr: "chose {name}, to vouch for them"
  - Rumormonger: "gave {name}, a fellow evil, a harmless secret to own to" (this one was in my draft).
- Not changed: the rework alternatives' reasons. They appear only in the dev log.
- Not changed: the honest choices of whom to read. They aren't lies.

## Proposed for the backlog (sent to Seneschal)

- **Evil's spoken-lie reasons in the reveal.** The reveal's lie list also prints evil's "think: lie" lines from Beadle's code, such as "Evil: publicly accuses scapegoat X, citing: ... vibes" and "push scapegoat X (good self wouldn't nominate)". These carry the same shorthand. Suggested owner: Herald for the wording, Beadle reviewing.

## Measured

- Passed: `test_evidence_cards`, `test_evil_owned_lie`, `test_evil_play`, `test_fabrication_check`, `test_lie_severity`, `test_medium_relay_challenge`, all eight `test_roles_*`, `test_dialogue`, `test_case_metrics_dead`.
- Golden: text only, every seed, all in `why` fields (1,021 strings). Record counts and outcomes are unchanged. Re-baselined to `baseline_e958cb2` from two identical captures; `ci.yml` and `docs/golden_baseline.md` are updated.

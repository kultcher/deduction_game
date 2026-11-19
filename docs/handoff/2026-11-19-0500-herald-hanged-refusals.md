# Herald: hanged-Demon refusals, and "Demon" capitalised (#305 follow-up)

- **Signed:** Claude-Herald
- **Base:** main at b856819.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed
#305 merged with Quill's placeholder refusal lines. Michael approved Herald's A drafts on Nov 19, and this PR swaps them in. They are the two constants in `workshop/live_assessment.gd`:

| Refusal | Was | Now |
|---|---|---|
| A saved "is not the Demon" about a hanged person | Someone the town hanged can't be argued not to be the Demon. | Once the town has hanged someone, a case can't clear them of being the Demon. |
| A saved "was the Demon" about a hanged person, with no Scion on the script | With no Scion on this script, a hanged Demon would have ended the game. | With no Scion in this town, hanging the Demon would already have saved it. |

## "Demon" capitalised (Michael, Nov 19)
Michael approved capitalising "Demon" throughout. Every player-facing string in `sim/`, `game/`, `ui/` and `workshop/` that said "the demon", "a demon", "one demon" or "the demon's" now says "Demon": 65 strings in 21 files. That covers readings, role descriptions, filed-case and premise text, endings, logs and dialogue. The voices already used "the Demon".
- **Left alone:** command tokens ("guess <name> demon"), counts beside minions ("1 demon", "%d demon"), ids and keys, and comments.
- **Golden moves on text only:** the new baseline is `baseline_a91d12d`. Every record matches `baseline_e287b3d` once case is ignored, and the two captures were identical. See `docs/golden_baseline.md`.
- **Conflict note:** Quill's #301 edits the `"demon"` branch of `Deduction.conclusion_text` next to these lines. Whoever merges second resolves it, keeping the capital D.

## Measured
- **Suite:** test_demon_when_hanged passes. It checks against the constants.
- **Golden, refusal commit alone:** identical at `--tol 0` to `baseline_e287b3d`.
- **Fast suites:** see the PR. They were running at the time of this push.

## Settled since
Michael approved "X was the Demon when hanged" and "was turned by the Revenant's curse". Both are in Quill's #301.

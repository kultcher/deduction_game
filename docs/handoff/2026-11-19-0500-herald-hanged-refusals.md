# Herald: Michael's wording for the hanged-Demon refusals (#305 follow-up)

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

## Measured
- **Suite:** test_demon_when_hanged passes. It checks against the constants.
- **Golden:** identical at `--tol 0` to the CI baseline on all five seeds.

## Still with Michael
- "X was the Demon when hanged" for filed cases (Quill's #301).
- "was turned by the curse" (Quill's #301).
- Capitalising "Demon" in filed-case lines. This would move golden on text only.

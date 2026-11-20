# Herald: test_social_credibility checks self-support rapport on a real filed case

- **Agent:** Claude-Herald
- **Base:** main (after #395)
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Quill found that `test_social_credibility` fails on main after #395. The failure is in `_support_self`, the check "supportive deductions about the listener can build rapport". The check presented a bare deduction card: "I believe they are not the Demon", with no cards behind it. Only the removed social route could weigh one. A bare belief can't be filed from the Workshop, so in play it now meets the ordinary refusal, as #395 intended.

The behaviour it guards still exists, in the shared presentation: `WorkshopPresentation` thanks the listener and raises rapport (`SELF_SUPPORT_BONUS`) when you present, privately, a case that clears them. So the check now files a real Workshop case that the listener is not the Demon, on a Seer reading that pairs them with another good townsperson and finds no evil. It presents that case "for" them. A new fixture check confirms the case is filed and founded. The routing and rapport checks are unchanged.

Test only, zero drift. CI didn't catch it because the suite isn't on the fast or slow list, so it runs only on main and in the nightly run.

## Measured

- **`test_social_credibility`:** 152 checks, 0 failures locally on main 13865d2 plus this change (1 failure before).

## Proposed for the backlog
None.

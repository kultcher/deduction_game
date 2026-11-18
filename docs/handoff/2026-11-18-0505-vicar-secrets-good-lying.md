# Vicar: secrets rework, good NPCs lying about their gift (Michael, Nov 18)

- **Agent:** Claude-Vicar
- **Base:** `claude/vicar-backlog-verified` (PR #254, unmerged)
- **Status:** docs only, ready for Bailiff
- **Next actor:** none to build. The secrets rework stays backlogged; Seneschal may note the
  decisions for when it's picked up. Argon is checking the solver math with Michael.

## What changed and why

From a talk between Michael and Claude-Vicar on Nov 18. `docs/design/secrets_rework.md`:

- **Section 2, Michael's decisions:**
  - Good NPCs may lie about their gift, but only with a reason: avoiding or drawing the
    Demon's attention. It's fairly uncommon, possibly tied to Confidence. The liar
    discloses only under pressure, with the most harmless lie available.
  - Every secret is unique.
  - The hidden kinds (probably Delusional and Sleepwalker) stay but are mutually exclusive
    at the script level.
- **Not decided:** plain folk and confidants.
- **Section 8:** the open list is updated to match.
- **Section 10 (new):** the reasoning:
  - what good lying does to the double-claim tell, and the lie-severity precedent;
  - evil's secret bluffs once secrets are unique, and the Baron;
  - a rough count for one hidden kind per script: 840 arrangements at 10 NPCs, against
    5,040 today, from the code and not timed;
  - confidants (Michael's idea) and plain folk, as options.

BACKLOG's "Lying about one's role" sub-point and the secrets-rework item record the
decisions. The open-questions index (1.2) matches.

## Checked

Code facts were read from main, not run: the judge's claim rules
(`WorldDomainKernel.ClaimsCompatible`, `ReadingFraction`), `GOOD_OWN_ALIBI_OUT`,
`ALLOW_NO_GIFT_DENIAL`, the day-1 confidant, and `Tuning.Setup.SETUPS`.

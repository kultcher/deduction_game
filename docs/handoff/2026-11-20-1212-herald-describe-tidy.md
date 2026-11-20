# Herald: the comparison panel's text is built in reading order

- **Agent:** Claude-Herald
- **Base:** main (after Lantern's #420)
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is the second half of cleanup item (3), which Michael approved on Nov 20, via Seneschal. The first half was #402, the plain container. It was to wait for Lantern's scaffolding PR (#420), which merged. Lantern confirmed that `describe()` read none of the dropped keys. The rule: the preview must look the same before and after.

`describe()` in `ui/workshop_comparison.gd` (the developer comparison panel's text) built its list and then spliced lines in at fixed positions (`insert(2)`, `insert(3)`, `insert(4)`). Where a line landed depended on which optional lines came before it. It now appends each line in reading order:
- the new model's stance and words;
- the conditional worlds;
- the reasoning, if any;
- the working theory, if any, with the reasoning or just after the blank line when there's none, as before;
- the evidence-strength lines.

UI only, zero drift. The text doesn't change.

## Measured

- **Old and new output are identical** on 48 real recorded comparisons: cases for and against, three venues, four listeners, 7- and 10-NPC towns. They also match on four synthetic results that reach every optional line: theory with and without reasoning; errors, a released explanation and an audience that can't evaluate; and a result that isn't ready. The probe was a throwaway script and isn't committed.
- **Suites:** test_workshop_live_ui and test_workshop_integration pass.

## Proposed for the backlog
None.

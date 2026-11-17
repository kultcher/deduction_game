# 2026-11-17, Claude-Beadle: lie severity, the vote side (claude/beadle-lie-severity-votes)

**Base:** main ae6c304 (#210, Quill's judge side). **Status:** PR open. Golden is identical
to `baseline_f554c4a`, so this needs no golden-queue slot. **Next actor:** Codex, then
Bailiff. Herald drafts the voice lines, and Michael picks the wording.

## What changed and why (BACKLOG "Lie severity", [decided], Michael Nov 17)

- **How the judge's lighter reading reaches votes:** no new wiring was needed. Votes
  weigh each voter's suspicion, which since #210 comes from the judge's softer reading of
  a caught "home" lie (about 51% evil from a 33% start, away from the kill). Nothing in
  the vote rules treated a caught lie as certain on its own account.
- **"Accepts the lie but won't hang, and says so":**
  - Say the player presents a case in public, and it catches the target in a home lie:
    their own "I was home" for a night, plus something that puts them out that night.
  - A listener who grants that case (accepts it, or takes it partly) now remembers it
    for the day.
  - If that listener then votes no on the target, the after-vote resistance lines give
    them their own reason: "I'll grant Kiran lied about where they were that night. But
    a lie about one's bed isn't the Demon's work, and I won't hang them for it." This
    is draft wording for Herald and Michael.
  - It comes after "I'd sooner hang the one on the block". It comes ahead of the other
    reasons, and it is said even when the vote wasn't close.
- **Why "partial" counts:** since #210, a case that rests only on a caught home lie
  usually moves a listener only partway. That listener is exactly the one the item
  describes: they believe the lie but not that the person is evil.
- **The rule:** `MindMeeting.catches_home_lie` uses the judge's own dispute rule
  (`CaseGraph.valid_dispute`) over the cards the listener actually weighed. That's the
  same list the existing "Fine, I was out" reply uses.

## Measured

- `tools/test_lie_severity_votes.gd` (new, on the fast list, 18 checks):
  - the rule;
  - the resistance line;
  - the real presentation path. On seed 692 (7 NPCs), a filed "home + seen out" case was
    granted by 4 listeners, all 4 recorded the lie. A sighting-only case recorded none.
- Also passing: test_lie_severity, test_meeting_m2d, test_workshop_presentation,
  test_meeting_flow, test_meeting_reasons, test_presentation_contracts, test_dialogue.
- Golden: identical on all 5 seeds.
- **Not measured:** how often the line fires in played games. As Quill found, a caught
  home lie needs the player pressing someone at the podium. Passive play doesn't produce
  it.

## For Herald

- **New key:** `vote_no_lie_not_rope`, with slot `{nominee}`. It has no per-voice lines
  yet, so every voice falls back to the draft above.

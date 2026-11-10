# Playtest report: case 13910 (2026-11-05)

Michael at the controls, Claude-Tally making every decision. 10 townsfolk, a dynamic
(random) script, `main` after the overnight sweep. **Won on Day 2:** Bartholomew (the
Demon) hanged at the first execution. Innocents surviving 6/7, no wrongful executions.
The private theory was never recorded, so identification wasn't scored.

## How it went

- **Day 1.** Jory traded his gift for a promised vigil on the Docks: Magistrate, no
  reading yet. Constance hinted at official business and vouched for Jory; Jory vouched
  for her. The tavern gossip gave only bonds and a haunt. A quiet first meeting: Merrin
  reported Dorian leaving his house on night 0, and Constance voiced generic
  "misgivings" about Isolde. Nobody nominated.
- **Night 1.** The vigil caught Dorian on the Docks. Isolde (the Augur) was killed on
  Chapel Hill.
- **Day 2.**
  - Pressing Dorian with the vigil card got the Warden reveal and his dated guard
    history (Constance's door, both nights). Constance claimed Clerk privately. The crime
    scene gave a scent trace (chapel, graveyard or smithy).
  - At the meeting the puzzle came together:
    - Lian: Surveyor, the Square's residents mixed, backed by Constance's Clerk pair
      ("Lian or Greta is the Surveyor").
    - Merrin: Dowser, with two counts that partition the living town.
    - Fenwick: "Monitor", "a Surveyor was abroad on the Square last night".
  - Claude's read: exactly one evil among Lian, Kiran and Fenwick; two among Constance,
    Greta, Jory, Bartholomew and Dorian. Fenwick's reading frames the confirmed
    Surveyor, so the hypothesis was **Fenwick, Bartholomew and Greta**. That proved
    exactly right.
  - The town's shared model said Kiran instead. Five nominations followed: Fenwick (3
    votes), Dorian (1), Kiran (4), Bartholomew (6, on the block after claiming Medium
    under a public press), and Jory, a counter-nomination (2). Bartholomew was hanged.

## Grimoire highlights

- Evil: **Bartholomew Demon** (bluffing Medium), **Greta Poisoner** (bluffing
  Gravedigger, never claimed), **Fenwick Revenant** (bluffing Monitor; hid a totem at
  the graveyard on Day 1).
- Merrin (Dowser) was **Marked**; Dorian was evil's scapegoat. Greta poisoned Kiran on
  night 0 and Lian on night 1. Lian's Surveyor reading was from night 0, so it held.
- Isolde (Augur) learned on Day 1 that she had **crossed paths with the Demon** at the
  tavern, and was killed that night before she could share it. Coincidence: the vengeful
  Demon's kill score (2.16) didn't know her reading.
- Kiran (Registrar, register Clerk, Gravedigger, Scion) **cleared Fenwick of being the
  Scion** on night 1 and never shared it.
- Constance's Day-1 accusation of Isolde was a **p = 0.12 generic roll**, with no
  reason behind it.

## Issues

### Bugs

1. **The owned-lie line fires on a refusal.** Dorian answered `ask night` with "Where I
   was is my own business". When pressed with the vigil card he said "I know I said I was
   home", which he never did. The "owning the earlier lie" line needs an actual earlier
   "home" claim.
2. **A spliced reply to a press.** Dorian's answer to the vigil card opened with a
   sighting stem ("Look, I'm jumpy, not blind! I know who walked right past me:") and then
   swerved into a gift reveal.
3. **"ask why" after a plain accusation wastes a question.** It only works after a hint
   tier ("I have a reason…"). After Constance's generic "misgivings" it was offered and
   answered "I have nothing further to add". Hide it, or let a willing accuser explain.
4. **"press role" worked twice** on the same nominee (Bartholomew). The prompt says once.
5. **Muddled presentation reply.** Constance on "Dorian holds the Warden gift": "Those
   reports do not suffice to alter my judgment… incline me toward your reading… physical
   traces… weighs against their being that night's killer". There were no traces in the
   case, and the premise wasn't about the killer.
6. **Text:** "Last night, I learned that a Surveyor was abroad on the Square last night.."
   (repeated "last night", double full stop). Jory: "didn't see a soul" followed by "Didn't
   spot a single person!" (a repeated line).
7. **Gossip tells people about themselves.** In `grimoire talk`, "Merrin tells Dorian:
   Dorian was out on the Market…" and "Greta tells Dorian: Dorian was out…". The
   meeting-broadcast shares list the subject as a listener.
8. **Missing role icons:** Augur, Magistrate, Monitor, Psychologist and Registrar show "?"
   placeholders in the script window.

### Reasoning and balance (to investigate)

9. **The case against Fenwick got no traction.** Found with `tools/explain_case.gd` (PR #72):
   - **Filed case #78 never included Fenwick's Monitor reading.** It cited Merrin's Hill
     Dowser reading, Lian's Surveyor claim and reading, and Constance's Clerk pair. It moved
     the town's P(Fenwick evil) only from about 0.42 to 0.52 on average. Removing any one
     card changed that by 0.03 at most, so no card carried it. Most of the posterior is the
     listener's prior, and the probability moves to Kiran, Bartholomew and Jory instead.
   - **Adding Fenwick's Monitor reading makes the case weaker** (0.52 → 0.41). His claimed
     reading clears him: removing it raises each mind's suspicion of him by 0.12–0.17.
   - **Challenging it as a lie does nothing** (0.41 either way). Every mind answers "the
     cited evidence does not establish a problem". The challenge only counts on a hard
     conflict, and "a Surveyor was abroad on the Square" doesn't conflict with Lian being
     the Surveyor: a Surveyor with a night-walking secret (Sleepwalker, Lovers) can be out.
     How unlikely that is doesn't count.
   - **The bigger cause: Fenwick's defence, "Merrin is lying".** When Claude nominated
     him, that one line cut suspicion of Fenwick by 0.08–0.18 for every listener (Constance
     0.18 → 0.00, Jory 0.18 → 0.02). Yet every listener's own assessment of the challenge
     rejected it (`supported: false`). P(Merrin evil) didn't rise. Removing just that
     defence restores the old values. **The cause is attention, not the challenge** (an
     earlier version of this report guessed the lying challenge's "the source is evil"
     assumption; that was wrong). A bare defence was recorded with every fact the
     listener held as its grounds, and the attention rule that never drops a challenge's
     grounds then pulled them all in. Constance went from weighing 8 of her 22 cards to all
     22. With the full picture Fenwick looked less guilty (0.46 → 0.31 to be evil), and that
     lasted for every later refresh. So the player's well-grounded challenge did nothing,
     while the evil nominee's bare one switched the whole room to full attention. Fix
     written in the premises pass, step 0: a bare defence now has no grounds. It's on
     branch `claude/defence-empty-grounds`, **not yet merged** (no PR as of Nov 5,
     22:30 ET).
10. **The whole town named "Kiran as the Demon"** from tiny suspicion gaps. Snapshot
    suspicions were 0.15–0.23 and nearly flat, yet nine speakers voiced the same top-pair
    verdict. The case replies restated each speaker's own top suspect instead of
    answering the case.
11. **Kiran never claimed under 4 of 10 votes.** Michael: fine as it is. It fits a
    high-Privacy character and played as a dramatic close call. The danger-scaled openness
    idea stays a design note, not a fix.
12. **Nomination fatigue** (Michael): five nominations in one meeting is tense but slow.
    Consider making unlikely nominations rarer after about three.
13. **Generic Day-1 accusations.** Constance's p = 0.12 roll accused a good person with no
    reason, then the Demon killed that person. It's harmless noise, but it reads as a clue.
14. **Greta voted yes on Fenwick, her teammate.** Michael is fine with the vote, but the
    logged reason doesn't match the one we'd want. The log says "The Revenant's totem is
    hidden: its hanging will turn one of the town", with a cover override at stakes 0.75.
    The reasons that would fit are (a) it was a low-odds vote, so a yes builds credibility,
    and (b) it's the Revenant, which evil should eventually work to get hanged. Evil
    actively framing its own Revenant isn't built yet.

### Presentation and wording

15. Dorian's two accusations and Fenwick's nomination reused the same template, "…Lian's
    reading on the Square points toward their quarter". "Then Merrin is lying. Ask
    yourselves why." came from two speakers.
16. The zoomed block view's name labels for Jory and Isolde sit apart from their standees.
17. `ask seen today` isn't flagged when it can only repeat people already in view.
18. Constance told me "I saw Jory at the Square this afternoon" while I stood in the Square
    looking at Jory. Sightings the player has already made could be left out.
19. DESIGN.md is already behind: the Monitor, the new Psychologist and the Confessor
    aren't documented.

## Why the town hanged Bartholomew (investigated after the game)

Michael's questions: why did the town vote more strongly for Bartholomew than for Fenwick
or Kiran, and is the town too smart by default? Answered with the new
`tools/replay_log.gd --why` (PR #72), which replays the log and prints each good mind's beliefs
before each vote. The replay reproduced all five votes exactly.

**The Dowser readings.** Fenwick had one Dowser ping, not two:

- Day 1, the Square: 2 evil among Constance, Greta, Jory, Bartholomew, Isolde and Dorian.
- Day 2, Chapel Hill: 1 evil among Lian, Kiran and Fenwick.

**Why Bartholomew rather than Kiran or Fenwick.**

- The structure favoured him. In the Square group, Isolde (the Demon's victim), Dorian
  (the Warden, confirmed by the vigil) and Constance (the Clerk, cross-checked with Lian)
  are mostly cleared. That leaves 2 evil spread over Greta, Jory and Bartholomew.
- In the Hill group, Lian's Clerk-backed Surveyor claim leaves 1 evil split between Kiran
  and Fenwick. Fenwick's Monitor claim makes him look a little better than Kiran, who never
  claimed.
- So Bartholomew sat at about 0.53–0.69 P(evil) for five of six minds; Kiran and Fenwick at about
  0.35–0.5 for most.
- "Kiran is everyone's top suspect" wasn't true of the minds' beliefs. Kiran was top only
  for Lian, who knows she's good, so the Hill evil is Kiran or Fenwick, and Fenwick claimed.
  Kiran's own top was Fenwick (0.82), for the same reason. For Constance, Merrin and Jory,
  Bartholomew was first or second. Bartholomew was the one name near the top for everyone.
  The meeting replies naming Kiran as the Demon probably came from the case-scoped evaluation of
  Claude's "Fenwick lied" case rather than the minds' own beliefs (not yet checked; see issues 9–10).

**Not too smart: unsure, and pushed over the line by the player.**

- No mind was confident. Every mind's likeliest evil team held only 10–22% of its worlds,
  and the true team (Greta, Bartholomew, Fenwick) was in most minds' top four.
- The Bartholomew vote was marginal. Lian voted yes at 0.48 against a need of 0.44 and
  Jory at 0.63 against 0.51. Dorian voted no at exactly 0.55 against 0.55.
- The player's "accuse" plus "vote yes" added 0.125 to every voter's score. Without them,
  Lian (0.355 against 0.44) and Jory (0.505 against 0.51) vote no, and the nomination
  fails at about 4 votes.
- Constance's nomination was close to a coin flip. Her suspicion was Bartholomew 0.41
  against Jory 0.40, and Jory is good. With the nomination on Jory, the same arithmetic
  could have hanged the Magistrate.
- What feels "too smart" is mostly the player's push landing on a nominee who happened to
  be right. To look at: the player's influence on a vote. +0.125 for every voter is large
  next to these margins.
- Jory at 0.70 to be evil for Constance is consistent, not a missed clear. The vigil Jory
  asked for was the player's, on the Docks: it watches arrivals, so it says nothing about
  Jory at home there. Constance's 0.70 is Dowser arithmetic: she knows she's good, Isolde
  died to the Demon and Dorian's Warden claim held, which leaves the Square's two evil
  among Greta, Jory and Bartholomew. (Corrected Nov 5: an earlier version said the
  vigil should have cleared Jory.)

## Positives

- **The core loop worked exactly as designed.** Fear-for-protection trade → vigil → a real
  sighting → press with the card → reveal plus dated guard history → a Warden the town then
  protected (1 vote against him).
- **The Day-2 meeting was a genuinely solvable logic puzzle.** The Dowser partition, the
  Surveyor and Clerk cross-check and a suspicious fake claim combined into a clean,
  deducible answer.
- **Voices carry character:** Jory's "Yo, Demonologist!", Dorian's shaking hands,
  Constance's "allow for my partiality", Merrin's "I cannot carry this omen alone another
  hour", Kiran's "That's your free sample", Greta's "Use your memories for once".
- **Evil behaved credibly:** Greta's true-but-misleading window sighting of the Warden,
  Fenwick's frame built from what Lian told him, the late Medium claim, the
  counter-nomination of the Magistrate.
- Pressing a nominee's role in public works and gives usable claims.
- Readable UI touches: the crime-scene cross, claim icons in the townsfolk list, the
  "(1 more at bakery)" counts, the tie arithmetic on counter-nominations, "already public
  knowledge" when citing a public case.

## Follow-ups suggested

- Fix bugs 1–4 and 7 (small, self-contained).
- Weigh the player's vote push (+0.125 per voter) against typical vote margins.
- Evil framing its own Revenant (Michael's design idea; see 14).
- Merge the defence attention-leak fix (9; premises pass, step 0, on
  `claude/defence-empty-grounds`). It changes what NPCs believe after a defence, so check
  the golden diff before it lands; the baseline may need re-recording.
- Let a lying or unlikely challenge weigh improbability, not only hard conflict. Example:
  a non-walking gift seen abroad at night needs a rare night-walking secret on that person.
- Use `tools/replay_log.gd --why` and `tools/explain_case.gd` on future playtests whenever a
  vote or a case reply looks surprising.

## Status (Nov 5, 22:30 ET)

PR #73 (`claude/playtest-13910-dialogue`) fixes 1, 2, 3, 6, 7, 10, 15, 17 and 18; it's
wording only. It's merged.
- 9: the attention leak is fixed on `claude/defence-empty-grounds` (premises pass, step 0),
  not merged yet. The other half of 9, challenges that ignore improbability, is still open.
- 11: closed. Michael is fine with it as it is.
- 13: the accusation floor was tried and reverted, and is now in the backlog (NPC
  behaviour). Constance's accusation was pure chance: 0.13 against the 0.10 everyone starts
  with. But those chance accusations are what start a meeting talking; with a 0.2 floor some
  Day-1 meetings went silent.
- 5 is deferred to the "premises matter" overhaul.
- 4, 8, 12 and 14 are still open.

# The grim reveal (design note)

**Status: direction from Michael (Nov 20–21, 2026). Nothing is built.** Written by Claude-Vicar
from a talk with Michael on Nov 21. It develops DESIGN's sixth pillar, "Hindsight reveal: end
of case shows the full grimoire: who was what, who was poisoned when, and every lie."
- **Today:** the end of a game offers three plain buttons: "Show the grimoire", "Show every
  lie" and "Show who told whom what" (`ui/main_actions.gd`).
- **This note:** turns those into a paced reveal.
- **Scoring:** shares the end screen. Its note is drafted separately and not yet published.
- **The daily evil-team guess** (section 2a) is new player bookkeeping that feeds the end
  sheet.

---

## 1. What it should feel like

Modelled on how a Blood on the Clocktower game is revealed at the table:
- the truth comes **one person at a time**, with that person's key moment;
- it **leads with what shaped the game most:** often the biggest source of misinformation,
  sometimes the clean chain of confirmations that won it;
- it then **follows how the case developed,** through each death and hanging;
- in a **final-three game** the winner is held to the very end, since it comes down to whether
  the last person hanged was the Demon.

A loss should be **explainable in hindsight**, as DESIGN asks. The game already logs a reason
for every lie and every poisoning, so the reveal can say *why*, not only *what*.

## 2. Decided (Michael, Nov 21)

- **The player paces it:** they can click through as fast as they like, or skip to the end.
- **Key moments:** zero or one per NPC, two at most.
- **Presentation:** a central overlay window. Each NPC's portrait appears, then a randomizer
  visual (a wheel, a slot reel or similar) spins through the possible roles and lands on the
  NPC's true one.
- **Fakeouts:** evil NPCs, and NPCs the town believed were evil, can occasionally land on a
  false role first before revealing the real one.
- **The order** finds a starting point, then lets "whatever's more interesting" come next. A
  smooth game can follow its chain of confirmations, for example: the Dowser cleared the Clerk
  with a night-0 reading, the Clerk confirmed the Seer, the Seer got a lucky ping on the Demon
  on night 2, and the rest was history.
- **The Storyteller** (BACKLOG section 4) can later use the same "what shaped the game"
  measure as its sense of drama. The first version doesn't need it.

### More decisions (Michael, Nov 20, relayed by Seneschal)

- **The reel** is the card-based version Limner put together, which Michael confirmed.
  - **Timing:** about 3 seconds per reveal.
  - **Space:** the reveal has the whole screen, so space isn't a constraint.
- **Watch again** is in: the player can replay the reveal.
- **There's no end-of-game verdict screen** (corrected by Michael, Nov 20). The scored
  verdict is the last guess locked in a daily window (section 2a).
- **Stage 1** shows each guess as right or wrong only, with no points. Scoring follows; see
  the scoring note.

## 2a. The daily evil-team guess

New (Michael, Nov 20). It has **no mechanical effect**; it's the player's own bookkeeping.

- **When:** each day, after the meeting is settled, the screen fades to black. Before the
  execution is announced, the player gets a window to guess the evil team.
- **The layout:**
  - three portrait circles, the Demon at the top and the Minions below;
  - a type dropdown under each circle;
  - clicking a circle picks from the NPC portraits.
- **Who can be picked:**
  - the Demon's victims are crossed out in the Demon picker;
  - they stay selectable for the Minions, in case the Demon ever kills a Minion.
- **Pre-fill:** on scripts with a single Demon type, the Demon's type is filled in.
- **Buttons:** Confirm, Skip, and "Don't ask again this case".
- **Access:** it's also reachable from the Main Menu button.
- **The number of circles** follows the script's evil count (Seneschal's small call).
- **No burden guess** until Burdens ships (Seneschal's small call).

### Corrections (Michael, Nov 20, relayed by Seneschal)

- **No end-of-game "Seal my verdict".**
  - **Why:** the town may hang the Demon by chance early, before the player has built a
    case. A verdict screen at the end would tell the player that the person just hanged was
    the Demon, which kills the drama.
  - **The scored verdict** is the last guess locked in a daily window, after the meeting and
    before the execution result. No extra window opens when a game ends overnight.
  - This replaces DESIGN's "Private theory" rule of scoring the last copy before the
    outcome.
- **Guess changes are limited,** so that naming whoever is about to hang isn't the best play.
  The details are below (Michael, Nov 21).
- **The profile guesses feed the window (a hybrid).**
  - If the player has marked someone as Demon or Minion in their profile, the window prefills
    that person, greyed out.
  - A note tells the player they can pick someone new, or just confirm to lock it in.
  - This replaces the earlier small call that the two share one source.
- **Wording:**
  - there's no line on the fade;
  - Herald's other drafts are approved: "Your suspicions", "Choose…", "Who is the Demon?",
    "Who is a Minion?", "Killed by the Demon; it cannot be them.", "What kind?", "Confirm",
    "Skip" and "Don't ask again this case".

### The change limit (Michael, Nov 21, relayed by Seneschal)

- **No "locked before the hanging day" rule.** Picking the person the player knows will hang
  is allowed: it still costs a change and forces a commitment. Moving the window before the
  meeting was considered and rejected as less fun and less dramatic.
- **Only the Demon pick costs a change.** Minion picks and their types are free.
- **The allowance:** one initial selection, plus two changes per case.
- **Confirming** with no new Demon pick, or an unchanged one, just moves on.
- **A change asks first:** "Change your Demon selection? You can only do this two times per
  case. (n change(s) remaining)."
- **Scoring:** each change costs a little score, so players lean toward being sure rather than
  guessing that someone might happen to be the Demon. The game shows no line about that cost.
  Details are in the scoring note.
- **No write-back to the profile:** the window's picks don't change the profile's marks.
- **Wording:** all of Herald's wording for #496 and #499 is approved, including "Your guess"
  and "You named %d of the %d evil rightly."
- **Seneschal's small calls,** which Herald may flag:
  - clearing the Demon pick counts as a change;
  - at zero changes left, the picker is disabled, with the tooltip "No changes left this case";
  - there's no counter label under the title.

## 3. The order: a walk through the game

### 3.1 The event graph

At the end of the game, build a small graph of what happened:
- **Nodes:** each NPC's truth, and the events that shaped the game: readings, claims, lies,
  poisonings, Delusional and Marked misreads, deaths and hangings.
- **Edges:** "X's reading confirmed Y", "Y's lie misled Z", "the poisoning of W made that
  reading false", "this hanging rested on that reading".

### 3.2 Which falsehoods mattered

The hard part is the key misinformation that never shows up in the player's case: an
assumption everyone simply carried. For example: "We thought we hanged the Poisoner on day 1
because the Gravedigger read it, but the Gravedigger was Delusional."

The game knows every falsehood (each lie, poisoned reading, Delusional reading and Marked
misread). It can measure each one's weight by asking what would have changed without it:
- **At each hanging,** re-run the decisive voters' beliefs as if that falsehood had never
  existed, and see how far the vote, or the suspicion behind it, would have moved.
- **Each falsehood's score** is that effect, summed over the game's hangings and weighted by
  how long the falsehood stood before being contradicted.
- **An implicit assumption is caught too.** The re-run works on what NPCs believe, so it
  doesn't matter whether the item ever entered a case.
- **The cost:** a few dozen belief re-runs, once, at the end of the game, so speed isn't a
  concern. Lantern would know best how to do the re-run cleanly.

### 3.3 The walk

1. **Start at the strongest node.**
   - **In a messy game,** that's the key deception, the highest-scoring falsehood: "The
     Gravedigger was Delusional. The 'Poisoner' you hanged on day 1 was Odette, the Baker."
   - **In a smooth game,** where no falsehood clears a threshold, start at the root of the
     chain the game turned on, such as the Dowser's night-0 reading.
2. **Next, follow the strongest edge** from what was just revealed to someone not yet revealed:
   from the Dowser to the Clerk it cleared, from a lie to the person it fooled.
3. **When a chain runs out,** fall back to time order: the next death or hanging not yet
   revealed.
4. **The Demon goes last,** unless the walk reaches it naturally at the end of a chain ("the
   Seer found the Demon on night 2").
5. **In a final-three game,** the last hanging is revealed last, and so is the winner.
6. **The fallback:** if the graph has nothing strong to follow, a plain timeline still works.
   It's interesting on its own when the player made missteps.

## 4. Each NPC's reveal

- **The portrait,** then the reel spins through **this script's roles only**, not the whole
  roster. It keeps the spin plausible and teaches the script.
- **The role lands, then the alignment.** The burden lands as a second beat, a tag that drops
  in after the role: "…and Delusional". A hidden burden landing this way is a strong moment.
- **The key moment,** zero or one, two at most, written from the logged reasons:
  - "Claimed Seer on day 2. True."
  - "Lied about being home on the first night, to cover the kill."
  - "Poisoned on the second night. That 'yes' was false."
- **The player's guess,** the last one locked in a daily window, shows under the portrait
  while the reel spins ("You guessed: Minion"). It builds tension at no cost, and ties the score into the reveal.
- **Dead NPCs' portraits** stay greyed until their turn, so the board reads as the town that
  ended the game.

## 5. Fakeouts

- **An evil NPC** can land briefly on the gift it claimed, then slip to its true role. The
  reel shows the lie, then the truth.
- **A good NPC the town believed was evil** can land on an evil role, then slip to its true
  one.
- **Rare:** one or two per reveal at most, or they stop surprising.
- **A fakeout on the last NPC of a final-three game** may be the best moment of the reveal.

## 6. Pacing and options

- Each reveal takes about 3 seconds (Michael, Nov 20), and can be quicker after the first
  few.
- **Skip** goes straight to the final screen; **click** advances as fast as the player likes.
- **Reduced motion:** a setting that replaces the spin with a plain reveal.
- **The final screen:** every NPC's truth at once, the player's locked guess against the truth, then
  the score. The detail views (every lie, who told whom what) stay one click away.

## 7. Who would build what

- **Herald and Limner:** the overlay, the reel, the fakeouts and the pacing. It's presentation
  only, so golden doesn't move.
- **Lantern, with Quill:** the event graph and the falsehood-impact measure (section 3.2), on
  the belief and evidence side, run once at the end of a game.
- **Scoring** (its own note, in draft): the locked guess and the score lines share the final
  screen, so the two notes should agree on its layout.
  - DESIGN's "Private theory" rule (scoring the last copy before the outcome) is replaced by
    the last locked daily guess (section 2a). DESIGN needs updating to match when this is
    built.
- **Herald:** also the daily guess window (section 2a).

## 8. Open questions

1. **The threshold** for leading with a key deception rather than a chain or timeline. It's a
   tuning value, set by watching real reveals.
2. **The edge weights:** how strongly "confirmed" and "misled" links pull the walk, against
   falling back to time order.
3. ~~**The reel's style**~~: settled on Limner's card-based reel (section 2).
4. **Fakeout rules:** a fixed chance, or tied to how strongly the town believed the false
   role.
5. **Wording** of the key-moment lines and the lead line. It's player-facing, so it's
   Michael's; Herald drafts.

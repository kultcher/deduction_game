# Scoring (design note)

**Status: draft for Michael (Nov 21, 2026). Partly decided (section 9); nothing is built.**
Written by Claude-Vicar from a talk with Michael on Nov 21. It expands BACKLOG section 4,
"Scoring system" (`[open]`), and folds in that item's notes. The weights in section 5 are a
starting point to argue with.

---

## 1. Purpose and shape

- **Now:** a score at the end of each game, shown with the grimoire reveal.
- **Later:** score turns into progression (XP or similar), which gates unlocks: larger towns,
  new roles, player perks and abilities. That ties into the player toolbox. It's out of scope
  here.
- **The weights are arbitrary in absolute terms.** What matters is how they compare, and that
  they reward what DESIGN wants: the player building the case and leading the town, and
  reading misinformation. They mustn't reward stalling or flattery.

## 2. Principles

1. **Positive only.** Score what went right; never subtract. A bad game still ends with
   something earned. "Good Judgement" is a bonus, not a penalty for a wrong vote.
2. **Stalling mustn't pay.** Each extra day should cost about what it could earn (section 4).
3. **Reward the player's own deduction over what the game handed them.** Information the game
   confirmed publicly is worth less (section 3.3).
4. **Skill counts on a loss too.** Identification, catching lies and good cases score whether
   or not the Demon hangs. Only the outcome-based items need a win.
5. **General rules over per-role ones,** as in the rest of the design.

## 3. What scores

### 3.1 The outcome

- **Hanging the Demon:** the main objective, a win.
- **Each day left at the win:** the counterweight to stalling (section 4).
- **Each good NPC alive at the end:** win only.
- **Hanging a Minion:** on a win or a loss.

### 3.2 The verdict sheet

**There's no end-of-game sheet** (corrected by Michael, Nov 20). The scored verdict is the
last guess the player locked in a daily evil-team guess window, after a meeting and before
the execution result (section 9). It's scored win or lose, and it gives the reveal its moment:
the player's guess, then the truth. The rest of this section describes what that guess holds
and how it scores; "verdict sheet" below means the locked guess.
- **The Demon.** On a win this is effectively given, so its points come mostly from losses.
  That rewards "I knew, but couldn't get the town there".
- **Each Minion,** by person.
- **The evil types in play,** regardless of who holds which.
- **The burden:** who carries it, and which burden. Getting the Delusional right is a real
  read. This waits for the burdens work.
- **Partial credit,** from the backlog item:
  - naming a person as evil but with the wrong Minion type still scores, less than an exact
    match;
  - the 61251 example: Jory identified as evil but guessed as the Breathstealer.
- **No confidence marks** (Michael, Nov 20). The backlog item's sure-or-unsure idea is
  dropped.

### 3.3 "Loud" evils

Some evils confirm themselves through public events: the Breathstealer's silencing, the
Revenant's totem and curse. Naming an evil type that game events have already **confirmed
publicly** scores half, or nothing, against a type the player worked out. It's one general
rule for every loud evil, now and later. *Open: half or zero, and what counts as "confirmed
publicly".*

### 3.4 Bonus objectives

- **A successful ward:** the player's ward stopped a Demon kill.
- **A successful clemency:** used on a good person who would have been executed without it.
  The votes are known, so this is a counterfactual the game can check.
- **A good case:** scaled by how far it moved the town toward a truly evil person, as the
  change in the town's suspicion of its target that the case caused. Moving the town toward
  an innocent scores nothing. It doesn't lose points.
- **Caught a lie:** correctly called an evil fabrication or bluff, even if the town wasn't
  convinced.
- **Read the poison:** correctly called a reading Mistaken because it was poisoned or
  Delusional. It's a harder read than catching a lie.
- **Saw through a bluff:** exposed an evil's false gift or burden claim, with the
  counter-claim or contradiction on record.
- **Against the grain:** a case or nomination that turned the town when most of it believed
  otherwise. It rewards leading over following.
- **Kept the eyes open:** an information gift (Seer, Dowser, Night Watch and so on) survived
  to the end.
- **Last-day win:** won with three or fewer alive.

### 3.5 Flavour bonuses (small)

- **Man About Town:** talked to everyone privately.
- **Lay of the Land:** learned everyone's haunts.
- **Good Judgement:** never voted to hang an innocent. It's a bonus, because sometimes the
  player hangs someone for good reasons.
- **Well-liked:** NPCs ended up liking the player a lot. Kept small, so it doesn't pull play
  toward flattery over deduction.

## 4. Stalling, worked through

The risk: the player draws the game out to hang Minions before going after the Demon. The
fix is to make an extra day cost about what a Minion is worth:
- each day costs the early-win bonus for that day;
- each day probably costs one more night kill, and so one fewer survivor.

With the section 5 weights, a stalled day costs about 15 + 5 = 20, and a hanged Minion is
worth 20. Hunting a Minion breaks roughly even, while catching one on the way still pays.
This holds on a loss too, where Minion points still count but the early-win bonus is never
earned.

## 5. Starting weights (to argue with)

| Objective | Points |
|---|---|
| Hang the Demon (a win) | 100 |
| Each day left at the win | 15 |
| Each good NPC alive (win only) | 5 |
| Hang a Minion (win or loss) | 20 |
| Verdict sheet: name the Demon | 30 |
| Verdict sheet: each Minion named | 15 (partial for evil with the wrong type) |
| Verdict sheet: each evil type | 10 (half if publicly confirmed) |
| Verdict sheet: burden holder and kind | 15 |
| Bonus objectives (ward, clemency, caught a lie, read the poison, saw through a bluff, against the grain, kept the eyes open, last-day win) | 10–20 each |
| Good case | up to 20, scaled by how far it moved the town |
| Flavour bonuses | 5 each |

**A difficulty multiplier** on the total, by town size and script (more Minions, a
Breathstealer script, more burdens). Progression will be gated by score, so harder setups
should feed it faster, and it gives a reason to choose the bigger towns once they unlock.

## 6. Why the player lost

From the backlog item. On a loss, the reveal names the main reason, which also shapes what
the score sheet highlights:
- **a wrong read:** the player believed something false;
- **missed:** the information was there and went unused;
- **never available:** the information wasn't there, so nothing could have found it;
- **failed to persuade:** the player was right but the town didn't follow.

It needs a way to tell these apart from the game's record. That's the same machinery as the
grim reveal's "key misinformation" question; see the grim reveal discussion (Nov 21).

## 7. What it needs from the game

- **The sim already knows most of it:** the true roles, who was hanged, deaths, wards,
  clemency votes, readings poisoned or Delusional, and every lie with its logged reason.
- **New:**
  - the verdict sheet UI (Herald);
  - case influence on the town, which the judge already computes per case;
  - "publicly confirmed" flags for loud evils;
  - the counterfactual check for clemency;
  - a record of which calls the player made (lie, Mistaken, bluff).
- The backlog item also absorbs the removed voting prompt and the Scion credit rule.

## 8. Open questions for Michael

1. **The weights** in section 5, especially the Demon (100) against the verdict sheet's
   Demon guess (30). Should a loss with a correct verdict feel close to a win?
2. **Loud evils:** half or zero for a publicly confirmed type? What counts as confirmed?
3. ~~**Confidence on the verdict sheet**~~: dropped (section 9).
4. **The difficulty multiplier:** what goes into it (town size, Minion count, script
   features)?
5. **Good case:** measure on the whole town, or only on the voters who acted next?
6. ~~**"Why you lost"**~~: in the first version (section 9).
7. ~~**Shown how**~~: a total with a breakdown (section 9).

## 9. Decided (Michael, Nov 20, relayed by Seneschal)

- **Stage 1 shows right or wrong only,** with no points: the verdict sheet against the truth.
  The points come later.
- **When scoring arrives, it shows a total with a breakdown.**
- **"Why you lost"** (section 6) is in the first version.
- **No confidence marks** on the verdict sheet.
- **The daily evil-team guess is the verdict** (corrected by Michael, Nov 20). Each day,
  after the meeting settles and before the execution is announced, the player can guess the
  evil team.
  - **There's no end-of-game "Seal my verdict":** a chance early hanging of the Demon would
    be spoiled by it. The last locked daily guess is scored. No window opens when a game ends
    overnight.
  - **Guess changes are limited,** so that naming whoever is about to hang isn't the best
    play. Herald is proposing the count.
  - **The profile's Demon and Minion marks** prefill the window, greyed out, for the player
    to change or confirm.
  - This replaces DESIGN's "latest pre-outcome copy" rule.
  - The full design is in
  [grim_reveal.md](grim_reveal.md#2a-the-daily-evil-team-guess).
- **Seneschal's small calls,** which Herald may flag:
  - there's no burden guess until Burdens ships, so the sheet's burden line (section 3.2)
    waits.

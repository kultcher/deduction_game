# Open design questions: an index

Kept by Claude-Vicar. **As of Nov 17 (secrets added later the same day), from `main` at `6873616` plus the open PRs #174, #180
and #182, which add backlog items not yet merged.** This is an index, not a record:
each entry says what's open, where the evidence is, and who would build it once Michael
decides. The record stays in `BACKLOG.md` (items and tags) and `DESIGN.md` (how things work
and why). When Michael decides one, it's recorded there with the date, and it comes off
this list.

Owners: **Lantern** beliefs; **Beadle** NPC behaviour (what NPCs say, do, vote, lie
about); **Quill** evidence, challenges and the judge; **Herald** UI, dialogue,
onboarding; **Argon** performance; **Tally** sweeps (on request).

---

## 1. Live threads (raised in the last few days)

These are the ones under discussion now, roughly by how much they shape other work.

### 1.1 The Breathstealer overhaul
- **Open:** what silence should do. Today a silenced person is proven good (the
  Breathstealer only silences the good), and the role measures as a net gift to good.
  Options on the table: (a) it may silence a teammate as cover; (b) silence is quiet
  (unannounced, the victim stonewalls with a small tell, evil can feign it); (c) both; a
  good secret that inflicts the same silence (a vow, a sore throat); silences that skip
  days. Michael (Nov 17) wants a thorough rework before any more tuning.
- **Folded in:** the judge lets a silencing victim be the Breathstealer (Quill, 26532 case
  #90). Fixing it alone made the case against Isolde 92–98% for every listener, and also
  pushed the town onto Isolde before any case was presented, so it isn't a pure bug fix:
  it strengthens good and changes how much the player is needed.
- **Evidence:** Breathstealer deals favour good by 18–32 points; an inert Minion does 10–19
  points better for evil; the "silenced, so likely good" factor is 40–45% of the gap at 10
  NPCs; lasting silences barely help evil. `docs/archive/project-docs/inert-breathstealer-sweep-2026-11-15.md`,
  BACKLOG section 4 (#180), Quill's entries on #173 and #177, Bailiff's final handoff
  ("Open questions"). Unanswered: did the Demon and the Breathstealer double up on targets
  (`tools/breath_stats.gd`, sweep `breath_*` fields)?
- **Builds:** Beadle (whom it silences, how the silenced behave, evil feigning) and Quill
  (what the judge infers from a silence). Herald for any silence tell.

### 1.2 Secrets: a rework (the Muddler folds in)
- **Open:** how secrets should work. Michael (Nov 17): disclosure is inconsistent (three
  are hidden from their holder, the Lovers claim at will); a confirmed secret is a
  confirmed good, so they don't help evil hide; and they leave out good people with
  reasons to lie. Direction so far: secrets stay riders on a gift; most become something
  the holder knows but doesn't volunteer; evil can bluff them; a Saint as the worked
  example. **The Muddler is tentatively cut** (it had something to muddle in 5 of 40
  games).
- **Proposal on the table:** the judge keeps one slot for the self-unaware kinds (Marked,
  Delusional, Sleepwalker); the kinds the holder knows about become ordinary claims, with a
  per-case hypothesis so the player can argue an unclaimed one.
- **Evidence:** `docs/design/secrets_rework.md` (the options, costs and the Saint and Baron
  examples); BACKLOG section 4 for the Muddler (#180).
- **Builds:** Lantern and Quill (the judge), Beadle (claiming, hiding, bluffing), Herald
  (wording). Argon to time it, Tally for the Lovers' win rate.

### 1.3 What Insight does in belief
- **Open:** Insight was taken out of belief for v1 by the connections model. After the
  purge removes the headline reading, Insight only sets how many cards an NPC cites and how
  fast they fade from its attention. Seneschal's brief says Michael approved **Option A**
  for Insight's new role and that it is being measured; **neither the option nor the
  measurement is in the repo yet.** The written candidates are "one dial: the core
  threshold, or a second ring" (`docs/belief_model.md`, "Insight is out for v1").
- **Also open:** DESIGN's Insight row needs new wording (purge plan, decision 6: Lantern
  drafts it in phase 8, the wording is Michael's).
- **Evidence:** `docs/belief_model.md`; `docs/connections_purge_plan.md` sections 7–8 (#174).
- **Builds:** Lantern.

### 1.4 Tunnel vision: persistence Confidence `[tentative]`
- **Open:** whether to bring back a working theory that colours new evidence. A listener
  committed to a theory (high Confidence) let moderate contrary evidence slide; a
  low-Confidence one revised. It fits "simulate a human mind", but the connections refresh
  never read through a theory and live play didn't use it, so it is deleted in the purge.
  The questions: does it belong in the connections model, at what strength, and does it
  make NPCs sheep-like or stubborn in a way the player can work with?
- **Evidence:** BACKLOG section 6 (#182); code on `archive/legacy-belief-final` once the
  purge pushes it.
- **Builds:** Lantern.

### 1.5 Spillover damping `[tentative]`
- **Open:** whether a presented premise should shape its own cards' effect again (the
  premise's target takes the full effect, bystanders 40–80% by Insight). Under connections a
  case moves bystanders only through its own cards. Revisit if presentations move
  bystanders too far in play; it would tie into 1.3 if Insight comes back.
- **Evidence:** BACKLOG section 6 (#174); `docs/premises_plan.md` step 1.
- **Builds:** Lantern.

### 1.6 Are unlimited vigils too strong?
- **Open:** a vigil on the right block can catch the Demon outright (playtest 26532; also
  54875, where a vigil on the first kill block caught both walkers on nights 1 and 2, "near a
  free Seer reading"). Options discussed, none chosen: a vigil costs the next morning's
  action (Claude's earlier favourite); vigils limited like the ward; a vigil shows only a
  count of people on the block; watch one spot, name anyone there, count the rest of the
  block.
- **Related open question in DESIGN:** does the Lamplighter's every-block route make that
  gift too easy to confirm, now that nobody else passes through a block?
- **Evidence:** BACKLOG section 2, Numbers ("Unlimited vigil strength", `[watch]`); DESIGN
  "Open questions"; 26532 itself isn't written up in the repo (Michael has the log).
- **Builds:** depends on the option. A cost or limit is player actions (Herald for UI,
  game flow); a count-only vigil changes evidence (Quill). Tally for a sweep.

### 1.7 Onboarding and tutorials (waits for mechanics to settle)
- **Open:** when mechanics are settled enough to start, and the shape. The decided
  direction is three layers from one data registry: tooltips and terms; an in-game field
  manual; a guided 7-NPC tutorial case on a fixed seed. Layers 1 and 2 are UI and data only
  and could start any time; layer 3 waits.
- **Evidence:** BACKLOG section 4, "Learning resources" (`[decided: direction]`); DESIGN
  "Teaching"; `docs/migration_notes.md` (Michael, Nov 16: onboarding after mechanics
  settle).
- **Builds:** Herald.

### 1.8 Evil's blind spots in its own lies
- **Decided (Nov 16):** evil checks a fabrication against the public cards, and a liar who
  notices (Insight roll) reworks or holds it. Beadle builds it.
- **Still open around it:** the role-local bluff gaps Beadle found (a lone Clerk or
  Rumormonger vouching for "a teammate" names itself; the Magistrate bluff saying
  "different" when both are evil; the Surveyor's 65% "not the same"; a Monitor bluff naming
  an evil role); a bluffer's frame memory (later readings stay consistent with whom earlier
  ones implicated); one pass over every bluffer for the "too clean when an ally is
  involved" tell. All change evil's play, so they wait for Michael.
- **Evidence:** Beadle's #175 entry; BACKLOG section 5.
- **Builds:** Beadle.

### 1.9 Smaller live calls
| Question | Where | Builds |
|---|---|---|
| Honest mistakes against lies in challenges: "misled" lands 3–12% on honest mistakes, and to a listener the cards are the same. Pursue evidence that separates them (teller's history, signs of poisoning)? | BACKLOG section 6 `[open; Michael]` | Quill |
| Purge phase 6b: the four places attention still feeds belief on a refresh. Measured first, then Michael decides | `docs/connections_purge_plan.md` (#174) | Lantern |
| The Hexer: the declaration's default ("walker"?) and the bot's Hexer call (54% right). On hold until Michael plays two-kind scripts | BACKLOG section 4; Bailiff's final handoff | Quill (bot), Herald (UI) |
| Is the 10-NPC connections gain real? +5.7 on 300 seeds (z +1.9); a 1,000-seed cell would settle it | Bailiff's final handoff | Tally |
| Storing an NPC defender's challenge as a case, so defences work for both sides `[deferred until after connections]` | BACKLOG section 5 | Lantern, Beadle |
| Presenting a card to one NPC: a case, or a card with a defined interaction; secret awareness and how evil claims a secret | BACKLOG section 2 "Secret awareness and bluffing", section 5 `[design]` | Beadle, Herald |

---

## 2. The standing list: other `[open]` items

Older open items, grouped. One line each; the BACKLOG entry has the detail.

### Evidence, cases and the judge (Quill unless noted)
- **Say what a card is offered for** ("about Constance's alibi"), so a sighting's collateral
  doesn't land on everyone it places. Changes how evidence counts.
- **Withdraw or revise a case** believably, without scoring below the version it replaces.
  Pairs with signposting the way back from a wrong "lying" call (`[decided: test later;
  signposting open]`). Herald for the UI.
- **Quiet-night evidence argued by the player** (protection + quiet night + sighting).
- **Misled versus lying strength** at equal weight.
- **Medium relays:** who is blamed when a relay is challenged; challenging the transmission
  versus the dead source; nested relays. Beadle for the social side.
- **The sighter contest cap** and **an evil Medium's night-0 relay**: known bugs in the judge
  that move golden, waiting on a call (BACKLOG section 6). Lantern.
- **Trace weight** (3:1 against 1.5:1 and 2:1); **the Seer's rise looks small**;
  **situational credence modifiers** (early disclosure, a quiet night, admission against
  interest, consistency). Tally to measure, Lantern to build.
- **Demon detours** exist in inference but not in movement: which is authoritative?
  Lantern (inference) and Beadle (movement).

### NPC behaviour (Beadle)
- **Accusations from starting suspicion read as clues** (13910). Idea: keep a floor, and
  let one speaker voice unease without pressure. `[open; Michael to decide]`
- **Kill-score pass on every role** (whom the Demon targets).
- **The Gravedigger in a reluctant town** pushing for a hanging.
- **Lovers as an excuse** (evil faking a Lovers confession; the solver's proof must go if so,
  Quill).
- **Good NPCs lie tactically** (stretch). **Lie severity.**
- **NPC-to-NPC credibility** (liking versus believing). Lantern for the belief side.
- **Throw a teammate under the bus**; **evil coordination you can see**; **trust dynamics
  around sources** (naming a source; evil tracing one).
- **Storyteller-driven Medium visits.**

### World, evidence types and structure
- **Locations as evidence, from both sides**; **passing through versus stopping**;
  **evidence chains**; **the demon lures a victim elsewhere**. Quill (evidence), Beadle
  (movement).
- **Ways to discover and confront secrets**; **named corroborators in alibis**. Beadle,
  Quill.
- **Role hints from workplaces and haunts.** Quill.
- **Relationships** (Bonded, Unrequited, Feuding, Hater). Beadle, Lantern.
- **Roster expansion** (On Deck gifts, minions such as Framer/Forger and Blackmailer, the
  Debtor secret, Demon resilience). Each needs a hint package and solver support. Quill
  and Beadle.
- **Player toolbox** (Autopsy, Séance, Scry, Binding circle; exorcism as an alternate
  win); **scoring**; **the Storyteller/director and solvability check**. Design first.
- **Talking to a group** (3 questions per phase, split). Herald, Beadle.

### Presentation (Herald)
- **Case board visuals** (`[decided: needed; design open]`); a claims and reveals timeline;
  free-floating panels; long dropdowns (`[tentative]`).

### DESIGN.md's own open questions
- How many clues per day feel right (1 or 2 player actions per phase)?
- The persuasion economy beyond trust (how pressure sours NPCs).
- (Vigils and the Lamplighter route are in 1.6.)

---

## 3. `[tentative]` tuning candidates

Proposals for one unified social retuning, not approved (BACKLOG section 2, "Tentative
social tuning"; plus 1.4 and 1.5 above). Lantern for belief, Beadle for behaviour.

- Privacy without compounding trust penalties (54875: three of three stonewalled on day 1).
- Evidence building NPC-to-NPC trust.
- Opinion strength and shared origins (several NPCs repeating one story aren't independent).
- Martyr urgency from day 3.
- Demon victims' earlier information read as sincere.
- Dowser clearing only on a positive ping.
- Expanded dialogue and trust management (requests spreading through chats, follow-through,
  guilt, "what would change your mind", apologies). Herald for wording.

---

## 4. Notes for Vicar's own work

- `DESIGN.md` still describes the earlier belief model as current in its NPC-minds section
  (bounded attention, Insight-scaled spillover, "swayed by headlines"), and doesn't describe
  the connections model (Lantern's final handoff). Bringing it up to date is the first
  DESIGN.md job, after Michael settles 1.3, so the Insight row is written once.
- DESIGN's "Decided and open directions" sections and BACKLOG's tags have drifted in
  places (DESIGN lists "Lie severity" under decided with an `[open]` tag). Reconcile in the
  same pass.

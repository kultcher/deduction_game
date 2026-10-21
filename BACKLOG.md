# Demonologist backlog

The single to-do list. It gathers the deferred and open items from DESIGN.md, the
role_exploration On Deck list, the Project notes and playtests 13473/55774. Items are
sorted by effort. DESIGN.md stays the record of how things work and why.
Tags: **[decided]** = direction agreed, ready to build; **[open]** = path not chosen yet;
**[watch]** = no change, keep an eye on it; **[knob]** = not planned, a balancing tool to
reach for only if needed. Settled, built and parked items move to **Closed** at the end. Source in parentheses where useful. Exploratory mechanics
(new roles, places, ideas still being shaped) live in role_exploration.md.

---

## 1. Bugs and quick fixes (hours, low risk)


## 2. Small features and tuning (a day or so each)

### Deduction types and templates
- **Starting secret-count card.** Generate a public setup card stating how many secrets
  are in town. Decide whether the count means modifier types, holders (Lovers count
  twice), or includes ordinary personal secrets; do not expose assignments. (61251/25923)
  [decided: card; count definition open]
- **One evaluation path for generic and structured cases.** In 25923, vigil sighting
  #86 + death #87 (Nisha at Merrin's murder block that night) had no template, while
  the generic support sum capped at 1.0 agreement. `trace_match` is specifically an
  evening trace + evening presence, and faces competing explanations. Add the missing
  night-sighting + murder relationship (the death assertion also needs its location)
  with the broader fit-check work, so recognizing a case cannot make it weaker. [decided]
- **Independent support versus repetition.** The ledger currently takes the strongest
  justification for a conclusion. Preserve duplicate-evidence suppression, but let
  separate nights and independent sources build a cumulative case. Tie this to the
  repeated-trace item below and the belief/action split, rather than raising every
  suspicion increment. (61251) [decided]
- **Template generalization** (now part of "Cases instead of proofs" in section 4: one fit check per evidence type;
  originally: one translation table per role, so pair elimination
  etc. work for any gift that makes the same kind of statement). (DESIGN, deferred to
  roster expansion) [decided]

### NPC behaviour
- **Secret awareness and bluffing.** Lovers' existing confessions now carry a usable
  secret type and can explain night movement. The same card/interpretation format can
  represent a reported Marked secret, but no spontaneous Marked confession is added:
  decide whether holders know they're Marked, how one asks about it, and how evil can
  claim it too. Currently only Lovers have an explicit modifier-confession path. Keep
  these as attributed claims, not hard alignment confirmations. (61251/25923) [open]
- **Nisha's reticence.** 25923 used Gossip 0.11, Privacy 0.60, Trust 0.38. The shared
  gossip rule returns zero below Gossip 0.20 unless pressure reaches 0.50; her pressure
  stayed around 0–0.21. This explains repeated refusals without an evil-only penalty.
  Consider a softer minimum-information policy separately from the bug fixes. [watch]
- **Believable public revisions.** Let the player withdraw or revise an earlier case,
  while NPCs may retain reasons they still believe. In 25923 the final Nisha nomination
  cited the player's earlier argument after the player had adopted a different world.
  Private guesses must remain private. [open]
- **Quiet-night evidence.** Sightings outside an actual murder scene currently get
  only 0.12 of normal weight, including failed attacks. Support a player-argued link
  between protection, suspected attack and movement without exposing hidden attacks.
  In 61251 the successful Fenwick ward suppressed the apparent value of the sightings.
  [open]
- **Vote resistance feedback.** Distinguish disbelief from execution priority and
  distrust of the player. In 25923 the -0.4 preference for Lian already on the block
  stopped several good NPCs voting for Nisha despite substantial suspicion. Revisit
  with meeting/vote talk; do not turn every plausible alternative into inaction. [open]
- **Evil vote stakes beyond the Demon.** Cover can no longer cause an evil NPC to
  nominate/vote for the Demon. The existing pivot heuristic still considers only
  votes already cast for other nominees. Future tactical bussing (including any
  deliberate Scion succession) needs remaining-voter estimates and a team-benefit
  policy; preserve ordinary minion bussing meanwhile. (25923) [open]
- **Outcome attribution.** Separate identifying evil alignment, identifying an exact
  minion gift, and making a useful execution. 61251 correctly identified Jory as evil
  but guessed Breathstealer; executing the Revenant turned the last good NPC. [open]
- **From playtest 61251** (an evil team the player had identified won anyway). [decided]
  - **A proven lie should hurt an info claimant's credibility hard.** Constance (the
    Breathstealer bluffing Seer) was caught in an off-route lie on day 2, and listeners
    still credited her at about 90% (from 94%). Her fake "yes" readings then hanged Lian
    (+3.1 suspicion across the town) and Edda (+2.6), and a fake "no" cleared the demon.
    A proven whereabouts lie by a public info claimant should cut their readings to
    around 50% credibility. This turns "lie severity" around: the lie itself was minor,
    but it says the claimant's readings can't be trusted.
  - **A Seer's record.** Each "yes" pair that's hanged and shown good (by the
    Gravedigger, the Martyr, or a public clear) should discount that Seer's later
    readings, not just add red-herring talk. In 61251, Lian was shown to be the Warden,
    but only the Gravedigger updated (−0.4), and he was killed that night.
  - **Repeated trace matches add up.** Three kill nights in a row had a trace on the
    Docks with Greta there each time. Each was judged alone ("more likely someone else
    on the Docks"), at about 0.3 agreement. The same suspect matching across several
    nights should compound. This is a natural first test case for the theory and fit
    checks (section 4), and the same shape as the Breathstealer-by-presence pattern.
  - **The player's voice in votes is small at ordinary trust.** At trust 0.3–0.5, "the
    player accuses" added only 0.05–0.14 to votes, while non-template cases got 0.19
    agreement. This is the execution-priority idea (section 4) applied to the player's
    own nominations.
  - **Not the cause:** a failed nomination costs trust only with the nominee (−0.15).
    There's no town-wide penalty, so the early lark nomination of Bart didn't cascade.
    Worth confirming in a conservative playthrough.
- **Offering protection eases fear.** Someone you've offered your ward or a vigil (and
  kept your word to) should be less afraid to say what they are. (96773) [decided]
- **Backing a strong case builds trust.** Nominating or voting for someone the town
  strongly suspects (and who turns out evil, or is widely believed so) earns a little
  trust from the NPCs who agree. It's what makes throwing a teammate under the bus pay
  for evil, and it rewards good NPCs who stick their necks out. (Oct 19) [decided]
- **The fearful ask for protection.** NPCs afraid their gift makes them a target appeal
  to the Demonologist (a ward, a vigil) and/or the Warden for protection, instead of
  only clamming up. Ties into offers easing fear. (Oct 19) [decided]
- **More talk in town, especially in bigger towns.** 96773 (10 townsfolk, 4 days): 7
  conversations, 7 shares; three conversations passed nothing on, and one pair swapped
  the same sighting back and forth. Scale conversations with population, let each pass
  on the one or two most newsworthy things the other hasn't heard, never echo back what
  you were just told. Check with bot runs. [decided]
- **Evil backs into a bluff.** Like the scapegoat switch: an evil NPC that hasn't
  claimed yet can change its planned bluff when another gift would serve better, if no
  one has claimed that gift and it would build a frame or deflect suspicion. Example: the
  Poisoner planned to bluff Seer but is seen out at night, and nobody has claimed Night
  Watch, so it claims Night Watch. This opens the door to double claims (the real Night
  Watch may just be quiet), which need their own logic: a classic of the genre, needed
  eventually. Once double claims are handled, fake Mediums (and evil generally) can also
  make bolder lies: fake readings in gifts the dead never claimed. (Oct 19) [decided]
- **Storyteller-driven Medium visits.** Today the Medium visits the most recent dead it
  hasn't visited (demon victims first). Eventually: "I was called to Hollis's home to
  commune with his spirit", chosen by a director. (Oct 19) [open]
- **NPCs push back on nominations their own information contradicts** (a player-led
  nomination of the true Seer passed 7/8). (DESIGN playtests) [open]
- **Lie severity:** a false gift report weighs more than a whereabouts lie, unless the
  lie puts them near the crime. NPCs who accept a lie but won't hang should say so.
  (DESIGN) [open]
- **Evil reads as evil:** evil casting aspersions with no information stands out; give
  good NPCs reasons (grudges, secrets) or make evil hold back. (playtest 30294) Largely
  addressed by the shadow self (evil's replies now differ from the good crowd's about
  twice as often as good's own disagreements, down from about five times); revisit
  after playtests. [watch]

### Numbers
- **Unlimited Vigil strength.** (DESIGN open question) [watch]
- **Situational credence modifiers** still to settle: early disclosure, quiet night
  as a credence boost, admission against interest, consistency over time,
  role-specific confirmations. (DESIGN) [open]
- **Offer trust** (+0.03 offer, +0.06 kept, -0.15 broken): first guesses, tune from
  play. [watch]

### UI
- **"Stayed home" vs "none of your business"** on the sightings/claims boards. [watch]
- **From Playtest Notes 12553**, still unclear or unchecked: pin cards to the main
  view; people who aren't talking or working showing on the map; a wrong role guess
  blocking process of elimination.
- **Card zoom and text extension.** Settle card sizing, clipping and zoom/detail
  transitions before extending rich text onto board cards, pinned deductions, the
  tray and Card List. The shared formatter, log and profiles are built (steps 1–3);
  steps 4–5 are deferred. Card List/working-set rows are wrapping Godot Trees with
  one colour per row; richer rows still need custom cells or replacement controls.
  See [the handoff](docs/text_system_handoff.md) for hooks, issues and alternatives.
  [decided: extension deferred; renderer approach open]

## 3. Medium features (several days; touch a few systems)

- **Rebuttals and excuses.** Someone accused explains with their gift ("I was out
  because I'm the Lamplighter"; own-lie admissions are built), which buys some grace with listeners; evil without a
  fitting bluff can claim a fake secret. Biggest open hole: hidden night walkers frame
  themselves (Isolde 55774, Constance 96773; Lamplighter/Veteran/Sleepwalker/Warden hang rates). (DESIGN)
  Now part of the meeting-flow plan (docs/meeting_flow_plan.md, step 2). [decided]
- **Trust dynamics around sources (later).** A relayer may name their source outright,
  at the cost of that person's trust; and evil may try to trace an unnamed source ("the
  Seer told me") back to a person, to kill or frame them. (Oct 19) [open]
- **Last words.** A condemned NPC gets some final words before the hanging (flavour). (Oct 19) [decided]
- **Nominations make a case.** The nominator cites several cards, even weak ones.
  Mostly flavour; it only moves NPCs if it brings new information. [decided]
- **Meeting and vote talk** (returns with the rebuttal work). Votes are silent for now;
  PR #3's vote explanations were removed. When vote talk comes back: evil voters must
  draw from the same spread of reasons as good ones (in PR #3 they all said "the case is
  strong enough"), and only lines that tell you something should be spoken (a reason
  that differs from the crowd, a vote against a stated stance, a swing vote). [decided]
- **Fading into the crowd.** NPCs weigh how much talking is already going on before
  speaking or disclosing. When the town is already moving in a direction, a private
  character may just bide their time and listen. (Oct 19) [decided]
- **Outing yourself to defend someone.** The flip side of the accusation tiers: when an
  NPC holds information that could clear someone on the block (a Seer "no", a Night
  Watch who saw them stay in), when are they willing to come out to defend them? The
  same weighing as accusing (how strong the clearing is, what the reveal costs, how
  close the vote is). (Oct 19) [decided]
- **Talking to a group:** 3 questions per phase, split among anyone at the spot.
  [open; discussed 2026-10-18]
- **Revenant seeks execution** (draws suspicion on purpose) and **NPCs search for
  totems.** Today the Revenant is often invisible (55774). [decided]
- **NPCs find evidence and personal items** (dropped items, traces). [decided]
- **Lovers downside:** when one dies, the other becomes withdrawn: Privacy to max,
  Gossip to min, and whichever other shifts hurt the player most (e.g. Composure up so
  they're harder to read). Visible, so the player can notice the change. [decided]
- **Ways to discover and confront secrets:** sightings that don't fit, confidants,
  personal items, a "you have a secret" card used as leverage. (DESIGN) [open]
- **Named corroborators in alibis** ("I was with Jory"), word-against-word cards; evil
  fake secrets that name someone they really met. (DESIGN) [open]
- **Evidence chains:** a trace leads to a second clue at the killer's evening spot.
  (DESIGN, open since playtest 1) [open]
- **Evil coordination you can see:** daytime evil meetups, with friends and Lovers
  meeting too as noise. (DESIGN) [open]
- **Throw a teammate under the bus:** a pressured minion distances themselves from the
  demon; the demon goes along with town conclusions to build trust. (DESIGN) [open]
- **Claims/reveals timeline** next to the location timeline. (DESIGN) [open]
- **Dialogue voices for the rest of the cast.** The composer is merged (Agnes,
  Bartholomew, Constance × five situations; dialogue lab at `ui/dialogue_lab.tscn`).
  Everyone else uses the plain lines until they get a voice. [decided, later]
- **Bot coverage of the new talk options:** the bot doesn't offer wards or vigils or ask
  about others to learn haunts, so bot runs don't measure them. [decided]
- **Evidence-reading bot.** The bot ignores traces and dropped materials entirely (and
  peeks at `w.dropped` when deciding to search), so bot win rates say nothing about
  physical evidence. Teach it to read traces and drops, and stop the peek, to measure
  what evidence is worth. [decided]

## 4. Major structural work (a week or more; design first)

- **Cases instead of proofs: the player argues a theory** (Oct 19–20 discussion; next up
  after the usage reset, ahead of meeting-flow step 5). [decided, design first]
  - **The problem:** deductions are "these cards prove this", gated by templates. Most
    Clocktower reasoning is cumulative and probabilistic, so a strong case like "Seer
    pair + near a murder + caught in a lie" gets filed as a weak "your inference". The
    space of evidence interactions is too large for templates, and some that fit are
    unintuitive to build.
  - **The direction:** the player proposes a theory, which can be partial:
    - the demon candidate and the suspected evil;
    - optional assumptions ("Edda is the red herring", "Constance's reading was
      poisoned").

    The game scores each card on how well it fits that theory: supports, contradicts,
    or doesn't bear. This answers the question the evidence poses (the Surveyor's "3":
    mark who the evil are, and see if the count fits).
  - **One fit check per evidence type** instead of templates for pairs:
    - Surveyor: N blocks with an evil resident;
    - Seer yes: the demon, the red herring or a Marked person is in the pair;
    - Dowser and Hearthwitch: N evil among a group;
    - Archivist: one of two is that minion;
    - Gravedigger: the hanged person was that role;
    - sightings near deaths: soft fits.

    Partial theories need "fits / could fit / contradicts" (is the count still
    reachable?). Demon victims count as good by default, so a Surveyor check includes
    the dead without extra steps.
  - **Against flooding the zone:** score fit weighted by how surprising it is.
    Irrelevant cards add nothing, loose fits little (a Surveyor count fits many
    theories), tight fits a lot (a Seer yes on the pair), contradictions cost.
    Same-source cards count once. Every assumption weakens the case by the listener's
    doubt in it.
  - **NPCs judge the player's theory; they don't search for theories.** Each listener
    checks it against what they know, at their own credibility weights, and answers two
    questions: does it make it more likely (belief), and is it enough to act on
    (execution priority: urgency, trust in the player, counterevidence)? An accepted
    assumption can become a working belief that later arguments build on, and it's undone
    if it collapses. That keeps the player as the detective and NPCs persuadable and
    plausibly wrong (accidental misdirection and deliberate manipulation, such as
    getting someone hanged for a Gravedigger read, both still work).
  - **Keep:** templates, now as bonuses for rigorous links rather than gates; the evidence
    ledger; cards; provenance; the shadow self. The per-card weighing that private cases
    already use is the starting point for scoring.
  - **Bonuses:** a supports/contradicts view of the board is a strong player tool on its
    own. The private-theory panel (demon and minion guesses) is the natural entry point.
    The bot can use the same checks.
  - **Where it plugs in:** the player's turn in the meeting flow becomes "make a case".
  - **Considered and not chosen:** Astra's full competing-hypotheses rework (every NPC
    tracking demon, minion, red herring and Marked beliefs for everyone). It's sound,
    but it makes NPCs better reasoners, which is the wrong direction, and it's a large
    open-ended core rewrite. Revisit only if playtests keep pointing at "one suspicion
    score" problems, and then as a log-only prototype first.
  - **Related cheap idea, can come first:** an execution-priority term in nominations and
    votes. A credible lead (a Seer yes, a trusted player's case) makes a target
    actionable without inflating belief, scaled by urgency.

- **Pattern-based cases.** Alongside existing deductions, build a case from many
  cards, without the three-card limit: repeated encounters, conflicting stories, or
  other patterns. Offer small observation cards automatically ("Bart was near a
  silencing"), then let the player name a suspect and a role or explanation. Show
  support, counterevidence, gaps, and other people who fit. Unknown whereabouts are
  not an alibi; retellings and observation cards don't count the same evidence again.
  NPCs weigh what was actually presented plus what they know, considering sources
  and alternatives, and explain their response. Reassess when evidence becomes
  doubtful. Use plain-language strength, not exact odds. Prototype one pattern first,
  initially reporting assessments without changing votes. Breathstealer contact is
  one example, not the scope; use actual possible action times (currently any daytime
  phase, with silence starting at the meeting). [decided: prototype; broader design
  open; discussed 2026-10-19]
- **Night movement and trace model.** One package of related items:
  - the deferred night-proximity rule for sightings (route from home to the death
    block);
  - the proposed route limit (home → at most one detour → victim);
  - traces based on where the killer *started* rather than their evening block (this
    fixes the evening-shift demon problem);
  With every block joined, a walker is seen only at home (leaving) or at their
  destination, so "passing vs stopping" mostly collapses into "seen on their own block
  (they went out)" vs "seen elsewhere (where they went)"; homes are what tells the two
  apart.
  When this is settled, check whether the home cards and haunt cards still earn their
  place (with every block joined, a route is just home → destination and homes may say
  little a template needs); remove them if not. The
  evidence-chain item, and the watchtower idea in role_exploration.md, depend on this
  package. (DESIGN) [open]
- **Locations as evidence, from both sides.**
  - A Dowser's "on the Market I sensed 1 evil among A, B, C" places the Dowser and the
    group on that block on the timeline ("ability" marks), but it isn't a location card:
    it doesn't take part in corroboration or the two-places contradiction. So the player
    can't use it to show a (fake) Medium or Dowser wasn't where they said.
  - Your own visit excludes people. Being at a spot shows everyone at that spot (and the
    other spot on the block), so anyone not seen wasn't there that phase. Hearsay can't
    do that. Caveat: people at home on that block aren't shown. A "not there" fact from
    the player's own presence would let templates rule people out.

  Low impact while most suspicious activity happens at night. (Oct 19) [open]
- **Passing through vs. stopping** (potential movement overhaul direction). Sightings say
  whether someone was passing through a block or out on it (their destination). Two
  "out on" sightings on different blocks are a real contradiction; "passing through"
  fits a route. Open: who can tell the difference (street observers and vigils, not
  window glimpses), and the wording ("heading toward the Docks" vs "out on the
  Docks"). Destination sightings on a kill night overlap with the night-proximity rule,
  and it makes vigils stronger. [open]
- **Breathstealer confirms the good.** It only silences the good, so a silenced person
  is proven good, and the role's visible effect becomes a gift to the town. Options:
  (a) the Breathstealer may silence a teammate under suspicion, as cover (a strong evil
  play; silence becomes "probably good"); (b) silence goes quiet: not announced; the
  victim volunteers nothing and stonewalls direct questions, with a small tell you can
  see in private ("…opens her mouth, then shakes her head"); evil can feign it; (c) both.
  [open; see 96773 discussion]
- **Breathstealer ambiguity, two more routes** (for the Breathstealer decision above):
  - a good secret that inflicts the same silence (a vow, a sore throat), so a silence
    isn't proof of the Breathstealer or of the victim's good;
  - make the Breathstealer's silence optional (it may skip days), which also explains
    why the secret's silences come on some days and not others, for maximum
    dastardliness. (Oct 19) [open]
- **Relationships:** Bonded, Unrequited, Feuding, Hater (role_exploration).
  Relationship mods for the Lovers live here too. [open]
- **Roster expansion:** On Deck gifts (Tracker, Clairvoyant, Beckon, Tallyman…); minions
  (Framer/Forger with evidence planting, Blackmailer, Hexer, Informant); Debtor secret.
  Each needs its hint package and template coverage. [open]
- **Player toolbox:** Autopsy, Séance, Scry, Binding circle; demon types with bestiary
  entries; exorcism / true-name alternate win. (DESIGN) [open]
- **Scoring system:** identification credit, accuracy of guesses with confidence, why
  the player lost (wrong read / missed / never available / failed to persuade). Absorbs
  the removed voting prompt and the Scion credit rule. [open]
- **Storyteller/director and solvability check:** poisoned readings become arbitrary
  (chosen plausibly) rather than inverted; check that a case can be solved. (DESIGN)
  [open]
- **Procedural town:** blocks, buildings and roads generated per case. (DESIGN) [open]
- **Larger towns (12–15):** only after the core loop works at 7/10. [watch]
- **NPC memory and recency bias.** (Random ideas) [open]
- **Dead NPCs:** no ghost votes for now. (DESIGN, deferred) [watch]

---

## Template gaps (NYI)

A running list of patterns that come up in play, or that the mechanics make meaningful,
but that no link template recognises yet. Add to it whenever a playtest log shows
"no template matched" on a combination that should mean something.

- **Succession breaks earlier clears.** A Seer "no" (or any not-the-demon clear) only
  speaks for the demon *as of that night*. If a hanging with 5+ alive (so a Scion could
  rise) falls between two readings, group elimination, overlap and pair elimination
  must keep "X became the demon afterwards" as an explanation instead of "the earlier
  reading clears the rest". In 55774, #150 cleared Edda from Agnes's night-5 "Greta or
  Edda" using the night-4 "Fenwick or Edda: neither", across Hollis's hanging. Greta
  was right, but Edda (evil, an equally possible successor) stayed a live candidate.
  NPC reasoning and the bot should apply the same limit to old clears. (Astra, 55774)
- **Same person in repeated Seer yeses, later proven good** → that person is the
  red herring; drop them from the Seer's later readings. (55774: Jory)
- **Evil reading on a proven-good person** (Dowser count, Archivist pair) → Marked.
- **Minion gifts in templates.** The builder can now conclude "X is the Breathstealer /
  Poisoner / Revenant / Scion", but no template reasons toward a minion: e.g. someone
  silenced, and the people seen on their block that evening (the Breathstealer has to be
  there); a reading that failed on a night someone was near the reader's home (the
  Poisoner's visit); a totem found and the people who live where its material is from
  (the Revenant). Needs "silenced" and "totem" facts that templates read.
- **Breathstealer by presence:** someone silenced, and who was on their block that
  evening (the Breathstealer has to be there); over several silencings, the one person
  present each time. (96773: Bartholomew was nearby for each.) Needs "silenced" facts
  with where the silenced person was. Depends on the Breathstealer decision below.
- **Night companions of the proven evil:** out on the same block on the same nights as
  someone proven evil (a Gravedigger-confirmed Poisoner) → likely their teammate. 96773:
  Hollis's watch put Isolde out with Greta on night 1 (the kill block) and night 2;
  Greta was hanged and shown to be the Poisoner, but nothing linked Isolde to her.
- **A Medium's relayed sighting vs the dead's known vantage:** the dead watched or
  guarded a different block that night, so couldn't have seen what the Medium says.
- **Accounting:** a Lamplighter's "N others out" plus home alibis for everyone but one
  → the unaccounted person was out.
- **Role confirmations:** a Clerk or Gravedigger confirming someone's gift → that claim
  is backed (claim_backed covers the Clerk; the Gravedigger on a living rival claim
  does not).
- **Duty claim vs reading:** the off-route check now tests a named destination (a watch
  kept, a door guarded, the hearth of the dead) against sightings. Still missing: the
  hearth in the Medium's *reading* ("at Dorian's hearth") as the destination, so a
  reading and a sighting can conflict, not only the alibi and a sighting.
- **Walker's sightings vs the Lamplighter count:** more people reported out than the
  Lamplighter counted (or a Lamplighter who counted others but is seen nowhere).

---

## Closed

- **61251/25923 concrete fixes (Oct 20):** private card targets include the listener;
  speaking for their own claim acknowledges support and grants +0.03 trust once per
  fact, instead of pressing them. Daytime whereabouts produce attributed cards even
  when the speaker withholds other sightings. Publicly cited night sightings produce
  the same evidence cards as private testimony, including evil fabrications.
- **Disclosure consistency:** a Night Watch's withheld reading cannot be obtained by
  switching to whereabouts or person-specific follow-ups. Repeating old readings
  before withholding newer ones now says "the rest of my readings" when citing fear.
- **Secrets as evidence:** existing private, public-defence and gossip confessions
  carry secret metadata; linking a confessed personal secret with night movement
  offers a defeasible explanation. Marked-report support is wired for future disclosure.
- **Own knowledge and evil cover:** NPCs do not entertain another gift as their own
  identity; ordinary sightings can be on their route rather than only at their final
  destination. Evil cover cannot nominate or vote to execute its Demon. A Warden
  bluff may claim to protect a teammate, avoiding a metagame alignment tell.
- **UI and phrasing:** spent nomination button disabled with tooltip; blue X on homes
  of the dead without crime scenes; circular nominee portrait crop; consistent Clear
  filters hover/pressed styles. Alternative-explanation replies label a subsequent
  preferred suspect as a judgement about the whole case, not a trace-specific match.

Settled decisions, built work and parked levers, kept for the record.

- **Oct 19: relaying another's private reading** is gossip with the source unnamed ("Word reached me from the Seer"). See DESIGN, "Meeting flow, step 1".

- **Oct 19: shadow good self for evil,** steps 1, 2, 4 and 5 of docs/shadow_self_plan.md (step 3, rebuttals, is on hold in section 3). Evil's public acts follow its good self unless breaking cover beats caution; refined heat; daily scapegoat re-pick. See DESIGN, "Shadow good self".
- **Oct 19: Mediums,** a shared menu for real and fake: fake readings fit the dead's public record and claimed gift, frame only some nights, "nothing new" and empty answers for both. See DESIGN, "Mediums".
- **Oct 19: hints at the meeting and following up on them** ("ask why", confidences). See DESIGN, "Citing reasons".

- **Oct 19: meeting opinions cite only what the audience has.** Reasons carry their source; private readings become a hint or a reveal (see DESIGN, "Citing reasons").

- **Oct 18 quick-fix pass:** everything then in this section (see DESIGN, "Quick-fix pass, Oct 18").
- **Deduction types built Oct 18:** Martyr facts in templates, the Martyr who doesn't die, pair with both proven good, Misread (Marked, red herring), suspicious, hiding a secret, secrets and evil roles as conclusions, builder headings; NPCs owning their own lies; fear as cover.
- **Day limit by town size:** settled, kept as is (6 days for 7 townsfolk, 8 for 10).
- **"Maybe" conclusions** [knob]: half the persuasion and half the trust consequences, if committed conclusions turn out too punishing. If used: "maybe" can't support further deductions or be cited in accuse/defend.
- **Initial general skepticism** [knob]: a lever to pull only if the early game gets too decisive.
- **"No gift" denials** [knob] (C.ALLOW_NO_GIFT_DENIAL, off since Oct 18): evil almost never bluffed it, so a denial was near-proof of good at the cost of the gift.
- **Playtest Notes 12553, done:** "I agree with X", "from my window", home on "was home" cards, pressure in the debug view, combined and excluding filters ("greta+night" / "-sighting"), clicking a timeline cell again clears it.
- **Timing within the night:** settled, not modelled (a night stays one instant).
- **Template gaps built Oct 18:** Martyr saves as proof of good; the chosen hanged with the Martyr standing; a pair reading naming two proven-good people; filed good / Marked / red herring deductions as template inputs; a Seer pair with one proven good.
- **Vigil deterrent:** tried and removed Oct 18 (it cost the bot's vigil catches). Offered vigils build trust only.
- **An open Warden: "I saw X out while I stood guard":** dropped Oct 19.
- **Oct 19: silenced NPC eligibility.** Silenced NPCs are excluded from player
  approaches and tavern gossip. They become eligible again when silence ends. (96773)
- **Oct 19: victim trace filter.** A victim's own night walk cannot supply the
  misleading trace at their cottage. Other passers still can; no balance tuning. (96773)
- **Oct 19: full-screen case board.** The grid fills the canvas. Cards & filters,
  Build case, and Profile start minimized and open as movable, resizable overlays.
  Opening or minimizing them preserves the board's pan/zoom and the working set;
  staging cards opens Build case, and Record theory opens Profile. The deduction
  tray also overlays the grid. Initial zoom waits for the visible layout to settle.
  Checked with rendered views and mouse drags; regression checks: 71 fixes, 28 social,
  and 63 UI checks passed on standard Godot 4.4.1. The UI test's existing synthetic
  card-drag preview and shutdown resource diagnostics remain.
- **Oct 19: case-board layout and filter follow-up.** Fixed recognized text filters
  resizing initially closed tools: filter chips/status keep a stable dock height,
  and overlay sizing waits for container layout to settle. Shared text, kind,
  person, place and any/all filters now live only on the main screen and apply to
  both the grid and Cards. Added the centered title and view tabs, filters with
  day/fit controls below, and a bottom-left dock for Cards, Build case, Profile,
  Notes and Roles, retaining the existing visual style. Timeframes have stronger
  separators and subtle distinct tints, darkest at night; morning/evening use
  sunrise/paler sunset icons. Statement, reading and accusation glyphs supplement
  role icons; no legend. In Statements, left-clicking a name only filters;
  right-click opens its profile, switches to another person, or minimizes the
  already displayed person's profile. Checked rendered layouts and panel mouse
  movement/resizing; 81 UI and 25 board checks passed on standard Godot 4.4.1,
  including recognized/misspelled filters before opening tools and profile toggles.
  The UI test's existing synthetic drag-preview and shutdown diagnostics remain;
  the rendered check completed without errors.
- **Oct 19: case-board UI phase 2.** Bottom rows now run from the grid to removable
  filter chips, the popup toolbar, then the deduction tray. Filter chips wrap in
  their own row without stretching the toolbar buttons; deductions expand beneath
  both rows. Renamed Cards to Card List, starting at its minimum width (340), and
  removed its action buttons. All three board windows use a visible flat line to
  minimize. A shared right-click menu on grid cards, list entries, tray deductions
  and profile card links offers Add to Deduction, Hide/Unhide, Find Links and Hints;
  deductions also offer Delete, with Unpin retained for pinned deductions. Actions
  target the clicked card; Find Links searches for links involving that card.
  Hidden deductions now respect Show hidden in both the grid and tray. Moved Show
  hidden after Clear filters and gave Clear filters a gold border. Verified 108 UI
  and 25 board checks on standard Godot 4.4.1, plus rendered layouts, the card menu,
  and panel mouse movement/resizing. The UI test's previously recorded synthetic
  drag-preview and shutdown diagnostics remain.
- **Oct 19: continuous social bars and town selection.** Learned social traits now
  display their actual scores, filling from the midpoint toward the value; 0.5 is
  a thin center marker. Undiscovered traits remain unknown. Privacy runs from Open
  Book (0) to Secretive (1), matching its actual score. Townsfolk rows have more
  padding, reserve only occupied role-icon slots, and elide long text inside the
  plaque. Living townsfolk show Location: followed by the visible location or
  Unknown, instead of falling back to their occupation. Circular portrait masks
  prevent artwork spilling past its frame; face crops were adjusted, including
  Hollis, Odette and Constance. Only townsfolk-panel clicks own the map highlight:
  select home, workplace, visible icon and known haunts; click again to clear, or
  another person to switch. Map hover, map clicks, profile changes and conversation
  focus cannot take it over. Night ward targeting remains available separately.
  Verified 25 focused town-UI, 108 existing UI and 71 fixes checks on standard Godot
  4.4.1, plus rendered town, portrait and trait-bar views. The existing UI test's
  synthetic drag-preview and shutdown diagnostics remain; rendered checks had no
  errors.
- **Oct 19: hidden-card fading and recent sightings** (`codex/ui-sightings-followup`).
  Shown hidden cards now draw at 42% opacity across board cards, place markers,
  pinned/tray deductions and text card lists, including staged cards. Cast-list
  locations now use "at". Asking about a person can add remembered sightings of
  that specific person from the current and previous two timeframes, keeping their
  original times and speaker attribution. Gossip controls willingness to share;
  the addition uses no extra question. Night reports require a disclosed walking
  gift and respect existing alibis/refusals; evil Night Watch claims reuse their
  approved fake report, and other night bluffs only repeat committed sightings.
  No new bluff generation or shadow-self decision changes. Each daytime phase,
  including the first morning and later dawns, automatically records people
  visibly working at their actual workplace as firsthand sighting cards and
  timeline markers. Repeated looks merge rather than duplicate observations;
  hidden idlers, dead people and night work are excluded. Verified 37 focused
  sighting checks, 110 UI, 25 town UI, 25 board, 89 fixes, 28 social, 102 shadow,
  138 dialogue and 20 dialogue-decision checks on standard Godot 4.4.1, plus
  rendered town, hidden-card and timeline views. The UI test's previously
  documented synthetic drag-preview and shutdown diagnostics remain.
- **Oct 19: shared text system, step 1** (`codex/text-term-registry`). Added a
  public display-term registry seeded from the cast, character colors, role
  descriptions and existing role icons. Stable person/role IDs carry optional
  color, icon and tooltip metadata; other term kinds can register through the
  same API. Matching returns original character ranges, preserves capitalization,
  supports possessives and Unicode word boundaries, and prefers the longest
  phrase. Ambiguous lowercase words such as medium/clerk require explicit role
  context; callers can limit eligible term kinds or opt out. Registry lookups
  return copies. No world/secret-role state is read. API and remaining steps are
  documented in `docs/text_formatting.md`. This is the registry/matching foundation;
  UI formatting and tooltips will be integrated in later steps. Verified 25 focused
  checks and a clean Godot 4.4.1 editor import.
- **Oct 19: shared text system, step 2** (`codex/text-formatter`). Added a formatter
  that covers original plain text with styled spans, preserving source ranges,
  wording and whitespace. A known speaker supplies the surrounding color; named
  characters override only their own spans. Parchment uses readable ink variants,
  and role spans carry public icon/hint metadata with configurable sizes and
  decorations. Overall opacity applies once to text and icons. An isolated native
  RichTextLabel adapter appends literal text, hints and inline images, preserves
  outer formatting contexts and falls back to readable text for missing icons.
  Original text can be reconstructed exactly from the spans. Extended the API
  notes in `docs/text_formatting.md`; game-panel integration remains step 3.
  Verified 24 formatter/adapter and 25 registry checks, a clean Godot 4.4.1 editor
  import, and rendered dark, parchment, faded, compact and literal-text samples.
- **Oct 19: shared text system, step 3 and entity styling**
  (`codex/text-log-profiles`). Names and roles are bold. Good role words use a
  reserved blue darker than Nisha's; evil roles use a reserved red, with ink
  variants on parchment. The speech log now enriches plain passages through the
  shared formatter, keeping speaker colors, portraits, headers, emphasis and
  clickable card references. Typed commands stay literal. Both profile panels
  enrich About, readings, disclosed claim headers, Their claims and About them;
  original times and private/public provenance remain visible. Role icons and
  wrapping paper tooltips supplement role words. Native role hints inside card
  links preserve left-click navigation and right-click card actions. Hidden
  profile entries use the shared fade. Matching font faces preserve the existing
  serif/monospace families when bold or italic. Updated the API notes. Verified
  27 registry, 26 formatter, 17 text-UI, 110 existing UI and 25 town-UI checks,
  including real mouse interaction through role hints and unchanged evidence/RNG
  state, plus editor import and rendered 1920x1080/1280x720 town, profile and
  tooltip views. Existing UI smoke-test drag-preview/shutdown diagnostics remain.
- **Oct 19: small inline icons on dark surfaces.** The shared formatter now carries
  its display surface into the renderer. Dark backgrounds use a cached warm
  light-ink version of each small inline icon, made by inverting luminance while
  preserving transparency; parchment keeps the original art. Processing happens
  once per icon/size on a small image copy, preserving source resources and the
  existing opacity behavior. Portraits and decorative log art retain their
  existing presentation. Documented the variant selection. Verified 29 formatter
  checks (including source/alpha preservation and separate caches), 17 live text-UI
  checks, editor import and rendered log/profile views on Godot 4.4.1.
- **Oct 20: text-system handoff; card extension deferred.** Added
  `docs/text_system_handoff.md` with completed steps 1–3, API/integration hooks,
  remaining steps, existing verification and a resume checklist. Reviewed the
  board/tray/list renderers and documented fixed card heights versus font/line
  budgets, detail thresholds, zoom-dependent row geometry, input and caching
  concerns. Compared custom drawing, reusable native cards, a hybrid and a compact
  board/detail view. Linked the handoff from the API notes and deferred steps 4–5
  until card zoom/presentation is settled. Documentation only; no runtime changes.

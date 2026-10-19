# Working title: Demonologist (single-player social deduction)

Status: early design + text prototype. This doc records decisions so far.
Tags: **(prototype)** = what the current build does as a placeholder; **(proposed)** = a
resolution suggested but not yet confirmed; **(open)** = unresolved. Untagged = decided.

The running to-do list (bugs, deferred and open items, by effort) is in BACKLOG.md.

## Pitch

A single-player social deduction game inspired by Blood on the Clocktower (BotC). Unlike
Demon Bluff / Dupery, information is not handed over up front: a case unfolds over several
days, with night kills, new information, lies, and twists. The town is a small simulated
place with schedules, sightings and relationships, not just a grid of claims.

The player is a **Demonologist**, an outsider summoned to a town where a demon has taken a
host. The player has their own tools but is not a townsperson, which sidesteps the "why
doesn't the player follow an occupation schedule" problem.

Movement and "being seen" are a core layer that BotC doesn't have. This is a feature,
but it means the game must teach its own way of thinking and make evidence very readable.

## Pillars

1. **Information arrives over time.** Each day brings new reports, deaths and claims.
2. **Chaos in information, not in outcome.** Misinformation (lies, poisoning) is something
   to reason about. Losing should be explainable in hindsight.
3. **Every lie has a reason.** NPCs lie because they are evil, or for personal motives.
   The dev log always records why.
4. **Choices cost time, failures don't.** Actions spend a phase; empty results should still
   be informative.
5. **The player builds the case.** Deduction is expressed by assembling evidence into
   arguments and persuading the town, not by the game drawing conclusions.
6. **Hindsight reveal.** End of case shows the full grimoire: who was what, who was
   poisoned when, and every lie.

## Structure

- **Run:** a sequence of cases (roguelike). Meta-progression adds variety (new roles,
  demons, modifiers, player tools) and knowledge (bestiary), never raw certainty. **(open)**
- **Case:** one town, 12–15 NPCs in the full game; **6–7 in the prototype**, with one
  demon and one minion.
- **Cast pool:** NPCs are persistent characters with fixed personalities who get dealt
  different occupations/roles each case, or sit a case out. Personality must never
  predict alignment. The pool is 15: the original ten plus Kiran (affable, nosy but private,
  deflects with humour), Lian (blunt, practical, moved by concrete evidence), Merrin
  (theatrical worrier, repeats stories overconfidently), Nisha (patient, precise, keeps
  confidences, stubborn about her theories) and Odette (dry, independent, won't follow a
  crowd), each with a portrait and a standee.

## Time

- Each day: **3 day phases (Morning, Afternoon, Evening) and 1 Night phase**.
- The player gets **one action per phase**.
- End of Evening: **town meeting** (see below).
- Night: evil acts, abilities fire, the player performs one night action.
- Demon kills happen at night by default. Breaking that rule is a future demon trait.

## World

- The town is divided into **blocks**; each block holds 1–2 **locations**.
- Testimony and evidence usually point to **blocks**, not exact locations.
- NPCs have **homes** (on a block) and **occupations** (tied to a location).
- **Homes are visitable:** an NPC at home can be called on (talking still costs the action).
- **Schedules:** each NPC has **at least one work slot**; their work schedule is known to
  the player, and the player can always find and talk to them at work then, no
  exceptions. Free slots are flexible and not shown in advance. Deviation is normal, so
  absence alone is not damning.
- **Sightings:** NPCs in the same location see each other; NPCs on the same block may
  notice each other. Sightings are stored as beliefs and can be reported (truthfully or
  not).
- **Night movement:** most NPCs stay home. Evil NPCs go out to act. Gifts that choose a
  place (e.g. the Night Watch) put the holder out at night, where they can be seen. Some
  good NPCs go out for personal reasons (secrets), which creates red herrings.

### Visibility of NPCs by day

- The map shows where each NPC is **during the current phase**, and whether they are
  **busy** (in a conversation). This lets the player plan, but they still risk missing a
  conversation: if they want two people in the afternoon and pick one, the other may be
  busy by evening.
- **Availability per phase:** working NPCs are always available at work. Idle NPCs may
  be pre-paired into a visible conversation, but only while the player keeps **at least 3
  people to choose from** (relaxed late in the game). Example (7 NPCs, morning): 2 working,
  5 idle; 2 pair off; the player chooses among 3 idle + 2 working. After the player
  chooses, remaining idles may pair off (a semi-random chance, with partners chosen by
  trust, confidence and paranoia: two who dislike each other rarely talk; of three, the
  two who like each other are likeliest). Each NPC has at most one NPC conversation per
  day; once pre-paired, they can't be pre-paired again that day (but may still be at work).
- **Who you can see [built].** People at work or deep in conversation are visible from
  anywhere. Anyone else (out and about, or at home) is out of sight until the player
  chooses a block for the phase; then everyone on that block shows, including who's home
  (a lit window). `go <person>` only works for someone you can see; otherwise the game
  points you to their work and home block. At night everyone is home.
- Only the *current* phase is shown live. On the map and timeline, positions the player
  witnessed are shown as **confirmed**; positions heard secondhand (testimony, gossip) are
  shown as **tentative** (e.g. low alpha) and carry their source. Recording other
  positions is otherwise a deliberate player action. This keeps the evening trace and
  daytime testimony meaningful (see Evidence).

## Occupations vs. gifts

- **Occupation** is public (the undertaker is known to be the undertaker).
- **Gift (role/ability)** is secret and awakened by the demon's presence.
- Occupations loosely correlate with gifts (believable bluffs). **(prototype: occupation
  and role independent)**

## Roles: the script (built Oct 2026)

The full design notes live in `role_exploration.md`; this is what's built. Data in
`sim/content.gd`; what each reading *says* in general terms (who it points at, who it speaks
for, who it names) in `sim/gifts.gd`, so reasoning keys off a few reading shapes rather than
off particular gifts.

**Case sizes.** 7 townsfolk: 5 good (one carries the secret), 1 minion, the demon. 10
townsfolk: 7 good (one carries the secret), 2 minions, the demon (8 days instead of 6).
Roles are drawn from the script with no duplicates and a little protection: at least two
start-knowledge gifts (Archivist, Clerk, Surveyor, Rumormonger) and at least one strong
identifier (Seer, Dowser, Gravedigger). The town size is picked beside the case seed.

Good (15):

| Gift | Ability (as built) |
|---|---|
| Archivist | Starts knowing that one of two people is a particular minion. |
| Clerk | Starts knowing that one of two people holds a particular gift. |
| Dowser | The first time each day they're on a block with 2+ others (at home counts as your home block), learns how many of those are evil. A day reading, shared with its time. |
| Gravedigger | Each night after an execution, learns the hanged person's true role. |
| Lamplighter | Each night walks the lamp route through every block (so is out, and can be seen) and learns how many others were out. |
| Martyr | Once per case, secretly chooses someone they trust (needs trust ≥ 0.62, minus suspicion; never on night 0). If that person is later executed while good, the Martyr dies in their place: both proven good to everyone. If the chosen is hanged and the Martyr lives, the Martyr learns they were evil. Doesn't cover demon kills. A poisoned Martyr's save fails. The choice is shareable like a reading ("I've given my life over for X"). |
| Medium | Each night visits the home of the most recent dead not yet visited and learns one thing they knew but never said in public: unshared readings first, then night sightings, then their strongest suspicion; else where they were their last night. The evil dead give their cover story (fake readings, the scapegoat). |
| Night Watch | Each night watches a block; learns who passed through it. Is out on that block. |
| Psychologist | Each night picks someone they talked with that day (NPC conversations) and learns whom they trust and suspect most. Evil mostly name a teammate as most trusted and their scapegoat as most suspected. The Psychologist gets a nudge to seek conversations. |
| Rumormonger | Starts knowing that one of two people carries a particular secret ("one of two", like the Clerk; one person outright would fully clear them, since secret-holders are good). |
| Seer | Each night picks two people; learns if either is the demon. One good soul reads falsely as the demon (and a Marked soul may). |
| Sexton | Once per case, with fewer than five alive, may toll the death knell in the evening (likely once allowed). That night no gift that walks abroad works: the demon's kill, the Poisoner, Warden, Night Watch, Medium, Lamplighter. Secrets still walk (they aren't gifts). The toll is public; the bell's ringer isn't named. A poisoned Sexton tolls for nothing. (Replaces the Sexton occupation: now groundskeeper.) |
| Surveyor | Starts knowing how many of the four blocks have an evil resident. |
| Veteran | The first attack fails; they learn the last block the attacker came through before theirs (their own if the demon lives on the same block). A second attack kills. |
| Warden | Each night guards one other person's door against the demon (stands at the door, so can be seen). |

Hearthwitch is benched (kept in code, out of the script).

Evil: the Demon (kills each night from night 1) and minions:

| Minion | Ability (as built) |
|---|---|
| Poisoner | Each night poisons one person: their gift fails or lies until the next night. Kept at night for first-night poisoning; when no Poisoner is in play the demon is the only evil out at night. |
| Breathstealer | Once a day (any day phase, likelier later), silences someone on its block. The silence takes hold at that evening's meeting (so the player never meets a freshly silenced person mid-day) and lasts until the next evening. Silenced people can't claim, testify, accuse, nominate, defend themselves, talk with you, or chat with NPCs; they can still vote. Never the same person twice running. Picks the most dangerous voice (public info claims, hostility, known threats). |
| Revenant | Hides a totem at a location it visits, on any day that began with no totem in play (so a totem found in the morning can't be replaced until the next day). If hanged with a totem hidden (and not poisoned), a random good NPC who voted yes turns evil; the town is warned ("someone among you has turned"). The player's `search` at the totem's location finds and burns it (the totem is caked with the Revenant's home-block material, a lead). Found before the hanging: no curse. Found after: the turned soul is good again. Evil teammates often vote to let a Revenant with a totem hang. |
| Scion | If the demon is executed while five or more are alive, the Scion becomes the demon (no double kill). |

Secrets are **modifiers**: one per case, laid on a good townsfolk on top of their gift
(the Lovers affect two but count as one secret):

| Secret | Effect (as built) |
|---|---|
| Delusional | Their gift doesn't work and gives arbitrary information (they don't know). Protective gifts fail too. |
| Marked | Each gift that reads them sees them as evil (Dowser, Surveyor, Hearthwitch) or the demon (Seer) half the time; a Gravedigger sees a random evil role 30% of the time. |
| Secret Lovers | Two townsfolk meet at a random block each night (both out), trust each other, know each other's secret, and hide it like any secret (they may confess). |
| Sleepwalker | Leaves home each night to a random block without knowing it: they honestly say they were home, and see nothing while out. |

The older personal night-outs (insomnia, smuggling, debt) remain as flavour secrets.

**The turned (Revenant's curse).** They keep their gift and keep claiming it (their bluff
is their own role); from then on their readings are fabricated the way evil bluffs are.
They know the team and the team knows them. When the totem burns they're good again,
remember nothing of who else was evil, and disown what they said while turned (they
won't repeat it, and it no longer counts in their own beliefs). Other NPCs still hold what
they heard; nobody knows who was turned. (Simplification: their evil-era claims aren't
discounted by the town; the player can argue it.)

**Town reactions to the new events** (existing patterns): someone silenced gets a small
credit with everyone (evil wanted them quiet); a curse makes every good yes-voter on the
Revenant a little suspect to the rest; a Martyr's sacrifice proves both good; a Veteran's
"came by way of X" nudges suspicion toward X's residents; a Psychologist's reading rubs a
little suspicion between a suspect and whom they trust most; the Rumormonger's pair is
mildly cleared; what a Medium hears counts at 0.6 of hearing it from the dead.

**Evil bluffs** cover the new info gifts: a fake Surveyor count (true ±1), a Rumormonger
pair that lends a teammate a harmless secret, a plausible Lamplighter count, a Medium who
says the dead saw the scapegoat out, a Psychologist who says someone suspects the
scapegoat, a Martyr who "chose" a teammate. Evil bluffing a walking gift says their gift
took them out when asked where they were.

**Night sightings and deaths (after the roster).** Being seen out at night now counts
in full only on the block where someone was killed that night (x1.0); anywhere else it
counts very little (x0.12). Someone who openly claims a walking gift is discounted further
by how far the listener believes the claim (up to -70%). This applies to Night Watch
reports, NPC gossip, the Medium, and the strength of your night-sighting cards (which
still read as "against" when presented, just weakly away from a death). The Sleepwalker
now walks on about half of nights. The demon values a claimed start-knowledge gift
(spent after night 0) less as a kill target than a gift that keeps reporting. The bot
player reads every gift's reading through `sim/gifts.gd` and weighs night sightings the
same way. Effect (10 townsfolk, 150 seeds): Lamplighters hanged 57% -> 43%, Veterans
49% -> 33%, Sleepwalkers 58% -> 40%; Wardens unchanged (48%). Walkers really are near
the deaths (the Lamplighter passes every block, the Warden stands at a target's door), and
most are hanged on the bot's nomination after hiding their gift and saying they were
home. The fix that remains is the filed "rebuttals/excuses" item: a hidden walker caught
out at night should be able to explain with their gift.

Every role and secret on the script now has its own icon (`assets/ui/roles/<id>.png`).

**Not built yet:** the Revenant actively drawing suspicion to get itself hanged; NPCs searching for
totems; Beckon, Tallyman and the rest of On Deck; Relationships.

- Evil NPCs know each other and receive bluffs (good roles not in play, at least one more
  than the evil team's size).
- A demon kill is **strong but not certain** evidence of goodness: future demons may kill
  their own minion to fake a good death. Rules text should not promise otherwise.

## Player: the Demonologist

Day actions (one per phase). After choosing a location, the player sees who is there and
who is nearby. They get **one free move within the same block** (e.g. tavern → well) before
acting, as a backup when nobody useful is home, without letting them scout the whole map.
Then one action:

- **Talk** to an NPC present: a conversation of up to 3 exchanges (questions or
  `convince` arguments).
- **Search** the location (murder scenes yield physical evidence).
- **Gossip** (tavern only): overhear a rumour, with its source.
- **Wait.**

Night action:

- **Vigil** at a block (default, unlimited for now; watch whether it's too strong): see
  who moves through it at night, including anyone whose gift sent them there.

### Toolbox

- The player has **2 tool slots, each usable once per case**. Tools resemble town gifts
  and become unlockable/customisable through progression.
- Starting tools:
  - **Ward:** at night, shield one person from the demon (once).
  - **Clemency:** spare one person from execution (once). Used **immediately when a
    nomination is made**: the player is given a chance to intervene, and that nomination
    is cancelled. Other nominations that day proceed normally. Trust effects follow each
    NPC's attitude to the spared person: those who trust them think better of the
    player; those who suspect them think worse.
- Future candidates: Autopsy (learn a dead person's gift), Séance (question the dead; evil
  dead may still lie), Scry (is X the demon? once, foolable at higher difficulty), Binding
  circle (sets up exorcism). Info tools must narrow, never settle. Evil should react to the
  player's loadout. High difficulty may let the Poisoner affect the player's tools.

The demon cannot target the player directly. **(prototype)**

## Arguments: `convince`

All persuasion uses one model:

> **convince** [NPC] **that** [conclusion] **because** [card(s)]

### Conclusions (starting set; expand from playtesting)

Built as a sentence: **[name] [is / is not / should be] [status] [on night N] because
[cards]**.

- [X] is evil / is good / is (not) the demon
- [X] is (or isn't) the [role]
- [X] is lying / is not lying (about a card of theirs among the supports)
- [X] is **misled** [on night N]: not lying, but their information was wrong (poisoned or
  mistaken; the town can't tell those apart, so they are one status)
- [X] is **misled or lying**: the hedge when you only know their information is wrong
- [X] should be protected / spared from execution

Each conclusion moves a different part of the NPC's mind:

| Conclusion | Effect on listener |
|---|---|
| X is evil / the demon | suspicion of X up |
| X is good | suspicion of X down; Warden more likely to protect X |
| X is / isn't the role | belief about X's claim; affects double-claim reasoning |
| X is not the demon / not lying | suspicion of X down a little |
| X lied about card | discredits that card; suspicion of X up (less than "evil") |
| X is misled on night N | discounts X's info from night N (all their info if no night); **no** suspicion change |
| X is misled or lying | discounts X's info by half; small suspicion rise. As an explanation it doesn't compete with "lying" or "misled" about X, since it contains both |
| protect X / don't execute X | protection weighting; vote intention |

This needs belief state the prototype lacks: per-source/per-night "possibly poisoned"
discounts, believed roles, and believed-good flags.

### Contradiction, corroboration and inference

- **Player-built**: the player links two (or more) cards and the game checks them against a
  template library. Three kinds of link, one interface:
  - **Contradiction**: these accounts can't both be accurate (two places at once, a
    reading that flips, ...).
  - **Corroboration**: independent evidence supports the same account (two witnesses put
    someone in the same place; a Clerk reading backs someone's claim).
  - **Inference**: these facts make one explanation more plausible (a Seer or Archivist
    names two people and one is cleared, which leaves the other; the death-scene trace
    points to a block and someone was there that evening).
  None of them prove anything; each lists explanations, and the player picks one.
- Each contradiction template carries a set of **explanations** (A lied, B lied, A
  poisoned, B mistaken/red herring/misleading trace, ...). The player chooses which
  explanation they argue as their conclusion.
- Templates are a data library (same person in two places at once; double role claim;
  watcher omitted someone seen on their block; info vs. confirmed fact; etc.). Checking all
  card pairs against all templates is cheap. The dev log flags player links no template
  covers, to grow the library.
- **No template is not the same as unfounded.** A conclusion argued from cards that bear on
  the person is the player's own inference, weighed on its support. It's **unfounded** only
  when the cards don't touch the person at all; a sharp NPC rejects that, a credulous or
  trusting one may be swayed anyway. The player can mislead the town by mistake.
- The same conclusion from the same cards gets the same footing however it was built
  (pressing Link first or not): filing checks the supports for a template that offers it.
- Caution (not a hard rule): avoid cases where the player believes they are proving
  something but the cards disagree on an invisible technicality. Showing the fields a
  template depends on (night number, phase, block, source) and having NPCs name why they
  reject an argument are the expected mitigations.

### Homes and routes (Oct 2026)

Where everyone lives is common knowledge: each case opens with a "lives on" card per
resident (Statements view; it can't be presented to anyone). At night a walker takes the
shortest road from home to their destination and can be seen on any block along it.
**Since Oct 18 every block has a road to every other** (outer roads Market–Docks and
Chapel Hill–Docks), so a route is just home → destination: nobody passes through a
block, and a walker is seen only at home or where they went. The Lamplighter is the
exception (the lamp route passes every block), which may make the gift easy to confirm. The night `two_places` template is
gone. Its replacement, *off-route*, fires only when no single way from their home passes
both blocks, or when someone names where their night took them (a watch kept, a door
guarded, the hearth of the dead) and the way there doesn't pass a block they were seen
on. Explanations: a source lied, or they were walking the lamp route. A claimed lamp
route never conflicts. Compatible pairs get a "these fit together" note showing the way
(Market → Square → Docks). Day `two_places` (one phase, one place) and out-vs-home are
unchanged.

### The conclusion builder

- Available from the evidence board at any time to draft and file conclusions ahead of
  time, and inside conversations and the meeting to present them.
- Piece by piece: name, verb, status, optional night, and the selected cards as "because".
  Picking an explanation from a link prefills it (and backs it with the contradiction).
- **Restatements are refused.** A positive conclusion (good, a role, not the demon, not
  lying, protect, spare) whose supports all come from the subject ("Jory is the Seer
  because of Jory's claim and Jory's reading") can't be filed unless a template matched.
  Flimsy conclusions with outside evidence are allowed ("Jory named Hollis and then died,
  so Hollis is the demon"), as is a conclusion with no contradiction behind it (marked
  unfounded). A deduction needs at least one supporting card.
- A deduction's evidence class is the weakest of its supports when a template matched;
  otherwise at most circumstantial.
- Filed conclusions appear on the board and in NPC profiles. The player can delete their
  own deductions; any card can be hidden (and shown again with "show hidden"), but only
  deductions can be deleted.

### How NPCs evaluate an argument

- Weigh each possible explanation using their own view: trust in each source, likelihood
  of poison, firsthand knowledge, relationships, trust in the player.
- The argument moves them in proportion to how much their own weighting agrees with the
  player's chosen conclusion.
- **Insight** trait: higher insight checks more explanations and catches unfounded
  arguments; lower insight is easier to persuade (and to mislead).
- **Diminishing returns** follow the underlying evidence, not the card or its wording (see
  the evidence ledger below): hearing the same reading again by any route adds nothing,
  re-wrapping a card in a new deduction counts much less, and only independent sources
  corroborate.
- Evil NPCs evaluate arguments for what they reveal: arguing your case to a minion tells
  the demon what you know. Their replies come from the same lines good NPCs use, chosen by
  what serves evil, so wording is never an alignment tell.
- A deduction resting on someone's confessed secret spreads it, exactly as citing the
  secret directly does.

### Something doesn't add up

A conclusion in its own right: "one of these people is misled or lying", where the group is
the people the supporting cards rest on (sources and claimants, excluding the player,
physical evidence and the demon's victims; at least two). Link offers it first on any
conflict, so the player can flag a clash without committing to an explanation; the builder
offers it as **One of these people**. Template-backed, anyone sees the clash (agreement
rises with Insight); otherwise it rests on trust in the player, and sharp NPCs ask what
doesn't add up. Accepting it splits a little doubt across the group's readings plus a
small suspicion bump; presenting it raises **pressure** on those involved (all of them at
the meeting; privately, the listener if involved), which loosens claims and secrets later.
Group members know they told the truth and answer accordingly; evil uses the same lines.

### Presenting: direction from the card

`present` reads direction from the card (incriminating vs. clearing strength), applies
multi-person cards to the whole group split, and keeps `for`/`against` as an override. A
card with no direction of its own falls flat ("I'm not sure what you're trying to prove"),
costs no question, and is logged (`present_fallback`, counted in `case_summary`) so we
can see which cards land there.

### The evidence ledger (belief record)

Each good NPC keeps a ledger of the evidence and arguments they've taken in, keyed by the
underlying fact (Jory's night-1 reading; Agnes's sighting of Bart on the Docks), not by who
relayed it or which card or deduction wrapped it. The record keeps the whole history, but
each NPC reasons only from what they actually heard or witnessed.

- Suspicion = a social base (vibes, nominations, grudges, claims) + each ledger entry's
  effects × its weight × how reliable the NPC currently thinks its source is.
- Hearing the same fact again only raises its weight to the stronger hearing; it never
  stacks.
- "Jory is misled on night 1" doesn't overwrite Jory's report: it lowers how much that
  report counts, for readings already heard and for ones heard later. Trust in a person
  and confidence in a particular reading are separate: "Jory is honest, but his gift
  failed" is a coherent belief.
- **Shifting trust.** The player's arguments are stored with their weight before trust.
  When an NPC's trust in the player shifts noticeably, and before every vote, they re-weigh
  what the player argued with current trust. An earlier dismissal is not extra evidence
  against the argument (that would count the same distrust twice); **Confidence** sets
  how far they move at once. Evidence they witnessed themselves doesn't depend on trust.
- When an old argument finally lands, they say so next time you talk: "I didn't put much
  stock in what you told me, that Jory is misled... perhaps I should have."
- Accepting "X is the Seer" makes anyone else claiming the Seer a liar to that NPC.
- **Terms.** A **claim** is any stated piece of information from an NPC. Kinds: a **role
  claim** (what someone says their gift is), a **reading** (a gift's result; poison can
  break it), a **report** (ordinary testimony: a sighting, an alibi, an opinion; poison
  doesn't touch it). **Evidence** is what the player saw or physically found (no source to
  doubt). An **argument** is a deduction the player presents (credible as its supports).
- **Credibility.** Every claim has a source, and counts as much as that source is credible
  to the listener. Credibility is two separate factors:
  - **Honesty of the person**: 1 − a modest, capped share (max 50%) of the *evidence*
    against them, from any source or role (a verdict that they were evil, a sighting, an
    argued deduction). Never from suspicion, which includes vibes and grudges.
  - **Doubt about a particular reading**: from "X was misled on night N". Poison is a
    property of the night, not the person, so it doesn't touch their honesty, their other
    readings, or their ordinary reports from that night. A good NPC never doubts their own
    honesty, but can accept that their own reading was poisoned (and stop suspecting the
    people it named).
- **No circular reasoning.** Everything is recomputed from scratch from the underlying
  inputs (each entry's original strength, the player's arguments and their supports) to a
  fixed depth: night doubt; honesty from evidence at original strength; honesty again with
  that evidence weighted by the first-pass honesty of whoever gave it; arguments scaled by
  how credible their supporting evidence still is; then every effect applied as a
  difference. Nothing carries over between calculations, so recomputing without new
  evidence changes nothing, and A and B accusing each other can't amplify. It recomputes
  immediately whenever anything an NPC believes changes, so there's no stale reasoning.
- **Cascades fall out of this, with no role-specific rules.** B says A was evil → A's
  claims count for less. Discredit B's report → that evidence weakens → A's claims recover
  (as far as other evidence allows). Discrediting is not vindicating: it removes evidence
  against A rather than proving A good.
- **Accepted conclusions track their supports.** An argument the NPC accepted weakens if
  the evidence it rested on is later discredited, including through a chain (a deduction
  built on another deduction is followed down to the claims underneath). Each distinct
  justification for a conclusion is kept separately with its own strength and supports;
  the conclusion counts as its strongest justification *as it stands now*, so a weak
  restatement can't borrow a discredited strong one's weight.
- **Order of the recompute.** First estimate of reading doubt and honesty (arguments at
  full strength) → arguments scaled by their supports' credibility → final reading doubt
  → final honesty under that same doubt → effects applied. Everything downstream of a
  poison argument uses the same final doubt, so undoing the argument undoes all of it.
- **Debug overlay** (checkbox): each card shows its current influence across the good NPCs
  who've heard it (avg / high / low, with initials, and how many heard it); profiles show
  how the town credits and suspects the person. Turning it on marks the case's
  identification unscored. Readings and arguments map to NPC records cleanly; role
  claims now map too; most sightings and reports still don't (they're told to the player,
  not held by NPCs).
- Acceptance tests: `tools/test_beliefs.gd` (recovery; independent evidence keeps a
  discount; poison doesn't damage honesty; recomputing is stable; works for any source;
  mutual accusation is stable and bounded).
- **Vindication** follows from the rules: if the Gravedigger was poisoned the night they
  named someone the Poisoner, the Poisoner was alive then, so the hanged person wasn't.
  This relies on poison always making a reading wrong (current rule). If the director
  later makes poisoned results merely plausible (sometimes right), revisit this template.
- Every evaluation is logged with its explanation weights.

## Town meeting

Follows BotC's structure:

1. **Floor:** the player may present one prepared argument to everyone at once. NPCs
   give testimony and claims.
2. **Nominations, one at a time.** Each nomination is its own event with a start and an
   end: nominator speaks, the player may make one short statement (accuse or defend) or
   use Clemency, then everyone votes and the tally is recorded before the next
   nomination.
3. **On the block:** a nomination that reaches the threshold puts that person on the
   block. A later nomination with more votes replaces them (the first is safe). A tie at
   the highest count means no execution.
4. At the end, whoever is on the block is executed (unless the player uses Clemency).

BotC limits: each person nominates at most once and can be nominated at most once per
day. Threshold: votes from at least half the living (rounded up).

**Peer pressure, not a pile-on [built].** A public accusation is a social signal, not
evidence. Each accuser counts once (their latest stance), by how much the listener trusts
them; each further voice adds half as much as the one before; an accusation fades to 60%
per day; the total is capped (0.3 before Confidence scaling). Re-accusing at the next
meeting adds nothing. It's kept out of the evidence ledger, so a crowd's opinion never
lowers anyone's credibility. Pressure from an accusation halves with each voice that only
joins in. In speech, the second person to accuse the same target says "I agree with X
about Y", adding grounds only if they're their own (their reading, what they saw).

**Dead NPCs (deferred):** no ghost votes for now. In BotC that rule mainly keeps dead
players engaged, which matters less in single player. Keep the door open to the dead
affecting the game, e.g. the final day's vote is a **Séance** in which the dead also vote.

**(prototype)** All nominations are voted on together and the player can't speak.

## Evidence

- Physical traces at death scenes point to the **block where the killer spent the
  evening** before the kill (75% accurate in the prototype, otherwise a random other block).
  This rewards tracking evening whereabouts. The trace card must state this rule plainly
  (the prototype's card wrongly implies home/work).
- **Known issue (evening shifts):** because the trace uses the killer's *evening* block, a
  demon who works an evening shift has a fixed, publicly known evening block, so traces
  converge on their workplace more reliably than for other demons. **(proposed fix, with
  paths)** decouple the trace from day schedules: at night the killer walks a path from a
  starting point (home or a deliberate detour) to the victim; evidence is drawn from that
  path, which the demon chooses (a cunning demon routes through the scapegoat's block).
  Evening whereabouts then matter as alibis rather than as trace input.
  **Limit on routes (proposed):** the route is home → at most one detour block → victim.
  The physical trace reflects where the killer *started* (their home block, with the usual
  chance of being misleading), so detours can't hide the origin; they only let the demon
  pass near someone it wants to implicate. Every extra block raises the chance of being
  seen by night walkers or a vigil, so wandering is a risk, not a free smokescreen.
- Conflict to watch: if every evening position were automatically recorded, the trace
  would point straight at a suspect. See the visibility proposal above.

## UI overhaul (planned, Oct 2026)

Mockups: main screen = map/meeting (top left), cast list (top middle), profile (top right),
actions beside the text log (bottom). Case screen = card library + builder (left), main
board (centre), profile and notes (right).

**Decisions so far**
- Every card carries two times: **when it happened** (`when`, the canonical time) and **when
  you learned it** (`learned`: every disclosure, with who told you and whether it was
  public). **All views place cards at the canonical time** (a Seer reading about night 1
  sits at N1 however late you heard it), so a gift's readings line up night by night. A
  claim or opinion happened when it was said. **[built]**
- The same fact reaching you again (told privately, relayed, announced at a meeting) is one
  card with another disclosure, not a new card (claims, readings, sightings, alibis).
  **[built]**
- Rows: Places by place (toggle: by person); Statements by the person a card is **about**
  (a "said by" toggle may come later); Process by person (nominee and each yes voter).
  **[built in the layout model]**
- Deductions: a fold-up tray along the bottom of the board, about a quarter showing
  ("Deductions (#)" and the tops of the cards), from which they can be pinned to the board.
- Board views (exclusive, each with its own filters): **Places & sightings** (your sightings,
  conversations seen, location hearsay, physical traces), **Statements** (claims, readings,
  opinions, accusations; private and at meetings), **Process** (nominations, votes,
  executions, deaths and quiet nights). One card may show in two views (a Night Watch report
  is a statement whose positions also appear in Sightings as "ability report" markers);
  selecting either highlights the same card, and it counts once in a deduction.
- Deductions live in a "My theories" section of the library, visible from every view, and can
  be pinned beside evidence on the board.
- Movement: solid marker = you saw it; hollow = someone told you; conflicting reports both
  shown; observations aren't joined into an implied route.
- Strings (source, subjects, supports) on hover; click to pin.
- Three zoom levels: overview (dots, icons, stack counts), day (one-line summaries), close
  (full text). Row and time headers stay readable at any zoom. Fit day, fit selection, reset.
- Every filter that hides evidence shows as a removable chip beside a Clear all, and a status
  line always says what's showing ("Showing 4 of 31 · Statements · Filters: About: Agnes");
  if a view comes up empty because of filters, it says so. **[built]** Row-name
  filters in Statements mean "said by" by default, with "about" as an option. The card
  library and board share view and filter state; the working set is independent.
- One profile component on both screens (header: name, portrait, status, claimed role and
  your guess styled differently; tabs: lore and stats | claims they've made | claims about
  them), with clickable evidence and private/public labels.
- Link folds into the builder as a live "what these cards suggest" panel that updates as
  cards are added; filing is unchanged.
- Panels: dock, collapse, resize, reset layout first; free-floating later. A future "Script"
  panel lists the roles that may be in play.
- Visual skin through one shared theme (`ui/theme.gd`): nine-slice art in `assets/ui/`
  (see its README) replaces the flat look when present. **[built]**
- **Case board v1 [built]** (`ui/board_view.gd`, `ui/deduction_tray.gd`): drawn board with
  pan (drag) and zoom (wheel), three levels of detail, paper cards with role icons and the
  speaker's colour, coloured dots in Places (solid/hollow/ability ring), red strings on hover
  or selection (to the speaker's and relayers' rows, between a card's appearances, to a
  deduction's supports), row-name filters, day navigation (a day includes the night before),
  Fit day / Fit selection / Whole case. Cards drag to the working set; deductions wait in a
  fold-up tray and pin to the board where dropped (drag to move, right-click to unpin).
  Link is now live: "What these cards suggest" updates as the working set changes.
- **Shared profile [built]** (`ui/profile_panel.gd`): the same component on the town screen
  (compact) and the case board, following the shared selected person. Header on framed
  paper: portrait (greyed when dead), name in their ink colour, occupation and status,
  their claim with its role icon ("Claims: Night Watch (to the town)" / "told you
  privately" / "Hinted at a night-sight gift" / "Says they have no gift"), and **Your
  guesses** in red pencil: a role dropdown and a secret dropdown ("None" or any secret on
  the script), each with "?" on its options and its own confidence (Flimsy / Maybe /
  Likely / Confirmed). Tabs: About
  (blurb, work and home, revealed traits, what readings say, debug lines), Their claims
  (cards they're the source or relayer of), About them (cards about them from others),
  each entry a link with when it happened and how you heard it; clicking selects the card
  (and shows it on the board). The guess saves as you change it. (Per-person notes were
  dropped; the case notes window covers it.)
- **Town screen [built]**: title bar (sun or moon, "DEMONOLOGIST", day and phase, Town / Case
  board / Notes / Roles / Help; case seed, New case, More ▾ for the text
  cast and timeline, the old card sidebar and the dev log; Debug). Top: map, the
  townsfolk list (`ui/cast_list.gd`: portrait in a gold ring, colour, claim icon, your
  pencilled guess, where they are if visible; dead greyed with a cross), the compact
  profile. Bottom: actions with a context line ("Talking with Greta · 2 questions left")
  beside the log. The log shows the speaker's portrait on speech lines, sun/moon/seal on
  day headers, a raven on deaths and a card icon on new case-board cards. **Case notes**
  open in one window from either screen and save as you type. **Roles** is a second movable
  window (from either screen) listing every gift with its icon and description, and who has
  claimed it to the town or to you. Record theory was dropped from the title bar (the case
  board's builder does it). Other panels stay fixed for now; making them movable is deferred.
  Text sizes were raised across the town screen, map, profile, log and board (deeper type
  polish later).
- **Painted map [built]** (`ui/map_view.gd`): each block is its painted base (Square plaza,
  Market clearings, Docks with the pier, Chapel Hill's winding path), places are building
  sprites with name signs, homes are small cottages with the owner's colour at the door
  (crossed out when they become a crime scene), sandy roads with lamps join the blocks,
  trees and flowers dress the edges, and townsfolk are paper standees (busy ones marked,
  the person you're talking to framed in gold). Night tints everything blue. Zooming into a
  block dims the rest. Same layout logic and click targets as before.
- **Town meeting circle [built]** (`ui/meeting_view.gd`): during the meeting and
  nominations the map gives way to a ring of the living townsfolk's standees on the Square
  (you at the bottom, a candle for your seat), set well back from the middle. The nominee's
  portrait sits in the centre with who nominated them; the nominee's standee is framed red
  and the nominator's gold. When a vote is taken a gold hand sweeps clockwise from the seat
  after the nominee, counting each vote as it passes: yes voters step in and get a numbered
  red token (1, 2, 3 ... in counting order), no voters pull back and grey out. A tally in the
  corner shows the running count against the threshold, then the outcome and who is on the
  block. Click to finish the count; click a person to show their profile.
  - **Rule change:** votes now resolve in BotC order (clockwise from the nominee's left,
    nominee last), not roster order. Evil votes react to the running count, so order
    matters. Bots after the change, 300 seeds: active 31.7%, passive 13.7% (was ~33/16;
    within noise for active, passive a touch lower).
  - The log still prints the full result at once, ahead of the hand.
  - **Later:** fake and noncommittal voting (a hand half-raised, a late switch).
- **Papercraft skin [built]**: navy board, cream plaques as buttons (red when pressed), gold
  edges, framed paper for the profile, serif type. Art sliced from the sheets by
  `tools/slice_sheets.py` (see `assets/ui/README.md`).
- Code: `game/card_model.gd` (times, views, rows, place markers), `game/board_model.gd`
  (layout as plain data), `ui/case_state.gd` (shared view, filters, selection);
  tests in `tools/test_board.gd`.
- Meeting circle (low priority): votes counted clockwise from the nominator's left, and
  resolved in that order (evil voters react to votes already cast, so order is a rule, not
  just presentation). Fast/instant counting; clear tie message.

## Player UI (target)

Three main views:

1. **Map:** navigation; home and work locations; currently known positions and busy status.
2. **Evidence board / timeline (one screen):** a grid of people × phases. Every
   observation, claim, reading and testimony sits in its time slot; conflicts are
   highlighted. Filter by type, person, location, source. Contradictions and filed
   conclusions live here. Conclusion builder opens from here.
3. **Profiles:** one per NPC: known facts, their claims, player notes, and (later) a
   player-chosen role icon with a confidence colour.

The prototype's text interface (a flat numbered card list) is a stand-in.

## NPC minds

- **Belief store:** facts with source, confidence and when learned.
- **Suspicion:** each NPC holds a suspicion score for every other NPC, updated by ability
  info, contradictions, sightings near murders, and arguments from people they trust.
- **Trust in the player:** gates how much they share and how much arguments move them.
- **Personality traits:** see *Trait model* (Planned features). Prototype still uses
  honesty, caution, gossip, temper, loyalty.
- **Relationships:** friend/rival edges seed NPC-to-NPC trust and bias suspicion and voting. Friends of an executed
  NPC resent its nominators, yes-voters and the player (implemented).
- **Evil coordination:** demon and minion share a plan: bluffs, a scapegoat to frame,
  kill priority.

### Showing trust diegetically

- Greetings, refusals, willingness and small body-language lines change by trust tier
  ("What do *you* want?" vs. "Ah, Demonologist. Sit."). Kept subtle.
- An NPC's **Composure** decides whether these cues appear in the text at all: low
  composure, open book; high composure, gives nothing away.

## Lying

Reasons NPCs lie, always recorded in the dev log:

1. **Evil cover:** an evil NPC claims a bluff role and generates info by running that
   role's ability on a fake world in which a scapegoat is evil. Lies stay consistent and
   break only where the cover story contradicts reality.
2. **Personal secrets:** a good NPC out at night for a personal reason lies about where
   they were.
3. **Caution:** a good NPC with a high-value role may hide it early (claims "nothing").
4. **Poisoned:** not a lie; the NPC honestly reports false info.

## Demon kill choice

Each candidate is scored on threat (info claims, suspicion of the demon, saw the demon at
night, confided in the player), opportunity (lives alone, not a known protection target)
and motive (demon temperament: vengeful, cunning, hungry). Kills are evidence.

How it works now: the demon takes the highest score; a noise term (0 to 0.8) only matters
between close candidates. The temperament is rolled once per case and only touches the
kill choice: *vengeful* +1.5 for anyone the demon trusts below 0.4 (people who've been
against it); *cunning* +1.5 for anyone living on the scapegoat's block (so the kill
falls near the scapegoat); *hungry* adds a random 0 to 2.0 per person per night (the
least predictable). Decided, not built yet: 3% of nights the demon skips its top three
(BACKLOG).

## Quick-fix pass, Oct 18

- Builder: "is not evil" / "is not good" file correctly (the drop-down passes the stored
  type, typed commands the label; they're no longer matched against each other).
- An evil Medium bluff's night story names the hearth of its fake reading ("Communing
  with the dead at Dorian's hearth"), on that hearth's block, not wherever they really
  were; fake readings visit each of the dead once, most recent first. A real Medium
  names the hearth too. The duty card no longer carries the speaker's true role.
- A Warden asked about their gift lists whose doors they guarded, one card per night; an
  evil Warden bluff's invented doors are fixed per night (same story on every ask).
- A Martyr is reluctant to vote to hang the person they'd die for, unless the case,
  pressure or panic is overwhelming.
- Case summary: a Martyr's death is recorded against the nomination (the nominee, who
  lived, plus `martyr_died`); demon identification credits naming the demon the case
  started with (a Scion's rise doesn't take it away).
- The demon skips its top three targets 3% of nights (logged as an unpredictable choice).
- Wording: "night 0" anywhere player-facing reads "the night before you arrived";
  relayed readings are retold in the third person ("Agnes told me… that they looked
  at…"); Medium readings say "Communing with the dead at X's hearth".
- Gossip (tavern and approaches) skips what that person already told you and readings
  the whole town heard at a meeting; an approach with nothing new doesn't happen.
- "town consensus fading" is logged when old stances fade (it said "against them").
- The "No demon guess recorded" voting prompt is gone.
- Votes are silent (PR #3's vote explanations removed until the rebuttal/meeting work).
  Argument replies say when the listener had already come to the conclusion; evil
  listeners' reasons for doubt now come from the same range good listeners use (another
  explanation, shaky evidence, a likelier suspect: their scapegoat), chosen without game
  RNG.
- The case board's card list is newest first, like the other lists.

## Dialogue composer (merged from codex/dialogue-prototype)

Presentation only: the simulation decides what is said (including an evil character's
fabricated account), then `sim/dialogue.gd` words it in a character's voice from
`sim/dialogue_voices.gd`. It never sees world state, alignment, truth or secrets, and
draws no game RNG (30 bot cases came out identical with and without it). Three voices
(Agnes, Bartholomew, Constance) cover five situations: reporting information, being
doubted, discussing a friend, refusing whereabouts, and coming round to an argument.
Everyone else keeps the plain lines. Per-NPC `dialogue_memory` notices a repeated
answer to the same listener. Workshop: `ui/dialogue_lab.tscn`; guide:
`docs/dialogue_prototype.md`; tests: `tools/test_dialogue.gd`.

## Logic depth

- **NPCs reason with templates**: explainable (every judgement fits a log line), fallible,
  personality-driven. They must not out-deduce the player.
- **A full solver exists only for dev and director use**: enumerate possible worlds
  (role assignments × poison targets per night) consistent with the evidence. Uses:
  solvability checks, measuring how certain the player could be by day N, a future
  storyteller director, possibly hints. Feasible at 7–15 NPCs.
- Main risk is tuning sprawl, not computation: keep the conclusion vocabulary small and
  weights in data files.

## Dev logging (required)

Every event is traced to a JSONL log plus a readable text transcript: world events, NPC
reasoning snapshots (claims, lies, votes, kill/poison scores, argument evaluations with
explanation weights), suspicion and trust changes with causes, per-phase snapshots, and
hidden state. Unmatched player contradiction links are flagged for template work.

## Teaching

- General rules over special cases ("gifts that choose a place send you out at night";
  "a demon kill is strong evidence, not proof").
- A tutorial case on a fixed seed, **later**, once mechanics settle.

## Tech

- **Godot 4 / GDScript.** Simulation core is pure logic, separate from presentation,
  deterministic from a seed, runnable headless.
- Text prototype first: terminal CLI and in-editor text console share one command
  interpreter. An autoplay bot runs many seeds for testing.

## Planned features (tentative)

### Trait model

**Defined traits** (rolled once at case start as base ± that trait's volatility, then
constant for the case; low/mid/high tiers):

| Trait | Low | High |
|---|---|---|
| **Privacy** (about self: role, relationships, whereabouts) | shares who they are and what they know even at low trust; claims publicly early | withholds as long as possible; reveals under pressure; stonewalls rather than lies |
| **Gossip** (about others) | keeps out of others' business; at the extreme, won't share even if asked ("none of my business") until under pressure | volunteers what they've seen and heard |
| **Confidence** | opinions shift quickly; stonewalls or cracks when pushed; rarely nominates | opinions shift slowly both ways; lies boldly when pushed (as good or evil); nominates and votes readily |
| **Insight** (logic, impressionability) | swayed by speech alone | swayed only by concrete evidence or a preponderance of circumstantial evidence |
| **Composure** (keeps emotions in check) | attitude cues obvious; strongly affected by pressure and paranoia | almost no cues; resists pressure and paranoia |

- **Privacy decides whether** an NPC discloses; **Confidence decides what they do when
  pushed** (high: lie outright; low: stonewall or crack). This keeps personal-secret lies
  alive for good NPCs.

**Derived traits** (change during the case, always hidden from the player):
- **Pressure** (individual): scrutiny from accusations, nominations, circulating
  evidence. Pushes high-Privacy NPCs to open up and low-Gossip NPCs to deflect.
- **Paranoia** (global): baseline suspicion of everyone not confirmed; rises as bodies pile
  up. Weighs against Insight and Confidence (flimsy nominations get support late).
- **Trust**: toward the player and toward each other NPC. NPC-to-NPC trust replaces the
  old Loyalty trait.
- Composure reduces the effect of Pressure and Paranoia.

**Alignment:** traits apply to both alignments. Evil **overrides content** (lies instead of
truth) but **style follows traits and pressure**: a high-Privacy demon stonewalls (good
cover); a low-Privacy demon volunteers a bluff early. Pressure is the legitimate reason for
behaviour to shift, for both.

**Decisions are weighted rolls:** a score from traits, trust and context becomes a
probability; score breakdowns are logged.

**Trait reveals to the player:** after a private conversation, one trait is revealed with a
roll for a second (Composure lowers it); after each meeting, a chance per attendee
(Composure lowers it) to learn one trait. Reveals show the rolled value, not the cast
member's baseline. Only defined traits are revealable. Tuning: if too fast, make the
conversation reveal a chance and the meeting chance low. Present as tiers, described in
character the first time.

**(prototype)** Traits are mostly hard thresholds on the old set: caution (claim timing,
trust needed to reveal a gift, starting trust), temper (meeting accusations, trust lost
when pressed), loyalty (friends in votes/accusations, grief), honesty (confession
threshold), gossip (tavern speaker pick).

### Evidence classes (for Insight)
- **Speech:** claims, opinions, hearsay.
- **Circumstantial:** reported sightings, traces, readings reported by others.
- **Concrete:** player-witnessed events, owner-identifying items, template-confirmed
  contradictions.

### Statement taxonomy

| # | Statement | Drivers | Evil variant |
|---|---|---|---|
| 1 | Gift disclosure (tiers) | Privacy ↑ lower/later; Trust ↑ and Pressure ↑ raise tier; Composure dampens pressure | same schedule, bluff content |
| 2 | Gift reading | as #1; trust drop stops new readings, with explicit refusal | fabricated; high Confidence frames, low stays harmless |
| 3 | Own whereabouts / alibi | Privacy high stonewalls, low volunteers; if hiding and pushed: Confidence high lies, low cracks/stonewalls; Pressure pushes to lie-or-confess | same; always hiding after a night out |
| 4 | Sighting of others | Gossip high volunteers, low only if asked; high trust in subject may omit friends | omits teammates; Confidence decides inventing |
| 5 | Corroborate / deny an alibi | trust in that person; shared secret: Privacy (quiet) vs Confidence (lie to protect) | may deny a true alibi to frame |
| 6 | Opinion, vibes ("something's off") | low Insight, high Paranoia; Gossip shares | same mix |
| 7 | Opinion, reasoned | Insight ↑; Gossip shares | fabricated reasons |
| 8 | NPC-made argument / contradiction | Insight finds; Confidence airs publicly | built from bluffs |
| 9 | Accusation / nomination | Confidence ↑; Paranoia lowers threshold; Pressure deflects onto others; Composure dampens | pushes scapegoat |
| 10 | Defence of self or another | trust in defended, Confidence; self-defence rises with Pressure | defends teammate, carefully. **(later)** Overrides: a pressured minion distances himself from the demon and tries to look like someone else's minion ("throw under the bus"); the demon goes along with town/player conclusions to build trust |
| 11 | Confession | low Privacy, high Trust, high Pressure, low Confidence | false confessions (fake secrets) |
| 12 | Hearsay / relay | Gossip; distortion with low Insight | seeds lies |
| 13 | Request to the player | low Privacy; trust in player and subject | "protect X" as bait or probe |
| 14 | Reaction to an argument | Insight sets bar by evidence class; Confidence sets shift speed; trust in source and subject | judges what it reveals |
| 15 | Changed story when caught | Confidence high doubles down, low confesses; Composure hides fluster | main improvisation point |
| 16 | Small talk / noise | Gossip | same |
| 17 | Approaching the player | low Privacy or high Gossip, plus an agenda | to frame or probe |
| 18 | Withholding ("I've told you enough") | trust fell below highest shared tier; Composure decides whether a reason is given | same |

Vague opinions are the default for both alignments ("something's off about them"), so
neither vagueness nor a stated reason is a tell. Good NPCs state a reason only when it is
grounded in something real they heard or saw; evil NPCs state one only when it is grounded
in an active bluff (a fabricated reading already shared, or a fake sighting they told the
player). Both use the same roll (lower Insight, more often vague).

### Reactions

| Event | Effect | Modifiers |
|---|---|---|
| Player airs their secret publicly | trust loss | Privacy low: small; mid: large; high: large + **trust ceiling** (can't rebuild past "wary" this case). High Confidence may retaliate publicly. Composure: visible anger or not |
| Player keeps their secret (end of day) | trust gain | bigger for high Privacy; reduced (not lost) if someone else spread it and the player stayed quiet |
| Neutral chat (once/day) | small gain | high Privacy warms up slower |
| Player argues something they agree with | gain scaled by agreement | high Insight gains less from agreement alone |
| Pressed with too many questions | loss | high Privacy loses more; Composure dampens |
| Player accuses them privately | loss, Pressure ↑ | high Confidence counter-accuses; low cracks (more disclosure) |
| Player accuses someone they trust | loss | scaled by trust in that person and Confidence |
| Publicly nominated / accused | Pressure ↑ and trust loss toward the nominator (and the player, if they nominated or backed it) | Composure dampens; low Confidence discloses, high counter-attacks |
| Caught in a contradiction | Pressure ↑↑; #15 fires | confession + player discretion can raise trust |
| Friend executed | loss toward nominators, yes-voters, player if yes | scaled by trust in friend; trust ceiling if the player nominated |
| Player proven right | gain | bigger for high Insight |
| Ward/Clemency on someone they trust / suspect | gain / loss | Paranoia tilts toward loss |
| Body found; town shrinks | Paranoia ↑ (global) | Composure dampens |
| Evidence against them circulates | Pressure ↑ | Composure dampens |

**Trust ceiling:** serious betrayals cap the maximum trust regainable with that NPC.

### Unified gift/info question and hints
- `ask gift` and `ask info` merge. Disclosure tiers:
  1. Denies having a gift, **or** refuses to say what it is.
  2. **Flavoured hint** (in-world, not metagame) pointing to a role package (e.g.
     protection: Warden/Veteran).
  3. Gift, **or** vague information. **(tabled until the roster is defined)**
  4. Everything.
- No 3-for-3.
- Good NPCs never illogically fall back to a lower tier. If trust drops after sharing,
  they withhold *new* information and say so explicitly ("I've told you enough").
- Roles are flavoured to fit hint packages; keep packages in mind when adding roles
  (aim for 2+ roles per package).

### NPCs approach the player
- At the start of some phases an NPC asks to talk. The approach itself is free: the
  player gets a yes/no prompt. **Having the conversation costs the phase action**; if they
  decline, the slot is used normally. Sussing out who's worth talking to is part of play.
- Who approaches: a good NPC with news, an evil NPC spreading a frame or probing, or a
  **busybody** (high Gossip). Busybodies always give *some* information, usually low
  impact (a sighting), and are a main path to learning others' **secrets** (an affair, a
  reason someone sneaks out).

### Building trust
- Neutral conversation; presenting a case they agree with (even one the player doesn't
  believe); acting in their interest (warding/sparing someone they trust); being proven
  right; keeping their secret (end-of-day bonus). See Reactions for losses.
- Using someone's secret publicly costs trust with its owner regardless of who told the
  player.

### Evil knowledge and coordination
- At baseline evil knows: each other's identities, bluffs, and a shared plan. The first
  night gives free shared knowledge (as in BotC).
- After that, evil knows only what a member **saw or was told**, and must **meet** to
  share: own sightings, what the player argued to them, readings of public behaviour,
  plan updates (scapegoat, kill target, consistent bluffs and alibis).
- This replaces places where the prototype's evil AI reads hidden state directly (private
  suspicion, private night sightings, true night walkers, whom the player confided in).
- If this makes evil too weak (measure with the autoplay bot), add specific knowledge back
  to evil's automatic pile selectively.
- Meetings can be crowded (tavern; slow, hard to observe) or private (fast, riskier).
  Frequency follows personality, not alignment. Good NPCs meet constantly too, so meetings
  aren't a tell on their own.

- **Poisoner sense and team play [built].** The Poisoner skips gifts that poisoning
  wouldn't stop tonight, judged from public claims only: first-night gifts (Archivist,
  Clerk) after night 0, a Gravedigger on a night with no execution, a claimed Veteran on
  its own. The demon treats a claimed Veteran, or someone whose attack failed with nobody
  at the door, as a possible Veteran: with the Poisoner alive it may go for them anyway
  and ask the Poisoner to poison them first (one retry), so the kill lands. A suspected
  Warden (claimed, or glimpsed at a door when a kill failed) is a poison target on nights
  the demon goes for someone prominent.
- **Demon on the block.** When one more vote for its own minion would tie the block's
  count (clearing it), a demon on the block may cast it (likelier when confident). It
  votes for its minion otherwise only when the vote passes without it.
- **Bluff consistency.** A Seer bluff never gives a "no" that covers the scapegoat (it
  would undo its own frame) and frames every night once five or fewer remain. Still to
  come: a "throw a teammate under the bus" pass.

### Good-to-good social dynamics
- Simple model: two NPCs choose to talk; NPC 1 shares one thing they know (a sighting, a
  reading, an opinion, something the player argued); it affects NPC 2's judgement through
  the same evaluation as player arguments (source trust, diminishing returns).
- Every belief records **who it was heard from**, so it can be traced and disowned.
- Evil can feed lies into the network.
- Limit and scheduling: see *Availability per phase* (World). Pre-paired conversations are
  visible (busy); evil meetups use the same mechanism and each evil NPC's one daily
  conversation, with good pairs as noise. Tune the signal:noise ratio.

### Claims matter to good NPCs
- Good NPCs weigh public claims. A Warden who trusts a claimed strong information role is
  more likely to protect them; NPCs value claimed roles when voting and choosing whom to
  confide in.
- The demon factors in a known Warden claim when choosing targets, and after a failed
  kill almost always switches to a new target the next night.

### Geography, paths and dropped evidence
**Built (v1):** roads Square–Market, Square–Docks, Square–Hill, Market–Hill. Night walkers
take the shortest route from home; sightings, vigils and the Night Watch see them on any
block along it. Each walker may drop something on the route (demon 35%, others 15%): a
home-block material (88%) or a personal item (12%). Searching a location finds everything
dropped there; personal items become a night "out" card for the owner (works with every
place-based template); materials become a card linkable with a resident's home alibi
(`dropped_vs_home`). The scene trace is misleading only when another walker actually
passed the victim's block (40% then), and the grimoire says who and why. Still to come:
paths within blocks, planting by a Framer, NPCs searching.

- Blocks remain the unit of space; the map gains real **paths** (sequences of
  blocks/locations). Night movement follows paths.
- Evidence can be dropped **anywhere along a path**, by the killer or by anyone else out
  for their own reasons (noise). E.g. demon goes chapel → graveyard → victim's house; a
  clue may turn up in the graveyard.
- The death-scene trace (killer's evening block) stays.
- **Misleading evidence should have a cause.** The current 25% random wrong trace is a
  placeholder. Here it becomes something that happened: another walker passed through,
  borrowed clothing, contamination, or a Framer planting it, so the end-of-case reveal can
  explain *why* the evidence misled you, and a sharp player could have reconstructed it.
- Owner-identifying items (a named scarf) are strong evidence: keep them rare, and later
  plantable by a Framer-type role. Category traces (soot, mud) are common.

### Confrontation, alibis and confessions
- The player can **confront** an NPC with evidence. The NPC may confess the true reason
  (including a personal secret like a gambling debt), lie, or name an alibi.
  **v1 built (`press <card#>`):** raises pressure in proportion to the card's strength;
  a night card makes them account for that night (existing confess/lie/stonewall logic),
  a card about their gift re-runs the disclosure decision (a true Clerk naming opens them
  up), a rival's claim of their gift makes them restate it and turn on the rival. Nerves
  show with probability ~ (hiding ? 0.6 : 0.2) × (1 − Composure) × strength, so they're a
  hint, not a tell. Costs trust (Privacy-scaled) unless the card names them favourably.
  Named alibis and corroborators are still to come.
- **One verb.** In conversation, `present <card#> [for|against <name>]` covers making a
  case, arguing a deduction, speaking up for someone, and pressing the listener; the game
  infers which from the card and who it's about, and asks when a card mentions several
  people. It mirrors the meeting's `present`, which is the same act in public.
- **Sightings are told from where you say you were [built].** Someone at home saw the
  street from their window ("From my window, I saw X leave their house" / "out in the
  street"); someone out saw them in passing ("I saw X out on the Docks"). Neighbours at
  home sometimes notice each other go in for the night and not come out: a true, weak
  **witness alibi** card ("Y says X stayed home on night N"), which works with
  `out_vs_home`. A person who claims home won't report what they saw on another block
  (a rattled few let it slip: 0.25 × (1 − Composure) + 0.15 × pressure, a catchable
  contradiction). Evil's invented sightings follow the same rule: from their own window,
  or while out on a night-active bluff (a Night Watch's watched block, a Warden's
  guarded door); a liar who refused to say where they were invents nothing.
- **To do: more ways to discover and confront secrets.** Today a secret surfaces only if the
  holder confesses when asked about a night, or someone gossips it. Needed: more routes to
  find one (sightings that don't fit, a confidant, physical evidence such as a personal
  item) and ways to confront someone with it, as a card, and to use it as leverage.
- **Filed (playtest 30294): evil reads as evil.** (1) An evil NPC casting aspersions with no
  information stands out because good NPCs rarely do it; either give good NPCs reasons to
  do it too (secrets, grudges, relationships) or make evil hold back. (2) An evil NPC
  doubting a sound player deduction everyone else accepts looks suspicious; fine once the
  player's own information can be suspect, otherwise fold into the "throw a teammate under
  the bus" pass.
- **To settle: lie severity.** A proven lie should weigh by what it was about. A false gift
  report (a Night Watch's watched block, a Warden's guarded door, a reading) is strong
  evidence of evil, since good people hide secrets, not invent gifts. A lie about
  whereabouts is weaker (it might hide a secret), but weighs more when it places them near
  the crime (at the murder scene's block on the murder night). Also: when an NPC accepts an
  argument but still won't vote to hang, they should say so ("So she lied. That's not
  enough for me to hang her.").
- **To do (next social pass): rebuttals and excuses.** An accused NPC should push back with
  a reason when they have one ("I was out there because I'm the Night Watch"), which buys
  some grace with listeners. Evil without a bluff that fits can claim a secret they don't
  have ("I was paying off a debt"), which needs more ways for the player to unravel fake
  secrets (ties into the secrets item above).
- **Built:** a false Night Watch's answer to "where were you" now names exactly who their
  made-up watch report names (case 30294: Isolde's report said she saw Bartholomew, but
  she told you she saw nobody).
- **Filed:** an open Warden saying "I saw X out while I stood guard" (strong; maybe too
  strong).
- Alibis **name a corroborator** ("I was with Jory"). The corroborator confirms or denies,
  which can produce a word-against-word contradiction card.
- Evil may claim a false secret ("I was meeting Jory for an affair"), or name someone they
  really did meet, to throw suspicion on them. Good NPCs may also lie to protect a shared
  secret out of trust in their partner, so a real affair can stay hidden.
- Evil naming each other as alibis is a classic BotC pairing tell; smart evil usually
  avoids it.
- All of these are expressed as cards (alibi claim, confirmation, denial, confession).

### Asking questions
Two menus in conversation:
- **Ask about <them>…:** their gift, who they've seen around today, whether they saw
  anything last night, and **"are you the <gift>?"** (`ask are <gift>`). A right guess
  makes them own up a little more readily, but only if it's the first guess you've put to
  them. A wrong guess costs trust (0.02 × the number of wrong guesses so far) and gets the
  same non-answer an unwilling holder gives ("What my gift is, I'll keep to myself"), so a
  guess never eliminates anyone; after a few they ask why you keep asking.
- **Ask about others…:** "Opinion on…" a person, or "Heard of a…" gift: whether they've
  heard anyone claim it (publicly, or told in private if they're willing to pass it on).
  If it's their own gift there's a small chance they own up (0.15 + 0.2 × trust); it never
  costs trust.
- A card you've already shown someone ("You've told me that already") costs no question,
  once per conversation.

### Clemency and the demon
- The demon may deliberately **not** kill someone the player spared, leaving them alive to
  be suspected (fits the existing scapegoat logic).
- **Town paranoia:** as the town shrinks, good NPCs grow more suspicious of everyone not
  yet killed or otherwise confirmed.
- **Urgency:** NPCs become more willing to execute late ("we must hang someone"); the
  player may need to talk them down. Tune paranoia and urgency together so the last days
  don't become random lynchings.

## Rollout plan (proposed)

1. **Foundation (text). [built]** Split game output into structured events/cards with text as a
   rendering layer, so a UI can later consume the same data. Add the trait model,
   schedules/availability with the in-block move, unified gift question with tiers and
   hints, trust building/reactions/ceiling, BotC-style one-at-a-time nominations, the
   two-slot toolbox (Ward, Clemency), demon retargeting, and the opinion-template fix.
2. **The town talks (text). [built]** NPC-to-NPC conversations and belief provenance; evil
   coordination replacing hidden-state reads; NPC approaches (incl. busybody secrets);
   pressure and paranoia. Bot runs to check evil isn't too weak; playtest round.
3. **The case board (thin Godot UI). [built]** `convince` with conclusions, contradiction cards and
   templates, evidence classes, diminishing returns; timeline grid, profiles, filters,
   confirmed vs. tentative positions. Built as a minimal Godot panel because multi-card
   building is painful in pure text. Playtest round.
4. **Full UI. [first pass built]** Mouse-driven: a `_draw()` town map (zoom to block; click
   places, homes, scenes, people), a context action panel with pickers for every command,
   character colours in the log, multi-select case-view filters. Still placeholder art; no
   portraits or role icons yet; the typed prompt remains as a fallback.
   Map (homes, work, known positions), board/timeline, profiles with role icons
   and confidence. Trait reveals and trust cues presented diegetically.
5. **Geography and confrontation. [partly built]** Roads and routes, dropped evidence,
   causal misleading traces, press/confront, Warden walking. Remaining: named alibis and
   corroborators, Framer planting. Paths, dropped evidence along paths, confrontation,
   alibis and confessions. Benefits from the real map.
6. **Later:** urgency tuning, throw-under-the-bus overrides, Séance final vote, roster
   expansion and hint packages, solver/director, larger towns.

## Playtest findings (3 cases, 2 players)

- Gradual reveal works; relationships and secrets work as intended.
- **Wasted actions:** many day actions were spent searching ordinary empty locations,
  usually because the person sought wasn't there. Addressed by day visibility; consider
  making `go` free to look.
- **Players expect evidence chains:** after a trace pointed to a block, players went and
  searched that block. Candidate: traces lead to a secondary clue at the killer's evening
  location (dropped item, witness), giving `search` a real purpose. **(open)**
- **Players read social patterns** ("Agnes keeps meeting the other evil"). The prototype
  has no daytime evil coordination, so that read was coincidence. Candidate: make it real
  (evil meetups to coordinate, which can be observed; friends and lovers meet too, as
  noise). **(open)**
- **Evil information is the most forthcoming:** evil NPCs claim early and share a
  steady, consistent frame of the scapegoat, which is easy to follow into lynching the
  innocent. Working as intended, but town and player pull may be too strong: a
  player-led nomination of the true Seer passed 7/8. Consider NPCs resisting when their
  own information contradicts the nomination.
- **Vigil is strong:** one well-placed vigil on the kill block (plus an Archivist pair)
  won a case on day 3. Keep watching.
- **Template tell (fixed in stage 1):** evil opinions say "Something's off about them" with no reason,
  while good opinions cite one. Fix both ways: good NPCs give vibes opinions too; evil also
  cites (fabricated) reasons.
- **UX:** `go <block>`/`go <person>` should work (expected to resolve with the real UI);
  asking `info` before `gift` repeats the answer (resolved by the unified question);
  "as I said" is used for claims never said to the player.

- **Playtest 4 (case 90028):** strong "figured it out, too late" feeling. Findings:
  - **Poison is exploitable as inversion.** Poisoned readings are currently the *opposite*
    of the truth (Seer yes/no flips; Hearthwitch always a wrong count; Night Watch always a
    wrong name). A player who suspects poison can invert the reading and get perfect info.
    **(proposed)** Poisoned readings become *arbitrary*, as in BotC: drawn from plausible
    results, which can coincide with the truth; later chosen by the storyteller/director.
  - **Players want to cite evidence in meeting statements** (tried `accuse 30`). Until
    `convince` (stage 3), `accuse`/`defend` could optionally take a card, evaluated by every
    voter like a private argument but weaker. **(proposed)**
  - **Key info stayed private.** The Gravedigger learned Fenwick was the Veteran (which,
    with the Seer's night-0 pair, pointed at the demon) but never went public before being
    killed. Working as intended (privacy, caution), but it argues for NPC-to-NPC sharing and
    approaches in stage 2.
  - Fixed: sighting answers were a long dump (now memory scales with Insight, sharing with
    Gossip); `done` closed the meeting before the town spoke (now requires a quiet `wait`);
    a Seer could nominate someone their own sight cleared (own "no" now weighs more and
    raises their bar to nominate that person). `ask info` remains an alias of `ask gift`.
- **Built (stage 2): ask about a role.** `ask about <role>`: a trusting, gossipy NPC who
  has heard from (or about) that role may share who claims it and what they said.

- **Stage 2 balance notes:** evil sharing and approaches use exactly the same willingness
  formulas as good NPCs (otherwise evil was suspiciously forthcoming and a third of all
  shares were lies). Evil's sense of public "heat" ignores its own team's accusations and
  readings (otherwise it talked itself into early nominations). Gifts aren't leaked by
  reasons: an NPC who hasn't claimed keeps a reason vague if it comes from their own reading.
  Bot win rate stays ~30-40%, in line with stage 1.

- **Stage 3 notes:** NPC agreement compares the chosen explanation with the strongest
  alternative (with three options, an even split otherwise always read as rejection).
  Conflicts are never auto-marked on the timeline (space for a future optional hint
  system). The board panel is a summary; the full case view is a separate full-screen
  overlay. Bot win rate rose from ~30% to ~36% on the same seeds once it used deductions.

## Outcome tracking (built)

Private profile guesses now form a timestamped revision history, with copies frozen before
votes, executions and night resolution. The latest pre-outcome copy is used for final
identification credit; abandoned earlier guesses remain inspectable but do not count as a
solved final theory. Confidence and player notes are preserved without requiring a
template-approved argument. Correctness is revealed only after the case ends. The console
and case view show the current demon/minion candidates, with optional reminders before
votes and a Record theory shortcut. There is one candidate per evil identity; changing it
replaces the former candidate. Opening a debug grimoire disqualifies identification credit.

Case results distinguish identifying the demon, identifying the minion, saving the town,
and preserving good townsfolk. Identified-but-lost is descriptive partial credit, not a
claim that persuasion specifically caused the loss. Each execution logs nomination,
yes/no vote and explicit accuse/defend statements; conflicting actions are marked mixed.
Known card IDs and the private theory are saved before execution for manual diagnosis.
Earlier arguments are not automatically assigned causal responsibility for a death.

Autoplay emits versioned JSON results with --results; compare_runs.py pairs completed
seeds across active/passive reports. Wrongful-execution fractions use all executions as
the denominator, alongside counts per case and good survivors in victories. Incomplete
cases are excluded from outcome rates. Same seeds guarantee the starting setup, not the
later random draws after different actions. No RNG streams or gameplay rules changed.
The active bot records its existing suspicion ranking (first = demon, second = minion),
which is a deliberately simple diagnostic prediction policy.

Validation on seeds 1000–1149: active 53/150 wins, passive 25/150; active identified the
demon in 84/150 cases and both identities in 29/150, with 36 identified-but-lost cases.
Wrongful executions were 210/317 active vs 198/265 passive. All 150 active per-seed case
results match the pre-tracking commit, including deaths, executions and end reasons.

## Open questions

- Is unlimited Vigil too strong?
- Persuasion economy beyond trust (how pressure sours NPCs).
- Evidence planting (Framer-type evil role).
- Demon types with bestiary entries; exorcism/true-name alternate win.
- Solvability verifier and storyteller director.
- How many clues per day feel right (1 vs 2 player actions per phase).
- **Why did the player lose?** Record it in playtests: wrong interpretation, missed
  accessible information, information that was never available, or failure to persuade.
  Each calls for a different fix. The logs can classify the first three automatically
  (was evidence pointing at the demon on the board, reachable but missed, or absent);
  persuasion failures need the player's notes.
- Keep the 7-person town until the core loop reliably works: form a hypothesis, choose an
  investigation that tests it, revise, make a consequential argument. 12–15 people with
  the same three actions a day may make relationship-building too expensive.

## Playtest 13473 (10 townsfolk; Agnes demon, Isolde Scion, Edda Poisoner)

Findings:
- Lost on a final-day tie: with Isolde on the block 2-2, a good NPC nominated Hollis and
  the tie cleared the block. Clemency was available and would have saved it. **Filed:**
  good NPCs should avoid creating a tie when few remain (no execution at the end loses).
- The Scion's rise had no confirmation: the Gravedigger claimed and was killed the same
  night, before his reading. Fair, but flat.
- NPCs don't combine group readings: a Dowser "0 among Fenwick, Hollis, Constance" didn't
  clear Hollis of an earlier "1 among Edda, Hollis, Greta", so a Seer pair with the real
  demon was pinned on Hollis. **Filed:** templates for "readings that overlap in one
  person" (two Seer yeses sharing Agnes; Archivist pair and Dowser crowd sharing Edda) and
  "a clean group clears a member of a dirty one".
- The death-block night rule weakened two good vigil catches (Edda and Isolde seen leaving
  home on kill nights). **Open:** count sightings on the person's route from home to the
  death block (user thinking it over).
- Key readings withheld from the player (Archivist, Dowser), while shared with an evil
  NPC in a private chat.

Built from the session's list:
- UI: crowds at one spot spread out and shrink to one row; every menu has a Close button
  (and clicking its button again closes it); card numbers in the log open the card on the
  case board; the map tooltip no longer clips; townsfolk rows are bigger with fixed claim
  and guess slots (gifts without icons get a lettered tag); the profile is a little
  narrower; homes say plainly you can only call on someone who's in (and the free move to
  a home on your block works); the case-card sidebar shows by default at the lower right;
  the present-card picker and sidebar list newest first; "Look at the map" during
  meetings; "Townsfolk · N alive"; New case picks a fresh seed unless you typed one.
- Game: "ask today" leaves out people seen this phase where you are (you can see them) and
  reaches further back; "ask seen morning | afternoon | evening | yesterday" (also in the
  ask menu); leaving a conversation before asking anything costs no time (not for an
  approach you accepted); habitual haunts (two favourite idle spots per person, 40% of
  idle hours, shown in profiles, the cast list and the "can't see them" hint); the town
  overview and the map show how many people are at a spot you can't see (a count, not a
  name); confession grammar ("I can't sleep, so I walk to the chapel").
- Habit strength: at 60% the bot found fewer people and won ~8 points less at 7 townsfolk;
  at 40% it's back to baseline. The bot now also uses the "someone's there" counts.

## After playtest 13473: follow-up pass

- **Homes spread evenly** across the blocks (10: 3/3/2/2; 7: 2/2/2/1, random order), so
  no block is a much better vigil than the rest.
- **Seer picks scale with Insight.** Re-checks the top suspect 30% (dull) to 80% (sharp) of
  the time, else two at random. A sharp Seer pairs the suspect with someone unchecked, and
  once two "yes" readings include the same person (demon or the one who reads falsely,
  sight can't tell which), looks at two fresh people. Bot runs, 10 townsfolk, demon in the
  pair: night 1 41% -> 30%, night 3 62% -> 43% (random would be 24% / 34%).
- **Withholding** is a card ("X claims the Archivist but won't share what it has shown
  them", one per person and gift) and a deduction: claims an information gift + won't share
  = hiding something (evil), not that gift, or simply cautious. Weak (speech).
- **Fake Surveyor counts:** mostly a plausible wrong count (no more blocks than the evil
  team could cover), sometimes the truth (25%), now and then a count too high for the team
  (15%), which can pass for a poisoned or Delusional reading.
- **Flavour secrets benched** (insomnia, smuggling, debt; `C.USE_FLAVOR_SECRETS`). Night
  walkers per night (bot runs): 7 townsfolk 2.04 -> 1.88 (innocent 1.01 -> 0.89); 10
  townsfolk 2.68 -> 2.36 (innocent 1.47 -> 1.13). Only the Lovers can confess a secret now.
- **The script** opens when a case begins, in two columns (the town's gifts; the demon's
  side and the secrets).
- **Scion-safe deductions:** "hanged without ending the case, so not the demon" only holds
  with fewer than five alive at the hanging; otherwise pair elimination also offers "they
  were the demon, and a Scion took over". (NPC reasoning never used this inference.)
- **New deduction patterns:** *overlap* (two readings pointing toward evil share exactly
  one person: two Seer yeses -> the demon or the one who reads falsely; otherwise -> evil)
  and *group elimination* (a "one of these is evil" reading, Seer yes or a Dowser/
  Hearthwitch count of 1, with another reading clearing all but one of them). They label
  what the town's aggregate suspicion was already doing.
- **Meeting view:** a vote starting (or being counted) brings the circle back from the map.
- Left as is: good NPCs creating a final-day tie (social dynamics as intended).
- Deferred: the night-proximity rule for sightings (user exploring options).
- Bots after this pass: 7 townsfolk 58/150 (39%) vs passive 11/150 (7%); 10 townsfolk
  42/150 (28%) vs 16/150 (11%).

## Directions noted from playtests (not built yet)

- **Caution tied to the gift. [built]** One more term in the same claim roll: Seer,
  Hearthwitch and Night Watch lean quieter on days 1–2; Clerk and Archivist lean a little
  more open. A chatty Seer can still come out on day 1.
- **Demon caution after a failed kill. [built]** A kill stopped by a Warden or Veteran has
  no visible cause, so the demon avoids that person and shies away from high-profile
  targets for a couple of nights (fading). A kill stopped by the Demonologist's ward
  leaves a chalk sigil on the door; wards are single-use, so the demon isn't cautious.
- **The Warden walks. [built]** It stands guard at the protected door, so it can be sighted
  (and seen on vigils), framed by evil fake sightings, and hunted: a demon whose attack is
  stopped by a Warden marks anyone it glimpsed on that block as a likely Warden. An open
  Warden answers "where were you" with whose door they guarded; an evil Warden bluff
  invents one on the block they were really on.
- **A claims/reveals timeline** alongside the location timeline (cards per person per
  slot, with shortcuts), for the full UI.
- Who you saw nearby is now on the cards. Anonymising unseen people ("someone") would be
  a broader visibility redesign; revisit only if the town view gives away too much.

- **Role claims are per-listener records. [built]** Hearing a role claim (publicly at a
  meeting at weight 0.5, or relayed privately at the relayer's weight) creates a record
  whose **credence** = hearing weight × the claimant's honesty. Each record counts against
  everyone else that listener knows claims the same gift (0.6 × credence), so a double
  claim resolves by comparing credences and shifts as either claimant's credibility
  changes. A good NPC's knowledge of their own gift is a record at weight 1.5 (a false
  claimant of it is a liar to them). Quiet-night credit to a Warden/Veteran claimant is
  scaled by that claimant's credibility. An argued "X is the R" also counts against any
  rival claimant of R, now or later.
- **Situational credence adjustments.** One table of small, situational modifiers to how
  much a claim is credited, recorded per listener so logs show why. Built so far: a
  claimant the demon killed (so known good) has their claim counted double. Candidates
  to settle once the roster is fleshed out:
  - **Early disclosure:** volunteered early +0.05, and before any rival claim +0.10 (on the
    0.50 hearing weight); per listener, kept from their first hearing; evil can earn it.
    Applies to the role claim only, not the claimant's later readings (no double counting).
  - **No demon kill:** a quiet night supports Warden/Veteran claimants (currently a
    suspicion credit; could become a credence boost on their claim).
  - **Admission against interest:** a confessed secret is more credible than an alibi.
  - **Consistency:** a claimant whose readings have held up (nothing contradicted) gains a
    little credence over time.
  - **Role-specific confirmations:** e.g. a Clerk or Gravedigger confirming someone's gift.
- **Initial general skepticism (filed, not built).** Early on, every claim is just someone's
  word with nothing to corroborate it, so all claims could start with extra doubt that
  fades as evidence accumulates. Likely makes the early game too indecisive; keep it as a
  lever if the opposite problem (early game too decisive) shows up.
- **Procedural town (future).** Generate the town per case: different blocks, buildings
  and routes between them, rather than the fixed four blocks. The map already lays places
  out from data per block; the block rectangles, roads and decor would need generating too.
- **Template generalization (deferred to roster expansion).** Templates should read
  abstract statements ("one of {A, B} is P", "none of these is P", "X is P") produced by
  a single per-role translation table, so pair elimination, pair-vs-claims and quiet-night
  logic work for any role that makes such a statement.

## Testing baselines

- `--passive` bot: a player who does nothing (waits, declines, never nominates, votes no).
  The town should sometimes win on its own, but a playing player should raise the win
  rate substantially. First measurement (150 seeds): passive 16%, playing bot 33%.
- After the consensus cap, smarter Poisoner, visibility rules (the bot now only sees what a
  player sees) and window-only sightings, over 300 seeds (1000–1149, 2000–2149): playing bot
  99/300 (33%) vs passive 47/300 (16%), against 115/300 (38%) vs 35/300 (12%) before. The
  bot lost about 2 points from the visibility rule alone; passive gained mostly from fewer
  pile-on executions (fewer executions overall). Seed-to-seed noise is about ±3 points per
  150-seed batch.
- After the roster (new script, secrets, 7/10 sizes), 150 seeds each (1000–1149): 7
  townsfolk, playing bot 57/150 (38%) vs passive 18/150 (12%); 10 townsfolk, 43/150 (29%)
  vs 15/150 (10%). The bot names one minion, so "both identified" is rare at 10. How often
  the new pieces came up in the playing runs (7 / 10): silences 115 / 231; totems hidden
  37 / 77, someone turned 10 / 14 (the bot never finds totems); Martyr choices 25 / 60,
  saves 0 / 12; knells 17 / 17; Scion rose 5 / 25; Veteran survived 10 / 10. Tests:
  `tools/test_roster.gd` covers setups and every new mechanic.
- After the death-tied night suspicion, Sleepwalker chance and spent-gift kill discount
  (bot updated to read gifts generally): 7 townsfolk 55/150 (37%) vs passive 14/150 (9%);
  10 townsfolk 40/150 (27%) vs 17/150 (11%).
- After playtest 13473's fixes (habits, unseen counts, ask-today changes; bot uses the
  counts): 7 townsfolk 61/150 (41%) vs passive 12/150 (8%); 10 townsfolk 38/150 (25%) vs
  13/150 (9%).

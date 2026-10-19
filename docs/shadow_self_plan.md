# Shadow good self: implementation plan

Status: planned (Oct 19). Backlog: "Shadow good self for evil" (section 4), "Rebuttals and
excuses" (section 3) and "Fake Medium readings" (section 2). This doc is the step-by-step
plan. Each step ends with a check, and steps should land as separate commits.

## Goal

Evil NPCs today don't form beliefs at all. `Mind.ledger_hear` returns early for evil, and
so do about 40 other `is_evil()` checks in `sim/mind.gd`. Every public act is a
hand-written rule in `sim/evil.gd`:
- argument replies come from `Argue._evil_mask`;
- votes from `Evil.evil_vote`;
- nominations from `Evil.evil_nomination`;
- replies to accusations from `Evil.evil_hear_accusation`;
- opinions from `Evil.town_view`, which is just `public_heat`.

The rules leave tells. Evil answers "partial" to nearly every argument that helps the
town, protects teammates absolutely, and never drifts toward the town's view.

The shadow self gives each evil NPC a second, good mind. It runs the normal good belief
pipeline on what that NPC really heard, with its bluff as its role. Public acts default to
what the shadow would do. The real evil brain overrides only when the stakes beat the
exposure.

**The boundary that must hold:**
- **Secret acts stay on the real evil brain:** kill, poison, breath, totem, evil intel and
  the evil plan. They use real knowledge.
- **Public acts go through the shadow:** speech, argument replies, opinions, claims,
  nominations, votes and gossip. A public act may use real evil knowledge only through
  the override.

## Settled design decisions (from the user)

1. **Override strictness.** Start strict: evil breaks cover only for a teammate under real
   threat. It gets looser as the game goes on, **for minions especially**. Late in the
   game minions shift from self-preservation to sowing chaos and follow their "evil id"
   more often. Their basic behaviour doesn't change; their caution does. The demon stays
   cautious longer.
2. **Belief in evil's own fake readings.** The shadow believes them more strongly than a
   townsperson believes their own reading, but not unshakably. It can still consider that
   "its" reading was poisoned when the evidence goes the other way. Being too adamant is
   itself suspicious.

## What exists today: heat and exposure

- **`Evil.public_heat(w, t)`** (`sim/evil.gd`): starts at 0.15 and adds, from
  `w.public_log`, 0.12 per accusation, 0.20 per nomination, 0.20 per public reading
  naming them and 0.04 per yes vote. It skips anything said by evil and is clamped to
  0..1.
  - **Used for:** evil nominating the scapegoat (when heat ≥ 0.45 − 0.15 × confidence),
    `town_view` (evil's mimicked opinion), and gossip about the scapegoat (heat ≥ 0.3,
    in `social.gd`).
  - **Not used for evil's own safety.** Nothing checks the heat on yourself or a teammate
    before speaking or voting.
- **`n.pressure`** (all NPCs, `npc.gd`): rises when publicly accused or nominated
  (`mind.gd` ~859, `world.gd` ~636) and when the player confronts them (`mind.gd`
  ~1052). It shrinks to 0.6× each night. It affects disclosure, gossip, claims and slips
  for evil too, but evil never reasons with it.
- **Evil intel** (`Evil.add_intel`): `threat` entries feed the kill, poison and breath
  target choices. `player_suspects` entries are recorded (`argue.gd` ~1070, `evil.gd`
  ~706, `mind.gd` ~1899 and ~1932) but **nothing reads them**. They are the ready-made
  input for exposure.
- **`evil_plan["caution"]`:** only about failed kills, and unrelated to this work.

So step 2 needs a new `Evil.exposure(w, n)`. The pieces above are its inputs.

## Step 0: warm-up bug fixes

- **Done (b8baa69, checked Oct 19):** silenced NPCs no longer approach the player or
  supply tavern gossip (`Social.approach_candidate`, `Mind.gossip`). The victim is no
  longer a "passer" for their own cottage's trace (`World._kill`). Both have tests in
  `tools/test_fixes.gd`.
- **Done Oct 19** (DESIGN, "Citing reasons"): reasons carry their source, and meeting
  accusations go silent / generic / hint / reveal. The original framing, kept for
  reference: **treat it as an evidence-provenance problem, not missing card creation.** Meeting opinions cite reasons the NPC never put out
  (Hollis citing his unshared Night Watch reading made only an opinion card). The rule:
  an NPC may cite a reason only if they've already made that claim, at least privately
  to the player.
  - Every reason an opinion can cite (`sus_why`, `Evil.cite`, `Evil.bluff_reason`,
    `decision_line` reason text) should carry a pointer to the claim or fact it rests on:
    a reading entry, a sighting belief, or a public event.
  - "Already claimed" means that pointer is shared, or is on the player's board with
    this NPC as source or via.
  - Unshared reasons fall back to vaguer wording ("something's off about them") or force
    the claim out first. The second is a design choice: it makes evil put its fakes out
    before leaning on them.
  - Don't fix it by minting a card at the moment of citing. That hides the provenance gap
    instead of closing it, and would let evil create evidence just by referring to it.
  - The shadow's reasons in step 2 go through the same gate.

**Check (for the open item):** a test where an NPC holding an unshared reading gives an
opinion about its subject, and the reason is vague or the reading is claimed first. Then
all `tools/test_*.gd`, a headless Godot parse check, and a bot baseline of 150 games at 7
townsfolk and 150 at 10. Record the baseline in DESIGN.md. It's the "before" for step 5.

## Step 1: the shadow mind, inspection only (no behaviour change)

**Done Oct 19** (see DESIGN.md, "Shadow good self, step 1"). It differs from the text
below in three ways:
- It's built on first use rather than at setup.
- The debug UI column isn't built yet; snapshots carry the data.
- The player's private cases and arguments don't reach the shadow yet; step 2 rewrites
  those paths anyway.

1. **Data.** Add `var shadow = null` to `sim/npc.gd`. For each evil NPC at setup
   (`world.gd`, after roles and bluffs are assigned), build a shadow NPC object:
   - copy traits, home, work, friends and rivals;
   - set its alignment to good and its role to the bluff from
     `w.evil_plan["bluffs"][id]`. A bluff of "" or none means a plain townsperson with no
     gift;
   - the shadow is not in `w.npcs` or `w.by_id`. Nothing that iterates the town may find
     it.
2. **Routing.** Audit every `is_evil()` early return in `sim/mind.gd`, one at a time. For
   each belief-updating function (`ledger_hear`, `_eff`, `reconsider`,
   `update_from_own_info`, `hear_accusation`, the public-event hearing in `world.gd`
   ~614, gossip intake, sightings intake), call the same function with `n.shadow` in place
   of `n` instead of returning. Keep a short list in DESIGN.md of which sites were routed
   and which deliberately stayed evil-only.
3. **What the shadow may know.**
   - Day sightings: yes.
   - Things said to this NPC: yes.
   - Public events: yes.
   - Night observations only if a good self with this bluff could have had them: from
     home or window, or on the bluff's own night duty (a Night Watch bluff keeps its
     `fake_watch`).
   - Never: anything seen while out doing evil work, the evil plan, evil intel, teammate
     identities, or kill knowledge.
   - The shadow knows it is good. Its suspicion of itself is pinned at 0, and it never
     suspects the real NPC's own id.
4. **Fake readings as own info.** Every `fake_info` entry the evil NPC generates goes into
   the shadow's info log as its own reading. Weight it with a new knob,
   `C.SHADOW_OWN_READING_WEIGHT`, around 1.2× a normal own-reading weight. It enters the
   same credibility and conflict machinery as a good NPC's reading, so poisoned and
   misled explanations stay available and can win when the evidence is strong. Add a test
   where a fake reading is clearly contradicted and the shadow comes to doubt it.
5. **Its own RNG.** The shadow pipeline must draw from its own `RandomNumberGenerator`,
   seeded from `seed_value` plus a hash of the NPC id, never from `w.rng`. Then step 1
   leaves the main random stream untouched.
6. **Debug view.** Add the shadow's suspicion and trust to the `snapshot` dlog event under
   a new key (`"shadow": {...}`). Don't overwrite the existing evil entries. Show it in the
   debug UI as "if good: …".

**Check:**
- **Same results with the shadow switched off.** Gate the new code behind
  `C.SHADOW_SELF = true/false`. The bot results JSON for seeds 1000–1149 must be
  **identical** with the flag on and off. If not, something in step 1 leaked into behaviour
  or the main random stream.
- New test in `tools/test_fixes.gd` or a new `tools/test_shadow.gd`: the shadow exists for
  each evil NPC, isn't in `w.npcs`, never suspects itself, and has no evil-intel or
  night-work beliefs.
- Spot-read two case logs (for example seeds 96773 and 55774 at 10 townsfolk): does
  "Isolde if good" look like a plausible townsperson?

## Step 2: public acts follow the shadow, with an override

**First slice done Oct 19:** argument replies, votes, and opinions of non-teammates, plus
exposure, caution, the override and the tell metric. See DESIGN, "Shadow good self, step
2, first slice", for the numbers and what's left.

0. **Refine heat first.** `public_heat` gives every implicating public reading the same
   +0.2 and never goes down. Before exposure and scapegoat scoring build on it:
   - weight each reading by how strongly it implicates: a Seer "yes" pair counts more than
     one of three in a Dowser count, and a Night Watch "seen out" or an Archivist pair
     naming a good role counts less;
   - cool heat a little on public clears and proven-good results;
   - decay older events by day.

   Keep the old function's callers (scapegoat nomination, `town_view`, gossip) on the new
   version, and log the parts.
1. **`Evil.exposure(w, n)`, from 0 to about 1.5:**
   - `public_heat` on n, but counting evil's own contributions too (the town can't tell
     them apart);
   - + 0.3 if the player is known to suspect n (`player_suspects` intel);
   - + 0.5 × `n.pressure`;
   - + 0.2 if n is currently nominated or on the block.

   Write it as named parts in a dictionary, like `_public_threat`, so it shows in the log.
2. **`Evil.caution(w, n)`, the override threshold:**
   - demon: `C.EVIL_CAUTION_DEMON` (start around 0.8), loosening slowly by day;
   - minions: `C.EVIL_CAUTION_MINION` (start around 0.7), minus `C.MINION_ID_DRIFT` per
     day after day 2 (start around 0.08), floored around 0.25. This is the late-game
     "evil id".
3. **Stakes, per kind of act:**
   - **Vote:** how much my vote changes whether a teammate hangs. High when the tally is
     at the threshold minus one, low when it passes or fails without me. A demon's life
     counts about twice a minion's.
   - **Argument or opinion:** how much agreeing would move the town against a teammate.
     Use the listener-weighted effect the conclusion already computes.
   - **Nomination:** naming a teammate is a high-stakes act. Not naming anyone is low.
4. **The rule.** For each public act, take the shadow's act. Override with the evil choice
   when `stakes − exposure_cost > caution`. The exposure cost is how much the evil choice
   breaks from the shadow's choice, times `exposure(w, n)`. Log both choices and the
   numbers (`think`, topic `"override"`), so playtests can see when cover broke.
5. **Wire it in:**
   - `Argue._evil_mask` (`argue.gd` ~1399): replace it with the shadow's stance from the
     normal good listener path, then the override.
   - `Evil.evil_vote`: shadow's vote, then the override. The special cases stay as
     override reasons: the Revenant with a hidden totem, the demon tying the block,
     replacing a teammate on the block.
   - `Evil.evil_nomination`: the shadow's normal nomination. Pushing the scapegoat becomes
     an override that is cheap when heat on the scapegoat is high.
   - `Evil.evil_hear_accusation`: the shadow's reply. The evil-intel side effects stay
     exactly as they are.
   - `Evil.town_view` and opinions: the shadow's suspicion.
   - Claims (`mind.gd` ~772 onwards): leave as they are for now. Bluff claims already
     follow the bluff.
6. **Throwing a teammate under the bus** now happens on its own. When the shadow suspects
   a teammate and the stakes are low, evil goes along with it.
7. **Re-pick the scapegoat daily.** Today it's chosen once at setup (`_pick_scapegoat`)
   and replaced only when that person dies (`ensure_scapegoat`). Make it a scoring
   function, run each morning, over living good candidates:
   - **momentum:** refined heat, plus how much the evil members' shadows suspect them, as
     a stand-in for "what the town thinks";
   - **fit:** how well they match lies already told (a fake sighting near a death, a fake
     reading naming them);
   - **dead ends:** a big minus for someone proven good, confirmed by a Clerk or cleared
     by a Gravedigger;
   - **switching cost:** a member who has publicly accused the old scapegoat pays to drop
     them, unless a new fact (a card) gives a reason. This keeps evil from flip-flopping,
     which would be a tell.

   **Ride, don't steer:** if the town is settling on a good person, that person usually
   wins on momentum. Evil's own fakes matter most when the town is settling on a
   teammate. Keep it a scoring function with named parts, so a "pattern fit" term can join
   later (see "Build with in mind").

**Check:**
- Update `test_argue`, `test_dialogue_decisions` and `test_beliefs` where they assert the
  old evil stances. Change the expectation, don't loosen it.
- Bot runs at 7 and 10 townsfolk, same seeds as step 0.
- **Tell metric.** Add to `game/case_metrics.gd`: for each argument, compare each evil
  listener's stance with the average good listener's stance on the same argument; report
  the mismatch rate for evil and for good. Expect evil far above good before this step and
  close to good after it, except at logged overrides.

## Step 3: rebuttals

1. When an NPC is publicly accused or nominated with a night sighting against them, they
   may answer with a gift that explains being out: Lamplighter, Veteran, Warden, Night
   Watch, Medium or a sleepwalker secret. Good NPCs with such a gift do it when exposure
   is high enough to beat their reasons for hiding (reuse the `_afraid` and
   hiding-the-gift logic). Their own-lie admissions are already built; reuse them.
2. The rebuttal is a claim, so it makes a card. Listeners give the accused grace scaled by
   how believable the claim is: corroboration, a role already claimed by someone else,
   whether it fits the sighting's block.
3. Evil rebuts with its bluff, but only when the shadow would, plus override. With the
   step 0 cite rule, the excuse is a card the player can check.
4. Optional: evil with no fitting bluff claims a fake secret.
5. **The desperation play:** "I don't know what's going on, but I know I'm not evil."
   Available to both sides when exposure is high and there's no fitting gift to claim.
   Good NPCs say it honestly; for evil it's a free bluff. Listeners give it a little
   grace, scaled by their trust in the speaker. It makes no card, since it claims
   nothing checkable. Keep its effect small so it can't save someone on its own.

**Check:** a scenario test where a Lamplighter is accused for a night sighting and
rebuts; a bot run comparing the hang rates of hidden night walkers (Lamplighter, Veteran,
Sleepwalker, Warden) before and after.

## Step 4: fake Medium readings from the shadow

In `evil.gd` around line 442, generate fake Medium readings from the shadow's view of the
dead's public record:
- fit what the dead were known to be doing that night (watching a block, guarding a door,
  their claimed gift);
- frame the scapegoat only where it matters: a block away from their home, near a death;
- don't frame someone every night.

Keep "each dead person once, most recent first".

**Check:** a test where a dead Night Watch is known to have watched the Square, and the
fake reading never puts what they saw on another block.

## Step 5: measure and write up

- 150 games each at 7 and 10 townsfolk. Compare win rate, wrongful executions, evil
  hanged per game, the tell metric and override counts against the step 0 baseline.
- Update DESIGN.md: a section on the shadow self, the knobs and their starting values,
  and the new baselines.
- Bot runtime: note it. There are 3 extra belief pipelines in a 10-player game.

## Gotchas and risk areas

**Leaks from shadow to real (the biggest risk)**
- The shadow is a separate object. It must not share a dictionary or array with the real
  NPC: `ledger`, `suspicion`, `npc_trust`, `beliefs`, `info_log`, `dialogue_memory`. Use
  `duplicate(true)` at creation and never alias afterwards.
- Anything that iterates `w.npcs`, `w.living()` or `w.by_id` must never see a shadow.
  That covers the evil team, votes, the map, metrics and the bot.
- Some `mind.gd` functions read the world through `w.by_id[n.id]`, not through `n`.
  Called with a shadow, they would quietly act on the real evil NPC. Grep each routed
  function for `by_id[n.id]` and similar.
- `dlog.think(n.id, …)` calls made from the shadow pipeline log under the real id. Tag
  them (`"shadow": true` in data, or a `"shadow:"` topic prefix), or the debug view and
  `trace.py` will mix the two minds.

**Information hygiene**
- The shadow must not learn from evil-only channels: `evil_share`, `add_intel`, the night
  walk while killing or poisoning, the first-night conference, or knowing which readings
  are fake. If the shadow ever suspects a good person *because* they're a threat to evil,
  something leaked.
- A real night sighting made while out doing evil work is a known gap. The shadow
  wouldn't have been out, so it doesn't get it. But the evil NPC may later want to lie
  using it. That's the override path, not the shadow's.

**Random stream and determinism**
- If the shadow draws from `w.rng`, every seed changes and step 1 can't be verified.
  Use its own generator.
- `_evil_mask` was written to keep "the same branch order and RNG draws as the original
  mask". Replacing it changes the main stream from step 2 on. That's expected. Re-record
  baselines and don't compare seeds one by one across step 2.
- `_afraid` and `_evil_reason` are deterministic hashes on the NPC id. Keep the shadow
  using the real id there, so fear and reasons stay consistent between the two.

**Interactions with recent rules**
- **Silent votes:** nothing is spoken at votes. Overrides must not add vote lines.
- **Cite only what's been claimed:** the shadow's opinion reasons must point at cards the
  NPC has actually put out. Its fake readings count only after evil has claimed them.
- **Corroboration** (`core_keys`, `word_factor`): a shadow must never count as a
  corroborating witness.
- **"Already" cues and `dialogue_memory`:** use the real NPC's memory for what was said
  out loud. The shadow's copy is only for its own belief bookkeeping.
- **Offers and trust:** the trust the player reads off an evil NPC (cues, disclosure)
  should come from the shadow, since a good self would warm to a kept promise. But the
  real `trust` field also drives evil decisions such as whom to share with. Decide which
  sites read which, and write it down.
- **Martyr reluctance:** an evil NPC bluffing Martyr should get the shadow's reluctance on
  votes. Make sure `registers_evil` and the gift checks keep reading the real NPC.
- **Breathstealer:** silencing stays on the real brain. A silenced shadow is meaningless:
  silence belongs to the real NPC, and the shadow only stops "speaking" because the real
  one can't.

**Tests and the bot**
- Existing tests that pin evil stances (`test_argue`, `test_dialogue_decisions`,
  `test_beliefs`) will fail at step 2 by design. Update them with intent; don't delete
  checks.
- `tools/autoplay.gd` reads `is_evil()` (around line 103). Check that it doesn't use evil
  NPCs' suspicion or stances as a signal. If it does, the bot's numbers will move for the
  wrong reason.
- `case_metrics` reads snapshots. Adding a `shadow` key must not change the existing
  fields.

**Balance**
- Evil will get stronger. The user is fine with that, but watch the 7-townsfolk game
  especially: fewer voices means one evil vote matters more.
- Too strict an override makes evil passive and gives away no tells at all. Too loose
  brings back today's tells. Use the tell metric and override counts as the gauge.
- Minion drift in late games can make minions reckless enough to out themselves, which
  makes the demon easier to find through the "night companions" pattern. That's
  acceptable, but watch it.
- Mind the 6- and 8-day limits: a later-game shift only matters if games last.

## Build with in mind (not this pass)

Evil needs to "world build": keep a coherent false story and adapt it as the town's
direction changes. This pass lays the groundwork; don't build these yet, but don't close
the doors either.
- **A shared story ledger.** The evil team keeps one record of what each member has
  claimed and faked, so new lies fit old ones. The fake Medium problem in step 4 is one
  case. The shadow is the consistency check: "would my good self believe this, given
  what's public?"
- **Coordination lag is a feature.** A scapegoat switch spreads only when evil members
  confer (at night or in a daytime meetup). A teammate who hasn't heard keeps pushing the
  old target; that visible split is a natural tell, so don't paper over it. Late in the
  game, minions in "evil id" mode could deliberately push a second target to split the
  town.
- **One pattern evaluator for both sides.** When good NPCs get pattern reasoning (the
  footprint and case-file idea: who keeps turning up near silencings, failed readings,
  deaths), evil should use the same evaluator in reverse. It frames the good person the
  evidence already half-fits. The scapegoat score in step 2 should gain that as a
  "pattern fit" term rather than a separate system.

## Out of scope here

- The Breathstealer redesign (still open). The shadow doesn't depend on it.
- Vote talk coming back. It's designed to sit on top of this, but not in this pass.
- Group conversations, the full-screen board, and new roles.

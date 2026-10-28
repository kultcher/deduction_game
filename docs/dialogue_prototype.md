# Dialogue prototype

Three voices (Agnes, Bartholomew and Constance) now cover the original five situations
plus argument responses and nominations. The workshop covers each of these. (Vote
explanations were removed on Oct 18: voting is silent until the meeting/rebuttal work.) Existing gameplay decisions and evidence cards remain authoritative. Other
characters use generic decision lines and retain their previous wording at the original
five hooks. This phase extends the merged implementation rather than replacing it.

## Current integration structure

Updated October 28, 2026 against `bounded-reasoning-fix` (`526d756`).
`docs/DIALOGUE_DESIGN.md` is the creative direction; this document records implemented
behavior. The three established voices remain the authored baseline.

- `sim/mind_dialogue.gd` owns private questions, approved daytime/night observations
  and conversation responses; existing role-definition disclosure hooks are preserved.
- `sim/mind_meeting.gd` owns public disclosure/readings and volunteered night sightings.
- `sim/mind.gd` keeps forwarding methods for existing callers rather than duplicate
  implementations of these behaviors.
- `sim/dialogue_contract.gd` filters delivery context to recognized public fields and
  attaches copied canonical payload, audience, speech act and relation to reports,
  bounded forms, fallback and resolved-decision results. Downstream evidence continues
  using the original simulation facts, never speech text.
- The default relation is `independent`, with no filler. `continuation` is retained as
  a silent compatibility alias; safe scene joins still require explicit provenance.

No full fifteen-voice expansion, new interpretation/reaction layer or serious-event
activation is implied. Those design targets require separately authored content and
simulation-approved event context. Existing pressure/warmth cues remain tone only.

Integration validation: Godot 4.7.2 import passed. Eleven relevant suites passed:
`test_dialogue`, `test_dialogue_decisions`, `test_role_def_poc`, `test_case_eval`,
`test_backlog_batch4`, `test_npc_interactions`, `test_sighting_followup`,
`test_workshop_card_answers`, `test_fixes`, `test_board`, and `test_workshop_presentation`.
The role suite needed three fixture corrections exposed by the incoming branch:
select living evil NPCs through `living()`, check the `minion` metadata flag rather
than a nonexistent role kind, and establish a public Gravedigger claim before testing
the public-claim timing gate. Its final rerun passed all 148 checks. These are test
preconditions/API repairs, not changes to role behavior.

## Try it

For the remaining twelve voices, start with
[the first writing-pass review sheet](DIALOGUE_VOICE_SKETCHES.md). The scene below
also has a **Voice calibration — first writing pass** section comparing all fifteen
on four basic chunks. These are fixed editorial samples; changing them never enables
a new live voice or records delivered dialogue. The comparison controls above that
section still apply to the original three-voice composer only. The editable fixture
source is `tools/dialogue_voice_sketches.json`; `dialogue_preview.gd` prints it too.

Open `ui/dialogue_lab.tscn` in Godot and **Run Current Scene (F6)**. Or run:

```sh
godot --path . res://ui/dialogue_lab.tscn
```

The workshop shows all three characters side by side. Choose a situation, change trust,
pressure, audience or friendship, and press **Speak / ask again**. Changing a control
previews the next response without recording delivery. **Reset conversation memory**
starts fresh. These are explicitly synthetic scenarios, with identical underlying
statements for comparison; no live case is loaded. The main game UI is untouched.

For a printable comparison, including a listener-memory example:

```sh
godot --headless --path . --script res://tools/dialogue_preview.gd
```

Normal play also uses the composer at the integration points below. The named characters
must be present in that case; their existing disclosure/decision rules still determine
whether a situation occurs. The workshop is the reliable way to hear every example.

## Voices

- **Agnes:** warm and socially attentive, inviting someone into the conversation.
- **Bartholomew:** economical and blunt, without becoming magically more certain.
- **Constance:** formal and exacting, drawing attention to accounts and interpretation.

Ordinary reports preserve the approved statement verbatim and change delivery around it.
The bounded direct-presence form described below retains the canonical statement while
allowing authored speech and shared-scene elision.
The two bounded forms for refusing whereabouts and revising a belief have authored
sentence structures as well. For example, on reconsidering the same argument:

- Agnes: "I've been thinking about your argument that Edda was poisoned on night 2.
  I brushed it aside before. Perhaps I shouldn't have."
- Bartholomew: "About your argument that Edda was poisoned on night 2: I dismissed that.
  Might deserve another look."
- Constance: "I previously gave little weight to your argument that Edda was poisoned
  on night 2. I now consider it more plausible."

These lines acknowledge an existing change in weight. They do not establish that the
poison claim is true. An affectionate response can still explicitly suspect its subject.

## How it works

1. The simulation selects a statement/disclosure using the existing rules, including
   choosing an evil character's fabricated account.
2. The caller supplies an intent, approved sentence, stable event ID and only relevant
   delivery cues. `sim/dialogue.gd` receives no world or NPC object and performs no
   reasoning about truth, roles, secrets, or evidence.
3. `sim/dialogue_voices.gd` supplies authored lines for the original five intents.
   Unsupported characters/intents fall back to the original statement. Resolved decisions
   use `sim/dialogue_decisions.gd`, with a generic fallback and three authored voices.
4. The existing speech event carries the result. Evidence creation is unchanged.

| Situation | Live integration | Authorization |
|---|---|---|
| Report information | `Mind.info_line`, private gift answers and meeting readings | Caller has already approved disclosure; uses the report even if fabricated |
| Be doubted | `Mind.press`, first spoken response to a relevant challenge | The player actually presented a relevant card; unrelated-card response stays unchanged |
| Discuss a friend | `Mind.answer_opinion` | Same closeness threshold and scapegoat exclusion as the existing "We're close" line |
| Conceal a secret | Stonewall branch of `Mind.answer_night` | Decision to refuse has already happened; composer never receives the concealed information |
| Revise a belief | Queued `remarks` consumed when the player starts a conversation | Existing reconsideration logic has queued an argument for comment |
| Answer a deduction | `Argue.evaluate`, private and meeting presentations | Existing agreement, quality, and competing-explanation weights select approved speech content |
| Nominate | `Mind.next_nomination` | Target and the existing disclosure-approved citation have already been chosen |

## Phase two: resolved decisions and continuity

The decision renderer accepts a small descriptor, never a world/NPC or private reasoning
log. For good NPCs, argument replies can cite the strongest evaluated alternative, weak
support, low evidence quality, a distrusted source, or an already stronger suspect. These
are descriptions of the current evaluator's judgment, not a new reasoning engine.
In particular, freeform arguments do not gain logical deductions from this layer.

Delivery history is keyed by conclusion and audience and stores the supplied facts,
expressed stance, and explanation. Repetition, added evidence, and changed assessments
receive different lines. Removing support is not presented as adding evidence. The
latest expressed accusation across audiences can be acknowledged when the same NPC
subsequently votes no. This does not create a promise or alter their vote.

Good vote explanations prefer a factor that tipped the actual result, otherwise the
strongest contribution toward that result. They can explain trust, an existing nominee
on the block, a preference to spare, or the player's intervention. Evil speakers use
the same vocabulary for public cover; their teammate and scapegoat calculations never
enter the renderer. The existing evil strategy and random draws are preserved.

Silenced characters do not deliver the new replies. Arguments evaluated silently during
an accusation/defence do not enter spoken history. Neither vote explanations nor argument
phrasing create evidence cards or feed back into NPC beliefs.

Question cost uses the explicit response flag `repeated`, not English text. This retains
the existing one-free-repeat-per-conversation rule, independently of whether the wording
acknowledges a repeat, a new audience, or a changed assessment. Keep the flag on all
response producers when extending private interactions.

Reporting chooses one opening in this priority: repeated delivery to this listener,
high pressure (>= 0.8), low trust (< 0.3), ordinary report. Explicit `speech_act` values
`answer` and `volunteer` select separate authored openings within those tones. Audience
does not determine the speech act: a private speaker can volunteer, and a town speaker
can answer. An explicit `warm: true` selects a warmer ordinary opening; pressure,
guarded delivery, and repetition take priority. Warmth is optional presentation context,
not a deduction from friendship or hidden state. Trust/pressure select tone only.
Relationship and reconsideration cues cannot be replaced by mood. The optional request
for confidentiality is available to callers and demonstrated in the lab, but is not
automatically inferred from a reading being private.

`NPC.dialogue_memory` stores delivered statements and variant counts by audience, for
one case. Variants cycle deterministically without drawing from the world's RNG. Memory
keys include the exact statement so a changed account is never called "the same answer".
Private and meeting delivery are conservatively kept separate; hearing a private claim
does not imply the town heard it. The system does not yet propagate a public delivery to
every listener's memory or normalize equivalent time phrases across days.

## Turn composition

The dialogue composer can now receive an **ordered speaker turn** through
`Dialogue.compose_turn(id, approved_intents, context, memory, preceded)`. Each intent
continues to carry an approved, exact factual statement and event ID. `preceded`
means the caller has already supplied a spoken line in the same uninterrupted turn
(for example, "I'm the Seer"). An opening report uses existing trust, pressure and
repetition behavior; continuing reports suppress a fresh "Here is my account" lead-in.

An approved `relation` on a report selects optional authored connective speech:
`independent` (the default, **no** connective), `continuation` (silent legacy alias), `development`, `contrast`,
`transition`, or `correction`. The caller must explicitly authorize the relation.
The composer does not read a statement to decide what contrasts or what is true.
Agnes, Bartholomew and Constance have different connective styles. Non-voiced
characters continue to use the unchanged approved statements. Confidentiality
requests appear at most once at the end of a composed turn and never in town speech.

`Mind.info_lines` now uses this path for multiple readings when privately revealing
a gift and when publicly claiming a reading role at a meeting. The preceding role
claim is accounted for, so even the *first* reading avoids starting another
speech. Every report remains a separate speech event, with its original statement
and fact card; evidence and disclosures are unchanged. Single reports still use
`info_line` and its established behavior.

The lab offers three multi-line examples: role reveal with successive readings,
two people sharing a scene, and transitions/corrections. Its previews use
copied dialogue memory, so only "Speak" commits delivery.

**Scope:** this is turn composition, not conversational momentum between separate
questions, and not a general overhaul of evidence-based rebuttals, excuses,
social grievances, or offers. The latter need explicit approved responses from
the NPC logic. In particular, no hidden role, secret or lie status enters
connective selection.

`tools/test_dialogue.gd` covers turn sequencing, content preservation, repeated
delivery, confidentiality, explicit connectives and truth-independent phrasing.

### Semantic grouping of direct presence

Once disclosure is approved, construct a bounded intent with
`Dialogue.Observations.presence(source_id, subject_id, subject_name, place_id,
day, phase, place_label, time_label)`. It carries an immutable canonical sentence,
stable event ID, subject slots and an explicit scene:

```gdscript
{"source": "agnes", "place_id": "loc:tavern", "day": 2, "phase": 2,
 "how": "direct", "predicate": "presence"}
```

Use `loc:` and `block:` prefixes so a named venue cannot be mistaken for its whole
neighborhood. Numeric day/phase establishes identity; display time alone never does.
Two **adjacent** presence reports in one speaker turn may share their place/time
wording only when the complete scene, display labels and direct observation method
match, their subjects differ, and their relation is independent, continuation or development.
The three baseline voices answer the synthetic tavern example as follows:

- Agnes: "Oh, yes. I did see Jory at the tavern yesterday evening. Fenwick was there too."
- Bart: "Right. Saw Jory at the tavern yesterday evening. Fenwick too."
- Constance: "As I recall, Jory was at the tavern yesterday evening. Fenwick was there as well."

The result still contains one entry per approved intent, with its original `statement`
and `event_id`. Each member enters listener-specific repetition history; a separate
turn starts with a complete place/time reference. No arrival, departure, shared
journey or conversation is inferred from co-presence. This initial form covers direct
daytime presence only. Missing, malformed or unsupported provenance, uncertainty,
hearsay, modified canonical prose, repeated subjects, intervening statements and
explicit contrast/correction/transition prevent elision. Plain strings are never parsed
to discover scene relationships. Unvoiced characters retain canonical statements.

`Mind.answer_today` builds these descriptors **after** its existing recall, gossip,
teammate, visible-pair and disclosure filters. Witnessed conversations retain their
separate, complete predicate. Self-whereabouts narration remains the start of that
answer when present. Night reports, stayed-home observations, window departures,
whereabouts slips and opinion followups now group using explicit scene keys and
authored before/after slots instead of searching prose for character names. Their
source, block, time, method, predicate and qualifications must match. Their original
fact dictionaries, order and card creation paths remain intact.

Live reading answers explicitly use `speech_act: answer`; public meeting readings
and volunteered night sightings use `volunteer`. The `info_line` / `info_lines`
helpers also accept an explicit speech act for other callers. No solver, belief,
truth, disclosure gate, question cost, or gameplay RNG rule is changed.

The lab's **Speech act** selector and **Warm delivery** toggle combine with the
existing pressure/trust/audience controls. The shared scene appears as one paragraph;
canonical source statements remain visible above it. `tools/dialogue_preview.gd`
also prints the complete flow fixtures, including these three exact examples.

## Across-exchange conversational continuity

A private conversation now has a **short-lived interaction scope** independent of
case-long disclosure/argument memory. The game calls
`Dialogue.begin_conversation(n.dialogue_memory)` when the player starts a
conversation or accepts an NPC approach. After the NPC has actually spoken to
answer a question, the game records only the last **player-expressed action**
and **named subject** with `Dialogue.record_exchange`. Invalid commands and
unspoken responses do not create a false preceding act; an unrelated question
breaks immediate adjacency.

`Dialogue.exchange_cue` currently recognizes a deliberately small set:

- A challenge to an NPC's gift followed by their subsequently approved **first
  gift reveal**: the usual standalone "I'll trust you" opener becomes an authored
  acknowledgement of the pressure. This never forces the NPC to disclose a gift;
  if they still refuse, they continue refusing. Nighttime whereabouts challenges
  are distinguished from gift challenges.
- A player accusation against person X followed immediately by asking that same
  NPC's opinion about X: the opinion acknowledges the accusation, without
  implying agreement. Questions about different people do not inherit the cue.
- A second immediate opinion question about the same subject: the NPC recognizes
  that they were just asked. A second refusal uses a distinct but equally
  non-disclosing line rather than "It's not my place to say" again.

Agnes, Bartholomew, and Constance have independent authored wording for all
three contexts. Unvoiced characters keep the prior behavior. No new NPC
decision rules, suspicion modifiers, evidence cards, or assertion templates are
introduced; even fabricated reading/role claims are composed from the same
approved statements as honest claims. This is **immediate adjacency**, not a
persistent long-term transcript or automatic reasoning about past objections.

The lab now includes three synthetic across-exchange examples. It primes a
fictional preceding action in preview-only memory, and records the current
answer only on "Speak". The next preview of that same topic therefore sees
the newly delivered exchange. Regression checks also exercise the real
`tell edda <card>` → `ask about edda` → repeat-question path.

### Parallel work boundary

The original turn-flow work reviewed Opus's `claude/case-reasoning` at stable
commit `8e8f05a` and identified overlapping presentation hooks in `sim/mind.gd`
and `game/game.gd`. It used already-approved replies and the player's expressed
actions, without reading private solver reasoning or modifying Opus's branch.

For the semantic-grouping followup, PR #19 was already merged. The existing
`feat/dialogue-turn-flow` branch was fast-forwarded to current main `cc53a1c`, which
already contains `8e8f05a` and the later case-reasoning integration. The remote
`claude/case-reasoning` branch is no longer advertised. Changes here touch presentation
hooks in `sim/mind.gd` and `game/recent_sightings.gd`; workshop evaluation, role
definitions and game command handling are unchanged.

## Scope and extensions

This is a writing/behavior prototype, not a complete dialogue rewrite. It does not yet
author greetings, confessions, bereavement, betrayal or execution scenes, record new
promises, or track a full conversational history. Existing narration and ordinary lines
outside these hooks remain in place. Plain-card accusation/defence responses keep their
existing wording; richer argument replies currently apply to filed deductions. More
consequential personal scenes should get bespoke writing rather than automatically adding adjectives to every utterance.

Add voices in `dialogue_voices.gd` and `dialogue_decisions.gd`; add situations only when
an existing event can authorize the reaction. New factual information should enter through the game's normal
facts/disclosure pipeline. Do not turn hidden alignment, actual poisoning, or `entry.true`
into delivery cues. Good and evil speakers must be able to use exactly the same voice.

Additional bounded forms should preserve explicit slots (source, target, time, place,
uncertainty) and have tests that exercise misinformation as well as honest accounts.
Keep the canonical statement separate from its phrasing; never parse prose back into
beliefs or evidence.

## Validation

Semantic-grouping followup, October 27, 2026: Godot **4.7.2** imported the project
without parse/compile errors. All **12/12** relevant suites passed through
`tools/run_gd_tests.py` (which checks printed failures as well as exit codes):

```sh
python tools/run_gd_tests.py --godot <godot-executable> \
  test_dialogue test_dialogue_decisions test_backlog_batch4 test_npc_interactions \
  test_fixes test_sighting_followup test_meeting_stream test_board \
  test_workshop_card_answers test_workshop_presentation test_case_eval test_role_def_poc
```

The final provenance guard was separately rechecked with `test_dialogue` and
`test_backlog_batch4`. The printable preview reproduces all three requested examples
exactly. Tests cover malformed/missing provenance, different scenes and times,
uncertainty/attribution, duplicates and turn boundaries, pressure/warmth precedence,
preview-only memory, live honest/evil accounts, unchanged facts/RNG and separate case
cards. The meeting suite verifies streamed/batched testimony, cards, beliefs and trust
agree for seeds 42, 7104 and 54875 over three meetings each.

`test_backlog_batch4` passes all 474 checks but emits shutdown resource-leak diagnostics.
Running that suite against the unchanged `cc53a1c` snapshot reproduces the same RID and
ObjectDB leak counts. This followup does not claim a fresh whole-game A/B balance run;
the older experiment below belongs to the earlier prototype.

For focused iteration:

```sh
godot --headless --path . --script res://tools/test_dialogue.gd
godot --headless --path . --script res://tools/test_dialogue_decisions.gd
```

Checks include every workshop scenario, context guards, unchanged evidence, source attribution,
private/public delivery, per-listener repetition, no secret leaks, identical phrasing for
identical honest/fabricated readings, no gameplay RNG consumption, live conversation
hooks, new-case reset, and the workshop's controls/memory behavior. Decision checks cover
the actual argument/command/vote paths, repeat costs, competing explanations, silent
evaluation, latest spoken stance, silence, and correspondence between speech and votes.

Earlier prototype validation (before the semantic-grouping followup): the existing
social, beliefs, arguments, outcomes, board and UI suites were also run.
All assertions passed. The existing UI test emits a drag-state diagnostic and a font
resource leak at shutdown on both the base and this branch; neither originates in the
new workshop, whose headless test completes without those errors.
Ten active and ten passive cases (seeds 8200-8209) produced identical result JSON on this
branch and merged base `9c94fc3`, including case outcomes and player theories. Their full
JSONL event streams also match after excluding only player-facing command output and the
new `vote_tally.speeches` field. This checks mechanical preservation; it is not a new
balance estimate. The existing night-movement contradiction templates are outside this
dialogue change and still need the separate evidence-system correction discussed in review.

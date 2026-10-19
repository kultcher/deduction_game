# Dialogue prototype

Three voices (Agnes, Bartholomew and Constance) now express five situations through a
small composer: reporting information, answering a challenge, discussing someone close,
withholding whereabouts, and reconsidering an argument. Existing gameplay decisions and
evidence cards remain authoritative. Other characters retain their previous wording.

## Try it

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

Reporting preserves the approved statement verbatim and changes the delivery around it.
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
3. `sim/dialogue_voices.gd` supplies authored lines for a named character. Unsupported
   characters/intents fall back to the original statement without touching memory.
4. The existing speech event carries the result. Evidence creation is unchanged.

| Situation | Live integration | Authorization |
|---|---|---|
| Report information | `Mind.info_line`, private gift answers and meeting readings | Caller has already approved disclosure; uses the report even if fabricated |
| Be doubted | `Mind.press`, first spoken response to a relevant challenge | The player actually presented a relevant card; unrelated-card response stays unchanged |
| Discuss a friend | `Mind.answer_opinion` | Same closeness threshold and scapegoat exclusion as the existing "We're close" line |
| Conceal a secret | Stonewall branch of `Mind.answer_night` | Decision to refuse has already happened; composer never receives the concealed information |
| Revise a belief | Queued `remarks` consumed when the player starts a conversation | Existing reconsideration logic has queued an argument for comment |

Reporting chooses one opening in this priority: repeated delivery to this listener,
high pressure (>= 0.8), low trust (< 0.3), ordinary report. Trust/pressure select tone only.
Relationship and reconsideration cues cannot be replaced by mood. The optional request
for confidentiality is available to callers and demonstrated in the lab, but is not
automatically inferred from a reading being private.

`NPC.dialogue_memory` stores delivered statements and variant counts by audience, for
one case. Variants cycle deterministically without drawing from the world's RNG. Memory
keys include the exact statement so a changed account is never called "the same answer".
Private and meeting delivery are conservatively kept separate; hearing a private claim
does not imply the town heard it. The system does not yet propagate a public delivery to
every listener's memory or normalize equivalent time phrases across days.

## Scope and extensions

This is a writing/behavior prototype, not a complete dialogue rewrite. It does not yet
author greetings, confessions, bereavement, betrayal or execution scenes, record new
promises, or track a full conversational history. Existing narration and ordinary lines
outside the five hooks remain in place. More consequential personal scenes should get
bespoke writing rather than automatically adding adjectives to every utterance.

Add voices in `dialogue_voices.gd`; add situations only when an existing event can
authorize the reaction. New factual information should enter through the game's normal
facts/disclosure pipeline. Do not turn hidden alignment, actual poisoning, or `entry.true`
into delivery cues. Good and evil speakers must be able to use exactly the same voice.

Additional bounded forms should preserve explicit slots (source, target, time, place,
uncertainty) and have tests that exercise misinformation as well as honest accounts.
Keep the canonical statement separate from its phrasing; never parse prose back into
beliefs or evidence.

## Validation

```sh
godot --headless --path . --script res://tools/test_dialogue.gd
```

Checks include all five scenarios, context guards, unchanged evidence, source attribution,
private/public delivery, per-listener repetition, no secret leaks, identical phrasing for
identical honest/fabricated readings, no gameplay RNG consumption, live conversation
hooks, new-case reset, and the workshop's controls/memory behavior.

The existing social, beliefs, arguments, outcomes, board and UI suites were also run.
All assertions passed. The existing UI test emits a drag-state diagnostic and a font
resource leak at shutdown on both the base and this branch; neither originates in the
new workshop, whose headless test completes without those errors.
Ten active and ten passive cases (seeds 8200-8209) produced identical result JSON on this
branch and its unchanged base, including case outcomes and player theories. This checks
mechanical preservation; it is not a new balance estimate.

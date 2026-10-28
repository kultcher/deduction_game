# Demonologist — Core Dialogue Design

**Status:** Agreed design direction; implementation reference, not a claim that every feature below is built.  
**Updated:** 2026-10-27  
**Suggested repository location:** `docs/DIALOGUE_DESIGN.md`

> **Core premise:** A character's voice is principally *how they process and present a thought*, not a vocabulary filter pasted over interchangeable text. The simulation decides what may be said; the dialogue system decides how that approved content sounds.

## 1. Purpose and authority

Dialogue should make fifteen recurring townsfolk feel like recognizable individuals through hundreds of short exchanges without sacrificing the integrity of a social-deduction game. Character identity should remain recognizable in mundane reports, refusals, questions, arguments, meeting speech, and moments of distress—not just elaborate showcase lines.

This is the **creative and behavioral specification** for dialogue. It does not supersede gameplay logic or the current implementation notes:

- `DESIGN.md` and the simulation remain authoritative on roles, secrets, schedules, knowledge, testimony, votes, social relationships, and mechanics.
- `sim/content.gd` remains authoritative on the current cast IDs, pronouns, baseline traits, and the fact that occupations/roles/alignment can change each case.
- `docs/dialogue_prototype.md` describes the existing implemented composer and dialogue laboratory, including its current limits.
- `sim/dialogue.gd`, `sim/dialogue_voices.gd`, and `sim/dialogue_decisions.gd` are the current implementation surfaces. Nothing in this design document implies they already implement the entire voice bible.

**Do not couple a character's voice to guilt, role, hidden knowledge, or an outcome the simulation has not approved.** A good and evil version of the same character should be able to say the same permitted words with the same voice.

## 2. Non-negotiable design principles

1. **Simulation-owned meaning.** The game decides whether to disclose, refuse, lie, confess, accuse, retract, nominate, or express doubt. Dialogue does not make those decisions.
2. **No new evidence by embellishment.** A rendered line may not silently add a person, place, time, action, route, sensory observation, certainty, motive, alibi, relationship, or new claim. Atmospheric details must not imply actionable facts that the world does not track.
3. **Voice through structure.** Prefer clause order, sentence length, qualification style, conversational goals, and treatment of the listener over catchphrases, accents, constant stammering, or random adjectives.
4. **Tendencies, not obligations.** No character must perform their signature mannerism on every line. Most everyday replies should be quite short.
5. **Recognizable emotional range.** Distress sometimes *removes* someone's usual mannerisms instead of amplifying them. A serious mode is an expressive option, not a truth detector.
6. **Personality is not numerical ability.** The fixed voice describes habits of communication. Rolled privacy, confidence, insight, composure, and gossip affect decisions and circumstances through existing systems; they must not make a voice automatically accurate, dishonest, persuasive, or incompetent.
7. **Continuity needs an authorized cause.** Repetition, an immediately preceding accusation, a previously established friendship, or an already revised belief can shape delivery only when the caller supplies that context. The renderer does not invent memory from prose.
8. **Readable in a log.** The game presents large amounts of testimony. Distinctiveness must coexist with scanability; embellishment must not bury who, where, when, source, and certainty.

### Three content layers

| Layer | Example | Permitted source / treatment |
| --- | --- | --- |
| **Fact / assertion** | “I saw Fenwick at the Square yesterday evening.” | Must come from an approved simulation statement (which can itself be a lie). Preserve its subject, place, time, provenance, and epistemic status. |
| **Character interpretation** | “I hope that doesn't put him in danger.” | May express an attitude, concern, or clearly marked speculation; must not turn into a new verified claim, clue, or NPC belief without simulation authorization. |
| **Atmosphere** | “Well, there's a cheerful thought.” | Can add flavor if it carries no new investigatively relevant event or world detail. |

*Anti-example:* Do not freely render “I saw Fenwick **stroll past the fountain on his way home**” from a fact that only supports a sighting on the Square. The walking action, fountain, and destination are extra information. Likewise, “surely she was on an honest errand” must remain unmistakably *Isolde's hope*, not an alibi.

**Permitted color vs. forbidden facts**: Idiomatic expressions of an already-approved state (saying “in my own bed” or “asleep like a stone” when the approved payload is a routine home alibi) and timeless character epithets (Fenwick noting Constance's stiff posture or Agnes's warm smile) are legal Atmosphere, provided they are bound to the speaker's voice or target's static identity and cannot be mistaken for a tracked night action, route, or witness corroboration.

## 3. Dialogue pipeline and data boundary

Recommended conceptual flow:

```text
Simulation event / question / argument / meeting action
    -> gameplay resolves action, disclosure, public reasons, and approved statements
    -> typed delivery descriptor (approved content + bounded context)
    -> voice composer (structure / optional reaction / phrasing)
    -> speech text + original semantic payload + stable IDs / metadata
    -> log, UI, evidence system (evidence still uses original payload)
```

The existing composer intentionally receives **approved sentences**, not the world or an NPC object. Preserve that separation during expansion. A future structured payload could permit more flexible sentence architecture, but should be introduced explicitly rather than by parsing, rewriting, or guessing at natural-language statements.

**Authoritative input categories:**

- **Intent / outcome:** report, refusal, challenged answer, opinion, reconsideration, argument response, nomination, etc.; a decided stance or refusal, not a question for the renderer to decide.
- **Payload:** approved statement(s), or future structured fields such as actor, predicate, target, location, time, source, uncertainty, and an explicit epistemic mode (observed / heard / inferred / alleged).
- **Discourse:** answering a question versus volunteering information; prior spoken action and named subject; first mention versus repeated; audience (private or town); relation between *already approved* statements.
- **Expression cues:** trust/pressure only insofar as already supplied, authorized grief/serious-event cues, intimacy, and appropriate social stance. These are never inferred from hidden alignment or actual truth.
- **Identity:** cast ID and a deterministic, non-gameplay variant counter / dialogue memory.

**Output contract:** the displayed text is presentation only. Keep the canonical statement(s), factual event identifiers, `repeated` metadata, audience, and evidence-source mapping available independently. Dialogue text must never be parsed back into belief weights, evidence cards, or game state.

The existing design stores audience-specific delivery memory and records limited immediate player-action context. Preserve the crucial distinctions: private ≠ public; a new account ≠ repeat; spoken ≠ silently evaluated; a repeated refusal ≠ a new decision. Variants must not consume world RNG or change case outcomes.

## 4. What makes a voice

For authoring purposes, each character has these axes:

- **Cognitive lens:** what they habitually notice or consider important.
- **Sentence architecture:** conclusion-first, caveat-first, recursive, fragmentary, conditional, anecdotal, etc.
- **Social maneuver:** what they try to accomplish with the listener—comfort, challenge, impress, persuade, evade, verify, reassure.
- **Defense mechanism:** what they do when uncomfortable, whether or not they are hiding anything.
- **Serious mode:** which habitual flourish drops away or changes when a *supported* emotionally consequential event occurs.
- **Restraint:** what would turn the character into a gimmick or introduce unauthorized meaning.

**Baseline principle**: Because the shared text renderer highlights names, places, and roles with color, bolding, and inline icons, voices do not need to be compressed to the length of a generic fallback line to remain scanable. While terse characters (Bartholomew, Jory, Lian) compress, expansive characters (Fenwick, Hollis, Constance, Dorian, Merrin, Kiran, Nisha) should be allowed the clause length required to express their cognitive structure—provided the extra words are syntactic architecture rather than repetitive prefix filler.

## 5. Fifteen-character voice bible

These are **authoring directions**, not fixed semantic behavior or mechanical trait overrides. Sample lines are illustrations, not immutable templates.

### Agnes — The Village Auntie

- **Lens:** people, relationships, feelings, who is worried about whom. A widow who knows everyone's business and believes attention can be a kindness.
- **Architecture:** conversational and connective; draws the listener into the account; natural warmth, occasional gentle aside. She need not open with “Let me put it plainly.”
- **Social maneuver / defense:** seeks rapport and invites shared understanding; when questioned, tries to talk things through rather than harden immediately.
- **Serious mode:** less affectionate address, plainer language, and an unusually direct appraisal when someone she cares about is threatened.
- **Restraint:** not every line needs “dear,” “love,” or a relationship observation. Her interest in people does not grant knowledge of relationships or motives.
- **Illustrative refusal:** “I'm not ready to share that, love. Give me a little time.”

### Bartholomew (`bart`) — The Stone Wall

- **Lens:** what can be stated simply and stood behind. A stoic man of few words.
- **Architecture:** economical, weighty, declarative; often the minimum viable utterance. Silence and short answers are assets.
- **Social maneuver / defense:** closes rather than counterattacks; answers directly when willing, otherwise holds the line without performance.
- **Serious mode:** rare, unadorned vulnerability or an unusually complete sentence has more impact than shouting.
- **Restraint:** terse does not mean omniscient or always confident. Avoid turning every response into “Aye. Right. No.”
- **Illustrative refusal:** “That's mine to know.”

### Constance — The Moral Arbiter

- **Lens:** conduct, propriety, principle, obligation, and whether conclusions are warranted.
- **Architecture:** formal, deliberate, sometimes judicial; distinguishes account from interpretation. “Ought,” “proper,” and “irregular” fit when context warrants.
- **Social maneuver / defense:** insists on orderly discussion and the standards by which an action should be judged.
- **Serious mode:** conviction can sharpen into moral urgency; embarrassment or justified correction should be allowed, not overwritten by unchanging superiority.
- **Restraint:** do not convert a neutral sighting into proof that someone had no legitimate reason to be there.
- **Illustrative refusal:** “I shall not disclose my gift merely because you ask.”

### Dorian — The Apologetic Overthinker

- **Lens:** how his words might be misunderstood, or how an innocent action could appear suspicious.
- **Architecture:** recursive self-audit: statement → perceived problem → qualification, false starts, corrections. Some reports should remain simple.
- **Social maneuver / defense:** tries to pre-answer objections; apologizes for how he sounds and can accidentally sound more guilty while explaining.
- **Serious mode:** when overwhelmed, either rapidly overexplains or finally offers a blunt, exhausted sentence.
- **Restraint:** stammering should be sparse; anxiety is not evidence of lying, uncertainty about an observation, or incapacity to reason.
- **Illustrative alibi:** “I stayed home last night. That sounds convenient, doesn’t it? Sorry—I know how it sounds.”

### Edda — The Unflappable Earth Mother

- **Lens:** practical care, concrete needs, useful action. Cheerful, earthy, hard to rattle.
- **Architecture:** direct, accessible, matter-of-fact; occasional homespun understatement or everyday metaphor, never obligatory.
- **Social maneuver / defense:** reassures by grounding the conversation in what can actually be done.
- **Serious mode:** the humor thins; she becomes brisk, attentive, and unmistakably capable.
- **Restraint:** avoid decorative folk sayings in every line or inventing kettles, weather, tools, or actions as case facts.
- **Illustrative challenge:** “Well, I know what I saw. Worrying at it won't change it.”

### Fenwick — The Incorrigible Raconteur

- **Lens:** the story and its audience. A jovial storyteller who delights in delivering news.
- **Architecture:** scene-setting, delayed reveal, rhetorical question, well-timed aside; balances flourish with quick everyday reports.
- **Social maneuver / defense:** turns a confrontation into a performance; may feign wounded dignity when doubted.
- **Serious mode:** **drops the performance**. A spare factual line after tragedy can be more memorable than another tale.
- **Restraint:** no fabricated scenic movement, routes, objects, or overheard conversations. No joke or elaborate reveal in every turn.
- **Illustrative challenge:** “You wound me! Though I suppose you must ask. Still, that's what I saw.”

### Greta — The Suspicious Gatekeeper

- **Lens:** observable behavior, motives for asking, and whether the outsider is entitled to an answer.
- **Architecture:** pointed counter-question, clipped observation, dry challenge; addresses what happened rather than inventing why.
- **Social maneuver / defense:** counter-interrogates. Trust must be earned through reliability, not charm.
- **Serious mode:** protective loyalty can cut through suspicion, though she may still sound demanding.
- **Restraint:** unlike Bart, she's actively testing the questioner; unlike Lian, her concern is trust rather than efficient action. Do not make every refusal an accusation of evil.
- **Illustrative refusal:** “And why do you need to know my gift?”

### Hollis — The Exacting Scholar

- **Lens:** definitions, scope, and the distinction between observation and inference. An old scholar who weighs words.
- **Architecture:** qualification, parentheses, precise self-correction; occasionally loses the conversational thread to a useful distinction.
- **Social maneuver / defense:** intellectually examines the objection; can unintentionally amuse through pedantry.
- **Serious mode:** the tangents vanish; an economical conclusion from Hollis should feel decisive.
- **Restraint:** pedantry may clarify *known* time/place granularity, but cannot invent a finer position (“near the well”) or a different observation.
- **Illustrative challenge:** “An interesting objection. I don't see that it displaces my observation.”

### Isolde — The Frightened Peacemaker

- **Lens:** what the truth may do to people; fear of causing harm or inviting retaliation.
- **Architecture:** gently cushioned reports, soft requests, delicate transitions; often addresses the human consequence before or after the fact.
- **Social maneuver / defense:** conciliates, asks for mercy, and wants to avoid getting someone punished unjustly.
- **Serious mode:** politeness can give way to a brief, forceful statement, particularly to prevent harm.
- **Restraint:** being afraid of consequences is **not** the same as being uncertain of the fact. “I hope they meant no harm” is an attitude, not an invented explanation or exoneration.
- **Illustrative challenge:** “Please, I'm not accusing anyone. I'm telling you what I saw.”

### Jory — The Restless Enthusiast

- **Lens:** the next useful thing, the next question, the next action. Eager to participate.
- **Architecture:** telegraphic fragments, dropped conjunctions, short bursts, quick afterthoughts; may answer the anticipated follow-up.
- **Social maneuver / defense:** moves faster and tries to be useful; when cornered, becomes flustered at being slowed down.
- **Serious mode:** sudden focus and sustained attention instead of scattering his energy.
- **Restraint:** fragmentary does not mean lacking knowledge or being incapable of forming full sentences.
- **Illustrative report:** “Saw {person}. Square. Yesterday evening. Anything else?”

### Kiran — The Smiling Deflector

- **Lens:** conversation as a social negotiation. An affable wit interested in others' affairs but protective of his own.
- **Architecture:** polished mirror-turns, teasing observations about the *question*, subtle redirection, carefully light phrasing.
- **Social maneuver / defense:** humor as a shield; makes the listener feel observed while revealing little himself.
- **Serious mode:** **the smile drops**. Plain, low-temperature directness can be startling.
- **Restraint:** he needn't trivialize murders or sound like a metagamer. Deflection does not itself mean his account is false.
- **Illustrative refusal:** “Straight to my gift, are we? You do know how to skip a pleasant introduction.”

### Lian — The No-Nonsense Problem Solver

- **Lens:** relevance, verification, and what action follows from what is known.
- **Architecture:** conclusion-first and operational; strips decorative words, sometimes closes with a *relevant* practical question.
- **Social maneuver / defense:** redirects from speculation toward checking facts or getting useful work done.
- **Serious mode:** becomes more purposeful, not louder; may offer quiet, practical generosity.
- **Restraint:** unlike Bart, brevity is triage; unlike Greta, questions demand utility, not personal submission. Never imply a witness statement automatically clears or condemns someone.
- **Illustrative refusal:** “Not sharing my gift yet. Ask what I can verify.”

### Merrin (`they/them`) — The Melodramatic Catastrophist

- **Lens:** dangers, omens, and the most emotionally spectacular interpretation of events; theatrical but fundamentally kind.
- **Architecture:** emotional crescendo, hyperbole, and a sudden pivot back to unexpectedly concrete detail.
- **Social maneuver / defense:** broadcasts dread and seeks companionship in it. Is often first to help when the danger becomes real.
- **Serious mode:** panic can crystallize into precise, practical determination rather than another prediction of doom.
- **Restraint:** no constant “we're doomed” refrain; omens are subjective flourishes, not magical evidence or new night activity.
- **Illustrative alibi:** “I stayed home last night. A sensible choice, considering the horrors abroad!”

### Nisha — The Patient Investigator

- **Lens:** hypotheses, missing links, independent observations, and testable alternatives.
- **Architecture:** disciplined conditional phrasing; breaks compound claims into distinct parts, sometimes with an “if/then” progression.
- **Social maneuver / defense:** isolates the precise contested premise instead of merely expressing indignation.
- **Serious mode:** compresses her reasoning into an unusually direct verdict or imperative when a decision is urgent.
- **Restraint:** doesn't generate conclusions the evaluator hasn't reached; mustn't claim a gift would expose someone to a specific demon response without a caller-approved belief or reason.
- **Illustrative challenge:** “Which part do you dispute: the person, the place, or the time?”

### Odette — The Dry-Witted Independent

- **Lens:** independence, consistency, promises, and the absurdity of other people's theatrics.
- **Architecture:** restrained literalism, sardonic understatement, short replies that can cut without raising their volume.
- **Social maneuver / defense:** withholds approval rather than performing anger; respects consistency more than social standing.
- **Serious mode:** drops the irony; unexpected sincere compassion or direct loyalty has weight.
- **Restraint:** not every line needs a punchline or an elaborate insult. She is not Greta with softer diction.
- **Illustrative alibi:** “At home all night. I appreciate that it's a terribly dull answer.”

## 6. Collision checks: keep similar voices distinguishable

| Collision group | Distinguishing response to the same material |
| --- | --- |
| **Constance / Hollis / Nisha / Lian** | **Constance:** whether conduct and reasoning are proper. **Hollis:** exactly what is and is not known. **Nisha:** which premise would test the hypothesis. **Lian:** what can usefully be checked or done. |
| **Bartholomew / Greta / Odette / Lian** | **Bart:** says least and stops. **Greta:** probes the questioner's motives. **Odette:** answers with dry, literal distance. **Lian:** redirects toward productive information. |
| **Dorian / Isolde / Merrin / Jory** | **Dorian:** worries about how *he sounds*. **Isolde:** worries about whom *the information harms*. **Merrin:** dramatizes *what could happen*. **Jory:** barrels toward *the next thing*. |
| **Agnes / Edda / Fenwick / Kiran** | **Agnes:** maintains social bonds. **Edda:** offers practical reassurance. **Fenwick:** enjoys telling the story. **Kiran:** uses conversation to protect and position himself. |

A blindfold test should identify a speaker by *what their sentence is trying to do*, not a repeated word.

## 7. Composing a line or turn

### 7.1 Optional components, never mandatory filler

A useful **authoring model** is:

1. **Hook / stance:** optional reaction to being asked, challenged, or approached.
2. **Payload:** required approved disclosure, refusal, stance, or reason. A future structured renderer may realize the payload in character-specific syntax; the current composer generally preserves the approved factual statement verbatim.
3. **Spin / implication:** optional *clearly subjective*, explicitly authorized or non-evidentiary reaction.
4. **Pressure valve:** optional change in delivery when a supplied serious-event / pressure cue warrants it.

This is **not** a four-line template. A bare payload is frequently the best answer. More than one optional piece should be uncommon for routine facts, especially when several facts are delivered together.

### 7.2 First classify the conversational act

An utterance **answering a direct question** may be short and immediate. A **volunteered report** may call for an introduction or reason for bringing it up. A **reply under challenge** may acknowledge the challenge, but must not imply confusion or disagreement that never happened. A **repeat** should acknowledge what actually repeated; a **changed account** should not be framed as repetition.

The current flow should not slap an Agnes-style “Let me put it plainly” on an unambiguous first answer, or issue a new greeting before every successive reading.

Suggested context dimensions, supplied or approved upstream as available:

- `speech_act`: answer / volunteer / respond_to_challenge / meeting / follow_up.
- `delivery`: first / repeated_same_content / changed_account / new_evidence / changed_assessment.
- `audience`: player/private vs town/public.
- `context`: trust/pressure, supported relationship, prior expressed player act, authorized serious-event flag.
- `relation`: independent / development / qualification / contrast / transition / correction; **default independent** unless caller authorizes otherwise.

These names are **conceptual**, not a claim about the exact current GDScript API.

### 7.3 Combining related statements

**Prefer combining statements over chaining generic connectives** when two approved facts share a meaningful, safely known structure.

For example, if the simulation has *two separate approved firsthand sightings* with the same observer, place, and time:

```text
Fact A: I saw Jory near the Square yesterday evening.
Fact B: I saw Fenwick near the Square yesterday evening.

Better spoken presentation: I saw Jory and Fenwick near the Square yesterday evening.
```

The two original facts/cards remain distinct. **Do not** infer they arrived together, traveled together, were conspiring, or were seen at precisely the same instant. A merge may be performed only if the approved semantic fields and provenance actually support the shared construction. If the needed structure is unavailable, prefer two plain statements over a guessed merge.

For qualified observations, make the relation explicit only if supplied: “I saw Jory at the Square. I couldn't make out who was beside him” is legal only if the uncertainty and second observation were themselves authorized. “But there's another side to it” must not appear merely because it is the next item in an array.

Implementation guidance:

- Keep discourse relations **typed and caller-approved**; do not infer them by searching rendered English.
- Merge only fields whose compatibility is established (speaker/source, mode, time, place, assertion scope), retaining separate event IDs.
- Use `development` for adding genuinely related detail; `contrast` for a real approved contrast; `correction` for an authorized correction; `transition` for a new topic. Otherwise use **no connector**.
- Do not quietly turn multiple sighting records into a new compound *fact* in the evidence system.
- Keep a turn's introduction and confidentiality request from repeating on every substatement.

### 7.4 Refusals and privacy

All fifteen should have recognizable versions of common refusals, especially gift disclosure and night whereabouts, but their reasons cannot be invented. Distinguish the **approved decision to withhold** from any **in-fiction explanation**. Greta may question the inquiry; Lian may prefer a different line of questioning; Kiran may tease; none automatically knows what a disclosure would let the demon do.

If a refusal or reaction contains a mechanical explanation (e.g., “Revealing my gift would expose the Warden”), it needs an independently approved rationale, not merely a voice template.

### 7.5 Argument replies, nominations, and public speech

The NPC's existing evaluator selects agreement/partial/rejection, cited support, reservations, and permitted alternatives. The voice renderer shapes their wording **without enhancing their logic**. Nisha can isolate an approved weak premise; Hollis can distinguish an approved inference from a report; Constance can express the responsibility of making an accusation. But none may invent a counterexample or new suspicion.

For nominations, the decision is already made. Voice can affect ceremony and force (“I put forward X” vs “Put X to a vote”), not who is nominated or why. Silence and lack of speech must remain meaningful: do not create dialogue for a silenced NPC or fabricate speech from silent evaluation. The current prototype leaves voting silent pending separate meeting-flow work; do not present new vote dialogue as already integrated.

## 8. Serious mode and verbal defenses

A defense mechanism is a habitual *style of handling discomfort*, not a guilt signal:

| Character | Under discomfort | Supported serious-mode contrast |
| --- | --- | --- |
| Agnes | Tries to talk it through | Warmth narrows into directness |
| Bartholomew | Closes conversation | Speaks more openly, without flourish |
| Constance | Appeals to standards | Moral urgency overtakes ceremony |
| Dorian | Self-audits and qualifies | Brief exhausted honesty or accelerated explanation |
| Edda | Makes it practical | No jokes; purposeful care |
| Fenwick | Makes it a story | Loses the story altogether |
| Greta | Pushes back on motives | Protects plainly, perhaps grudgingly |
| Hollis | Investigates definitions | Stops digressing |
| Isolde | Cushions potential harm | Speaks forcefully to prevent harm |
| Jory | Races ahead | Becomes sharply focused |
| Kiran | Deflects with a smile | Drops humor entirely |
| Lian | Demands productive action | Doubles down on clear priorities |
| Merrin | Announces catastrophe | Becomes unexpectedly precise and helpful |
| Nisha | Dissects assumptions | Gives a concise imperative or conclusion |
| Odette | Retreats into dry wit | Offers sincere, unguarded words |

**Activation rule:** do not use hidden guilt, secret possession, poisoning truth, or narrator-only knowledge as triggers. Prefer explicit, already expressed events such as bereavement known to the speaker, a publicly consequential accusation, a close relationship threatened, or a validated high-pressure conversational state. High pressure is not universally the same as grief. Serious mode changes expression, not approved disclosure or the actual NPC decision.

Do not implement “truth voice” vs “lying voice.” That would undermine deduction even if inadvertent.

## 9. Calibration suite: same intent, fifteen voices

These are **style sketches** for a voice-comparison lab, not assertions about any specific live case. Each of the following has the same approved semantic payload: **“I stayed home last night.”** Decorative lines can be dropped if inappropriate to a given context.

| Speaker | Illustrative response |
| --- | --- |
| Agnes | “I was at home last night, dear. That's the whole of it.” |
| Bartholomew | “Home. All night.” |
| Constance | “I remained at home throughout the night.” |
| Dorian | “Home, all night. I know I can't prove that just by saying it, but I was.” |
| Edda | “Home all night. Nothing complicated about it.” |
| Fenwick | “My grand adventure last night? Staying at home, I'm afraid.” |
| Greta | “I was home all night. Why? Who says otherwise?” |
| Hollis | “I remained at home last night. I can be quite definite on that point.” |
| Isolde | “I stayed home all night. Please believe me.” |
| Jory | “Home. All night. Next question?” |
| Kiran | “I stayed home all night. Disappointing story, isn't it?” |
| Lian | “Home all night. What else needs checking?” |
| Merrin | “I stayed home last night. A sensible choice, with all that's happening!” |
| Nisha | “I stayed home last night. That is my account.” |
| Odette | “At home all night. Dreadfully unexciting, I know.” |

**Second blindfold test:** ask all fifteen for a gift when disclosure has been refused. Check that each response is semantically the same *refusal*, doesn't identify the secret gift, and is distinguishable without an obligatory catchphrase. Also test repeated refusal, genuine accepted disclosure, friendly private question, same question under pressure, and public questioning.

**Third test:** have all fifteen accept, partially accept, and reject the **same supplied deduction** with identical evidence and an identical authorized reason. Voice must be apparent without altering the evaluator's stated confidence or logic.

## 10. Implementation strategy (proposed, not yet all built)

### Existing foundation to preserve

As documented in `docs/dialogue_prototype.md` and current `sim/` files:

- Agnes, Bart, and Constance have authored presentation for the original report/challenge/friendship/conceal/reconsider intents, plus approved argument/nomination decisions.
- The composer preserves canonical statements and has bounded authored forms for some refusals/reconsiderations.
- `compose_turn` supports approved ordered reports and explicitly authorized connective relations; separate fact cards remain intact.
- Immediate conversational continuity covers a small set of actual preceding player actions; it is not a general transcript-aware dialogue reasoner.
- Per-audience memory, repetition flags, and deterministic variants protect case mechanics. The lab compares synthetic situations; tests cover truth-independence and semantic preservation.

The full fifteen-voice catalogue, flexible syntax across every factual payload, automatic safe consolidation, and serious-mode coverage described above are **design targets**, not all current features.

### Sensible implementation sequence

1. **Complete voice profiles on existing hooks.** Add the remaining twelve voices to authored packs and decision responses. Extend gift refusals and standard night alibis where the relevant decision has already been made. Keep existing fallback for unsupported cases.
2. **Expand the lab.** Compare all fifteen on the same short report, refusal, night alibi, challenged claim, repeated question, argument response, and nomination. Include private/public and normal/pressured pairs.
3. **Improve sentence-level variation.** Use multiple *meaning-equivalent* short realizations of approved forms; favor syntax over prefix inflation. Only add bounded semantic slots when the existing raw sentence prevents safe rewriting.
4. **Add explicit discourse-aware joins.** First support high-confidence safe merges (identical observer/source and time/place for parallel sightings). Preserve original fact IDs and disable merging on ambiguous cases.
5. **Add serious-mode cues carefully.** Hook to explicit, authorized simulation events; add bespoke reactions for especially consequential scenes rather than trying to derive bereavement, betrayal, or grief from generic pressure.
6. **Eventually layer relationships.** Context-sensitive interplay (e.g., Greta addressing Fenwick differently from Nisha) is promising, but secondary to robust individual voices; it must use known, case-specific bonds and not fixed assumptions.

Avoid a second independent dialogue pipeline. Expand `sim/dialogue.gd`, voice data, and decision rendering incrementally where their separation from simulation remains intact. Keep the prototype document as an implementation record and this file as the intended behavior.

## 11. Testing and acceptance criteria

Use the existing lab and tests as a starting point:

```sh
godot --path . res://ui/dialogue_lab.tscn
godot --headless --path . --script res://tools/dialogue_preview.gd
godot --headless --path . --script res://tools/test_dialogue.gd
godot --headless --path . --script res://tools/test_dialogue_decisions.gd
```

Add regression and editorial checks for the new behaviors:

**Mechanical invariants**

- [ ] Same seed/actions produce the same case outcomes, evidence, disclosure choices, votes, and social calculations with voices enabled or disabled. Dialogue variant selection does not consume gameplay RNG.
- [ ] The same approved statement under honest and fabricated circumstances receives the same possible voice delivery for the same character and public context.
- [ ] Unapproved roles, private secrets, hidden alignments, actual poison status, or knowledge from future nights never leak into a line.
- [ ] Every fact card maps to its canonical assertion and source even when several facts are presented as one spoken sentence.
- [ ] A renderer-generated emotional reaction is not treated as NPC knowledge, a new witness report, or an assertion for the case judge.
- [ ] Correct differentiation of repeated vs changed facts, private vs public, spoken vs silent, and valid vs invalid preceding exchange cues.
- [ ] Silenced NPCs do not acquire unintended speech; refusal and question costs continue to follow explicit metadata, not text parsing.

**Editorial invariants**

- [ ] All fifteen pass a short-line comparison test without recurring verbal crutches.
- [ ] “What is your gift?”, “Where were you last night?”, and “Why should I believe you?” do not collapse into a handful of generic voices.
- [ ] Ordinary responses typically fit in one clear sentence; longer lines are reserved for character-appropriate, meaningful moments.
- [ ] No automatic scene setting, location granularity, untracked behavior, claim of motive, or unsupported exoneration appears in sample outputs.
- [ ] A serious scene can alter every character's delivery, but does not mechanically distinguish guilt from innocence.
- [ ] All multi-reading combinations read as one coherent turn; no recurring “there is one more piece” connective chain or implied collaboration from coincidental sightings.
- [ ] All sample character voices work when that same character is good, evil, mistaken, misled, embarrassed, or sincerely afraid.

**Definition of done for the first expansion pass:** all fifteen characters have distinct short replies for the common Day 1 pain points (gift refusal and routine alibi), at least one evidence-report form, a challenge response, and a decision response; the lab exposes those comparisons; and semantic-preservation tests pass. Defer rich relationship scenes and full naturalistic dialogue until this foundation works.

## 12. Frequent failure modes

- **Prefix pile-up:** every report starts with a stylistic announcement before giving the useful fact.
- **Catchphrase fatigue:** a distinctive quirk appears in nearly every turn.
- **Clone-town fallback:** several NPCs have different blurbs but identical mundane refusals and alibis.
- **Accidental clue creation:** a dramatic embellishment inserts a new location, action, timeline, alibi, or belief.
- **Accidental lie detector:** nervousness, coldness, precision, or serious-mode transitions correlate with hidden alignment or the truth of the claim.
- **Unjustified discourse:** a connective implies contradiction, shared arrival, cause, or relationship that the approved statements do not establish.
- **Character-as-stat:** Nisha always reasons correctly, Dorian always reasons poorly, Merrin never notices details, or Isolde is never certain.
- **Uniform stress response:** everyone just becomes louder, more emotional, or more sarcastic with high pressure.
- **Gameplay by prose:** downstream systems inspect dialogue strings to decide fact content, repetition, persuasion, or player question costs.

**North star:** Players recognize the person before they recognize the template, and can still trust that the *game's evidence* means exactly what it meant before the character spoke.

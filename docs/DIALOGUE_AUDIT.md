# Dialogue System Audit — Updated October 28, 2026

This audit updates Codex's October 23, 2026 inventory against the current `main` codebase (including the 15-character voice baseline, turn composition, across-exchange continuity, role-definition refactor, Batch 2–4 social/meeting updates, and the CaseEval Workshop Jury).

It does three things:
1. Updates **Section 1** to reflect what is now live across all 15 voices.
2. Updates **Sections 2 and 3** to flag which "Missing" items from October 23 have since been **mechanically built in the simulation** (using generic unvoiced strings) and now only need per-character voice templates.
3. Adds **Section 4**, covering **13 dialogue surfaces** present in the codebase that were missing from the October 23 audit (most notably the ~35 clinical "solver-speak" strings in `workshop/jury.gd` and `game/workshop_presentation.gd`).

## 1. Currently Implemented Authored Response Categories

As of the 15-character baseline pass (`sim/dialogue.gd`, `sim/dialogue_voices.gd`, `sim/dialogue_decisions.gd`), all fifteen cast members have authored coverage for the core composer intents, turn-flow connectives, across-exchange cues, and resolved argument/nomination decisions:

| Category | Recognizes / Responds To | Live Hook / File | Coverage |
| :--- | :--- | :--- | :--- |
| **Reporting information** | Sharing a reading, observation, or approved statement (`report`, `report_answer`, `report_volunteer`, plus `_warm`, `pressure_`, and `guarded_` variants) | `Mind.info_line`, `Mind.info_lines`, `MindDialogue.answer_today` | All 15 voices |
| **Shared-scene presence** | Condensing adjacent firsthand daytime sightings at the same location and phase (`presence_first`, `presence_more`, plus `FENWICK_EPITHETS`) | `Dialogue.Observations.presence`, `Dialogue.compose_turn` | All 15 voices |
| **Routine night alibi** | Claiming to have stayed home all night (used identically for honest home accounts and bold lies) | `Dialogue.alibi_intent`, `Mind.home_alibi`, `Warden.night_duty_alibi` | All 15 voices |
| **Gift refusal (privacy)** | Tier-1 refusal to disclose a gift when not triggered by fear (`gift_refusal`) | `Dialogue.gift_refusal_intent`, `Mind.gift_refusal` | All 15 voices |
| **Concealing whereabouts** | Stonewalling nighttime movements (`whereabouts` / `conceal`) | `Dialogue.whereabouts_intent`, `Mind.whereabouts_refusal` | All 15 voices |
| **Being doubted** | Responding when pressed with a card or deduction about the speaker (`doubted`) | `Mind.press` -> `Mind._challenged` | All 15 voices |
| **Discussing a friend** | Appending a relationship qualifier when giving an opinion about a close friend (`friend`) | `MindDialogue.answer_opinion` | All 15 voices |
| **Revising a belief** | Voluntarily acknowledging that an earlier player argument deserves more weight (`reconsideration` / `revise`) | `Mind.reconsideration_line` on conversation start | All 15 voices |
| **Requesting privacy** | Asking the player to keep a private report out of the town meeting (`private`) | `Dialogue.compose` / `Dialogue.compose_turn` (`request_privacy`) | All 15 voices |
| **Accepting an argument** | Agreeing with a player deduction (`accept`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Already convinced** | Acknowledging a conclusion the NPC had already reached (`already`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Partially persuaded** | Recognizing merit in a deduction without full conviction (`partial`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Rejecting an argument** | Disagreeing with a deduction (`reject`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Competing explanation** | Citing a stronger rival explanation (`alternative`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Possible alternative** | Citing an unresolved alternative possibility (`possible_alternative`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Insufficient support** | Explaining that the cited facts do not establish the claim (`weak`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Unreliable evidence** | Expressing doubt about supporting evidence quality (`quality`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Distrusted source** | Citing low credibility of the witness behind a card (`source`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Preferred suspect** | Naming a third party the NPC suspects more (`preferred`) | `Argue.evaluate` -> `Dialogue.decision` | All 15 voices |
| **Nomination** | Announcing an execution nomination and citing a public reason (`nominate`) | `MindMeeting.next_nomination` -> `Dialogue.decision` | All 15 voices |

### Implemented Turn-Flow & Continuity Categories

| Category | Behavior | Live Hook / File | Coverage |
| :--- | :--- | :--- | :--- |
| **Turn-flow connectives** | Joining multi-part speaker turns via caller-approved discourse relations (`flow_development`, `flow_contrast`, `flow_transition`, `flow_correction`) while suppressing repeated report openers | `Dialogue.compose_turn` | All 15 voices |
| **Gift reveal after challenge** | Replacing the default first-time gift reveal opener when the player just pressed the speaker's gift in the immediately preceding exchange (`conversation_gift_after_challenge`) | `Dialogue.exchange_cue`, `Dialogue.gift_reveal` | All 15 voices |
| **Opinion after accusation** | Acknowledging that the player just accused person X before giving an opinion on X (`conversation_opinion_after_accusation`) | `Dialogue.exchange_cue`, `Dialogue.contextualize` | All 15 voices |
| **Repeated opinion query** | Acknowledging an immediate repeat of `ask about X` (`conversation_opinion_again`) | `Dialogue.exchange_cue`, `Dialogue.contextualize` | All 15 voices |
| **Repeated opinion refusal** | Varying a low-gossip refusal when asked about the same person twice in a row (`conversation_opinion_refusal_again`) | `Dialogue.repeated_opinion_refusal` | All 15 voices |
| **Decision continuity** | Tracking per-audience argument history (`repeat`, `changed`, `new_evidence`, `reframed`) | `Dialogue.Decisions.render` | All 15 voices |

## 2. Existing Gameplay Branches Still Using Generic or Bucketed Lines

These branches are fully functional in the simulation, but they bypass `sim/dialogue_voices.gd` and use a single hardcoded string, a 2-way toggle, or a 3-to-5 bucket lookup:

| Existing Response Situation | Current Implementation & File Location | Voice Status |
| :--- | :--- | :--- |
| **Greeting / attitude cues** | `MindDialogue.greeting_cue` (`sim/mind_dialogue.gd:253`): 4 trust bands gated by Composure (`"What do you want now?"` to `"Ah, Demonologist. Sit."`). | Unvoiced (1 generic per tier) |
| **Fear-based gift refusal** | `MindDialogue._answer_gift_impl` (`sim/mind_dialogue.gd:462`): `"If I say what I am, I'll be dead by morning. Ask me again when it's safer."` | Unvoiced (1 generic string) |
| **Gift hint (Tier 2)** | `MindDialogue._answer_gift_impl` (`sim/mind_dialogue.gd:479`): `C.HINT_PACKAGES[pk]["text"] + " That's all I'll say."` | Unvoiced (1 generic per package) |
| **First-time private gift disclosure (unpressed)** | `MindDialogue._answer_gift_impl` (`sim/mind_dialogue.gd:494`): `"I'll trust you with this. I'm the %s."` (Only pressed reveals use `conversation_gift_after_challenge`). | Unvoiced when unpressed |
| **Repeat gift confirmation** | `MindDialogue._answer_gift_impl` (`sim/mind_dialogue.gd:502`): `"As you know, I'm the %s."` | Unvoiced (1 generic string) |
| **Public role claim at meeting** | `MindMeeting._claim_line` (`sim/mind_meeting.gd:144`): Uses 5 `n.style` buckets (`warm`, `gruff`, `formal`, `nervous`, `plain`), so Dorian, Isolde, and Merrin share `"I-I suppose I have to say it. I am the %s."` | Bucketed (5 styles, not 15 voices) |
| **Non-reading / empty-reading / withheld-reading gift replies** | `MindDialogue._answer_gift_impl` (`sim/mind_dialogue.gd:514, 544-559`): Hardcoded lines for passive/protective gifts (`"My gift doesn't tell me things..."`), trust-drop withholding (`"I've told you what I knew before..."`), fear withholding, privacy withholding (`"What it's shown me, I'll keep to myself for now."`), and empty logs (`"It hasn't shown me anything yet."`). | Unvoiced (1 generic per branch) |
| **Direct role guess (`ask are <role>`)** | `Social.answer_is_role` (`sim/social.gd:510`): Hardcoded mismatch (`"No. I told you: I'm the %s."`) and 3-step patience escalation (`"What my gift is, I'll keep to myself."`, `"You're grasping at straws..."`, `"Why do you keep asking me that?"`). | Unvoiced (1 generic per step) |
| **Asking who holds a role (`ask about <role>`)** | `Social.answer_about_role` (`sim/social.gd:458`): Hardcoded self-confirmation (`"That would be me."`), public recap (`"Everyone heard %s claim the %s."`), private leak (`"Between us, %s told me..."`), and refusal/ignorance (`"That's not for me to say."` / `"I couldn't tell you who the %s is."`). | Unvoiced (1 generic per branch) |
| **Following up on a hinted accusation (`ask why`)** | `MindDialogue.answer_hint` & `_hint_decline` (`sim/mind_dialogue.gd:34-85`): Hardcoded reveal lead-in (`"All right. You asked, so here's why I suspect %s."`), confidentiality tail (`"But keep this between us..."`), and 2-way stall (`"Not yet. Give me a day or two..."` / `"I said I'm not ready..."`). | Unvoiced (1–2 generic strings) |
| **Night-duty alibis & pressed-night reconfirmations** | `sim/roles/warden.gd`, `nightwatch.gd`, `lamplighter.gd`, `medium.gd`, and `MindDialogue._answer_pressed_night` (`sim/mind_dialogue.gd:199`): Role-specific duty lines and 2-variant pressed-night reconfirmations (`"I was at home on night X. I stand by that account."` / `"That sighting doesn't change where I was..."`). | Unvoiced (2 generic variants) |
| **Personal secret confession** | `MindDialogue.answer_night` (`sim/mind_dialogue.gd:636`) & `MindMeeting.defend_self` (`sim/mind_meeting.gd:830`): `"...I wasn't home. I %s. Please, keep it quiet."` and `"I wasn't out for anything wicked. I %s."` | Unvoiced (1 generic per venue) |
| **Night sighting testimony (window / street / stayed in)** | `MindDialogue.sighting_report` (`sim/mind_dialogue.gd:743`): Fixed `before`/`after` slots (`"From my window on night %d, I saw..."`, `"I did see %s out on %s..."`) passed through `Dialogue.compose_turn`. | Voiced opener; fixed body slots |
| **Daytime self-whereabouts** | `MindDialogue.answer_today` (`sim/mind_dialogue.gd:818`): `"Yesterday evening I was at the smithy..."` prepended before voiced `presence` sightings. | Unvoiced prefix |
| **Opinion core statements** | `MindDialogue.answer_opinion` (`sim/mind_dialogue.gd:908, 943-956`): Low-gossip refusal (`"It's not my place to say."`) and 6 suspicion/reason bands (`"I trust %s."`, `"%s seems all right to me."`, `"I don't really know %s that well."`, `"I can't put my finger on it..."`, `"I have my doubts about %s."`, `"If you ask me, %s is the one."`). Only the friendship tail and immediate-exchange prefix are voiced. | Core statement unvoiced |
| **Legacy personal/group card accusation & defense** | `Mind.hear_accusation`, `hear_defence`, `hear_group_case` (`sim/mind.gd:1440-1582`) and `Evil` equivalents (`sim/evil.gd:778-796`): Fixed lines (`"Me? That's madness."`, `"%s is my friend. You'll need more than that."`, `"Thank you for believing me."`). | Unvoiced (1–2 generic strings) |
| **Public meeting accusation** | `MindMeeting._public_accusation` (`sim/mind_meeting.gd:503-515`): `"I agree with %s about %s."`, `"I have a reason to suspect %s, but I'm not ready to share it yet."`, `"I don't trust %s. %s."` | Unvoiced (1 generic per tier) |
| **Execution self-defense (`defence_line` & `defend_self`)** | `MindMeeting.defence_line` (`sim/mind_meeting.gd:937`: 3 confidence buckets) and `MindMeeting.defend_self` (`sim/mind_meeting.gd:793`: walking-gift reveal, secret confession, sleepwalk excuse, Seer red herring, pair deflection, source lying, source misled, fear plea, desperation plea). | Unvoiced (generic per move) |
| **Ward / vigil offer appreciation** | `Game._offer_command` (`game/game.gd:1468`): `"That's good of you. I'll sleep a little easier."` | Unvoiced (1 generic string) |
| **NPC approaches (`approach_teaser` & `approach_open`)** | `Social.approach_teaser` & `approach_open` (`sim/social.gd:355-388`): `"Demonologist, a word?"`, `"It's about my gift..."`, `"I've heard something about one of our neighbours."`, `"I've been meaning to find you."`, `"And keep an eye on %s..."` | Unvoiced (1 generic per agenda) |
| **Tavern gossip (`gossip_item`)** | `Social.gossip_item` (`sim/social.gd:420-455`): Secret leak (`"Between you and me, %s %s..."`), relayed reading (`"%s told me their gift is %s..."`), relayed sighting (`"%s says %s was out..."`), and empty fallback (`"...Well, I thought I had something. The price of bread, mostly."`). | Unvoiced (1 generic per type) |

## 3. Updated Status of the October 23 Playtest Categories (1–55)

Several items listed as "Missing" in the October 23 audit have since been **mechanically implemented** in Batches 2–4 and the Workshop migration, but still use generic unvoiced text. Their updated status is marked below:

### A. Responding to Accusations, Contradictions, and Evidence

| # | Category | Oct 23 Status | Oct 28 Status & Implementation Notes |
| :--- | :--- | :--- | :--- |
| 1 | **Caught in a specific lie** | Partial | **Built (Unvoiced generic)** — `MindDialogue.answer_night` now preserves `dialogue_memory["night_accounts"]` so a caught speaker stands by their prior account or concedes via `answer_gift` rather than flipping between alibi and refusal. Needs per-voice phrasing. |
| 2 | **Admit lying, deny guilt** | Partial | **Built (Unvoiced generic)** — `WorkshopPresentation._present` (`game/workshop_presentation.gd:160`) now emits `"Fine, I was out. Doesn't mean I was doing anything wrong."` when a non-Sleepwalker's home alibi is disputed by a considered sighting. Needs 15-voice variants. |
| 3 | **Explain why a statement was false** | Partial | **Built (Unvoiced generic)** — `MindDialogue._answer_pressed_night` (`sim/mind_dialogue.gd:200`) and `answer_gift` (`line 498`) emit `"So yes: I was out on night X, whatever I told you. I wasn't ready to tell you why."`, plus `sleepwalk_excuse` (`line 194`). Needs 15-voice variants. |
| 4 | **Acknowledge evidence, reject interpretation** | Missing | **Built in Workshop Jury (Unvoiced solver-speak)** — `workshop/jury.gd:329-332, 654-658` emits movement/trace and challenged-alibi caveats (`"The routes, observation coverage and traces change which explanation I favor. Lawful activity and eligible passers remain alternatives..."`). Needs translation out of solver-speak into character voices. |
| 5 | **Accept a suspicious sighting but dispute guilt** | Missing | **Partial (Workshop Jury only)** — `workshop/jury.gd:631` emits `"That gives me a reason to be suspicious, though it does not establish evil."`, and quiet-night/other-block discounts apply mathematically, but NPCs do not yet explicitly say *"No one died that night"* or *"The murder was on another block."* |
| 6 | **Challenge the reliability of a reading** | Partial | **Built (Unvoiced generic)** — `MindMeeting.defend_self` (`lines 888-897`), `sim/roles/seer.gd:70`, and `Support.ReadingChallenges` distinguish `lying`, `misled` (poison/delusion), and `red_herring` (Marked / Seer false positive). Needs 15-voice variants. |
| 7 | **Respond to a role-based contradiction** | Partial | **Partial (Workshop Jury)** — Handled through `workshop/jury.gd` world-compatibility and movement checks, but spoken output is still generic solver prose. |
| 8 | **Respond to repeated independent evidence** | Partial | **Partial** — `workshop/jury.gd:930` counts distinct outings (`"These are %d distinct outings..."`), while `game/workshop_presentation.gd:302` tracks fresh vs. already-considered cards. Still lacks natural multi-incident escalation in character voice. |
| 9 | **Explain what would change their mind** | Missing | **Missing (Interactive question)** — `workshop/jury.gd` appends automatic objections (`"I still doubt these reports..."`, `"I am least convinced by %s's report..."`), but there is no player command to ask what would change their mind. |
| 10 | **Express uncertainty about their own information** | Missing | **Partial** — Good NPCs can accept `misled` deductions about their own readings in the shared ledger, and `workshop/jury.gd:935` flags conflicts with own knowledge, but there is no self-doubt voice line when an NPC accepts their own reading was poisoned. |

### B. Disclosure, Role Questions, and Testimony

| # | Category | Oct 23 Status | Oct 28 Status & Implementation Notes |
| :--- | :--- | :--- | :--- |
| 11 | **Repeated gift hint** | Partial | **Partial** — `Game._repeat_refusal` (`game/game.gd:1099`) handles repeated tier-1 refusals and repeated `ask are <role>` guesses, but repeating `ask gift` at Tier 2 still replays the static package hint unless tier advances. |
| 12 | **Running out of patience with guesses** | Partial | **Built (Unvoiced generic)** — `Social.answer_is_role` (`sim/social.gd:534-536`) has 3 escalation steps (`guesses == 1`, `guesses == 2`, `guesses >= 3`) plus `Game._repeat_refusal` (`line 1116`). Needs 15-voice variants. |
| 13 | **Explaining a disclosure boundary** | Partial | **Built (Partially voiced)** — Privacy refusals (`gift_refusal`) are now voiced for all 15 characters; fear refusals (`sim/mind_dialogue.gd:462`), distrust explanations (`sim/mind.gd:201`), and confidence requests (`sim/mind_dialogue.gd:404`) are mechanically distinct but still use generic strings. |
| 14 | **Firsthand vs. relayed knowledge** | Partial | **Built (Unvoiced generic)** — `Social.gossip_item` (`sim/social.gd:447, 451`), `Social.answer_about_role` (`line 489`), and `MindMeeting.relay_reading` (`sim/mind_meeting.gd:283`) explicitly attribute relays (`"Via X"`, `"Word reached me from the <Role>..."`). Needs character voice styling. |
| 15 | **Empty result vs. failed gift** | Partial | **Partial** — Role definitions format empty results (e.g., `"nobody stirred"`, `"my sight was unclear"`), and `MindDialogue._answer_gift_impl` has `"It hasn't shown me anything yet."` (`line 559`). |
| 16 | **Limited recall** | Missing | **Missing** — `MindDialogue.answer_today` (`sim/mind_dialogue.gd:831`) slices `recalled` to `2 + round(insight * 4)` sightings silently without appending an `"I know there were others, but I can't place them"` acknowledgement when `seen.size() > memory`. |
| 17 | **Specific gift explanation** | Partial | **Built (Unvoiced role-def strings)** — Extracted into `sim/roles/*.gd` (`seer.gd`, `warden.gd`, `nightwatch.gd`, `medium.gd`, `lamplighter.gd`). |
| 18 | **Seer false-positive hypothesis** | Partial | **Built (Unvoiced generic)** — `sim/roles/seer.gd:70` (`"%s keeps finding me because I'm the one the Seer always misreads..."`) and `workshop/jury.gd:352, 952` (`"...evil; %s Marked"`). |
| 19 | **Explaining suspicious behavior after revealing a role** | Partial | **Built (Unvoiced generic)** — `MindDialogue._answer_gift_impl` (`sim/mind_dialogue.gd:498`) owns earlier lies (`"So yes: I was out on night X, whatever I told you. I wasn't ready to tell you why."`). Needs 15-voice variants. |
| 20 | **Follow-up on "nothing new"** | Partial | **Built (Unvoiced generic)** — `MindDialogue.answer_hint` (`sim/mind_dialogue.gd:47`: `"I've nothing more to tell you."` / `"I've no further reason to give you."`) and `sim/roles/medium.gd`. |

### C. Opinions, Trust, Relationships, and Gossip

| # | Category | Oct 23 Status | Oct 28 Status & Implementation Notes |
| :--- | :--- | :--- | :--- |
| 21 | **Explain an existing suspicion** | Missing / routing gap | **Partial** — `MindDialogue.answer_opinion` cites `citable_reason(w, n, t.id, "player")` when `gossip >= 0.2 or pressure >= 0.5`, but the Backlog exemption for stances already given in public (`gossip < 0.2` refusing to repeat their own public accusation) is still open. |
| 22 | **Express genuine neutrality** | Missing | **Built (Unvoiced generic)** — `MindDialogue.answer_opinion` (`sim/mind_dialogue.gd:950`) distinguishes `"%s seems all right to me."` (`level < 0.35`) from `"I don't really know %s that well."` (`0.35 <= level < 0.45`). Needs 15-voice variants. |
| 23 | **Explain distrust of the player** | Missing | **Built (Unvoiced generic)** — `Mind._append_distrust` and `Mind._trust_action` (`sim/mind.gd:162-202`) remember the largest trust-losing incident and append `"I don't trust you. You nominated me."` (or 12 other specific player offenses) once per day on any refusal when `trust < 0.35`. Needs 15-voice variants. |
| 24 | **Differentiate disagreement from personal distrust** | Missing | **Partial** — `workshop/jury.gd` and `Argue.evaluate` separate source/player trust scaling from logical agreement, but spoken replies do not explicitly contrast *"I trust you, but the facts aren't there"* vs. *"The facts fit, but I don't trust your angle."* |
| 25 | **Describe another person's personality** | Missing | **Built (Unvoiced generic)** — `Game._maybe_tell_trait` (`game/game.gd:1538-1579`) reveals a target's trait during `ask about` with friend, neutral, or rival framing (`"I'll say this for %s: they're principled."` vs. `"%s is pigheaded, if you ask me."`). Needs 15-voice framing. |
| 26 | **Discuss public friendships and rivalries** | Missing | **Built (Unvoiced generic)** — `Game._maybe_tell_relationships` (`game/game.gd:1583-1610`) reveals town bonds (`"%s and %s are close."` / `"don't get along"`, and first-person `"%s and I are close."`). Needs 15-voice framing. |
| 27 | **Repeated or irrelevant gossip** | Partial | **Fixed mechanically** — `Social._gossip_items` (`sim/social.gd:392-413`) and `RecentSightings` now filter out public sightings, self-incriminating hearsay, co-present people, and already-disclosed readings. |
| 28 | **Explain why information is being withheld** | Partial | **Built (Unvoiced generic)** — `MindDialogue._answer_gift_impl` (`lines 544-553`), `answer_night` (`line 664`), and `_append_distrust` distinguish trust drop, fear, privacy, and withheld Night Watch reports. |
| 29 | **Respond to accusations against a friend** | Partial | **Partial** — Legacy `Mind.hear_accusation` (`sim/mind.gd:1455`) has `"%s is my friend. You'll need more than that."`, while Workshop Jury (`workshop/jury.gd`) folds `npc_trust` into prior/source quality silently without a spoken friendship objection line. |
| 30 | **Respond to a betrayed confidence** | Missing | **Built via `_trust_action` (Unvoiced generic)** — `Mind._trust_action` (`sim/mind.gd:169, 175`) maps `"the Demonologist spread my secret"` to `"You spread what I told you in confidence."` and `"the Demonologist broke my confidence"` to `"You broke my confidence at the meeting."` Needs reactive callout at the moment of betrayal and 15-voice phrasing. |

### D. Argument Continuity and Public Meetings

| # | Category | Oct 23 Status | Oct 28 Status & Implementation Notes |
| :--- | :--- | :--- | :--- |
| 31 | **Recognize a previously public claim / accusation** | Missing | **Built (Unvoiced generic)** — `MindMeeting._public_accusation` (`sim/mind_meeting.gd:509`) says `"I agree with %s about %s."` when joining an earlier accuser, and `relay_reading` (`line 291`) has the original giver say `"That was me."` Needs 15-voice variants. |
| 32 | **Explain changing a public position** | Partial | **Partial** — `Dialogue.Decisions` has `changed` (`"I have revised my assessment..."`) and `MindMeeting.last_words` (`line 425`) corrects an earlier false role claim, but public accusation target switches (`w.stances`) do not yet acknowledge the previous target. |
| 33 | **Withdraw or modify a prior case** | Missing | **Partial** — `WorkshopPresentation.readiness` (`game/workshop_presentation.gd:25-34`) and `workshop/jury.gd:1007` (`_changes`) track case revisions and announce `"You added X's report. You changed the conclusion."`, but there is no standalone withdraw command. |
| 34–35 | **Distinguish belief from execution priority / Explain voting** | Missing | **Deferred by design** — Votes remain silent pending the meeting-flow / Q3 execution-priority pass. |
| 36 | **Respond directly to a public accusation** | Partial | **Partial** — Accused NPCs respond when a case is presented at the meeting or when nominated (`defend_self`), but not immediately after an un-nominated `_public_accusation` during `meeting_testimony`. |
| 37 | **Voluntarily defend another person** | Missing | **Missing** — NPCs can relay readings to accuse (`_accuse_tier`), but do not yet voluntarily burn cover at a meeting to clear a nominated townsperson. |
| 38 | **Justify an information-seeking execution** | Missing | **Missing** — Nominations remain driven by suspicion / scapegoat scores. |
| 39 | **Recognize a strong but incomplete case** | Partial | **Built in Workshop Jury (Unvoiced solver-speak)** — `workshop/jury.gd` distinguishes circumstantial pattern cases, conditional cases needing extra choices, and rival worlds (`"I checked another explanation and it also fits..."`). Needs 15-voice translation. |
| 40 | **Final words (Gallows speech)** | Missing | **Built (Unvoiced generic)** — `MindMeeting.last_words` (`sim/mind_meeting.gd:417-442`) is now live: condemned NPCs claim their role (or say `"As I've said, I am the <Role>."`) and name their top suspect (`"I still suspect %s."`), or try to speak while silenced. Needs 15-voice gallows flair. |

### E. Promises, Requests, and Longer-Term Interactions

| # | Category | Oct 23 Status | Oct 28 Status & Implementation Notes |
| :--- | :--- | :--- | :--- |
| 41 | **Accept or refuse a suggested use of a gift** | Missing | **Built (Unvoiced generic)** — `Mind.consider_gift_request` (`sim/mind.gd:972-994`) and `RoleDef.request_agree_line` (`"All right. I'll look at %s tonight."`, `"I'll watch %s tonight."`, `"I'll guard %s's door tonight."`) vs. refusal (`"My gift's mine to use as I see fit."`). Needs 15-voice variants. |
| 42 | **Counterproposal on a gift request** | Missing | **Built (Unvoiced generic)** — `Mind.consider_gift_request` (`sim/mind.gd:988-992`) calls `rdef.counter_gift_request` when `trust >= 0.35` (`"No. I'd rather look at %s."` / `"No. %s's door needs me more."`). Needs 15-voice variants. |
| 43 | **Follow-up on a requested action** | Missing | **Partial** — Agreed requests populate `n.gift_request` and generate the next night's real or fabricated reading, which is delivered through normal reading disclosure without a bespoke *"I did as you asked"* preface. |
| 44 | **Successful protection acknowledgment** | Partial | **Built (Unvoiced generic)** — Kept promises trigger the divulge approach (`game/game.gd:962`: `"You kept your word. Now I'll keep mine."`), and `workshop/jury.gd:165, 830` credits quiet-night protection claims. |
| 45 | **Broken promise confrontation** | Missing | **Built via `_trust_action` (Unvoiced generic)** — Breaking a ward or vigil promise logs `"the Demonologist broke their word (%s)"` (`game/game.gd:1506`), which surfaces on the next refusal via `Mind._append_distrust` (`"I don't trust you. You broke your promise to me."`). |
| 46–47 | **Apology for a particular incident & Forgiveness tiers** | Missing | **Built (Unvoiced generic)** — `Mind.apologise` (`sim/mind.gd:136-159`) is live (`apologise <n>`) and branches into 3 forgiveness tiers: accepted (`"Well. I appreciate you saying so."`), sharp/skeptical on evidence (`"Sorry for it, are you? You'd do the same again, I think."`), and grudging (`"Hm. Words are cheap, but I heard you."`). Needs 15-voice variants. |
| 48 | **Request for confidentiality** | Partial | **Built (Unvoiced generic)** — `MindDialogue._confidence_request` (`sim/mind_dialogue.gd:391-405`) negotiates `"I'll tell you, but only if you promise not to reveal it yet."` with decline `"Then it stays with me."` Needs 15-voice variants. |

### F. Emotional Reactions and Major Case Events (49–55)

Categories **49 (Grief)**, **50 (Survivor guilt)**, **51 (Vindication)**, **52 (Embarrassment / error)**, **53 (Shock at supernatural events: Revenant haunting, totem found, Breathstealer silence)**, **54 (Relationship betrayal)**, and **55 (Serious-mode tone shift after tragedy)** remain **Missing** as dedicated simulation hooks (though grief and Revenant curses apply trust/suspicion math in `sim/world.gd` and `Mind._trust_action` records `"You backed hanging %s."` for bereaved friends).

## 4. Additional Spoken Surfaces Missing from the October 23 Audit

Inspection of the current `sim/`, `game/`, and `workshop/` scripts reveals **13 additional dialogue surfaces** that were not listed in the October 23 audit:

| # | Newly Identified Surface | Current Implementation & File Location | Why It Needs Dialogue Coverage |
| :--- | :--- | :--- | :--- |
| 56 | **Workshop Jury / CaseEval "Solver-Speak" (`workshop/jury.gd` & `game/workshop_presentation.gd`)** | `Jury._eval_response`, `_assess_target_eval`, `_eval_claim`, `_objection`, `_bounded_objection`, `_changes`, and `WorkshopPresentation._present` / `_belief_stance_text` emit ~35 clinical diagnostic strings (`"Your explanation fits what I considered. I am provisionally persuaded, but I have not checked another explanation."`, `"I did not combine all the evidence in this case."`, `"Those reports can't all be right together, so I'm weighing which of them to doubt."`). | **Highest-visibility gap in live play.** Because `WorkshopPresentation` passes `assessment.response` in `descriptor.special`, it bypasses `sim/dialogue_decisions.gd`, making all 15 townsfolk sound like the same Bayesian referee when evaluating Workshop cases. |
| 57 | **Sleepwalking Excuse (`sleepwalk_excuse`)** | `MindDialogue.sleepwalk_excuse` (`sim/mind_dialogue.gd:194`): `"I don't remember going out. But I've been known to sleepwalk."` | Used both in private sighting presses and public nomination defenses by real Sleepwalkers and cornered evil bluffers. |
| 58 | **Inadvertent Night-Sighting Slips (`whereabouts_slip` / `refused_whereabouts_slip`)** | `MindDialogue.answer_night` (`sim/mind_dialogue.gd:721`): `"…though I did see %s %s on %s on night %d, not that I was there."` | A great comedic/dramatic beat when a low-composure NPC lies or stonewalls about their night and then blurts out a sighting from another block. |
| 59 | **Protection-Request Negotiation & Divulge Flow** | `MindDialogue.protection_line` (`sim/mind_dialogue.gd:365`), `_protection_request` (`line 387`), and `Game._protect_approach_answer` / `_grant_protection` / `_maybe_divulge` (`game/game.gd:962, 1021, 1044, 1051`): 7 hardcoded lines covering asking for a Ward/Vigil, accepting (immediate vs. deferred reveal), declining, and morning-after fulfillment. | High-stakes social negotiation where frightened or scheming NPCs bargain for their lives. |
| 60 | **Repeated Refusal Free-Slot Notice (`Game._repeat_refusal`)** | `Game._repeat_refusal` (`game/game.gd:1114-1126`): Overwrites repeated gift, fear, withheld-reading, and role-guess refusals within the same conversation (`"You've had my answer about my gift. I won't tell you more."` / `"I'm still keeping my gift to myself."`). | Currently overwrites the character's voiced `gift_refusal` on the second ask in the same conversation with a generic 2-way toggle. |
| 61 | **Daytime Sighting Refusals & Empty-Recall Replies** | `MindDialogue.answer_night` (`lines 710, 713`) and `answer_today` (`lines 828, 835, 850, 889`): `"I'm not ready to discuss who I saw."`, `"I saw nobody."`, `"Who else goes where is none of my business."`, `"Nobody worth mentioning."`, `"Nobody you didn't see for yourself."` | Very frequent everyday replies when querying low-gossip NPCs or quiet phases. |
| 62 | **Known Haunt Disclosures (`_maybe_tell_haunts`)** | `Game._maybe_tell_haunts` (`game/game.gd:1530`): `"When %s isn't working, you'll often find them at %s."` | Triggered frequently alongside `ask about <name>`; currently identical across all speakers. |
| 63 | **Self-Trait Reflection (`_maybe_tell_trait` when `n == t`)** | `Game._maybe_tell_trait` (`game/game.gd:1575`): `"I'd call myself %s."` | Triggered when an NPC describes their own disposition; needs character-appropriate self-awareness (or lack thereof). |
| 64 | **Anonymous Reading Relay & Public Authorship Claim** | `MindMeeting.relay_reading` (`sim/mind_meeting.gd:283, 291`): `"Word reached me from the %s: %s."` and the original source replying `"That was me."` | Dramatic town-meeting moment when a townsperson steps forward to own a relayed reading. |
| 65 | **Releasing a Confidentiality Promise in Public** | `MindMeeting._public_disclosure` (`sim/mind_meeting.gd:377`): `"I've decided the town should hear it."` | Spoken when an NPC who previously bound the player to secrecy decides to reveal their gift to the town anyway. |
| 66 | **Nominator's Case Recap, Empty Fallback & Private-Reason Teaser** | `MindMeeting.nomination_case` (`sim/mind_meeting.gd:759-773`): `"I don't trust %s, and I can't say better than that."`, `"Remember: %s."`, and `"And I have another reason I'm not ready to share yet."` | Spoken on every NPC nomination right after the voiced `nominate` line. |
| 67 | **Unrelated Card Press Rejection** | `MindDialogue.press` (`sim/mind_dialogue.gd:102`): `"What has that to do with me?"` | Spoken whenever the player presses an NPC with a card that does not implicate or concern them. |
| 68 | **Ward-Context Presentation (`_show_ward_context`)** | `Game._show_ward_context` (`game/game.gd:1143`): Presenting a chalk-sigil Ward card to prove a demon attack was stopped. | Needs character-appropriate reaction to physical proof of a thwarted night kill. |

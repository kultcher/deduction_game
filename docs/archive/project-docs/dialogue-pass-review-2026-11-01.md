# Dialogue pass: review before merging

Branch `claude/dialogue-opinion-pass` (commits `c4cb3f0` and `882cc16`, pushed), built on `claude/purge-phase1-deduction-schema` (`a441f7a`). Nothing is merged.

**Round 2 (Nov 2), after your notes:**
- Nisha redone from her original lines. Her refined vocabulary is kept; only modern-sounding words were swapped. Her meeting lines are included now.
- Older nights are ordinal ("on the second night").
- Dorian's "sorry" is uncapped.

**Scope:** NPC-on-NPC opinions, the playtest dialogue flags from Oct 31, and a jargon pass on Nisha.

**Left out, as agreed:**
- `[PH]` lines
- Gossip content
- Public-meeting accusation lines
- "Trust" wording aimed at the player

**How to proofread:**
- `godot --headless --path . --script res://tools/opinion_preview.gd` prints every voice's "ask about" answer across 12 suspicion/bond/word combinations.
- Sections A–C below list every changed line with its before and after.

---

## 1. Behavior changes

### 1.1 Opinions keep three things apart (`answer_opinion`)

The opinion line used to be chosen from demon suspicion alone, yet it said "I trust X." Each part now has its own job:

| Factor | Source | What it controls |
|---|---|---|
| Is X evil? | `susp` (unchanged buckets) | Which line is spoken. `opinion_trust` is now `opinion_clear`: "I don't take X for one of the evil ones." |
| Is X's word reliable? | `honesty[X]` (the evidence-based "credits X's word" value) | A separate caveat (`opinion_word_doubt`), added when X is cleared (suspicion < 0.45) but `honesty` < 0.75. |
| Friend or rival? | `n.friends` / `n.rivals`, plus the existing "close" test (`npc_trust` > 0.7) | **Clear or fine:** said together with the opinion (`opinion_friend_clear`, `opinion_rival_clear`). **Doubt:** said together (`*_suspect`). **Accuse or vibes:** the opinion line, then a partiality note (the existing `friend`, plus the new `rival`). |

**Rules:**
- Both alignments state their real bonds (your call).
- An evil speaker lying about a teammate or scapegoat never adds the word caveat.
- A friend or rival never gets "I don't really know X that well." That bucket reads as "seems all right" for them.
- When a friend or rival line already says "I have my doubts" and there's no reason to give, the generic "Something's off about them." tail is dropped.
- The bond is recorded as a spoken relationship (`relationship.kind` is now `friend` or `rival`). `_maybe_tell_relationships` won't repeat it in the same answer.
- No new RNG draws. The vibes roll and the relationship roll are unchanged (checked in tests).

### 1.2 Verbal tic caps (`Dialogue.apply_tics`, applied in `Mind.say` / `say_voiced`)

**Scope:** a conversation with the player (reset in `begin_conversation`) or a town meeting (reset in `World.open_meeting`).

**How it works:**
- Uses past the cap are removed by ordered regex rewrites, then the line is tidied (spaces, stray commas, sentence-start capitals).
- Only the spoken text changes. The canonical `statement` is untouched.
- Every voiced line was run through the stripper with the cap already used up. All 222 affected lines came out clean, with no leftover tic words.

| Voice | Tic | Cap per scope |
|---|---|---|
| Isolde | "truly" | 1 |
| Odette | "miraculously" / "miracles" | 1 |
| Edda | "dear" / "love" | 2 / 1 |
| Agnes | "love" / "dear" | 1 / 1 |
| Fenwick | "my friend" | 2 |
| Kiran | "Demonologist" | 2 |
| Merrin | "heaven help us/me" | 1 |

**Example (Isolde, second line in one conversation):** "I'm sorry, truly—my gift hasn't shown me anything yet." becomes "I'm sorry—my gift hasn't shown me anything yet."

The caps are guesses. Tune them in `TICS` in `sim/dialogue.gd`.

### 1.3 Mixed persuasion lines (`dialogue_decisions.gd`)

**Before:** the `changed` opener ("I've come round on this") fired whenever a repeated argument's reply signature changed. That included the same stance with a different reason, and stance moving *down*. Two examples from the playtests:
- Edda: "I've come round on this… not baked through… wouldn't hang a kettle."
- Agnes: "that gives us something more to work with. I don't buy it."

**Now the opener follows the direction of the stance:**
- Moving to accept: `changed`.
- Moving up but not to accept: new `warming`.
- Moving down: new `cooling`.
- Same stance with new facts: `new_evidence`.
- Same stance, same facts, different reason: no opener.
- An argument about the speaker never gets an opener. Their denial stands alone.

**Grammar fix:** the default `partial` read "I can see a case **for** Lian is the demon". It's now "a case **that** …".

**Not touched:** the private workshop reply stacking ("…more convincing. So it doesn't change my mind") is `[PH]` text. Current code already strips the accept tail before a reject lead; I checked the exact Kiran string from case 92974. That playtest line came from the older build.

### 1.4 Spoken night names (`C.spoken_night` / `spoken_when`)

**Spoken lines now say:**
- "last night" for the previous night
- "the night before you arrived" for night 0
- an ordinal for anything older: "on the second night", "the third night". Night N is the Nth night since the Demonologist arrived.

**Applied to:**
- the pressed home-alibi line (Odette's "on night 1" flag)
- the "So yes, I was out…" admission
- meeting reading recitals
- spoken night sightings ("From my window on the second night, I saw…", "I did see Kiran out on the Docks last night"), including volunteered and slipped ones

Card and log text keeps `night_name()`.

### 1.5 Relationship answers (`_maybe_tell_relationships`)

- At most two bonds per answer, with the speaker's own ties first.
- Bonds involving the dead are skipped (Kiran's "Bartholomew and Lian are…" after Bartholomew's death). They're filtered after the roll, so the draws are unchanged.
- A second third-party bond of the same kind in one answer uses plain wording, not the voice idiom (Agnes's "thick as thieves" twice in a row).

### 1.6 Reading history on re-ask (`answer_gift`)

**Before:** asked again with something new, an NPC recited every reading from night 0 onward before reaching the news.

**Now:** they say a voiced `readings_stand` line ("My earlier findings stand as I reported them.") followed by only the new readings.
- Case-board facts still cover every reading.
- If nothing is new, the old behavior stays and they repeat everything.

### 1.7 Smaller fixes

- **Accusation cards:** a card that *names* an NPC (for example, a Seer reading) no longer gets the "are you doubting my account?" opener, such as Greta's "You think my eyes are going?". That framing is kept for cards that question something they said themselves.
- **"The movement and trace evidence":** the workshop's "trace" wording now needs a trace card *in the case*, not just a trace assessed somewhere on the board.
- **"Seen elsewhere … not that night's killer":** this note is no longer attached to a *minion* case (the 77388 Constance flag).
- **Trait words, Confidence mid:** neutral "fairly firm in their views" is now "neither stubborn nor easily swayed". Friend wording "steady in their views" is now "sensible, and open to reason".

---

## 2. Sample output (from `opinion_preview.gd`, speaker asked about Lian)

**Constance**
- [clear] I have seen nothing in Lian's conduct to suggest wickedness.
- [clear, word doubted] I have seen nothing in Lian's conduct to suggest wickedness. I would not, however, accept every account Lian gives without corroboration.
- [friend, doubt] I am close to Lian, and it grieves me to say it, yet I have my doubts about them.
- [rival, clear] Lian and I have little patience for one another, yet I do not believe them capable of murder.
- [rival, accuse] In my considered judgment, the guilt lies with Lian. Something's off about them. There is friction between Lian and me; you should allow for it.

**Odette**
- [clear] I don't take Lian for one of the wicked, which is more than I'd say for most.
- [friend, clear] I happen to like Lian, rare as that is, and no, I don't think they're evil.
- [rival, clear] Lian and I don't get along, but tedious isn't the same thing as murderous.
- [rival, doubt] Lian and I don't get along, so discount accordingly—but I have my doubts about them.

**Nisha**
- [clear] Nothing I've observed supports the hypothesis that Lian is evil.
- [rival, clear] Lian and I don't get along, but dislike isn't evidence. I don't take them for a killer.
- [friend, doubt] Lian is a friend, so I tested this hardest of all. I still have my doubts about them. I have my reasons, but I'm not ready to say.

---

## 3. Flagged but not changed (your call)

1. **Nisha's meeting lines (resolved in round 2):** the "constraint" lines were reworded ("an unshared deduction", "the established premises"). Lines you said read fine were kept: "My own model aligns with…", "It isn't a locked deduction yet…", "raises a serious flag on the board", "public premise". Her gossip lines ("Log this privately…", "Noise, not signal") are left for the gossip rework.
2. **Odette's meeting `meeting_agree_accuse` ("Miraculously, …")** is untouched. The new tic cap now limits it at meetings anyway.
3. **Dorian's comma splices (resolved):** his "sorry" is no longer capped, so those lines stay as written.
4. **Older nights (resolved):** they're ordinal now. Past the tenth night, a spoken line would fall back to "night 11", which a 10-person town shouldn't reach.
5. **Jory's modern words** ("awesome", "super", "Haha") and Dorian's "Okay" read as deliberate voice choices, so I left them.
6. **The plain doubt line** still ends "…I have my doubts about X. Something's off about them." for non-bonded speakers. It's slightly redundant, but it's how the composer signals "no reason". I only removed it from the new bonded lines.
7. **Asking the same question twice charges twice** (`ask seen yesterday evening` in 77388). That's a question-economy issue, not a dialogue one. Noted, not changed.
8. **The word caveat reads live `honesty`**, which is recomputed at the start of each answer. In practice it appears once someone's reports have been contradicted by evidence. The threshold is 0.75 (`WORD_DOUBT_BELOW`).

---

## 4. Tests

- **Existing suites:**
  - All 107 non-slow suites pass.
  - `test_trace`, the slow 12-game parity suite, wasn't run.
  - A 4-game autoplay smoke run was clean.
- **Expectations updated for intended wording changes:**
  - `test_dialogue`: the friendship-opinion check, the grouped-readings night name, and the new opinion keys in the slot check
  - `test_backlog_batch3`, `test_backlog_batch4`, `test_fixes`, `test_sighting_followup` and `test_playtest_regressions`: "night N" in speech became the spoken night name. Card text still checks the number.
- **New `tools/test_dialogue_opinion_pass.gd` (294 checks, 0 failures). It covers:**
  - coverage of all new keys in every voice
  - tic caps and scope reset
  - stance-direction openers and self-arguments
  - spoken night names
  - bonded opinions: the wording, the recorded relationship, the distrust fact still filed, and no extra RNG

---

## A. Opinion lines (all 15 voices)

`opinion_trust` is renamed `opinion_clear`. The other six keys are new. `{subject}` is the person asked about.

### Agnes

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I trust {subject} wholeheartedly.” | “I can't believe {subject} has any part in this wickedness, dear.” |
| `opinion_word_doubt` | *(new)* | “Mind, I wouldn't take every word {subject} says as gospel.” |
| `opinion_friend_clear` | *(new)* | “{subject}'s a dear friend, love, and there's no wickedness in them. I'd swear to it.” |
| `opinion_friend_suspect` | *(new)* | “{subject} is a dear friend, and it breaks my heart to say it, but I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I have never seen eye to eye, but I don't think they've a murderous bone in them.” |
| `opinion_rival_suspect` | *(new)* | “You know {subject} and I don't get on, so take this as you will, but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I don't get on, love, so weigh my words with that in mind.” / “I've never been fond of {subject}; bear that in mind.” |

### Bartholomew

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I trust {subject}.” | “{subject}'s not one of them.” |
| `opinion_word_doubt` | *(new)* | “Wouldn't swallow everything {subject} tells you, though.” |
| `opinion_friend_clear` | *(new)* | “{subject}'s a friend. Not one of them.” |
| `opinion_friend_suspect` | *(new)* | “{subject}'s a friend. Still, I have my doubts.” |
| `opinion_rival_clear` | *(new)* | “Never liked {subject}. Doesn't make them a killer.” |
| `opinion_rival_suspect` | *(new)* | “Never liked {subject}, so weigh it. But I have my doubts.” |
| `rival` | *(new)* | “{subject} and I don't get on. Take that into account.” / “No love lost between me and {subject}. There it is.” |

### Constance

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I have every confidence in {subject}'s character.” | “I have seen nothing in {subject}'s conduct to suggest wickedness.” |
| `opinion_word_doubt` | *(new)* | “I would not, however, accept every account {subject} gives without corroboration.” |
| `opinion_friend_clear` | *(new)* | “{subject} is dear to me, and I am satisfied they have no part in this evil; allow for my partiality.” |
| `opinion_friend_suspect` | *(new)* | “I am close to {subject}, and it grieves me to say it, yet I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I have little patience for one another, yet I do not believe them capable of murder.” |
| `opinion_rival_suspect` | *(new)* | “You should know there is friction between {subject} and me; with that caveat, I have my doubts about them.” |
| `rival` | *(new)* | “There is friction between {subject} and me; you should allow for it.” / “My differences with {subject} are relevant to how you judge my opinion.” |

### Dorian

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I actually really trust {subject}—if that's worth anything.” | “I really don't think {subject} is one of them—for whatever my opinion's worth.” |
| `opinion_word_doubt` | *(new)* | “Though maybe double-check what {subject} tells you? Not that they'd lie. Probably.” |
| `opinion_friend_clear` | *(new)* | “{subject} is a friend of mine, so I'm biased, obviously—but no, I can't see them being evil.” |
| `opinion_friend_suspect` | *(new)* | “{subject} is my friend, which makes this awful to say, but I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I don't get along—they mostly scare me, honestly—but I don't think they'd kill anyone.” |
| `opinion_rival_suspect` | *(new)* | “I know {subject} and I don't get along, so maybe I'm being unfair, but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I don't really get along, so maybe discount what I say a bit.” / “I should admit {subject} and I aren't on good terms, in case that's coloring things.” |

### Edda

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I'd trust {subject} with my own hearth, dear.” | “There's no rot in {subject}, dear. I'd know.” |
| `opinion_word_doubt` | *(new)* | “Still, I'd sift what {subject} tells you before you bake with it.” |
| `opinion_friend_clear` | *(new)* | “{subject} is dear to me, and I'd swear there's no wickedness in them—though I'm hardly impartial.” |
| `opinion_friend_suspect` | *(new)* | “I've a soft spot for {subject}, so it pains me, but I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I rub each other the wrong way, but that's a long road from murder.” |
| `opinion_rival_suspect` | *(new)* | “{subject} and I have never got on, so take it with a pinch of salt, but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I rub each other the wrong way, so mind that when you weigh my words.” / “No love lost between {subject} and me, dear—factor that in.” |

### Fenwick

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “{subject} is true gold, my friend—I trust them completely.” | “{subject}? No villain in that one, my friend—wrong casting entirely.” |
| `opinion_word_doubt` | *(new)* | “Though I'd not print every line {subject} feeds you without checking the proofs.” |
| `opinion_friend_clear` | *(new)* | “{subject} is a dear friend of mine, and I'd wager my best tale they've no part in this—fondness duly noted.” |
| `opinion_friend_suspect` | *(new)* | “It wounds me, for {subject} is a dear friend, but I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I have never quite harmonized, but a sour note doesn't make a murderer.” |
| `opinion_rival_suspect` | *(new)* | “{subject} and I are hardly friends, so read this review with care—but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I have never quite harmonized—weigh my review accordingly.” / “I'll confess no great fondness for {subject}; factor that into the telling.” |

### Greta

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “{subject} is solid. I trust them.” | “{subject} isn't one of them. I'd have smelled it by now.” |
| `opinion_word_doubt` | *(new)* | “Doesn't mean I'd swallow everything {subject} says, mind.” |
| `opinion_friend_clear` | *(new)* | “{subject}'s one of the few I'd vouch for. Not evil—and yes, I'm partial.” |
| `opinion_friend_suspect` | *(new)* | “I stand by {subject} more than most, which is why it galls me to say I have my doubts.” |
| `opinion_rival_clear` | *(new)* | “Can't stand {subject}, but they're no killer. Don't twist my words.” |
| `opinion_rival_suspect` | *(new)* | “{subject} and I can't stand each other, so discount it if you like—but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I can't stand each other. Weigh that.” / “No love lost between me and {subject}, so don't take my word as gospel.” |

### Hollis

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I consider {subject} entirely trustworthy.” | “I have observed nothing to suggest {subject} is in league with the fiend.” |
| `opinion_word_doubt` | *(new)* | “I would, however, treat {subject}'s reports with a degree of caution.” |
| `opinion_friend_clear` | *(new)* | “I should note my fondness for {subject}; that said, I find no ground to think them evil.” |
| `opinion_friend_suspect` | *(new)* | “I hold {subject} in considerable regard, which makes it painful to record that I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I have long been at odds, but antipathy is not evidence; I do not believe them a killer.” |
| `opinion_rival_suspect` | *(new)* | “I should disclose a longstanding antipathy toward {subject}; allowing for it, I still have my doubts about them.” |
| `rival` | *(new)* | “I should disclose a longstanding antipathy toward {subject}; weight my view accordingly.” / “{subject} and I have long been at odds, which you should factor into my assessment.” |

### Isolde

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “I trust {subject} with all my heart.” | “I can't believe {subject} would ever hurt anyone.” |
| `opinion_word_doubt` | *(new)* | “Only... I might not lean too hard on everything {subject} says.” |
| `opinion_friend_clear` | *(new)* | “{subject} is so dear to me, and I know they'd never be part of something so wicked.” |
| `opinion_friend_suspect` | *(new)* | “I care for {subject} so much, and it breaks my heart, but I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I don't get along, I'm afraid, but I could never believe they'd kill anyone.” |
| `opinion_rival_suspect` | *(new)* | “Please weigh this knowing {subject} and I don't get along, but I do have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I don't get along, so please don't take my word too heavily.” / “I should tell you {subject} and I aren't on good terms, in fairness to them.” |

### Jory

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “Oh, {subject} is great—I trust them!” | “{subject}? Nah, not one of them. No way.” |
| `opinion_word_doubt` | *(new)* | “Wouldn't take everything {subject} says as gospel, though.” |
| `opinion_friend_clear` | *(new)* | “{subject}'s my friend—and no, they're not evil! I'd know!” |
| `opinion_friend_suspect` | *(new)* | “Ugh, {subject}'s my friend, but... yeah, I have my doubts.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I clash constantly, but murder? Nah.” |
| `opinion_rival_suspect` | *(new)* | “Okay, {subject} and I don't get on, so maybe I'm biased—but I have my doubts!” |
| `rival` | *(new)* | “Heads up, {subject} and I clash a lot, so maybe I'm biased.” / “{subject} and I don't really get along—just so you know.” |

### Kiran

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “Strange as it sounds coming from me, I actually trust {subject}.” | “Strange as it sounds coming from me, I don't take {subject} for one of the wicked.” |
| `opinion_word_doubt` | *(new)* | “I'd still count my change after {subject} hands it back, so to speak.” |
| `opinion_friend_clear` | *(new)* | “I'm quite fond of {subject}, and I'd bet good coin they're clean—do factor in the fondness.” |
| `opinion_friend_suspect` | *(new)* | “I'm fond of {subject}, which makes this a poor bet to place, but I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I aren't on each other's holiday lists, but I wouldn't bet on them as a killer.” |
| `opinion_rival_suspect` | *(new)* | “{subject} and I have a feud going, so price my word accordingly—but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I aren't on each other's holiday lists, so do price that in.” / “Fair warning: {subject} and I have a little feud going.” |

### Lian

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “{subject} is reliable. Cross them off your list.” | “{subject} doesn't flag as evil. Cross them off for now.” |
| `opinion_word_doubt` | *(new)* | “Check what {subject} tells you, though; their reports haven't all held up.” |
| `opinion_friend_clear` | *(new)* | “I know {subject} well. Not evil—factor in that we're close.” |
| `opinion_friend_suspect` | *(new)* | “{subject} and I are close, and I still have my doubts about them. That should tell you something.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I don't get along. Not relevant—they don't flag as a killer.” |
| `opinion_rival_suspect` | *(new)* | “{subject} and I have bad blood, so discount my read if you want. I still have my doubts.” |
| `rival` | *(new)* | “{subject} and I have bad blood. Factor that in.” / “We don't get along, {subject} and me, so check my read against someone else's.” |

### Merrin

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “Thank heaven for {subject}—one soul in this doomed town I still trust!” | “Thank heaven for {subject}—one soul in this doomed town I'd swear is free of the fiend!” |
| `opinion_word_doubt` | *(new)* | “Yet I'd not stake my life on every word that leaves {subject}'s lips!” |
| `opinion_friend_clear` | *(new)* | “{subject} is a dear friend to this frayed heart—they cannot be one of the fiend's own, they cannot!” |
| `opinion_friend_suspect` | *(new)* | “Oh, it tears me apart, for {subject} is dear to me, yet I have my doubts about them!” |
| `opinion_rival_clear` | *(new)* | “{subject} and I cross like two stray cats, yet even I cannot believe them a murderer!” |
| `opinion_rival_suspect` | *(new)* | “Weigh it as you will, for {subject} and I have no love lost—but I have my doubts about them!” |
| `rival` | *(new)* | “{subject} and I cross like two stray cats, so weigh my dread accordingly!” / “I confess no fondness for {subject}—mark that before you heed me!” |

### Nisha

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “My baseline for {subject} is clean; I trust them.” | “Nothing I've observed supports the hypothesis that {subject} is evil.” |
| `opinion_word_doubt` | *(new)* | “I'd still corroborate {subject}'s reports before relying on them.” |
| `opinion_friend_clear` | *(new)* | “Note my prior—{subject} and I are close—but nothing I've observed suggests they're evil.” |
| `opinion_friend_suspect` | *(new)* | “{subject} is a friend, so I tested this hardest of all. I still have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I don't get along, but dislike isn't evidence. I don't take them for a killer.” |
| `opinion_rival_suspect` | *(new)* | “For transparency: {subject} and I don't get along. Allowing for that bias, I have my doubts about them.” |
| `rival` | *(new)* | “For transparency, {subject} and I don't get along; weigh my judgment accordingly.” / “I dislike {subject}, so test my reasoning rather than my tone.” |

### Odette

| Key | Before | After |
|---|---|---|
| `opinion_clear` | “Miraculously enough, I actually trust {subject}.” | “I don't take {subject} for one of the wicked, which is more than I'd say for most.” |
| `opinion_word_doubt` | *(new)* | “I wouldn't take {subject}'s word as scripture, mind you.” |
| `opinion_friend_clear` | *(new)* | “I happen to like {subject}, rare as that is, and no, I don't think they're evil.” |
| `opinion_friend_suspect` | *(new)* | “I like {subject}, which is rare for me, so it's irritating to admit I have my doubts about them.” |
| `opinion_rival_clear` | *(new)* | “{subject} and I don't get along, but tedious isn't the same thing as murderous.” |
| `opinion_rival_suspect` | *(new)* | “{subject} and I don't get along, so discount accordingly—but I have my doubts about them.” |
| `rival` | *(new)* | “{subject} and I don't get along, so do discount accordingly.” / “I'm no admirer of {subject}; weigh that as you please.” |

## B. Other voice-line changes

### Agnes

| Key | Before | After |
|---|---|---|
| `tell_bond_third_close` | “{a} and {b} have been thick as thieves for ages.” | “{a} and {b} have been close for years.” |
| `readings_stand` | *(new)* | “What I told you before still stands, dear.” |

### Bartholomew

| Key | Before | After |
|---|---|---|
| `readings_stand` | *(new)* | “Rest's as I told you.” |

### Constance

| Key | Before | After |
|---|---|---|
| `private_reveal` | “You have conducted this inquiry properly, so I shall be candid: I am the {role}.” | “You strike me as a serious person, so I shall be candid: I am the {role}.” |
| `readings_stand` | *(new)* | “My earlier findings stand as I reported them.” |

### Dorian

| Key | Before | After |
|---|---|---|
| `readings_stand` | *(new)* | “The earlier stuff is the same as I told you—nothing's changed there.” |

### Edda

| Key | Before | After |
|---|---|---|
| `readings_stand` | *(new)* | “The rest is just as I told you before, dear.” |

### Fenwick

| Key | Before | After |
|---|---|---|
| `tell_bond_self_close` | “{other} and I are thick as thieves!” | “{other} and I are fast friends!” |
| `readings_stand` | *(new)* | “The earlier chapters stand as told, my friend.” |

### Greta

| Key | Before | After |
|---|---|---|
| `tell_haunt` | “When {subject} isn't working, check {places}—that's where they loiter.” | “When {subject} isn't working, check {places}.” |
| `readings_stand` | *(new)* | “The rest you've already got.” |

### Hollis

| Key | Before | After |
|---|---|---|
| `flow_transition` | “Turning to an orthogonal category:” / “On a separate branch of the inquiry:” | “Turning to a separate category entirely:” / “On a separate branch of the inquiry:” |
| `public_claim` | “To place the relevant variable on the public record without further ambiguity: I am the {role}.” | “So that the record is free of ambiguity on this point: I am the {role}.” |
| `readings_stand` | *(new)* | “My prior findings stand as previously recorded.” |

### Isolde

| Key | Before | After |
|---|---|---|
| `opinion_fine` | “{subject} seems all right to me, truly—a gentle neighbor.” | “{subject} seems all right to me—gentle enough, as far as I can see.” |
| `request_confidence` | “I'll tell you, truly, if only you'll promise not to repeat it in front of the town yet.” | “I'll tell you, if only you'll promise not to repeat it in front of the town yet.” |
| `readings_stand` | *(new)* | “What I told you before is still true.” |

### Jory

| Key | Before | After |
|---|---|---|
| `readings_stand` | *(new)* | “Old stuff's the same as before!” |

### Kiran

| Key | Before | After |
|---|---|---|
| `repeat` | “Testing whether my story changes on the second telling? Spoiler:” / “Word for word, just as before:” | “Testing whether my story changes on the second telling? It doesn't:” / “Word for word, just as before:” |
| `gift_refusal` | “Asking for my cards on the very first turn, Demonologist? Half the charm of a parlor game is the guessing. I'll keep my gift to myself.” / “Straight to my gift? You really do skip the foreplay. I'll keep that card face-down.” | “Asking for my cards on the very first turn, Demonologist? Half the charm of a parlor game is the guessing. I'll keep my gift to myself.” / “Straight to my gift? You don't even buy a fellow a drink first. I'll keep that card face-down.” |
| `readings_stand` | *(new)* | “The earlier hands played out just as I told you.” |

### Lian

Light pass on modern management wording ('actionable', 'logged', 'inputs/outputs').

| Key | Before | After |
|---|---|---|
| `report` | “Here's what's actionable:” / “Put this to work:” | “Here's what you can use:” / “Put this to work:” |
| `report_volunteer` | “Before we waste time:” / “Log this first:” | “Before we waste time:” / “Note this first:” |
| `friend` | “I trust {subject} to pull their weight, so factor that in.” / “I know {subject} well; that doesn't change the facts, only my read.” | “I know {subject} well, so factor that in.” / “I know {subject} well; that doesn't change the facts, only my read.” |
| `alibi` | “Home all last night. Cross it off and tell me what else needs checking.” / “At home all last night. One less variable for you—what's next?” | “Home all last night. Cross it off and tell me what else needs checking.” / “At home all last night. One less thing for you to check—what's next?” |
| `readings_stand` | *(new)* | “Earlier readings unchanged.” |

### Merrin

| Key | Before | After |
|---|---|---|
| `opinion_refuse` | “Heaven forbid I invite bad karma by slandering a neighbor!” | “Heaven forbid I invite ill luck by slandering a neighbor!” |
| `readings_stand` | *(new)* | “All I told you before still stands, alas!” |

### Nisha

Second pass: Nisha keeps her refined, hypothesis-testing vocabulary (premise, deduction, model, hold in reserve). Only modern-sounding words are swapped out: variable, constraint, data, baseline, signal, log, outputs, over-fitting, specificity, correlations.

| Key | Before | After |
|---|---|---|
| `description` | “Patient investigator; isolates testable variables and separates observation from inference.” | “Patient investigator; isolates testable premises and separates observation from inference.” |
| `report` | “Treat this as a single verified data point:” / “Here is the observation—keep it distinct from the inference:” | “Treat this as a single verified observation:” / “Here is the observation—keep it distinct from the inference:” |
| `report_volunteer` | “You are missing a variable:” / “Add this to the baseline:” | “You are missing a premise:” / “Add this to what you already hold:” |
| `pressure_answer` | “Pressure doesn't change the evidence.” / “Set the urgency aside and look at the variable:” | “Pressure doesn't change the evidence.” / “Set the urgency aside and look at the premise:” |
| `pressure_volunteer` | “Before you lock in a flawed premise:” / “Consider this constraint first:” | “Before you lock in a flawed premise:” / “Consider this condition first:” |
| `guarded_answer` | “I will confirm the observation, nothing further:” / “One variable at a time:” | “I will confirm the observation, nothing further:” / “One premise at a time:” |
| `guarded_volunteer` | “I'll give you the isolated fact:” / “Log this without extrapolation:” | “I'll give you the isolated fact:” / “Note this without extrapolation:” |
| `friend` | “Note my prior with {subject}: we are close, so audit my threshold accordingly.” / “I trust {subject} personally, though I try to keep that separate from the board.” | “Note my prior with {subject}: we are close, so discount my judgment accordingly.” / “I'm fond of {subject} personally, though I try to keep that separate from the evidence.” |
| `conceal` | “That variable stays unrevealed until the board justifies the cost.” / “You don't have enough on the board to make that disclosure worth the trade.” | “That stays undisclosed until the evidence justifies the cost.” / “You don't have enough on the board to make that disclosure worth the trade.” |
| `revise` | “When the constraints shift, the model has to follow.” / “I've re-tested my earlier assumption.” | “When the premises shift, the model has to follow.” / “I've re-tested my earlier assumption.” |
| `repeat` | “The observation is unchanged from the prior query:” / “Repeating the query yields the same variable:” | “The observation is unchanged since you last asked:” / “Asking again yields the same answer:” |
| `guarded` | “I'm keeping my scope narrow for now:” / “Just the baseline fact:” | “I'm keeping my scope narrow for now:” / “Just the bare fact:” |
| `conversation_gift_after_challenge` | “Fair enough—holding the variable back is costing more than it saves. I'm the {role}.” | “Fair enough—holding it back is costing more than it saves. I'm the {role}.” |
| `flow_contrast` | “However, the counter-indicator is:” / “Set that against this constraint:” | “However, the counter-indication is:” / “Set that against this condition:” |
| `flow_transition` | “Shifting to the separate line of inquiry:” / “On the other variable:” | “Shifting to the separate line of inquiry:” / “On the other question:” |
| `whereabouts` | “Where I was is an unshared variable. Work from the sightings you can corroborate.” / “I'm withholding my night whereabouts; test the rest of the board first.” | “Where I was stays undisclosed. Work from the sightings you can corroborate.” / “I'm withholding my night whereabouts; test the rest of the board first.” |
| `gift_refusal` | “I'm not disclosing my gift. Treat it as an unknown variable and work around it for now.” / “If I name my gift now, the Demon adjusts its plan. Work around that variable for now.” | “I'm not disclosing my gift. Treat it as an unknown and reason around it for now.” / “If I name my gift now, the Demon adjusts its plan. Reason around that unknown for now.” |
| `alibi` | “I stayed home all last night. That is my account—though I'm well aware a self-report isn't independent confirmation.” / “At home all last night. Log it as a self-report until you have a window witness.” | “I stayed home all last night. That is my account—though I'm well aware my own word isn't independent confirmation.” / “At home all last night. Treat it as my word alone until you have a window witness.” |
| `reconsideration` | “I tested {argument} against the remaining worlds. It eliminates more alternatives than I first calculated.” / “My earlier rejection of {argument} rested on a weak assumption. The link holds.” | “I tested {argument} against the remaining possibilities. It eliminates more alternatives than I first calculated.” / “My earlier rejection of {argument} rested on a weak assumption. The link holds.” |
| `own_night_lie` | “Update your ledger for {nights} accordingly: I was out on my role's work, and withheld that variable until my claim was on the table.” | “Amend your ledger for {nights} accordingly: I was out on my gift's work, and withheld that until my claim was on the table.” |
| `opinion_unfamiliar` | “I don't really know {subject} that well; treat them as an open variable.” | “I don't really know {subject} that well; treat them as an open question.” |
| `opinion_vibes` | “It isn't a hard constraint yet—I can't put my finger on it, but something's off about {subject}.” | “It isn't a firm deduction yet—I can't put my finger on it, but something's off about {subject}.” |
| `defence_lying` | “If that reading is on the board, then {source} is fabricating data. Ask why.” | “If that reading is on the board, then {source} is fabricating it. Ask why.” |
| `distrust_action` | “Your prior actions lowered my trust below threshold. {action}” | “Your prior actions have cost you my confidence. {action}” |
| `apology_accept` | “Noted. Correcting an error restores some baseline trust.” | “Noted. Correcting an error restores some of my confidence.” |
| `hint_stall_wait` | “I told you the premise isn't ready for disclosure. Ask me again when I have more data.” | “I told you the premise isn't ready for disclosure. Ask me again when I have more to go on.” |
| `request_confidence` | “I'll share the variable with you now if you agree to keep it off the public board.” | “I'll share it with you now if you agree to keep it off the public board.” |
| `request_declined` | “Without that constraint, I'm keeping the variable private.” | “Without that assurance, I'm keeping it private.” |
| `pressed_home_stand` | “I was at home {when}. That baseline is unchanged.” | “I was at home {when}. My account is unchanged.” |
| `repeat_gift_confirm` | “You already have that logged: I am the {role}.” | “You already have that noted: I am the {role}.” |
| `empty_readings` | “My reading log is still empty—no observations to report yet.” | “My gift has yielded no observations to report yet.” |
| `withhold_readings_privacy` | “You have my role constraint, but I'm keeping my actual readings in reserve for now.” | “You have my role, but I'm keeping my actual readings in reserve for now.” |
| `withhold_readings_trust` | “You have my prior outputs. Given the drop in trust, I'm withholding subsequent readings for now.” | “You have my earlier findings. Given the drop in my confidence in you, I'm withholding subsequent readings for now.” |
| `role_query_self` | “You already have that variable logged: that's me.” | “You already have that noted: that's me.” |
| `role_query_refuse` | “That isn't a variable I'm willing to disclose.” | “That isn't something I'm willing to disclose.” |
| `gift_req_counter` | “That target isn't optimal tonight. {counter}” | “That target isn't the best use of it tonight. {counter}” |
| `meeting_accuse_hint` | “I have an unshared constraint pointing at {target}, which I'm holding in reserve for now.” | “I have an unshared deduction pointing at {target}, which I'm holding in reserve for now.” |
| `release_confidence_public` | “The board needs this constraint publicly now, so I'm lifting my earlier hold.” | “The town needs this on the public record now, so I'm lifting my earlier hold.” |
| `trace_fit_locations` | “Foot traffic across {places} covers half the cast; recovering {item} has low specificity against me.” | “Foot traffic across {places} covers half the town; finding {item} singles me out no more than anyone.” |
| `trace_fit_quarter` | “Living on {home_block} or crossing {evening_block} at evening matches too many baselines to isolate me.” | “Living on {home_block} or crossing {evening_block} at evening describes too many people to isolate me.” |
| `trace_not_me` | “That trace sits outside my work and off-shift data.” | “That trace sits outside both my work and my off-hours.” |
| `pressed_multi_trace_case` | “You are over-fitting noisy scraps from half the village; any night walker on that lane could have tracked those in or planted them to frame me.” | “You are forcing noisy scraps from half the village into one theory; any night walker on that lane could have tracked those in or planted them to frame me.” |
| `circumstantial_hub_landed` | “Combined with your primary data, those surrounding correlations make {target} much harder to discount.” | “Combined with your primary evidence, those surrounding associations make {target} much harder to discount.” |
| `circumstantial_smear_pushback` | “Loose social correlations without baseline data do not establish guilt.” | “Loose social associations without firmer evidence do not establish guilt.” |
| `tell_trait_friend` | “For baseline context, {subject} is reliably {words}.” | “For context, {subject} is reliably {words}.” |
| `tell_bond_third_close` | “Log the social tie: {a} and {b} are close.” | “Mark the social tie: {a} and {b} are close.” |
| `nomination_recap` | “Recapping the established constraints: {recap}.” | “Recapping the established premises: {recap}.” |
| `nomination_held_reason` | “I'm also holding an unshared constraint in reserve for now.” | “I'm also holding an unshared deduction in reserve for now.” |
| `night_saw_nobody` | “Zero sightings to log from my end.” | “No sightings to report from my end.” |
| `day_saw_nobody` | “logged no other sightings.” | “observed no one else.” |
| `nightwatch_withhold` | “That's my watch sector; the traffic log itself stays in reserve for now.” | “That's my watch sector; whom I observed there stays in reserve for now.” |
| `approach_teaser_gift` | “My role produced a constraint you should factor in.” | “My role produced a finding you should factor in.” |
| `approach_open_gossip` | “You'll want to log this on your board.” | “You'll want to note this on your board.” |
| `readings_stand` | *(new)* | “My earlier readings stand as I gave them.” |

### Odette

| Key | Before | After |
|---|---|---|
| `defence_line` | “How wonderfully efficient—lynching an innocent woman before supper.” | “How wonderfully efficient—hanging an innocent woman before supper.” |
| `role_query_unknown` | “I couldn't tell you who the {role} is; people rarely send me their résumés.” | “I couldn't tell you who the {role} is; people rarely send me their credentials.” |
| `tell_trait_friend` | “Miraculously, {subject} is actually {words}.” | “Against all odds, {subject} is actually {words}.” |
| `readings_stand` | *(new)* | “The earlier installments haven't changed.” |

## C. Argument-reply lines (`sim/dialogue_decisions.gd`)

`warming` and `cooling` are new openers (see 1.3). Other rows are rewrites.

### Default (unvoiced)

| Key | Before | After |
|---|---|---|
| `partial` | “I can see a case for {claim}, but I'm not convinced.” | “I can see a case that {claim}, but I'm not convinced.” |
| `warming` | *(new)* | “I've come partway round since we last spoke.” |
| `cooling` | *(new)* | “Looking at it again, I'm less sure than I was.” |

### Agnes

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “I've been turning it over, and I'm a little nearer your view than I was.” |
| `cooling` | *(new)* | “I've thought on it again, love, and I'm less sure than I was.” |

### Bartholomew

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “Moved a bit since last time.” |
| `cooling` | *(new)* | “Less sure than I was.” |

### Constance

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “My assessment has moved somewhat toward yours.” |
| `cooling` | *(new)* | “On reflection, I am less persuaded than I was.” |

### Dorian

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “Okay—I'm a bit closer to your view than before, I think.” |
| `cooling` | *(new)* | “Wait, I think I'm actually less sure than I was before.” |

### Edda

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “I've warmed to it a little since we last talked, dear.” |
| `cooling` | *(new)* | “I've had another think, and I'm less sure than I was.” |

### Fenwick

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “The plot has drawn me a little nearer your telling.” |
| `cooling` | *(new)* | “Alas, on a second reading the tale grips me less.” |

### Greta

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “Fine—I'm closer to your read than I was.” |
| `cooling` | *(new)* | “Looked again. I'm less convinced than before.” |

### Hollis

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “My position has shifted somewhat in your direction.” |
| `cooling` | *(new)* | “On re-examination, my confidence in the inference has diminished.” |

### Isolde

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “I've been thinking on it, and I'm a little more afraid you're right.” |
| `cooling` | *(new)* | “I've thought it over again, and I'm less sure than I was—forgive me.” |

### Jory

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “Okay, I'm leaning your way a bit more now!” |
| `cooling` | *(new)* | “Hm, actually—less sure than I was.” |

### Kiran

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “I've shaded my odds a little toward yours.” |
| `cooling` | *(new)* | “On the rematch, I like your odds less than I did.” |

### Lian

| Key | Before | After |
|---|---|---|
| `already` | “Already logged: {claim}.” | “Already had that: {claim}.” |
| `repeat` | “Same inputs, same output. Move on.” | “Same facts, same answer. Move on.” |
| `new_evidence` | “New evidence logged. Re-evaluating.” | “That's new. Weighing it.” |
| `quality` | “Source reliability is too low to act on.” | “I wouldn't act on sources that shaky.” |
| `preferred` | “Higher-priority suspect is {preferred}.” | “I'd look at {preferred} first.” |
| `warming` | *(new)* | “Moved closer to your read.” |
| `cooling` | *(new)* | “Less convinced than before.” |

### Merrin

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “Oh, I fear you're nearer the truth than I allowed!” |
| `cooling` | *(new)* | “Perhaps my dread ran ahead of me—I'm less certain now!” |

### Nisha

| Key | Before | After |
|---|---|---|
| `accept` | “The constraints lock in: {claim}.” | “The premises lock in: {claim}.” |
| `reject` | “The premise that {claim} fails against the current constraints.” | “The premise that {claim} fails against what we know.” |
| `new_evidence` | “Adding that constraint narrows the remaining worlds.” | “Adding that fact narrows the remaining possibilities.” |
| `weak` | “The cited cards don't isolate the target variable.” | “The cited cards don't isolate the target.” |
| `preferred` | “The stronger signal on the board points to {preferred}.” | “The stronger indication on the board points to {preferred}.” |
| `nominate` | “To test the leading hypothesis, I nominate {target}.” | “On the leading hypothesis, I nominate {target}.” |
| `warming` | *(new)* | “Testing it again moves me somewhat toward your view.” |
| `cooling` | *(new)* | “Testing it again leaves me less convinced than I was.” |

### Odette

| Key | Before | After |
|---|---|---|
| `warming` | *(new)* | “I'm marginally closer to agreeing with you, which is annoying.” |
| `cooling` | *(new)* | “On second thought, I'm less taken with it than I was.” |

# Voice calibration: first writing pass

Drafts for editorial review, following [DIALOGUE_DESIGN](DIALOGUE_DESIGN.md).
Four short situations per speaker. The new twelve are lab-only sketches, not live voice packs.
Agnes, Bartholomew and Constance are comparison references. One version per situation;
no pressure/repeat/serious-mode variants or new gameplay hooks in this pass.

The editable sample source is `tools/dialogue_voice_sketches.json`. This sheet is its first-pass review snapshot.

## Shared situations

- **Gift refusal** — Player: “What is your gift?” Approved meaning: “I will not disclose my gift.” The decision is to refuse. No role, reason for secrecy, or promise to reveal later is supplied.
- **Routine alibi** — Player: “Where were you last night?” Approved meaning: “I stayed home all last night.” A claimed alibi, not certified truth. No sleeping, visitors, activity, or independent proof is supplied.
- **Firsthand report** — Player: “Who did you see yesterday evening?” Approved meaning: “I saw Rowan at the tavern yesterday evening.” Rowan is a fictional visitor used for calibration, so nobody reports seeing themselves. No route, action, motive, companion, or finer time is supplied.
- **The same report under doubt** — Player: “I don't believe that account.” Approved meaning: “I saw Rowan at the tavern yesterday evening.” The player has expressed doubt. The speaker maintains the same account; no new proof, certainty change, or counter-accusation is authorized.

The report and challenged report describe exactly the same synthetic sighting. Rowan is a fictional visitor, not a new cast member or case clue. Subjective reactions concern the exchange; they provide no new proof, role, motive or alibi.

## Twelve draft voices

### Dorian

Worries about how his words sound, without becoming uncertain of the observation.

- **Gift refusal:** “I'd rather not say. That sounds evasive. Sorry, but I'm still not saying.”
- **Routine alibi:** "I was at home all night. Alone, obviously, which means I can't prove it, not that I'm saying you think I'm lying, just—I was in bed."
- **Firsthand report:** “I saw Rowan at the tavern yesterday evening—I mean, I happened to be there, and so was he, not that I was following him or anything.”
- **The same report under doubt:** “Have I explained it badly? I saw Rowan at the tavern yesterday evening. No, that was clear enough. I stand by it.”

### Edda

Grounds the exchange in a plain answer; occasional understatement, no ornamental folk sayings.

- **Gift refusal:** “I'll be keeping my gift to myself, for now, if you don't mind. We can still talk.”
- **Routine alibi:** “Home all last night, snug as a bug and quiet as you please."
- **Firsthand report:** “Rowan was at the tavern yesterday evening. Saw them myself.”
- **The same report under doubt:** “I saw Rowan at the tavern yesterday evening. Same question, same answer.”

### Fenwick

Enjoys delivering the reveal; the performance stays shorter than a story and supplies no scenery.

- **Gift refusal:** “Ah, you'd have me give the whole tale away. My gift stays with me.”
- **Routine alibi:** “My grand adventure last night? Home, the whole night. Every hero needs an off-evening.”
- **Firsthand report:** "Picture it: yesterday's eve, as the shadows lengthened across the Square... who should I see stroll past, clear as day: none other than Agnes." (kinda feel like Fenwick should probably have additional descriptors for every character, like "none other than Agnes, why I'd recognize that smile from ten miles away.")
- **The same report under doubt:** “You wound me! Rowan, at the tavern yesterday evening. I saw them, whatever you think of the telling.”

### Greta

Tests the questioner's entitlement; sharper than Bart, focused on trust rather than efficiency.

- **Gift refusal:** ““And why would I hand that knowledge over to you? My gift stays my business.”
- **Routine alibi:** “Home all last night. I'm an civilized woman, not some rapscallion wandering the streets at all hours.”
- **Firsthand report:** “I saw Rowan at the tavern yesterday evening. Make of it what you want, if you're keeping a tally.”
- **The same report under doubt:** “Rowan was at the tavern, as I said. Show me who puts him elsewhere, then. Until you do, he was at the tavern."

### Hollis

Examines scope and definitions; precision never invents a finer location or time.

- **Gift refusal:** “A perfectly clear and reasonable question, which I shall nonetheless decline to answer. My gift remains my own affair.”
- **Routine alibi:** “At home for the entirety of last night. 'Entirety' being the operative word. Make a note of that."
- **Firsthand report:** “I observed Rowan at the tavern the preceding evening. Just past dusk, technically, if you need a finer distinction.”
- **The same report under doubt:** “I observed Rowan at the tavern the preceding evening. Your doubt is an objection to the account, but not yet a reason to revise it.”
- Accusation Response: "A novel hypothesis. Entirely unsupported by the sequence of events, mind you, but novel."

### Isolde

Fears what testimony may do to someone; cushions the consequence, not the fact.

- **Gift refusal:** “I'm sorry, truly—I'd much rather keep my gift to myself, if you can forgive me that.”
- **Routine alibi:** “I stayed home all last night. Please take my word for it."
- **Firsthand report:** “I did see Rowan at the tavern yesterday evening... though I'd hate for that to bring them any trouble.”
- **The same report under doubt:** “I don't want to argue. But I did see Rowan at the tavern yesterday evening. I'm certain of it. Nearly certain."
- Alt: “I'm not trying to stir up strife, truly! I saw Rowan at the tavern yesterday evening—I can't in good conscience say otherwise.”

### Jory

Short bursts reach for the next useful question; eagerness rather than Bart's closure.

- **Gift refusal:** “Not saying what my gift is. Something else?”
- **Routine alibi:** "Home. Asleep like a stone. Didn't hear a thing, didn't see a soul—wait, did something happen on my block last night?"
- **Firsthand report:** “Rowan. Tavern, yesterday evening. Saw them. Anything else?”
- **The same report under doubt:** “But I saw Rowan! Tavern. Yesterday evening. Which bit do you want again?”

### Kiran

Turns the question back with an easy smile; protects his own affairs without inventing a reason.

- **Gift refusal:** “Straight to my gift? You do skip the pleasantries. I'll keep that one to myself.” | "Asking for my cards on the first turn, Demonologist? Half the fun of a parlor game is the guessing."
- **Routine alibi:** “Home all last night. You were hoping for a better story, weren't you?”
- **Firsthand report:** “Rowan was at the tavern yesterday evening. I saw them. There, a question I can oblige you on.”
- **The same report under doubt:** “You did ask for my account. Must it pass an audition? I saw Rowan at the tavern yesterday evening.”
- Accusation response: "I told you where I was. If you're going to hang me, get on with it; if not, stop circling."

### Lian

Brevity is practical triage; redirects toward a useful check rather than testing personal submission.

- **Gift refusal:** "Naming my gift won't catch a killer today. Next question."
- **Routine alibi:** “Home all last night. What else needs checking?”
- **Firsthand report:** “Rowan was at the tavern yesterday evening. If that's not relevant then let's move on."
- **The same report under doubt:** “Rowan was at the tavern yesterday evening. The answer won't change, so let's move on to more important questions.”

### Merrin

Dramatizes the burden of the conversation, then lands on the concrete detail; no prophetic facts.

- **Gift refusal:** “Must we drag every private mercy into the open? No—my gift stays with me, thank you!”
- **Routine alibi:** "Barred my door at sundown and prayed for dawn, for all the good a wooden latch does against the pit! I didn't set foot outside."
- Alt: “Shut inside my home the whole wretched night, thank providence! I wasn't about to test my luck in the dark.”
- **Firsthand report:** “Oh, I dread what you'll make of this. I saw Rowan at the tavern yesterday evening.”
- **The same report under doubt:** “Heaven help us, now my own eyes are on trial! I saw Rowan at the tavern yesterday evening—would that I hadn't!”

### Nisha

Separates the contested premise from the rest; no deductions beyond the supplied account.

- **Gift refusal:** “I'm not disclosing my gift. You'll have to work around that variable for now.”
- **Routine alibi:** “I stayed home all last night. That is my account; I understand it isn't independent confirmation.”
- **Firsthand report:** “I saw Rowan at the tavern yesterday evening. Keep the sighting separate from what it might mean.”
- **The same report under doubt:** “I saw Rowan at the tavern yesterday evening. Which part do you dispute: the person, the place, or the time?”
- "Fear" response: "If I name my gift now, the Demon adjusts its plan tonight. You don't have enough on the board to make that trade worth it."

### Odette

Literal independence with dry understatement; withholding approval rather than cross-examining.

- **Gift refusal:** “Fair question. I'm sure I'll let you know if it becomes your business."
- **Routine alibi:** "In my own bed, surprisingly enough. I find the night air lacks charm when there's a murderer about."
- **Firsthand report:** “Rowan was at the tavern yesterday evening. I saw them. Utterly scandalous, I'm sure.”
- **The same report under doubt:** “I did see Rowan at the tavern yesterday evening. You want the truth or shall I make up an answer that pleases you?"

## Established-voice references

### Agnes

Invites understanding; warmth without an affectionate address on every line.

- **Gift refusal:** “I'm keeping that to myself, love. I hope you'll understand.”
- **Routine alibi:** “I was home all last night. Nothing more to tell you there.”
- **Firsthand report:** “Oh, yes. I did see Rowan at the tavern yesterday evening.”
- **The same report under doubt:** “All right, let's talk it through. I saw Rowan at the tavern yesterday evening. What troubles you about that?”

### Bartholomew

States the minimum and stops; no habitual counterattack.

- **Gift refusal:** “That's mine to know.”
- **Routine alibi:** “Home. All night.”
- **Firsthand report:** “Saw Rowan at the tavern yesterday evening.”
- **The same report under doubt:** “Rowan. Tavern. Yesterday evening. That's my account.”

### Constance

Considers the propriety of the inquiry and the responsibility of an assertion.

- **Gift refusal:** “I shall not disclose my gift merely because you ask.”
- **Routine alibi:** “I remained at home throughout last night.”
- **Firsthand report:** “As I recall, Rowan was at the tavern yesterday evening.”
- **The same report under doubt:** “I stand by my account: I saw Rowan at the tavern yesterday evening. If you object, state your grounds.”

## Review focus

Compare Greta/Bart/Lian/Odette for entitlement, closure, practical triage and dry independence; Hollis/Constance/Nisha for scope, responsibility and contested premises; Dorian/Isolde/Merrin/Jory for self-consciousness, concern for others, theatrical dread and eagerness.

Judge the short ordinary lines as well as the more characteristic challenge replies. The aim is a recognizable range, not fifteen mandatory catchphrases. Treat any line that adds unapproved certainty or investigative detail as a writing defect.

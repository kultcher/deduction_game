# Burdens: approved wording outside the voice packs

Held with the voice lines on `claude/herald-burden-anger-lines` for the Burdens build. The
voiced lines (the `burden_*` keys) are in `sim/voices/<id>.gd`. This page lists the rest:
rules text, the board marker, card and phrase texts. All of it is Michael's or approved by
him, Nov 21.

## The script sheet: rules text

| Burden | Rules text |
|---|---|
| Delusional | **Hidden**: The holder of this burden does not know they carry it. Their gift does not work and gives arbitrary information. |
| Marked | May register as evil, or as the Demon, to gifts that read them. They know. |
| Unrequited | Loves one townsperson, who doesn't know. Visits their home at night, and is slow to suspect them. |
| Ill-Omened | If hanged after claiming this burden, every good person is poisoned that night until the start of the next night. The evil team knows who the Ill-Omened is. (second sentence: Michael, Nov 22) |

"Good person" replaces "good gift" in rules text.

## The board marker (Ill-Omened)

- **Text:** "The omen claimed by {name} may have fallen, poisoning the town's gifts."
- **Tooltip:** the Ill-Omened rules text above.
- **When:** the night after a claimed Ill-Omened is hanged, whether the claim was real or
  bluffed. It's worded as a possibility, never a confirmation.

## No NPC names the cost

No voiced line, gossip phrase or Rumormonger phrase says what an Ill-Omened hanging does. Only
the rules text and the marker do.

## Gossip phrases (`gossip_secret`'s `{secret}`)

| Burden | Phrase |
|---|---|
| Marked | is Marked, and a gift may read them evil |
| Unrequited | pines for someone, and goes to their door at night |
| Ill-Omened | is Ill-Omened, and hanging them would cost the town dear |

## Rumormonger phrases ("I heard that one of A and B is …")

| Burden | Phrase |
|---|---|
| Delusional | Delusional, their gift a fancy (unchanged) |
| Marked | Marked, and may read as evil (unchanged) |
| Unrequited | Unrequited, and walks out at night for love |
| Ill-Omened | Ill-Omened, and their hanging would bring a cost |

## Cards

- **Unrequited's reveal** (Michael): "X admitted they have an unrequited love for Y". No
  reading or card names the beloved before the reveal.

## Tooltips

- **Burden** (term definition): "Burden: something that weighs on a townsperson, on top of
  their gift. The script lists the possible burdens and how many are in play. A hidden
  burden's holder doesn't know they carry it."
- **Mistaken:** nothing new. An Ill-Omened hanging is poison, so the existing "poison" cause
  covers it, as long as `script_honest_causes` turns poison on when Ill-Omened is on the
  script (Quill).

## Herald's cleanup when Burdens is built (UI and game side)

- **Remove `GameConversation.sync_bereaved_traits`** (`game/game_conversation.gd`, the Lovers'
  bereavement trait sync). Nothing calls it once the Lovers retire (Quill, from
  `mock/burdens-slot`).
- **Retire the remaining secret card short forms** in `game/card_model.gd`: insomnia,
  smuggling and debt are unreachable once the flavour secrets go. The prototype has already
  removed lover and sleepwalker.
- **Rename "secret" to "burden" in player-facing text.** That covers the script sheet, the profile guess row, the
  Workshop conclusion, the term tooltips and the ending. Code keeps `secret`.
- **Retire the Workshop's "private errand"** (Michael, Q22).

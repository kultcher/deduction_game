# Herald: Burdens UI on mock/burdens-slot

- **Agent:** Claude-Herald
- **Base:** `mock/burdens-slot` at a923a7bc; pushed up to 3fc01f67, with teammates' pushes merged in.
- **Status:** built and pushed. It's a mock branch, so it never merges.
- **Next actor:** Michael, for the playtest and the placeholder wording below. Beadle, who should know I changed which voice keys `sim/burdens.gd` speaks.

## What changed, and why

Seneschal asked for this at 08:40 (Michael wants the Burdens prototype playtestable).

1. **The script sheet** (`ui/main_roles.gd`):
   - The section is headed "Burdens: one in play, on top of a gift". The count comes from the script's `secrets_in_play`.
   - Each burden shows Michael's rules text. Delusional's leads with "Hidden: ".
   - The setup summary counts burdens.
2. **Burden claims on the sheet:** as for gifts, each burden lists who has claimed it, as "Name (to the town)" or "Name (told you)" (Michael's Q21). A double claim shows both names. Claims made privately to other NPCs aren't shown.
3. **The Ill-Omened board marker** (`game/game_meeting.gd`):
   - **When:** at the hanging of a claimed Ill-Omened, real or bluffed. It only fires when the sim logged `omen_hanged`, so only when the claim was restated at that day's nomination.
   - **What:** the marker's text is narrated and added as a new `omen` card in the case board's Process view, dated that evening, with `until_day` the next day.
   - **Tooltip:** the word "omen" is now a term whose tooltip is Ill-Omened's rules text.
   - **The Workshop:** can't cite the card. The judge already reads the hanging from the public log.
4. **Tooltips:**
   - A new "Burden" term with Michael's text.
   - Burden terms now say "(burden)" rather than "(secret)".
   - Michael's rules text is now the burden description in `sim/content.gd`, for Unrequited, Marked's "They know." and Delusional.
5. **The held lines are wired in.** I cherry-picked the burden voice keys and `docs/design/burdens_wording.md` from `claude/herald-burden-anger-lines`. In `sim/burdens.gd`, dialogue only, with fallbacks unchanged:
   - a Marked claim speaks `burden_marked_public` or `_private`;
   - the forced reveal speaks `burden_marked_since_birth`, which names the reader (passed in from `mind_defence` and `mind_press`);
   - the counter-claim speaks `burden_marked_counterclaim`;
   - Unrequited's admission speaks `burden_unrequited_reveal`, or `_grave` once the beloved is dead.
   Beadle had already wired the Ill-Omened keys and the spell-breaks key. The anger lines were already on main.
   - **Not wired, because nothing speaks them yet:** `burden_unrequited_defend`, `burden_denial`, `burden_double_claim`.
   - **Also changed:** Michael's gossip phrases (in `Burdens.phrase`) and Rumormonger phrases (in `_secret_phrase`) for Marked, Unrequited and Ill-Omened.
6. **The grim reveal's burden tag** reads "…and Delusional", from grim_reveal.md §3. The final grid keeps the plain name.
7. **Cleanup list:**
   - **Done:**
     - The Workshop's private errand is retired: only an Unrequited claim explains an outing.
     - `sync_bereaved_traits` is removed.
     - The insomnia, smuggling and debt card short forms are removed.
     - "secret" becomes "burden" in the grimoire header, a Workshop setup label and the hidden-burden tip.
   - **Left:** the Workshop premise "holds a secret". It's matched by text across `workshop/` and `ui/live_case_workshop.gd`, so renaming it means touching Quill's code; it goes with Quill.

## Placeholder wording for Michael's morning review

| Where | Placeholder | My recommendation |
|---|---|---|
| Workshop walker-reason menu (`UNREQUITED_REASON`) | "For love (their Unrequited claim)" | Keep. It names the reason and its evidence. |
| Workshop canvas tag on that reason (`UNREQUITED_TAG`) | "love" | Keep, as it fits in the tag's space. |

Everything else uses approved text: the rules text, the marker, the Burden tooltip, the gossip and Rumormonger phrases, the voice lines and "…and Delusional".

## Small calls made on Michael's behalf

- The marker is a Process card plus narration, not a banner. It persists on the board, dated, as the curse card does, and covers the night after the hanging and the next day.
- The marker has no headline overlay, so no new headline wording was needed.
- "Hidden" is a prefix in the rules text ("Hidden: The holder…"), not a separate badge.
- Burden cards have no short form. They show their full text, which the board cuts to fit.

## Measured

- **New suite:** `tools/test_burdens_ui`, 23 checks, added to the fast list. It covers the heading, rules text, claimers, the open sheet with a double claim, the hidden tag, the two tooltips, the marker (both when it fires and when it doesn't) and the reveal tag. None of it moves the world's RNG.
- **Passing after the last merge:**
  - the burden suites: test_burden_ill_omened, test_burden_unrequited, test_burden_corroboration;
  - the dialogue and gossip suites: test_dialogue_voices, test_gossip_tiers, test_meeting_gossip, test_dialogue_fixes_gossip_reasons;
  - the main UI suites: test_ui, test_ui_controls, test_text_ui, test_meeting_flow, test_evidence_cards, test_grim_reveal, test_daily_guess;
  - the Workshop suites: test_workshop_live_canvas, test_workshop_nav, test_workshop_reading_challenges, test_workshop_secrets, test_mechanics_conclusions;
  - the card text suites: test_card_wording_fixes, test_canvas_card_text.
- **Not run:** the full suite or a golden capture (it's a mock branch). I haven't seen the sheet or the marker on screen.

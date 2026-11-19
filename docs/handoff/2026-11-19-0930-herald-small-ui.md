# Herald: four small UI items from Michael's Nov 19 batch

- **Signed:** Claude-Herald
- **Base:** main at 68e4f85.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed
Michael's Nov 19 batch, relayed by Seneschal: the bugs and the small UI items. The Workshop items and removing "Speak against / in defence" follow in their own PRs.

- **RID leaks at exit.** Two hidden drop-downs in the Live Workshop (`premise_person` and `premise_type`, kept off-screen for older callers) were never added to the scene tree, so they were never freed. Each one's popup held a viewport. They're now hidden children of the tools row. Starting a case and quitting under a display now leaks nothing; it leaked 2 viewports, 2 render targets, 2 shadow atlases, canvases and textures.
- **The "p_gutter = -1" error is not in the game.** The project has no `CodeEdit`, which is the only control with gutters. Our two `TextEdit`s, the notes and the decision window's detail box, use none. The error comes from Godot's editor (its script editor) while the game runs from it. I've asked Michael where he sees it.
- **The script window.** The frame's corner leaves covered the role icons on the left and the scrollbar on the right. `_make_window` takes an optional inset, and the script window uses 22/4/18/12 px and is 40 px wider. Screenshots show the icons, the Demon section and the summary line clear of the frame.
- **Daytime sightings hidden.** "X saw Y at Z" cards from the day are hidden by default in the side card list and in the conversation's "Present a card" picker. Each list has a "Show daytime sightings" box. Both boxes share one setting, which resets with a new case. Following Michael's answer, this covers every daytime location sighting, people's own "I was at the mill" accounts included. Night sightings still show.
- **No phase change mid-conversation.** A talk's last answer still ends the phase in the game. Now the screen keeps the old phase (the clock, the map, the townsfolk and the cards) until the player clicks "Leave conversation". Nothing the player does can come between, so only what the player sees changes. Golden can't move.
  - **The townsfolk list is frozen too (Codex, #322).** Hovering it redrew live locations, so it now keeps the lines it showed and ignores the pointer until Leave. The map sits under the conversation view meanwhile.

## Measured
- **Suites:** `test_control_flow` has a new check: a talk's last answer moves the game's phase, but the clock holds until Leave. That suite passes, and so do test_day_conversation_view, test_meeting_stage, test_playtest_1709, test_ui, test_withdraw_ui, test_ui_controls, test_town_ui, test_text_ui and the four Workshop UI suites.
- **Golden:** not run. This is UI only, and no game or sim code changed.

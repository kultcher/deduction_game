# Herald: voiced lines in block terms, with no roads and no passing through

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Michael, Nov 20, via Seneschal: "there are no roads". The town is block to block: every walk goes from home to a destination, and nobody passes through a block (Quill confirmed this against the code). Seneschal asked me to reword the remaining voiced lines that use "road" or imply travelling along one. #415's rebuttals are done on that PR. These are the rest. Zero drift: golden identical.

**Reworded (22 voice lines, 3 canonical):**

| Voice / file | Key | Was | Now |
|---|---|---|---|
| Agnes | trace_fit_locations | Half the village passes through {places} | …goes by {places} |
| Agnes | nightwatch_withhold | who passed through, I'll hold onto | who I saw out, I'll hold onto |
| Bart | pressed_multi_trace_case | Anyone on that road after dark | Anyone out after dark |
| Bart | present_move_trace_lean | The street routes and traces | Who went where, and the traces, |
| Dorian | trace_fit_connection | walking past their lane | calling on their block |
| Fenwick | pressed_multi_trace_case | Any shadow on the road | Any shadow abroad that night |
| Fenwick | night_saw_nobody | Nary a soul crossed the stage! | Nary a soul stirred upon that stage! |
| Fenwick | nightwatch_withhold | the players who crossed it | the players I saw upon it |
| Greta | pressed_multi_trace_case | Anyone on that dark road | Anyone out in the dark |
| Greta | present_move_trace_lean | The street paths and scene traces | Who went where and the scene traces |
| Hollis | present_move_trace_lean | The routes and the traces | The movements and the traces |
| Isolde, Jory | trace_fit_locations | pass through {places} | go by {places} |
| Jory | present_move_trace_lean | The street routes and scene traces | Who went where and the scene traces |
| Jory | pressed_nightwatch_night | My watch route took me right through {block} | I was keeping watch on {block} |
| Kiran, Lian | pressed_multi_trace_case | anyone on that road after dark / at night | anyone out after dark / at night |
| Lian | present_move_trace_lean | Route coverage … lawfully eligible passers keep it circumstantial | Who could have been where, and the scene traces, … it stays circumstantial |
| Merrin | augur_yes / augur_no | The Demon crossed my road / Not a Demon on my road | The Demon crossed paths with me … Woe! / Not once did the Demon cross my path |
| Nisha | present_move_trace_lean | the routes and the traces | the movements and the traces |
| Nisha | pressed_nightwatch_night | My watch route covered {block} | I was keeping watch on {block} |
| canonical (mind_press, mind_dialogue, dialogue_presentations) | the same three keys | road / pass through / routes | out in the dark / go by / movements |

**Kept on purpose (small calls made on Michael's behalf):**
- **The Lamplighter's "lamp route" and "rounds".** The Lamplighter really does walk a round of blocks each night, block to block, so it's not a road.
- **"Crossed paths with the Demon"** in the other Augur lines. It's the idiom for meeting someone, which is the Augur's rule (in public on the same block), not a road.
- **"A long road from murder"** (Edda). It's an idiom.
- **Generic town flavour** ("its streets", "prowling the lanes").

**Not changed here; drafted for Michael via Seneschal:** the Night Watch card ("I saw A, B pass by"), its fabricated twin in `sim/evil.gd`, and the Vigil tooltip ("not those only passing through"). These are evidence and UI text, and the wording is Michael's.

## Measured

- test_dialogue_voices, test_dialogue, test_text_terms, test_dialogue_decisions, test_augur_wording and test_too_clean_bluffs pass.
- **Golden:** identical at `--tol 0` on all five seeds.

## Proposed for the backlog
None.

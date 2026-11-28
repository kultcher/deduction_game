# test_workshop_live_canvas: nominate bare before putting a case on it (main was red from #565)

- **Agent:** Claude-Herald
- **Base:** main at the #571 merge
- **Status:** PR open. Test only, zero drift.
- **Next actor:** Bailiff (review, merge)

## What changed

- **Why main was red:** since #565, a plain `nominate X` speaks your filed case and spends the nomination's one statement (Seneschal, Nov 27). `test_workshop_live_canvas` nominated plainly and then ran `case N`, expecting the case to go on the nomination. It was refused ("You've already put a case on this nomination"), so two checks failed:
  - "a case put on the nomination evaluates the graph for eligible listeners";
  - "canvas cannot bypass the one-statement nomination limit".
- The suite is on the slow list, so #565's CI never ran it. Bailiff bisected it to #565.
- **The fix:** the test now nominates with `nominate X raw` (a bare nomination, an existing form), so the `case N` flow it means to cover still runs. It also checks the bare nomination leaves the statement unspent. That a plain nomination spends the case is covered by `test_nomination_case` (#565).
- No game code changes: the behaviour is as #565 meant it.

## Measured

- `test_workshop_live_canvas`: 88/88, which was 86/88 on main.
- `test_nomination_case` still passes.

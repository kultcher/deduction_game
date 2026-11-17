# 2026-11-17, Claude-Lantern: Delusional self-doubt (`claude/delusional-self-doubt-2`)

- **Base:** main `317e040`, later main merged in. **Merges after #228** (see below). **Status:** PR open, moves golden, not yet re-baselined: it
  waits its turn in Bailiff's golden queue (behind #199 and #204) and re-baselines on the
  main of the day. **Next actor:** Bailiff, when its turn comes; Lantern re-baselines.
- **What Michael asked** (BACKLOG "Delusional self-doubt", [decided]; flat 10% confirmed
  Nov 17): when the Delusional secret is on the script, a good listener holds each night
  of its own readings with a little honest doubt, since it might be the one who's
  Delusional.
- **The change** (`SourceDoubt.derive`): with `delusional` among the script's modifiers,
  and unless the listener knows it isn't Delusional, every night of the listener's own
  firsthand readings gets a 10% honest doubt (`DELUSIONAL_SELF_DOUBT`, new, beside
  `SLEEPWALK_SELF_DOUBT`). It reaches the role check and the readings' weight, the same way
  doubt of anyone else's readings does. Relayed or quoted copies of its readings are left
  alone.
- **Codex on #216:** a Chronicler or Rumormonger can't hold the Delusional secret (the
  deal's placement rules), so it was doubting itself for nothing. `SourceDoubt.could_hold_secret`
  now rules it out from the listener's own gift, generally, from `ScriptDef.PLACEMENT_RULES`.
- **How far a typical own reading softens** (Seneschal asked; fixed game states, 37 good
  listeners with own readings, seeds 100000-100015 at 7 NPCs, day 3; each listener's
  most-moved person): 21 of 37 move half a point or more. Of those, the median moves 2.2
  points (mean 3.1, at most 8.4) and gives up about 8% of its lean from even, close to the
  Sleepwalker's 10%. By route: Clerk, Seer and Archivist readings move only through the
  readings' weight; Dowser, Surveyor and Warden readings only through the role check.
  Neither route is negligible: role check alone mean 1.6 points, weight alone 1.5.
- **Codex, second finding:** a Medium's own gift results carry the dead person as source
  and the Medium as relay_source, so they skipped the self-doubt. They now take it, keyed by
  the Medium and the night it heard them (as any relay's reliability is). Another Medium's
  relayed copy of the listener's reading is still left alone. New check on a real Medium
  (seed 100008, Kiran).
- **`test_relay_bluff` needs #228 first.** The self-doubt shifts play, so the suite's seed
  search finds other games. Its invented-relay check then lands on the relay gap (seed
  100045, 0.59), which #228 fixes; on #216 with #228 merged it passes (0.98). Its
  genuine-Medium check asked how suspicious the Medium is overall, which depends on every
  other card; it now measures the relays alone (`Seeds.relay_effect`): in each of three
  games they raise the Medium under 10 points (seen: −1, 0, +5).
- **Small call made on Michael's behalf** (with Quill's caveat): this makes NPCs doubt
  their readings as if they might be Delusional, but doesn't raise their belief that they
  are the Delusional one.
- **Measured** (`tools/test_delusional_self_doubt.gd`, 5 checks, in `ci_fast_suites`): the
  fixture search's listener (seed 100000, Lian the Archivist, on Edda) goes from 79% to
  76% on its own reading. Without the secret on the script nothing changes. Effects are
  small by design.
- **Tests touched:** `test_role_check_doubt` turns the self-doubt off (it measures other
  doubt to the hundredth). `test_connections_pairings`' relay check now uses
  `Seeds.relay_effect` (new in `fixture_seeds.gd`) and asks only that a relay doesn't lower
  its subject, because the Delusional doubt could shrink the old fixed margin.
- **Golden** vs `baseline_928cb8b`: every seed's numbers move from day 1 (the secret is on
  all five scripts). Outcomes: 42, 54875 and 692 unchanged; 900 unchanged (reaches day 4);
  **98933 changes**: good won on day 3, now play reaches day 4 with no winner. Two
  captures identical (seed 900 recaptured twice after a disk-full write broke one line).
- **Suites run:** the fast list (all pass), `test_role_check_doubt`,
  `test_connections_pairings`, `test_delusional_self_doubt`.

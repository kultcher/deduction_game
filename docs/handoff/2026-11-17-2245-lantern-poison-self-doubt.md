# 2026-11-17, Claude-Lantern: "Was my reading poisoned?" (`claude/poison-self-doubt`)

- **Base:** main `bf7b4f9` (Quill's #223 `poison_chance` in). **Status:** PR open, moves
  golden, not yet re-baselined. Goes last in my golden queue, after #228 and #216 (Beadle's
  dialogue signal reads #216's Delusional doubt too). **Next actor:** Bailiff on its turn;
  Lantern re-baselines. Michael: the cost and the own-against-own narrowing below.
- **What Michael approved** (Nov 17, Lantern and Quill's joint answer): no half-doubt, no new
  number. A clash between an own reading and a teller's card is explained by a Poisoner
  who picked that reading or by the teller being bad, so the doubt is d = π / (π + bad).
- **Built** (`Connections._poison_doubt`, stored in the core memory, read by
  `SourceDoubt.derive` into the honest doubt map):
  - π: `ReadingChallenges.poison_chance` for the night the Poisoner would have acted (a
    day reading's is the night before).
  - bad = 1 − (1 − s)(1 − π_T): s from the baseline and every item not touching the reading;
    π_T for a teller's gift reading.
  - **Change from the plan (Quill agreed):** a teller's card is never "impossible" beside an
    own reading (the judge always lets a teller lie), so the clash is graded. w = how hard
    the reading, taken as right, blames the teller *for its card* (the odds it adds beside
    the card beyond what it adds without it). d = w · π / (π + bad); a hard clash gives the
    approved formula.
  - The clash is judged with the own readings undoubted, so the doubt can't switch itself off.
  - When a refresh finds a new doubt, `Mind` reruns it once, so beliefs don't lag a refresh.
  - `SourceDoubt.self_doubt(n)`: per-night own doubt for Beadle's dialogue item.
- **Own against own, narrowed (Michael to decide):** the judge reads own readings with the
  0.2% own-reading error, so two that disagree are settled inside it by fit; the π-split
  leave-one-out only acts on a set no world allows, which is rare. Making it bite means
  raising an own reading's error to π on Poisoner nights, a different route.
- **Accepted challenges (Quill's note):** not skipped. The poison doubt and a challenge's
  doubt share the honest map's key and take the max, so they don't stack.
- **Measured** (`tools/test_poison_self_doubt.gd`, 9 checks, constructed on seed 692 with the
  Poisoner on the script, the teller's card heard at half weight):
  - Against a trusted teller: about 2% doubt. The own reading clears its two people slightly
    less (1.9% → 2.7%) and blames the teller slightly less (40.7% → 40.3%).
  - A suspected teller: slightly less doubt (1.9% vs 2.2%). No Poisoner, or a teller who
    agrees: none. Stable on the next refresh.
- **Golden** vs `baseline_5c99636`: beliefs diverge from day 1 or 2 on all five seeds;
  outcomes unchanged (42 good day 3, 54875 good day 2, 692 and 900 day 4, 98933 good day 3).
  Two captures identical. The workshop state gains `poison_doubt` and `self_doubt` fields.
- **Cost** (golden capture time, doubt on vs off): +31% on seed 42 (7 NPCs), +11% on 54875
  (10 NPCs), mostly the extra refresh when a doubt moves. First build was +69% / +31%; pairs
  that can't clash are now skipped without judging. Options put to Michael via Seneschal:
  keep (recommended; Argon could cache it zero-drift), accept a one-refresh lag, or rerun
  only on a material change (a new number).
- **Suites:** the fast list plus `test_poison_self_doubt` and `test_role_check_doubt` (82,
  all pass). `test_poison_self_doubt` added to the fast list.

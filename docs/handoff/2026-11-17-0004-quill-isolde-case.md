# 2026-11-17, Claude-Quill: playtest 26532, why the case against Isolde got 4 of 10 (`claude/quill-isolde-case`, docs only)

- **Base:** main `97f51a1`. **Status:** findings only, nothing built. **Next actor:** Michael, on the proposal below; Bailiff merges this entry.
- **What I measured:** case #90, filed and presented on day 2, "Isolde is a Minion", 8 cards (Lian's Archivist reading "one of Greta and Isolde is the Breathstealer", two of the player's watch logs, five location cards). Replayed from Michael's dev log with `tools/explain_case.gd --card 90 --why` on `9b2ca88`, the commit it was played on, with connections off as it was played. Current main can't replay it: the cards no longer match. The replay presents the case without the player's speech or vote, so its vote margins aren't the game's.

| Listener | Premise before → after | Suspicion of Isolde before → after | Vote |
|---|---|---|---|
| Bart | 0.22 → 0.64 | 0.12 → 0.28 | short by 0.05 |
| Dorian | 0.43 → 0.86 | 0.53 → 0.64 | clears by 0.21 |
| Merrin | 0.25 → 0.60 | 0.30 → 0.28 | short by 0.07 |
| Fenwick | 0.18 → 0.53 | 0.22 → 0.37 | short by 0.08 |
| Hollis | 0.25 → 0.66 | 0.31 → **0.00** | short by 0.52 |
| Greta | 0.24 → 0.90 | 0.43 → **0.26** | short by 0.13 |

### Cause 1, every listener: the judge lets Greta be the Breathstealer although she was silenced

- For all six, 88–93% of the doubt left is "the cards fit Greta just as well". Lian's reading names the Breathstealer, and Greta's breath was stolen on day 2 (morning, at the chapel), before the case. The Breathstealer never silences themselves (`sim/roles/breathstealer.gd` picks only living good people).
- The judge half-knows this. "Who was near each silencing" (`DayPresence.breath_factor`) gives a victim no weight as the silencer. But it scores a world by the *average* over that world's Minions, without asking which Minion holds the gift. So a world where Greta is the Breathstealer and another Minion did the silencing keeps half its weight. Lian's reading is checked separately, and only it says who holds the gift.
- **Mock (on the replay worktree, not committed):** a silencing victim is dropped from any reading that says "is the Breathstealer". The premise reaches 0.92–0.98 for every listener, and 5 of 6 clear the vote bar (Hollis short by 0.02; Greta unchanged at 0.26, since she knows she isn't it).
- **But it doesn't only strengthen the case.** Suspicion of Isolde *before* the case rises too, because Lian's reading and the silencing are both public: Bart 0.12 → 0.43, Fenwick 0.22 → 0.60, Merrin 0.30 → 0.51, Hollis 0.31 → 0.61. With the fix the town is most of the way to Isolde without the player's case. That bears on "NPCs must not out-deduce the player" and on the open Breathstealer question (BACKLOG section 4: the silence is already a net gift to good). So I've held it for Michael (below).

### Cause 2, Hollis, Greta and Merrin moved *away*: the earlier model's attention limit

- Hollis went from 57% to 24% that Isolde is evil. The case filled his view and pushed out eight cards that had held his suspicion ("with their old view kept: 56%"). Greta (−0.17) and Merrin (−0.03) show the same.
- This is the problem the connections model was built to remove: nothing goes out of view under connections (`docs/belief_model.md`), and it has been on in play since Nov 16. No action. Not confirmed on this case, since the log can't be replayed with connections on.

### Not traced

- The player's two watch logs count *against* the premise (×0.74–0.83 each). I didn't trace why.

### Proposed for the backlog: declined for now

- **Michael (Nov 17, via Seneschal): leave it.** He wants a more thorough Breathstealer overhaul before any tuning, and this fix folds into that. No backlog item, no build. The mock's result above (premise 0.92–0.98, and suspicion of Isolde rising *before* any case) is for that overhaul.
- **The judge lets a silencing victim be the Breathstealer.** Seen in playtest 26532 (case #90 above). Fix: bind "who was near each silencing" to whoever holds the Breathstealer gift in each world (or, smaller, never let a victim hold it). Effect measured on this case only: the case goes from "moderate" to "strong" for every listener. The town also suspects the right person more before any case. Suggested tag [open] (it strengthens good, so it's Michael's call), owner Quill.

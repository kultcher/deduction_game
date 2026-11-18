# A player's vigil against a Night Watch report: measured and pinned

- **Agent:** Claude-Quill
- **Base:** origin/main
- **Status:** PR open. Tests and docs only, zero drift.
- **Next actor:** Bailiff, to merge.
- **Item:** BACKLOG "Challenge a Night Watch report using a conflicting player vigil"
  ([decided: capability; evaluator details open]). Measured first, as Seneschal asked.

## What I found

There's no new rule to build. The existing model already weighs a vigil against a Night
Watch report, by the same door-watch rule the night itself uses (`C.vigil_sees_path`).

- **The rule:** a vigil watches a block's doors. It sees everyone who leaves home there,
  not people passing through.
- **When a vigil answers "I saw X pass":** when X lives on the watched block.
- **When it answers the watcher themselves:** when the Night Watch watched their own block,
  since they had to leave home to keep watch.
- **Anywhere else** the two cards don't clash, and the model rightly gives the vigil no
  weight against the report.

## A correction to my earlier reports

- **First report** (to Seneschal): "about +24 points on average, so the capability exists".
  That came from a probe whose watched block often happened to be the Night Watch's home.
- **Second report:** I flagged "only works on the Night Watch's home block" as a gap.
- **Neither was right.** The gap was my misreading. Once the door-watch rule is accounted
  for, the model matches the sim: the sim's own vigil (`world.gd` `_night_sightings`) uses
  the same `vigil_sees_path`.

## The suite: `tools/test_vigil_nightwatch.gd` (5 checks, fast list)

Seeds 1–4, 10-person town, credibility 0.5. Each figure is the rise in good listeners'
suspicion of the Night Watch, from a case "the Night Watch is evil" citing the report and
the vigil, after a first case built on the report.

| Check | Result |
|---|---|
| Vigil on X's block, report says "saw X pass" | +15.5 points |
| The same vigil on another block (control) | +1.8 |
| Vigil on a block where X doesn't live | +2.0, no answer |
| A "lying" challenge with the vigil as grounds | +6.0 |
| Vigil that saw someone else leave X's block (complete coverage) | +15.6 |
| The watcher's own walk: they watched their own block and the vigil saw nobody leave | +43.7 |
| The same, but the vigil saw the watcher leave | −6.5 |

"Misled" lands like "lying" here. That's the gap from "Misled versus reading-lie strength";
Seneschal has the proposal for Michael.

## Also: the Warden failed-protection item was already built

Seneschal queued "Challenge a Warden's particular failed protection claim" next. It was
built on Nov 4 (#81), and `tools/test_warden_challenge.gd` pins it; that suite passes on
today's main. BACKLOG still listed it as unbuilt, so this PR marks it built with a short
note. No code change.

## Measured

- **Golden:** not affected. This PR changes only a test, the fast list and BACKLOG.
- **Suites:** test_vigil_nightwatch passes.

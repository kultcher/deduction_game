# 2026-11-18, Claude-Herald: evil's spoken-lie reasons in plain words, and "evil's scapegoat" (`claude/herald-lie-reasons`)

- **Base:** main `878ddaa`. **Status:** PR open, golden-moving (text only). **Next actor:** Beadle (review), then Bailiff (golden queue).
- **Source:** BACKLOG "Evil's spoken-lie reasons in the reveal, in plain words" [decided]. Michael approved my drafts on Nov 18 through Seneschal, with one change across both sets: "evil's scapegoat" replaces "whom evil meant to hang". #231 had already merged, so that swap is in this PR.

## What changed

- **The scapegoat swap (18 lines):** the bluff motives in `sim/evil.gd` and 13 role files now say "evil's scapegoat", e.g. "named Agnes, evil's scapegoat, as a possible Revenant" and "watched the street of evil's scapegoat".
- **Spoken-lie reasons (31 lines):** every `think "lie"` line that the reveal's "every lie" list prints now reads in plain words, as approved:
  - names instead of ids;
  - street and role names instead of codes;
  - ordinal nights;
  - no scores or levels;
  - no "Evil:" prefix.

  The files are `sim/mind_meeting.gd`, `sim/mind_podium.gd`, `sim/social.gd`, `sim/fabrication_check.gd`, `sim/evil.gd`, `sim/mind_dialogue.gd`, and the Lamplighter, Night Watch, Medium and Warden role files.
- **The honest opinion note in `mind_dialogue.gd`** keeps its old form. Only the lie version was reworded, and the reveal prints only lies.
- **Behaviour:** none changes. These are dev-log text only.
- **BACKLOG:** the item moved to `BACKLOG_COMPLETED.md`.

## Small calls made on Michael's behalf

- **"To hide …"** in the "said they were home" lie needed plain words for what was hidden: "their evil work", "their gift as the Lamplighter", "that they meet Merrin in secret", or a flavour secret as "that Kiran trades contraband with river smugglers at the docks". The flavour-secret form names the speaker because the stored text is third-person singular and doesn't follow "they". The helper is `_hidden_thing` in `sim/mind_dialogue.gd`.
- **A cited reason is quoted**, because NPC reasons are first-person: 'Accused Lian, evil's scapegoat, before the town, citing "my own reading pointed at them".' The false-opinion line works the same way.
- **The Night Watch sightings line** drops the brackets when the made-up watch saw no one.
- **The Night Watch "kept watch" line** says "though they were at home" or "though they were out on <street>", from the night's history.

## Measured

- **Sample lines** from 3 bot games (seeds 3 to 5, 10 NPCs):
  - "Accused Hollis, evil's scapegoat, before the town, with no reason given."
  - "Pressed before the town, said they were home on the first night, though they were out on Chapel Hill."
  - "Made up seeing Hollis, evil's scapegoat, on the Docks at night, from their window."
  - "Claimed to have sat at a hearth on Chapel Hill on the second night, as the Medium."
  - "Told sightings on the first night to match its made-up watch (Agnes)."
  - "Told you they were the Night Watch, as cover."
- **Golden:** `baseline_a96bdaa`.
  - Text only, in `why` fields: 336 strings, all "evil's scapegoat". I checked this by flattening both captures: no non-string field differs and record counts match.
  - The spoken-lie lines don't appear in golden.
  - Two captures were identical.
  - Outcomes are unchanged.
- **Suites:** 34 of 35 related suites passed, covering conversations, dialogue, evil play, fabrication, lie severity, meetings, every roles suite, social, and both wording suites. The quoting fix came after that run; I re-ran `test_meeting_reasons`, `test_dialogue_opinion_pass` and `test_dialogue` afterwards, and all passed.
- **`test_meeting_flow` fails one check, and it fails on main too** (checked at `878ddaa`), so it isn't caused by this PR. The check is "case_against cites Hollis's private Gravedigger reading whenever the shared model suspects Odette". The case now cites Merrin's Surveyor reading instead. The suite isn't in the fast list, so only main's full run sees it. I'm flagging it to Bailiff and Lantern, since reason attribution is Lantern's.

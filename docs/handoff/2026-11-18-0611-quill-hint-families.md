# Eleven hint families, with a script-aware pick

- **Agent:** Claude-Quill
- **Base:** origin/main at the branch point of `claude/hint-families`
- **Status:** PR open; golden re-baselined to `baseline_4211f5b`.
- **Next actor:** Bailiff (golden-moving: merge one at a time). Herald follows up with
  voice lines for the new families.
- **Decision:** Michael, Nov 18, via Seneschal. All eleven families stay, with first-pick
  names and generic base lines only for the new families (no per-voice lines yet). The
  script-aware pick replaces a seeded random one.

## What changed

- **`C.HINT_PACKAGES`** (`sim/content.gd`) now holds eleven families. The roles in each
  are listed in DESIGN under "Hint families". Every live good gift is in at least one, and
  each family holds 3 to 5 live gifts.
- **`C.hint_package(w, role)`** chooses the family for a gift in several. It takes the
  family with the most gifts on the case's script, breaks a tie by
  `hash([seed, role, family])`, and keeps that choice for the game. The pick is the same
  for a true holder and for evil bluffing the gift. It returns "" when every family the
  gift is in has only that gift on the script.
- **Every place a hint is chosen** now uses it: private disclosure (`mind_dialogue`), the
  podium (`mind_podium`), private gift talk and tavern rumour (`social`), the dev screens
  and the profile panel. `package_of` remains, unaware of the script, for nothing but a
  fallback.
- **The guard:** a holder at the hint tier with no family to hint from gives the tier-1
  answer instead, refusing to say, so the gift stays hidden. The podium and gift talk
  already skip a hint when there's no family.
- **Voice lines:** the new families (affairs, justice, true_gifts, chosen, against_dark,
  conquer_death) use their base `text` through the existing `say_voiced` fallback, with no
  `hint_pkg_*` keys. `test_dialogue_voices`' key list is unchanged. The base lines for the
  dead and shelter are Herald's revised ones.
- **Tests:**
  - `tools/test_hint_families.gd` (28 checks, fast list): family sizes, coverage, the
    fullest-family pick following the script, a seed tie-break that is fixed and goes both
    ways across seeds, no hint when alone, and real holders' hints naming the chosen family.
  - `test_roles_registry`: the Magistrate is now in affairs.
  - `test_workshop_hints`: its matching claim uses the Clerk, since the Surveyor left
    official business.
  - `test_npc_chatter` and `test_peer_role_gossip` now use `hint_package`.

## The "fullest family" tell (for playtests to watch)

A gift in several families always hints from its fullest one on the script. A player who
knows the script and reads which family was named might narrow the gift a little further,
for example: "a Gravedigger here would have hinted the dead, not justice". I haven't
measured how often this would help. A playtest review should note whether it happens.

## What I measured

- **Golden:** it moves on two seeds, and only in which family a hint names, its role list
  and its wording. On 692 a Medium's hint is heard as night sight instead of the dead. On
  900 a Psychologist's hint is heard as "against the dark" instead of reading people.
  - With hint fields ignored (`--ignore engine,package,roles,text,reply,lines,statement`),
    all five seeds are identical: no belief, vote or execution changes.
  - The end records are identical on every seed.
  - Two captures were identical.
- **Suites:** all 26 suites that mention hints pass, after the two test updates above,
  plus test_hint_families.
- **What a hint narrows to** (15 of 22 gifts on a script, rough):
  - A family of 3 leaves about 2.
  - A family of 4 leaves about 2.7.
  - A family of 5 leaves about 3.4.
  - The pick nudges these up a little.

## Proposed for the backlog

None.

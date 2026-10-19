# Shared text formatting

Step 1 provides `ui/text_terms.gd`: the public term registry and matching rules.
The formatter, rich-text rendering, hover behavior and UI integration are later steps.

## Registry

`Terms.new()` seeds names from `C.CAST`, colors from `C.npc_color()`, and gifts from
`C.ROLES`. It reads no world, NPC, claim, secret or case state. Registering a person
does not associate them with a gift. All defined roles are vocabulary, not evidence
that those roles are in play.

Stable IDs use `person:<cast id>` and `role:<role id>`; Bartholomew is `person:bart`.
`lookup(id)` returns a deep copy with `kind`, `content_id`, `label`, `aliases`, and
optional appearance: `color`, `icon_path`, `tooltip`. A null color means inherit;
empty icon/tooltip strings mean absent. Characters start with their color only.
Role tooltip content is the existing public name and description. Existing role
PNG paths are supplied where available, otherwise the icon path is empty.

`register_term(definition)` accepts other kinds such as places or statuses. Required
fields are nonempty `id`, `kind`, `label`. Optional `aliases` defaults to the label.
Aliases are strings or `{text, case_sensitive, role_only}` dictionaries. Strings
match case-insensitively. Duplicate IDs or invalid aliases reject the complete
registration. Equal-length alias collisions resolve by stable ID order.

## Matching contract

`find_matches(plain_text, options = {})` returns ordered, non-overlapping
`{id, start, end, text}` ranges. `end` is exclusive; offsets are Godot String
character offsets. `text` is the original substring, preserving spelling and case.
Unmatched text remains available between ranges for the future formatter.

- Whole words/phrases only: Unicode letters, numbers, combining marks and underscore
  prevent a boundary. Both straight and curly possessives match the name itself.
- At the same start position, the longest eligible alias wins.
- Names match case-insensitively. Multiword role names remain one reference.
- Ambiguous gifts (for example Medium, Clerk, Veteran) require canonical
  capitalization in ordinary prose. Lowercase ordinary uses remain unrecognized.
  Capitalization is a convention, not semantic understanding; occupation segments
  should restrict eligible kinds. The explicit ambiguous-role list lives beside
  the registry defaults.
- `role_context: true` enables lowercase ambiguous role names and internal role IDs
  in text that the caller already knows describes gifts.
- `kinds: ["person"]` permits names while suppressing roles (useful for occupations).
  Omitting `kinds`, or supplying an empty array, permits all registered kinds.
- `enabled: false` opts out for an ineligible segment, such as an input or command.

Call only on eligible plain-text segments, before rendering markup. This matcher
does not parse BBCode, recognize links, resolve pronouns, or infer a person's role.
Existing markup and card references must be handled structurally by the later
formatter. It emits no icons, colors, hover controls, or changes to source strings.

## Next steps

2. Turn matches and intervening plain text into styled spans, with speaker/background
   context and whole-content opacity applied by the renderer.
3. Integrate logs and profiles, including role hints that coexist with card links.
4. Add wrapping/layout support for board cards, pinned deductions and the tray.
5. Integrate Card List and other eligible text surfaces.

Run the step-1 checks:

```sh
godot --headless --path . --script res://tools/test_text_terms.gd
```

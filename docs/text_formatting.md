# Shared text formatting

Step 1 provides `ui/text_terms.gd`: the public term registry and matching rules.
Step 2 adds `ui/text_formatter.gd` and `ui/rich_text_renderer.gd`: styled spans and
a native rich-text adapter. Step 3 integrates the speech log and both profiles.

## Registry

`Terms.new()` seeds names from `C.CAST`, colors from `C.npc_color()`, and gifts from
`C.ROLES`. It reads no world, NPC, claim, secret or case state. Registering a person
does not associate them with a gift. All defined roles are vocabulary, not evidence
that those roles are in play.

Stable IDs use `person:<cast id>` and `role:<role id>`; Bartholomew is `person:bart`.
`lookup(id)` returns a deep copy with `kind`, `content_id`, `label`, `aliases`, and
optional appearance: `color`, `bold`, `icon_path`, `tooltip`. A null color means inherit;
empty icon/tooltip strings mean absent; omitted bold defaults to false. Characters
have their own color and bold text. Roles also use bold text, with `role_good`
(deeper blue than Nisha) or `role_evil` (red) from the shared UI palette. Neither
reserved color is assigned to a character. Colors describe the role word, not the
speaker's actual alignment or the truth of a claim. On parchment the formatter
uses darker ink variants of these colors.
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

## Formatter (step 2)

`Formatter.new(registry = null)` uses a supplied registry or seeds the defaults.
`format_text(plain_text, context = {})` returns spans covering the complete original
text, with no gaps, repeated characters or generated markup. Empty text returns
an empty array. Each span has:

- `text`, `start`, `end`: original text and exclusive character ranges.
- `entity_id`: the registry ID, or an empty string for ordinary text.
- `color`, `bold`: resolved text appearance; color retains its own alpha.
- `opacity`: overall opacity, clamped to 0..1 and not yet multiplied into color.
- `surface`: normalized `dark` or `paper`, also used to choose readable inline art.
- `font_size`, `icon_size`: positive pixel sizes.
- `icon_path`, `tooltip`: optional metadata, empty when absent or disabled.

Context options:

| Option | Default | Effect |
| --- | --- | --- |
| `surface` | `"dark"` | `"paper"` uses parchment ink variants for entity/speaker colors. |
| `base_color` | Surface's text/ink color | Color for ordinary text without a known speaker. |
| `speaker_id` | `""` | A cast ID, such as `"bart"`; supplies the surrounding speech color. |
| `font_size` | `16` | Text size; also the default icon height. |
| `icon_size` | Font size | Explicit icon height. |
| `opacity` | `1.0` | Overall opacity, including icons. |
| `bold` | `false` | Emphasize a whole segment; registered name/role spans are always bold. |
| `icons`, `tooltips` | `true` | Disable either decoration independently of name colors. |
| `enabled`, `kinds`, `role_context` | Registry defaults | Control recognition on this eligible segment. |

Color precedence is explicit entity color, then known speaker color, then base
color. A custom term with no explicit color inherits the surrounding speech/base color.
Entity overrides end at the entity span; subsequent ordinary text resumes the
base style. Parchment conversion preserves custom color alpha. A supplied base
color is already a surface-specific color and is not converted a second time.
`enabled: false` disables recognition while retaining surrounding speech styling.

`Formatter.plain_text(spans)` reconstructs the exact source text for copying,
searching or a plain renderer; icons are supplemental metadata. Future board and
list renderers can use these spans without parsing rich-text markup.

## Rich-text adapter (step 2)

`Renderer.new().append_to(rich_text_label, spans)` appends using native font, color,
hint and image operations. Source text goes through `add_text()`, so literal
brackets and BBCode-looking strings are displayed as text. Hints likewise use the
native API. The adapter balances its own pushes and pops, preserving an outer
card-link/bold/italic context; it does not create click actions or clear the label.
Callers own the label's font family, tooltip underline style and other UI settings.

Inline icons retain aspect ratio and transparency. `ui/inline_icons.gd` returns
original art on parchment and a warm light-ink variant on dark surfaces. The dark
variant inverts luminance into the paper palette, keeping engraved details readable
without the cyan colors of a full RGB negative. It processes only the small display
image and caches by path and size. Original resources stay untouched. The adapter
adds a nonbreaking gap between each icon and its complete textual role name.
Unavailable textures produce text without an icon or added gap. Source lookups,
including missing resources, are also cached. Portraits and decorative log art use
their existing presentation; this adjustment applies to the small inline term icons.

The shared `Renderer.text_color(span)` and `Renderer.icon_color(span)` helpers apply
overall opacity once: text alpha is its own alpha times opacity; icon modulation
is white with that opacity. Both native and later custom renderers should use the
same rule, without multiplying overall opacity again at the parent control.

Append successive formatted entries to retain log content. Call `clear()` to rebuild
a label; assigning its `text` property after native rendering reconstructs its
contents and discards native styling. Godot's parsed-text fallback represents inline
images with spaces; use `Formatter.plain_text()` when exact original text is needed.

## Log and profiles (step 3)

`ui/log_text.gd` presents the existing plain game output. It recognizes speech,
headers and generated card-reference suffixes before rendering eligible text;
there is no search-and-replace pass over generated markup. Speech retains its
speaker color and portrait, while mentioned names and roles override their own
spans. Headers, leading emphasis and card links use the native text stack. Typed
command echoes opt out of enrichment, including apparent tags or card suffixes.
Each new entry appends to the log without rebuilding its history.

`ui/profile_panel.gd` renders both town and case-board profiles through the same
formatter. About text, readings, disclosed claim headers, Their claims and About
them share the vocabulary. Occupation/biography segments permit names only; debug
text opts out. Private/public provenance and original card times are retained.
The entire card passage remains a `card:<number>` link; native role hints sit
inside that context, preserving its left-click and right-click actions. Hidden
entries receive the shared hidden opacity, including names and role icons.
Claim display still uses the existing disclosure gates.

`ui/formatted_text_label.gd` provides wrapping role tooltips capped at 480 logical
pixels (or 75% of the viewport when narrower), using the existing paper theme.
The log uses 20px inline icons; profile entries use 18px alongside 16px text.
Matching normal, bold, italic and bold-italic system-font faces are installed
through `UITheme.rich_text_fonts()` so emphasizing names preserves the font family.

## Next steps

4. Add wrapping/layout support for board cards, pinned deductions and the tray.
5. Integrate Card List and other eligible text surfaces.

Run the registry, formatter and live UI checks:

```sh
godot --headless --path . --script res://tools/test_text_terms.gd
godot --headless --path . --script res://tools/test_text_formatter.gd
godot --headless --path . --script res://tools/test_text_ui.gd
```

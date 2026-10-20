# Text system handoff: card extension paused

Status: steps 1–3 are complete on `codex/text-log-profiles`. Steps 4–5 are
**deferred at the player's request** until card zoom and presentation are settled.
No card-rendering or gameplay changes accompany this document.

Snapshot: `73629a4` (small inline icons on dark surfaces), following `76877ea`
(log/profile integration and entity styling). The branch was reviewed against
`origin/main` at `78da9e3`; that newer main work has not been merged into this
branch. Recheck both histories before resuming, particularly if another developer
has changed profiles, case-board UI or shared theme code.

See [the API reference](text_formatting.md) for full field and matching contracts.

## Completed work

| Step | Delivered | Scope boundary |
| --- | --- | --- |
| 1: vocabulary | Public names and roles, aliases, stable IDs, whole-word matching and ambiguity rules | No inference about an NPC's real gift or whether a gift is in play |
| 2: formatter | Plain text to styled spans; native rich-text adapter; literal text preserved | No board geometry, wrapping engine or custom-draw hit regions |
| 3: integration | Speech log and both shared profile panels; role tooltips; existing card links/actions preserved | Board cards, pinned deductions, tray and Card List still use their existing renderers |
| Styling follow-ups | Bold names/roles; good role words blue, evil role words red; parchment ink variants; readable small icons on dark backgrounds | Colors describe the word, not the truth of a claim; original art stays unchanged |

Speech keeps its speaker color except where another name or a role overrides its
own span. Typed commands stay literal. Profiles preserve disclosure gates, original
card times, provenance, hidden-card fading and card actions. Role hints inside a
card passage do not replace its card navigation or right-click menu.

Only small inline term icons get the new dark-surface treatment: luminance is
inverted into warm light ink while transparency is preserved. Parchment uses the
original image. Portraits and decorative log/header art keep their existing look.

## Existing entry points

Paths below are relative to the repository root.

| File / API | Responsibility and useful hook |
| --- | --- |
| [`ui/text_terms.gd`](../ui/text_terms.gd): `register_term`, `lookup`, `find_matches` | Public vocabulary. Extend with another term kind without coupling it to world state. IDs include `person:bart` and `role:nightwatch`. |
| [`ui/text_formatter.gd`](../ui/text_formatter.gd): `format_text(text, context)` | Produces complete ordered spans: original text/ranges, entity ID, color, bold, opacity, surface, font/icon size, icon path and tooltip. Reusable by a future custom renderer. |
| Same file: `plain_text(spans)` | Exact original text for copying/search/fallback; generated icon spacing is excluded. |
| [`ui/rich_text_renderer.gd`](../ui/rich_text_renderer.gd): `append_to(label, spans)` | Native `RichTextLabel` rendering. Balances its own formatting stack so an outer card-link context survives. |
| Same file: `text_color`, `icon_color` | Apply overall opacity exactly once. Use the same rule in any new renderer. |
| [`ui/inline_icons.gd`](../ui/inline_icons.gd): `texture(path, surface, height)` | Original parchment texture or cached small dark-surface variant. Share an instance across cards where practical. |
| [`ui/formatted_text_label.gd`](../ui/formatted_text_label.gd) | Wrapping paper tooltips, capped to the viewport; suppresses empty tooltip panels. |
| [`ui/log_text.gd`](../ui/log_text.gd): `append_to` | Classifies existing plain log output before enrichment. Owns speech/header/card-reference structure. |
| [`ui/profile_panel.gd`](../ui/profile_panel.gd) | Reference implementation for rich card passages, native role hints, hidden opacity and disclosure gates. Shared by town and case board. |
| [`ui/theme.gd`](../ui/theme.gd): `rich_text_fonts`, `font_face`, role colors | Matching normal/bold/italic font families and shared appearance. Keep the parchment/engraving style. |

Minimal native rendering example (inside a UI script):

```gdscript
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const UITheme = preload("res://ui/theme.gd")

var formatter = Formatter.new()
var renderer = Renderer.new()

func render_passage(label: RichTextLabel, source: String) -> void:
    label.clear()
    UITheme.rich_text_fonts(label, UITheme.serif())
    renderer.append_to(label, formatter.format_text(source, {
        "surface": "paper", "font_size": 16, "icon_size": 18
    }))
```

The caller still owns size, clipping, input, card metadata and selection. Use the
custom formatted label when wrapping tooltips are needed. Native rendering is
append-only: assigning `label.text` afterward discards its native formatting.

### Contracts to preserve

- Match eligible **plain text**, never generated markup. Literal brackets must not
  become BBCode or new click actions. Parse card-reference structure separately.
- Registry vocabulary is public. Do not inspect hidden roles to choose colors or
  tooltips. Preserve existing claim/knowledge gates at the integration point.
- Ambiguous role words such as Medium and Clerk require canonical capitalization
  in ordinary prose. Use `kinds: ["person"]` for occupations/biographies,
  `role_context: true` only for known gift text, and `enabled: false` for commands/debug.
- A name is bold/colored but currently has no generic tooltip or click action.
  A role has public description text and an optional icon; missing art leaves text.
- Use `surface: "paper"` for card parchment, `"dark"` for dark panels. Entity colors
  override the surrounding speaker/base color only for their own span.
- Hidden alpha applies once, including icons. Avoid fading both spans and a parent.
- Duplicate the source image before generating variants. `get_image()` may expose
  shared image data; mutating it corrupted other variants during development.
- Native parsed text includes placeholder spacing for images. Use `plain_text()`
  for exact source reconstruction, not `get_parsed_text()`.

## Current card architecture

The board is a single custom-drawn `Control`, not a scene instance per card.
The tray is another custom-drawn control. Card List and the working set use a
one-column, wrapping `Tree`. Profiles and the speech log already use native rich text.
Switching to scenes alone will not resolve a disagreement about zoom behavior.

| Layer | Existing separation to keep |
| --- | --- |
| [`game/card_model.gd`](../game/card_model.gd) | Card meaning, time, short text, subjects and place markers |
| [`game/board_model.gd`](../game/board_model.gd): `layout`, `links` | Pure rows/columns/cells/item identities and connections; one card can appear more than once |
| [`ui/case_state.gd`](../ui/case_state.gd): `apply`, selection signals | Shared filters and selection across views; working set is separate |
| [`ui/board_view.gd`](../ui/board_view.gd) | World/screen transforms, measured geometry, drawing, manual hit tests, pan/zoom and pin movement |
| [`ui/case_view.gd`](../ui/case_view.gd): `show_card_menu`, staging/reveal methods | Existing actions, shared context menu, list/board/profile coordination |
| [`ui/deduction_tray.gd`](../ui/deduction_tray.gd) | Fixed screen-size deduction cards, folding, horizontal scroll and drag-to-pin |
| [`ui/card_list.gd`](../ui/card_list.gd) | Wrapping Tree rows, multi-selection, drag/drop and right-click card actions; one color per row today |

Keep stable card numbers as action identities, not the displayed text or a UI
node's lifetime. Preserve `{"cards": [n]}` drag payloads and the tray's additional
`"pin": n` payload. Pins are stored as world positions per board view. Retain the
meaning of solid/hollow/ability/trace place markers, hidden-card fading, support
strings and the same selection across repeated representations.

## Why zoom needs a pass first

The player reports visual messiness while zooming. These source findings are
concrete constraints, not a complete diagnosis of every reported visual issue:

1. **Geometry and text follow different rules.** Ordinary cards are 158 × 58 world
   units; their rectangles scale continuously from zoom 0.25 to 2.6. Text uses
   `int(clampf(13.5 * zoom, 12, 28))`, so it stops shrinking while the paper keeps
   shrinking. Pinned deductions have a separate size/font rule.
2. **Detail changes abruptly.** Below 0.55 cards become chips; 0.55–1.3 uses short
   text with up to two lines; at 1.3 full text allows five lines plus a heard line.
   The card/row height does not grow to fit those lines. Pinned deductions similarly
   jump from two to six lines without content measurement.
3. **Text has no per-card clip rectangle.** The board clips its outer boundary,
   not each drawn card. Long statement overflow was seen in earlier rendered QA;
   the current line allowance can exceed the available height or collide with
   provenance. Hit testing still uses the paper rectangle, so overflow is not a
   reliable interactive region. Rich icons/bold words would add width pressure.
4. **Zoom also changes row geometry.** `_measure()` enforces a 30px screen minimum
   by dividing by zoom. Sparse rows therefore change world height during zoom.
   `zoom_at()` preserves the numerical world point under the cursor, which need
   not preserve the same card when preceding rows change height. This is a
   plausible source of apparent movement; reproduce it before choosing a fix.
5. **Fit and layout depend on one another.** Fit methods recalculate zoom/row
   measurements; `fit_all()` makes two passes and `fit_selection()` collects
   positions before remeasuring. Check sparse/dense rows and resizing when deciding
   the desired anchoring behavior. These are investigation targets, not confirmed
   failures in every fit operation.
6. **There is no span-aware board layout yet.** Drawing and `_items` hit rectangles
   are rebuilt during `_draw()`. Board tooltips are whole-card text. Future term
   hints need layout-derived term regions and an explicit priority over card hints,
   while keeping right-click, double-click, pan and drag working.
7. **Rendering cost needs measurement.** Visible card text is drawn on redraw;
   there is no shared persistent shaped-span layout cache. Name dictionaries are
   rebuilt per drawn statement card. Adding labels or term hit tests to every
   item without culling/caching could make pan/zoom more expensive. No performance
   regression from a proposed replacement has been measured yet.

Do not add inline icons to the current five-line drawing call and treat that as
phase 4 complete. First specify the card's text budget, clipping/overflow rule,
zoom behavior and input geometry together.

## Approaches and tradeoffs

| Approach | What it eases | Cost / limitation |
| --- | --- | --- |
| Keep custom drawing, fix measurement and detail levels | Smallest migration; retains grid, strings, marker behavior and current input routing | Custom wrapping, bold/icon placement and term hit regions remain our responsibility |
| Reusable card scene/control with a native rich label | Native text wrapping, rich formatting and tooltips; card layout can be edited visually in a scene | Parent scaling alone retains zoom problems; many live controls need culling/reuse; nested input must forward card actions |
| Hybrid: custom grid/markers, native detailed cards | Reuses the existing models and native formatter while retaining inexpensive overview rendering | Must coordinate two representations, stacking order, string anchors, focus and input at detail transitions |
| Compact board cards plus a fixed-size detail view | Most predictable reading size; less overflow pressure on a dense timeline | Full text is not simultaneously readable on every board card; changes the interaction design |

**Suggested direction to prototype, not an agreed replacement:** keep the data,
filters, pins, grid and connections. Use compact markers/chips at a distance and
one reusable native card control for detailed cards, initially only for visible
items. Start with one representative statement card and a pinned deduction.

Choose whether zoom physically scales paper and text together or changes the
amount of detail while keeping text within a readable screen-size range. Both are
valid, but mixing them without a measured text budget causes the current tension.
For a smaller first fix, retain custom drawing and give each detail level a clear
line budget, clipping and stable anchoring; that can be assessed before migrating
any cards to controls. Preserve the existing parchment art in either approach.

Avoid rendering whole cards to textures as the default solution: that can simplify
batch drawing, but text can blur when scaled and role hover regions still need
separate geometry. It does not solve the core sizing policy.

## Resume checklist

1. Reconcile the branch with current main and review changes to the files above.
   Keep this work isolated from dialogue/mechanics changes.
2. Capture the reported zoom issues with long/short statements, multiple cards per
   cell, sparse rows, pinned deductions and provenance. Test 1280×720 and 1920×1080,
   fit day/all/selection, and wheel steps around 0.55 and 1.3 in both directions.
3. Agree on physical versus detail-based zoom, readable font sizes, overflow policy
   (clip/ellipsis/expand/detail view), and which card/row stays anchored.
4. Prototype the smallest renderer change. Derive drawing, clipping, string anchors
   and card/term hit areas from the same measured geometry. Keep row changes from
   causing avoidable jumps; avoid reflow on every wheel step if fixed detail levels
   can provide stable geometry.
5. Once that is satisfactory, resume **step 4**: board statement/process cards,
   pinned deductions and tray through shared formatter spans. Native cards can use
   the existing adapter; custom cards need a new measured span renderer. This
   custom layout renderer has **not** been built.
6. Resume **step 5** separately: Card List and working-set rows, then other eligible
   surfaces. Tree rows do not accept the native rich label adapter directly;
   choose custom cells or replacement rows, preserving multi-select and drag/drop.
7. Verify role hints never swallow card actions; wheel over a label still zooms the
   board; empty-space pan, pin movement and drop coordinates remain correct.
   Retest filters, hidden opacity, support strings, selection and full-screen overlays.
8. Cache measured layouts by content/style/font/width/detail level and invalidate
   them deliberately. Reuse icon caches; do not generate a new image or node tree
   per card per frame. Benchmark a populated multi-day board before broad rollout.

## Verification already completed

The last icon adjustment passed 29 formatter/adapter checks and 17 live text-UI
checks, plus editor import and rendered log/profile inspection on Godot 4.4.1.
The preceding integration also passed 27 registry, 110 existing UI and 25 town-UI
checks, with 1920×1080 and 1280×720 rendered inspection. Text UI checks cover native
role hints within clickable card passages, left/right mouse actions, disclosure,
literal text, times/provenance and unchanged evidence/RNG state.

Existing `test_ui.gd` synthetic drag-preview and shutdown resource diagnostics were
already present; do not attribute them to a new card renderer without comparison.
No runtime tests were rerun for this documentation-only handoff.

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tools/test_text_terms.gd
godot --headless --path . --script res://tools/test_text_formatter.gd
godot --headless --path . --script res://tools/test_text_ui.gd
godot --headless --path . --script res://tools/test_ui.gd
godot --headless --path . --script res://tools/test_town_ui.gd
```

Headless checks do not establish that zoom looks good. Retain a rendered/manual
pass for clipping, transitions, readability, cursor anchoring and tooltip placement.

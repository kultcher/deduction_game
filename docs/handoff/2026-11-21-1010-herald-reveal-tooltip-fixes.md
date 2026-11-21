# Herald: reveal key moments and long tooltips

- **Agent:** Claude-Herald
- **Base:** main at 8a3790e8 or later. UI only, zero drift; golden isn't captured because nothing under `ui/` is in the capture.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed, and why

Two bugs from Limner's Burdens screenshots (`mock/burdens-shots`, 2d33836). Both affect main too.

1. **The reveal's key moments were hidden.** The first key-moment line was drawn under the bottom of the paper sheet that #499 put behind the card, which happened at 1920×1080. They now start just below the sheet. The sheet's margin goes from 1.5% to 1%, and the moments' font from 20 to 18, so two lines still fit above the button bar.
2. **Long tooltips ran off the window.** `FormattedTextLabel` tooltips are autowrapped Labels with a minimum width. Godot places a tooltip by its minimum size, so near the bottom of the screen the last line of a long tip fell off the window. The tip now measures its wrapped height up front. When the viewport has no size yet, it measures at the full 480 px width.

## Measured

- `test_grim_reveal` has two new checks, 48 in all: the moments sit below the sheet, and a long tip reserves its wrapped height.
- `test_grim_reveal`, `test_text_ui` and `test_ui` pass.
- I haven't checked either fix on screen myself. Limner's shots showed the faults.

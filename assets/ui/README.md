# UI art

Optional. Any of these PNGs, if present, replace the flat default look (see `ui/theme.gd`):

| File | Used for |
|---|---|
| `panel.png` | large panels (case view background, side panels) |
| `popup.png` | popup menus and pickers |
| `frame.png` | framed boxes (profile, notes, board cards) |
| `button.png`, `button_hover.png`, `button_pressed.png` | buttons, option and menu buttons |
| `field.png` | text fields |

All are drawn as nine-slice: corners stay fixed, edges and centre stretch, so a frame
works at any size. Slice margins default to 12 px on each side; override per file in
`slices.json`, e.g. `{"panel": [24, 24, 24, 24], "button": [8, 6, 8, 6]}`.

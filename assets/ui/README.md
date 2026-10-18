# Art

The original sheets live in `assets/ui/source/` and `assets/art/source/` (ignored by Godot's
importer). `tools/slice_sheets.py` cuts each sheet into one PNG per piece:

    python3 tools/slice_sheets.py --preview

| Folder | Pieces |
|---|---|
| `assets/ui/` | plaques, tabs, rings, corners, divider, curtains, candle, raven, books, sun, moon, wax seal, arrows, six frames |
| `assets/ui/cards/` | `card_01`–`card_16`: paper cards for the case board |
| `assets/ui/roles/` | one icon per gift, plus `demon`, `poisoner`, `unknown`, `none` |
| `assets/art/portraits/`, `assets/art/standees/` | one per character id (agnes … jory) |
| `assets/art/buildings/`, `blocks/`, `decor/`, `terrain/` | map pieces (not used yet) |

`assets/slices.json` records each piece's size and where it came from;
`assets/ui/source/slices_preview.png` shows every piece with its name.

To change art: edit or replace a sheet, keep the pieces in the same reading order (rows top
to bottom, left to right), and re-run the script. If a sheet gains or loses pieces, update
its name list in the script (it stops with an error if the count doesn't match). Pieces need
a transparent background with clear gaps between them.

How the art is used is all in `ui/theme.gd` (palette, plaques as buttons, frames as panels,
nine-slice margins). Missing art falls back to flat colour.

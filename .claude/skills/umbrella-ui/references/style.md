# Style and saved state

## Look

Two skins, chosen by the theme:

- **Brand** (every theme except `umbrella`; default for big windows): the Draft Helper look. Dark, sharp, technical. Cut corners on the big boxes, 2.5 px corners on everything else, an accent hairline, upper-case letter-spaced titles, Bahnschrift. See "The brand skin".
- **Flat** (`umbrella` theme, always for `K.SMALL`): a copy of Umbrella's own panels. See "The Umbrella panel skin".

Colour is used for state and the accent, not decoration.

Do:
- Accent only for the current choice: selected tab thumb, switch on, selected row bar, section bar and rule, primary button, focused field outline, header underline.
- Grey (`T.t3`/`T.t4`) for secondary text and disabled things; game icons go grey (`gray = 1`) when off.
- Green/red/yellow (`T.green`, `T.red`, `T.yellow`) only for good/bad/warning values.
- Animate state changes (hover 0.12 s, toggles 0.16-0.25 s, folds 0.22 s, segment thumb 0.3 s).

Do not: outlines around every element, glows, pulsing, extra gradients, emoji, lettered badges, drop shadows under text, more than one accent, decorative separators, icons drawn from primitives when a game icon or a FontAwesome glyph exists, rounded 8-14 px corners in the brand skin.

## The brand skin

| Part | Brand |
| --- | --- |
| Boxes | header (`C.bar`, top-right corner cut 16) and body (`C.win`, bottom-left corner cut 16), 4 px apart, no shadow. Accent hairline (`A` at 0.33) around both; accent corner ticks 28 px, 2 px thick, at the top-left and bottom-right of the window |
| Header | 52 px (42 in compact). Accent underline: 2 px gradient from `A` to transparent along the bottom, 240 px. Left: logo (`view.logo`, 56% of the header height), 12 px, title in upper case, 700 15 px, tracking 2.5, `T.t1`. Then an accent slash (`/`, 1.5 px) and the subtitle, upper case, 600 11 px, tracking 1.4, `AT`. Right: close, fold, extra buttons, 28 px squares 34 apart, then the optional status pill (`o.pill`) |
| Header buttons | 28 px square, 2.5 corners, faint white fill and 8% outline. Hover: accent tint (red for close) and accent corner brackets, glyph turns accent |
| Cards | `C.card`, top-left and bottom-right corners cut 8, a 26x2 accent tab right after the top-left cut, no outline |
| Popups | `view.box`: `C.menu`, cut corners like cards, 9% white outline, soft shadow (dropdown list, right-click menu, action bar, loader) |
| Sections | 3x12 accent bar, upper-case 700 11 px tracking 1.6 in `T.t2`, then a 1 px accent rule fading out to the right edge |
| Buttons | 3 px corners. `"accent"`: solid `A`, text `AON`. `"soft"`: accent tint with an accent outline, text `AT`. Ghost: faint white fill and outline. Hover adds corner brackets 3 px outside the button |
| Switch | square: 40x22 (mini 28x16), off `C.off`, on `A`, a square knob (radius 2) in `T.t2` off, `C.win` on |
| Slider | 4 px track in `C.off`, accent fill, a 10x18 upright knob (20 when held) |
| Segment (`view.tabs`) | 32 px, faint fill, solid accent thumb inset 2 px sliding 0.3 s, label on it in `AON`, thin separators between the other cells. `view.choice` is the right-aligned compact version for setting rows |
| Rows | selected: accent tint at 0.12 and a 2 px accent bar at the left edge |
| Scrollbar | 4 px thumb, widens to 6 with an 8 px track on hover |
| Font | Bahnschrift (Cyrillic included), weights collapse to 400/700; Inter when Bahnschrift is missing |
| Resize | grip of two diagonal strokes in the bottom-right corner; dragging it scales the window 70-150% in 5% steps, saved on release |

`AON` is the text colour for anything drawn on a solid accent: `C.win` for light accents (brand lavender), white for dark ones.

## Themes and accents (big windows)

The default for big windows is `brand` (theme and accent). `umbrella` is the palette of the Umbrella menu itself and switches to the flat skin, so the window sits next to the cheat's own panels (Illusion Controller and the like) as one family; small windows always use it. `apply_theme()` reads it live from `Menu.Style(name)` and follows the user's Umbrella colours. The numbers below are the stock values, used as the fallback.

| `umbrella` slot | `Menu.Style` key | Stock |
| --- | --- | --- |
| `C.win` | `main_background` | 16 17 21 |
| `C.card` | `group_background` | 19 21 25 |
| `C.menu` (buttons, fields) | `button_background` | 23 26 28 |
| `C.off` | `slider_background` | 36 38 46 |
| `C.line` (outline, 1 px) | `outline` | 51 51 51 |
| `T.knob` (switch off knob) | `disabled_switch_circle` | 102 102 102 |
| `T.t1` / `T.t2` / `T.t3` / `T.t4` | `active_widgets_text` / `primary_first_tab_text` / `primary_widgets_text` / `section_group_text` | 245 / 207 209 222 / 176 / 115 117 130 |
| `A` (accent `umbrella`) | `primary` | 207 54 54 |

Never hardcode these numbers in a script and never tint the header with the accent in this theme: read them through the kit.

### The Umbrella panel skin

The `umbrella` theme also switches the kit to the flat skin (`U.flat`), measured pixel by pixel from Umbrella's own panels (Illusion Controller, its collapsed tab):

| Part | Umbrella |
| --- | --- |
| Boxes | header and body are two separate boxes, 4 px apart, each `C.win` with a 1 px `C.line` outline, radius 5, no shadow, no tint |
| Header | 22 px with the outline (`K.HEAD = 22`), a 12 px logo in `T.t2`, 5 px, then the title regular 13 px in `T.t2` (207 209 222); logo and title are centered on the window as one group |
| Font | `MuseoSansEx`, the Umbrella menu font (Cyrillic included). The kit loads it by itself under the `umbrella` theme; Bahnschrift in the brand skin. Inter was the first thing that made the old window look foreign |
| Header | one chevron. Away from the screen walls it is on the right and folds the body up: open = red `<` (accent at 0.8), folded = grey `v` (`T.knob`, 102), like folded Net Worth and Wards. Flush to a left or right wall it sits on the side away from that wall, red, pointing at it (`>` on the left for the right wall, like Illusion Controller), and docks into the wall. Then the enable switch (`o.switch`, mini) and action glyphs, 16 px slots, grey 102 (`T.knob`). Nothing else: no close, fold or extra right-side buttons |
| Body | either an outlined box (Illusion Controller) or, with `o.bare`, no box: rows and slots bring their own backgrounds (Wards, Item panel) |
| Icons | square, radius 2, no accent frame: on = full colour, off = grey and dimmed |
| Switch | pill 18x11 (mini) or 26x14, on = accent at 0.8 alpha (169 47 47 over the window) with a hole-shaped knob in `C.win`, off = `C.off` with a `T.knob` dot |
| Rows | 28 px apart: icon 20 px (radius 2; heroes as portraits `asset.portrait`, like Net Worth; opaque portraits look bigger than Umbrella's transparent unit art, so never above 20) at the left edge, label regular 13 px in `T.t3` (176) 8 px after it, the control (switch, slider + value, number) right-aligned to the padding |
| Slider | 5 px track in `C.off`, accent fill, white knob 11 px |
| Buttons | flat `C.menu` boxes, 22 px high, radius 4, text 13 px `T.t3` centered. Hover fills the whole box with the accent (207 54 54) and turns the text white, with a faint 2 px accent glow around it; the kit animates it (0.12 s). Full width, or two halves 8 px apart (Radiant / DIRE). A mode is a full-width button that cycles its values on click (Adaptive) |
| Spacing | 10 px from the body outline to the first and last element. Between a button and an icon row keep a clear 10 px from the button edge to the icon edge (row centre 20 px from the button), otherwise the boxes crowd the icons |
| Docked tab | 22 px high, 26 px wide plus content (`tab_w = 22` for the mini switch), `C.win` with the `C.line` outline, chevron 11 px in `T.knob` 10 px from the outer edge, then the mini switch. Flush to the wall |

Do not add rounded 10-14 px corners, shadows, header tints, bold titles, icon-button squares, a close button, buttons on the right of the header or accent frames on icons in this theme, nor grey caption lines over the content, status lines with an info glyph, bare icon grids without labels or the Inter font: each of them is what made the window look "almost but not quite" Umbrella. Other keys exist (`slider_grab`, `indication_active` 76 204 51, `healthbar_ally`, `manabar` and more); call `Menu.Style()` without an argument for the full table.

| Theme | win | card | menu | off |
| --- | --- | --- | --- | --- |
| brand (default, header `bar` 41 41 48) | 35 35 41 | 46 46 54 | 60 60 70 | 74 74 86 |
| umbrella (flat skin) | 16 17 21 | 19 21 25 | 23 26 28 | 36 38 46 |
| graphite | 25 25 27 | 34 34 37 | 42 42 46 | 58 58 63 |
| midnight | 17 20 31 | 25 30 45 | 34 40 58 | 52 60 84 |
| purple | 22 17 32 | 32 25 47 | 46 36 67 | 62 49 88 |
| forest | 17 25 21 | 24 35 29 | 37 52 44 | 52 70 60 |
| oled | 0 0 0 | 15 15 17 | 28 28 31 | 44 44 48 |

Accents: brand (default, 184 167 240 lavender), umbrella (`Menu.Style("primary")`, stock 207 54 54), blue 76 130 247, teal 38 166 154, green 52 168 83, purple 138 99 210, orange 240 140 40, pink 232 90 150. `AT` is the accent lightened by 35% for text on dark backgrounds, `AON` the text on a solid accent. Themes without a `bar` colour get one halfway between `win` and `card`.

The user picks theme and accent with swatches (`view.theme_settings`), plus Size (70-150%, `P.set.scale`, also by the resize grip), Opacity (40-100%) and Compact (pass `labels.compact`). Changes apply at once and are saved.

### Compact mode

`P.set.compact` (saved as `compact`) animates `g.cmp` from 0 to 1. `g.lay(normal, compact)` returns the size in between: the kit uses it for the brand header (52 to 42) and toggle rows (36 to 30, 44 to 38). Use it for your own row heights and gaps, for example `y = y + g.lay(22, 14)`.

## Small scripts: the Umbrella palette, fixed

Scripts that do not need a big window (a pill bar, a few icons, a compact panel with a handful of toggles and sliders) use `K.SMALL = true`. It locks the `umbrella` theme and accent: the colours of the Umbrella menu, with no picker.

Small means minimal, never bulky:
- No look settings in the window at all: no theme/accent pickers, no opacity slider, no Style tab, no gear page. Look settings belong only to big, complex windows. If size really matters, one Size slider in the Umbrella menu (script gear).
- Compact header (`K.HEAD = 22`): title only, no glyph tile, no subtitle. The kit draws it as the Umbrella header box (see above). Rows go straight into the body, no section headers or nested cards, no tabs.
- Compact size: `K.W` 240-280, `K.PAD = 10`, hero/item icons 28-30 px. A list label is `view.caption` (dim 11.5 px text, count right-aligned), not a section header.
- Proportions: text never touches icons. The caption takes 22 px, so 8 px stay clear between its text and the icons under it. Leave 12 px between a grid and the next row. Text in a small window is 11.5-13 px; icons are at most 2.5 times the text height.
- At most two header glyphs plus the switch, all on the left. Check the longest translation of the title: it must stay readable between the left glyphs and the chevron (the kit cuts it with an ellipsis, it never overlaps).
- The fewer elements, the better: a pill or a single panel, no header if the panel has nothing to drag or close.
- Keep `K.DOCK = true` so the window can slide into the left or right screen wall (see `components.md`, "Side docking").

## Typography and spacing

| Use | Weight | Size | Brand form |
| --- | --- | --- | --- |
| Window title | 700 | 15 | upper case, tracking 2.5 (`g.track_fit`) |
| Window subtitle | 600 | 11 | upper case, tracking 1.4, `AT` |
| Section title | 700 | 11 | upper case, tracking 1.6, `T.t2` |
| Row title, labels | 600 | 12.5-13 | |
| Body, values | 500 | 12-12.5 | |
| Secondary, status | 400-500 | 11-11.5 | |
| Badge, keycap | 600-700 | 10-10.5 | |

Upper-case text always goes through `g.up` (it handles Cyrillic; `string.upper` does not). Tracked text that may not fit goes through `g.track_fit`, which falls back to plain text with an ellipsis.

Header 52, padding 12, card inner padding 10, gap between blocks 10, rows 36-44, icons 32-36 with gap 6-8, buttons 28-30 high, fields 32 high. All in window units; the scale multiplies them.

## Saving state

Read at load: `Config.ReadInt/ReadString(K.CFG, key, default)` (the kit reads theme, accent, scale, opacity, collapsed; the window reads `wx`, `wy` on first draw). Reading is safe.

Write only through `save(key, value)` and only:
- when a drag ends (`input.end_drag` saves `wx`, `wy`),
- when a slider is released (`on_done`),
- when the user changes a setting (tab, theme, accent, a toggle you want to keep).

Never write on load, per frame or from a timer. `Config.Write*` triggers an Umbrella save; a write at load caused an endless reload loop in Cloud Radar. `save()` skips values that did not change.

Validate what you read: `valid(list, value, default)` for names, `clamp` for numbers, and reset the window position if it is off screen (`view.home` does).

### How to test saving (same as Ability Draft Helper)

1. Drag the window, change theme, accent, size, fold it, switch a tab.
2. Reload scripts. Everything must come back as it was.
3. Look at the log: after your reload there must be exactly one `Reload ScriptSystem`; no repeating reloads.
4. Set the position far off screen in the config or change the resolution: the window must come back to the default place.
5. A "Reset position" button in the menu writes `wx`/`wy` = -1 and clears `P.wx` so the next frame calls `view.home()`.

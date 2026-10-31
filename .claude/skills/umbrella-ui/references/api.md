# Kit API

Everything here is defined in `kit.lua`. Coordinates are window units (multiplied by `g.s`, the scale), `cy` means vertical center, colours are `{ r, g, b }` tables (optional 4th value is alpha), alpha arguments are 0..1 multipliers.

## Configuration: `K`

| Field | Meaning |
| --- | --- |
| `NAME` | Name in log lines, `[NAME] ...`. |
| `CFG` | Config name for `Config.Read*/Write*`. Unique per script. |
| `W`, `HEAD`, `PAD` | Window width, header height, inner padding. |
| `EVERYWHERE` | `true`: draw in main menu and match (`OnFrame`/`OnUpdateEx`); `false`: match only (`OnDraw`/`OnUpdate`). |
| `SMALL` | `true`: the `umbrella` theme and accent are locked, theme/accent pickers hidden. Minimal window, no look settings. |
| `DOCK`, `SNAP` | Small windows only: side docking into the left/right screen wall (default `true`) and the snap distance in pixels (24). |
| `THEME`, `ACCENT` | Defaults when nothing is saved: `"brand"` (the Draft Helper look). `"umbrella"` is the live Umbrella menu palette with the flat skin; `K.SMALL` forces it. |
| `SINK_ID` | Name of the hidden Panorama TextEntry. Unique per script. |
| `SINK_ALIVE`, `SINK_TIMEOUT` | Text input keep-alive interval (s) and JS watchdog timeout (ms). |
| `TIP_DELAY`, `TOAST_TIME`, `WHEEL`, `DOUBLE` | Hint delay, toast life, wheel step, double-click window. |
| `G` | FontAwesome glyphs the kit uses. |
| `DEBUG` | Set by the script: `function() return ui.debug:Get() end`. Enables `say()`. |
| `ON_CLOSE` | Set by the script: called by the close button, usually `ui.show:Set(false)`. |

## State: `P`

`P.open` (window wanted), `P.alpha` (current fade), `P.wx/P.wy` (position in pixels), `P.h` (current height), `P.dt`, `P.now`, `P.set` (theme, accent, scale, opacity, collapsed, docked, compact), `P.menu` (open dropdown id), `P.ctx` (open right-click menu), `P.resize` (grip drag), `P.focus` (focused input field table), `P.toasts`. Script state goes in its own table, not in `P`.

## Theme

- `C.win`, `C.bar`, `C.card`, `C.menu`, `C.off`: theme colours (window body, brand header bar, card, popup/field, switch off). The `umbrella` theme adds `C.line` (outline) and sets `T.t1..t4` and `T.knob`, all read from `Menu.Style`, and turns on the flat skin: `U.flat = true`. Every other theme is the brand skin (`U.flat = false`).
- `A`: accent, `AT`: lighter accent for text on dark, `AON`: text on a solid accent fill.
- `T.t1..t4`: text from brightest to dimmest; `T.white`, `T.black`, `T.knob`, `T.green`, `T.red`, `T.yellow`.
- `apply_theme()`: recompute `C`, `A`, `AT` (and `T.t1..t4`) after changing `P.set.theme` or `P.set.accent`; for `umbrella` it rereads `Menu.Style`. `style_rgb(name, fallback)` reads any other `Menu.Style` key as `{ r, g, b }`.
- `THEME_ORDER`, `THEMES`, `ACCENT_ORDER`, `ACCENTS`: the lists for pickers.

## Skins: `U`

`U.flat = false` is the brand skin: `g.r` caps every radius at 2.5, `view.window` draws `view.brand_head` (cut header bar, underline, logo, tracked title, slash + subtitle, status pill, square buttons) and `view.brand_shell` (accent hairline, corner ticks), plus the resize grip. The widgets switch to their brand forms (see `style.md`, "The brand skin").

`U.flat` is true while the `umbrella` theme is on. Widgets then copy the Umbrella menu: `g.r(r, w, h)` caps corner radii at 5 (pills and circles keep theirs), `g.shadow` draws nothing, `view.window` draws separate header and body boxes, `view.icon_button` is a bare glyph (grey 102, hover lighter, active in accent at 0.8), `view.flat_head` lays the header out like Umbrella (switch and buttons left, title centered, one red chevron right that folds or docks, no close button), `view.grid` drops the accent frame, `view.button` is a flat 4-radius box in `C.menu`, `view.toggle_row` is 28 high with regular text, `view.slider` has a 5 px track and a 5.5 knob.

## Helpers

- `clamp(v, a, b)`, `ease_out(t)`, `ease_in_out(t)`, `valid(list, v, default)`.
- `save(key, value)`: writes to `Config` only if the value changed. Booleans become 1/0.
- `say(text)`: `Log.Write("[NAME] text")` when `K.DEBUG()` is true.

## Assets

- `asset.font(weight)`: the skin's font at weight 400-700 (`asset.family()`: `MuseoSansEx` flat, `Bahnschrift` brand with 400/700 only, `Inter` when Bahnschrift is missing).
- `asset.icons()`: FontAwesomeEx.
- `asset.size(font, px, str) -> Vec2`: cached `Render.TextSize`.
- `asset.image(path) -> handle|nil`: cached `Render.LoadImage`, at most 3 new loads per frame; `nil` while waiting or missing.
- `asset.hero(npc_name)` (small minimap icon), `asset.portrait(npc_name)` (hero portrait, cropped to a square by `g.square`; use it for rows), `asset.item(item_name)`, `asset.ability(ability_name)`: game image paths.

## Drawing: `g`

| Function | Notes |
| --- | --- |
| `g.origin(x, y)` | Set the pixel origin; the window does it for you. |
| `g.s`, `g.a` | Scale and global alpha multiplier (fades). |
| `g.rect(x, y, w, h, c, r, a, flags)` | Filled rounded rect. |
| `g.frame(x, y, w, h, c, r, a, t, flags)` | Outline; `flags` defaults to all corners rounded. |
| `g.hl(x, y, w, c, a)` / `g.vl(x, y, h, c, a)` | 1 px horizontal / vertical line. |
| `g.dot(cx, cy, r, c, a)` / `g.ring(cx, cy, r, c, a, t)` | Circle / ring. |
| `g.arc(cx, cy, r, c, a, t, start, pct)` | Part of a ring: `start` in degrees (0 = right, 90 = bottom), `pct` 0..1. |
| `g.line(x1, y1, x2, y2, c, a, t)` | Line. |
| `g.grad(x, y, w, h, c1, a1, c2, a2, vertical)` | Gradient fill, left to right (or top to bottom). |
| `g.cut(x, y, w, h, c, a, k, tl, tr, br, bl)` | Brand panel: filled rect with 45-degree cut corners of size `k` on the chosen corners. |
| `g.cut_frame(x, y, w, h, c, a, t, k, tl, tr, br, bl)` | Its outline. |
| `g.brackets(x, y, w, h, len, c, a, t)` | Corner brackets (brand hover and focus). |
| `g.up(str)` | Upper case for Latin and Cyrillic, cached. |
| `g.track(weight, size, str, x, cy, c, a, space, align) -> width` / `g.track_w(...)` | Letter-spaced text / its width. |
| `g.track_fit(weight, size, str, x, cy, c, a, space, max_w, align) -> width` | Upper case + tracking; plain text with an ellipsis when it does not fit. |
| `g.lay(normal, compact)` | Size for the current compact state (animated). |
| `g.text(weight, size, str, x, cy, c, a, align) -> width` | `align` nil (left), `"c"`, `"r"`. |
| `g.width(weight, size, str) -> width` | In window units. |
| `g.glyph(glyph, size, cx, cy, c, a)` | Centered FontAwesome glyph. |
| `g.fit(weight, size, str, max_w) -> str` | Ellipsis to fit, cached. |
| `g.wrap(weight, size, str, max_w) -> lines` | Word wrap, cached. |
| `g.chars(str) -> table` | UTF-8 characters. |
| `g.clip(x, y, w, h)` / `g.unclip()` | Nested clip; also clips hit areas. |
| `g.shadow(x, y, w, h, r, a)` | Soft stacked shadow (brand popups only; nothing under the flat skin). |
| `g.square(img, label, x, y, size, a, r, gray)` | Square icon (crops non-square art); lettered tile when `img` is nil; `gray` 0..1. |
| `g.reset()` | Pop all clips; called after every layer. |

## Hit testing and animation

- `hit.add(x, y, w, h, id, on)`: register a clickable rect. `on` may hold `click(mx, my)`, `down(mx, my)`, `dbl()`, `rclick(mx, my)`, `wheel(dir)`. Later rects are on top.
- `hit.is(id) -> bool`: hovered this frame.
- `hit.at(mx, my, field) -> entry|nil`: topmost rect, optionally only those with `on[field]`.
- `anim.tween(key, target, time, curve) -> value`: fixed-time tween, resets when unused for 0.1 s.
- `anim.hover(id, on) -> 0..1`: hover fade.
- `anim.snap(key, value)`, `anim.mix(c1, c2, k) -> colour`.

## Widgets: `view`

| Function | Returns | Notes |
| --- | --- | --- |
| `view.window(o)` | | `o.title`, `o.sub` (brand: after the accent slash), `o.pill` (brand: header status pill, same table as `view.status_pill`), `o.body_h`, `o.body(y)`, `o.buttons = {{glyph, id, active, click}}`, `o.switch = {on, click, id}` (flat skin: header enable switch, after the chevron), `o.bare` (flat skin: no body box), `o.tab_w` and `o.tab(x, cy)` (extra content of the 22 px docked tab, use `tab_w = 22` with a mini switch). Draws blur, header with the logo and drag (double-click folds), fold and close buttons (plus the dock chevron when a small window touches a screen wall); the title is fitted left of the leftmost button or pill, clips and fades the body, the brand outline and resize grip, then the open dropdown and right-click menu. |
| `view.logo(x, cy, h, c, a)` | width | The logo, `h` units tall, left edge at `x`, tinted `c`. The window draws it; use it yourself only in overlays and the loader. |
| `view.edge()` / `view.side()` / `view.dock(on)` | -1, 1, nil | Which screen wall a small window touches; the nearest wall; dock (`true`, moves to the nearest wall first), undock (`false`) or toggle (`nil`), saved as `docked`. |
| `view.fold()` / `view.close()` / `view.home()` | | Toggle fold (saved), close (calls `K.ON_CLOSE`), reset position from config. |
| `view.icon_button(x, y, size, glyph, id, active, click, danger)` | | Square button with glyph. |
| `view.button(x, y, w, h, label, kind, id, click)` | | `kind`: `"accent"`, `"soft"`, anything else = ghost. |
| `view.badge(right, cy, text, c)` | width | Count pill, right-aligned. |
| `view.card(x, y, w, h)` | | Card in `C.card` (brand: cut corners + accent tab). |
| `view.box(x, y, w, h, c, a)` | | Popup/panel box: brand cut corners + faint outline, flat Umbrella box. |
| `view.section(x, y, w, title, count)` | 22 | Accent bar, title (brand: tracked caps + fading accent rule), optional count badge. |
| `view.caption(x, y, w, text, count)` | 22 | Dim caption with an optional right-aligned count; content goes at `y + 22`, 8 px below its text. Use it in small windows instead of `view.section`. |
| `view.switch(x, cy, on, id, click, mini)` | | Brand: square 40x22, `mini` 28x16. Flat skin: Umbrella switch, 26x14, `mini` 18x11, on = accent pill with a hole knob, off = grey knob. |
| `view.toggle_row(x, y, w, label, on, id, click, sub)` | height | Label (+ subtitle) with a switch; whole row clickable. |
| `view.slider(x, cy, w, id, value, min, max, step, on_change, on_done, fmt)` | | `on_change(v)` while dragging, `on_done(v)` on release (save there). |
| `view.dropdown(x, y, w, id, options, cur, pick)` | | `options = {{value, label}}`; list drawn above everything; `pick(value)`. |
| `view.tabs(x, y, w, labels, cur, pick, id)` | 32 | Segmented control with sliding thumb; `cur` and `pick(i)` are 1-based. Brand: solid accent thumb, separators. |
| `view.choice(right, cy, id, options, cur, pick)` | width | Compact right-aligned segment for a setting row; `options = {{value, label}}`, `pick(value)`. |
| `view.row(x, y, w, h, o)` | h | `o.id, o.click, o.rclick, o.img, o.img_label, o.gray, o.glyph, o.glyph_c, o.title, o.sub, o.value, o.value_c, o.selected`. |
| `view.grid(x, y, w, items, size, gap, id, click)` | height | `items = {{key, img, label, on, dot}}`; selected = colour + accent outline, off = grey; hint shows `label`; `click(item, i)`. |
| `view.status(x, cy, w, glyph, text, c)` | | One-line status with a glyph. |
| `view.empty(x, y, w, h, glyph, text)` | | Centered empty state. |
| `view.swatches(right, cy, order, cur, color, pick, prefix)` | | Colour dots picker. |
| `view.theme_settings(x, y, w, labels)` | height | Theme and accent swatches (hidden when `K.SMALL`), size and opacity sliders, and a Compact switch when `labels.compact` is given; `labels = {theme, accent, scale, opacity, compact}`. Height: 64 for the swatches (0 when small) + 64, or + 96 with compact. |
| `view.scroll_begin(id, x, y, w, h)` | content origin y | Starts a clipped, wheel-scrollable area. |
| `view.scroll_end(id, content_h)` | | Ends it, draws the thumb (draggable). |
| `view.input(x, y, w, id, f, placeholder, glyph)` | 32 | Single-line text field. `f` is a table you own: `text`, `max`, `on_change(text)`, `on_enter(text)`. |
| `view.hint(id, text)` | | Hover hint for the rect `id`, shown after `K.TIP_DELAY`. |
| `view.toast(text, kind)` | | `kind`: `"info"`, `"ok"`, `"warn"`, `"error"`. Bottom-right, 4 s, click to dismiss. |
| `view.pill(x, cy, o)` | width | On-screen pill: `o.img` or `o.glyph`, `o.text`, `o.detail`, `o.c`, `o.gray`, `o.id`, `o.click`. Set `g.origin` first. |
| `view.spinner(cx, cy, r, c, a)` | | Small spinning arc on a dim ring. |
| `view.orbit(cx, cy, r, a)` | | The logo in a disc with an orbiting accent arc and two expanding rings. |
| `view.loader(x, y, w, title, text)` | 224 | Loading card: orbit, tracked title, text, indeterminate bar. Draw it instead of the body while data loads. |
| `view.status_pill(right, cy, o)` | left x | Grows from `right`; `o = {id, kind, label, glyph, click, hint}`, `kind` `"accent"`, `"loading"` (spinner), `"ok"`, `"error"` or nil (shrinks away). Cross-fades colour on change. |
| `view.ctx_open(mx, my, o)` | | Opens a right-click menu at the cursor (pixels, from `rclick(mx, my)`); `o = {title, w, items}`, item = `{label, glyph or img, hint, check, danger, disabled, click}`, `{sep = true}` or `{section = text}`. Closes on a pick, a click elsewhere or Esc. The window draws it (`view.draw_ctx`). |
| `view.action_bar(x, y, w, o)` | visible height | Slide-in bar for a pending choice: `o = {id, on, img or glyph, title, sub, buttons = {{label, key, kind, id, click}}}`; `key` draws a keycap, `kind` `"accent"`/`"danger"`/ghost. |
| `view.key(x, cy, text, a)` | width | Keycap hint (`"Enter"`, `"Esc"`). |
| `view.grip(W, h)` | | Resize grip; the brand window draws it. |

## Text editing: `edit`

`edit.focus(f, id)`, `edit.blur()`, `edit.insert(f, str)`, `edit.key(key)`, `edit.poll()`, `edit.sink(on, force)`. Normally you only call `edit.blur()` (on disable or close); `view.input` and `input.*` do the rest. Details in `input.md`.

## Driver: `input`

| Function | Where to call |
| --- | --- |
| `input.frame(draw)` | In the draw callback. Computes `dt`, fades, drag/slide/scroll, polls text input, runs `draw` in `pcall`, then toasts and hints. |
| `input.event(e)` | Return its result from `OnKeyEvent`. |
| `input.end_drag()` | When the script gets disabled. |
| `input.shutdown()` | Optional: drop the hidden TextEntry right away. |

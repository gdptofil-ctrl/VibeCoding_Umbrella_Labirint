# Components

Copy-ready recipes. Every snippet runs inside a window `body(y)` callback unless it says otherwise; `x, w` are usually `K.PAD, K.W - K.PAD * 2`. `examples/ui_kit_demo.lua` shows all of them together.

## Skeleton of a script with a window

```lua
local ui = {}
do
	-- menu: enable (+ debug in its gear), show, key ... (umbrella-lua menu rules)
end

-- paste kit.lua here, edit K

local S = { tab = Config.ReadInt(K.CFG, "tab", 1) }
local body_h = 200

local function draw_window()
	view.window({
		title = "My Script", sub = "Short subtitle",
		body_h = anim.tween("body_h", body_h, 0.2),
		body = function(y)
			local top = y
			-- widgets...
			body_h = y - top + K.PAD
		end,
	})
end

local function frame()
	if not ui.enable:Get() then return end
	P.open = ui.show:Get()
	input.frame(draw_window)
end

local function update()
	if not ui.enable:Get() then return end
	if ui.key:IsPressed() and not Input.IsInputCaptured() then ui.show:Set(not ui.show:Get()) end
end

K.DEBUG = function() return ui.debug:Get() end
K.ON_CLOSE = function() ui.show:Set(false) end

local script = {}
if K.EVERYWHERE then
	script.OnFrame, script.OnUpdateEx = frame, update
else
	script.OnDraw, script.OnUpdate = frame, update
end
function script.OnKeyEvent(e)
	if not ui.enable:Get() then return true end
	return input.event(e)
end
return script
```

The body height is measured while drawing and fed back next frame through a tween, so the window grows and shrinks smoothly when content changes.

## Brand window (big windows, the default)

```lua
view.window({
	title = L("xx_title"),            -- drawn in upper case with tracking, logo on its left
	sub = L("xx_mode"),               -- short state after the accent slash: "TRAINING", "CAPTAINS MODE"
	pill = { id = "head_pill", kind = S.upd_kind, label = S.upd_label, glyph = "\u{f063}", click = install },
	buttons = { { glyph = K.G.gear, id = "btn_gear", active = S.view == "set", click = toggle_settings } },
	body_h = anim.tween("body_h", S.body_h, 0.2),
	body = draw_body,
})
```

- The logo, the cut corners, the accent hairline, the corner ticks and the resize grip come from the kit. Do not draw them again and do not add your own frame.
- `sub` is the current mode or step in one or two words, not a description.
- `pill` is for background state that matters now (update available, loading, done, error). `kind = nil` hides it with an animation. Never more than one.
- Body layout: segment tabs on top (`view.tabs`), then cards with one `view.section` each, rows inside. Settings pages: one card per topic, rows of title + control right (`view.choice`, `view.switch`, `view.slider`).
- While data loads draw `view.loader(K.PAD, y, K.W - K.PAD * 2, title, text)` instead of the body.
- Pending choice (a picked row waiting for confirm): `view.action_bar` at the bottom of the body with the primary action in `"accent"` and Esc/Enter keycaps.

## Right-click menu

```lua
view.row(x, y, w, 42, { id = "row:" .. id, title = name,
	click = function() S.sel = id end,
	rclick = function(mx, my)
		view.ctx_open(mx, my, { title = name, items = {
			{ label = L("xx_select"), glyph = K.G.check, hint = L("xx_dbl"), click = function() pick(id) end },
			{ label = L("xx_star"), glyph = "\u{f005}", check = S.star[id], click = function() S.star[id] = not S.star[id] end },
			{ sep = true },
			{ section = L("xx_danger") },
			{ label = L("xx_delete"), glyph = "\u{f1f8}", danger = true, click = function() remove(id) end },
		} })
	end,
})
```

The menu stays inside the screen, closes on a pick, on a click elsewhere (swallowed) or Esc. Destructive items last, after a separator.

## Action bar

```lua
y = y + view.action_bar(x, y, w, {
	id = "pick_bar", on = S.sel ~= nil, img = asset.portrait(S.sel or ""), title = name, sub = L("xx_pick_sub"),
	buttons = {
		{ label = L("xx_cancel"), key = "Esc", id = "bar_cancel", click = function() S.sel = nil end },
		{ label = L("xx_confirm"), key = "Enter", kind = "accent", id = "bar_ok", click = confirm },
	},
})
```

Returns the visible height, so content below moves smoothly while it slides in. Wire Enter/Esc in your `OnKeyEvent` before `input.event` if the keys must work.

## Loading and status

```lua
if S.loading then
	y = y + view.loader(x, y, w, L("xx_title"), L("xx_loading"))
end
view.spinner(x + 8, cy, 5.5)              -- inline, next to a "waiting" line
```

## Compact mode

Pass `compact = L("xx_compact")` to `view.theme_settings` and use `g.lay(normal, compact)` for your own row heights and gaps. The kit already shrinks the header and toggle rows.

## Window: drag, fold, close, fade

- Drag by the header (left part, the buttons keep their clicks). Position is saved when the drag ends (`wx`, `wy`).
- Fold with the chevron button or a double-click on the header. The body animates with `ease_in_out` and fades with `fold ^ 1.5`. Saved as `collapsed`.
- Close with the red-on-hover button: calls `view.close()` -> `K.ON_CLOSE`. Reopen with the menu key.
- Fade in and out with `P.open`; when alpha reaches 0 the window stops drawing and drops its hit areas, so clicks go to the game.
- Header extras: `buttons = {{ glyph = "\u{f013}", id = "btn_gear", active = S.gear, click = function() S.gear = not S.gear end }}`. They line up to the left of fold and close (and of the dock chevron when it shows). The title is cut with an ellipsis to the space left of the leftmost button, so buttons never cover it. Still keep extras to two in a small window: each one takes 24 px of title.

## Side docking (small windows)

With `K.SMALL` and `K.DOCK` (default `true`) a window can hide into the left or right screen wall, not only fold up:

- Drag the window to a wall: within `K.SNAP` (24 px) it snaps flush to it, and stays pinned to that wall when the size changes.
- Away from the walls the header chevron is on the right and folds the body up into the header (red `<` open, grey `v` folded). It never pulls the window to a wall.
- Flush to a wall (dragged there, it snaps) the chevron moves to the side away from that wall and points at it (Umbrella's rule). Click: the window slides into the wall and fades (0.22 s, `ease_in_out`), and a tab fades in at the same height, flush to the wall. A double-click on the header still folds the body up.
- The tab copies Umbrella's collapsed panels: 22 px high, 26 px wide, 1 px outline, a grey chevron pointing back 10 px from the outer edge (hover brightens it, click undocks) and, optionally, script content after it: pass `o.tab_w` (extra width) and `o.tab(x, cy)` to `view.window`. Usually the main switch, always mini, with `tab_w = 22`:

```lua
view.window({
	title = "My Script", body_h = S.body_h, body = draw_body,
	tab_w = 22, tab = function(x, cy) view.switch(x, cy, ui.enable:Get(), "tab_on", toggle_enable, true) end,
})
```

- Nothing else goes in the tab: no icon buttons, no full-size switch, no text.

- Drag the tab up and down to move it (horizontal position stays on the wall). Docked state is saved as `docked`; position as `wx`, `wy` when a drag ends.
- `view.edge()` returns `-1`/`1`/`nil` (left wall, right wall, none), `view.side()` the nearest wall (`-1`/`1`); `view.dock(on)` docks or undocks from code (docking from code moves the window to the nearest wall first; the header chevron only docks when the window already touches a wall).
- Big windows (`K.SMALL = false`) never dock.

## Umbrella-style panel (small window)

How Umbrella lays out its own panels (Illusion Controller, Net Worth, Wards) and how a small script window should look:

```lua
local ROW = 28
view.window({
	title = L("xx_title"),
	switch = { on = ui.enable:Get(), click = toggle_enable },
	tab_w = 22, tab = function(x, cy) view.switch(x, cy, ui.enable:Get(), "tab_sw", toggle_enable, true) end,
	body_h = anim.tween("body_h", S.body_h, 0.2),
	body = function(y)
		local top, x, w = y, K.PAD, K.W - K.PAD * 2
		y = y + 10
		view.button(x, y, w, 22, L(MODES[ui.mode:Get() + 1]), "soft", "btn_mode", function() cycle(ui.mode, #MODES) end)
		y = y + 28
		for _, name in ipairs(S.list) do
			local cy = y + ROW / 2
			g.square(asset.portrait(name), label(name), x, cy - 10, 20, 1, 2, S.off[name] and 1 or 0)
			g.text(500, 13, g.fit(500, 13, label(name), w - 62), x + 28, cy, S.off[name] and T.t4 or T.t3)
			view.switch(x + w - 26, cy, not S.off[name], "sw:" .. name, function() toggle(name) end)
			y = y + ROW
		end
		y = y + 6
		view.button(x, y, w, 22, L(OPTS[ui.opt:Get() + 1]), "soft", "btn_opt", function() cycle(ui.opt, #OPTS) end)
		S.body_h = y + 22 + 10 - top
	end,
})
```

- Every line is a row: icon, label, control on the right. No caption lines, no subtitles, no status line with an info glyph: state shows in the rows themselves (a red crosshair next to the current target, a grey label for an off item).
- Spacing: `+28` after a 22 px button before the first row and `+6` after the last row before a button, so 10 px stay between every button edge and the icons. Icons 20 px.
- Buttons light up in the accent on hover (the kit does it), like Umbrella's Adaptive button.
- A mode or option with a few values is a full-width button that cycles them and writes the menu widget (`widget:Set`), so the window and the Umbrella menu stay in sync. Its name goes in a hover hint.
- The header switch is the script's main enable switch; the window stays visible while it is off, like Umbrella's panels. Show and hide the window itself with the menu item.
- A list the user orders: drag the row by its icon and label, the switch keeps its own click. While dragging, draw the lifted row on a `C.menu` box under the cursor and let the others close the gap.
- Real example: `dark_seer_illusions.lua` (enemy priority rows, order mode and no-target buttons).

## Header with buttons

`view.icon_button(x, y, 28, glyph, id, active, click, danger)`. 28 px square, 2.5 radius, faint fill; hover tints it with the accent and draws corner brackets. `active` keeps it lit (a toggled gear page). `danger` turns it red on hover (close, delete).

`view.window` sizes its own header buttons: 28 px with a 34 step in the brand skin, all on the right next to fold and close, square with corner brackets on hover. The flat skin (`umbrella` theme) copies Umbrella's panels instead: `o.switch` and `o.buttons` sit on the left as bare 16 px glyphs, the title is regular 13 px `T.t2` centered on the window, and the chevron folds the body up (right side) or, when the window touches a wall, docks it (side away from the wall). There is no close button; the window is shown and hidden from the menu or its key.

```lua
view.window({
	title = L("xx_title"), body_h = S.body_h, body = draw_body,
	switch = { on = S.active, id = "head_sw", click = toggle_active },
	buttons = { { glyph = "\u{f0b0}", id = "btn_filters", active = S.filters, click = toggle_filters } },
})
```

## Cards and sections with a count badge

```lua
view.card(x, y, w, card_h)
local h = view.section(x + 10, y + 10, w - 20, "Targets", #targets)
```

Compute `card_h` before drawing the card (cards are drawn first so content lands on top). For grids: rows = `math.ceil(n / per_row)`, `per_row = math.floor((w + gap) / (size + gap))`.

## Toggle, button, slider, dropdown

```lua
y = y + view.toggle_row(cx, y, cw, "Auto mode", S.auto, "auto", function() S.auto = not S.auto end, "Toggle row with a subtitle")

view.button(x, y, 120, 30, "Apply", "accent", "apply", apply)

g.text(600, 12.5, "Range", cx + 10, y + 16, T.t2)
view.slider(cx + cw * 0.38, y + 16, cw * 0.62 - 10, "range", S.range, 300, 1200, 50,
	function(v) S.range = v end, function(v) save("range", v) end)

view.dropdown(cx + cw - 150, y + 2, 140, "mode", {
	{ value = "fast", label = "Fast" }, { value = "safe", label = "Safe" },
}, S.mode, function(v) S.mode = v; save("mode", v) end)
```

The dropdown list closes on a pick, on a click anywhere else (that click is swallowed) and on Esc.

## Segmented tabs

```lua
y = y + view.tabs(x, y, w, { "Main", "Extra" }, S.tab, function(i) S.tab = i; save("tab", i) end) + 10
```

## List rows

```lua
view.row(x, y, w, 42, {
	id = "row:" .. id, img = asset.hero(name), title = loc_name, sub = role,
	value = "52.1%", value_c = T.green, selected = S.sel == id,
	click = function() S.sel = id end,
})
```

Text is cut with an ellipsis to fit before the value.

## Icon grid with click to select

```lua
local items = {}
for i, name in ipairs(enemies) do
	items[i] = { key = name, img = asset.hero(name), label = GameLocalizer.FindNPC(name), on = S.list[name] == true }
end
view.grid(x, y, w, items, 36, 8, "enemy", function(it) S.list[it.key] = not S.list[it.key] end)
```

Selected icons are full colour with an accent outline, the rest grey and dimmed; hover brightens and shows the name as a hint. `dot = T.green` puts a small status dot in the corner. For items use `asset.item("item_blink")`, for abilities `asset.ability("grimstroke_spirit_walk")`; names come from game data (`lt data`, umbrella-lua skill).

In a small window put a caption above the grid, never a section header, and keep the spacing fixed so the text does not sit on the icons:

```lua
y = y + view.caption(x, y, w, L("xx_targets"), string.format("%d/%d", on_count, #items))
y = y + view.grid(x, y, w, items, 30, 6, "ally", toggle) + 12
view.status(x, y + 8, w, "\u{f6e2}", status_text, status_c)
```

## Status line and empty state

```lua
view.status(x + 4, y + 10, w - 8, K.G.info, string.format("Ready, %d of %d", n, total))
if #rows == 0 then view.empty(x, y, w, 160, K.G.search, "Nothing found") end
```

The empty state takes the place of the list with the same height, so the window does not jump.

## Scrolling for long lists

```lua
local area_h = 300
local cy0 = view.scroll_begin("list", x, y, w, area_h)
for n, r in ipairs(rows) do
	view.row(x, cy0 + (n - 1) * 44, w - 8, 42, { id = "row:" .. r.id, title = r.title })
end
view.scroll_end("list", #rows * 44)
```

Leave 8 px on the right for the thumb (`w - 8`). Wheel scroll accelerates on fast spins, the thumb widens on hover and can be dragged, a hairline appears at the top once scrolled. Rows outside the area are clipped, and their hit areas too. Each scroll area keeps its own state by `id`.

## Text input

```lua
S.search = S.search or { text = "", max = 32, on_change = function(t) S.filter = t end }
y = y + view.input(x, y, w, "search", S.search, "Search…", K.G.search) + 10
```

Russian and any other layout, Ctrl+V, selection with Shift, Ctrl+A, Ctrl+Backspace, Home/End, Enter (`on_enter`), Esc. How it works and what not to do: `input.md`.

## Toast notifications

```lua
view.toast("Saved", "ok")
view.toast("Something went wrong", "error")
```

Bottom-right, stacked up to 4, fade and slide, 4 s, click to dismiss. They draw even when the window is closed, so use them for results of background work.

## Hover hints on icons

`view.hint(id, text)` right after the widget that registered `id`. The grid does it for you with `label`. One line, short, appears after 0.35 s, stays on screen.

## On-screen pill bar (small overlays)

```lua
local function draw_pills()
	g.origin(0, 0)
	g.a = 1
	local screen = Render.ScreenSize()
	local x = screen.x / g.s / 2 - 90
	x = x + view.pill(x, 40, { glyph = "\u{f0e7}", text = "Ready", c = T.green }) + 8
	view.pill(x, 40, { img = asset.hero(name), text = loc_name, detail = "3.2s", gray = not alive })
end
```

Call it after `input.frame(...)` in the same draw callback, wrapped in `pcall` and followed by `g.reset()`. Pills follow `references/pill.md` of the umbrella-lua skill: dark capsule, icon left, bold text, divider, grey detail.

## Settings inside the window

```lua
view.card(x, y, w, 188)
view.theme_settings(x + 14, y + 14, w - 28, {
	theme = "Theme", accent = "Accent", scale = "Size", opacity = "Opacity", compact = "Compact",
})
```

Only for big, complex windows: put it in a Style tab or behind a gear button in the header. Small windows (`K.SMALL`) get no look settings at all; if size matters, one Size slider in the Umbrella menu.

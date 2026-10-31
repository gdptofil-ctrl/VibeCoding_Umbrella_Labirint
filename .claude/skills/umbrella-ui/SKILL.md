---
name: umbrella-ui
disable-model-invocation: true
description: Builds on-screen UI for Umbrella (Dota 2) Lua scripts - draggable windows with fold/close/fade, cards, sections, toggles, sliders, dropdowns, tabs, list rows, hero/item icon grids, scroll areas, text input (Cyrillic and Ctrl+V through a hidden Panorama TextEntry), toasts, hover hints and small on-screen pills - using one tested immediate-mode kit (references/kit.lua) with themes, accents, a size slider and saved window state. Use when the user asks for a window, panel, overlay, HUD element, settings screen, list, picker or any custom drawn interface in an Umbrella script, or asks to restyle or fix one.
---

# Umbrella UI

Custom interfaces in Umbrella scripts are drawn every frame with `Render.*` (immediate mode). There is no retained widget tree: each frame the script draws the window, registers clickable rectangles, and routes mouse and keyboard events to them. This skill gives you a ready kit for that, extracted from the user's best scripts (Draft Helper 2.x is the reference for the look; Script Manager and Ability Draft Helper for behaviour) and simplified.

`<skill>` below is this skill's folder. Load the `umbrella-lua` skill too: everything that is not UI (menu, script setup, `lt check`, API signatures from `references/api/`) follows its rules. This skill covers only the drawn interface.

## Files

| File | What it is |
| --- | --- |
| `references/kit.lua` | The kit: paste it into the script. Generic code plus one `K` block to edit. Tested in game. |
| `references/api.md` | Every kit function: signature, arguments, return value. Read before using a widget. |
| `references/components.md` | Recipes for each component with code, sizes and behaviour. |
| `references/input.md` | Mouse/keyboard routing and the text input (hidden TextEntry, Cyrillic, Ctrl+V). Read before touching input. |
| `references/style.md` | Themes, accents, colours, typography, spacing, the default `umbrella` theme (live Umbrella menu colours), saving state and how to test it. |
| `examples/ui_kit_demo.lua` | A complete working script that uses every component (brand window with logo and header status pill, segment tabs, toggles, slider, dropdown, choice, input, loader, list with scroll, right-click menu, action bar, hero grid, status, empty state, toasts, hints, pills, style settings with compact mode, resize grip). Copy from it. |

## Pick the shape first

Decide by the size of the task, not by habit. A small script gets a small UI.

1. **Big window** (lists, settings, pickers, several sections, a complex task): the full kit with `view.window` in the **brand skin** (the Draft Helper look, default `K.THEME = "brand"`): a header bar and a body box with 45-degree cut corners, an accent hairline and accent corner ticks, the logo and an upper-case letter-spaced title on the left, an accent slash with the subtitle, square header buttons with corner brackets on hover, sharp 2.5 px corners everywhere, Bahnschrift. Themes and accents chosen by the user, size, opacity and compact mode in a Style tab or gear page, a resize grip in the corner. Look settings exist **only** in this shape. Recipe: "Brand window" in `references/components.md`.
2. **Small menu or overlay** (a few toggles or sliders, a status pill, a few icons, one compact panel): set `K.SMALL = true`. It locks the `umbrella` palette (the Umbrella menu colours, read live from `Menu.Style`) and hides theme/accent choices. Big windows default to the same palette. Never hardcode menu colours or tint the header red: let the kit read them.
   - Strict minimalism: nothing bulky. No tabs, no Style tab or gear page, no section headers, no subtitle, no header glyph tile, no cards inside cards, no toasts or empty states unless the task needs them. Compact header (`K.HEAD = 22`), title only, rows straight in the body. Only what the user needs to read or change at a glance.
   - Compact size: `K.W` 240-280, `K.PAD = 10`, at most two extra header buttons. Use `K.HEAD = 22`. With the default `umbrella` theme the kit draws the Umbrella panel skin (like Illusion Controller): a header box and a body box, 1 px outline, 5 radius, 4 px gap, no shadow. The text is drawn in `MuseoSansEx`, the Umbrella menu font. The header is laid out like Umbrella's: one chevron (on the right, folding the body up; flush to a screen wall, on the side away from it, docking), the enable switch (`o.switch`) and action glyphs, the title centered, no close button. The title is fitted left of the leftmost button so a button never covers it.
   - Content is Umbrella rows, not cards: a full-width mode button that cycles a menu Combo, then rows of 20 px icon + 13 px label + control on the right (switch, slider, value), 28 px apart, then buttons, with 10 px clear between a button edge and the icons. Buttons fill with the accent on hover. No caption lines, no status lines with info glyphs, no bare icon grids. Recipe: "Umbrella-style panel" in `references/components.md`.
   - No look settings in the window: no theme/accent pickers, no opacity slider, no `view.theme_settings`. If size matters, one Size slider goes in the Umbrella menu (script gear), not in the window.
   - Side docking (`K.DOCK = true`, on by default): away from the screen walls the header chevron folds the body up (red `<` open, grey `v` folded) and never pulls the window to a wall. Dragged to the left or right wall the window snaps there and the chevron moves to the side away from the wall, pointing at it. A click slides it into the wall, leaving only a 22 px tab with a chevron back (and, optionally, the main on/off switch through `o.tab`, always the mini switch with `tab_w = 22`). Double-click on the header folds the body up anywhere. See "Side docking" in `references/components.md`.

**Every window carries the logo** (`view.logo`): the brand header draws it left of the title, the flat header draws a 12 px logo in front of the centered title, the loader draws it inside the orbit. Never remove it, never replace it with a glyph tile, and never use `Render.Logo` (that is the Umbrella cheat's own mark, not the scripts' logo).

Minimalism is the rule for both: the brand skin's ornaments are fixed (cut corners, accent hairline, two corner ticks, the header underline, section rules, hover brackets) and nothing is added on top: no glows, pulsing, emoji, lettered badges, extra groups or extra lines. Every element must earn its place.

## Build it well: the visual checklist

Run this before you call a window done. Each item is a defect that made earlier windows look cheap.

1. **One grid.** Every x is `K.PAD` or a card inset (`x + 10`); every gap is 8, 10 or 12. No odd offsets like 7 or 13.
2. **Hierarchy in three steps.** Title (`T.t1`, 600-700), body (`T.t2`), secondary (`T.t3`/`T.t4`, 11-11.5 px). Never two bold lines next to each other.
3. **Accent only where the user acts or looks first:** current tab, switch on, primary button, slider fill, selected row bar, section rule, header underline. One primary (`"accent"`) button per view; the rest `"soft"` or ghost.
4. **Text on accent fills uses `AON`**, never `T.white` (the brand lavender needs dark text).
5. **Numbers align right**, labels left, one control per row on the right edge at the same x.
6. **Sections** are `view.section` (accent bar + tracked caps + fading rule), at most one per card; a card holds one topic.
7. **States everywhere:** loading (`view.loader` or the header `pill = {kind = "loading"}`), empty (`view.empty`), error (toast or pill `"error"`). A window never shows a blank body.
8. **Feedback on every action:** hover (kit animates it), a toast or pill change for results, the action bar for a pending choice (`view.action_bar` with keycaps).
9. **Right click** on a list item opens `view.ctx_open` with the item's actions; destructive ones last, `danger = true`, after a `sep`.
10. **Fit, never overflow.** Every text in a fixed width goes through `g.fit`/`g.track_fit`; check the longest Russian string.
11. **Motion:** state changes animate (the kit does it); nothing loops except loaders and spinners.

## Order of work

1. Create the script by the umbrella-lua skill.
2. Paste `references/kit.lua` after the menu block. Edit only the `K` block: `NAME`, `CFG` (config name, unique per script), `W`, `EVERYWHERE`, `SMALL`, `SINK_ID` (unique per script). Leave `THEME`/`ACCENT` at `"brand"` unless the user asks for another look.
3. Write the content functions with the widgets from `api.md`, the way `examples/ui_kit_demo.lua` does: a `draw_window()` that calls `view.window{...}` with a `body(y)` callback, and callbacks that set `K.DEBUG`, `K.ON_CLOSE` and wire `input.frame`, `input.event`.
4. Choose where it draws with one flag: `K.EVERYWHERE = true` hooks `OnFrame` + `OnUpdateEx` (main menu and match), `false` hooks `OnDraw` + `OnUpdate` (match only). The example shows the wiring.
5. `lt check "<file>"`, then reload in game (qMCP `reload_scripts` if present) and read the log. Draw errors are caught by `input.frame` and written once as `[NAME] draw error: ...`.

## Rules that prevent the known bugs

- All coordinates are window units; the kit multiplies by the scale. Never mix screen pixels into widget calls, except in code that sets `g.origin(x, y)` itself (toasts, pills, overlays).
- Register clicks with `hit.add` (or the widgets do it). Clicks are handled in `OnKeyEvent` through `input.event`, which swallows both the press and the release so the click never reaches the game. Do not poll `Input.IsKeyDown(KEY_MOUSE1)` for clicks: it leaks clicks and fires repeatedly.
- Anything that must appear above the window (dropdown lists, tooltips, toasts) is drawn after the window body, outside its clip. The kit does this; keep it that way when adding popups.
- Text input uses the hidden Panorama TextEntry from `input.md`. Never build typed text from key codes alone: that was the Script Manager bug (Latin only, no Cyrillic, no paste).
- Never call `Engine.RunScript` at the top level of the file or from network callbacks (`OnPostReceivedNetMessage`, `OnSendNetMessage`, `OnGCMessage`). Run it only from frame/update callbacks. JS from the wrong place crashed Dota with `v8::Context::Exit() - Cannot exit non-entered context`.
- `Config.Write*` triggers an Umbrella save. Write only when a drag ends or a setting changes, never on load or per frame. `save()` in the kit skips unchanged values. Reading at load is fine.
- Images load through `asset.image` with a budget of 3 new loads per frame, so opening a window with many icons never hitches. A missing image draws a lettered tile, so `nil` is safe.
- Keep the main chunk under 200 locals: the kit uses about 40. Put new state in tables (`S`, `P`).
- Draw with `pcall` (the kit does), log an error once, not every frame.
- Hover states, toggles and folds animate with `anim.tween`; sizes and positions use fixed-time tweens, never exponential crawl to the last pixel.

## Testing in game

1. `lt check` must show 0 warnings (the `ai_bridge` warning is fine when the project logs through qMCP).
2. Reload, read the log: no `draw error`, no Lua errors for the file.
3. Ask the user to check by hand what code cannot: drag the window, fold, close and reopen with the key, scroll with the wheel and the thumb, open a dropdown and click outside, type Russian and English text, paste with Ctrl+V, press Esc in the field, click through the window edge (the game must not get the click).
4. Small windows: switch the menu language and check that the title is fully readable left of the header buttons; drag to the left and right wall (it snaps), dock with the chevron, drag the tab up and down, undock, reload scripts while docked (it must stay docked).
5. Saved state: drag the window, change a setting, reload scripts. The window must come back in the same place with the same settings, and the log must not show a reload loop (`Reload ScriptSystem` repeating by itself).

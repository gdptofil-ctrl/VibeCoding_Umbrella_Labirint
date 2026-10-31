# Input

## Mouse

All clicks go through `OnKeyEvent` -> `input.event(e)`:

1. `hit.at(mx, my)` looks up the topmost rect registered last frame. If there is none, the event goes to the game (`return true`), and an open dropdown or focused field is closed.
2. Over the UI, the press is swallowed (`return false`), `input.press` records it and calls `on.down` (drags, sliders, text caret, scroll thumb). The matching release is swallowed too, otherwise the game sees a lone mouse-up.
3. On release `input.release` calls `on.click` only if the cursor is still over the same id and the press did not turn into a drag (moved more than 4 px). `on.dbl` fires on a second click within `K.DOUBLE`.
4. Right button calls `on.rclick`.
5. The wheel goes to the topmost rect with `on.wheel` under the cursor; over the UI it is always swallowed so the camera does not zoom.
6. `input.tick` (inside `input.frame`) ends a press if the button was released outside the game window, and moves the window, slider or scroll thumb while the button is held.

Do not detect clicks with `Input.IsKeyDown(KEY_MOUSE1)` in a draw callback. It fires every frame while held and the click still reaches the game (the hero walks to the cursor).

## Keyboard

- While a text field is focused, every key event is swallowed so typing never triggers game hotkeys or the shop. Editing keys (arrows, Home, End, Backspace, Delete, Ctrl+A, Enter, Esc) are handled in `edit.key`.
- Without focus, keys pass to the game. Esc over the window closes an open dropdown.
- Menu binds: read them in the update callback with `ui.key:IsPressed() and not Input.IsInputCaptured()` (chat and console capture input).

## Text input: how typed text is read

Umbrella gives scripts key codes, not characters. Building text from key codes only knows `KEY_A`..`KEY_Z` and digits: no Cyrillic, no layout, no Shift symbols, no paste. That is exactly the bug Script Manager had before 2.10.3.

The working approach (Script Manager 2.10.3+, in the kit):

1. When a field gets focus, `edit.sink(true)` runs JS that creates a hidden 1x1 `TextEntry` panel named `K.SINK_ID` at the Panorama root and calls `SetFocus()` on it. Windows now delivers real characters to it: any layout, IME, Shift symbols, and Ctrl+V paste (the TextEntry pastes natively).
2. Its `ontextentrychange` handler appends `sink.text` to a panel attribute `typed` and clears the text, so nothing accumulates in the hidden field.
3. Every frame `edit.poll()` finds the panel with `Panorama.GetPanelByName(K.SINK_ID, false)`, reads `GetAttribute("typed", "")`, clears it, strips control characters and inserts the text character by character with `utf8.codes` (UTF-8 safe: caret positions, widths and deletion all work on `g.chars`, never on bytes).
4. Key-code fallback: until the TextEntry has delivered anything once (`edit.typed_ok`), Latin letters from key codes are buffered for 80 ms. If the TextEntry delivers in that window the buffer is dropped, so a character is never inserted twice. After the first delivery the fallback is off for the session.
5. Keep-alive and safety: while focused, `edit.sink(true)` refreshes an `alive` timestamp every `K.SINK_ALIVE` seconds and re-focuses the entry on each key press (another panel may steal focus). A JS watchdog deletes the entry if it was not refreshed for `K.SINK_TIMEOUT` ms, so if the script errors or is unloaded the game keyboard comes back by itself.
6. Blur (click outside, Esc, Enter, window hidden, script disabled) calls `edit.sink(false)`, which deletes the entry.

Rules:

- Give every script its own `K.SINK_ID`. Two scripts sharing one name fight over the same panel.
- Do not handle Ctrl+V, Ctrl+C or text characters in Lua. Paste arrives through `typed`. Copy is not supported (no verified clipboard API); do not invent one.
- Never call `Engine.RunScript` at the top level of the file or from network callbacks. Script Manager runs one cleanup call at load; the kit does not: the watchdog removes a stale entry within 1.5 s anyway. JS run from the wrong context can crash Dota with `v8::Context::Exit() - Cannot exit non-entered context`.
- Do not drive the sink from `OnUpdate` or `OnDraw` when `K.EVERYWHERE` is true and the field is used in the main menu: those callbacks do not run there. `input.frame` handles it from whichever draw callback the script uses.
- Limit length with `f.max` (default 64 characters).
- Single-line only. For multi-line text (feedback forms) see Script Manager `edit.fb_layout`: word wrap that keeps every caret position.

## Field behaviour checklist

Click puts the caret at the nearest character; Shift+arrows select; Ctrl+arrows jump words; Ctrl+Backspace/Delete delete words; Ctrl+A selects all; typing replaces the selection; the view scrolls horizontally to keep the caret visible; the caret blinks after 0.5 s idle; placeholder text when empty; accent outline while focused.

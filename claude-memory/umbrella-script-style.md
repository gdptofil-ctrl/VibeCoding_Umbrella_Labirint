---
name: umbrella-script-style
description: "Every Umbrella script/doc I write gets the user's ASCII picture on top and the big \"@umbrella_3OHT\" nick banner at the bottom, chen_circus.lua style"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 0efa3139-fef6-440c-b048-ca9fa86f0118
  modified: 2026-10-29T12:10:35.258Z
---

Every script or doc I write or edit for the user's Umbrella (Dota 2 cheat) work must be framed like their
`chen_circus.lua` (the user set that file up as the reference on 2026-09-27):

- **Top:** a blank line, `--[[`, the picture, `]]`. The picture is the user's own classic-ASCII art
  (`:-=+*#%@`, 101 lines x 146 cols), saved verbatim in `assets/umbrella_art.txt` next to this memory.
  Not the braille version I made first — the user replaced it. In `chen_circus.lua` the art shares its
  `--[[ ]]` with the Chen's Circus description underneath: that text is NOT part of the picture (I once
  copied it into every file by mistake and the user was rightly annoyed). Only take the art lines.
- **Bottom:** `--[[`, the nick banner (`@umbrella` / `_3OHT` + heart, Segoe UI Black rendered in the same
  `:-=+*#%@` alphabet, with the caption line `by @umbrella_3OHT <3` right-aligned under it), `]]`.
  Saved verbatim in `assets/umbrella_nick.txt`. Copy both files as-is; do not regenerate.
- `.md` files: same content inside ```` ```text ```` blocks. `.py` files: same content as `# ` lines.

Code must look hand-written, not AI-made. The user's words (2026-09-27): too many comments, "убери объяснение
каждой строчки". So: no explanatory comments at all. Allowed: a 1-2 line lowercase casual description under the
picture, `---@diagnostic` lines, bare section markers like `-- меню` / `-- логика` / `-- рисуем`, and
commented-out example settings. No essay headers, no "why this works" comments, no em dashes in strings.
Never rename menu widget labels (Umbrella saves configs by widget name).

Done on 2026-09-27 for chen_circus, mana_void_killer (+ _en), arc_warden_heist, mini_games and all of mock/,
with a proof that the Lua bytecode listing (line numbers and heap addresses masked) and the Python AST did not
change. `micro.lua` / `micro_demo.lua` were not in the list and still carry the long comments.

**Why:** they publish in the Umbrella Discord `#user-scripts` forum; the picture + nick is their branding.

**How to apply:** any new/edited `.lua`, `.md`, `.py` in the active scripts folder (see [[umbrella-scripts-folder]]).
The picture + nick frame is the default, not absolute: for `creep_obituary.lua` (2026-09-28) the user said
"без аниме девочки и без ника", so it has neither. `farm_helper.lua` (2026-10-29): user deleted the top
picture themselves and swore when I put it back ("шапку не добавляй") - file starts with `---@diagnostic`,
nick at the bottom stays. If a file the user edited has no picture, it was removed on purpose: never
re-add it. Follow what they say per script; the hand-written style
(few comments) still applies either way.
`mock/tools/update_api.py` already stamps the same frame onto `mock/surface.lua` and `UMBRELLA_API.md` when it
regenerates them. See [[umbrella-scripts-folder]].

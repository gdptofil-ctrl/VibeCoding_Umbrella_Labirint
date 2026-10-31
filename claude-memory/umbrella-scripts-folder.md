---
name: umbrella-scripts-folder
description: "Where the user's Umbrella scripts live: back in Downloads\\scripts since 2026-09-28 (was AppData for a few days)"
metadata:
  node_type: memory
  type: project
  originSessionId: 0efa3139-fef6-440c-b048-ca9fa86f0118
  modified: 2026-09-28T16:28:48.099Z
---

Active scripts folder (2026-09-28): `C:\Users\gdpto\Downloads\scripts`. The user works there again.
From 2026-09-25 to 09-28 it was `C:\Users\gdpto\AppData\Roaming\AAsavAHngxPLF\scripts` (the cheat folder, with
`debug.log`, `assets/JSON.lua`, `db.json`); that copy is now secondary. The folder has moved twice, so before
editing anything check which one has the newest files (compare mtimes), and never overwrite a file the user
changed in the other copy.

On 09-28 I copied everything I had built in AppData over to Downloads (wrapped.lua, micro.lua, MICRO.md, mock/,
CLAUDE.md, MOCK.md, UMBRELLA_API.md, restyled chen/mana_void/arc_warden/mini_games), after confirming the Downloads
copies were untouched originals. Downloads-only user files: techies2.lua, ascii_grid.lua.

Tooling: `lua mock/run.lua x.lua --keep-going` (offline runner), `python mock/tools/update_api.py` (regenerates
`UMBRELLA_API.md` + `mock/surface.lua` from https://uczone.gitbook.io/api-v2.0). Lua 5.4.6 lives at
`%LOCALAPPDATA%\Programs\Lua\bin` (not on PATH in this shell; call it by full path).
Style rules: [[umbrella-script-style]].

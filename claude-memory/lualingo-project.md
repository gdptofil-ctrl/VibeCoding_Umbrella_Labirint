---
name: lualingo-project
description: "Lualingo (Duolingo for Lua + Umbrella API, built 2026-10-02): design decisions and what is still unverified in game"
metadata:
  node_type: memory
  type: project
  originSessionId: 9807ea43-25d7-4c8f-9a69-5328152bbe00
  modified: 2026-10-02T05:06:03.285Z
---

Built 2026-10-02 in `Downloads\scripts`: `lualingo.lua` + `lualingo/tasks.lua` (12 units, 176 static tasks,
10 generators; 6 kinds: choice, tiles, order, bug, type, match). Daily pack of 10, wrong answers come back at the
end (max 3 tries so a lesson always ends), Elo-style skill 1..10 picks task difficulty, units unlock by skill.
Streak day = Moscow time from `yandex.com/time/sync.json?geo=213` (fallback timeapi.io), stored as offset vs
`os.time()`, so the PC clock is ignored; offline completion is "pending" until a sync. Freeze every 7 days, max 2.
Draws in `OnFrame` (works in the Dota main menu), blocks input only while drawn, End always closes.

**Why:** the user asked for "Duolingo only for Lua with the Umbrella API", streak by MSK not PC time, harder tasks
the more you learn, 10 tasks a day. Next sessions will likely be in-game bug reports.

**How to apply:** not verified in game yet: HTTP to yandex from the user's network, whether `OnKeyEvent` gets
`KEY_MOUSE1` and whether `return false` stops clicks reaching Dota's main menu, font names
("Segoe UI Black", "Consolas") in `Render.LoadFont`, `Config.ReadFloat`, sounds. Offline checks I used (scratchpad,
not in repo): bank validator that runs every "what prints" task, an e2e bot that clicks drawn text over 50+
simulated days, and a PIL renderer of recorded draw calls for screenshots. The Bash tool mangles backslashes in
heredocs, so write helper scripts with Write. Frame/style per [[umbrella-script-style]].

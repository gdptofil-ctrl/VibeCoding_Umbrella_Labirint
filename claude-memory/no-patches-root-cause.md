---
name: no-patches-root-cause
description: "User strictly forbids symptom patches (\"заплатки\") - find and remove the root cause; reproduce the exact screenshot case in the mock first"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 044625d6-4050-49c3-b175-5a44b471f5a5
  modified: 2026-10-29T13:05:11.923Z
---

The user (2026-10-29, farm_helper.lua) explicitly banned patches: "я строго запрещаю тебе ставить заплатки,
старайся искоренить проблему". Earlier rounds piled rule on rule (loop + commit + grab + hysteresis) and the
rules fought each other; every screenshot showed a new symptom of the same design flaw.

**Why:** each patch fixed one screenshot and broke another; the user lost trust ("ты опять просто затычки делаешь").

**How to apply:** before editing, name the root cause in one sentence (which quantity/model is wrong, not which
case misbehaves). Reproduce the exact situation from the screenshot in the mock (scenario + wrapper, see
[[umbrella-scripts-folder]]) and show old vs new on it. Prefer removing a rule over adding one. Say honestly
when a previous change of mine caused the bug. Related: [[umbrella-script-style]].

---
name: umbrella-ui-skill
description: "User's umbrella-ui kit installed as a personal skill (2026-10-29); use it only when the user says so"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 044625d6-4050-49c3-b175-5a44b471f5a5
  modified: 2026-10-29T15:10:55.353Z
---

The user sent `umbrella-ui.zip` (their UI kit: kit.lua, recipes, style rules) and said: "добавить в скиллы но не
юзать пока я не скажу". Installed at `~/.claude/skills/umbrella-ui` with `disable-model-invocation: true` added
to its SKILL.md so it never triggers by itself. farm_helper.lua's panel was rebuilt on the kit (small Umbrella
panel, kit wrapped in its own function scope because the kit's `C`/`ui` names clash with script locals).

**Why:** the user wants control over when the kit shapes new UI.

**How to apply:** for other scripts' windows do not reach for the kit unless the user asks; when they do, read
its SKILL.md and references first. Related: [[umbrella-script-style]].

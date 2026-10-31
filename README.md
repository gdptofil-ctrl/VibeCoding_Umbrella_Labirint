# Umbrella scripts — набор для вайбкодинга

Всё, что нужно, чтобы писать скрипты Umbrella (Dota 2) с Claude Code на любом компе.

- `CLAUDE.md` — правила для Claude (API, грабли, стиль).
- `UMBRELLA_API.md`, `UMBRELLA_FEATURES.md` — справочник API и встроенные фичи чита.
- `mock/` + `MOCK.md` — проверка скриптов без игры: `lua mock/run.lua имя.lua --brief --keep-going` (нужен Lua 5.4).
- `micro.lua` + `MICRO.md` — библиотека управления юнитами.
- `brain.lua` + `brain/` — запись действий по героям и нейросеть, формат данных в `CLAUDE.md`.
- `examples/` — скрипты-образцы. Для мока клади свой скрипт в корень рядом с `CLAUDE.md`.
- `.claude/skills/umbrella-ui` — UI-кит (скилл, подхватится в этой папке).
- `claude-memory/` — память Claude с основного компа. На ноуте скопируй в
  `~/.claude/projects/<имя-папки>/memory/`, если нужен тот же контекст.

Готовые скрипты кидай в папку `scripts` чита.

# Micro 1.0 — библиотека управления юнитами для Umbrella

Один файл, без зависимостей. Всё, что ты можешь приказать: волки Ликана, крипы Чена,
медведь LD, паучки Брудмазер, фамильяры Визажа, клон Арк Вардена, доминированные
нейтралы.

```lua
local Micro = require("micro")

Micro.summons():follow(Heroes.GetLocal(), { radius = 300 })
Micro.byName("npc_dota_lone_druid_bear"):kite(target)
Micro.all():formation(point, Micro.Formation.arc(600))
```

## Зачем

Скрипт на управление юнитами каждый раз начинается с одного и того же: перебрать
`NPCs.GetAll()`, отфильтровать курьера и варды, завести таймер `nextOrderAt`, чтобы не
спамить приказами, вспомнить что у станненного юнита приказ уйдёт в пустоту, и что
игрок вообще-то тоже хочет иногда покликать сам.

Micro делает это один раз за всех:

- **не больше одного приказа на юнит за тик**, одинаковые приказы не переотправляются —
  нет спама и дёрганья;
- **ручной приказ игрока имеет приоритет** — юнит, которого ты только что кликнул,
  автоматика не трогает полторы секунды;
- **два скрипта на одном крипе договариваются приоритетом**, а не дерутся каждый кадр;
- мёртвые, дормантные, застанненные и ещё не заспавненные юниты отсекаются до того, как
  приказ вообще будет собран;
- слоты строя **привязываются к проходимой земле** — юнит не застревает в обрыве.

## Установка

Положи `micro.lua` в папку со скриптами. Дальше:

```lua
local Micro = require("micro")
```

Подключи жизненный цикл. Обязателен только `update()`, остальное — по строке за штуку:

```lua
function script.OnUpdate()              Micro.update()         end
function script.OnDraw()                Micro.draw()           end
function script.OnUnitAnimation(data)   Micro.animation(data)  end
function script.OnPrepareUnitOrders(d)  return Micro.orders(d) end
function script.OnEntityDestroy(e)      Micro.forget(e)        end
```

`OnUnitAnimation` даёт точный тайминг атаки — кайт становится заметно плотнее.
`OnPrepareUnitOrders` — то самое уступание ручным приказам.

## Выбор юнитов

```lua
Micro.all()            -- всё управляемое, кроме героя, курьера и вардов
Micro.summons()        -- только призванные
Micro.clones()         -- клоны и иллюзии
Micro.everything()     -- вообще всё, включая курьера и варды
Micro.byName("npc_dota_lycan_wolf")
Micro.matching("^npc_dota_visage_familiar")
Micro.of(npc)          -- обернуть конкретный юнит
Micro.wrap({ a, b, c })
```

Фильтры возвращают новую группу, так что их можно цеплять:

```lua
Micro.all()
    :alive()
    :ranged()
    :within(Entity.GetAbsOrigin(hero), 1500)
    :nearest(cursor, 4)
    :attack(target)
```

Полный список: `filter`, `kind`, `name`, `matching`, `exclude`, `within`, `ranged`,
`melee`, `idle`, `free`, `sorted`, `nearest`, `limit`.

Посмотреть, что получилось: `count`, `empty`, `first`, `units`, `each`, `center`,
`slowest`.

## Разовые приказы

```lua
group:move(point)          -- точка подтягивается к проходимой земле
group:moveRaw(point)       -- без подтягивания, если ты сам знаешь что делаешь
group:attack(target)
group:cast("lycan_howl")
group:cast(ability, target)
group:cast(ability, point)
group:stop()
```

## Поведения

Поведение живёт, пока его не заменят или не отпустят. Переназначать его каждый тик
дёшево и правильно — тогда заново призванные юниты сами попадают в строй:

```lua
group:follow(hero, { radius = 300 })            -- кольцом вокруг, держат дистанцию
group:guard(hero, { radius = 350, range = 900 })-- дугой впереди, сами встречают врагов
group:formation(point, Micro.Formation.line(160), { facing = hero })
group:attackMove(point)                         -- идут и убивают всё по дороге
group:kite(target, { range = 500 })             -- бьют и отходят между ударами
group:patrol({ p1, p2, p3 }, { loop = true })
group:hold()
group:release()                                 -- отпустить управление
```

Про `kite` отдельно: весь фокус в том, чтобы не дать приказ на движение до того, как
удар сошёл с руки. Иначе атака отменяется и юнит не делает вообще ничего — именно так
самописный кайт обычно оказывается медленнее обычного правого клика. Micro знает момент
схода удара из `OnUnitAnimation`, а без него оценивает по `GetAttackAnimPoint` и
`GetSecondsPerAttack`.

## Строи

Форма — это функция `(count, center, facing) -> массив точек`:

```lua
Micro.Formation.line(spacing)
Micro.Formation.arc(radius, spread)
Micro.Formation.circle(radius)
Micro.Formation.grid(spacing, columns)
Micro.Formation.wedge(spacing, angle)
Micro.Formation.custom(fn)
```

`facing` в опциях можно задать углом или вектором — если вектором, направление
пересчитывается каждый тик, и строй поворачивается за целью.

Слоты раздаются жадно по ближайшему и **залипают**: юнит держится за своё место, пока
может. Без этого соседи меняются местами каждый тик и никто никуда не доходит.

## Приоритеты и теги

Дай своему скрипту тег и приоритет — и он перестанет конфликтовать с чужими:

```lua
local group = Micro.all():as("my_combo", 80)
```

Юнит под поведением с приоритетом 80 не слушает приказы с приоритетом ниже, пока его не
отпустят. `release()` возвращает юнит тому, кто держал его слабее — так комбо-скрипт
отдаёт медведя обратно фарм-скрипту, когда замес кончился.

По умолчанию приоритет 50, тег `"default"`.

## Своё поведение

```lua
Micro.behaviour("retreat", {
    label = "retreat",
    tick = function (unit, behavior, time)
        local home = behavior.opts.home
        Micro.issue(unit, {
            kind     = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            position = home,
            priority = behavior.priority,
            tag      = behavior.tag,
        })
    end,
})

group:behave("retreat", { home = fountain })
```

`tick` вызывается раз в тик для каждого юнита с этим поведением. `unit.npc` — сущность,
`behavior.opts` — то, что ты передал. Если положишь в `opts.shape` форму строя, слоты
будут раздаваться автоматически и лягут в `unit.slot`.

## Отладка

```lua
Micro.debug = true      -- в OnDraw рисует слоты, поводки и имя поведения над юнитом
Micro.stats             -- { sent = ..., suppressed = ..., deferred = ... }
```

`suppressed` — сколько приказов библиотека не отправила. Если это число сильно больше
`sent`, значит всё работает как задумано: ты бы отправил их все.

`deferred` — сколько приказов отложено на следующий тик, потому что спам-фильтр самого чита
(`Humanizer.IsSafeToCastOrder()`) сказал «хватит на этот тик».

## Настройки

```lua
Micro.tuning.throttle = 0.10   -- минимальный интервал между приказами одному юниту
Micro.tuning.resend   = 0.35   -- сколько одинаковый приказ считается действующим
Micro.tuning.slack    = 24     -- на сколько должна сместиться точка, чтобы это был новый приказ
Micro.tuning.refine   = 0.30   -- как часто можно уточнять точку, которая чуть сдвинулась
Micro.tuning.leap     = 150    -- сдвиг точки, который считается новым планом и уходит сразу
Micro.tuning.yield    = 1.25   -- сколько не трогаем юнит после ручного приказа
Micro.tuning.arrive   = 48     -- радиус, в котором юнит считается дошедшим до слота
```

`refine` и `leap` — про следование за движущейся целью. Идущий герой сдвигает точку каждого
волка на ~30 единиц за 0.1 с; без этих двух настроек каждый такой сдвиг уходил отдельным
приказом — 10 в секунду на юнит. Сейчас мелкие уточнения идут не чаще раза в 0.3 с, а смена
цели или скачок точки — сразу.

## Пример

`micro_demo.lua` — готовый скрипт на пять хоткеев: за мной, охрана, строй по курсору,
атака по курсору, кайт. Меньше двухсот строк вместе с меню.

## Лицензия

Public domain. Делай что хочешь.

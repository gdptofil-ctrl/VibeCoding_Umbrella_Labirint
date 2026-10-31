---@diagnostic disable: undefined-global
--[[===========================================================================

  Micro demo -- pack control on five hotkeys.

  A complete, useful script in under two hundred lines, written to show what
  the Micro library takes off your hands. Works on anything you can command:
  Lycan wolves, Chen's creeps, the Spirit Bear, Brood spiderlings, Visage
  familiars, Arc Warden's double, dominated neutrals.

  Put micro.lua next to this file.

===========================================================================]]

local Micro = require("micro")

local script = {}
local ui = {}

-- Our claim on the units. Any other script using Micro with a lower priority
-- will leave them alone while we hold them, and pick them back up when we
-- release. Give your own script its own tag.
local TAG      = "micro_demo"
local PRIORITY = 60

local mode = nil

--=============================================================================
-- MENU
--=============================================================================

local function buildMenu()
    local tab = Menu.Create("Scripts", "Utility", "Micro Demo", "Main")
    if tab == nil or tab.Create == nil then return false end

    local main  = tab:Create("Основное", Enum.GroupSide.Left)
    local binds = tab:Create("Команды", Enum.GroupSide.Right)

    if main == nil or main.Switch == nil then return false end

    ui.enabled = main:Switch("Включить", true, "\u{f0e7}")
    ui.enabled:ToolTip("Управляет всеми юнитами под твоим контролем, кроме героя, курьера и вардов.")

    ui.overlay = main:Switch("Отладочный оверлей", false, "\u{f06e}")
    ui.overlay:ToolTip("Показывает, какое место занял каждый юнит и какое поведение им сейчас владеет.")

    ui.spread = main:Slider("Радиус строя", 150, 800, 300, "%d")
    ui.spread:ToolTip("На каком расстоянии от тебя держится пачка в режимах «за мной» и «охрана».")

    ui.follow = binds:Bind("За мной", Enum.ButtonCode.KEY_NONE, "\u{f0c0}")
    ui.follow:ToolTip("Юниты кольцом вокруг тебя и держат дистанцию на бегу.")

    ui.guard = binds:Bind("Охрана", Enum.ButtonCode.KEY_NONE, "\u{f132}")
    ui.guard:ToolTip("Строятся дугой перед тобой и сами встречают всё, что подходит близко.")

    ui.line = binds:Bind("Строй по курсору", Enum.ButtonCode.KEY_NONE, "\u{f7a4}")
    ui.line:ToolTip("Шеренга в точке под курсором, лицом к тебе.")

    ui.push = binds:Bind("Атака по курсору", Enum.ButtonCode.KEY_NONE, "\u{f05b}")
    ui.push:ToolTip("Идут в точку и убивают всё, что попадётся по дороге.")

    ui.kite = binds:Bind("Кайт", Enum.ButtonCode.KEY_NONE, "\u{f0e7}")
    ui.kite:ToolTip("Бьют ближайшую цель и отходят между ударами, не теряя атаку.")

    ui.release = binds:Bind("Отпустить", Enum.ButtonCode.KEY_NONE, "\u{f04d}")
    ui.release:ToolTip("Снимает управление. Юниты снова слушаются только тебя.")

    return true
end

--=============================================================================
-- HELPERS
--=============================================================================

local function enabled()
    return ui.enabled ~= nil and ui.enabled:Get()
end

-- Every selection starts here, so the tag and priority are never forgotten.
local function pack()
    return Micro.all():as(TAG, PRIORITY)
end

local function cursor()
    local point = Input.GetWorldCursorPos()
    if point == nil then return nil end
    return Micro.walkable(Micro.onGround(point))
end

local function pressed(bind)
    return bind ~= nil and bind:IsPressed()
end

--=============================================================================
-- COMMANDS
--=============================================================================

-- The point a mode was started on, for the two modes that need one.
local mark = nil

-- Applied every tick rather than once on the keypress. Adopting a behaviour a
-- unit already has is close to free, and re-applying is what makes the pack
-- self-healing: wolves resummoned ten seconds from now fall straight into
-- formation instead of standing where they spawned.
local function drive()
    if mode == nil then return end

    local hero = Micro.hero()
    if hero == nil then return end

    local group = pack()
    if group:empty() then return end

    local spread = ui.spread and ui.spread:Get() or 300

    if mode == "follow" then
        group:follow(hero, { radius = spread })

    elseif mode == "guard" then
        group:guard(hero, { radius = spread, range = 900 })

    elseif mode == "line" and mark ~= nil then
        -- Facing is recomputed each tick, so the rank keeps turning to face
        -- you as you walk around it.
        group:formation(mark, Micro.Formation.line(160), { facing = Entity.GetAbsOrigin(hero) })

    elseif mode == "push" and mark ~= nil then
        group:attackMove(mark)

    elseif mode == "kite" then
        -- No target given, so each unit picks the nearest thing it can hit.
        group:kite(nil, { search = 1200 })
    end
end

local function engage(name)
    if name == "release" then
        pack():release()
        mode, mark = nil, nil
        return
    end

    if name == "line" or name == "push" then
        local point = cursor()
        if point == nil then return end
        mark = point
    end

    mode = name
end

local function readBinds()
    if pressed(ui.release) then return "release" end
    if pressed(ui.follow)  then return "follow"  end
    if pressed(ui.guard)   then return "guard"   end
    if pressed(ui.line)    then return "line"    end
    if pressed(ui.push)    then return "push"    end
    if pressed(ui.kite)    then return "kite"    end
    return nil
end

--=============================================================================
-- LIFECYCLE
--=============================================================================

function script.OnScriptsLoaded()
    buildMenu()
end

function script.OnUpdate()
    if not enabled() then
        if mode ~= nil then
            pack():release()
            mode, mark = nil, nil
        end
        return
    end

    local hit = readBinds()

    -- Pressing the mode you are already in turns it off. One key, on and off.
    if hit ~= nil then
        engage(hit == mode and "release" or hit)
    end

    drive()

    Micro.debug = ui.overlay ~= nil and ui.overlay:Get()

    -- The only mandatory line. Everything the behaviours do happens here.
    Micro.update()
end

function script.OnDraw()
    Micro.draw()
end

-- Optional, but worth the two lines: tighter kiting and automation that gets
-- out of the way the moment you click something yourself.
function script.OnUnitAnimation(data)
    Micro.animation(data)
end

function script.OnPrepareUnitOrders(data)
    return Micro.orders(data)
end

function script.OnEntityDestroy(entity)
    Micro.forget(entity)
end

function script.OnGameEnd()
    Micro.reset()
    mode = nil
end

return script

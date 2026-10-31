---@diagnostic disable: undefined-global
--[[===========================================================================

  Micro 1.0 -- unit control library for Umbrella

  One file, no dependencies. Drop it next to your script and require it:

      local Micro = require("micro")

  Wire the lifecycle in. Only update() is mandatory; the rest buy you nicer
  behaviour and cost one line each:

      function script.OnUpdate()              Micro.update()         end
      function script.OnDraw()                Micro.draw()           end
      function script.OnUnitAnimation(data)   Micro.animation(data)  end
      function script.OnPrepareUnitOrders(d)  return Micro.orders(d) end
      function script.OnEntityDestroy(e)      Micro.forget(e)        end

  Then pick units and tell them what to do:

      Micro.summons():follow(Heroes.GetLocal(), { radius = 300 })
      Micro.byName("npc_dota_lone_druid_bear"):kite(target)
      Micro.all():formation(point, Micro.Formation.arc(600))
      Micro.all():release()

  What the library does for you, so your script does not have to:

    * at most one order per unit per tick, and identical orders are never
      resent -- no order spam, no stutter;
    * a unit the player just commanded by hand is left alone for a moment,
      so automation never wrestles the mouse;
    * two scripts driving the same creep settle it by priority instead of
      fighting frame by frame;
    * dead, dormant, stunned and not-yet-spawned units are skipped before
      an order is ever built.

  Public domain -- do what you like with it.

===========================================================================]]

local Micro = {}

Micro.VERSION = "1.0.0"

--=============================================================================
-- TUNING
--
-- Every number the library leans on, in one place. Change them from your
-- script with Micro.tuning.<name> = value if the defaults do not suit you.
--=============================================================================

local TUNING = {
    -- Smallest gap between two orders sent to the same unit.
    throttle   = 0.10,

    -- How long an identical order counts as still in force. Repeating it
    -- earlier than this is pure network noise, so we drop it.
    resend     = 0.35,

    -- A destination that only crept a little is a refinement, not a new
    -- order. Following a walking hero moves the slot ~30 units per 0.1 s,
    -- and without this every one of those nudges went out as a fresh order,
    -- ten a second per unit. Refinements go out at most this often...
    refine     = 0.30,

    -- ...unless the destination jumped at least this far, which is a real
    -- change of plan and is sent at once.
    leap       = 150,

    -- A destination has to move at least this far to count as a new order.
    slack      = 24,

    -- How long we keep our hands off a unit after the player ordered it by
    -- hand. Short enough to feel responsive, long enough not to fight a drag.
    yield      = 1.25,

    -- Default priority. Higher wins.
    priority   = 50,

    -- Distance at which a unit counts as standing on its slot.
    arrive     = 48,

    -- Ring step and ring count used when a slot lands in a cliff or a tree.
    probe      = 64,
    probeRings = 6,
}

Micro.tuning = TUNING

-- Identifier prefix stamped onto every order we send. It is what lets
-- Micro.orders() tell our own traffic apart from the player's clicks.
local ORDER_TAG = "micro"

--=============================================================================
-- SMALL HELPERS
--=============================================================================

local sqrt           = math.sqrt
local cos, sin       = math.cos, math.sin
local min, max, huge = math.min, math.max, math.huge
local pi             = math.pi
local insert, sort   = table.insert, table.sort

-- 5.1 spells it atan2 and 5.4 folds it into atan. Guessing wrong does not
-- raise an error, it silently returns the angle of y alone, so resolve it
-- once here instead of finding out from a formation that faces the wrong way.
local atan = math.atan2 or function (y, x) return math.atan(y, x) end

-- Guarded call for API surface that may be missing on a given build. Used at
-- boundaries only; wrapping every call would cost more than it protects.
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function now()
    return GameRules.GetGameTime() or 0
end

local function dist2d(a, b)
    if a == nil or b == nil then return huge end
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end

-- A point `reach` units away from `from` in the direction of `to`.
local function toward(from, to, reach)
    local dx, dy = to.x - from.x, to.y - from.y
    local length = sqrt(dx * dx + dy * dy)
    if length < 1 then return Vector(from.x, from.y, from.z) end
    return Vector(from.x + dx / length * reach, from.y + dy / length * reach, from.z)
end

local function angleOf(from, to)
    return atan(to.y - from.y, to.x - from.x)
end

-- GetGroundZ takes two numbers, not a vector. Passing the vector fails
-- quietly inside the guarded call and the height is simply never applied,
-- which is the kind of bug that never announces itself.
local function onGround(point)
    local z = call(World.GetGroundZ, point.x, point.y)
    if z == nil then return point end
    return Vector(point.x, point.y, z)
end

-- Nearest spot a unit can actually stand on. Slots built from pure geometry
-- land in cliffs and trees often enough that this has to be automatic, or
-- every formation quietly loses a unit to a rock.
local function walkable(point)
    if type(GridNav) ~= "table" or type(GridNav.IsTraversable) ~= "function" then
        return point
    end

    if GridNav.IsTraversable(point) then return point end

    for ring = 1, TUNING.probeRings do
        local reach = TUNING.probe * ring
        for step = 0, 7 do
            local angle = step * pi / 4
            local probe = Vector(point.x + cos(angle) * reach, point.y + sin(angle) * reach, point.z)
            if GridNav.IsTraversable(probe) then return probe end
        end
    end

    return point
end

local function origin(npc)
    return call(Entity.GetAbsOrigin, npc)
end

Micro.walkable = walkable
Micro.onGround = onGround
Micro.toward   = toward
Micro.distance = dist2d

--=============================================================================
-- ORDER AND STATE ENUMS
--
-- Resolved once, defensively: a build that renames or drops one of these
-- should cost you that single order, not load-time death.
--=============================================================================

local ORDER, ISSUER, STATE = {}, nil, {}

do
    local U = (type(Enum) == "table" and Enum.UnitOrder) or {}

    ORDER.move       = U.DOTA_UNIT_ORDER_MOVE_TO_POSITION
    ORDER.moveTarget = U.DOTA_UNIT_ORDER_MOVE_TO_TARGET
    ORDER.attack     = U.DOTA_UNIT_ORDER_ATTACK_TARGET
    ORDER.attackMove = U.DOTA_UNIT_ORDER_ATTACK_MOVE
    ORDER.hold       = U.DOTA_UNIT_ORDER_HOLD_POSITION
    ORDER.stop       = U.DOTA_UNIT_ORDER_STOP
    ORDER.castNone   = U.DOTA_UNIT_ORDER_CAST_NO_TARGET
    ORDER.castTarget = U.DOTA_UNIT_ORDER_CAST_TARGET
    ORDER.castPoint  = U.DOTA_UNIT_ORDER_CAST_POSITION

    local I = (type(Enum) == "table" and Enum.PlayerOrderIssuer) or {}
    ISSUER = I.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

    local S = (type(Enum) == "table" and Enum.ModifierState) or {}
    STATE.stunned     = S.MODIFIER_STATE_STUNNED
    STATE.hexed       = S.MODIFIER_STATE_HEXED
    STATE.outOfGame   = S.MODIFIER_STATE_OUT_OF_GAME
    STATE.commandless = S.MODIFIER_STATE_COMMAND_RESTRICTED
    STATE.attackImmune= S.MODIFIER_STATE_ATTACK_IMMUNE
    STATE.invulnerable= S.MODIFIER_STATE_INVULNERABLE
end

local function hasState(npc, state)
    if state == nil then return false end
    return call(NPC.HasState, npc, state) == true
end

-- A unit that cannot be commanded at all right now. Worth checking before we
-- build an order rather than after the server drops it.
local function muted(npc)
    return hasState(npc, STATE.stunned)
        or hasState(npc, STATE.hexed)
        or hasState(npc, STATE.outOfGame)
        or hasState(npc, STATE.commandless)
end

--=============================================================================
-- CONTEXT
--
-- The local player, hero and player id, refreshed once per tick instead of
-- once per call site.
--=============================================================================

local ctx = {
    tick   = 0,
    time   = 0,
    player = nil,
    hero   = nil,
    pid    = -1,
    stamp  = -1,
}

local function context()
    if ctx.stamp == ctx.tick then return ctx end

    ctx.stamp  = ctx.tick
    ctx.time   = now()
    ctx.player = call(Players.GetLocal)
    ctx.hero   = call(Heroes.GetLocal)
    ctx.pid    = ctx.player and call(Player.GetPlayerID, ctx.player) or -1

    return ctx
end

function Micro.hero()   return context().hero   end
function Micro.player() return context().player end
function Micro.time()   return context().time   end

--=============================================================================
-- UNIT REGISTRY
--
-- One record per controllable unit, keyed by entity index so a unit keeps its
-- state -- slot, behaviour, order history -- across ticks.
--=============================================================================

local store  = {}   -- [entity index] = record
local roster = {}   -- array of live records, rebuilt each tick
local rosterStamp = -1

local function isLive(npc)
    return npc ~= nil
        and call(Entity.IsEntity, npc) == true
        and call(Entity.IsAlive, npc) == true
        and call(Entity.IsDormant, npc) ~= true
end

-- What kind of thing this is, or nil when it is not ours to command.
-- The awkward cases are real: Arc Warden's double, Meepo's clones and Dazzle's
-- projection all read as heroes or illusions while being perfectly orderable.
local function classify(npc, pid, hero)
    if npc == nil or npc == hero then return nil end
    if not isLive(npc) then return nil end
    if call(NPC.IsWaitingToSpawn, npc) == true then return nil end
    if call(NPC.IsControllableByPlayer, npc, pid) ~= true then return nil end

    if call(NPC.IsCourier, npc) == true then return "courier" end
    if call(NPC.IsWard, npc) == true then return "ward" end

    if call(NPC.IsMeepoClone, npc) == true then return "clone" end
    if call(NPC.HasModifier, npc, "modifier_arc_warden_tempest_double") == true then return "clone" end
    if call(NPC.HasModifier, npc, "modifier_dazzle_nothl_projection_soul_clone") == true then return "clone" end

    if call(NPC.IsIllusion, npc) == true then return "illusion" end
    if call(NPC.IsHero, npc) == true then return "hero" end

    -- Buildings and immobile things do not deserve a slot in a formation, but
    -- anything that can move or shoot is fair game whatever the engine calls it.
    if call(NPC.IsStructure, npc) == true then
        local speed  = call(NPC.GetMoveSpeed, npc) or 0
        local damage = call(NPC.GetTrueDamage, npc) or 0
        if speed <= 0 and damage <= 0 then return nil end
    end

    return "summon"
end

local function record(npc, kind)
    local index = call(Entity.GetIndex, npc)
    if index == nil then return nil end

    local unit = store[index]

    if unit == nil then
        unit = {
            npc      = npc,
            index    = index,
            kind     = kind,
            nextAt   = 0,     -- throttle gate
            lastSig  = nil,   -- signature of the order in force
            lastAt   = 0,
            manual   = 0,     -- player took over until this time
            behavior = nil,
            slot     = nil,   -- assigned formation slot, when any
            attack   = { readyAt = 0, releaseAt = 0, swinging = false },
        }
        store[index] = unit
    end

    unit.npc  = npc
    unit.kind = kind

    return unit
end

local function rebuild()
    if rosterStamp == ctx.tick then return roster end
    rosterStamp = ctx.tick

    local c = context()
    roster = {}

    if c.pid < 0 then return roster end

    local all  = call(NPCs.GetAll) or {}
    local seen = {}

    for _, npc in pairs(all) do
        local kind = classify(npc, c.pid, c.hero)
        if kind ~= nil then
            local unit = record(npc, kind)
            if unit ~= nil then
                seen[unit.index] = true
                insert(roster, unit)
            end
        end
    end

    -- Forget units that died or left. Their behaviours go with them, which is
    -- what you want: a re-summoned wolf starts clean rather than inheriting
    -- the orders of the one that died.
    for index in pairs(store) do
        if not seen[index] then store[index] = nil end
    end

    sort(roster, function (left, right) return left.index < right.index end)

    return roster
end

function Micro.forget(entity)
    local index = call(Entity.GetIndex, entity)
    if index ~= nil then store[index] = nil end
end

--=============================================================================
-- ORDER LAYER
--
-- Everything funnels through issue(). It is the only place that talks to
-- Player.PrepareUnitOrders, and the only place that decides an order is not
-- worth sending.
--=============================================================================

local stats = { sent = 0, suppressed = 0, deferred = 0 }

Micro.stats = stats

-- An order is "the same order" when it would produce the same behaviour.
-- Positions are quantised so that a destination drifting by a few units --
-- which happens constantly when you follow a moving hero -- does not count
-- as a fresh command.
local function signature(kind, target, position, ability)
    local parts = kind

    if target ~= nil then
        parts = parts .. ":" .. tostring(call(Entity.GetIndex, target) or 0)
    end

    if position ~= nil then
        local grid = max(1, TUNING.slack)
        parts = parts .. ":" .. math.floor(position.x / grid) .. "," .. math.floor(position.y / grid)
    end

    if ability ~= nil then
        parts = parts .. ":" .. tostring(call(Ability.GetName, ability) or "?")
    end

    return parts
end

-- Raised while we are inside PrepareUnitOrders. The order callback fires from
-- in there, and an order of ours that came back unrecognised would look like
-- the player grabbing the unit -- which would mute us, every tick, forever.
-- The identifier normally settles it; this flag covers the fallback below,
-- which has no room to carry one.
local sending = false

-- The long form carries an identifier, which is what Micro.orders() matches
-- on. Older builds take the short form only, so fall back rather than fail.
local function send(player, kind, target, position, ability, npc, queue, tag)
    local identifier = ORDER_TAG .. ":" .. (tag or "default")

    sending = true

    local ok = pcall(
        Player.PrepareUnitOrders,
        player, kind, target, position or Vector(0, 0, 0), ability,
        ISSUER, npc, queue == true, false, false, true, identifier, false
    )

    if not ok then
        ok = pcall(
            Player.PrepareUnitOrders,
            player, kind, target, position or Vector(0, 0, 0), ability,
            ISSUER, npc, queue == true, false
        )
    end

    sending = false

    return ok
end

-- spec = { kind, target, position, ability, queue, priority, tag, force }
local function issue(unit, spec)
    local c = context()

    if c.player == nil or unit == nil or spec.kind == nil then
        return false
    end

    local npc = unit.npc
    if not isLive(npc) then return false end

    local time = c.time

    if not spec.force then
        -- The player is driving. Hands off.
        if time < unit.manual then
            stats.suppressed = stats.suppressed + 1
            return false
        end

        -- Somebody with a stronger claim owns this unit.
        local owner = unit.behavior
        local priority = spec.priority or TUNING.priority
        if owner ~= nil and owner.priority > priority and owner.tag ~= spec.tag then
            stats.suppressed = stats.suppressed + 1
            return false
        end

        if time < unit.nextAt then
            stats.suppressed = stats.suppressed + 1
            return false
        end

        if muted(npc) then
            stats.suppressed = stats.suppressed + 1
            return false
        end
    end

    local sig = signature(spec.kind, spec.target, spec.position, spec.ability)

    if not spec.force and sig == unit.lastSig and (time - unit.lastAt) < TUNING.resend then
        stats.suppressed = stats.suppressed + 1
        return false
    end

    -- Same kind of order, same target, destination only crept: a refinement.
    -- Rate-limit those separately from real changes of plan.
    if not spec.force
        and spec.position ~= nil and unit.lastPos ~= nil
        and spec.kind == unit.lastKind and spec.target == unit.lastTarget
        and (time - unit.lastAt) < TUNING.refine
        and dist2d(spec.position, unit.lastPos) < TUNING.leap
    then
        stats.suppressed = stats.suppressed + 1
        return false
    end

    -- The cheat keeps its own per-tick order budget and runs a spam filter
    -- on top. Spending past it gets orders dropped or delayed server-side, so
    -- ask first and leave the order for next tick instead. Checked last, on
    -- purpose: only an order we were really about to send should cost a call.
    if not spec.force and call(Humanizer and Humanizer.IsSafeToCastOrder) == false then
        stats.deferred = stats.deferred + 1
        return false
    end

    if not send(c.player, spec.kind, spec.target, spec.position, spec.ability,
                npc, spec.queue, spec.tag) then
        return false
    end

    unit.lastSig    = sig
    unit.lastAt     = time
    unit.lastKind   = spec.kind
    unit.lastTarget = spec.target
    unit.lastPos    = spec.position
    unit.nextAt  = time + (spec.throttle or TUNING.throttle)
    stats.sent   = stats.sent + 1

    return true
end

Micro.issue = issue

--=============================================================================
-- ATTACK CLOCK
--
-- Kiting needs to know when a unit may attack again and when its current
-- swing has landed. OnUnitAnimation gives both precisely; without it we fall
-- back to watching IsAttacking flip, which is coarser but still usable.
--=============================================================================

local function attackPoint(npc, castpoint)
    if castpoint ~= nil and castpoint > 0 then return castpoint end

    local base  = call(NPC.GetAttackAnimPoint, npc) or 0.3
    local speed = call(NPC.GetAttackSpeed, npc) or 1

    return base / max(0.2, speed)
end

-- Fed from script.OnUnitAnimation. Optional, but kiting is noticeably tighter
-- with it: the swing is timed from the animation the server actually started,
-- not from when we noticed.
function Micro.animation(data)
    if type(data) ~= "table" or data.unit == nil then return end

    local index = call(Entity.GetIndex, data.unit)
    local unit  = index and store[index]
    if unit == nil then return end
    if call(NPC.IsAttacking, data.unit) ~= true then return end

    local time  = now()
    local start = time - max(0, data.lag_compensation_time or 0)
    local point = attackPoint(data.unit, data.castpoint)
    local cycle = call(NPC.GetSecondsPerAttack, data.unit, false) or 1.7

    unit.attack.releaseAt = start + point
    unit.attack.readyAt   = start + cycle
    unit.attack.swinging  = true
end

-- Coarse fallback for scripts that do not forward the animation callback.
-- IsAttacking stays true across back-to-back swings, so an edge alone would
-- time the first attack and then never re-arm. Re-arming once the previous
-- cycle should have finished keeps the estimate honest without the callback.
local function observeAttack(unit, time)
    local attacking = call(NPC.IsAttacking, unit.npc) == true

    if attacking and (not unit.attack.swinging or time >= unit.attack.readyAt) then
        local point = attackPoint(unit.npc)
        local cycle = call(NPC.GetSecondsPerAttack, unit.npc, false) or 1.7
        unit.attack.releaseAt = time + point
        unit.attack.readyAt   = time + cycle
        unit.attack.swinging  = true
    elseif not attacking and time > unit.attack.releaseAt then
        unit.attack.swinging = false
    end
end

--=============================================================================
-- TARGETING
--=============================================================================

local function attackable(npc, target)
    return isLive(target)
        and call(Entity.IsSameTeam, npc, target) ~= true
        and call(NPC.IsVisible, target) == true
        and not hasState(target, STATE.attackImmune)
        and not hasState(target, STATE.invulnerable)
        and not hasState(target, STATE.outOfGame)
end

Micro.attackable = attackable

local function reach(npc)
    local base  = call(NPC.GetAttackRange, npc) or 0
    local bonus = call(NPC.GetAttackRangeBonus, npc) or 0
    local hull  = call(NPC.GetHullRadius, npc) or 0
    return base + bonus + hull
end

Micro.reach = reach

-- A radius scan costs real time, and a pack of six wolves guarding the same
-- hero would otherwise run six identical ones every tick. Round the query and
-- keep the answer for the rest of the tick.
local scanCache, scanStamp = {}, -1

local function scan(around, radius)
    local c = context()
    if c.hero == nil then return {} end

    if scanStamp ~= ctx.tick then
        scanCache, scanStamp = {}, ctx.tick
    end

    local key = math.floor(around.x / 128) .. "," .. math.floor(around.y / 128)
                .. ":" .. math.floor(radius / 128)

    local hit = scanCache[key]

    if hit == nil then
        hit = call(NPCs.InRadius, around, radius, call(Entity.GetTeamNum, c.hero),
                   Enum.TeamType and Enum.TeamType.TEAM_ENEMY, true, true) or {}
        scanCache[key] = hit
    end

    return hit
end

-- Nearest enemy this unit could sensibly shoot, within `radius` of `around`.
local function enemyNear(npc, around, radius)
    local found = scan(around, radius)

    local best, bestDistance = nil, huge

    for _, candidate in pairs(found) do
        if attackable(npc, candidate) then
            local gap = dist2d(around, origin(candidate))
            if gap < bestDistance then
                best, bestDistance = candidate, gap
            end
        end
    end

    return best, bestDistance
end

Micro.enemyNear = enemyNear

--=============================================================================
-- FORMATIONS
--
-- A shape is a function (count, center, facing) -> array of points. Slots are
-- snapped to walkable ground by the caller, not here, so shapes stay pure and
-- easy to write yourself.
--=============================================================================

local Formation = {}

-- A straight rank, perpendicular to `facing`.
function Formation.line(spacing)
    spacing = spacing or 160

    return function (count, center, facing)
        local slots = {}
        local side  = (facing or 0) + pi / 2
        local half  = (count - 1) / 2

        for i = 1, count do
            local offset = (i - 1 - half) * spacing
            insert(slots, Vector(center.x + cos(side) * offset,
                                 center.y + sin(side) * offset,
                                 center.z))
        end

        return slots
    end
end

-- A bow centred on `facing`. The default spread is a half circle, which reads
-- as a screen in front of whatever you are protecting.
function Formation.arc(radius, spread)
    radius = radius or 400
    spread = spread or pi

    return function (count, center, facing)
        local slots = {}
        local start = (facing or 0) - spread / 2
        local step  = count > 1 and spread / (count - 1) or 0

        for i = 1, count do
            local angle = start + step * (i - 1)
            insert(slots, Vector(center.x + cos(angle) * radius,
                                 center.y + sin(angle) * radius,
                                 center.z))
        end

        return slots
    end
end

function Formation.circle(radius)
    radius = radius or 400

    return function (count, center, facing)
        local slots = {}
        local step  = pi * 2 / max(1, count)

        for i = 1, count do
            local angle = (facing or 0) + step * (i - 1)
            insert(slots, Vector(center.x + cos(angle) * radius,
                                 center.y + sin(angle) * radius,
                                 center.z))
        end

        return slots
    end
end

function Formation.grid(spacing, columns)
    spacing = spacing or 160

    return function (count, center, facing)
        local slots = {}
        local cols  = columns or math.ceil(sqrt(count))
        local rows  = math.ceil(count / cols)
        local side  = (facing or 0) + pi / 2
        local ahead = (facing or 0)

        for i = 1, count do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local dx  = (col - (cols - 1) / 2) * spacing
            local dy  = (row - (rows - 1) / 2) * spacing

            insert(slots, Vector(center.x + cos(side) * dx + cos(ahead) * dy,
                                 center.y + sin(side) * dx + sin(ahead) * dy,
                                 center.z))
        end

        return slots
    end
end

-- A V opening away from `facing`, the classic escort shape.
function Formation.wedge(spacing, angle)
    spacing = spacing or 150
    angle   = angle or (pi / 4)

    return function (count, center, facing)
        local slots = {}
        local heading = facing or 0

        for i = 1, count do
            local rank = math.ceil(i / 2)
            local side = (i % 2 == 0) and 1 or -1
            local away = heading + pi + side * angle
            insert(slots, Vector(center.x + cos(away) * spacing * rank,
                                 center.y + sin(away) * spacing * rank,
                                 center.z))
        end

        return slots
    end
end

-- Wrap your own generator so it gets slot assignment and terrain snapping.
function Formation.custom(fn)
    return fn
end

Micro.Formation = Formation

-- Hand out slots so that nobody crosses anybody. Greedy nearest-first is not
-- optimal, but it is stable and cheap, and stability matters more here: a unit
-- that swaps slots with its neighbour every tick never arrives anywhere.
local function assign(units, slots)
    local taken, result = {}, {}

    -- Keep the slot a unit already holds when it is still on offer.
    for _, unit in ipairs(units) do
        local held = unit.slotIndex
        if held ~= nil and slots[held] ~= nil and not taken[held] then
            taken[held]  = true
            result[unit] = held
        end
    end

    for _, unit in ipairs(units) do
        if result[unit] == nil then
            local where = origin(unit.npc)
            local best, bestDistance = nil, huge

            for index, slot in ipairs(slots) do
                if not taken[index] then
                    local gap = dist2d(where, slot)
                    if gap < bestDistance then
                        best, bestDistance = index, gap
                    end
                end
            end

            if best ~= nil then
                taken[best]  = true
                result[unit] = best
            end
        end
    end

    for unit, index in pairs(result) do
        unit.slotIndex = index
        unit.slot      = slots[index]
    end

    return result
end

--=============================================================================
-- BEHAVIOURS
--
-- A behaviour is a table with tick(unit, self, time). It owns the unit until
-- something with a higher priority replaces it or the unit is released.
-- Writing your own is two lines plus the logic -- see Micro.behaviour().
--=============================================================================

local behaviours = {}

local function anchorPoint(behavior)
    local anchor = behavior.opts.anchor

    if anchor == nil then return behavior.opts.point end
    if type(anchor) == "table" and anchor.x ~= nil then return anchor end

    if isLive(anchor) then return origin(anchor) end

    return nil
end

-- Stand still and shoot what wanders in.
behaviours.hold = {
    label = "hold",
    tick  = function (unit, behavior)
        if ORDER.hold ~= nil then
            issue(unit, { kind = ORDER.hold, priority = behavior.priority, tag = behavior.tag })
        else
            issue(unit, {
                kind     = ORDER.move,
                position = origin(unit.npc),
                priority = behavior.priority,
                tag      = behavior.tag,
            })
        end
    end,
}

-- Keep station on a hero or a point. Units spread over slots instead of
-- stacking on one pixel, which is the difference between a pack and a blob.
behaviours.follow = {
    label = "follow",
    tick  = function (unit, behavior, time)
        local point = anchorPoint(behavior)
        if point == nil then return end

        local target = unit.slot or point
        local gap    = dist2d(origin(unit.npc), target)

        if gap <= (behavior.opts.arrive or TUNING.arrive) then
            return
        end

        issue(unit, {
            kind     = ORDER.move,
            position = target,
            priority = behavior.priority,
            tag      = behavior.tag,
        })
    end,
}

-- Follow, but engage anything hostile that comes near the thing being guarded,
-- and go back to station when the coast is clear.
behaviours.guard = {
    label = "guard",
    tick  = function (unit, behavior, time)
        local point = anchorPoint(behavior)
        if point == nil then return end

        local range  = behavior.opts.range or 900
        local leash  = behavior.opts.leash or (range + 400)
        local target = behavior.target

        if not attackable(unit.npc, target) or dist2d(point, origin(target)) > leash then
            target = enemyNear(unit.npc, point, range)
            behavior.target = target
        end

        if target ~= nil then
            issue(unit, {
                kind     = ORDER.attack,
                target   = target,
                position = origin(target),
                priority = behavior.priority,
                tag      = behavior.tag,
            })
            return
        end

        local station = unit.slot or point
        if dist2d(origin(unit.npc), station) > (behavior.opts.arrive or TUNING.arrive) then
            issue(unit, {
                kind     = ORDER.move,
                position = station,
                priority = behavior.priority,
                tag      = behavior.tag,
            })
        end
    end,
}

-- Hold a shape around a point. The shape is re-evaluated every tick, so the
-- point may move and the formation follows it.
behaviours.formation = {
    label = "formation",
    tick  = function (unit, behavior, time)
        local target = unit.slot
        if target == nil then return end

        if dist2d(origin(unit.npc), target) <= (behavior.opts.arrive or TUNING.arrive) then
            return
        end

        issue(unit, {
            kind     = ORDER.move,
            position = target,
            priority = behavior.priority,
            tag      = behavior.tag,
        })
    end,
}

-- Advance on a point, stopping to kill whatever is in range on the way.
behaviours.attackMove = {
    label = "attack-move",
    tick  = function (unit, behavior, time)
        local point = anchorPoint(behavior)
        if point == nil then return end

        local here   = origin(unit.npc)
        local radius = reach(unit.npc) + (behavior.opts.aggro or 200)
        local target = behavior.target

        if not attackable(unit.npc, target) or dist2d(here, origin(target)) > radius then
            target = enemyNear(unit.npc, here, radius)
            behavior.target = target
        end

        if target ~= nil then
            issue(unit, {
                kind     = ORDER.attack,
                target   = target,
                position = origin(target),
                priority = behavior.priority,
                tag      = behavior.tag,
            })
            return
        end

        if dist2d(here, point) > (behavior.opts.arrive or TUNING.arrive) then
            issue(unit, {
                kind     = ORDER.move,
                position = point,
                priority = behavior.priority,
                tag      = behavior.tag,
            })
        end
    end,
}

-- Attack, then use the backswing to reposition. The whole trick is knowing
-- when the swing has landed: ordering a move before that cancels the attack
-- and the unit does nothing at all, which is how most hand-rolled kiting
-- ends up slower than just right-clicking.
behaviours.kite = {
    label = "kite",
    tick  = function (unit, behavior, time)
        local target = behavior.opts.target

        if type(target) == "function" then target = target(unit.npc) end
        if not attackable(unit.npc, target) then
            target = enemyNear(unit.npc, origin(unit.npc), behavior.opts.search or 1200)
        end

        if target == nil then return end

        local npc    = unit.npc
        local here   = origin(npc)
        local there  = origin(target)
        local radius = reach(npc)

        -- Ready to swing and close enough: swing. The swing flag is left to
        -- the attack clock -- setting it here would hide the real animation
        -- from the detector and the cycle would never be timed again.
        if time >= unit.attack.readyAt and dist2d(here, there) <= radius then
            issue(unit, {
                kind     = ORDER.attack,
                target   = target,
                position = there,
                priority = behavior.priority,
                tag      = behavior.tag,
            })
            return
        end

        -- Mid-swing: do not touch it, or the attack is thrown away.
        if unit.attack.swinging and time < unit.attack.releaseAt then
            return
        end

        -- Swing has landed and the next one is not ready: use the gap.
        -- Both "too close" and "too far" want the same thing: the spot at
        -- `hold` from the target, on our side of it. The deadband keeps a unit
        -- from twitching when it is already standing about right.
        local hold = behavior.opts.range or (radius - 60)
        local gap  = dist2d(here, there)
        local goal

        if behavior.opts.retreat ~= nil then
            goal = behavior.opts.retreat
            if type(goal) == "function" then goal = goal(npc) end
        elseif math.abs(gap - hold) > (behavior.opts.deadband or 60) then
            goal = toward(there, here, hold)
        else
            return
        end

        if goal == nil then return end

        issue(unit, {
            kind     = ORDER.move,
            position = walkable(onGround(goal)),
            priority = behavior.priority,
            tag      = behavior.tag,
        })
    end,
}

-- Walk a loop of points. Useful for spiders on a map edge, wolves on a ward
-- route, anything that should keep moving without supervision.
behaviours.patrol = {
    label = "patrol",
    tick  = function (unit, behavior, time)
        local route = behavior.opts.route
        if type(route) ~= "table" or #route == 0 then return end

        behavior.leg = behavior.leg or 1
        local point  = route[behavior.leg]

        if dist2d(origin(unit.npc), point) <= (behavior.opts.arrive or 120) then
            behavior.leg = behavior.leg + 1
            if behavior.leg > #route then
                behavior.leg = behavior.opts.loop == false and #route or 1
            end
            point = route[behavior.leg]
        end

        issue(unit, {
            kind     = ORDER.move,
            position = point,
            priority = behavior.priority,
            tag      = behavior.tag,
        })
    end,
}

-- Register your own. `spec.tick(unit, behavior, time)` is called once per tick
-- for every unit that carries it; `unit.npc` is the entity, `behavior.opts` is
-- whatever you passed in.
function Micro.behaviour(name, spec)
    behaviours[name] = spec
    return spec
end

Micro.behavior  = Micro.behaviour
Micro.behaviours = behaviours

--=============================================================================
-- GROUP
--
-- An immutable selection of units. Filters return a new group, orders and
-- behaviours act on the current one.
--=============================================================================

local Group = {}
Group.__index = Group

local function newGroup(list, opts)
    return setmetatable({
        list = list or {},
        opts = opts or { priority = TUNING.priority, tag = "default" },
    }, Group)
end

local function derive(group, list)
    return newGroup(list, group.opts)
end

--- Selection ---------------------------------------------------------------

function Group:filter(predicate)
    local kept = {}
    for _, unit in ipairs(self.list) do
        if predicate(unit.npc, unit) then insert(kept, unit) end
    end
    return derive(self, kept)
end

function Group:kind(...)
    local wanted = {}
    for _, name in ipairs({ ... }) do wanted[name] = true end
    return self:filter(function (_, unit) return wanted[unit.kind] == true end)
end

function Group:name(...)
    local wanted = {}
    for _, name in ipairs({ ... }) do wanted[name] = true end
    return self:filter(function (npc)
        return wanted[call(NPC.GetUnitName, npc) or ""] == true
    end)
end

function Group:matching(pattern)
    return self:filter(function (npc)
        local name = call(NPC.GetUnitName, npc) or ""
        return name:find(pattern) ~= nil
    end)
end

function Group:exclude(npc)
    return self:filter(function (other) return other ~= npc end)
end

function Group:within(point, radius)
    return self:filter(function (npc)
        return dist2d(origin(npc), point) <= radius
    end)
end

function Group:ranged()
    return self:filter(function (npc) return call(NPC.IsRanged, npc) == true end)
end

function Group:melee()
    return self:filter(function (npc) return call(NPC.IsRanged, npc) ~= true end)
end

function Group:idle()
    return self:filter(function (npc)
        return call(NPC.IsAttacking, npc) ~= true and call(NPC.IsRunning, npc) ~= true
    end)
end

function Group:free()
    local time = context().time
    return self:filter(function (_, unit) return time >= unit.manual end)
end

function Group:sorted(comparator)
    local copy = {}
    for i, unit in ipairs(self.list) do copy[i] = unit end
    sort(copy, function (a, b) return comparator(a.npc, b.npc) end)
    return derive(self, copy)
end

function Group:nearest(point, count)
    local ranked = self:sorted(function (a, b)
        return dist2d(origin(a), point) < dist2d(origin(b), point)
    end)
    return count and ranked:limit(count) or ranked
end

function Group:limit(count)
    local kept = {}
    for i = 1, min(count, #self.list) do kept[i] = self.list[i] end
    return derive(self, kept)
end

--- Inspection --------------------------------------------------------------

function Group:count()   return #self.list end
function Group:empty()   return #self.list == 0 end

function Group:first()
    local unit = self.list[1]
    return unit and unit.npc or nil
end

function Group:units()
    local out = {}
    for i, unit in ipairs(self.list) do out[i] = unit.npc end
    return out
end

function Group:each(fn)
    for _, unit in ipairs(self.list) do fn(unit.npc, unit) end
    return self
end

function Group:center()
    if #self.list == 0 then return nil end

    local x, y, z = 0, 0, 0
    for _, unit in ipairs(self.list) do
        local point = origin(unit.npc)
        x, y, z = x + point.x, y + point.y, z + point.z
    end

    local n = #self.list
    return Vector(x / n, y / n, z / n)
end

-- Nobody in the group can outrun the slowest member, so this is the speed a
-- formation may travel at without tearing itself apart.
function Group:slowest()
    local slowest = nil
    for _, unit in ipairs(self.list) do
        local speed = call(NPC.GetMoveSpeed, unit.npc)
        if speed and speed > 0 and (slowest == nil or speed < slowest) then
            slowest = speed
        end
    end
    return slowest or 300
end

--- Claims ------------------------------------------------------------------

-- Tag and priority travel with the group into every order it sends. Give your
-- script its own tag and a priority that reflects how much it should win.
function Group:as(tag, priority)
    return newGroup(self.list, {
        tag      = tag or self.opts.tag,
        priority = priority or self.opts.priority,
    })
end

function Group:priority(value)
    return self:as(self.opts.tag, value)
end

--- One-shot orders ---------------------------------------------------------

local function command(group, spec)
    spec.priority = spec.priority or group.opts.priority
    spec.tag      = spec.tag or group.opts.tag

    local sent = 0
    for _, unit in ipairs(group.list) do
        if issue(unit, spec) then sent = sent + 1 end
    end

    return sent
end

function Group:move(point, queue)
    return command(self, { kind = ORDER.move, position = walkable(onGround(point)), queue = queue })
end

function Group:moveRaw(point, queue)
    return command(self, { kind = ORDER.move, position = point, queue = queue })
end

function Group:attack(target, queue)
    if not isLive(target) then return 0 end
    return command(self, {
        kind     = ORDER.attack,
        target   = target,
        position = origin(target),
        queue    = queue,
    })
end

function Group:stop()
    self:release()
    if ORDER.stop == nil then return 0 end
    return command(self, { kind = ORDER.stop, force = true })
end

function Group:cast(ability, targetOrPoint, queue)
    local sent = 0

    for _, unit in ipairs(self.list) do
        local spell = ability

        if type(ability) == "string" then
            spell = call(NPC.GetAbility, unit.npc, ability)
        end

        -- IsCastable weighs mana too, which is what you actually want; not
        -- every build exposes it, so fall back to the readiness flag alone.
        local castable = call(Ability.IsCastable, spell, call(NPC.GetMana, unit.npc) or 0)
        if castable == nil then castable = call(Ability.IsReady, spell) end

        if spell ~= nil and castable ~= false then
            local spec = { priority = self.opts.priority, tag = self.opts.tag, queue = queue, ability = spell }

            if targetOrPoint == nil then
                spec.kind = ORDER.castNone
            elseif type(targetOrPoint) == "table" and targetOrPoint.x ~= nil then
                spec.kind, spec.position = ORDER.castPoint, targetOrPoint
            else
                spec.kind, spec.target, spec.position = ORDER.castTarget, targetOrPoint, origin(targetOrPoint)
            end

            if issue(unit, spec) then sent = sent + 1 end
        end
    end

    return sent
end

--- Behaviours --------------------------------------------------------------

local function adopt(group, name, opts)
    local spec = behaviours[name]
    if spec == nil then return group end

    for _, unit in ipairs(group.list) do
        local current = unit.behavior

        -- Leave a unit alone when something with a stronger claim holds it,
        -- unless we are that something coming back with new options.
        if current == nil
            or current.priority <= group.opts.priority
            or current.tag == group.opts.tag
        then
            if current == nil or current.name ~= name or current.tag ~= group.opts.tag then
                unit.behavior = {
                    name     = name,
                    spec     = spec,
                    opts     = opts or {},
                    priority = group.opts.priority,
                    tag      = group.opts.tag,
                }
            else
                -- Same behaviour, same owner: keep whatever state it has
                -- built up (its current target, its leg of the patrol) and
                -- just refresh the terms.
                current.opts     = opts or current.opts
                current.priority = group.opts.priority
            end
        end
    end

    return group
end

function Group:hold()
    return adopt(self, "hold", {})
end

function Group:follow(anchor, opts)
    opts = opts or {}
    opts.anchor = anchor
    opts.shape  = opts.shape or Formation.circle(opts.radius or 250)
    return adopt(self, "follow", opts)
end

function Group:guard(anchor, opts)
    opts = opts or {}
    opts.anchor = anchor
    opts.shape  = opts.shape or Formation.arc(opts.radius or 350)
    return adopt(self, "guard", opts)
end

function Group:formation(point, shape, opts)
    opts = opts or {}
    opts.anchor = point
    opts.shape  = shape or Formation.line()
    return adopt(self, "formation", opts)
end

function Group:attackMove(point, opts)
    opts = opts or {}
    opts.anchor = point
    return adopt(self, "attackMove", opts)
end

function Group:kite(target, opts)
    opts = opts or {}
    opts.target = target
    return adopt(self, "kite", opts)
end

function Group:patrol(route, opts)
    opts = opts or {}
    opts.route = route
    return adopt(self, "patrol", opts)
end

function Group:behave(name, opts)
    return adopt(self, name, opts)
end

-- Give the units back. Anything still holding them at a lower priority may
-- pick them up again next tick, which is exactly what you want when a combo
-- script hands control back to a farming script.
function Group:release()
    for _, unit in ipairs(self.list) do
        if unit.behavior == nil
            or unit.behavior.priority <= self.opts.priority
            or unit.behavior.tag == self.opts.tag
        then
            unit.behavior  = nil
            unit.slot      = nil
            unit.slotIndex = nil
        end
    end
    return self
end

--=============================================================================
-- SELECTION ENTRY POINTS
--=============================================================================

local function collect(predicate)
    rebuild()

    local list = {}
    for _, unit in ipairs(roster) do
        if predicate == nil or predicate(unit) then insert(list, unit) end
    end

    return newGroup(list)
end

-- Everything you can order that is not you, the courier or a ward. This is
-- what you want nine times out of ten.
function Micro.all()
    return collect(function (unit)
        return unit.kind ~= "courier" and unit.kind ~= "ward"
    end)
end

function Micro.summons()
    return collect(function (unit) return unit.kind == "summon" end)
end

function Micro.clones()
    return collect(function (unit) return unit.kind == "clone" or unit.kind == "illusion" end)
end

function Micro.everything()
    return collect(nil)
end

function Micro.byName(...)
    return Micro.all():name(...)
end

function Micro.matching(pattern)
    return Micro.all():matching(pattern)
end

-- Wrap units you already have in hand.
function Micro.wrap(list)
    rebuild()

    local picked = {}
    for _, npc in ipairs(list) do
        local index = call(Entity.GetIndex, npc)
        local unit  = index and store[index]
        if unit ~= nil then insert(picked, unit) end
    end

    return newGroup(picked)
end

function Micro.of(npc)
    return Micro.wrap({ npc })
end

--=============================================================================
-- PLAYER ORDERS
--
-- Forward script.OnPrepareUnitOrders here and automation steps aside whenever
-- the player takes the wheel. Returning the result keeps your own filtering
-- working: we never block an order, we only notice it.
--=============================================================================

function Micro.orders(data)
    if type(data) ~= "table" then return true end

    -- Our own traffic. Ignore it, or every order we send would look like the
    -- player taking over and we would immediately mute ourselves.
    if sending then return true end

    local identifier = data.identifier
    if type(identifier) == "string" and identifier:find(ORDER_TAG, 1, true) == 1 then
        return true
    end

    local c = context()
    if c.player == nil or (data.player ~= nil and data.player ~= c.player) then
        return true
    end

    local until_ = now() + TUNING.yield

    local function mute(npc)
        local index = call(Entity.GetIndex, npc)
        local unit  = index and store[index]
        if unit ~= nil then unit.manual = until_ end
    end

    if data.npc ~= nil then mute(data.npc) end

    -- A click with several units selected only names one of them, so mute the
    -- whole selection rather than letting the rest keep marching.
    local issuer = data.orderIssuer
    if issuer ~= nil and Enum.PlayerOrderIssuer ~= nil
        and issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS
    then
        for _, npc in ipairs(call(Player.GetSelectedUnits, c.player) or {}) do
            mute(npc)
        end
    end

    return true
end

-- Manual override from your own code, for cases the callback cannot see.
function Micro.yield(npc, seconds)
    local index = call(Entity.GetIndex, npc)
    local unit  = index and store[index]
    if unit ~= nil then unit.manual = now() + (seconds or TUNING.yield) end
end

--=============================================================================
-- TICK
--=============================================================================

-- Formation-shaped behaviours need their slots recomputed together, once per
-- tick, for all units sharing an anchor. Doing it per unit would give each of
-- them a different idea of where the shape is.
-- Two formations under the same tag are still two formations. Bucket on the
-- anchor as well, or a script holding one shape at the rune and another at the
-- tower would quietly collapse both onto whichever anchor was seen first.
local function anchorKey(behavior)
    local anchor = behavior.opts.anchor

    if anchor == nil then return "-" end

    if type(anchor) == "table" and anchor.x ~= nil then
        return math.floor(anchor.x / 64) .. "," .. math.floor(anchor.y / 64)
    end

    return "e" .. tostring(call(Entity.GetIndex, anchor) or 0)
end

local function reslot(time)
    local groups = {}

    for _, unit in ipairs(roster) do
        local behavior = unit.behavior

        if behavior == nil or behavior.opts.shape == nil then
            -- Drop a slot the unit no longer has any claim to, so a later
            -- formation does not inherit last minute's stale assignment.
            unit.slot, unit.slotIndex = nil, nil
        end

        if behavior ~= nil and behavior.opts.shape ~= nil then
            local key = tostring(behavior.tag) .. ":" .. behavior.name .. ":" .. anchorKey(behavior)
            local bucket = groups[key]
            if bucket == nil then
                bucket = { behavior = behavior, units = {} }
                groups[key] = bucket
            end
            insert(bucket.units, unit)
        end
    end

    for _, bucket in pairs(groups) do
        local behavior = bucket.behavior
        local center   = anchorPoint(behavior)

        if center ~= nil then
            local facing = behavior.opts.facing

            if facing == nil then
                local c = context()
                facing = c.hero and angleOf(center, origin(c.hero)) or 0
            elseif type(facing) == "table" and facing.x ~= nil then
                facing = angleOf(center, facing)
            end

            local slots = behavior.opts.shape(#bucket.units, center, facing)

            for index, slot in ipairs(slots) do
                slots[index] = walkable(onGround(slot))
            end

            assign(bucket.units, slots)
        end
    end
end

function Micro.update()
    ctx.tick = ctx.tick + 1

    local c = context()
    if c.player == nil or c.hero == nil then return end

    rebuild()

    local time = c.time

    reslot(time)

    for _, unit in ipairs(roster) do
        observeAttack(unit, time)

        local behavior = unit.behavior
        if behavior ~= nil and time >= unit.manual and not muted(unit.npc) then
            behavior.spec.tick(unit, behavior, time)
        end
    end
end

function Micro.reset()
    store, roster, rosterStamp = {}, {}, -1
    stats.sent, stats.suppressed, stats.deferred = 0, 0, 0
end

--=============================================================================
-- DEBUG OVERLAY
--
-- Optional, and off until you ask for it. Seeing which unit holds which slot
-- and which behaviour owns it turns most micro bugs into a glance.
--=============================================================================

local font = nil

local function ensureFont()
    if font ~= nil then return font end
    font = call(Render.LoadFont, "Tahoma", Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    return font
end

local function worldLine(from, to, colour, thickness)
    local a, aVisible = Render.WorldToScreen(from)
    local b, bVisible = Render.WorldToScreen(to)
    if aVisible and bVisible then
        Render.Line(a, b, colour, thickness or 1.4)
    end
end

local function worldRing(center, radius, colour, segments)
    segments = segments or 32
    local previous = nil

    for step = 0, segments do
        local angle = step * pi * 2 / segments
        local edge  = onGround(Vector(center.x + cos(angle) * radius,
                                      center.y + sin(angle) * radius,
                                      center.z))
        if previous ~= nil then worldLine(previous, edge, colour, 1.2) end
        previous = edge
    end
end

Micro.debug = false

function Micro.draw()
    if not Micro.debug then return end

    rebuild()
    ensureFont()

    local slotColour  = Color(120, 210, 255, 200)
    local leashColour = Color(120, 210, 255, 90)
    local textColour  = Color(235, 240, 255, 230)
    local shadow      = Color(0, 0, 0, 200)

    for _, unit in ipairs(roster) do
        local behavior = unit.behavior
        if behavior ~= nil then
            local here = origin(unit.npc)

            if unit.slot ~= nil then
                worldRing(unit.slot, 42, slotColour, 20)
                worldLine(here, unit.slot, leashColour, 1)
            end

            if font ~= nil then
                local head, visible = Render.WorldToScreen(here + Vector(0, 0, 200))
                if visible then
                    local label = (behavior.spec.label or behavior.name)
                    if behavior.tag ~= "default" then
                        label = label .. " / " .. tostring(behavior.tag)
                    end
                    Render.Text(font, 13, label, Vec2(head.x + 1, head.y + 1), shadow)
                    Render.Text(font, 13, label, head, textColour)
                end
            end
        end
    end
end

return Micro

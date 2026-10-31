-- сценарий для brain.lua: клики, враги, бой
-- запуск: lua mock/run.lua brain.lua --scenario mock/examples/brain_scenario.lua

local clicks = {}
for i = 0, 40 do
    local t = 20 + i * 12
    if i % 4 == 0 then
        clicks[#clicks + 1] = { tick = t, order = "DOTA_UNIT_ORDER_ATTACK_TARGET", target = "enemy" }
    elseif i % 4 == 1 then
        clicks[#clicks + 1] = { tick = t, order = "DOTA_UNIT_ORDER_CAST_NO_TARGET", ability = "lycan_howl" }
    else
        clicks[#clicks + 1] = { tick = t, order = "DOTA_UNIT_ORDER_MOVE_TO_POSITION" }
    end
end

return {
    ticks = 600,
    hero = {
        name = "npc_dota_hero_lycan", pos = { 0, 0 }, hp = 900, mana = 400, speed = 320, range = 150,
        abilities = { { name = "lycan_summon_wolves", mana = 100, cooldown = 30 },
                      { name = "lycan_howl", mana = 50, cooldown = 1 } },
        items = { { name = "item_blink", mana = 0, cooldown = 15 } },
    },
    heroPath = { { 0, 0 }, { 600, 300 } },
    enemies = {
        { name = "npc_dota_hero_sniper", pos = { 300, 100 }, kind = "hero", hp = 600, range = 550, attack = "hero" },
        { name = "npc_dota_creep_badguys_melee", pos = { 200, -100 }, kind = "creep", hp = 300 },
    },
    respawn = 6,
    clicks = clicks,
}

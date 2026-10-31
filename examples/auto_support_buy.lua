--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = name:match("%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							return function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

local localization = qLocalization.new({
	en = {
		asb_group_main = "Main",
		asb_group_extra = "Behavior",
		asb_enable = "Enable",
		asb_enable_tip = "Buys one support item each time its stock in the shop is full",
		asb_gear_extra = "Extra",
		asb_debug = "Debug log",
		asb_debug_tip = "Writes what the script is doing\nto the log",
		asb_items = "Items to buy",
		asb_items_tip = "Buys one item each time the stock is full:\nSmoke 3, Observer 4, Sentry 8",
		asb_minute = "From minute",
		asb_minute_tip = "The script waits until this game minute",
		asb_gold = "Min gold",
		asb_gold_tip = "Buys only while you have at least\nthis much gold on hand",
		asb_drop = "Drop after purchase",
		asb_drop_tip = "Drops the bought items from the stash\nonto the ground at the fountain",
		asb_base = "Leave at base",
		asb_base_tip = "If you bought them standing at the shop,\nthey are dropped at the fountain from the inventory too",
	},
	ru = {
		asb_group_main = "Основное",
		asb_group_extra = "Поведение",
		asb_enable = "Включить",
		asb_enable_tip = "Покупает 1 саппорт-предмет каждый раз, когда его запас в лавке полный",
		asb_gear_extra = "Дополнительно",
		asb_debug = "Отладка в лог",
		asb_debug_tip = "Пишет в лог, что сейчас делает скрипт",
		asb_items = "Что покупать",
		asb_items_tip = "Покупает 1 штуку, когда запас полный:\nСмоки 3, Обсы 4, Сентри 8",
		asb_minute = "С минуты",
		asb_minute_tip = "Скрипт ждет эту минуту игры",
		asb_gold = "Мин. золото",
		asb_gold_tip = "Покупает, только пока на руках\nне меньше этого золота",
		asb_drop = "Выкладывать после покупки",
		asb_drop_tip = "Выкладывает купленное из тайника\nна землю у фонтана",
		asb_base = "Оставлять на базе",
		asb_base_tip = "Если купил, стоя у лавки, предметы\nвыкладываются у фонтана и из инвентаря",
	},
})

local VERSION = "1.1.0"

local UI = localization.WrapLibrary(Menu)

local ITEMS = {
	{ id = "Smoke of Deceit", name = "item_smoke_of_deceit", item_id = 188, max = 3, cost = 50, icon = "panorama/images/items/smoke_of_deceit_png.vtex_c" },
	{ id = "Observer Ward", name = "item_ward_observer", item_id = 42, max = 4, cost = 0, icon = "panorama/images/items/ward_observer_png.vtex_c" },
	{ id = "Sentry Ward", name = "item_ward_sentry", item_id = 43, max = 8, cost = 50, icon = "panorama/images/items/ward_sentry_png.vtex_c" },
}

local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Auto Support Buy")
	tab:Icon("\u{f07a}")

	local page = tab:Create("Settings")
	local g_main = page:Create("asb_group_main", Enum.GroupSide.Left)
	local g_extra = page:Create("asb_group_extra", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("asb_enable", false, "\u{f011}")
	ui.enable:ToolTip("asb_enable_tip")
	local g_gear = ui.enable:Gear("asb_gear_extra")
	ui.debug = g_gear:Switch("asb_debug", false, "\u{f188}")
	ui.debug:ToolTip("asb_debug_tip")

	local list = {}
	for i, it in ipairs(ITEMS) do list[i] = { it.id, it.icon, true } end
	ui.items = g_main:MultiSelect("asb_items", list, true)
	ui.items:Icon("\u{f07a}")
	ui.items:ToolTip("asb_items_tip")

	ui.minute = g_main:Slider("asb_minute", 0, 60, 0, "%d")
	ui.minute:Icon("\u{f017}")
	ui.minute:ToolTip("asb_minute_tip")

	ui.gold = g_main:Slider("asb_gold", 0, 5000, 0, "%d")
	ui.gold:Icon("\u{f51e}")
	ui.gold:ToolTip("asb_gold_tip")

	ui.drop = g_extra:Switch("asb_drop", true, "\u{f019}")
	ui.drop:ToolTip("asb_drop_tip")

	ui.base = g_extra:Switch("asb_base", false, "\u{f015}")
	ui.base:ToolTip("asb_base_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.debug:Disabled(not on)
	ui.items:Disabled(not on)
	ui.minute:Disabled(not on)
	ui.gold:Disabled(not on)
	ui.drop:Disabled(not on)
	ui.base:Disabled(not on or not ui.drop:Get())
end

ui.enable:SetCallback(refresh_disabled, true)
ui.drop:SetCallback(refresh_disabled)

local state = { next = 0, wait = {}, drop_until = 0, dropped = {} }

local function log(text, data)
	if ui.debug:Get() and ai_bridge and ai_bridge.mcp_log then
		ai_bridge.mcp_log("info", "[Auto Support Buy] " .. text, data)
	end
end

local function order(player, hero, kind, item, target)
	Player.PrepareUnitOrders(player, kind, target, Vector(0, 0, 0), item,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, true, "auto_support_buy", false)
end

local function drop_items(player, hero, now)
	local names = {}
	for _, it in ipairs(ITEMS) do names[it.name] = true end
	local first = 9
	if ui.base:Get() and NPC.IsInRangeOfShop(hero, Enum.ShopType.DOTA_SHOP_HOME) then first = 0 end
	for slot = first, 14 do
		local item = NPC.GetItemByIndex(hero, slot)
		if item and names[Ability.GetName(item)] and (state.dropped[item] or 0) < now then
			state.dropped[item] = now + 1
			if slot >= 9 then
				order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH, item)
			else
				order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_DROP_ITEM_AT_FOUNTAIN, item)
			end
			log("drop", { item = Ability.GetName(item), slot = slot })
			return
		end
	end
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then return end
	local now = GameRules.GetGameTime()
	if now < state.next then return end
	state.next = now + 0.25

	local hero, player = Heroes.GetLocal(), Players.GetLocal()
	if not hero or not player then return end

	if ui.drop:Get() and now < state.drop_until and Entity.IsAlive(hero) then
		drop_items(player, hero, now)
	end

	if GameRules.GetDOTATime() < ui.minute:Get() * 60 then return end

	local team = Entity.GetTeamNum(hero)
	local gold = Player.GetTotalGold(player)
	for _, it in ipairs(ITEMS) do
		local stock = Item.GetStockCount(it.item_id, team)
		if ui.items:Get(it.id) and stock >= it.max and gold >= ui.gold:Get() and gold >= it.cost
			and (state.wait[it.name] or 0) < now then
			state.wait[it.name] = now + 2
			order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, it.item_id, it.item_id)
			state.drop_until = now + 15
			log("buy", { item = it.name, stock = stock, gold = gold })
			return
		end
	end
end

function script.OnGameEnd()
	state.wait, state.dropped, state.drop_until = {}, {}, 0
end

return script

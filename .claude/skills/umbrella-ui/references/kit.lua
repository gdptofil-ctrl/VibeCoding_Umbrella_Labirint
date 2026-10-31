-- ===========================================================================
-- umbrella-ui kit (paste after the menu block)
-- Only edit the K block; everything below it is generic.
-- ===========================================================================

local K = {
	NAME = "My Script",
	CFG = "my_script",
	W = 360,
	HEAD = 52,
	PAD = 12,
	EVERYWHERE = false,
	SMALL = false,
	DOCK = true,
	SNAP = 24,
	THEME = "brand",
	ACCENT = "brand",
	SINK_ID = "MyScriptInput",
	SINK_ALIVE = 0.4,
	SINK_TIMEOUT = 1500,
	TIP_DELAY = 0.35,
	TOAST_TIME = 4,
	WHEEL = 56,
	DOUBLE = 0.35,
	G = {
		close = "\u{f00d}", up = "\u{f077}", down = "\u{f078}", gear = "\u{f013}", check = "\u{f00c}",
		left = "\u{f053}", right = "\u{f054}",
		search = "\u{f002}", info = "\u{f05a}", warn = "\u{f071}", ok = "\u{f058}", empty = "\u{f49e}",
	},
}

local ROUND = Enum.DrawFlags.RoundCornersAll
local KEY = Enum.ButtonCode

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function ease_out(t) return 1 - (1 - t) * (1 - t) end
local function ease_in_out(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end

local THEME_ORDER = { "brand", "umbrella", "graphite", "midnight", "purple", "forest", "oled" }
local THEMES = {
	brand = { win = { 35, 35, 41 }, bar = { 41, 41, 48 }, card = { 46, 46, 54 }, menu = { 60, 60, 70 }, off = { 74, 74, 86 } },
	graphite = { win = { 25, 25, 27 }, card = { 34, 34, 37 }, menu = { 42, 42, 46 }, off = { 58, 58, 63 } },
	midnight = { win = { 17, 20, 31 }, card = { 25, 30, 45 }, menu = { 34, 40, 58 }, off = { 52, 60, 84 } },
	purple = { win = { 22, 17, 32 }, card = { 32, 25, 47 }, menu = { 46, 36, 67 }, off = { 62, 49, 88 } },
	forest = { win = { 17, 25, 21 }, card = { 24, 35, 29 }, menu = { 37, 52, 44 }, off = { 52, 70, 60 } },
	oled = { win = { 0, 0, 0 }, card = { 15, 15, 17 }, menu = { 28, 28, 31 }, off = { 44, 44, 48 } },
	umbrella = {
		win = { 16, 17, 21 }, card = { 19, 21, 25 }, menu = { 23, 26, 28 }, off = { 36, 38, 46 },
		line = { 51, 51, 51 }, knob = { 102, 102, 102 },
		t1 = { 245, 245, 245 }, t2 = { 207, 209, 222 }, t3 = { 176, 176, 176 }, t4 = { 115, 117, 130 },
	},
}

local ACCENT_ORDER = { "brand", "umbrella", "blue", "teal", "green", "purple", "orange", "pink" }
local ACCENTS = {
	brand = { 184, 167, 240 }, umbrella = { 207, 54, 54 }, blue = { 76, 130, 247 }, teal = { 38, 166, 154 }, green = { 52, 168, 83 },
	purple = { 138, 99, 210 }, orange = { 240, 140, 40 }, red = { 226, 75, 75 }, pink = { 232, 90, 150 },
}

local UMBRELLA_STYLE = {
	win = "main_background", card = "group_background", menu = "button_background", off = "slider_background",
	line = "outline", knob = "disabled_switch_circle", t1 = "active_widgets_text", t2 = "primary_first_tab_text",
	t3 = "primary_widgets_text", t4 = "section_group_text", accent = "primary",
}

local T = {
	t1 = { 250, 250, 252 }, t2 = { 218, 218, 224 }, t3 = { 160, 160, 168 }, t4 = { 120, 120, 128 },
	white = { 255, 255, 255 }, black = { 0, 0, 0 }, knob = { 142, 142, 147 },
	green = { 104, 214, 126 }, red = { 255, 110, 100 }, yellow = { 255, 204, 64 },
}
local T_BASE = { t1 = T.t1, t2 = T.t2, t3 = T.t3, t4 = T.t4, knob = T.knob }

local function valid(list, v, default)
	for _, o in ipairs(list) do
		if o == v then return v end
	end
	return default
end

local P = {
	open = true, alpha = 0, wx = nil, wy = nil, h = 0, dt = 0, now = 0,
	tweens = {}, press = nil, drag = nil, slide = nil, sb_drag = nil, resize = nil, moved = false,
	menu = nil, menu_req = nil, ctx = nil, tip_req = nil, tip_id = nil, tip_since = 0,
	scroll = {}, toasts = {}, last_click = { id = nil, t = -10 }, draw_error = nil,
	focus = nil, focus_id = nil, saved = {},
	set = {
		theme = Config.ReadString(K.CFG, "theme", K.THEME),
		accent = Config.ReadString(K.CFG, "accent", K.ACCENT),
		scale = Config.ReadInt(K.CFG, "scale", 100),
		opacity = Config.ReadInt(K.CFG, "opacity", 94),
		collapsed = Config.ReadInt(K.CFG, "collapsed", 0) == 1,
		docked = Config.ReadInt(K.CFG, "docked", 0) == 1,
		compact = Config.ReadInt(K.CFG, "compact", 0) == 1,
	},
}
P.set.theme = K.SMALL and "umbrella" or valid(THEME_ORDER, P.set.theme, "brand")
P.set.accent = K.SMALL and "umbrella" or valid(ACCENT_ORDER, P.set.accent, "brand")
P.set.scale = clamp(P.set.scale, 70, 150)
P.set.opacity = clamp(P.set.opacity, 40, 100)
for k, v in pairs(P.set) do P.saved[k] = type(v) == "boolean" and (v and 1 or 0) or v end

-- AON: text on an accent fill (dark on light accents, white on dark ones)
local C, A, AT, AON = {}, { 0, 0, 0 }, { 0, 0, 0 }, { 255, 255, 255 }
local U = { flat = false }

local function style_rgb(name, fallback)
	local ok, c = pcall(Menu.Style, name)
	if not ok or type(c) ~= "userdata" and type(c) ~= "table" or not c.r then return fallback end
	return { math.floor(c.r + 0.5), math.floor(c.g + 0.5), math.floor(c.b + 0.5) }
end

local function apply_theme()
	local umbrella = P.set.theme == "umbrella"
	U.flat = umbrella
	for name in pairs(C) do C[name] = nil end
	for name, v in pairs(T_BASE) do T[name] = v end
	for name, v in pairs(THEMES[P.set.theme]) do
		if umbrella then v = style_rgb(UMBRELLA_STYLE[name], v) end
		if T_BASE[name] then T[name] = v else C[name] = { v[1], v[2], v[3] } end
	end
	if not C.bar then C.bar = { (C.win[1] + C.card[1]) / 2, (C.win[2] + C.card[2]) / 2, (C.win[3] + C.card[3]) / 2 } end
	local a = ACCENTS[P.set.accent]
	if P.set.accent == "umbrella" then a = style_rgb(UMBRELLA_STYLE.accent, a) end
	for i = 1, 3 do
		A[i] = a[i]
		AT[i] = math.floor(a[i] + (255 - a[i]) * 0.35 + 0.5)
	end
	AON = (0.299 * A[1] + 0.587 * A[2] + 0.114 * A[3]) > 160 and C.win or T.white
end

apply_theme()

local function say(text)
	if K.DEBUG and K.DEBUG() then Log.Write("[" .. K.NAME .. "] " .. text) end
end

local function save(key, value)
	if type(value) == "boolean" then value = value and 1 or 0 end
	if P.saved[key] == value then return end
	P.saved[key] = value
	if type(value) == "number" then
		Config.WriteInt(K.CFG, key, math.floor(value))
	else
		Config.WriteString(K.CFG, key, tostring(value))
	end
end

-- ---------------------------------------------------------------------------
-- assets
-- ---------------------------------------------------------------------------

local asset = { fonts = {}, sizes = {}, size_n = 0, images = {}, dims = {}, budget = 3 }

-- MuseoSansEx under the flat skin; Bahnschrift (Inter when it is missing) under the brand skin
function asset.family()
	if U.flat then return "MuseoSansEx" end
	if not asset.fam then
		local aa, sample = Enum.FontCreate.FONTFLAG_ANTIALIAS, "Aq9Яж"
		local have, miss = Render.LoadFont("Bahnschrift", aa, 400), Render.LoadFont("UiKitNoSuchFont", aa, 400)
		asset.fam = Render.TextSize(have, 20, sample).x ~= Render.TextSize(miss, 20, sample).x and "Bahnschrift" or "Inter"
	end
	return asset.fam
end

function asset.font(weight)
	local name = asset.family()
	if name == "Bahnschrift" then weight = weight >= 600 and 700 or 400 end
	local key = name .. weight
	local f = asset.fonts[key]
	if not f then
		f = Render.LoadFont(name, Enum.FontCreate.FONTFLAG_ANTIALIAS, weight)
		asset.fonts[key] = f
	end
	return f
end

function asset.icons()
	local f = asset.fonts.icon
	if not f then
		f = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
		asset.fonts.icon = f
	end
	return f
end

function asset.size(font, px, str)
	local by_font = asset.sizes[font]
	if not by_font then
		by_font = {}
		asset.sizes[font] = by_font
	end
	local by_px = by_font[px]
	if not by_px then
		by_px = {}
		by_font[px] = by_px
	end
	local v = by_px[str]
	if not v then
		if asset.size_n >= 6000 then
			asset.sizes, asset.size_n = {}, 0
		end
		v = Render.TextSize(font, px, str)
		by_px[str] = v
		asset.size_n = asset.size_n + 1
	end
	return v
end

function asset.image(path)
	local img = asset.images[path]
	if img == nil then
		if asset.budget <= 0 then return nil end
		asset.budget = asset.budget - 1
		img = Render.LoadImage(path)
		if not img or img == 0 then img = false end
		asset.images[path] = img
	end
	return img or nil
end

function asset.hero(npc_name)
	return asset.image("panorama/images/heroes/icons/" .. npc_name .. "_png.vtex_c")
end

function asset.portrait(npc_name)
	return asset.image("panorama/images/heroes/" .. npc_name .. "_png.vtex_c")
end

function asset.item(item_name)
	return asset.image("panorama/images/items/" .. item_name:gsub("^item_", "") .. "_png.vtex_c")
end

function asset.ability(ability_name)
	return asset.image("panorama/images/spellicons/" .. ability_name .. "_png.vtex_c")
end

-- ---------------------------------------------------------------------------
-- drawing in window units: g.x/g.y is the origin, g.s the scale, g.a the alpha
-- ---------------------------------------------------------------------------

local g = { x = 0, y = 0, s = 1, a = 1, cmp = 0, depth = 0, clips = {}, fits = {}, fit_n = 0, wraps = {}, ups = {}, up_n = 0 }
local hit = { list = {}, hover = nil, clip = nil }

function g.px(x) return math.floor(g.x + x * g.s + 0.5) end
function g.py(y) return math.floor(g.y + y * g.s + 0.5) end
function g.v(x, y) return Vec2(g.px(x), g.py(y)) end
function g.fs(size) return math.max(1, math.floor(size * g.s + 0.5)) end
function g.hair() return math.max(1, math.floor(g.s)) end
-- compact mode: n at normal density, c when P.set.compact is on (animated)
function g.lay(n, c) return n + (c - n) * g.cmp end

function g.origin(x, y)
	g.x, g.y = x, y
end

function g.col(c, a)
	return Color(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5),
		math.floor(clamp((c[4] or 255) * (a or 1) * g.a, 0, 255) + 0.5))
end

-- corner radius by skin: flat caps at 5 (pills keep theirs), brand is sharp (2.5 at most)
function g.r(r, w, h)
	r = r or 0
	if U.flat then return r < math.min(w, h) / 2 and math.min(r, 5) or r end
	return math.min(r, 2.5)
end

function g.rect(x, y, w, h, c, r, a, flags)
	Render.FilledRect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), g.r(r, w, h) * g.s, flags or ROUND)
end

function g.frame(x, y, w, h, c, r, a, t, flags)
	Render.Rect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), g.r(r, w, h) * g.s, flags or ROUND, (t or 1) * g.s)
end

function g.hl(x, y, w, c, a)
	local y0 = g.py(y)
	Render.FilledRect(Vec2(g.px(x), y0), Vec2(g.px(x + w), y0 + g.hair()), g.col(c, a))
end

function g.vl(x, y, h, c, a)
	local x0 = g.px(x)
	Render.FilledRect(Vec2(x0, g.py(y)), Vec2(x0 + g.hair(), g.py(y + h)), g.col(c, a))
end

function g.dot(cx, cy, r, c, a)
	Render.FilledCircle(Vec2(g.x + cx * g.s, g.y + cy * g.s), r * g.s, g.col(c, a), 0, 1, 24)
end

function g.ring(cx, cy, r, c, a, t)
	Render.Circle(Vec2(g.x + cx * g.s, g.y + cy * g.s), r * g.s, g.col(c, a), (t or 1) * g.s, 0, 1, false, 48)
end

function g.arc(cx, cy, r, c, a, t, start, pct)
	Render.Circle(Vec2(g.x + cx * g.s, g.y + cy * g.s), r * g.s, g.col(c, a), (t or 1) * g.s, start, pct, true, 48)
end

function g.line(x1, y1, x2, y2, c, a, t)
	Render.Line(Vec2(g.x + x1 * g.s, g.y + y1 * g.s), Vec2(g.x + x2 * g.s, g.y + y2 * g.s), g.col(c, a), (t or 1) * g.s)
end

-- horizontal (or vertical) gradient between two colours
function g.grad(x, y, w, h, c1, a1, c2, a2, vertical)
	local t1, t2 = g.col(c1, a1), g.col(c2, a2)
	if vertical then
		Render.Gradient(g.v(x, y), g.v(x + w, y + h), t1, t1, t2, t2)
	else
		Render.Gradient(g.v(x, y), g.v(x + w, y + h), t1, t2, t1, t2)
	end
end

-- brand panel: a rect with 45-degree cut corners (k = cut size; tl/tr/br/bl pick the corners)
function g.cut(x, y, w, h, c, a, k, tl, tr, br, bl)
	local x0, y0, x1, y1 = g.px(x), g.py(y), g.px(x + w), g.py(y + h)
	local cc = g.col(c, a)
	k = clamp(math.floor(k * g.s + 0.5), 1, math.floor(math.min(x1 - x0, y1 - y0) / 2))
	local ct, cb = (tl or tr) and k or 0, (bl or br) and k or 0
	Render.FilledRect(Vec2(x0, y0 + ct), Vec2(x1, y1 - cb), cc)
	if ct > 0 then
		Render.FilledRect(Vec2(tl and x0 + k or x0, y0), Vec2(tr and x1 - k or x1, y0 + ct), cc)
		if tl then Render.FilledTriangle({ Vec2(x0 + k, y0), Vec2(x0 + k, y0 + k), Vec2(x0, y0 + k) }, cc) end
		if tr then Render.FilledTriangle({ Vec2(x1 - k, y0), Vec2(x1, y0 + k), Vec2(x1 - k, y0 + k) }, cc) end
	end
	if cb > 0 then
		Render.FilledRect(Vec2(bl and x0 + k or x0, y1 - cb), Vec2(br and x1 - k or x1, y1), cc)
		if bl then Render.FilledTriangle({ Vec2(x0 + k, y1), Vec2(x0, y1 - k), Vec2(x0 + k, y1 - k) }, cc) end
		if br then Render.FilledTriangle({ Vec2(x1 - k, y1), Vec2(x1 - k, y1 - k), Vec2(x1, y1 - k) }, cc) end
	end
end

function g.cut_frame(x, y, w, h, c, a, t, k, tl, tr, br, bl)
	local X0, Y0 = g.px(x) + 0.5, g.py(y) + 0.5
	local X1, Y1 = g.px(x + w) - 0.5, g.py(y + h) - 0.5
	k = math.min(k * g.s, (Y1 - Y0) / 2)
	local pts = {}
	local function add(px, py) pts[#pts + 1] = Vec2(px, py) end
	if tl then add(X0, Y0 + k) add(X0 + k, Y0) else add(X0, Y0) end
	if tr then add(X1 - k, Y0) add(X1, Y0 + k) else add(X1, Y0) end
	if br then add(X1, Y1 - k) add(X1 - k, Y1) else add(X1, Y1) end
	if bl then add(X0 + k, Y1) add(X0, Y1 - k) else add(X0, Y1) end
	Render.PolyLine(pts, g.col(c, a), math.max(1, (t or 1) * g.s))
end

-- corner brackets around a rect (brand hover and focus)
function g.brackets(x, y, w, h, len, c, a, t)
	local x2, y2 = x + w, y + h
	g.line(x, y, x + len, y, c, a, t)
	g.line(x, y, x, y + len, c, a, t)
	g.line(x2, y, x2 - len, y, c, a, t)
	g.line(x2, y, x2, y + len, c, a, t)
	g.line(x, y2, x + len, y2, c, a, t)
	g.line(x, y2, x, y2 - len, c, a, t)
	g.line(x2, y2, x2 - len, y2, c, a, t)
	g.line(x2, y2, x2, y2 - len, c, a, t)
end

function g.width(weight, size, str)
	return asset.size(asset.font(weight), g.fs(size), str).x / g.s
end

function g.text(weight, size, str, x, cy, c, a, align)
	local font, px = asset.font(weight), g.fs(size)
	local ts = asset.size(font, px, str)
	local x0 = g.x + x * g.s
	if align == "r" then x0 = x0 - ts.x elseif align == "c" then x0 = x0 - ts.x / 2 end
	Render.Text(font, px, str, Vec2(math.floor(x0 + 0.5), math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)), g.col(c, a))
	return ts.x / g.s
end

function g.glyph(glyph, size, cx, cy, c, a)
	local font, px = asset.icons(), g.fs(size)
	local ts = asset.size(font, px, glyph)
	Render.Text(font, px, glyph, Vec2(math.floor(g.x + cx * g.s - ts.x / 2 + 0.5), math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)),
		g.col(c, a))
end

function g.chars(str)
	local out = {}
	for _, c in utf8.codes(str) do out[#out + 1] = utf8.char(c) end
	return out
end

function g.fit(weight, size, str, max_w)
	local key = (U.flat and "m" or "i") .. weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. g.s .. ":" .. str
	local out = g.fits[key]
	if out then return out end
	out = str
	if g.width(weight, size, str) > max_w then
		local chars = g.chars(str)
		out = "…"
		for n = #chars - 1, 1, -1 do
			local s = table.concat(chars, "", 1, n):gsub("%s+$", "") .. "…"
			if g.width(weight, size, s) <= max_w then
				out = s
				break
			end
		end
	end
	if g.fit_n >= 3000 then g.fits, g.fit_n = {}, 0 end
	g.fits[key], g.fit_n = out, g.fit_n + 1
	return out
end

function g.wrap(weight, size, str, max_w)
	local key = (U.flat and "m" or "i") .. weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. g.s .. ":" .. str
	local out = g.wraps[key]
	if out then return out end
	out = {}
	local line = ""
	for word in str:gmatch("%S+") do
		local candidate = line == "" and word or line .. " " .. word
		if line ~= "" and g.width(weight, size, candidate) > max_w then
			out[#out + 1] = line
			line = word
		else
			line = candidate
		end
	end
	if line ~= "" then out[#out + 1] = line end
	g.wraps[key] = out
	return out
end

-- upper case for Latin and Cyrillic (string.upper leaves Cyrillic alone)
function g.up(str)
	local out = g.ups[str]
	if out then return out end
	local t = {}
	for _, cp in utf8.codes(str) do
		if cp >= 0x430 and cp <= 0x44F then cp = cp - 32
		elseif cp == 0x451 then cp = 0x401
		elseif cp >= 97 and cp <= 122 then cp = cp - 32 end
		t[#t + 1] = utf8.char(cp)
	end
	out = table.concat(t)
	if g.up_n >= 2000 then g.ups, g.up_n = {}, 0 end
	g.ups[str], g.up_n = out, g.up_n + 1
	return out
end

-- letter-spaced text (brand titles and section headers); space is in window units
function g.track_w(weight, size, str, space)
	local font, px = asset.font(weight), g.fs(size)
	local total, n = 0, 0
	for _, cp in utf8.codes(str) do total, n = total + asset.size(font, px, utf8.char(cp)).x, n + 1 end
	return total / g.s + (space or 1) * math.max(0, n - 1)
end

function g.track(weight, size, str, x, cy, c, a, space, align)
	local font, px, sp = asset.font(weight), g.fs(size), (space or 1) * g.s
	local total = g.track_w(weight, size, str, space)
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - total * g.s elseif align == "c" then tx = tx - total * g.s / 2 end
	local ty = math.floor(g.y + cy * g.s - asset.size(font, px, "A").y / 2 + 0.5)
	local cc = g.col(c, a)
	for _, cp in utf8.codes(str) do
		local ch = utf8.char(cp)
		Render.Text(font, px, ch, Vec2(math.floor(tx + 0.5), ty), cc)
		tx = tx + asset.size(font, px, ch).x + sp
	end
	return total
end

-- upper-cased tracked text that falls back to plain text with an ellipsis when it does not fit
function g.track_fit(weight, size, str, x, cy, c, a, space, max_w, align)
	local up = g.up(str)
	if g.track_w(weight, size, up, space) <= max_w then return g.track(weight, size, up, x, cy, c, a, space, align) end
	return g.text(weight, size, g.fit(weight, size, up, max_w), x, cy, c, a, align)
end

function g.clip(x, y, w, h)
	Render.PushClip(g.v(x, y), g.v(x + w, y + h), true)
	g.depth = g.depth + 1
	g.clips[#g.clips + 1] = hit.clip or false
	local c = { g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s }
	local p = hit.clip
	if p then c = { math.max(c[1], p[1]), math.max(c[2], p[2]), math.min(c[3], p[3]), math.min(c[4], p[4]) } end
	hit.clip = c
end

function g.unclip()
	Render.PopClip()
	g.depth = g.depth - 1
	hit.clip = g.clips[#g.clips] or nil
	g.clips[#g.clips] = nil
end

function g.reset()
	for _ = 1, g.depth do Render.PopClip() end
	g.depth, g.clips, g.a, hit.clip = 0, {}, 1, nil
end

function g.shadow(x, y, w, h, r, a)
	if U.flat then return end
	for i = 1, 5 do
		local e = i * 2.5
		g.rect(x - e, y - e + 4, w + e * 2, h + e * 2, T.black, r + e, (a or 0.07) * (1 - (i - 1) / 5))
	end
end

function g.square(img, label, x, y, size, a, r, gray)
	if img then
		local dim = asset.dims[img]
		if not dim then
			dim = Render.ImageSize(img)
			asset.dims[img] = dim
		end
		local u0, v0, u1, v1 = 0, 0, 1, 1
		if dim.x > dim.y and dim.y > 0 then
			local d = (1 - dim.y / dim.x) / 2
			u0, u1 = d, 1 - d
		elseif dim.y > dim.x and dim.x > 0 then
			local d = (1 - dim.x / dim.y) / 2
			v0, v1 = d, 1 - d
		end
		local px = math.floor(size * g.s + 0.5)
		Render.Image(img, g.v(x, y), Vec2(px, px), g.col(T.white, a), g.r(r, size, size) * g.s, ROUND, Vec2(u0, v0), Vec2(u1, v1), gray or 0)
	else
		g.rect(x, y, size, size, T.white, r, 0.10 * (a or 1))
		local first = label and label:sub(1, (utf8.offset(label, 2) or 2) - 1) or "?"
		g.text(700, size * 0.45, first:upper(), x + size / 2, y + size / 2, T.t3, a, "c")
	end
end

-- the logo: two umbrella wings, one SVG texture per pixel height, tinted by colour
local LOGO = {
	w = 0.8417, tex = {},
	polys = {
		{ { 1.0000, 0.0000 }, { 0.8502, 0.1289 }, { 0.6705, 0.3095 }, { 0.5391, 0.5966 }, { 0.5191, 1.0000 }, { 0.6955, 0.8039 }, { 0.7770, 0.6891 }, { 0.6273, 0.7871 }, { 0.6938, 0.7017 }, { 0.7604, 0.6373 }, { 0.7804, 0.5392 }, { 0.6389, 0.6485 }, { 0.6356, 0.6471 }, { 0.7304, 0.4104 }, { 0.8852, 0.2367 }, { 0.8835, 0.2493 }, { 0.8353, 0.3768 }, { 0.7454, 0.5028 }, { 0.8735, 0.3782 } },
		{ { 0.0000, 0.0000 }, { 0.1265, 0.3782 }, { 0.2546, 0.5028 }, { 0.1647, 0.3768 }, { 0.1148, 0.2353 }, { 0.2712, 0.4146 }, { 0.3627, 0.6485 }, { 0.3594, 0.6499 }, { 0.2163, 0.5406 }, { 0.2363, 0.6359 }, { 0.3028, 0.7031 }, { 0.3677, 0.7871 }, { 0.3577, 0.7843 }, { 0.2180, 0.6905 }, { 0.3012, 0.8067 }, { 0.4792, 1.0000 }, { 0.4592, 0.5938 }, { 0.3295, 0.3081 }, { 0.1547, 0.1331 }, { 0.0466, 0.0364 } },
	},
}

local view = {}

-- draws the logo h units tall with its left edge at x; returns its width
function view.logo(x, cy, h, c, a)
	local hp = math.max(1, math.floor(h * g.s + 0.5))
	local wp = math.max(1, math.floor(hp * LOGO.w + 0.5))
	local tex = LOGO.tex[hp]
	if tex == nil then
		if not LOGO.svg then
			local parts = {}
			for _, poly in ipairs(LOGO.polys) do
				for i, p in ipairs(poly) do
					parts[#parts + 1] = string.format("%s%.2f %.2f", i == 1 and "M" or "L", p[1] * 842, p[2] * 1000)
				end
				parts[#parts + 1] = "Z"
			end
			LOGO.svg = string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 842 1000" preserveAspectRatio="none"><path fill="#ffffff" d="%s"/></svg>', table.concat(parts, " "))
		end
		tex = Render.LoadSvgString(LOGO.svg, Vec2(wp, hp), "uikit_logo_" .. hp)
		if not tex or tex == 0 then tex = false end
		LOGO.tex[hp] = tex
	end
	if tex then Render.Image(tex, Vec2(g.px(x), math.floor(g.y + (cy - h / 2) * g.s + 0.5)), Vec2(wp, hp), g.col(c, a)) end
	return h * LOGO.w
end

-- ---------------------------------------------------------------------------
-- hit testing and animation
-- ---------------------------------------------------------------------------

function hit.begin()
	local prev = hit.list
	hit.list, hit.clip = {}, nil
	local mx, my = Input.GetCursorPos()
	hit.hover = nil
	for i = #prev, 1, -1 do
		local h = prev[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then
			hit.hover = h[5]
			break
		end
	end
	if P.press and P.press.id and hit.hover ~= P.press.id then hit.hover = nil end
	if P.drag or P.slide or P.sb_drag or P.resize then hit.hover = nil end
end

function hit.add(x, y, w, h, id, on)
	local x1, y1, x2, y2 = g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s
	if hit.clip then
		x1, y1 = math.max(x1, hit.clip[1]), math.max(y1, hit.clip[2])
		x2, y2 = math.min(x2, hit.clip[3]), math.min(y2, hit.clip[4])
		if x2 <= x1 or y2 <= y1 then return end
	end
	hit.list[#hit.list + 1] = { x1, y1, x2, y2, id, on or {} }
end

function hit.is(id) return hit.hover == id end

function hit.at(mx, my, field)
	for i = #hit.list, 1, -1 do
		local h = hit.list[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] and (not field or h[6][field]) then return h end
	end
	return nil
end

local anim = {}

function anim.tween(key, target, time, curve)
	local t = P.tweens[key]
	if not t or (t.seen and P.now - t.seen > 0.1) then
		t = { from = target, to = target, v = target, k = 1 }
		P.tweens[key] = t
	end
	t.seen = P.now
	if t.to ~= target then t.from, t.to, t.k = t.v, target, 0 end
	if t.k < 1 then
		t.k = math.min(1, t.k + P.dt / time)
		t.v = t.from + (t.to - t.from) * (curve or ease_out)(t.k)
	else
		t.v = t.to
	end
	return t.v
end

function anim.snap(key, value)
	P.tweens[key] = { from = value, to = value, v = value, k = 1, seen = P.now }
end

function anim.hover(id, on)
	if on == nil then on = hit.hover == id end
	return anim.tween("hv:" .. id, on and 1 or 0, 0.12)
end

function anim.mix(a, b, k)
	return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

-- ---------------------------------------------------------------------------
-- widgets (all coordinates in window units, cy = vertical center)
-- ---------------------------------------------------------------------------

function view.icon_button(x, y, size, glyph, id, active, click, danger)
	local hv = anim.hover(id)
	local ak = anim.tween("ib:" .. id, active and 1 or 0, 0.16)
	if U.flat then
		local c = danger and anim.mix(T.knob, T.red, hv) or anim.mix(anim.mix(T.knob, T.t3, hv), A, ak)
		g.glyph(glyph, 11, x + size / 2, y + size / 2, c, 1 - 0.2 * ak)
		hit.add(x, y, size, size, id, { click = click })
		return
	end
	local hc = danger and T.red or A
	g.rect(x, y, size, size, T.white, 2.5, 0.06 + 0.05 * ak)
	g.frame(x, y, size, size, T.white, 2.5, 0.08)
	if hv > 0.01 then
		g.rect(x, y, size, size, hc, 2.5, 0.14 * hv)
		g.brackets(x, y, size, size, 6, hc, hv, 1.5)
	end
	g.glyph(glyph, 14, x + size / 2, y + size / 2, anim.mix(T.t3, hc, math.max(ak, hv)))
	hit.add(x, y, size, size, id, { click = click })
end

function view.button(x, y, w, h, label, kind, id, click)
	local hv = anim.hover(id)
	if U.flat then
		local k = kind == "accent" and 1 or hv
		if hv > 0.01 then g.rect(x - 2, y - 2, w + 4, h + 4, A, 6, 0.10 * hv) end
		g.rect(x, y, w, h, anim.mix(C.menu, A, k), 4)
		g.text(500, 13, label, x + w / 2, y + h / 2, anim.mix(T.t3, T.white, k), 1, "c")
		hit.add(x, y, w, h, id, { click = click })
		return
	end
	if kind == "accent" then
		g.rect(x, y, w, h, A, 3, 0.9 + 0.1 * hv)
		g.text(600, 13, label, x + w / 2, y + h / 2, AON, 1, "c")
	elseif kind == "soft" then
		g.rect(x, y, w, h, A, 3, 0.14 + 0.08 * hv)
		g.frame(x, y, w, h, A, 3, 0.6 + 0.4 * hv)
		g.text(600, 13, label, x + w / 2, y + h / 2, AT, 1, "c")
	else
		g.rect(x, y, w, h, anim.mix(T.white, A, hv), 3, 0.07 + 0.07 * hv)
		g.frame(x, y, w, h, T.white, 3, 0.08)
		g.text(500, 13, label, x + w / 2, y + h / 2, anim.mix(T.t2, T.t1, hv), 1, "c")
	end
	if hv > 0.01 then g.brackets(x - 3, y - 3, w + 6, h + 6, 6, A, hv, 1.5) end
	hit.add(x, y, w, h, id, { click = click })
end

function view.badge(right, cy, text, c)
	local w = g.width(700, 10, text) + 12
	g.rect(right - w, cy - 8, w, 16, c or A, 8, 0.18)
	g.text(700, 10, text, right - w / 2, cy, c or AT, 1, "c")
	return w
end

-- popup or panel box: brand = cut corners (top-left, bottom-right) and a faint outline, flat = Umbrella box
function view.box(x, y, w, h, c, a)
	if U.flat then
		g.rect(x, y, w, h, c or C.card, 5, a)
		g.frame(x, y, w, h, C.line or T.white, 5, C.line and a or 0.09 * (a or 1))
		return
	end
	g.cut(x, y, w, h, c or C.card, a, 8, true, false, true, false)
	g.cut_frame(x, y, w, h, T.white, 0.09 * (a or 1), 1, 8, true, false, true, false)
end

function view.card(x, y, w, h)
	if U.flat then
		g.rect(x, y, w, h, C.card, 10)
		return
	end
	g.cut(x, y, w, h, C.card, 1, 8, true, false, true, false)
	g.rect(x + 8, y, 26, 2, A, 0, 0.9)
end

function view.section(x, y, w, title, count)
	if U.flat then
		g.rect(x, y + 3, 3, 14, A, 1.5)
		g.text(700, 12.5, title, x + 10, y + 10, T.t1)
		if count ~= nil then view.badge(x + w, y + 10, tostring(count)) end
		return 22
	end
	local right = x + w
	if count ~= nil then right = right - view.badge(right, y + 10, tostring(count)) - 8 end
	g.rect(x, y + 4, 3, 12, A, 0)
	local lx = x + 11 + g.track_fit(700, 11, title, x + 11, y + 10, T.t2, 1, 1.6, right - x - 11) + 10
	if right - lx > 8 then g.grad(lx, y + 10, right - lx, 1, A, 0.5, A, 0) end
	return 22
end

function view.caption(x, y, w, text, count)
	local wt = U.flat and 500 or 600
	local cw = count ~= nil and g.text(wt, 11.5, tostring(count), x + w, y + 7, T.t4, nil, "r") + 8 or 0
	g.text(wt, 11.5, g.fit(wt, 11.5, text, w - cw), x, y + 7, T.t3)
	return 22
end

function view.switch(x, cy, on, id, click, mini)
	local k = anim.tween("sw:" .. id, on and 1 or 0, 0.18, ease_in_out)
	if U.flat then
		local w, h = mini and 18 or 26, mini and 11 or 14
		g.rect(x, cy - h / 2, w, h, anim.mix(C.off, A, k), h / 2, 1 - 0.2 * k)
		g.dot(x + h / 2 + (w - h) * k, cy, h / 2 - 3, anim.mix(T.knob, C.win, k))
		hit.add(x - 4, cy - h / 2 - 4, w + 8, h + 8, id, { click = click })
		return
	end
	local w, h = mini and 28 or 40, mini and 16 or 22
	local kn = h - 6
	g.rect(x, cy - h / 2, w, h, anim.mix(C.off, A, k), 3)
	g.rect(x + 3 + (w - kn - 6) * k, cy - kn / 2, kn, kn, k > 0.5 and C.win or T.t2, 2)
	hit.add(x - 4, cy - h / 2 - 4, w + 8, h + 8, id, { click = click })
end

function view.toggle_row(x, y, w, label, on, id, click, sub)
	local hv = anim.hover(id)
	if U.flat then
		local h = math.floor(sub and g.lay(40, 34) or g.lay(28, 24))
		if sub then
			g.text(500, 12.5, g.fit(500, 12.5, label, w - 50), x + 10, y + 13, anim.mix(T.t3, T.t1, hv))
			g.text(500, 11, g.fit(500, 11, sub, w - 50), x + 10, y + 28, T.t4)
		else
			g.text(500, 12.5, g.fit(500, 12.5, label, w - 50), x + 10, y + h / 2, anim.mix(T.t3, T.t1, hv))
		end
		view.switch(x + w - 36, y + h / 2, on, id .. ":sw", click)
		hit.add(x, y, w - 40, h, id, { click = click })
		return h
	end
	local h = math.floor(sub and g.lay(44, 38) or g.lay(36, 30))
	g.rect(x, y, w, h, T.white, 3, 0.04 * hv)
	if sub then
		g.text(600, 13, g.fit(600, 13, label, w - 70), x + 10, y + h / 2 - 8, T.t1)
		g.text(400, 11.5, g.fit(400, 11.5, sub, w - 70), x + 10, y + h / 2 + 8, T.t3)
	else
		g.text(600, 13, g.fit(600, 13, label, w - 70), x + 10, y + h / 2, T.t1)
	end
	view.switch(x + w - 48, y + h / 2, on, id .. ":sw", click)
	hit.add(x, y, w - 54, h, id, { click = click })
	return h
end

function view.slider(x, cy, w, id, value, min, max, step, on_change, on_done, fmt)
	local v = clamp((value - min) / (max - min), 0, 1)
	local hot = hit.is(id) or (P.slide ~= nil and P.slide.id == id)
	local label = fmt and string.format(fmt, value) or tostring(value)
	local lw = 44
	local tx, tw = x, w - lw - 8
	local th = U.flat and 5 or 4
	g.rect(tx, cy - th / 2, tw, th, C.off, th / 2)
	if v > 0 then g.rect(tx, cy - th / 2, tw * v, th, A, th / 2) end
	if U.flat then
		g.dot(tx + tw * v, cy, hot and 6.5 or 5.5, T.white)
	else
		local kh = hot and 20 or 18
		g.rect(tx + tw * v - 5, cy - kh / 2, 10, kh, T.t1, 2)
	end
	g.text(U.flat and 500 or 600, 12, label, x + w, cy, T.t2, 1, "r")
	local ax, aw = g.x + tx * g.s, tw * g.s
	hit.add(tx - 10, cy - 14, tw + 20, 28, id, { down = function(mx)
		P.slide = { id = id, x = ax, w = aw, min = min, max = max, step = step or 1,
			change = on_change, done = on_done, value = value }
		view.slide_to(mx)
	end })
end

function view.slide_to(mx)
	local sl = P.slide
	local v = clamp((mx - sl.x) / sl.w, 0, 1)
	local value = sl.min + math.floor((sl.max - sl.min) * v / sl.step + 0.5) * sl.step
	if value ~= sl.value then
		sl.value = value
		if sl.change then sl.change(value) end
	end
end

function view.tabs(x, y, w, labels, cur, pick, id)
	id = id or "tabs"
	local seg = w / #labels
	if not U.flat then
		-- brand segment: solid accent thumb, separators between the other cells
		g.rect(x, y, w, 32, T.white, 3, 0.07)
		local hx = anim.tween(id .. ":x", cur - 1, 0.3, ease_in_out)
		g.rect(x + 2 + hx * seg, y + 2, seg - 4, 28, A, 2.5)
		for i, label in ipairs(labels) do
			local tid = id .. ":" .. i
			local hv = anim.hover(tid)
			if i > 1 and i ~= cur and i - 1 ~= cur then g.vl(x + (i - 1) * seg, y + 9, 14, T.white, 0.12) end
			local c = i == cur and AON or anim.mix(T.t3, T.t1, hv)
			g.text(600, 12.5, g.fit(600, 12.5, label, seg - 10), x + (i - 0.5) * seg, y + 16, c, 1, "c")
			hit.add(x + (i - 1) * seg, y, seg, 32, tid, { click = function()
				if i ~= cur then pick(i) end
			end })
		end
		return 32
	end
	g.rect(x, y, w, 32, T.white, 9, 0.055)
	local hx = anim.tween(id .. ":x", cur - 1, 0.22, ease_in_out)
	g.rect(x + 2 + hx * seg, y + 2, seg - 4, 28, A, 7, 0.26)
	for i, label in ipairs(labels) do
		local tid = id .. ":" .. i
		local hv = anim.hover(tid)
		local on = i == cur
		local c = on and T.white or anim.mix(T.t3, T.t1, hv)
		g.text(on and 700 or 600, 12, g.fit(600, 12, label, seg - 10), x + (i - 0.5) * seg, y + 16, c, 1, "c")
		hit.add(x + (i - 1) * seg, y, seg, 32, tid, { click = function()
			if i ~= cur then pick(i) end
		end })
	end
	return 32
end

-- right-aligned compact segmented choice for setting rows; options = {{value, label}}; returns width
function view.choice(right, cy, id, options, cur, pick)
	local widths, total = {}, 4
	for i, o in ipairs(options) do
		widths[i] = g.width(500, 12, o.label) + 22
		total = total + widths[i]
	end
	local x = right - total
	g.rect(x, cy - 14, total, 28, T.white, 3, 0.07)
	local sx, sw, bx = 2, widths[1], 2
	for i, o in ipairs(options) do
		if o.value == cur then sx, sw = bx, widths[i] end
		bx = bx + widths[i]
	end
	local tx = anim.tween(id .. ":x", sx, 0.28, ease_in_out)
	local tw = anim.tween(id .. ":w", sw, 0.28, ease_in_out)
	g.rect(x + tx, cy - 12, tw, 24, A, 2.5)
	bx = x + 2
	for i, o in ipairs(options) do
		local oid = id .. ":" .. i
		local c = o.value == cur and AON or anim.mix(T.t3, T.t1, anim.hover(oid))
		g.text(500, 12, o.label, bx + widths[i] / 2, cy, c, 1, "c")
		hit.add(bx, cy - 12, widths[i], 24, oid, { click = function()
			if o.value ~= cur then pick(o.value) end
		end })
		bx = bx + widths[i]
	end
	return total
end

function view.row(x, y, w, h, o)
	local hv = o.id and anim.hover(o.id) or 0
	local sel = anim.tween("row_sel:" .. (o.id or ""), o.selected and 1 or 0, 0.14)
	if sel > 0.01 then
		g.rect(x, y, w, h, A, 8, (U.flat and 0.16 or 0.12) * sel)
		if not U.flat then g.rect(x, y, 2, h, A, 0, sel) end
	end
	if hv > 0.01 then g.rect(x, y, w, h, T.white, 8, 0.05 * hv) end
	local tx = x + 10
	local icon = math.min(h - 10, 28)
	if o.img or o.img_label then
		g.square(o.img, o.img_label or o.title, tx, y + (h - icon) / 2, icon, 1, 6, o.gray and 1 or 0)
		tx = tx + icon + 10
	elseif o.glyph then
		g.glyph(o.glyph, 13, tx + 8, y + h / 2, o.glyph_c or T.t3)
		tx = tx + 26
	end
	local vw = 0
	if o.value then
		vw = g.text(700, 12.5, o.value, x + w - 10, y + h / 2, o.value_c or T.t1, 1, "r") + 12
	end
	local max_w = x + w - 10 - vw - tx
	if o.sub then
		g.text(600, 12.5, g.fit(600, 12.5, o.title, max_w), tx, y + h / 2 - 8, T.t1)
		g.text(500, 11, g.fit(500, 11, o.sub, max_w), tx, y + h / 2 + 8, T.t3)
	else
		g.text(600, 12.5, g.fit(600, 12.5, o.title, max_w), tx, y + h / 2, T.t1)
	end
	if o.id then hit.add(x, y, w, h, o.id, { click = o.click, rclick = o.rclick }) end
	return h
end

function view.grid(x, y, w, items, size, gap, id, click)
	size, gap = size or 32, gap or 6
	local per_row = math.max(1, math.floor((w + gap) / (size + gap)))
	for i, it in ipairs(items) do
		local col, row = (i - 1) % per_row, (i - 1) // per_row
		local ix, iy = x + col * (size + gap), y + row * (size + gap)
		local cid = id .. ":" .. tostring(it.key)
		local hv = anim.hover(cid)
		local on = it.on ~= false
		local k = anim.tween("gr:" .. cid, on and 1 or 0, 0.14)
		local r = U.flat and 2 or 8
		g.square(it.img, it.label, ix, iy, size, 0.45 + 0.55 * math.max(k, hv * 0.6), r, 1 - k)
		if k > 0.01 and not U.flat then g.frame(ix, iy, size, size, A, r, k, 1.5) end
		if hv > 0.01 and (U.flat or k < 0.99) then g.frame(ix, iy, size, size, T.white, r, 0.25 * hv) end
		if it.dot then g.dot(ix + size - 4, iy + 4, 3.5, it.dot) end
		hit.add(ix, iy, size, size, cid, { click = function() click(it, i) end })
		if it.label then view.hint(cid, it.label) end
	end
	local rows = math.max(1, math.ceil(#items / per_row))
	return rows * (size + gap) - gap
end

function view.status(x, cy, w, glyph, text, c)
	c = c or T.t3
	local tx = x
	if glyph then
		g.glyph(glyph, 11, x + 6, cy, c)
		tx = x + 18
	end
	g.text(500, 11.5, g.fit(500, 11.5, text, w - (tx - x)), tx, cy, c)
end

function view.empty(x, y, w, h, glyph, text)
	g.glyph(glyph or K.G.empty, 20, x + w / 2, y + h / 2 - 12, T.t4)
	local lines = g.wrap(500, 12, text, w - 32)
	for i = 1, math.min(3, #lines) do
		g.text(500, 12, lines[i], x + w / 2, y + h / 2 + 10 + (i - 1) * 16, T.t3, 1, "c")
	end
end

function view.swatches(right, cy, order, cur, color, pick, prefix)
	local size, gap = 18, 8
	local x = right - (#order * size + (#order - 1) * gap)
	for i, id in ipairs(order) do
		local key = prefix .. id
		local hv = anim.hover(key)
		local on = anim.tween("swt:" .. key, cur == id and 1 or 0, 0.16)
		local sx = x + (i - 1) * (size + gap) + size / 2
		g.dot(sx, cy, size / 2 - 1 + 0.8 * hv, color(id))
		g.ring(sx, cy, size / 2 - 1, T.white, 0.14, 1)
		if on > 0.01 then g.ring(sx, cy, size / 2 + 3, T.white, 0.85 * on, 1.5) end
		hit.add(sx - size / 2 - gap / 2, cy - size / 2 - 4, size + gap, size + 8, key, { click = function() pick(id) end })
	end
end

function view.theme_settings(x, y, w, labels)
	local rows = 0
	if not K.SMALL then
		g.text(600, 12.5, labels.theme, x, y + 14, T.t2)
		view.swatches(x + w, y + 14, THEME_ORDER, P.set.theme, function(id) return THEMES[id].card end, function(id)
			P.set.theme = id
			apply_theme()
			save("theme", id)
		end, "th:")
		g.text(600, 12.5, labels.accent, x, y + 46, T.t2)
		view.swatches(x + w, y + 46, ACCENT_ORDER, P.set.accent, function(id) return ACCENTS[id] end, function(id)
			P.set.accent = id
			apply_theme()
			save("accent", id)
		end, "ac:")
		rows = 64
	end
	g.text(600, 12.5, labels.scale, x, y + rows + 14, T.t2)
	view.slider(x + w * 0.42, y + rows + 14, w * 0.58, "set_scale", P.set.scale, 70, 150, 5,
		function(v) P.set.scale = v end, function(v) save("scale", v) end, "%d%%")
	g.text(600, 12.5, labels.opacity, x, y + rows + 46, T.t2)
	view.slider(x + w * 0.42, y + rows + 46, w * 0.58, "set_opacity", P.set.opacity, 40, 100, 5,
		function(v) P.set.opacity = v end, function(v) save("opacity", v) end, "%d%%")
	if not labels.compact then return rows + 64 end
	g.text(600, 12.5, labels.compact, x, y + rows + 78, T.t2)
	view.switch(x + w - (U.flat and 26 or 40), y + rows + 78, P.set.compact, "set_compact", function()
		P.set.compact = not P.set.compact
		save("compact", P.set.compact)
	end)
	return rows + 96
end

-- ---------------------------------------------------------------------------
-- dropdown: the field is drawn in place, the open list is drawn last, above everything
-- ---------------------------------------------------------------------------

function view.dropdown(x, y, w, id, options, cur, pick)
	local did = "dd:" .. id
	local open = P.menu == id
	local hv = anim.hover(did)
	local k = anim.tween("dd_on:" .. id, open and 1 or 0, 0.16)
	g.rect(x, y, w, 28, C.menu, 7)
	local fa = 0.14 * hv + (0.18 - 0.14 * hv) * k
	if fa > 0.005 then g.frame(x, y, w, 28, T.white, 7, fa) end
	local label = "?"
	for _, o in ipairs(options) do
		if o.value == cur then label = o.label end
	end
	g.text(500, 12, g.fit(500, 12, label, w - 34), x + 10, y + 14, T.t2)
	g.glyph(open and K.G.up or K.G.down, 9, x + w - 14, y + 14, T.t3)
	hit.add(x, y, w, 28, did, { click = function() P.menu = open and nil or id end })
	if open or k > 0.01 then
		P.menu_req = { x = g.x + x * g.s, y = g.y + (y + 32) * g.s, w = w, id = id, options = options, cur = cur, pick = pick, k = k }
	end
end

function view.draw_menu()
	local m = P.menu_req
	P.menu_req = nil
	if not m or m.k <= 0.01 then return end
	local ox, oy, oa = g.x, g.y, g.a
	g.x, g.y = m.x, m.y
	g.a = oa * m.k
	local h = 8 + #m.options * 28
	local dy = -6 * (1 - m.k)
	g.shadow(0, dy, m.w, h, 8, 0.10)
	view.box(0, dy, m.w, h, C.menu)
	hit.add(0, dy, m.w, h, "menu:" .. m.id .. ":bg")
	for i, o in ipairs(m.options) do
		local oid = "menu:" .. m.id .. ":" .. tostring(o.value)
		local iy = dy + 4 + (i - 1) * 28
		local hv = anim.hover(oid)
		g.rect(4, iy, m.w - 8, 28, T.white, 5, 0.08 * hv)
		local on = o.value == m.cur
		g.text(on and 600 or 500, 12, g.fit(500, 12, o.label, m.w - 36), 12, iy + 14, on and AT or T.t2)
		if on then g.glyph(K.G.check, 10, m.w - 16, iy + 14, AT) end
		if P.menu == m.id then
			hit.add(4, iy, m.w - 8, 28, oid, { click = function()
				P.menu = nil
				if o.value ~= m.cur then m.pick(o.value) end
			end })
		end
	end
	g.x, g.y, g.a = ox, oy, oa
end

-- ---------------------------------------------------------------------------
-- scroll areas (one state per id; wheel and a draggable thumb)
-- ---------------------------------------------------------------------------

function view.scroll_begin(id, x, y, w, h)
	local s = P.scroll[id]
	if not s then
		s = { f = 0, to = 0, v = 0, content = 0, view = h, t = -10 }
		P.scroll[id] = s
	end
	s.view, s.area = h, { x, y, w, h }
	local diff = s.to - s.f
	if math.abs(diff) * g.s < 0.5 then s.f = s.to else s.f = s.f + diff * (1 - math.exp(-P.dt * 18)) end
	s.v = math.floor(s.f * g.s + 0.5) / g.s
	hit.add(x, y, w, h, "scroll:" .. id, { wheel = function(dir)
		s.n = (P.now - (s.wt or -10) < 0.12) and math.min((s.n or 0) + 1, 6) or 0
		s.wt = P.now
		s.to = clamp(s.to + dir * K.WHEEL * (1 + s.n * 0.25), 0, math.max(0, s.content - s.view))
		s.t = P.now
	end })
	g.clip(x, y, w, h)
	return y - s.v
end

function view.scroll_end(id, content_h)
	local s = P.scroll[id]
	g.unclip()
	s.content = content_h
	local max_scroll = math.max(0, content_h - s.view)
	if s.to > max_scroll then s.to, s.f, s.v = max_scroll, max_scroll, max_scroll end
	local ax, ay, aw, ah = s.area[1], s.area[2], s.area[3], s.area[4]
	local ta = clamp(s.v / 14, 0, 1)
	if ta > 0.01 then g.hl(ax + 10, ay, aw - 20, T.white, 0.08 * ta) end
	if max_scroll <= 0 then return end
	local track = ah - 8
	local thumb = math.max(24, track * s.view / content_h)
	local span = math.max(1, track - thumb)
	local top = ay + 4 + span * clamp(s.v / max_scroll, 0, 1)
	local sid = "sb:" .. id
	local hot = hit.is(sid) or (P.sb_drag ~= nil and P.sb_drag.id == id)
	local sa = anim.tween(sid, (hot or P.now - s.t < 0.9) and 1 or 0, 0.2)
	if sa > 0.01 and U.flat then
		local bw = hot and 5 or 3
		g.rect(ax + aw - bw - 2, top, bw, thumb, T.white, bw / 2, (hot and 0.42 or 0.24) * sa)
	elseif sa > 0.01 then
		-- brand: a track shows on hover and the thumb widens from 4 to 6
		local wide = anim.tween(sid .. ":w", hot and 1 or 0, 0.15)
		if wide > 0.01 then g.rect(ax + aw - 10, ay + 4, 8, track, T.white, 4, 0.05 * sa * wide) end
		local bw = 4 + 2 * wide
		g.rect(ax + aw - 6 - bw / 2, top, bw, thumb, hot and T.t2 or T.t3, 3, sa)
	end
	hit.add(ax + aw - 12, ay + 4, 12, track, sid, { down = function(_, my)
		P.sb_drag = { id = id, my = my, v = s.v, k = max_scroll / span }
		s.t = P.now
	end })
end

function view.scroll_drag(my)
	local d = P.sb_drag
	local s = P.scroll[d.id]
	if not s then return end
	local v = clamp(d.v + (my - d.my) / g.s * d.k, 0, math.max(0, s.content - s.view))
	s.to, s.f, s.v, s.t = v, v, v, P.now
end

-- ---------------------------------------------------------------------------
-- hover hints and toasts (screen space, drawn after the window)
-- ---------------------------------------------------------------------------

function view.hint(id, text)
	if hit.is(id) then P.tip_req = { id = id, text = text } end
end

function view.draw_tip()
	local req = P.tip_req
	P.tip_req = nil
	local id = req and req.id
	if id ~= P.tip_id then P.tip_id, P.tip_since = id, P.now end
	if not req or P.drag or P.slide or P.press then return end
	local k = clamp((P.now - P.tip_since - K.TIP_DELAY) / 0.12, 0, 1)
	if k <= 0 then return end
	local ox, oy, oa = g.x, g.y, g.a
	g.x, g.y, g.a = 0, 0, k
	local mx, my = Input.GetCursorPos()
	local screen = Render.ScreenSize()
	local w = g.width(600, 12, req.text) + 20
	local x = clamp(mx / g.s - w / 2, 4, screen.x / g.s - w - 4)
	local y = my / g.s + 22
	if (y + 30) * g.s > screen.y then y = my / g.s - 36 end
	g.rect(x, y, w, 26, C.menu, 7)
	g.frame(x, y, w, 26, T.white, 7, 0.12)
	g.text(600, 12, req.text, x + 10, y + 13, T.t1)
	g.x, g.y, g.a = ox, oy, oa
end

function view.toast(text, kind)
	table.insert(P.toasts, 1, { text = text, kind = kind or "info", t = P.now, id = tostring(P.now) .. text })
	while #P.toasts > 4 do table.remove(P.toasts) end
end

function view.draw_toasts()
	if #P.toasts == 0 then return end
	local ox, oy, oa = g.x, g.y, g.a
	local screen = Render.ScreenSize()
	g.x, g.y = 0, 0
	local w = 280
	local x = screen.x / g.s - w - 20
	local y = screen.y / g.s - 90
	for i = #P.toasts, 1, -1 do
		local t = P.toasts[i]
		local age = P.now - t.t
		if age > K.TOAST_TIME + 0.3 or t.closed then table.remove(P.toasts, i) end
	end
	for i, t in ipairs(P.toasts) do
		local age = P.now - t.t
		local k = math.min(1, age / 0.18) * clamp((K.TOAST_TIME + 0.3 - age) / 0.3, 0, 1)
		local target = (i - 1) * 50
		t.slide = t.slide and t.slide + (target - t.slide) * (1 - math.exp(-P.dt * 14)) or target
		local ty = y - t.slide + (1 - k) * 10
		g.a = k
		local c = t.kind == "ok" and T.green or (t.kind == "error" and T.red or (t.kind == "warn" and T.yellow or A))
		local glyph = t.kind == "ok" and K.G.ok or ((t.kind == "error" or t.kind == "warn") and K.G.warn or K.G.info)
		g.shadow(x, ty, w, 42, 10, 0.10)
		g.rect(x, ty, w, 42, C.win, 10, 0.97)
		g.frame(x, ty, w, 42, T.white, 10, 0.10)
		if not U.flat then g.rect(x, ty, 2, 42, c, 0) end
		g.glyph(glyph, 13, x + 20, ty + 21, c)
		g.text(500, 12.5, g.fit(500, 12.5, t.text, w - 48), x + 36, ty + 21, T.t1)
		hit.add(x, ty, w, 42, "toast:" .. t.id, { click = function() t.closed = true end })
	end
	g.x, g.y, g.a = ox, oy, oa
end

-- ---------------------------------------------------------------------------
-- on-screen pill (small overlays: icon on the left, short text, dark rounded capsule)
-- ---------------------------------------------------------------------------

function view.pill(x, cy, o)
	local h = 26
	local tw = o.text and g.width(700, 12, o.text) or 0
	local dw = o.detail and (g.width(500, 11, o.detail) + 17) or 0
	local w = h + (tw > 0 and tw + 10 or 0) + dw + (tw > 0 and 10 or 0)
	local y = cy - h / 2
	g.rect(x, y, w, h, { 14, 16, 18 }, h / 2, 0.72)
	local isz = h - 6
	if o.img then
		g.square(o.img, o.text, x + 3, y + 3, isz, 1, isz / 2, o.gray and 1 or 0)
	elseif o.glyph then
		g.glyph(o.glyph, 11, x + h / 2, cy, o.c or T.t1)
	end
	local tx = x + h + 4
	if tw > 0 then
		g.text(700, 12, o.text, tx, cy, o.c or T.t1)
		tx = tx + tw + 8
	end
	if dw > 0 then
		g.vl(tx, cy - 7, 14, T.white, 0.18)
		g.text(500, 11, o.detail, tx + 8, cy, T.t3)
	end
	if o.id then hit.add(x, y, w, h, o.id, { click = o.click }) end
	return w
end

-- ---------------------------------------------------------------------------
-- loading and status: spinner, logo orbit, loader card, animated status pill
-- ---------------------------------------------------------------------------

function view.spinner(cx, cy, r, c, a)
	g.ring(cx, cy, r, T.t4, a, 1.5)
	g.arc(cx, cy, r, c or T.t1, a, 1.5, (P.now * 400) % 360, 0.25)
end

function view.orbit(cx, cy, r, a)
	g.dot(cx, cy, r, C.menu, a)
	for i = 0, 1 do
		local t = (P.now * 0.45 + i * 0.5) % 1
		g.ring(cx, cy, r + r * 0.5 * t, A, (a or 1) * (1 - t) * 0.5, 1.5)
	end
	g.arc(cx, cy, r, A, (a or 1) * 0.9, 2, (P.now * 80) % 360, 0.28)
	local lh = math.floor(r * 1.2)
	view.logo(cx - lh * LOGO.w / 2, cy, lh, T.t1, a)
end

-- loading card: logo orbit, tracked title, one line of text, an indeterminate bar; returns height
function view.loader(x, y, w, title, text)
	local h, cx = 224, x + w / 2
	view.box(x, y, w, h)
	view.orbit(cx, y + 74, 40, 1)
	g.track_fit(700, 14, title, cx, y + 144, T.t1, 1, 3, w - 32, "c")
	if text then g.text(500, 12, g.fit(500, 12, text, w - 32), cx, y + 168, T.t2, 1, "c") end
	local bw, by = math.min(200, w - 40), y + 192
	g.rect(cx - bw / 2, by, bw, 3, C.off, 0)
	local sw = bw * 0.4
	local from = -sw + (bw + sw) * ((P.now * 0.7) % 1)
	local l, r = math.max(0, from), math.min(bw, from + sw)
	if r > l then g.rect(cx - bw / 2 + l, by, r - l, 3, A, 0) end
	return h
end

-- status pill that grows from the right edge and cross-fades its colour when o.kind changes.
-- o = {id, kind = "accent"|"loading"|"ok"|"error"|nil (hidden), label, glyph, click, hint}; returns its left x
local PILLS = {}
function view.status_pill(right, cy, o)
	local st = PILLS[o.id]
	if not st then
		st = { at = -10 }
		PILLS[o.id] = st
	end
	local kind = o.label and o.kind or nil
	if kind ~= st.kind then st.prev, st.kind, st.at = st.col, kind, P.now end
	local col, tc
	if kind == "accent" then col, tc = { A[1], A[2], A[3] }, AON
	elseif kind == "loading" then col, tc = { A[1], A[2], A[3], 90 }, T.t1
	elseif kind == "ok" then col, tc = { T.green[1], T.green[2], T.green[3], 72 }, T.green
	elseif kind == "error" then col, tc = { T.red[1], T.red[2], T.red[3], 72 }, T.red end
	local content = kind and (18 + 7 + g.width(500, 12.5, o.label)) or 0
	local w = anim.tween("pill_w:" .. o.id, kind and content + 22 or 0, 0.28, ease_in_out)
	local k = anim.tween("pill_a:" .. o.id, kind and 1 or 0, 0.2)
	if w < 1 then return right end
	col = col or st.col or A
	st.col = col
	local prev = st.prev or col
	local m = math.min(1, (P.now - st.at) / 0.25)
	local bg = { prev[1] + (col[1] - prev[1]) * m, prev[2] + (col[2] - prev[2]) * m, prev[3] + (col[3] - prev[3]) * m,
		(prev[4] or 255) + ((col[4] or 255) - (prev[4] or 255)) * m }
	local x, h = right - w, 26
	g.clip(x, cy - h / 2, w, h)
	g.rect(x, cy - h / 2, w, h, bg, 3, k * (hit.is(o.id) and 0.85 or 1))
	if kind then
		local la = k * math.min(1, (P.now - st.at) / 0.18)
		if kind == "loading" then view.spinner(x + 19, cy, 5.5, tc, la)
		elseif o.glyph then g.glyph(o.glyph, 12, x + 19, cy, tc, la) end
		g.text(500, 12.5, o.label, x + 36, cy, tc, la)
	end
	g.unclip()
	if kind and o.click then hit.add(x, cy - h / 2, w, h, o.id, { click = o.click }) end
	if kind and o.hint then view.hint(o.id, o.hint) end
	return x
end

-- ---------------------------------------------------------------------------
-- context menu (right click) and the bottom action bar
-- ---------------------------------------------------------------------------

-- o = {title, w, items = {{label, glyph | img, hint, check, danger, disabled, click} | {sep = true} | {section = text}}}
function view.ctx_open(mx, my, o)
	P.ctx, P.menu = { x = mx + 2, y = my + 2, o = o, t = P.now }, nil
end

function view.draw_ctx()
	local m = P.ctx
	if not m then return end
	local ox, oy, oa = g.x, g.y, g.a
	g.x, g.y, g.a = 0, 0, oa * math.min(1, (P.now - m.t) / 0.12)
	local items, w = m.o.items, m.o.w or 220
	local h = (m.o.title and 30 or 4) + 4
	for _, it in ipairs(items) do h = h + (it.sep and 9 or (it.section and 22 or 30)) end
	local screen = Render.ScreenSize()
	local x = clamp(m.x / g.s, 4, screen.x / g.s - w - 4)
	local y = clamp(m.y / g.s, 4, screen.y / g.s - h - 4)
	hit.add(x, y, w, h, "ctx:bg")
	g.shadow(x, y, w, h, 8, 0.10)
	view.box(x, y, w, h, C.menu)
	local iy = y + 4
	if m.o.title then
		g.text(700, 12.5, g.fit(700, 12.5, m.o.title, w - 24), x + 12, y + 16, T.t1)
		iy = y + 30
	end
	for n, it in ipairs(items) do
		if it.sep then
			g.hl(x + 8, iy + 4, w - 16, T.white, 0.08)
			iy = iy + 9
		elseif it.section then
			if U.flat then g.text(600, 11, it.section, x + 12, iy + 11, T.t4)
			else g.track_fit(600, 10.5, it.section, x + 12, iy + 11, T.t4, 1, 1.2, w - 24) end
			iy = iy + 22
		else
			local id, ia = "ctx:" .. n, it.disabled and 0.35 or 1
			local hv = it.disabled and 0 or anim.hover(id)
			if hv > 0.01 then g.rect(x + 4, iy, w - 8, 30, it.danger and T.red or A, 4, hv) end
			local tc = anim.mix(it.danger and T.red or T.t1, it.danger and T.white or AON, hv)
			if it.img or it.img_label then g.square(it.img, it.img_label or it.label, x + 12, iy + 6, 18, ia, 2)
			elseif it.glyph then g.glyph(it.glyph, 12, x + 21, iy + 15, tc, ia) end
			local lw = g.text(500, 12.5, g.fit(500, 12.5, it.label, w - 50), x + 36, iy + 15, tc, ia)
			if it.hint then
				g.text(500, 11, g.fit(500, 11, it.hint, w - 36 - lw - 24), x + w - 12, iy + 15, anim.mix(T.t4, tc, hv), ia, "r")
			elseif it.check then
				g.glyph(K.G.check, 10, x + w - 18, iy + 15, tc, ia)
			end
			if not it.disabled then
				hit.add(x + 4, iy, w - 8, 30, id, { click = function()
					P.ctx = nil
					if it.click then it.click() end
				end })
			end
			iy = iy + 30
		end
	end
	g.x, g.y, g.a = ox, oy, oa
end

-- keycap hint ("Enter", "Esc"); returns width
function view.key(x, cy, text, a)
	local w = g.width(600, 10.5, text) + 12
	g.rect(x, cy - 9, w, 18, T.black, 4, 0.28 * (a or 1))
	g.text(600, 10.5, text, x + w / 2, cy, T.t1, a, "c")
	return w
end

-- bottom action bar that slides in while o.on: icon, title, sub, buttons on the right with keycaps.
-- o = {id, on, img, img_label, glyph, title, sub, buttons = {{label, key, kind = "accent"|"danger"|nil, id, click}}}
-- returns the visible height (0 when hidden)
function view.action_bar(x, y, w, o)
	local k = anim.tween("bar:" .. o.id, o.on and 1 or 0, 0.2)
	if k <= 0.01 then return 0 end
	local h, by = 64, y + (1 - k) * 8
	hit.add(x, by, w, h, o.id, {})
	view.box(x, by, w, h, C.menu, k)
	local tx = x + 12
	if o.img or o.img_label then
		g.square(o.img, o.img_label or o.title, tx, by + 12, 40, k, 4)
		tx = tx + 52
	elseif o.glyph then
		g.glyph(o.glyph, 16, tx + 14, by + h / 2, A, k)
		tx = tx + 36
	end
	local bx = x + w - 12
	for i = #(o.buttons or {}), 1, -1 do
		local b = o.buttons[i]
		local kw = b.key and g.width(600, 10.5, b.key) + 20 or 0
		local bw = g.width(600, 12.5, b.label) + kw + 28
		bx = bx - bw
		local hv = anim.hover(b.id)
		local fill = b.kind == "accent" and A or (b.kind == "danger" and T.red or nil)
		if fill then g.rect(bx, by + 14, bw, 36, fill, 4, k * (0.9 + 0.1 * hv))
		else g.rect(bx, by + 14, bw, 36, T.white, 4, k * (0.08 + 0.05 * hv)) end
		local tc = b.kind == "accent" and AON or (b.kind == "danger" and T.white or T.t1)
		local lx = bx + 14 + g.text(600, 12.5, b.label, bx + 14, by + 32, tc, k) + 8
		if b.key then view.key(lx, by + 32, b.key, k) end
		hit.add(bx, by + 14, bw, 36, b.id, { click = b.click })
		bx = bx - 8
	end
	local tw = bx - tx - 4
	if o.sub then
		g.text(700, 14, g.fit(700, 14, o.title, tw), tx, by + 24, T.t1, k)
		g.text(500, 11.5, g.fit(500, 11.5, o.sub, tw), tx, by + 42, T.t3, k)
	else
		g.text(700, 14, g.fit(700, 14, o.title, tw), tx, by + h / 2, T.t1, k)
	end
	return h * k
end

-- ---------------------------------------------------------------------------
-- text input: typed text comes from a hidden Panorama TextEntry (any layout, Cyrillic, Ctrl+V)
-- ---------------------------------------------------------------------------

local JS_SINK = [[
(function () {
	let root = $.GetContextPanel();
	while (root.GetParent()) root = root.GetParent();
	let sink = root.FindChild('%s');
	const drop = () => {
		sink.text = '';
		sink.DeleteAsync(0);
	};
	if (%s) {
		if (!sink) {
			sink = $.CreatePanel('TextEntry', root, '%s');
			sink.style.width = '1px';
			sink.style.height = '1px';
			sink.style.opacity = '0';
			sink.hittest = false;
			sink.SetPanelEvent('ontextentrychange', () => {
				if (!sink.IsValid() || sink.text === '') return;
				const typed = sink.GetAttributeString('typed', '') + sink.text;
				sink.text = '';
				sink.SetAttributeString('typed', typed);
			});
			const watch = () => {
				if (!sink.IsValid()) return;
				if (Date.now() - Number(sink.GetAttributeString('alive', '0')) > %d) return drop();
				$.Schedule(0.25, watch);
			};
			$.Schedule(0.25, watch);
		}
		sink.SetAttributeString('alive', String(Date.now()));
		sink.text = '';
		sink.SetFocus();
	} else if (sink) {
		drop();
	}
})();
]]

local CHARS = {}
for i = 0, 25 do
	local letter = string.char(65 + i)
	CHARS[KEY["KEY_" .. letter]] = letter:lower()
end
for i = 0, 9 do CHARS[KEY["KEY_" .. i]] = tostring(i) end
CHARS[KEY.KEY_SPACE] = " "

local edit = { sink_on = false, sink_at = 0, typed_ok = false, pend = {}, pend_t = 0, panel = nil, find_at = -10 }

function edit.sink(on, force)
	if edit.sink_on == on and not force and not (on and P.now >= edit.sink_at) then return end
	edit.sink_on, edit.sink_at = on, P.now + K.SINK_ALIVE
	Engine.RunScript(JS_SINK:format(K.SINK_ID, on and "true" or "false", K.SINK_ID, K.SINK_TIMEOUT))
end

function edit.field(f)
	f.text = f.text or ""
	f.caret = f.caret or #g.chars(f.text)
	return f
end

function edit.range(f)
	if f.anchor and f.anchor ~= f.caret then return math.min(f.anchor, f.caret), math.max(f.anchor, f.caret) end
	return nil
end

function edit.put(f, chars, caret)
	f.text, f.caret, f.anchor = table.concat(chars), caret, nil
	f.blink = P.now
	if f.on_change then f.on_change(f.text) end
end

function edit.cut(f, chars)
	local lo, hi = edit.range(f)
	if not lo then return chars, f.caret end
	local out = {}
	for i = 1, lo do out[#out + 1] = chars[i] end
	for i = hi + 1, #chars do out[#out + 1] = chars[i] end
	return out, lo
end

function edit.insert(f, str)
	local chars, caret = edit.cut(f, g.chars(f.text))
	if #chars >= (f.max or 64) then return end
	table.insert(chars, caret + 1, str)
	edit.put(f, chars, caret + 1)
end

local function is_gap(c) return c == " " end

function edit.word_left(chars, i)
	while i > 0 and is_gap(chars[i]) do i = i - 1 end
	while i > 0 and not is_gap(chars[i]) do i = i - 1 end
	return i
end

function edit.word_right(chars, i)
	local n = #chars
	while i < n and is_gap(chars[i + 1]) do i = i + 1 end
	while i < n and not is_gap(chars[i + 1]) do i = i + 1 end
	return i
end

function edit.erase(f, forward, word)
	local chars = g.chars(f.text)
	if not edit.range(f) then
		local a, b = f.caret, f.caret
		if forward then
			b = word and edit.word_right(chars, f.caret) or math.min(#chars, f.caret + 1)
		else
			a = word and edit.word_left(chars, f.caret) or math.max(0, f.caret - 1)
		end
		if a == b then return end
		f.anchor, f.caret = a, b
	end
	local out, caret = edit.cut(f, chars)
	edit.put(f, out, caret)
end

function edit.move(f, to, shift)
	if shift then f.anchor = f.anchor or f.caret else f.anchor = nil end
	f.caret, f.blink = to, P.now
end

function edit.focus(f, id)
	if P.focus == f then return end
	P.focus, P.focus_id = f, id
	edit.pend = {}
	edit.sink(f ~= nil, true)
end

function edit.blur()
	if not P.focus then return end
	P.focus, P.focus_id = nil, nil
	edit.pend = {}
	edit.sink(false, true)
end

function edit.key(key)
	local f = P.focus
	if not f then return end
	local ctrl = Input.IsKeyDown(KEY.KEY_LCONTROL) or Input.IsKeyDown(KEY.KEY_RCONTROL)
	local shift = Input.IsKeyDown(KEY.KEY_LSHIFT) or Input.IsKeyDown(KEY.KEY_RSHIFT)
	local chars = g.chars(f.text)
	local n = #chars
	local lo, hi = edit.range(f)
	if ctrl and key == KEY.KEY_A then
		f.anchor, f.caret = 0, n
	elseif key == KEY.KEY_LEFT then
		if lo and not shift then edit.move(f, lo, false) else edit.move(f, ctrl and edit.word_left(chars, f.caret) or math.max(0, f.caret - 1), shift) end
	elseif key == KEY.KEY_RIGHT then
		if hi and not shift then edit.move(f, hi, false) else edit.move(f, ctrl and edit.word_right(chars, f.caret) or math.min(n, f.caret + 1), shift) end
	elseif key == KEY.KEY_HOME then
		edit.move(f, 0, shift)
	elseif key == KEY.KEY_END then
		edit.move(f, n, shift)
	elseif key == KEY.KEY_BACKSPACE then
		edit.erase(f, false, ctrl)
	elseif key == KEY.KEY_DELETE then
		edit.erase(f, true, ctrl)
	elseif key == KEY.KEY_ESCAPE then
		if lo then f.anchor = nil else edit.blur() end
	elseif key == KEY.KEY_ENTER or key == KEY.KEY_PAD_ENTER then
		if f.on_enter then f.on_enter(f.text) end
		edit.blur()
	elseif not ctrl and CHARS[key] and not edit.typed_ok then
		edit.pend[#edit.pend + 1] = shift and CHARS[key]:upper() or CHARS[key]
		edit.pend_t = P.now
	end
end

function edit.poll()
	local f = P.focus
	if not f then return end
	local p = edit.panel
	if not p or not p:IsValid() then
		edit.panel = nil
		if P.now - edit.find_at < 0.2 then return end
		edit.find_at = P.now
		p = Panorama.GetPanelByName(K.SINK_ID, false)
		if not p then return end
		edit.panel = p
	end
	local typed = p:GetAttribute("typed", "")
	if type(typed) == "string" and typed ~= "" then
		p:SetAttribute("typed", "")
		edit.typed_ok, edit.pend = true, {}
		local clean = typed:gsub("%c", "")
		pcall(function()
			for _, ch in utf8.codes(clean) do edit.insert(f, utf8.char(ch)) end
		end)
	elseif #edit.pend > 0 and P.now - edit.pend_t > 0.08 then
		for _, ch in ipairs(edit.pend) do edit.insert(f, ch) end
		edit.pend = {}
	end
end

function view.input(x, y, w, id, f, placeholder, glyph)
	edit.field(f)
	local h = 32
	local focused = P.focus == f
	local fa = anim.tween("in_f:" .. id, focused and 1 or 0, 0.16)
	g.rect(x, y, w, h, T.white, 9, 0.06 + 0.04 * fa)
	if fa > 0.01 then g.frame(x, y, w, h, A, 9, 0.6 * fa) end
	local tx = x + 10
	if glyph then
		g.glyph(glyph, 12, x + 16, y + h / 2, anim.mix(T.t3, T.t1, fa))
		tx = x + 30
	end
	local maxw = x + w - 10 - tx
	local chars = g.chars(f.text)
	local widths = { [0] = 0 }
	for i = 1, #chars do widths[i] = g.width(400, 13, table.concat(chars, "", 1, i)) end
	local caret_x = widths[f.caret] or widths[#chars]
	f.off = f.off or 0
	if caret_x - f.off > maxw then f.off = caret_x - maxw elseif caret_x < f.off then f.off = caret_x end
	f.off = clamp(f.off, 0, math.max(0, widths[#chars] - maxw))
	g.clip(tx - 2, y, maxw + 4, h)
	if f.text == "" and placeholder then g.text(400, 13, placeholder, tx, y + h / 2, T.t4) end
	local lo, hi = edit.range(f)
	if focused and lo then g.rect(tx + widths[lo] - f.off, y + 8, widths[hi] - widths[lo], 16, A, 3, 0.45) end
	if f.text ~= "" then g.text(400, 13, f.text, tx - f.off, y + h / 2, T.t1) end
	if focused then
		local t = P.now - (f.blink or 0)
		local blink = t < 0.5 and 1 or (math.cos((t - 0.5) * math.pi * 2) + 1) / 2
		g.rect(tx + caret_x - f.off, y + 8, 1.5, 16, T.t1, 0, blink)
	end
	g.unclip()
	local gx, gs = g.x, g.s
	hit.add(x, y, w, h, id, { down = function(mx)
		edit.focus(f, id)
		local lx = (mx - gx) / gs - tx + f.off
		local best = #chars
		for k = 1, #chars do
			if lx < (widths[k - 1] + widths[k]) / 2 then
				best = k - 1
				break
			end
		end
		edit.move(f, best, false)
	end })
	return h
end

-- ---------------------------------------------------------------------------
-- window: position, fade, drag, fold, close; body is drawn by the script
-- ---------------------------------------------------------------------------

function view.home()
	local screen = Render.ScreenSize()
	local wx, wy = Config.ReadInt(K.CFG, "wx", -1), Config.ReadInt(K.CFG, "wy", -1)
	if wx < 0 or wy < 0 or wx > screen.x - 40 or wy > screen.y - 40 then
		wx, wy = math.floor(screen.x * 0.5 - K.W * g.s / 2), math.floor(screen.y * 0.18)
	end
	P.wx, P.wy = wx, wy
	P.saved.wx, P.saved.wy = wx, wy
end

function view.reset_pos()
	save("wx", -1)
	save("wy", -1)
	P.wx = nil
end

function view.fold()
	P.set.collapsed = not P.set.collapsed
	save("collapsed", P.set.collapsed)
	if P.set.collapsed then P.menu = nil end
end

-- side docking (K.SMALL and K.DOCK): a window that touches the left or right
-- screen wall can slide into it, leaving a small tab with a chevron
function view.edge()
	if not (K.SMALL and K.DOCK) or not P.wx then return nil end
	local sw = Render.ScreenSize().x
	if P.wx <= K.SNAP then return -1 end
	if P.wx + K.W * g.s >= sw - K.SNAP then return 1 end
	return nil
end

function view.pin()
	local edge = view.edge()
	if edge then P.wx = edge < 0 and 0 or math.floor(Render.ScreenSize().x - K.W * g.s) end
	return edge
end

function view.side()
	return P.wx + K.W * g.s / 2 > Render.ScreenSize().x / 2 and 1 or -1
end

function view.dock(on)
	if on == nil then on = not P.set.docked end
	if on and not view.edge() then
		P.wx = view.side() < 0 and 0 or math.floor(Render.ScreenSize().x - K.W * g.s)
		save("wx", P.wx)
	end
	P.set.docked = on and view.edge() ~= nil
	save("docked", P.set.docked)
	if P.set.docked then
		P.menu = nil
		edit.blur()
	end
end

function view.dock_tab(o, edge, d)
	local tw, th = 26 + (o.tab_w or 0), U.flat and K.HEAD or 22
	local sw = Render.ScreenSize().x
	g.origin(edge > 0 and sw - tw * g.s or 0, P.wy)
	g.a = P.alpha * d
	local flags = edge > 0 and Enum.DrawFlags.RoundCornersLeft or Enum.DrawFlags.RoundCornersRight
	g.shadow(0, 0, tw, th, 6, 0.07)
	g.rect(0, 0, tw, th, C.win, 6, P.set.opacity / 100, flags)
	if C.line then g.frame(0, 0, tw, th, C.line, 6, 1, 1, flags) else g.frame(0, 0, tw, th, T.white, 6, 0.09, 1, flags) end
	hit.add(0, 0, tw, th, "dock_tab", {
		down = function(mx, my) P.drag, P.moved = { mx = mx, my = my, wx = P.wx, wy = P.wy, lock = true }, false end,
	})
	local cx = edge > 0 and 10 or tw - 10
	local cc = U.flat and T.knob or T.t3
	g.glyph(edge > 0 and K.G.left or K.G.right, 11, cx, th / 2, anim.mix(cc, T.t2, anim.hover("btn_undock")))
	hit.add(edge > 0 and 0 or tw - 22, 0, 22, th, "btn_undock", { click = function() view.dock(false) end })
	if o.tab then o.tab(edge > 0 and 22 or 4, th / 2) end
end

function view.close()
	P.open = false
	P.menu, P.ctx = nil, nil
	edit.blur()
	if K.ON_CLOSE then K.ON_CLOSE() end
end

function view.flat_head(o, W, edge)
	local H, bs = K.HEAD, K.HEAD - 6
	local by = (H - bs) / 2
	hit.add(0, 0, W, H, "drag", {
		down = function(mx, my) P.drag, P.moved = { mx = mx, my = my, wx = P.wx, wy = P.wy }, false end,
		dbl = view.fold,
	})
	local dock = K.SMALL and K.DOCK and edge
	local side = dock and edge or -1
	local glyph, click, lit = P.set.collapsed and K.G.down or K.G.left, view.fold, not P.set.collapsed
	if dock then glyph, click, lit = side > 0 and K.G.right or K.G.left, function() view.dock(true) end, true end
	local x, right = 6, W - 6
	if side > 0 then
		view.icon_button(x, by, bs, glyph, "btn_head", lit, click)
		x = x + bs + 2
	else
		right = right - bs
		view.icon_button(right, by, bs, glyph, "btn_head", lit, click)
	end
	if o.switch then
		view.switch(x + 2, H / 2, o.switch.on, o.switch.id or "head_sw", o.switch.click, true)
		x = x + 26
	end
	for _, b in ipairs(o.buttons or {}) do
		view.icon_button(x, by, bs, b.glyph, b.id, b.active, b.click)
		x = x + bs + 2
	end
	-- logo + title centered as one group, fitted between the left buttons and the chevron
	local room = 2 * math.min(W / 2 - x - 4, right - W / 2 - 4)
	local lw = 12 * LOGO.w + 5
	local title = g.fit(500, 13, o.title, room - lw)
	local tx = W / 2 - (g.width(500, 13, title) + lw) / 2
	view.logo(tx, H / 2, 12, T.t2)
	g.text(500, 13, title, tx + lw, H / 2, T.t2)
end

-- brand header: bar box with a cut top-right corner, accent underline, logo, tracked title,
-- accent slash + subtitle, optional status pill, square buttons with brackets on hover
function view.brand_head(o, W, H, h, top, opacity)
	g.cut(0, 0, W, H, C.bar, opacity, 16, false, true, false, false)
	if h > top + 0.5 then g.cut(0, top, W, h - top, C.win, opacity, 16, false, false, false, true) end
	g.grad(0, H - 3, math.min(240, W * 0.6), 2, A, 1, A, 0)
	local bs, step = 28, 34
	local by, bx = (H - bs) / 2, W - 12 - bs
	view.icon_button(bx, by, bs, K.G.close, "btn_close", false, view.close, true)
	bx = bx - step
	view.icon_button(bx, by, bs, P.set.collapsed and K.G.down or K.G.up, "btn_fold", false, view.fold)
	for _, b in ipairs(o.buttons or {}) do
		bx = bx - step
		view.icon_button(bx, by, bs, b.glyph, b.id, b.active, b.click)
	end
	local left = bx - 8
	if o.pill then left = view.status_pill(left, H / 2, o.pill) - 8 end
	hit.add(0, 0, left, H, "drag", {
		down = function(mx, my) P.drag, P.moved = { mx = mx, my = my, wx = P.wx, wy = P.wy }, false end,
		dbl = view.fold,
	})
	local x = 16
	x = x + view.logo(x, H / 2, math.floor(H * 0.56 + 0.5), T.t1) + 12
	x = x + g.track_fit(700, 15, o.title, x, H / 2, T.t1, 1, 2.5, left - x)
	if o.sub and left - x > 60 then
		g.line(x + 12, H / 2 + 8, x + 20, H / 2 - 8, A, 0.9, 1.5)
		g.track_fit(600, 11, o.sub, x + 32, H / 2 + 1, AT, 1, 1.4, left - x - 32)
	end
end

-- brand outline: accent hairline around both boxes and accent corner ticks (top-left, bottom-right)
function view.brand_shell(W, H, h, top)
	g.cut_frame(0, 0, W, H, A, 0.33, 1, 16, false, true, false, false)
	if h > top + 0.5 then g.cut_frame(0, top, W, h - top, A, 0.33, 1, 16, false, false, false, true) end
	local t = math.min(28, h - 4)
	g.line(1, 1, 29, 1, A, 0.95, 2)
	g.line(1, 1, 1, 29, A, 0.95, 2)
	g.line(W - 1, h - 1, W - 29, h - 1, A, 0.95, 2)
	g.line(W - 1, h - 1, W - 1, h - 1 - t, A, 0.95, 2)
end

-- resize grip in the bottom-right corner: dragging changes the scale (saved on release)
function view.grip(W, h)
	local hot = hit.is("grip") or P.resize ~= nil
	local c = hot and T.t2 or T.t4
	g.line(W - 6, h - 14, W - 14, h - 6, c, 1, 1.5)
	g.line(W - 6, h - 9, W - 9, h - 6, c, 1, 1.5)
	hit.add(W - 18, h - 18, 18, 18, "grip", { down = function(mx)
		P.resize = { mx = mx, w = W * g.s, scale = P.set.scale }
	end })
end

function view.window(o)
	g.s = P.set.scale / 100
	g.cmp = anim.tween("compact", P.set.compact and 1 or 0, 0.25, ease_in_out)
	if not P.wx then view.home() end
	local W = K.W
	local edge = P.drag and view.edge() or view.pin()
	local d = anim.tween("dock", P.set.docked and edge and 1 or 0, 0.22, ease_in_out)
	if edge and d > 0.01 then view.dock_tab(o, edge, d) end
	if d > 0.99 then return end
	local fold = anim.tween("fold", P.set.collapsed and 0 or 1, 0.22, ease_in_out)
	local body_h = o.body_h or 0
	local flat = U.flat
	local H = flat and K.HEAD or math.floor(g.lay(K.HEAD, K.HEAD - 10) + 0.5)
	local gap = body_h > 0 and 4 or 0
	local h = H + math.floor((body_h + gap) * fold + 0.5)
	local top = H + gap
	P.h = h
	g.origin(P.wx + (edge or 0) * d * (W + 8) * g.s, P.wy)
	g.a = P.alpha * (1 - d)
	local opacity = P.set.opacity / 100
	hit.add(0, 0, W, h, "win")
	if opacity < 1 then
		local r = flat and g.r(10, W, h) * g.s or 0
		Render.Blur(g.v(0, 0), g.v(W, H), P.alpha, 1.0, r, ROUND)
		if h > top + 0.5 then Render.Blur(g.v(0, top), g.v(W, h), P.alpha, 1.0, r, ROUND) end
	end
	if flat then
		g.rect(0, 0, W, H, C.win, 10, opacity)
		g.frame(0, 0, W, H, C.line, 10)
		if h > top + 0.5 and not o.bare then
			g.rect(0, top, W, h - top, C.win, 10, opacity)
			g.frame(0, top, W, h - top, C.line, 10)
		end
		view.flat_head(o, W, edge)
	else
		view.brand_head(o, W, H, h, top, opacity)
	end

	if fold > 0.01 and body_h > 0 then
		g.clip(0, top, W, h - top)
		local base = g.a
		g.a = base * fold ^ 1.5
		o.body(top)
		g.a = base
		g.unclip()
	end
	if not flat then
		view.brand_shell(W, H, h, top)
		if fold > 0.99 and body_h > 0 then view.grip(W, h) end
	end
	view.draw_menu()
	view.draw_ctx()
end

-- ---------------------------------------------------------------------------
-- input routing and the frame driver
-- ---------------------------------------------------------------------------

local input = { swallow = false, held = {} }

function input.press(mx, my, button)
	local h = hit.at(mx, my)
	local id, on = h and h[5], h and h[6] or {}
	if P.ctx and not (id and id:sub(1, 4) == "ctx:") then
		P.ctx = nil
		if button ~= 2 then
			P.press = { id = false }
			return
		end
	end
	if P.menu and not (id and (id:sub(1, 5) == "menu:" or id == "dd:" .. P.menu)) then
		P.menu = nil
		P.press = { id = false }
		return
	end
	if P.focus and id ~= P.focus_id then edit.blur() end
	if button == 2 then
		if on.rclick then on.rclick(mx, my) end
		return
	end
	P.press = { id = id or false, on = on }
	if on.down then on.down(mx, my) end
end

function input.release(mx, my)
	local press = P.press
	P.press = nil
	if not press or not press.id then return end
	if P.moved then
		P.moved = false
		return
	end
	local h = hit.at(mx, my)
	if not h or h[5] ~= press.id then return end
	local on = press.on
	if on.dbl and P.last_click.id == press.id and P.now - P.last_click.t < K.DOUBLE then
		P.last_click.id = nil
		on.dbl()
		return
	end
	P.last_click.id, P.last_click.t = press.id, P.now
	if on.click then on.click(mx, my) end
end

function input.end_drag()
	if P.drag then
		view.pin()
		save("wx", math.floor(P.wx))
		save("wy", math.floor(P.wy))
	end
	if P.slide and P.slide.done then P.slide.done(P.slide.value) end
	if P.resize then save("scale", P.set.scale) end
	P.drag, P.slide, P.sb_drag, P.resize = nil, nil, nil, nil
end

function input.tick()
	if P.press and not Input.IsKeyDown(KEY.KEY_MOUSE1, true) then
		input.end_drag()
		P.press = nil
	end
	for key in pairs(input.held) do
		if not Input.IsKeyDown(key, true) then input.held[key] = nil end
	end
	local mx, my = Input.GetCursorPos()
	if P.drag then
		if math.abs(mx - P.drag.mx) + math.abs(my - P.drag.my) > 4 then P.moved = true end
		if not P.drag.lock then P.wx = P.drag.wx + mx - P.drag.mx end
		P.wy = P.drag.wy + my - P.drag.my
	end
	if P.slide then view.slide_to(mx) end
	if P.sb_drag then view.scroll_drag(my) end
	if P.resize then
		local r = P.resize
		P.set.scale = clamp(math.floor(r.scale * (r.w + mx - r.mx) / r.w / 5 + 0.5) * 5, 70, 150)
	end
	if P.focus then
		if P.alpha < 0.5 then
			edit.blur()
		else
			edit.sink(true)
			edit.poll()
		end
	end
end

function input.event(e)
	if P.alpha <= 0.02 and #P.toasts == 0 then return true end
	local mx, my = Input.GetCursorPos()
	local over = hit.at(mx, my) ~= nil

	if e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP or e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN then
		if not over then return true end
		local h = hit.at(mx, my, "wheel")
		if h then h[6].wheel(e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN and 1 or -1) end
		return false
	end

	if e.key == KEY.KEY_MOUSE1 or e.key == KEY.KEY_MOUSE2 then
		local left = e.key == KEY.KEY_MOUSE1
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			if input.held[e.key] then return not input.swallow end
			input.held[e.key] = true
			if not over then
				if P.focus then edit.blur() end
				P.menu, P.ctx = nil, nil
				if left then P.press = { id = false } end
				return true
			end
			input.swallow = true
			input.press(mx, my, left and 1 or 2)
			return false
		elseif e.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
			input.held[e.key] = nil
			if left then
				input.end_drag()
				input.release(mx, my)
			end
			if input.swallow then
				input.swallow = false
				return false
			end
		end
		return true
	end

	if P.focus then
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			edit.sink(true, true)
			edit.key(e.key)
		end
		return false
	end

	if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and e.key == KEY.KEY_ESCAPE and over and (P.menu or P.ctx) then
		P.menu, P.ctx = nil, nil
		return false
	end
	return true
end

function input.frame(draw)
	local frame = GlobalVars.GetAbsFrameTime()
	P.now = os.clock()
	P.dt = clamp(frame > 0 and frame or 0.016, 0, 0.1)
	asset.budget = 3
	P.alpha = anim.tween("window", P.open and 1 or 0, 0.18)
	input.tick()
	hit.begin()
	local ok, err = true, nil
	if P.alpha > 0.001 then
		ok, err = pcall(draw)
	else
		P.press, P.drag, P.slide, P.sb_drag, P.resize, P.menu, P.ctx = nil, nil, nil, nil, nil, nil, nil
	end
	g.reset()
	if ok then ok, err = pcall(view.draw_toasts) end
	g.reset()
	if ok then ok, err = pcall(view.draw_tip) end
	g.reset()
	if not ok and err ~= P.draw_error then
		P.draw_error = err
		Log.Write("[" .. K.NAME .. "] draw error: " .. tostring(err))
	end
end

function input.shutdown()
	if edit.sink_on then Engine.RunScript(JS_SINK:format(K.SINK_ID, "false", K.SINK_ID, K.SINK_TIMEOUT)) end
end

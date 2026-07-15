local utils = require("utils")
local millennium = require("millennium")
local cjson = require("json")
local fs = require("fs")

local PLUGIN_ID = "zonasteam-plugin"
local BROWSER_JS = "public/zonasteam.js"
local BROWSER_CSS = "public/zonasteam.css"
local BROWSER_JS_WEBKIT = "webkit/Zonasteam/zonasteam.js"
local BROWSER_CSS_WEBKIT = "webkit/Zonasteam/zonasteam.css"

local runtime = {
	browser_js_id = 0,
	browser_css_id = 0,
	steam_path = nil
}

local function safe_backend_path()
	local ok, value = pcall(function() return utils.get_backend_path() end)
	if ok and value ~= nil and tostring(value) ~= "" then
		return tostring(value)
	end
	return "."
end

local function plugin_dir()
	local root = safe_backend_path()
	local lowered = root:lower()
	if lowered:sub(-9) == "\\backend" or lowered:sub(-9) == "/backend" then
		return root:sub(1, #root - 8)
	end
	return root .. "\\.."
end

local function read_file(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function write_file(path, data)
	local f = io.open(path, "wb")
	if not f then return false end
	f:write(data or "")
	f:close()
	return true
end

local function mkdirs(path)
	pcall(function()
		if fs and fs.create_directories then
			fs.create_directories(path)
		else
			os.execute("mkdir \"" .. path .. "\" >nul 2>nul")
		end
	end)
end

local function is_file(path)
	local f = io.open(path, "rb")
	if f then f:close(); return true end
	return false
end

local function detect_steam_path()
	if runtime.steam_path then return runtime.steam_path end
	local ok, path = pcall(function() return millennium.steam_path() end)
	if ok and path and tostring(path) ~= "" then
		runtime.steam_path = tostring(path)
		return runtime.steam_path
	end
	local candidates = {
		"C:\\Program Files (x86)\\Steam",
		"C:\\Program Files\\Steam"
	}
	for _, c in ipairs(candidates) do
		if is_file(c .. "\\steam.exe") then
			runtime.steam_path = c
			return c
		end
	end
	return ""
end

local function copy_public_assets()
	local pdir = plugin_dir()
	local steam = detect_steam_path()
	if steam == "" then return end

	local webkit_dir = steam .. "\\steamui\\webkit\\Zonasteam"
	mkdirs(webkit_dir)

	local files = {
		{ pdir .. "\\public\\zonasteam.js", webkit_dir .. "\\zonasteam.js" },
		{ pdir .. "\\public\\zonasteam.css", webkit_dir .. "\\zonasteam.css" }
	}
	for _, pair in ipairs(files) do
		local data = read_file(pair[1])
		if data then
			write_file(pair[2], data)
		end
	end
end

local function inject_browser_assets()
	local ok, id

	ok, id = pcall(millennium.add_browser_css, BROWSER_CSS)
	if ok and id and id ~= 0 and id ~= -1 then
		runtime.browser_css_id = id
	else
		ok, id = pcall(millennium.add_browser_css, BROWSER_CSS_WEBKIT)
		if ok and id then runtime.browser_css_id = id end
	end

	ok, id = pcall(millennium.add_browser_js, BROWSER_JS)
	if ok and id and id ~= 0 and id ~= -1 then
		runtime.browser_js_id = id
	else
		ok, id = pcall(millennium.add_browser_js, BROWSER_JS_WEBKIT)
		if ok and id then runtime.browser_js_id = id end
	end
end

local function json_ok(data)
	local ok, s = pcall(cjson.encode, data)
	if ok then return s end
	return '{"success":false,"error":"serialization error"}'
end

local function json_err(msg)
	return json_ok({ success = false, error = tostring(msg) })
end

function AddGame(...)
	local args = {...}
	local appid = ""

	if #args > 0 then
		local first = args[1]
		if type(first) == "table" then
			appid = tostring(first.appid or first.appId or "")
		elseif type(first) == "string" then
			appid = first
		elseif type(first) == "number" then
			appid = tostring(first)
		end
	end

	appid = appid:match("(%d+)") or ""
	if appid == "" then
		return json_err("AppID invalido")
	end

	local steam = detect_steam_path()
	if steam == "" then
		return json_err("No se encontro Steam")
	end

	local pdir = plugin_dir()
	local bin_path = pdir .. "\\backend\\zonasteam.exe"

	if not is_file(bin_path) then
		return json_err("zonasteam.exe no encontrado")
	end

	local temp_dir = pdir .. "\\backend\\temp\\" .. appid
	pcall(function() os.execute("rmdir /s /q \"" .. temp_dir .. "\"") end)
	os.execute("mkdir \"" .. temp_dir .. "\"")

	local back_dir = pdir .. "\\backend"
	local depot_dir = steam .. "\\depotcache"
	mkdirs(depot_dir)
	local args = '--outdir "' .. temp_dir .. '" --depotdir "' .. depot_dir .. '" ' .. appid
	local ps = 'powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath ' .. "'" .. bin_path .. "'" .. ' -ArgumentList ' .. "'" .. args .. "'" .. ' -WorkingDirectory ' .. "'" .. back_dir .. "'" .. ' -WindowStyle Hidden -Wait"'
	pcall(utils.exec, ps)

	local lua_src = temp_dir .. "\\" .. appid .. "\\" .. appid .. ".lua"
	local lua_content = read_file(lua_src)
	if not lua_content then
		pcall(function() os.execute("rmdir /s /q \"" .. temp_dir .. "\"") end)
		return json_err("No se genero el archivo .lua")
	end

	local lua_dir = steam .. "\\config\\stplug-in"
	mkdirs(lua_dir)
	write_file(lua_dir .. "\\" .. appid .. ".lua", lua_content)

	pcall(function() os.execute("rmdir /s /q \"" .. temp_dir .. "\"") end)

	pcall(function()
		utils.exec('powershell -WindowStyle Hidden -NoProfile -Command "Start-Process ''steam://offline/''; Start-Sleep 2; Start-Process ''steam://connect/''"')
	end)

	return json_ok({
		success = true,
		appid = appid,
		lua_path = lua_dir .. "\\" .. appid .. ".lua"
	})
end

_G["AddGame"] = AddGame

local function on_load()
	pcall(function()
		copy_public_assets()
		inject_browser_assets()
		if millennium.ready then
			millennium.ready()
		end
	end)
end

local function on_unload()
end

local function on_frontend_loaded()
end

return {
	on_load = on_load,
	on_unload = on_unload,
	on_frontend_loaded = on_frontend_loaded
}

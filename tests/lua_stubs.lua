--[[--
Fake/stub implementations of the KOReader + LuaSocket APIs the inkRPG
plugin modules require(), so plugin .lua files can be require()'d and
exercised outside a real KOReader install. These are obviously-minimal
stand-ins for testing -- not a KOReader reimplementation -- and only cover
the surface this plugin actually touches.

Loaded once per test (each test gets a brand-new Lua runtime, see env.py),
so there's no state leaking between tests.

Three globals are expected to exist (as a table __TEST__) before this file
runs -- env.py sets sane defaults for all of them on every new runtime:
  __TEST__.http_request(request_table) -> ok, code
      Fakes socket.http.request. Must call request.sink(chunk) one or more
      times then request.sink(nil) to end the body (real ltn12 sink
      protocol), and return (1, code) -- matching what
      `socket.skip(1, http.request(request))` expects to unpack.
  __TEST__.recorded_timeouts
      An array socketutil:set_timeout(block, total) appends {block=,
      total=} to, so a test can assert on what timeout the code actually
      asked for (this project has been bitten once already by a too-short
      block timeout silently regressing).
  __TEST__.lfs_isdir(path) / lfs_isfile(path) / lfs_listdir(path)
      Back the plugin's directory-scanning code (game pack discovery).
      Default to real filesystem calls rooted at whatever absolute path
      the plugin code itself computes (normally its own games/ folder).
--]]--

local preload = package.preload

preload["logger"] = function()
    local calls = {}
    return {
        warn = function(...) table.insert(calls, { "warn", ... }) end,
        info = function(...) table.insert(calls, { "info", ... }) end,
        dbg = function(...) table.insert(calls, { "dbg", ... }) end,
        _calls = calls,
    }
end

preload["gettext"] = function()
    return function(s) return s end
end

preload["json"] = function()
    -- Tiny pure-Lua JSON encoder/decoder -- just enough for the flat,
    -- ASCII request/response shapes this plugin sends and receives.
    -- Not a general-purpose JSON library (no \uXXXX decoding, no
    -- scientific notation edge cases beyond what tonumber handles).
    local json = {}

    local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }

    local function encode_string(s)
        return '"' .. s:gsub('[%c"\\]', function(c)
            return ESCAPES[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    end

    local function is_array(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        if n == 0 then return true, 0 end
        for i = 1, n do
            if t[i] == nil then return false end
        end
        return true, n
    end

    function json.encode(v)
        local t = type(v)
        if t == "string" then return encode_string(v) end
        if t == "number" or t == "boolean" then return tostring(v) end
        if v == nil then return "null" end
        if t == "table" then
            local arr, n = is_array(v)
            if arr then
                local parts = {}
                for i = 1, n do parts[i] = json.encode(v[i]) end
                return "[" .. table.concat(parts, ",") .. "]"
            end
            local parts = {}
            for k, val in pairs(v) do
                table.insert(parts, encode_string(tostring(k)) .. ":" .. json.encode(val))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        error("json.encode: unsupported type " .. t)
    end

    local decode_value

    local function skip_ws(s, i)
        while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
        return i
    end

    local function decode_string(s, i)
        i = i + 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == '"' then
                return table.concat(out), i + 1
            elseif c == "\\" then
                local nc = s:sub(i + 1, i + 1)
                local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                table.insert(out, map[nc] or nc)
                i = i + 2
            else
                table.insert(out, c)
                i = i + 1
            end
        end
    end

    local function decode_number(s, i)
        local j = i
        while j <= #s and s:sub(j, j):match("[%d%.%-%+eE]") do j = j + 1 end
        return tonumber(s:sub(i, j - 1)), j
    end

    decode_value = function(s, i)
        i = skip_ws(s, i)
        local c = s:sub(i, i)
        if c == '"' then
            return decode_string(s, i)
        elseif c == "{" then
            local obj = {}
            i = skip_ws(s, i + 1)
            if s:sub(i, i) == "}" then return obj, i + 1 end
            while true do
                local key
                key, i = decode_string(s, skip_ws(s, i))
                i = skip_ws(s, i)
                assert(s:sub(i, i) == ":", "json decode: expected ':'")
                local val
                val, i = decode_value(s, i + 1)
                obj[key] = val
                i = skip_ws(s, i)
                local sep = s:sub(i, i)
                if sep == "," then
                    i = i + 1
                elseif sep == "}" then
                    return obj, i + 1
                else
                    error("json decode: expected ',' or '}'")
                end
            end
        elseif c == "[" then
            local arr = {}
            i = skip_ws(s, i + 1)
            if s:sub(i, i) == "]" then return arr, i + 1 end
            local n = 0
            while true do
                local val
                val, i = decode_value(s, i)
                n = n + 1
                arr[n] = val
                i = skip_ws(s, i)
                local sep = s:sub(i, i)
                if sep == "," then
                    i = i + 1
                elseif sep == "]" then
                    return arr, i + 1
                else
                    error("json decode: expected ',' or ']'")
                end
            end
        elseif s:sub(i, i + 3) == "true" then
            return true, i + 4
        elseif s:sub(i, i + 4) == "false" then
            return false, i + 5
        elseif s:sub(i, i + 3) == "null" then
            return nil, i + 4
        else
            return decode_number(s, i)
        end
    end

    function json.decode(s)
        return (decode_value(s, 1))
    end

    return json
end

preload["socket"] = function()
    return {
        skip = function(n, ...)
            local args = { ... }
            local out = {}
            for i = n + 1, select("#", ...) do
                table.insert(out, args[i])
            end
            return table.unpack(out)
        end,
    }
end

preload["socket.http"] = function()
    return {
        request = function(req)
            return __TEST__.http_request(req)
        end,
    }
end

preload["ltn12"] = function()
    return {
        source = {
            string = function(s)
                local sent = false
                return function()
                    if sent then return nil end
                    sent = true
                    return s
                end
            end,
        },
        sink = {
            table = function(t)
                t = t or {}
                return function(chunk)
                    if chunk then table.insert(t, chunk) end
                    return 1
                end
            end,
        },
    }
end

preload["socketutil"] = function()
    return {
        set_timeout = function(self, block, total)
            table.insert(__TEST__.recorded_timeouts, { block = block, total = total })
        end,
        reset_timeout = function(self) end,
    }
end

preload["datastorage"] = function()
    return {
        getSettingsDir = function(self) return "/fake-koreader-settings" end,
    }
end

preload["luasettings"] = function()
    -- In-memory, keyed by path, shared for the life of one runtime -- a
    -- State.write in a test is visible to a later State.read in the same
    -- test, same as real LuaSettings backed by a real file would be.
    local STORE = {}
    local LuaSettings = {}
    LuaSettings.__index = LuaSettings

    function LuaSettings:open(path)
        STORE[path] = STORE[path] or {}
        return setmetatable({ _path = path }, LuaSettings)
    end

    function LuaSettings:readSetting(key, default)
        local v = STORE[self._path][key]
        if v == nil then return default end
        return v
    end

    function LuaSettings:saveSetting(key, value)
        STORE[self._path][key] = value
    end

    function LuaSettings:flush() end
    function LuaSettings:close() end

    return LuaSettings
end

preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, field)
            if field ~= "mode" then return nil end
            if __TEST__.lfs_isdir(path) then return "directory" end
            if __TEST__.lfs_isfile(path) then return "file" end
            return nil
        end,
        mkdir = function(path) return true end,
        dir = function(path)
            local entries = __TEST__.lfs_listdir(path) or {}
            local i = 0
            return function()
                i = i + 1
                if entries[i] then return entries[i] end
                return nil
            end
        end,
    }
end

preload["dispatcher"] = function()
    return {
        registerAction = function(self, ...) end,
    }
end

preload["ui/uimanager"] = function()
    local shown = {}
    return {
        show = function(self, widget) table.insert(shown, widget) end,
        close = function(self, widget) end,
        -- Real UIManager:scheduleIn defers to the next event-loop tick;
        -- tests are synchronous so it just runs the callback right away.
        scheduleIn = function(self, delay, fn) fn() end,
        _shown = shown,
    }
end

local function widget_stub()
    local W = {}
    W.__index = W
    function W:new(opts)
        opts = opts or {}
        return setmetatable(opts, W)
    end
    function W:onShowKeyboard() end
    function W:getInputText() return self._test_input or self.input or "" end
    return W
end

preload["ui/widget/menu"] = function() return widget_stub() end
preload["ui/widget/inputdialog"] = function() return widget_stub() end
preload["ui/widget/infomessage"] = function() return widget_stub() end
preload["ui/widget/textviewer"] = function() return widget_stub() end

preload["ui/widget/container/widgetcontainer"] = function()
    local W = {}
    W.__index = W
    function W:extend(opts)
        return setmetatable(opts or {}, W)
    end
    return W
end

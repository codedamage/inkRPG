--[[--
Per-save-slot persistence for inkRPG, built on KOReader's own LuaSettings
(the same mechanism KOReader uses for its own settings files).

One save file per (game, slot):
  <koreader settings dir>/inkrpg/<game_slug>_<slot>.lua
--]]--

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local lfs = require("libs/libkoreader-lfs")

local State = {}

local function saves_dir()
    local dir = DataStorage:getSettingsDir() .. "/inkrpg/"
    if lfs.attributes(dir, "mode") ~= "directory" then
        lfs.mkdir(dir)
    end
    return dir
end

-- Opens (creating if needed) the LuaSettings object for one save slot.
function State.open(game_slug, slot)
    slot = slot or "autosave"
    local path = saves_dir() .. game_slug .. "_" .. slot .. ".lua"
    return LuaSettings:open(path)
end

-- Convenience: read the whole state table (scene id, stats, flags, and
-- ai_scene -- the current AI-improvised node, if the player was mid
-- freeform-AI play rather than in the authored scene graph when they
-- last saved; nil in the common case).
function State.read(game_slug, slot)
    local settings = State.open(game_slug, slot)
    local data = {
        scene = settings:readSetting("scene"),
        stats = settings:readSetting("stats", {}),
        flags = settings:readSetting("flags", {}),
        ai_scene = settings:readSetting("ai_scene"),
    }
    settings:close()
    return data
end

-- Convenience: write the whole state table in one go and flush to disk.
function State.write(game_slug, slot, data)
    data = data or {}
    local settings = State.open(game_slug, slot)
    settings:saveSetting("scene", data.scene)
    settings:saveSetting("stats", data.stats or {})
    settings:saveSetting("flags", data.flags or {})
    settings:saveSetting("ai_scene", data.ai_scene)
    settings:flush()
    settings:close()
end

return State

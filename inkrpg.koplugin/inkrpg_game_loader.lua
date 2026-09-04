--[[--
Discovers game packs under inkrpg.koplugin/games/<slug>/manifest.lua and
loads their manifest and scene tables.

Game packs are plain Lua data files (a `return { ... }` table), the same
pattern KOReader itself uses for configuration.lua-style files. There is
no game-authored code and no sandboxing beyond "you trust files you put
on your own device" -- the same trust level as an epub or a KOReader
patch.

See games/demo-cave for a complete, playable, AI-free example.
--]]--

local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local GameLoader = {}

-- Resolve this file's own directory so game discovery works no matter
-- where the user installed koreader/plugins/inkrpg.koplugin. Same trick
-- frotz.koplugin uses to find its bundled interpreter binaries.
local _plugin_dir = debug.getinfo(1, "S").source:match("@(.+)/[^/]+$") or "."
GameLoader.games_dir = _plugin_dir .. "/games/"

function GameLoader.listGames()
    local games = {}
    local ok = pcall(function()
        for entry in lfs.dir(GameLoader.games_dir) do
            if entry ~= "." and entry ~= ".." then
                local manifest_path = GameLoader.games_dir .. entry .. "/manifest.lua"
                if lfs.attributes(manifest_path, "mode") == "file" then
                    local chunk, load_err = loadfile(manifest_path)
                    if chunk then
                        local ok2, manifest = pcall(chunk)
                        if ok2 and type(manifest) == "table" then
                            manifest.slug = manifest.slug or entry
                            manifest._dir = GameLoader.games_dir .. entry .. "/"
                            table.insert(games, manifest)
                        else
                            logger.warn("inkRPG: bad manifest", manifest_path, manifest)
                        end
                    else
                        logger.warn("inkRPG: could not load", manifest_path, load_err)
                    end
                end
            end
        end
    end)
    if not ok then
        return nil, "Could not read " .. GameLoader.games_dir
    end
    table.sort(games, function(a, b) return (a.title or a.slug) < (b.title or b.slug) end)
    return games
end

-- Loads a game's scene graph. Returns a table keyed by scene id:
--   { text = "...", choices = { { label = "...", next = "scene_id" }, ... },
--     is_ending = false, on_enter = function(stats, flags) ... end }
function GameLoader.loadScenes(manifest)
    local scenes_path = manifest._dir .. "scenes.lua"
    local chunk, load_err = loadfile(scenes_path)
    if not chunk then
        return nil, "Could not load " .. scenes_path .. ": " .. tostring(load_err)
    end
    local ok, scenes = pcall(chunk)
    if not ok or type(scenes) ~= "table" then
        return nil, scenes_path .. " did not return a table"
    end
    return scenes
end

-- Loads a lore/markdown file's raw text (for prompt-building or display).
function GameLoader.loadText(manifest, relative_path)
    local path = manifest._dir .. relative_path
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

return GameLoader

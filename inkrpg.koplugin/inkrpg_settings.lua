--[[--
Per-user AI provider configuration -- read/written by inkrpg_settings_screen
(Tools > More tools > inkRPG > AI provider settings), not by editing any
file in this plugin's own folder.

Storage: KOReader's own LuaSettings, same mechanism inkrpg_state.lua uses
for save games, at

    <koreader settings dir>/inkrpg_settings.lua

That's the device's own data directory, not this git checkout -- so a
fresh `git clone` of this repo never carries anyone's API key, and two
people running the same plugin on their own devices each get their own
independent settings file. This deliberately mirrors why
configuration.lua was gitignored in the first place, but goes one step
further: there's no file to create or hand-edit at all, so someone
installing the plugin from a release zip (not a git checkout) has a real
way to configure it.

configuration.lua (see configuration.sample.lua) still works as a
power-user override -- inkrpg_ai_provider.lua checks this settings store
first and only falls back to that file if nothing has been saved here.
That's useful for scripting/testing multiple providers without re-typing
a key in the UI each time, but the settings screen is the documented,
primary path for a normal install.
--]]--

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Settings = {}

-- Provider presets: id -> { name = shown in the picker, base_url =,
-- default_model = }. "custom" has no fixed base_url -- the settings
-- screen prompts for one when this preset is chosen. Order is kept
-- separately since Lua tables don't preserve key order.
Settings.PRESETS = {
    openai = {
        name = "OpenAI",
        base_url = "https://api.openai.com/v1/chat/completions",
        default_model = "gpt-4o-mini",
    },
    ollama = {
        name = "Local Ollama",
        base_url = "http://localhost:11434/v1/chat/completions",
        default_model = "llama3.1",
    },
    deepseek = {
        name = "DeepSeek",
        base_url = "https://api.deepseek.com/v1/chat/completions",
        default_model = "deepseek-chat",
    },
    groq = {
        name = "Groq",
        base_url = "https://api.groq.com/openai/v1/chat/completions",
        default_model = "llama-3.1-8b-instant",
    },
    openrouter = {
        name = "OpenRouter",
        base_url = "https://openrouter.ai/api/v1/chat/completions",
        default_model = "openrouter/auto",
    },
    custom = {
        name = "Custom (OpenAI-compatible)",
        base_url = "",
        default_model = "",
    },
}

Settings.PRESET_ORDER = { "openai", "ollama", "deepseek", "groq", "openrouter", "custom" }

local function settings_path()
    return DataStorage:getSettingsDir() .. "/inkrpg_settings.lua"
end

function Settings.open()
    return LuaSettings:open(settings_path())
end

-- Returns { preset, model, base_url, api_key } or nil if nothing has
-- been configured yet (no preset chosen).
function Settings.read()
    local s = Settings.open()
    local data = {
        preset = s:readSetting("preset"),
        model = s:readSetting("model"),
        base_url = s:readSetting("base_url"),
        api_key = s:readSetting("api_key"),
    }
    s:close()
    if not data.preset then
        return nil
    end
    return data
end

function Settings.write(data)
    data = data or {}
    local s = Settings.open()
    s:saveSetting("preset", data.preset)
    s:saveSetting("model", data.model)
    s:saveSetting("base_url", data.base_url)
    s:saveSetting("api_key", data.api_key)
    s:flush()
    s:close()
end

return Settings

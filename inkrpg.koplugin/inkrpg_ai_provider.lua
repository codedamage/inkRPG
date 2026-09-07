--[[--
AI provider client: one OpenAI-compatible chat-completion request shape,
reused for every backend that speaks it (OpenAI itself, a local Ollama
server, DeepSeek, Groq, OpenRouter, and most proxies) by pointing
base_url/model/api_key at whichever provider is configured.

Modeled on the working pattern from omer-faruq/assistant.koplugin; the
HTTP call itself follows the same socket.http + ltn12 + socketutil shape
used by KOReader's own wallabag.koplugin.

Configuration is per-user, not part of this codebase: the primary path
is Tools > More tools > inkRPG > AI provider settings (see
inkrpg_settings.lua / inkrpg_settings_screen.lua), which writes to
KOReader's own settings directory on the device -- nothing to create or
hand-edit in this plugin's own folder, and nothing that ends up in a git
checkout. configuration.lua (copy from configuration.sample.lua, still
gitignored) is kept as a power-user/scripting override and is only
consulted if nothing has been saved through the settings screen:

    return {
        provider = "openai",
        provider_settings = {
            openai = {
                model = "gpt-4o-mini",
                base_url = "https://api.openai.com/v1/chat/completions",
                api_key = "sk-...",
            },
        },
    }

Native Claude (Messages API) and Gemini endpoints use a different
request/response shape than OpenAI's chat-completions -- they'd need
their own small handler function, not covered here yet. See PLAN.md
Phase 2 (the rest of it: this module's `request` is the raw chat call;
`requestStructured` below is what the play loop actually uses).
--]]--

local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local JSON = require("json")
local logger = require("logger")

local Settings = require("inkrpg_settings")

local AIProvider = {}

local REQUEST_BLOCK_TIMEOUT = 10
local REQUEST_TOTAL_TIMEOUT = 60

-- Prefers whatever was saved through the in-app settings screen; falls
-- back to configuration.lua (a file in this plugin's own folder, kept
-- for power users) only if nothing has been configured through the UI
-- yet. Either path returns the same shape: { provider = "...",
-- provider_settings = { [provider] = { model, base_url, api_key } } }.
local function loadConfig()
    local settings = Settings.read()
    if settings and settings.preset and settings.api_key and settings.api_key ~= "" then
        return {
            provider = settings.preset,
            provider_settings = {
                [settings.preset] = {
                    model = settings.model,
                    base_url = settings.base_url,
                    api_key = settings.api_key,
                },
            },
        }
    end

    local _plugin_dir = debug.getinfo(1, "S").source:match("@(.+)/[^/]+$") or "."
    local config_path = _plugin_dir .. "/configuration.lua"
    local chunk = loadfile(config_path)
    if not chunk then
        return nil, "No AI provider configured -- open Tools > More tools > inkRPG > AI provider settings to add one."
    end
    local ok, config = pcall(chunk)
    if not ok or type(config) ~= "table" then
        return nil, "configuration.lua did not return a table"
    end
    return config
end

-- messages: array of { role = "system"|"user"|"assistant", content = "..." }
-- Returns (ok, text_or_error)
function AIProvider.request(messages)
    local config, cfg_err = loadConfig()
    if not config then
        return false, cfg_err
    end

    local provider = config.provider_settings and config.provider_settings[config.provider]
    if not provider or not provider.api_key or provider.api_key == "" then
        return false, "No API key configured for provider '" .. tostring(config.provider) .. "'"
    end

    local body = JSON.encode({
        model = provider.model,
        messages = messages,
    })

    local sink = {}
    local request = {
        url = provider.base_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body),
            ["Authorization"] = "Bearer " .. provider.api_key,
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(sink),
    }

    socketutil:set_timeout(REQUEST_BLOCK_TIMEOUT, REQUEST_TOTAL_TIMEOUT)
    local code = socket.skip(1, http.request(request))
    socketutil:reset_timeout()

    local content = table.concat(sink)
    if code ~= 200 then
        logger.warn("inkRPG AIProvider: request failed", code, content)
        return false, "AI request failed (HTTP " .. tostring(code) .. ")"
    end

    local ok, decoded = pcall(JSON.decode, content)
    if not ok or not decoded then
        return false, "Could not parse AI response as JSON"
    end

    local message = decoded.choices and decoded.choices[1] and decoded.choices[1].message
    if not message or not message.content then
        return false, "AI response had no message content"
    end

    return true, message.content
end

-- Structured mode: the play loop's actual entry point (Phase 2). Wraps
-- `request` with instructions that constrain the model to a fixed JSON
-- shape, so narration and game-mechanical state changes (HP, flags,
-- inventory) come back as data the engine can apply deterministically
-- instead of free text it would have to guess at parsing. Returns
-- (true, { narration = "...", choices = {...}, state_changes = {...} })
-- or (false, error_string).
local STRUCTURED_INSTRUCTIONS = [[
Respond with ONLY a single JSON object -- no prose outside it, no
markdown code fences -- matching exactly this shape:
{
  "narration": "1-3 short paragraphs of DM narration, plain text",
  "choices": [
    {"label": "short button text", "id": "short_snake_case_id"}
  ],
  "state_changes": {
    "hp_delta": 0,
    "flags_set": [],
    "items_add": [],
    "items_remove": []
  }
}
Include 2-4 choices unless the story has clearly ended, in which case
use an empty choices array. hp_delta is a signed integer (negative for
damage, positive for healing, 0 for no change). flags_set/items_add/
items_remove are arrays of short strings ([] if nothing changes). Do
not include any keys other than the ones shown above.
]]

-- Some models add a ```json fence or a sentence of preamble despite
-- being told not to. Rather than trust the whole reply is bare JSON,
-- slice from the first '{' to the matching last '}'. This assumes a
-- single top-level JSON object with no stray braces in surrounding
-- prose, which holds in practice for this prompt -- it is not a real
-- JSON-aware scan.
local function extract_json(text)
    local first = text:find("{")
    if not first then
        return text
    end
    local last = text:reverse():find("}")
    if not last then
        return text
    end
    last = #text - last + 1
    return text:sub(first, last)
end

function AIProvider.requestStructured(messages)
    local wrapped = { { role = "system", content = STRUCTURED_INSTRUCTIONS } }
    for _, m in ipairs(messages) do
        table.insert(wrapped, m)
    end

    local ok, reply = AIProvider.request(wrapped)
    if not ok then
        return false, reply
    end

    local json_text = extract_json(reply)
    local ok2, parsed = pcall(JSON.decode, json_text)
    if not ok2 or type(parsed) ~= "table" or type(parsed.narration) ~= "string" then
        return false, "AI reply wasn't valid structured JSON:\n" .. tostring(reply)
    end
    parsed.choices = parsed.choices or {}
    parsed.state_changes = parsed.state_changes or {}
    return true, parsed
end

return AIProvider

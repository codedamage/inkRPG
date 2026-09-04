--[[--
AI provider client: one OpenAI-compatible chat-completion request shape,
reused for every backend that speaks it (OpenAI itself, a local Ollama
server, DeepSeek, Groq, OpenRouter, and most proxies) by pointing
base_url/model/api_key at a different entry in configuration.lua.

Modeled on the working pattern from omer-faruq/assistant.koplugin; the
HTTP call itself follows the same socket.http + ltn12 + socketutil shape
used by KOReader's own wallabag.koplugin.

configuration.lua (copy from configuration.sample.lua, keep out of git):

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
Phase 2. This module is wired up but not yet exercised by the Phase 1
demo game (demo-cave is fully hand-authored, zero API calls by design)
-- it's here so Phase 2 is "call AIProvider.request(...) from the play
loop" rather than "invent the HTTP layer from scratch".
--]]--

local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local JSON = require("json")
local logger = require("logger")

local AIProvider = {}

local REQUEST_BLOCK_TIMEOUT = 10
local REQUEST_TOTAL_TIMEOUT = 60

local function loadConfig()
    local _plugin_dir = debug.getinfo(1, "S").source:match("@(.+)/[^/]+$") or "."
    local config_path = _plugin_dir .. "/configuration.lua"
    local chunk = loadfile(config_path)
    if not chunk then
        return nil, "No configuration.lua found -- copy configuration.sample.lua and add your API key."
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

return AIProvider

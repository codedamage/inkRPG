--[[--
In-app AI provider settings: pick a provider preset, enter an API key
(and model / base URL for a custom endpoint), and test the connection --
all from KOReader's own UI. See inkrpg_settings.lua for where this is
actually stored (not in this plugin's folder, not in git).

Reached from Tools > More tools > inkRPG > AI provider settings.
--]]--

local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

local Settings = require("inkrpg_settings")

local SettingsScreen = {}

-- Shows only the last 4 characters, e.g. "************ab12" -- enough
-- for the player to recognize which key is saved without displaying the
-- whole thing on screen.
local function mask_key(key)
    if not key or key == "" then
        return _("not set")
    end
    if #key <= 4 then
        return string.rep("*", #key)
    end
    return string.rep("*", #key - 4) .. key:sub(-4)
end

function SettingsScreen:show()
    local data = Settings.read() or {}
    local preset_info = Settings.PRESETS[data.preset]
    local provider_label = preset_info and preset_info.name or _("not set")

    local item_table = {}

    table.insert(item_table, {
        text = _("Provider: ") .. provider_label,
        callback = function()
            UIManager:close(self.menu)
            self:pickProvider()
        end,
    })

    table.insert(item_table, {
        text = _("Model: ") .. ((data.model and data.model ~= "") and data.model or _("not set")),
        callback = function()
            UIManager:close(self.menu)
            self:editModel(data)
        end,
    })

    if data.preset == "custom" then
        table.insert(item_table, {
            text = _("Base URL: ") .. ((data.base_url and data.base_url ~= "") and data.base_url or _("not set")),
            callback = function()
                UIManager:close(self.menu)
                self:editBaseUrl(data)
            end,
        })
    end

    table.insert(item_table, {
        text = _("API key: ") .. mask_key(data.api_key),
        callback = function()
            UIManager:close(self.menu)
            self:editApiKey(data)
        end,
    })

    table.insert(item_table, {
        text = _("Test connection"),
        callback = function()
            UIManager:close(self.menu)
            self:testConnection()
        end,
    })

    self.menu = Menu:new{
        title = _("inkRPG -- AI provider"),
        item_table = item_table,
        is_borderless = true,
        is_popout = false,
    }
    UIManager:show(self.menu)
end

function SettingsScreen:pickProvider()
    local item_table = {}
    for _, id in ipairs(Settings.PRESET_ORDER) do
        local preset = Settings.PRESETS[id]
        table.insert(item_table, {
            text = preset.name,
            callback = function()
                UIManager:close(self.picker)
                local data = Settings.read() or {}
                data.preset = id
                -- Fill in the preset's default model only if nothing was
                -- typed yet -- never clobber a model the player already
                -- entered by switching providers and back.
                if (not data.model or data.model == "") and preset.default_model ~= "" then
                    data.model = preset.default_model
                end
                -- Non-custom presets own their base_url outright; "custom"
                -- leaves whatever was there (or nothing) for editBaseUrl.
                if id ~= "custom" then
                    data.base_url = preset.base_url
                end
                Settings.write(data)
                self:show()
            end,
        })
    end
    self.picker = Menu:new{
        title = _("Choose a provider"),
        item_table = item_table,
        is_borderless = true,
        is_popout = false,
    }
    UIManager:show(self.picker)
end

function SettingsScreen:editModel(data)
    local dialog
    dialog = InputDialog:new{
        title = _("Model name"),
        input = data.model or "",
        buttons = {{
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                    self:show()
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    data.model = dialog:getInputText()
                    Settings.write(data)
                    UIManager:close(dialog)
                    self:show()
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function SettingsScreen:editBaseUrl(data)
    local dialog
    dialog = InputDialog:new{
        title = _("Base URL"),
        input = data.base_url or "",
        buttons = {{
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                    self:show()
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    data.base_url = dialog:getInputText()
                    Settings.write(data)
                    UIManager:close(dialog)
                    self:show()
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function SettingsScreen:editApiKey(data)
    local dialog
    dialog = InputDialog:new{
        title = _("API key"),
        input = data.api_key or "",
        text_type = "password",
        buttons = {{
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                    self:show()
                end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    data.api_key = dialog:getInputText()
                    Settings.write(data)
                    UIManager:close(dialog)
                    self:show()
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function SettingsScreen:testConnection()
    local AIProvider = require("inkrpg_ai_provider")
    local waiting = InfoMessage:new{ text = _("Testing connection…") }
    UIManager:show(waiting)
    -- AIProvider.request() is a blocking socket call (see
    -- inkrpg_ai_provider.lua) -- calling it directly in this callback
    -- would block before UIManager ever gets a chance to paint the
    -- "Testing..." message above. Deferring it one tick via scheduleIn
    -- lets that message actually render first, at the cost of the UI
    -- being unresponsive for the (still blocking) duration of the
    -- request itself -- a known rough edge, not a real async fix.
    UIManager:scheduleIn(0.1, function()
        UIManager:close(waiting)
        local ok, result = AIProvider.request({
            { role = "user", content = "Reply with exactly the word OK." },
        })
        if ok then
            UIManager:show(InfoMessage:new{
                text = _("Connection OK. Response:\n\n") .. tostring(result),
            })
        else
            UIManager:show(InfoMessage:new{
                text = _("Connection failed:\n\n") .. tostring(result),
            })
        end
        self:show()
    end)
end

return SettingsScreen

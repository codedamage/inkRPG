--[[--
inkRPG -- a single-player, AI-narrated tabletop RPG framework for KOReader.

This file is the engine's entry point only. It discovers game packs under
games/<slug>/manifest.lua, lets the player pick one, and hands off to
inkrpg_play_screen for the actual turn loop. It contains no adventure
content of its own -- see games/demo-cave for a worked, playable example
that needs zero AI calls (Phase 1 of PLAN.md: prove the UI loop before
wiring up an AI provider).

@module koplugin.InkRPG
--]]--

local Dispatcher = require("dispatcher")  -- luacheck:ignore
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local _ = require("gettext")

local GameLoader = require("inkrpg_game_loader")
local PlayScreen = require("inkrpg_play_screen")

local InkRPG = WidgetContainer:extend{
    name = "inkrpg",
    is_doc_only = false,
}

function InkRPG:onDispatcherRegisterActions()
    Dispatcher:registerAction("inkrpg_open_action", {
        category = "none",
        event = "InkRPGOpen",
        title = _("Open inkRPG"),
        general = true,
    })
end

function InkRPG:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function InkRPG:addToMainMenu(menu_items)
    menu_items.inkrpg = {
        text = _("inkRPG"),
        sorting_hint = "more_tools",
        callback = function()
            self:openGamePicker()
        end,
    }
end

function InkRPG:onInkRPGOpen()
    self:openGamePicker()
    return true
end

function InkRPG:openGamePicker()
    local games, err = GameLoader.listGames()
    if not games or #games == 0 then
        UIManager:show(InfoMessage:new{
            text = err or _("No game packs found.\nDrop one into inkrpg.koplugin/games/ -- see games/demo-cave for the format."),
        })
        return
    end

    local game_menu
    local menu_entries = {}
    for _, game in ipairs(games) do
        table.insert(menu_entries, {
            text = game.title or game.slug,
            callback = function()
                UIManager:close(game_menu)
                PlayScreen:start(game)
            end,
        })
    end

    game_menu = Menu:new{
        title = _("inkRPG -- choose a game"),
        item_table = menu_entries,
        is_borderless = true,
        is_popout = false,
    }
    UIManager:show(game_menu)
end

return InkRPG

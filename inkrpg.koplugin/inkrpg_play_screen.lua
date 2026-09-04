--[[--
The turn loop: render the current scene's narration + choices, act on the
player's pick, save, repeat.

Phase 1: scenes are fully hand-authored (see games/demo-cave), so the AI
provider is only ever hit via the optional "...Something else" free-text
action. Phase 2 wires the AI into the main path too, so a scene with no
matching choice can ask it to narrate a continuation instead of dead-ending.
--]]--

local UIManager = require("ui/uimanager")
local TextViewer = require("ui/widget/textviewer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local _ = require("gettext")

local GameLoader = require("inkrpg_game_loader")
local State = require("inkrpg_state")

local PlayScreen = {}

function PlayScreen:start(manifest, slot)
    self.manifest = manifest
    self.slot = slot or "autosave"

    local scenes, err = GameLoader.loadScenes(manifest)
    if not scenes then
        UIManager:show(InfoMessage:new{ text = err })
        return
    end
    self.scenes = scenes

    local saved = State.read(manifest.slug, self.slot)
    self.stats = saved.stats or manifest.starting_stats or {}
    self.flags = saved.flags or {}
    self.scene_id = saved.scene or manifest.start_scene

    self:render()
end

function PlayScreen:save()
    State.write(self.manifest.slug, self.slot, {
        scene = self.scene_id,
        stats = self.stats,
        flags = self.flags,
    })
end

function PlayScreen:goTo(scene_id)
    self.scene_id = scene_id
    self:save()
    self:render()
end

function PlayScreen:restart()
    self.stats = self.manifest.starting_stats or {}
    self.flags = {}
    self.scene_id = self.manifest.start_scene
    self:save()
    self:render()
end

function PlayScreen:render()
    local scene = self.scenes[self.scene_id]
    if not scene then
        UIManager:show(InfoMessage:new{
            text = _("inkRPG: unknown scene '") .. tostring(self.scene_id) .. "'",
        })
        return
    end

    -- A scene can mutate stats/flags deterministically on entry (HP
    -- deltas, items found, flags set) -- no AI required for authored beats.
    if scene.on_enter then
        scene.on_enter(self.stats, self.flags)
    end

    local buttons_table = {}
    for _, choice in ipairs(scene.choices or {}) do
        table.insert(buttons_table, { {
            text = choice.label,
            callback = function()
                UIManager:close(self.viewer)
                self:goTo(choice.next)
            end,
        } })
    end

    if scene.is_ending or #(scene.choices or {}) == 0 then
        table.insert(buttons_table, { {
            text = _("Play again"),
            callback = function()
                UIManager:close(self.viewer)
                self:restart()
            end,
        } })
    else
        table.insert(buttons_table, { {
            text = _("...Something else"),
            callback = function()
                UIManager:close(self.viewer)
                self:promptFreeAction()
            end,
        } })
    end

    self.viewer = TextViewer:new{
        title = self.manifest.title,
        text = scene.text,
        buttons_table = buttons_table,
    }
    UIManager:show(self.viewer)
end

function PlayScreen:promptFreeAction()
    local dialog
    dialog = InputDialog:new{
        title = _("What do you do?"),
        input = "",
        buttons = {{
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(dialog)
                    self:render()
                end,
            },
            {
                text = _("Go"),
                is_enter_default = true,
                callback = function()
                    local action = dialog:getInputText()
                    UIManager:close(dialog)
                    self:handleFreeAction(action)
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function PlayScreen:handleFreeAction(action)
    local AIProvider = require("inkrpg_ai_provider")
    local ok, reply = AIProvider.request({
        { role = "system", content = self.manifest.dm_persona or "You are a fair, concise dungeon master." },
        { role = "user", content = action },
    })
    if not ok then
        UIManager:show(InfoMessage:new{
            text = _("Free-form actions need an AI provider configured -- copy configuration.sample.lua to configuration.lua and add a key.\n\n") .. tostring(reply),
        })
        self:render()
        return
    end
    -- Phase 2 parses structured JSON (narration + choices + state changes)
    -- out of `reply` instead of showing it raw. Scaffold stops here.
    UIManager:show(InfoMessage:new{ text = reply })
    self:render()
end

return PlayScreen

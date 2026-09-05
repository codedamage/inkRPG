--[[--
The turn loop: render the current scene's narration + choices, act on the
player's pick, save, repeat.

Phase 1: scenes are fully hand-authored (see games/demo-cave), so the AI
provider is only ever hit via the optional "...Something else" free-text
action, and its reply is shown as raw text with no way back into the story.

Phase 2 (this file): once the player goes off the authored scene graph, the
AI takes over the main path too. `self.ai_scene` holds the current
AI-improvised node ({narration, choices}) when the player is in that mode;
it's nil while they're still walking the authored graph. Picking a choice on
an authored scene (`goTo`) or restarting always drops back to `ai_scene =
nil` -- AI-driven play only starts from "...Something else" and, once
started, stays AI-driven (each of its own choices is itself sent back to the
AI) until the player restarts.
--]]--

local UIManager = require("ui/uimanager")
local TextViewer = require("ui/widget/textviewer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local _ = require("gettext")

local GameLoader = require("inkrpg_game_loader")
local State = require("inkrpg_state")

local PlayScreen = {}

-- self.stats gets mutated in place (HP deltas, inventory adds/removes), so
-- a fresh playthrough must never alias manifest.starting_stats directly --
-- otherwise the first goblin bite would permanently lower every future
-- restart's "fresh" starting HP. Recursive because starting_stats.inventory
-- is itself a table.
local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

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
    self.stats = saved.stats or deepCopy(manifest.starting_stats) or {}
    self.flags = saved.flags or {}
    self.scene_id = saved.scene or manifest.start_scene
    self.ai_scene = saved.ai_scene

    self:render()
end

function PlayScreen:save()
    State.write(self.manifest.slug, self.slot, {
        scene = self.scene_id,
        stats = self.stats,
        flags = self.flags,
        ai_scene = self.ai_scene,
    })
end

-- Moving to an authored scene always leaves AI-improvised territory.
function PlayScreen:goTo(scene_id)
    self.scene_id = scene_id
    self.ai_scene = nil
    self:save()
    self:render()
end

function PlayScreen:restart()
    self.stats = deepCopy(self.manifest.starting_stats) or {}
    self.flags = {}
    self.scene_id = self.manifest.start_scene
    self.ai_scene = nil
    self:save()
    self:render()
end

-- Applies one AI reply's game-mechanical side effects to self.stats/flags.
-- hp_delta is clamped to [0, max_hp] when max_hp is known (never below 0,
-- never healed past the character's max); with no max_hp on record it's
-- only clamped at 0. flags_set/items_add/items_remove are best-effort: any
-- field the model omitted is already defaulted to {} by requestStructured.
function PlayScreen:applyStateChanges(state_changes)
    state_changes = state_changes or {}

    if state_changes.hp_delta and state_changes.hp_delta ~= 0 then
        local hp = (self.stats.hp or 0) + state_changes.hp_delta
        if hp < 0 then
            hp = 0
        end
        if self.stats.max_hp and hp > self.stats.max_hp then
            hp = self.stats.max_hp
        end
        self.stats.hp = hp
    end

    for _, flag in ipairs(state_changes.flags_set or {}) do
        self.flags[flag] = true
    end

    self.stats.inventory = self.stats.inventory or {}

    for _, item in ipairs(state_changes.items_add or {}) do
        local already_have = false
        for _, have in ipairs(self.stats.inventory) do
            if have == item then
                already_have = true
                break
            end
        end
        if not already_have then
            table.insert(self.stats.inventory, item)
        end
    end

    for _, item in ipairs(state_changes.items_remove or {}) do
        for i, have in ipairs(self.stats.inventory) do
            if have == item then
                table.remove(self.stats.inventory, i)
                break
            end
        end
    end
end

-- The system-prompt context sent with every AI request: the game's DM
-- persona plus a flattened, plain-text snapshot of current stats/flags, so
-- the model's narration and choices stay consistent with what already
-- happened (HP lost, items picked up, flags earned) instead of drifting.
function PlayScreen:buildContext()
    local lines = {
        self.manifest.dm_persona or "You are a fair, concise dungeon master.",
        "",
        "Current character state:",
    }

    for key, value in pairs(self.stats or {}) do
        if key == "inventory" then
            table.insert(lines, "  inventory: " .. table.concat(value, ", "))
        else
            table.insert(lines, "  " .. tostring(key) .. ": " .. tostring(value))
        end
    end

    local flag_names = {}
    for flag, is_set in pairs(self.flags or {}) do
        if is_set then
            table.insert(flag_names, flag)
        end
    end
    if #flag_names > 0 then
        table.insert(lines, "  flags: " .. table.concat(flag_names, ", "))
    end

    return table.concat(lines, "\n")
end

function PlayScreen:render()
    if self.ai_scene then
        self:renderAiScene()
        return
    end

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

-- Renders the current AI-improvised node the same way an authored scene
-- renders: narration as the body text, each of the AI's own choices as a
-- button that sends that choice's label back to the AI as the next action.
-- An empty choices array means the AI ended the story, same as
-- scene.is_ending.
function PlayScreen:renderAiScene()
    local buttons_table = {}
    for _, choice in ipairs(self.ai_scene.choices or {}) do
        table.insert(buttons_table, { {
            text = choice.label,
            callback = function()
                UIManager:close(self.viewer)
                self:sendAiAction(choice.label)
            end,
        } })
    end

    if #(self.ai_scene.choices or {}) == 0 then
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
        text = self.ai_scene.narration,
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
                    self:sendAiAction(action)
                end,
            },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

-- The Phase 2 entry point: sends the player's freeform action (or a click
-- on one of the AI's own previous choices) to the AI, applies the
-- mechanical side effects it reports, and adopts its reply as the new
-- current node -- from here on the player is in AI-improvised territory
-- until they restart.
function PlayScreen:sendAiAction(action)
    local AIProvider = require("inkrpg_ai_provider")
    local ok, result = AIProvider.requestStructured({
        { role = "system", content = self:buildContext() },
        { role = "user", content = action },
    })
    if not ok then
        UIManager:show(InfoMessage:new{
            text = _("Free-form actions need an AI provider configured -- copy configuration.sample.lua to configuration.lua and add a key.\n\n") .. tostring(result),
        })
        self:render()
        return
    end

    self:applyStateChanges(result.state_changes)
    self.ai_scene = {
        narration = result.narration,
        choices = result.choices,
    }
    self:save()
    self:render()
end

return PlayScreen

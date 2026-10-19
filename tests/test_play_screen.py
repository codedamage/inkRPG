"""inkrpg_play_screen.lua -- the turn loop. PlayScreen is used as a plain
singleton table (methods called with `:`, never instantiated), so tests
below poke its fields directly rather than going through GameLoader/file
loading -- keeps these tests focused on the turn-loop logic itself."""

import pytest


def _fresh(env):
    """A PlayScreen wired up with a tiny two-scene authored graph and
    starting stats, bypassing :start()'s manifest-file loading."""
    PlayScreen = env.require("inkrpg_play_screen")
    env.lua.execute("""
        local PlayScreen = require("inkrpg_play_screen")
        PlayScreen.manifest = {
            slug = "test-game",
            title = "Test Game",
            dm_persona = "You are terse.",
            start_scene = "start_scene",
            starting_stats = { hp = 10, max_hp = 10, inventory = {} },
        }
        PlayScreen.slot = "autosave"
        PlayScreen.scenes = {
            start_scene = {
                text = "The beginning.",
                choices = { { label = "Go on", next = "end_scene" } },
            },
            end_scene = {
                is_ending = true,
                text = "The end.",
                choices = {},
            },
        }
        PlayScreen.stats = { hp = 10, max_hp = 10, inventory = {} }
        PlayScreen.flags = {}
        PlayScreen.scene_id = "start_scene"
        PlayScreen.ai_scene = nil
    """)
    return PlayScreen


# -- applyStateChanges --------------------------------------------------

def test_apply_state_changes_hp_delta(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval("{ hp_delta = -3 }"))
    assert PlayScreen["stats"]["hp"] == 7


def test_apply_state_changes_clamps_hp_at_zero(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval("{ hp_delta = -999 }"))
    assert PlayScreen["stats"]["hp"] == 0


def test_apply_state_changes_clamps_hp_at_max(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval("{ hp_delta = -3 }"))
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval("{ hp_delta = 999 }"))
    assert PlayScreen["stats"]["hp"] == 10  # never past max_hp


def test_apply_state_changes_sets_flags(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval('{ flags_set = { "found_key", "met_ghost" } }'))
    assert PlayScreen["flags"]["found_key"] is True
    assert PlayScreen["flags"]["met_ghost"] is True


def test_apply_state_changes_adds_items_without_duplicating(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval('{ items_add = { "torch" } }'))
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval('{ items_add = { "torch", "key" } }'))
    inventory = list(PlayScreen["stats"]["inventory"].values())
    assert inventory.count("torch") == 1
    assert "key" in inventory


def test_apply_state_changes_removes_items(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval('{ items_add = { "torch", "key" } }'))
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval('{ items_remove = { "torch" } }'))
    inventory = list(PlayScreen["stats"]["inventory"].values())
    assert inventory == ["key"]


def test_apply_state_changes_tolerates_nil(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, None)  # requestStructured always fills these in, but don't crash if not
    assert PlayScreen["stats"]["hp"] == 10


# -- buildContext ---------------------------------------------------------

def test_build_context_includes_persona_and_stats(env):
    PlayScreen = _fresh(env)
    PlayScreen["stats"]["torches"] = 2
    ctx = PlayScreen.buildContext(PlayScreen)
    assert "You are terse." in ctx
    assert "hp: 10" in ctx
    assert "torches: 2" in ctx


def test_build_context_lists_inventory_and_flags(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval('{ items_add = { "torch", "rope" }, flags_set = { "met_ghost" } }'))
    ctx = PlayScreen.buildContext(PlayScreen)
    assert "inventory: torch, rope" in ctx
    assert "flags: met_ghost" in ctx


def test_build_context_falls_back_to_default_persona(env):
    PlayScreen = _fresh(env)
    PlayScreen["manifest"]["dm_persona"] = None
    ctx = PlayScreen.buildContext(PlayScreen)
    assert "fair, concise dungeon master" in ctx


# -- goTo / restart: always leave AI-improvised territory ------------------

def test_goto_clears_ai_scene_and_saves(env):
    PlayScreen = _fresh(env)
    PlayScreen["ai_scene"] = env.lua.eval('{ narration = "improvised", choices = {} }')
    PlayScreen.goTo(PlayScreen, "end_scene")
    assert PlayScreen["scene_id"] == "end_scene"
    assert PlayScreen["ai_scene"] is None

    State = env.require("inkrpg_state")
    saved = State.read("test-game", "autosave")
    assert saved["scene"] == "end_scene"
    assert saved["ai_scene"] is None


def test_restart_resets_stats_and_scene(env):
    PlayScreen = _fresh(env)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval("{ hp_delta = -9 }"))
    PlayScreen.goTo(PlayScreen, "end_scene")
    PlayScreen.restart(PlayScreen)
    assert PlayScreen["stats"]["hp"] == 10
    assert PlayScreen["scene_id"] == "start_scene"
    assert PlayScreen["ai_scene"] is None
    assert len(PlayScreen["flags"]) == 0


def test_restart_does_not_alias_manifest_starting_stats(env):
    # The bug deepCopy() exists to prevent: mutating one playthrough's HP
    # must never leak into manifest.starting_stats itself, or a second
    # restart would inherit the damage.
    PlayScreen = env.require("inkrpg_play_screen")
    env.lua.execute("""
        local PlayScreen = require("inkrpg_play_screen")
        PlayScreen.manifest = {
            slug = "test-game",
            title = "Test Game",
            starting_stats = { hp = 10, max_hp = 10 },
        }
        PlayScreen.scenes = { start_scene = { text = "x", choices = {} } }
        PlayScreen.stats = { hp = 10, max_hp = 10 }
        PlayScreen.flags = {}
        PlayScreen.scene_id = "start_scene"
    """)
    PlayScreen.applyStateChanges(PlayScreen, env.lua.eval("{ hp_delta = -10 }"))
    assert PlayScreen["stats"]["hp"] == 0
    PlayScreen.restart(PlayScreen)
    assert PlayScreen["stats"]["hp"] == 10
    assert PlayScreen["manifest"]["starting_stats"]["hp"] == 10


# -- sendAiAction: the Phase 2 entry point ---------------------------------

def test_send_ai_action_success_adopts_the_reply(env):
    PlayScreen = _fresh(env)
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider["requestStructured"] = lambda messages: (
        True,
        env.lua.eval('{ narration = "A door creaks open.", '
                     'choices = { { label = "Enter", id = "enter" } }, '
                     'state_changes = { hp_delta = -1 } }'),
    )

    PlayScreen.sendAiAction(PlayScreen, "look around")

    assert PlayScreen["ai_scene"]["narration"] == "A door creaks open."
    assert PlayScreen["stats"]["hp"] == 9
    assert PlayScreen["ai_scene"] is not None


def test_send_ai_action_failure_shows_error_and_stays_on_current_scene(env):
    PlayScreen = _fresh(env)
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider["requestStructured"] = lambda messages: (False, "No AI provider configured")

    PlayScreen.sendAiAction(PlayScreen, "look around")

    # Falls back to re-rendering the authored scene -- ai_scene must stay nil.
    assert PlayScreen["ai_scene"] is None
    assert PlayScreen["scene_id"] == "start_scene"


# -- "...Something else": the free-action dialog ----------------------------

def _contains(env, lua_list, widget):
    # Compare inside Lua: lupa hands out a fresh Python wrapper per access,
    # so Python identity can't tell whether two wrappers are the same table.
    contains = env.lua.eval(
        "function(list, w) for i = 1, #list do if list[i] == w then return true end end return false end")
    return contains(lua_list, widget)


def _something_else_button(viewer):
    rows = viewer["buttons_table"]
    last_row = rows[len(rows)]
    assert last_row[1]["text"] == "...Something else"
    return last_row[1]


def _last_shown(UIManager):
    shown = UIManager["_shown"]
    return shown[len(shown)]


def test_something_else_keeps_the_scene_under_the_dialog(env):
    PlayScreen = _fresh(env)
    UIManager = env.require("ui/uimanager")
    PlayScreen.render(PlayScreen)
    viewer = PlayScreen["viewer"]

    _something_else_button(viewer)["callback"]()

    assert not _contains(env, UIManager["_closed"], viewer)
    assert _last_shown(UIManager)["title"] == "What do you do?"


def test_cancel_closes_only_the_dialog_without_redrawing_the_scene(env):
    PlayScreen = _fresh(env)
    UIManager = env.require("ui/uimanager")
    PlayScreen.render(PlayScreen)
    viewer = PlayScreen["viewer"]
    _something_else_button(viewer)["callback"]()
    dialog = _last_shown(UIManager)
    shown_before = len(UIManager["_shown"])

    dialog["buttons"][1][1]["callback"]()  # Cancel

    assert _contains(env, UIManager["_closed"], dialog)
    assert not _contains(env, UIManager["_closed"], viewer)
    assert len(UIManager["_shown"]) == shown_before
    assert env.lua.eval("function(a, b) return a == b end")(PlayScreen["viewer"], viewer)


def test_go_keeps_the_scene_and_shows_thinking_until_the_reply_replaces_it(env):
    PlayScreen = _fresh(env)
    UIManager = env.require("ui/uimanager")
    AIProvider = env.require("inkrpg_ai_provider")
    PlayScreen.render(PlayScreen)
    viewer = PlayScreen["viewer"]
    _something_else_button(viewer)["callback"]()
    dialog = _last_shown(UIManager)
    dialog["_test_input"] = "look around"

    seen_during_request = {}

    def fake_request(messages):
        seen_during_request["top"] = _last_shown(UIManager)
        seen_during_request["scene_closed"] = _contains(env, UIManager["_closed"], viewer)
        return (True, env.lua.eval('{ narration = "A door creaks open.", '
                                   'choices = { { label = "Enter" } } }'))

    AIProvider["requestStructured"] = fake_request

    dialog["buttons"][1][2]["callback"]()  # Go

    assert not seen_during_request["scene_closed"]
    assert _contains(env, UIManager["_closed"], viewer)
    thinking = seen_during_request["top"]
    assert "thinking" in thinking["text"]
    assert _contains(env, UIManager["_closed"], thinking)
    assert PlayScreen["ai_scene"]["narration"] == "A door creaks open."


def test_ai_failure_leaves_the_current_scene_on_screen(env):
    PlayScreen = _fresh(env)
    UIManager = env.require("ui/uimanager")
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider["requestStructured"] = lambda messages: (False, "connection refused")
    PlayScreen.render(PlayScreen)
    viewer = PlayScreen["viewer"]
    shown_before = len(UIManager["_shown"])

    PlayScreen.sendAiAction(PlayScreen, "look around")

    assert not _contains(env, UIManager["_closed"], viewer)
    # thinking message + error message, and no second copy of the scene
    assert len(UIManager["_shown"]) == shown_before + 2
    assert "connection refused" in _last_shown(UIManager)["text"]

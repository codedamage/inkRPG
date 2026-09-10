"""inkrpg_state.lua -- per-(game, slot) save/load on top of LuaSettings."""


def test_read_missing_save_returns_empty_defaults(env):
    State = env.require("inkrpg_state")
    data = State.read("demo-cave", "autosave")
    assert data["scene"] is None
    assert len(data["stats"]) == 0
    assert len(data["flags"]) == 0
    assert data["ai_scene"] is None


def test_write_then_read_round_trips(env):
    State = env.require("inkrpg_state")
    State.write("demo-cave", "autosave", env.lua.eval(
        '{ scene = "entrance_hall", stats = { hp = 7, max_hp = 10 }, '
        'flags = { met_ghost = true }, ai_scene = nil }'
    ))
    data = State.read("demo-cave", "autosave")
    assert data["scene"] == "entrance_hall"
    assert data["stats"]["hp"] == 7
    assert data["stats"]["max_hp"] == 10
    assert data["flags"]["met_ghost"] is True


def test_different_slots_are_independent(env):
    State = env.require("inkrpg_state")
    State.write("demo-cave", "slot1", env.lua.eval('{ scene = "a" }'))
    State.write("demo-cave", "slot2", env.lua.eval('{ scene = "b" }'))
    assert State.read("demo-cave", "slot1")["scene"] == "a"
    assert State.read("demo-cave", "slot2")["scene"] == "b"


def test_different_games_are_independent(env):
    # Same slot name, different game slug -- must not collide. This is the
    # whole reason saves are keyed "<game_slug>_<slot>", not just "<slot>".
    State = env.require("inkrpg_state")
    State.write("demo-cave", "autosave", env.lua.eval('{ scene = "cave_mouth" }'))
    State.write("other-game", "autosave", env.lua.eval('{ scene = "other_start" }'))
    assert State.read("demo-cave", "autosave")["scene"] == "cave_mouth"
    assert State.read("other-game", "autosave")["scene"] == "other_start"


def test_slot_defaults_to_autosave(env):
    State = env.require("inkrpg_state")
    State.write("demo-cave", None, env.lua.eval('{ scene = "x" }'))
    assert State.read("demo-cave", "autosave")["scene"] == "x"

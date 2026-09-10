"""inkrpg_settings.lua -- the AI provider settings store (presets + the
saved preset/model/base_url/api_key), used by both the in-app settings
screen and inkrpg_ai_provider's config resolution."""


def test_read_before_anything_saved_returns_nil(env):
    Settings = env.require("inkrpg_settings")
    assert Settings.read() is None


def test_write_then_read_round_trips(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval(
        '{ preset = "openai", model = "gpt-4o-mini", '
        'base_url = "https://api.openai.com/v1/chat/completions", api_key = "sk-test" }'
    ))
    data = Settings.read()
    assert data["preset"] == "openai"
    assert data["model"] == "gpt-4o-mini"
    assert data["base_url"] == "https://api.openai.com/v1/chat/completions"
    assert data["api_key"] == "sk-test"


def test_presets_cover_the_documented_order(env):
    Settings = env.require("inkrpg_settings")
    order = list(Settings["PRESET_ORDER"].values())
    assert order == ["openai", "ollama", "deepseek", "groq", "openrouter", "custom"]
    for preset_id in order:
        preset = Settings["PRESETS"][preset_id]
        assert preset["name"]
        # "custom" deliberately has no fixed base_url/model -- the settings
        # screen prompts for them. Every other preset must ship real
        # defaults so picking it alone is enough to Test Connection.
        if preset_id != "custom":
            assert preset["base_url"].startswith("http")
            assert preset["default_model"] != ""


def test_settings_persist_across_separate_opens(env):
    # Settings.read()/write() each open+close their own LuaSettings handle
    # (mirrors what the real KOReader settings dir does across app
    # restarts) -- make sure that round-trips, not just within one handle.
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "groq", model = "llama-3.1-8b-instant" }'))
    Settings2 = env.require("inkrpg_settings")  # same runtime, same in-memory store
    assert Settings2.read()["preset"] == "groq"

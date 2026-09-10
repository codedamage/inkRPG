"""inkrpg_settings_screen.lua -- the in-app AI provider settings UI. Since
Menu/InputDialog/InfoMessage are just plain tables in the stubs (see
lua_stubs.lua's widget_stub), tests here call the shown widget's own
button callbacks directly instead of driving a real screen."""


def _last_shown(env):
    UIManager = env.require("ui/uimanager")
    shown = UIManager["_shown"]
    return shown[len(shown)]


def _last_shown_with_text(env):
    """testConnection() shows an InfoMessage and then re-renders the menu
    (self:show()) right after -- both land in _shown, so grab the last
    widget that actually looks like a message rather than just the last
    thing shown."""
    UIManager = env.require("ui/uimanager")
    shown = UIManager["_shown"]
    for i in range(len(shown), 0, -1):
        widget = shown[i]
        if widget["text"] is not None:
            return widget
    raise AssertionError("no shown widget had a .text field")


def test_show_lists_provider_model_and_test_connection(env):
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.show(SettingsScreen)
    menu = _last_shown(env)
    texts = [item["text"] for item in menu["item_table"].values()]
    assert any(t.startswith("Provider:") for t in texts)
    assert any(t.startswith("Model:") for t in texts)
    assert any(t == "API key: not set" for t in texts)
    assert "Test connection" in texts
    # No provider chosen yet -- no Base URL row (that's custom-preset only).
    assert not any(t.startswith("Base URL:") for t in texts)


def test_show_masks_a_saved_api_key(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai", model = "gpt-4o-mini", api_key = "sk-abcdefgh1234" }'))
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.show(SettingsScreen)
    menu = _last_shown(env)
    texts = [item["text"] for item in menu["item_table"].values()]
    key_row = next(t for t in texts if t.startswith("API key:"))
    assert key_row.endswith("1234")
    assert "sk-abcdefgh" not in key_row


def test_custom_preset_shows_base_url_row(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "custom" }'))
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.show(SettingsScreen)
    menu = _last_shown(env)
    texts = [item["text"] for item in menu["item_table"].values()]
    assert any(t.startswith("Base URL:") for t in texts)


def test_pick_provider_fills_in_default_model_and_base_url(env):
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.pickProvider(SettingsScreen)
    picker = _last_shown(env)
    ollama_item = next(i for i in picker["item_table"].values() if i["text"] == "Local Ollama")
    ollama_item["callback"]()

    Settings = env.require("inkrpg_settings")
    data = Settings.read()
    assert data["preset"] == "ollama"
    assert data["model"] == "llama3.1"
    assert data["base_url"] == "http://localhost:11434/v1/chat/completions"


def test_pick_provider_never_clobbers_an_already_typed_model(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai", model = "my-custom-finetune" }'))
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.pickProvider(SettingsScreen)
    picker = _last_shown(env)
    groq_item = next(i for i in picker["item_table"].values() if i["text"] == "Groq")
    groq_item["callback"]()

    data = Settings.read()
    assert data["preset"] == "groq"
    assert data["model"] == "my-custom-finetune"  # untouched


def test_edit_model_saves_typed_text(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai", model = "gpt-4o-mini" }'))
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.editModel(SettingsScreen, Settings.read())
    dialog = _last_shown(env)
    dialog["_test_input"] = "gpt-4o"
    save_button = dialog["buttons"][1][2]
    assert save_button["text"] == "Save"
    save_button["callback"]()

    assert Settings.read()["model"] == "gpt-4o"


def test_edit_api_key_saves_typed_text(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai" }'))
    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.editApiKey(SettingsScreen, Settings.read())
    dialog = _last_shown(env)
    dialog["_test_input"] = "sk-newkey"
    dialog["buttons"][1][2]["callback"]()

    assert Settings.read()["api_key"] == "sk-newkey"


def test_test_connection_shows_success_message(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai", model = "gpt-4o-mini", api_key = "sk-x" }'))
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider["request"] = lambda messages: (True, "OK")

    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.testConnection(SettingsScreen)

    info = _last_shown_with_text(env)
    assert "Connection OK" in info["text"]


def test_test_connection_shows_failure_message(env):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai", model = "gpt-4o-mini", api_key = "sk-x" }'))
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider["request"] = lambda messages: (False, "AI request failed (HTTP 404)")

    SettingsScreen = env.require("inkrpg_settings_screen")
    SettingsScreen.testConnection(SettingsScreen)

    info = _last_shown_with_text(env)
    assert "Connection failed" in info["text"]
    assert "404" in info["text"]

"""inkrpg_ai_provider.lua -- config resolution priority, the raw request(),
and requestStructured()'s JSON-mode enforcement + parsing. All HTTP is
faked via env.set_http_response()/set_http_handler() -- nothing here ever
makes a real network call or reads the real configuration.lua."""

import json as pyjson


OK_CHAT_RESPONSE = pyjson.dumps({"choices": [{"message": {"content": "OK"}}]})


def _configure_via_settings(env, preset="openai", model="gpt-4o-mini",
                             base_url="https://api.openai.com/v1/chat/completions",
                             api_key="sk-test"):
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval(
        '{ preset = %r, model = %r, base_url = %r, api_key = %r }'
        % (preset, model, base_url, api_key)
    ))


# -- loadConfig priority: settings screen first, configuration.lua fallback

def test_request_fails_with_no_config_at_all(env):
    env.fake_loadfile_missing()
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "No AI provider configured" in err


def test_request_falls_back_to_configuration_lua_when_nothing_saved(env):
    env.fake_loadfile_returns(
        '{ provider = "openai", provider_settings = { openai = { '
        'model = "gpt-4o-mini", base_url = "https://api.openai.com/v1/chat/completions", '
        'api_key = "sk-fallback" } } }'
    )
    env.set_http_handler(lambda req: (200, OK_CHAT_RESPONSE))
    AIProvider = env.require("inkrpg_ai_provider")
    ok, text = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is True
    assert text == "OK"


def test_request_prefers_settings_screen_over_configuration_lua(env):
    # If loadfile() were ever consulted here, it would explode -- it's
    # wired to error on any call for this test, so this also proves the
    # settings-store path short-circuits before touching configuration.lua.
    env.lua.execute('loadfile = function(path) error("should not be called") end')
    _configure_via_settings(env, api_key="sk-from-settings")

    captured = {}

    def handler(req):
        captured["auth"] = req["headers"]["Authorization"]
        return 200, OK_CHAT_RESPONSE

    env.set_http_handler(handler)
    AIProvider = env.require("inkrpg_ai_provider")
    ok, _ = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is True
    assert captured["auth"] == "Bearer sk-from-settings"


def test_request_ignores_settings_with_no_api_key_yet(env):
    # A preset picked but no key typed in yet -- Settings.read() returns a
    # table, but loadConfig must still fall through to configuration.lua
    # rather than treating an empty key as configured.
    Settings = env.require("inkrpg_settings")
    Settings.write(env.lua.eval('{ preset = "openai", model = "gpt-4o-mini", api_key = "" }'))
    env.fake_loadfile_returns(
        '{ provider = "deepseek", provider_settings = { deepseek = { '
        'model = "deepseek-chat", base_url = "https://api.deepseek.com/v1/chat/completions", '
        'api_key = "sk-fallback" } } }'
    )
    captured = {}
    env.set_http_handler(lambda req: (captured.__setitem__("url", req["url"]), (200, OK_CHAT_RESPONSE))[1])
    AIProvider = env.require("inkrpg_ai_provider")
    ok, _ = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is True
    assert captured["url"] == "https://api.deepseek.com/v1/chat/completions"


def test_request_fails_when_configured_provider_has_no_api_key(env):
    env.fake_loadfile_returns(
        '{ provider = "openai", provider_settings = { openai = { '
        'model = "gpt-4o-mini", base_url = "https://api.openai.com/v1/chat/completions" } } }'
    )
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "No API key configured" in err


# -- request(): payload shape, timeouts, error handling --------------------

def test_request_sends_model_and_messages(env):
    _configure_via_settings(env, model="gpt-4o-mini")
    captured = {}

    def handler(req):
        captured["body"] = pyjson.loads(env.body_of(req))
        return 200, OK_CHAT_RESPONSE

    env.set_http_handler(handler)
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider.request(env.lua.eval('{ { role = "user", content = "hello" } }'))
    assert captured["body"]["model"] == "gpt-4o-mini"
    assert captured["body"]["messages"] == [{"role": "user", "content": "hello"}]
    assert "response_format" not in captured["body"]


def test_plain_request_does_not_force_json_mode(env):
    # Test Connection uses plain request() and must not have its "reply
    # with exactly OK" response constrained to JSON mode.
    _configure_via_settings(env)
    captured = {}
    env.set_http_handler(lambda req: (captured.__setitem__("body", pyjson.loads(env.body_of(req))), (200, OK_CHAT_RESPONSE))[1])
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert "response_format" not in captured["body"]


def test_request_uses_generous_timeouts(env):
    # Regression guard: the block timeout was once 10s and silently broke
    # real (slower) generations with a "wantread" failure. Make sure it
    # never quietly shrinks back down.
    _configure_via_settings(env)
    env.set_http_response(200, OK_CHAT_RESPONSE)
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    timeout = env.last_timeout()
    assert timeout["block"] >= 30
    assert timeout["total"] >= 60


def test_request_reports_non_200_status(env):
    _configure_via_settings(env)
    env.set_http_response(404, '{"error": "model not found"}')
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "404" in err


def test_request_reports_unparseable_response(env):
    _configure_via_settings(env)
    env.set_http_response(200, "not json at all {{{")
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "parse" in err.lower()


def test_request_reports_missing_message_content(env):
    _configure_via_settings(env)
    env.set_http_response(200, pyjson.dumps({"choices": []}))
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.request(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "no message content" in err.lower()


# -- requestStructured(): forces JSON mode, extracts/parses the reply ------

def test_structured_request_sets_json_response_format(env):
    _configure_via_settings(env)
    captured = {}
    reply = pyjson.dumps({"narration": "Hi.", "choices": [], "state_changes": {}})
    env.set_http_handler(lambda req: (captured.__setitem__("body", pyjson.loads(env.body_of(req))), (200, pyjson.dumps({"choices": [{"message": {"content": reply}}]})))[1])
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider.requestStructured(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert captured["body"]["response_format"] == {"type": "json_object"}


def test_structured_request_prepends_system_instructions(env):
    _configure_via_settings(env)
    captured = {}
    reply = pyjson.dumps({"narration": "Hi.", "choices": [], "state_changes": {}})
    env.set_http_handler(lambda req: (captured.__setitem__("body", pyjson.loads(env.body_of(req))), (200, pyjson.dumps({"choices": [{"message": {"content": reply}}]})))[1])
    AIProvider = env.require("inkrpg_ai_provider")
    AIProvider.requestStructured(env.lua.eval('{ { role = "system", content = "game context" }, { role = "user", content = "hi" } }'))
    messages = captured["body"]["messages"]
    assert messages[0]["role"] == "system"
    assert "JSON object" in messages[0]["content"]
    assert messages[1] == {"role": "system", "content": "game context"}
    assert messages[2] == {"role": "user", "content": "hi"}


def test_structured_request_parses_clean_json(env):
    _configure_via_settings(env)
    reply = pyjson.dumps({
        "narration": "A door creaks open.",
        "choices": [{"label": "Enter", "id": "enter"}],
        "state_changes": {"hp_delta": -1, "flags_set": ["found_door"]},
    })
    env.set_http_response(200, pyjson.dumps({"choices": [{"message": {"content": reply}}]}))
    AIProvider = env.require("inkrpg_ai_provider")
    ok, parsed = AIProvider.requestStructured(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is True
    assert parsed["narration"] == "A door creaks open."
    assert list(parsed["choices"].values())[0]["label"] == "Enter"
    assert parsed["state_changes"]["hp_delta"] == -1


def test_structured_request_strips_markdown_fence(env):
    # Some models wrap the JSON in ```json ... ``` despite being told not
    # to -- extract_json() slices from the first { to the last } to cope.
    _configure_via_settings(env)
    inner = pyjson.dumps({"narration": "Hi.", "choices": [], "state_changes": {}})
    fenced = "Here you go:\n```json\n" + inner + "\n```\nHope that helps!"
    env.set_http_response(200, pyjson.dumps({"choices": [{"message": {"content": fenced}}]}))
    AIProvider = env.require("inkrpg_ai_provider")
    ok, parsed = AIProvider.requestStructured(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is True
    assert parsed["narration"] == "Hi."


def test_structured_request_defaults_missing_optional_fields(env):
    reply = pyjson.dumps({"narration": "Just narration."})
    _configure_via_settings(env)
    env.set_http_response(200, pyjson.dumps({"choices": [{"message": {"content": reply}}]}))
    AIProvider = env.require("inkrpg_ai_provider")
    ok, parsed = AIProvider.requestStructured(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is True
    assert len(parsed["choices"]) == 0
    assert len(parsed["state_changes"]) == 0


def test_structured_request_rejects_plain_prose(env):
    _configure_via_settings(env)
    env.set_http_response(200, pyjson.dumps({"choices": [{"message": {"content": "Sure, here's what happens next..."}}]}))
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.requestStructured(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "valid structured JSON" in err


def test_structured_request_propagates_http_failure(env):
    _configure_via_settings(env)
    env.set_http_response(503, "high demand")
    AIProvider = env.require("inkrpg_ai_provider")
    ok, err = AIProvider.requestStructured(env.lua.eval('{ { role = "user", content = "hi" } }'))
    assert ok is False
    assert "503" in err

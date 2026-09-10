# inkRPG test suite

Runs every `inkrpg.koplugin/*.lua` module outside a real KOReader install,
by faking the handful of KOReader/LuaSocket APIs the plugin touches (see
`lua_stubs.lua`) and letting `require()` load the real plugin code through
[lupa](https://github.com/scoder/lupa) (a Python binding to LuaJIT/Lua).
This is the same ad-hoc technique used throughout this project's
development, formalized into a real, repeatable suite so a future change
that breaks something gets caught instead of silently regressing.

## Running

```sh
pip install -r tests/requirements.txt
pytest tests/
```

Run from a Linux/macOS/WSL shell (the emulator setup already assumes
Docker + Linux for the same reason) -- `test_ai_provider.py` and
`test_game_loader.py` rely on the plugin's own path-splitting logic, which
expects `/`-style paths.

## What's covered

- `test_syntax.py` -- every `.lua` file in the plugin loads without a
  syntax error. Cheap, catches typos immediately.
- `test_dice.py` -- the dice/skill-check helper.
- `test_state.py` -- save/load persistence, keyed correctly per (game, slot).
- `test_settings.py` -- the AI provider settings store and its presets.
- `test_settings_screen.py` -- the in-app settings UI's menu wiring
  (provider picker, model/base URL/API key editors, Test connection).
- `test_game_loader.py` -- game pack discovery, and (doubling as content
  validation) that the bundled demo-cave game pack's scene graph is
  actually well-formed: every choice points at a real scene, every
  non-ending scene has a way forward.
- `test_play_screen.py` -- the turn loop: HP/inventory/flag mutations,
  restart never leaking state into a fresh playthrough, and the AI
  hand-off (`sendAiAction`) on both success and failure.
- `test_ai_provider.py` -- config resolution priority (settings screen
  before `configuration.lua`), the request payload shape, the timeout
  values (a regression guard -- this project already had a too-short
  timeout silently break real generations once), and `requestStructured`'s
  JSON-mode enforcement and parsing (including the markdown-fence-stripping
  fallback real models have actually triggered).

## What isn't covered

This never drives real KOReader widgets (no real rendering, no real
touch/keyboard input) and never makes a real network call -- it's testing
this plugin's own logic, not KOReader itself or a live AI provider. The
emulator under `../emulator/` is what exercises the real thing end to end;
this suite is the fast, no-device, no-API-key layer underneath it.

## A note on credentials

None of this ever reads `inkrpg.koplugin/configuration.lua` (the
gitignored, real-API-key file a developer may have sitting next to the
plugin for local testing). Anywhere the plugin code would normally read
that file, the tests replace Lua's own `loadfile()` with a fake that
returns a canned in-memory table instead -- see `env.py`'s
`fake_loadfile_returns`/`fake_loadfile_missing`.

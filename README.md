# inkRPG

A single-player, AI-narrated tabletop RPG framework for KOReader.

- `PLAN.md` -- investigation + phased build plan. Read this first.
- `inkrpg.koplugin/` -- the engine: a KOReader plugin. Game-agnostic.
- `inkrpg.koplugin/games/` -- game packs (content only, no code).
  `demo-cave` is the Phase 1 reference game: fully playable with zero AI
  calls, to prove the engine loop before any AI wiring lands.

## Status

Phase 0/1 scaffold (engine skeleton + one playable non-AI demo game) plus
Phase 2 (structured AI responses wired into the main play loop, not just
the free-text side path), plus an `emulator/` Docker Compose harness for
the real KOReader desktop emulator.

The emulator build succeeded on your machine and the plugin **loads
cleanly in real KOReader with zero Lua errors** (confirmed from
`emulator/screenshots/koreader-stdout.log`: "Plugin loaded inkrpg" / "RD
loaded plugin inkrpg at plugins/inkrpg.koplugin"). What's *not* yet
confirmed on screen is the actual play loop (menu navigation, scene
rendering, the AI turn loop) -- see `emulator/README.md` for where that
stands. See "Known gaps" below before trusting any of this.

## Try it

1. Get KOReader running. For development, the desktop emulator is much
   faster to iterate against than a physical device -- see PLAN.md
   Phase 0 for the WSL2 route on Windows, or grab a build for
   Linux/macOS/Windows from https://github.com/koreader/koreader.
2. Copy `inkrpg.koplugin/` into your KOReader install's `plugins/` folder.
3. Launch KOReader -> Tools -> inkRPG -> The Whispering Cave.
4. To try the AI hook: `cp inkrpg.koplugin/configuration.sample.lua
   inkrpg.koplugin/configuration.lua`, fill in an API key, then pick
   "...Something else" during play. (You already have Ollama installed
   locally, per your home folder -- that's a free way to test this path
   without spending API credits; point `base_url` at
   `http://localhost:11434/v1/chat/completions`.)

## Repo layout

```
inkRPG/
  PLAN.md
  README.md
  emulator/                     -- Docker Compose harness to run the real KOReader emulator (see emulator/README.md)
  inkrpg.koplugin/
    _meta.lua
    main.lua                    -- entry point, menu registration, game picker
    inkrpg_game_loader.lua      -- discovers/loads game packs from games/
    inkrpg_state.lua            -- save/load via KOReader's LuaSettings
    inkrpg_dice.lua             -- dice rolls / skill checks (unused by the demo so far)
    inkrpg_ai_provider.lua      -- OpenAI-compatible AI client (Phase 2 hook)
    inkrpg_play_screen.lua      -- the turn loop UI
    configuration.sample.lua    -- copy to configuration.lua, add your API key
    games/
      demo-cave/                -- Phase 1 reference game, no AI required
        manifest.lua
        scenes.lua
        world/intro.md
```

Module naming note: flat files prefixed `inkrpg_*` living directly in
`inkrpg.koplugin/`, rather than the `core/`/`ui/` subfolders sketched in
PLAN.md. That sketch turned out to not match how KOReader plugins
actually resolve `require()` for their own sibling files -- I checked
against two real, shipping plugins (`assistant.koplugin`, `frotz.koplugin`)
and both use flat, prefixed filenames, so this scaffold follows the
pattern that's proven to work rather than the original diagram.

## Known gaps (read before assuming this works)

- **Loads, but the play loop itself is unconfirmed on screen.** The
  plugin registers and loads with zero Lua errors in real KOReader (see
  Status above), which was cross-checked line-by-line against real
  plugins on GitHub before that. What's still unconfirmed is the actual
  UI: menu navigation, scene rendering, and the AI turn loop have only
  been exercised with `lupa` (a Python<->Lua binding) against stubbed
  KOReader widget modules, not against KOReader's real widget toolkit on
  screen. `emulator/README.md` has the current state of getting a
  screenshot of that.
- `inkrpg_ai_provider.lua` only implements the OpenAI-compatible request
  shape (works for OpenAI itself, Ollama, DeepSeek, Groq, OpenRouter,
  and similar). Native Claude Messages API / Gemini endpoints use a
  different request and response shape and need their own small handler
  -- not started.
- **Phase 2 is done in code, not yet confirmed against a live model.**
  `AIProvider.requestStructured()` asks the model for narration + choices
  + state changes (HP/flags/inventory) as JSON and `PlayScreen` applies
  them and continues the story from there (`ai_scene` in the save file
  tracks being mid-AI-improvised-scene vs. on the authored graph). Tested
  with `lupa` against canned AI replies (fence-stripping, hp clamping,
  flag/inventory adds & removes, save/resume of an in-progress AI scene,
  the AI-unavailable fallback) -- not yet tried against a real model's
  actual output, which may not follow the JSON shape as reliably as the
  canned test fixtures do.
- No in-app settings screen for provider/model/API key yet (Phase 4) --
  hand-edit `configuration.lua` for now.

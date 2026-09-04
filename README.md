# inkRPG

A single-player, AI-narrated tabletop RPG framework for KOReader.

- `PLAN.md` -- investigation + phased build plan. Read this first.
- `inkrpg.koplugin/` -- the engine: a KOReader plugin. Game-agnostic.
- `inkrpg.koplugin/games/` -- game packs (content only, no code).
  `demo-cave` is the Phase 1 reference game: fully playable with zero AI
  calls, to prove the engine loop before any AI wiring lands.

## Status

Phase 0/1 scaffold: engine skeleton plus one playable non-AI demo game.
**Not yet run against a real KOReader emulator or device** -- see
"Known gaps" below before trusting any of this.

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

- **Never executed.** This was written against KOReader's documented
  APIs and cross-checked line-by-line against real plugins on GitHub,
  but I have no way to run KOReader myself. Treat it as
  reviewed-against-source code, not tested code. The very next step
  should be getting it to load in the emulator and fixing whatever
  disagrees with the real widget toolkit.
- `inkrpg_ai_provider.lua` only implements the OpenAI-compatible request
  shape (works for OpenAI itself, Ollama, DeepSeek, Groq, OpenRouter,
  and similar). Native Claude Messages API / Gemini endpoints use a
  different request and response shape and need their own small handler
  -- that's a Phase 2 task, not started here.
- Free-text AI replies are shown raw, not parsed into structured state
  changes (HP/inventory/flags). That parsing is the rest of Phase 2.
- No in-app settings screen for provider/model/API key yet (Phase 4) --
  hand-edit `configuration.lua` for now.

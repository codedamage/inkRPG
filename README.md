# inkRPG

A single-player, AI-narrated tabletop RPG framework for KOReader.

- `PLAN.md` -- investigation + phased build plan. Read this first.
- `inkrpg.koplugin/` -- the engine: a KOReader plugin. Game-agnostic.
- `inkrpg.koplugin/games/` -- game packs (content only, no code).
  `demo-cave` is the Phase 1 reference game: fully playable with zero AI
  calls, to prove the engine loop before any AI wiring lands.

## Status

Phase 0/1 (engine skeleton + one playable non-AI demo game) is now
**fully confirmed working end to end in real KOReader, on screen, via the
emulator, start to finish**: Tools -> More tools -> inkRPG opens the game
picker ("The Whispering Cave"); selecting it plays through the entire
authored scene graph -- `cave_mouth` -> `entrance_hall` -> `crawl_space`
-> `locked_door` -> the `ending_key` ending, one screenshot per tap -- with
every narration line and choice button matching
`games/demo-cave/scenes.lua` verbatim, an ending correctly showing "THE
END" text with a "Play again" button instead of more choices, and a
completely clean log the entire way (zero Lua errors, only ordinary
first-run cache warnings) across four full runs. See `emulator/README.md`
for all the screenshots and the confirmed navigation path.

The structured-JSON half of Phase 2 is implemented but not yet exercised
this way. Not yet confirmed on screen: the "Play again" button actually
restarting; closing and reopening to confirm save/resume reloads the
right scene (KOReader's own settings dir isn't bind-mounted, so this
needs a different test setup -- see `emulator/README.md`); the
"...Something else" free-text path; and anything AI-driven (Phase 2's
`requestStructured` loop is only tested against canned fixtures via
`lupa`, not a live model or KOReader UI). See "Known gaps" below.

## Try it

1. Get KOReader running. For development, the desktop emulator is much
   faster to iterate against than a physical device -- see PLAN.md
   Phase 0 for the WSL2 route on Windows, or grab a build for
   Linux/macOS/Windows from https://github.com/koreader/koreader.
2. Copy `inkrpg.koplugin/` into your KOReader install's `plugins/` folder.
3. Launch KOReader -> Tools (wrench icon) -> More tools -> inkRPG ->
   The Whispering Cave. (Confirmed navigation path, from the emulator --
   inkRPG is grouped under KOReader's own "More tools" submenu, not a
   top-level Tools entry.)
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

- **The entire non-AI game loop is confirmed on screen, start to
  finish.** Menu navigation, the picker, every scene transition down to
  an ending, and the ending's "Play again" button all render correctly
  in real KOReader via the emulator, log clean throughout -- see Status
  above and `emulator/README.md` for every screenshot. Not yet clicked
  through: "Play again" actually restarting; closing/reopening KOReader
  to confirm save/resume reloads mid-game state (needs the settings dir
  bind-mounted, or an in-run restart -- not just re-running the
  container, which starts a fresh KOReader install every time); or the
  "...Something else" free-text path. Those are the obvious next things
  to confirm, same screenshot-driven approach.
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

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

Restart and save/resume are ALSO now confirmed: "Play again" correctly
resets to `cave_mouth`; and with `emulator/docker-compose.yml`'s new
`./saves` bind mount (onto inkRPG's real save-file path, found via a
diagnostic search rather than guessed), a save now persists ACROSS
separate `docker compose run` invocations -- selecting "The Whispering
Cave" a second time skipped straight to the previously-reached
`entrance_hall` instead of restarting at `cave_mouth`, exactly as
`inkrpg_state.lua`'s save/load is supposed to work.

One real side effect from adding that mount, since fixed in the
Dockerfile (needs a rebuild to take effect): KOReader's `settings/`
directory doesn't exist until first run, so Docker was auto-creating
the whole missing parent chain as root right before mounting onto it --
which left `settings/` root-owned and broke a few unrelated built-in
KOReader plugins (vocabbuilder, coverbrowser, statistics) trying to
create their own sqlite files there ("cantopen" in the log). Didn't
affect inkRPG itself. Fixed by pre-creating that directory tree at
image-build time, owned by the right user, so the mount just overlays
an already-correct directory.

The structured-JSON half of Phase 2 is implemented but not yet exercised
this way. Not yet confirmed on screen: the "...Something else" free-text
path, and anything AI-driven (Phase 2's `requestStructured` loop is only
tested against canned fixtures via `lupa`, not a live model or KOReader
UI). See "Known gaps" below.

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
4. To try the AI hook: Tools -> More tools -> inkRPG -> AI provider
   settings. Pick a provider preset (OpenAI, local Ollama, DeepSeek,
   Groq, OpenRouter, or Custom), enter a model name and API key, then
   "Test connection" to confirm it works -- then pick "...Something
   else" during play. (You already have Ollama installed locally, per
   your home folder -- that's a free way to test this path without
   spending API credits; the "Local Ollama" preset already points at
   `http://localhost:11434/v1/chat/completions`.) Settings are stored
   in KOReader's own settings directory on-device, not in this repo --
   `configuration.lua` (copy from `configuration.sample.lua`) still
   works as a power-user/scripting override if you'd rather hand-edit a
   file, and is only consulted when nothing has been saved through the
   settings screen.

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
    inkrpg_settings.lua         -- per-user AI provider config, stored via KOReader's LuaSettings
    inkrpg_settings_screen.lua  -- in-app settings UI (provider picker, API key, test connection)
    configuration.sample.lua    -- power-user override; copy to configuration.lua only if you'd rather hand-edit
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
  finish, including save/resume across separate runs.** Menu navigation,
  the picker, every scene transition down to an ending, "Play again"
  restarting, and a save persisting across two independent
  `docker compose run` invocations all render correctly in real KOReader
  via the emulator, log clean throughout -- see Status above and
  `emulator/README.md` for every screenshot. The AI provider settings
  screen is now confirmed on screen too (see the settings-screen entry
  below). Not yet clicked through: the "...Something else" free-text
  path itself, which needs a real, reachable AI endpoint -- the emulator
  container's "localhost" isn't the Windows host running Ollama, so
  that's the next environment wrinkle to sort out before this can be
  exercised end-to-end in the emulator (a real device wouldn't have this
  problem).
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
- **In-app settings screen for provider/model/API key is implemented
  and confirmed on screen** (Phase 4 item, done ahead of schedule):
  Tools -> More tools -> inkRPG -> AI provider settings, with a
  provider-preset picker, model/base-URL/API-key editors, a masked key
  display, and a "Test connection" button. Stored via KOReader's own
  `LuaSettings` in its settings directory, not in this repo -- see
  `inkrpg_settings.lua` / `inkrpg_settings_screen.lua`. Confirmed in the
  real emulator: the submenu, the settings menu, the 6-entry provider
  picker, picking a preset and having model/base_url auto-fill, the API
  key entry dialog, and "Test connection" all render and behave exactly
  as coded, including a clean (non-crashing) failure message when
  nothing's fully configured yet -- log stayed error-free throughout.
  One real UX rough edge this surfaced: Ollama's OpenAI-compat endpoint
  ignores the API key but the settings screen still treats an empty key
  as "not configured" and falls through to the `configuration.lua`
  check, so picking "Local Ollama" alone isn't enough -- something
  (even a throwaway value like `ollama`) has to go in the API key field
  too. Not yet fixed; worth a small UX tweak later (e.g. skip the
  empty-key requirement for presets that don't need one, or prefill a
  placeholder).

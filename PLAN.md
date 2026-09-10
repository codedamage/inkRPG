# inkRPG — an AI Dungeon Master for KOReader

Status: planning draft, 2026-09-04
Repo: `F:\PetProjects\inkRPG`

## 1. The idea, restated

A single-player, AI-narrated tabletop-RPG experience that runs *inside KOReader* — the same reading app already installed on most jailbroken Kindles, Kobos, PocketBooks and Android e-readers. Two layers, as you described:

1. **The engine** — a reusable KOReader plugin (the "game framework"). It knows how to render a turn-based narrative loop, keep game state, call out to an AI model with your own API key, and save/load a session. It knows nothing about any specific adventure.
2. **Games** — separate content packs (text/data files, no code) that plug into the engine: a world bible, a DM persona/system prompt, optional pre-authored scenes, starting stats. Anyone (you) can write a new game without touching the engine.

This document covers what already exists that we can learn from or reuse, and a concrete phased plan for building both layers.

## 2. Prior art (what I found)

Nobody has published an "AI DM on KOReader" plugin yet — this looks like a genuine gap. But two existing KOReader plugins each solve *half* the problem, and together they de-risk this a lot.

**[frotz.koplugin](https://github.com/kbarni/frotz.koplugin)** — a full interactive-fiction interpreter for KOReader. It proves the *engine* half is very doable:
- Bundles compiled interpreters (Bocfel for Z-machine, Git for Glulx) that speak a structured JSON protocol; the Lua side only handles rendering and input, decoupled from game logic.
- Ships native-feeling UI: status bar, styled text, single-key and line input, on-screen keyboard toggle, adjustable font size.
- Has save/restore slots per game, autosave, and a "resume previous session" history list — exactly the state-management shape we need.
- Distributed as a drop-in `koreader/plugins/frotz.koplugin` folder; games are separate files the interpreter loads.

This is close to a reference architecture for us, minus the AI part: decouple "game logic/state" from "KOReader rendering," talk between them with a small structured message format, ship the engine as one `.koplugin` folder, ship games as separate files it discovers.

**[assistant.koplugin](https://github.com/omer-faruq/assistant.koplugin)** (and the older, simpler [AskGPT](https://github.com/drewbaumann/AskGPT)) — an AI chat helper for KOReader, already in daily use by real users. It proves the *AI API call* half is solved:
- Makes HTTPS calls straight from KOReader's Lua runtime (KOReader ships `luasocket`/`luasec`/`ltn12`, so no native networking code is needed).
- Talks to Claude, GPT-4, Gemini, DeepSeek, Groq, NVIDIA, and local Ollama through one **OpenAI-compatible handler abstraction**, selected per-provider in a `configuration.lua` file:

  ```lua
  local CONFIGURATION = {
    provider_settings = {
      gemini = {
        model = "gemini-2.5-flash",
        base_url = "https://generativelanguage.googleapis.com/v1beta/models/",
        api_key = "your-gemini-api-key",
      },
    },
  }
  return CONFIGURATION
  ```
- Supports streaming responses (useful for perceived latency, though on e-ink a full-response render is often better — see §5).
- Renders markdown-formatted AI output in native dialog/viewer widgets.

We don't need to invent "how do I add my API key and call an LLM from KOReader" — we can lift this pattern close to verbatim, which removes most of the technical risk from the AI side.

**Not directly reusable, but useful reference points:**
- **[AI Dungeon](https://en.wikipedia.org/wiki/AI_Dungeon)** — the conceptual ancestor: freeform, AI-improvised text adventures. Good reference for prompt design and turn UX, not reusable code (closed, cloud-only, no e-ink concerns).
- **Ink** ([inkle/ink](https://github.com/inkle/ink)) / Twine / ChoiceScript — mature *authored* branching-narrative formats. Good conceptual model for node/knot-based scenes, but their runtimes are C#/JS, and there's no Lua port — porting one is more work than it saves. Better to design a small custom scene format tailored to the AI-hybrid loop (§4.2).
- KOReader itself is scriptable in **Lua**, plugins load via `pluginloader.lua`, and the [Development guide](https://koreader.rocks/doc/topics/Development_guide.md.html) documents the widget toolkit we'll build the UI from (`InputDialog`, `ButtonDialog`, `Menu`, `TextBoxWidget`, `ScrollTextWidget`, etc.) plus `LuaSettings`/`docsettings` for persisting state.
- KOReader has a **desktop emulator** (Linux/macOS natively; Windows via WSL2 — see the [build guide](https://github.com/koreader/koreader/blob/master/doc/Building.md) and this [WSL2 discussion thread](https://github.com/koreader/koreader/discussions/13856)). Since you're on Windows, this matters a lot: you can develop and iterate without touching a physical e-reader for most of the work.

## 3. What KOReader plugins can and can't do (constraints that shape the design)

- **Language**: Lua only (no JS execution). "js" content files from your brief don't run as code here — the practical equivalent is structured data (YAML/JSON) for anything the engine must parse, and plain Markdown/text for anything that's prose. I'll use "yaml/json + md" language for the rest of this doc.
- **Networking**: works fine — `assistant.koplugin` proves HTTPS calls to cloud AI APIs work from a real Kindle/Kobo over Wi-Fi. Latency and Wi-Fi reliability (many e-readers sleep their radio) are UX concerns, not blockers.
- **Rendering**: e-ink, so full-screen refreshes are slowish and flicker on the ghosting-heavy modes; the UI should favor discrete "render a screen of text, wait for one input" turns over anything animated or partial-refresh-heavy. This maps naturally onto a turn-based RPG anyway.
- **Input**: touchscreen taps for menus/choices are cheap and pleasant on e-ink; on-screen-keyboard free text entry works but is slower to use — so the loop should default to tap-a-choice, with free-text as an option, not the primary input.
- **Distribution**: a plugin is just a folder (`<name>.koplugin`) with a `main.lua`, copied into `koreader/plugins/`. No app-store gatekeeping; frotz and assistant are both distributed as GitHub release zips.

## 4. Proposed architecture

### 4.1 Engine — `inkrpg.koplugin`

A provider-agnostic, game-agnostic KOReader plugin, structured like the plugins above:

```
inkrpg.koplugin/
  main.lua                 -- entry point, registers menu under Tools
  core/
    game_loader.lua        -- discovers and parses game packs from games/
    state.lua              -- save/load session state (LuaSettings-backed JSON), autosave
    scene_graph.lua         -- interprets authored scenes (optional, see 4.2)
    ai_provider.lua         -- HTTP client + per-provider handlers (ported from assistant.koplugin's pattern)
    prompt_builder.lua      -- assembles system prompt + world context + recent history + state
    dice.lua                -- dice rolls / skill-check resolution shared across games
  ui/
    menu_screen.lua         -- game picker, save-slot picker
    play_screen.lua         -- narration box (ScrollTextWidget) + choice list (Menu) + free-text (InputDialog)
    settings_screen.lua     -- pick AI provider/model, enter API key, tune options
  configuration.sample.lua  -- API key template (never committed with real keys)
  games/                    -- drop-in content packs live here (or a configurable external path)
```

**Turn loop:**
1. Render current narration text + a list of choices (if the current scene offers any) + a "do something else" free-text option.
2. On player input, `prompt_builder` assembles a request: DM persona + condensed world-bible excerpt + character sheet/stats + last N turns + the player's action.
3. `ai_provider` sends it to whichever backend is configured (Claude, OpenAI-compatible, Gemini, or a local Ollama server on the LAN), **asking for a structured JSON reply** — narration text, a short list of next choices, and explicit state changes (HP delta, inventory add/remove, flags set) — rather than trusting free text for anything that has to stay numerically consistent.
4. Engine applies the state changes deterministically, appends to history, autosaves, re-renders.

This structured-output constraint is the one deliberate departure from "pure AI Dungeon freeform": it keeps HP/inventory/quest-flags reliable even with a cheap/small model, and it's a pattern the assistant-style plugins don't need but a *game* engine does.

**Offline/no-AI mode**: if a scene node has fully authored text and choices, the engine can render it with zero API calls. This means the engine is also useful with no API key at all (pure choice-based gamebook), and AI is used to *fill the gaps* between authored beats rather than being required for every single turn — good for cost control and for moments with no Wi-Fi.

### 4.2 Content format — game packs

Each game is a folder, data only, no Lua:

```
games/goblin-caves/
  manifest.yaml     -- title, DM persona/system prompt, tone/rating, stat schema, starting scene id
  world/*.md         -- lore, factions, locations — human-writable prose, quoted into prompts by keyword match (simple substring/tag matching is enough at this scale; no vector DB needed)
  scenes/*.yaml       -- optional authored scene graph: id, text, choices -> next scene id, triggers/state changes
  characters/*.md     -- NPC and player-character templates
```

`manifest.yaml` is the contract between a game and the engine — this is the one schema worth nailing down early and documenting, since it's what lets you (or anyone) author new games without ever opening the engine code.

### 4.3 AI provider layer

Ported near-verbatim from `assistant.koplugin`'s approach, since it's already proven on real devices: one OpenAI-compatible request/response shape, per-provider config blocks (`model`, `base_url`, `api_key`), so Claude, OpenAI, Gemini, DeepSeek, or a local Ollama endpoint are all just different config entries, not different code paths. This also means you're never locked to one AI vendor.

## 5. Design decisions worth flagging now

- **Hybrid over pure-freeform**: recommend starting with the scene-graph-optional hybrid above rather than 100% AI-improvised. It's cheaper, more reliable on a small model, and still lets you write a game that's almost entirely AI-narrated by simply authoring very few scene nodes (mostly just the starting one) and letting the AI drive the rest — the graph is a scaffold, not a cage.
- **Full-response over streaming**: e-ink screens redraw slowly and streaming token-by-token fights that; recommend rendering the complete AI response in one paint, with a lightweight "thinking…" indicator during the wait, rather than porting assistant.koplugin's streaming mode.
- **Tap-first input**: default to choice menus; free-text is available but secondary, given on-screen-keyboard entry is slower on e-ink touch panels.
- **Provider-neutral from day one**: build the handler abstraction even though you'll probably test against one provider first — it's cheap to do now and expensive to retrofit.

Open questions for you, not blocking the plan but worth deciding before Phase 2:
- Target device(s) to actually test on (Kindle/Kobo/PocketBook) vs. developing purely against the desktop emulator for now?
- Preferred first AI provider to build/test against (Claude, or an OpenAI-compatible one, or local Ollama for zero cost during development)?

## 6. Phased roadmap

**Phase 0 — environment**
Get the KOReader desktop emulator running on Windows (WSL2 route), scaffold `inkrpg.koplugin` as a "hello world" plugin per KOReader's own `plugins/hello.koplugin/main.lua` example, confirm it loads and shows up under Tools.

**Phase 1 — engine skeleton, no AI**
Build the turn-loop UI (narration box, choice menu, free-text input), the scene-graph loader, and save/load. Validate with one tiny hand-authored test game (a few scenes, no AI calls) to shake out the UI/UX on both emulator and, if available, real hardware.

**Phase 2 — AI integration**
Port the provider/handler pattern from `assistant.koplugin` for API-key config and HTTPS calls. Build `prompt_builder` and the structured-JSON response contract (narration + choices + state changes). Wire the hybrid loop: authored scenes where they exist, AI-generated continuation where they don't. Test against a cheap/free model first to iterate quickly on prompt design and latency feel.

**Phase 3 — content tooling & first real game**
Write and document the `manifest.yaml`/scene schema properly. Optionally build a small validator (a Node or Python script run on your dev machine, not on the device) to lint game packs before copying them over. Author a short real one-shot DnD adventure as the reference/example game pack. **Not started.** The schema itself only exists as `games/demo-cave/`'s worked example plus scattered code comments -- there's no `CONTENT_AUTHORING.md`-style guide a third party could follow to write their own game pack without reading the engine source. Worth doing before calling this shareable as a product: what a manifest needs (`title`, `dm_persona`, `starting_stats`, `start_scene`), the scene shape (`text`, `choices[].{label,next}`, `is_ending`, `on_enter(stats, flags)`), how `world/*.md` files relate to scenes (if at all yet), and how the AI hybrid path picks up when authored choices run out.

**Phase 4 — polish**
~~In-app settings screen for provider/model/API key (instead of hand-editing a Lua file)~~ -- **done, and now confirmed two ways**: `inkrpg_settings.lua` + `inkrpg_settings_screen.lua`, reached from Tools > More tools > inkRPG > AI provider settings, storing per-user config via KOReader's own `LuaSettings` (not in this repo); `configuration.lua` remains as a power-user override. `lupa`-tested at the code level, **and** visually confirmed end to end in the real emulator (submenu, provider picker, all editors, Test connection) -- see 6c below. `AIProvider.requestStructured()` has also now produced a real narration from a live model (Gemini), closing out Phase 2's last "not yet confirmed against a real model" gap too.

Remaining polish, roughly in priority order:
- Confirm one full successful "...Something else" round-trip that actually renders `renderAiScene()`'s output (real narration *and* clickable AI-generated choice buttons) -- every piece works individually (see 6c) but a transient `503` cut the last run short of seeing the fully-rendered result.
- A small retry-with-backoff around `AIProvider.request()` for transient HTTP failures (502/503/429) -- free-tier model endpoints hit these under load; not urgent, but a real-world rough edge now confirmed to happen, not hypothetical.
- The Ollama preset's empty-API-key UX gap (Ollama ignores the key entirely, but an empty key is still treated as "not configured") -- skip the empty-key requirement for presets that don't need one, or prefill a non-secret placeholder.
- A player-visible character/inventory screen. HP, `max_hp`, and `inventory` are already tracked in `self.stats` and fed into the AI's context (`buildContext()`), but there is currently **no UI for the player to see their own stats or inventory** -- it only surfaces if the narration happens to mention it. Worth its own menu entry (a read-only `TextViewer` off `PlayScreen` would do it cheaply).
- Multiple save slots with a picker, graceful handling of dropped Wi-Fi mid-turn, a rough token/cost estimate shown to the player, respecting KOReader's global font-size settings automatically (comes free from using its native widgets).
- A real e-reader test. Everything so far is confirmed on the desktop Docker/Xvfb emulator only -- e-ink refresh behavior, touch-input feel, and real Wi-Fi latency haven't been tried on actual hardware.
- No installer/release-zip flow yet -- "copy the folder into `plugins/`" is fine for personal use but is real friction for anyone else trying this.

**Phase 5 — stretch goals**
Local-LLM support via Ollama on the same network for zero-cost play (the provider layer already supports this shape -- confirmed reachable from the emulator via `host.docker.internal` given `OLLAMA_HOST=0.0.0.0`, just blocked on a real request by the "custom preset" UI flow, not a fundamental limit); a small reusable combat/skill-check resolver module shared across game packs (`inkrpg_dice.lua` already exists but nothing calls it yet); a "game pack" sharing/install flow modeled on `appstore.koplugin`'s community-plugin browser.

Bigger RPG-system ideas, not yet designed:
- **A character sheet portable across games/worlds.** Right now a character is 100% per-game: `starting_stats` comes from each game's own `manifest.lua`, and saves are keyed `<game_slug>_<slot>.lua` (`inkrpg_state.lua`) -- nothing persists between two different game packs. A shared "player" concept (name, a portrait/description, maybe a running log of past adventures) that a new game pack can optionally read from, separate from that game's own mechanical `starting_stats`, would need: its own storage (a `data/character.lua`-style `LuaSettings` file, game-pack-agnostic), a UI to view/edit it, and a manifest-level opt-in (a game pack shouldn't be forced to honor a foreign character's stats if its whole design assumes a fixed starting point).
- **A real inventory system**, beyond the current flat add/remove-by-name list: item descriptions, quantities (right now picking up "torch" twice just silently no-ops via the dedup check in `applyStateChanges`), maybe equip slots or item-triggered `on_use` effects a scene/AI could reference.
- **Other RPG elements worth considering**: a proper skill-check/dice resolver actually wired into the AI loop (the system prompt already tells the model "never resolve combat without a dice roll" but nothing enforces or even rolls anything server-side -- it's an honor system the model may or may not follow); a simple leveling/XP track; multiple NPCs/companions with their own mini stat blocks the AI can reference consistently across a session.

## 6a. Phase 0 progress (2026-09-04)

Attempted Phase 0 from a sandboxed cloud container, to hand over
something already working rather than untested instructions. Result,
in short: got the toolchain and clone fully working, found and fixed a
real bug, then hit a wall specific to that sandbox's network policy
before the compile could finish. Full writeup in `emulator/README.md`;
the short version:

- `koreader/koappimage` (KOReader's own CI build image) pulls fine and
  has the right toolchain.
- `git clone --recursive https://github.com/koreader/koreader.git`
  completes in full (~2.7 GB checked out).
- `./kodev build` / `./kodev run` are the confirmed correct commands.
- Found a real, worth-knowing bug: `wget` doesn't pick up a system CA
  trust store automatically even after `update-ca-certificates` --
  needs `ca_certificate = /etc/ssl/certs/ca-certificates.crt` added to
  `/etc/wgetrc` explicitly. Only matters if you're behind a
  TLS-intercepting proxy.
- Blocked at the actual compile: KOReader's build fetches ~40 vendored
  thirdparty libraries as tarballs from `github.com/.../archive/...`
  and `github.com/.../releases/download/...`. My cloud sandbox's
  outbound network policy returns `403 Forbidden` for those specific
  endpoints while still allowing plain `git clone` and
  `raw.githubusercontent.com`. That's my hosted environment's egress
  allowlist, not a problem with the Dockerfile or a normal internet
  connection.

The `emulator/` folder has a ready-to-run Docker Compose setup encoding
everything confirmed above. Running `docker compose build` from a normal
network (yours) should get further than I could and produce an actual
running emulator with `inkrpg.koplugin` loaded.

## 6b. Phase 1/2 progress (2026-09-05)

Phase 1 (engine skeleton, no AI) and the structured-JSON half of Phase 2
are both implemented in `inkrpg.koplugin/` -- not just planned.

**Phase 1**, verified with `lupa` (a Python<->Lua binding, used to
syntax-check and execute the real Lua source against stubbed KOReader
modules, since no live KOReader was available at the time): the game
loader discovers `demo-cave` and loads all 8 of its scenes correctly, the
scene graph has no dangling `choices[].next` references and every scene
is reachable from `start_scene`, and a full sample playthrough completes.
**Since then**, the emulator build succeeded on your machine and the real
KOReader log confirms the plugin loads with zero Lua errors -- see
`emulator/README.md`.

**Phase 2** (structured JSON AI responses, wired into the *main* play
loop rather than only the free-text side path): `AIProvider.requestStructured()`
wraps the raw chat call with an instruction constraining the model to
`{narration, choices:[{label,id}], state_changes:{hp_delta, flags_set,
items_add, items_remove}}`, defensively slicing out the JSON if a model
adds a code fence or preamble despite being told not to. `PlayScreen` applies
`state_changes` (HP clamped to `[0, max_hp]`, flags, inventory
add/remove) and tracks `ai_scene` -- the current AI-improvised node --
separately from the authored `scene_id`, so a player who goes off-script
via "...Something else" stays in AI-driven territory (each of the AI's
own choices is sent back to it) until they restart, and it survives
save/resume. Verified with `lupa` against canned AI replies covering:
fence/preamble stripping, hp clamping at both ends, flag/inventory
adds and removes, ai_scene save-then-resume, chained AI choices, and the
no-provider-configured fallback. One real bug caught and fixed by this
testing: `starting_stats` was being aliased (not copied) into `self.stats`,
so combat damage taken in one playthrough would silently persist as the
new "fresh start" HP for every future restart.

Not yet done: this has never been tried against a real model's actual
output (only canned fixtures), and the on-screen play loop (menu
navigation, scene rendering) hasn't been visually confirmed in the
emulator yet -- see `emulator/README.md`.

## 6c. Settings screen + live-model confirmation (2026-09-09)

Two things landed this session, both fully confirmed on screen in the
real emulator (not just `lupa`-tested), and they close out two items
this doc had flagged as open (Phase 4's settings screen, and Phase 2's
"not yet tried against a real model" gap):

**In-app AI provider settings** (`inkrpg_settings.lua` +
`inkrpg_settings_screen.lua`, reached from Tools > More tools > inkRPG >
AI provider settings): a provider-preset picker (OpenAI / Local Ollama /
DeepSeek / Groq / OpenRouter / Custom), Model/Base URL/API-key editors,
a masked key display, and a Test connection button, storing per-user
config via KOReader's own `LuaSettings` -- nothing AI-credential-related
lives in this git checkout. `inkrpg_ai_provider.lua` checks this store
first and falls back to `configuration.lua` (still gitignored) only if
nothing's been saved through the UI. Confirmed on screen across several
rounds: the submenu, every editor (including a first successful use of
`xdotool type` to drive KOReader's `InputDialog` from this test harness,
not just taps), the provider picker, and Test connection's own failure
path all render and behave exactly as coded, zero Lua errors throughout.

**A real model's actual output, end to end**, using a Gemini key the
user created for this purpose, via Gemini's OpenAI-compatible endpoint
(`generativelanguage.googleapis.com/v1beta/openai/...` -- same
Bearer-auth, same request shape `inkrpg_ai_provider.lua` already spoke,
so no native Gemini handler was needed) set in `configuration.lua`
directly by the user's own hand -- entering API keys/credentials isn't
something this assistant does itself, even at the user's request, so the
settings-screen-typing path built for this was set aside in favor of the
user adding the key to a file themselves. Getting a real reply back
surfaced three genuine, previously-hypothetical risks, each fixed in
turn:
- A deprecated model name (`gemini-2.5-flash` → `404`) -- Google's own
  error message named the current replacement directly.
- `REQUEST_BLOCK_TIMEOUT` (10s) was tuned for a fast rejection, not real
  inference time -- a working model actually composing a reply hit a
  `wantread` (LuaSec read-timeout) failure at exactly 10s. Raised to 30s.
- The model ignored the "respond with ONLY JSON" prompt instruction and
  replied with plain atmospheric prose instead (genuinely good DM
  narration, just not JSON) -- fixed by adding `response_format:
  {type="json_object"}` to structured requests, the standard
  OpenAI-compatible-API way to force strict JSON rather than trusting
  prompt wording alone.

After that fix, the next run hit a transient `503` ("high demand")
straight from Google before generating anything -- not a bug, free-tier
capacity limiting. So: every individual piece (config resolution,
network reachability, auth, timeout, JSON-mode enforcement, and a real
model actually producing narration) is now confirmed working, but a
single successful run all the way through to `renderAiScene()` actually
drawing the AI's choices as buttons hasn't landed yet, purely due to bad
luck on timing across two separate transient failures. The next attempt
should close this out.

## 7. Suggested next step

Phase 0 and Phase 1 are done and confirmed (see 6a/6b). Phase 2's core
mechanic and Phase 4's settings screen are both implemented and
confirmed on screen (see 6c) -- the one loose thread is re-running the
"...Something else" path once more to see a full AI turn render with
real choice buttons, not just narration text (likely to just work on a
retry, per 6c). Past that, the two most product-shaping open items are:
Phase 3 (there's still only one hand-authored demo game, and no
authoring guide for anyone but the original developer to write another
one) and the player-visible stats/inventory screen called out in Phase
4's polish list (the data's already tracked, it's just invisible to the
player today).

---
Sources consulted: [frotz.koplugin](https://github.com/kbarni/frotz.koplugin) · [assistant.koplugin](https://github.com/omer-faruq/assistant.koplugin) · [AskGPT](https://github.com/drewbaumann/AskGPT) · [KOReader Development guide](https://koreader.rocks/doc/topics/Development_guide.md.html) · [KOReader Building guide](https://github.com/koreader/koreader/blob/master/doc/Building.md) · [KOReader WSL2 discussion](https://github.com/koreader/koreader/discussions/13856) · [koreader/koreader](https://github.com/koreader/koreader) · [appstore.koplugin](https://github.com/omer-faruq/appstore.koplugin) · [AI Dungeon](https://en.wikipedia.org/wiki/AI_Dungeon) · [inkle/ink](https://github.com/inkle/ink)

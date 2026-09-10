#!/bin/bash
# Launches the KOReader emulator under a virtual display, walks toward
# Tools > inkRPG, and saves a screenshot after each step to
# /home/ko/screenshots.
#
# ROUND 2 (05 Sep 2026) -- based on real output from round 1:
#   - The plugin loads cleanly: koreader-stdout.log shows
#     "Plugin loaded inkrpg" / "RD loaded plugin inkrpg at
#     plugins/inkrpg.koplugin" with no error. Good sign.
#   - KOReader's first launch opens straight into its bundled
#     "Quickstart Guide" document (ReaderUI), NOT the file manager --
#     my round-1 assumption was wrong, hence the wasted taps.
#   - The actual content is rendered at 540x720 (per the log's "region
#     0 0 540 720"), letterboxed inside the 768x1024 Xvfb screen. From
#     01-startup.png the white page area visually starts at roughly
#     x=115,y=150 and is 540 wide x 720 tall -- i.e. content spans
#     x:[115,655], y:[150,870]. All coordinates below are computed from
#     that box, not screen absolutes.
#
# ROUND 3 (05 Sep 2026) -- based on real output from round 2:
#   - The top-center tap worked exactly as hoped: 02-top-menu.png shows
#     the real top menu bar's icon row (bookmark / TOC-list / gear /
#     wrench / search / file-drawer / hamburger), with the leftmost
#     (bookmark/navigation) tab's panel open by default -- that's
#     KOReader's own default, not something we tapped into.
#   - Measured the wrench (Tools) icon's center directly from a 2x crop
#     of that screenshot: original-image coordinates (348, 172). The
#     icon row sits at CONTENT_TOP+~22 (150+22=172), consistent with the
#     TOPMENU_Y=190 tap having landed just below the icon row and still
#     opened the menu -- so 172 is the more precise y for tapping an
#     icon squarely, not just anywhere in the bar.
#
# This round adds ONE new step: tap the Tools/wrench icon and screenshot
# whatever tab content that reveals. Once we can see the Tools panel
# (which should include a "More tools" section -- inkRPG registers with
# sorting_hint="more_tools"), the final tap onto "inkRPG" itself can be
# aimed precisely instead of guessed, same incremental approach as round 2.
#
# ROUND 4 (05 Sep 2026) -- based on real output from round 3:
#   - The wrench tap worked: 03-tools-tab.png shows the Tools tab
#     selected (highlighted in the icon row) with its own paginated
#     item list -- "Page 1 of 2": Read timer, Calibre, Export
#     highlights and notes, Reading statistics, Progress sync, Cloud
#     storage, Move to archive, Wallabag, News downloader, Text editor.
#     inkRPG isn't on this page -- KOReader alphabetizes/groups plugin
#     menu items and ours (sorting_hint="more_tools") is landing on
#     page 2.
#   - Measured the next-page ">" arrow from a 3x crop of the
#     "Page 1 of 2" pager row: original-image coordinates (462, 680).
#
# This round adds ONE new step: tap the next-page arrow and screenshot
# page 2, which should finally show the inkRPG entry itself.
#
# ROUND 5 (05 Sep 2026) -- based on real output from round 4:
#   - The next-page tap worked: 04-tools-page2.png shows page 2 of the
#     Tools tab -- Profiles, QR from clipboard, and "More tools ▸".
#     inkRPG isn't listed directly either -- it's one level deeper,
#     inside that "More tools" submenu (matches sorting_hint=
#     "more_tools" in main.lua: that hint puts our menu item inside
#     KOReader's own catch-all "More tools" submenu, not as a top-level
#     Tools entry).
#   - Measured "More tools ▸"'s row from a 3x crop: original-image
#     coordinates (196, 313).
#
# This round adds ONE new step: tap "More tools" and screenshot whatever
# submenu that opens -- inkRPG should finally be visible in it.
#
# ROUND 6 (05 Sep 2026) -- based on real output from round 5:
#   - The "More tools" tap worked: 05-more-tools.png shows that submenu's
#     items (Battery statistics, Book shortcuts, Keep alive, Tweak
#     document settings, Terminal emulator, Plugin management, KOReader
#     HTTP inspector) and, at the bottom, "inkRPG" -- with no ▸ arrow,
#     meaning it's a direct action (main.lua's Dispatcher-registered menu
#     item), not another submenu. This is the one we want.
#   - Measured its row from a 3x crop: original-image coordinates
#     (169, 543).
#   - Log is still clean -- only ordinary first-run cache/settings
#     warnings, no Lua errors.
#
# This round adds the actual payoff step: tap "inkRPG" itself. Per
# main.lua, this should open a game-picker Menu listing the one
# registered game (games/demo-cave, "The Whispering Cave") -- selecting
# it should hand off to PlayScreen:start() and render the first scene.
#
# ROUND 7 (05 Sep 2026) -- based on real output from round 6:
#   - Full payoff, confirmed on screen in real KOReader: 06 shows the
#     game picker ("inkRPG -- choose a game" / "The Whispering Cave"),
#     and round 6's blind guess at the first list entry (07) actually
#     landed and opened the game -- rendering the exact cave_mouth scene
#     text and both choice buttons ("Light a torch and go in", "Walk
#     away", plus "...Something else") verbatim from
#     games/demo-cave/scenes.lua. Log stayed clean the whole run (only
#     ordinary first-run cache warnings, zero Lua errors) all the way to
#     a clean shutdown.
#   - Measured the "Light a torch and go in" button's row from a 2x crop
#     of 07-game-selected.png: y ~752 (x can be content-center, since
#     buttons span the full content width).
#
# This round adds ONE new step: tap that first choice button. Per
# scenes.lua, this should advance to `entrance_hall` -- confirming the
# save/goTo/render loop (not just the initial render) actually works on
# screen, not just in the lupa-stubbed tests.
#
# ROUND 8 (05 Sep 2026) -- based on real output from round 7:
#   - Confirmed exactly as predicted: 08-entrance-hall.png shows
#     entrance_hall's narration and both its choices, log still
#     completely clean across two full runs now. The goTo/save/render
#     loop -- not just the initial render -- works on screen.
#   - Noted in passing: KOReader's own settings dir lives inside the
#     container, NOT bind-mounted (only inkrpg.koplugin/screenshot.sh/
#     screenshots/ are), so every `docker compose run` starts a
#     genuinely fresh KOReader install -- no save/resume persists
#     *across* separate runs. Testing save/resume for real will need a
#     different approach (kill+restart kodev within one run, or
#     bind-mounting the settings dir) -- not attempted yet, flagged for
#     later rather than blocking this round.
#   - Button-row geometry, inferred from both cave_mouth and
#     entrance_hall having identical 3-row layouts (2 choices +
#     "...Something else") at the same y positions regardless of label
#     text: rows are bottom-anchored at a fixed spacing (~752, ~795,
#     ~838), not positioned relative to narration length. This lets the
#     next few taps be predicted rather than measured fresh each time --
#     unverified until this round's screenshots confirm it, so this
#     chains three taps and captures a screenshot after each rather than
#     assuming success and skipping straight to the end.
#
# This round chases an ending down the shortest path (cave_mouth ->
# entrance_hall ALREADY reached by round 7's step above; now:
# entrance_hall -> narrow crawl -> crawl_space -> its one choice ->
# locked_door -> "Try the iron key" -> ending_key). crawl_space has only
# 1 choice + "...Something else" (2 rows total, not 3) -- if the
# bottom-anchoring theory holds, its one choice lands at the predicted
# "middle" row position (~795) rather than the "top" row (~752) a
# 3-row scene would use. locked_door has 2 choices again (3-row layout,
# same as before), so its first choice is back at ~752.
#
# ROUND 9 (05 Sep 2026) -- based on real output from round 8:
#   - Every guess landed exactly right. 09-crawl-space.png confirmed the
#     bottom-anchoring theory for a 2-row layout (the one real choice at
#     row 2, ~795), 10-locked-door.png confirmed the 3-row layout
#     returning for a 2-choice scene, and 11-ending.png shows ending_key's
#     "THE END" text with a single "Play again" button at row 3 (~838,
#     measured directly from a crop -- matches the theory exactly). Log
#     stayed completely clean across all four runs so far, clean shutdown
#     every time. This is the ENTIRE non-AI game loop confirmed working,
#     start to finish, in real KOReader.
#
# This round does two things:
#   1. Taps "Play again" (row 3, ~838) to confirm restart actually
#      works, i.e. PlayScreen:restart() resets scene/stats/flags and
#      re-renders cave_mouth rather than erroring or getting stuck.
#   2. Adds a diagnostic `find` for inkRPG's actual save-file path
#      (State.open() resolves it via KOReader's DataStorage:
#      getSettingsDir(), which hasn't been directly observed yet --
#      only inferred from relative "./settings/..." log lines). This is
#      NOT a guess used to configure anything yet -- it just locates the
#      real path so a docker-compose volume mount can be added correctly
#      next round, to let a save actually persist *across* separate
#      `docker compose run` invocations (right now nothing does, since
#      only inkrpg.koplugin/screenshot.sh/screenshots/ are bind-mounted).
#
# ROUND 10 (05 Sep 2026) -- based on real output from round 9:
#   - Restart confirmed: 12-play-again.png shows cave_mouth's opening
#     text and all three original buttons again, exactly as a fresh
#     start would. Log stayed clean through a fifth full run.
#   - inkrpg-save-search.txt found the real path:
#     /home/ko/koreader/koreader-emulator-x86_64-linux-gnu-debug/koreader/settings/inkrpg
#     (nested under the emulator's own build-output dir, not the simple
#     "./settings/inkrpg" the log's relative paths suggested). Added
#     that as a docker-compose.yml volume mount (./saves on the host)
#     so a save now persists ACROSS separate `docker compose run`
#     invocations, not just within one -- the diagnostic `find` is
#     removed below since it already did its job.
#   - Important: this round's last action can't be the "Play again"
#     restart from round 9, because PlayScreen:restart() itself saves
#     scene="cave_mouth" -- that's indistinguishable from a fresh save
#     file, so it wouldn't prove anything about resume. Instead this
#     round moves forward into entrance_hall ONE more time after the
#     restart and stops there, so the persisted save is clearly
#     different from a fresh start (scene="entrance_hall", not
#     "cave_mouth").
#
# This round adds ONE step (advance into entrance_hall again, then
# stop) and removes the now-unneeded diagnostic. The actual resume test
# is: run this exact script a SECOND time after this one -- if
# save/resume works, that second run's "07-game-selected.png" should
# show entrance_hall's text directly (since PlayScreen:start() reads
# the persisted scene_id), not cave_mouth's opening text, even though
# nothing in the script changed to request that.
#
# ROUND 11 (07 Sep 2026) -- main.lua changed since round 10: the flat
# "inkRPG" entry inside "More tools" (confirmed with NO ▸ arrow in round
# 6 -- a direct action) is now a submenu (sub_item_table with "Play" and
# "AI provider settings"), added to build the new in-app AI provider
# settings screen (inkrpg_settings.lua / inkrpg_settings_screen.lua) the
# user asked for, so credentials are a per-user runtime setting instead
# of a hand-edited configuration.lua in the codebase. That means
# tapping INKRPG_X/INKRPG_Y (still the same row inside "More tools" --
# that part of the tree is unchanged) now opens a small 2-item submenu
# instead of the game picker directly, and everything downstream of
# that tap in rounds 6-10 no longer applies as written.
#
# The already-recorded rounds above fully confirmed the non-AI game
# loop end-to-end under the OLD flat-menu shape, so this round does not
# repeat that walk -- it focuses on the new, not-yet-confirmed-on-screen
# part: the inkRPG submenu itself, and the AI provider settings screen
# reached from it. Steps, chained same as previous rounds (screenshot
# after each so a wrong guess is caught immediately rather than
# compounding):
#   1. Tap INKRPG_X/INKRPG_Y (unchanged from round 6) -- should now
#      reveal the 2-item "Play" / "AI provider settings" submenu instead
#      of the old game picker.
#   2. Tap the second row of that submenu ("AI provider settings").
#      Position is an informed guess, not yet measured: the one other
#      small Menu seen so far (the 1-item game picker) had its first row
#      at CONTENT_TOP+60 -- reused here as SUBMENU_ROW1_Y, with
#      SUBMENU_ROW2_Y one row-height (~40px, the smallest spacing seen
#      between adjacent list rows elsewhere in this script) below that.
#      Should open inkrpg_settings_screen.lua's menu: "Provider: not
#      set", "Model: not set", "API key: not set", "Test connection"
#      (no "Base URL" row yet -- that only appears once a "custom"
#      preset is chosen, per the screen's own logic).
#   3. Tap that settings menu's first row ("Provider: not set") --
#      SETTINGS_ROW1_Y, same CONTENT_TOP+60 guess as any first row.
#      Should open the provider picker (openai / ollama / deepseek /
#      groq / openrouter / custom).
#   4. Tap the picker's second entry ("Local Ollama") -- picking Ollama
#      specifically because it's already installed and running locally,
#      so "Test connection" afterward has a real chance of succeeding
#      without spending API credits on a hosted provider. Position:
#      SETTINGS_ROW1_Y (first row) + one row height for the 2nd entry =
#      PICKER_ROW2_Y. Should return to the settings menu, now showing
#      "Provider: Local Ollama" and "Model: llama3.1" (pickProvider()
#      fills in the preset's default_model automatically).
#   5. Tap "Test connection", now the 3rd row of the settings menu since
#      picking a provider didn't add a Base URL row (only "custom"
#      does) -- SETTINGS_ROW3_Y, one more row-height down from
#      SETTINGS_ROW1_Y+SETTINGS_ROW2_Y spacing. Expect an "InfoMessage"
#      overlay first reading "Testing connection...", then either a
#      success or failure message -- likely failure, since the
#      container's "localhost" is its own network namespace, not the
#      Windows host running Ollama (would need host.docker.internal or
#      --network=host to actually reach it) -- but the POINT of this
#      round is confirming the button/flow renders and completes
#      without a Lua error, not that the live HTTP call succeeds.
#
# ROUND 12 (07 Sep 2026) -- based on real output from round 11:
#   - Everything through the provider-picker round-trip confirmed exactly
#     as coded: 06-inkrpg-submenu.png showed the new "Play"/"AI provider
#     settings" submenu (rendered as KOReader's own inline touch-menu
#     dropdown, not a full popup -- different chrome than the other
#     Menu:new{} screens in this plugin, but functionally the same), 07
#     showed inkrpg_settings_screen.lua's menu with all rows "not set",
#     08 showed the 6-entry provider picker verbatim, and 09 confirmed
#     picking "Local Ollama" returns to the settings menu with "Provider:
#     Local Ollama" / "Model: llama3.1" auto-filled by pickProvider()'s
#     default_model logic. Log stayed completely clean (zero Lua errors,
#     zero "cantopen" -- the Dockerfile fix from the previous round is
#     confirmed working now too).
#   - SETTINGS_ROW3_Y's guess (290) landed one row short, on "API key"
#     instead of "Test connection" -- which incidentally confirmed that
#     row's InputDialog too (10/11 both show the "API key" InputDialog,
#     password field + Show password checkbox + Cancel/Save, exactly as
#     editApiKey() builds it). Corrected above from a real crop
#     measurement (346, not 290).
#   - Caveat worth flagging, not yet acted on: inkrpg_settings.lua saves
#     to DataStorage:getSettingsDir().."/inkrpg_settings.lua", a flat
#     file in the settings dir root -- NOT inside the "settings/inkrpg"
#     subfolder that docker-compose.yml bind-mounts for save-game
#     persistence. So unlike game saves, AI provider settings picked in
#     one `docker compose run` do NOT persist into the next one; this
#     run's "Local Ollama" pick will be gone on the next fresh run. Not a
#     bug in the plugin itself (real installs keep one persistent
#     settings dir), just a gap in this emulator harness -- worth a
#     dedicated volume mount later if testing settings persistence
#     across runs matters, not addressed this round.
#
# This round only changes the SETTINGS_ROW3_Y constant above -- the step
# sequence is unchanged, so this run should reach "Test connection" for
# real this time and show its actual result (success or a clean failure
# message) in 10/11 instead of the API key dialog again.
#
# ROUND 13 (07 Sep 2026) -- goal: get an actual real-model reply through
# AIProvider.requestStructured(), not just confirm the settings UI. Round
# 12 confirmed "Test connection" fails cleanly against "Local Ollama"
# with no API key set (expected -- an empty key is treated as
# unconfigured even though Ollama itself ignores it). Two real blockers
# stood between that and a live reply, checked directly rather than
# guessed at:
#   1. Container -> Windows-host networking: confirmed host.docker.internal
#      DOES resolve to the host's real IP from inside this environment,
#      but Ollama's default bind (127.0.0.1 only) refuses the connection
#      regardless of DNS working -- confirmed via a direct curl, not
#      assumed. docker-compose.yml now sets extra_hosts for
#      host.docker.internal reliability, but the actual fix has to happen
#      on the Windows side: Ollama needs to be started with
#      OLLAMA_HOST=0.0.0.0 (restart the Ollama app/service after setting
#      that env var) so it accepts connections from outside 127.0.0.1,
#      the container included. This script can't do that part -- it's a
#      host-machine config change, done before running this round.
#   2. Typing a real credential into the emulator: not attempted, on
#      purpose -- entering API keys/credentials isn't something this
#      assistant does even at the user's request. Ollama's OpenAI-compat
#      endpoint ignores the key entirely, so this round uses "ollama" as
#      the API key value -- a non-secret placeholder already documented
#      in configuration.sample.lua for exactly this case, not a real
#      credential.
#
# This round switches the picked preset from "Local Ollama" (whose
# base_url is hardcoded to http://localhost:11434/... -- localhost
# *inside the container*, unreachable no matter what) to "Custom", which
# exposes an editable Base URL row, and types
# http://host.docker.internal:11434/v1/chat/completions into it. It also
# types a model name ("llama3.1", this project's existing default guess
# everywhere else -- adjust and re-run if a different model is actually
# pulled) since "Custom" has no default_model to auto-fill.
#
# New mechanism, not used anywhere earlier in this script: typing actual
# text into an InputDialog via `xdotool type`, rather than only taps.
# Untested until this round confirms it -- KOReader's InputDialog calls
# :onShowKeyboard() which may rely on tapping its own on-screen keyboard
# rather than accepting raw X11 key events, in which case `xdotool type`
# will silently do nothing and the field will stay empty. Screenshotting
# after each typed field (not just at the end) so that failure mode is
# caught at the first field, not discovered three fields later.
#
# Row/button geometry for the 5-row "Custom" settings menu (Provider /
# Model / Base URL / API key / Test connection) and the Save button on
# each InputDialog are extrapolated from the confirmed 4-row spacing
# (SETTINGS_ROW1_Y=210 confirmed correct, SETTINGS_ROW3_Y=346 confirmed
# correct -- both round 12 results -- giving ~45px/row) and from the
# general InputDialog layout glimpsed in round 11's accidental API-key
# dialog screenshot (title bar, input box, buttons row). Marked as
# guesses below; this round's screenshots will confirm or correct them.
#
# ROUND 14 (07 Sep 2026) -- round 13 confirmed the two real unknowns
# (picking "Custom" reveals the Base URL row exactly as coded; `xdotool
# type` DOES reach KOReader's InputDialog and typed "llama3.1" correctly)
# but the Save button's y was off by ~20px, so the Model dialog never
# closed and every step after that landed on the wrong screen (see the
# DIALOG_BUTTONS_Y comment above for the measured fix). Log stayed
# completely clean throughout -- this was a tap-coordinate miss, not a
# code bug. Step sequence is otherwise unchanged; this round should now
# get all the way through Model -> Base URL -> API key -> Test connection
# for real.
#
# ROUND 15 (07 Sep 2026) -- changed vector before round 14 ever ran: the
# user got a real Gemini API key specifically to test the live AI path,
# and asked to test it. This assistant does not type API keys/credentials
# into anything itself -- not the emulator, not a config file -- even
# when the user supplies the value and asks directly; that's a hard rule,
# not a judgment call made per-request. So the Ollama/Custom-preset/
# settings-screen-typing path rounds 13-14 were building is shelved for
# now (the mechanism it proved -- `xdotool type` reaching an InputDialog
# -- carries forward to this round instead).
#
# The much simpler alternative: configuration.lua (inkrpg_ai_provider.lua's
# power-user fallback, see its header comment) lives inside
# inkrpg.koplugin/, which is already bind-mounted whole into the
# container by docker-compose.yml. So if the user creates that file
# THEMSELVES, on their own machine, with their own key pasted in by their
# own hand, it's simply *there* the next time this script runs -- no
# typing-into-the-emulator step needed at all, and this assistant never
# touches the actual secret. Confirmed via ai.google.dev/gemini-api/docs/openai
# before suggesting it: Gemini's OpenAI-compatible endpoint
# (https://generativelanguage.googleapis.com/v1beta/openai/chat/completions,
# Bearer-token auth) matches inkrpg_ai_provider.lua's existing OpenAI-style
# request shape exactly, so no native Gemini handler is needed for this
# test -- configuration.lua just needs provider="gemini" pointed at that
# base_url or the same via the "Custom" preset in the settings screen).
#
# This round replaces the settings-screen walk (steps 07+) with the
# actually-intended payoff: More tools > inkRPG > Play (not "AI provider
# settings") > the demo game > "...Something else" > type a free action >
# see whether a real model's reply survives extract_json() and
# AIProvider.requestStructured()'s parsing, same as canned lupa fixtures
# tested but a live model never has. Reuses the `xdotool type` mechanism
# round 13 already proved works, and the ROW3_Y button-row geometry
# rounds 7-10 already confirmed for cave_mouth's "...Something else".
set -e

mkdir -p /home/ko/screenshots
export DISPLAY=:99

# Content box, from visual inspection of round 1's screenshots.
CONTENT_LEFT=115
CONTENT_TOP=150
CONTENT_W=540
CONTENT_H=720
CONTENT_CENTER_X=$((CONTENT_LEFT + CONTENT_W / 2))

# Tools (wrench) icon center, measured from round 2's 02-top-menu.png.
TOOLS_ICON_X=348
TOOLS_ICON_Y=172

# Tools-tab pager's next-page ">" arrow, measured from round 3's
# 03-tools-tab.png.
NEXT_PAGE_X=462
NEXT_PAGE_Y=680

# "More tools ▸" row, measured from round 4's 04-tools-page2.png.
MORE_TOOLS_X=196
MORE_TOOLS_Y=313

# "inkRPG" row itself, measured from round 5's 05-more-tools.png.
INKRPG_X=169
INKRPG_Y=543

# Button-row y positions, measured/inferred from rounds 6-7 (cave_mouth
# and entrance_hall both laid out 2 choices + "...Something else" at
# these same three rows). Buttons span the full content width, so x can
# always be the content box's center. Not used by round 11's new steps
# below (those stop before reaching the play screen) -- kept here since
# they document confirmed geometry other rounds may reuse later.
ROW1_Y=752
ROW2_Y=795
ROW3_Y=838

# Round 11: the inkRPG submenu / settings-screen rows haven't been
# measured from a real screenshot yet -- these are the informed guesses
# described in the ROUND 11 comment above, kept as named constants so a
# wrong guess is easy to correct in one place next round.
SUBMENU_ROW1_Y=$((CONTENT_TOP + 60))
SUBMENU_ROW2_Y=$((SUBMENU_ROW1_Y + 40))
SETTINGS_ROW1_Y=$((CONTENT_TOP + 60))
# Round 11 result: the SETTINGS_ROW3_Y guess (SETTINGS_ROW1_Y+80=290) was
# one row short -- it landed on "API key" (which still usefully confirmed
# that row's InputDialog renders correctly, password field and all) not
# "Test connection". Measured directly from a 2x crop of round 11's
# 07-ai-settings.png: the 4 rows (Provider/Model/API key/Test connection)
# run from y~210 with separators at 190/232/280/325/368 (crop-local before
# the +190 offset, i.e. absolute), putting "Test connection"'s row center
# at 346, not 290 -- corrected below.
SETTINGS_ROW3_Y=346
PICKER_ROW2_Y=$((CONTENT_TOP + 60 + 40))

# Round 13: "Custom" is the picker's 6th (last) entry -- same ~45px
# spacing as the other 5 confirmed entries, extrapolated from
# PICKER_ROW2_Y (Local Ollama, row 2) + 4 more rows.
PICKER_ROW_SPACING=45
PICKER_ROW6_Y=$((PICKER_ROW2_Y + 4 * PICKER_ROW_SPACING))

# Round 13: the settings menu grows a "Base URL" row once "Custom" is
# picked, inserted between Model and API key -- 5 rows total instead of
# 4. Extrapolated from the same confirmed ~45px spacing (SETTINGS_ROW1_Y
# and SETTINGS_ROW3_Y above are real, round-12-confirmed anchors).
SETTINGS5_ROW_SPACING=45
SETTINGS5_PROVIDER_Y=$SETTINGS_ROW1_Y
SETTINGS5_MODEL_Y=$((SETTINGS_ROW1_Y + SETTINGS5_ROW_SPACING))
SETTINGS5_BASEURL_Y=$((SETTINGS_ROW1_Y + 2 * SETTINGS5_ROW_SPACING))
SETTINGS5_APIKEY_Y=$((SETTINGS_ROW1_Y + 3 * SETTINGS5_ROW_SPACING))
SETTINGS5_TESTCONN_Y=$((SETTINGS_ROW1_Y + 4 * SETTINGS5_ROW_SPACING))

# Round 13 result: DIALOG_BUTTONS_Y=540 was too high -- it landed on
# (or just above) the divider line between the input box and the button
# row, not the "Save" button itself, so the Model dialog never actually
# closed. Everything after that step cascaded into the wrong screen: with
# the dialog still open but not covering the full display, later taps
# meant for Base URL / API key / Test connection landed on the reader
# document underneath instead (KOReader's own tap zones -- one of them
# opened the Table of Contents), and the run never recovered. `xdotool
# type` itself worked exactly as hoped (11-model-typed.png showed
# "llama3.1" landing in the field character-for-character) -- only the
# button coordinate was wrong. Corrected below from a real 2x crop of
# round 13's 11-model-typed.png: the button row's divider line sits at
# x=385 (so Cancel center=277, Save center=492 -- both close to the
# original guesses), and the row itself spans y=540-580, center ~562 --
# not 540, which was right at its top edge. DIALOG_BUTTONS_Y_WITH_CHECKBOX
# extrapolated the same +40px the checkbox row added elsewhere = 602.
DIALOG_SAVE_X=492
DIALOG_BUTTONS_Y=562
DIALOG_BUTTONS_Y_WITH_CHECKBOX=602

OLLAMA_MODEL="llama3.1"
OLLAMA_URL="http://host.docker.internal:11434/v1/chat/completions"
OLLAMA_PLACEHOLDER_KEY="ollama"

echo "Starting Xvfb..."
Xvfb :99 -screen 0 768x1024x24 &
XVFB_PID=$!
sleep 2

cd /home/ko/koreader
echo "Starting KOReader emulator..."
./kodev run > /home/ko/screenshots/koreader-stdout.log 2>&1 &
KO_PID=$!

sleep 20
import -window root /home/ko/screenshots/00-startup.png
echo "Wrote 00-startup.png"

# Dismiss the "documents render in color" info popup, if present
# (round 1: a tap around here closed it without side effects).
xdotool mousemove 600 400 click 1
sleep 1
import -window root /home/ko/screenshots/01-popup-dismissed.png
echo "Wrote 01-popup-dismissed.png"

# Tap top-center of the actual content box (not screen-absolute top)
# to reveal the top menu bar.
TOPMENU_Y=$((CONTENT_TOP + 40))
xdotool mousemove "$CONTENT_CENTER_X" "$TOPMENU_Y" click 1
sleep 1
import -window root /home/ko/screenshots/02-top-menu.png
echo "Wrote 02-top-menu.png"

# Tap the Tools (wrench) icon in that top menu bar.
xdotool mousemove "$TOOLS_ICON_X" "$TOOLS_ICON_Y" click 1
sleep 1
import -window root /home/ko/screenshots/03-tools-tab.png
echo "Wrote 03-tools-tab.png"

# inkRPG didn't fit on page 1 of the Tools tab -- go to page 2.
xdotool mousemove "$NEXT_PAGE_X" "$NEXT_PAGE_Y" click 1
sleep 1
import -window root /home/ko/screenshots/04-tools-page2.png
echo "Wrote 04-tools-page2.png"

# inkRPG is inside the "More tools" submenu, not a top-level Tools entry.
xdotool mousemove "$MORE_TOOLS_X" "$MORE_TOOLS_Y" click 1
sleep 1
import -window root /home/ko/screenshots/05-more-tools.png
echo "Wrote 05-more-tools.png"

# Tap "inkRPG" itself -- as of round 11 this is now a submenu (Play /
# AI provider settings), not a direct action.
xdotool mousemove "$INKRPG_X" "$INKRPG_Y" click 1
sleep 1
import -window root /home/ko/screenshots/06-inkrpg-submenu.png
echo "Wrote 06-inkrpg-submenu.png (tapped $INKRPG_X,$INKRPG_Y -- should now show a 2-item 'Play' / 'AI provider settings' submenu, not the old game picker)"

# ROUND 15: changed vector -- tap the submenu's 1ST row ("Play") instead
# of "AI provider settings". A real Gemini key is going into
# configuration.lua directly (by the user, on their own machine -- see
# ROUND 15 notes above), which inkrpg_ai_provider.lua's loadConfig()
# falls back to automatically since nothing is saved in the settings
# store this run. That sidesteps the whole settings-screen typing flow
# rounds 13-14 were building -- this round goes straight for the actual
# payoff (a live AI turn) via the game itself.
xdotool mousemove "$CONTENT_CENTER_X" "$SUBMENU_ROW1_Y" click 1
sleep 1
import -window root /home/ko/screenshots/07-play-tapped.png
echo "Wrote 07-play-tapped.png (tapped submenu row 1 'Play' at y=$SUBMENU_ROW1_Y -- should show the game picker with 'The Whispering Cave', same as the old flat-menu flow rounds 6-10 confirmed)"

# Select the one demo game -- same GAME_ENTRY_Y guess that landed
# correctly back in round 6/7.
GAME_ENTRY_Y=$((CONTENT_TOP + 60))
xdotool mousemove "$CONTENT_CENTER_X" "$GAME_ENTRY_Y" click 1
sleep 1
import -window root /home/ko/screenshots/08-cave-mouth.png
echo "Wrote 08-cave-mouth.png (should show cave_mouth's opening narration and its 3 rows: 2 authored choices + '...Something else')"

# Tap "...Something else" -- always the LAST button row per
# inkrpg_play_screen.lua (added after the scene's own choices), so for
# cave_mouth's 2-choice layout that's ROW3_Y (838, confirmed geometry
# from rounds 7-10).
xdotool mousemove "$CONTENT_CENTER_X" "$ROW3_Y" click 1
sleep 1
import -window root /home/ko/screenshots/09-free-action-dialog.png
echo "Wrote 09-free-action-dialog.png (tapped row 3 at y=$ROW3_Y -- should show promptFreeAction()'s 'What do you do?' InputDialog)"

# Type a free action. Same InputDialog widget as the settings screen's
# Model/Base URL dialogs (single-line input, no checkbox), so the same
# button-row geometry applies: Cancel/Go at DIALOG_BUTTONS_Y=562, "Go" on
# the right at DIALOG_SAVE_X=492 (button position, not button label --
# both dialogs share the same 2-button-row layout).
FREE_ACTION="I look around carefully for anything unusual before going further."
xdotool type --delay 50 "$FREE_ACTION"
sleep 1
import -window root /home/ko/screenshots/10-free-action-typed.png
echo "Wrote 10-free-action-typed.png (typed the free action into the input field)"

xdotool mousemove "$DIALOG_SAVE_X" "$DIALOG_BUTTONS_Y" click 1
sleep 1
import -window root /home/ko/screenshots/11-ai-request-sent.png
echo "Wrote 11-ai-request-sent.png (tapped 'Go' -- this triggers PlayScreen:sendAiAction(), a BLOCKING call to AIProvider.requestStructured() -- may still be in flight here)"

# ROUND 17 result: the previous run got a real HTTP 404 back almost
# instantly (fast rejection, no generation involved) -- confirming
# network/config were fine -- but after fixing the model name, the next
# run hit a "wantread" failure landing at EXACTLY 10s after the request,
# matching REQUEST_BLOCK_TIMEOUT's old value: a real model actually
# composing a full structured-JSON reply took longer than that one
# socket-read timeout allowed (not the 60s total cap -- see
# inkrpg_ai_provider.lua, now raised to 30s). Bumped this sleep to match
# -- long enough to cover a real generation call finishing within the new
# 30s block / 60s total ceiling, not just the near-instant error cases
# tested so far.
sleep 35
import -window root /home/ko/screenshots/12-ai-result.png
echo "Wrote 12-ai-result.png (should show either PlayScreen:renderAiScene()'s output -- real Gemini narration + choices, structured JSON successfully parsed -- or a specific error InfoMessage if the request/parsing failed; either is useful information)"

kill "$KO_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true
wait 2>/dev/null || true

echo "Done. Screenshots + koreader-stdout.log are in /home/ko/screenshots"
echo "(mounted at ./screenshots on your host)."

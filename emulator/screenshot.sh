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
# always be the content box's center.
ROW1_Y=752
ROW2_Y=795
ROW3_Y=838

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

# The payoff: tap "inkRPG" itself. Should open the game-picker Menu.
xdotool mousemove "$INKRPG_X" "$INKRPG_Y" click 1
sleep 1
import -window root /home/ko/screenshots/06-inkrpg-picker.png
echo "Wrote 06-inkrpg-picker.png (tapped $INKRPG_X,$INKRPG_Y -- should show the game picker with 'The Whispering Cave')"

# If the picker showed up, try selecting the one demo game too, in the
# same run -- worst case this screenshot just repeats 06 unchanged and
# tells us the picker didn't render where expected.
GAME_ENTRY_Y=$((CONTENT_TOP + 60))
xdotool mousemove "$CONTENT_CENTER_X" "$GAME_ENTRY_Y" click 1
sleep 1
import -window root /home/ko/screenshots/07-game-selected.png
echo "Wrote 07-game-selected.png"

# Advance the story: tap the first choice button ("Light a torch and go
# in"). Per scenes.lua this should move to entrance_hall.
xdotool mousemove "$CONTENT_CENTER_X" "$ROW1_Y" click 1
sleep 1
import -window root /home/ko/screenshots/08-entrance-hall.png
echo "Wrote 08-entrance-hall.png"

# entrance_hall also has a 2-choice + "...Something else" layout, so its
# first choice ("Take the narrow crawl") is at the same row-1 position.
xdotool mousemove "$CONTENT_CENTER_X" "$ROW1_Y" click 1
sleep 1
import -window root /home/ko/screenshots/09-crawl-space.png
echo "Wrote 09-crawl-space.png (tapped row 1 -- should show crawl_space, which has only ONE choice + Something else -- a 2-row layout, untested until now)"

# crawl_space has only 1 choice + "...Something else" (2 rows, not 3).
# If bottom-anchoring holds, its one choice sits at the row-2 position
# (the last non-"Something else" row), not row 1. Unverified guess.
xdotool mousemove "$CONTENT_CENTER_X" "$ROW2_Y" click 1
sleep 1
import -window root /home/ko/screenshots/10-locked-door.png
echo "Wrote 10-locked-door.png (tapped row 2 -- should show locked_door if the bottom-anchoring guess was right; inspect regardless)"

# locked_door has 2 choices again (3-row layout) -- "Try the iron key"
# back at row 1, should lead to the ending_key ending.
xdotool mousemove "$CONTENT_CENTER_X" "$ROW1_Y" click 1
sleep 1
import -window root /home/ko/screenshots/11-ending.png
echo "Wrote 11-ending.png"

# Confirm restart: tap "Play again" (row 3). Should reset back to
# cave_mouth's opening text and its two choices, not error or hang.
xdotool mousemove "$CONTENT_CENTER_X" "$ROW3_Y" click 1
sleep 1
import -window root /home/ko/screenshots/12-play-again.png
echo "Wrote 12-play-again.png"

# Move forward once more so the save left on disk when this run ends is
# clearly NOT a fresh start (scene="entrance_hall", not "cave_mouth") --
# see ROUND 10 notes above for why this matters for the resume test.
xdotool mousemove "$CONTENT_CENTER_X" "$ROW1_Y" click 1
sleep 1
import -window root /home/ko/screenshots/13-final-state.png
echo "Wrote 13-final-state.png (should show entrance_hall again -- this is the state that should now persist to ./saves on the host)"

kill "$KO_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true
wait 2>/dev/null || true

echo "Done. Screenshots + koreader-stdout.log are in /home/ko/screenshots"
echo "(mounted at ./screenshots on your host)."

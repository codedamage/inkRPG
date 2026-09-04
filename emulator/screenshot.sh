#!/bin/bash
# Launches the KOReader emulator under a virtual display, waits for it
# to come up, tries to walk into Tools > inkRPG > The Whispering Cave,
# and saves a screenshot after each step to /home/ko/screenshots.
#
# HONESTY NOTE: this script has not been run end-to-end (see the
# Dockerfile header for why -- the build itself was blocked in the
# sandbox this was developed in before the emulator ever launched). The
# startup and Xvfb/screenshot mechanics are standard and should work;
# the exact xdotool tap coordinates for reaching the Tools menu are a
# best guess at KOReader's default desktop-emulator layout, not
# something confirmed on screen. If 02-after-tap.png doesn't show the
# Tools menu, open a shell instead and drive it interactively to find
# the right coordinates:
#   docker compose run --rm --entrypoint bash inkrpg-emulator
#   Xvfb :99 -screen 0 768x1024x24 & export DISPLAY=:99
#   cd koreader && ./kodev run &
#   sleep 15 && import -window root /home/ko/screenshots/manual.png
# then adjust the `xdotool mousemove X Y click 1` lines below to match
# what you see.
set -e

mkdir -p /home/ko/screenshots
export DISPLAY=:99

echo "Starting Xvfb..."
Xvfb :99 -screen 0 768x1024x24 &
XVFB_PID=$!
sleep 2

cd /home/ko/koreader
echo "Starting KOReader emulator..."
./kodev run > /home/ko/screenshots/koreader-stdout.log 2>&1 &
KO_PID=$!

# First launch is slower (builds font/doc caches). Give it real time.
sleep 20
import -window root /home/ko/screenshots/01-startup.png
echo "Wrote 01-startup.png (should show KOReader's file manager)"

# Tap near the top edge to open KOReader's top menu bar.
xdotool mousemove 380 15 click 1
sleep 1
import -window root /home/ko/screenshots/02-after-tap.png
echo "Wrote 02-after-tap.png -- check this to find the real Tools/inkRPG coordinates"

# Best-guess follow-up taps -- likely need adjusting once 02 is visible.
xdotool mousemove 600 400 click 1
sleep 1
import -window root /home/ko/screenshots/03-tools-menu.png

xdotool mousemove 400 300 click 1
sleep 1
import -window root /home/ko/screenshots/04-inkrpg.png

kill "$KO_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true
wait 2>/dev/null || true

echo "Done. Screenshots + koreader-stdout.log are in /home/ko/screenshots"
echo "(mounted at ./screenshots on your host)."
echo "Check koreader-stdout.log first: a Lua error loading inkrpg.koplugin"
echo "will show up there even if the screenshots look like a normal boot."

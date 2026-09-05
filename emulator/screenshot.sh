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
#   - One of the round-1 screenshots happened to land on KOReader's own
#     "USER INTERFACE" help page, which diagrams the tap zones: a thin
#     TOP MENU strip across the top (minus small corner tap zones), a
#     PREVIOUS PAGE column on the left, NEXT PAGE over most of the
#     middle, a BOTTOM MENU strip, and a STATUS BAR at the very bottom.
#     Tapping top-center should reveal the top menu bar.
#
# This round takes ONE new step (tap top-center, screenshot) rather
# than chaining several guesses -- once we can see what the top menu
# bar actually looks like, the follow-up taps (finding the Tools/wrench
# icon, then inkRPG under it) can be aimed precisely instead of guessed.
set -e

mkdir -p /home/ko/screenshots
export DISPLAY=:99

# Content box, from visual inspection of round 1's screenshots.
CONTENT_LEFT=115
CONTENT_TOP=150
CONTENT_W=540
CONTENT_H=720
CONTENT_CENTER_X=$((CONTENT_LEFT + CONTENT_W / 2))

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
echo "Wrote 02-top-menu.png (tapped $CONTENT_CENTER_X,$TOPMENU_Y -- inspect this to find the Tools/wrench icon's coordinates for the next round)"

kill "$KO_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true
wait 2>/dev/null || true

echo "Done. Screenshots + koreader-stdout.log are in /home/ko/screenshots"
echo "(mounted at ./screenshots on your host)."

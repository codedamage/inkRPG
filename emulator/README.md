# inkRPG emulator harness

Docker Compose setup to build and run the real KOReader desktop
emulator with `inkrpg.koplugin` loaded, so you can smoke-test the
plugin and grab screenshots without a physical e-reader. This is the
Phase 0 tooling from `../PLAN.md`.

## Status: built and validated up to the compile step; not run end-to-end yet

I attempted this from my own cloud sandbox first, to hand you something
already working rather than untested. Here's exactly how far that got:

- **Confirmed working:** `koreader/koappimage` pulls and has the right
  toolchain; `git clone --recursive https://github.com/koreader/koreader.git`
  completes in full (~2.7 GB); `./kodev build` / `./kodev run` are the
  correct commands (confirmed via `./kodev` -- there's no separate
  "emulator build" target, `build` is it).
- **Found and fixed one real bug along the way:** on a network with a
  TLS-intercepting proxy, `wget` doesn't pick up the system CA trust
  store automatically, even after `update-ca-certificates`. Fix:
  ```
  echo 'ca_certificate = /etc/ssl/certs/ca-certificates.crt' >> /etc/wgetrc
  ```
  This may not matter at all on your home network -- only relevant if
  you're behind a corporate proxy or similar.
- **Blocked, in that sandbox specifically:** the actual dependency
  compile. KOReader's build downloads ~40 vendored thirdparty libraries
  (zlib, freetype, mupdf, sdl3, ...) as tarballs from
  `github.com/.../archive/...` and `github.com/.../releases/download/...`.
  My cloud sandbox's outbound network policy allows plain `git clone`
  and `raw.githubusercontent.com` but returns `403 Forbidden` for those
  bulk archive/release download endpoints specifically. That's a
  property of my hosted environment's egress allowlist, not of a normal
  internet connection -- it shouldn't affect you running this on your
  own machine.

So: the Dockerfile and this compose setup encode everything I verified
is correct, but I haven't personally watched KOReader boot with
inkrpg.koplugin loaded or seen a real screenshot yet. `screenshot.sh`
says so again at the point that matters (the xdotool tap coordinates
for reaching the Tools menu are a best guess, not confirmed on screen).

## Try it

```
cd emulator
docker compose build          # first time: ~20-40+ min (compiles KOReader + deps)
docker compose run --rm inkrpg-emulator
```

Screenshots and `koreader-stdout.log` land in `./screenshots/`. Check
the log first -- a Lua error loading `inkrpg.koplugin` (e.g. a
`require()` path issue, a widget API mismatch) will show up there even
if a screenshot still looks like a normal boot.

If the automated tap sequence misses the Tools/inkRPG menu (likely,
first try), drive it by hand instead to find the right coordinates:

```
docker compose run --rm --entrypoint bash inkrpg-emulator
Xvfb :99 -screen 0 768x1024x24 &
export DISPLAY=:99
cd koreader && ./kodev run &
sleep 15 && import -window root /home/ko/screenshots/manual.png
```

Then adjust the `xdotool mousemove X Y click 1` lines in
`screenshot.sh` to match what you see, or just navigate it live if you
have a way to view the X display (e.g. add an x11vnc service to
`docker-compose.yml` and connect a VNC viewer -- happy to wire that up
if you'd rather watch it live than iterate on screenshots blind).

## If you'd rather I keep driving this

Send me the contents of `./screenshots/koreader-stdout.log` (and
whatever `.png` files came out) after your first `docker compose run`,
and I can debug from there -- most likely fixes are either a `require()`
path issue in the plugin or a widget field name that doesn't match the
real API (see the "known gaps" list in `../README.md`).

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

## Update: you ran it, and hit (and I fixed) a real bug

You ran `docker compose build` for real and got much further than my
sandbox could -- past zlib, libpng, freetype, and dozens of other
github.com-hosted dependencies -- before failing here:

```
+ clone_git_repo .../lua-Spore/build/downloads/source https://framagit.org/fperrad/lua-Spore 0.4.2
fatal: unable to access 'https://framagit.org/fperrad/lua-Spore/': Failed to connect to framagit.org port 443
```

One dependency, `lua-Spore`, is fetched via `git clone` straight from
`framagit.org` (a GitLab instance) instead of a github.com tarball like
everything else. I confirmed framagit.org *is* reachable from my own
sandbox (`git ls-remote` succeeded), so it isn't a framagit outage --
something about your specific network/Docker path is refusing that one
host (a firewall or antivirus product treating an unfamiliar GitLab
instance differently than github.com, or a Docker Desktop/WSL2 network
quirk -- framagit.org's IPv6 reachability is a plausible suspect if
your setup prefers IPv6 and that path is the one that's broken).

Rather than have you chase that down, I:
1. Cloned `lua-Spore` at the exact tag KOReader needs (0.4.2) from my
   side, where framagit.org is reachable, and repackaged it as a plain
   tarball: `vendor/lua-Spore-0.4.2.tar.gz`.
2. Patched the Dockerfile to serve that tarball from a throwaway local
   HTTP server during the build and point koreader-base's
   `lua-Spore/CMakeLists.txt` at `http://127.0.0.1:8765/...` instead of
   framagit.org (plain HTTP to localhost, not `file://` -- wget in this
   build doesn't support the `file://` scheme, I checked).
3. **Verified this in isolation** by invoking koreader-base's actual
   `download_archive` and `extract_archive` shell functions (from the
   real, generated `koenv.sh` in a from-scratch build tree) against the
   local server and the vendored tarball -- both succeeded, and the
   extracted tree matches what the real git-clone path would have
   produced (correct top-level dir stripped, `src/`, `Makefile`, etc.
   all present).

What I *can't* verify from my side: whether your build gets all the way
through the remaining ~35 dependencies after this fix, since my own
sandbox is blocked on a different, unrelated set of hosts (see above).
Given you'd already gotten past most of them before hitting lua-Spore,
I'd expect this to be the last blocker, but if you hit another one,
send me the log the same way and I'll debug it the same way.

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

# Builds and runs the KOReader desktop emulator with inkRPG's plugin
# mounted in, so you can smoke-test and screenshot it without a
# physical e-reader. See ../PLAN.md Phase 0.
#
# What's verified (from a sandboxed cloud container, 04 Sep 2026):
#   - this base image pulls fine and has the right toolchain (gcc/cmake/git)
#   - `git clone --recursive https://github.com/koreader/koreader.git`
#     completes in full (~2.7 GB checked out)
#   - `./kodev build` is the correct build entry point
#
# What's NOT verified end-to-end from that sandbox: the actual compile.
# That specific environment's outbound network policy blocks bulk
# github.com/archive + github.com/releases/download requests (used to
# fetch ~40 vendored thirdparty libs -- zlib, freetype, mupdf, sdl3...),
# even though plain `git clone`/`git ls-remote` and
# raw.githubusercontent.com work fine there. That's a property of that
# hosted sandbox's egress allowlist, not of a normal internet
# connection or of this Dockerfile -- on your own machine this should
# just build.
#
# If you ever see wget fail with "ERROR 403: Forbidden" fetching a
# *.tar.gz from github.com here, that's the same class of issue
# (an outbound proxy/policy blocking archive downloads specifically).
# If instead wget fails with a certificate error ("cannot verify
# github.com's certificate ... Self-signed certificate encountered"),
# that means something on your network is TLS-intercepting (a
# corporate proxy, antivirus, etc.) -- fix it by trusting that proxy's
# CA and adding this line to /etc/wgetrc inside the image:
#   ca_certificate = /etc/ssl/certs/ca-certificates.crt
# (that exact fix is what unblocked the cert half of this build in the
# sandboxed environment this was developed in.)
#
# UPDATE (05 Sep 2026): you actually ran this and hit a *different*
# wall further along: one specific thirdparty lib, lua-Spore, is fetched
# via `git clone` straight from framagit.org (a GitLab instance) instead
# of a github.com tarball like the other ~40 libs -- and your network
# refused the TCP connection to framagit.org specifically (everything
# else, including dozens of other github.com archive/release downloads,
# had already succeeded by that point). I confirmed framagit.org *is*
# reachable from my own sandbox, so this isn't a framagit outage -- it
# looks like something specific to your network/Docker path (framagit
# is a much less commonly allowlisted host than github.com; could be a
# firewall, antivirus, or a Docker Desktop/WSL2 IPv6 quirk).
#
# Rather than ask you to chase that down, I vendored the exact source
# koreader-base needs (lua-Spore tag 0.4.2, straight from framagit.org
# from my side, repackaged as a plain tarball) into vendor/, and patch
# the build to fetch it from a throwaway local HTTP server instead of
# framagit.org. Verified end-to-end in my sandbox against the real
# koreader-base download/extract machinery (base/thirdparty/cmake_modules
# /koenv.sh's download_archive + extract_archive), not just "should work".

FROM koreader/koappimage:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb xdotool imagemagick procps \
    && rm -rf /var/lib/apt/lists/*

USER ko
WORKDIR /home/ko
RUN git clone --recursive --jobs=8 https://github.com/koreader/koreader.git

# --- lua-Spore workaround: serve our vendored copy locally instead of
# fetching from framagit.org (see the UPDATE note above). ---
COPY --chown=ko:ko vendor/lua-Spore-0.4.2.tar.gz /home/ko/vendor/lua-Spore-0.4.2.tar.gz
RUN sed -i \
        -e "s#DOWNLOAD GIT 0.4.2#DOWNLOAD URL 3ff7716adda43291cd0a98e90644981f#" \
        -e "s#https://framagit.org/fperrad/lua-Spore#http://127.0.0.1:8765/lua-Spore-0.4.2.tar.gz#" \
        /home/ko/koreader/base/thirdparty/lua-Spore/CMakeLists.txt

WORKDIR /home/ko/koreader
RUN cd /home/ko/vendor && (python3 -m http.server 8765 >/tmp/vendor-http.log 2>&1 &) \
    && sleep 1 \
    && cd /home/ko/koreader \
    && ./kodev build

# inkrpg.koplugin is bind-mounted at runtime (see docker-compose.yml),
# not baked into the image, so editing the plugin on your host shows up
# on the next `docker compose run` without rebuilding the image.

COPY --chown=ko:ko screenshot.sh /home/ko/screenshot.sh
USER root
RUN chmod +x /home/ko/screenshot.sh
USER ko

ENTRYPOINT ["/home/ko/screenshot.sh"]

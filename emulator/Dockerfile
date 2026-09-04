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

FROM koreader/koappimage:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb xdotool imagemagick procps \
    && rm -rf /var/lib/apt/lists/*

USER ko
WORKDIR /home/ko
RUN git clone --recursive --jobs=8 https://github.com/koreader/koreader.git

WORKDIR /home/ko/koreader
RUN ./kodev build

# inkrpg.koplugin is bind-mounted at runtime (see docker-compose.yml),
# not baked into the image, so editing the plugin on your host shows up
# on the next `docker compose run` without rebuilding the image.

COPY --chown=ko:ko screenshot.sh /home/ko/screenshot.sh
USER root
RUN chmod +x /home/ko/screenshot.sh
USER ko

ENTRYPOINT ["/home/ko/screenshot.sh"]

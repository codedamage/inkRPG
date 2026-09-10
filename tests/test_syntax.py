"""
Loads every .lua file in the plugin with plain load() (no execution) --
catches typos and syntax breakage immediately, cheaply, without needing any
of the KOReader stubs. This was the very first check used throughout this
project's ad-hoc testing; formalized here so it always runs.
"""
import glob
import os

from lupa import LuaRuntime

from env import PLUGIN_DIR


def _all_lua_files():
    return sorted(glob.glob(os.path.join(PLUGIN_DIR, "**", "*.lua"), recursive=True))


def test_finds_lua_files():
    files = _all_lua_files()
    assert len(files) >= 10, "expected to find the plugin's .lua files under %s" % PLUGIN_DIR


def test_every_lua_file_is_syntactically_valid():
    lua = LuaRuntime(unpack_returned_tuples=True)
    try_load = lua.eval(
        "function(src, name) "
        "local chunk, err = load(src, name); "
        "return chunk ~= nil, err "
        "end"
    )
    errors = []
    for path in _all_lua_files():
        if os.path.basename(path) == "configuration.lua":
            # Real per-user credentials file, gitignored, may not even
            # exist -- and never something a test should open.
            continue
        with open(path, "rb") as f:
            src = f.read()
        ok, err = try_load(src, "@" + path)
        if not ok:
            errors.append("%s: %s" % (path, err))
    assert not errors, "syntax errors:\n" + "\n".join(errors)

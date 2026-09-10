"""
Builds one fresh, isolated Lua runtime per test, with KOReader's own APIs
faked out (see lua_stubs.lua) and this plugin's real directory on
package.path -- so inkrpg.koplugin/*.lua can require() each other exactly
like they do inside a real KOReader install, with no real KOReader needed
to run these tests.

Deliberately never touches inkrpg.koplugin/configuration.lua (the
gitignored, real-API-key file a developer may have sitting next to the
plugin): AIProvider's own power-user config-file fallback is exercised via
a monkeypatched `loadfile`, not the real file on disk -- see the
fake_loadfile_* helpers below and test_ai_provider.py. Never read, print,
or assert on that file's contents from a test.
"""
import os

from lupa import LuaRuntime

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(TESTS_DIR)
PLUGIN_DIR = os.path.join(REPO_ROOT, "inkrpg.koplugin")
STUBS_LUA = os.path.join(TESTS_DIR, "lua_stubs.lua")


class Env:
    def __init__(self):
        if not os.path.isdir(PLUGIN_DIR):
            raise RuntimeError(
                "Expected inkrpg.koplugin/ next to tests/ at %s -- run pytest "
                "from a checkout of the whole repo, not a copied tests/ folder."
                % PLUGIN_DIR
            )

        self.lua = LuaRuntime(unpack_returned_tuples=True)
        g = self.lua.globals()

        # Python-side implementations, wired into a Lua __TEST__ table that
        # lua_stubs.lua's fakes call out to. Built from Lua source (rather
        # than poking the table from Python attribute-by-attribute) because
        # lupa's globals()/table proxies don't support attribute assignment.
        g["__lfs_isdir"] = lambda p: os.path.isdir(p)
        g["__lfs_isfile"] = lambda p: os.path.isfile(p)
        g["__lfs_listdir"] = self._lfs_listdir
        g["__default_http_request"] = self._default_http_request

        self.lua.execute(
            "__TEST__ = {\n"
            "    recorded_timeouts = {},\n"
            "    http_request = __default_http_request,\n"
            "    lfs_isdir = __lfs_isdir,\n"
            "    lfs_isfile = __lfs_isfile,\n"
            "    lfs_listdir = __lfs_listdir,\n"
            "}\n"
            "__lfs_isdir, __lfs_isfile, __lfs_listdir, __default_http_request = nil, nil, nil, nil\n"
        )

        with open(STUBS_LUA, "r") as f:
            self.lua.execute(f.read())

        self.lua.execute('package.path = %r .. "/?.lua;" .. package.path' % (PLUGIN_DIR,))

    def _lfs_listdir(self, path):
        if not os.path.isdir(path):
            return None
        return self.lua.table_from(sorted(os.listdir(path)))

    def _default_http_request(self, req):
        raise AssertionError(
            "this test never configured __TEST__.http_request -- "
            "use env.set_http_response()/set_http_handler()"
        )

    # -- convenience for tests --------------------------------------------

    def require(self, module_name):
        """require() a plugin module by its bare name, e.g. "inkrpg_state".
        This Lua's require() returns (module, loader_data) -- only the
        module itself is useful here."""
        result = self.lua.eval('require("%s")' % module_name)
        if isinstance(result, tuple):
            return result[0]
        return result

    def globals(self):
        return self.lua.globals()

    def set_http_response(self, code, body):
        """Every AI provider HTTP call gets this same canned (code, body)."""
        def handler(req):
            req["sink"](body)
            req["sink"](None)
            return 1, code
        self.lua.globals()["__TEST__"]["http_request"] = handler

    def set_http_handler(self, fn):
        """fn(request_table) -> (code, body). Called per request, for tests
        that need to inspect what was actually sent (url/headers/body)."""
        def handler(req):
            code, body = fn(req)
            req["sink"](body)
            req["sink"](None)
            return 1, code
        self.lua.globals()["__TEST__"]["http_request"] = handler

    def fake_loadfile_returns(self, lua_table_source):
        """Makes the global loadfile() (used by AIProvider's configuration.lua
        power-user fallback, and by GameLoader for manifest/scenes files)
        return a chunk evaluating to the given Lua table literal, for ANY
        path -- so this never actually opens a real file. lua_table_source
        is raw Lua source text, e.g. '{ provider = "openai" }'."""
        self.lua.execute(
            "loadfile = function(path) return function() return %s end end"
            % lua_table_source
        )

    def fake_loadfile_missing(self):
        """Makes the global loadfile() report "no such file" for any path,
        without touching the real filesystem."""
        self.lua.execute('loadfile = function(path) return nil, "no such file" end')

    def body_of(self, req):
        """Drains a captured http.request `req` table's ltn12 source into
        the request body string it represents -- the real request table
        has no plain `.body` field (the body is only ever sent through
        `source`), so this is how a test recovers what was actually sent."""
        return req["source"]()

    def call2(self, fn, *args):
        """Call a Lua function that follows the "(value, err)" convention,
        normalizing to always return a 2-tuple -- several of this plugin's
        functions only bother returning a second nil on the error path
        (`return games` on success vs. `return nil, "..."` on failure),
        which Lua/lupa collapse to a single value when there's nothing
        after it."""
        result = fn(*args)
        if isinstance(result, tuple):
            return result
        return (result, None)

    def last_timeout(self):
        timeouts = self.lua.globals()["__TEST__"]["recorded_timeouts"]
        n = len(timeouts)
        assert n > 0, "socketutil:set_timeout was never called"
        last = timeouts[n]
        return {"block": last["block"], "total": last["total"]}

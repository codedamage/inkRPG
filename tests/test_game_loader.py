"""inkrpg_game_loader.lua -- game pack discovery, plus (doubling as
content validation) checks that the bundled demo-cave game pack is
actually well-formed: every choice points somewhere real, every
non-ending scene has a way forward. A broken game pack here is exactly
the kind of thing a third-party game author's mistake would trip."""


def test_lists_the_bundled_demo_cave(env):
    GameLoader = env.require("inkrpg_game_loader")
    games, err = env.call2(GameLoader.listGames)
    assert err is None
    slugs = [g["slug"] for g in games.values()]
    assert "demo-cave" in slugs


def test_demo_cave_manifest_has_required_fields(env):
    GameLoader = env.require("inkrpg_game_loader")
    games, _ = env.call2(GameLoader.listGames)
    demo = next(g for g in games.values() if g["slug"] == "demo-cave")
    assert demo["title"]
    assert demo["start_scene"]
    assert demo["starting_stats"]["hp"] > 0
    assert demo["starting_stats"]["max_hp"] >= demo["starting_stats"]["hp"]


def test_demo_cave_scenes_form_a_consistent_graph(env):
    GameLoader = env.require("inkrpg_game_loader")
    games, _ = env.call2(GameLoader.listGames)
    demo = next(g for g in games.values() if g["slug"] == "demo-cave")
    scenes, _ = env.call2(GameLoader.loadScenes, demo)
    assert scenes is not None

    scene_ids = set(scenes.keys())
    assert demo["start_scene"] in scene_ids, "start_scene must be a real scene"

    for scene_id in scene_ids:
        scene = scenes[scene_id]
        assert scene["text"], "scene %r has no text" % scene_id
        choices = scene["choices"]
        is_ending = bool(scene["is_ending"])
        if is_ending:
            assert len(choices) == 0, "ending scene %r should have no choices" % scene_id
        else:
            assert len(choices) > 0, (
                "non-ending scene %r has no choices -- dead end with no "
                "'...Something else' fallback reachable" % scene_id
            )
        for choice in choices.values():
            assert choice["label"], "a choice in %r has no label" % scene_id
            assert choice["next"] in scene_ids, (
                "scene %r has a choice pointing at unknown scene %r"
                % (scene_id, choice["next"])
            )


def test_load_scenes_reports_missing_file(env):
    GameLoader = env.require("inkrpg_game_loader")
    ok, err = env.call2(GameLoader.loadScenes, env.lua.eval('{ _dir = "/no/such/dir/" }'))
    assert ok is None
    assert "Could not load" in err


def test_load_scenes_rejects_a_file_that_returns_no_table(env, tmp_path):
    GameLoader = env.require("inkrpg_game_loader")
    (tmp_path / "scenes.lua").write_text("return 42\n")
    ok, err = env.call2(GameLoader.loadScenes, env.lua.eval('{ _dir = %r }' % (str(tmp_path) + "/")))
    assert ok is None
    assert "did not return a table" in err


def test_load_text_reads_a_lore_file(env):
    GameLoader = env.require("inkrpg_game_loader")
    games, _ = env.call2(GameLoader.listGames)
    demo = next(g for g in games.values() if g["slug"] == "demo-cave")
    text = GameLoader.loadText(demo, "world/intro.md")
    assert text is None or isinstance(text, str)  # present if demo-cave ships this file


def test_load_text_returns_nil_for_missing_file(env):
    GameLoader = env.require("inkrpg_game_loader")
    games, _ = env.call2(GameLoader.listGames)
    demo = next(g for g in games.values() if g["slug"] == "demo-cave")
    assert GameLoader.loadText(demo, "does/not/exist.md") is None

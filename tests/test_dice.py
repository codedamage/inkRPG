"""inkrpg_dice.lua -- small, dependency-free, so these need no stubs at all
beyond require() finding the plugin directory."""


def test_roll_bounds(env):
    Dice = env.require("inkrpg_dice")
    for _ in range(50):
        total, rolls = Dice.roll(3, 6)
        assert 3 <= total <= 18
        assert len(rolls) == 3
        for r in rolls.values():
            assert 1 <= r <= 6
        assert sum(rolls.values()) == total


def test_roll_defaults_to_one_d6(env):
    Dice = env.require("inkrpg_dice")
    total, rolls = Dice.roll()
    assert len(rolls) == 1
    assert 1 <= total <= 6


def test_check_success_and_failure_are_deterministic_with_forced_roll(env):
    # Pin math.random so the d20 in Dice.check is no longer random --
    # lets us assert the exact pass/fail boundary instead of a fuzzy
    # "usually succeeds" check.
    env.lua.execute("math.random = function(a, b) return a end")  # always rolls the minimum (1)
    Dice = env.require("inkrpg_dice")

    ok, raw, total = Dice.check(10, 0)
    assert raw == 1
    assert total == 1
    assert ok is False

    ok, raw, total = Dice.check(1, 0)
    assert ok is True  # a roll of 1 still clears a target of 1

    ok, raw, total = Dice.check(10, 15)
    assert total == 16
    assert ok is True

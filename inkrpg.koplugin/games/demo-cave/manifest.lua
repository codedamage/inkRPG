-- inkRPG game pack manifest. Plain Lua table, no code required beyond
-- this literal. See PLAN.md section 4.2 for the full format writeup.

return {
    title = "The Whispering Cave",
    slug = "demo-cave", -- optional; defaults to the folder name
    dm_persona = [[
You are a terse, atmospheric dungeon master running a short cave-exploration
one-shot for a single player. Keep replies under 120 words. Never resolve
combat or damage without a dice roll.
]],
    starting_stats = {
        hp = 10,
        max_hp = 10,
        torches = 2,
    },
    start_scene = "cave_mouth",
}

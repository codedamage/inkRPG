-- Phase 1 reference game: a fully hand-authored mini adventure, zero AI
-- calls. Proves the engine's turn loop, choices, state and save/load
-- before any AI wiring lands.
--
-- Each scene: { text = "...", choices = {...}, is_ending = bool,
--               on_enter = function(stats, flags) ... end }
-- choices: { { label = "shown on the button", next = "next scene id" } }
-- on_enter runs right before the scene renders and can mutate
-- stats/flags -- this is how a scene applies its own state changes
-- deterministically, no AI required.

return {
    cave_mouth = {
        text = "Cold air breathes out of a crack in the hillside. Your torch "
            .. "gutters in the draft. Somewhere below, something drips.",
        choices = {
            { label = "Light a torch and go in", next = "entrance_hall" },
            { label = "Walk away", next = "ending_walk_away" },
        },
    },

    entrance_hall = {
        on_enter = function(stats)
            stats.torches = math.max(0, (stats.torches or 0) - 1)
        end,
        text = "The passage opens into a hall lined with old, dry bones. "
            .. "Two ways lead on: a narrow crawl to the left, a wide, "
            .. "damp tunnel straight ahead.",
        choices = {
            { label = "Take the narrow crawl", next = "crawl_space" },
            { label = "Take the wide tunnel", next = "flooded_tunnel" },
        },
    },

    crawl_space = {
        text = "You squeeze through loose rock and drop into a small, dry "
            .. "chamber. A glint catches your eye: an old iron key, "
            .. "half-buried in the dust.",
        choices = {
            { label = "Take the key and press on", next = "locked_door" },
        },
    },

    flooded_tunnel = {
        on_enter = function(stats)
            stats.hp = math.max(0, (stats.hp or 10) - 2)
        end,
        text = "Knee-deep water numbs your legs. Something brushes past in "
            .. "the dark and you flinch, scraping your arm on the rock. "
            .. "(-2 HP.) The tunnel ends at a heavy, locked door.",
        choices = {
            { label = "Search yourself for anything useful", next = "locked_door" },
        },
    },

    locked_door = {
        text = "A rusted iron door blocks the way, sealed with an old lock.",
        choices = {
            { label = "Try the iron key", next = "ending_key" },
            { label = "Force it open", next = "ending_force" },
        },
    },

    ending_key = {
        is_ending = true,
        text = "The key turns. Beyond the door, faint daylight -- a way "
            .. "out, and the cave's one real secret, saved for the AI-DM "
            .. "chapters of this project to reveal. For now: you win. "
            .. "THE END.",
        choices = {},
    },

    ending_force = {
        is_ending = true,
        on_enter = function(stats)
            stats.hp = math.max(0, (stats.hp or 10) - 4)
        end,
        text = "The door doesn't budge, but the rock around the hinges "
            .. "does -- painfully. (-4 HP.) It gives way in a shower of "
            .. "rust. You stumble through, bruised but through. THE END.",
        choices = {},
    },

    ending_walk_away = {
        is_ending = true,
        text = "Some mysteries aren't worth the climb. You turn back to "
            .. "the light. THE END.",
        choices = {},
    },
}

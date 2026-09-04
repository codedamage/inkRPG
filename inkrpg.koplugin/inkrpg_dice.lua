--[[--
Small dice / skill-check helper shared across game packs. Deliberately
tiny for Phase 1 -- grow it as real games need more (advantage,
modifiers, opposed rolls) instead of speculatively building it all now.
Not used by demo-cave yet; it's here for the next game pack to reach for.
--]]--

local Dice = {}

math.randomseed(os.time())

-- Rolls `count` dice of `sides` and returns the total plus the individual
-- rolls, e.g. Dice.roll(2, 6) -> 7, {3, 4}
function Dice.roll(count, sides)
    count = count or 1
    sides = sides or 6
    local total = 0
    local rolls = {}
    for _ = 1, count do
        local r = math.random(1, sides)
        table.insert(rolls, r)
        total = total + r
    end
    return total, rolls
end

-- Simple d20 skill check against a target number, with an optional flat
-- modifier. Returns success (bool), the raw d20 roll, and the total.
function Dice.check(target, modifier)
    modifier = modifier or 0
    local raw = Dice.roll(1, 20)
    local total = raw + modifier
    return total >= target, raw, total
end

return Dice

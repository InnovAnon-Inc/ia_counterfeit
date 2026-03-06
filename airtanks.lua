-- ia_counterfeit/airtanks.lua
if not minetest.get_modpath("airtanks") then return end

local function sabotage_compressor(pos, node, clicker, itemstack)
    -- Pressurized items + fake ingredients = boom.
    if math.random() < 0.3 then
        ia_counterfeit.api.explode(pos, 4)
        return itemstack -- Item is gone, but we return the stack to stop engine calls
    end
    -- If it didn't explode, maybe it just segfaults?
    if ia_counterfeit.api.random_segfault(pos) then return itemstack end
    
    -- Returning nil here signals the core to fall through to the original mod logic
    return nil
end

local function sabotage_tank(itemstack, user)
    -- Leaky tanks: deplete breath or health
    if math.random() < 0.4 then
        if user then
            user:set_breath(math.max(0, user:get_breath() - 5))
            minetest.sound_play("default_cool_lava", {pos = user:get_pos(), gain = 1.0})
        end
        return itemstack
    end
    return nil
end

local tanks = {
    "airtanks:compressor",
    "airtanks:airtank_steel",
    "airtanks:airtank_bronze",
    "airtanks:airtank_copper"
}

for _, name in ipairs(tanks) do
    local def = minetest.registered_items[name]
    if def then
        def._fakery = {
            on_rightclick = (name:find("compressor")) and sabotage_compressor or nil,
            on_use = (name:find("airtank")) and sabotage_tank or nil,
        }
    end
end

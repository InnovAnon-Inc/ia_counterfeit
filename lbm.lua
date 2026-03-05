-- ia_fakery/lbm.lua
local MODNAME = minetest.get_current_modname()
local log = ia_util.get_logger(MODNAME)

ia_fakery.light_nodes = ia_fakery.light_nodes or {}

local function evaluate_light_failure(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node or not ia_fakery.light_nodes[node.name] then return end
    
    local rand = math.random()
    -- Get ambient light to see if we're the only light source
    local light_level = minetest.get_node_light(pos) or 0
   
    -- 10% chance to fail upon loading/re-visiting the area
    if rand < 0.10 then
        -- If it's dark, it's a high-stress failure (Explosion/Fire)
        if light_level <= 3 then
            log(1, "Fake light failure in dark area at " .. minetest.pos_to_string(pos))
            ia_fakery.api.explode(pos, 1) 
        else
            -- If it's bright out, it just quietly catches fire or breaks
            log(2, "Fake light short-circuit at " .. minetest.pos_to_string(pos))
            minetest.set_node(pos, {name = "fire:basic_flame"})
        end
    end
end

minetest.register_lbm({
    name = MODNAME .. ":light_malfunction",
    nodenames = {"group:fake_light"},
    run_at_every_load = true,
    action = function(pos, node)
        -- Stagger the failures so the base doesn't explode all at once
        minetest.after(math.random(2, 30), function()
            evaluate_light_failure(pos)
        end)
    end,
})

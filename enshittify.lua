-- ia_fakery/enshittify.lua
-- NOTE fake lights shouldn't work (reliably) ... gotta check the light source property ?
-- NOTE fake nodes/items should (risk) explode or catch fire, especially if they have fake mese
-- NOTE fake nodes/items should not on_use properly; risk of just not working; risk of breaking; risk of injuring user; especially if they have fake diamond
-- NOTE fake nodes/items should (risk) injuring the user / nearby players/mobs
-- NOTE any other properties or fields we wanna override with intentional "jankiness" ?
-- NOTE durability decay
-- NOTE we might detect whether a player is using a fake compressor or a fake airtank in a compressor, and blow it tf up
-- NOTE our magic books that generate really useful reports... obv those have gotta f their data before generating the report. decision makers love bad intel. to handle this, we can actually add a _fakery field to the def in those gutenberg book mods, and consume it here. that is: application-specific enshittification, as well as a default fallback. in this case... we can probably just f the text displayed by any book as a naive default fallback.
-- NOTE would be pretty funny if we can make it a little... "sticky"... like a lode stone... so it has a chance to ... just refuse to be dropped.... or switched from the hand. not a permanent thing. maybe ya gotta try dropping it a few times.
-- NOTE it's funnier to be unreliable than to reliably not work at all
-- NOTE sometimes (especially when it's the only light source in a very dark place), a light should just go out completely. even funnier if it starts working again when the surrounding area is bright again.

-- ia_fakery/enshittify.lua
local MODNAME = minetest.get_current_modname()
local log = ia_util.get_logger(MODNAME)

-- 1. THE SABOTAGE TOOLBOX (API)
ia_fakery.api = {}

-- Returns true if the "failure" triggered (15% chance)
function ia_fakery.api.random_segfault(pos)
    if math.random() < 0.15 then
        log(2, "Interaction 'segfault' at " .. (pos and minetest.pos_to_string(pos) or "unknown"))
        return true
    end
    return false
end

-- Fire and brimstone (5% chance)
function ia_fakery.api.short_circuit(pos, puncher)
    if math.random() < 0.05 then
        minetest.set_node(pos, {name = "fire:basic_flame"})
        if puncher and puncher:is_player() then
            puncher:set_hp(puncher:get_hp() - 2)
        end
        return true
    end
    return false
end

-- Tool destruction and user injury (10% chance)
function ia_fakery.api.shatter(itemstack, user)
    if math.random() < 0.10 then
        if user then
            user:set_hp(user:get_hp() - 1)
            minetest.sound_play("default_tool_breaks", {pos = user:get_pos(), gain = 0.5})
        end
        itemstack:take_item()
        return true
    end
    return false
end

-- Catastrophic failure for pressurized or heavy machinery
function ia_fakery.api.explode(pos, radius)
    log(1, "Catastrophic failure at " .. minetest.pos_to_string(pos))
    minetest.set_node(pos, {name = "air"})
    minetest.explode_node(pos, radius or 3, 1)
end

-- 2. THE STANDARD WRAPPER
function ia_fakery.apply_standard_enshittification(def, name, used_mese, used_diamond)
    local spec = def._fakery or {}

    -- A. Tool Decay & Swing Lag (Worse than Wood)
    if def.tool_capabilities or name:find("tool") or name:find("pick") then
        def.tool_capabilities = {
            full_punch_interval = 8.0,
            max_drop_level = 0,
            groupcaps = {
                crumbly = {times={[1]=60, [2]=40, [3]=20}, uses=3, maxlevel=1},
                cracky   = {times={[1]=60, [2]=40, [3]=20}, uses=3, maxlevel=1},
                snappy   = {times={[1]=60, [2]=40, [3]=20}, uses=3, maxlevel=1},
            },
            damage_groups = {fleshy=1},
        }
    end

    -- B. "Sticky" Hands (Refuse to drop)
    local old_on_drop = def.on_drop
    def.on_drop = function(itemstack, dropper, pos)
        if math.random() < 0.20 then
            log(2, "Item stuck in " .. (dropper:get_player_name() or "unknown") .. "'s hand")
            return itemstack
        end
        return old_on_drop and old_on_drop(itemstack, dropper, pos) or minetest.item_drop(itemstack, dropper, pos)
    end

    -- C. Standard Rightclick (Segfault)
    -- Only applies if the item doesn't have a specific _fakery override
    if not spec.on_rightclick then
        local old_rc = def.on_rightclick
        def.on_rightclick = function(pos, node, clicker, itemstack, pt)
            if ia_fakery.api.random_segfault(pos) then return itemstack end
            return old_rc and old_rc(pos, node, clicker, itemstack, pt) or itemstack
        end
    end

    -- D. Standard Use (Shatter)
    if not spec.on_use then
        local old_use = def.on_use
        def.on_use = function(itemstack, user, pt)
            if used_diamond and ia_fakery.api.shatter(itemstack, user) then return itemstack end
            return old_use and old_use(itemstack, user, pt) or itemstack
        end
    end

    -- E. Standard Punch (Short Circuit)
    if not spec.on_punch then
        local old_punch = def.on_punch
        def.on_punch = function(pos, node, puncher, pt)
            if used_mese then ia_fakery.api.short_circuit(pos, puncher) end
            return old_punch and old_punch(pos, node, puncher, pt)
        end
    end

    -- F. Dynamic Lighting (Registration phase dimming) -- NOTE makes our mod janky, too
--    if def.light_source and def.light_source > 0 then
--        if math.random() < 0.5 then def.light_source = 1 end
--    end

    return def
end

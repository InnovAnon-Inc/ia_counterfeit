-- ia_fakery/core.lua
-- NOTE make sure we allow "substitutions": to make a fake item that requires some number of mese crystals and/or diamonds, we just need any one of them to be fake
local MODNAME = minetest.get_current_modname()
local log = ia_util.get_logger(MODNAME)

local function get_fake_name(name)
    local clean_name = name:match("^:(.+)") or name
    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
    if not m_name then m_name = "unknown"; i_name = clean_name end
    return "fakery:" .. m_name .. "_" .. i_name
end

function ia_fakery.ensure_fake_variant(name)
    if ia_fakery.substitutions[name] then return ia_fakery.substitutions[name] end
    if name:find("^fakery:") or ia_fakery.processed_items[name] then return nil end
    ia_fakery.processed_items[name] = true

    local recipes = minetest.get_all_craft_recipes(name)
    if not recipes then return nil end

    local fake_name = get_fake_name(name)

    for _, recipe in ipairs(recipes) do
        local method = recipe.method or "normal"
        local items = recipe.items or recipe.recipe
        local new_recipe_items = {}
        local recipe_changed = false
        local used_mese = false
        local used_diamond = false

        for i, ingredient in pairs(items) do
            if type(ingredient) == "string" and ingredient ~= "" then
                -- Track ingredient types for specific enshittification
                -- NOTE: We allow substitutions; if any ingredient is fake, the output is fake
                if ingredient == "default:mese_crystal" or ingredient == "fakery:mese" then used_mese = true end
                if ingredient == "default:diamond" or ingredient == "fakery:diamond" then used_diamond = true end

                local f_ing = ia_fakery.ensure_fake_variant(ingredient)
                if f_ing then
                    new_recipe_items[i] = f_ing
                    recipe_changed = true
                else
                    new_recipe_items[i] = ingredient
                end
            else
                new_recipe_items[i] = ingredient or ""
            end
        end

        if recipe_changed then
            -- 1. Ensure Item Definition exists
            if not minetest.registered_items[fake_name] then
                local original_def = minetest.registered_items[name]
                if original_def then
                    local def = table.copy(original_def)
                    local spec = def._fakery or {}
                    
                    -- A. Handle Light Source Grouping for LBM
                    local is_light = (def.light_source and def.light_source > 0)
                    if is_light then
                        def.groups = def.groups or {}
                        def.groups.fake_light = 1
                        ia_fakery.light_nodes[fake_name] = true
                    end

                    -- B. Apply App-Specific Overrides (Airtanks, Gutenberg, etc.)
                    if spec.on_rightclick then
                        local old_rc = def.on_rightclick
                        def.on_rightclick = function(pos, node, clicker, itemstack, pt)
                            local res = spec.on_rightclick(pos, node, clicker, itemstack)
                            if res then return res end -- Override handled/sabotaged it
                            return old_rc and old_rc(pos, node, clicker, itemstack, pt) or itemstack
                        end
                    end

                    if spec.on_use then
                        local old_use = def.on_use
                        def.on_use = function(itemstack, user, pt)
                            local res = spec.on_use(itemstack, user)
                            if res then return res end -- Override handled/sabotaged it
                            return old_use and old_use(itemstack, user, pt) or itemstack
                        end
                    end

                    -- C. Apply Standard Enshittification Fallbacks
                    def = ia_fakery.apply_standard_enshittification(def, name, used_mese, used_diamond)

                    -- D. Registration
                    if def.drawtype or minetest.registered_nodes[name] then
                        minetest.register_node(":" .. fake_name, def)
                    else
                        minetest.register_craftitem(":" .. fake_name, def)
                    end
                end
            end

            -- 2. Reconstruct Grid (API Asymmetry Handling)
            local craft_def = { output = fake_name .. " " .. ItemStack(recipe.output):get_count() }
            if recipe.width > 0 then
                local grid = {}
                for y = 0, math.floor((#new_recipe_items - 1) / recipe.width) do
                    local row = {}
                    for x = 1, recipe.width do table.insert(row, new_recipe_items[y * recipe.width + x] or "") end
                    table.insert(grid, row)
                end
                craft_def.recipe = grid
                craft_def.type = (method ~= "normal") and method or nil
            else
                craft_def.type = "shapeless"
                craft_def.recipe = new_recipe_items
            end
            
            minetest.register_craft(craft_def)
            ia_fakery.substitutions[name] = fake_name
        end
    end
    return ia_fakery.substitutions[name]
end

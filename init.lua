-- ia_fakery/init.lua
-- FIXME fake lights shouldn't work (reliably)
-- FIXME fake nodes should (risk) explode or catch fire
-- FIXME fake items should (risk) injuring the user
-- FIXME fake items should on_use properly; maybe risk of failure
-- TODO use ia_crapht

-- ia_fakery/init.lua
local MODNAME = minetest.get_current_modname()

-- 1. UTILITIES
local function get_fake_name(name)
    local clean_name = name:match("^:(.+)") or name
    local m_name, i_name = clean_name:match("([^:]+):([^:]+)")
    if not m_name then m_name = "unknown"; i_name = clean_name end
    return "fakery:" .. m_name .. "_" .. i_name
end

-- 2. CORE REGISTRY
assert(minetest.get_modpath('ia_util'))
local log = ia_util.get_logger(MODNAME)

ia_fakery = {
    substitutions = {
        ["default:diamond"]      = "fakery:diamond",
        ["default:mese_crystal"] = "fakery:mese",
    },
    processed_items = {} 
}

-- 3. THE RECURSIVE BUILDER
local function ensure_fake_variant(name)
    if ia_fakery.substitutions[name] then
        return ia_fakery.substitutions[name]
    end
    if name:find("^fakery:") then return nil end

    if ia_fakery.processed_items[name] then
        return nil
    end
    ia_fakery.processed_items[name] = true

    local recipes = minetest.get_all_craft_recipes(name)
    if not recipes then return nil end

    local fake_name = get_fake_name(name)

    for _, recipe in ipairs(recipes) do
        local method = recipe.method or "normal"
        local items = recipe.items or recipe.recipe
        local new_recipe_items = {}
        local recipe_changed = false

        -- Scan ingredients
        for i, ingredient in pairs(items) do
            if type(ingredient) == "string" and ingredient ~= "" then
                local f_ing = ensure_fake_variant(ingredient)
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
            -- Ensure definition exists
            if not minetest.registered_items[fake_name] then
                local original_def = minetest.registered_items[name]
                if original_def then
                    local def = table.copy(original_def)
                    def.description = "Fake " .. (def.description or name)
                    def.tool_capabilities = nil
                    if def.light_source then def.light_source = 0 end
                    
                    if def.drawtype or minetest.registered_nodes[name] then
                        minetest.register_node(":" .. fake_name, def)
                    else
                        minetest.register_craftitem(":" .. fake_name, def)
                    end
                end
            end

            -- RECONSTRUCT GRID (Handling the API asymmetry)
            local craft_def = {
                output = fake_name .. " " .. ItemStack(recipe.output):get_count(),
            }

            if recipe.width > 0 then
                -- Shaped: Convert flat array [1,2,3,4,5,6] to {{1,2,3},{4,5,6}}
                local grid = {}
                for y = 0, math.floor((#new_recipe_items - 1) / recipe.width) do
                    local row = {}
                    for x = 1, recipe.width do
                        table.insert(row, new_recipe_items[y * recipe.width + x] or "")
                    end
                    table.insert(grid, row)
                end
                craft_def.recipe = grid
                craft_def.type = (method ~= "normal") and method or nil
            else
                -- Shapeless
                craft_def.type = "shapeless"
                craft_def.recipe = new_recipe_items
            end

            -- Final assertion to catch issues before passing to engine
            assert(craft_def.recipe ~= nil, "Recipe construction failed for " .. name)
            
            minetest.register_craft(craft_def)
            ia_fakery.substitutions[name] = fake_name
        end
    end

    return ia_fakery.substitutions[name]
end

-- 4. BOOTSTRAP
function ia_fakery.init()
    log(3, "Deep-navigating tree with grid reconstruction...")
    
    local all_items = {}
    for name, _ in pairs(minetest.registered_items) do 
        table.insert(all_items, name) 
    end
    
    for _, name in ipairs(all_items) do
        ensure_fake_variant(name)
    end
    
    log(3, "Fakery Tree Navigation Complete.")
end

minetest.register_on_mods_loaded(ia_fakery.init)

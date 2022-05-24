-- registers a new fruitTypeCategory for earth fruits
function register()
    local categoryName = "EARTHFRUITS"
    local fruitTypeCategoryIndex = g_fruitTypeManager:addFruitTypeCategory(categoryName, false)
    local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory(categoryName, false)

    for _, fruitTypeData in pairs(g_fruitTypeManager.fruitTypes) do
        if fruitTypeData ~= nil then
            local minHarvestingGrowthState = fruitTypeData.minHarvestingGrowthState
            local minPreparingGrowthState = fruitTypeData.minPreparingGrowthState
            local preparedGrowthState = fruitTypeData.preparedGrowthState
            local name = fruitTypeData.name

            -- check if fruit is needs herb removement to be harvested
            if minHarvestingGrowthState >= 9 and minPreparingGrowthState ~= -1 and preparedGrowthState ~= -1 and name ~= "SUGARCANE" then

                -- add fruitType to new fruitTypeCategory
                local fruitType = g_fruitTypeManager:getFruitTypeByName(name)

                if fruitType ~= nil then
                    if not g_fruitTypeManager:addFruitTypeToCategory(fruitType.index, fruitTypeCategoryIndex) or not g_fillTypeManager:addFillTypeToCategory(fruitType.fillType.index, fillTypeCategoryIndex) then
                        print("Warning: Could not add fruitType '" .. tostring(name) .. "' to fruitTypeCategory '" .. tostring(categoryName) .. "'!")
                    end
                else
                    print("Warning: FruitType '" .. tostring(name) .. "' not defined in fruitTypeCategory '" .. tostring(name) .. "'!")
                end
            end
        end
    end
end

BaseMission.loadMap = Utils.prependedFunction(BaseMission.loadMap, register)
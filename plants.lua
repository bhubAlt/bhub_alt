local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook)
    local Plants = Window:CreateTab("Plants", "leaf")
    local myFarm = getMyFarm()
    local maxFruitInBag = false
    local maxFruitInBagAutoSellTrigger = false
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Notification = ReplicatedStorage.GameEvents.Notification
    Notification.OnClientEvent:Connect(function(message)
        if typeof(message) == "string" and message:lower():find("max backpack space! go sell!") then
            maxFruitInBag = true
            maxFruitInBagAutoSellTrigger = true
        end
    end)

    local function getAllSeedsTable()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local ItemModule = require(ReplicatedStorage:WaitForChild("Item_Module"))
        if typeof(ItemModule.Return_All_Seeds) ~= "function" then
            return nil
        end
        local result = ItemModule.Return_All_Seeds()
        if typeof(result) ~= "table" then
            return nil
        end
        return result
    end

    local function equipItemByExactName(itemName)
        local player = game.Players.LocalPlayer
        local backpack = player:WaitForChild("Backpack")
        -- player.Character.Humanoid:UnequipTools() --unequip all first

        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == itemName then
                --print("Equipping:", tool.Name)
                -- player.Character.Humanoid:UnequipTools() --unequip all first
                player.Character.Humanoid:EquipTool(tool)
                return true -- stop after first match
            end
        end
        return false
    end

    print("[BeastHub] Loading all seeds data..")
    local allSeedsData = getAllSeedsTable()
    local allSeedsOnly = {}

    if allSeedsData then
        for _, data in pairs(allSeedsData) do
            if typeof(data) == "table" and data[2] then
                table.insert(allSeedsOnly, data[2])
            end
        end
        print("[BeastHub] All seeds data loaded")
    else
        warn("[BeastHub] Failed to load seeds data")
    end
    table.sort(allSeedsOnly)

    local function getMutationEnumTable()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local DataFolder = ReplicatedStorage:WaitForChild("Data")
        local EnumRegistry = DataFolder:WaitForChild("EnumRegistry")
        local MutationEnums = require(EnumRegistry:WaitForChild("MutationEnums"))
        if typeof(MutationEnums) ~= "table" then
            return nil
        end
        return MutationEnums
    end
    local fruitMutationData = getMutationEnumTable()
    local function getMutationNameList(mutationEnumTable)
        if typeof(mutationEnumTable) ~= "table" then
            return {}
        end
        local result = {}
        for mutationName in pairs(mutationEnumTable) do
            table.insert(result, tostring(mutationName))
        end
        table.sort(result)
        return result
    end
    local mutationNameList = getMutationNameList(fruitMutationData)
    --=======

    Plants:CreateSection("Auto Collect Fruit")
    local selectedFruitsForAutoCollect = {}
    local dropdown_selectedFruitForAutoCollect = Plants:CreateDropdown({
        Name = "Select Fruit",
        Options = allSeedsOnly,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "selectedFruit_autoCollect", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Options)
            selectedFruitsForAutoCollect = Options
        end,
    })
    local searchDebounce_seed = nil
    Plants:CreateInput({
        Name = "Search fruit",
        PlaceholderText = "fruit",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_seed then
                task.cancel(searchDebounce_seed)
            end
            searchDebounce_seed = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = allSeedsOnly
                else
                    for _, fruitName in ipairs(allSeedsOnly) do
                        if string.find(string.lower(fruitName), query, 1, true) then
                            table.insert(results, fruitName)
                        end
                    end
                end
                dropdown_selectedFruitForAutoCollect:Refresh(results)
                dropdown_selectedFruitForAutoCollect:Set(selectedFruitsForAutoCollect) --set to current selected

            end)
        end,
    })
    Plants:CreateButton({
        Name = "Clear fruit",
        Callback = function()
            dropdown_selectedFruitForAutoCollect:Set({})
        end,
    })
    local function getAllVariantNames()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local ItemModule = require(ReplicatedStorage:WaitForChild("Item_Module"))
        local variants = ItemModule.VariantNames
        if typeof(variants) ~= "table" then
            return nil
        end
        local result = {}
        for _,name in pairs(variants) do
            if typeof(name) == "string" then
                table.insert(result, name)
            end
        end
        return result
    end
    local allVariantNames = getAllVariantNames()
    local dropdown_selectedFruitVariantForAutoCollect = Plants:CreateDropdown({
        Name = "Select Variant",
        Options = allVariantNames,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "selectedFruitVariant_autoCollect", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Options)
        -- The function that takes place when the selected option is changed
        -- The variable (Options) is a table of strings for the current selected options
        end,
    })
    local selectedMutationForAutoCollect = {}
    local dropdown_selectedFruitMutationForAutoCollect = Plants:CreateDropdown({
        Name = "Select Mutation",
        Options = mutationNameList,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "selectedFruitMutation_autoCollect", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Options)
            selectedMutationForAutoCollect = Options
        end,
    })
    local searchDebounce_fruitMutation = nil
    Plants:CreateInput({
        Name = "Search mutation",
        PlaceholderText = "mutation",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_fruitMutation then
                task.cancel(searchDebounce_fruitMutation)
            end
            searchDebounce_fruitMutation = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = mutationNameList
                else
                    for _, mutationName in ipairs(mutationNameList) do
                        if string.find(string.lower(mutationName), query, 1, true) then
                            table.insert(results, mutationName)
                        end
                    end
                end
                dropdown_selectedFruitMutationForAutoCollect:Refresh(results)
                dropdown_selectedFruitMutationForAutoCollect:Set(selectedMutationForAutoCollect) --set to current selected

            end)
        end,
    })
    Plants:CreateButton({
        Name = "Clear mutation",
        Callback = function()
            dropdown_selectedFruitMutationForAutoCollect:Set({})
        end,
    })
    local dropdown_selectedFruitKGmodeForAutoCollect = Plants:CreateDropdown({
        Name = "Below kg or Above kg",
        Options = {"Below", "Above"},
        CurrentOption = {"Below"},
        MultipleOptions = false,
        Flag = "selectedFruitBelowOrAbove_autoCollect", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Options)
        -- The function that takes place when the selected option is changed
        -- The variable (Options) is a table of strings for the current selected options
        end,
    })
    local dropdown_selectedFruitKGForAutoCollect = Plants:CreateInput({
        Name = "KG",
        CurrentValue = "",
        PlaceholderText = "number",
        RemoveTextAfterFocusLost = false,
        Flag = "autoCollect_kg",
        Callback = function(Text)
        -- The function that takes place when the input is changed
        -- The variable (Text) is a string for the value in the text box
        end,
    })
    local dropdown_delayToCollectFruits = Plants:CreateInput({
        Name = "Delay to Collect",
        CurrentValue = "0",
        PlaceholderText = "number",
        RemoveTextAfterFocusLost = false,
        Flag = "delayToCollectFruits",
        Callback = function(Text)
        -- The function that takes place when the input is changed
        -- The variable (Text) is a string for the value in the text box
        end,
    })

    local function teleportToNPC(npcName)
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
        local npc = workspace:WaitForChild("NPCS"):WaitForChild(npcName)
        local baseCFrame
        if npc.PrimaryPart then
            baseCFrame = npc.PrimaryPart.CFrame
        else
            baseCFrame = npc:GetPivot()
        end
        local offset = baseCFrame.LookVector * 6 + Vector3.new(0, 4, 0)
        hrp.CFrame = baseCFrame + offset
        return hrp
    end

    local function autoSellWhenFull()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
        local originalCFrame = hrp.CFrame
        teleportToNPC("Steven")
        task.wait(1)
        local success = pcall(function()
            local args = {}
            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("Sell_Inventory", 9e9):FireServer(unpack(args))
        end)
        if success then
            task.wait(0.5)
            hrp.CFrame = originalCFrame
        end
    end

    local autoSellWhenFullEnabled = false
    local autoSellWhenFullThread = nil
    Plants:CreateToggle({
        Name = "Auto Sell All fruits When Full",
        CurrentValue = false,
        Flag = "autoSellWhenFull",
        Callback = function(Value)
            autoSellWhenFullEnabled = Value

            if autoSellWhenFullEnabled then
                if autoSellWhenFullThread then
                    return
                end
                autoSellWhenFullThread = task.spawn(function()
                    while autoSellWhenFullEnabled do
                        if maxFruitInBagAutoSellTrigger then
                            maxFruitInBagAutoSellTrigger = false
                            autoSellWhenFull()
                        end
                        task.wait(2) 
                    end
                    autoSellWhenFullThread = nil
                end)
            else
                autoSellWhenFullEnabled = false
                if autoSellWhenFullThread then
                    autoSellWhenFullThread = nil
                end
            end
        end,
    })


    local toggle_stopCollectWhenFUll = Plants:CreateToggle({
        Name = "Stop collect when full (collect again after 1 min)",
        CurrentValue = false,
        Flag = "stopCollectWhenFull",
        Callback = function(Value)
        end,
    })

    local autoCollectFruitEnabled = false
    local autoCollectFruitThread = nil
    Plants:CreateToggle({
        Name = "Auto Collect Fruit",
        CurrentValue = false,
        Flag = "autoCollectFruit",
        Callback = function(Value)
            autoCollectFruitEnabled = Value

            if autoCollectFruitEnabled then
                maxFruitInBag = false
                if autoCollectFruitThread then
                    return
                end

                -- Gather current selections
                -- local fruits = dropdown_selectedFruitForAutoCollect.CurrentOption or {}
                -- local variants = dropdown_selectedFruitVariantForAutoCollect.CurrentOption or {}
                -- local mutations = dropdown_selectedFruitMutationForAutoCollect.CurrentOption or {}
                -- local kgMode = dropdown_selectedFruitKGmodeForAutoCollect.CurrentOption or {"Below"}
                -- local kgValue = tonumber(dropdown_selectedFruitKGForAutoCollect.CurrentValue or 0)

                --with retry logic
                local fruits
                local variants
                local mutations
                local kgMode
                local kgValue
                local delayToCollect
                local waited = 0
                while waited < 5 do
                    fruits = dropdown_selectedFruitForAutoCollect and dropdown_selectedFruitForAutoCollect.CurrentOption
                    kgValue = dropdown_selectedFruitKGForAutoCollect and tonumber(dropdown_selectedFruitKGForAutoCollect.CurrentValue)
                    delayToCollect = dropdown_delayToCollectFruits and tonumber(dropdown_delayToCollectFruits.CurrentValue)
                    if typeof(fruits) == "table" and typeof(kgValue) == "number" then
                        break
                    end
                    task.wait(0.5)
                    waited += 0.5
                end
                fruits = typeof(fruits) == "table" and fruits or {}
                variants = dropdown_selectedFruitVariantForAutoCollect and dropdown_selectedFruitVariantForAutoCollect.CurrentOption or {}
                mutations = dropdown_selectedFruitMutationForAutoCollect and dropdown_selectedFruitMutationForAutoCollect.CurrentOption or {}
                kgMode = dropdown_selectedFruitKGmodeForAutoCollect and dropdown_selectedFruitKGmodeForAutoCollect.CurrentOption or {"Below"}
                kgValue = typeof(kgValue) == "number" and kgValue or 0
                delayToCollect = typeof(delayToCollect) == "number" and delayToCollect or 0 


                -- Input validation
                if #fruits == 0 then
                    beastHubNotify("Please select at least one fruit", "", 3)
                    autoCollectFruitEnabled = false
                    return
                elseif not kgValue or kgValue < 0 then
                    beastHubNotify("Please input a valid KG value", "", 3)
                    autoCollectFruitEnabled = false
                    return
                end

                -- Safe nils for variants and mutations
                if #variants == 0 then variants = {nil} end
                if #mutations == 0 then mutations = {nil} end

                beastHubNotify("Auto Collect Fruit running", "", 3)
                -- local myFarm = getMyFarm()
                local function hasMatchingMutation(fruitInstance, mutations)
                    if not mutations or #mutations == 0 or (mutations[1] == nil) then
                        return true -- no mutation filter selected, allow
                    end

                    for _, userMutation in ipairs(mutations) do
                        if fruitInstance:GetAttribute(userMutation) then
                            return true
                        end
                    end

                    return false
                end
                local function hasMatchingVariant(fruitInstance, variants)
                    if not variants or #variants == 0 or (variants[1] == nil) then
                        return true -- no variant filter selected, allow
                    end

                    local variantObj = fruitInstance:FindFirstChild("Variant")
                    if not variantObj then
                        return false -- no variant, cannot match
                    end

                    for _, userVariant in ipairs(variants) do
                        if variantObj.Value == userVariant then
                            return true
                        end
                    end

                    return false
                end
                local function kgAllowed(fruitInstance, kgMode, kgValue)
                    if not fruitInstance then return false end
                    if not kgMode or #kgMode == 0 or not kgValue or kgValue <= 0 then
                        return true -- no kg filter, allow by default
                    end

                    local weightObj = fruitInstance:FindFirstChild("Weight")
                    if not weightObj then
                        return false -- no weight info
                    end

                    local fruitWeight = tonumber(weightObj.Value)
                    if not fruitWeight then
                        return false -- invalid weight
                    end

                    local mode = kgMode[1]
                    if mode == "Above" then
                        return fruitWeight > kgValue
                    elseif mode == "Below" then
                        return fruitWeight < kgValue
                    else
                        return true -- unknown mode, default allow
                    end
                end

                -- local FruitCollectionController = require(game:GetService("ReplicatedStorage").Modules.FruitCollectionController)
                autoCollectFruitThread = task.spawn(function()
                    while autoCollectFruitEnabled do
                        if myFarm then
                            local timeout = 3
                            local important = myFarm:WaitForChild("Important", timeout)
                            local plantsFolder = important and important:WaitForChild("Plants_Physical", timeout)
                            local allPlants = plantsFolder and plantsFolder:GetChildren() or {}

                            for _, plant in ipairs(allPlants) do
                                if plant:IsA("Model") or plant:IsA("Folder") then
                                    local fruitsFolder = plant:FindFirstChild("Fruits")

                                    -- Multi-harvest
                                    if fruitsFolder then
                                        for _, fruitInstance in ipairs(fruitsFolder:GetChildren()) do
                                            if not autoCollectFruitEnabled then break end

                                            local curFruitName = fruitInstance.Name
                                            local variantAllowed = hasMatchingVariant(fruitInstance, variants)
                                            local mutationAllowed = hasMatchingMutation(fruitInstance, mutations)
                                            local isKgAllowed = kgAllowed(fruitInstance, kgMode, kgValue)
                                            local fruitMatch = (#fruits == 0) or (table.find(fruits, curFruitName) ~= nil)
                                            if fruitMatch and variantAllowed and mutationAllowed and isKgAllowed then
                                                if maxFruitInBag and toggle_stopCollectWhenFUll.CurrentValue == true then
                                                    task.wait(60)
                                                    maxFruitInBag = false
                                                end
                                                -- print("multi, match found")
                                                -- print(curFruitName)
                                                if fruitInstance:IsA("Model") then
                                                    local args = {
                                                        [1] = {
                                                            [1] = fruitInstance;
                                                        };
                                                    }
                                                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5):WaitForChild("Crops", 5):WaitForChild("Collect", 5):FireServer(unpack(args))
                                                end
                                                task.wait(delayToCollect)
                                            end
                                        end
                                    else
                                        -- Single-harvest
                                        local curFruitName = plant.Name
                                        local variantAllowed = hasMatchingVariant(plant, variants)
                                        local mutationAllowed = hasMatchingMutation(plant, mutations)
                                        local isKgAllowed = kgAllowed(plant, kgMode, kgValue)
                                        local fruitMatch = (#fruits == 0) or (table.find(fruits, curFruitName) ~= nil)
                                        if fruitMatch and variantAllowed and mutationAllowed and isKgAllowed then
                                            if maxFruitInBag and toggle_stopCollectWhenFUll.CurrentValue == true then
                                                task.wait(60)
                                                maxFruitInBag = false
                                            end
                                            -- print("single, match found")
                                            -- print(curFruitName)
                                            if plant:IsA("Model") then
                                                local args = {
                                                    [1] = {
                                                        [1] = plant;
                                                    };
                                                }
                                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5):WaitForChild("Crops", 5):WaitForChild("Collect", 5):FireServer(unpack(args))
                                                task.wait(delayToCollect)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(0.05)
                    end
                    autoCollectFruitThread = nil
                end)
            else
                autoCollectFruitEnabled = false
                autoCollectFruitThread = nil
                -- beastHubNotify("Auto Collect Fruit disabled", "", 3)
            end
        end,
    })
    Plants:CreateDivider()

    -- Auto Shovel
    Plants:CreateSection("Auto Shovel Plant")
    local selectedPlantsForAutoShovel = {}

    local dropdown_selectedPlantForAutoShovel = Plants:CreateDropdown({
        Name = "Select Plant",
        Options = allSeedsOnly, -- start empty, will refresh
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "selectedPlant_autoShovel",
        Callback = function(Options)
            selectedPlantsForAutoShovel = Options
        end,
    })
    local searchDebounce_shovel = nil
    Plants:CreateInput({
        Name = "Search plant",
        PlaceholderText = "plant",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_shovel then
                task.cancel(searchDebounce_shovel)
            end
            searchDebounce_shovel = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = allSeedsOnly
                else
                    for _, plantName in ipairs(allSeedsOnly) do
                        if string.find(string.lower(plantName), query, 1, true) then
                            table.insert(results, plantName)
                        end
                    end
                end
                dropdown_selectedPlantForAutoShovel:Refresh(results)
                dropdown_selectedPlantForAutoShovel:Set(selectedPlantsForAutoShovel) --set to current selected

            end)
        end,
    })
    Plants:CreateButton({
        Name = "Clear plant",
        Callback = function()
            dropdown_selectedPlantForAutoShovel:Set({})
        end,
    })

    local autoShovelPlantEnabled = false
    local autoShovelPlantThread = nil
    Plants:CreateToggle({
        Name = "Auto Shovel Plant",
        CurrentValue = false,
        Flag = "autoShovelPlant",
        Callback = function(Value)
            autoShovelPlantEnabled = Value

            if autoShovelPlantEnabled then
                if autoShovelPlantThread then return end
                autoShovelPlantThread = task.spawn(function()
                    while autoShovelPlantEnabled do
                        if myFarm and #selectedPlantsForAutoShovel > 0 then
                            local timeout = 3
                            local important = myFarm:WaitForChild("Important", timeout)
                            if not important then
                                task.wait(2)
                                continue
                            end
                            local plantsFolder = important:FindFirstChild("Plants_Physical")
                            if not plantsFolder then
                                task.wait(2)
                                continue
                            end

                            local allPlants = plantsFolder:GetChildren()

                            for _, plant in ipairs(allPlants) do
                                if plant:IsA("Model") or plant:IsA("Folder") then
                                    local curPlantName = plant.Name
                                    local plantMatch = table.find(selectedPlantsForAutoShovel, curPlantName) ~= nil
                                    if plantMatch then
                                        equipItemByExactName("Shovel [Destroy Plants]")
                                        task.wait(0.1)
                                        local args = {[1] = plant}
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5)
                                            :WaitForChild("Remove_Item", 5)
                                            :FireServer(unpack(args))
                                    end
                                end
                            end
                        end
                        task.wait(0.2) -- loop delay
                    end
                    autoShovelPlantThread = nil
                end)
            else
                autoShovelPlantEnabled = false
                if autoShovelPlantThread then
                    autoShovelPlantThread = nil
                end
            end
        end,
    })
    Plants:CreateDivider()

    local autoShovelSprinklerEnabled = false
    local autoShovelSprinklerThread = nil

    Plants:CreateToggle({
        Name = "Auto Shovel Sprinklers",
        CurrentValue = false,
        Flag = "autoShovelSprinklers",
        Callback = function(Value)
            autoShovelSprinklerEnabled = Value

            if autoShovelSprinklerEnabled then
                if autoShovelSprinklerThread then return end
                autoShovelSprinklerThread = task.spawn(function()
                    while autoShovelSprinklerEnabled do
                        if myFarm then
                            local timeout = 3
                            local important = myFarm:WaitForChild("Important", timeout)
                            if not important then
                                task.wait(0.5)
                                continue
                            end

                            local objectsFolder = important:FindFirstChild("Objects_Physical")
                            if not objectsFolder then
                                task.wait(0.5)
                                continue
                            end

                            for _, obj in ipairs(objectsFolder:GetChildren()) do
                                if string.find(obj.Name, "Sprinkler") then
                                    equipItemByExactName("Shovel [Destroy Plants]")
                                    task.wait(0.1)
                                    local args = {[1] = obj}
                                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5)
                                        :WaitForChild("DeleteObject", 5)
                                        :FireServer(unpack(args))
                                    task.wait(0.15)
                                end
                            end
                        end
                        task.wait(1)
                    end
                    autoShovelSprinklerThread = nil
                end)
            else
                autoShovelSprinklerEnabled = false
                if autoShovelSprinklerThread then
                    autoShovelSprinklerThread = nil
                end
            end
        end,
    })

    Plants:CreateDivider()

end

return M

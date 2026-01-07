local M = {}


function M.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, allSeedsData, allSeedsOnly, equipFruitById)
    local Event = Window:CreateTab("Event", "gift")

    Event:CreateSection("New Year Event")

    local function isMultiHarvest(seedName)
        if not allSeedsData then
            warn("[isMultiHarvest] allSeedsData is nil")
            return false
        end
        local seedData = allSeedsData[seedName]
        if not seedData then
            warn("[isMultiHarvest] No data found for seed:", seedName)
            return false
        end
        return seedData.HarvestType == "Multi"
    end

    local autoSpinEnabled = false
    local autoSpinThread = nil
    Event:CreateToggle({
        Name = "Auto Spin",
        CurrentValue = false,
        Flag = "autoSpin",
        Callback = function(Value)
            autoSpinEnabled = Value
            if autoSpinEnabled then
                if autoSpinThread then
                    return
                end
                autoSpinThread = task.spawn(function()
                    local rs = game:GetService("ReplicatedStorage")
                    local spinEvent = rs:WaitForChild("GameEvents", 5):WaitForChild("GardenGame", 5):WaitForChild("Spin", 5)
                    while autoSpinEnabled do
                        spinEvent:FireServer()
                        task.wait(2)
                    end
                    autoSpinThread = nil
                end)
            else
                autoSpinEnabled = false
                autoSpinThread = nil
            end
        end,
    })

    local function equipItemByNameV3(itemName) --for plants
        local player = game.Players.LocalPlayer
        local backpack = player:WaitForChild("Backpack")
        -- player.Character.Humanoid:UnequipTools()

        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name
                local cleaned = string.match(name, "^(.-)%s*%[X%d+%]$") or name
                if cleaned == itemName then
                    -- player.Character.Humanoid:UnequipTools()
                    player.Character.Humanoid:EquipTool(tool)
                    return true
                end
            end
        end
        return false
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

    local myFarm = getMyFarm()
    local function collectFruitWithCount(fruitType, targetCount)
        local collected = 0
        if not myFarm then
            return
        end
        local timeout = 3
        local important = myFarm:WaitForChild("Important", timeout)
        if not important then
            return
        end
        local plantsFolder = important:WaitForChild("Plants_Physical", timeout)
        if not plantsFolder then
            return
        end
        local allPlants = plantsFolder:GetChildren()
        for _, plant in ipairs(allPlants) do
            if not (plant:IsA("Model") or plant:IsA("Folder")) then
                continue
            end
            local fruitsFolder = plant:FindFirstChild("Fruits")
            if fruitsFolder then
                for _, fruitInstance in ipairs(fruitsFolder:GetChildren()) do
                    if fruitInstance.Name == fruitType then
                        if fruitInstance:IsA("Model") then
                            local args = {
                                [1] = {
                                    [1] = fruitInstance
                                }
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5):WaitForChild("Crops", 5):WaitForChild("Collect", 5):FireServer(unpack(args))
                            collected = collected + 1
                            if collected >= targetCount then
                                return collected
                            end
                        end
                        task.wait(0.01)
                    end
                end
            else
                if plant.Name == fruitType then
                    if plant:IsA("Model") then
                        local args = {
                            [1] = {
                                [1] = plant
                            }
                        }
                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5):WaitForChild("Crops", 5):WaitForChild("Collect", 5):FireServer(unpack(args))
                        collected = collected + 1
                        if collected >= targetCount then
                            return collected
                        end
                    end
                    task.wait(0.01)
                end
            end
        end
        return collected
    end



    local function plantFruitWithCount(fruitType, targetCount)
        local spawnCFrame = getFarmSpawnCFrame()
        local offset = Vector3.new(8, 0, -50)
        local dropPos = spawnCFrame:PointToWorldSpace(offset)
        local seedName = fruitType .. " Seed"
        equipItemByNameV3(seedName)
        for i = 1, targetCount do
            local args = {
                [1] = dropPos,
                [2] = fruitType
            }
            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("Plant_RE", 9e9):FireServer(unpack(args))
            task.wait(0.1)
        end
    end

    local function getPlantCountByName(plantName)
        local myFarm = getMyFarm()
        if not myFarm then
            warn("[getPlantCountByName] myFarm is nil")
            return 0
        end

        local important = myFarm:FindFirstChild("Important")
        if not important then
            warn("[getPlantCountByName] Important folder not found")
            return 0
        end

        local plantsFolder = important:FindFirstChild("Plants_Physical")
        if not plantsFolder then
            warn("[getPlantCountByName] Plants_Physical folder not found")
            return 0
        end

        local count = 0
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if plant:IsA("Model") or plant:IsA("Folder") then
                if plant.Name == plantName then
                    count = count + 1
                end
            end
        end

        return count
    end

    local function shovelByFruitName(fruitName, shovelCount)
        if not myFarm or shovelCount <= 0 then return end

        local important = myFarm:FindFirstChild("Important")
        if not important then
            warn("[shovelByFruitName] Important folder not found")
            return
        end

        local plantsFolder = important:FindFirstChild("Plants_Physical")
        if not plantsFolder then
            warn("[shovelByFruitName] Plants_Physical folder not found")
            return
        end

        local allPlants = plantsFolder:GetChildren()
        local shovelsDone = 0

        for _, plant in ipairs(allPlants) do
            if shovelsDone >= shovelCount then
                break
            end

            if plant:IsA("Model") or plant:IsA("Folder") then
                local curPlantName = plant.Name
                if curPlantName == fruitName then
                    equipItemByExactName("Shovel [Destroy Plants]")
                    task.wait(0.1)
                    local args = {[1] = plant}
                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5)
                        :WaitForChild("Remove_Item", 5)
                        :FireServer(unpack(args))
                    shovelsDone = shovelsDone + 1
                end
            end
        end

        print(("[shovelByFruitName] Shoveled %d/%d %s"):format(shovelsDone, shovelCount, fruitName))
    end


    local function getPlayerData()
        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
        return dataService:GetData()
    end
    local function getGardenEventQuests()
        local playerData = getPlayerData()
        local questContainers = playerData.QuestContainers
        for containerId, data in pairs(questContainers) do
            if data.Tag == "GardenGames" then
                return containerId, data.Quests
            end
        end
        return nil, {}
    end

    local autoQuestHarvestEnabled = false
    local autoQuestHarvestThread = nil
    Event:CreateToggle({
        Name = "Auto Quest (Harvest)",
        CurrentValue = false,
        Flag = "autoQuestHarvest",
        Callback = function(Value)
            autoQuestHarvestEnabled = Value
            if autoQuestHarvestEnabled then
                if autoQuestHarvestThread then
                    return
                end
                autoQuestHarvestThread = task.spawn(function()
                    while autoQuestHarvestEnabled do
                        local containerId, quests = getGardenEventQuests()
                        for _, data in pairs(quests) do
                            if typeof(data) ~= "table" then
                                continue
                            end
                            if data.Completed == false and data.Type == "Harvest" then
                                local fruitTarget = data.Arguments and data.Arguments[1]
                                local harvestTarget = tonumber(data.Target) or 0
                                if fruitTarget and harvestTarget > 0 then
                                    local collectedAfter = collectFruitWithCount(fruitTarget, harvestTarget) or 0
                                    if not isMultiHarvest(fruitTarget) then
                                        local needToPlant = harvestTarget - collectedAfter
                                        if needToPlant > 0 then
                                            plantFruitWithCount(fruitTarget, needToPlant)
                                        end
                                    else
                                        local currentPlantCount = getPlantCountByName(fruitTarget)
                                        local needToPlant = 10 - currentPlantCount
                                        if needToPlant > 0 then
                                            plantFruitWithCount(fruitTarget, needToPlant)
                                        end
                                    end
                                end
                            end
                            if data.Completed == true and data.Claimed == false then
                                local args = {
                                    [1] = containerId,
                                    [2] = data.Id
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9)
                                    :WaitForChild("Quests", 9e9)
                                    :WaitForChild("Claim", 9e9)
                                    :FireServer(unpack(args))
                            end
                        end
                        task.wait(2)
                    end
                    autoQuestHarvestThread = nil
                end)
            else
                autoQuestHarvestEnabled = false
                autoQuestHarvestThread = nil
            end
        end,
    })



    local autoQuestPlantEnabled = false
    local autoQuestPlantThread = nil
    local autoPantQuestPlanted = 0
    Event:CreateToggle({
        Name = "Auto Quest (Plant)",
        CurrentValue = false,
        Flag = "autoQuestPlant",
        Callback = function(Value)
            autoQuestPlantEnabled = Value
            if autoQuestPlantEnabled then
                if autoQuestPlantThread then
                    return
                end
                autoQuestPlantThread = task.spawn(function()
                    while autoQuestPlantEnabled do
                        local containerId, quests = getGardenEventQuests()
                        for _, data in pairs(quests) do
                            if data.Completed == false and data.Type == "Plant" then
                                local fruitTarget = data.Arguments[1]
                                local plantTarget = data.Target
                                plantFruitWithCount(fruitTarget, plantTarget)
                                --auto shovel after plant multi harvest
                                if isMultiHarvest(fruitTarget) then
                                    autoPantQuestPlanted = plantTarget
                                    task.wait(2)
                                    shovelByFruitName(fruitTarget, autoPantQuestPlanted)
                                    autoPantQuestPlanted = 0
                                end
                                
                            end
                            if data.Completed == true and data.Claimed == false then
                                local args = {
                                    [1] = containerId,
                                    [2] = data.Id
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("Quests", 9e9):WaitForChild("Claim", 9e9):FireServer(unpack(args))
                            end
                        end
                        task.wait(2)
                    end
                    autoQuestPlantThread = nil
                end)
            else
                autoQuestPlantEnabled = false
                autoQuestPlantThread = nil
            end
        end,
    })


    

    Event:CreateDivider()

    -- --Event Shop
    Event:CreateSection("Event Shop")
    -- local parag_eventName = Event:CreateParagraph({Title = "Event Name:", Content = "None"})
    local curEventName
    local function getEventItems()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local dataTbl = require(ReplicatedStorage.Data.EventShopData)
        local listItems = {}

        for eventName,eventItems in pairs(dataTbl) do
            curEventName = eventName
            for itemName,itemData in pairs(eventItems) do
                local itemType = tostring(itemData.ItemType or "")
                local itemToType = itemName.." | "..itemType
                table.insert(listItems, itemToType)
                -- print(itemToType)
            end
        end

        return listItems
    end
    local allShopItems = getEventItems()
    task.wait()
    if #allShopItems > 0 then
        -- print("allShopItems have contents")
    else
        -- print("allShopItems nil")
    end

    local autoBuyEventLookup = {}
    local dropdown_eventShopItems = Event:CreateDropdown({
        Name = "Select Items",
        Options = allShopItems,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "autoBuyEventShopItems", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Options)
            -- parag_eventName:Set({Title = "Event Name:", Content = curEventName})
            if #Options > 0 then
                autoBuyEventLookup = {}
                for _, option in ipairs(Options) do
                    local curItemName = option:match("^(.-)%s*|")
                    if curItemName then
                        autoBuyEventLookup[curItemName] = true
                    end
                end
            end
        end,
    })

    Event:CreateButton({
        Name = "Clear",
        Callback = function()
            dropdown_eventShopItems:Set({})
            -- dropdown_eventShopItems:Refresh(allShopItems)
        end,
    })

    local allowShopBuy = {"New Years Shop"} --for multiple 
    local autoBuyEventShopEnabled = false
    local autoBuyEventShopThread = nil
    local toggle_autoBuyEventShop = Event:CreateToggle({ --OLD
        Name = "Auto Buy Event Shop (default ON)",
        CurrentValue = false,
        Flag = "autoBuyEventShopNew",
        Callback = function(Value)
            autoBuyEventShopEnabled = Value
            if autoBuyEventShopEnabled then
                if autoBuyEventShopThread then
                    return
                end
                -- beastHubNotify("Auto event shop check running","",3)
                autoBuyEventShopThread = task.spawn(function()
                    local function getPlayerData()
                        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        return dataService:GetData()
                    end
                    while autoBuyEventShopEnabled do
                        local listToBuy = dropdown_eventShopItems and dropdown_eventShopItems.CurrentOption or {}
                        if #listToBuy == 0 then
                            local waited = 0
                            while waited < 10 do
                                task.wait(0.5)
                                waited = waited + 0.5
                                listToBuy = dropdown_eventShopItems and dropdown_eventShopItems.CurrentOption or {}
                                if #listToBuy > 0 then
                                    break
                                end
                            end
                            if #listToBuy == 0 then
                                -- print("list to buy empty after retry")
                                continue
                            else
                                -- print("list to buy has value")
                            end
                        end

                        local playerData = getPlayerData()
                        local eventStock = playerData and playerData.EventShopStock
                        if eventStock then
                            for eventName, eventData in pairs(eventStock) do
                                if eventName == curEventName or #allowShopBuy > 0 then
                                    local stocks = eventData.Stocks
                                    if stocks then
                                        for itemName, stockData in pairs(stocks) do
                                            local curStock = stockData.Stock
                                            if curStock and curStock > 0 then
                                                if autoBuyEventLookup[itemName] == true then
                                                    for i = 1, curStock do
                                                        local args = {
                                                            [1] = itemName,
                                                            [2] = curEventName
                                                        }
                                                        game:GetService("ReplicatedStorage").GameEvents.BuyEventShopStock:FireServer(unpack(args))
                                                        task.wait(0.15)
                                                        --for allow buy
                                                        if #allowShopBuy > 0 then
                                                            for _, allowBuy in ipairs(allowShopBuy) do
                                                                local args = {
                                                                    [1] = itemName,
                                                                    [2] = allowBuy
                                                                }
                                                                game:GetService("ReplicatedStorage").GameEvents.BuyEventShopStock:FireServer(unpack(args))
                                                                task.wait(0.15)
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(2)
                    end
                    autoBuyEventShopThread = nil
                end)
            else
                autoBuyEventShopEnabled = false
                autoBuyEventShopThread = nil
            end
        end,
    })
    Event:CreateDivider()

    

    --bring back
    Event:CreateButton({
        Name = "Show New Event platform",
        Callback = function()
            -- local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local newEvent = game:GetService("ReplicatedStorage").Modules.UpdateService.GardenGames
            newEvent.Parent = workspace

            local oldEvent = workspace.Interaction["New Year's Event"]
            oldEvent.Parent = nil
        end,
    })
    Event:CreateDivider()
end

return M

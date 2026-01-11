local M = {}


function M.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, allSeedsData, allSeedsOnly, equipFruitById)
    local Event = Window:CreateTab("Event", "gift")

    Event:CreateSection("Auto Feed Event")

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

    local selectedFruitsForAutoFeed = {}
    local dropdown_selectedFruitForAutoFeed = Event:CreateDropdown({
        Name = "Select Fruit",
        Options = allSeedsOnly,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "selectedFruit_autoFeed_event",
        Callback = function(Options)
            selectedFruitsForAutoFeed = Options
        end
    })
    local searchDebounce_seedForFeed = nil
    Event:CreateInput({
        Name = "Search fruit",
        PlaceholderText = "fruit",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_seedForFeed then
                task.cancel(searchDebounce_seedForFeed)
            end
            searchDebounce_seedForFeed = task.delay(0.5, function()
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
                dropdown_selectedFruitForAutoFeed:Refresh(results)
                dropdown_selectedFruitForAutoFeed:Set(selectedFruitsForAutoFeed)
            end)
        end
    })
    Event:CreateButton({
        Name = "Clear fruit",
        Callback = function()
            dropdown_selectedFruitForAutoFeed:Set({})
        end
    })
    local autoSpinEnabled = false
    local autoSpinThread = nil
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local function getPlayerData()
        local dataService = require(ReplicatedStorage.Modules.DataService)
        return dataService:GetData()
    end

    local function getFeedFruitUid2(playerData, selectedFruits)
        if not playerData or not playerData.InventoryData then
            return nil
        end
        for uid, item in pairs(playerData.InventoryData) do
            if item.ItemType == "Holdable" then
                local itemData = item.ItemData
                if itemData and not itemData.IsFavorite then
                    if table.find(selectedFruits, itemData.ItemName) then
                        return uid
                    end
                end
            elseif item.ItemType == "Food" then
                local ingredients = item.ItemData and item.ItemData.Ingredients
                if ingredients then
                    for ingUid, ing in pairs(ingredients) do
                        if ing.ItemType == "Holdable" then
                            local ingData = ing.ItemData
                            if ingData and not ingData.IsFavorite then
                                if table.find(selectedFruits, ingData.ItemName) then
                                    return ingUid
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end


    Event:CreateToggle({
        Name = "Auto Feed Event Pet",
        CurrentValue = false,
        Flag = "autoSpin",
        Callback = function(Value)
            autoSpinEnabled = Value
            if autoSpinEnabled then
                if autoSpinThread then
                    return
                end
                autoSpinThread = task.spawn(function()
                    while autoSpinEnabled do
                        local serverPetMover = workspace:FindFirstChild("PetsPhysical") and workspace.PetsPhysical:FindFirstChild("ServerPetMover")
                        if serverPetMover then
                            local serverPetModel
                            for _, v in ipairs(serverPetMover:GetChildren()) do
                                if v:IsA("Model") then
                                    serverPetModel = v
                                    break
                                end
                            end
                            if serverPetModel then
                                if selectedFruitsForAutoFeed and #selectedFruitsForAutoFeed > 0 then
                                    local playerData = getPlayerData()
                                    if playerData then
                                        local fruitUid = getFeedFruitUid2(playerData, selectedFruitsForAutoFeed)
                                        if fruitUid then
                                            equipFruitById(fruitUid)
                                            task.wait()
                                            local args = {
                                                [1] = "FeedServerPet",
                                                [2] = serverPetModel.Name
                                            }
                                            ReplicatedStorage:WaitForChild("GameEvents", 5):WaitForChild("ActivePetService", 5):FireServer(unpack(args))
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(2)
                    end
                    autoSpinThread = nil
                end)
            else
                autoSpinEnabled = false
                autoSpinThread = nil
            end
        end
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
    -- Event:CreateButton({
    --     Name = "Show New Event platform",
    --     Callback = function()
    --         -- local ReplicatedStorage = game:GetService("ReplicatedStorage")
    --         local newEvent = game:GetService("ReplicatedStorage").Modules.UpdateService.GardenGames
    --         newEvent.Parent = workspace

    --         local oldEvent = workspace.Interaction["New Year's Event"]
    --         oldEvent.Parent = nil
    --     end,
    -- })
    -- Event:CreateDivider()
end

return M

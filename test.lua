-- Auto Trade Script
-- Only confirms after partner clicks Accept (AcceptNegotiation)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))

local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade")
local RefreshProfile = API:WaitForChild("PlayerProfileAPI/RefreshProfile")
local SendQuickChat = API:WaitForChild("TradeAPI/SendQuickChat")
local SuggestionAdded = API:WaitForChild("TradeAPI/SuggestionAdded")
local SuggestionRemoved = API:WaitForChild("TradeAPI/SuggestionRemoved")

-- This fires to YOUR client when the PARTNER accepts negotiation
local TradeReactedTo = API:WaitForChild("TradeAPI/TradeReactedTo")

local ClientData = Fsys.load("ClientData")

local ITEM_KIND = "sandwich-default"

local currentSender = nil
local partnerHasItem = false
local remindThread = nil

local function findSandwichId()
    local ok, inventory = pcall(function()
        return ClientData.get("inventory")
    end)
    if not ok or not inventory or not inventory.food then return nil end
    for id, item in pairs(inventory.food) do
        if tostring(item.kind) == ITEM_KIND then
            return tostring(id)
        end
    end
    return nil
end

local function cancelRemindThread()
    if remindThread then
        task.cancel(remindThread)
        remindThread = nil
    end
end

local function startRemindLoop()
    cancelRemindThread()
    remindThread = task.spawn(function()
        while currentSender and not partnerHasItem do
            task.wait(8)
            if not currentSender or partnerHasItem then break end
            pcall(function() SendQuickChat:FireServer("Please add an item to the trade!") end)
            print("[TradeScript] Reminded partner to add an item.")
        end
    end)
end

-- Partner added item
SuggestionAdded.OnClientEvent:Connect(function(...)
    if not currentSender then return end
    partnerHasItem = true
    cancelRemindThread()
    print("[TradeScript] Partner added an item — waiting for them to accept...")
end)

-- Partner removed item
SuggestionRemoved.OnClientEvent:Connect(function(...)
    if not currentSender then return end
    partnerHasItem = false
    print("[TradeScript] Partner removed their item.")
    pcall(function() SendQuickChat:FireServer("Please add an item to the trade!") end)
    startRemindLoop()
end)

-- Partner clicked Accept — NOW we accept and confirm
TradeReactedTo.OnClientEvent:Connect(function(...)
    if not currentSender then return end
    if not partnerHasItem then
        print("[TradeScript] Partner accepted but has no item — ignoring.")
        return
    end

    print("[TradeScript] Partner accepted! Accepting and confirming...")
    cancelRemindThread()

    task.wait(0.5)

    -- Accept negotiation on our side
    local ok1 = pcall(function() AcceptNegotiation:FireServer() end)
    print("[TradeScript] AcceptNegotiation: " .. tostring(ok1))

    task.wait(0.8)

    -- Refresh profile then confirm
    pcall(function() RefreshProfile:InvokeServer(currentSender) end)
    task.wait(0.5)

    local ok2 = pcall(function() ConfirmTrade:FireServer() end)
    print("[TradeScript] ConfirmTrade: " .. tostring(ok2))

    print("[TradeScript] Trade complete with: " .. tostring(currentSender.Name))
    currentSender = nil
    partnerHasItem = false
end)

print("[TradeScript] Ready — waiting for trades...")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade from: " .. tostring(sender.Name))

    currentSender = sender
    partnerHasItem = false
    cancelRemindThread()

    task.wait(0.5)

    -- Accept trade request
    local ok1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)
    if not ok1 then
        warn("[TradeScript] Failed to accept: " .. tostring(err1))
        currentSender = nil
        return
    end
    print("[TradeScript] Accepted trade with: " .. sender.Name)

    task.wait(0.5)

    -- Add sandwich
    local itemId = findSandwichId()
    if not itemId then
        warn("[TradeScript] No sandwich found.")
        currentSender = nil
        return
    end

    local ok2, err2 = pcall(function()
        AddItemToOffer:FireServer(itemId)
    end)
    if ok2 then
        print("[TradeScript] Sandwich added! ID: " .. itemId)
    else
        warn("[TradeScript] Failed to add: " .. tostring(err2))
        currentSender = nil
        return
    end

    task.wait(0.3)
    pcall(function() SendQuickChat:FireServer("Please add an item to the trade!") end)
    startRemindLoop()

    print("[TradeScript] Waiting for partner to add item and accept...")
end)

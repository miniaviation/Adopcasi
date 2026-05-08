-- Auto Trade Script
-- Detects partner accepting via ClientData trade state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))

local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade")
local RefreshProfile = API:WaitForChild("PlayerProfileAPI/RefreshProfile")
local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local SendQuickChat = API:WaitForChild("TradeAPI/SendQuickChat")
local SuggestionAdded = API:WaitForChild("TradeAPI/SuggestionAdded")
local SuggestionRemoved = API:WaitForChild("TradeAPI/SuggestionRemoved")

local ClientData = Fsys.load("ClientData")
local LocalPlayer = game:GetService("Players").LocalPlayer

local ITEM_KIND = "sandwich-default"

local currentSender = nil
local partnerHasItem = false
local confirmed = false
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

local function cancelRemind()
    if remindThread then
        task.cancel(remindThread)
        remindThread = nil
    end
end

local function startRemindLoop()
    cancelRemind()
    remindThread = task.spawn(function()
        while currentSender and not partnerHasItem do
            task.wait(8)
            if not currentSender or partnerHasItem then break end
            pcall(function() SendQuickChat:FireServer("Please add an item to the trade!") end)
            print("[TradeScript] Reminded partner to add an item.")
        end
    end)
end

local function doConfirm()
    if confirmed or not currentSender then return end
    confirmed = true
    cancelRemind()

    local sender = currentSender
    print("[TradeScript] Partner accepted! Confirming trade...")

    task.wait(0.5)
    pcall(function() RefreshProfile:InvokeServer(sender) end)
    task.wait(0.3)
    pcall(function() AcceptNegotiation:FireServer() end)
    task.wait(0.8)
    pcall(function() ConfirmTrade:FireServer() end)

    print("[TradeScript] Trade confirmed with: " .. tostring(sender.Name))
    currentSender = nil
    partnerHasItem = false
    confirmed = false
end

-- Watch trade state via ClientData — same way the game does internally
ClientData.register_callback_plus_existing("trade", function(newState, oldState)
    if not currentSender then return end
    if not newState then return end

    -- Figure out which offer is the partner's
    local partnerOffer
    if newState.sender == LocalPlayer then
        partnerOffer = newState.recipient_offer
    else
        partnerOffer = newState.sender_offer
    end

    if partnerOffer and partnerOffer.negotiated then
        print("[TradeScript] Detected partner accepted negotiation!")
        if partnerHasItem then
            doConfirm()
        else
            print("[TradeScript] Partner accepted but no item — waiting for item first.")
        end
    end
end)

-- Partner added item
SuggestionAdded.OnClientEvent:Connect(function()
    if not currentSender then return end
    partnerHasItem = true
    cancelRemind()
    print("[TradeScript] Partner added an item.")

    -- Check if they already accepted too
    local ok, tradeState = pcall(function()
        return ClientData.get("trade")
    end)
    if ok and tradeState then
        local partnerOffer = if tradeState.sender == LocalPlayer then tradeState.recipient_offer else tradeState.sender_offer
        if partnerOffer and partnerOffer.negotiated then
            print("[TradeScript] Partner already accepted — confirming now!")
            doConfirm()
        end
    end
end)

-- Partner removed item
SuggestionRemoved.OnClientEvent:Connect(function()
    if not currentSender then return end
    partnerHasItem = false
    print("[TradeScript] Partner removed item.")
    pcall(function() SendQuickChat:FireServer("Please add an item to the trade!") end)
    startRemindLoop()
end)

print("[TradeScript] Ready — watching for trades...")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade from: " .. tostring(sender.Name))

    currentSender = sender
    partnerHasItem = false
    confirmed = false
    cancelRemind()

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

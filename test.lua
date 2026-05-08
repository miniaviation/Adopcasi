-- Auto Trade Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local LocalPlayer = game:GetService("Players").LocalPlayer

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

local ITEM_KIND = "sandwich-default"
local currentSender = nil
local partnerHasItem = false
local confirmed = false
local remindThread = nil

-- Mirrors the notification script's tracking variables
local lastTradeId = nil
local lastPartnerNegotiated = false

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
            print("[TradeScript] Reminded partner.")
        end
    end)
end

local function doConfirm()
    if confirmed or not currentSender then return end
    confirmed = true
    cancelRemind()
    local sender = currentSender
    print("[TradeScript] Confirming trade with: " .. tostring(sender.Name))

    task.wait(0.5)
    pcall(function() RefreshProfile:InvokeServer(sender) end)
    task.wait(0.3)

    -- Accept our side of negotiation first
    pcall(function() AcceptNegotiation:FireServer() end)
    print("[TradeScript] Accepted negotiation.")
    task.wait(1)

    -- Then confirm
    pcall(function() ConfirmTrade:FireServer() end)
    print("[TradeScript] Trade confirmed!")

    currentSender = nil
    partnerHasItem = false
    confirmed = false
    lastTradeId = nil
    lastPartnerNegotiated = false
end

-- Mirrors the notification script's ClientData trade watcher exactly
ClientData.register_callback_plus_existing("trade", function(newState)
    if newState == nil then
        lastTradeId = nil
        lastPartnerNegotiated = false
        return
    end

    -- Reset tracking on new trade so old state can't bleed in
    if newState.trade_id ~= lastTradeId then
        lastTradeId = newState.trade_id
        lastPartnerNegotiated = false
    end

    -- Determine partner offer the same way _get_partner_offer does in source
    local isLocalSender = newState.sender == LocalPlayer
    local partnerOffer = isLocalSender and newState.recipient_offer or newState.sender_offer

    if not partnerOffer then return end

    local partnerNegotiated = partnerOffer.negotiated == true

    -- Only fire when partner JUST flipped to accepted this callback
    if partnerNegotiated and not lastPartnerNegotiated then
        lastPartnerNegotiated = true
        print("[TradeScript] Partner accepted negotiation!")
        if currentSender then
            if partnerHasItem then
                doConfirm()
            else
                print("[TradeScript] Partner accepted but no item yet — waiting...")
            end
        end
    elseif not partnerNegotiated then
        lastPartnerNegotiated = false
    end
end)

-- Partner added item
SuggestionAdded.OnClientEvent:Connect(function()
    if not currentSender then return end
    partnerHasItem = true
    cancelRemind()
    print("[TradeScript] Partner added item.")

    task.wait(0.2) -- let state settle
    local ok, tradeState = pcall(function() return ClientData.get("trade") end)
    if ok and tradeState then
        local isLocalSender = tradeState.sender == LocalPlayer
        local partnerOffer = isLocalSender and tradeState.recipient_offer or tradeState.sender_offer
        if partnerOffer and partnerOffer.negotiated == true then
            print("[TradeScript] Partner already accepted — confirming!")
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
    lastPartnerNegotiated = false
    cancelRemind()

    task.wait(0.5)

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

-- Auto Trade Script
-- Waits for partner to add item before accepting, reminds them if they haven't

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local API = ReplicatedStorage:WaitForChild("API")

local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade")
local RefreshProfile = API:WaitForChild("PlayerProfileAPI/RefreshProfile")
local SuggestionAdded = API:WaitForChild("TradeAPI/SuggestionAdded")
local SuggestionRemoved = API:WaitForChild("TradeAPI/SuggestionRemoved")
local SendQuickChat = API:WaitForChild("TradeAPI/SendQuickChat")

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local ClientData = Fsys.load("ClientData")

local ITEM_KIND = "sandwich-default"
local STABLE_TIME = 5 -- seconds after partner adds item before confirming
local REMIND_INTERVAL = 8 -- seconds between reminders

local currentSender = nil
local partnerAddedItem = false
local confirmThread = nil
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

local function sendChat(message)
    pcall(function()
        SendQuickChat:FireServer(message)
    end)
    print("[TradeScript] Sent chat: " .. message)
end

local function cancelTimers()
    if confirmThread then task.cancel(confirmThread) confirmThread = nil end
    if remindThread then task.cancel(remindThread) remindThread = nil end
end

local function startConfirmTimer()
    if confirmThread then task.cancel(confirmThread) confirmThread = nil end

    confirmThread = task.delay(STABLE_TIME, function()
        if not currentSender or not partnerAddedItem then return end
        print("[TradeScript] Offer stable — confirming trade...")

        pcall(function() RefreshProfile:InvokeServer(currentSender) end)
        task.wait(0.5)
        pcall(function() AcceptNegotiation:FireServer() end)
        task.wait(0.8)
        pcall(function() ConfirmTrade:FireServer() end)

        print("[TradeScript] Trade confirmed with: " .. tostring(currentSender.Name))
        cancelTimers()
        currentSender = nil
        partnerAddedItem = false
    end)
end

local function startRemindLoop()
    if remindThread then task.cancel(remindThread) remindThread = nil end

    remindThread = task.spawn(function()
        while currentSender and not partnerAddedItem do
            task.wait(REMIND_INTERVAL)
            if not currentSender or partnerAddedItem then break end
            print("[TradeScript] Partner hasnt added item yet — reminding...")
            sendChat("Please add an item to the trade!")
        end
    end)
end

-- Detect when partner adds an item
SuggestionAdded.OnClientEvent:Connect(function(...)
    if not currentSender then return end
    print("[TradeScript] Partner added an item!")

    partnerAddedItem = true

    -- Stop remind loop
    if remindThread then task.cancel(remindThread) remindThread = nil end

    -- Accept negotiation and start confirm timer
    task.wait(0.5)
    pcall(function() AcceptNegotiation:FireServer() end)
    print("[TradeScript] AcceptNegotiation fired.")
    startConfirmTimer()
end)

-- If partner removes their item, reset and remind again
SuggestionRemoved.OnClientEvent:Connect(function(...)
    if not currentSender then return end
    print("[TradeScript] Partner removed their item — waiting again...")

    partnerAddedItem = false
    cancelTimers()
    sendChat("Please add an item to the trade!")
    startRemindLoop()
end)

print("[TradeScript] Ready — watching for trades...")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade from: " .. tostring(sender.Name))

    currentSender = sender
    partnerAddedItem = false
    cancelTimers()

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

    -- Send initial reminder and start remind loop
    task.wait(0.5)
    sendChat("Please add an item to the trade!")
    startRemindLoop()

    print("[TradeScript] Waiting for partner to add an item...")
end)

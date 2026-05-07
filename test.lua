-- Auto Trade Script
-- Auto accepts trades, adds Sandwich, then confirms when other player accepts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local API = ReplicatedStorage:WaitForChild("API")

local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade")
local RefreshProfile = API:WaitForChild("PlayerProfileAPI/RefreshProfile")
local DataChanged = API:WaitForChild("DataAPI/DataChanged")

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local ClientData = Fsys.load("ClientData")

local ITEM_KIND = "sandwich-default"
local currentPartner = nil
local confirmed = false

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

local function confirmTrade(partner)
    if confirmed then return end
    confirmed = true

    print("[TradeScript] Confirming trade with: " .. tostring(partner.Name))

    task.wait(0.5)

    -- Step 1: Refresh partner profile
    local ok1 = pcall(function()
        RefreshProfile:InvokeServer(partner)
    end)
    print("[TradeScript] RefreshProfile: " .. tostring(ok1))

    task.wait(0.5)

    -- Step 2: Accept negotiation
    local ok2 = pcall(function()
        AcceptNegotiation:FireServer()
    end)
    print("[TradeScript] AcceptNegotiation: " .. tostring(ok2))

    task.wait(0.8)

    -- Step 3: Confirm trade
    local ok3 = pcall(function()
        ConfirmTrade:FireServer()
    end)
    print("[TradeScript] ConfirmTrade: " .. tostring(ok3))
end

-- Watch for partner accepting (DataChanged fires when trade state updates)
DataChanged.OnClientEvent:Connect(function(player, key)
    if not currentPartner then return end
    if confirmed then return end

    -- When partner's trade data changes they likely accepted
    if key == "trade" and player ~= Players.LocalPlayer then
        print("[TradeScript] Partner trade data changed — they accepted!")
        confirmTrade(currentPartner)
    end
end)

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade request from: " .. tostring(sender.Name))

    currentPartner = sender
    confirmed = false

    task.wait(0.5)

    -- Step 1: Accept trade request
    local ok1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)
    if not ok1 then
        warn("[TradeScript] Failed to accept: " .. tostring(err1))
        currentPartner = nil
        return
    end
    print("[TradeScript] Accepted trade with: " .. sender.Name)

    task.wait(0.5)

    -- Step 2: Add sandwich
    local itemId = findSandwichId()
    if not itemId then
        warn("[TradeScript] No sandwich found.")
        currentPartner = nil
        return
    end

    local ok2, err2 = pcall(function()
        AddItemToOffer:FireServer(itemId)
    end)
    if ok2 then
        print("[TradeScript] Sandwich added! ID: " .. itemId)
    else
        warn("[TradeScript] Failed to add: " .. tostring(err2))
    end

    -- Step 3: Wait for partner to accept then auto confirm
    print("[TradeScript] Waiting for partner to accept...")
end)

print("[TradeScript] Ready — watching for trades...")

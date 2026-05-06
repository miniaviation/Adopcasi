-- Auto Add Item To Offer Script
-- Fires after trade is accepted and adds a small food item to your offer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local ClientData = Fsys.load("ClientData")

local ITEM_KIND = "sandwich-default"

local function getItemId()
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

print("[OfferScript] Ready — will auto-add item when trade opens.")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[OfferScript] Trade opened with: " .. tostring(sender.Name))

    task.wait(0.5)

    local success1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)
    if success1 then
        print("[OfferScript] Trade accepted with: " .. sender.Name)
    else
        warn("[OfferScript] Failed to accept trade: " .. tostring(err1))
        return
    end

    task.wait(0.5)

    local ITEM_ID = getItemId()
    if not ITEM_ID then
        warn("[OfferScript] Could not find sandwich in inventory.")
        return
    end

    local success2, err2 = pcall(function()
        AddItemToOffer:FireServer(ITEM_ID)
    end)
    if success2 then
        print("[OfferScript] Item added to offer: " .. ITEM_ID)
    else
        warn("[OfferScript] Failed to add item: " .. tostring(err2))
    end
end)

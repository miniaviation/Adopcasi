-- Auto Add Item To Offer Script
-- Fires after trade is accepted and adds a small food item to your offer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API = ReplicatedStorage:WaitForChild("API")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation") -- confirms offer

-- Your item ID (replace with any small food item ID from your inventory)
local ITEM_ID = "2_9acd1bca3ca74fdcb4f08536792e8f6c"

local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")

print("[OfferScript] Ready — will auto-add item when trade opens.")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end

    print("[OfferScript] Trade opened with: " .. tostring(sender.Name))

    task.wait(0.5) -- Wait for trade window to open

    -- Accept the trade request first
    local success1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)

    if success1 then
        print("[OfferScript] Trade accepted with: " .. sender.Name)
    else
        warn("[OfferScript] Failed to accept trade: " .. tostring(err1))
        return
    end

    task.wait(0.5) -- Wait for trade session to register

    -- Add the item to your offer
    local success2, err2 = pcall(function()
        AddItemToOffer:FireServer(ITEM_ID)
    end)

    if success2 then
        print("[OfferScript] Item added to offer: " .. ITEM_ID)
    else
        warn("[OfferScript] Failed to add item: " .. tostring(err2))
    end
end)

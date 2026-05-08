-- LocalScript in StarterPlayerScripts

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- GUI
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

local function showNotif(partnerName)
    -- Always stamp the time at the exact moment of triggering
    label.Text = "✅ " .. partnerName .. " accepted!"
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

-- Hook into the game's own ClientData trade callback,
-- exactly how the TradeApp does it internally
local ok, Fsys = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Fsys", 5))
end)

if not ok or not Fsys then
    warn("Could not load Fsys")
    return
end

local ClientData = Fsys.load("ClientData")

local lastTradeId = nil
local lastPartnerNegotiated = false

-- This mirrors exactly how v1.register_callback_plus_existing("trade") works in the source
ClientData.register_callback_plus_existing("trade", function(_, newState)
    if newState == nil then
        -- Trade ended, reset everything
        lastTradeId = nil
        lastPartnerNegotiated = false
        return
    end

    -- New trade started — reset tracking so old state can't bleed in
    if newState.trade_id ~= lastTradeId then
        lastTradeId = newState.trade_id
        lastPartnerNegotiated = false
    end

    -- Determine partner offer the same way _get_partner_offer does in source:
    -- If LocalPlayer is sender → partner offer is recipient_offer
    -- If LocalPlayer is recipient → partner offer is sender_offer
    local isLocalSender = newState.sender == LocalPlayer
    local partnerOffer = isLocalSender and newState.recipient_offer or newState.sender_offer
    local partner = isLocalSender and newState.recipient or newState.sender

    if not partnerOffer or not partner then return end

    local partnerNegotiated = partnerOffer.negotiated == true

    -- Only fire if partner JUST flipped to accepted this callback
    if partnerNegotiated and not lastPartnerNegotiated then
        lastPartnerNegotiated = true
        task.spawn(showNotif, partner.Name)
    elseif not partnerNegotiated then
        lastPartnerNegotiated = false
    end
end)

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

ClientData.register_callback_plus_existing("trade", function(_, newState)
    if newState == nil then
        lastTradeId = nil
        lastPartnerNegotiated = false
        return
    end

    if newState.trade_id ~= lastTradeId then
        lastTradeId = newState.trade_id
        lastPartnerNegotiated = false
    end

    local isLocalSender = newState.sender == LocalPlayer
    local partnerOffer = isLocalSender and newState.recipient_offer or newState.sender_offer
    local partner = isLocalSender and newState.recipient or newState.sender

    if not partnerOffer or not partner then return end

    local partnerNegotiated = partnerOffer.negotiated == true

    if partnerNegotiated and not lastPartnerNegotiated then
        lastPartnerNegotiated = true

        -- Show notification
        task.spawn(showNotif, partner.Name)

        -- Fire AcceptNegotiation after partner accepted
        task.spawn(function()
            task.wait(0.3)
            local success, err = pcall(function()
                game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
            end)
            if success then
                print("[TradeScript] AcceptNegotiation fired after " .. partner.Name .. " accepted.")
            else
                warn("[TradeScript] Failed to fire AcceptNegotiation: " .. tostring(err))
            end
        end)

    elseif not partnerNegotiated then
        lastPartnerNegotiated = false
    end
end)

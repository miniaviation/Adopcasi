-- Executor version

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Remove old GUI if re-running the script
if LocalPlayer.PlayerGui:FindFirstChild("TradeStatusGui") then
    LocalPlayer.PlayerGui.TradeStatusGui:Destroy()
end

-- Create the GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeStatusGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Executors may need this to parent to CoreGui instead
pcall(function()
    screenGui.Parent = game:GetService("CoreGui")
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer.PlayerGui
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 70)
frame.Position = UDim2.new(0.5, -150, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.7
stroke.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -20, 1, 0)
label.Position = UDim2.new(0, 10, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = ""
label.Parent = frame

-- Notification logic
local hideThread = nil
local function showNotification(text, color)
    if hideThread then
        task.cancel(hideThread)
    end
    label.Text = text
    frame.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
    frame.Visible = true
    hideThread = task.delay(4, function()
        frame.Visible = false
    end)
end

-- Load RouterClient
local ok, RouterClient = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Fsys", 10)).load("RouterClient")
end)

if not ok or not RouterClient then
    warn("[TradeWatcher] Failed to load RouterClient:", RouterClient)
    return
end

-- Track previous state to avoid duplicate notifications
local prevNegotiated = false
local prevConfirmed = false

local function getPartnerData(tradeState)
    if not tradeState then return nil, nil end
    local isLocalSender = tradeState.sender == LocalPlayer
    local partnerOffer = isLocalSender and tradeState.recipient_offer or tradeState.sender_offer
    local partner = isLocalSender and tradeState.recipient or tradeState.sender
    local partnerName = partner and partner.Name or "Partner"
    return partnerOffer, partnerName
end

RouterClient.get_event("TradeAPI/TradeUpdated").OnClientEvent:Connect(function(tradeState)
    if not tradeState then
        -- Trade ended, reset tracking
        prevNegotiated = false
        prevConfirmed = false
        return
    end

    local partnerOffer, partnerName = getPartnerData(tradeState)
    if not partnerOffer then return end

    -- Partner accepted (negotiation phase)
    if partnerOffer.negotiated and not prevNegotiated then
        prevNegotiated = true
        showNotification("✅ " .. partnerName .. " accepted!", Color3.fromRGB(34, 139, 34))
    elseif not partnerOffer.negotiated then
        prevNegotiated = false
    end

    -- Partner confirmed (confirmation phase)
    if partnerOffer.confirmed and not prevConfirmed then
        prevConfirmed = true
        showNotification("🔒 " .. partnerName .. " confirmed!", Color3.fromRGB(30, 100, 200))
    elseif not partnerOffer.confirmed then
        prevConfirmed = false
    end
end)

print("[TradeWatcher] Running! Listening for trade events.")

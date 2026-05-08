-- Executor version (no require, hooks RemoteEvents directly)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Cleanup old GUI
local coreGui = game:GetService("CoreGui")
if coreGui:FindFirstChild("TradeStatusGui") then
    coreGui.TradeStatusGui:Destroy()
end

-- Build GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeStatusGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = coreGui

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

-- Track state
local prevNegotiated = false
local prevConfirmed = false

-- Find RemoteEvents by crawling the game tree
local function findRemote(name)
    -- Common locations Adopt Me uses
    local locations = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedStorage"):FindFirstChild("new"),
        game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"),
        game:GetService("ReplicatedStorage"):FindFirstChild("Events"),
    }
    for _, loc in ipairs(locations) do
        if loc then
            local found = loc:FindFirstChild(name, true) -- true = recursive search
            if found then
                return found
            end
        end
    end
    return nil
end

-- Hook a RemoteEvent safely
local function hookRemote(name, callback)
    task.spawn(function()
        local remote = findRemote(name)
        if remote then
            print("[TradeWatcher] Hooked:", name)
            remote.OnClientEvent:Connect(callback)
        else
            warn("[TradeWatcher] Could not find remote:", name)
        end
    end)
end

-- Hook trade state updates
hookRemote("TradeUpdated", function(tradeState)
    if not tradeState then
        prevNegotiated = false
        prevConfirmed = false
        return
    end

    local isLocalSender = tradeState.sender == LocalPlayer
    local partnerOffer = isLocalSender and tradeState.recipient_offer or tradeState.sender_offer
    local partner = isLocalSender and tradeState.recipient or tradeState.sender
    local partnerName = (partner and partner.Name) or "Partner"

    if not partnerOffer then return end

    if partnerOffer.negotiated and not prevNegotiated then
        prevNegotiated = true
        showNotification("✅ " .. partnerName .. " accepted!", Color3.fromRGB(34, 139, 34))
    elseif not partnerOffer.negotiated then
        prevNegotiated = false
    end

    if partnerOffer.confirmed and not prevConfirmed then
        prevConfirmed = true
        showNotification("🔒 " .. partnerName .. " confirmed!", Color3.fromRGB(30, 100, 200))
    elseif not partnerOffer.confirmed then
        prevConfirmed = false
    end
end)

-- Also hook AcceptNegotiation as a backup signal
hookRemote("AcceptNegotiation", function(player)
    if player and player ~= LocalPlayer then
        showNotification("✅ " .. player.Name .. " accepted!", Color3.fromRGB(34, 139, 34))
    end
end)

print("[TradeWatcher] Running!")

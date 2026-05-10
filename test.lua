local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local API_URL = "https://bloxwing.com/api/trade-log"
local API_KEY = "bloxwing-k9x2mT84nQpL31"

-- GUI to show result
local function showResult(text, color)
    local old = PlayerGui:FindFirstChild("TestGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TestGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true
    sg.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(420, 120)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, -50)
    lbl.Position = UDim2.new(0, 10, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
    lbl.TextSize = 15
    lbl.Font = Enum.Font.Gotham
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 32)
    btn.Position = UDim2.new(0, 10, 1, -40)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Text = "Close"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function() sg:Destroy() end)
end

-- Find request function
local requestFn = (syn and syn.request)
    or (http and http.request)
    or (http_request and http_request)
    or (request and request)

if not requestFn then
    showResult("❌ No HTTP function found!\nYour executor may not support HTTP requests.", Color3.fromRGB(255, 80, 80))
    return
end

local ok, response = pcall(function()
    return requestFn({
        Url = API_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = API_KEY,
        },
        Body = HttpService:JSONEncode({
            userId        = tostring(LocalPlayer.UserId),
            partnerId     = "123456",
            partnerName   = "TestPlayer",
            itemsReceived = {
                { kind = "frost_dragon", name = "Frost Dragon", category = "pets", properties = { neon = false, flyable = true, rideable = true } }
            },
            timestamp = os.time(),
        }),
    })
end)

if ok then
    local status = response.StatusCode or "nil"
    local body = response.Body or "nil"
    showResult("Status: " .. tostring(status) .. "\n\nBody: " .. tostring(body),
        status == 200 and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80))
else
    showResult("❌ pcall failed:\n" .. tostring(response), Color3.fromRGB(255, 80, 80))
end

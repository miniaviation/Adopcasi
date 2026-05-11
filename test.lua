local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/"
local TRADES_NODE = "trades"

-- ==================== FIREBASE REQUEST (exact style as test script) ====================
local function firebaseRequest(url, method, body)
    local requestFunc =
        (syn and syn.request) or
        (http and http.request) or
        (request) or
        (HttpService and function(o)
            return HttpService:RequestAsync(o)
        end)

    if not requestFunc then
        warn("❌ No valid HTTP function found for this executor!")
        return nil
    end

    return requestFunc({
        Url = url,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
end

-- ==================== SAVE TRADE ====================
local function saveTradeToFirebase(tradeData)
    local endpoint = FIREBASE_URL .. TRADES_NODE .. ".json"
    local payload = HttpService:JSONEncode(tradeData)

    local success, result = pcall(firebaseRequest, endpoint, "POST", payload)

    if success and result then
        if result.StatusCode == 200 or result.StatusCode == 201 then
            print("✅ Trade saved to Firebase!")
            print("👤 Player: " .. LocalPlayer.Name)
            print("📦 Response: " .. tostring(result.Body))
        else
            warn("❌ Status code: " .. tostring(result.StatusCode))
            warn("📄 Body: " .. tostring(result.Body))
        end
    else
        warn("❌ Request failed: " .. tostring(result))
    end
end

-- ==================== HELPERS ====================
local function getItemDB()
    local ok, db = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ItemDB")
    end)
    return ok and db or {}
end

local function getPartnerName(state)
    if state.sender == LocalPlayer then
        return state.recipient and state.recipient.Name or "Unknown"
    else
        return state.sender and state.sender.Name or "Unknown"
    end
end

local function getPartnerItems(state)
    if state.sender == LocalPlayer then
        return state.recipient_offer and state.recipient_offer.items or {}
    else
        return state.sender_offer and state.sender_offer.items or {}
    end
end

local function getMyItems(state)
    if state.sender == LocalPlayer then
        return state.sender_offer and state.sender_offer.items or {}
    else
        return state.recipient_offer and state.recipient_offer.items or {}
    end
end

local function formatItems(items, ItemDB)
    local formatted = {}
    for _, item in ipairs(items or {}) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local props = item.properties or {}
        table.insert(formatted, {
            name      = (itemData and itemData.name) or item.kind or "Unknown",
            kind      = item.kind or "unknown",
            category  = item.category or "unknown",
            neon      = props.neon or false,
            mega_neon = props.mega_neon or false,
            flyable   = props.flyable or false,
            rideable  = props.rideable or false,
        })
    end
    return formatted
end

-- ==================== GUI ====================
local function showGui(partnerName, items, ItemDB)
    local existing = PlayerGui:FindFirstChild("TradeResultGui")
    if existing then existing:Destroy() end

    local lines = {}
    for _, item in ipairs(items) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local name = (itemData and itemData.name) or item.kind or "Unknown"
        local tags = {}
        local props = item.properties or {}
        if props.mega_neon then table.insert(tags, "Mega Neon")
        elseif props.neon then table.insert(tags, "Neon") end
        if props.flyable then table.insert(tags, "Fly") end
        if props.rideable then table.insert(tags, "Ride") end
        local label = name
        if #tags > 0 then label = label .. " [" .. table.concat(tags, ", ") .. "]" end
        table.insert(lines, label)
    end
    if #lines == 0 then table.insert(lines, "No items") end

    local PADDING  = 16
    local TITLE_H  = 48
    local PARTNER_H = 32
    local ROW_H    = 30
    local BUTTON_H = 38
    local FRAME_W  = 340
    local totalH = PADDING + TITLE_H + PARTNER_H + 28 + (#lines * ROW_H) + 8 + BUTTON_H + PADDING

    local sg = Instance.new("ScreenGui")
    sg.Name = "TradeResultGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true
    sg.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(FRAME_W, totalH)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
    Instance.new("UIListLayout", frame).SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingLeft   = UDim.new(0, PADDING)
    pad.PaddingRight  = UDim.new(0, PADDING)
    pad.PaddingTop    = UDim.new(0, PADDING)
    pad.PaddingBottom = UDim.new(0, PADDING)

    local function makeLabel(text, size, color, height, bold, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, height)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextSize = size
        lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        lbl.Parent = frame
    end

    makeLabel("✔ Trade Complete!", 20, Color3.fromRGB(100, 200, 255), TITLE_H, true, 1)
    makeLabel("Traded with: " .. partnerName, 16, Color3.fromRGB(255, 220, 80), PARTNER_H, true, 2)
    makeLabel("They gave you:", 14, Color3.fromRGB(140, 140, 150), 28, false, 3)

    for i, line in ipairs(lines) do
        makeLabel(" • " .. line, 15, Color3.fromRGB(235, 235, 235), ROW_H, false, 10 + i)
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, BUTTON_H)
    btn.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
    btn.Text = "Close"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.LayoutOrder = 100
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function() sg:Destroy() end)
    task.delay(30, function() if sg and sg.Parent then sg:Destroy() end end)
end

-- ==================== MAIN ====================
task.spawn(function()
    local ok, ClientData = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    end)

    if not ok or not ClientData then
        warn("❌ Failed to load ClientData: " .. tostring(ClientData))
        return
    end

    local ItemDB = getItemDB()
    local lastTradeState = nil

    ClientData.register_callback_plus_existing("trade", function(_, newState)
        if newState == nil and lastTradeState ~= nil then
            local stage = tostring(lastTradeState.current_stage or "")

            if stage ~= "declined" and stage ~= "cancelled" then
                local partnerName  = getPartnerName(lastTradeState)
                local partnerItems = getPartnerItems(lastTradeState)
                local myItems      = getMyItems(lastTradeState)

                showGui(partnerName, partnerItems, ItemDB)

                saveTradeToFirebase({
                    player    = LocalPlayer.Name,
                    userId    = LocalPlayer.UserId,
                    partner   = partnerName,
                    gave      = formatItems(myItems, ItemDB),
                    received  = formatItems(partnerItems, ItemDB),
                    stage     = stage,
                    timestamp = os.time(),
                    date      = os.date("%Y-%m-%d %H:%M:%S"),
                    placeId   = game.PlaceId,
                })
            end
        end

        lastTradeState = newState
    end)

    print("✅ TradeLogger running")
end)

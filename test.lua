local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/trades.json"

local lastTradeState = nil

-- ==================== FIREBASE FUNCTION ====================
local function sendToFirebase(payload)
    local req = (syn and syn.request) or (http and http.request) or request or httprequest
    if not req then
        warn("[TradeLogger] ❌ No HTTP function found")
        return
    end

    local success, response = pcall(req, {
        Url = FIREBASE_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(payload)
    })

    if success and response and (response.StatusCode == 200 or response.StatusCode == 201) then
        print("✅ Trade successfully saved to Firebase")
    else
        warn("❌ Failed to save trade to Firebase")
        if response then
            warn("Status:", response.StatusCode)
            warn("Body:", response.Body)
        end
    end
end

-- ==================== HELPER FUNCTIONS ====================
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

local function getMyItems(state)
    if state.sender == LocalPlayer then
        return state.sender_offer and state.sender_offer.items or {}
    else
        return state.recipient_offer and state.recipient_offer.items or {}
    end
end

local function getPartnerItems(state)
    if state.sender == LocalPlayer then
        return state.recipient_offer and state.recipient_offer.items or {}
    else
        return state.sender_offer and state.sender_offer.items or {}
    end
end

local function formatItems(items, ItemDB)
    local formatted = {}
    for _, item in ipairs(items or {}) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        table.insert(formatted, {
            name = (itemData and itemData.name) or item.kind or "Unknown Item",
            kind = item.kind,
            category = item.category,
            unique = item.unique_id or item.id or "",
            neon = item.properties and item.properties.neon or false,
            mega_neon = item.properties and item.properties.mega_neon or false,
            flyable = item.properties and item.properties.flyable or false,
            rideable = item.properties and item.properties.rideable or false,
            age = item.properties and item.properties.age or "",
        })
    end
    return formatted
end

-- ==================== TRADE RESULT GUI ====================
local function showGui(partnerName, items, ItemDB)
    local existing = PlayerGui:FindFirstChild("TradeResultGui")
    if existing then existing:Destroy() end

    local lines = {}
    for _, item in ipairs(items) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local name = (itemData and itemData.name) or item.kind or "Unknown"
        local tags = {}
        if item.properties then
            if item.properties.mega_neon then table.insert(tags, "Mega Neon")
            elseif item.properties.neon then table.insert(tags, "Neon") end
            if item.properties.flyable then table.insert(tags, "Fly") end
            if item.properties.rideable then table.insert(tags, "Ride") end
        end
        local label = name
        if #tags > 0 then
            label = label .. " [" .. table.concat(tags, ", ") .. "]"
        end
        table.insert(lines, label)
    end
    if #lines == 0 then table.insert(lines, "No items") end

    local PADDING = 16
    local TITLE_H = 48
    local PARTNER_H = 32
    local DIVIDER_H = 8
    local ROW_H = 30
    local BUTTON_H = 38
    local FRAME_W = 340
    local totalH = PADDING + TITLE_H + PARTNER_H + DIVIDER_H + (#lines * ROW_H) + DIVIDER_H + BUTTON_H + PADDING

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
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 180, 255)
    stroke.Thickness = 2
    stroke.Parent = frame

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 0)
    list.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, PADDING)
    padding.PaddingRight = UDim.new(0, PADDING)
    padding.PaddingTop = UDim.new(0, PADDING)
    padding.PaddingBottom = UDim.new(0, PADDING)
    padding.Parent = frame

    local function makeLabel(text, textSize, color, height, bold, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, height)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextSize = textSize
        lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.LayoutOrder = order
        lbl.Parent = frame
        return lbl
    end

    local function makeDivider(order)
        local spacer = Instance.new("Frame")
        spacer.Size = UDim2.new(1, 0, 0, DIVIDER_H * 2 + 1)
        spacer.BackgroundTransparency = 1
        spacer.LayoutOrder = order
        spacer.Parent = frame
        local d = Instance.new("Frame")
        d.Size = UDim2.new(1, 0, 0, 1)
        d.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        d.BorderSizePixel = 0
        d.Position = UDim2.new(0, 0, 0.5, 0)
        d.Parent = spacer
        return spacer
    end

    makeLabel("✔ Trade Complete!", 20, Color3.fromRGB(100, 200, 255), TITLE_H, true, 1)
    
    -- Partner Row
    local partnerRow = Instance.new("Frame")
    partnerRow.Size = UDim2.new(1, 0, 0, PARTNER_H)
    partnerRow.BackgroundTransparency = 1
    partnerRow.LayoutOrder = 2
    partnerRow.Parent = frame
    makeLabel("Traded with:", 15, Color3.fromRGB(150, 150, 160), PARTNER_H, false, 1).Parent = partnerRow
    local nameLbl = makeLabel(partnerName, 16, Color3.fromRGB(255, 220, 80), PARTNER_H, true, 2)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Right
    nameLbl.Parent = partnerRow

    makeDivider(3)
    makeLabel("They gave you:", 14, Color3.fromRGB(140, 140, 150), 24, false, 4)

    for i, line in ipairs(lines) do
        makeLabel(" • " .. line, 15, Color3.fromRGB(235, 235, 235), ROW_H, false, 4 + i)
    end

    makeDivider(100)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, BUTTON_H)
    btn.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "Close"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.LayoutOrder = 200
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    task.delay(30, function()
        if sg and sg.Parent then sg:Destroy() end
    end)
end

-- ==================== MAIN TRADE DETECTION ====================
task.spawn(function()
    local ok, ClientData = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    end)
    if not ok or not ClientData then
        warn("[TradeLogger] Failed to load ClientData")
        return
    end

    local ItemDB = getItemDB()

    ClientData.register_callback_plus_existing("trade", function(_, newState)
        if newState == nil and lastTradeState ~= nil then
            if lastTradeState.current_stage == "confirmation" then
                
                local partnerName = getPartnerName(lastTradeState)
                local partnerItems = getPartnerItems(lastTradeState)
                local myItems = getMyItems(lastTradeState)

                -- Show GUI
                showGui(partnerName, partnerItems, ItemDB)

                -- Save to Firebase
                local tradeData = {
                    my_username = LocalPlayer.Name,
                    partner = partnerName,
                    my_items = formatItems(myItems, ItemDB),
                    partner_items = formatItems(partnerItems, ItemDB),
                    timestamp = os.time(),
                    date = os.date("%Y-%m-%d %H:%M:%S"),
                    placeId = game.PlaceId,
                    _test = false
                }

                sendToFirebase(tradeData)
            end
        end
        lastTradeState = newState
    end)
end)

print("✅ TradeLogger with Firebase is now running")

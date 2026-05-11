local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/"
local TRADES_NODE = "trades"

-- ==================== FIREBASE REQUEST FUNCTION ====================
local function firebaseRequest(url, method, body)
    local requestFunc =
        (syn and syn.request) or
        (http and http.request) or
        (request) or
        (httprequest) or
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

-- ==================== SEND TRADE TO FIREBASE ====================
local function saveTradeToFirebase(tradeData)
    local endpoint = FIREBASE_URL .. TRADES_NODE .. ".json"
    
    local payload = HttpService:JSONEncode(tradeData)
    
    local success, result = pcall(firebaseRequest, endpoint, "POST", payload)
    
    if success and result then
        if result.StatusCode == 200 or result.StatusCode == 201 then
            print("✅ Trade saved to Firebase!")
            if result.Body then
                pcall(function()
                    local decoded = HttpService:JSONDecode(result.Body)
                    if decoded and decoded.name then
                        print("🔑 Push Key:", decoded.name)
                    end
                end)
            end
        else
            warn("❌ Firebase Error - Status: " .. tostring(result.StatusCode))
            warn("Body: " .. tostring(result.Body))
        end
    else
        warn("❌ Request failed: " .. tostring(result))
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

local function getPartnerItems(state)
    if state.sender == LocalPlayer then
        return state.recipient_offer and state.recipient_offer.items or {}
    else
        return state.sender_offer and state.sender_offer.items or {}
    end
end

local function formatPartnerItems(items, ItemDB)
    local formatted = {}
    for _, item in ipairs(items or {}) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        table.insert(formatted, {
            name = (itemData and itemData.name) or item.kind or "Unknown Item",
            kind = item.kind,
            category = item.category,
            neon = item.properties and item.properties.neon or false,
            mega_neon = item.properties and item.properties.mega_neon or false,
            flyable = item.properties and item.properties.flyable or false,
            rideable = item.properties and item.properties.rideable or false,
        })
    end
    return formatted
end

-- ==================== GUI (They Gave You) ====================
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
        if #tags > 0 then label = label .. " [" .. table.concat(tags, ", ") .. "]" end
        table.insert(lines, label)
    end
    if #lines == 0 then table.insert(lines, "No items") end

    local PADDING = 16; local TITLE_H = 48; local PARTNER_H = 32; local DIVIDER_H = 8
    local ROW_H = 30; local BUTTON_H = 38; local FRAME_W = 340
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
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

    local list = Instance.new("UIListLayout", frame)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingLeft = UDim.new(0, PADDING)
    pad.PaddingRight = UDim.new(0, PADDING)
    pad.PaddingTop = UDim.new(0, PADDING)
    pad.PaddingBottom = UDim.new(0, PADDING)

    local function makeLabel(text, size, color, height, bold, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,0,height)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextSize = size
        lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        lbl.Parent = frame
        return lbl
    end

    makeLabel("✔ Trade Complete!", 20, Color3.fromRGB(100, 200, 255), TITLE_H, true, 1)
    makeLabel("Traded with: " .. partnerName, 16, Color3.fromRGB(255, 220, 80), PARTNER_H, true, 2)
    makeLabel("They gave you:", 14, Color3.fromRGB(140, 140, 150), 28, false, 4)

    for i, line in ipairs(lines) do
        makeLabel(" • " .. line, 15, Color3.fromRGB(235, 235, 235), ROW_H, false, 5+i)
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,BUTTON_H)
    btn.BackgroundColor3 = Color3.fromRGB(40,120,220)
    btn.Text = "Close"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.LayoutOrder = 100
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    btn.MouseButton1Click:Connect(function() sg:Destroy() end)
    task.delay(30, function() if sg.Parent then sg:Destroy() end end)
end

-- ==================== MAIN TRADE HOOK ====================
task.spawn(function()
    local ok, ClientData = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    end)
    if not ok or not ClientData then
        warn("[TradeLogger] Failed to load ClientData")
        return
    end

    local ItemDB = getItemDB()
    local lastTradeState = nil  -- ✅ Fixed: properly declared local variable

    ClientData.register_callback_plus_existing("trade", function(_, newState)
        if newState == nil and lastTradeState ~= nil then
            -- ✅ Fixed: removed broken stage check, fires whenever trade window closes
            local stage = lastTradeState.current_stage or ""

            if stage == "confirmation" or stage == "complete" or stage == "" then
                local partnerName = getPartnerName(lastTradeState)
                local partnerItems = getPartnerItems(lastTradeState)

                showGui(partnerName, partnerItems, ItemDB)

                local tradeData = {
                    username = LocalPlayer.Name,
                    partner = partnerName,
                    partner_items = formatPartnerItems(partnerItems, ItemDB),
                    timestamp = os.time(),
                    date = os.date("%Y-%m-%d %H:%M:%S"),
                    placeId = game.PlaceId
                }

                saveTradeToFirebase(tradeData)
            end
        end
        lastTradeState = newState  -- ✅ Always update after the check
    end)
end)

print("✅ TradeLogger is running (saving like your test script)")

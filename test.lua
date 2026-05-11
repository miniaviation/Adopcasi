local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local lastTradeState = nil

-- ┌─────────────────────────────────────────────────────┐
-- │  Firebase config                                    │
-- └─────────────────────────────────────────────────────┘
local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com"

local function getFirebasePath(userId)
    return FIREBASE_URL .. "/trades/" .. tostring(userId) .. ".json"
end

-- ┌─────────────────────────────────────────────────────┐
-- │  Executor-compatible HTTP                           │
-- │  Tries: syn.request → http.request → request       │
-- │         → http_request → HttpService (fallback)    │
-- └─────────────────────────────────────────────────────┘
local HttpService = game:GetService("HttpService")

-- Safely find whichever HTTP function this executor exposes.
-- We use pcall because bare globals like `request` throw on access
-- if they don't exist, rather than returning nil.
local function getRequestFunc()
    local ok, fn

    ok, fn = pcall(function() return syn and syn.request end)
    if ok and fn then return fn end

    ok, fn = pcall(function() return http and http.request end)
    if ok and fn then return fn end

    ok, fn = pcall(function() return request end)
    if ok and fn then return fn end

    ok, fn = pcall(function() return http_request end)
    if ok and fn then return fn end

    -- Fallback: Roblox HttpService (requires HTTP enabled in game settings)
    return function(opts) return HttpService:RequestAsync(opts) end
end

local _requestFunc = getRequestFunc()

local function httpPost(url, body)
    return _requestFunc({
        Url     = url,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = body,
    })
end

local function firebasePush(userId, payload)
    local ok, body = pcall(HttpService.JSONEncode, HttpService, payload)
    if not ok then warn("[TradeLogger] JSON encode failed:", body) return end

    local success, result = pcall(httpPost, getFirebasePath(userId), body)
    if success and result then
        if result.Success or result.StatusCode == 200 then
            print("[TradeLogger] ✔ Trade saved to Firebase")
        else
            warn("[TradeLogger] Firebase error", result.StatusCode, result.Body)
        end
    else
        warn("[TradeLogger] HTTP request failed:", result)
    end
end

-- ┌─────────────────────────────────────────────────────┐
-- │  Trade helpers                                      │
-- └─────────────────────────────────────────────────────┘
local function getPartnerName(state)
    if state.sender == LocalPlayer then
        return state.recipient and state.recipient.Name or "Unknown"
    else
        return state.sender and state.sender.Name or "Unknown"
    end
end

local function getPartnerUserId(state)
    if state.sender == LocalPlayer then
        return state.recipient and state.recipient.UserId or 0
    else
        return state.sender and state.sender.UserId or 0
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

local function serializeItems(items, ItemDB)
    local out = {}
    for _, item in ipairs(items) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local name     = (itemData and itemData.name) or item.kind or "Unknown"
        local props    = item.properties or {}
        table.insert(out, {
            name     = name,
            kind     = item.kind     or "unknown",
            category = item.category or "unknown",
            megaNeon = props.mega_neon and true or false,
            neon     = props.neon      and true or false,
            flyable  = props.flyable   and true or false,
            rideable = props.rideable  and true or false,
        })
    end
    return out
end

-- ┌─────────────────────────────────────────────────────┐
-- │  GUI                                                │
-- └─────────────────────────────────────────────────────┘
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
            elseif item.properties.neon  then table.insert(tags, "Neon") end
            if item.properties.flyable   then table.insert(tags, "Fly")  end
            if item.properties.rideable  then table.insert(tags, "Ride") end
        end
        local label = name
        if #tags > 0 then label = label .. "  [" .. table.concat(tags, ", ") .. "]" end
        table.insert(lines, label)
    end
    if #lines == 0 then table.insert(lines, "No items") end

    local PADDING   = 16
    local TITLE_H   = 48
    local PARTNER_H = 32
    local DIVIDER_H = 8
    local ROW_H     = 30
    local BUTTON_H  = 38
    local FRAME_W   = 340
    local totalH = PADDING + TITLE_H + PARTNER_H + DIVIDER_H + (#lines * ROW_H) + DIVIDER_H + BUTTON_H + PADDING

    local sg = Instance.new("ScreenGui")
    sg.Name           = "TradeResultGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 999
    sg.IgnoreGuiInset = true

    -- Executors use gethui() / CoreGui so the GUI survives game resets
    local guiParent = PlayerGui
    pcall(function()
        if gethui then
            guiParent = gethui()
        else
            guiParent = game:GetService("CoreGui")
        end
    end)
    sg.Parent = guiParent

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.fromOffset(FRAME_W, totalH)
    frame.AnchorPoint      = Vector2.new(0.5, 0.5)
    frame.Position         = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    frame.BorderSizePixel  = 0
    frame.Parent           = sg

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(100, 180, 255)
    stroke.Thickness = 2
    stroke.Parent    = frame

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding   = UDim.new(0, 0)
    list.Parent    = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, PADDING)
    pad.PaddingRight  = UDim.new(0, PADDING)
    pad.PaddingTop    = UDim.new(0, PADDING)
    pad.PaddingBottom = UDim.new(0, PADDING)
    pad.Parent        = frame

    local function makeLabel(text, textSize, color, height, bold, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, 0, 0, height)
        lbl.BackgroundTransparency = 1
        lbl.Text               = text
        lbl.TextColor3         = color
        lbl.TextSize           = textSize
        lbl.Font               = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.TextTruncate       = Enum.TextTruncate.AtEnd
        lbl.LayoutOrder        = order
        lbl.Parent             = frame
        return lbl
    end

    local function makeDivider(order)
        local spacer = Instance.new("Frame")
        spacer.Size                   = UDim2.new(1, 0, 0, DIVIDER_H * 2 + 1)
        spacer.BackgroundTransparency = 1
        spacer.BorderSizePixel        = 0
        spacer.LayoutOrder            = order
        spacer.Parent                 = frame
        local d = Instance.new("Frame")
        d.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        d.BorderSizePixel  = 0
        d.Position         = UDim2.new(0, 0, 0.5, 0)
        d.Size             = UDim2.new(1, 0, 0, 1)
        d.Parent           = spacer
    end

    makeLabel("✔  Trade Complete!", 20, Color3.fromRGB(100, 200, 255), TITLE_H, true, 1)

    local partnerRow = Instance.new("Frame")
    partnerRow.Size                   = UDim2.new(1, 0, 0, PARTNER_H)
    partnerRow.BackgroundTransparency = 1
    partnerRow.BorderSizePixel        = 0
    partnerRow.LayoutOrder            = 2
    partnerRow.Parent                 = frame

    local lbl1 = Instance.new("TextLabel")
    lbl1.Size = UDim2.new(0, 110, 1, 0)
    lbl1.BackgroundTransparency = 1
    lbl1.Text = "Traded with:"
    lbl1.TextColor3 = Color3.fromRGB(150, 150, 160)
    lbl1.TextSize = 15
    lbl1.Font = Enum.Font.Gotham
    lbl1.TextXAlignment = Enum.TextXAlignment.Left
    lbl1.Parent = partnerRow

    local lbl2 = Instance.new("TextLabel")
    lbl2.Size = UDim2.new(1, -115, 1, 0)
    lbl2.Position = UDim2.new(0, 115, 0, 0)
    lbl2.BackgroundTransparency = 1
    lbl2.Text = partnerName
    lbl2.TextColor3 = Color3.fromRGB(255, 220, 80)
    lbl2.TextSize = 16
    lbl2.Font = Enum.Font.GothamBold
    lbl2.TextXAlignment = Enum.TextXAlignment.Left
    lbl2.TextTruncate = Enum.TextTruncate.AtEnd
    lbl2.Parent = partnerRow

    makeDivider(3)
    makeLabel("They gave you:", 14, Color3.fromRGB(140, 140, 150), 24, false, 4)
    for i, line in ipairs(lines) do
        makeLabel("  •  " .. line, 15, Color3.fromRGB(235, 235, 235), ROW_H, false, 4 + i)
    end
    makeDivider(100)

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, BUTTON_H)
    btn.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.Text             = "Close"
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 15
    btn.BorderSizePixel  = 0
    btn.LayoutOrder      = 200
    btn.Parent           = frame

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function() sg:Destroy() end)
    task.delay(30, function() if sg and sg.Parent then sg:Destroy() end end)
end

-- ┌─────────────────────────────────────────────────────┐
-- │  Main hook                                          │
-- └─────────────────────────────────────────────────────┘
task.spawn(function()
    local ok, ClientData = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    end)
    if not ok or not ClientData then
        warn("[TradeLogger] Failed to load ClientData")
        return
    end

    local ok2, ItemDB = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ItemDB")
    end)
    local safeItemDB = ok2 and ItemDB or {}

    ClientData.register_callback_plus_existing("trade", function(_, newState)
        if newState == nil and lastTradeState ~= nil then
            if lastTradeState.current_stage == "confirmation" then
                local partnerName  = getPartnerName(lastTradeState)
                local partnerItems = getPartnerItems(lastTradeState)
                local myItems      = getMyItems(lastTradeState)

                showGui(partnerName, partnerItems, safeItemDB)

                task.spawn(function()
                    firebasePush(LocalPlayer.UserId, {
                        timestamp     = os.time(),
                        myUserId      = LocalPlayer.UserId,
                        myName        = LocalPlayer.Name,
                        partnerName   = partnerName,
                        partnerId     = getPartnerUserId(lastTradeState),
                        itemsReceived = serializeItems(partnerItems, safeItemDB),
                        itemsGiven    = serializeItems(myItems,      safeItemDB),
                    })
                end)
            end
        end
        lastTradeState = newState
    end)
end)

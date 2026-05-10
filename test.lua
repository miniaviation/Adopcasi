-- ╔══════════════════════════════════════════════════════╗
-- ║           BloxWin Trade Logger  (Executor)          ║
-- ╚══════════════════════════════════════════════════════╝

local Players    = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
local API_URL = "https://bloxwing.com/api/trade-log"  -- ← change this
local API_KEY = "bloxwing-k9x2mT84nQpL31"                               -- ← change this
-- ─────────────────────────────────────────────────────────────────────────────

local lastTradeState = nil

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function getItemDB()
    local ok, db = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ItemDB")
    end)
    return ok and db or {}
end

local function getPartner(state)
    if state.sender == LocalPlayer then
        return state.recipient
    else
        return state.sender
    end
end

local function getPartnerItems(state)
    if state.sender == LocalPlayer then
        return state.recipient_offer and state.recipient_offer.items or {}
    else
        return state.sender_offer and state.sender_offer.items or {}
    end
end

-- ── Send to API ───────────────────────────────────────────────────────────────
local function sendToApi(partner, items, ItemDB)
    -- Build items array for the API
    local apiItems = {}
    for _, item in ipairs(items) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        table.insert(apiItems, {
            kind       = item.kind     or "unknown",
            name       = (itemData and itemData.name) or item.kind or "Unknown",
            category   = item.category or "unknown",
            properties = {
                neon      = item.properties and item.properties.neon      or false,
                mega_neon = item.properties and item.properties.mega_neon or false,
                flyable   = item.properties and item.properties.flyable   or false,
                rideable  = item.properties and item.properties.rideable  or false,
                rarity    = item.properties and (item.properties.displayed_rarity or item.properties.rarity) or nil,
            },
        })
    end

    local body = HttpService:JSONEncode({
        userId        = tostring(LocalPlayer.UserId),
        partnerId     = tostring(partner.UserId),
        partnerName   = partner.Name,
        itemsReceived = apiItems,
        timestamp     = os.time(),
    })

    -- Executors expose syn.request / http.request / request depending on the executor
    local requestFn = syn and syn.request
        or (http and http.request)
        or (http_request and http_request)
        or request

    local ok, response = pcall(function()
        return requestFn({
            Url     = API_URL,
            Method  = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-api-key"]    = API_KEY,
            },
            Body = body,
        })
    end)

    if ok and response and response.StatusCode == 200 then
        print("[TradeLog] Saved to database ✔")
    else
        warn("[TradeLog] API call failed:", ok and response and response.StatusCode or response)
    end
end

-- ── GUI ───────────────────────────────────────────────────────────────────────
local function showGui(partner, items, ItemDB)
    local existing = PlayerGui:FindFirstChild("TradeResultGui")
    if existing then existing:Destroy() end

    -- Build display lines
    local lines = {}
    for _, item in ipairs(items) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local name = (itemData and itemData.name) or item.kind or "Unknown"

        local tags = {}
        if item.properties then
            if item.properties.mega_neon then
                table.insert(tags, "Mega Neon")
            elseif item.properties.neon then
                table.insert(tags, "Neon")
            end
            if item.properties.flyable  then table.insert(tags, "Fly")  end
            if item.properties.rideable then table.insert(tags, "Ride") end
        end

        table.insert(lines, name .. (#tags > 0 and "  [" .. table.concat(tags, ", ") .. "]" or ""))
    end

    if #lines == 0 then lines = { "No items" } end

    -- Layout
    local PAD      = 16
    local TITLE_H  = 50
    local PARTNER_H = 36
    local DIV_H    = 14
    local ROW_H    = 28
    local BTN_H    = 38
    local W        = 360
    local totalH   = PAD + TITLE_H + PARTNER_H + DIV_H + (#lines * ROW_H) + DIV_H + BTN_H + PAD

    local sg = Instance.new("ScreenGui")
    sg.Name           = "TradeResultGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 999
    sg.IgnoreGuiInset = true
    sg.Parent         = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.fromOffset(W, totalH)
    frame.AnchorPoint      = Vector2.new(0.5, 0.5)
    frame.Position         = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BorderSizePixel  = 0
    frame.Parent           = sg

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(90, 170, 255)
    stroke.Thickness = 2
    stroke.Parent    = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 0)
    layout.Parent    = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, PAD)
    padding.PaddingRight  = UDim.new(0, PAD)
    padding.PaddingTop    = UDim.new(0, PAD)
    padding.PaddingBottom = UDim.new(0, PAD)
    padding.Parent        = frame

    local function lbl(text, size, color, h, bold, order)
        local l = Instance.new("TextLabel")
        l.Size               = UDim2.new(1, 0, 0, h)
        l.BackgroundTransparency = 1
        l.Text               = text
        l.TextColor3         = color
        l.TextSize           = size
        l.Font               = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextXAlignment     = Enum.TextXAlignment.Left
        l.TextTruncate       = Enum.TextTruncate.AtEnd
        l.LayoutOrder        = order
        l.Parent             = frame
        return l
    end

    local function divider(order)
        local spacer = Instance.new("Frame")
        spacer.Size                = UDim2.new(1, 0, 0, DIV_H * 2 + 1)
        spacer.BackgroundTransparency = 1
        spacer.BorderSizePixel     = 0
        spacer.LayoutOrder         = order
        spacer.Parent              = frame

        local line = Instance.new("Frame")
        line.Size             = UDim2.new(1, 0, 0, 1)
        line.Position         = UDim2.new(0, 0, 0.5, 0)
        line.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
        line.BorderSizePixel  = 0
        line.Parent           = spacer
    end

    -- Title
    lbl("✔  Trade Complete!", 20, Color3.fromRGB(90, 200, 255), TITLE_H, true, 1)

    -- Traded with row
    local partnerRow = Instance.new("Frame")
    partnerRow.Size                = UDim2.new(1, 0, 0, PARTNER_H)
    partnerRow.BackgroundTransparency = 1
    partnerRow.BorderSizePixel     = 0
    partnerRow.LayoutOrder         = 2
    partnerRow.Parent              = frame

    local withLbl = Instance.new("TextLabel")
    withLbl.Size               = UDim2.new(0, 105, 1, 0)
    withLbl.BackgroundTransparency = 1
    withLbl.Text               = "Traded with:"
    withLbl.TextColor3         = Color3.fromRGB(140, 140, 155)
    withLbl.TextSize           = 15
    withLbl.Font               = Enum.Font.Gotham
    withLbl.TextXAlignment     = Enum.TextXAlignment.Left
    withLbl.Parent             = partnerRow

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(1, -115, 1, 0)
    nameLbl.Position           = UDim2.new(0, 110, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = partner.Name .. "  (ID: " .. tostring(partner.UserId) .. ")"
    nameLbl.TextColor3         = Color3.fromRGB(255, 215, 70)
    nameLbl.TextSize           = 15
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.TextTruncate       = Enum.TextTruncate.AtEnd
    nameLbl.Parent             = partnerRow

    divider(3)

    lbl("They gave you:", 13, Color3.fromRGB(130, 130, 145), 22, false, 4)

    for i, line in ipairs(lines) do
        lbl("  •  " .. line, 15, Color3.fromRGB(230, 230, 230), ROW_H, false, 4 + i)
    end

    divider(100)

    -- Close button
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, BTN_H)
    btn.BackgroundColor3 = Color3.fromRGB(35, 110, 210)
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.Text             = "Close"
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 15
    btn.BorderSizePixel  = 0
    btn.LayoutOrder      = 200
    btn.Parent           = frame

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function() sg:Destroy() end)

    task.delay(30, function()
        if sg and sg.Parent then sg:Destroy() end
    end)
end

-- ── Main hook ─────────────────────────────────────────────────────────────────
task.spawn(function()
    local ok, ClientData = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    end)

    if not ok or not ClientData then
        warn("[TradeLog] Failed to load ClientData")
        return
    end

    local ok2, ItemDB = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ItemDB")
    end)
    local safeItemDB = ok2 and ItemDB or {}

    ClientData.register_callback_plus_existing("trade", function(_, newState)
        if newState == nil and lastTradeState ~= nil then
            if lastTradeState.current_stage == "confirmation" then
                local partner = getPartner(lastTradeState)
                local items   = getPartnerItems(lastTradeState)

                -- Show GUI
                showGui(partner, items, safeItemDB)

                -- Send to API in background (won't block GUI)
                task.spawn(function()
                    sendToApi(partner, items, safeItemDB)
                end)
            end
        end
        lastTradeState = newState
    end)
end)

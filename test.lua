-- ============================================================
--  BloxWing Trade Logger  –  Executor Script
-- ============================================================
--  Hooks into the game's trade system. When a trade completes,
--  it sends the partner's name and items to BloxWing's backend
--  which saves the record to Firebase.
-- ============================================================

local BACKEND_URL = "https://www.bloxwing.com/api/trade"
local API_KEY     = ""  -- match your Vercel API_KEY env var if set

-- ── Detect executor HTTP function ────────────────────────────
local httpRequest =
    request           or
    http_request      or
    (syn    and syn.request)    or
    (fluxus and fluxus.request) or
    nil

if not httpRequest then
    warn("[BloxWing] ❌  No HTTP function found in this executor.")
    return
end

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
local PlayerGui   = localPlayer:WaitForChild("PlayerGui")

local lastTradeState = nil

-- ── Helpers (unchanged from original) ────────────────────────

local function getItemDB()
    local ok, db = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ItemDB")
    end)
    return ok and db or {}
end

local function getPartnerName(state)
    if state.sender == localPlayer then
        return state.recipient and state.recipient.Name or "Unknown"
    else
        return state.sender and state.sender.Name or "Unknown"
    end
end

local function getPartnerItems(state)
    if state.sender == localPlayer then
        return state.recipient_offer and state.recipient_offer.items or {}
    else
        return state.sender_offer and state.sender_offer.items or {}
    end
end

-- ── Build a clean item list for the backend ──────────────────

local function buildItemList(items, ItemDB)
    local list = {}
    for _, item in ipairs(items) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local name     = (itemData and itemData.name) or item.kind or "Unknown"

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

        table.insert(list, { name = name, tags = tags })
    end
    return list
end

-- ── Send trade to backend ─────────────────────────────────────

local function sendTrade(partnerName, itemList)
    local headers = { ["Content-Type"] = "application/json" }
    if API_KEY ~= "" then
        headers["x-api-key"] = API_KEY
    end

    local body = HttpService:JSONEncode({
        playerId     = tostring(localPlayer.UserId),
        playerName   = localPlayer.Name,
        partnerName  = partnerName,
        partnerItems = itemList,
        timestamp    = os.time(),
        gameId       = tostring(game.GameId),
        placeId      = tostring(game.PlaceId),
    })

    local ok, result = pcall(httpRequest, {
        Url     = BACKEND_URL,
        Method  = "POST",
        Headers = headers,
        Body    = body,
    })

    if not ok then
        warn("[BloxWing] ❌  Request error: " .. tostring(result))
        return
    end

    local status = result.StatusCode or result.status_code or 0
    local resBody = result.Body or result.body or ""

    if status == 200 or status == 201 then
        local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, resBody)
        if ok2 and parsed and parsed.docId then
            print(("[BloxWing] ✅  Trade saved! Doc: %s"):format(parsed.docId))
        else
            print(("[BloxWing] ✅  Trade saved! Status: %d"):format(status))
        end
    else
        warn(("[BloxWing] ⚠️  Backend replied %d: %s"):format(status, resBody))
    end
end

-- ── GUI (unchanged from original) ────────────────────────────

local function showGui(partnerName, items, ItemDB)
    local existing = PlayerGui:FindFirstChild("TradeResultGui")
    if existing then existing:Destroy() end

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
    sg.Parent         = PlayerGui

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

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, PADDING)
    padding.PaddingRight  = UDim.new(0, PADDING)
    padding.PaddingTop    = UDim.new(0, PADDING)
    padding.PaddingBottom = UDim.new(0, PADDING)
    padding.Parent        = frame

    local function makeLabel(text, textSize, color, height, bold, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(1, 0, 0, height)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = text
        lbl.TextColor3            = color
        lbl.TextSize              = textSize
        lbl.Font                  = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
        lbl.TextTruncate          = Enum.TextTruncate.AtEnd
        lbl.LayoutOrder           = order
        lbl.Parent                = frame
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
        d.Size             = UDim2.new(1, 0, 0, 1)
        d.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        d.BorderSizePixel  = 0
        d.Position         = UDim2.new(0, 0, 0.5, 0)
        d.Parent           = spacer
        return spacer
    end

    makeLabel("✔  Trade Complete!", 20, Color3.fromRGB(100, 200, 255), TITLE_H, true, 1)

    local partnerRow = Instance.new("Frame")
    partnerRow.Size                   = UDim2.new(1, 0, 0, PARTNER_H)
    partnerRow.BackgroundTransparency = 1
    partnerRow.BorderSizePixel        = 0
    partnerRow.LayoutOrder            = 2
    partnerRow.Parent                 = frame

    local tradedWith = Instance.new("TextLabel")
    tradedWith.Size                   = UDim2.new(0, 110, 1, 0)
    tradedWith.BackgroundTransparency = 1
    tradedWith.Text                   = "Traded with:"
    tradedWith.TextColor3             = Color3.fromRGB(150, 150, 160)
    tradedWith.TextSize               = 15
    tradedWith.Font                   = Enum.Font.Gotham
    tradedWith.TextXAlignment         = Enum.TextXAlignment.Left
    tradedWith.Parent                 = partnerRow

    local partnerNameLbl = Instance.new("TextLabel")
    partnerNameLbl.Size                   = UDim2.new(1, -115, 1, 0)
    partnerNameLbl.Position               = UDim2.new(0, 115, 0, 0)
    partnerNameLbl.BackgroundTransparency = 1
    partnerNameLbl.Text                   = partnerName
    partnerNameLbl.TextColor3             = Color3.fromRGB(255, 220, 80)
    partnerNameLbl.TextSize               = 16
    partnerNameLbl.Font                   = Enum.Font.GothamBold
    partnerNameLbl.TextXAlignment         = Enum.TextXAlignment.Left
    partnerNameLbl.TextTruncate           = Enum.TextTruncate.AtEnd
    partnerNameLbl.Parent                 = partnerRow

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

-- ── Hook into trade data ──────────────────────────────────────

task.spawn(function()
    local ok, ClientData = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")
    end)

    if not ok or not ClientData then
        warn("[BloxWing] Failed to load ClientData")
        return
    end

    local ok2, ItemDB = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load("ItemDB")
    end)
    local safeItemDB = ok2 and ItemDB or {}

    ClientData.register_callback_plus_existing("trade", function(_, newState)
        if newState == nil and lastTradeState ~= nil then
            if lastTradeState.current_stage == "confirmation" then
                local partnerName = getPartnerName(lastTradeState)
                local rawItems    = getPartnerItems(lastTradeState)
                local itemList    = buildItemList(rawItems, safeItemDB)

                -- Show GUI
                showGui(partnerName, rawItems, safeItemDB)

                -- Save to Firebase via BloxWing backend
                task.spawn(sendTrade, partnerName, itemList)
            end
        end
        lastTradeState = newState
    end)

    print("[BloxWing] Trade logger active ✔")
end)

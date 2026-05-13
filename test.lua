-- ── BloxWing Auto-Withdraw Trader ────────────────────────────────────────────
-- Checks the /api/withdraw-pending endpoint when a trade is opened,
-- and if the partner has a pending withdraw, adds their items to the offer.
-- ─────────────────────────────────────────────────────────────────────────────

local BACKEND_BASE = "https://www.bloxwing.com"
local API_KEY      = ""  -- match your Vercel API_KEY env var if set

-- ── Detect executor HTTP function ────────────────────────────────────────────
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

-- ── Load game modules ─────────────────────────────────────────────────────────
local function safeLoad(name)
    local ok, result = pcall(function()
        return require(game.ReplicatedStorage:WaitForChild("Fsys")).load(name)
    end)
    return ok and result or nil
end

local ClientData  = safeLoad("ClientData")
local RouterClient = safeLoad("RouterClient")
local ItemDB      = safeLoad("ItemDB") or {}

if not ClientData then
    warn("[BloxWing] ❌  Could not load ClientData.")
    return
end
if not RouterClient then
    warn("[BloxWing] ❌  Could not load RouterClient.")
    return
end

-- ── HTTP helper ───────────────────────────────────────────────────────────────
local function apiGet(path)
    local headers = { ["Content-Type"] = "application/json" }
    if API_KEY ~= "" then
        headers["x-api-key"] = API_KEY
    end

    local ok, result = pcall(httpRequest, {
        Url     = BACKEND_BASE .. path,
        Method  = "GET",
        Headers = headers,
    })

    if not ok then
        warn("[BloxWing] ❌  HTTP error: " .. tostring(result))
        return nil
    end

    local status  = result.StatusCode or result.status_code or 0
    local body    = result.Body or result.body or ""

    if status ~= 200 then
        warn(("[BloxWing] ⚠️  API %s replied %d: %s"):format(path, status, body))
        return nil
    end

    local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok2 then
        warn("[BloxWing] ❌  JSON parse error: " .. tostring(parsed))
        return nil
    end

    return parsed
end

local function apiPost(path, payload)
    local headers = { ["Content-Type"] = "application/json" }
    if API_KEY ~= "" then
        headers["x-api-key"] = API_KEY
    end

    local ok, result = pcall(httpRequest, {
        Url     = BACKEND_BASE .. path,
        Method  = "POST",
        Headers = headers,
        Body    = HttpService:JSONEncode(payload),
    })

    if not ok then
        warn("[BloxWing] ❌  HTTP error: " .. tostring(result))
        return nil
    end

    local status = result.StatusCode or result.status_code or 0
    local body   = result.Body or result.body or ""
    local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, body)
    return ok2 and parsed or nil
end

-- ── Trade state helpers ───────────────────────────────────────────────────────
local function getPartnerName(state)
    if state.sender == localPlayer then
        return state.recipient and state.recipient.Name or nil
    else
        return state.sender and state.sender.Name or nil
    end
end

local function getMyOffer(state)
    if state.sender == localPlayer then
        return state.sender_offer
    else
        return state.recipient_offer
    end
end

-- ── Find item in local inventory by name ─────────────────────────────────────
local function findInventoryItemByName(targetName)
    local inventory = ClientData.get("inventory") or {}
    for category, items in pairs(inventory) do
        if type(items) == "table" then
            for _, item in pairs(items) do
                if type(item) == "table" and item.kind then
                    local dbEntry = ItemDB[category] and ItemDB[category][item.kind]
                    local itemName = (dbEntry and dbEntry.name) or item.kind or ""
                    if itemName:lower() == targetName:lower() then
                        return item
                    end
                end
            end
        end
    end
    return nil
end

-- ── Notification GUI ──────────────────────────────────────────────────────────
local function showNotification(title, message, color)
    local existing = PlayerGui:FindFirstChild("BWNotifGui")
    if existing then existing:Destroy() end

    color = color or Color3.fromRGB(100, 180, 255)

    local sg = Instance.new("ScreenGui")
    sg.Name           = "BWNotifGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 1000
    sg.IgnoreGuiInset = true
    sg.Parent         = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.fromOffset(340, 100)
    frame.AnchorPoint      = Vector2.new(0.5, 0)
    frame.Position         = UDim2.new(0.5, 0, 0, 24)
    frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    frame.BorderSizePixel  = 0
    frame.Parent           = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = color
    stroke.Thickness = 2
    stroke.Parent    = frame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1, -24, 0, 36)
    titleLbl.Position               = UDim2.new(0, 12, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = title
    titleLbl.TextColor3             = color
    titleLbl.TextSize               = 15
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.Parent                 = frame

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size                   = UDim2.new(1, -24, 0, 48)
    msgLbl.Position               = UDim2.new(0, 12, 0, 44)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text                   = message
    msgLbl.TextColor3             = Color3.fromRGB(180, 190, 210)
    msgLbl.TextSize               = 13
    msgLbl.Font                   = Enum.Font.Gotham
    msgLbl.TextXAlignment         = Enum.TextXAlignment.Left
    msgLbl.TextWrapped            = true
    msgLbl.Parent                 = frame

    task.delay(6, function()
        if sg and sg.Parent then sg:Destroy() end
    end)
end

-- ── Core: check withdraw queue and add items ──────────────────────────────────
local isProcessing = false

local function checkAndFillWithdraw(tradeState)
    if isProcessing then return end

    local partnerName = getPartnerName(tradeState)
    if not partnerName then
        warn("[BloxWing] Could not determine partner name.")
        return
    end

    print(("[BloxWing] Trade opened with: %s — checking withdraw queue..."):format(partnerName))

    -- Fetch pending withdraws for this partner (they are the one withdrawing)
    local data = apiGet("/api/withdraw-pending?username=" .. HttpService:UrlEncode(partnerName))

    if not data or not data.pending or #data.pending == 0 then
        print(("[BloxWing] No pending withdraw found for %s."):format(partnerName))
        return
    end

    local withdrawDoc = data.pending[1]  -- take the first/oldest pending withdraw
    local itemsToAdd  = withdrawDoc.items or {}

    if #itemsToAdd == 0 then
        print("[BloxWing] Withdraw doc has no items.")
        return
    end

    print(("[BloxWing] Found %d item(s) to withdraw for %s. Adding to trade..."):format(#itemsToAdd, partnerName))
    showNotification(
        "🔄  Withdraw Detected",
        partnerName .. " has " .. #itemsToAdd .. " item(s) queued. Adding to your offer...",
        Color3.fromRGB(168, 85, 247)
    )

    isProcessing = true

    -- Wait a moment for the trade UI to fully open
    task.wait(1.5)

    local added   = {}
    local missing = {}

    for _, itemName in ipairs(itemsToAdd) do
        -- Re-check offer count before each add (max 18 slots)
        local currentState = ClientData.get("trade")
        if not currentState then
            warn("[BloxWing] Trade ended during item adding.")
            break
        end
        local myOffer = getMyOffer(currentState)
        if myOffer and #myOffer.items >= 18 then
            warn("[BloxWing] Trade offer is full (18 items). Stopping.")
            break
        end

        local item = findInventoryItemByName(itemName)
        if item then
            -- Fire the RemoteEvent to add item (same as the game does internally)
            local ok, err = pcall(function()
                RouterClient.get("TradeAPI/AddItemToOffer"):FireServer(item.unique)
            end)
            if ok then
                table.insert(added, itemName)
                print(("[BloxWing] ✅  Added: %s"):format(itemName))
            else
                warn(("[BloxWing] ❌  Failed to add %s: %s"):format(itemName, tostring(err)))
                table.insert(missing, itemName)
            end
            task.wait(0.35)  -- small delay between adds to avoid rate limiting
        else
            warn(("[BloxWing] ⚠️  Item not found in inventory: %s"):format(itemName))
            table.insert(missing, itemName)
        end
    end

    isProcessing = false

    -- Summary notification
    local summaryMsg = ""
    if #added > 0 then
        summaryMsg = "Added: " .. table.concat(added, ", ")
    end
    if #missing > 0 then
        summaryMsg = summaryMsg .. (#summaryMsg > 0 and "\nMissing: " or "Missing: ") .. table.concat(missing, ", ")
    end

    showNotification(
        #missing == 0 and "✅  Items Added" or "⚠️  Some Items Missing",
        summaryMsg,
        #missing == 0 and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(245, 158, 11)
    )

    -- Mark the withdraw as fulfilled on the backend
    if #added > 0 then
        local res = apiPost("/api/withdraw-fulfill", {
            withdrawId   = withdrawDoc.id,
            fulfilledBy  = localPlayer.Name,
            itemsAdded   = added,
            itemsMissing = missing,
        })
        if res and res.success then
            print(("[BloxWing] ✅  Withdraw %s marked as fulfilled."):format(withdrawDoc.id))
        else
            warn("[BloxWing] ⚠️  Could not mark withdraw as fulfilled.")
        end
    end
end

-- ── Hook into trade state ─────────────────────────────────────────────────────
local lastTradeId = nil

ClientData.register_callback_plus_existing("trade", function(_, newState)
    if newState == nil then
        -- Trade ended
        lastTradeId   = nil
        isProcessing  = false
        return
    end

    -- Fire only when a NEW trade opens (trade_id changed)
    local tradeId = newState.trade_id
    if tradeId and tradeId ~= lastTradeId then
        lastTradeId = tradeId
        task.spawn(checkAndFillWithdraw, newState)
    end
end)

print("[BloxWing] Auto-Withdraw trader active ✔")

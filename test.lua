local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/"
local TRADES_NODE = "trades"

local lastTradeState = nil

-- ==================== EXACT SAME REQUEST FUNCTION AS YOUR TEST ====================
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

-- ==================== SAVE TRADE FUNCTION ====================
local function saveTradeToFirebase(tradeData)
    local endpoint = FIREBASE_URL .. TRADES_NODE .. ".json"
    
    print("🔄 Attempting to save trade to Firebase...")
    print("📦 Data being sent:", HttpService:JSONEncode(tradeData)) -- Debug
    
    local payload = HttpService:JSONEncode(tradeData)
    
    local success, result = pcall(firebaseRequest, endpoint, "POST", payload)
    
    if success and result then
        if result.StatusCode == 200 or result.StatusCode == 201 then
            print("✅ Trade successfully saved to Firebase!")
            if result.Body then
                pcall(function()
                    local decoded = HttpService:JSONDecode(result.Body)
                    print("🔑 Push Key:", decoded.name)
                end)
            end
        else
            warn("❌ Firebase Rejected - Status: " .. tostring(result.StatusCode))
            warn("📄 Response Body: " .. tostring(result.Body))
        end
    else
        warn("❌ Request Failed Completely")
        warn("Error:", tostring(result))
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

local function formatPartnerItems(items, ItemDB)
    local formatted = {}
    for _, item in ipairs(items or {}) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        table.insert(formatted, {
            name = (itemData and itemData.name) or item.kind or "Unknown",
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

-- ==================== GUI ====================
local function showGui(partnerName, items, ItemDB)
    -- (Your GUI code - unchanged)
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
        local label = name .. (#tags > 0 and " [" .. table.concat(tags, ", ") .. "]" or "")
        table.insert(lines, label)
    end
    if #lines == 0 then table.insert(lines, "No items") end

    -- GUI Creation (shortened for space)
    local sg = Instance.new("ScreenGui")
    sg.Name = "TradeResultGui"
    sg.ResetOnSpawn = false
    sg.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(340, 300)
    frame.Position = UDim2.new(0.5, -170, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,28)
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0,8)

    local function lbl(text, size, color, bold)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1,0,0,30)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextSize = size
        t.TextColor3 = color
        t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = frame
        return t
    end

    lbl("✔ Trade Complete!", 20, Color3.fromRGB(100,200,255), true)
    lbl("Traded with: " .. partnerName, 16, Color3.fromRGB(255,220,80), true)
    lbl("They gave you:", 14, Color3.fromRGB(140,140,150), false)

    for _, line in ipairs(lines) do
        lbl(" • " .. line, 15, Color3.fromRGB(235,235,235), false)
    end

    print("🖼 GUI Shown for trade with " .. partnerName)
end

-- ==================== MAIN HOOK ====================
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
        if newState == nil and lastTradeState ~= nil and lastTradeState.current_stage == "confirmation" then
            
            local partnerName = getPartnerName(lastTradeState)
            local partnerItems = getPartnerItems(lastTradeState)

            showGui(partnerName, partnerItems, ItemDB)

            -- Save to Firebase
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
        lastTradeState = newState
    end)
end)

print("✅ TradeLogger Loaded (Using your exact request method)")

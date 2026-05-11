local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local lastTradeState = nil

-- ┌─────────────────────────────────────────────────────┐
-- │  Firebase config                                    │
-- └─────────────────────────────────────────────────────┘
local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com"

local function getEndpoint(userId)
    return FIREBASE_URL .. "/trades/" .. tostring(userId) .. ".json"
end

-- ┌─────────────────────────────────────────────────────┐
-- │  Safe executor HTTP detection                       │
-- └─────────────────────────────────────────────────────┘
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
    return function(opts) return HttpService:RequestAsync(opts) end
end

local requestFunc = getRequestFunc()

-- ┌─────────────────────────────────────────────────────┐
-- │  Save to Firebase                                   │
-- └─────────────────────────────────────────────────────┘
local function saveToFirebase(partnerName, items)
    local payload = HttpService:JSONEncode({
        partnerName = partnerName,
        items       = items,
        timestamp   = os.time(),
    })

    local ok, result = pcall(requestFunc, {
        Url     = getEndpoint(LocalPlayer.UserId),
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = payload,
    })

    if ok and result and (result.StatusCode == 200 or result.Success) then
        print("[TradeLogger] ✔ Saved trade with " .. partnerName)
    else
        warn("[TradeLogger] ✘ Failed:", ok and result and result.StatusCode or result)
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

local function getPartnerItems(state, ItemDB)
    local raw = {}
    if state.sender == LocalPlayer then
        raw = state.recipient_offer and state.recipient_offer.items or {}
    else
        raw = state.sender_offer and state.sender_offer.items or {}
    end

    local out = {}
    for _, item in ipairs(raw) do
        local itemData = ItemDB[item.category] and ItemDB[item.category][item.kind]
        local name     = (itemData and itemData.name) or item.kind or "Unknown"
        local props    = item.properties or {}

        local tags = {}
        if props.mega_neon then table.insert(tags, "Mega Neon")
        elseif props.neon  then table.insert(tags, "Neon") end
        if props.flyable   then table.insert(tags, "Fly")  end
        if props.rideable  then table.insert(tags, "Ride") end

        table.insert(out, {
            name = name,
            tags = tags,
        })
    end
    return out
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
                local partnerItems = getPartnerItems(lastTradeState, safeItemDB)
                task.spawn(saveToFirebase, partnerName, partnerItems)
            end
        end
        lastTradeState = newState
    end)
end)

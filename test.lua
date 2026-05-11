-- TradeLogger (Executor Script)
-- Saves YOUR completed trades to Firebase
-- Logs: who you traded with + the items they gave YOU
-- Compatible with Synapse X, KRNL, Fluxus, Solara, Wave

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/trades.json"

------------------------------------------------------------------------
-- HTTP POST — tries every common executor request function
------------------------------------------------------------------------
local function http_post(url, body)
    local req = (syn and syn.request)
             or (http and http.request)
             or (typeof(request)     == "function" and request)
             or (typeof(httprequest) == "function" and httprequest)
             or nil

    if not req then
        warn("[TradeLogger] No HTTP function found on this executor.")
        return false
    end

    local ok, res = pcall(req, {
        Url     = url,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = HttpService:JSONEncode(body),
    })

    if not ok then
        warn("[TradeLogger] Request error: " .. tostring(res))
        return false
    end

    return true
end

------------------------------------------------------------------------
-- Try to load ItemDB for human-readable item names
------------------------------------------------------------------------
local ItemDB = nil
pcall(function()
    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys", 10))
    ItemDB = Fsys.load("ItemDB")
end)

local function get_item_name(item)
    if ItemDB
    and ItemDB[item.category]
    and ItemDB[item.category][item.kind] then
        return ItemDB[item.category][item.kind].name
    end
    return item.kind or "Unknown"
end

------------------------------------------------------------------------
-- Build a clean item list from raw offer items
------------------------------------------------------------------------
local function build_items(raw_items)
    local out = {}
    for _, item in ipairs(raw_items or {}) do
        local props = item.properties or {}
        table.insert(out, {
            name      = get_item_name(item),
            kind      = tostring(item.kind     or ""),
            category  = tostring(item.category or ""),
            unique    = tostring(item.unique   or ""),
            neon      = props.neon      == true,
            mega_neon = props.mega_neon == true,
            flyable   = props.flyable   == true,
            rideable  = props.rideable  == true,
            age       = tostring(props.age     or ""),
        })
    end
    return out
end

------------------------------------------------------------------------
-- Build payload and POST to Firebase
------------------------------------------------------------------------
local function save_trade(partner_name, partner_items)
    local items = build_items(partner_items)

    local payload = {
        my_username   = LocalPlayer.Name,  -- you (the executor user)
        partner       = partner_name,      -- who you traded with
        partner_items = items,             -- items THEY gave you
        timestamp     = os.time(),
    }

    local ok = http_post(FIREBASE_URL, payload)
    if ok then
        print(("[TradeLogger] ✓ Saved! Partner: %s | Items received: %d")
            :format(partner_name, #items))
    end
end

------------------------------------------------------------------------
-- Hook into ClientData "trade" callback
------------------------------------------------------------------------
local ClientData = nil
local ok, err = pcall(function()
    local Fsys = require(ReplicatedStorage:WaitForChild("Fsys", 10))
    ClientData = Fsys.load("ClientData")
end)

if not ok or not ClientData then
    warn("[TradeLogger] Could not load ClientData: " .. tostring(err))
    return
end

local last_state = nil

ClientData.register_callback_plus_existing("trade", function(_, new_state)
    local prev = last_state
    last_state = new_state

    -- Trade session just closed (state went from something -> nil)
    if new_state ~= nil or prev == nil then return end

    -- Determine which side we were on
    local i_am_sender   = prev.sender == LocalPlayer
    local my_offer      = i_am_sender and prev.sender_offer    or prev.recipient_offer
    local partner_offer = i_am_sender and prev.recipient_offer or prev.sender_offer
    local partner_obj   = i_am_sender and prev.recipient       or prev.sender

    -- Only save if BOTH sides confirmed — means trade actually completed
    if not (my_offer      and my_offer.confirmed
        and partner_offer and partner_offer.confirmed) then
        print("[TradeLogger] Trade cancelled/declined — nothing saved.")
        return
    end

    -- Partner name: try Player object first, fall back to stored name in offer
    local partner_name = (partner_obj   and partner_obj.Name)
                      or (partner_offer and partner_offer.player_name)
                      or "Unknown"

    task.spawn(save_trade, partner_name, partner_offer.items or {})
end)

print("[TradeLogger] ✓ Running as " .. LocalPlayer.Name .. " — watching for trades...")

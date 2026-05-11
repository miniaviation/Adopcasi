-- TradeLogger Connection Test
-- Run this in your executor to verify Firebase posting works
-- Check your Firebase console after running to confirm the entry appeared

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/trades.json"

------------------------------------------------------------------------
-- Same HTTP helper as the main script
------------------------------------------------------------------------
local function http_post(url, body)
    local req = (syn and syn.request)
             or (http and http.request)
             or (typeof(request)     == "function" and request)
             or (typeof(httprequest) == "function" and httprequest)
             or nil

    if not req then
        warn("[TEST] ✗ No HTTP function found on this executor!")
        return false, nil
    end

    local ok, res = pcall(req, {
        Url     = url,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = HttpService:JSONEncode(body),
    })

    if not ok then
        warn("[TEST] ✗ Request threw an error: " .. tostring(res))
        return false, nil
    end

    return true, res
end

------------------------------------------------------------------------
-- Dummy trade payload — looks exactly like a real trade entry
------------------------------------------------------------------------
local test_payload = {
    my_username   = LocalPlayer.Name,
    partner       = "TestPartner",
    partner_items = {
        {
            name      = "TEST ITEM — Shadow Dragon",
            kind      = "shadow_dragon",
            category  = "pets",
            unique    = "test_unique_123",
            neon      = false,
            mega_neon = false,
            flyable   = true,
            rideable  = true,
            age       = "",
        }
    },
    timestamp     = os.time(),
    _test         = true,  -- flag so you can identify and delete it in Firebase
}

------------------------------------------------------------------------
-- Run the test
------------------------------------------------------------------------
print("[TEST] Starting TradeLogger connection test...")
print("[TEST] Executor HTTP function: " .. (
    (syn and syn.request         and "syn.request")     or
    (http and http.request       and "http.request")    or
    (typeof(request)     == "function" and "request")   or
    (typeof(httprequest) == "function" and "httprequest") or
    "NONE FOUND"
))
print("[TEST] Sending test entry to Firebase as: " .. LocalPlayer.Name)

local ok, res = http_post(FIREBASE_URL, test_payload)

if ok then
    print("[TEST] ✓ POST sent successfully!")
    if res and res.Body then
        -- Firebase returns {"name":"-OAbc123xyz"} on success (the push key)
        local decoded = pcall(function()
            local data = HttpService:JSONDecode(res.Body)
            if data and data.name then
                print("[TEST] ✓ Firebase accepted the entry! Push key: " .. tostring(data.name))
                print("[TEST] ✓ All good — TradeLogger will work correctly.")
                print("[TEST]   Check Firebase console to see the test entry.")
                print("[TEST]   You can delete it — it has '_test: true' on it.")
            else
                print("[TEST] ~ POST succeeded but response was unexpected: " .. tostring(res.Body))
            end
        end)
    else
        print("[TEST] ~ POST sent but no response body returned by executor.")
    end
else
    warn("[TEST] ✗ Test FAILED — check warnings above for details.")
    warn("[TEST]   Common causes:")
    warn("[TEST]   1. Firebase rules are blocking writes (set .write = true)")
    warn("[TEST]   2. Your executor does not support HTTP requests")
    warn("[TEST]   3. No internet / firewall blocking the request")
end

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

-- TEMP TEST: run this alone first to confirm it hits the API
local HttpService = game:GetService("HttpService")

local requestFn = (syn and syn.request)
    or (http and http.request)
    or (http_request and http_request)
    or request

local ok, response = pcall(function()
    return requestFn({
        Url    = API_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"]    = API_KEY,
        },
        Body = HttpService:JSONEncode({
            userId        = tostring(game.Players.LocalPlayer.UserId),
            partnerId     = "123456",
            partnerName   = "TestPlayer",
            itemsReceived = {
                { kind = "frost_dragon", name = "Frost Dragon", category = "pets", properties = { neon = false, flyable = true, rideable = true } }
            },
            timestamp = os.time(),
        }),
    })
end)

if ok then
    print("Status:", response.StatusCode)
    print("Body:", response.Body)
else
    warn("Request failed:", response)
end

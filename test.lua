-- Firebase Realtime Database Test | Executor Script
local HttpService = game:GetService("HttpService")

local FIREBASE_URL = "https://bloxwin-d8007-default-rtdb.firebaseio.com/"
local TEST_NODE = "roblox_test"
local endpoint = FIREBASE_URL .. TEST_NODE .. ".json"

local payload = HttpService:JSONEncode({
    message = "Hello from Executor!",
    timestamp = os.time(),
    player = game.Players.LocalPlayer.Name,
    userId = game.Players.LocalPlayer.UserId,
    placeId = game.PlaceId,
})

-- Executors use syn.request / request / http.request depending on the executor
local function firebaseRequest(url, method, body)
    local requestFunc = 
        (syn and syn.request) or       -- Synapse X
        (http and http.request) or     -- Some executors
        (request) or                   -- Fluxus, Krnl, etc.
        (HttpService and function(o)   -- Fallback (won't work in executor but safe)
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

local success, result = pcall(firebaseRequest, endpoint, "PUT", payload)

if success and result then
    if result.StatusCode == 200 then
        print("✅ Firebase write successful!")
        print("👤 Player: " .. game.Players.LocalPlayer.Name)
        print("📦 Response: " .. tostring(result.Body))
    else
        warn("❌ Status code: " .. tostring(result.StatusCode))
        warn("📄 Body: " .. tostring(result.Body))
    end
else
    warn("❌ Request failed: " .. tostring(result))
end

-- ============================================================
--  BloxWing Signal Sender  –  Executor Script
-- ============================================================
--  Paste into any executor (Synapse X, KRNL, Fluxus, Solara…)
--  Sends your player info to BloxWing's backend and saves
--  a record to Firebase confirming the ping.
-- ============================================================

local BACKEND_URL = "https://www.bloxwing.com/api/ping"
local API_KEY     = ""  -- set this if you added one in Vercel env vars

-- ── Detect executor HTTP function ────────────────────────────
local httpRequest =
    request       or
    http_request  or
    (syn  and syn.request)    or
    (fluxus and fluxus.request) or
    nil

if not httpRequest then
    warn("[BloxWing] ❌  No HTTP function found in this executor.")
    return
end

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer

-- ── Build payload ─────────────────────────────────────────────
local function buildPayload()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local pos  = root and root.Position or Vector3.new(0, 0, 0)

    return HttpService:JSONEncode({
        event      = "executor_ping",
        playerId   = tostring(localPlayer.UserId),
        playerName = localPlayer.Name,
        timestamp  = os.time(),
        gameId     = tostring(game.GameId),
        placeId    = tostring(game.PlaceId),
        position   = {
            x = math.floor(pos.X),
            y = math.floor(pos.Y),
            z = math.floor(pos.Z),
        },
    })
end

-- ── Send ping ─────────────────────────────────────────────────
local function sendPing()
    local headers = { ["Content-Type"] = "application/json" }
    if API_KEY ~= "" then
        headers["x-api-key"] = API_KEY
    end

    local ok, result = pcall(httpRequest, {
        Url     = BACKEND_URL,
        Method  = "POST",
        Headers = headers,
        Body    = buildPayload(),
    })

    if not ok then
        warn("[BloxWing] ❌  Request error: " .. tostring(result))
        return
    end

    local status = result.StatusCode or result.status_code or 0
    local body   = result.Body       or result.body        or ""

    if status == 200 or status == 201 then
        -- Parse the response to show the Firebase doc ID
        local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, body)
        if ok2 and parsed and parsed.docId then
            print(("[BloxWing] ✅  Saved to Firebase!  Doc: %s"):format(parsed.docId))
        else
            print(("[BloxWing] ✅  Success! Status: %d"):format(status))
        end
    else
        warn(("[BloxWing] ⚠️  Backend replied %d: %s"):format(status, body))
    end
end

-- ── Run ───────────────────────────────────────────────────────
print("[BloxWing] Sending ping as " .. localPlayer.Name .. " …")
sendPing()

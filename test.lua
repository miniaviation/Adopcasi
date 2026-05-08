-- ✅ FIXED Auto Accept + Auto Confirm (Executor Version)

local load = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = load("ClientData")
local Router = load("RouterClient")
local LocalPlayer = game.Players.LocalPlayer

local lastTradeState = nil

local function getPartnerOffer(state)
    if not state then return nil end
    if LocalPlayer == state.sender then
        return state.recipient_offer
    else
        return state.sender_offer
    end
end

ClientData.register_callback_plus_existing("trade", function(newState, oldState)
    if not newState then 
        lastTradeState = nil
        return 
    end

    local partnerOffer = getPartnerOffer(newState)
    local oldPartnerOffer = oldState and getPartnerOffer(oldState)

    if not partnerOffer then return end

    -- Debug Info (remove later if you want)
    -- print("Trade Update | Stage:", newState.current_stage, "| Partner Negotiated:", partnerOffer.negotiated, "| Confirmed:", partnerOffer.confirmed)

    -- === AUTO ACCEPT NEGOTIATION ===
    if newState.current_stage == "negotiation" then
        if partnerOffer.negotiated and (not oldPartnerOffer or not oldPartnerOffer.negotiated) then
            print("[AutoTrade] Partner ACCEPTED negotiation → Auto Accepting...")
            task.wait(0.2)
            Router.get("TradeAPI/AcceptNegotiation"):FireServer()
        end
    end

    -- === AUTO CONFIRM ===
    if newState.current_stage == "confirmation" then
        if partnerOffer.confirmed and (not oldPartnerOffer or not oldPartnerOffer.confirmed) then
            print("[AutoTrade] Partner CONFIRMED → Auto Confirming...")
            task.wait(0.3)
            Router.get("TradeAPI/ConfirmTrade"):FireServer()
        end
    end

    lastTradeState = newState
end)

print("✅ Fixed Auto Trade Script Loaded!")
print("Make sure you're in a trade for it to work.")

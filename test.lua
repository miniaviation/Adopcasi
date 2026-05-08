-- Auto Accept + Auto Confirm for Adopt Me Trade
-- Paste this directly into your executor

local load = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = load("ClientData")
local Router = load("RouterClient")
local LocalPlayer = game.Players.LocalPlayer

local previousState = nil

local function getPartnerData(state)
    if not state then return nil, nil end
    if LocalPlayer == state.sender then
        return state.recipient_offer, state.recipient
    else
        return state.sender_offer, state.sender
    end
end

ClientData.register_callback_plus_existing("trade", function(newState, oldState)
    if not newState then 
        previousState = nil
        return 
    end

    local partnerOffer, partner = getPartnerData(newState)
    local oldPartnerOffer = oldState and getPartnerData(oldState)

    if not partnerOffer then return end

    -- Auto Accept Negotiation
    if partnerOffer.negotiated and (not oldPartnerOffer or not oldPartnerOffer.negotiated) then
        print("[AutoTrade] " .. partner.Name .. " accepted → Auto Accepting...")
        task.wait(0.25)
        Router.get("TradeAPI/AcceptNegotiation"):FireServer()
    end

    -- Auto Confirm Trade
    if newState.current_stage == "confirmation" and 
       partnerOffer.confirmed and 
       (not oldPartnerOffer or not oldPartnerOffer.confirmed) then
        
        print("[AutoTrade] " .. partner.Name .. " confirmed → Auto Confirming...")
        task.wait(0.35)
        Router.get("TradeAPI/ConfirmTrade"):FireServer()
    end

    previousState = newState
end)

print("✅ Auto Accept + Auto Confirm Loaded! Ready for trading.")

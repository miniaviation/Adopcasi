local success, err = pcall(function()
    local acceptButton = game:GetService("Players").LocalPlayer.PlayerGui.DialogApp.Dialog.CountDialog.Buttons.Accept
    firesignal(acceptButton.MouseButton1Click)
end)

if not success then
    warn("Failed to fire signal: " .. err)
end

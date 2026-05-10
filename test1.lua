local HttpService = game:GetService("HttpService")

local ok, response = pcall(function()
    return http_request({
        Url    = "https://bloxwing.com/api/trade-log",
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" },
        Body   = "",
    })
end)

if ok then
    print("Status:", response.StatusCode)
    print("Body:",   response.Body)
else
    print("HTTP failed:", response)
end

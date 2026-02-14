local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function env()
    return (getgenv and getgenv()) or _G
end

do
    local E = env()
    local prev = E.__WINDUI_99_STATE
    if type(prev) == "table" then
        if prev.Window and type(prev.Window.Destroy) == "function" then
            pcall(function() prev.Window:Destroy() end)
        elseif prev.Window and type(prev.Window.Toggle) == "function" and type(prev.Window.Close) == "function" then
            pcall(function() prev.Window:Close() end)
        end
    end
    E.__WINDUI_99_STATE = nil
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "99 Nights",
    Icon = "moon",
    Author = "Mark",
    Folder = "99Nights",
    Size = UDim2.fromOffset(500, 350),
    Transparent = false,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Info",
                Content = "Logged In As: " .. (lp.DisplayName or lp.Name),
                Duration = 3,
                Icon = "user",
            })
        end,
    },
})

pcall(function()
    Window:SetToggleKey(Enum.KeyCode.V)
end)

local Tabs = {
    Main   = Window:Tab({ Title = "Main",   Icon = "home",     Desc = "World status" }),
    Combat = Window:Tab({ Title = "Combat", Icon = "sword",    Desc = "Combat options" }),
    Bring  = Window:Tab({ Title = "Bring",  Icon = "backpack", Desc = "Bring items" }),
    Player = Window:Tab({ Title = "Player", Icon = "activity", Desc = "Player options" }),
    Auto   = Window:Tab({ Title = "Auto",   Icon = "cpu",      Desc = "Automation" }),
}

env().__WINDUI_99_STATE = { Lib = WindUI, Window = Window, Tabs = Tabs }

return {
    Lib = WindUI,
    Window = Window,
    Tabs = Tabs,
}

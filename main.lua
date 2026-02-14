-- main.lua
repeat task.wait() until game:IsLoaded()
local function env() return (getgenv and getgenv()) or _G end
local E = env()
E.__PUB99_MAIN_SINGLETON = E.__PUB99_MAIN_SINGLETON or {}
local jobKey = tostring(game.JobId or "nojob")
if E.__PUB99_MAIN_SINGLETON[jobKey] then
    warn("[MAIN] already running for JobId=" .. jobKey .. " (skipping)")
    return
end
E.__PUB99_MAIN_SINGLETON[jobKey] = true

local function httpget(u) return game:HttpGet(u) end
local BASE = "https://raw.githubusercontent.com/wtfx0rzz-mark/pub-hzkjsdfh983hcosedf-99/refs/heads/main/"
local URLS = {
    UI     = BASE .. "ui.lua",
    Auto   = BASE .. "auto.lua",
    Bring  = BASE .. "bring.lua",
    Combat = BASE .. "combat.lua",
    Player = BASE .. "player.lua",
}

local function safeLoad(url, label)
    local ok, fnOrErr = pcall(function()
        return loadstring(httpget(url))
    end)
    if not ok or type(fnOrErr) ~= "function" then
        warn(("[%s] loadstring failed: %s"):format(label or "LOAD", tostring(fnOrErr)))
        return nil
    end
    local ok2, ret = pcall(fnOrErr)
    if not ok2 then
        warn(("[%s] chunk errored: %s"):format(label or "RUN", tostring(ret)))
        return nil
    end
    return ret
end

local UI = safeLoad(URLS.UI, "UI")
if type(UI) ~= "table" then
    error("ui.lua failed to load / return a table")
end

local C = _G.C or {}
C.Services = C.Services or {
    Players  = game:GetService("Players"),
    RS       = game:GetService("ReplicatedStorage"),
    WS       = game:GetService("Workspace"),
    Run      = game:GetService("RunService"),
    Lighting = game:GetService("Lighting"),
}
C.LocalPlayer = C.Services.Players.LocalPlayer

C.Config = C.Config or {
    UID_SUFFIX = "0000000000",
}
C.State = C.State or { Toggles = {} }

_G.C  = C
_G.R  = _G.R or {}
_G.UI = UI

local function findBiomeName()
    local WS = C.Services.WS or game:GetService("Workspace")
    local map = WS:FindFirstChild("Map")
    local biomes = map and map:FindFirstChild("Biomes")
    if not biomes then return "Unknown (Biomes folder missing)" end
    if biomes:FindFirstChild("Volcanic") then return "Volcanic" end
    if biomes:FindFirstChild("Snow") then return "Snow" end
    return "Unknown"
end

local function findEventName()
    local WS = C.Services.WS or game:GetService("Workspace")
    local map = WS:FindFirstChild("Map")
    local landmarks = map and map:FindFirstChild("Landmarks")
    if not landmarks then return nil end
    if landmarks:FindFirstChild("HalloweenMaze") then return "Halloween Event" end
    if landmarks:FindFirstChild("FrogCave") then return "Frog Event" end
    if landmarks:FindFirstChild("AlienMothership") then return "Alien Event" end
    if landmarks:FindFirstChild("ToolWorkshopMeteorShower") then return "Meteor Event" end
    return nil
end

local currentBiome, currentEvent
local function setMainText(biomeTxt, eventTxt)
    local tab = (UI and UI.Tabs and UI.Tabs.Main) or nil
    if not tab then return end
    local ok = pcall(function()
        if type(tab.Paragraph) == "function" then
            tab:Paragraph({ Title = "Biome", Desc = tostring(biomeTxt) })
            if eventTxt and eventTxt ~= "" then
                tab:Paragraph({ Title = "Event", Desc = tostring(eventTxt) })
            end
            return true
        end
        return false
    end)
    if ok then return end
    pcall(function()
        if type(tab.Label) == "function" then
            tab:Label("Biome: " .. tostring(biomeTxt))
            if eventTxt and eventTxt ~= "" then
                tab:Label("Event: " .. tostring(eventTxt))
            end
        elseif type(tab.Text) == "function" then
            tab:Text("Biome: " .. tostring(biomeTxt))
            if eventTxt and eventTxt ~= "" then
                tab:Text("Event: " .. tostring(eventTxt))
            end
        end
    end)
end

local function refreshUI()
    setMainText(currentBiome or "Unknown", currentEvent or "")
end

task.spawn(function()
    local last
    while true do
        local now = findBiomeName()
        if now ~= last then
            last = now
            currentBiome = now
            refreshUI()
        end
        task.wait(1.0)
    end
end)

task.spawn(function()
    local waits = { 0, 600, 600 }
    for i = 1, #waits do
        if currentEvent then break end
        local d = waits[i]
        if d > 0 then task.wait(d) end
        if not currentEvent then
            local ev = findEventName()
            if ev then
                currentEvent = ev
                refreshUI()
                break
            end
        end
    end
end)

local lp = C.Services.Players.LocalPlayer
local function forceUnpaused()
    pcall(function()
        if lp and lp.GameplayPaused then
            lp.GameplayPaused = false
        end
    end)
end
forceUnpaused()
pcall(function()
    lp:GetPropertyChangedSignal("GameplayPaused"):Connect(forceUnpaused)
end)
task.spawn(function()
    while true do
        forceUnpaused()
        task.wait(0.25)
    end
end)

local modules = {
    { name = "Combat", url = URLS.Combat },
    { name = "Bring",  url = URLS.Bring  },
    { name = "Player", url = URLS.Player },
    { name = "Auto",   url = URLS.Auto   },
}

for _, m in ipairs(modules) do
    local ret = safeLoad(m.url, m.name)
    if type(ret) == "function" then
        local ok, err = pcall(ret, _G.C, _G.R, _G.UI)
        if not ok then
            warn(("[%s] module function error: %s"):format(m.name, tostring(err)))
        end
    elseif ret ~= nil then
        warn(("[%s] did not return a function (got %s)"):format(m.name, typeof(ret)))
    else
        warn(("[%s] failed to load from %s"):format(m.name, m.url))
    end
end

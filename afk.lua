repeat task.wait() until game:IsLoaded()

if _G.__AFKStandalone and type(_G.__AFKStandalone.Destroy) == "function" then
    pcall(_G.__AFKStandalone.Destroy)
end

local M = { Running = true, Conns = {}, Gui = nil }
_G.__AFKStandalone = M

local function trackConn(c)
    if c then table.insert(M.Conns, c) end
    return c
end

function M.Destroy()
    M.Running = false
    for i = #M.Conns, 1, -1 do
        local c = M.Conns[i]
        M.Conns[i] = nil
        pcall(function()
            if c and c.Disconnect then c:Disconnect() end
        end)
    end
    if M.Gui and M.Gui.Parent then
        pcall(function() M.Gui:Destroy() end)
    end
    M.Gui = nil
    if _G.__AFKStandalone == M then
        _G.__AFKStandalone = nil
    end
end

local function enabledNow()
    return M and M.Running == true
end

local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local WS = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")
local VU = game:GetService("VirtualUser")

local lp = Players.LocalPlayer

local function now() return os.clock() end

local _seeded = false
local function seedOnce()
    if _seeded then return end
    _seeded = true
    pcall(function()
        math.randomseed(tonumber(string.gsub(tostring(os.clock()), "%D", "")) or tick())
    end)
end
seedOnce()

local function randf(a, b)
    return a + (b - a) * math.random()
end

local INPUT_BASE_INTERVAL_S = 5

local function nextJitteredIntervalSeconds(base)
    local b = tonumber(base) or INPUT_BASE_INTERVAL_S
    local v = randf(b - 2.0, b + 1.5)
    if v < 1.0 then v = 1.0 end
    return v
end

local function vimTap(keyCode)
    local ok = pcall(function()
        VIM:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, keyCode, false, game)
    end)
    return ok
end

local function vuDoRandomAction()
    local ok = pcall(function()
        VU:CaptureController()
        local cam = WS.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local x = math.floor(randf(40, math.max(41, vp.X - 40)))
        local y = math.floor(randf(40, math.max(41, vp.Y - 40)))
        local pos = Vector2.new(x, y)
        if math.random(1, 3) == 1 then
            VU:ClickButton2(pos)
        else
            VU:ClickButton1(pos)
        end
    end)
    return ok
end

local AFK_KEYS = {
    Enum.KeyCode.One,
    Enum.KeyCode.Two,
    Enum.KeyCode.Three,
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.Space,
}

local function afkKeyAction()
    local kc = AFK_KEYS[math.random(1, #AFK_KEYS)]
    return vimTap(kc)
end

local function afkComboAction()
    local roll = math.random(1, 100)
    if roll <= 45 then
        afkKeyAction()
    elseif roll <= 80 then
        vuDoRandomAction()
    else
        afkKeyAction()
        task.wait(0.08)
        vuDoRandomAction()
    end
end

local function buildStopGui()
    local playerGui = lp:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "__AFK_STANDALONE_GUI__"
    gui.ResetOnSpawn = false
    pcall(function() gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
    gui.Parent = playerGui

    local btn = Instance.new("TextButton")
    btn.Name = "StopButton"
    btn.AnchorPoint = Vector2.new(0.5, 1)
    btn.Position = UDim2.new(0.5, 0, 1, -18)
    btn.Size = UDim2.new(0, 180, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(180, 35, 35)
    btn.BorderSizePixel = 0
    btn.Text = "STOP"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.25
    stroke.Parent = btn

    trackConn(btn.MouseButton1Click:Connect(function()
        if enabledNow() then
            M.Destroy()
        end
    end))

    return gui
end

M.Gui = buildStopGui()

local nextAt = now() + nextJitteredIntervalSeconds(INPUT_BASE_INTERVAL_S)

trackConn(Run.Heartbeat:Connect(function()
    if not enabledNow() then return end
    local t = now()
    if t < nextAt then return end
    pcall(afkComboAction)
    nextAt = t + nextJitteredIntervalSeconds(INPUT_BASE_INTERVAL_S)
end))

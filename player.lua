--=====================================================
-- 1337 Nights | Player Tab (mobile fly only, optimized)
--=====================================================
return function(C, R, UI)
    local Players    = C.Services.Players
    local RunService = C.Services.RunService or game:GetService("RunService")
    local UIS        = C.Services.UIS        or game:GetService("UserInputService")
    local WS         = C.Services.WS         or game:GetService("Workspace")
    local VIM        = C.Services.VIM        or game:GetService("VirtualInputManager")
    local VU         = C.Services.VU         or game:GetService("VirtualUser")
    local PPS        = C.Services.PPS        or game:GetService("ProximityPromptService")

    local lp = Players.LocalPlayer
    local tab = UI.Tabs and UI.Tabs.Player
    assert(tab, "Player tab not found in UI")

    local function clearInstance(x) if x then pcall(function() x:Destroy() end) end end
    local function disconnectConn(c) if c then pcall(function() c:Disconnect() end) end end

    local function humanoid()
        local ch = lp.Character
        return ch and ch:FindFirstChildOfClass("Humanoid")
    end

    local function hrp()
        local ch = lp.Character or lp.CharacterAdded:Wait()
        return ch:FindFirstChild("HumanoidRootPart")
    end

    local function zeroAssembly(root)
        if not root then return end
        root.AssemblyLinearVelocity  = Vector3.new()
        root.AssemblyAngularVelocity = Vector3.new()
    end

    local function mainPart(m)
        if not m then return nil end
        if m:IsA("BasePart") then return m end
        if m:IsA("Model") then
            if m.PrimaryPart then return m.PrimaryPart end
            return m:FindFirstChildWhichIsA("BasePart")
        end
        return nil
    end

    local function groundBelow(pos)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ex = { lp.Character }

        local map = WS:FindFirstChild("Map")
        if map then
            local fol = map:FindFirstChild("Foliage")
            if fol then table.insert(ex, fol) end
        end

        local items = WS:FindFirstChild("Items")
        if items then table.insert(ex, items) end

        params.FilterDescendantsInstances = ex

        local start = pos + Vector3.new(0, 5, 0)
        local hit = WS:Raycast(start, Vector3.new(0, -1000, 0), params)
        if hit then return hit.Position end

        hit = WS:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -1000, 0), params)
        return (hit and hit.Position) or pos
    end

    C.State = C.State or {}
    do
        local key = "__PlayerTab1337Nights"
        local prev = C.State[key]
        if prev and prev.__cleanup then pcall(prev.__cleanup) end
        C.State[key] = {}
    end
    local BAG = C.State["__PlayerTab1337Nights"]

    local flyEnabled = false
    local FLYING = false
    local flySpeed = 3

    local walkSpeedValue = 50
    local speedEnabled = true

    local noclipEnabled = false
    local infiniteJumpEnabled = true

    local bodyGyro, bodyVelocity
    local flyRenderConn, flyCharConn
    local speedConn

    local noclipAddedConn, noclipCharConn, noclipTimerConn
    local noclipTouched = {}
    local noclipOrig    = {}
    local noclipLastReassert = 0

    local jumpConn

    local cachedControlModule = nil
    local cachedControlOk = false

    local function cacheControlModule()
        cachedControlModule = nil
        cachedControlOk = false
        local ok, cm = pcall(function()
            local ps = lp:FindFirstChildOfClass("PlayerScripts") or lp:WaitForChild("PlayerScripts", 2)
            if not ps then return nil end
            local pm = ps:FindFirstChild("PlayerModule") or ps:WaitForChild("PlayerModule", 2)
            if not pm then return nil end
            local mod = pm:FindFirstChild("ControlModule") or pm:WaitForChild("ControlModule", 2)
            if not mod then return nil end
            return require(mod)
        end)
        if ok and cm and type(cm.GetMoveVector) == "function" then
            cachedControlModule = cm
            cachedControlOk = true
        end
    end

    local function ensureBodyMovers(root)
        clearInstance(bodyGyro); bodyGyro = nil
        clearInstance(bodyVelocity); bodyVelocity = nil

        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.P = 1000
        bodyGyro.D = 50
        bodyGyro.Parent = root

        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = root
    end

    local function startMobileFly()
        if FLYING then return end
        if not UIS.TouchEnabled then return end
        local root = hrp()
        local hum = humanoid()
        if not root or not hum then return end

        FLYING = true
        cacheControlModule()
        ensureBodyMovers(root)

        disconnectConn(flyRenderConn); flyRenderConn = nil
        flyRenderConn = RunService.RenderStepped:Connect(function()
            if not FLYING then return end
            local r = hrp()
            local h = humanoid()
            local cam = workspace.CurrentCamera
            if not r or not h or not cam then return end

            if bodyGyro == nil or bodyVelocity == nil or bodyGyro.Parent ~= r or bodyVelocity.Parent ~= r then
                ensureBodyMovers(r)
            end

            h.PlatformStand = true
            bodyGyro.CFrame = cam.CFrame

            local move = Vector3.zero
            if cachedControlOk and cachedControlModule then
                local ok, mv = pcall(function() return cachedControlModule:GetMoveVector() end)
                if ok and typeof(mv) == "Vector3" then move = mv end
            else
                pcall(cacheControlModule)
            end

            local spd = (flySpeed * 50)
            local vel = Vector3.zero
            vel = vel + cam.CFrame.RightVector * (move.X * spd)
            vel = vel - cam.CFrame.LookVector  * (move.Z * spd)
            bodyVelocity.Velocity = vel
        end)
    end

    local function stopMobileFly()
        FLYING = false
        disconnectConn(flyRenderConn); flyRenderConn = nil
        local hum = humanoid()
        if hum then hum.PlatformStand = false end
        clearInstance(bodyVelocity); bodyVelocity = nil
        clearInstance(bodyGyro); bodyGyro = nil
    end

    local function startFly()
        flyEnabled = true
        startMobileFly()
    end

    local function stopFly()
        flyEnabled = false
        stopMobileFly()
    end

    local function setWalkSpeed(val)
        local hum = humanoid()
        if hum then hum.WalkSpeed = val end
    end

    local function startSpeedEnforcer()
        disconnectConn(speedConn); speedConn = nil
        speedConn = RunService.Heartbeat:Connect(function()
            if not speedEnabled then return end
            local hum = humanoid()
            if hum and hum.WalkSpeed ~= walkSpeedValue then
                hum.WalkSpeed = walkSpeedValue
            end
        end)
    end

    local function setPartNoclip(part)
        if not part or not part:IsA("BasePart") then return end
        if noclipOrig[part] == nil then
            noclipOrig[part] = part.CanCollide
        end
        if part.CanCollide ~= false then
            part.CanCollide = false
        end
        noclipTouched[part] = true
    end

    local function restoreNoclipParts()
        for part, orig in pairs(noclipOrig) do
            if part and part.Parent and part:IsA("BasePart") then
                part.CanCollide = orig
            end
        end
    end

    local function applyNoclipToCharacter(ch)
        if not ch then return end
        for _, inst in ipairs(ch:GetDescendants()) do
            if inst:IsA("BasePart") then
                setPartNoclip(inst)
            end
        end
    end

    local function hookNoclipDescendants(ch)
        disconnectConn(noclipAddedConn); noclipAddedConn = nil
        if not ch then return end
        noclipAddedConn = ch.DescendantAdded:Connect(function(inst)
            if not noclipEnabled then return end
            if inst:IsA("BasePart") then
                setPartNoclip(inst)
            end
        end)
    end

    local function startNoclip()
        if noclipEnabled then return end
        noclipEnabled = true
        noclipTouched = {}
        noclipOrig = {}

        local ch = lp.Character
        if ch then
            applyNoclipToCharacter(ch)
            hookNoclipDescendants(ch)
        end

        disconnectConn(noclipCharConn); noclipCharConn = nil
        noclipCharConn = lp.CharacterAdded:Connect(function(newCh)
            if not noclipEnabled then return end
            task.defer(function()
                noclipTouched = {}
                noclipOrig = {}
                applyNoclipToCharacter(newCh)
                hookNoclipDescendants(newCh)
            end)
        end)

        disconnectConn(noclipTimerConn); noclipTimerConn = nil
        noclipLastReassert = 0
        noclipTimerConn = RunService.Heartbeat:Connect(function()
            if not noclipEnabled then return end
            local now = os.clock()
            if (now - noclipLastReassert) < 0.5 then return end
            noclipLastReassert = now
            for part in pairs(noclipTouched) do
                if part and part.Parent and part:IsA("BasePart") and part.CanCollide ~= false then
                    part.CanCollide = false
                end
            end
        end)
    end

    local function stopNoclip()
        if not noclipEnabled then return end
        noclipEnabled = false
        disconnectConn(noclipAddedConn); noclipAddedConn = nil
        disconnectConn(noclipCharConn);  noclipCharConn  = nil
        disconnectConn(noclipTimerConn); noclipTimerConn = nil
        restoreNoclipParts()
        noclipTouched = {}
        noclipOrig = {}
    end

    local function startInfJump()
        disconnectConn(jumpConn); jumpConn = nil
        jumpConn = UIS.JumpRequest:Connect(function()
            local hum = humanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end

    local function stopInfJump()
        disconnectConn(jumpConn); jumpConn = nil
    end

    if C.State.AFK == nil then C.State.AFK = false end
    if C.State._AFKConn ~= nil then
        pcall(function() C.State._AFKConn:Disconnect() end)
        C.State._AFKConn = nil
    end

    local INPUT_BASE_INTERVAL_S = 5
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

    local function inputOneTap()
        return vimTap(Enum.KeyCode.One)
    end

    local function afkStart()
        if C.State._AFKConn then return end
        local nextAt = now() + nextJitteredIntervalSeconds(INPUT_BASE_INTERVAL_S)
        C.State._AFKConn = RunService.Heartbeat:Connect(function()
            if not (C.State and C.State.AFK) then return end
            local t = now()
            if t < nextAt then return end
            pcall(inputOneTap)
            nextAt = t + nextJitteredIntervalSeconds(INPUT_BASE_INTERVAL_S)
        end)
    end

    local function afkStop()
        if C.State._AFKConn then
            pcall(function() C.State._AFKConn:Disconnect() end)
            C.State._AFKConn = nil
        end
    end

    --=====================================================
    -- Auto Revive (Bandage/MedKit only)
    --=====================================================
    local AR_Enable = false
    local AR_Running = false
    local AR_Busy = false
    local AR_InProgress = {}
    local AR_HealingAvailable = false

    local AR_SCAN_INTERVAL = 0.8
    local AR_MAX_ATTEMPTS = 3
    local AR_CONFIRM_WAIT = 2.2
    local AR_CONFIRM_STEP = 0.12
    local AR_STAY_SEC = 5.0

    local AR_STAND_DIST = 3.0
    local AR_STAND_UP   = 2.0

    local invConnA, invConnR
    local bpConnA, bpConnR
    local chConnA, chConnR, chConnC

    local function hasItemNamed(name)
        if not name then return false end
        local inv = lp:FindFirstChild("Inventory")
        if inv and inv:FindFirstChild(name) then return true end
        local bp = lp:FindFirstChild("Backpack")
        if bp and bp:FindFirstChild(name) then return true end
        local ch = lp.Character
        if ch and ch:FindFirstChild(name) then return true end
        return false
    end

    local function recomputeHealingAvailable()
        AR_HealingAvailable = hasItemNamed("Bandage") or hasItemNamed("MedKit")
        return AR_HealingAvailable
    end

    local function startHealingWatch()
        disconnectConn(invConnA); disconnectConn(invConnR)
        disconnectConn(bpConnA);  disconnectConn(bpConnR)
        disconnectConn(chConnA);  disconnectConn(chConnR); disconnectConn(chConnC)

        local function bind(container)
            if not container then return nil, nil end
            local a = container.ChildAdded:Connect(function() recomputeHealingAvailable() end)
            local r = container.ChildRemoved:Connect(function() recomputeHealingAvailable() end)
            return a, r
        end

        task.spawn(function()
            local inv = lp:WaitForChild("Inventory", 10)
            if inv then invConnA, invConnR = bind(inv) end

            local bp = lp:FindFirstChild("Backpack") or lp:WaitForChild("Backpack", 10)
            if bp then bpConnA, bpConnR = bind(bp) end

            local function bindChar(ch)
                disconnectConn(chConnA); disconnectConn(chConnR)
                if ch then chConnA, chConnR = bind(ch) end
            end

            bindChar(lp.Character)
            chConnC = lp.CharacterAdded:Connect(function(ch)
                task.defer(function() bindChar(ch) end)
            end)

            recomputeHealingAvailable()
        end)
    end

    local function bodyNameMatchesPlayer(bodyName, plr)
        if type(bodyName) ~= "string" or not plr then return false end
        local n1 = tostring(plr.Name or "") .. " Body"
        local n2 = tostring(plr.DisplayName or "") .. " Body"
        return bodyName == n1 or bodyName == n2
    end

    local function findPlayerBodyModel(plr)
        local chars = WS:FindFirstChild("Characters") or WS
        for _,child in ipairs(chars:GetChildren()) do
            if child and child:IsA("Model") and bodyNameMatchesPlayer(child.Name, plr) then
                return child
            end
        end
        return nil
    end

    local function bodyGoneForPlayer(plr, originalBody)
        if originalBody and (not originalBody.Parent) then return true end
        return findPlayerBodyModel(plr) == nil
    end

    local function findRevivePrompt(body)
        if not (body and body.Parent) then return nil end
        local best = nil
        local bestScore = -1

        for _,d in ipairs(body:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                local a = tostring(d.ActionText or ""):lower()
                local o = tostring(d.ObjectText or ""):lower()
                local n = tostring(d.Name or ""):lower()

                local score = 0
                if a:find("revive", 1, true) then score += 3 end
                if o:find("revive", 1, true) then score += 2 end
                if n:find("revive", 1, true) then score += 1 end

                if score > bestScore then
                    bestScore = score
                    best = d
                end
            end
        end

        if best then return best end
        return body:FindFirstChildWhichIsA("ProximityPrompt", true)
    end

    local function triggerPrompt(prompt)
        if not (prompt and prompt.Parent) then return false end
        pcall(function() prompt.Enabled = true end)
        pcall(function() prompt.RequiresLineOfSight = false end)
        pcall(function()
            if typeof(prompt.HoldDuration) == "number" and prompt.HoldDuration > 0.12 then
                prompt.HoldDuration = 0.12
            end
        end)

        local ok = pcall(function()
            PPS:TriggerPrompt(prompt)
        end)
        if ok then return true end

        local hd = 0.08
        pcall(function()
            if typeof(prompt.HoldDuration) == "number" then
                hd = math.clamp(prompt.HoldDuration, 0.02, 0.12)
            end
        end)

        local ok2 = pcall(function()
            prompt:InputHoldBegin()
            task.wait(hd)
            prompt:InputHoldEnd()
        end)
        return ok2
    end

    local function teleportToCF(cf)
        local root = hrp()
        if not root then return false end
        local ch = lp.Character
        if ch and ch.Parent then pcall(function() ch:PivotTo(cf) end) end
        local ok = pcall(function() root.CFrame = cf end)
        if ok then pcall(function() zeroAssembly(root) end) end
        return ok
    end

    local function teleportNearBody(body)
        local root = hrp()
        local bp = mainPart(body)
        if not (root and bp) then return false end

        local bodyPos = bp.Position
        local rootPos = root.Position
        local dir = (rootPos - bodyPos)
        if dir.Magnitude < 0.5 then
            dir = -bp.CFrame.LookVector
        else
            dir = dir.Unit
        end

        local standPos = bodyPos + dir * AR_STAND_DIST + Vector3.new(0, AR_STAND_UP, 0)
        local g = groundBelow(standPos)
        standPos = Vector3.new(standPos.X, g.Y + AR_STAND_UP, standPos.Z)

        return teleportToCF(CFrame.new(standPos, bodyPos))
    end

    local function collectDownedQueue()
        local chars = WS:FindFirstChild("Characters") or WS
        local out = {}

        local root = hrp()
        local origin = root and root.Position or Vector3.new(0,0,0)

        local players = Players:GetPlayers()

        for _,m in ipairs(chars:GetChildren()) do
            if m:IsA("Model") then
                local nm = tostring(m.Name or "")
                if nm:match("%sBody$") then
                    local owner = nil
                    for _,p in ipairs(players) do
                        if p ~= lp and bodyNameMatchesPlayer(nm, p) then
                            owner = p
                            break
                        end
                    end
                    if owner and not AR_InProgress[owner.UserId] and mainPart(m) then
                        local ppart = mainPart(m)
                        local dist = ppart and (ppart.Position - origin).Magnitude or math.huge
                        out[#out+1] = { plr = owner, body = m, dist = dist }
                    end
                end
            end
        end

        table.sort(out, function(a,b)
            if a.dist == b.dist then
                return tostring(a.plr.Name or "") < tostring(b.plr.Name or "")
            end
            return a.dist < b.dist
        end)

        return out
    end

    local function tryReviveOne(plr, body, startCF)
        if not (plr and body and startCF) then return false end
        if AR_InProgress[plr.UserId] then return false end
        AR_InProgress[plr.UserId] = true

        local ok = false

        local function finally()
            pcall(function() teleportToCF(startCF) end)
            AR_InProgress[plr.UserId] = nil
        end

        local success = xpcall(function()
            if not recomputeHealingAvailable() then return end

            local prompt = findRevivePrompt(body)
            if not prompt then return end

            local attempt = 0
            while attempt < AR_MAX_ATTEMPTS do
                attempt += 1
                if not (body and body.Parent) then break end
                if bodyGoneForPlayer(plr, body) then ok = true break end

                teleportNearBody(body)
                task.wait(0.06)
                triggerPrompt(prompt)

                local t0 = os.clock()
                while os.clock() - t0 < AR_CONFIRM_WAIT do
                    if bodyGoneForPlayer(plr, body) then ok = true break end
                    task.wait(AR_CONFIRM_STEP)
                end
                if ok then break end

                task.wait(0.18)
                prompt = findRevivePrompt(body) or prompt
            end

            if ok then
                local stayUntil = os.clock() + AR_STAY_SEC
                while os.clock() < stayUntil do
                    task.wait(0.2)
                end

                if not bodyGoneForPlayer(plr, body) then
                    local extra = 0
                    while extra < AR_MAX_ATTEMPTS do
                        extra += 1
                        if bodyGoneForPlayer(plr, body) then break end
                        prompt = findRevivePrompt(body) or prompt
                        if prompt then triggerPrompt(prompt) end

                        local t1 = os.clock()
                        while os.clock() - t1 < AR_CONFIRM_WAIT do
                            if bodyGoneForPlayer(plr, body) then break end
                            task.wait(AR_CONFIRM_STEP)
                        end
                        if bodyGoneForPlayer(plr, body) then break end
                        task.wait(0.15)
                    end
                    ok = bodyGoneForPlayer(plr, body)
                end
            end
        end, debug.traceback)

        finally()
        return success and ok
    end

    local function runRevivePass()
        if AR_Busy then return end
        if not recomputeHealingAvailable() then return end

        local root = hrp()
        if not root then return end

        AR_Busy = true
        local startCF = root.CFrame

        local queue = collectDownedQueue()
        for _,it in ipairs(queue) do
            if not recomputeHealingAvailable() then break end
            if it and it.plr and it.body and it.body.Parent then
                tryReviveOne(it.plr, it.body, startCF)
                task.wait(0.08)
                local r2 = hrp()
                if r2 then startCF = r2.CFrame end
            end
        end

        AR_Busy = false
    end

    local function startAutoRevive()
        if AR_Running then return end
        AR_Running = true

        local key = "__AutoRevive_Loop__PlayerTab__"
        _G[key] = (_G[key] == nil) and true or _G[key]

        BAG.__arThread = task.spawn(function()
            while AR_Running do
                task.wait(AR_SCAN_INTERVAL)
                if not (AR_Running and AR_Enable) then continue end
                if AR_Busy then continue end
                if not recomputeHealingAvailable() then continue end
                local q = collectDownedQueue()
                if #q > 0 then
                    runRevivePass()
                end
            end
        end)
    end

    local function stopAutoRevive()
        AR_Running = false
        BAG.__arThread = nil
    end

    BAG.__cleanup = function()
        if flyEnabled or FLYING then stopFly() end
        disconnectConn(flyCharConn); flyCharConn = nil
        disconnectConn(speedConn); speedConn = nil

        if noclipEnabled then
            stopNoclip()
        else
            disconnectConn(noclipAddedConn); noclipAddedConn = nil
            disconnectConn(noclipCharConn);  noclipCharConn  = nil
            disconnectConn(noclipTimerConn); noclipTimerConn = nil
        end

        if infiniteJumpEnabled then stopInfJump() else disconnectConn(jumpConn); jumpConn = nil end

        if C.State and C.State.AFK then
            C.State.AFK = false
        end
        afkStop()

        cachedControlModule = nil
        cachedControlOk = false

        AR_Enable = false
        stopAutoRevive()
        disconnectConn(invConnA); disconnectConn(invConnR)
        disconnectConn(bpConnA);  disconnectConn(bpConnR)
        disconnectConn(chConnA);  disconnectConn(chConnR); disconnectConn(chConnC)
    end

    startSpeedEnforcer()

    tab:Section({ Title = "Movement Controls", Icon = "activity" })
    tab:Slider({
        Title = "Fly Speed",
        Value = { Min = 1, Max = 20, Default = 3 },
        Callback = function(v)
            flySpeed = tonumber(v) or flySpeed
        end
    })
    tab:Toggle({
        Title = "Enable Fly (Mobile)",
        Value = false,
        Callback = function(state)
            if state then startFly() else stopFly() end
        end
    })

    tab:Divider()
    tab:Section({ Title = "Walk Speed", Icon = "walk" })
    tab:Slider({
        Title = "Speed",
        Value = { Min = 16, Max = 150, Default = 50 },
        Callback = function(v)
            walkSpeedValue = tonumber(v) or walkSpeedValue
            if speedEnabled then setWalkSpeed(walkSpeedValue) end
        end
    })
    tab:Toggle({
        Title = "Enable Speed",
        Value = true,
        Callback = function(state)
            speedEnabled = state
            if state then setWalkSpeed(walkSpeedValue) else setWalkSpeed(16) end
        end
    })

    tab:Divider()
    tab:Section({ Title = "Modifiers", Icon = "hammer" })
    tab:Toggle({
        Title = "Noclip",
        Value = false,
        Callback = function(state)
            if state then startNoclip() else stopNoclip() end
        end
    })
    tab:Toggle({
        Title = "Infinite Jump",
        Value = true,
        Callback = function(state)
            infiniteJumpEnabled = state
            if state then startInfJump() else stopInfJump() end
        end
    })
    tab:Toggle({
        Title = "AFK",
        Value = (C.State.AFK == true),
        Callback = function(state)
            C.State.AFK = (state == true)
            if C.State.AFK then
                afkStart()
            else
                afkStop()
            end
        end
    })

    tab:Divider()
    tab:Section({ Title = "Auto Revive", Icon = "heart" })
    tab:Toggle({
        Title = "Auto Revive (Bandage/MedKit only)",
        Value = false,
        Callback = function(state)
            AR_Enable = (state == true)
            if AR_Enable then startAutoRevive() else stopAutoRevive() end
        end
    })
    tab:Button({
        Title = "Revive Now",
        Callback = function()
            task.spawn(function()
                runRevivePass()
            end)
        end
    })

    if infiniteJumpEnabled then startInfJump() end
    if speedEnabled then setWalkSpeed(walkSpeedValue) end
    if C.State.AFK then afkStart() else afkStop() end

    startHealingWatch()
    recomputeHealingAvailable()

    disconnectConn(flyCharConn); flyCharConn = nil
    flyCharConn = lp.CharacterAdded:Connect(function()
        task.defer(function()
            cachedControlModule = nil
            cachedControlOk = false

            if flyEnabled then
                stopFly()
                startFly()
            end

            if speedEnabled then
                setWalkSpeed(walkSpeedValue)
            end

            if noclipEnabled then
                noclipTouched = {}
                noclipOrig = {}
                local ch = lp.Character
                if ch then
                    applyNoclipToCharacter(ch)
                    hookNoclipDescendants(ch)
                end
            end

            recomputeHealingAvailable()
        end)
    end)
end

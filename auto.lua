-- auto.lua

return function(C, R, UI)
    local function run()
        local Players  = (C and C.Services and C.Services.Players)  or game:GetService("Players")
        local RS       = (C and C.Services and C.Services.RS)       or game:GetService("ReplicatedStorage")
        local WS       = (C and C.Services and C.Services.WS)       or game:GetService("Workspace")
        local PPS      = game:GetService("ProximityPromptService")
        local Run      = (C and C.Services and C.Services.Run)      or game:GetService("RunService")

        local lp = Players.LocalPlayer
        local Tabs = (UI and UI.Tabs) or {}
        local tab  = Tabs.Auto
        if not tab then return end

        local function hrp()
            local ch = lp.Character or lp.CharacterAdded:Wait()
            return ch and ch:FindFirstChild("HumanoidRootPart")
        end
        local function hum()
            local ch = lp.Character
            return ch and ch:FindFirstChildOfClass("Humanoid")
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
        local function getRemote(name)
            local f = RS:FindFirstChild("RemoteEvents")
            return f and f:FindFirstChild(name) or nil
        end

        local DUMMY_MODEL = Instance.new("Model")
        DUMMY_MODEL.Name = "__cg_dummy__"

        local function zeroAssembly(root)
            if not root then return end
            root.AssemblyLinearVelocity  = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        end

        local STICK_DURATION    = 0.35
        local STICK_EXTRA_FR    = 2
        local STICK_CLEAR_VEL   = true
        local TELEPORT_UP_NUDGE = 0.05
        local SAFE_DROP_UP      = 4.0

        local STREAM_TIMEOUT = 6.0
        local function requestStreamAt(pos, timeout)
            local p = typeof(pos) == "CFrame" and pos.Position or pos
            local ok = pcall(function()
                WS:RequestStreamAroundAsync(p, timeout or STREAM_TIMEOUT)
            end)
            return ok
        end
        local function prefetchRing(cf, r)
            local base = typeof(cf) == "CFrame" and cf.Position or cf
            r = r or 80
            local o = {
                Vector3.new( 0,0, 0),
                Vector3.new( r,0, 0), Vector3.new(-r,0, 0),
                Vector3.new( 0,0, r), Vector3.new( 0,0,-r),
                Vector3.new( r,0, r), Vector3.new( r,0,-r),
                Vector3.new(-r,0, r), Vector3.new(-r,0,-r),
            }
            for i = 1, #o do requestStreamAt(base + o[i]) end
        end
        local function waitGameplayResumed(timeout)
            local t0 = os.clock()
            while lp and lp.GameplayPaused do
                if os.clock() - t0 > (timeout or STREAM_TIMEOUT) then break end
                Run.Heartbeat:Wait()
            end
        end

        local function snapshotCollide()
            local ch = lp.Character
            if not ch then return {} end
            local t = {}
            for _, d in ipairs(ch:GetDescendants()) do
                if d:IsA("BasePart") then t[d] = d.CanCollide end
            end
            return t
        end
        local function setCollideAll(on, snapshot)
            local ch = lp.Character
            if not ch then return end
            if on and snapshot then
                for part, can in pairs(snapshot) do
                    if part and part.Parent then part.CanCollide = can end
                end
            else
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA("BasePart") then d.CanCollide = false end
                end
            end
        end
        local function isNoclipNow()
            local ch = lp.Character
            if not ch then return false end
            local total, off = 0, 0
            for _, d in ipairs(ch:GetDescendants()) do
                if d:IsA("BasePart") then
                    total += 1
                    if d.CanCollide == false then off += 1 end
                end
            end
            return (total > 0) and ((off / total) >= 0.9) or false
        end

        local rollbackCF = nil
        local rollbackThread = nil
        local ROLLBACK_IDLE_S = 30
        local MIN_MOVE_DIST = 2.0

        local function startRollbackWatch(afterCF)
            if rollbackThread then task.cancel(rollbackThread) end
            rollbackCF = afterCF
            local startRoot = hrp()
            local startPos = startRoot and startRoot.Position or nil
            local startTime = os.clock()
            rollbackThread = task.spawn(function()
                local moved = false
                while os.clock() - startTime < ROLLBACK_IDLE_S do
                    local h = hum()
                    local r = hrp()
                    if r and startPos and (r.Position - startPos).Magnitude >= MIN_MOVE_DIST then
                        moved = true
                        break
                    end
                    if h and h.MoveDirection.Magnitude > 0.05 then
                        moved = true
                        break
                    end
                    if not lp or lp.GameplayPaused then
                        moved = true
                        break
                    end
                    Run.Heartbeat:Wait()
                end
                if (not moved) and rollbackCF then
                    local root = hrp()
                    if root then
                        local cf = rollbackCF
                        local snap = snapshotCollide()
                        setCollideAll(false)
                        prefetchRing(cf)
                        requestStreamAt(cf)
                        waitGameplayResumed(1.0)
                        pcall(function()
                            local ch = lp.Character
                            if ch and ch.PrimaryPart then ch.PrimaryPart.CFrame = cf end
                        end)
                        pcall(function() root.CFrame = cf end)
                        zeroAssembly(root)
                        setCollideAll(true, snap)
                        waitGameplayResumed(1.0)
                    end
                end
            end)
        end

        local function teleportSticky(cf, dropMode)
            local root = hrp()
            if not root then return end
            local ch = lp.Character
            local targetCF = cf + Vector3.new(0, TELEPORT_UP_NUDGE, 0)

            prefetchRing(targetCF)
            requestStreamAt(targetCF)
            waitGameplayResumed(1.0)

            local hadNoclip = isNoclipNow()
            local snap
            if not hadNoclip then
                snap = snapshotCollide()
                setCollideAll(false)
            end

            if ch then pcall(function() ch:PivotTo(targetCF) end) end
            pcall(function() root.CFrame = targetCF end)
            if STICK_CLEAR_VEL then zeroAssembly(root) end

            if dropMode then
                if not hadNoclip then setCollideAll(true, snap) end
                waitGameplayResumed(1.0)
                startRollbackWatch(targetCF)
                return
            end

            local t0 = os.clock()
            while (os.clock() - t0) < STICK_DURATION do
                if ch then pcall(function() ch:PivotTo(targetCF) end) end
                pcall(function() root.CFrame = targetCF end)
                if STICK_CLEAR_VEL then zeroAssembly(root) end
                Run.Heartbeat:Wait()
            end
            for _ = 1, STICK_EXTRA_FR do
                if ch then pcall(function() ch:PivotTo(targetCF) end) end
                pcall(function() root.CFrame = targetCF end)
                if STICK_CLEAR_VEL then zeroAssembly(root) end
                Run.Heartbeat:Wait()
            end

            if not hadNoclip then setCollideAll(true, snap) end
            if STICK_CLEAR_VEL then zeroAssembly(root) end
            waitGameplayResumed(1.0)
            startRollbackWatch(targetCF)
        end

        local function waitUntilGroundedOrMoving(timeout)
            local h = hum()
            local t0 = os.clock()
            local groundedFrames = 0
            while os.clock() - t0 < (timeout or 3) do
                if h then
                    local grounded = (h.FloorMaterial ~= Enum.Material.Air)
                    if grounded then groundedFrames += 1 else groundedFrames = 0 end
                    if groundedFrames >= 5 then
                        local t1 = os.clock()
                        while os.clock() - t1 < 0.35 do
                            if h.MoveDirection.Magnitude > 0.05 then return true end
                            Run.Heartbeat:Wait()
                        end
                        return true
                    end
                end
                Run.Heartbeat:Wait()
            end
            return false
        end

        local function teleportWithDive(targetCF)
            if not targetCF then return end
            local upCF = targetCF + Vector3.new(0, SAFE_DROP_UP, 0)
            prefetchRing(upCF)
            requestStreamAt(upCF)
            waitGameplayResumed(1.0)
            teleportSticky(upCF, true)
            waitUntilGroundedOrMoving(3)
            waitGameplayResumed(1.0)
        end

        local function fireCenterPart(fire)
            return fire:FindFirstChild("Center") or fire:FindFirstChild("InnerTouchZone") or mainPart(fire) or fire.PrimaryPart
        end
        local function resolveCampfireModel()
            local map = WS:FindFirstChild("Map")
            local cg  = map and map:FindFirstChild("Campground")
            local mf  = cg and cg:FindFirstChild("MainFire")
            if mf then return mf end
            for _, d in ipairs(WS:GetDescendants()) do
                if d:IsA("Model") then
                    local n = (d.Name or ""):lower()
                    if n == "mainfire" or n == "campfire" or n == "camp fire" then return d end
                end
            end
            return nil
        end

        local CAMPFIRE_GROUND_PAD_Y        = 4.25
        local CAMPFIRE_MIN_ABOVE_CENTER_Y  = 1.00
        local CAMPFIRE_RAY_START_ABOVE_Y   = 250
        local CAMPFIRE_RAY_DEPTH_Y         = 1600

        local function groundBelowCampfire(pos, extraExcludes)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.IgnoreWater = true

            local ex = { lp.Character }
            local map = WS:FindFirstChild("Map")
            if map then
                local fol = map:FindFirstChild("Foliage")
                if fol then table.insert(ex, fol) end
            end
            local items = WS:FindFirstChild("Items"); if items then table.insert(ex, items) end
            local chars = WS:FindFirstChild("Characters"); if chars then table.insert(ex, chars) end
            if typeof(extraExcludes) == "table" then
                for i = 1, #extraExcludes do
                    local inst = extraExcludes[i]
                    if inst then table.insert(ex, inst) end
                end
            end
            params.FilterDescendantsInstances = ex

            local start = Vector3.new(pos.X, pos.Y + CAMPFIRE_RAY_START_ABOVE_Y, pos.Z)
            local hit = WS:Raycast(start, Vector3.new(0, -CAMPFIRE_RAY_DEPTH_Y, 0), params)
            if hit then return hit.Position end
            start = Vector3.new(pos.X, pos.Y + (CAMPFIRE_RAY_START_ABOVE_Y * 2), pos.Z)
            hit = WS:Raycast(start, Vector3.new(0, -CAMPFIRE_RAY_DEPTH_Y, 0), params)
            return (hit and hit.Position) or pos
        end

        local function campfireTeleportCF()
            local fire = resolveCampfireModel()
            if not fire then return nil end
            local center = fireCenterPart(fire)
            if not center then return fire:GetPivot() end

            local look = center.CFrame.LookVector
            local zone = fire:FindFirstChild("InnerTouchZone")

            local offset = 6
            if zone and zone:IsA("BasePart") then
                offset = math.max(zone.Size.X, zone.Size.Z) * 0.5 + 4
            end

            local desiredXZ = center.Position + look * offset
            local g = groundBelowCampfire(desiredXZ, { fire })
            local minY = math.max(g.Y + CAMPFIRE_GROUND_PAD_Y, center.Position.Y + CAMPFIRE_MIN_ABOVE_CENTER_Y)
            local finalPos = Vector3.new(desiredXZ.X, minY, desiredXZ.Z)
            return CFrame.new(finalPos, center.Position)
        end

        local playerGui = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")
        local edgeGui = playerGui:FindFirstChild("EdgeButtons")
        if not edgeGui then
            edgeGui = Instance.new("ScreenGui")
            edgeGui.Name = "EdgeButtons"
            edgeGui.ResetOnSpawn = false
            pcall(function() edgeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
            edgeGui.Parent = playerGui
        end
        local stack = edgeGui:FindFirstChild("EdgeStack")
        if not stack then
            stack = Instance.new("Frame")
            stack.Name = "EdgeStack"
            stack.AnchorPoint = Vector2.new(1, 0)
            stack.Position = UDim2.new(1, -6, 0, 6)
            stack.Size = UDim2.new(0, 130, 1, -12)
            stack.BackgroundTransparency = 1
            stack.BorderSizePixel = 0
            stack.Parent = edgeGui
            local list = Instance.new("UIListLayout")
            list.Name = "VList"
            list.FillDirection = Enum.FillDirection.Vertical
            list.SortOrder = Enum.SortOrder.LayoutOrder
            list.Padding = UDim.new(0, 6)
            list.HorizontalAlignment = Enum.HorizontalAlignment.Right
            list.Parent = stack
        end

        local function makeEdgeBtn(name, label, order)
            local b = stack:FindFirstChild(name)
            if not b then
                b = Instance.new("TextButton")
                b.Name = name
                b.Size = UDim2.new(1, 0, 0, 30)
                b.Text = label
                b.TextSize = 12
                b.Font = Enum.Font.GothamBold
                b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                b.TextColor3 = Color3.new(1, 1, 1)
                b.BorderSizePixel = 0
                b.Visible = false
                b.LayoutOrder = order or 1
                b.Parent = stack
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = b
            else
                b.Text = label
                b.LayoutOrder = order or b.LayoutOrder
                b.Visible = false
            end
            return b
        end

        local campBtn = makeEdgeBtn("CampEdge", "Campfire", 1)
        local lostBtn = makeEdgeBtn("LostEdge", "Lost Child", 2)

        do
            local allow = { CampEdge = true, LostEdge = true }
            for _, child in ipairs(stack:GetChildren()) do
                if child:IsA("TextButton") and not allow[child.Name] then
                    pcall(function() child:Destroy() end)
                end
            end
            local old = stack:FindFirstChild("SkipNightEdge")
            if old then pcall(function() old:Destroy() end) end
        end

        local showCampEdge = true
        campBtn.Visible = showCampEdge
        lostBtn.Visible = false

        campBtn.MouseButton1Click:Connect(function()
            local cf = campfireTeleportCF()
            if cf then teleportWithDive(cf) end
        end)

        tab:Toggle({
            Title = "Edge Button: Campfire",
            Value = true,
            Callback = function(state)
                showCampEdge = state
                if campBtn then campBtn.Visible = state end
            end
        })

        local MAX_TO_SAVE, savedCount = 4, 0
        local autoLostEnabled = false
        local lostEligible = setmetatable({}, { __mode = "k" })
        local visitedLost  = setmetatable({}, { __mode = "k" })
        local lostModelConns = setmetatable({}, { __mode = "k" })
        local lostDescAddConn = nil
        local lostBtnConn = nil

        local function isLostChildModel(m)
            return m and m:IsA("Model") and m.Name:match("^Lost Child")
        end
        local function refreshLostBtn()
            if not autoLostEnabled then
                lostBtn.Visible = false
                return
            end
            local anyEligible = next(lostEligible) ~= nil
            lostBtn.Visible = (savedCount < MAX_TO_SAVE) and anyEligible
        end
        local function onLostAttrChange(m)
            if not autoLostEnabled then return end
            local v = m:GetAttribute("Lost") == true
            local was = lostEligible[m] == true
            if v then
                lostEligible[m] = true
                visitedLost[m] = nil
            else
                if was and savedCount < MAX_TO_SAVE then savedCount += 1 end
                lostEligible[m] = nil
                visitedLost[m] = nil
            end
            refreshLostBtn()
        end
        local function untrackLostModel(m)
            local t = lostModelConns[m]
            if t then
                for i = 1, #t do
                    local c = t[i]
                    if c and c.Disconnect then pcall(function() c:Disconnect() end) end
                end
            end
            lostModelConns[m] = nil
            lostEligible[m] = nil
            visitedLost[m] = nil
        end
        local function trackLostModel(m)
            if not autoLostEnabled then return end
            if not isLostChildModel(m) then return end
            if lostModelConns[m] then
                onLostAttrChange(m)
                return
            end
            onLostAttrChange(m)
            local conns = {}
            conns[#conns+1] = m:GetAttributeChangedSignal("Lost"):Connect(function()
                if autoLostEnabled then onLostAttrChange(m) end
            end)
            conns[#conns+1] = m.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    untrackLostModel(m)
                    refreshLostBtn()
                end
            end)
            lostModelConns[m] = conns
        end
        local function findUnvisitedLost()
            local root = hrp()
            if not root then return nil end
            local best, bestD = nil, math.huge
            for m, _ in pairs(lostEligible) do
                if not visitedLost[m] then
                    local mp = mainPart(m)
                    if mp then
                        local dist = (mp.Position - root.Position).Magnitude
                        if dist < bestD then bestD, best = dist, m end
                    end
                end
            end
            return best
        end
        local function findNearestEligibleLost()
            local root = hrp()
            if not root then return nil end
            local best, bestD = nil, math.huge
            for m, _ in pairs(lostEligible) do
                local mp = mainPart(m)
                if mp then
                    local dist = (mp.Position - root.Position).Magnitude
                    if dist < bestD then bestD, best = dist, m end
                end
            end
            return best
        end
        local function teleportToNearestLost()
            if not autoLostEnabled then return end
            if savedCount >= MAX_TO_SAVE then return end
            local target = findUnvisitedLost()
            if not target then target = findNearestEligibleLost() end
            if not target then return end
            local mp = mainPart(target)
            if mp then
                visitedLost[target] = mp.Position
                teleportWithDive(CFrame.new(mp.Position + Vector3.new(0, 3, 0), mp.Position))
            end
        end
        local function enableLostChild()
            if autoLostEnabled then return end
            autoLostEnabled = true
            savedCount = 0
            table.clear(lostEligible)
            table.clear(visitedLost)
            for m, _ in pairs(lostModelConns) do untrackLostModel(m) end
            for _, d in ipairs(WS:GetDescendants()) do trackLostModel(d) end
            if lostDescAddConn then lostDescAddConn:Disconnect() lostDescAddConn = nil end
            lostDescAddConn = WS.DescendantAdded:Connect(function(d) trackLostModel(d) end)
            if lostBtnConn then lostBtnConn:Disconnect() lostBtnConn = nil end
            lostBtnConn = lostBtn.MouseButton1Click:Connect(function() teleportToNearestLost() end)
            refreshLostBtn()
        end
        local function disableLostChild()
            if not autoLostEnabled then
                lostBtn.Visible = false
                return
            end
            autoLostEnabled = false
            if lostDescAddConn then lostDescAddConn:Disconnect() lostDescAddConn = nil end
            if lostBtnConn then lostBtnConn:Disconnect() lostBtnConn = nil end
            for m, _ in pairs(lostModelConns) do untrackLostModel(m) end
            table.clear(lostEligible)
            table.clear(visitedLost)
            lostBtn.Visible = false
        end

        tab:Toggle({
            Title = "Teleport to Missing Kids",
            Value = true,
            Callback = function(state)
                if state then enableLostChild() else disableLostChild() end
            end
        })
        task.defer(enableLostChild)

        local godOn = false
        local godHB = nil
        local godLastHealth = nil
        local godRecentUntil = 0
        local godHealthConn = nil
        local godCharConn = nil
        local GOD_POST_DAMAGE_WINDOW = 8.0
        local GOD_POST_DAMAGE_INTERVAL = 1.5
        local GOD_IDLE_INTERVAL = 15.0

        local function fireGod()
            local f = RS:FindFirstChild("RemoteEvents")
            local ev = f and f:FindFirstChild("DamagePlayer")
            if ev and ev:IsA("RemoteEvent") then
                pcall(function() ev:FireServer(-math.huge) end)
            end
        end

        local function bindGodToHumanoid()
            if godHealthConn then godHealthConn:Disconnect() godHealthConn = nil end
            local h = hum()
            if not h then return end
            godLastHealth = h.Health
            godHealthConn = h.HealthChanged:Connect(function(newHealth)
                if not godOn then return end
                if typeof(newHealth) ~= "number" then return end
                local last = godLastHealth
                godLastHealth = newHealth
                if last ~= nil and newHealth < last then
                    godRecentUntil = os.clock() + GOD_POST_DAMAGE_WINDOW
                    fireGod()
                    task.defer(fireGod)
                end
            end)
        end

        local function enableGod()
            if godOn then return end
            godOn = true
            bindGodToHumanoid()
            if godCharConn then godCharConn:Disconnect() godCharConn = nil end
            godCharConn = lp.CharacterAdded:Connect(function()
                task.wait(0.15)
                if godOn then bindGodToHumanoid() end
            end)
            if godHB then godHB:Disconnect() end
            local acc = 0
            godHB = Run.Heartbeat:Connect(function(dt)
                if not godOn then return end
                acc += dt
                local now = os.clock()
                local interval = (now <= godRecentUntil) and GOD_POST_DAMAGE_INTERVAL or GOD_IDLE_INTERVAL
                if acc >= interval then
                    acc = 0
                    fireGod()
                end
            end)
        end
        local function disableGod()
            godOn = false
            if godHB then godHB:Disconnect() godHB = nil end
            if godHealthConn then godHealthConn:Disconnect() godHealthConn = nil end
            if godCharConn then godCharConn:Disconnect() godCharConn = nil end
            godLastHealth = nil
            godRecentUntil = 0
        end

        tab:Toggle({
            Title = "Godmode",
            Value = true,
            Callback = function(state)
                if state then enableGod() else disableGod() end
            end
        })
        task.defer(enableGod)

        local INSTANT_HOLD, TRIGGER_COOLDOWN = 0.2, 0.2
        local EXCLUDE_NAME_SUBSTR = { "door", "closet", "gate", "hatch" }
        local EXCLUDE_ANCESTOR_SUBSTR = { "closetdoors", "closet", "door", "landmarks" }
        local UID_OPEN_KEY = tostring(lp.UserId) .. "Opened"

        local function strfindAny(s, list)
            s = string.lower(s or "")
            for _, w in ipairs(list) do
                if string.find(s, w, 1, true) then return true end
            end
            return false
        end
        local function trimUpper(s)
            s = tostring(s or "")
            s = s:gsub("^%s+", ""):gsub("%s+$", "")
            return string.upper(s)
        end
        local function shouldSkipPrompt(p)
            if not p or not p.Parent then return true end
            if strfindAny(p.Name, EXCLUDE_NAME_SUBSTR) then return true end
            local ot = trimUpper(p.ObjectText)
            local at = trimUpper(p.ActionText)
            if ot == "TELEPORT" or at == "TELEPORT" then return true end
            pcall(function()
                if strfindAny(p.ObjectText, EXCLUDE_NAME_SUBSTR) then error(true) end
                if strfindAny(p.ActionText, EXCLUDE_NAME_SUBSTR) then error(true) end
            end)
            local a = p.Parent
            while a and a ~= workspace do
                if strfindAny(a.Name, EXCLUDE_ANCESTOR_SUBSTR) then return true end
                a = a.Parent
            end
            return false
        end

        local promptDurations = setmetatable({}, { __mode = "k" })
        local shownConn, trigConn, hiddenConn

        local function restorePrompt(prompt)
            local orig = promptDurations[prompt]
            if orig ~= nil and prompt and prompt.Parent then
                pcall(function() prompt.HoldDuration = orig end)
            end
            promptDurations[prompt] = nil
        end
        local function tagChestFromPrompt(prompt)
            if not prompt then return end
            local node = prompt
            for _ = 1, 8 do
                if not node then break end
                if node:IsA("Model") then
                    local n = node.Name
                    if type(n) == "string" and (n:match("Chest%d*$") or n:match("Chest$")) then
                        pcall(function() node:SetAttribute(UID_OPEN_KEY, true) end)
                        break
                    end
                end
                node = node.Parent
            end
        end
        local function onPromptShown(prompt)
            if not prompt or not prompt:IsA("ProximityPrompt") then return end
            if shouldSkipPrompt(prompt) then return end
            if promptDurations[prompt] == nil then promptDurations[prompt] = prompt.HoldDuration end
            if prompt and prompt.Parent and not shouldSkipPrompt(prompt) then
                pcall(function() prompt.HoldDuration = INSTANT_HOLD end)
            end
        end

        local function enableInstantInteract()
            if shownConn then return end
            shownConn = PPS.PromptShown:Connect(onPromptShown)
            trigConn = PPS.PromptTriggered:Connect(function(prompt, player)
                if player ~= lp or shouldSkipPrompt(prompt) then return end
                tagChestFromPrompt(prompt)
                if TRIGGER_COOLDOWN and TRIGGER_COOLDOWN > 0 then
                    pcall(function() prompt.Enabled = false end)
                    task.delay(TRIGGER_COOLDOWN, function()
                        if prompt and prompt.Parent then pcall(function() prompt.Enabled = true end) end
                    end)
                end
                restorePrompt(prompt)
            end)
            hiddenConn = PPS.PromptHidden:Connect(function(prompt)
                if shouldSkipPrompt(prompt) then return end
                restorePrompt(prompt)
            end)
        end
        local function disableInstantInteract()
            if shownConn then shownConn:Disconnect() shownConn = nil end
            if trigConn then trigConn:Disconnect() trigConn = nil end
            if hiddenConn then hiddenConn:Disconnect() hiddenConn = nil end
            for p, _ in pairs(promptDurations) do restorePrompt(p) end
        end

        enableInstantInteract()
        tab:Toggle({
            Title = "Instant Interact",
            Value = true,
            Callback = function(state)
                if state then enableInstantInteract() else disableInstantInteract() end
            end
        })

        local FLASHLIGHT_PREF = { "Strong Flashlight", "Old Flashlight" }
        local MONSTER_NAMES = { "Deer", "Ram", "Owl" }
        local STUN_RADIUS = 24
        local OFF_PULSE_EVERY = 1.5
        local autoStunOn, autoStunThread = false, nil
        local lastFlashState, lastFlashName = nil, nil

        local function resolveFlashlightName()
            local inv = lp and lp:FindFirstChild("Inventory")
            if not inv then return nil end
            for _, n in ipairs(FLASHLIGHT_PREF) do
                if inv:FindFirstChild(n) then return n end
            end
            return nil
        end
        local function equipFlashlight(name)
            local inv = lp and lp:FindFirstChild("Inventory")
            if not (inv and name) then return false end
            local item = inv:FindFirstChild(name)
            if not item then return false end
            local equip = getRemote("EquipItemHandle")
            local eqf = getRemote("EquippedFlashlight")
            if equip and equip:IsA("RemoteEvent") then pcall(function() equip:FireServer("FireAllClients", item) end) end
            if eqf and eqf:IsA("RemoteEvent") then pcall(function() eqf:FireServer() end) end
            return true
        end
        local function setFlashlight(state, name)
            local ev = getRemote("FlashlightToggle")
            if not ev or not name then return end
            if state and lastFlashName ~= name then equipFlashlight(name) end
            if lastFlashState == state and lastFlashName == name then return end
            pcall(function() ev:FireServer(state, name) end)
            lastFlashState, lastFlashName = state, name
        end
        local function forceFlashlightOffAll()
            local ev = getRemote("FlashlightToggle")
            if not ev then return end
            pcall(function() ev:FireServer(false, "Strong Flashlight") end)
            pcall(function() ev:FireServer(false, "Old Flashlight") end)
            lastFlashState, lastFlashName = nil, nil
        end
        local function nearestMonsterWithin(radius)
            local chars = WS:FindFirstChild("Characters")
            local root = hrp()
            if not (chars and root) then return nil end
            local best, bestD = nil, radius
            for _, m in ipairs(chars:GetChildren()) do
                if m:IsA("Model") then
                    local n = m.Name
                    for _, want in ipairs(MONSTER_NAMES) do
                        if n == want then
                            local mp = mainPart(m)
                            if mp then
                                local d = (mp.Position - root.Position).Magnitude
                                if d <= bestD then bestD, best = d, m end
                            end
                            break
                        end
                    end
                end
            end
            return best
        end
        local function torchHit(targetModel)
            local torch = getRemote("MonsterHitByTorch")
            if not torch then return end
            local ok = pcall(function()
                if torch:IsA("RemoteFunction") then
                    return torch:InvokeServer(targetModel or DUMMY_MODEL)
                else
                    return torch:FireServer(targetModel or DUMMY_MODEL)
                end
            end)
            return ok
        end

        local function enableAutoStun()
            if autoStunOn then return end
            autoStunOn = true
            autoStunThread = task.spawn(function()
                forceFlashlightOffAll()
                local fname = resolveFlashlightName()
                local lastPulse = os.clock()
                while autoStunOn do
                    if not fname then fname = resolveFlashlightName() end
                    local target = nearestMonsterWithin(STUN_RADIUS)
                    if fname and target then
                        setFlashlight(true, fname)
                        for _ = 1, 2 do torchHit(target) end
                        if os.clock() - lastPulse >= OFF_PULSE_EVERY then
                            setFlashlight(false, fname)
                            Run.Heartbeat:Wait()
                            setFlashlight(true, fname)
                            lastPulse = os.clock()
                        end
                    else
                        if fname then setFlashlight(false, fname) end
                        lastPulse = os.clock()
                        task.wait(0.15)
                    end
                    Run.Heartbeat:Wait()
                end
                forceFlashlightOffAll()
            end)
        end
        local function disableAutoStun()
            autoStunOn = false
        end

        tab:Toggle({
            Title = "Auto Stun Monster",
            Value = true,
            Callback = function(state)
                if state then enableAutoStun() else disableAutoStun() end
            end
        })
        task.defer(enableAutoStun)

        --=====================================================
        -- Auto Revive (Bandage/MedKit only)  [PATCHED IN]
        -- (UI title requested: "Auto Revive")
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

        local function groundBelowRevive(pos)
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

        local function disconnectConn(c)
            if c then pcall(function() c:Disconnect() end) end
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
            for _, child in ipairs(chars:GetChildren()) do
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

            for _, d in ipairs(body:GetDescendants()) do
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

        local function triggerPromptRevive(prompt)
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

        local function teleportToCFRevive(cf)
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
            local g = groundBelowRevive(standPos)
            standPos = Vector3.new(standPos.X, g.Y + AR_STAND_UP, standPos.Z)

            return teleportToCFRevive(CFrame.new(standPos, bodyPos))
        end

        local function collectDownedQueue()
            local chars = WS:FindFirstChild("Characters") or WS
            local out = {}

            local root = hrp()
            local origin = root and root.Position or Vector3.new(0,0,0)

            local players = Players:GetPlayers()

            for _, m in ipairs(chars:GetChildren()) do
                if m:IsA("Model") then
                    local nm = tostring(m.Name or "")
                    if nm:match("%sBody$") then
                        local owner = nil
                        for _, p in ipairs(players) do
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
                pcall(function() teleportToCFRevive(startCF) end)
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
                    triggerPromptRevive(prompt)

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
                            if prompt then triggerPromptRevive(prompt) end

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
            for _, it in ipairs(queue) do
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

            local key = "__AutoRevive_Loop__"
            local prev = _G[key]
            if prev and typeof(prev) == "thread" then
                _G[key] = nil
            end

            _G[key] = task.spawn(function()
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
        end

        if tab.Section then
            tab:Section({ Title = "Auto Revive" })
        end

        tab:Toggle({
            Title = "Auto Revive",
            Value = false,
            Callback = function(v)
                AR_Enable = v and true or false
                if AR_Enable then startAutoRevive() else stopAutoRevive() end
            end
        })

        startHealingWatch()
        recomputeHealingAvailable()

        Players.LocalPlayer.CharacterAdded:Connect(function()
            local playerGui2 = lp:WaitForChild("PlayerGui")
            local edgeGui2 = playerGui2:FindFirstChild("EdgeButtons")
            if edgeGui2 and edgeGui2.Parent ~= playerGui2 then edgeGui2.Parent = playerGui2 end
            if campBtn then campBtn.Visible = showCampEdge end
            lostBtn.Visible = false
            if godOn then
                task.wait(0.15)
                bindGodToHumanoid()
            end
            if autoLostEnabled then
                task.wait(0.15)
                for _, d in ipairs(WS:GetDescendants()) do trackLostModel(d) end
                refreshLostBtn()
            end
        end)
    end

    local ok, err = pcall(run)
    if not ok then warn("[Auto] module error: " .. tostring(err)) end
end

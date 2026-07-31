-- special.lua

return function(C, R, UI)
    local function run()
        C  = C  or _G.C
        UI = UI or _G.UI

        local Players = (C and C.Services and C.Services.Players) or game:GetService("Players")
        local RS      = (C and C.Services and C.Services.RS)      or game:GetService("ReplicatedStorage")
        local WS      = (C and C.Services and C.Services.WS)      or game:GetService("Workspace")
        local Run     = (C and C.Services and C.Services.Run)      or game:GetService("RunService")
        local VIM     = game:GetService("VirtualInputManager")

        local lp   = Players.LocalPlayer
        local Tabs = (UI and UI.Tabs) or {}
        local tab  = Tabs.Special
        if not tab then return end

        C.State = C.State or {}
        C.State.Toggles = C.State.Toggles or {}

        local RootRS, RootWS = nil, nil

        local function refreshRoots()
            local ugc = game:FindFirstChild("Ugc")
            if ugc then
                local rs = ugc:FindFirstChild("ReplicatedStorage")
                local ws = ugc:FindFirstChild("Workspace")
                if rs and ws then
                    RootRS = rs
                    RootWS = ws
                    return RootRS, RootWS
                end
            end
            RootRS = RS
            RootWS = WS
            return RootRS, RootWS
        end
        refreshRoots()

        local function chr()
            return lp.Character or lp.CharacterAdded:Wait()
        end

        local function hrp()
            local ch = chr()
            return ch and ch:WaitForChild("HumanoidRootPart")
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
                return m:FindFirstChildWhichIsA("BasePart", true)
            end
            return nil
        end

        local function getRemote(name)
            refreshRoots()
            local f = RootRS:FindFirstChild("RemoteEvents")
            local r = f and f:FindFirstChild(name)
            if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
            for _, d in ipairs(RootRS:GetDescendants()) do
                if d.Name == name and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then
                    return d
                end
            end
            return nil
        end

        local function lower(s)
            return (type(s) == "string") and string.lower(s) or ""
        end

        local function itemsFolder()
            refreshRoots()
            local f = RootWS:FindFirstChild("Items")
            if f then return f end
            return WS:FindFirstChild("Items")
        end

        local function isMyCharModel(m)
            local c = lp.Character
            return c and m == c
        end

        local function isSelectedNPC(m, selectedSet)
            if not (m and m:IsA("Model")) then return false end
            if isMyCharModel(m) then return false end
            if not m:FindFirstChildWhichIsA("Humanoid", true) then return false end
            local n = lower(m.Name or "")
            if selectedSet["Cultist"] and n:find("cultist", 1, true) then return true end
            if selectedSet["Alien"]   and n:find("alien",   1, true) then return true end
            return false
        end

        local function isSelectedItem(inst, selectedSet)
            if not inst then return false end
            local ln = lower(inst.Name or "")
            if selectedSet["Sapling"] and ln == "sapling" then return true end
            return false
        end

        local function topModelUnderItems(part, items)
            local cur = part
            local lastModel = nil
            while cur and cur ~= WS and cur ~= RootWS and cur ~= items do
                if cur:IsA("Model") then lastModel = cur end
                cur = cur.Parent
            end
            if lastModel and items and lastModel:IsDescendantOf(items) then
                return lastModel
            end
            return lastModel
        end

        local function candidateFromPart(part, items, selectedSet)
            if not (part and part:IsA("BasePart")) then return nil end
            if RootWS ~= WS and not part:IsDescendantOf(RootWS) then return nil end
            if items and part:IsDescendantOf(items) then
                local m = topModelUnderItems(part, items) or part:FindFirstAncestorOfClass("Model")
                if m and isSelectedItem(m, selectedSet) then return m end
                if m and isSelectedNPC(m, selectedSet) then return m end
            end
            local m = part:FindFirstAncestorOfClass("Model")
            if m and isSelectedNPC(m, selectedSet) then return m end
            return nil
        end

        local function findLavaBurnRemote()
            refreshRoots()
            local remFolder = RootRS:FindFirstChild("RemoteEvents") or RootRS
            local r = remFolder:FindFirstChild("RequestLavaBurnItem")
            if r and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then return r end
            for _, d in ipairs(RootRS:GetDescendants()) do
                if d.Name == "RequestLavaBurnItem" and (d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) then
                    return d
                end
            end
            return nil
        end

        local function findLava()
            refreshRoots()
            local direct = RootWS:FindFirstChild("Map")
            if direct then
                local lm = direct:FindFirstChild("Landmarks")
                local v  = lm and lm:FindFirstChild("Volcano")
                local f  = v and v:FindFirstChild("Functional")
                local lv = f and f:FindFirstChild("Lava")
                if lv and lv:IsA("BasePart") then return lv end
            end
            for _, d in ipairs(RootWS:GetDescendants()) do
                if d:IsA("BasePart") and d.Name == "Lava" then
                    local a = d.Parent
                    while a do
                        if a.Name == "Volcano" then return d end
                        a = a.Parent
                    end
                end
            end
            return nil
        end

        local SCAN_RADIUS = 140

        local burnBusy = false
        local function burnTargets(selectedSet)
            if burnBusy then return end
            burnBusy = true
            pcall(function()
                local Remote = findLavaBurnRemote()
                local Lava   = findLava()
                if not (Remote and Lava and Lava.Parent) then
                    warn("[Special] LavaBurn missing Remote or Lava")
                    return
                end

                local root = hrp()
                if not root then return end
                local items = itemsFolder()

                local params = OverlapParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = { lp.Character }

                local parts = WS:GetPartBoundsInRadius(root.Position, SCAN_RADIUS, params) or {}
                local uniq, targets = {}, {}
                for _, p in ipairs(parts) do
                    local cand = candidateFromPart(p, items, selectedSet)
                    if cand and not uniq[cand] then
                        uniq[cand] = true
                        targets[#targets+1] = cand
                    end
                end

                local okN, errN = 0, 0
                for i = 1, #targets do
                    local inst = targets[i]
                    if inst and inst.Parent then
                        local okCall
                        if Remote:IsA("RemoteFunction") then
                            okCall = pcall(function() return Remote:InvokeServer(inst, Lava) end)
                        else
                            okCall = pcall(function() Remote:FireServer(inst, Lava) end)
                        end
                        if okCall then okN += 1 else errN += 1 end
                    end
                    if i % 8 == 0 then Run.Heartbeat:Wait() end
                    task.wait(0.02)
                end
                warn(("[Special] LavaBurn: radius=%d targets=%d ok=%d err=%d"):format(SCAN_RADIUS, #targets, okN, errN))
            end)
            burnBusy = false
        end

        local burnAllBusy = false
        local function burnAllSaplings()
            if burnAllBusy then return end
            burnAllBusy = true
            task.spawn(function()
                pcall(function()
                    local items = itemsFolder()
                    if not items then return end
                    local Remote = findLavaBurnRemote()
                    local Lava = findLava()
                    if not (Remote and Lava and Lava.Parent) then
                        warn("[Special] BurnAllSaplings missing Remote or Lava")
                        return
                    end

                    local okN, errN = 0, 0
                    for _, inst in ipairs(items:GetChildren()) do
                        if inst:IsA("Model") and lower(inst.Name or "") == "sapling" then
                            local okCall
                            if Remote:IsA("RemoteFunction") then
                                okCall = pcall(function() return Remote:InvokeServer(inst, Lava) end)
                            else
                                okCall = pcall(function() Remote:FireServer(inst, Lava) end)
                            end
                            if okCall then okN += 1 else errN += 1 end
                            task.wait(0.02)
                        end
                    end
                    warn(("[Special] BurnAllSaplings: ok=%d err=%d"):format(okN, errN))
                end)
                burnAllBusy = false
            end)
        end

        tab:Section({ Title = "Lava Burn" })

        tab:Button({
            Title = "Burn Cultists",
            Callback = function()
                burnTargets({ Cultist = true })
            end
        })

        tab:Button({
            Title = "Burn Aliens",
            Callback = function()
                burnTargets({ Alien = true })
            end
        })

        tab:Button({
            Title = "Burn Saplings",
            Callback = function()
                burnAllSaplings()
            end
        })

        local autoBurnConn = nil
        local autoBurnSeen = {}

        local function stopAutoBurn()
            if autoBurnConn then
                pcall(function() autoBurnConn:Disconnect() end)
                autoBurnConn = nil
            end
            autoBurnSeen = {}
        end

        local function startAutoBurn()
            stopAutoBurn()
            local items = itemsFolder()
            if not items then return end

            autoBurnConn = items.DescendantAdded:Connect(function(inst)
                if not inst:IsA("Model") then return end
                if autoBurnSeen[inst] then return end
                local n = lower(inst.Name or "")
                if not n:find("cultist", 1, true) then return end
                if not inst:FindFirstChildWhichIsA("Humanoid", true) then return end
                autoBurnSeen[inst] = true

                task.spawn(function()
                    task.wait(0.2)
                    if not (inst and inst.Parent) then return end
                    local Remote = findLavaBurnRemote()
                    local Lava = findLava()
                    if not (Remote and Lava and Lava.Parent) then return end
                    pcall(function()
                        if Remote:IsA("RemoteFunction") then
                            Remote:InvokeServer(inst, Lava)
                        else
                            Remote:FireServer(inst, Lava)
                        end
                    end)
                    task.delay(30, function()
                        autoBurnSeen[inst] = nil
                    end)
                end)
            end)
        end

        if C.State.Toggles.SpecialAutoBurnCultist == nil then
            C.State.Toggles.SpecialAutoBurnCultist = false
        end

        tab:Toggle({
            Title = "Auto Burn: Cultist",
            Value = (C.State.Toggles.SpecialAutoBurnCultist == true),
            Callback = function(state)
                C.State.Toggles.SpecialAutoBurnCultist = (state == true)
                if state then
                    startAutoBurn()
                else
                    stopAutoBurn()
                end
            end
        })

        if C.State.Toggles.SpecialAutoBurnCultist == true then
            startAutoBurn()
        end

        local cam = WS.CurrentCamera
        local camConn = WS:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            cam = WS.CurrentCamera
        end)

        local DUMMY_MODEL = Instance.new("Model")
        DUMMY_MODEL.Name = "__sp_dummy__"

        local function zeroAssembly(root)
            if not root then return end
            root.AssemblyLinearVelocity  = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        end

        local STREAM_TIMEOUT = 6.0
        local function requestStreamAt(pos, timeout)
            local p = typeof(pos) == "CFrame" and pos.Position or pos
            local ok = pcall(function() WS:RequestStreamAroundAsync(p, timeout or STREAM_TIMEOUT) end)
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
            for i=1,#o do requestStreamAt(base + o[i]) end
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
            for _,d in ipairs(ch:GetDescendants()) do
                if d:IsA("BasePart") then t[d] = d.CanCollide end
            end
            return t
        end

        local function setCollideAll(on, snapshot)
            local ch = lp.Character
            if not ch then return end
            if on and snapshot then
                for part,can in pairs(snapshot) do
                    if part and part.Parent then part.CanCollide = can end
                end
            else
                for _,d in ipairs(ch:GetDescendants()) do
                    if d:IsA("BasePart") then d.CanCollide = false end
                end
            end
        end

        local function isNoclipNow()
            local ch = lp.Character
            if not ch then return false end
            local total, off = 0, 0
            for _,d in ipairs(ch:GetDescendants()) do
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

        local function stopRollbackWatch()
            rollbackCF = nil
            if rollbackThread then
                pcall(function() task.cancel(rollbackThread) end)
                rollbackThread = nil
            end
        end

        local function startRollbackWatch(afterCF)
            stopRollbackWatch()
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
                        pcall(function() (lp.Character or {}).PrimaryPart.CFrame = cf end)
                        pcall(function() root.CFrame = cf end)
                        zeroAssembly(root)
                        setCollideAll(true, snap)
                        waitGameplayResumed(1.0)
                    end
                end
            end)
        end

        local function groundBelow(pos)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ex = { lp.Character }
            refreshRoots()
            local map = (RootWS and RootWS:FindFirstChild("Map")) or WS:FindFirstChild("Map")
            if map then
                local fol = map:FindFirstChild("Foliage")
                if fol then table.insert(ex, fol) end
            end
            local items = (RootWS and RootWS:FindFirstChild("Items")) or WS:FindFirstChild("Items")
            local chars = (RootWS and RootWS:FindFirstChild("Characters")) or WS:FindFirstChild("Characters")
            if items then table.insert(ex, items) end
            if chars then table.insert(ex, chars) end
            params.FilterDescendantsInstances = ex
            local start = pos + Vector3.new(0, 5, 0)
            local hit = WS:Raycast(start, Vector3.new(0, -1000, 0), params)
            if hit then return hit.Position end
            hit = WS:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -1000, 0), params)
            return (hit and hit.Position) or pos
        end

        local STICK_DURATION    = 0.35
        local STICK_EXTRA_FR    = 2
        local STICK_CLEAR_VEL   = true
        local TELEPORT_UP_NUDGE = 1.00
        local SAFE_DROP_UP      = 4.0
        local CAMPFIRE_TP_UP_NUDGE = 2.0

        local function teleportSticky(cf, dropMode, skipNudge)
            local root = hrp()
            if not root then return end
            local ch   = lp.Character
            local targetCF = skipNudge and cf or (cf + Vector3.new(0, TELEPORT_UP_NUDGE, 0))

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
            for _=1,STICK_EXTRA_FR do
                if ch then pcall(function() ch:PivotTo(targetCF) end) end
                pcall(function() root.CFrame = targetCF end)
                if STICK_CLEAR_VEL then zeroAssembly(root) end
                Run.Heartbeat:Wait()
            end

            if not hadNoclip then
                setCollideAll(true, snap)
            end
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

        local function structureFolder()
            refreshRoots()
            return (RootWS and RootWS:FindFirstChild("Structures")) or WS:FindFirstChild("Structures")
        end

        local function modelPos(m)
            if not m then return nil end
            if m.PrimaryPart then return m.PrimaryPart.Position end
            local ok, cf = pcall(function() return m:GetPivot() end)
            if ok and cf then return cf.Position end
            local bp = m:FindFirstChildWhichIsA("BasePart", true)
            return bp and bp.Position or nil
        end

        local function resolveAccelModel()
            refreshRoots()
            local folder = structureFolder()
            if not folder then return nil end
            local m = folder:FindFirstChild("Temporal Accelerometer") or folder:FindFirstChild("TemporalAccelerometer")
            if m and m:IsA("Model") then return m end
            for _, ch in ipairs(folder:GetChildren()) do
                if ch:IsA("Model") then
                    local n = ch.Name:lower()
                    if n:find("temporal", 1, true) and n:find("acceler", 1, true) then
                        return ch
                    end
                end
            end
            return nil
        end

        local function findCampfire()
            refreshRoots()
            local map = (RootWS and RootWS:FindFirstChild("Map")) or WS:FindFirstChild("Map")
            local camp = map and map:FindFirstChild("Campground")
            return camp and camp:FindFirstChild("MainFire")
        end

        local function campfireTeleportCF()
            local fire = findCampfire()
            if not fire then return nil end
            local mp = mainPart(fire)
            local pos = mp and mp.Position or (fire:IsA("Model") and fire:GetPivot().Position)
            if not pos then return nil end
            return CFrame.new(pos + Vector3.new(0, 6 + CAMPFIRE_TP_UP_NUDGE, 0))
        end

        local function nightSkipTeleportCF(machine)
            if not machine then return nil end
            local mp = mainPart(machine) or machine.PrimaryPart
            if not mp then
                local ok, cf = pcall(function() return machine:GetPivot() end)
                return ok and cf or nil
            end
            local look = mp.CFrame.LookVector
            local desired = mp.Position - look * 8
            local g = groundBelow(desired)
            local standPos = Vector3.new(desired.X, g.Y + 3.0, desired.Z)
            return CFrame.new(standPos, mp.Position)
        end

        local function inv()
            return lp:FindFirstChild("Inventory")
        end

        local function findAccelBlueprintInstance()
            local f = inv()
            if not f then return nil end
            for _, ch in ipairs(f:GetChildren()) do
                if ch:IsA("Model") then
                    local n = ch.Name
                    if type(n) == "string" then
                        local ln = n:lower()
                        if ln:sub(-9) == "blueprint" and ln:find("temporal", 1, true) and ln:find("acceler", 1, true) then
                            return ch
                        end
                    end
                end
            end
            return nil
        end

        local function waitForAccelBlueprint(timeout)
            local t0 = os.clock()
            while os.clock() - t0 < (timeout or 8) do
                local bp = findAccelBlueprintInstance()
                if bp and bp.Parent then return bp end
                task.wait(0.15)
            end
            return nil
        end

        local function waitForAccelModel(timeout)
            local t0 = os.clock()
            while os.clock() - t0 < (timeout or 8) do
                local m = resolveAccelModel()
                if m and m.Parent then return m end
                task.wait(0.15)
            end
            return nil
        end

        local function yawRotationOnly(cf0)
            local lv = cf0.LookVector
            local flat = Vector3.new(lv.X, 0, lv.Z)
            if flat.Magnitude < 1e-6 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
            local origin = Vector3.new(0, 0, 0)
            return CFrame.lookAt(origin, origin + flat, Vector3.new(0, 1, 0))
        end

        local function placementFromExistingModel(model)
            local ok, cf0 = pcall(function() return model:GetPivot() end)
            if not ok or not cf0 then return nil, nil, nil end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { model, chr(), cam }
            local origin = cf0.Position + Vector3.new(0, 200, 0)
            local hit = WS:Raycast(origin, Vector3.new(0, -1200, 0), params)
            local groundY = hit and hit.Position.Y or cf0.Position.Y
            local yOff = cf0.Position.Y - groundY
            local rot = yawRotationOnly(cf0)
            local pos = Vector3.new(cf0.Position.X, groundY, cf0.Position.Z)
            local cf = CFrame.new(Vector3.new(pos.X, pos.Y + yOff, pos.Z)) * rot
            local placement = { Valid = true, Position = pos, CFrame = cf }
            return placement, rot, true
        end

        local function findPickUpRemote()
            refreshRoots()
            local re = RootRS:FindFirstChild("RemoteEvents")
            if re then
                local r = re:FindFirstChild("RequestPickUpStructure")
                if r and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then return r end
            end
            local rf = RootRS:FindFirstChild("RemoteFunctions")
            if rf then
                local r = rf:FindFirstChild("RequestPickUpStructure")
                if r and (r:IsA("RemoteFunction") or r:IsA("RemoteEvent")) then return r end
            end
            for _, d in ipairs(RootRS:GetDescendants()) do
                if d.Name == "RequestPickUpStructure" and (d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) then
                    return d
                end
            end
            return nil
        end

        local function doPickupStructure(targetModel)
            local remote = findPickUpRemote()
            if not (remote and targetModel and targetModel.Parent) then return false end
            local ok = pcall(function()
                if remote:IsA("RemoteFunction") then
                    remote:InvokeServer(targetModel)
                else
                    remote:FireServer(targetModel)
                end
            end)
            return ok
        end

        local function doPickupTemporalAccelerometerOnly(targetModel)
            if not (targetModel and targetModel.Parent) then return false end
            local preBlueprint = findAccelBlueprintInstance()
            local okPickup = doPickupStructure(targetModel)
            if not okPickup then return false end
            local t0 = os.clock()
            while os.clock() - t0 < 5 do
                local bp = findAccelBlueprintInstance()
                if bp and bp.Parent and bp ~= preBlueprint then return true end
                if not (targetModel and targetModel.Parent) then
                    local bp2 = findAccelBlueprintInstance()
                    if bp2 and bp2.Parent then return true end
                end
                task.wait(0.10)
            end
            return false
        end

        local function findPlaceRemote()
            refreshRoots()
            local re = RootRS:FindFirstChild("RemoteEvents")
            local r = re and re:FindFirstChild("RequestPlaceStructure")
            if r and r:IsA("RemoteFunction") then return r end
            for _, d in ipairs(RootRS:GetDescendants()) do
                if d.Name == "RequestPlaceStructure" and d:IsA("RemoteFunction") then
                    return d
                end
            end
            return nil
        end

        local function waitForBlueprintGone(timeout)
            local t0 = os.clock()
            while os.clock() - t0 < (timeout or 8) do
                if not findAccelBlueprintInstance() then return true end
                task.wait(0.10)
            end
            return false
        end

        local function placeAccelConfirmed(placeRemote, bp, placement, rot)
            if not (placeRemote and bp and placement and rot) then return false end
            pcall(function() placeRemote:InvokeServer(bp, placement, rot, nil) end)
            if waitForBlueprintGone(6) then return true end
            bp = findAccelBlueprintInstance()
            if bp and bp.Parent then
                pcall(function() placeRemote:InvokeServer(bp, placement, rot, nil) end)
                return waitForBlueprintGone(6)
            end
            return false
        end

        local function fireAccelRemote(model)
            local r = getRemote("RequestActivateNightSkipMachine")
            if not (r and model) then return false end
            local ok = pcall(function()
                if r:IsA("RemoteEvent") then
                    r:FireServer(model)
                else
                    r:InvokeServer(model)
                end
            end)
            return ok
        end

        local function vimTapKey(keyCode)
            pcall(function()
                VIM:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, keyCode, false, game)
            end)
        end

        local busy = false
        local temporalRunNonce = 0

        local function freshTemporalRunState()
            refreshRoots()
            stopRollbackWatch()
            cam = WS.CurrentCamera
            temporalRunNonce += 1
            return temporalRunNonce
        end

        local function runTemporalSequence(fromTimer)
            if busy then return end
            busy = true

            local runNonce = freshTemporalRunState()
            local root0 = hrp()
            local returnCF = root0 and root0.CFrame or nil
            local savedPlacement, savedRot = nil, nil

            local ok, err = pcall(function()
                if fromTimer == true then
                    local campCF = campfireTeleportCF()
                    if campCF then
                        teleportSticky(campCF, true)
                        task.wait(1.5)
                    end
                end

                if runNonce ~= temporalRunNonce then return end

                local machine = resolveAccelModel()
                if not machine then return end

                local destCF = nightSkipTeleportCF(machine)
                if not destCF then return end

                savedPlacement, savedRot = placementFromExistingModel(machine)
                if not savedPlacement then return end

                teleportSticky(destCF, true)
                task.wait(1.0)

                if not (machine and machine.Parent) then
                    machine = resolveAccelModel()
                    if not machine then return end
                end

                local picked = doPickupTemporalAccelerometerOnly(machine)
                if not picked then return end

                task.wait(0.35)

                local placeRemote = findPlaceRemote()
                if not placeRemote then
                    warn("[Special] runTemporalSequence: no place remote")
                    return
                end

                local bp = waitForAccelBlueprint(8)
                if not (bp and bp.Parent) then
                    warn("[Special] runTemporalSequence: blueprint timeout")
                    return
                end

                local placed = placeAccelConfirmed(placeRemote, bp, savedPlacement, savedRot)
                if not placed then
                    warn("[Special] runTemporalSequence: place failed after retry")
                    return
                end

                task.wait(1.0)

                local accelPlaced = waitForAccelModel(8)
                if not (accelPlaced and accelPlaced.Parent) then
                    warn("[Special] runTemporalSequence: could not confirm model in workspace after place")
                    return
                end

                local mpCheck = mainPart(accelPlaced)
                if not mpCheck then
                    warn("[Special] runTemporalSequence: placed model has no mainPart")
                    return
                end

                fireAccelRemote(accelPlaced)
                task.wait(1.0)
            end)

            if not ok then
                warn("[Special] runTemporalSequence error: " .. tostring(err))
                local bp = findAccelBlueprintInstance()
                if bp and bp.Parent and savedPlacement and savedRot then
                    warn("[Special] runTemporalSequence: error recovery - placing machine back from inventory")
                    local placeRemote = findPlaceRemote()
                    if placeRemote then
                        task.wait(0.5)
                        local placed = placeAccelConfirmed(placeRemote, bp, savedPlacement, savedRot)
                        if placed then
                            task.wait(1.0)
                            local accelPlaced = waitForAccelModel(8)
                            if accelPlaced and accelPlaced.Parent and mainPart(accelPlaced) then
                                fireAccelRemote(accelPlaced)
                            end
                        end
                    end
                end
            end

            if returnCF then
                pcall(function()
                    freshTemporalRunState()
                    teleportSticky(returnCF, true, true)
                end)
            end

            task.wait(3.0)
            vimTapKey(Enum.KeyCode.One)

            busy = false
        end

        local timerOn = false
        local timerConn = nil

        local function stopTimer()
            timerOn = false
            if timerConn then
                pcall(function() timerConn:Disconnect() end)
                timerConn = nil
            end
        end

        local function getPeriod(clock)
            return (clock >= 6 and clock < 20) and "DAY" or "NIGHT"
        end

        local function startTimer()
            if timerOn then return end
            timerOn = true
            local lastPeriod = getPeriod(game:GetService("Lighting").ClockTime)
            timerConn = game:GetService("Lighting"):GetPropertyChangedSignal("ClockTime"):Connect(function()
                if not timerOn then return end
                local period = getPeriod(game:GetService("Lighting").ClockTime)
                if period ~= lastPeriod then
                    lastPeriod = period
                    if period == "NIGHT" then
                        local root = hrp()
                        local accel = resolveAccelModel()
                        if root and accel then
                            local mp = mainPart(accel)
                            if mp then
                                local verticalDistance = root.Position.Y - mp.Position.Y
                                if verticalDistance > -50 then
                                    task.spawn(function()
                                        runTemporalSequence(true)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
        end

        if C.State.Toggles.SpecialTemporalTimer == nil then
            C.State.Toggles.SpecialTemporalTimer = false
        end

        tab:Section({ Title = "Temporal Accelerometer" })

        tab:Toggle({
            Title = "Auto Temporal Extra Attack",
            Value = (C.State.Toggles.SpecialTemporalTimer == true),
            Callback = function(state)
                C.State.Toggles.SpecialTemporalTimer = (state == true)
                if state then startTimer() else stopTimer() end
            end
        })

        if C.State.Toggles.SpecialTemporalTimer == true then
            startTimer()
        end

        _G.__SpecialTemporal = {
            Destroy = function()
                stopTimer()
                stopRollbackWatch()
                busy = false
                if camConn then pcall(function() camConn:Disconnect() end) end
                if DUMMY_MODEL then pcall(function() DUMMY_MODEL:Destroy() end) end
            end
        }
    end

    local ok, err = pcall(run)
    if not ok then warn("[Special] module error: " .. tostring(err)) end
end

-- special.lua

return function(C, R, UI)
    local function run()
        C  = C  or _G.C
        UI = UI or _G.UI

        local Players = (C and C.Services and C.Services.Players) or game:GetService("Players")
        local RS      = (C and C.Services and C.Services.RS)      or game:GetService("ReplicatedStorage")
        local WS      = (C and C.Services and C.Services.WS)      or game:GetService("Workspace")
        local Run     = (C and C.Services and C.Services.Run)      or game:GetService("RunService")

        local lp   = Players.LocalPlayer
        local Tabs = (UI and UI.Tabs) or {}
        local tab  = Tabs.Special
        if not tab then return end

        C.State = C.State or {}

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
    end

    local ok, err = pcall(run)
    if not ok then warn("[Special] module error: " .. tostring(err)) end
end
